# Research: TAK-88 ブラウザの画像をフォルダへ保存する

spec の要件を実装する方法の決定。参照する行番号は 2026-11-08 の `master`（`835b82c`）のもの。

## R1 先に行う確認（A-212）

- **Decision**: 実装の最初に、開発用の確認スクリプト `scripts/dev/pasteboard-probe.swift`（公開用リポジトリへ書き出さない）を作り、
  保守者が macOS で次を確かめる。結果を `checklists/validation.md` に記録し、結果に合わせて spec と plan を直してから残りを実装する。
  1. Safari・Chrome の Web の画像のドラッグで、ペーストボードにある型（file promise・PNG・TIFF・URL）、file promise が示す種類（`fileTypes`）、
     ドラッグ元が許可する操作（マスク）、書き出されるファイルの名前と形式、書き出しにかかる時間
  2. Safari・Chrome の「画像をコピー」、写真アプリの写真・動画の「コピー」で、一般のペーストボードにある型と大きさ
  3. 一般のペーストボードから `NSFilePromiseReceiver` を読み出し、書き出させられるか（写真アプリのコピー）
  4. ドロップの間に、ペーストボードの画像データ（数 MB と、作った 200 MB 程度の TIFF）を読むのにかかる時間
- **Rationale**: 受け付ける型・ホバー中の判定・読み出し方法は、ブラウザが渡すものに依存し、Cloud と CI では確かめられない。
  TAK-74 の T005 と同じく、先に事実を確かめてから仕様を確定する。
- **Alternatives considered**: Folzio に診断用の機能を入れる案。製品のコードに開発用の機能を残さないため採らない。
  スクリプトは `swift scripts/dev/pasteboard-probe.swift` で実行でき、Xcode を要しない。

## R2 受け付ける型とホバー中の判定（FR-348・FR-356）

- **Decision**: 3つのビュー（`DirectoryTreeViewController.swift:1059`、`ListModeView.swift:262`、`ThumbnailModeView.swift:642`）の
  `registerForDraggedTypes` に、`.fileURL` に加えて `NSFilePromiseReceiver.readableDraggedTypes`、`.png`、`.tiff` を登録する。
  App の `ExternalImageDrag` が、ドラッグの通し番号ごとに1回だけペーストボードを調べ、受け取るデータ（`ImportPayload`。data-model.md）を決める。
  - file URL があれば、今の `ExternalDrag`（TAK-74）の経路のまま（EC-241）
  - file promise は、`NSFilePromiseReceiver` を読み出し、`fileTypes` を Core の `ImportPayloadPolicy.acceptsPromise(declaredTypes:)` で判定する
    （画像・対応形式の動画・不明だけを受け付ける。FR-348）
  - 画像データは、型の一覧だけを見て、データを読まない
  - 受け付けるときの操作は `.copy`（ドラッグ元のマスクが `.copy` を含むときだけ）。修飾キーで変えない（FR-356）
  - 宛先の有効性は、今の各ビューの宛先の判断（`FileListDropTarget` など）をそのまま使う。画像の保存は自分自身・配下への転送の検査
    （`InternalDropValidation`）を要しないので、ファイルシステムを読まずに即答する
- **Rationale**: 型を登録しなければビューは反応しないので、URL・文字列だけのドラッグは今と同じく無視される（FR-348）。
  ホバー中にファイルシステムを読まないので、`DropOperationCache` の非同期の判定は不要で、通し番号ごとの結果だけを保持する。
- **Alternatives considered**: `NSImage.imageTypes` をすべて登録する案。PDF・EPS が含まれ、FR-357 で拒否するものに宛先を強調するため採らない。

## R3 受け取りの流れと打ち切り（FR-350・FR-355・FR-359・FR-363）

