# Implementation Plan: Folzioへの改名

**Branch**: `015-rename-to-folzio` | **Date**: 2026-10-29 | **Spec**: [spec.md](spec.md)

## Summary

表示、アプリバンドル、Swift Package、ソースとテスト、運用・公開手順を Folzio に統一する。既存設定はユーザーが明示的に実行する一度きりのローカル移行で保存し、新旧ドメインの衝突を防ぐ。最終的なディレクトリ移動はレビュー済み仕様の反映後にユーザーが行い、新パスで再検証する。

## Technical Context

**Language/Version**: Swift 6、Shell、既存の Python 3 ツール
**Primary Dependencies**: AppKit、Foundation、Swift Package Manager。外部パッケージ追加なし
**Storage**: UserDefaults の独立したアプリ／開発実行ドメイン、Gitリポジトリ、IDEローカル設定
**Testing**: Swift Testing、既存Pythonテスト、シェル検証、ユーザーによるGUI確認
**Target Platform**: macOS 15以降
**Project Type**: ローカル動作のデスクトップアプリ
**Performance Goals**: 既存の性能基準を維持する
**Constraints**: ネットワークAPI不使用、CoreはAppKit非依存、GUI起動はユーザー、凍結した記録を変更しない
**Scale/Scope**: 1アプリ、2つの設定ドメイン、開発用・公開用2ディレクトリ

## Constitution Check

- I: 通信・テレメトリを追加しない。旧設定と未追跡ファイルを保護し、画像ファイルを移動・変更しない。
- II: 重い処理や画像処理の実行経路を変更せず、既存の性能テストを実行する。
- III: 既存操作・ショートカット・アクセシビリティを保持する。
- IV: 全自動テストと異常系を実行し、設定移行の衝突・不存在・失敗を分離されたテストデータで検証する。
- V: 外部依存・アプリ内の恒久的な旧ドメイン移行を追加しない。ローカル一回限りの移行支援は要件 FR-167 の範囲。
- 仕様管理: 新featureで変更を追跡し、検証後に product spec を反映する。既存の凍結済みfeatureは編集しない。

設計後の再確認: すべて適合。追加の憲章改定は不要。

## Project Structure

```text
Package.swift
Sources/FolzioCore/                # 旧 MediaViewerCore
Sources/FolzioLocalization/        # 旧 MediaViewerLocalization
Sources/FolzioApp/                 # 旧 MediaViewerApp
Sources/FixtureKit/
Tests/FolzioCoreTests/             # 旧 MediaViewerCoreTests
Tests/FolzioPerformanceTests/      # 旧 MediaViewerPerformanceTests
scripts/                           # build, publish, verification and private migration helper
docs/                              # public English/Japanese guides
docs_private/                      # private migration and relocation instructions
specs/015-rename-to-folzio/       # feature artifacts
```

**Structure Decision**: 既存の Swift Package と Core / AppKit 境界を保ち、対象の名前と参照を同時に変更する。Git管理外の `.code-workspace` はローカルで個別に更新する。

## Implementation Order

1. Package・モジュール・リソース・アプリバンドルを一体で改名し、旧名称に依存するテストやスクリプトを追従させる。
2. 設定移行の実行前検査、バックアップ、衝突防止、テストを実装する。[data-model.md](data-model.md) と [移行契約](contracts/migration.md) を正とする。
3. README双方・利用／開発ガイド双方・非公開運用資料・SDDワークフローを更新する。公開除外と公開先の `.vscode/` の保護を検証する。
4. 規定の自動ゲートと生成アプリの契約検査を順に実施し、ユーザーによるGUI確認を受ける。Phaseコミット後、convergeを実施する。
5. 検証済みの変更を `specs/product/` に反映し、レビューを受けてfeatureを凍結・コミットする。
6. feature外の運用引き継ぎとして、ユーザーが実際の2ディレクトリを移動し、IDEを開き直して新パスで検証する。[quickstart.md](quickstart.md) に手順と結果記録先を定義する。移動前に一時ディレクトリ内でパス非依存のリハーサルを行う。

## Complexity Tracking

憲章違反なし。
