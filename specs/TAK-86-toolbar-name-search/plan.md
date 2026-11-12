# Implementation Plan: TAK-86 ツールバーの名前検索欄

**Branch**: `claude/peaceful-bell-dj1h3u` | **Date**: 2026-11-12 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-86-toolbar-name-search/spec.md`

## Summary

ツールバーに、検索フィールドを `view` に持つ項目 `search` を加える（R1）。既定の並びは Core の `ToolbarLayout` で「8つのセット → 可変スペース → 検索」にし、
ツールバーのデリゲートは既定と許可の一覧を `ToolbarLayout` から作る（R8）。保存済みの並びの読み込みの規則は変えない。
Return は検索フィールドのデリゲートで受け（R3）、`MainSplitViewController` の新しい入口が、検索のモーダルの既定の起点と同じ `model.listing.folder` を
既存の `SearchRoot.validate(_:)` で検証してから、既存の `model.startSearch(_:root:)` を呼ぶ（R5・R6）。検証に失敗したら、理由を表示した検索のモーダルを開く。
虫眼鏡の押下と、検索欄にフォーカスがある間の ⌘F は、検索欄の文字をキーワードとして検索のモーダルを開く（R2・R11）。
引き継ぐキーワードの決め方は Core の小さな型 `ToolbarSearchInput` に置く。×ボタンと Esc は標準の検索フィールドの動作のまま使う（R4）。
検索の処理（照合・列挙・結果の表示）と検索のモーダルの動作は変えない。

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: Foundation / AppKit。外部依存なし

**Storage**: 新しい設定キーは追加しない。既存の `view.toolbarItems` が取り得る識別子に `search` が加わる（contracts/toolbar-search-field.md）

**Testing**: Swift Testing（`Tests/FolzioCoreTests`）、macOS CI、保守者の GUI 確認（quickstart.md）

**Target Platform**: macOS 15 以降

**Project Type**: Swift Package のデスクトップアプリ

**Performance Goals**: Return から検索の開始までに UI スレッドでファイルシステムを読まない（起点の検証は既存の UI スレッドの外の処理）。
検索そのものの性能の基準（SC-016）を変えない

**Constraints**: 判断ロジックは FolzioCore（AppKit を import しない）、描画と入力は FolzioApp に置く（AGENTS.md）。
検索のモーダルの ⌘F からの動作を変えない（FR-386）。ネットワーク API を使わない。
AppKit UI の不変条件（制約は `addSubview` の後、異なる階層のアンカー同士を制約しない）を守る

**Scale/Scope**: ツールバーの項目 1 つ、Core の値型 1 つ、文言 3 つ（日英）、`SearchPanelController` の引数 1 つ

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判定 | 根拠 |
|---|---|---|
| I. ローカル完結・プライバシー | 適合 | ネットワークを使わない。検索欄の文字と検索条件は保存しない（EC-254） |
| II. 体感パフォーマンス | 適合 | 起点の検証と検索は既存の UI スレッドの外の処理を使う。入力のたびには検索しない（A-226） |
| III. キーボードファースト & アクセシビリティ | 適合 | キーボードだけの検索は従来の ⌘F で行える（A-228）。検索欄はアクセシビリティのラベルを持ち、虫眼鏡は説明を持つ（FR-389） |
| IV. テスト必須 | 適合 | 並びの既定値・保存値の扱い・引き継ぐキーワードの決め方を Core に置いてテストし、文言を翻訳の検査に加える。画面は GUI 確認で確かめる（R12） |
| V. シンプルさ | 適合 | 検索の処理とモーダルを再利用し、新しい型は値型 1 つとフィールドのサブクラス 1 つ。起点はモーダルの既定と同じ式を使う（R5） |

設計の後の再確認: 違反なし。Complexity Tracking は不要。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-86-toolbar-name-search/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── toolbar-search-field.md
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks で作る
```

### Source Code (repository root)

```text
Sources/FolzioCore/Settings/
└── ToolbarLayout.swift                 # setIdentifiers に search を追加。defaultOrder を「…→ 可変スペース → search」に（R8）

Sources/FolzioCore/Search/
└── ToolbarSearchInput.swift            # 追加。モーダルへ引き継ぐキーワードの決め方（FR-386）

Sources/FolzioApp/Search/
├── ToolbarSearchField.swift            # 追加。NSSearchField のサブクラス。虫眼鏡のツールチップ、⌘F の受け渡し（R2・R11）
└── SearchPanelController.swift         # 初期の理由（SearchRootError?）を受ける引数を追加（R6）

Sources/FolzioApp/App/
├── MainSplitViewController.swift       # 検索欄からの検索の入口と、キーワードを引き継いでモーダルを開く入口を追加（R5・R6）
└── MainToolbarController.swift         # search の項目の生成・状態・文言・あふれたメニュー。既定と許可の一覧を ToolbarLayout から作る（R1・R7・R8・R10）

Sources/FolzioApp/Shortcuts/
└── ToolbarShortcutText.swift           # toolbarSearchFindHelp に .find を対応させる（R9）

Sources/FolzioLocalization/
├── TextKey.swift                       # toolbarSearchLabel・toolbarSearchPlaceholder・toolbarSearchFindHelp を追加（R9）
└── Resources/{ja,en}.lproj/Localizable.strings

docs/
├── usage.md・usage.ja.md              # 「ツールバー」と「名前の検索」に検索欄を加える
└── development.md・development.ja.md  # 手動の確認に検索欄を加える

Tests/FolzioCoreTests/
├── ToolbarLayoutTests.swift            # 既定の並びと、search を含む・含まない保存値（R8）
├── ToolbarSearchInputTests.swift       # 追加。引き継ぐキーワード（FR-386）
└── Localization/ShortcutSettingsTextTests.swift   # 新しい文言（R9）
```

**Structure Decision**: 既存の Swift Package の構成のまま。Core の判断は `Sources/FolzioCore/Settings/` と `Sources/FolzioCore/Search/` に、
AppKit の適用は `Sources/FolzioApp/App/` と `Sources/FolzioApp/Search/` に置く。

## Complexity Tracking

なし。
