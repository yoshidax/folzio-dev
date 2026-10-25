---

description: "Task list for 操作の履歴を戻る・進む"
---

# Tasks: 操作の履歴を戻る・進む

**Input**: Design documents from `/specs/004-navigation-history/`

**Prerequisites**: plan.md, spec.md, research.md（R68〜R78）, data-model.md, contracts/, quickstart.md

**Tests**: 憲章 原則 IV（テスト必須）により、`MediaViewerCore` の判断ロジックと異常系には自動テストを付ける
（data-model.md の「テスト」の表）。各テストタスクは対応する実装タスクの前に書き、ビルドエラーまたは失敗になることを確かめてから実装する。
ツールバー・メニュー・ショートカット・ツリーの見た目の同期・VoiceOver は、quickstart.md の手動確認で検証する（R78）。

**Organization**: spec.md のユーザーストーリーは US7（フォルダの戻る・進む、P2）と US8（表示の変更を戻す・やり直す、P3）。
この feature の中では US7 が MVP。履歴の値型（場所・表示の状態・履歴の列の基本の規則）は両方が使うため Phase 2 に置く。
各履歴は記録の時点の表示の状態を持ち、戻る・進むはそれを復元する（FR-108）ため、表示の状態の**復元**は US7 に、
表示の変更の**記録**（サイズの変更のまとめを含む）は US8 に置く。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US7, US8)
- Include exact file paths in descriptions

## Path Conventions

- Core（AppKit 非依存）: `Sources/MediaViewerCore/`（新しい `History/` を作る）
- UI（AppKit）: `Sources/MediaViewerApp/`
- テスト: `Tests/MediaViewerCoreTests/`・`Tests/MediaViewerPerformanceTests/`。一時ディレクトリは FixtureKit（`@testable import FixtureKit`）で作り、
  テスト後に消す。`BrowserModel` を使うテストは `Tests/MediaViewerCoreTests/BrowserModelFolderTests.swift` の `Env`・`makeEnv` と同じ形
  （`/private/var/...` の表記の一時フォルダ・専用の `UserDefaults` スイート）にする。zip は `ZipFixtureWriter` で作る
- 共通ルール: Swift 6 strict concurrency。Core から `import AppKit` しない。ネットワーク API は使わない。
  stat・zip の索引の作成・ディレクトリ列挙を UI スレッドで行わない
- 変更しないファイル: `Sources/MediaViewerApp/App/MainWindowController.swift`・`ListModeView.swift`・`ThumbnailModeView.swift`（plan.md）
- コードのコメントでは判断の根拠を `R68` のように research.md の番号で参照する
- 同じファイルを触るタスクは並列にしない（AGENTS.md の worktree 規約）:
  `NavigationHistory.swift`（T005・T009・T027）、`NavigationHistoryTests.swift`（T003・T006・T025）、`BrowserModel.swift`（T014・T015）、
  `BrowserModelHistoryTests.swift`（T012・T013）、`HistoryNavigator.swift`（T017・T028）、`HistoryNavigatorTests.swift`（T016・T026）、
  `FileListViewController.swift`（T018・T029）、`MainSplitViewController.swift`（T021・T030）

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 変更前の状態が健全であることを確かめる。新しいターゲットや外部依存は追加しない

- [x] T001 ブランチ `004-navigation-history` で、変更前に `swift build` と `swift test` が通ることを確かめる。失敗があれば
  この feature の変更に入る前にユーザーへ報告する（既存の失敗をこの feature で直さない）

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: US7・US8 の両方が使う履歴の値型と、履歴の列の基本の規則（記録・移動・分岐・上限）。ファイルを使わない純粋なロジック（R68）

**⚠️ CRITICAL**: この Phase が終わるまで US7・US8 に入らない

### Tests（Foundational）

> **NOTE: 先に書き、ビルドエラーになることを確かめてから T004・T005 を実装する**

- [x] T002 [P] `Tests/MediaViewerCoreTests/HistoryLocationTests.swift` を新規作成する（`@Suite("HistoryLocation")`、Swift Testing）。T004 の前にビルドエラーになることを確かめる（R69）:
  - `==`: `/tmp/h/A` と `/tmp/h/A/`（`isDirectory: true`）、`/tmp/h/./A`、`/tmp/h/x/../A` は同じ。`/tmp/h/A` と `/tmp/h/B` は違う。
    `archive` が nil と非 nil は違う。zip の中は `ArchiveLocation(archive: /tmp/h/A/t.zip, directory: "d/")` どうしで、zip のパスの表記の違い
    （`/tmp/h/A/./t.zip`）は同じ、`directory` が `"d/"` と `"e/"` は違う（文字列のまま比べる）。存在しないパスでも比べられる
  - `isWithin(_:)`: `folder` が `url` 自身・配下なら true。`/tmp/h/Photo` は `/tmp/h/Photos` の配下ではない（兄弟の前方一致を配下にしない）。
    zip の中の場所は `archive.archive` が `url` 自身（zip ファイル）か配下なら true（`folder` が `url` の配下でなくても）。
    `url = /` ならすべて true。関係のない場所は false
  - `rebased(by:)`: `RenamedFolder(from: /tmp/h/A, to: /tmp/h/A2)` で、`folder == /tmp/h/A` → `/tmp/h/A2`、`/tmp/h/A/B` → `/tmp/h/A2/B`、
    zip の中（`folder == /tmp/h/A`・`archive.archive == /tmp/h/A/t.zip`・`directory == "d/"`）→ 両方が付け替わり `directory` は同じ。
    `/tmp/h/Other`・`/tmp/h/A3` は nil
  - `HistoryEntry.hasSameState(as:)`: `location` と `viewState` が同じなら `focusedItem` が違っても true。`viewState` の5つの値
    （`displayMode`・`thumbnailSize`・`paneLayout`・`mediaTypeFilter`・`showsZipFiles`）のどれか1つが違えば false
- [x] T003 [P] `Tests/MediaViewerCoreTests/NavigationHistoryTests.swift` を新規作成する（`@Suite("NavigationHistory")`）。場所は `HistoryLocation(folder: /tmp/n/A)` などの
  存在しないパスでよい（ファイルを作らない）。テスト用に `entry(_ name:, displayMode: = .list, ...)` の小さなヘルパーを置く。T005 の前にビルドエラーになることを確かめる
  （FR-107・FR-110・FR-111、R68）:
  - `init()` は `current == nil`・`count == 0`・`canGoBack == false`・`canGoForward == false`
  - 最初の `record(..., kind: .navigation, leavingFocus: nil)` は true を返し、`backEntries == []`・`current` が A・`canGoBack == false`（FR-111 の起動直後）
  - A → B → C の記録で `backEntries == [A, B]`（古い順）・`current == C`。現在と同じ状態の `record` は false を返し、`backEntries`・`current`・`forwardEntries`・`version` が変わらない
  - `record` の `leavingFocus` が、戻る側へ移した直前の履歴の `focusedItem` に入る。新しい履歴の `focusedItem` は nil
  - `candidate(.back)` は戻る側の末尾、`candidate(.forward)` は進む側の先頭。なければ nil
  - `move(.back, leavingFocus: f)` は C の `focusedItem = f` にして進む側の先頭へ移し、B を現在にして返す。2回目で A、`forwardEntries == [B, C]`（近い順）。
    候補がない方向の `move` は nil を返し何も変えない
  - 分岐: A → B → C、戻る×2 の後に E を記録すると `backEntries == [A]`・`current == E`・`forwardEntries == []`（US7-AS5）
  - 上限: 150 件の異なる場所を記録すると `count == 100`、`backEntries.first` が 51 件目、`move(.back)` がちょうど 99 回成功し 100 回目は nil（FR-110、US7-AS8、SC-031）
  - 進む側がある状態で記録して 100 件を超えないこと（進む側を取り除いてから数える）
  - `version` は変更のたびに増え、変更のない操作では変わらない。`allEntries` は戻る側・現在・進む側の順

