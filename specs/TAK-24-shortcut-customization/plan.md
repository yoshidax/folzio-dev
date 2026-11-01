# Implementation Plan: 設定画面でのショートカットキー割り当ての変更

**Branch**: `claude/modest-edison-e1itmi` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-24-shortcut-customization/spec.md` / [TAK-24](https://linear.app/takyoshida/issue/TAK-24)

## Summary

メニュー項目のキー割り当てを、Core の「割り当ての表」（既定値 + 利用者の上書き）を唯一の元にして管理する。Core にコマンド一覧（ID・既定値・区分）、
キーの組み合わせの型、検証（修飾キー・予約キー・固定キー・重複）、`UserDefaults` への保存と読み込みを置き、AppKit に依存しない。
App 側は、割り当ての変更通知を受けて、メインメニュー・コンテキストメニュー・ツールバーのツールチップ・ショートカット一覧ウインドウを同じ値から更新する。
設定ウインドウは `NSTabView` で「一般」「ショートカット」の 2 タブにし、「ショートカット」にコマンド行（名前・現在のキー・記録・既定値に戻す）をスクロール可能に並べる。
記録は、記録中の行だけが `performKeyEquivalent` でキーを横取りして候補にする。メニューのキー等価より先にウインドウのビューが受けるため、既存の操作は実行されない。

本資料は設計レビュー用。承認の前に実装しない（`docs_private/cloud-agent-workflow.md`）。

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: Foundation、AppKit、既存の FolzioCore / FolzioLocalization。外部依存なし

**Storage**: `UserDefaults` に 1 キー `shortcuts.overrides`（[String: String]）を追加。他のキーは変えない（contracts/shortcut-settings.md §5）

**Testing**: Swift Testing。Core の純粋ロジック（組み合わせの解釈・表記・検証・保存・既定値との整合）は `Tests/FolzioCoreTests/Shortcuts/` で自動テストする。
翻訳は既存の `CatalogConsistencyTests` と新しい `ShortcutSettingsTextTests` で検査する。AppKit の動作（記録・メニュー反映・タブ・Tab 順・VoiceOver）は quickstart.md で保守者が GUI 確認する（憲章 原則 IV）

**Target Platform**: macOS 15 以降。Cloud（Linux）では `swift` と GUI を実行しない。ビルドとテストは CI、GUI は保守者

**Project Type**: Swift Package のデスクトップアプリ（FolzioCore / FolzioLocalization / FolzioApp）

**Performance Goals**: 割り当ての反映はメインメニューの項目数（約 40）の走査だけで、UI スレッドで重い処理はない。起動時に 1 回読み込む

**Constraints**: Core は AppKit を import しない（修飾キーは Core 独自の `OptionSet`）。ウインドウ・ビューの操作は MainActor。制約は `addSubview` の後に有効化。
`NSSplitViewDelegate` の禁止メソッドは触らない。ネットワーク API なし

**Scale/Scope**: コマンド 32 個（contracts §1）。Core 新規 4 ファイル程度、App は設定ウインドウの分割と、メニューを組み立てる 4 か所の差し替え

## Constitution Check

| 原則 | Phase 0 前 / Phase 1 後の判断 |
|---|---|
| I ローカル完結 | PASS / PASS。通信なし。保存はアプリの `UserDefaults` のみ |
| II 体感性能 | PASS / PASS。UI スレッドの重い処理なし。起動時の読み込みは辞書 1 つ |
| III キーボード・アクセシビリティ | PASS / PASS。コマンドは常に 1 つのキーを持ち（FR-240）、記録 UI は Tab / Space で操作でき、状態を読み上げる（FR-242）。「すべて既定値に戻す」で全操作が既定のキーに戻る |
| IV テスト必須 | PASS / PASS。検証・保存・整合は Core で自動テスト。異常系（不正な保存値、重複、予約キー）を含める。GUI は quickstart.md の手順で保守者が確認し、確認前は完了にしない |
| V YAGNI | PASS / PASS。エクスポート、プロファイル、複数キー、グローバルショートカットは作らない（A-151）。「なし」の割り当ても作らない。汎用の設定フレームワークは作らず、割り当ての表 1 つに集約する |
| 仕様管理 | PASS / PASS。新しい feature ディレクトリだけを作る。`specs/product/` への反映は実装・検証の後、PR の最後に行う。ID は product と他の feature の最大値 FR-232 / SC-116 / EC-163 / A-143 / US43 の次から採った |

Complexity Tracking: 追加の複雑さはない。ただし「メニュー項目を組み立てる 4 か所とコンテキストメニューが、キーを直書きしている」点は、
個別に直すと割り当ての元が分散して FR-238 を満たせないため、割り当ての表から読む 1 つの経路に置き換える（research.md R2）。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-24-shortcut-customization/
├── spec.md
├── plan.md                         # この文書
├── research.md                     # R1〜R9
├── data-model.md                   # コマンド・組み合わせ・割り当ての表・保存形式
├── contracts/shortcut-settings.md  # 対象コマンド・固定キー・予約キー・設定ウインドウ・保存の契約
├── quickstart.md                   # 自動検証と GUI 確認の手順
├── checklists/requirements.md
└── tasks.md                        # /speckit-tasks の出力
```

