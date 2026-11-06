# 契約: README の開発用リポジトリの注記と書き出し

## 印

- 開始の印: 行の全体が `<!-- dev-repo-note:start -->` である行
- 終了の印: 行の全体が `<!-- dev-repo-note:end -->` である行
- 印は行頭から書き、前後に空白を置かない

## 開発用リポジトリの README の形（`README.md` と `README.ja.md`）

```markdown
# Folzio

English | [日本語](README.ja.md)

<!-- dev-repo-note:start -->
> [!NOTE]
> （開発用リポジトリであることの説明と、https://github.com/yoshidax/folzio へのリンク）
<!-- dev-repo-note:end -->

**Browse and organize ...**
```

- 英語版と日本語版で、注記の位置と行の構造をそろえる
- 注記には、書き出さないファイル（`specs/` など）へのリンクを書かない

## `scripts/dev/strip-readme-dev-note.sh`

```text
scripts/dev/strip-readme-dev-note.sh <file>...
```

- 各ファイルを、その場で書き換える
- 開始の印から終了の印まで（両方の印を含む）を除く。終了の印の直後の行が空行なら、その 1 行も除く
- ファイルに印がなければ、変えない（終了コード 0）
- 次の場合は、ファイルを変えずに、理由とファイル名を標準エラーに出して、終了コード 1 で終わる
  - 開始の印の後に終了の印がない
  - 開始の印の前に終了の印がある
  - 範囲の中に、もう一度開始の印がある
  - 範囲が 2 つ以上ある
  - 除いた後に、`dev-repo-note:` の文字列が残る
- 指定したファイルがなければ、終了コード 1 で終わる

## `scripts/dev/publish.sh` での扱い

- `git archive HEAD` で一時ディレクトリへ取り出した後、開発用ファイルの混入の検査の前に、一時ディレクトリの
  `README.md` と `README.ja.md` に上のスクリプトを適用する
- スクリプトが失敗したら、公開先の初期化・同期・ステージの前に非ゼロで終了する
- 開発用リポジトリの作業ツリーの README は変えない
