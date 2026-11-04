# 契約: 公開書き出しでの workflow の扱い

`scripts/dev/publish.sh [書き出し先]` の引数・既定値（`../folzio-oss`）・終了コードの意味は変えない。次を加える。
反映の作業で、`specs/product/contracts/scripts.md` に要点を加える。

## 除外

- `git archive HEAD` は `.github/workflows/` を除く（`.gitattributes` の `/.github/workflows export-ignore`）。
- `git archive` の結果に `.github/workflows/` の項目があれば、既存の混入検査と同じメッセージ
  （「書き出しに開発用のファイルが含まれています（.gitattributes を確認してください）」）で非ゼロ終了する。
  公開先の初期化・同期・ステージより前に止まる。

## 配置

- `HEAD` の `scripts/dev/oss-workflows/` の直下にある通常ファイルのうち、名前が `.yml` または `.yaml` で終わるものを、
  同じ名前・同じ内容で書き出しの `.github/workflows/` に置く（data-model.md の「定義として扱う条件」）。
- 定義が 1 つもなければ、書き出しに `.github/workflows/` を作らない。
- 配置の後、書き出しの `.github/workflows/` の名前の集合と内容が管理元の定義と一致しなければ、非ゼロ終了する（同期の前）。
- 配置した定義の名前を標準出力に示す（定義がなければ、ないことを示す）。

## 順序

1. README の同期・英語のコメントの検査（既存）
2. `git archive HEAD` で取り出す（既存）
3. 開発用のファイル（`.github/workflows/` を含む）の混入検査（既存の対象を広げる）
4. 公開用 workflow の配置と、その確認（新規）
5. `$HOME`・ユーザー名の検査（既存。配置の後に行い、公開用 workflow も対象にする）
6. 公開先の初期化と `rsync -a --delete`（既存。保護の対象は変えない）
7. 公開先でのビルド・テスト・ネットワークの検査・ステージ（既存）

## 変えないこと

- `rsync` の除外（`/.git`、`/.build`、`/.vscode`）。公開先の `.github/workflows/` は保護しない（research.md の R5）
- 開発用リポジトリの `.github/workflows/macos-swift-ci.yml` の内容とトリガー
- `scripts/dev/release-distribution.sh` の動作
