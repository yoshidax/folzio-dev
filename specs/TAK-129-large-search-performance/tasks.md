---

description: "Task list for TAK-129 large search performance"
---

# Tasks: 5万件のメディアがある階層の検索を速くし、PC の負荷を下げる

**Input**: Design documents from `specs/TAK-129-large-search-performance/`

**Prerequisites**: [plan.md](plan.md)、[spec.md](spec.md)、[research.md](research.md)、[data-model.md](data-model.md)、[quickstart.md](quickstart.md)

**Tests**: spec.md の「検証方針」と憲章の原則 IV に従い、Swift Testing のテストを含める。テストを先に書き、実装の前に失敗することを
CI で確かめる（Cloud では Swift を実行できない）。性能テストは実装の前に現状の値を CI で記録する（research.md R9）。

**Organization**: ユーザーストーリーは US99 の1つだけなので、Phase 3 以降を部品ごとに分ける。Cloud ではサブエージェントで実装を分けず、
同じセッションで順に行う。`[P]` は別ファイルで依存がないことを示す。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US99（spec.md の User Story 1）
- **[MANUAL]**: 保守者が行う確認。報告を受けるまでチェックしない

## Path Conventions

- Swift Package: `Sources/FolzioCore/`、`Sources/FolzioApp/`、`Sources/FixtureKit/`、`Tests/FolzioCoreTests/`、`Tests/FolzioAppTests/`、`Tests/FolzioPerformanceTests/`
- ソースのコメントは英語（公開用リポジトリへ書き出される）

## Phase 1: Setup（5万件の階層と現状の計測）

**Purpose**: 実装の前に、5万件の階層を作る手段と、現状の値を記録する性能テストを用意する（research.md R1・R9）

- [X] T001 [P] `Sources/FixtureKit/FixtureSets.swift` に `public static func largeSearch(in directory: URL, folders: Int = 500, filesPerFolder: Int = 100) throws -> URL` を足す。`large-search/` の下に `folder-000`〜`folder-499` を作り、各フォルダに 8×8 の JPEG を `cat_000.jpg`（偶数）・`dog_001.jpg`（奇数）の形で `filesPerFolder` 個書く（SC-016 の性能テストと同じ形）。JPEG は1回だけ作って `Data` を書き込む。`makeAll` には含めない。戻り値は `large-search/` の URL
- [X] T002 `Sources/make-fixtures/main.swift` に `--large-search` の選択肢を足し、指定されたときに `FixtureSets.largeSearch(in:)` を呼ぶ。使い方の表示（usage）を `[--big] [--large-search]` にする（T001 に依存）
- [X] T003 `Tests/FolzioPerformanceTests/PerformanceBaselineTests.swift` に、5万件の性能テストを足す（T001 に依存）。(a) `FileNameSearcher` だけで `cat` を検索し、25,000 件と時間を `[perf] search 50,000 files: …` で出す。(b) 本物の `FileNameSearcher` を渡した `BrowserModel` で `startSearch` し、`listing.search?.phase == .finished` になるまでの時間と件数、終了時の `listing.files` が名前順であることを `[perf] model search 50,000 files: …` で出す。(c) (b) の間、UI スレッドで 10ms ごとに時刻を記録するタスクを動かし、隣り合う記録の最大の間隔を `[perf] main thread max gap: …` で出す。(a)〜(c) の基準は SC-249（3 秒）・SC-251（100ms）で `#expect` する（CI は参考。A-263）
- [X] T004 T001〜T003 をコミットして push し、CI の性能テストのログから (a)〜(c) の現状の値を `specs/TAK-129-large-search-performance/research.md` の R1 に追記する（実装の前の値）

**Checkpoint**: 現状の値が記録され、以後の変更の効果を比べられる

---

## Phase 2: Foundational（Core の検索中の追加と終了時の並べ替え）

**Purpose**: 見つかった順に末尾へ足し、反映をまとめ、終了時に UI スレッドの外で並べ替える（FR-085（変更）・FR-436・FR-437）。表示側（Phase 4）が使う

### Tests for Foundational

