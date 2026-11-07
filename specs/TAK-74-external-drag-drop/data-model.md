# Data Model: TAK-74 他のアプリとのドラッグ&ドロップ

新しい永続データ・設定は追加しない。ドラッグの間だけ使う値を定める。

## ExternalDropPolicy（FolzioCore、新規）

アプリ外から受け取る file URL の操作を決める（FR-346・EC-237・EC-238、research.md R3・R4）。

| 入力 | 型 | 意味 |
|---|---|---|
| `option` | Bool | ドロップ時に Option を押している |
| `command` | Bool | ドロップ時に ⌘ を押している |
| `allOnSameVolume` | Bool | すべての項目が宛先と同じボリューム（値が取れなければ false） |
| `allowsMove` | Bool | ドラッグ元のマスクに `.move` または `.generic` がある（App 側で求める） |
| `allowsCopy` | Bool | ドラッグ元のマスクに `.copy` がある（App 側で求める） |

出力: `Operation?`（`.move`・`.copy`・`nil`）

| option | command | allOnSameVolume | 優先する操作 |
|---|---|---|---|
| true | 任意 | 任意 | コピー |
| false | true | 任意 | 移動 |
| false | false | true | 移動 |
| false | false | false | コピー |

- 優先する操作が許可されていなければ、もう一方が許可されていればそれを返し、どちらもなければ `nil`（EC-238）
- Option と ⌘ の同時は、OS がマスクをリンクだけに絞ると `allowsMove`・`allowsCopy` がどちらも false になり、`nil` になる（FR-346）
- `allOnSameVolume(_ sources: [URL], destination: URL) -> Bool`: ファイルシステムを読むので、UI スレッドで呼ばない

## PasteboardFileURLs（FolzioApp、新規。既存の3か所をまとめる）

- `fileURLs(in pasteboard: NSPasteboard) -> [URL]`: `.urlReadingFileURLsOnly` で file URL だけを読む（FR-348、research.md R4・R6）
- `InternalDrag`・`ExternalDrag`・`FileOperationCoordinator` の一般のペーストボードからの読み出しが使う

## DropOperationCache（FolzioApp、新規。InternalDrag のキャッシュを移す）

ホバー中の操作の決定を、ドラッグの通し番号ごとにキャッシュする（research.md R4）。アプリ内とアプリ外で共有する。

- 通し番号が変わったら、キャッシュ・計算中の集合・URL を捨てる
- 通し番号ごとに、ペーストボードから読んだ URL の配列を1回だけ保持する
- キー: URL の配列・宛先・Option・⌘。値: 決まった操作（`InternalDropValidation.Kind?`）
- 結果が出るまでは `[]`（宛先を有効にしない）。計算は detached task で行い、渡された「操作の決め方」を使う
  - アプリ内: Option ならコピー、なければ移動。`InternalDropValidation.validate` が `.valid` のときだけ
  - アプリ外: `ExternalDropPolicy.operation` と `allOnSameVolume`、`InternalDropValidation.validate`
- `cachedOperation(...)`: ドロップ時に使う。キャッシュがなければ nil（受け付けない）。ファイルシステムを読まない
- 移動を返すときは、マスクに `.move` があれば `.move`、なければ `.generic`

## InternalDrag・ExternalDrag（FolzioApp）

- `InternalDrag`（変更）: キャッシュを `DropOperationCache` に移す。通し番号ごとに「Folzio のビューで受け取った」印を残す `markAccepted(_:)` と
  `wasAccepted(_:) -> Bool` を加える（research.md R7）。ツリー・リスト形式・サムネイル形式のアプリ内の `acceptDrop` で印を残す
- `ExternalDrag`（新規）: `urls(_:)`（`InternalDrag.urls` が nil で file URL があるときだけ）、アプリ外の「操作の決め方」、アプリ外向けのマスクの定数

## BrowserModel（FolzioCore、変更）

- 変更: `pruneMissingResults(under:)`（private）が、消えた結果を外すときに、消えた祖先のうち一番上のフォルダ（検索のルートまで。ファイルだけが消えたときはそのファイル）を
  `movedSearchPaths` に記録する（EC-236、research.md R8）。公開のメソッドは増やさない
- 追加（任意）: 一番上の消えた祖先を求める処理は、ファイルシステムの存在の確認を引数で渡せる純粋な関数にして、単体でテストできるようにする

## ドラッグ元のマスク（FolzioApp、変更）

| ビュー | `forLocal: true` | `forLocal: false`（変更後） |
|---|---|---|
| ツリー | `[.copy, .move]`（変更なし） | `[.copy, .move, .generic, .delete]`（今は `.copy`） |
| リスト形式 | `[.copy, .move]`（変更なし） | `[.copy, .move, .generic, .delete]`（今は `.copy`） |
| サムネイル形式 | `[.copy, .move]`（変更なし） | `[.copy, .move, .generic, .delete]`（今は未設定） |

## 登録する型（変更なし）

- 3つのビューとも `[.fileURL]` のまま（research.md R6）
