# Research: TAK-74 他のアプリとのドラッグ&ドロップ

Cloud の環境（Linux）には macOS と Swift がないため、AppKit の挙動は実行して確かめていない。各項目の「根拠」は、現行のコードと
Apple の文書の記述に基づく。macOS で確かめる点は「未検証」に書き、quickstart.md の手順で保守者が確かめる。

ブラウザの画像の取り込みは、憲章 原則 III のため範囲外にした（spec の A-204）。そのための調査（file promise・画像データ・ファイル名）は、
別の Issue へ引き継ぐ（spec の Clarifications）。

## R1 アプリ内とアプリ外のドラッグの区別

- **Decision**: 既存の `InternalDrag.urls(_:)`（ドラッグ元が Folzio の登録済みのビューかどうか）で区別する。`nil` のときだけ、新しい `ExternalDrag` で扱う。
- **Rationale**: 014 の research（`specs/014-internal-drag-drop/research.md` の最初の項目）で、URL だけで区別しない方針を決めている。
  アプリ内の規則（FR-020・FR-162〜FR-165）を変えない（SC-184）ために、判定の入口を分ける。
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
- **未検証（実装の最初に確かめる。tasks.md の Phase 2）**:
  - Finder が同じボリュームで移動し、Option でコピーし、別のボリュームでコピーし、⌘ で移動すること
  - Dock のゴミ箱が受け付けて、ファイルをゴミ箱へ移すこと。Apple の文書は `NSDragOperation.delete` を「ドラッグ元が削除する」操作と説明しているため、
    Dock がドラッグ元に削除を任せる可能性がある（`draggingSession(_:endedAt:operation:)` が `.delete` で終わり、ファイルが元の場所に残る）
  - Option と ⌘ を同時に押したとき、OS がマスクをリンクだけに絞るか（Finder のエイリアスの操作）
- **未検証の結果による分岐（保守者の決定、spec の Clarifications）**: Dock がドラッグ元に削除を任せる場合は、`.delete` をマスクから外し、Dock のゴミ箱には対応しない。
  Folzio はドロップの後に削除や確認を行わない。ドロップ先が移した結果は、FSEvents（EC-13・EC-236）で反映する。
- **注意（A-132）**: ツリーは ⌘ を押したまま行からドラッグを始められない（選択の変更として扱う）。ツリーから ⌘ で移動するには、ドラッグを始めてから ⌘ を押す。
- **Alternatives considered**: `.every` を許可する案。`.link` と `.private` を含み、A-206 と合わないため採らない。

## R3 アプリ外からの file URL の操作の決め方（FR-346・EC-237・EC-238）

- **Decision**: Core に `ExternalDropPolicy.operation(_:)` を置き、入力（Option・⌘ の有無、すべての項目が宛先と同じボリュームか、
  ドラッグ元が移動とコピーを許可しているか）から `.move`・`.copy`・`nil` を返す純粋な関数にする。
  - 修飾キー: Option → コピー、⌘ → 移動。両方押したときは Option を優先してコピーを選ぶが、OS がマスクをリンクだけに絞っていれば
    コピーも移動も許可されず `nil` になる（FR-346。R2 の未検証）
  - 修飾キーなし: すべてが同じボリューム → 移動、それ以外 → コピー
  - ドラッグ元が許可しない場合: もう一方が許可されていればそれ、どちらもなければ `nil`（EC-238）
  - 移動が許可されているかは、マスクに `.move` か `.generic` があるかで判断する（R2 の ⌘ による `.generic` のため）
- **Rationale**: 判断ロジックを `FolzioCore` に置く（AGENTS.md の設計の制約）。修飾キーとマスクの組み合わせを Swift Testing で網羅できる。
  今のツリーは ⌘ を押すとマスクが `.generic` だけになり、`.move` も `.copy` も含まないので受け付けない（`DirectoryTreeViewController.swift:1806-1813`）。この不具合も直る。
- **Alternatives considered**: 今のツリーの「常に移動、Option でコピー」を残す案。保守者が Finder と同じ規則を選んだので採らない。

## R4 ボリュームの判定とホバー中の検証