### Implementation（Foundational）

- [x] T004 [P] `Sources/MediaViewerCore/History/HistoryEntry.swift` を新規作成する（contracts/core-api.md の「履歴の値型」）: `HistoryLocation`（`folder: URL`・`archive: ArchiveLocation?`、
  `==` は `folder`・`archive.archive` を「`.`・`..` を取り除いたパスの文字列」（`RenamedFolder` と同じ正規化。`standardizedFileURL` を使わない。R69）で、
  `archive.directory` は文字列のまま比べる。`isWithin(_:)` は `pathComponents` を区切りの `/` まで比べる。`rebased(by:)` は `RenamedFolder.rebase` で
  `folder` と `archive.archive` を付け替え、どちらも関係しなければ nil）、`HistoryPresentation`（`displayMode: DisplayMode`・`thumbnailSize: Double`・`paneLayout: PaneLayout`）、
  `HistoryViewState`（`presentation`・`mediaTypeFilter: MediaTypeFilter`・`showsZipFiles: Bool`）、`HistoryEntry`（`location`・`viewState`・`focusedItem: URL?`、
  `hasSameState(as:)` は `location` と `viewState` だけを比べる）、`HistoryRecordKind`（`.navigation`・`.viewChange`・`.thumbnailSize`）、`HistoryDirection`（`.back`・`.forward`）。
  すべて `Sendable`・`Equatable`。`thumbnailSize` は `ViewSettings.clampThumbnailSize` 済みの値を入れる前提とし、型では丸めない。
  `PaneLayout`・`MediaTypeFilter`・`DisplayMode` が `Sendable`・`Equatable` でなければ準拠を足す。T002 を通す
- [x] T005 `Sources/MediaViewerCore/History/NavigationHistory.swift` を新規作成する（`public struct NavigationHistory: Sendable`、`capacity = 100`）。
  この時点では `init`・`count`・`canGoBack`・`canGoForward`・`version`・`allEntries`・`record(location:viewState:kind:leavingFocus:)`・`candidate(_:)`・`move(_:leavingFocus:)` を実装する
  （data-model.md の表）。`record` は `kind` を非公開の `lastRecordKind` に保存するだけで、サイズの変更のまとめは T027 で足す。`move` は `lastRecordKind = nil` にする。
  現在が nil のときの `record` は新しい履歴を現在にして進む側を取り除く（戻る側は変えない）。T003 を通す（T004 の後）

**Checkpoint**: 履歴の値型と基本の規則が `swift test --filter NavigationHistoryTests` と `HistoryLocationTests` で通る

---

## Phase 3: User Story 1 - 移動したフォルダを戻る・進む（US7、Priority: P2）🎯 MVP

**Goal**: ツリーの選択・ファイルリストでのフォルダ・zip の移動・`..`・⌘↑ を履歴に記録し、ツールバーの `<`・`>`、⌘[・⌘]、「移動」メニューで
戻る・進む。移った先の場所と記録時の表示の状態・フォーカス行を復元し、ツリーの選択を同期する。見つからない場所は飛ばして取り除き、
アプリの中と外の名前の変更・ゴミ箱・移動・ボリュームの取り外しで履歴を直す。検索結果の表示中の「戻る」は Esc と同じく検索結果の表示を終える
（FR-107（1）（2）・FR-108〜FR-113、EC-54〜EC-65、US7-AS1〜AS13）

**Independent Test**: `swift test` で T006〜T016 のテストが通ること。`.app` で quickstart.md の「3. 手動確認」1〜12・20〜24 を行い、
A → B → C を選んで ⌘[ ×2 で A に戻り ⌘] で B に進むこと、外部で B を消すと飛ばすこと、再起動で `<`・`>` が淡色であること

### Tests for User Story 1（履歴の列の取り除き・Core の部品）

> **NOTE: 先に書き、ビルドエラーまたは失敗になることを確かめてから T009〜T011 を実装する**

- [x] T006 [P] [US7] `Tests/MediaViewerCoreTests/NavigationHistoryTests.swift` に取り除き・置き換え・まとめのケースを追加する（FR-109、EC-54・EC-58〜EC-60・EC-62・EC-65、R75）。T009 の前に失敗することを確かめる:
  - `dropCandidate(.back)`: A → B → C で B を取り除くと `backEntries == [A]`・`current == C`。続けて `move(.back)` で A（US7-AS6）。戻る側がすべて見つからない場合に
    `dropCandidate` を繰り返すと `backEntries == []` になり、`current` と `forwardEntries` は変わらない（EC-54）
  - まとめ（EC-59）: A → B → A' （A と同じ状態）で B を取り除くと、隣り合う A と A' が1つになり現在の A' が残る。現在を含まない組は新しい方を残す
    （`focusedItem` は残した方のもの）
  - `removeEntries(within: [/tmp/n/B], keepingCurrent: true)`: B とその配下（`/tmp/n/B/x`）と、zip が B の配下にある zip の中の履歴を取り除き、
    `/tmp/n/B2`（兄弟の前方一致）は残す。現在が B でも残る。`keepingCurrent: false` なら現在も取り除いて nil にする（US7-AS7）
  - `removeEntries(at:)`: `allEntries` の添字で指定した履歴を取り除く（現在を含めば nil になる）。範囲外の添字は無視する
  - `renameFolder(RenamedFolder(from: B, to: B2))`: 現在が B なら B2 に置き換え、戻る側・進む側の B とその配下は取り除く（新しい名前に追従させない。FR-109）。
    現在が B の配下（`B/x`）なら `B2/x` に置き換える。関係がなければ何も変えず `version` も変えない
  - `replaceCurrentLocation(P)`: 現在の場所だけを P にし、表示の状態と進む側は変えない。1つ前が P と同じ状態ならまとめる（EC-60）
  - `detachCurrent()`: 現在を戻る側の末尾へ移して nil にする。進む側は残す（EC-62）。`removeCurrent()`: 現在を取り除いて nil にし、ほかは残す（EC-65）
  - 現在が nil の状態: `candidate(.back)` は戻る側の末尾、`candidate(.forward)` は進む側の先頭。`move(.back)` で現在になり、離れる履歴はない（反対側へ何も足さない）。
    `record` で新しい履歴が現在になり進む側が消える（EC-65 の最後の文）
  - `updateCurrentViewState(_:)`: 現在の表示の状態だけを書き換え、1つ前と同じ状態になればまとめる（R76）
  - data-model.md の「状態の遷移の例」の6行を1つのテストで順に再現する
