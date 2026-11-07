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
- **未検証**: Finder が同じボリュームで移動し、Option でコピーし、別のボリュームでコピーすること。Dock のゴミ箱が受け付けて、ファイルをゴミ箱へ移すこと。
  ゴミ箱へ移す処理をドロップ先（Dock/Finder）が行い、ドラッグ元の Folzio に削除を求めないこと（`draggingSession(_:endedAt:operation:)` が `.delete` で終わっても、
  Folzio は何も削除しない）。ドロップ先が移した結果は、FSEvents（EC-13・EC-236）で反映する。
- **Alternatives considered**: `.every` を許可する案。`.link` と `.private` を含み、A-206 と合わないため採らない。

## R3 アプリ外からの file URL の操作の決め方（FR-346・EC-237・EC-238）

- **Decision**: Core に `ExternalDropPolicy.operation(_:)` を置き、入力（Option・⌘ の有無、すべての項目が宛先と同じボリュームか、
  ドラッグ元が移動とコピーを許可しているか）から `.move`・`.copy`・`nil` を返す純粋な関数にする。
  - 修飾キー: Option → コピー、⌘ → 移動（両方押したときは Option を優先してコピー。FR-346）
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

- **Decision**: 新しい処理を加えない。既存の `BrowserModel.handleFileSystemEvent(_:)` が、検索結果の表示中は報告されたフォルダの下で消えた結果を外す
  （`pruneMissingResults`、`BrowserModel.swift:865-870`）。
- **Rationale**: ドロップ先のアプリが移動・削除した結果は、FSEvents で元の親フォルダの変更として報告される。アプリ内の移動（`didMoveSearchItems`）と結果が同じになる。
- **未検証**: 検索結果の表示中に Finder へ移動したとき、FSEvents の報告から実際に行が外れるまでの時間。
