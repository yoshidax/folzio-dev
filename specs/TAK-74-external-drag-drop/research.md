# Research: TAK-74 他のアプリとのドラッグ&ドロップ

Cloud の環境（Linux）には macOS と Swift がないため、AppKit の挙動は実行して確かめていない。各項目の「根拠」は、現行のコードと
Apple の文書の記述に基づく。macOS で確かめる点は「未検証」に書き、quickstart.md の手順で保守者が確かめる。

## R1 アプリ内とアプリ外のドラッグの区別

- **Decision**: 既存の `InternalDrag.urls(_:)`（ドラッグ元が Folzio の登録済みのビューかどうか）で区別する。`nil` のときだけ、新しい `ExternalDrag` で扱う。
- **Rationale**: 014 の research（`specs/014-internal-drag-drop/research.md` の最初の項目）で、URL だけで区別しない方針を決めている。
  アプリ内の規則（FR-020・FR-162〜FR-165）を変えない（SC-185）ために、判定の入口を分ける。
- **Alternatives considered**: ドラッグ元のアプリのバンドル ID で区別する案。`NSDraggingInfo` からは取れず、ビューの同一性で足りるので採らない。

## R2 アプリ外へのドラッグで許可する操作（FR-344）

- **Decision**: ツリー（`NSOutlineView`）・リスト形式（`NSTableView`）・サムネイル形式（`NSCollectionView`）の
  `setDraggingSourceOperationMask(_:forLocal: false)` を `[.copy, .move, .generic, .delete]` にする。`forLocal: true` は今の `[.copy, .move]` のまま。
- **Rationale**:
  - 今はツリーとリスト形式が `.copy` だけ（`DirectoryTreeViewController.swift:1061`、`ListModeView.swift:263`）で、Finder は移動できない。
    サムネイル形式はアプリ外向けの設定がない（`ThumbnailModeView.swift:600`）。3つをそろえる。
  - `NSDraggingInfo.draggingSourceOperationMask` の文書は、⌘ を押すとマスクが `.generic` に絞られると説明している（Option は `.copy`、Control は `.link`）。
    Finder がドラッグ元に `.generic` を求める場合に備えて含める。
  - Dock のゴミ箱へのドロップは、保守者の決定（spec の Clarifications）で許可する。ゴミ箱は `.delete` を使うため含める。
  - `.link`（エイリアス）は A-206 で対象外にするため含めない。
- **未検証**: Finder が同じボリュームで移動し、Option でコピーし、別のボリュームでコピーすること。Dock のゴミ箱が受け付けて、ファイルをゴミ箱へ移すこと。
  ゴミ箱へ移す処理をドロップ先（Dock/Finder）が行い、ドラッグ元の Folzio に削除を求めないこと（`draggingSession(_:endedAt:operation:)` が `.delete` で終わっても、
  Folzio は何も削除しない）。ドロップ先が移した結果は、FSEvents（EC-13・EC-236）で反映する。
- **Alternatives considered**: `.every` を許可する案。`.link` と `.private` を含み、A-206 と合わないため採らない。

## R3 アプリ外からの file URL の操作の決め方（FR-346・EC-237・EC-238）

- **Decision**: Core に `ExternalDropPolicy.operation(_:)` を置き、入力（Option・⌘ の有無、すべての項目が宛先と同じボリュームか、
  ドラッグ元が移動とコピーを許可しているか）から `.move`・`.copy`・`nil` を返す純粋な関数にする。
  - 修飾キー: Option → コピー、⌘ → 移動（両方押したときは Finder の表示に合わせて Option を優先し、コピー）
  - 修飾キーなし: すべてが同じボリューム → 移動、それ以外 → コピー
  - ドラッグ元が許可しない場合: もう一方が許可されていればそれ、どちらもなければ `nil`（EC-238）
  - 移動が許可されているかは、マスクに `.move` か `.generic` があるかで判断する（R2 の ⌘ による `.generic` のため）
