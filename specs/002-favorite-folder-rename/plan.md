# Implementation Plan: お気に入りの名前の変更

**Branch**: `002-favorite-folder-rename` | **Date**: 2026-10-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-favorite-folder-rename/spec.md`
（あわせて参照する既存の領域: `specs/product/directory-tree.md`・`specs/product/file-operations.md`・
`specs/product/contracts/keyboard-and-menus.md`・`specs/product/contracts/settings.md`。
spec.md が参照する `specs/product/overview.md`（FR-003）・`specs/product/zip.md`（FR-073・096）・`specs/product/search.md`（FR-080）・
`specs/product/window-layout.md`（FR-090）も含む）

## Summary

ツリーの「お気に入り」の下の項目に、ユーザーが任意の表示名を付けられるようにする（FR-099〜102、FR-064 の変更）。
表示名はお気に入りの登録内容の一部で、実際のフォルダには一切触れない。

- **Core**: `FavoriteFolders` に「パス → 表示名」の対応を持たせ、確定時の名前の扱い（前後の空白の除去・空なら解除・
  改行の除去・255 文字の上限・編集前と同じなら何もしない）を純粋関数 `FavoriteName` に置く。右クリックメニューに
  `TreeContextMenuItem.renameFavorite` を加え、対象の判定を `FavoriteCommands.renameTarget(_:)` に置く（R48・R50）
- **保存**: 既存の `favorites.paths` はそのまま使い、表示名だけを新しいキー `favorites.displayNames`（パス → 名前の辞書）に
  保存する。旧形式は「表示名なし」として読めるため、移行処理は要らない（R49）
- **App**: `DirectoryTreeViewController` が、お気に入りの行のセルのテキストフィールドをその場で編集可能にする
  （ファイルリストの `ListModeView.beginRenaming` と同じ方式）。Return は既存の「編集 > 名前を変更」（`rename(_:)`、
  Return のキー等価）を、ツリーが応答チェーンで受けて始める。右クリックメニューは右クリックした行を対象にする（R51・R52）
- **名前の変更中**: 既存の無効化はウインドウの first responder が `NSTextView`（フィールドエディタ）かで判定している
  （`FileListViewController.isEditingText`）。ツリーでの編集もフィールドエディタを使うため、契約の「ファイル名の変更中」に
  無効とされる操作はそのまま無効になる。ツリー自身のメニュー項目（⌘⌫・名前を変更・右クリックの「ここにペースト」・移動ペーストなど）だけ、編集中は検証で無効にする。
  「編集 > ペースト」（⌘V）はフィールドエディタが受けて編集欄へのテキストのペーストになる（R53）
- **削除の確認モーダル**: `ConfirmationPresenter.confirmRemovingFavorite` に登録したフォルダの絶対パスを渡して表示する（R55）

## Technical Context

**Language/Version**: Swift 6（strict concurrency）

**Primary Dependencies**: AppKit（`NSOutlineView`・`NSTextField`・`Formatter`）、Foundation。外部パッケージなし

**Storage**: `UserDefaults`（`SettingsStore`）。既存キー `favorites.paths` に加え、`favorites.displayNames` を追加（R49）

**Testing**: Swift Testing（`Tests/MediaViewerCoreTests`）。UI は quickstart.md の手動確認

**Target Platform**: macOS 15 以降

**Project Type**: desktop-app（Swift Package: `MediaViewerCore` / `MediaViewerApp`）

**Performance Goals**: 既存の基準値（憲章 II）を変えない。名前の確定は数件〜数十件の辞書の更新と `UserDefaults` への書き込みだけで、
UI スレッドで行ってよい規模（既存のお気に入りの追加・削除と同じ）

**Constraints**: ファイルシステムを変更しない（FR-099）。ネットワーク API を使わない。`MediaViewerCore` は AppKit を import しない

**Scale/Scope**: お気に入りは数十件程度を想定。変更するソースは Core 4 ファイル（うち新規 1）、App 2 ファイル＋新規 1

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判定 | 根拠 |
|---|---|---|
| I. ローカル完結・プライバシー | PASS | 表示名は `UserDefaults` にだけ保存する。実際のフォルダの名前・場所・中身は変えない（FR-099、SC-019）。破壊的操作ではないため確認モーダルは不要で、Esc での取り消しと空での解除で取り消し可能性を満たす（A-29） |
| II. 体感パフォーマンス | PASS | 重い処理を追加しない。存在の確認は既存の `FavoriteProbe`（UI スレッド外）のまま |
| III. キーボードファースト & アクセシビリティ | PASS | Return と「編集 > 名前を変更」で開始・Return で確定・Esc で取り消し。表示名をアクセシビリティの項目名に使い、編集欄に「お気に入りの名前」のラベルを付ける（FR-101、R54） |
| IV. テスト必須 | PASS | 名前の正規化・登録内容の更新・保存と旧形式の読み込み・メニューの判定を Core のテストで検証する。不正な保存値（型違い・未登録のパス・長すぎる名前）の異常系を含める（data-model.md の「テスト」） |
| V. シンプルさ（YAGNI） | PASS | 新しい依存なし。保存は既存キーを残して辞書を1つ足すだけで、移行処理を持たない（R49）。新しい型は `FavoriteName`（純粋関数）と App の `Formatter` 1つ |

**Post-design re-check（Phase 1 後）**: PASS。contracts と data-model で追加した API・キーは上の判定を変えない。
Complexity Tracking に記載する違反なし。

## Project Structure

### Documentation (this feature)

```text
specs/002-favorite-folder-rename/
├── spec.md
├── plan.md              # このファイル
├── research.md          # Phase 0（R48〜R56）
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1（手動確認の手順）
├── contracts/
│   ├── core-api.md            # Core の公開 API の追加・変更
│   ├── settings.md            # specs/product/contracts/settings.md への差分
│   └── keyboard-and-menus.md  # specs/product/contracts/keyboard-and-menus.md への差分
├── checklists/
└── tasks.md             # /speckit-tasks で作る
```

### Source Code (repository root)

```text
Sources/MediaViewerCore/
├── Model/
│   ├── FavoriteFolders.swift      # 変更: 表示名の保持・設定・解除、削除時の破棄
│   ├── FavoriteName.swift         # 新規: 編集中の入力の整形、確定時の正規化
│   └── FavoriteCommands.swift     # 変更: renameTarget、contextMenu に .renameFavorite
└── Settings/
    └── SettingsStore.swift        # 変更: favorites.displayNames の読み書き

