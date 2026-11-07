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
- `allOnSameVolume(_ sources: [URL], destination: URL) -> Bool`: ファイルシステムを読むので、UI スレッドで呼ばない

## ExternalDrag（FolzioApp、新規）

アプリ外からのドラッグの受け取り（FR-345・FR-346・FR-348、research.md R1・R4・R6）。

- `urls(_ info) -> [URL]?`: `InternalDrag.urls(info)` が nil で、ペーストボードに file URL があるときだけ、その URL の配列を返す
- `operation(_ info, destination) -> NSDragOperation`: ホバー中の操作。検証とボリュームの判定を detached task で求め、次のキーごとにキャッシュする
  - キー: `draggingSequenceNumber`・URL の配列・宛先・Option・⌘
  - 結果が出るまでは `[]`（宛先を有効にしない）
  - 移動を返すときは、マスクに `.move` があれば `.move`、なければ `.generic`
- `dropOperation(_ info, destination) -> InternalDropValidation.Kind?`: ドロップ時の操作（ホバー中と同じ規則で決め直す）

## InternalDrag（FolzioApp、変更）

- 追加: 通し番号ごとに「Folzio のビューで受け取った」印を残す `markAccepted(_ sequence:)` と、それを読む `wasAccepted(_ sequence:) -> Bool`（research.md R7）
- ツリー・リスト形式・サムネイル形式の、アプリ内のドラッグの `acceptDrop` で印を残す

## ドラッグ元のマスク（FolzioApp、変更）

| ビュー | `forLocal: true` | `forLocal: false`（変更後） |
|---|---|---|
| ツリー | `[.copy, .move]`（変更なし） | `[.copy, .move, .generic, .delete]`（今は `.copy`） |
| リスト形式 | `[.copy, .move]`（変更なし） | `[.copy, .move, .generic, .delete]`（今は `.copy`） |
| サムネイル形式 | `[.copy, .move]`（変更なし） | `[.copy, .move, .generic, .delete]`（今は未設定） |

## 登録する型（変更なし）

- 3つのビューとも `[.fileURL]` のまま（research.md R6）