- **Decision**: App の `ImportSession`（MainActor）が1回のドロップ・ペーストを担う。
  1. `acceptDrop` の中で、受け取るデータを同期的に読む（file promise は `NSFilePromiseReceiver` の配列、画像データは R5）。ペーストボードはドロップの間しか確かでない
  2. Core の `ImportStaging` で、一時的なフォルダを detached task で作る（R10）。約束ごとに「約束のフォルダ」を、全体に1つ「検査用のフォルダ」を作る
  3. 約束ごとに `receivePromisedFiles(atDestination: 約束のフォルダ, options: [:], operationQueue: 専用のキュー, reader:)` を呼ぶ
  4. 待つ時間は、約束が示す種類で 60 秒（画像・不明）または 10 分（動画）。打ち切り・取り消しの後に届いた結果は捨てる
  5. 待つ間、1 秒ごとに一時的なフォルダの大きさの合計を detached task で調べ、約束ごとの上限（画像・不明 256 MB、動画 4 GB）の合計を超えたら全体を打ち切る
  6. すべての約束の結果がそろったら、R4 の検査と複製、R7 の確認と保存へ進む
  7. 成功・失敗・取り消しのどれでも、最後に一時的なフォルダを消し、R10 の記録から外す
- **1つの約束が複数のファイルを書き出す場合**（spec の5回目のレビューで plan に回した点）: `reader` が呼ばれるたびに1件のファイルとして扱う。
  `reader` が報告しないで約束のフォルダに書かれたファイル（付随するファイルなど）は使わず、一時的なフォルダとともに消す。
  報告されたファイルは、それぞれ FR-357 で検査する（Live Photo で静止画と動画が報告されれば、両方が対象になる）。
- **Rationale**: Apple の文書は、受け取り側がドロップの後で書き出しを待つ方式を示している。`reader` が報告したものだけを使うと、
  ドラッグ元が何を渡したかが明確になる。打ち切りの後に書き出されたファイルは、一時的なフォルダを消すことで残らない。
- **Alternatives considered**: 約束のフォルダにあるファイルをすべて受け取る案。報告されないファイル（作業用のファイルなど）を保存するおそれがあるため採らない。

## R4 検査と複製（FR-357・FR-360・FR-359、拡張属性）

- **Decision**: Core の `ImportInspector` が、報告されたファイルごとに detached task で次を行う。
  1. 構造: `lstat` でシンボリックリンクをたどらずに通常のファイルであること、パッケージ・エイリアス（`URLResourceValues.isAliasFile`）でないこと、
     親のフォルダがその約束のフォルダであること（`standardizedFileURL` の比較ではなく、`realpath` で解いた親）
  2. 複製: 検査用のフォルダへ `copyfile(_:_:nil, COPYFILE_CLONE | COPYFILE_ALL)` で複製する。
     APFS では内容を共有する複製になり、ほかのボリュームでは通常の複製になる（`COPYFILE_CLONE` は複製できないときに複製へ切り替わる）。
     `COPYFILE_ALL` で拡張属性（ブラウザが付けた quarantine の印を含む）を保つ（spec の5回目のレビューで plan に回した点）
  3. 大きさ: 複製の大きさ（`stat`）を、中身の種類の上限（画像 256 MB・動画 4 GB）と比べる（FR-359）
  4. 中身: 画像は `CGImageSourceCreateWithURL` の `CGImageSourceGetType` と `CGImageSourceGetCount` だけを読み、画像を展開しない。
     種類が `public.image` に適合し、SVG・PDF・EPS・PostScript（`UTType.svg`・`.pdf`・`com.adobe.encapsulated-postscript`・`com.adobe.postscript`）でないこと。
     動画は先頭の 64 バイトだけを読み、ISO の形式の `ftyp` の箱の銘柄（`qt  ` なら QuickTime、`isom`・`mp41`・`mp42`・`avc1`・`M4V ` などなら MP4）か、
     QuickTime の最初の箱（`moov`・`mdat`・`wide`・`free`・`skip`）で判別する。AVFoundation で開かない（再生しない）
  5. 名前: R6 の規則で、中身の形式の拡張子と名前の条件に合わせる
  6. 検査に通った複製の名前を、宛先に作る名前に変える（検査用のフォルダの中で。EC-243 の連番もここで付ける）
- **Rationale**: 複製を検査し、その複製を保存するので、ドラッグ元が元のファイルを開いたまま書き換えても影響しない（FR-357）。
  `copyfile` は Foundation と同じく UI に依存せず、Core で使える。ImageIO の型と枚数の読み出しはヘッダーだけで足りる（ImageIO の文書）。