Sources/MediaViewerApp/
├── Tree/
│   ├── DirectoryTreeViewController.swift  # 変更: 行内編集、rename(_:)、検証、確認モーダルへのパス
│   └── FavoriteNameFormatter.swift        # 新規: 改行を除き 255 文字で打ち切る Formatter（判定は FavoriteName）
└── Operations/
    └── ConfirmationPresenter.swift        # 変更: confirmRemovingFavorite(named:path:)

Tests/MediaViewerCoreTests/
├── FavoriteNameTests.swift        # 新規
├── FavoriteFoldersTests.swift     # 追加
├── FavoriteCommandsTests.swift    # 追加
└── SettingsStoreTests.swift       # 追加（旧形式の読み込みを含む）
```

`MainMenu.swift` は変更しない（「編集 > 名前を変更」は `target = nil` の `rename(_:)` で、ツリーが同名のアクションを実装すれば
応答チェーンで受けられる。R52）。`FileListViewController`・`PaneCommands`・`MainToolbarController` も変更しない（R53）。

**Structure Decision**: 既存の Swift Package 構成のまま。判断（名前の正規化・メニューの項目・保存形式）は `MediaViewerCore`、
行内編集とメニューの検証は `MediaViewerApp` のツリーに置く。

## Complexity Tracking

違反なし。
