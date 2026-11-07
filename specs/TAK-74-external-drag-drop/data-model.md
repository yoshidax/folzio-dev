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

## ImportedImageName（FolzioCore、新規）

画像データだけを受け取ったときのファイル名（FR-350、research.md R8）。

- 入力: 画像の URL（任意）、日時、接頭辞（表示言語の「画像」/`Image`）、タイムゾーン（既定はローカル）
- 出力: `.png` で終わるファイル名
- 規則:
  - URL の最後のパスの要素（パーセントエンコードを解く）から拡張子を除き、`.png` を付ける
  - 要素が空・`.` で始まる・`validateNewName` で不正のときは `<接頭辞> yyyy-MM-dd HH.mm.ss.png`
  - 同じ名前の衝突は解決しない（FR-025 の確認で扱う）

## ExternalDragPayload（FolzioApp、新規）

アプリ外からのドラッグで受け取るデータ。EC-241 の順に1つだけを選ぶ。

| case | 中身 | 操作 |
|---|---|---|
| `fileURLs([URL])` | file URL の項目 | ExternalDropPolicy で移動かコピー |
| `filePromises([NSFilePromiseReceiver])` | ファイルの書き出しの約束 | コピー（画像の保存） |
| `imageData(Data, sourceURL: URL?)` | PNG または TIFF のデータと、同じドラッグにある URL | コピー（PNG に変換して保存） |

- ペーストボードはドロップの間しか読めないので、`acceptDrop` の中で同期的に読み出し、値として保持する
- ホバー中（`validateDrop`）は種類の判定だけを行い、データの中身は読まない

## ImportSession（FolzioApp、新規）

file promise と画像データの保存の1回分（FR-348・FR-349、research.md R6・R7）。

状態の遷移:

1. 一時フォルダを作る（宛先と同じボリューム）
2. 書き出す（約束ごとに URL か Error。60 秒で打ち切る）／画像データを PNG で書く
3. 書き出したファイルを、コピーの経路（確認 → 衝突 → 実行 → 結果表示）で宛先へ入れる
4. 一時フォルダを消す（どの結果でも必ず行う）

- 書き出しの失敗は、手順 3 の結果と合わせて FR-026 の1回の表示にまとめる（EC-240）
- 書き出しが1件も成功しなければ、確認を出さずに失敗だけを表示する

## OperationFailureReason（FolzioCore、変更）

- 追加: `importTimedOut` — ドラッグ元のアプリがファイルの書き出しを時間内に終えなかった（EC-239）
- ドラッグ元のアプリが返したエラーは、既存の `systemFailure(systemReason:)` を使う

## ドラッグ元のマスク（FolzioApp、変更）

| ビュー | `forLocal: true` | `forLocal: false`（変更後） |
|---|---|---|
| ツリー | `[.copy, .move]`（変更なし） | `[.copy, .move, .generic, .delete]`（今は `.copy`） |
| リスト形式 | `[.copy, .move]`（変更なし） | `[.copy, .move, .generic, .delete]`（今は `.copy`） |
| サムネイル形式 | `[.copy, .move]`（変更なし） | `[.copy, .move, .generic, .delete]`（今は未設定） |
