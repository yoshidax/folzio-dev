# Implementation Plan: 検索でフォルダも検索対象にする

**Branch**: `009-folder-search` | **Date**: 2026-10-27 | **Spec**: [spec.md](spec.md)

**Input**: `specs/009-folder-search/spec.md`、spec が参照する `specs/product/` の領域（search.md・file-list.md・file-operations.md・directory-tree.md・navigation-history.md・preview.md・zip.md・overview.md）と [contracts/keyboard-and-menus.md](../product/contracts/keyboard-and-menus.md)。憲章 v1.2.0。

## Summary

名前の検索で、ファイル名に加えてフォルダ名もキーワードと照合し、一致したフォルダを、通常のフォルダの一覧のフォルダの行と同じ見た目・操作で検索結果に混ぜて表示する。一致の対象は通常の一覧にフォルダの行として出るフォルダ（隠し・パッケージ・フォルダへのリンクを除く）で、起点そのものと zip は対象にしない。一致したフォルダの中も辿り、中の項目はそれぞれの名前で照合する。フォルダの行はダブルクリック・⌘↓・「中を表示」で開け、開くと検索結果の表示を終えてそのフォルダの一覧へ移る。検索結果は従来どおり履歴に記録しない。

列挙は既存の `FileNameSearcher` の1回の走査のまま、ディレクトリも照合してフォルダの行を返す。フォルダの行の値は `DirectoryLister` と共有する。一覧の状態・並べ替え・種類フィルタ・プレビュー・フルスクリーン・スライドショー・ファイル操作の判定は、`ListItemKind.folder` の既存の分岐でそのまま成り立つ。新たに要るのは、検索中の名前の変更で「照合済みか」を判定する記録と台帳（EC-94）、索引の付け替えの修正、履歴の表示の状態の反映（FR-113・EC-99）、空のメッセージの文言、検索結果からのゴミ箱の扱い（EC-101・R8）、ツリーに表示されない場所の選択と保存（EC-102・R10）とする。根拠は [research.md](research.md)、型と遷移は [data-model.md](data-model.md)、UI・キー・履歴の差分契約は [contracts/folder-search.md](contracts/folder-search.md) を参照。

## Technical Context

**Language/Version**: Swift 6（Package の `swiftLanguageModes: [.v6]`）

**Primary Dependencies**: Foundation／Swift Concurrency、AppKit。既存の `FileManager` の列挙器・`URLResourceValues`・`NSLock` を使う。外部パッケージの追加なし。Core は AppKit を import しない。

**Storage**: なし。検索結果・検索条件・照合済みの記録は保存しない。UserDefaults のキーを追加しない。`lastFolder` は既存の設定を使い、検索結果から開いたフォルダがツリーに表示されない場合は同期完了後に選択できた祖先を保存する（EC-102・R10）。

**Testing**: Swift Testing。Core の照合（フォルダの行・除外・値の一致）、照合済みの記録、名前の変更の台帳、`BrowserModel` の一覧の状態・開く・ファイル操作・外部の変更・検索中と検索後の名前の変更・検索結果の一覧からのゴミ箱の判断（EC-101）、`HistoryNavigator` の EC-99・EC-100 を単体テストする。フィクスチャは FixtureKit で一時ディレクトリに作る。GUI の操作・見た目・ツリーの同期はユーザーによる `.app` の手動確認で確かめる。

**Target Platform**: macOS 15 以降

**Project Type**: AppKit デスクトップアプリ + Core ライブラリ、単一 Swift Package

**Performance Goals**: SC-054（SC-016 の 10,000 ファイルの階層で、フォルダも照合する検索が 3 秒以内、検索中も操作が 100ms 以上止まらない）。既存の SC-016・SC-025、10,000 件で UI を止めない基準、名前の変更の付け替えの費用（001 の R67）を維持する。フォルダの照合は名前の比較だけを足し、`isPackage`・作成日は名前が一致したディレクトリにだけ問い合わせる。 完了までの 3 秒は T024 の `ContinuousClock`、UI 停止の 100ms は T055 と quickstart.md 手動シナリオ 7 の Instruments Hangs（しきい値は 100ms 未満）で別々に検証する。目視は補助とし、計測未実施を合格にしない。

