# Implementation Plan: ファイルリストの右クリックの対象をツリーに合わせる

**Branch**: `feature/tak-115-file-list-context-target` | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

**Input**: [TAK-115](https://linear.app/takyoshida/issue/TAK-115/) と現行の file-list.md・file-operations.md・directory-tree.md

## Summary

ファイルリストで選択していない項目を右クリックしたら、選択を変えずに、その項目だけを右クリックメニューの操作の対象にする。
メニューの対象（背景・選択中の全体・その項目だけ）の決め方は `FolzioCore` の `ContextMenuTarget` に置き、
メニューを開いたときに `FileListViewController` に記録する。各 action は、右クリックメニューから呼ばれたときだけ
記録した対象を使い、キーボードとメニューバーからは従来どおり選択を使う。
当初の「右クリックで選択を変える」実装（03fca52）は取り除く。

## Technical Context

**Language/Version**: Swift 6（CI は Xcode 16.0）

**Primary Dependencies**: AppKit、FolzioCore。追加依存なし

**Storage**: なし

**Testing**: Swift Testing（FolzioCoreTests の `ContextMenuTargetTests`、FolzioAppTests の右クリックメニューの対象のテスト）、
保守者の GUI 起動確認

**Target Platform**: macOS 15 以降の既存ターゲット

**Project Type**: デスクトップアプリ

**Performance Goals**: 変更なし（メニューを開くときに対象を1回決めるだけ）

**Constraints**: オフライン。判断ロジックは AppKit を import しない `FolzioCore` に置く

**Scale/Scope**: 一覧のビュー2種、右クリックメニューの対象の項目9つ（FR-397）

## Constitution Check

| 原則 | 設計上の確認 |
|---|---|
| I ローカル完結 | 外部通信を追加しない。右クリックした項目と違うものを操作する誤操作を防ぐ。 |
| II 体感パフォーマンス | メニューを開くときの処理は、対象を決めて記録するだけで、UI スレッドに重い処理を足さない。 |
| III キーボードとアクセシビリティ | キーボードの操作の対象とフォーカスは変えない（A-238・A-239）。 |
| IV テスト | 対象の決め方を `FolzioCore` に置いて単体テストで全分岐を確かめ、各 action の対象を App のテストで確かめる。 |
| V シンプルさ | 対象は1つの値（`OperationTarget`）にまとめ、各 action の対象の取り方を1か所に寄せる。 |

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
└── Model/ContextMenuTarget.swift           # 新規（ContextClickSelection を置き換える）。背景・選択全体・その項目
Sources/FolzioApp/FileList/
├── FileContextMenu.swift                   # メニューを開くときに対象を記録し、編集中の名前を確定する。文言を対象に合わせる
├── FileListViewController.swift            # OperationTarget と、sender による対象の切り替え（各 action と validateMenuItem）
├── ListModeView.swift                      # 選択の変更を取り除く。右クリックした行の位置。URL を指定した名前の編集
└── ThumbnailModeView.swift                 # 選択の変更を取り除く。右クリックした項目の位置と枠。URL を指定した名前の編集
Tests/FolzioCoreTests/
└── ContextMenuTargetTests.swift            # ContextClickSelectionTests を置き換える
Tests/FolzioAppTests/
└── FileListContextClickTests.swift         # 書き換え。選択を変えないこと、各 action の対象、メニューバーの対象
docs/usage.md・docs/usage.ja.md              # 右クリックの対象の説明を書き換える
```

**Structure Decision**: 既存の配置に従う。判断（対象の種類）は `FolzioCore`、対象の記録と action の切り替えは `FolzioApp` に置く。

## Complexity Tracking

なし。
