# Verification quickstart

開発用リポジトリで実施する。公開先への同期や master へのマージは行わない。

1. `python3 -m unittest discover -s scripts/dev/tests -v` で一時環境の公開、配布、移行、Codex workflow のテストを実行する。開発用ディレクトリの除外と混入時の同期前停止が含まれる。
2. `swift build`、`swift test`、`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh` を順に実行する。
3. `scripts/make-app.sh` で `.build/Folzio.app` を作成する。ユーザーが `open .build/Folzio.app` を実行し、3ペインの表示を報告する。
4. 移動した参照を検索し、現行の呼び出しに旧開発用パスがなく、公開 archive のファイルが開発専用パスに依存しないことを確かめる。凍結した履歴は対象外。