- **Rationale**: 判断ロジックを `FolzioCore` に置く（AGENTS.md の設計の制約）。修飾キーとマスクの組み合わせを Swift Testing で網羅できる。
  今のツリーは ⌘ を押すとマスクが `.generic` だけになり、`.move` も `.copy` も含まないので受け付けない（`DirectoryTreeViewController.swift:1806-1813`）。この不具合も直る。
- **Alternatives considered**: 今のツリーの「常に移動、Option でコピー」を残す案。保守者が Finder と同じ規則を選んだので採らない。

## R4 ボリュームの判定とホバー中の検証

- **Decision**: Core の `ExternalDropPolicy.allOnSameVolume(_:destination:)` が `URLResourceValues.volumeIdentifier` を比べる。
  値が取れない項目があれば `false`（コピー。元を消さない側に倒す）。呼び出しは detached task で行い、
  `InternalDrag.operation(_:destination:)` と同じく、ドラッグの通し番号（`draggingSequenceNumber`）ごとに結果をキャッシュする。
  宛先の検証は既存の `InternalDropValidation.validate(sources:destination:kind:)` をそのまま使う（EC-16・EC-121）。
- **Rationale**: ホバー中に UI スレッドでファイルシステムを読まない（AGENTS.md、014 の plan）。既存の仕組みと同じ方式にすると、Option・⌘ の変更で検証し直す挙動（FR-164）も同じになる。
- **Alternatives considered**: パスの先頭（`/Volumes/…`）で判定する案。ファームリンクや APFS のボリュームで誤るので採らない。

## R5 アプリ外からの受け取りの経路（FR-347）

- **Decision**: `FileOperationCoordinator.internalDrop(_:to:copy:)` を `drop(_:to:copy:)` に名前を変え、アプリ内とアプリ外の file URL の両方で使う。
  確認・衝突・失敗・反映・実行直前の再検証（`validateInternalDrop`）は今の `transfer(_:to:kind:validateDrop:)` のまま。
- **Rationale**: FR-347 は既存の確認・衝突・失敗・反映の規則に従うことを求めている。今の `transfer` がそれを満たしており、新しい経路を作る理由がない。
  今のツリーのアプリ外からのドロップは `copy`・`move` を直接呼ぶため（`DirectoryTreeViewController.swift:1849-1855`）、EC-121 の実行時の再検証を通らない。これもそろう。
- **Alternatives considered**: `externalDrop` を別に作る案。中身が同じになるので採らない。

## R6 ファイルの書き出しの約束（file promise）の受け取り（FR-348・EC-239・EC-240）

- **Decision**: `acceptDrop` の中で、ペーストボードから `NSFilePromiseReceiver` を読み出す（ペーストボードはドロップの間しか読めないため、同期的に読む）。
  宛先と同じボリュームの一時フォルダ（`FileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: 宛先, create: true)`）を作り、
  `receivePromisedFiles(atDestination:options:operationQueue:reader:)` で書き出させる。書き出しは専用の `OperationQueue` で待ち、すべての約束の結果（URL か Error）がそろったら、
  書き出されたファイルを既存のコピーの経路（確認・衝突・失敗）で宛先へ入れる。最後に一時フォルダを必ず消す（成功・キャンセル・失敗のどれでも）。
  - 書き出しが 60 秒で終わらない約束は失敗として扱う（EC-239）。
  - 失敗した約束は、ファイル名が分かればその名前、分からなければ既定の名前（R8）で、FR-026 の結果表示に含める。
- **Rationale**: 宛先へ直接書き出させると、確認モーダルのキャンセル（US77-AS5）と衝突の「両方残す」（FR-025）を守れない。一時フォルダを経ると、既存のコピーと同じ規則を使える。
  `itemReplacementDirectory` は宛先と同じボリュームに作られるので、コピーの時間が短い。Apple の文書は、受け取り側がドロップの後で書き出しを待つ方式を示しており、
  ブラウザが画像を取得する通信はブラウザ側で行われる（FR-351）。
- **未検証**: Safari と Chrome が画像のドラッグで file promise を渡すか、ファイル名と拡張子に何を使うか、書き出しにかかる時間。
- **Alternatives considered**: 確認を先に出し、確定後に書き出させる案。確認モーダルにファイル名を出せず（書き出すまで名前が確定しないことがある）、衝突も書き出し後でないと分からないので採らない。

