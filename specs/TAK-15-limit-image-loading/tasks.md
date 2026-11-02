# Tasks: 連続選択時の画像読み込み数と不要な先読みを制御する

**Input**: `specs/TAK-15-limit-image-loading/` の spec.md・plan.md・research.md・data-model.md・contracts/core-api.md・quickstart.md

**Status**: 2026-11-01 保守者が設計を承認し、T004〜T015 を実装した。Cloud では Swift を実行できないため、ビルドとテストは CI（T016・T018）で確認する。

**Tests**: 憲章 IV によりコアロジックのテストは必須。Cloud では Swift を実行できないため、macOS CI で確認する。

## Phase 1: Setup

- [x] T001 origin/master（22e0a3c）が作業ブランチの祖先であることを確かめ、TAK-15 を In Progress にし、spec.md に Issue の URL と保守者の回答（Clarifications）を記録する
- [x] T002 spec.md・plan.md・research.md・data-model.md・contracts/core-api.md・quickstart.md を作る
- [x] T003 [MANUAL] 設計レビュー（analyze の結果を含む）の承認を保守者から受ける。承認前にソースを実装しない。FR-285 の採用、F1・F3・F4・F5・F6・F7 の反映、
  上限の値（合計 2、先読み 1）は承認済み（2026-11-01）

## Phase 2: Foundational（全ストーリーの前提）

- [x] T004 Sources/FolzioCore/Imaging/ImageLoadScheduler.swift に `ImageLoadPriority` と `ImageLoadScheduler`（actor）を作る。`limit` 既定 2、`prefetchLimit` 既定 1、
  `acquire(_:) async -> Bool`（取り消されていれば `false`、待機中の取り消しで待機者を外して `false`、取得後に取り消されていれば枠を返して `false`）、`release(_:)`、
  `peakRunning`。空いた枠はプレビューの待機者、次に（`runningPrefetches < prefetchLimit` のとき）先読みの待機者へ渡す（data-model.md、FR-282、FR-284、EC-198）
- [x] T005 [P] Tests/FolzioCoreTests/ImageLoadSchedulerTests.swift を作り、次を確かめる: 上限 2 を超えて取得できない／先読みは同時に 1 件まで／
  枠が空いたときプレビューの待機が先読みの待機より先に得る／待機中に取り消すと `false` で枠を取らず後続を妨げない／
  取得後に取り消された場合に枠が戻る／`peakRunning` が 2 以下。固定時間の待機は使わず、決定的に制御する（research.md R5）
- [x] T006 [P] Sources/FolzioCore/Imaging/ImageDecoder.swift の 2 つの `decode` を `withTaskCancellationHandler` で包み、内側の `Task.detached` に取り消しを伝え、
  本体の開始前に取り消されていれば `decodeSynchronously` を始めない。取り消し時は既存の `DecodeError` を投げる（新しい case は足さない。contracts/core-api.md、R2、EC-196）。
  Tests/FolzioCoreTests/ImageDecoderTests.swift に、開始前に取り消したタスクがデコードされないテストを足す
- [x] T007 Sources/FolzioCore/Browser/BrowserModel.swift の `init` に `loadScheduler: ImageLoadScheduler = ImageLoadScheduler()` を末尾の引数として足し、
  プロパティに保持する。既存の呼び出し（`Sources/FolzioApp` とテスト）が変更なしでビルドできることを確かめる

**Checkpoint**: Core がビルドでき、既存のテストが通る（挙動はまだ変わらない）

## Phase 3: User Story 1（US57）- 画像を連続して送っても読み込みが積み上がらない (P1 / MVP)

**Goal**: FR-282〜286、EC-196〜200（通常の画像）。**Independent Test**: quickstart.md の自動テストの表と目視のシナリオ 1