- [x] T007 [P] [US7] `Tests/MediaViewerCoreTests/ArchiveIndexTests.swift` に `containsDirectory(_:)` のケースを追加する（R73）。T010 の前にビルドエラーになることを確かめる:
  最上位 `""` は true。`a/`・`a/b/` を持つ zip で `containsDirectory("a/")`・`("a/b/")` は true、`("c/")`・`("a/c/")` は false。ディレクトリの項目を持たず
  `a/b/1.jpg` だけを持つ zip（暗黙のディレクトリ）でも `("a/")`・`("a/b/")` は true。ファイルのパス `("a/b/1.jpg")` は false
- [x] T008 [P] [US7] `Tests/MediaViewerCoreTests/PaneLayoutTests.swift` に `PaneCommands.canNavigateHistory` のケースを追加する（FR-112）。T011 の前にビルドエラーになることを確かめる:
  `isFullScreen`・`isEditingText` の4つの組み合わせを `@Test(arguments:)` で、両方 false のときだけ true。`layout` が `.all`・ファイルリストのみ・プレビューのみの
  どれでも結果が変わらない（ペインを隠していても使える。FR-108 の最後の文）

### Implementation for User Story 1（履歴の列の取り除き・Core の部品）

- [x] T009 [US7] `Sources/MediaViewerCore/History/NavigationHistory.swift` に `dropCandidate(_:)`・`updateCurrentViewState(_:)`・`replaceCurrentLocation(_:)`・`detachCurrent()`・
  `removeCurrent()`・`removeEntries(within:keepingCurrent:)`・`removeEntries(at:)`・`renameFolder(_:)` と、非公開のまとめ（EC-59。戻る側・現在・進む側を1列に並べ、
  隣り合う `hasSameState` の組を、現在を含むなら現在を、含まなければ新しい方を残して1つにする）を実装する。各操作の最後にまとめ、変更があれば `version` を増やす。
  `removeCurrent()` は `lastRecordKind = nil` にする。配下の判定は `HistoryLocation.isWithin`、付け替えは `rebased(by:)` を使う（R75）。T006 を通す（T005 の後）
- [x] T010 [P] [US7] `Sources/MediaViewerCore/Archive/ArchiveIndex.swift` に `public func containsDirectory(_ path: String) -> Bool` を追加する（R73）。`path.isEmpty` なら true。
  それ以外は `children[path] != nil`、または `entries[path]` がディレクトリの項目なら true（索引の作成で暗黙のディレクトリも `entries`・`children` に入っていることを
  コードで確かめ、足りなければ `children` の値（子のパスの配列）に `path` が含まれるかも見る）。T007 を通す
- [x] T011 [P] [US7] `Sources/MediaViewerCore/Model/PaneLayout.swift` の `PaneCommands` に `public var canNavigateHistory: Bool { !isFullScreen && !isEditingText }` を追加し、
  ドキュメントコメントに「⌘[・⌘]・「移動」メニュー・ツールバーの戻る・進む（FR-112）。履歴の有無は `HistoryNavigator` と AND を取る」と書く。T008 を通す

### Tests for User Story 1（BrowserModel の通知・確認・表示）

> **NOTE: T004 の後に書き、ビルドエラーまたは失敗になることを確かめてから T014・T015 を実装する**

- [x] T012 [P] [US7] `Tests/MediaViewerCoreTests/BrowserModelHistoryTests.swift` を新規作成し（`@Suite("BrowserModel の履歴") @MainActor`）、場所の通知のケースを書く（R70、data-model.md の
  「LocationEvent」の表）。一時フォルダ `root` に `A/1.jpg`・`A/2.jpg`・`A/Sub/3.jpg`・`B/`・`A/album.zip`（中に `d/e/4.jpg`）を作り、`model.onLocationEvent` に渡された通知を配列に集める:
  - `selectFolder(A)` → `[.navigated(leavingFocus: nil)]`。A で `2.jpg` をフォーカスしてから `selectFolder(B)` → `.navigated(leavingFocus: A/2.jpg)`（`resetForNavigation` の前の値）
  - `openItem(A/Sub)`・`openItem(..)`・`goToEnclosingLevel()`・`openItem(album.zip)`・zip の中の `openItem(d/)`・zip の中の `goToEnclosingLevel()`・zip の最上位からの
    `goToEnclosingLevel()` がそれぞれちょうど1件の `.navigated` を出す（`navigateToFolder` から `selectFolder` を呼んでも2件にならない）
  - 通知を受け取った時点で `model.historyLocation` が移った先の場所になっている（同期の通知。zip の中なら `archive` が入っている）
  - `startSearch` は通知しない。検索結果の表示中は `historyLocation == nil`。検索結果の表示中の `selectFolder(listing.folder)`（Esc）は `.navigated` を出す
  - 表示中の `A/Sub` をテストの中で削除して `handleFileSystemEvent([A/Sub])` → `.relocated(vanished: [A/Sub])` だけ（`.navigated` を出さない）
  - zip の中を表示中に zip を削除して `handleFileSystemEvent([A])` → `.relocated(vanished: [A/album.zip])`。zip を書き換えた（存在する）場合は `.relocated(vanished: [])`
  - `leaveTrashedFolders([A])`（A の配下を表示中）→ `.relocated(vanished: [A])`
  - 存在しない `root/Missing` を `selectFolder` → `.navigated` の後に `.notFound(HistoryLocation(folder: root/Missing))`。その後 `historyLocation == nil`。
    読み込みの途中で別のフォルダへ移った（世代が古い）場合は `.notFound` を出さない
  - `reloadCurrentFolder()`・`didRenameFolder(from:to:)`・`setMediaTypeFilter`・`setShowsZipFiles` は通知しない
- [x] T013 [US7] `Tests/MediaViewerCoreTests/BrowserModelHistoryTests.swift` に `resolveHistoryLocation` と `showHistoryLocation` のケースを追加する（R73・R74、EC-55〜EC-57・EC-64。T012 の後）:
  - 確認: 存在するフォルダは `.available`。削除したフォルダ・ファイル（ディレクトリでない）は `.missing`。権限のないフォルダ（`chmod 000`。テスト後に戻す）は `.available`（EC-55）。
    zip の最上位・存在する `d/`・`d/e/` は `.available`、存在しない `x/` は `.missing`。削除した zip は `.missing`。壊れた zip（ゼロバイトなど）は `.available`（EC-56）
  - 確認の途中に `selectFolder(B)` で移ると `.superseded`（確認の `await` 中に移動を挟む）
  - 確認中も `listing`・`selection` は変わらない（表示を変えない）
  - 表示（通常のフォルダ）: `showHistoryLocation(resolved(A), focusing: A/2.jpg)` は読み込みの完了を待たずに戻り、読み込みの後に `selection == {A/2.jpg}`・
    `focused == A/2.jpg`・`preview` が `.image`。`treeSyncRequest?.folder == A` に新しい id で出る。`lastFolder == A`。`onLocationEvent` は呼ばれない
  - `focusing` が消えたファイル・nil・種類フィルタで隠れた動画のときは何も選択せず `preview == .empty`（EC-64）
  - 表示（zip の中）: `d/e/` を表示し、`listing.folder == A`・`listing.archive?.directory == "d/e/"`、`treeSyncRequest?.folder == A`（zip を含むフォルダ。FR-108）。
    続けて `goToEnclosingLevel()` で `d/` に戻れる（索引が使われている）。壊れた zip では `listing.state == .failed(...)` で `..` の行だけがある（EC-24 と同じ）
  - 権限のないフォルダを表示すると `listing.state == .denied`（EC-55）
  - 世代が古い `ResolvedHistoryLocation`（確認の後に `selectFolder(B)` した）を渡すと何もしない
  - 再生中の動画のプレビューがある状態で表示すると `stopPlaybackSignal` が増える（FR-034）

