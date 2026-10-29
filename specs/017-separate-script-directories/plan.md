# Implementation Plan: 公開用と開発用スクリプトの分離

**Branch**: `017-separate-script-directories` | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)

## Summary

公開用は従来どおり `scripts/` 直下に置き、開発専用の実行物・補助データ・テストを `scripts/dev/` に集約する。ディレクトリ全体を export-ignore とし、公開前の混入検査も同じ境界を確認する。移動に伴うルート導出と現行の参照を更新し、一時リポジトリによる正負両方の書き出しテストで守る。

## Technical Context

**Language/Version**: Bash、Python 3、Swift 6
**Primary Dependencies**: Git、標準ツール、既存の Swift Package。外部パッケージ追加なし
**Storage**: リポジトリと一時ディレクトリ
**Testing**: Python unittest、Swift Testing、既存検査、ユーザーによる GUI 起動
**Target Platform**: macOS 15 以降
**Project Type**: macOS アプリと開発・公開ツール
**Performance Goals**: アプリ性能の変更なし
**Constraints**: 開発用 master へのマージ・push・実際の公開は行わない。ネットワーク API を追加しない
**Scale/Scope**: scripts の全ファイルと、現行の呼び出し元・運用案内

## Constitution Check

- I: アプリに通信を追加しない。公開作業の挙動は維持する。
- II: アプリの実行経路は変更しない。既存性能テストを実行する。
- III: UI とキーボード操作は変更しない。起動を目視確認する。
- IV: 正負の公開検査の回帰テストと既存の自動検証を行う。
- V: Swift の責務と依存を変更しない。
- 仕様の管理: feature を先に作成し、検証後に living spec を承認付きで反映する。

設計後も上記を満たす。違反なし。

## Project Structure

```text
scripts/                 # 公開用の既存スクリプトとパスを維持
scripts/dev/             # 開発専用スクリプト、schema、tests、spec-restructure
.gitattributes           # scripts/dev/ を一括除外
.specify/workflow-src/   # 現行 workflow の呼び出し
.specify/workflows/      # インストール済み workflow の整合
AGENTS.md, docs_private/ # 現行の開発・公開手順
```

**Structure Decision**: 開発専用は `check-english-comments.sh`、`publish.sh`、`release-distribution.sh`、`migrate-folzio-settings.sh`、`merge-to-master.sh`、`sdd-*`、`tests/`、`spec-restructure/` とする。既に公開されるその他のスクリプト（README 同期・アーカイブ検査を含む）は公開用として維持する。スクリプト内のリポジトリルートやテストフィクスチャの深さを修正する。

## Verification and impact

`git archive` の実際の属性を使った一時リポジトリテストで未知・入れ子を含む除外と公開ファイルの保持を確認し、属性を意図的に外したケースで同期前停止と対象保護を確認する。既存 Python テスト、ワークフローの参照や schema、実行可能属性、公開版が開発専用パスを参照しないことを検証する。`scripts/publish.sh` は実際の公開先には実行しない。旧パスの互換ラッパーは作らない。凍結済み記録は変更しない。

## Complexity Tracking

違反なし。