**Constraints**: オフライン・ネットワーク API 不使用。列挙・存在確認・ファイル操作を UI スレッドで行わない。zip の中・zip ファイルの名前は照合しない（A-79）。ファイルだけ・フォルダだけの切り替えを設けない（A-77）。フォルダから検索結果へ戻る操作は作らない（A-80）。Core は AppKit に依存しない。GUI の起動はユーザーが行う。

**Scale/Scope**: 検索結果の件数に上限なし（FR-085）。照合済みの記録はディレクトリ数に比例（10,000 ファイルの階層で数百件）。Core に型を3つ（`SearchRequest`・`SearchVisitLog`・`SearchRenameLedger`）と `LocationEvent` の case を1つ加え、`leaveTrashedFolders` に操作の経路の引数を加える。App は3か所（空のメッセージ・検索結果からのゴミ箱で経路を渡す・ツリー同期の完了を Core へ返す）を変える。新しい画面・設定・メニュー項目・ショートカットはない。

**Resolved design questions**: NEEDS CLARIFICATION はない。spec の Clarifications の回答を前提に、R1〜R10 を research.md に記す。EC-101 は 2026-10-27 にユーザーがゴミ箱・移動とも採用済み（T001）。ツリーに表示されない検索結果のフォルダは、一覧はそのフォルダ、ツリーと保存先は表示可能な最も近い祖先にする案を同日に採用し、EC-102・R10・T061〜T063 に反映した。

## Constitution Check

*Phase 0 の前と Phase 1 の後に評価。PASS は設計の適合の判定であり、実装・GUI 検証が済んだという意味ではない。*

| 原則・ゲート | Phase 0 前 | Phase 1 後の設計と検証方針 |
|---|---|---|
| I ローカル完結 | PASS | 通信・送信・保存の追加なし。ファイルの変更はユーザーが選んだ既存のファイル操作（確認・ゴミ箱経由）だけで、検索がファイルを変えることはない。no-network チェックを実行する |
| II 性能 | PASS | 列挙は1回の走査のまま、UI スレッドの外で行う。一致しないディレクトリには先読み済みのキーしか使わない。SC-054 を性能試験で測り、既存の SC-016 と名前の変更の試験を維持する。照合済みの記録はディレクトリだけで、メモリはディレクトリ数に比例する |
| III キーボード・アクセシビリティ | PASS | フォルダの行は既存の ⌘↓・「ファイル > 中を表示」・右クリックメニュー・矢印キーで開け、操作できる。新しい操作はない。行の読み上げは通常のフォルダの行と同じ（名前・種類） |
| IV テスト必須 | PASS | 照合の対象と除外（隠し・パッケージ・リンク・zip・起点・権限なし）、値の一致、照合済みの判定と名前の変更の組み合わせ、一覧の状態、開く、ファイル操作と外部の変更、履歴を Core でテストする。権限なし・消えたフォルダ・検索中の名前の変更の異常系を含める。既存テストの期待値（`cat-folder`）を更新する |
| V シンプルさ | PASS | 新しい依存なし。切り替え・設定・検索結果へ戻る操作を作らない。一覧・操作の判定は既存の `.folder` の分岐を使い、検索結果専用の行の種類を作らない。追加の型は EC-94 を満たすための最小限（Complexity Tracking） |
| 技術制約・AppKit 不変条件 | PASS | UI の変更は MainActor のみ。ビュー・制約・`NSSplitViewController` には触れない。Core は AppKit を import しない |
| 仕様管理・検証ゲート | PASS | 成果物は本 feature に限る。実装中は tasks のチェックと明示タスクの追記だけ。`specs/product/` への反映は実装・検証の後。GUI 未確認を完了にしない |

違反・例外の申請はない。

## Project Structure

### Documentation (this feature)

```text
specs/009-folder-search/
├── spec.md
├── checklists/requirements.md
├── plan.md
├── research.md
├── data-model.md
├── contracts/folder-search.md
├── quickstart.md
└── tasks.md
```

