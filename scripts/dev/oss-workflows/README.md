# 公開用リポジトリの workflow の管理元

このディレクトリは、公開用リポジトリ（`folzio-oss`）だけで動かす GitHub Actions の workflow の元のファイルを置く場所。
方針の正本は [docs_private/repository-and-release.md](../../../docs_private/repository-and-release.md) の「GitHub Actions の workflow」。

- `scripts/dev/publish.sh` は、書き出しのときに、このディレクトリの**直下**にある `*.yml`・`*.yaml` の通常ファイルを、同じ名前と内容で
  公開用リポジトリの `.github/workflows/` に置く。直下の通常ファイル `actions.lock` も同じ名前・内容で置く。
  サブディレクトリの中、シンボリックリンク、他の lock ファイル、このファイルのような説明の文書は置かない
- 置くのはコミット済みの内容（`HEAD`）。作業ツリーの未コミットの変更は使わない（`publish.sh` は未コミットの変更があると止まる）
- このディレクトリは `scripts/dev/` の中なので、ディレクトリそのものは書き出されない
- ここに置いた workflow は、開発用リポジトリでは動かない（GitHub Actions は `.github/workflows/` の直下だけを読む）。
  動作の確認は、公開用リポジトリで行う
- 公開用リポジトリの `.github/workflows/` を直接編集しない。次の書き出しで、このディレクトリの内容に置き換わる
- 開発用リポジトリだけで動かす workflow（`macos-swift-ci.yml` など）は、ここではなく `.github/workflows/` に置く。書き出しには含まれない

workflow の依存を変えたら、リポジトリのルートで `python3 scripts/dev/actions-lock.py` と
`python3 scripts/dev/actions-lock.py --verify` を実行し、workflow と `actions.lock` を一緒にレビューする。
生成・更新・検証とポリシーの手順は [actions-lock.md](../../../docs_private/actions-lock.md) を参照する。
このディレクトリを直接指定して生成せず、公開先の `.github/workflows/` のパスを記録するラッパーを使う。

## 配布 workflow

`release.yml` は公開用 main の push と手動実行で動き、公開済み SHA から arm64 の ZIP と SHA256SUMS を作って
ドラフトへ添付する。開発用の Release candidate / Publish release source は `.github/workflows/` 側に置く。
通常は release.json 変更 PR とローカル確認を起点に公開用へ同期する。
初回 App / base、候補の再確認と復旧の手順は上記の運用文書を参照する。
