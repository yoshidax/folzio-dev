# Tasks: TAK-74 他のアプリとのドラッグ&ドロップ

**Input**: `specs/TAK-74-external-drag-drop/` の設計文書

**Prerequisites**: spec.md / plan.md / research.md / data-model.md / contracts/external-drag-drop.md / quickstart.md

**Tests**: Core の判断（操作の決定、検索結果の記録）と、App のマスク・file URL の判定・キャッシュ・受け取った印に自動テストを付ける。
GUI は保守者がローカルで確認する。実装は保守者の設計承認の後に行う。

**注意**: `scripts/check-no-network.sh` は `Sources` の中の `http`・`https://` の文字列を、コメントを含めて拒否する。URL の例は `Tests` にだけ書く。

## Phase 1: Setup

- [x] T001 `specs/TAK-74-external-drag-drop/spec.md` と `checklists/requirements.md` を作り、TAK-74 と保守者の決定（Clarifications）を記録する
- [x] T002 `plan.md`・`research.md`・`data-model.md`・`contracts/external-drag-drop.md`・`quickstart.md` に設計と検証方法を記録する
- [x] T003 保守者の設計レビューと実装の承認を得る。承認がなければ T004 以降に進まない

## Phase 2: 先に行う確認（実装の前提を macOS で確かめる）

- [ ] T004 `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift`（1061 行付近）・`Sources/FolzioApp/FileList/ListModeView.swift`（263 行付近）・
  `Sources/FolzioApp/FileList/ThumbnailModeView.swift`（600 行付近）の `setDraggingSourceOperationMask(_:forLocal: false)` を `[.copy, .move, .generic, .delete]` にする
  （サムネイル形式は新しく設定する）。`forLocal: true` は変えない（FR-344、R2）。共通の値は `Sources/FolzioApp/Shared/ExternalDrag.swift` の定数にする。
  この変更だけをコミットして push し、CI（`workflow_dispatch`）で build とテストを確かめる
- [x] T005 [MANUAL] 保守者に、quickstart.md の「先に行う確認」を T004 の版で実行してもらい、結果を `checklists/validation.md` に記録する。
  Dock のゴミ箱がファイルを移さない場合は `.delete` をマスクから外し、spec の FR-344・US75-AS5・FR-079（変更）と contracts・quickstart を直す（保守者の決定）。
  Option と ⌘ の同時、Finder の移動・コピーの結果が設計と違う場合は、spec・research を直して保守者に確かめてから T006 に進む

## Phase 3: Foundational（全ストーリーの前提）

- [x] T006 `Tests/FolzioCoreTests/ExternalDropPolicyTests.swift` を作り、data-model.md の表のすべての組み合わせ（option・command・allOnSameVolume）と、
  優先する操作が許可されないときの切り替え・`nil`（EC-238）、Option と ⌘ の同時で `allowsMove`・`allowsCopy` がどちらも false のときの `nil` をテストする（FR-346）。
  `allOnSameVolume` は、一時フォルダの中の項目で true、存在しない項目を含むときに false（値が取れなければ false。EC-237）をテストする（先に失敗させる）
- [x] T007 `Sources/FolzioCore/Operations/ExternalDropPolicy.swift` を実装して T006 を通す（FR-346・EC-237・EC-238、R3・R4）。
  `operation(option:command:allOnSameVolume:allowsMove:allowsCopy:) -> Operation?` と `allOnSameVolume(_:destination:) -> Bool`
  （`URLResourceValues.volumeIdentifier` を比べる。UI スレッドで呼ばない旨をコメントに書く）
- [x] T008 `Sources/FolzioApp/Shared/PasteboardFileURLs.swift` を作り、`InternalDrag.urls`・`FileOperationCoordinator.pasteboardFileURLs`・
  `DirectoryTreeViewController.fileURLs(from:)` の file URL の読み出しを `fileURLs(in:)` にまとめる（R4・R6。動作は変えない）
