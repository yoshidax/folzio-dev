# Quickstart: 配布の検証

1. `python3 -m unittest scripts.tests.test_release_distribution -v` で一時 Git リポジトリとスタブを使い正常系、対象・タグ不一致、成果物改変とコマンド失敗を確認する。実際の Release は作らない。
2. 順に `swift build`、`swift test`、`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/check-english-comments.sh`、`scripts/make-app.sh` を実行し、すべて成功することを確認する。
3. ユーザーが `open .build/Folzio.app` で起動し、フォルダツリー・ファイル一覧・プレビューの3ペインが表示されることを確認する。
4. テスト用 ZIP `.build/release-validation/Folzio-v1.2.3-macos-arm64.zip` を展開し、ユーザーが Apple silicon Mac で起動して3ペインと設定による日英表示を確認する。Gatekeeper の実際の挙動はダウンロードした隔離属性付き成果物で確認し、未実施なら未実施と記録する。
5. 実際の公開時は `docs_private/repository-and-release.md` の手順でユーザーが公開用コミット・タグを push した後に `prepare`・`draft` を行い、ドラフトを確認して公開する。検証のために本番 Release を作らない。
