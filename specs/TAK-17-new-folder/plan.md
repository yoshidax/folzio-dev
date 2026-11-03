# Implementation Plan: TAK-17 フォルダの新規作成

**Branch**: `claude/epic-cray-f3r720` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-17-new-folder/spec.md`

## Summary

Core に「作成先と既定名から、空いている名前でフォルダを作る」操作と、既定名の連番の決定、ツリー・ファイルリストの
有効条件の判断を加える。App では、ツリーの右クリックメニュー・ファイルリストの背景の右クリックメニュー・「ファイル > 新規フォルダ」（⇧⌘N）から
作成し、作成した行で既存の行内の名前の編集を始める。作成直後の名前の確定は、既存の名前の変更の経路を使い、確認モーダルだけを省く。

## Technical Context

**Language/Version**: Swift 6（Swift Package、`swiftLanguageModes: [.v6]`）

**Primary Dependencies**: Foundation / AppKit。外部依存なし

**Storage**: ローカルのファイルシステム。新しい永続データ・設定キーなし

**Testing**: Swift Testing（`Tests/FolzioCoreTests`）と FixtureKit の一時ディレクトリ。Cloud では実行できないため macOS CI と保守者の実機で確認する

**Target Platform**: macOS 15 以降

**Project Type**: デスクトップアプリ（AppKit のみ）

**Performance Goals**: 作成は1回の `createDirectory` と親の列挙1回。既存の名前の変更と同程度の応答。UI スレッドで列挙・作成しない

**Constraints**: ネットワーク API を追加しない。`FolzioCore` は AppKit を import しない。AppKit の不変条件（AGENTS.md）を守る

**Scale/Scope**: ツリー（通常のフォルダ・ホーム・ボリュームの最上位・お気に入りの項目）、ファイルリストの背景（リスト形式・サムネイル形式）、
「ファイル」メニューと ⇧⌘N、ショートカット一覧（45 項目）、両言語の文言

## Constitution Check

| 原則 | Phase 0 / Phase 1 の確認 |
|---|---|
| I ローカル完結 | 適合。通信なし。作成は既存の項目を変更・上書きしない（同名は連番、作成時の衝突も次の番号で再試行）。破壊的操作ではないため確認を省く（FR-209、A-120） |
| II 性能 | 適合。作成と親の列挙は既存の `FileOperationService` と同じく detached task で行う。画像のデコード・キャッシュは変更しない |
| III キーボード | 適合。⇧⌘N と「ファイル > 新規フォルダ」を同時に提供する。編集欄のアクセシビリティラベルは既存（「フォルダの名前」）を使う |
| IV テスト | 適合する計画。既定名の連番、作成の成功・同名・作成先なし・書き込み不可、メニューの有効条件、ショートカット一覧の件数をテストする |
| V YAGNI | 適合。新しい依存・設定・抽象化を加えない。取り消し・選択項目から新規フォルダは範囲外（A-122） |
| 仕様管理 | 適合。変更はこの feature に記録し、検証後に最新 master と照合して `specs/product/` へ反映する |

設計前後で違反なし。設計レビューの承認前に実装しない（docs_private/cloud-agent-workflow.md「全体の流れ」）。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-17-new-folder/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── contracts/new-folder.md
├── quickstart.md
├── checklists/requirements.md
└── tasks.md            # /speckit-tasks で作る
```

### Source Code (repository root)

- `Sources/FolzioCore/Operations/NameValidation.swift`: `newFolderName(baseName:existingNames:)`。既定名が空いていればそのまま、なければ `uniqueName` の連番（R2）
- `Sources/FolzioCore/Operations/FileOperationService.swift`: `FileOperating.createFolder(in:baseName:)`。親の列挙・作成・作成時の同名の再試行・失敗理由（R1・R3）
- `Sources/FolzioCore/Model/FavoriteCommands.swift`: `TreeContextMenuItem.newFolder`、`newFolderTarget(_:)`、`contextMenu(for:roots:)` の先頭に「新規フォルダ」と区切り（R5）
- `Sources/FolzioCore/Model/ListItemCommands.swift`: `allowsNewFolder`（zip の中・検索結果で無効）（R5）
- `Sources/FolzioCore/Shortcuts/ShortcutCatalog.swift`: `newFolder`（⇧⌘N、「選択とファイル操作」、`duplicate` の後）
- `Sources/FolzioLocalization/`（`TextKey.swift`・`ShortcutText.swift`・`Resources/{ja,en}.lproj`）: 「新規フォルダ」「名称未設定フォルダ」とショートカット一覧の説明・条件
- `Sources/FolzioApp/Operations/FileOperationCoordinator.swift`: `createFolder(in:) async -> URL?`（失敗の表示・一覧の再読み込み・ツリーへの通知）と、`rename` の確認を省く引数（R4）
- `Sources/FolzioApp/App/MainMenu.swift`: 「ファイル」の先頭に「新規フォルダ」（⇧⌘N、target nil）と区切り（R6）
- `Sources/FolzioApp/FileList/FileContextMenu.swift`・`ListModeView.swift`・`ThumbnailModeView.swift`・`FileListViewController.swift`:
  背景の右クリックの判定と専用メニュー、`newFolder(_:)`、作成した行の選択と名前の編集、作成直後の印の受け渡し（R7・R8）
- `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift`: `newFolder(_:)`（選択中）と `newFolderFromMenu(_:)`（右クリックした行）、作成先の展開と新しい行の編集、
  お気に入りの項目からファイルリストへの編集の受け渡し（R9）
- `Sources/FolzioApp/App/MainSplitViewController.swift`: ファイルリストの名前の確定で作成直後の印を見て確認を省く結線、ツリーからファイルリストへの編集依頼の結線
- `Tests/FolzioCoreTests/`: `NameValidationTests`・`FileOperationServiceTests`・`FavoriteCommandsTests`・`ListItemCommandsTests`・`ShortcutCatalogTests`・
  `Localization/` の文言の網羅

**Structure Decision**: 既存の Core/App の分離に従う。判断（名前・有効条件・メニューの構成）は Core、メニュー・編集・フォーカスは App に置く。

## Phase 0: Research

[research.md](research.md) に決定・理由・代替案を記録した（R1〜R10）。未決事項なし。

## Phase 1: Design

[data-model.md](data-model.md) の型と [contracts/new-folder.md](contracts/new-folder.md) の操作・メニューの契約に従う。
検証手順は [quickstart.md](quickstart.md)。

## Complexity Tracking

憲章の例外なし。作成操作は `FileOperation.Kind` に加えず、専用のメソッドにする（R1）。`Kind` の網羅的な switch（確認モーダル・確認ポリシー）に
作成を持ち込まないためで、抽象化を増やすものではない。

## Delivery Gate

設計レビューの承認後に実装する。Cloud の静的検査（`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、
`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`、`test_check_git_push.py`）、macOS CI の build/test、
保守者の GUI 確認（quickstart の GUI 手順）を終えてから `specs/product/` に反映する。PR は依頼されたときだけ作る。
