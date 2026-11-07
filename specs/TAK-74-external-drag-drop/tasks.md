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
- [ ] T005 [MANUAL] 保守者に、quickstart.md の「先に行う確認」を T004 の版で実行してもらい、結果を `checklists/validation.md` に記録する。
  Dock のゴミ箱がファイルを移さない場合は `.delete` をマスクから外し、spec の FR-344・US75-AS5・FR-079（変更）と contracts・quickstart を直す（保守者の決定）。
  Option と ⌘ の同時、Finder の移動・コピーの結果が設計と違う場合は、spec・research を直して保守者に確かめてから T006 に進む

## Phase 3: Foundational（全ストーリーの前提）

- [ ] T006 `Tests/FolzioCoreTests/ExternalDropPolicyTests.swift` を作り、data-model.md の表のすべての組み合わせ（option・command・allOnSameVolume）と、
  優先する操作が許可されないときの切り替え・`nil`（EC-238）、Option と ⌘ の同時で `allowsMove`・`allowsCopy` がどちらも false のときの `nil` をテストする（FR-346）。
  `allOnSameVolume` は、一時フォルダの中の項目で true、存在しない項目を含むときに false（値が取れなければ false。EC-237）をテストする（先に失敗させる）
- [ ] T007 `Sources/FolzioCore/Operations/ExternalDropPolicy.swift` を実装して T006 を通す（FR-346・EC-237・EC-238、R3・R4）。
  `operation(option:command:allOnSameVolume:allowsMove:allowsCopy:) -> Operation?` と `allOnSameVolume(_:destination:) -> Bool`
  （`URLResourceValues.volumeIdentifier` を比べる。UI スレッドで呼ばない旨をコメントに書く）
- [ ] T008 `Sources/FolzioApp/Shared/PasteboardFileURLs.swift` を作り、`InternalDrag.urls`・`FileOperationCoordinator.pasteboardFileURLs`・
  `DirectoryTreeViewController.fileURLs(from:)` の file URL の読み出しを `fileURLs(in:)` にまとめる（R4・R6。動作は変えない）
- [ ] T009 `Sources/FolzioApp/Shared/DropOperationCache.swift` を作り、`InternalDrag` の通し番号ごとのキャッシュ（`cache`・`pending`・`currentSequence`）を移す。
  通し番号ごとに URL の配列も1回だけ読んで保持する。「操作の決め方」を渡せるようにし、`InternalDrag.operation` はアプリ内の決め方（Option でコピー、なければ移動）を渡す。
  ドロップ時に使う `cachedOperation`（キャッシュがなければ nil。ファイルシステムを読まない）を加え、アプリ内の `acceptDrop` もそれを使う（data-model.md、R4。アプリ内の動作は変えない）
- [ ] T010 `Tests/FolzioAppTests/ExternalDragTests.swift` を作り、`DropOperationCache` が通し番号の変化でキャッシュと URL を捨てること、同じ通し番号では URL を読み直さないこと、
  `cachedOperation` が結果の前は nil を返すことをテストする
- [ ] T011 `Sources/FolzioApp/Operations/FileOperationCoordinator.swift` の `internalDrop(_:to:copy:)` を `drop(_:to:copy:)` に改名し、
  `DirectoryTreeViewController.swift` と `Sources/FolzioApp/FileList/FileListViewController.swift` の呼び出しを直す（FR-347、R5。動作は変えない）

## Phase 4: User Story 75 - Folzio の項目を他のアプリへ渡す (P1)

**Goal**: ツリー・リスト形式・サムネイル形式から、Finder・ブラウザ・Dock のゴミ箱へドラッグして移動・コピー・アップロード・ゴミ箱を行える

**Independent Test**: quickstart.md の「Folzio からアプリ外へ」

