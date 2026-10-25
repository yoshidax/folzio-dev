# Implementation Plan: 操作の履歴を戻る・進む

**Branch**: `004-navigation-history` | **Date**: 2026-10-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-navigation-history/spec.md`
（あわせて参照する既存の領域: `specs/product/file-list.md`・`specs/product/directory-tree.md`・`specs/product/zip.md`・
`specs/product/window-layout.md`・`specs/product/search.md`・`specs/product/overview.md`・`specs/product/contracts/keyboard-and-menus.md`。
spec.md が参照する `specs/product/file-operations.md`（FR-079）・`specs/product/preview.md`（FR-034〜036）も含む）

## Summary

Finder と同じく、フォルダの選択・フォルダの移動・ファイルリストの表示の変更を履歴に記録し、ツールバーの `<`・`>`、⌘[・⌘]、
新しい「移動」メニューで戻る・進むを行う（FR-107・FR-108・FR-112）。各履歴は場所と表示の状態の組を持ち、戻る・進むはその組と、
離れたときのフォーカス行を復元する。見つからない場所は飛ばして取り除き（FR-109）、最大 100 件（FR-110）、起動ごとに消える（FR-111）。
検索結果の表示中の「戻る」は Esc と同じく検索結果の表示を終える（FR-113）。

- **履歴の列**: Core の値型 `NavigationHistory`（戻る側・現在（optional）・進む側）に、記録・同じ状態の無視・分岐・上限・サイズの変更の
  まとめ・取り除き・置き換え・隣り合う同じ履歴のまとめの規則をすべて置く（R68・R69・R71）
- **記録の経路**: 場所の変化は `BrowserModel` の同期の通知 `onLocationEvent`（`.navigated` / `.relocated` / `.notFound`）で受け、
  表示の変更は App のユーザーの操作の入口から `HistoryNavigator.recordViewChange` を呼ぶ。復元はこの経路を通らない（R70）
- **戻る・進む**: Core の `HistoryNavigator` が要求を直列に処理し、`BrowserModel.resolveHistoryLocation`（UI スレッドの外で stat・zip の索引）で
  確かめてから `showHistoryLocation` で表示する。表示の状態は種類フィルタ・zip ファイルの表示を `BrowserModel` で、表示形式・サイズ・
  ペインの表示状態を App の `HistoryPresentationHost` で戻す（R72〜R74）
- **取り除き**: アプリの中の名前の変更・ゴミ箱・移動、FSEvents とボリュームの増減、表示中の場所が消えたことによる自動の移動（EC-60）、
  「見つからない」表示（EC-62・EC-65）を契機に直す（R75）
- **UI**: ツールバーの先頭に `chevron.left`・`chevron.right` のボタングループ、「表示」の右に「移動」メニュー。有効・無効は
  `PaneCommands.canNavigateHistory`（フルスクリーン中・名前の変更中は無効）と `HistoryNavigator.canGoBack`・`canGoForward`（R76・R77）

## Technical Context

**Language/Version**: Swift 6（strict concurrency）

**Primary Dependencies**: AppKit（`NSToolbar`・`NSSegmentedControl`・`NSMenu`）、Foundation、Observation。外部パッケージなし

**Storage**: なし。履歴は保存しない（FR-111）。表示形式・サムネイルサイズ・zip ファイルの表示・`lastFolder` は、復元したときも既存の
`SettingsStore` のキーに保存する（FR-108。キーの追加・変更なし）

**Testing**: Swift Testing（`Tests/MediaViewerCoreTests`、`Tests/MediaViewerPerformanceTests`）。UI は quickstart.md の手動確認

**Target Platform**: macOS 15 以降

**Project Type**: desktop-app（Swift Package: `MediaViewerCore` / `MediaViewerApp`）

**Performance Goals**: 戻る・進むで移ったフォルダの最初の項目を 1 秒以内に表示（SC-029・SC-003 と同じ）。場所の確認（stat・zip の索引の作成）は
UI スレッドの外で行い、操作を 100ms 以上止めない。履歴の操作は最大 100 件の配列の操作で、UI スレッドで行う（R72・R78）

**Constraints**: `MediaViewerCore` は AppKit を import しない。ネットワーク API を使わない。読み込み・場所の確認で UI を止めない（EC-61）。
`NSSplitViewController` の不変条件（AGENTS.md）を変えない（ペインの表示状態の復元は既存の `setPaneLayout` を通す）

**Scale/Scope**: 変更するソースは Core 6 ファイル（うち新規 3）、App 6 ファイル。テストは Core 6 ファイル（うち新規 4）と性能テスト 1 ファイル

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判定 | 根拠 |
|---|---|---|
| I. ローカル完結・プライバシー | PASS | 履歴はメモリにだけ持ち、保存しない（FR-111）。ファイルを変更・移動・削除する操作を足さない（戻る・進むはファイル操作の取り消しではない。A-43）。通信は追加しない |
| II. 体感パフォーマンス | PASS | 場所の確認は `Task.detached` の stat と既存の zip の索引の作成（UI スレッドの外）。読み込みは既存の `loadFolder` で、完了を待たずに次の要求を受け付ける（R72）。10,000 ファイルのフォルダへ戻る時間を性能テストで計測する（R78） |
| III. キーボードファースト & アクセシビリティ | PASS | ⌘[・⌘] と「移動」メニューで、ツールバーなしでも全操作をキーボードで行える（FR-112）。ボタンに「戻る」「進む」のアクセシビリティの説明とツールチップを付ける（R77） |
| IV. テスト必須 | PASS | 記録・移動・取り除きの規則を値型 `NavigationHistory` に集め、ファイルなしでテストする。`HistoryNavigator` と `BrowserModel` の確認・表示は FixtureKit の一時ディレクトリと既存の zip のフィクスチャでテストする。異常系（削除・名前の変更・権限なし・壊れた zip・ボリュームの取り外しに当たる場所・確認中の移動・連打）を含める（data-model.md の「テスト」） |
| V. シンプルさ（YAGNI） | PASS | 新しい外部依存なし。保存キーを足さない。履歴の一覧の表示・スワイプ・サイドボタンは作らない（A-44）。表示の状態の持ち主は変えず、App の状態は小さなプロトコル `HistoryPresentationHost` で読み書きする（R74） |

**Post-design re-check（Phase 1 後）**: PASS。contracts と data-model で追加した API は上の判定を変えない。
`BrowserModel` に通知と確認・表示の API を足すが、規則は `NavigationHistory`・`HistoryNavigator` に分けて `BrowserModel` を太らせない。
EC-62 の「記録しない」を、記録を遅らせる代わりに値型の控えに戻すことで満たす（R75）。zip の中で始めた検索を Esc・⌘[ で終えた場合は、
FR-113 と US7-AS13 で「zip ファイルを含むフォルダの一覧に戻り、新しい履歴として記録する」と定めた（/speckit-analyze の指摘 I1）。R76 の規則が
そのまま満たすため、自動テスト（tasks.md の T016）と GUI（quickstart.md の 25）で検証する。Complexity Tracking に記載する違反なし。

## Project Structure

### Documentation (this feature)

```text
specs/004-navigation-history/
├── spec.md
├── plan.md              # このファイル
├── research.md          # Phase 0（R68〜R78）
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1（手動確認の手順）
├── contracts/
│   ├── core-api.md            # Core の公開 API の追加・変更
│   └── keyboard-and-menus.md  # specs/product/contracts/keyboard-and-menus.md への差分
├── checklists/
└── tasks.md             # /speckit-tasks で作る
```

### Source Code (repository root)

```text
Sources/MediaViewerCore/
├── History/
│   ├── HistoryEntry.swift         # 新規: HistoryLocation・HistoryPresentation・HistoryViewState・HistoryEntry・種類と方向
│   ├── NavigationHistory.swift    # 新規: 履歴の列の値型と規則
│   └── HistoryNavigator.swift     # 新規: HistoryPresentationHost、戻る・進むの実行と記録・取り除きの契機
├── Browser/
│   └── BrowserModel.swift         # 変更: LocationEvent と onLocationEvent、historyLocation、resolveHistoryLocation、showHistoryLocation
├── Archive/
│   └── ArchiveIndex.swift         # 変更: containsDirectory
└── Model/
    └── PaneLayout.swift           # 変更: PaneCommands.canNavigateHistory