## R7 画像データの保存（FR-349・FR-350）

- **Decision**: file URL も file promise もないとき、`acceptDrop` の中でペーストボードの PNG または TIFF のデータと、同じドラッグにある URL（file URL 以外）を同期的に読み出す。
  PNG への変換と一時フォルダへの書き込みは detached task で ImageIO（`CGImageSource`・`CGImageDestination`）を使って行い、以後は R6 と同じくコピーの経路で宛先へ入れる。
- **Rationale**: ImageIO はスレッドを問わず使え、UI スレッドで変換しない（AGENTS.md）。既に PNG のデータなら再エンコードせずにそのまま書く。
- **未検証**: ブラウザが file promise を渡さずに画像データだけを渡す場面があるか（Chrome の一部の画像、ほかのアプリの画像など）。

## R8 画像データのファイル名（FR-350）

- **Decision**: Core に `ImportedImageName.fileName(sourceURL:date:basePrefix:)` を置く。
  - URL の最後のパスの要素を、パーセントエンコードを解いて取り出し、拡張子を除いて `.png` を付ける（`https://example.com/a/cat.jpg?w=1` → `cat.png`）。
  - 名前が空、`.` で始まる、`/` を含む、既存の名前の検証（`validateNewName`。`Sources/FolzioCore/Operations/NameValidation.swift`）で不正な場合は、日時の名前にする。
  - 日時の名前は `<接頭辞> yyyy-MM-dd HH.mm.ss.png`。接頭辞は表示言語の「画像」/`Image`（新しい翻訳のキー）、日時はローカルのタイムゾーンで、数字は ASCII にする。
- **Rationale**: 規則を純粋な関数にして、URL の形・不正な名前・日時の書式を Swift Testing で確かめる。URL を文字列として解析するだけで通信しない（FR-351）。
- **Alternatives considered**: `NSURL` の `lastPathComponent` を使う案。それで取り出し、検証を加える（同じ意味）。

## R9 受け付けるペーストボードの型（FR-345・EC-241・FR-351）

- **Decision**: 3つのビューの `registerForDraggedTypes` に、`.fileURL` に加えて `NSFilePromiseReceiver.readableDraggedTypes`、`.png`、`.tiff` を登録する。
  `ExternalDrag.payload(from:)` が、file URL → file promise → 画像データの順に1つを選ぶ（EC-241）。どれもなければ `nil` で、宛先を有効にしない（URL・文字列だけのドラッグ）。
- **Rationale**: `.URL` や文字列の型は登録しない。登録しなければ、URL だけのドラッグでビューが反応しない。
- **未検証**: 型の登録を増やしても、アプリ内のドラッグと、サムネイルの画像のビューが登録を持たないこと（`ThumbnailDropTargetTests`）に影響しないこと。

## R10 アプリ外からの受け取りの結果の反映

- **Decision**: 既存の `transfer` の後処理（`reloadCurrentFolder`・`notifyFoldersChanged`・`onOperationFinished`）をそのまま使う。
  一時フォルダからのコピーでは、一時フォルダを `notifyFoldersChanged` の対象から外す（ツリーにない場所を更新させない）。
  移動元が Folzio に表示中のフォルダにある場合は、`notifyFoldersChanged` が元の親フォルダを含めるので、FSEvents を待たずに反映される（FR-347、EC-13）。
- **Rationale**: FR-027 の即時の反映は既存の経路で満たされている。

## R11 ローカライズ

- **Decision**: `TextKey` に、画像の既定の接頭辞（「画像」/`Image`）と、書き出しが時間内に終わらなかった理由（`OperationFailureReason` の新しい case `importTimedOut`）の文言。
  ドラッグ元のアプリが返したエラーは、既存の `systemFailure(systemReason:)` でそのまま示す（EC-111 と同じく訳し直さない）を加え、
  `ja.lproj`・`en.lproj` の `Localizable.strings` に訳を加える。
- **Rationale**: 既存の新規フォルダの既定名（`folder.defaultName`）と同じ方式（`specs/product/contracts/localization.md`）。
