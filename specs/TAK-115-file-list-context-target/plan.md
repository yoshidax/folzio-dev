# Implementation Plan: ファイルリストの右クリックの対象を Finder に合わせる

**Branch**: `feature/tak-115-file-list-context-target` | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

**Input**: [TAK-115](https://linear.app/takyoshida/issue/TAK-115/) と現行の file-list.md・file-operations.md・directory-tree.md

## Summary

ファイルリストで選択していない項目を右クリックしたら、メニューを出す前にその項目だけを選択する。
選択中の項目の右クリックと背景の右クリックでは選択を変えない。新しい選択の決め方は `FolzioCore` の
`ContextClickSelection` に置き、リスト形式とサムネイル形式の `menu(for:)` から使う。
選択の変更は既存の経路を通し、プレビューの切り替えと動画の停止をクリックで選んだときと同じにする。
メニューの各操作は従来どおり選択を対象にするため、変更しない。

## Technical Context

**Language/Version**: Swift 6（CI は Xcode 16.0）

**Primary Dependencies**: AppKit、FolzioCore。追加依存なし

**Storage**: なし

**Testing**: Swift Testing（FolzioCoreTests の `ContextClickSelectionTests`、FolzioAppTests のリスト形式・サムネイル形式の
右クリックの選択のテスト）、保守者の GUI 起動確認

**Target Platform**: macOS 15 以降の既存ターゲット

**Project Type**: デスクトップアプリ

**Performance Goals**: 変更なし（右クリック時に選択を1回変えるだけ）

**Constraints**: オフライン。判断ロジックは AppKit を import しない `FolzioCore` に置く

**Scale/Scope**: 一覧のビュー2種（リスト形式・サムネイル形式）

## Constitution Check

| 原則 | 設計上の確認 |
|---|---|
| I ローカル完結 | 外部通信を追加しない。右クリックした項目と違うものを操作する誤操作を防ぐ。 |
| II 体感パフォーマンス | 右クリック時の選択の変更は、クリックで選ぶときと同じ処理で、UI スレッドに重い処理を足さない。 |
| III キーボードとアクセシビリティ | キーボードの操作とフォーカスは変えない（A-238）。 |
| IV テスト | 選択の決め方を `FolzioCore` に置いて単体テストで全分岐を確かめ、2つのビューの結線を App のテストで確かめる。 |
| V シンプルさ | メニューの操作には手を入れず、選択を変えるだけにする。 |

**Post-design**: 上記を満たす。Complexity Tracking に記録する違反はない。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-115-file-list-context-target/
├── spec.md
├── plan.md
├── research.md
├── quickstart.md
├── checklists/requirements.md
└── tasks.md
```

データモデルと契約（設定のキー・文言・ショートカット）の変更はないため、data-model.md と contracts/ は作らない。

### Source Code (repository root)

```text
Sources/FolzioCore/
└── Model/ContextClickSelection.swift       # 新規。右クリックした項目と今の選択から新しい選択を決める
Sources/FolzioApp/FileList/
├── ListModeView.swift                      # FileListTableView.menu(for:) で選択を変える。名前の編集を終える
└── ThumbnailModeView.swift                 # ThumbnailCollectionView.menu(for:) で選択を変える。起点と編集の終了
Tests/FolzioCoreTests/
└── ContextClickSelectionTests.swift        # 新規
Tests/FolzioAppTests/
└── FileListContextClickTests.swift         # 新規。2つの形式で選択・プレビュー・複数選択の保持を確かめる
docs/usage.md・docs/usage.ja.md              # 右クリックの対象の説明（該当する記述があれば）
```

**Structure Decision**: 既存の配置に従う。判断（新しい選択）は `FolzioCore`、イベントの受け取りと選択の適用は
`FolzioApp` の一覧のビューに置く。

## Complexity Tracking

なし。