Sources/MediaViewerApp/
├── App/
│   ├── MainSplitViewController.swift   # 変更: HistoryNavigator の所有、HistoryPresentationHost、goBack/goForward と検証、ペインの表示の記録
│   ├── MainToolbarController.swift     # 変更: 戻る・進むのボタングループ（先頭）と有効・無効の更新
│   └── MainMenu.swift                  # 変更: 「移動」メニュー
├── FileList/
│   └── FileListViewController.swift    # 変更: 表示の変更の入口での記録（onViewChange）、記録しない復元の setter
├── Tree/
│   └── DirectoryTreeViewController.swift  # 変更: FSEvents・ボリュームの増減を HistoryNavigator へ
└── Operations/
    └── FileOperationCoordinator.swift     # 変更: 名前の変更・ゴミ箱・移動の成功を HistoryNavigator へ

Tests/MediaViewerCoreTests/
├── NavigationHistoryTests.swift    # 新規
├── HistoryLocationTests.swift      # 新規
├── HistoryNavigatorTests.swift     # 新規
├── BrowserModelHistoryTests.swift  # 新規（onLocationEvent・resolveHistoryLocation・showHistoryLocation）
├── ArchiveIndexTests.swift         # 追加（containsDirectory）
└── PaneLayoutTests.swift           # 追加（canNavigateHistory）

