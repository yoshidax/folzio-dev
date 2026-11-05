# 検証: TAK-78

1. 差分と `scripts/dev/publish.sh` の順序、`docs_private/repository-and-release.md` および製品仕様との一致を確認する。
2. Cloud では `scripts/dev/check-all.sh` を実行する（仕様 ID の検査を含む）。環境で実行できない項目は理由とともに記録する。
3. rsync がある環境で `python3 -m unittest scripts.dev.tests.test_publish_folzio -v` を実行する。テストは一時リポジトリを使う。成功時のコマンド順、通常テストと性能テストそれぞれの失敗による後続停止、ステージング未実行を確認する。
4. macOS で通常テスト `swift test --no-parallel --skip FolzioPerformanceTests` と性能テスト `swift test --filter FolzioPerformanceTests` を順に実行する。ログで Core と App のそれぞれに属するテストが 1 件以上実行され、性能テストも実行されることを確認する。実行環境と結果を記録する。
5. アプリ起動確認が必要な場合は保守者が行い、未実施ならその旨を記録する。実際の公開先に向けて `publish.sh` を実行しない。
6. 製品仕様の反映差分を保守者に提示して承認を得る。完了時の凍結注記はタスクの記録を済ませ、確認・承認を得た後の最後の編集とする。
