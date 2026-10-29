# Quickstart: 配布の検証

実装に合わせ、具体的なコマンド、期待結果、失敗からの復旧を T008 で追記する。

1. 一時 Git リポジトリとスタブで正常系・対象コミット不一致・タグ不一致・既存 Release・成果物改変・コマンド失敗を検証する。実際の Release は作らない。
2. `swift build`、`swift test`、`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/check-english-comments.sh` を順に実行する。
3. `scripts/make-app.sh` の後、ユーザーが `open .build/Folzio.app` で起動し、3ペインを確認する。
4. 配布 ZIP を展開し、ユーザーが Apple silicon Mac でアプリを起動して3ペインと日英表示を確認する。Gatekeeper の実際の挙動はダウンロードした隔離属性付き成果物で確認し、未実施なら未実施と記録する。
