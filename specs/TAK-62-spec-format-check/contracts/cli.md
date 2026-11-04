# Contract: 形式の検査と equivalence チェックのコマンド

## `scripts/dev/check-spec-format.py`

```text
python3 scripts/dev/check-spec-format.py [--update-baseline] [--config PATH] [--baseline PATH] [PATH ...]
```

| 引数 | 既定 | 内容 |
|---|---|---|
| `PATH ...` | `specs/product` | 調べるディレクトリまたはファイル。ディレクトリは中の `*.md` を再帰的に調べる。パスはリポジトリのルートからの相対で解釈する |
| `--config` | `scripts/dev/spec-format-config.json` | しきい値と対象外の範囲 |
| `--baseline` | `scripts/dev/spec-format-baseline.json` | 警告の基準値 |
| `--update-baseline` | なし | エラーが 0 件のとき、基準値を現在の警告の件数に書き換える |

- リポジトリのルートは、スクリプトの位置（`scripts/dev/` の2つ上）とする。作業ディレクトリによらない
- 基準値と対象外の範囲は、`specs/product/` からの相対パスで照合する

### 出力

標準出力に、検出した項目を1行ずつ出す。最後に集計を出す。

```text
specs/product/search.md:42: error quote-split: 「 is not closed on this line
specs/product/overview.md:120: warning line-width: display width 134 > 120
...
Errors: 1
Warnings: 85 (baseline 84)
  overview.md line-width: 4 > 3
```

- 基準値を下回った項目があるときは、`Warnings decreased; run with --update-baseline to record the new counts.` を出す

### 終了コード

| コード | 意味 |
|---|---|
| 0 | エラーが 0 件で、すべての警告の件数が基準値以下 |
| 1 | エラーがある、または警告の件数が基準値を超えた |
| 2 | 引数・設定・基準値の誤り（存在しないパス、読めない JSON、存在しない見出しの指定など） |

## `scripts/dev/check-spec-equivalence.py`

```text
python3 scripts/dev/check-spec-equivalence.py BASE
```

| 引数 | 内容 |
|---|---|
| `BASE` | 比較の基準とする版（例: `origin/master`）。`git merge-base BASE HEAD` を基準の版にする |

- 比べる範囲は `specs/product/` の `*.md`。基準の版は git から、作業ツリーはファイルシステムから読む

### 出力

```text
Comparing specs/product at 1a2b3c4 (merge-base of origin/master and HEAD) with the working tree
moved   contracts/settings.md:121 -> contracts/settings.md:125  補足説明「名前の変更・移動とツリーのフォルダを…
added   search.md:88  例外として…
removed search.md:90  ただし…
Identical: 12 files; changed: 3 files
Moved: 1, added: 1, removed: 1
```

- 差分がないときは `No differences other than formatting.` を出す

### 終了コード

| コード | 意味 |
|---|---|
| 0 | 「追加」と「削除」がない（差分なし、または移動だけ） |
| 1 | 「追加」または「削除」がある |
| 2 | 引数の誤り、または git の誤り（存在しない版、共通の祖先がない。EC-212） |