### Source Code (repository root)

```text
Sources/FolzioCore/Shortcuts/
├── ShortcutCatalog.swift           # 変更: 掲載項目のキーをコマンドから生成（ShortcutEntry に commands を持たせる）
├── ShortcutCommand.swift           # 新規: コマンド ID・既定の組み合わせ・区分・対象/固定の一覧
├── KeyCombination.swift            # 新規: 文字 + 修飾キーの値型。解釈・表記・比較・保存の文字列
└── ShortcutAssignments.swift       # 新規: 既定値 + 上書き。検証、設定・取消、読み込み、変更の通知用の値

Sources/FolzioCore/Settings/SettingsStore.swift   # 変更: shortcuts.overrides の読み書き

Sources/FolzioLocalization/
├── TextKey.swift                   # 変更: タブ名・列・ボタン・案内・エラーの翻訳キー
├── ShortcutText.swift              # 変更: コマンド名はメニューの既存のキーを使う
└── Resources/{en,ja}.lproj/Localizable.strings       # 変更: 同上。ツールチップのキー表記を引数化

Sources/FolzioApp/
├── Shortcuts/
│   ├── ShortcutAssignmentStore.swift   # 新規: 現在の割り当ての保持・保存・変更通知（MainActor）
│   ├── MenuShortcutApplier.swift       # 新規: メニューとコンテキストメニューの項目へキーを適用
│   ├── ShortcutRecorderRow.swift       # 新規: 設定の 1 行（名前・キー・記録・既定値に戻す・エラー）
│   └── ShortcutCheatSheetWindowController.swift 他   # 変更: 表示を割り当ての表から生成
├── Settings/
│   ├── SettingsWindowController.swift  # 変更: NSTabView 化。一般タブは現行の内容を移す
│   └── ShortcutSettingsViewController.swift   # 新規: 「ショートカット」タブ
├── App/MainMenu.swift                  # 変更: キーを割り当ての表から取得
├── App/MainToolbarController.swift     # 変更: ツールチップのキー表記を割り当てから生成
├── FileList/FileListViewController.swift, FileContextMenu.swift
├── App/MainSplitViewController.swift, Tree/DirectoryTreeViewController.swift   # 変更: 同上（キー直書きを置き換え）

Tests/FolzioCoreTests/Shortcuts/
├── KeyCombinationTests.swift
├── ShortcutAssignmentsTests.swift
├── ShortcutCommandConsistencyTests.swift   # 既定値どうし・既定値と固定/予約キーの整合（FR-244）
└── ShortcutOverridesStoreTests.swift
Tests/FolzioCoreTests/Localization/ShortcutSettingsTextTests.swift
```

**Structure Decision**: 判断ロジック（解釈・検証・保存）は Core、描画と入力（記録ビュー、メニューへの適用、タブ）は FolzioApp に置く（AGENTS.md）。
メニュー項目は、`MainMenu.bind` が文言のために付けている識別子と同じ仕組みで、コマンド ID を `NSMenuItem` に結び付け、適用側が ID から引く（R2）。
