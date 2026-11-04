# Data Model: 製品仕様の形式の検査

## 行の種類（形式の検査）

各行を、上から順に次のどれかに分ける（research.md の R2）。

| 種類 | 条件 | 検査 |
|---|---|---|
| コードブロックの区切り | 行頭の空白の後が ` ``` ` | なし。中と外を切り替える |
| コードブロックの中 | 区切りの間 | なし（EC-207） |
| 表 | 行頭の空白の後が `|` | 表のまとまりとして調べる |
| 見出し | `#` の並びと空白で始まる | 幅 |
| 項目 | 行頭の空白の後が `- `、`* `、`数字. ` | 幅、引用、インラインコード、定義 |
| 続きの行 | 上のどれでもない空でない行 | 幅、引用、インラインコード、英語句 |
| 空行 | 空白だけ | なし |

## 検出の結果（Finding）

| 属性 | 内容 |
|---|---|
| `path` | `specs/product/` からの相対パス |
| `line` | 1 から始まる行の番号 |
| `rule` | 検出項目の識別子（下の表） |
| `severity` | `error` または `warning` |
| `message` | 何が崩れているか（幅の桁数、キーなど） |

| `rule` | 重大度 | 内容 | 要件 |
|---|---|---|---|
| `line-width` | 警告 / エラー | 行の表示幅が 120 桁 / 160 桁を超える | FR-297、FR-298 |
| `table-row-split` | エラー | 表の行が物理的に複数行にまたがる | FR-297 |
| `table-columns` | エラー | 列数が見出しの行と違う | FR-297 |
| `table-separator` | エラー | 2 行目が区切りの行でない | FR-297 |
| `table-empty` | エラー | 本体の行がない | FR-297 |
| `code-split` | エラー | インラインコードが行をまたぐ | FR-297 |
| `quote-split` | エラー | 引用（「」・“ ”）が行をまたぐ | FR-297 |
| `english-split` | エラー | 英語句が行をまたぐ | FR-297 |
| `see-below-detail` | エラー | `下記` に対応する「表の詳細」の項目がない | FR-297 |
| `cell-width` | 警告 | セルの表示幅が 80 桁を超える | FR-298 |
| `multi-sentence` | 警告 | 定義の本文が 2 文以上 | FR-298 |

`line-width` は、160 桁を超えればエラー、120 桁を超えれば警告として、どちらか一方だけを出す。

## 設定（`scripts/dev/spec-format-config.json`）

```json
{
  "line_width_warning": 120,
  "line_width_error": 160,
  "cell_width_warning": 80,
  "exclusions": [
    {
      "file": "overview.md",
      "section": "## 出発点となった要望",
      "rules": ["quote-split", "english-split", "line-width"],
      "reason": "..."
    },
    {
      "file": "contracts/localization.md",
      "table_columns": ["日本語", "英語"],
      "rules": ["cell-width"],
      "reason": "..."
    }
  ]
}
```

- `section` は見出しの行と完全に一致する文字列。その見出しの次の行から、同じかより上位の次の見出しの前までを対象外にする
- `table_columns` は、見出しの行のセルにすべての列名を含む表を対象外にする
- `section` と `table_columns` のどちらもなければ、ファイル全体を対象外にする
- 存在しないファイル・見出しを指定した場合は、設定の誤りとして終了コード 2 で止める（対象外の指定が黙って効かなくなるのを防ぐ）

## 基準値（`scripts/dev/spec-format-baseline.json`）

```json
{
  "warnings": {
    "contracts/keyboard-and-menus.md": {"cell-width": 2},
    "overview.md": {"line-width": 3, "multi-sentence": 5}
  }
}
```

- 警告が 0 件のファイルと項目は書かない
- `--update-baseline` で、現在の件数に書き換える（キーは並べ替えて出力し、差分を読みやすくする）

## 正規化した本文（equivalence チェック）

| 属性 | 内容 |
|---|---|
| `text` | 正規化後の文字列（research.md の R11 の 2） |
| `lines` | `text` の各文字に対応する、元のファイルの行の番号 |

## 差分の項目（equivalence チェック）

| 属性 | 内容 |
|---|---|
| `kind` | `moved`、`added`、`removed` |
| `base` | 基準の版のファイルと行の番号（`added` はなし） |
| `head` | 作業ツリーのファイルと行の番号（`removed` はなし） |
| `text` | 正規化後の断片（表示は先頭の 80 文字まで） |