- [x] T009 `Sources/FolzioApp/Shared/DropOperationCache.swift` を作り、`InternalDrag` の通し番号ごとのキャッシュ（`cache`・`pending`・`currentSequence`）を移す。
  通し番号ごとに URL の配列も1回だけ読んで保持する。「操作の決め方」を渡せるようにし、`InternalDrag.operation` はアプリ内の決め方（Option でコピー、なければ移動）を渡す。
  ドロップ時に使う `cachedOperation`（キャッシュがなければ nil。ファイルシステムを読まない）を加え、アプリ内の `acceptDrop` もそれを使う（data-model.md、R4。アプリ内の動作は変えない）
- [x] T010 `Tests/FolzioAppTests/ExternalDragTests.swift` を作り、`DropOperationCache` が通し番号の変化でキャッシュと URL を捨てること、同じ通し番号では URL を読み直さないこと、
  `cachedOperation` が結果の前は nil を返すことをテストする
- [x] T011 `Sources/FolzioApp/Operations/FileOperationCoordinator.swift` の `internalDrop(_:to:copy:)` を `drop(_:to:copy:)` に改名し、
  `DirectoryTreeViewController.swift` と `Sources/FolzioApp/FileList/FileListViewController.swift` の呼び出しを直す（FR-347、R5。動作は変えない）

## Phase 4: User Story 75 - Folzio の項目を他のアプリへ渡す (P1)

**Goal**: ツリー・リスト形式・サムネイル形式から、Finder・ブラウザへドラッグして移動・コピー・アップロードを行える。Dock のゴミ箱には対応しない

**Independent Test**: quickstart.md の「Folzio からアプリ外へ」

- [x] T012 [US75] `Sources/FolzioApp/Shared/InternalDrag.swift` に、通し番号ごとの「Folzio のビューで受け取った」印（`markAccepted(_:)`・`wasAccepted(_:)`）を加え、
  ツリー・リスト形式・サムネイル形式のアプリ内の `acceptDrop` で印を残す。ツリーの `draggingSession(_:endedAt:operation:)`（1762 行付近）で、
  操作がない場合に加えて印がない場合（アプリ外へドロップした場合）も `pendingOperationSources` を消す。アプリ外へのドロップでは Folzio は何も削除せず、
  結果は FSEvents に任せる旨をコメントに書く（FR-219・FR-344・EC-236、R2・R7）
- [x] T013 [US75] `Tests/FolzioCoreTests/BrowserModelSearchTests.swift` に、次をテストする（EC-236、先に失敗させる）。
  （1）検索の途中でフォルダ `trip/day1` を外部で移動し、`handleFileSystemEvent` でその親を報告すると、配下の行 `trip/day1/cat.jpg` が外れ、
  その後に遅れて届く同じフォルダの別のファイル `trip/day1/bird.jpg`（外れた行とは別のファイル）が表示されない。
  （2）ファイル `trip/day2/a.jpg` だけを消したときは、同じフォルダのまだある結果と、後から届く `trip/day2/b.jpg` は表示される（フォルダを記録しない）。
  （3）検索のルートの外へはたどらない。（4）新しい検索を始めると記録が消える。既存の 9 行目のテストは、遅れた結果に同じファイルを送るため、この確認には使わない
- [x] T014 [US75] `Sources/FolzioCore/Browser/BrowserModel.swift` の `pruneMissingResults(under:)`（1473 行付近）の detached task の中で、`missing` の各 URL の親をたどり、
  まだある親の直下の消えたもの（一番上の消えた祖先。検索のルート（`listing.search?.root`。`listing` は MainActor の状態なので、detached task を始める前に値として取り出して渡す）まで、ルートが消えていればルート）を求め、`movedSearchPaths` に加えて T013 を通す
  （R8）。1回の呼び出しの中で確かめたフォルダの結果を覚えて、同じフォルダを繰り返し調べない。既存の `BrowserModelSearchTests` が通ること
- [x] T015 [US75] `Tests/FolzioAppTests/ExternalDragTests.swift` に、3つのビューの `draggingSourceOperationMask(forLocal: false)` が T004（T005 で直した場合はその値）、
  `forLocal: true` が `[.copy, .move]` であることと、T012 の印が通し番号ごとに分かれることのテストを加える

## Phase 5: User Story 76 - Finder の項目を Folzio のフォルダへ受け取る (P1)

**Goal**: Finder の file URL を、FR-163 と同じ宛先へ、Finder の規則で移動・コピーできる。file URL 以外は受け付けない