- [x] T008 [US1] Sources/FolzioCore/Browser/BrowserModel.swift の `decodedImage(for:version:)` に `priority` を足し、「キャッシュ参照 → 枠の取得（`false` なら取り消しとして終了）→
  取得後にもう一度キャッシュ参照 → デコード → 格納 → 枠の返却」にする。キャッシュ参照だけで済む場合は枠を通さない（FR-282、EC-197、EC-198）。
  プレビューは `.preview`、先読みは `.prefetch`。取り消し後に終わった結果は、キャッシュにだけ入れる（EC-196）。取り消し（`Task.isCancelled`）で投げられた `DecodeError` は失敗として扱わない:
  「表示できません」を出さず、失敗をキャッシュせず、枠だけ返す
- [x] T009 [US1] Sources/FolzioCore/Browser/BrowserModel.swift の `prefetchTasks` を `[URL: PrefetchEntry]` にする（`PrefetchEntry` は `task` と、枠を取得した時点で立てる `isRunning`。data-model.md）。
  `schedulePrefetch(around:)` は、前後 1 件（次の画像、前の画像の順）に入らない項目を `cancel()` して外し、すでにある項目は作り直さない（FR-283）。
  `noteReplacedContent` と `resetForNavigation` を新しい型に合わせる（EC-199）
- [x] T010 [US1] Sources/FolzioCore/Browser/BrowserModel.swift の `loadPreview(for:)` が、フォーカスする URL の `PrefetchEntry` を `prefetchTasks` から取り出す（FR-283、FR-285、R3）。
  実行中なら、`startImagePreview` と `loadArchivePreview` が作るプレビューのタスクの中でその完了を待ってからキャッシュを参照する
  （`loadPreview` 本体では待たない。待った後も `previewGeneration` を照合する。得られなければ通常の読み込みに進む）。待機中なら先読みを取り消して、プレビューの優先度で読み込む。
  `select` で `loadPreview` の後に `schedulePrefetch` が呼ばれる順序を保つ
- [x] T011 [US1] Tests/FolzioCoreTests/BrowserModelImageLoadTests.swift を作る。完了を制御し、同時実行数の最大値を記録する偽の decoder（`ImageDecoding`）を使い、次を確かめる:
  40 回の連続選択で最大が 2 以下（SC-145、US57-AS1）／最後に選択した画像だけが `preview` に反映される（FR-286、US57-AS2）／
  連続選択の後に開始された先読みが最後の選択の前後 1 件だけで、通過した画像の先読みは開始前なら実行されない（SC-146、US57-AS3・AS4）／
  先読みは同時に 1 件まで（FR-284）／先読み中の画像を選択してもデコードは 1 回（FR-285）／デコードが失敗した後も次の画像を表示できる（EC-198）／
  フォルダの移動で待機中の先読みが取り消される（EC-199）／動画を通過しても先読みの取り消しが同じに働く（EC-200）
- [x] T012 (変更不要と判断。先読みは順次でも `waitForCache` が最大 2 秒待つため通る見込み。CI で確認する) [US1] 既存の Tests/FolzioCoreTests/BrowserModelTests.swift の隣接 2 件の先読みのテストが、先読みの順次処理（同時に 1 件）でも通るように、
  2 件が読まれることを待つ形に調整する。必要がなければ変更しない（research.md R5）

**Checkpoint**: 通常の画像で US57 が自動テストで確認できる

## Phase 4: User Story 2（US58）- zip の中の画像でも同じ上限が働く (P2)

**Goal**: FR-282〜286（zip）。**Independent Test**: quickstart.md の自動テストの表と目視のシナリオ 2

- [x] T013 [US2] Sources/FolzioCore/Browser/BrowserModel.swift の `archiveImage(for:version:maxPixelSize:)` に `priority` を足し、「キャッシュ参照 → 枠の取得 → 項目の読み出し → デコード → 格納 →
  枠の返却」にする。先読みと `loadArchivePreview` のどちらも同じ経路で `PrefetchEntry` の印と引き継ぎ（T009・T010）を使う。アニメーション画像は `Data` を返す前に枠を返す
- [x] T014 [US2] Tests/FolzioCoreTests/BrowserModelImageLoadTests.swift に、偽の zip リーダー（Tests/FolzioCoreTests/BrowserModelArchiveTests.swift の方式）を使った
  zip の画像の 40 回の連続選択のテストを足す: 項目の読み出しとデコードを合わせた同時実行数が 2 以下（US58-AS1）／zip から出ると待機中の先読みが取り消される（US58-AS2、EC-199）