### Source Code (repository root)

以下は実装先の予定。既存ファイルの修正を優先し、新規には「新規」を付す。

```text
Sources/MediaViewerCore/
├── Search/
│   ├── FileNameSearcher.swift        # ディレクトリの照合・フォルダの行・SearchRequest・matchesRoot・記録
│   ├── SearchRequest.swift           # 新規: SearchRequest・SearchVisitLog（FileNameSearcher.swift に置いてもよい）
│   ├── SearchRenameLedger.swift      # 新規: 検索中の名前の変更の付け替えと照合済みの判定
│   └── SearchPattern.swift           # コメントのみ（ファイル名とフォルダ名）
├── FileSystem/DirectoryLister.swift  # folderRow(at:creationDate:) を共有
├── Browser/BrowserModel.swift        # 台帳・列挙の番号・rebaseSearchIndex の修正・LocationEvent の新 case・leaveTrashedFolders の経路（EC-101）
└── History/HistoryNavigator.swift    # .openedSearchResultFolder で表示の状態を反映してから記録
Sources/MediaViewerApp/
├── FileList/FileListViewController.swift      # 空のメッセージを「該当する項目はありません」
├── Operations/FileOperationCoordinator.swift  # leaveTrashedFolders へ操作の経路を渡すだけ（判断は Core。EC-101・R8）
└── Tree/DirectoryTreeViewController.swift     # 同期で選択したフォルダを Core へ渡す（EC-102・R10）
Sources/FixtureKit/FixtureSets.swift  # folderSearch(in:) と SC-053 の件数の生成。makeAll から呼ぶ
Tests/MediaViewerCoreTests/
├── FileNameSearcherTests.swift        # フォルダの照合・除外・値・matchesRoot・記録。既存の期待値の更新
├── SearchRenameLedgerTests.swift      # 新規: 付け替えの範囲・名前・照合済みの判定・捨てる規則
├── BrowserModelSearchTests.swift      # 状態・開く・操作・外部の変更・検索中と検索後の名前の変更・EC-101 のゴミ箱。FakeSearcher を SearchRequest に
└── HistoryNavigatorTests.swift        # 検索結果からフォルダを開く（EC-99・EC-100）
Tests/MediaViewerPerformanceTests/
└── PerformanceBaselineTests.swift     # SC-054。StreamingSearcher を SearchRequest に。名前の変更の試験の拡張
```

**Structure Decision**: 単一 Package と既存の2テスト target を保つ。照合・記録・名前の変更の判定は Core の検索器と値型に置き、`BrowserModel` は台帳を持って一覧へ反映するだけにする。履歴の判断は `HistoryNavigator` に置き、`BrowserModel` は通知の種類を分けるだけにする（001 の R70）。App は表示の文言・ゴミ箱の操作経路・ツリー同期の完了通知を変え、行の表示・メニュー・キーは既存の `.folder` の分岐に任せる。新しい target・UI テスト・設定は追加しない。

## Phase 0 — Research

spec・product の領域・既存コード（検索器、一覧、並べ替え、種類フィルタ、名前の変更の付け替え、索引、ファイル操作、履歴、メニュー）を読み、[research.md](research.md) を作成した。主な判断:

- 列挙は1回の走査のまま、ディレクトリを名前で照合する。`isPackage`・作成日は一致したものだけ読み、行の値は `DirectoryLister` と共有する（R1）。
- 検索の要求を `SearchRequest` にまとめ、ディレクトリを照合する直前に `SearchVisitLog` へ記録する（R2）。
- 検索中の名前の変更は `SearchRenameLedger` で、照合済みなら付け替えだけ、未照合なら古い場所の結果を捨てて新しい名前で照合する（R3、EC-94）。
- 索引でキーが変わらないエントリの URL も付け替える。消えたフォルダの中の結果は既存の存在確認で外す（R4）。
- 一覧の状態の判定は既存のまま FR-139・EC-96 を満たす。文言だけを「該当する項目」にする（R5）。
- フォルダの行は既存の `openItem` の経路で開き、メニュー・キーも既存の判定で有効になる（R6）。
- 履歴は新しい通知で、表示の状態を現在の履歴へ反映してから記録の要否を判定する。EC-99・EC-100 はこの順序で成り立つ（R7）。
- 検索結果の一覧からのゴミ箱・移動では、検索前の場所を含むフォルダでも検索結果の表示を続ける。ゴミ箱の判断は `BrowserModel.leaveTrashedFolders` に経路を渡して Core で行う。移動は既存の経路のままで同じ挙動になる（R8。spec の EC-101。採用は T001 に記録済み）。