- [ ] T005 [US99] `Tests/FolzioCoreTests/BrowserModelSearchTests.swift` に、同じファイルの偽の検索（`FakeSearcher`。必要なら、まとまりを1つずつ流せるようにする）で次を確かめるテストを足す。(1) 検索中は届いた順に `listing.files` の末尾へ加わり、名前順に並べ替えられない（FR-085）。(2) 最初のまとまりはすぐに反映され、以後は data-model.md の間隔でまとめられ、どの結果も届いてから 1 秒以内に反映される（時計を差し替えるか、間隔を注入して確かめる）。(3) ストリームの終了で、ためた結果を含めて全件が反映され、`phase == .finished` と同時に現在の並べ替えで並ぶ（FR-437・EC-303）。(4) 終了時の並べ替えの後も選択とフォーカスが同じ項目で、`searchOrderGeneration` が1つ進む。(5) 検索中に `sortOrder` を変えると、その時点の結果が並べ替わり、以後の結果は末尾に加わり、終了時に全体が新しい順で並ぶ（US99-AS7）。(6) 検索を止めた（新しい検索、検索中にフォルダを開く・ツリーでフォルダを選ぶ）ときは並べ替えず、`searchOrderGeneration` も進まない（EC-302）。(7) 種類フィルタ・名前の絞り込みの中でも、足す分だけが絞り込まれて末尾に加わる
- [ ] T006 [US99] 同じファイルの既存のテスト「Merges batches in sort order, preserves selection and focus, and includes no .. or folder rows」（並べ替えながら合流する前提）を、検索の終了後の並び順を確かめる形に書き換える。ほかに検索中の並び順を前提にするテスト（`BrowserModelNameFilterTests.swift`・`BrowserModelSlideshowTests.swift`・`BrowserModelContentRefreshTests.swift` など）を探し、終了を待ってから並び順を確かめる形に直す
- [ ] T007 [US99] 同じファイルに、検索中の名前の変更のテストを足す。検索中にファイルの行（`didRenameItem`）とフォルダ（`didRenameFolder`）の名前を変えると、行の値は新しい名前になり、位置は動かない。検索の終了時の並べ替えで新しい名前の位置へ移る（EC-304・FR-105（変更））。並べ替えの途中（UI スレッドの外で並べ替えている間）に名前を変えても、結果に新しい名前が残る（`kindFilesRevision` の照合でやり直す）

### Implementation for Foundational

- [ ] T008 [US99] `Sources/FolzioCore/Browser/BrowserModel.swift` の `appendSearchResults` を、`pendingSearchResults` にためて反映の時刻に末尾へ足す形に変える（data-model.md の状態と間隔）。反映では、足す分だけに種類フィルタ・名前の絞り込みを適用して `listing.files` の末尾へ足し、全件の `rebuildListing` と `sortedMerge` を使わない。選択の制限は、隠れた行が選択にあるときだけ行う。`startSearchStream` のストリームの終わりで、ためた分を待たずに反映する。検索を止めたら `searchReflectionTask` を取り消す（FR-085・FR-436）
- [ ] T009 [US99] 同じファイルに、検索の終了時の並べ替えを足す。すべての列挙の終了（`activeSearchStreams == 0`）で、`allFiles` の写しを `Task.detached` で並べ替え、UI スレッドで `kindFilesRevision` と `sortOrder` が同じなら適用し、`phase = .finished`・`isSearchOrderPending = false`・`rebuildListing()`・`searchOrderGeneration` を進める。違えばやり直す。`navigationGeneration` が変わっていたら捨てる（FR-437・EC-302・EC-303。research.md R4）
- [ ] T010 [US99] 同じファイルの `sortOrder` の `didSet` で、`isSearchOrderPending` のときは UI スレッドで並べ替えず、T009 と同じ仕組みでその時点の結果を並べ替えて適用する（以後の結果は末尾へ。US99-AS7）
- [ ] T011 [US99] 同じファイルの `didRenameItem`・`didRenameFolder` で、`isSearchOrderPending` のときは `resortRow`・`sorted` で並べ直さず、行の値だけを書き換える（EC-304・FR-105（変更））。並べ替えの済んだ後は従来どおり
- [ ] T012 [P] [US99] `Tests/FolzioPerformanceTests/PerformanceBaselineTests.swift` の「Processes a 256-item batch against 50,000 items in under 100 ms」を、検索中の追加（末尾へ足す）の1回の時間を計る形にし、基準を 50ms にする（SC-253）