**Independent Test**: quickstart.md の「Finder から Folzio へ」と「file URL 以外のドラッグ」

- [ ] T016 [US76] `Sources/FolzioApp/Shared/ExternalDrag.swift` に、`urls(_:)`（`InternalDrag.urls(_:)` が nil で、`PasteboardFileURLs.fileURLs(in:)` が空でないときだけ返す。FR-348、R6）と、
  アプリ外の「操作の決め方」（マスクから `allowsMove`（`.move` か `.generic`）・`allowsCopy` を求め、`ExternalDropPolicy.allOnSameVolume`・`operation` と
  `InternalDropValidation.validate` を使う）を実装し、`DropOperationCache` に渡す（FR-345・FR-346、R3・R4）。移動を返すときは、マスクに `.move` があれば `.move`、なければ `.generic`
- [ ] T017 [US76] `Tests/FolzioAppTests/ExternalDragTests.swift` に、名前付きの `NSPasteboard`（`NSPasteboard(name:)`、テストの後に `releaseGlobally()`）を使い、
  file URL だけ・file URL と画像データ・画像データだけ・file URL でない URL だけ・文字列だけの場合に、`PasteboardFileURLs.fileURLs(in:)` が file URL だけを返すことをテストする
  （FR-348・US76-AS6）。3つのビューの登録した型が `[.fileURL]` のままであることも確かめる（R6）
- [ ] T018 [US76] `DirectoryTreeViewController.swift` の `validateDrop`・`acceptDrop`（1777〜1857 行付近）のアプリ外の経路を `ExternalDrag` に置き換える。
  宛先はアプリ内と同じ判定（実在するフォルダ行・利用可能なお気に入り。FR-345）を共通の関数にして両方で使う。ドロップ時は `cachedOperation` の結果を使い、なければ受け付けない（R4）。
  受け取りは `coordinator.drop(urls, to:, copy:)`（FR-347、R5）
- [ ] T019 [US76] `ListModeView.swift`（684〜700 行付近）と `ThumbnailModeView.swift`（1043〜1065 行付近）の `validateDrop`・`acceptDrop` に、アプリ外の経路を加える
  （FR-345・FR-346）。宛先の判定（フォルダの行・アイコンだけ、zip の中を除く）はアプリ内と同じ。ドロップ時は `cachedOperation` を使う。
  受け取りはアプリ内と同じ `onInternalDrop` の経路（`FileListViewController.swift` の 128〜135 行付近）を使い、名前を `onDrop` に変える
- [ ] T020 [US76] `Tests/FolzioCoreTests/InternalDropValidationTests.swift` に、アプリ外から受け取る場合と同じ入力（Folzio の表示と関係のない場所の項目を、表示中のフォルダへ移動・コピー、
  元の親への移動）のケースが既存のテストで足りるかを確かめ、足りなければ追加する（EC-16・EC-121、US76-AS5）

## Phase 6: ファイルリストの背景へのドロップ（FR-349。保守者の追加の決定）

**Goal**: アプリ内とアプリ外からのドラッグを、ファイルリストの背景とフォルダでない項目の上へ落として、表示中のフォルダへ移動・コピーできる

**Independent Test**: quickstart.md の「ファイルリストの背景へのドロップ」

- [ ] T026 `Tests/FolzioCoreTests/FileListDropTargetTests.swift` を作り、data-model.md の `FileListDropTarget` の表のすべての種類（フォルダ・`..`・zip の中のディレクトリ・
  メディア・zip ファイル・項目なし）と、表示中のフォルダを宛先にしない状態（zip の中・検索結果・`.denied`・`.failed`）、検索結果のフォルダの行はそのフォルダになることをテストする（先に失敗させる）
- [ ] T027 `Sources/FolzioCore/Model/FileListDropTarget.swift` を実装して T026 を通す（FR-349、R9）
- [ ] T028 `ListModeView.swift` の `validateDrop`・`acceptDrop` を `FileListDropTarget` で決めるように変える。表示中のフォルダが宛先のときは
  `setDropRow(-1, dropOperation: .on)` にし、宛先の URL は `model.listing.folder`。アプリ内は `InternalDrag`、アプリ外は `ExternalDrag` の今の経路を使う（FR-349、R9）