Tests/MediaViewerPerformanceTests/
└── PerformanceBaselineTests.swift  # 追加（10,000 ファイルのフォルダへ戻る。SC-029）
```

`MainWindowController` は変更しない（ツールバーは `MainToolbarController` が作る）。`ListModeView`・`ThumbnailModeView` も変更しない
（復元した選択へのスクロールは既存の選択の反映で行われる。R74）。`HistoryNavigator` は `MainSplitViewController` が作り、
`MainToolbarController`・`DirectoryTreeViewController`・`FileOperationCoordinator`・`FileListViewController` には参照かコールバックで渡す。

**Structure Decision**: 既存の Swift Package 構成のまま。履歴の規則・場所の確認・復元の手順は `MediaViewerCore`（新しい `History/`）、
ツールバー・メニュー・App が持つ表示の状態の読み書きは `MediaViewerApp` に置く。

## 実装の順序と依存（tasks.md の参考）

1. Core の値型: `HistoryEntry.swift`（`HistoryLocation` ほか）→ `NavigationHistory`。`ArchiveIndex.containsDirectory`・
   `PaneCommands.canNavigateHistory` は独立（並列にできる）
2. `BrowserModel` の変更: `onLocationEvent` と呼び出し元ごとの理由、`historyLocation`、`resolveHistoryLocation`・`showHistoryLocation`
   （1 の `HistoryLocation`・`containsDirectory` に依存）
3. `HistoryNavigator`（1・2 に依存）: 記録の契機・戻る・進むのキュー・検索結果の表示中・取り除きの契機
4. App（3 に依存）: `MainSplitViewController`（所有・ホスト・アクション）→ `MainMenu`・`MainToolbarController`・`FileListViewController`・
   `DirectoryTreeViewController`・`FileOperationCoordinator`
5. 性能テスト、GUI の確認（quickstart.md）

`BrowserModel.swift`・`MainSplitViewController.swift` を触るタスクはそれぞれ同じファイルのため直列にする（AGENTS.md の worktree 規約）。

## Complexity Tracking

違反なし。