### Implementation for User Story 1（BrowserModel）

- [x] T014 [US7] `Sources/MediaViewerCore/Browser/BrowserModel.swift` に場所の通知を追加する（R70、contracts/core-api.md）:
  - `public enum LocationEvent`（`.navigated(leavingFocus:)`・`.relocated(vanished:)`・`.notFound(HistoryLocation)`）と、`@ObservationIgnored public var onLocationEvent: ((LocationEvent) -> Void)?`
  - `public var historyLocation: HistoryLocation?`: 検索結果の表示中と、通常のフォルダの読み込みが「見つからない」で終わった表示では nil。それ以外は
    `HistoryLocation(folder: listing.folder, archive: listing.archive)`。「見つからない」は非公開のフラグ（`loadFolder`・`reloadCurrentFolder` の `.notFound` で立て、
    `resetForNavigation` で下ろす）で判断し、メッセージの文字列で比べない
  - 内部の `selectFolder`・`navigateToFolder`・`returnToFolder`・`openArchive` に理由の引数を足す。公開の `selectFolder(_:)` は `.navigated`、`openItem`・`goToEnclosingLevel` は `.navigated`、
    `handleFileSystemEvent` の親への移動は `.relocated(vanished: [元の listing.folder])`、zip の変化による `returnToFolder` は zip ファイルの存在を見て
    `.relocated(vanished: [zip] または [])`、`leaveTrashedFolders` は `.relocated(vanished: trashed)`。zip の中の階層の移動（`openItem` の `.directory`、`goToEnclosingLevel` の
    `showArchiveLevel`）も `.navigated`
  - 通知は `listing` を新しい場所にした直後（読み込みの `await` の前）に1回だけ出す。`leavingFocus` は `resetForNavigation()` の前の `selection.focused`
  - `loadFolder` が `.notFound` で終わり、世代が今のもので `listing.folder == url` のときに `.notFound(HistoryLocation(folder: url))` を出す
  - `startSearch`・`reloadCurrentFolder`・`didRenameFolder`・`didRenameItem`・表示の setter は通知しない。既存の公開 API のシグネチャは変えない。T012 を通す
- [x] T015 [US7] `Sources/MediaViewerCore/Browser/BrowserModel.swift` に確認と表示を追加する（R73・R74。T014 の後）:
  - `public struct ResolvedHistoryLocation: Sendable`（`location` と、非公開の確認を始めたときの `navigationGeneration`・zip の索引（`ArchiveIndex?`）・開けなかった理由（`ArchiveError?`））、
    `public enum HistoryLocationResolution: Sendable { case available(ResolvedHistoryLocation), missing, superseded }`
  - `resolveHistoryLocation(_:) async`: 通常のフォルダは `Task.detached` の `fileExists(atPath:isDirectory:)` で、存在してディレクトリなら `.available`（読めるかは見ない）。
    zip の中は `Task.detached` で zip ファイルが存在して通常のファイルか見る。なければ `.missing`。あれば、今表示している zip と同じ（`archiveIndex` があり、zip のパスが同じ）なら
    その索引を使い、違えば `archiveReader.open` で開く。開けなければ理由を持って `.available`。開けたら `index.containsDirectory(location.archive!.directory)` が false なら `.missing`。
    確認の後に `navigationGeneration` が変わっていれば `.superseded`
  - `showHistoryLocation(_:focusing:)`: 世代が古ければ何もしない。`resetForNavigation()`・`leaveSearchIfNeeded()`・`archiveRenames.removeAll()` の後、`treeSyncRequest` を新しい id で
    `location.folder` に出し、`lastFolder` を `location.folder` に保存する（`selectFolder` と同じ書き方）。通常のフォルダは `listing = FolderListing(folder:..., state: .loading)` にして
    `listingTask` で `loadFolder` し、読み込みの後に世代が同じで `focusing` の行（`standardizedFileURL` で比べる）が `listing.files` にあればその行だけを `select` する。
    zip の中は `listing` の `folder` を `location.folder` にしてから、索引があれば `archiveIndex = index` で `showArchiveLevel` し、すぐに同じ規則で `focusing` を選択する。
    開けなかった理由があれば `loadArchive` の失敗と同じ表示にする。`onLocationEvent` は呼ばない。T013 を通す

### Tests for User Story 1（HistoryNavigator）

> **NOTE: T009・T015 の後に書き、ビルドエラーになることを確かめてから T017 を実装する**