## Phase 1 — Design

### 1. 照合とフォルダの行（Core）

- `FileNameSearcher.search(_:)` は列挙の各項目で、先読みした `isDirectory`・`isSymbolicLink` を見る。ディレクトリ（リンクでない）なら、まず `request.visits.record(path)` で記録し、名前が一致すれば `isPackage` を問い合わせ、パッケージでなければ `DirectoryLister.folderRow(at:creationDate:)` の行をバッチに加える。ファイルの扱い（拡張子・ファイルへのリンク・フォルダへのリンクの除外）は既存のまま。
- `request.matchesRoot` が true のときだけ、列挙の前に起点そのものを同じ規則で照合する（隠し属性も確かめる）。
- 起点の形への組み直し（`rebaser`）・バッチ（256件・100ms）・取り消しは既存のまま。`search(in:matching:)` はプロトコル拡張で `SearchRequest(root:pattern:)` を作って呼ぶ。

### 2. 一覧・開く・ファイル操作（Core と App）

- 一覧の状態（`.loading` / `.empty` / `.loaded` / `.noMatches`）・件数・並べ替え・種類フィルタ・プレビューの除外・フルスクリーンの飛ばし・スライドショーの除外は変えない。`FileListViewController.refresh` の検索結果の `.empty` の文言を「該当する項目はありません」にする。
- フォルダの行は `openItem` → `navigateToFolder` で開く。検索結果の表示中は理由を `.openedSearchResultFolder` にし、`onLocationEvent` の種類だけを変える。列挙の停止・「場所」の並べ替えの解除・フォーカスは既存の経路のまま。ツリーに表示されないフォルダは EC-102・R10 に従い、既存の祖先への同期後に Core が保存先を更新する（T061〜T063）。
- `rebaseSearchIndex` で、キーが変わらないエントリの URL にも `moved` を当てる。フォルダの消失・ゴミ箱・移動は既存の `pruneMissingResults` で、行と中の結果を外す。
- `BrowserModel.leaveTrashedFolders(_:origin:)` に操作の経路を加え、`origin == .fileList` かつ検索結果の表示中は親へ移らずに false を返す。`FileOperationCoordinator.trash` は `origin` を渡すだけで、false なら従来どおり `reloadCurrentFolder` を呼ぶ（EC-101・R8）。判断を Core に置き、App に分岐を作らない（憲章 IV）。`FileOperationCoordinator.transfer`（移動）は `leaveTrashedFolders` を呼ばないため変えず、検索結果の一覧からの移動の挙動は回帰テストで固定する（EC-101・R8）。

### 3. 検索中の名前の変更（Core）

- `BrowserModel` は `searchRenames` を `SearchRenameLedger` に置き換える。`startSearchStream` は記録を作って台帳に登録し、列挙の番号をバッチに添える。
- `appendSearchResults` は名前の変更があれば `ledger.place(_:fromStream:)` を通し、付け替え・フォルダの行の名前の変更・捨てる判定をしてから、既存の重複除き・マージを行う。
- `didRenameFolder` は、検索中に起点の配下のフォルダの名前を変えたとき、`ledger.hasVisited(oldURL)` の結果を `recordRename` に渡し、追加の列挙を `matchesRoot: !visited` で始める。起点・祖先の名前の変更は既存どおり。

### 4. 履歴（Core）