- [ ] T029 `ThumbnailModeView.swift` の `validateDrop`・`acceptDrop` を同じく変える。表示中のフォルダが宛先のときは `dropOperation` を `.before` にし、
  `ThumbnailCollectionView` に背景の強調の枠を描かせ、`acceptDrop`・`draggingExited(_:)`・`draggingEnded(_:)` で外す。
  フロー・レイアウトをサブクラスにして `layoutAttributesForInterItemGap(before:)` が nil を返すようにする（R9）
- [ ] T030 [MANUAL] 保守者に quickstart.md の「ファイルリストの背景へのドロップ」を確かめてもらう（T024 と一緒に行ってよい）

## Phase 7: Polish & Cross-Cutting

- [ ] T021 `docs/usage.ja.md`・`docs/usage.md` のドラッグ&ドロップの説明に、Finder・ブラウザとの受け渡し（移動・コピーの決まり方、ツリーから ⌘ で移動するときの押し方、
  Dock のゴミ箱には対応しないこと）を
  両方に同じ構成で追記する。`README.md`・`README.ja.md` の機能の概要（29 行・28 行付近）に、他のアプリとの受け渡しを同じ内容で加える（同じコミット）
- [ ] T022 Cloud で `scripts/dev/check-all.sh` を実行し、結果をこの tasks.md の Execution Notes に記録する
- [ ] T023 macOS CI で `swift build`・`swift test` を確認する（`workflow_dispatch`、または保守者の依頼で作った PR）。性能テストはログの末尾で件数を確かめる
- [ ] T024 [MANUAL] 保守者に、起動スモークと quickstart.md の「手動の確認」をローカルで実行してもらい、結果と未検証の点（research.md R4・R6・R8）の答えを
  `checklists/validation.md` に記録する。期待と違う点があれば、仕様か設計を直してから進める
- [ ] T025 検証の完了後に最新の master を取り込み、spec.md の「反映先」の項目を `specs/product/file-operations.md`・`directory-tree.md` へ反映する。
  反映の前と後に `scripts/dev/check-spec-ids.sh`、反映後に `python3 scripts/dev/check-spec-format.py` を実行する。ID が衝突すればこの feature の ID を振り直す。
  差分を保守者に示し、承認後にコミットして spec.md を凍結する

## Dependencies & Execution Order

T001 → T002 → T003（承認）→ T004 → T005（保守者の確認）→ T006〜T011 → US75（T012〜T015）→ US76（T016〜T020）→ 背景へのドロップ（T026〜T030）→ T021〜T025

- T005 の結果で仕様が変わる場合は、T006 以降の前に spec・research・tasks を直す
- T009（キャッシュの共通化）は US75・US76 の前提。アプリ内のドラッグの動作を変えないことを、既存のテストと T024（SC-184）で確かめる
- US75 と US76 は同じ3つのビューのファイルを編集するため直列にする

## Parallel Opportunities

Cloud ではタスクを分割して並列実装しない（AGENTS.md）。[P] は付けない。

## Implementation Strategy

承認 → マスクだけの版で macOS の挙動を確かめる（T004・T005）→ Core のテストと実装・共通化（T006〜T011）→ アプリ外へのドラッグ（US75）→
アプリ外からの file URL（US76）→ 静的検査・CI → 保守者の GUI 確認 → `specs/product/` への反映。

## Execution Notes

- 2026-11-07: Linear TAK-74 を In Progress に更新。作業ブランチ `claude/affectionate-carson-yaiayj`（origin/master c8840c8 を含む）
- 2026-11-07: 保守者の決定（spec の Clarifications）を記録し、spec・plan・tasks を作成
- 2026-11-07: speckit-analyze で、ブラウザの画像の取り込み（旧 US77）にキーボードの手段がない（憲章 原則 III、CRITICAL）ことが分かった。保守者の決定でこの feature から外し、
  別の Issue で扱う（A-204）。あわせて分析の MEDIUM・LOW の指摘（U1→R7、U2→EC-236・R8、G1→quickstart、A1→FR-346、T1→各タスクの ID）を反映した。
  旧 US77 に関わる G2（打ち切りのテスト）・G3（用語対応表）は、範囲外になったため不要