- **Alternatives considered**: 識別子・大きさ・変更日時を比べる案。開いたままの書き込みと変更日時の書き戻しで通るため、4回目のレビューで採らなかった。
  動画を AVFoundation で開く案。攻撃者が作った動画のデコーダの処理を走らせることになり、形式の判別だけなら先頭の箱で足りるため採らない。
- **未検証**: `COPYFILE_CLONE` が exFAT・SMB で通常の複製に切り替わること、`COPYFILE_ALL` が拡張属性を保存できないボリュームで失敗しないこと（R1 とあわせて確かめる）。

## R5 画像データの読み出しと変換（FR-351・FR-352・FR-355・FR-359）

- **Decision**: ペーストボードの項目ごとに、型を PNG、その他の画素を持つ画像の型（`public.jpeg`・`public.heic` など、R1 の結果で確定）、TIFF の順に選ぶ。
  - 読み出し: ドロップ（`acceptDrop`）とペーストの中で、選んだ型の `NSPasteboardItem.data(forType:)` を UI スレッドで読む。
    同じ項目の `public.url`（http・https）の文字列も読む。HTML・リッチテキストは読まない（FR-353）
  - 256 MB を超えるデータは、読んだ直後に捨てて失敗とする
  - 変換と書き込みは detached task で、ImageIO の `CGImageSource`・`CGImageDestination` を使う。PNG のデータはそのまま書く。
    ほかの形式は、1 枚目の画像の画素数をプロパティで調べ、1 億以下なら PNG に変換する（FR-359）
- **Rationale**: ドロップのペーストボードは、ドロップを返した後に読める保証がない。Web の画像は通常数 MB で、UI スレッドで読む時間は短いと見込む。
- **未検証と代わりの方法**: 大きなデータの読み出しで UI が止まらないか（R1 の 4）。目安の 0.2 秒を超える場合は、ドロップの間に
  `NSPasteboardItem` の型の一覧だけを確かめ、データは `NSPasteboard(name: .drag)` から detached task で読む方式に切り替え、保守者に結果を示す。

## R6 名前（FR-352・FR-357・FR-360・EC-243）

- **Decision**: Core の `ImportedFileName` に純粋な関数を置き、Swift Testing で確かめる。
  - `isAcceptable(_:)`: 空でない、`/`・`:` を含まない、`.` で始まらない（`validateNewName` と同じ規則。`Sources/FolzioCore/Operations/NameValidation.swift`）、
    制御文字（Unicode の `Cc`）と書式の文字（`Cf`。文字の向きを変える U+202A〜U+202E・U+2066〜U+2069・U+200E・U+200F を含む）を含まない、UTF-8 で 200 バイト以下
  - `nameFromURL(_:)`: スキームが http・https のときだけ、最後のパスの要素のパーセントエンコードを解き、拡張子を除いて `.png` を付ける
  - `datedName(prefix:date:extension:)`: `<接頭辞> yyyy-MM-dd HH.mm.ss.<拡張子>`。ローカルのタイムゾーン、`en_US_POSIX` で ASCII の数字
  - `corrected(name:contentType:)`: FR-360。最後の拡張子を中身の形式の標準の拡張子（`UTType.preferredFilenameExtension`）に置き換える。
    今の拡張子が同じ形式で、かつ `MediaKind(fileExtension:)` が認める（`Sources/FolzioCore/Model/MediaKind.swift`）か標準の拡張子と大文字小文字だけ違うときは残す
  - `uniqueNames(_:)`: 1回の操作の中で重なる名前に、既存の `uniqueName(for:existingNames:)`（`NameValidation.swift`）で連番を付ける
- **Rationale**: 名前の規則は入力が細工される場所なので、純粋な関数にして境界の値を網羅的にテストする。既存の連番の関数を再利用する。
- **通信の検査との関係**: `scripts/check-no-network.sh` は `Sources` の中の語 `http` と `https://` を、コメントを含めて拒否する。
  スキームの比較に `"http"` の文字列が要るため、`AboutInfo.swift` の例外と同じ形で、`Sources/FolzioCore/Operations/ImportedFileName.swift` の
  `"http"` と `"https"` の2つのリテラルだけを許す例外を加える（文字列として比べるだけで、通信しない）。
  検査を変えることになるので、設計レビューで保守者の承認を得る。承認されなければ、http・https を見分けられないので、URL から名前を取らず、常に日時の名前にする（FR-352 を改める）。