- [x] T016 [US7] `Tests/MediaViewerCoreTests/HistoryNavigatorTests.swift` を新規作成する（`@Suite("HistoryNavigator") @MainActor`）。T012 と同じ形の一時フォルダ（`A`・`B`・`C`・`E`・`A/Sub`・`A/album.zip`）と
  `BrowserModel`、`HistoryPresentationHost` に準拠するスタブ（`historyPresentation` を返し、`applyHistoryPresentation` の引数を配列に記録して自身の値を書き換える）を使う。
  ナビゲーターは `HistoryNavigator(model:)` の後に `presentationHost = stub` を設定してから最初の `selectFolder` を呼ぶ。各 `goBack()`・`goForward()` の後は `await waitUntilIdle()`、
  読み込みの完了は既存のテストと同じ待ち方で待つ（R72〜R76）:
  - 起動: 最初の `selectFolder(A)` の後 `history.count == 1`・`canGoBack == false`・`canGoForward == false`（FR-111、US7-AS9）
  - US7-AS1・AS2: A → B → C を選び、`goBack()` ×2 で `listing.folder == A`・`treeSyncRequest?.folder == A`・`canGoForward == true`。`goForward()` で B、もう一度で C・`canGoForward == false`
  - US7-AS3: A で `Sub` の行をフォーカスして `openItem(A/Sub)`、`goBack()` で A の一覧の選択が `{A/Sub}` だけ。`goForward()` で `A/Sub`
  - US7-AS4: A → `album.zip` → `d/` → `d/e/` と開き、`goBack()` のたびに `d/`・最上位・A の一覧に戻る。どの場合も `treeSyncRequest?.folder == A`
  - US7-AS5: A → B → C、戻る×2、`selectFolder(E)` で `canGoForward == false`・`history.backEntries.count == 1`
  - US7-AS6: A → B → C で B を削除して `goBack()` → A。`history.forwardEntries` が C だけ。`goForward()` で C
  - EC-54: A → B → C で A・B を削除して `goBack()` → `listing.folder == C` のまま・`canGoBack == false`
  - US7-AS7: A → B で `didRemoveItems([A])` → `canGoBack == false`。`didRenameFolder(from: A, to: A2)`（B を表示中）でも同じ。`didRenameItem(from: album.zip, to: x.zip)` で zip の中の履歴だけが消える
  - 名前の変更で現在が置き換わる: A を表示中に `didRenameFolder(from: A, to: A2)` → `history.current?.location.folder == A2`（FR-109）
  - EC-60: A → A/Sub で A/Sub を削除して `model.handleFileSystemEvent([A/Sub])` → 現在の場所が A に置き換わり、1つ前の A とまとまる（`canGoBack == false`）。進む側は残る
  - EC-62: B → `root/Missing`（存在しない）を選ぶ → `history.current == nil`・`backEntries` の末尾が B・進む側は記録の前のまま。`goBack()` で B（「見つからない」表示を履歴に入れない）
  - EC-65: A → B を表示中に B をテストの中で削除して `revalidateAll()`（`HistoryNavigator` 側だけで確かめる。`BrowserModel.handleFileSystemEvent` は親へ移るため通さない。
    実際の取り外しの経路は quickstart 26 で確かめる）→ 現在が取り除かれ、`goBack()` で A
  - 外部の変更: A → B → C を表示中に B を削除して `handleFileSystemEvent([root])` → `goBack()` を待たずに `history.backEntries` から B が消えている。関係のないフォルダのイベントでは何も消えない
  - EC-55: 権限のないフォルダ L → A で `goBack()` → `listing.folder == L`・`listing.state == .denied`。履歴から取り除かない
  - EC-61（連打）: A → B → C → E で `goBack()` を3回続けて呼び、`waitUntilIdle()` の後に `listing.folder == A`（読み込みの後）・`history.current` が A
  - 確認中のユーザーの移動: `goBack()` の直後（確認の `await` 中）に `selectFolder(E)` → 要求は捨てられ、`listing.folder == E`・`history.current` が E・進む側なし
  - US7-AS11: A で `startSearch` し、`canGoBack == true`・`canGoForward == false`。`goBack()` で検索が終わり `listing.folder == A`・`isShowingSearchResults == false`、
    `history.count` と `current` の場所は変わらない。`canGoForward == false`（検索結果は進む側に入らない）
  - US7-AS12: 起動直後（1件）に `startSearch` → `canGoBack == true`、`goBack()` の後 `canGoBack == false`
  - US7-AS13: A → `album.zip` → `Sub` を開き、`Sub` を表示したまま `startSearch` → `goBack()` で検索が終わり A の一覧に戻り、
    A が新しい履歴として記録される。`canGoBack == true` のままでもう一度 `goBack()` で zip の中の `Sub` に戻る
  - FR-113: 検索結果の表示中に `selectFolder(B)` → B が新しい履歴として記録される
  - 表示の状態の復元: A をスタブの `displayMode = .list` で記録し、スタブを `.thumbnails` に変えてから B を選ぶ。`goBack()` でスタブの `applyHistoryPresentation` に `.list` が渡る。
    A を `MediaTypeFilter(imagesOnly: true)` で記録した場合は `model.mediaTypeFilter` が戻る（FR-056 の変更）
  - FR-108（場所が同じ候補）: 現在と同じ場所で表示の状態だけが違う履歴へ `goBack()` すると、`resolveHistoryLocation` を呼ばず（`listing` を作り直さない。`selection` が保たれる）表示の状態だけを戻す
    （この時点では `recordViewChange` がないため、表示の状態を変えてから A → A/Sub と移り、Sub を削除して `handleFileSystemEvent([A/Sub])` の `.relocated` で
    現在の場所を A に置き換え、隣が「同じ場所で表示の状態が違う」履歴になる経路で準備する。EC-60 のケースと同じ）

### Implementation for User Story 1（HistoryNavigator）

- [x] T017 [US7] `Sources/MediaViewerCore/History/HistoryNavigator.swift` を新規作成する（contracts/core-api.md、data-model.md の「HistoryNavigator」、R72〜R76）:
  - `@MainActor public protocol HistoryPresentationHost: AnyObject`（`historyPresentation`・`applyHistoryPresentation(_:)`）
  - `@MainActor @Observable public final class HistoryNavigator`: `history`（`private(set)`）、`canGoBack`（`model.isShowingSearchResults || history.canGoBack`）、
    `canGoForward`（`!model.isShowingSearchResults && history.canGoForward`）、`weak var presentationHost`。`init(model:)` で `model.onLocationEvent` に `[weak self]` で自身を設定する
  - 今の表示の状態は `HistoryViewState(presentation: host.historyPresentation, mediaTypeFilter: model.mediaTypeFilter, showsZipFiles: model.showsZipFiles)`。
    `presentationHost` が nil のときは記録しない（App は `init` の直後に設定する）
  - `.navigated(leavingFocus:)`: `model.historyLocation` が nil なら何もしない。現在と場所が同じなら `updateCurrentViewState`（R76）。違えば記録の前の `history` と記録した場所を
    非公開の控えに取ってから `record(kind: .navigation, leavingFocus:)`
  - `.relocated(vanished:)`: `historyLocation` があれば `replaceCurrentLocation`、続けて `removeEntries(within: vanished, keepingCurrent: true)`
  - `.notFound(location)`: 控えがあり、記録した場所が `location` で、その後に `history.version` が記録の直後から変わっていなければ、控えに戻して `detachCurrent()`。
    そうでなく `history.current?.location == location` なら `removeCurrent()`。どちらでも控えを捨てる
  - `goBack()`・`goForward()`: 要求をキューに積み、処理中でなければ処理の `Task` を始める。処理は1件ずつ R72 の 1〜6 の順:
    検索結果の表示中の `.back` は `model.selectFolder(model.listing.folder)` で検索結果の表示を終える（`.navigated` で現在の表示の状態が書き換わる）。`.forward` は何もしない。
    候補がなければ何もしない。候補の場所が `model.historyLocation` と同じなら `move` して表示の状態だけを復元する。違えば `history.version` を控えて
    `resolveHistoryLocation` し、`.missing` なら（版が変わっていなければ）`dropCandidate` して次の候補へ、`.superseded` か版が変わっていればこの要求を捨てる。
    `.available` なら `move(direction, leavingFocus: model.selection.focused)`、`showHistoryLocation(resolved, focusing: entry.focusedItem)`、表示の状態の復元
  - 表示の状態の復元: `model.setMediaTypeFilter`・`model.setShowsZipFiles`、`presentationHost?.applyHistoryPresentation`。場所を変える場合は `showHistoryLocation` の後に行う（R74）
  - `waitUntilIdle()`: 処理の `Task` が終わるまで待つ（キューが空になるまで）
  - `didRenameFolder(from:to:)` → `renameFolder`、`didRenameItem(from:to:)` → `removeEntries(within: [from], keepingCurrent: false)`、`didRemoveItems(_:)` → `removeEntries(within:keepingCurrent: true)`
  - `handleFileSystemEvent(_ folders:)`: `allEntries` のうち場所（zip の中は zip ファイル）が `folders` のどれかの配下を指すものの添字とパスを控え、`Task.detached` で存在を確かめる
    （フォルダはディレクトリとして、zip はファイルとして）。`history.version` が控えたときと同じなら、見つからないものを `removeEntries(at:)`。`revalidateAll()` はすべての履歴で同じことをする
  - `recordViewChange` は US8（T028）で足す。T016 を通す

