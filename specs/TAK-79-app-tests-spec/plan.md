# 実装計画: 製品仕様の App テストターゲット

**Branch**: `feature/tak-79-app-tests-spec` | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

## 概要

`Package.swift` と開発ガイドに存在する `FolzioAppTests` を `specs/product/contracts/app-bundle.md` の一覧に加える。既存の `FolzioCore`・`FolzioLocalization`・`FolzioApp`・`FolzioCoreTests`・`FolzioPerformanceTests`、`FixtureKit` と補助ツールに関する記述は維持する。

## 変更案

契約冒頭のターゲット一覧を次に変更する。

> 製品とSwift Packageの名称は `Folzio`。ターゲットは `FolzioCore`、`FolzioLocalization`、`FolzioApp`、`FolzioCoreTests`、`FolzioAppTests`、`FolzioPerformanceTests` とし、`FixtureKit` と既存の補助ツールの名称は維持する（FR-166・168）。

改行以外の既存の表記も維持し、対象名の追加を最小限にする。`Package.swift` と開発ガイドは変更しない。FR-166・FR-168 は名称と開発に関する既存要件であり本文変更や新しい ID は不要。

## 憲章チェック

- 原則 I〜III: 製品の処理、通信、性能や操作を変更しない。
- 原則 IV: 製品コードを変更せず、契約と現行実装の目視照合、仕様の形式・ID 検査を行う。
- 原則 V: 依存や設定を追加しない。
- 製品仕様に反映する前に最新の `master` と ID を確認し、反映差分の承認を得てからコミットする。終了時は承認を得て feature 記録に凍結注記を付ける。

## 成果物

- [research.md](research.md): 実装と既存契約の照合。
- [quickstart.md](quickstart.md): 検証手順。
- [tasks.md](tasks.md): 作業、検証とレビューの順序。
- データモデル・新しい外部契約はない。既存の横断契約を変更する。