**Checkpoint**: zip の画像で US58 が自動テストで確認できる

## Phase 5: User Story 3（US59）- 通常の操作の応答が落ちない (P3)

**Goal**: SC-147、US59。**Independent Test**: 既存の性能テストと quickstart.md のシナリオ 3

- [x] T015 [US3] Tests/FolzioCoreTests/BrowserModelImageLoadTests.swift に、先読み済みの隣接画像への切り替えがキャッシュから行われ枠を通さないこと（US59-AS1、EC-197）と、
  先読みが 1 件実行中でも未読込の画像のプレビューが先読みの終了を待たずに始まること（US59-AS2、FR-284）を確かめるテストを足す
- [x] T016 [US3] Tests/FolzioPerformanceTests の既存の基準（SC-001）を変更せずに、変更後も通ることを CI で確認する（SC-147）。基準値を緩めない
  （2026-11-01 CI 実行 41350559595: SC-001 の「24 MP JPEG のデコード 0.5 秒以内」「先読み済みの隣接ファイルへの切り替え 0.1 秒以内」「プレビューのキャッシュ 256 MB 以内」は成功。
  27 件中 1 件 `didRenameFolder handles 10,000 search results` が 0.112 秒（基準 0.1 秒）で失敗。検索結果の名前変更の測定で、この feature が変更していない経路。共有ランナーでの測定のぶれの可能性があるが、原因は未調査）
  2026-11-02 master（9a5d9cc）取り込み後の CI 実行 41475877069（コミット f4114e2、4 回目の試行）: ビルド成功、通常のテスト 1047 件すべて成功、性能テスト 27 件中 26 件成功。
  失敗は同じ 1 件（0.105 秒、基準 0.1 秒）で、取り込み前（0.112 秒）にも失敗していた。master 単体で同じ失敗が出るかは、比較していない。
  試行 1〜3 は、GitHub Actions の予算が 0 ドルで設定されていたため、ステップが実行される前に失敗した（コードの失敗ではない）

## Phase 6: Polish & 検証

- [x] T017 Cloud の検査を行う: `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`、
  `python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py"`。新しいソースのコメントは英語で、doc comment は三人称単数・現在形で書く（AGENTS.md）
- [x] T018 作業ブランチを push する。保守者が PR を依頼したら PR を作り、CI の結果（通常のテストと、性能テストのログの末尾）を確認し、PR 本文に性能テストの結果を記載する（憲章 II）。失敗はログを読んでまとめてから直す
- [ ] T019 [MANUAL] 保守者に、ローカルの最新 Swift での build/test、起動スモーク、quickstart.md のシナリオ 1〜3 を依頼し、結果を quickstart.md に記録する。
  報告があるまで未チェックのままにする（A-179）
- [ ] T020 実装と検証の後、`specs/product/` へ反映する（spec.md の「反映先」の表）。反映の直前に `git merge origin/master` し、ID の衝突を
  `grep -rhoE '^\s*- \*\*(FR|SC|EC|A)-[0-9]+\*\*' specs/product | sed -E 's/^\s*- //' | sort | uniq -d` で確かめ、feature の spec.md の冒頭に凍結の注記を入れる。
  保守者の承認を得てからコミットする

## Dependencies

- T003 → T004 以降（承認前に実装しない）
- T004 → T005、T008（T006 は独立）、T007 → T008
- T008 → T009 → T010 → T011 → T012。US2（T013・T014）は T009・T010 の後（T013 は T010 の引き継ぎ処理を使う）。US3（T015・T016）は T011 の後
- T017〜T020 は実装の後。T019 は CI の成功の後

## Parallel Opportunities

- T005 と T006 は別のファイルで、T004 の後に並行できる（Cloud では並列の単位は Issue のため、実際には順に行う）

## Implementation Strategy

MVP は US57（T004〜T012）。通常の画像で上限と取り消しが働けば、報告された懸念の大部分が解消する。US58 は zip の経路を同じ仕組みに載せ、US59 は回帰の確認。
