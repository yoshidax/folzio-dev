# 調査: 公開検査

## 実行方法

`.github/workflows/macos-swift-ci.yml` は通常テストを `--no-parallel --skip FolzioPerformanceTests`、性能テストを別コマンドで実行する。公開スクリプトも同じ順序とし、性能テストと他のテストが同時に動いて Core の待機を阻害することを避ける。通常テストでは App を個別のフィルターで指定せず、性能を除くテストを実行する。実際に Core と App が選択されるかは macOS のログで確認する。

## 異常終了

`scripts/dev/publish.sh` は `set -euo pipefail` を使用し、`rsync` 後にビルド・テスト・ネットワーク検査・`git add -A` を行う。テストの失敗は後続の処理を止めるが、同期後の公開先を元に戻さない。仕様と手順にこの順序を明記する。

## テスト

`scripts/dev/tests/test_publish_folzio.py` の `PublishFixture` は公開元と公開先を一時ディレクトリに作成し、Swift をスタブ化する。実行記録と終了コードを制御し、成功順序と通常・性能テスト失敗時の後続停止を確認する。スタブは実際のテストの選択や Swift の動作は保証しない。実環境の検証は macOS・rsync・Swift が必要。