- `HistoryNavigator.handleLocationEvent` に `.openedSearchResultFolder(leavingFocus:)` を加える。`updateCurrentViewState` で検索終了時の表示の状態を現在の履歴に反映してから、`.navigated` と同じ記録・snapshot の処理をする。
- ツリーの選択・Esc・⌘[ による検索結果の終了、検索結果の表示中の「戻る」「進む」の可否は変えない。

### 5. フィクスチャとテスト

- `FixtureSets.folderSearch(in:)` で [quickstart.md](quickstart.md) の `folder-search/` を作り、SC-053 の件数の階層を生成する関数を同じファイルに置く。`makeAll` から呼ぶ。
- 既存の `search` フィクスチャの `cat-folder` が一致するようになるため、`FileNameSearcherTests` の期待値を更新する。`FakeSearcher`・`StreamingSearcher` は `SearchRequest` を受ける形に改める。
- SC-054 の性能試験を足し、名前の変更の性能試験をフォルダの行を含む結果に広げる。

### 6. Validation and handoff

要件との対応は [quickstart.md](quickstart.md) を参照。実装 Phase の検証は `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` の順に行う。その後、ユーザーへ `open .build/MediaViewer.app` と確認点（3ペイン、フォルダの行の表示と並び、開く3つの手段とツリーの同期・フォーカス、⌘[ の戻り先、EC-99・EC-100、プレビュー・フルスクリーン・スライドショー・種類フィルタ、名前の変更・ゴミ箱・外部の変更、権限なしのフォルダ）を依頼する。EC-101 と EC-102 はユーザーの回答で確定済み。GUI が未確認なら該当タスクを未チェックに保つ。問題のない Phase をコミットし、実装・検証の後にだけ spec の反映先の表に従って `specs/product/` へ反映する。

本書は実装前の設計。tasks は生成済みで、ソースの実装・GUI の起動確認は後続工程で行う。

### Constitution Check（Phase 1 後の再評価）

上の表の「Phase 1 後」の列のとおり、すべて PASS。設計で増えた要素（`SearchRequest`・`SearchVisitLog`・`SearchRenameLedger`・`LocationEvent` の case）は、EC-94 と FR-113 の変更を満たすための最小限であり、汎用の検索・履歴の基盤にはしない。

## Complexity Tracking

憲章違反はない。次の点は、より単純な案を採らなかった理由を記録する。

| 追加する複雑さ | 必要な理由 | 採らなかった単純な案と理由 |
|---|---|---|
| 列挙と `BrowserModel` で共有する照合済みの記録（`SearchVisitLog`、`NSLock`） | 検索中に名前を変えたフォルダが照合済みかを知り、照合済みなら判定し直さず、未照合なら新しい名前で照合する（EC-94、FR-105） | 記録なしで常に照合し直す・常に照合しない案は、それぞれ EC-94 の前半・後半に反する。全項目の記録はメモリが件数に比例する |
| 名前の変更の付け替えを `SearchRenameLedger`（Core の値型）に分ける | 列挙ごとの付け替えの範囲・フォルダの行の名前・照合済みの判定・捨てる規則の組み合わせを、AppKit なしで単体テストする（憲章 IV） | `BrowserModel` の中に直接書くと、1400行の型の中で順序の組み合わせのテストが書きにくい。既存の `searchRenames` の配列だけでは列挙ごとの範囲を持てない |
| `LocationEvent.openedSearchResultFolder` | 検索結果からフォルダを開いたときだけ、表示の状態を現在の履歴へ反映してから記録の要否を判定する（FR-113・EC-99） | `.navigated` に Bool を足すと既存の全呼び出しと意味が混ざる。すべての検索結果の終了で反映すると、ツリーからの終了の挙動が spec の範囲外で変わる |

### EC-102 の保存と複雑さ

ツリーの描画・列挙は App の既存経路を使い、Core に `completeSearchResultTreeSync(_:selectedFolder:)` と保留 ID を1つ加える。検索結果から開いた依頼だけを受け入れ、ナビゲーションの取り消し・世代交代・重複・祖先でない URL を排除して `lastFolder` だけを書き換える（R10、T061〜T063）。App が直接保存する案より Core で異常系を検証しやすく、通常のフォルダ移動・お気に入り・履歴からの同期を変更しない。