- **Decision**: Core の `ExternalDropPolicy.allOnSameVolume(_:destination:)` が `URLResourceValues.volumeIdentifier` を比べる。
  値が取れない項目があれば `false`（コピー。元を消さない側に倒す）。宛先の検証は既存の `InternalDropValidation.validate(sources:destination:kind:)` をそのまま使う（EC-16・EC-121）。
  - **キャッシュは1つにまとめる**: `InternalDrag` の通し番号ごとのキャッシュ（`cache`・`pending`・`currentSequence`）を、アプリ内とアプリ外で共有する仕組み（`DropOperationCache`）に移す。
    違いは「操作の決め方」だけにする（アプリ内: Option でコピー、なければ移動。アプリ外: `ExternalDropPolicy`）。重複する仕組みを作らない（設計レビューの指摘 8）
  - **ペーストボードの URL も通し番号ごとにキャッシュする**: ホバー中の更新のたびにペーストボードを読み直さない（指摘 9）
  - **file URL の読み出しを1つの関数にまとめる**: 今は `InternalDrag.urls`・`FileOperationCoordinator.pasteboardFileURLs`・`DirectoryTreeViewController.fileURLs(from:)` の3か所にある（指摘 10）。
    `NSPasteboard` を受け取る関数にして、テストでは名前付きのペーストボードを渡す
  - **ドロップ時はホバー中の結果を使う**: `acceptDrop` は同期で結果を返す必要があり、ボリュームの判定（ファイルシステムの読み出し）を UI スレッドで行えない。
    ドロップ時の Option・⌘ に対応するキャッシュの結果を使い、まだ結果がなければ受け付けない（指摘 6）。実行の直前には、既存の `transfer` が検証し直す（R5）
- **Rationale**: ホバー中に UI スレッドでファイルシステムを読まない（AGENTS.md、014 の plan）。既存の仕組みと同じ方式にすると、Option・⌘ の変更で検証し直す挙動（FR-164）も同じになる。
- **未検証（CI の制約）**: CI のランナーには1つのボリュームしかないため、別のボリュームの場合（`false`）と混在の場合（EC-237）は、値が取れない場合の `false` だけを自動テストで確かめ、
  実際の別のボリュームは保守者が quickstart.md で確かめる。
- **Alternatives considered**: パスの先頭（`/Volumes/…`）で判定する案。ファームリンクや APFS のボリュームで誤るので採らない。

## R5 アプリ外からの受け取りの経路（FR-347）

- **Decision**: `FileOperationCoordinator.internalDrop(_:to:copy:)` を `drop(_:to:copy:)` に名前を変え、アプリ内とアプリ外の file URL の両方で使う。
  確認・衝突・失敗・反映・実行直前の再検証（`validateInternalDrop`）は今の `transfer(_:to:kind:validateDrop:)` のまま。
- **Rationale**: FR-347 は既存の確認・衝突・失敗・反映の規則に従うことを求めている。今の `transfer` がそれを満たしており、新しい経路を作る理由がない。
  今のツリーのアプリ外からのドロップは `copy`・`move` を直接呼ぶため（`DirectoryTreeViewController.swift:1849-1855`）、EC-121 の実行時の再検証を通らない。これもそろう。
  移動元の親フォルダは `notifyFoldersChanged` が含めるので、元の場所が Folzio に表示中なら FSEvents を待たずに反映される（FR-347）。
- **Alternatives considered**: `externalDrop` を別に作る案。中身が同じになるので採らない。

## R6 受け付けるペーストボードの型（FR-348）

- **Decision**: 3つのビューの `registerForDraggedTypes` は今の `[.fileURL]` のまま変えない。`ExternalDrag` は file URL だけを読み（`.urlReadingFileURLsOnly`）、
  なければ宛先を有効にしない。
- **Rationale**: 画像のデータや file promise の型を登録しなければ、ブラウザの画像・リンク・文字列のドラッグでビューが反応しない（US76-AS6・SC-183）。
  リスト形式とサムネイル形式は既に `.fileURL` を登録しているが（`ListModeView.swift:260`、`ThumbnailModeView.swift:599`）、ドロップの処理が `InternalDrag` だけを見ている（`ListModeView.swift:684`、
  `ThumbnailModeView.swift:1043`）ので、処理だけを加えればよい。
- **未検証**: ブラウザの画像のドラッグが file URL を含まないこと（含む場合は、そのファイルを受け取る移動・コピーになる）。

## R7 ツリーからアプリ外へドロップしたときの記録の消去（分析の U1）