- 2026-11-07: 2つの AI Agent の設計レビュー（13 件）を反映した。保守者の決定: 確認の例外を FR-024・FR-079 に明記する、Dock がドラッグ元に削除を任せるなら対応しない、
  マスクだけの版で先に確かめる（Phase 2）。そのほか、Option と ⌘ の同時を OS の許可に従うよう改めた（FR-346）、EC-238 の補足、ドロップ時はキャッシュを使う、
  キャッシュと file URL の読み出しの共通化、ツリーの ⌘ の押し方（A-132）、衝突の中止で完了済みの項目が残ること（SC-182）、検索結果の遅れた結果の抑止（R8・T013・T014）、
  US76-AS6・SC-183 を file URL を持たないドラッグに限ったこと、キーボードの手段（ツリー・お気に入り）の記述を直した
- 2026-11-07: 2回目の設計レビュー（5 件）を反映した。保守者の決定: 遅れた検索結果を防ぐ記録は、ドラッグの終了ではなく FSEvents の除外（`pruneMissingResults`）で行う
  （R8・T013・T014。Finder の移動が非同期で、ドラッグの終了の時点では記録できない恐れがあるため）。そのほか、SC-182 の根拠をテストに直し、EC-238 の ⌘ を `.generic` と明記し、
  plan の実装の順序の番号を直し、contracts のキーボードの手段にツリーの ⌘V・⌥⌘V を加えた
- 2026-11-07: 3回目の設計レビューを反映した。FSEvents の除外で結果の行のファイルだけを記録すると、フォルダごと移動されたときに同じフォルダの別のファイルの遅れた結果が出るため、
  一番上の消えた祖先のフォルダ（検索のルートまで）を記録するようにした（spec の Clarifications・EC-236、R8、data-model、T013・T014）
- 2026-11-07: 保守者が設計を承認（T003）。T014 に、検索のルートを detached task の前に取り出す注意を加えた（保守者の指摘。設計の変更なし）
- 2026-11-07: T004 を実装（`6e8f2a3`。`ExternalDrag.sourceOperationMaskOutsideApp` を3つのビューのアプリ外向けのマスクにした）。`check-all.sh` 成功。
  CI（workflow_dispatch、run 42375125145 attempt 1）: build 成功、通常のテスト 1057 件すべて成功、性能テスト 27 件中 1 件失敗
  （`didRenameFolder` 10,000 件の中央値 0.107 秒、基準 0.1 秒。`PerformanceBaselineTests.swift:367`）。T004 は `BrowserModel` に触れていないため、共有ランナーのぶれと考え、
  コードを変えずに再実行した（docs_private/cloud-agent-workflow.md の 4 章）
- 2026-11-07: CI の再実行（run 42375125145 attempt 2、`6e8f2a3`）: build・通常のテスト成功、性能テスト 27 件中 4 件失敗（`didRenameFolder` 中央値 0.175 秒、
  256 件のバッチ 0.102 秒、スライドショー 50,000 件 0.131 秒、200,000 件 0.255 秒）。ランナー全体が遅かった（10,000 件の検索 0.98 秒。attempt 1 は 0.52 秒）。
  TAK-74 より前の run 42287354217（`968951c`、TAK-41）でも同じ4件を含む5件が失敗しており（`didRenameFolder` 中央値 0.164 秒）、TAK-74 の変更によるものではない。
  `didRenameFolder` は3回とも基準 0.1 秒を超えている（0.164・0.107・0.175 秒）ため、TAK-74 とは別に保守者へ報告する。これ以上の再実行はしない
- 2026-11-07: T005 の確認の結果を保守者から受け取った（`checklists/validation.md`）。Finder の移動・コピーは設計どおり。Dock のゴミ箱はファイルが元の場所に残ったため、
  保守者の先の決定どおり Dock のゴミ箱には対応しないことにし、`.delete` をマスクから外し、FR-079 の変更を取り下げた（spec・research・data-model・plan・contracts・quickstart）。
  Option と ⌘ の同時は、Finder へは受け付けられず（A-206 と合う）、Finder から Folzio へはコピーになる（FR-346 に追記）。
  `.delete` を外した後に Dock のゴミ箱が受け付けないことは T024 で確かめる
