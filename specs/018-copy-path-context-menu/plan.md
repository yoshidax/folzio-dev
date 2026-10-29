# Implementation Plan: パス名のコピー

**Branch**: `018-copy-path-context-menu` | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/018-copy-path-context-menu/spec.md`

## Summary

ツリーとファイルリストの右クリックメニューに「パス名をコピー」を加え、単数の実在項目の絶対パスを文字列でクリップボードへ置く
（FR-181・182）。キーボード手段として「編集 > パス名をコピー」（⌥⌘C）を加える（FR-184）。有効・無効の判定とコピー対象の決定は
`FolzioCore` の純粋なロジックに置き（既存の `ListItemCommands` と `FavoriteCommands` を拡張）、`FolzioApp` は
メニュー項目の追加と `NSPasteboard` への書き込みだけを行う。ネットワーク・設定・永続化は追加しない。

## Technical Context

**Language/Version**: Swift 6（Swift Package）

**Primary Dependencies**: AppKit のみ（外部パッケージなし）。`NSPasteboard` を使う

**Storage**: N/A（保存する設定なし）

**Testing**: Swift Testing（`Tests/FolzioCoreTests`）。AppKit 部分は手動確認（GUI）

**Target Platform**: macOS 15 以降

**Project Type**: desktop-app（`FolzioCore` + `FolzioApp` + `FolzioLocalization`）

**Performance Goals**: 該当なし（文字列を1回書くだけ。UI スレッドで I/O をしない）

**Constraints**: ファイルシステムを読まない・変更しない。ネットワーク API を使わない。翻訳キーは ja/en の両方に追加する（FR-146・157）

**Scale/Scope**: メニュー項目2か所（ファイルリスト・ツリー）+ 編集メニュー1項目 + 翻訳キー1つ

## Constitution Check

| 原則 | 判定 | 根拠 |
|---|---|---|
| I. ローカル完結・プライバシー | 適合 | クリップボードへの書き込みだけ。外部送信なし。ファイルを変更しない |
| II. 体感パフォーマンス | 適合 | 文字列の書き込みのみ。デコード・列挙をしない |
| III. キーボード＆アクセシビリティ | 適合 | ⌥⌘C と「編集」メニュー項目を同時に追加。メニュー項目は標準のラベルを持つ |
| IV. テスト必須 | 適合 | Core の判定（複数選択・`..`・zip 内・見出し・見つからない項目）に単体テストを付ける |
| V. シンプルさ | 適合 | 設定・抽象化を足さない。既存の判定型を拡張する |

設計後の再確認: 違反なし（Complexity Tracking は不要）。

## Project Structure

### Documentation (this feature)

```text
specs/018-copy-path-context-menu/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── menus.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks で作成
```

### Source Code (repository root)

```text
Sources/
├── FolzioCore/Model/
│   ├── ListItemCommands.swift        # allowsCopyPathname(selectionCount:) を追加
│   └── FavoriteCommands.swift        # pathnameTarget(_:) を追加、contextMenu に copyPathname を追加
├── FolzioLocalization/
│   ├── TextKey.swift                 # menuEditCopyPathname を追加
│   └── Resources/{ja,en}.lproj/Localizable.strings
└── FolzioApp/
    ├── App/MainMenu.swift            # 編集 > パス名をコピー（⌥⌘C）
    ├── FileList/FileContextMenu.swift, FileListViewController.swift
    └── Tree/DirectoryTreeViewController.swift
Tests/FolzioCoreTests/
├── ListItemCommandsTests.swift       # 追加
└── FavoriteCommandsTests.swift       # 追加
```

**Structure Decision**: 既存の Core/App 分離に従う。判断ロジックは Core、`NSPasteboard` 書き込みとメニューは App。

## Complexity Tracking

違反なし。
