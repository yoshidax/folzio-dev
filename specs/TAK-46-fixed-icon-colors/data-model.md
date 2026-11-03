# Data Model: TAK-46

永続データなし。

| ListItemKind | ListItemIconTone | 色 |
|---|---|---|
| `.folder`, `.directory` | `.folderBlue` | 固定の青（R1） |
| `.archive` | `.archiveYellow` | 固定の黄（R2） |
| `.parent` | `.secondary` | `secondaryLabelColor`（従来） |
| `.media(_)` | `.secondary` | 呼び出し側で `nil`（縮小画像／汎用アイコンは従来どおり） |
