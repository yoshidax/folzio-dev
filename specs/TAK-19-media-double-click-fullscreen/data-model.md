# Data Model: メディア表示区画のダブルクリックによる全画面の切り替え

永続化するデータはない。新しい値は、ダブルクリックで全画面を切り替えるかの判断だけで、FolzioCore に置く（research.md の R4）。

## PreviewContent.hasMedia（拡張）

| 値 | hasMedia |
|---|---|
| `.empty` | false（何も選択していない、フォルダ・zip ファイル・zip の中のディレクトリ・`..` の行。FR-075・FR-076（file-list.md）） |
| `.loading`・`.image`・`.animatedImage`・`.animatedImageData`・`.video`・`.unavailable` | true（メディアファイルを選んでいる。EC-141） |

## PreviewDoubleClick.togglesFullScreen(isFullScreen:hasMedia:isOverControl:)

| isOverControl | isFullScreen | hasMedia | 結果 | 根拠 |
|---|---|---|---|---|
| true | 任意 | 任意 | false | 再生コントロール・スクロールバーの上（FR-208、EC-142） |
| false | true | 任意 | true（解除） | 全画面中は画面のどこでも解除（FR-035、FR-208（2）、EC-141） |
| false | false | true | true（全画面化） | メディア表示区画（FR-208（1）） |
| false | false | false | false | 空のプレビュー（EC-141） |

- 状態を持たない純粋な関数とする。スライドショー中かどうかは判断に含めない（全画面の切り替え後の扱いは既存の FR-122 の処理に任せる）
- App 側では、`isOverControl` を認識の delegate のヒットテストで先に除外する（research.md の R2）。Core の判断にも同じ入力を持たせ、規則の全体を1か所のテストで示す