### Implementation for User Story 1（App）

- [x] T018 [P] [US7] `Sources/MediaViewerApp/FileList/FileListViewController.swift` に記録しない復元の setter `func restore(displayMode: DisplayMode, thumbnailSize: Double)` を追加する（R74）。
  既存の `setDisplayMode(_:)` と `setThumbnailSize(_:persist: true)` を呼ぶ（保存は FR-003 に従う。ツールバー・メニューの表示は既存の `onViewStateChange`・`updateViewMenuState` で揃う）。
  名前の変更中のガードは付けない（呼び出し元の戻る・進むが名前の変更中は無効のため）
- [x] T019 [P] [US7] `Sources/MediaViewerApp/Operations/FileOperationCoordinator.swift` に `weak var historyNavigator: HistoryNavigator?` を追加し、成功した操作を知らせる（R75）:
  - `rename`: フォルダなら `model.didRenameFolder(from:to:)` の直後に `historyNavigator?.didRenameFolder(from: file, to: renamed)`、ファイルなら `didRenameItem(at:to:)` の直後に
    `historyNavigator?.didRenameItem(from: file, to: renamed)`
  - `trash`: `trashedSources` を求めた直後、`model.leaveTrashedFolders` の前に `historyNavigator?.didRemoveItems(trashedSources)`
  - `transfer`（`kind == .move` のときだけ）: 中止（`.abort`）しなかった元の場所のうち、`result.failed` に含まれないものを集め、`reloadCurrentFolder` の前に `didRemoveItems` に渡す
    （`result.succeeded` は移動先の URL のため使わない）
- [x] T020 [P] [US7] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` に `weak var historyNavigator: HistoryNavigator?` を追加し、`eventTask` で
  `await self.model.handleFileSystemEvent(changed)` の直後に `await self.historyNavigator?.handleFileSystemEvent(changed)`、`volumeTask` で `applyRoots(newRoots)` の後に
  `await self.historyNavigator?.revalidateAll()` を呼ぶ（R75。外部の変更で表示中の場所が消えたときは、`BrowserModel` の `.relocated` が先に現在を置き換える）
- [x] T021 [US7] `Sources/MediaViewerApp/App/MainSplitViewController.swift` を変更する（R74・R77。T017〜T020 の後）:
  - `let historyNavigator: HistoryNavigator` を持ち、`init` で `model` の直後に作る。`super.init` の直後に `historyNavigator.presentationHost = self`、
    `fileOperationCoordinator.historyNavigator = historyNavigator`、`treeViewController.historyNavigator = historyNavigator` を設定する（ツリーの最初の `selectFolder` より前。FR-111）
  - `extension MainSplitViewController: HistoryPresentationHost`: `historyPresentation` は `HistoryPresentation(displayMode: fileListViewController.currentDisplayMode,
    thumbnailSize: fileListViewController.currentThumbnailSize, paneLayout: paneLayout)`。`applyHistoryPresentation` は `fileListViewController.restore(displayMode:thumbnailSize:)` と
    `setPaneLayout(presentation.paneLayout)`（FR-091 のフォーカスの移動と FR-088 の幅の保持は既存のまま。US8 で記録の経路を分けても、ここは記録しない経路を呼ぶ）
  - `@objc func goBack(_ sender: Any?)`・`@objc func goForward(_ sender: Any?)`: `paneCommands.canNavigateHistory` と `historyNavigator.canGoBack`（`canGoForward`）が true のときだけ
    `historyNavigator.goBack()`（`goForward()`）を呼ぶ
  - `validateMenuItem`: `#selector(goBack(_:))` は `paneCommands.canNavigateHistory && historyNavigator.canGoBack`、`goForward` も同じ形（FR-112・FR-113）
  - `HiddenListKeyPress`（`installHiddenListKeyMonitor`）が ⌘ 付きの `[`・`]` を消費しないことをコードで確かめる（contracts/keyboard-and-menus.md の最後の段落）。消費していれば通すように直す
- [x] T022 [US7] `Sources/MediaViewerApp/App/MainMenu.swift` の `install()` で「表示」メニューの右に「移動」メニューを足す（FR-112、contracts/keyboard-and-menus.md §4。T021 のセレクタを参照するため T021 の後）:
  「戻る」（`action: #selector(MainSplitViewController.goBack(_:))`・`keyEquivalent: "["`・修飾 ⌘）と「進む」（`goForward(_:)`・`"]"`・⌘）、`target = nil`
  （`addSelectedFolderToFavorites` と同じく応答チェーンで届ける）。既存の「中を表示」「上の階層へ」は「ファイル」メニューのまま（A-44）。T021 のセレクタ名に合わせる
- [x] T023 [US7] `Sources/MediaViewerApp/App/MainToolbarController.swift` に戻る・進むのボタングループを追加する（FR-112・FR-045 の変更、R77、contracts/keyboard-and-menus.md §3。T021 の後）:
  - `historyIdentifier = NSToolbarItem.Identifier("history")` を `toolbarDefaultItemIdentifiers`・`toolbarAllowedItemIdentifiers` の先頭に置く（以降の並びは変えない）
  - `makeSegmentedControl(items: [("chevron.left", "戻る"), ("chevron.right", "進む")], trackingMode: .momentary, action: #selector(historySelected(_:)))`、
    `makeGroupItem(label: "戻る・進む")`。`historySelected` は `sender.selectedSegment` が 0 なら `panes.goBack(nil)`、1 なら `panes.goForward(nil)`
  - `apply(historyAvailability:)` で `setEnabled(_:forSegment:)` を、`panes.paneCommands.canNavigateHistory && panes.historyNavigator.canGoBack`（進むも同じ）で設定する。
    `HistoryNavigator.canGoBack`・`canGoForward` を `withObservationTracking` で監視し、変化のたびに `Task { @MainActor }` で更新して再登録する
    （`MainSplitViewController.observeInitialListingState` と同じ形。確認の結果や外部の変更でイベントなしに変わるため）。`validateToolbarItem` の `historyIdentifier` でも同じ値を設定し、
    どちらかが有効なら true を返す（フルスクリーン・名前の変更の出入りを反映する）

### Polish for User Story 1

- [x] T024 [P] [US7] `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift` に「10,000 ファイルのフォルダへ戻ったときの最初の項目の表示が 1 秒以内」を追加する（SC-029、R78）。
  FixtureKit の 10,000 ファイルのフォルダ H と小さなフォルダ S を作り、`HistoryNavigator`（スタブのホスト）で H → S と選んでから `goBack()` を呼び、`listing.folder == H` かつ
  `listing.state == .loaded` で `listing.files` が空でなくなるまでの時間を測る。既存の「huge(10,000) の列挙と並べ替えが 1 秒以内」と同じ計測と書き方にする