- 2026-11-07: `b6858dd`（`.delete` を外した版）の CI（workflow_dispatch、run 42377626115）: build・通常のテスト成功、性能テスト 27 件中 2 件失敗
  （24 MP の JPEG のデコード 0.541 秒（基準 0.5 秒）、`didRenameFolder` 中央値 0.137 秒（基準 0.1 秒））。どちらも TAK-74 より前の run 42287354217 で失敗しているテストで、
  TAK-74 の変更によるものではない
- 2026-11-07: T006〜T011 を実装（`891ff4f`）。CI（workflow_dispatch、run 42379002585）: build 成功、通常のテスト 1064 件すべて成功（前回の 1057 件に、
  `ExternalDropPolicyTests` 4 件と `DropOperationCacheTests` 3 件を加えた数と一致）、性能テスト 27 件中 1 件失敗（`didRenameFolder` 中央値 0.105 秒。TAK-74 以前から失敗しているテスト）。
  Cloud のネットワーク設定でログの全文をダウンロードできないため、新しいテストの個別の結果は、件数の一致で確かめた
- 2026-11-07: T012〜T015 を実装。T014 の一番上の消えた祖先を求める処理は、data-model.md のとおり純粋な関数 `SearchRemovalScope.topmostMissing`
  （`Sources/FolzioCore/Search/SearchRemovalScope.swift`）に分け、ルートの外へたどらないこと（T013 の（3））はこの関数の単体テスト（`SearchRemovalScopeTests`）で確かめた。
  `BrowserModel` を通すテストでは、すべての結果がルートの下にあるため、この違いが外から見えない。記録したフォルダの下にある表示中の行も、`didMoveSearchItems` と同じく外す。
  T015 は、3つのビューを作るのに `BrowserModel` が要り、`FolzioAppTests` は `FixtureKit` に依存しないため、ビューごとのマスクではなく、共通の定数
  （`ExternalDrag.sourceOperationMaskOutsideApp`）と受け取った印をテストした。ビューごとのマスクは、3か所がこの定数を使うことをコードで確かめ、GUI（T024）で確かめる。
  ツリーの `draggingSession(_:endedAt:operation:)` は、AppKit がドロップ先の `acceptDrop` を終えてからドラッグ元に知らせるため、アプリ内のドロップでは印が先に残る前提にした
- 2026-11-07: T012〜T015（`5d3648a`）の CI（workflow_dispatch、run 42380089056）: build 成功、通常のテスト 1073 件すべて成功（1064 件に `SearchRemovalScopeTests` 5 件、
  `BrowserModelSearchTests` 2 件、`DragsToOtherAppsTests` 2 件を加えた数と一致）。性能テスト 27 件中 6 件失敗（ランナー全体が遅かった。10,000 件の検索 0.875 秒、
  1 GB のストリーム 122 秒）。今回初めて失敗した「Enumerates and sorts huge(10,000)」（1.105 秒）は `DirectoryLister` を測るテストで、T012〜T015 は触れていない。
  ほかの 5 件は TAK-74 以前から失敗している種類
- 2026-11-07: T016〜T020 を実装。ツリーのアプリ外からのドロップは、アプリ内と同じ宛先の判定（`dropDestination(for:)`。利用可能なお気に入りを含む）と、
  行の上だけ（行間は不可）にそろえた。T017 の登録した型は、3つのビューが `[.fileURL]` のままであることをコードで確かめた（ビューを作るテストは T015 と同じ理由で書けない）。
  T020 は、既存の `InternalDropValidationTests` が、Folzio の表示と関係のない場所の項目の移動・コピー（valid）・元の親への移動（sameParent）・自身と配下（intoItself）・
  親子の同時（overlappingSources）を確かめており、検証は表示に依存しないため、テストを加えなかった
- 2026-11-07: 保守者の追加の決定で、ファイルリストの背景へのドロップを、アプリ内とアプリ外の両方で受け付けることにした。フォルダでない項目の上も背景として扱う
  （spec の Clarifications、FR-163（変更）・FR-345・FR-349・US76-AS4・US76-AS7〜AS8・SC-185・A-207、research.md R9、data-model.md、contracts、quickstart、T026〜T030）

