# 実装計画: 公開書き出しでの App テスト

**Branch**: `feature/tak-78-publish-app-tests` | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

## 概要

CI と同じ `swift test --no-parallel --skip FolzioPerformanceTests` で Core・App を含む通常テストを実行し、その後 `swift test --filter FolzioPerformanceTests` を実行する。いずれかの失敗時は既存の `set -e` で後続のネットワーク検査・ステージングを中止する。正常時の公開のほか、各検査の失敗を隔離されたフィクスチャで確認する。

## 技術的な背景

- 対象: `scripts/dev/publish.sh`、`scripts/dev/tests/test_publish_folzio.py`、`docs_private/repository-and-release.md`。
- 製品仕様: `specs/product/overview.md` に FR-311・FR-312 を追加し、`specs/product/README.md` の件数と `specs/product/contracts/scripts.md` を追従させる。反映内容はコミット前に保守者へ提示する。
- Swift・AppKit の検証は macOS、公開回帰テストは rsync を要する。Cloud には Swift と rsync がない。
- 公開先への同期はビルド・テストより前。テストの失敗は同期済みファイルの取り消しを意味しない。実際の公開先で検証しない。
- 通常テストが Core と App の両方を実行することは macOS の実行ログで各対象に属するテストが 1 件以上実行されたことを確認する。フィクスチャでは Swift を模擬するため、この選択の確認を代替できない。

## 憲章チェック

- 原則 I: 外部通信やユーザーファイル操作を追加しない。既存のネットワーク検査を維持する。
- 原則 II・III: アプリの処理、性能、操作やアクセシビリティを変更しない。性能テストと通常テストは分離する。
- 原則 IV: 公開処理の正常・異常系を自動テストし、macOS で実際の対象テストの実行も確認する。
- 原則 V: 新しい外部依存や設定を追加しない。既存の CI とフィクスチャを利用する。
- 製品仕様と実装・公開手順を同じ feature で追従させる。ID は製品仕様の最大値を反映直前に再確認する。
- 孤立した一時リポジトリで回帰検証し、実際の公開先を変更しない。
- GUI 確認や macOS 検証は実施結果を記録し、未確認の場合は完了扱いにしない。凍結注記は対象確認と承認後、feature 記録の最後の編集とする。

## 設計と成果物

- [research.md](research.md): 検査順と既存実装の根拠。
- [quickstart.md](quickstart.md): 検証手順と実施環境。
- [tasks.md](tasks.md): 実装・検証・製品仕様反映・レビューの順序。
- 状態モデルや外部 API の追加はない。公開スクリプトの契約は製品仕様の既存契約に追加する。