**Checkpoint**: US7 だけで、フォルダの戻る・進むがツールバー・メニュー・ショートカットで使える。表示の変更はまだ記録されない（戻る・進むで移った先の記録時の表示の状態は戻る）

---

## Phase 4: User Story 2 - 表示の変更を戻す・やり直す（US8、Priority: P3）

**Goal**: 表示形式・サムネイルサイズ・種類フィルタ・zip ファイルの表示・ペインの表示切り替えを、「表示」メニュー・ショートカット・ツールバー・下部のサイズバーの
どこから行っても1件の履歴として記録する。続けて行ったサイズの変更は1件にまとめ、戻る・進むの直後のサイズの変更は新しい履歴にする
（FR-107（3）、US8-AS1〜AS7、R71）

**Independent Test**: `swift test` で T025・T026 が通ること。`.app` で quickstart.md の「3. 手動確認」13〜19 を行い、⌘1 → ⇧⌘I の後に ⌘[ を2回押すと
画像のみ表示の解除・リスト形式の順に戻り、⌘] で順にやり直せること

### Tests for User Story 2

> **NOTE: 先に書き、ビルドエラーまたは失敗になることを確かめてから T027・T028 を実装する**

- [x] T025 [P] [US8] `Tests/MediaViewerCoreTests/NavigationHistoryTests.swift` にサイズの変更のまとめのケースを追加する（R71）。T027 の前に失敗することを確かめる:
  - 同じ場所でサイズ S1〜S5 を `.thumbnailSize` で続けて記録すると、S0 の履歴の後に1件だけ増え、現在のサイズが S5（US8-AS2）
  - `.thumbnailSize` の間に `.viewChange` または `.navigation` を挟むと別の履歴になる
  - S0 → S1（`.thumbnailSize`）の後に `move(.back)` で S0、もう一度 S1' を記録すると新しい履歴になり、進む側の S1 が消える（US8-AS7）。`move(.back)` で S0 に戻る
  - S0 → S1 → S0 と続けて記録すると（ドラッグで元の大きさに戻した）、まとめた現在が1つ前と同じ状態になり1つにまとまる。その後の `.thumbnailSize` の記録は新しい履歴になる
    （古い履歴を書き換えない。`lastRecordKind = nil`）
  - `removeCurrent()` の後、現在が nil で `.thumbnailSize` を記録すると新しい履歴になる
- [x] T026 [P] [US8] `Tests/MediaViewerCoreTests/HistoryNavigatorTests.swift` に表示の変更の記録のケースを追加する（FR-107（3）・FR-108。T016 と同じスタブとフィクスチャ）。T028 の前にビルドエラーになることを確かめる:
  - US8-AS1: A をリスト形式で表示し、スタブを `.thumbnails` にして `recordViewChange(.viewChange)` → `goBack()` でスタブにリスト形式が渡り、`listing` と `selection` が変わらない。
    `goForward()` でサムネイル形式
  - US8-AS2: サイズを5回変えて毎回 `recordViewChange(.thumbnailSize)` → `goBack()` 1回で元のサイズ
  - US8-AS3: `model.setMediaTypeFilter(imagesOnly)` → `recordViewChange(.viewChange)` → `goBack()` で `model.mediaTypeFilter` が両方オフ。画像のみ表示で外れた動画の選択は戻らない（FR-059）
  - US8-AS4: スタブの `paneLayout` をプレビューのみにして記録 → `goBack()` で `.all` が渡る
  - US8-AS5: A（リスト）→ サムネイル（記録）→ B を選ぶ → `goBack()` で A のサムネイル形式（場所が変わる）、もう一度でリスト形式（場所は同じ。`resolveHistoryLocation` を通らない）
  - US8-AS7: S0 → ⌘+ 相当の S1 を記録 → `goBack()` → S1' を記録 → `canGoForward == false`、`goBack()` で S0
  - 検索結果の表示中の `recordViewChange` は何もしない。検索結果の表示中に変えた表示形式は、`goBack()`（検索結果の表示を終える）の後に現在の履歴の表示の状態になる（R76）
  - 同じ状態の再設定（変えていない値での `recordViewChange`）は記録しない
  - `goBack()` による復元では、スタブの `applyHistoryPresentation` が呼ばれても新しい履歴が増えない（復元は記録の入口を通らない。R70）

### Implementation for User Story 2

- [x] T027 [US8] `Sources/MediaViewerCore/History/NavigationHistory.swift` の `record` にサイズの変更のまとめを足す（R71、data-model.md の `record` の行）: `kind == .thumbnailSize` かつ
  `lastRecordKind == .thumbnailSize` かつ現在があれば、新しい履歴を足さずに現在の `viewState` を書き換え、進む側は変えない。まとめた結果1つ前と同じ状態になればまとめて
  `lastRecordKind = nil`。書き換えでも `version` を増やす。T025 を通す（T009 の後）
- [x] T028 [US8] `Sources/MediaViewerCore/History/HistoryNavigator.swift` に `public func recordViewChange(_ kind: HistoryRecordKind)` を追加する（R70）: 検索結果の表示中・
  `model.historyLocation` が nil・`presentationHost` が nil なら何もしない。そうでなければ今の場所と表示の状態で `record(kind:leavingFocus: model.selection.focused)` を呼ぶ。
  T026 を通す（T017 の後）
- [x] T029 [US8] `Sources/MediaViewerApp/FileList/FileListViewController.swift` に `var onViewChange: ((HistoryRecordKind) -> Void)?` を追加し、ユーザーの操作の入口で状態を変えた後に呼ぶ
  （R70。T018 の後）: `showThumbnails(_:)`・`showList(_:)`・`selectDisplayMode(_:)`（ツールバー）は `.viewChange`、`increaseThumbnailSize(_:)`・`decreaseThumbnailSize(_:)`・
  `thumbnailSizeSliderChanged(_:)`（下部のサイズバー）・`applyThumbnailSize(_:)`（ツールバーのスライダー）は `.thumbnailSize`、`toggleImagesOnly(_:)`・`toggleVideosOnly(_:)`・
  `applyMediaTypeFilter(_:)`（ツールバー）・`toggleShowsZipFiles(_:)`・`applyShowsZipFiles(_:)`（ツールバー）は `.viewChange`。名前の変更中のガードで戻った場合は呼ばない。
  `restore(displayMode:thumbnailSize:)`・`setDisplayMode`・`setThumbnailSize` などの内部の setter からは呼ばない（復元を記録しない）。同じ値の再設定は Core が記録しないため、入口では無条件に呼んでよい
- [x] T030 [US8] `Sources/MediaViewerApp/App/MainSplitViewController.swift` で記録をつなぐ（R70。T021・T029 の後）:
  `fileListViewController.onViewChange = { [weak self] kind in self?.historyNavigator.recordViewChange(kind) }`。ペインの表示切り替えのユーザーの入口
  （`toggleFileListOnly(_:)`・`togglePreviewOnly(_:)`（⌃⌘2 / ⌃⌘3）と `applyToolbarSelection(fileListSelected:previewSelected:)`（ツールバー））で `setPaneLayout` の後に
  `historyNavigator.recordViewChange(.viewChange)` を呼ぶ。`applyHistoryPresentation`・フルスクリーンの出入り・起動時の復元からは記録しない。
  ⇧⌘T・⌃⌘F・⌥⌘1〜3・⇧⌘F・列見出しの並べ替えは記録しないこと（US8-AS6）をコードで確かめる