- **Decision**: ツリーは `pendingOperationSources`（FR-219 の選択の更新のための、ドラッグしたフォルダの記録）を、今は操作なしで終わったドラッグでだけ消す
  （`DirectoryTreeViewController.swift:1762-1769`）。アプリ内の `acceptDrop`（ツリー・リスト形式・サムネイル形式）が coordinator の操作を始めたかどうかを、
  `InternalDrag` に「この通し番号のドラッグを Folzio で受け取った」という印として残し、`draggingSession(_:endedAt:operation:)` で印がなければ記録を消す。
- **Rationale**: アプリ外へのドロップは coordinator を通らないので、`onOperationFinished` が呼ばれず、記録が残る。残った記録は、次の無関係な操作の終了で
  ツリーの選択を誤って変える恐れがある（TAK-21 の tasks.md の Execution Notes の「懸念2」と同じ種類の問題）。
- **Alternatives considered**: 操作が `.delete` か、ドロップの位置がウインドウの外かで判断する案。Finder へのドロップも `.move` や `.copy` で終わり、
  位置はウインドウの重なりで誤るので採らない。

## R8 アプリ外へ移動した項目の検索結果からの除外（EC-236、分析の U2）

- **Decision**: `BrowserModel.pruneMissingResults(under:)`（`BrowserModel.swift:1473`）が、元の場所にもうない結果を外すときに、
  消えた祖先のフォルダを `movedSearchPaths` に記録する（アプリ内の移動の `didMoveSearchItems` と同じ記録）。ドラッグの終了での受け渡しは行わない。
  - 記録する場所: 存在を確かめる detached task の中で、消えた結果ごとに親をたどり、まだある親の直下の、消えているもの（一番上の消えた祖先）を記録する。
    ファイルだけが消え、親がある場合はそのファイルを記録する
  - たどる範囲は検索のルート（`listing.search?.root`）まで。ルートそのものが消えていればルートを記録する。ルートの外へはたどらない
  - 同じフォルダを何度も調べないよう、1回の呼び出しの中で、確かめたフォルダの結果を覚えておく
  - `movedSearchPaths` は「記録したパスと同じか、その配下か」で照合する（`isMovedSearchPath`、`BrowserModel.swift:1538-1541`）ので、フォルダを記録すれば、
    まだ届いていない同じフォルダの別のファイルも防げる
  - 呼び出し元は FSEvents の報告（`handleFileSystemEvent`、869 行）と、検索結果の表示中の再読み込み（`reloadCurrentFolder`、806 行）の2つで、どちらでも記録する
  - 記録は新しい検索を始めると消える（1090 行）
- **経緯**: 最初の設計は、ドラッグの終了の時点で消えた項目を調べて記録していた。設計レビューで、Finder が移動を非同期で行うと考えられ、
  ドラッグの終了の時点では項目がまだ元の場所にあって記録されない恐れがある、と指摘された。保守者の決定で、FSEvents の除外で記録する方式に改めた（spec の Clarifications）。
  3回目の設計レビューで、結果の行のファイルだけを記録すると、フォルダごと移動されたときに、まだ届いていない同じフォルダの別のファイル（例: `trip/day1/cat.jpg` を外した後の
  `trip/day1/bird.jpg`）が表示される、と指摘された。アプリ内の移動はフォルダ（`trip/day1`）を記録するので起きない。そのため、消えた祖先のフォルダを記録するようにした。
  たどる範囲は、レビューの案（検索のルートの直下まで）を広げ、ルートそのものが消えた場合も含めた（ルートの直下までだと、ルートごと消えたときにほかの子の遅れた結果が出る）
- **Rationale**: `pruneMissingResults` は今の結果から外すだけで、`movedSearchPaths` に記録しない（`BrowserModel.swift:1473-1527`）。検索中に移動元のフォルダの列挙が続いていると、
  遅れて届いた古い場所の結果が再び表示される（設計レビューの指摘）。`didMoveSearchItems` は記録して遅れた結果も外す（`BrowserModel.swift:1531-1536`、
  テストは `Tests/FolzioCoreTests/BrowserModelSearchTests.swift:9`）。
- **副作用（保守者が受け入れた）**: 検索の途中で項目が元の場所に戻されると、その場所の遅れた結果も表示しなくなる。今も FSEvents では結果を足さないため、影響は小さい。
- **Alternatives considered**: ドラッグの終了で記録する案（Finder の移動が終わっていないと働かない）、両方で記録する案（経路が2つになる）。どちらも採らない。
