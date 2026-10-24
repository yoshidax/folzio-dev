# Implementation Plan: ツリーのフォルダの名前の変更と削除

**Branch**: `003-tree-folder-rename-delete` | **Date**: 2026-10-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-tree-folder-rename-delete/spec.md`
（あわせて参照する既存の領域: `specs/product/directory-tree.md`・`specs/product/file-operations.md`・`specs/product/file-list.md`・
`specs/product/search.md`・`specs/product/contracts/keyboard-and-menus.md`。spec.md が参照する `specs/product/overview.md`（FR-003）・
`specs/product/zip.md`（FR-073）・`specs/product/window-layout.md`（FR-090）も含む）

## Summary

ツリーの通常のフォルダの名前を、ファイルリストと同じ操作（Return・右クリック・「編集 > 名前を変更」）でその場で変えられるようにし
（FR-103）、名前を変えた結果をツリー・ファイルリスト・検索結果・お気に入りに食い違いなく反映する（FR-104〜106）。
ツリーからフォルダをゴミ箱に入れるときは、確認モーダルの省略設定に関わらず必ず確認する（FR-079・FR-024 の変更）。
フォルダをパッケージになる名前に変えることは、ツリーとファイルリストの両方で拒否する（EC-53・EC-14）。

- **検証**: `validateNewName` にパッケージになる名前の検査を足す（`PackageName`、UTType で判定）。ツリーとファイルリストの
  フォルダの名前の変更は同じ `FileOperationCoordinator.rename` を通るため、1か所の変更で両方に効く（R57）
- **確認**: 省略できるかの判断を Core の `ConfirmationPolicy`（操作の種類 × 経路 `.fileList` / `.tree`）に移し、ツリーの
  ゴミ箱は省略できないようにする。ツリーからの確認モーダルには絶対パスを添える（R58・R66）
- **ツリーの編集**: 002 の行内編集の状態を `EditingTarget`（お気に入り / フォルダ）に広げて共有する。対象の判断は
  `FavoriteCommands.renameTarget(_:roots:) -> TreeRenameTarget?`、右クリックメニューに `.renameFolder` を足す（R59・R60）
- **付け替え**: Core の `RenamedFolder.rebase` で、名前を変えたフォルダの配下の URL（`file`・zip の中）を新しい場所に付け替える。
  `BrowserModel.didRenameFolder` が一覧・選択・検索結果・`lastFolder` をディスクを読まずに付け替え、プレビューと再生中の動画は
  変えない。検索中は後から届く結果も付け替え、新しい場所を追加で列挙する（R61〜R63）
- **ツリーの状態の保持**: ノードのオブジェクトを作り直さずに URL を付け替え、`applyListing` を既存のノードを使い回すように変えて、
  展開状態と選択を保つ（R64）。名前の変更のたびにお気に入りの有無を確かめ直す（R65）

## Technical Context

**Language/Version**: Swift 6（strict concurrency）

**Primary Dependencies**: AppKit（`NSOutlineView`・`NSTextField`・`NSAlert`）、Foundation、UniformTypeIdentifiers（Core のパッケージ型の判定。
OS の標準フレームワークで、外部依存ではない）。外部パッケージなし

**Storage**: `UserDefaults`（`SettingsStore`）。キーの追加・変更はない。`view.lastFolderPath` の値を新しい場所に書き換えることがある（R62）

**Testing**: Swift Testing（`Tests/MediaViewerCoreTests`、`Tests/MediaViewerPerformanceTests`）。UI は quickstart.md の手動確認

**Target Platform**: macOS 15 以降

**Project Type**: desktop-app（Swift Package: `MediaViewerCore` / `MediaViewerApp`）

**Performance Goals**: 既存の基準値（憲章 II）を変えない。名前の変更の後の付け替え（`didRenameFolder`）は UI スレッドで行うため、
10,000 件の検索結果でも 100ms 未満（SC-004 と同じ値。R67）。ディスクの読み書き（名前の変更・兄弟の名前の列挙・存在の確認）は
既存どおり UI スレッドの外で行う

**Constraints**: `MediaViewerCore` は AppKit を import しない。ネットワーク API を使わない。名前の変更の失敗時に部分的な変更を残さない（EC-47）

**Scale/Scope**: 変更するソースは Core 6 ファイル（うち新規 3）、App 5 ファイル。テストは Core 7 ファイル（うち新規 3）と性能テスト 1 ファイル

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判定 | 根拠 |
|---|---|---|
| I. ローカル完結・プライバシー | PASS | 名前の変更は常に確認モーダルの後に行い、Esc・キャンセル・検証エラーでは何も変えない（FR-103、SC-023）。ツリーのゴミ箱は省略設定に関わらず確認し、ゴミ箱経由で取り消せる（FR-079、SC-027）。パッケージになる名前を拒否し、名前を変えただけでフォルダが見えなくなる事故を防ぐ（EC-53）。通信は追加しない |
| II. 体感パフォーマンス | PASS | 付け替えはメモリ上の配列の更新だけで、10,000 件で 100ms 未満を性能テストで確かめる（R67）。ディスクの操作は既存どおり UI スレッドの外 |
| III. キーボードファースト & アクセシビリティ | PASS | Return・「編集 > 名前を変更」で開始、Return で確定、Esc で取り消し。編集欄に「フォルダの名前」のラベルを付ける（FR-103）。右クリックメニューの操作はキーボードでも行える（Return・⌘⌫） |
| IV. テスト必須 | PASS | パッケージ名の判定・確認の省略の判断・名前の変更の対象と右クリックメニュー・URL の付け替え・一覧と検索結果の付け替えを Core のテストで検証する。確認の省略の判断を App から Core に移してテスト可能にする（R58）。異常系（関係のないフォルダ、兄弟の前方一致、検索中に遅れて届く結果）を含める（data-model.md の「テスト」） |
| V. シンプルさ（YAGNI） | PASS | 新しい外部依存なし。保存キーを足さない。検索の対象外になったファイルを外す専用の処理は、アプリの中では起きないため持たない（R63）。新しい型は Core の小さな値型と名前空間（`PackageName`・`ConfirmationPolicy`・`OperationOrigin`・`TreeRenameTarget`・`RenamedFolder`）だけ |

**Post-design re-check（Phase 1 後）**: PASS。contracts と data-model で追加した API は上の判定を変えない。
`applyListing` のノードの使い回し（R64）は既存の外部変更の反映の振る舞いも変える（展開状態を保つようになる）が、より単純な代替
（名前を変えたノードだけを動かす）は FSEvents の後に展開状態を失うため採らない。Complexity Tracking に記載する違反なし。

## Project Structure

### Documentation (this feature)

```text
specs/003-tree-folder-rename-delete/
├── spec.md
├── plan.md              # このファイル
├── research.md          # Phase 0（R57〜R67）
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1（手動確認の手順）
├── contracts/
│   ├── core-api.md            # Core の公開 API の追加・変更
│   ├── keyboard-and-menus.md  # specs/product/contracts/keyboard-and-menus.md への差分
│   └── settings.md            # specs/product/contracts/settings.md への差分（設定ウインドウの項目名）
├── checklists/
└── tasks.md             # /speckit-tasks で作る
```

### Source Code (repository root)

```text
Sources/MediaViewerCore/
├── Operations/
│   ├── NameValidation.swift       # 変更: フォルダのパッケージになる名前を拒否
│   ├── PackageName.swift          # 新規: 拡張子がパッケージの型かの判定（UTType）
│   └── ConfirmationPolicy.swift   # 新規: OperationOrigin と、確認を省略できるかの判断
├── Model/
│   ├── FavoriteCommands.swift     # 変更: TreeRenameTarget、renameTarget(_:roots:)、.renameFolder
│   └── RenamedFolder.swift        # 新規: 名前を変えたフォルダの配下の URL の付け替え
└── Browser/
    └── BrowserModel.swift         # 変更: didRenameFolder、検索中の付け替えと追加の列挙