**Checkpoint**: US7・US8 の両方が動く。表示の変更も ⌘[・⌘] で戻せる

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: 検証ゲートと記録

- [x] T031 `specs/004-navigation-history/quickstart.md` の「3. 手動確認」の 25（zip の中を表示したまま始めた検索の ⌘[。手順と期待は追記済み）と 26
  （ボリュームの取り外しと EC-60・EC-65 の実際の経路）が、FR-113・US7-AS13・R75・R76 と一致することを確認する。不足や食い違いがあれば quickstart を直す。
  振る舞いが受け入れにくければ validation.md に記録し、仕様の変更としてユーザーに相談する
- [x] T032 `swift build`・`swift test`・`scripts/check-no-network.sh` をこの順で実行し、すべて成功することを確かめる（AGENTS.md の検証ゲート 1〜3）。T024 の計測値を控える
- [x] T033 `scripts/make-app.sh` で `.app` を作り、起動スモーク（3ペインが表示され、ツールバーの左端に `<`・`>` があること）をユーザーに依頼する。依頼には
  `pgrep -fl MediaViewer` での残りプロセスの確認、`open .build/MediaViewer.app`、quickstart.md の「2. 準備」を示す（GUI の起動はユーザーに依頼する。AGENTS.md）。
  起動しなければ AGENTS.md の「起動しないときの初動」（lldb で Objective-C 例外を止める）に従う
- [x] T034 quickstart.md の「3. 手動確認」1〜26 をユーザーに依頼し、結果を `specs/004-navigation-history/checklists/validation.md` に記録する
  （`specs/003-tree-folder-rename-delete/checklists/validation.md` の形式に倣う。実行日・OS・確認項目・合否、NG なら再現手順）。T024 の計測値（基準 1 秒に対する実測値。憲章 II・SC-029）と
  22 の 100ms の確認方法（Instruments の Hangs とメインスレッドの CPU、または目視。R78・SC-029）と自動テストの件数も記録する
- [x] T035 Phase 単位でコミットする（tasks.md のチェックと validation.md を含める）。`specs/product/` への反映は検証の後に別のコミットで行う（spec.md の「反映先」。この tasks の範囲外）

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 依存なし
- **Foundational (Phase 2)**: T001 の後。US7・US8 のすべてを止める
- **US7 (Phase 3)**: Phase 2 の後
- **US8 (Phase 4)**: Phase 2 の後に Core のテスト（T025）は書けるが、実装は US7 の T009（`NavigationHistory.swift`）・T017（`HistoryNavigator.swift`）・T018（`FileListViewController.swift`）・
  T021（`MainSplitViewController.swift`）と同じファイルを触るため、US7 の後に行う。US8 の記録は US7 の戻る・進む（`HistoryNavigator`）がないと確かめられない
- **Polish (Phase 5)**: Phase 3・4 の後

### Within Phase 2

- T002・T003 は互いに独立。T002 → T004、T003 → T005、T004 → T005

### Within User Story 1 (US7)

- T006・T007・T008 は互いに独立（別のファイル）。T006 → T009、T007 → T010、T008 → T011
- T009・T010・T011 は互いに独立（別のファイル）
- T012 は T004 の後。T012 → T013（同じファイル）。T012 → T014、T013 → T015、T014 → T015（同じファイル `BrowserModel.swift`）。T015 は T010 の後（`containsDirectory`）
- T016 は T009・T015 の後。T016 → T017
- T018・T019・T020 は T017 の後で互いに独立（別のファイル）
- T021 は T018・T019・T020 の後。T022・T023 は T021 の後（どちらも T021 のセレクタ・状態を使う）
- T024 は T017 の後（ほかの App のタスクと並列にできる）

### Within User Story 2 (US8)

- T025・T026 は互いに独立（別のファイル）。T025 → T027、T026 → T028
- T027 は T009 の後、T028 は T017 の後
- T029 は T018 の後、T030 は T021・T029・T028 の後

### Parallel Opportunities

- T002・T003 を同時に
- T006・T007・T008 を同時に、続けて T009・T010・T011 を同時に（別の worktree でもよい。AGENTS.md の worktree 規約）
- T012（BrowserModel のテスト）は T006〜T011 と同時に書ける（別のファイル）
- T018・T019・T020・T024 を同時に（T022 は T021 の後）
- T025・T026 を同時に

---

## Parallel Example: User Story 1

```bash
# Core のテストを同時に書く
Task: "T006 NavigationHistoryTests.swift（取り除き・まとめ）"
Task: "T007 ArchiveIndexTests.swift（containsDirectory）"
Task: "T008 PaneLayoutTests.swift（canNavigateHistory）"
Task: "T012 BrowserModelHistoryTests.swift（場所の通知）"

# Core の部品を同時に実装する（worktree ごとに1つ）
Task: "T009 NavigationHistory.swift"      # agent/T009-history-removal
Task: "T010 ArchiveIndex.swift"           # agent/T010-contains-directory
Task: "T011 PaneLayout.swift"             # agent/T011-can-navigate-history

# HistoryNavigator の後、App の別々のファイルを同時に
Task: "T018 FileListViewController.swift（restore）"
Task: "T019 FileOperationCoordinator.swift"
Task: "T020 DirectoryTreeViewController.swift"
Task: "T024 PerformanceBaselineTests.swift"
```

## Parallel Example: User Story 2

```bash
Task: "T025 NavigationHistoryTests.swift（サイズのまとめ）"
Task: "T026 HistoryNavigatorTests.swift（表示の変更）"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1（T001）
2. Phase 2（T002〜T005）→ `swift test --filter NavigationHistoryTests`
3. Core の部品（T006〜T011）→ BrowserModel（T012〜T015）→ HistoryNavigator（T016・T017）→ `swift test`
4. App（T018〜T023）→ `swift build`、T024
5. **STOP and VALIDATE**: 検証ゲート 1〜4 を行い、quickstart.md の 1〜12・20〜24 をユーザーに依頼する（US7 だけで止める場合は T034 の対象をこの範囲にする）

### Incremental Delivery

- 途中で止める場合の区切り: T005 まで（値型だけ。振る舞いは変わらない）、T017 まで（Core の戻る・進むまで。App はまだ使わない）、
  T023 まで（US7。フォルダの戻る・進む）、T030 まで（全機能）
- US7 の後に US8 を足しても、US7 の振る舞い（場所の戻る・進む）は変わらない。US8 で増えるのは表示の変更の履歴だけ

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability（US7・US8 は spec.md の新規ユーザーストーリーの番号）
- 外部の削除・名前の変更・権限のないフォルダの確認は、quickstart.md の準備で作った `~/MediaViewerHistoryTest` だけを使う。終わったら `chmod 755` してから消す
- 実装中に更新する仕様文書は、この tasks.md のチェックと T031 の quickstart.md の確認・修正だけにする（AGENTS.md）
- テストの失敗を3回直しても解決しない場合は、作業を止めて状況を報告する（AGENTS.md）
