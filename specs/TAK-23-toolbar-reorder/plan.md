# Implementation Plan: ツールバーのボタンセット単位のカスタマイズ

**Branch**: `claude/sleepy-brahmagupta-n900cl`（作業ブランチ） | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-23-toolbar-reorder/spec.md` / [TAK-23](https://linear.app/takyoshida/issue/TAK-23)

本資料は設計レビュー用。`docs_private/cloud-agent-workflow.md` の「承認の前に実装しない」に従い、承認後に tasks.md を作る。

## Summary

標準の `NSToolbar` のカスタマイズ（並び替え・削除・再追加・スペース・表示モード）を有効にする。セットはすでに1つの `NSToolbarItem` なので、
分離されない（実機で確認済み）。改修の中身は次の3点である。

1. **状態管理の作り直し（必須）**: セットごとの `NSSegmentedControl` を、`MainToolbarController` が1つずつプロパティに保持している。
   カスタマイズ用パレットと項目の作り直しで参照が上書き・失効し、履歴の有効・無効が壊れることを実機で確認した。参照を保持せず、
   現在 `toolbar.items` にある項目の `view` から都度引く形に改める
2. **復元**: 標準の自動保存は、書き込みは正常だが起動時の読み込みが効かない。原因が分かるまで方式を決めず、段階的に選ぶ（research.md R-3）
3. **ラベルとツールチップの整理**: FR-009・010。メニューの文言と共用せず、専用の文言キーを持つ（日英）

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: Foundation、AppKit、既存 FolzioCore / FolzioLocalization。外部依存なし

**Storage**: 復元の方式（R-3）次第で `UserDefaults` に設定キーを1つ追加する（`view.toolbarConfiguration` または `view.toolbarItems`。標準の自動保存で足りれば追加なし）

**Testing**: Swift Testing（`Tests/FolzioCoreTests`）。並び順の正規化を Core の純粋な関数にして自動検証。ローカライズ整合性検査（`CatalogConsistencyTests`）を継続。AppKit の挙動は quickstart.md の実機検証

**Target Platform**: macOS 15 以降。Cloud（Linux）では Swift のビルド・テストも GUI も実行しない（CI と保守者）

**Project Type**: Swift Package のデスクトップアプリ

**Performance Goals**: 起動時のツールバー構築は項目8個の生成のみ。デコード・列挙・ファイル操作は行わない。既存の性能基準を変えない

**Constraints**: Core に AppKit を import しない。ネットワーク API なし。UI は MainActor。制約は `addSubview` 後に有効化

**Scale/Scope**: セット8種＋標準のスペース。変更は `MainToolbarController`、`MainWindowController`、`SettingsStore`、`TextKey` と両言語の文字列

## Constitution Check

| 原則 | Phase 0 前 / Phase 1 後 |
|---|---|
| I ローカル完結 | PASS / PASS。保存は `UserDefaults` のみ。通信なし |
| II 体感性能 | PASS / PASS。重い処理なし。起動時の構築量はほぼ変わらない |
| III キーボード・アクセシビリティ | PASS / PASS。セットを外してもメニュー・ショートカットで全機能を使える（FR-003a）。ラベル・ヘルプを新文言に揃える |
| IV テスト必須 | PASS / PASS。並び順の正規化と文言キーを自動検証。GUI は実機。不正値のテストを含む |
| V シンプルさ | PASS / PASS。独自のカスタマイズ画面は作らない。復元は最小の方式から選ぶ（R-3）。Complexity Tracking を参照 |

## Project Structure

### Documentation (this feature)

```text
specs/TAK-23-toolbar-reorder/
├── plan.md
├── research.md          # 調査（Apple 文書・Web）と復元の方式選択
├── data-model.md
├── quickstart.md        # 検証手順（Cloud / CI / 実機）
├── contracts/
│   └── toolbar-labels.md  # ラベル・ツールチップの契約（日英）
└── tasks.md             # /speckit-tasks で作る（本コマンドでは作らない）
```

### Source Code

```text
Sources/FolzioCore/Settings/ToolbarLayout.swift          # 新規: 並び順の正規化（純粋な値と関数）
Sources/FolzioCore/Settings/SettingsStore.swift          # 変更: R-3 の方式次第で保存キーを追加
Sources/FolzioLocalization/TextKey.swift                 # 変更: 文言キーの追加と説明
Sources/FolzioLocalization/Resources/{ja,en}.lproj/Localizable.strings  # 変更: ラベル・ツールチップ
Sources/FolzioApp/App/MainToolbarController.swift        # 変更: 参照管理の作り直し、カスタマイズの有効化、復元
Sources/FolzioApp/App/MainWindowController.swift         # 変更: 構成の復元・保存のタイミング
Tests/FolzioCoreTests/ToolbarLayoutTests.swift           # 新規
Tests/FolzioCoreTests/Localization/                      # 既存検査が新キーを検査（変更が要れば追記）
docs/usage.md / docs/usage.ja.md                          # 変更: ツールバーの記述（ラベル・カスタマイズ）を同じ内容で更新
specs/product/                                           # 反映（最後の作業。下記）
```

**Structure Decision**: 判断ロジック（保存値の正規化）は Core、描画と入力は App（AGENTS.md）。

## Phase 0: Research

[research.md](research.md) に、Apple の文書・Web の調査結果、未解決の点、復元の方式選択の手順を記録した。

## Phase 1: Design

### 1. 状態管理の作り直し（R-2）

- `historyControl` などのプロパティ（セグメント6個＋スライダー＋項目）を廃止する。代わりに、`toolbar.items` から識別子で項目を引き、`view` を
  `NSSegmentedControl` として扱うアクセサを置く（例: `control(for: identifier)`）。パレット用に作られる項目は `toolbar.items` に入らないため、
  状態の更新対象にならない
- `itemForItemIdentifier` は呼ばれるたびに**新しい control と項目**を返す（スライダーも項目ごとに作る。1つの `NSView` を複数の項目で共有しない）。
  `willBeInsertedIntoToolbar == true` のときだけ、現在の状態を適用する。`false`（パレット用）は状態を適用せず、参照も保持しない
- 項目がツールバーに入った・外れたとき（`toolbarWillAddItem`／`toolbarDidRemoveItem`）に、その識別子の状態を再適用する。`toolbarWillAddItem` の時点では項目が `toolbar.items` に入っていない見込みのため、通知の項目へ直接適用するか、次の run loop で引き直す。
  これで「外して戻す」「デフォルトセットの入れ直し」でも状態が追従する
- `NSToolbarItemValidation` と `apply(...)` 系は、上のアクセサ経由に書き換える。`toolbar.items` に該当がない間（未装着）は何もしない
- 同じセットが複数回追加できた場合の扱いは、実機で確かめて決める（R-4）。許される場合は、識別子で見つかるすべての項目に同じ状態を適用する

### 2. カスタマイズの有効化

- `allowsUserCustomization = true`、`allowsDisplayModeCustomization = true`（FR-003c）。`displayMode` の既定は `.iconOnly`
- 許可項目は現行の8種に `.space`・`.flexibleSpace` を加える（標準の挙動を許容、FR-003）。「デフォルトのセット」は標準のカスタマイズ画面にある
- 既定の順序は現行のまま（FR-006）

### 3. 復元（R-3。方式は spike の結果で選ぶ）

次の順で、**最初に直った方式**を採る。上の段が効けば、下の段は実装しない。

| 段 | 方式 | 追加するもの |
|---|---|---|
| 0 | 標準の自動保存の切り分け。起動直後の `toolbar.items` の識別子を、`init` 後・`window.toolbar` 割り当て後・次の run loop でログに出す（保守者の実機） | 一時的なログのみ（実装には残さない） |
| 1 | 標準の自動保存で直る設定・順序が見つかれば、それを採る | なし |
| 2 | （不採用）`configuration` / `setConfiguration(_:)` は macOS 15 で非推奨（SDK ヘッダーで確認、R-1） | — |
| 3 | **採用見込み**。非推奨 API の正式な代替である `itemIdentifiers`（macOS 15 以降、get/set）と `displayMode` を保存・復元する。`autosavesConfiguration` は `false` | `view.toolbarItems`（識別子の配列）と表示モード。正規化は Core の `ToolbarLayout` |

- 段2・3 の保存のタイミング: カスタマイズ画面（シート）が閉じたとき（`NSWindow.didEndSheetNotification` の見込み。実機で確認）と、
  アプリの終了時。通知の有無は R-3 の段0 と合わせて確認する
- 段2 では、`configuration` / `setConfiguration(_:)` が macOS 15 以降で非推奨かどうかを、SDK のヘッダーで確認する（R-1）。
  非推奨で警告が出るなら、段3 を採る
- いずれの段でも、保存値が不正・未知の識別子を含むときは既定の構成で起動する（FR-005）。この正規化は Core の `ToolbarLayout` に置く

### 4. ラベルとツールチップ（R-5、[contracts/toolbar-labels.md](contracts/toolbar-labels.md)）

- ラベル用の文言キーを、ツールチップ・メニューと分ける。`toolbar.size` はファイルリスト下部のサイズバーのラベルとしても使われている
  （`FileListViewController.swift:379,492`）ため、ツールバー用に `toolbar.thumbnailSizeLabel` を新設し、サイズバーの「サイズ」は変えない
- 「スライドショー」「zipファイル」は、現在メニューの文言（`menu.view.*`）を流用している。専用キーを新設し、メニューは変えない
- ツールチップとアクセシビリティの読み上げは FR-010 の表に揃える。ショートカットは `contracts/keyboard-and-menus.md` と一致させる
- 英語の文言は contracts/toolbar-labels.md の案（保守者のレビュー対象）

### 5. `specs/product/` の変更箇所（PR の最後の作業）

| ファイル | 変更 |
|---|---|
| `window-layout.md` FR-051・FR-089・FR-114・FR-134 | 配置の記述を「既定では」とし、並び替え・削除後は位置が変わり得ると明記。FR-051 の「項目の並びと位置は変わらない」は表示形式の切り替えに限る旨を保つ |
| `contracts/keyboard-and-menus.md`「ツールバー」 | 既定の順序とカスタマイズ可能であること、ラベル・ツールチップの表 |
| `contracts/settings.md` | 「ツールバー構成は保存しない」を改め、保存する内容・保存先・不正値の扱い（R-3 の結果）を記述 |
| `overview.md` / ローカライズの領域 | 新しい文言キーの対応（日英） |
| 新しい FR | 現在の最大は FR-199（`overview.md`）。他の feature と衝突した場合は、マージされていない側が振り直す（AGENTS.md） |

## Validation & Delivery

[quickstart.md](quickstart.md) に Cloud・CI・実機の担当と期待結果を分けた。この段階では Swift のビルド・テスト・GUI は未実施。
実装後は Cloud の検査、CI、保守者の実機確認を順に記録する。PR は保守者の依頼があるときだけ作る。

## Complexity Tracking

憲章違反はない。次の判断を記録する。

| 判断 | 採った案 | 採らなかった案 |
|---|---|---|
| 参照管理 | 参照を持たず `toolbar.items` から都度引く | 識別子ごとに「現在の control」を再登録する辞書（パレット用との区別が要り、外れた項目の参照が残る） |
| 復元 | 段階的に選ぶ（標準 → 文書化された `configuration` → 自前の並び） | 最初から自前の保存（Apple が文書で示す方式を先に試すため） |
| 削除・スペース・表示モード | 標準の挙動を許容 | 抑止（独自の作り込みが増える。保守者が許容を選んだ） |