- [ ] T012 [US75] `Sources/FolzioApp/Shared/InternalDrag.swift` に、通し番号ごとの「Folzio のビューで受け取った」印（`markAccepted(_:)`・`wasAccepted(_:)`）を加え、
  ツリー・リスト形式・サムネイル形式のアプリ内の `acceptDrop` で印を残す。ツリーの `draggingSession(_:endedAt:operation:)`（1762 行付近）で、
  操作がない場合に加えて印がない場合（アプリ外へドロップした場合）も `pendingOperationSources` を消す。`.delete` で終わっても Folzio は何も削除せず、
  結果は FSEvents に任せる旨をコメントに書く（FR-219・FR-344・EC-236、R2・R7）
- [ ] T013 [US75] `Tests/FolzioCoreTests/BrowserModelSearchTests.swift` に、次をテストする（EC-236、先に失敗させる）。
  （1）検索の途中でフォルダ `trip/day1` を外部で移動し、`handleFileSystemEvent` でその親を報告すると、配下の行 `trip/day1/cat.jpg` が外れ、
  その後に遅れて届く同じフォルダの別のファイル `trip/day1/bird.jpg`（外れた行とは別のファイル）が表示されない。
  （2）ファイル `trip/day2/a.jpg` だけを消したときは、同じフォルダのまだある結果と、後から届く `trip/day2/b.jpg` は表示される（フォルダを記録しない）。
  （3）検索のルートの外へはたどらない。（4）新しい検索を始めると記録が消える。既存の 9 行目のテストは、遅れた結果に同じファイルを送るため、この確認には使わない
- [ ] T014 [US75] `Sources/FolzioCore/Browser/BrowserModel.swift` の `pruneMissingResults(under:)`（1473 行付近）の detached task の中で、`missing` の各 URL の親をたどり、
  まだある親の直下の消えたもの（一番上の消えた祖先。検索のルート（`listing.search?.root`。`listing` は MainActor の状態なので、detached task を始める前に値として取り出して渡す）まで、ルートが消えていればルート）を求め、`movedSearchPaths` に加えて T013 を通す
  （R8）。1回の呼び出しの中で確かめたフォルダの結果を覚えて、同じフォルダを繰り返し調べない。既存の `BrowserModelSearchTests` が通ること
- [ ] T015 [US75] `Tests/FolzioAppTests/ExternalDragTests.swift` に、3つのビューの `draggingSourceOperationMask(forLocal: false)` が T004（T005 で直した場合はその値）、
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

## Phase 6: Polish & Cross-Cutting

- [ ] T021 `docs/usage.ja.md`・`docs/usage.md` のドラッグ&ドロップの説明に、Finder・ブラウザ・ゴミ箱との受け渡し（移動・コピーの決まり方、ツリーから ⌘ で移動するときの押し方）を
  両方に同じ構成で追記する。`README.md`・`README.ja.md` の機能の概要（29 行・28 行付近）に、他のアプリとの受け渡しを同じ内容で加える（同じコミット）
- [ ] T022 Cloud で `scripts/dev/check-all.sh` を実行し、結果をこの tasks.md の Execution Notes に記録する
- [ ] T023 macOS CI で `swift build`・`swift test` を確認する（`workflow_dispatch`、または保守者の依頼で作った PR）。性能テストはログの末尾で件数を確かめる
- [ ] T024 [MANUAL] 保守者に、起動スモークと quickstart.md の「手動の確認」をローカルで実行してもらい、結果と未検証の点（research.md R4・R6・R8）の答えを
  `checklists/validation.md` に記録する。期待と違う点があれば、仕様か設計を直してから進める
- [ ] T025 検証の完了後に最新の master を取り込み、spec.md の「反映先」の項目を `specs/product/file-operations.md`・`directory-tree.md` へ反映する。
  反映の前と後に `scripts/dev/check-spec-ids.sh`、反映後に `python3 scripts/dev/check-spec-format.py` を実行する。ID が衝突すればこの feature の ID を振り直す。
  差分を保守者に示し、承認後にコミットして spec.md を凍結する

## Dependencies & Execution Order

T001 → T002 → T003（承認）→ T004 → T005（保守者の確認）→ T006〜T011 → US75（T012〜T015）→ US76（T016〜T020）→ T021〜T025

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