**Checkpoint**: T005〜T007 と T012 が CI で通る。T003 の (b)(c) の値が下がる

---

## Phase 3: 列挙を速くする（SC-249）

**Purpose**: ファイルごとの属性の読み取りを減らす（research.md R7）

- [ ] T013 [P] [US99] `Tests/FolzioCoreTests/FileNameSearcherTests.swift` に、同じ拡張子（大文字小文字の違いを含む `a.jpg`・`b.JPG`）と異なる拡張子のファイルを検索したとき、各行の種類の名前・作成日・変更日・サイズ・`contentVersion` が `DirectoryLister` の通常の一覧の行と同じになるテストを足す
- [ ] T014 [US99] `Sources/FolzioCore/Search/FileNameSearcher.swift` の列挙の `includingPropertiesForKeys` に、行に使う属性（作成日・変更日・サイズ・`FileContentVersion.resourceKeys`）を足す。種類の名前は、1回の検索の中で拡張子（小文字）ごとに1回だけ `localizedTypeDescriptionKey` を読み、以後は同じ値で行を作る。`Sources/FolzioCore/FileSystem/DirectoryLister.swift` の `mediaFile(at:kind:values:)` を internal にし、種類の名前を渡せる入口を足す
- [ ] T015 [US99] CI の性能テストで、T003 の (a) が下がり、SC-016・SC-054 の 1万件の列挙が遅くなっていないことを確かめる。遅くなっていれば、前もって読む属性を元に戻し、種類の名前のキャッシュだけを残す（research.md R7）

**Checkpoint**: T013 が通り、5万件の列挙の時間が下がる

---

## Phase 4: 表示側（FR-435・FR-436・FR-437）

**Purpose**: 末尾への追加で見えている項目を作り直さず、検索中は見えている項目だけの縮小画像を作り、終了時の並べ替えの後のスクロールを決める

### Tests for 表示側

- [ ] T016 [P] [US99] `Tests/FolzioAppTests/SearchThumbnailRequestTests.swift` を追加する。要求した URL を記録する偽の `ThumbnailProviding` と、まとまりを1つずつ流せる偽の `FileNameSearching`（`FileListTrashSelectionTests.swift` の `Searcher` に倣う）を使い、`BrowserModel` を渡した `ThumbnailModeView` をウインドウに置いて、2,000 件を数回に分けて流す。(1) 検索中に要求した URL が、要求した時点で見えている項目だけであること（先読みの URL を含まない。SC-252・FR-435）。(2) 末尾への追加で、見えている項目の縮小画像を要求し直さないこと。(3) 検索中にスクロールすると、新しく見えた項目を要求し、見えなくなった項目の要求を取り消すこと（EC-300）。(4) 検索の終了で並べ替わった後、先頭（フォーカスがあればその項目）が見え、見えている項目を要求し、先読みが再開されること（FR-437・US99-AS3・AS8）。(5) 検索中にサムネイルの大きさを変えても、先読みの URL を要求しないこと（EC-301）。(6) 検索していない通常のフォルダの一覧では、従来どおり先読みで要求すること（A-269）
- [ ] T017 [P] [US99] 同じファイルに、`ListModeView` で、末尾への追加では見えている行の縮小画像を要求し直さず、検索の終了の後にフォーカス行（なければ先頭）が見えることのテストを足す

### Implementation for 表示側