## R7 保存の実行と確認（FR-347・FR-350・FR-356）

- **Decision**: `FileOperationCoordinator` に `saveReceived(_ staged: [URL], to destination: URL, sameVolume: Bool)` を加える。
  - 確認: `FileOperation(kind: .copy, sources: staged, destination: destination)` で `ConfirmationPresenter.confirm` を呼ぶ。
    確認モーダルは項目の名前（`lastPathComponent`。`ConfirmationPresenter.swift:125-126`）と宛先を示すので、検査用のフォルダの場所は出ない（FR-347）
  - 実行: 既存の `transferItems`（`FileOperationCoordinator.swift:229`）を、同じボリュームなら `.move`（名前の変更で移す）、
    起動ディスクの一時的な場所を使ったときは `.copy` で呼ぶ。衝突は既存の `ConflictPrompt` で扱う（FR-025）
  - 後処理: コピーと同じく `reloadCurrentFolder` と、宛先だけの `onFoldersChanged`。一時的なフォルダを通知に含めない。
    移動の後処理（`didMoveSearchItems`・履歴からの削除）は行わない
  - 動画も同じ経路で、コピーとして扱う。spec の FR-347 の文言を「画像・動画の保存」に直す（spec の5回目のレビューで plan に回した点）
- **Rationale**: 確認・衝突・失敗の表示を既存の経路で満たし、新しい種類の確認を作らない（憲章 原則 V）。
- **Alternatives considered**: `FileOperation.Kind` に `.import` を加える案。確認の省略設定・文言・衝突の処理をすべて複製することになるため採らない。

## R8 quarantine の印（FR-358）

- **Decision**: 検査用のフォルダの複製に対して、`URLResourceValues.quarantineProperties` を読み、なければ
  `["LSQuarantineAgentName": "Folzio", "LSQuarantineTimeStamp": 保存の日時, "LSQuarantineType": "LSQuarantineTypeOtherDownload"]` を設定する。
  URL のキー（`LSQuarantineDataURL`・`LSQuarantineOriginURL`）は設定しない。設定に失敗したとき（拡張属性を保存できないボリューム）は、印なしで続ける。
  宛先へ移す前に付けるので、印のないファイルは宛先に現れない（`.move` は拡張属性を保ち、`.copy` は `FileManager.copyItem` が保つ）。
- **Rationale**: Foundation の API で、LaunchServices を import せずに設定できる。キーの文字列は LaunchServices の定数の値と同じ。
- **未検証**: 設定した印が `xattr -p com.apple.quarantine` で読めること（macOS CI のテストで確かめる）。

## R9 進み具合のパネルと取り消し（FR-363）

- **Decision**: 1つの `ReceivingPanelController` が、待っている操作をすべて行として並べる、操作を妨げないパネル
  （`NSPanel`、`.nonactivatingPanel`、`becomesKeyOnlyIfNeeded`）を持つ（spec の5回目のレビューで plan に回した点。操作ごとにパネルを出さない）。
  - 行には、宛先のフォルダの名前、約束の件数、書き出し済みの件数、書き出された大きさの合計、段階（書き出し中・確認中）、行ごとの「取り消す」ボタンを示す
  - 操作の開始から 2 秒で終わらなければ、その行を出す。最後の行が消えたらパネルを閉じる
  - パネルは書き出しの間だけでなく、R4 の複製と検査の間も出し続ける（spec の5回目のレビューで plan に回した点）。確認モーダルを出す直前にその行を消す
  - ⌘. は、編集メニューの「受け取りを取り消す」（新しい項目。キーは ⌘.、割り当ての変更の対象外）にし、最後に始めた操作を取り消す
  - `validateMenuItem` は、待っている操作があり、キーのウインドウにシートがなく、アプリのモーダルがなく、最初の応答者がテキストの編集
    （`NSText`）でないときだけ有効にする。無効のときは、⌘. は既存の取り消し（`cancelOperation:`）へ渡る
