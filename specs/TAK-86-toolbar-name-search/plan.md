# Implementation Plan: TAK-86 ツールバーの検索欄による名前の絞り込み

**Branch**: `claude/peaceful-bell-dj1h3u` | **Date**: 2026-11-12 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-86-toolbar-name-search/spec.md`

## Summary

名前の絞り込みは、種類フィルタと同じく `BrowserModel` の状態として持ち、表示する行を作る `rebuildListing()` で適用する（R1）。
照合は検索のモーダルと同じ `SearchPattern` を使う値型 `NameFilter` で行う（R2）。表示する一覧が別の場所へ替わる操作はすべて `resetForNavigation()` を通るので、
そこで絞り込みを解除する（R4）。ツールバーには、検索フィールドを `view` に持つ項目 `nameFilter` を加え、入力のたびにモデルへ渡し、モデルの変化を検索欄へ戻す（R5〜R7）。
虫眼鏡の押下と、検索欄にフォーカスがある間の ⌥⌘F は、検索欄の文字をキーワードとして検索のモーダルを開く（R8〜R10）。
検索欄へ移るコマンド「名前で絞り込む」（⌘F）を、割り当てを変更できるコマンドに加える（R11）。
検索の処理（照合・列挙・結果の表示）と、検索のモーダルの ⌥⌘F からの動作は変えない。

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: Foundation / AppKit。外部依存なし

**Storage**: 新しい設定キーは追加しない。既存の `view.toolbarItems` が取り得る識別子に `nameFilter` が、ショートカットの割り当ての保存値が取り得るコマンドに
`filterByName` が加わる（contracts/toolbar-name-filter.md）

**Testing**: Swift Testing（`Tests/FolzioCoreTests`・`Tests/FolzioPerformanceTests`）、macOS CI、保守者の GUI 確認（quickstart.md）

**Target Platform**: macOS 15 以降

**Project Type**: Swift Package のデスクトップアプリ

**Performance Goals**: 10,000 件の一覧で、1文字の入力から絞り込みの結果の表示までが 100ms 以内（SC-209）。絞り込みでファイルシステムを読まない

**Constraints**: 判断ロジックは FolzioCore（AppKit を import しない）、描画と入力は FolzioApp に置く（AGENTS.md）。
検索のモーダルの ⌥⌘F からの動作を変えない（FR-390）。ネットワーク API を使わない。
AppKit UI の不変条件（制約は `addSubview` の後、異なる階層のアンカー同士を制約しない）を守る

**Scale/Scope**: Core の値型 2 つ（`NameFilter`・`ToolbarSearchInput`）、`BrowserModel` の状態 1 つ、ツールバーの項目 1 つ、コマンド 1 つ、文言 8 つ（日英）

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判定 | 根拠 |
|---|---|---|
| I. ローカル完結・プライバシー | 適合 | ネットワークを使わない。検索欄の文字と絞り込みは保存しない（EC-254）。ファイルを変更しない |
| II. 体感パフォーマンス | 適合 | 絞り込みは表示中の項目の名前の照合だけで、ファイルシステムを読まない。10,000 件で 100ms 以内を性能テストで測る（R15） |
| III. キーボードファースト & アクセシビリティ | 適合 | 検索欄へ移るコマンドと ⌘F を加える（FR-391）。検索欄と虫眼鏡はアクセシビリティのラベルを持つ（FR-392） |
| IV. テスト必須 | 適合 | 照合・適用・解除・選択・一致なしの状態を Core に置いてテストする。画面は GUI 確認で確かめる（R16） |
| V. シンプルさ | 適合 | 種類フィルタの仕組み（モデルの状態・`rebuildListing()`・監視）と `SearchPattern` を再利用する。一覧の状態の case を足さない（R3） |

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
│   └── toolbar-name-filter.md
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks で作る
```

### Source Code (repository root)

```text
Sources/FolzioCore/Model/
└── NameFilter.swift                    # 追加。入力した文字と照合（R2）

Sources/FolzioCore/Browser/
└── BrowserModel.swift                  # nameFilter・setNameFilter・nameFilterHidesAllRows。rebuildListing と resetForNavigation（R1・R3・R4）

Sources/FolzioCore/Search/
└── ToolbarSearchInput.swift            # 追加。モーダルへ引き継ぐキーワードの決め方（R9）

Sources/FolzioCore/Settings/
└── ToolbarLayout.swift                 # setIdentifiers に nameFilter。defaultOrder を「…→ 可変スペース → nameFilter」に（R14）

Sources/FolzioCore/Shortcuts/
├── ShortcutCommand.swift               # filterByName（⌘F）を追加（R11）
└── ShortcutCatalog.swift               # ショートカット一覧の項目を追加

Sources/FolzioApp/Search/
└── ToolbarSearchField.swift            # 追加。NSSearchField のサブクラス。ツールチップ、⌥⌘F の受け渡し（R8・R10）

Sources/FolzioApp/FileList/
└── FileListViewController.swift        # applyNameFilter・onNameFilterChange・一致なしのメッセージ（R3・R5）

Sources/FolzioApp/App/
├── MainSplitViewController.swift       # presentSearchPanel・showSearch(carrying:)・filterByName（R9・R11）
├── MainToolbarController.swift         # nameFilter の項目の生成・入力・状態・文言・解除。既定と許可の一覧を ToolbarLayout から作る（R5〜R8・R12〜R14）
└── MainMenu.swift                      # 「ファイル > 名前で絞り込む」（R11）

Sources/FolzioApp/Shortcuts/
└── ToolbarShortcutText.swift           # ツールチップのキーの対応（R8）

Sources/FolzioLocalization/
├── TextKey.swift・ShortcutText.swift   # 文言 8 つとコマンドの対応
└── Resources/{ja,en}.lproj/Localizable.strings

docs/
├── usage.md・usage.ja.md              # 「ツールバー」「名前の検索」「ショートカット一覧」に絞り込みを加える
└── development.md・development.ja.md  # 手動の確認に絞り込みを加える

Tests/FolzioCoreTests/
├── NameFilterTests.swift               # 追加
├── BrowserModelNameFilterTests.swift   # 追加
├── ToolbarSearchInputTests.swift       # 追加
├── ToolbarLayoutTests.swift            # 既定の並びと保存値
├── Shortcuts/ShortcutCommandConsistencyTests.swift など   # コマンドの数と既定のキー
└── Localization/                       # 新しい文言

Tests/FolzioPerformanceTests/
└── NameFilterPerformanceTests.swift    # 追加。10,000 件（R15）
```

**Structure Decision**: 既存の Swift Package の構成のまま。Core の判断は `Sources/FolzioCore/` に、AppKit の適用は `Sources/FolzioApp/` に置く。

## Complexity Tracking

なし。