Sources/MediaViewerApp/
├── Tree/
│   └── DirectoryTreeViewController.swift  # 変更: EditingTarget、フォルダの行内編集、.renameFolder、
│                                          #       ノードの付け替え、applyListing の使い回し、お気に入りの再確認、origin: .tree
├── Operations/
│   ├── ConfirmationPresenter.swift        # 変更: origin と location、ConfirmationPolicy を使う
│   └── FileOperationCoordinator.swift     # 変更: rename/trash の origin、onFolderRenamed、didRenameFolder の呼び出し
├── Settings/
│   └── SettingsWindowController.swift     # 変更: 確認の項目名（ツリーのフォルダのゴミ箱は常に確認する）
└── App/
    └── MainSplitViewController.swift      # 変更: onFolderRenamed をツリーへつなぐ

Tests/MediaViewerCoreTests/
├── PackageNameTests.swift          # 新規
├── ConfirmationPolicyTests.swift   # 新規
├── RenamedFolderTests.swift        # 新規
├── NameValidationTests.swift       # 追加
├── FavoriteCommandsTests.swift     # 追加（renameTarget のシグネチャ変更に合わせて既存も直す）
├── BrowserModelFolderTests.swift   # 追加（didRenameFolder: 表示中・祖先・親・zip の中・lastFolder・FSEvents）
└── BrowserModelSearchTests.swift   # 追加（didRenameFolder: 検索結果・起点・検索中）

Tests/MediaViewerPerformanceTests/
└── PerformanceBaselineTests.swift  # 追加（10,000 件の検索結果での didRenameFolder）
```

`MainMenu.swift` は変更しない（「編集 > 名前を変更」「ゴミ箱に入れる」は `target = nil` で、ツリーにフォーカスがあれば
応答チェーンでツリーの `rename(_:)`・`moveToTrash(_:)` に届く）。`FileListViewController`・`ListModeView`・`ThumbnailModeView` も
変更しない（ファイルリストの名前の変更はコーディネータ経由で、付け替えは `BrowserModel` の変更で反映される）。

**Structure Decision**: 既存の Swift Package 構成のまま。判断（パッケージ名・確認の省略・名前の変更の対象・URL の付け替え・
一覧と検索結果の付け替え）は `MediaViewerCore`、行内編集・メニュー・ツリーのノードの付け替えは `MediaViewerApp` に置く。

## 実装の順序と依存（tasks.md の参考）

1. Core の独立した部品: `PackageName`＋`validateNewName`、`ConfirmationPolicy`、`RenamedFolder`、`FavoriteCommands`（互いに独立。並列にできる）
2. `BrowserModel.didRenameFolder`（`RenamedFolder` に依存）と、検索中の付け替え・追加の列挙
3. App の確認とコーディネータ（`ConfirmationPolicy` に依存）: `ConfirmationPresenter`・`FileOperationCoordinator`
4. App のツリー（2・3 に依存）: 行内編集の共有、`.renameFolder`、ノードの付け替えと `applyListing`、お気に入りの再確認、ゴミ箱の `origin`
5. 性能テスト、GUI の確認（quickstart.md）

`DirectoryTreeViewController.swift` を触るタスクは同じファイルのため直列にする（AGENTS.md の worktree 規約）。

## Complexity Tracking

違反なし。