- [ ] T018 [US99] `Sources/FolzioApp/FileList/ThumbnailModeView.swift` の `applyModel` で、新しい URL の列が前の列で始まり長くなっただけなら `insertItems(at:)` で末尾だけを足し、それ以外は従来どおり `reloadData` する（research.md R5）
- [X] T019 [US99] **取りやめ**（既存の App のテストが失敗したため `sizeForItemAt` に戻した。research.md R5）。元の内容: 同じファイルのフローレイアウトで、`sizeForItemAt` をやめ、`flowLayout.itemSize` をサムネイルの大きさとペイン幅から決める。今 `invalidateLayout` している箇所（サムネイルの大きさ・幅の変更）で `itemSize` を更新する（research.md R5）
- [ ] T020 [US99] 同じファイルで、検索中（`model.listing.search?.phase == .searching`）は `prefetchItemsAt` で要求しない。一覧が変わったら、見えている項目以外の要求を取り消す。`searchOrderGeneration` が進んだら、フォーカス項目があればそれを、なければ先頭を表示し、見えている項目を要求する（FR-435・FR-437・EC-300〜EC-302）
- [ ] T021 [US99] `Sources/FolzioApp/FileList/ListModeView.swift` の `applyModel` で、末尾への追加だけなら `noteNumberOfRowsChanged()` にし、`searchOrderGeneration` が進んだら、フォーカス行があればそれを、なければ先頭を表示する。検索中に末尾へ足しただけの更新では、フォーカス行への `scrollRowToVisible` を呼ばない（通常のフォルダと、それ以外の更新では従来どおり呼ぶ）

**Checkpoint**: T016・T017 が CI で通る

---

## Phase 5: 検証

- [ ] T022 Cloud で `scripts/dev/check-all.sh` を実行し、終了コード 0 を確かめる（`scripts/dev/check-english-comments.sh` を含む）
- [ ] T023 CI の通常のテストと性能テストのログを確かめ、T003 の (a)〜(c) と T012 の実装の前後の値を `specs/TAK-129-large-search-performance/research.md` の R1 に追記する（PR にも記載する。憲章の原則 II）
- [ ] T024 [MANUAL] 保守者が quickstart.md の「保守者の GUI 確認」の 1〜11 を行い、合否と時間を報告する。報告を `specs/TAK-129-large-search-performance/checklists/validation.md` に記録する（SC-249〜SC-252、US99-AS1〜AS8、A-269）
- [ ] T025 [MANUAL] 保守者が起動スモーク（`scripts/make-app.sh` の後に `open .build/Folzio.app` で 3 ペインが表示される）を行い、報告する

---

## Phase 6: 仕様の反映（PR の最後）

- [ ] T026 `git merge origin/master` で最新の `master` を取り込み、`scripts/dev/check-spec-ids.sh` を実行する。spec.md の「反映先」の項目を `specs/product/search.md`（と `README.md` の件数）へ反映し、検索中の並び順に触れているほかの記述を `specs/product/` から探して直す。`python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-spec-ids.sh` を再実行し、feature の spec.md の冒頭に移行済み・凍結の注記を入れる。差分を保守者に示し、承認後にコミットする

---

## Dependencies & Execution Order

- Phase 1（T001→T002、T001→T003→T004）を先に行い、現状の値を記録する
- Phase 2: テスト T005〜T007 → 実装 T008→T009→T010・T011。T012 は T008 の後
- Phase 3（T013→T014→T015）は Phase 2 と独立（`FileNameSearcher` だけ）。Phase 2 の後に行う（BrowserModel の計測を先に安定させるため）
- Phase 4 は Phase 2 に依存する（`searchOrderGeneration`・末尾への追加）。T018→T019→T020、T021 は T018 と独立
- Phase 5 → Phase 6

## Parallel Example

```text
T001（FixtureSets）と、T013（FileNameSearcherTests）は別ファイルで依存がない
T016（ThumbnailModeView のテスト）と T017（ListModeView のテスト）は同じファイルなので順に書く
```

## Implementation Strategy

1. Phase 1 で現状を計る
2. Phase 2 で Core の追加と終了時の並べ替えを入れ、CI で (b)(c) の改善を確かめる（最も効果が大きい見込み。research.md R1）
3. Phase 3 で列挙を速くし、Phase 4 で表示側を入れる
4. 保守者の GUI 確認（T024）で、3 秒の基準を確かめる。満たさない場合は、計測の値をもとに保守者と次の手を決める
