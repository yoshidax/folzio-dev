# Implementation Plan: 関連アプリケーションで開く

**Branch**: `feature/tak-97-open-with-app` | **Date**: 2026-11-11 | **Spec**: [spec.md](spec.md)

**Input**: TAK-97 と現行の file-list.md、contracts/keyboard-and-menus.md

## Summary

ファイルリストの右クリックと「ファイル」メニューに「このアプリケーションで開く」のサブメニューを追加する。OS の関連アプリ列挙結果を表示し、選んだアプリに明示的にファイルを渡す。1件の通常ファイルまたは zip ファイルだけを対象とする。

## Technical Context

**Language/Version**: Swift 6（CI は Xcode 16.0）

**Primary Dependencies**: AppKit、FolzioCore、FolzioLocalization。追加依存なし

**Storage**: なし。OS の既定アプリ設定を変更しない

**Testing**: FolzioCore の XCTest、macOS CI の build/test、保守者の GUI 起動確認

**Target Platform**: macOS 15 以降の既存ターゲット

**Project Type**: デスクトップアプリ

**Performance Goals**: 10,000 件の一覧表示とメニュー表示を妨げない

**Constraints**: オフライン、選択の固定、zip 内を除外、ローカライズ

**Scale/Scope**: 一度に1ファイル。選択したファイルの候補だけを問い合わせる

## Constitution Check

| 原則 | 設計上の確認 |
|---|---|
| I ローカル完結 | OS のローカル関連付けのみを問い合わせ、ネットワークや保存を追加しない。 |
| II 体感パフォーマンス | 候補列挙を一覧の更新処理に入れず、必要なときに取得する。メニュー表示中の同期処理の所要時間を確認する。 |
| III キーボードとアクセシビリティ | 同じサブメニューをメニューバーの「ファイル」に置き、標準 NSMenuItem のラベルとキーボード操作を使う。 |
| IV テスト | 対象判定と候補表示の判断を UI から分け、無効条件と選択変更を検証する。 |
| V シンプルさ | OS 標準 API と既存メニューを使い、新しい設定や外部依存を追加しない。 |

**Post-design**: 上記を満たす。OS API の呼び出しスレッドと表示遅延は実装時に CI と GUI で確認する。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-97-open-with-app/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/menu.md
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/FolzioCore/Model/ListItemCommands.swift
Sources/FolzioApp/FileList/FileContextMenu.swift
Sources/FolzioApp/FileList/FileListViewController.swift
Sources/FolzioApp/App/MainMenu.swift
Sources/FolzioLocalization/TextKey.swift
Sources/FolzioLocalization/Resources/en.lproj/Localizable.strings
Sources/FolzioLocalization/Resources/ja.lproj/Localizable.strings
Tests/FolzioCoreTests/
```

**Structure Decision**: 対象可否は FolzioCore、OS 問い合わせとメニュー・起動は FolzioApp、文言は FolzioLocalization に置く。

## Complexity Tracking

違反なし。