- **Rationale**: メニューの項目にすると、キーボードで到達でき（憲章 原則 III）、メニューの有効・無効で ⌘. の優先順位を決められる。
  パネルを1つにすると、複数の操作が重ならない。
- **Alternatives considered**: パネルのボタンのキーとして ⌘. を割り当てる案。パネルはフォーカスを奪わないため、キーが届かないので採らない。

## R10 一時的なフォルダと起動時の掃除（FR-350・FR-361）

- **Decision**: Core の `ImportStaging` が作る。
  - 場所: `FileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: 宛先, create: true)`。
    作れない、または宛先と別のボリュームが返ったときは、`FileManager.default.temporaryDirectory` の中の `Folzio-Import/<UUID>` を使い、宛先へは複製する（FR-350）
  - 記録: `UserDefaults` のキー `internal.pendingImportFolders` に、`[path, volumeUUID, createdAt]` の配列を保存する。
    作った直後に加え、消した後に外す。設定ではないので、設定ウインドウ・設定のキーの一覧（`contracts/settings.md`）の「設定」には入れず、内部の記録として載せる
  - 起動時: `AppDelegate` の起動の後に detached task で、記録ごとにボリュームの識別子（`URLResourceValues.volumeUUIDString`）を比べ、
    名前が OS の置き換え用のフォルダの形（`(A Document Being Saved By Folzio` で始まる）か `Folzio-Import` の中の UUID であることを確かめてから、
    `FileManager.removeItem` で消す。確かめられない・30 日を過ぎたものは消さずに外す。ボリュームがないものは持ち越す
- **Rationale**: 設定ストア（`Sources/FolzioCore/Settings/SettingsStore.swift`）と同じ `UserDefaults` を使えば、新しいファイルの保存場所を作らずに済む。
  名前とボリュームの確認で、記録が書き換えられても一時的なフォルダ以外を消さない。
- **Alternatives considered**: `Application Support` に記録のファイルを置く案。Folzio はまだこの場所を使っておらず、作成・権限の扱いが増えるため採らない。

## R11 ペーストとメニューの有効・無効（FR-354）

- **Decision**: `FileContextMenu.pasteboardHasFileURLs()`（`FileContextMenu.swift:37`）と、ツリー・ファイルリストの `validateMenuItem` の条件を、
  App の `PasteboardImport.availability(.general)` に置き換える。型の一覧だけを見て、`fileURLs`・`promise`・`imageData`・`none` を返す。
  - 「ペースト」「ここにペースト」は `none` 以外で有効、「移動ペースト」「ここに移動ペースト」は `fileURLs` だけで有効
  - ペーストの実行（`FileOperationCoordinator.paste`。`FileOperationCoordinator.swift:111`）は、file URL があれば今のまま、
    なければ R3（約束）または R5（画像データ）の `ImportSession` を始める
  - 一般のペーストボードの約束（写真アプリのコピー）は、R1 の 3 で読み出せることを確かめてから実装する。読み出せなければ、spec の EC-241 と US78-AS8 を改め、画像データを使う
- **Rationale**: メニューの有効・無効でデータを読まない（FR-354）。判定を1か所にまとめ、ツリーとファイルリストで食い違わないようにする。

## R12 ローカライズ（A-213）

- **Decision**: `Sources/FolzioLocalization/TextKey.swift` と両言語の `Localizable.strings` に、spec の「新しい文言」の表のキーを加える。
  失敗の理由は `OperationFailureReason` に `importRejected(ImportRejection)` を加え、`ImportRejection`（data-model.md）ごとに文言を選ぶ。
  編集メニューの「受け取りを取り消す」/ `Cancel Receiving` と、パネルの段階（「書き出し中」/「確認中」、`Receiving` / `Checking`）も加える。
- **Rationale**: 既存の翻訳の仕組み（`contracts/localization.md`）に従う。

## R13 変えないもの

- アプリ内のドラッグ（`InternalDrag`）と、アプリ外の file URL の受け取り（`ExternalDrag`・`ExternalDropPolicy`）の規則と経路は変えない（SC-192）
- Folzio からアプリ外へ渡すデータは file URL だけのまま（A-205）
