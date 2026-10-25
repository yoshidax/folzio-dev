---
description: "スライドショー実装タスク"
---

# Tasks: スライドショー

**Input**: `specs/006-add-slideshow/` の spec.md・plan.md・research.md・data-model.md・contracts/slideshow.md・quickstart.md、および spec が参照する `specs/product/` の領域・契約、憲章 v1.2.0。

**Prerequisites**: `006-add-slideshow` ブランチ。Swift 6 / macOS 15+ / AppKit / 単一 Swift Package。外部依存・新しい永続化キーなし。

**Tests**: spec の User Scenarios & Testing・SC-033〜037、plan の Swift Testing 方針と憲章 IV に従い、判断ロジック・異常系・競合の自動テストを含む。テストを先に追加し、実装前に期待する失敗を確認する。実時間 sleep で3秒周期を繰り返す単体テストは作らず、任意 now を注入する。

**Organization**: Story 番号は仕様の US9・US10・US11 を保持する。各 Story は前提 Phase 完了後、独立した受け入れ確認を行える増分とする。

## Format: `[ID] [P?] [Story] Description`

- `[P]`: 同じ Phase 内で、前提完了後に別ファイルとして並行処理できる候補。既定は順次実装。
- `[US9]` / `[US10]` / `[US11]`: spec.md の Story との対応。Setup・Foundational・最終 Phase には付けない。
- パスはリポジトリルートからの相対パス。新規ファイルも明示する。

## Path Conventions

- Core: `Sources/MediaViewerCore/`（AppKit を import しない）
- App: `Sources/MediaViewerApp/`（MainActor で描画・入力・ウィンドウを扱う）
- Fixtures: `Sources/FixtureKit/`、テスト: `Tests/MediaViewerCoreTests/`・`Tests/MediaViewerPerformanceTests/`
- 実装中に更新する設計文書は本書のチェックと、タスクで明示した quickstart 追記のみ。product への反映は T056 まで行わない。

## 共通の実装・検証規則

- 列挙・デコード・zip 展開・ファイル操作は UI スレッドに載せず、既存キャッシュ上限・zip の直接読み込みを維持する。通信 API は追加しない。
- 各 Phase 末尾のゲートは build → 全 test → no-network → bundle 作成 → ユーザーの起動スモーク → コミットの順。GUI の起動はユーザーに依頼し、未実施を合格・完了にしない。
- quickstart の「Phase 検証記録」は各ゲートで追記してよい。日付・コマンド結果・GUI 確認内容・未実施項目を記録する。
- AppKit の禁止 split delegate override は追加しない。minimumThickness 160/240/320pt、canCollapse の切替手順、addSubview 後の制約有効化を守る。

## 解析後の文書修正（2026-10-25）

- U1: FR-118/120/121/123 の入力受理条件とモーダル中の固定周期を、下記の未着手タスクへ反映した。今回の編集では実装・テスト実行・完了チェックを行っていない。完了済みタスクは0件。
- I1: 実行中の並べ替え操作を追加するか、順序変更への追従だけを保証するかは人の判断待ち。A-51 と並べ替え操作の契約は未変更。実装開始前に判断し、関連文書・タスクを揃える必要がある。

## Phase 1: Setup — 検証データと既存構成の確認

**Purpose**: 既存 Package を利用し、全 Story で再現可能な検証入力を用意する。

- [ ] T001 新規 `Tests/MediaViewerCoreTests/SlideshowFixtureTests.swift` に、slideshow セットの mixed・single・empty・同名別場所・zip の階層と短長動画を検査する Swift Testing を追加する。`FixtureKit` の一時ディレクトリに生成し defer で削除する

- [ ] T002 `Sources/FixtureKit/FixtureSets.swift` に `slideshow(in:)` を追加して `makeAll` から呼び、`slideshow/mixed/`（画像3件・GIF・1秒 MP4・10秒 MOV・subfolder・zip・text）、single/、empty/、search/left/same.jpg・right/same.jpg、mixed と sub を含む slides.zip を生成する。既存 ImageFixtures・VideoFixtures・ZipFixtureWriter を再利用する

- [ ] T003 `Package.swift` の既存 target と `Sources/make-fixtures/main.swift` の makeAll 経路で追加セットを生成できることを確認し、`scripts/make-fixtures.sh .build/SlideshowFixtures` を実行する。既存同梱 WebP を利用し、外部ツール導入が必要ならユーザーへ確認する

- [ ] T004 `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗は最大3回の修正までとする。結果を `specs/006-add-slideshow/quickstart.md` の「Phase 検証記録」へ追記する

- [ ] T005 ユーザーに `cd /Users/igachan/projects/my_img_viewer` と `open .build/MediaViewer.app` の実行を依頼し、通常起動の3ペイン表示と既存のフォルダ／zip プレビューが維持されることを確認してもらう。結果を `specs/006-add-slideshow/quickstart.md` へ追記し、GUI 未実施ならこのタスクを未チェックに保つ

- [ ] T006 直前の自動・GUI ゲート合格後、当該 Phase のソース・テスト・`specs/006-add-slideshow/tasks.md`・明示された quickstart 追記だけを確認して Phase 単位でコミットする（push は行わない）

**Checkpoint**: 共通フィクスチャ・既存回帰ゲートが揃う。

## Phase 2: Foundational — 共通の可否と閲覧先置換の境界

**Purpose**: 全 Story が使うコマンド抑止と、一覧を置換する前の同期停止を保証する。

**Blocking**: T007〜T013 完了後に Story 実装へ進む。

- [ ] T007 `Tests/MediaViewerCoreTests/PaneLayoutTests.swift` に、active／restoring 中の canChangeLayout・canNavigateHistory が false、非実行時は既存条件のままというテストと、開始可否の候補数・全3種編集・モーダル・読み込み中・全画面の真理値表テストを追加する。FR-123 の入力受理条件について、active／restoring、対象ウィンドウへの入力か、シート・アプリモーダル・編集欄・メニュー等による入力所有の各真偽を組み合わせた純粋な可否判断の試験も追加する（U1）

- [ ] T008 `Sources/MediaViewerCore/Model/PaneLayout.swift` の PaneCommands に active／restoring を入力する条件と共通の開始可否判断を追加する。候補あり AND 非実行／非復帰 AND 非編集 AND 非モーダルを守り、既存呼び出しを壊さず隠れたペインの focus／検索制限を維持する。Esc／矢印の共通入力受理判断も追加し、active AND 対象ウィンドウがキー入力先 AND 対象のシートなし AND アプリモーダルなし AND 編集欄・メニュー等がキーを処理していない場合だけ true とする。AppKit の状態は App から真偽値で渡す（U1）

- [ ] T009 新規 `Tests/MediaViewerCoreTests/BrowserModelSlideshowTests.swift` に、通常移動・zip 階層・検索置換・履歴復元の通知が一覧変更前に同期発火し、rename では発火しないこと、同じ URL へ戻っても旧 reload が採用されないことを追加する

- [ ] T010 `Sources/MediaViewerCore/Browser/BrowserModel.swift` の resetForNavigation 入口へ専用の同期 `onWillReplaceLocation` 通知を追加し、既存 onLocationEvent を維持する。reloadCurrentFolder の結果採用に navigationGeneration を照合し、URL 一致だけで旧処理を採用しない。didRenameFolder 等の場所付け替えは置換扱いにしない

- [ ] T011 `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗は最大3回の修正までとする。結果を `specs/006-add-slideshow/quickstart.md` の「Phase 検証記録」へ追記する

- [ ] T012 ユーザーに `cd /Users/igachan/projects/my_img_viewer` と `open .build/MediaViewer.app` の実行を依頼し、通常起動の3ペイン表示と通常移動・検索・zip 階層移動・名前変更に回帰がないことを確認してもらう。結果を `specs/006-add-slideshow/quickstart.md` へ追記し、GUI 未実施ならこのタスクを未チェックに保つ

- [ ] T013 直前の自動・GUI ゲート合格後、当該 Phase のソース・テスト・`specs/006-add-slideshow/tasks.md`・明示された quickstart 追記だけを確認して Phase 単位でコミットする（push は行わない）

**Checkpoint**: コマンド可否と置換前通知を Story から利用できる。

## Phase 3: User Story 9 — 表示中のメディアを順番に鑑賞する（P1 / MVP の核）

**Goal**: 最新一覧の対象を preview-only で固定3秒ごとに循環し、通常ウィンドウで開始・終了・更新・動画・検索・履歴を正しく扱う。

**Independent Test**: mixed を降順・フィルタ付きで途中選択から開始して2周し、通常フォルダ・zip 現在階層・検索結果の対象と順序を照合する。0件開始不可、1件動画維持、削除後の空選択、Esc 後6秒間0回、3種 layout 復帰を確認する（US9-AS1〜16）。全画面の最終受け入れは Phase 5。

### Tests for US9

- [ ] T014 [P] [US9] 新規 `Tests/MediaViewerCoreTests/SlideshowSequenceTests.swift` に、空／1件／非メディア混在、画面外を含む現在順序、選択内 focused 優先→選択内先頭→候補先頭、末尾循環、行番号変更、通常 URL と ArchiveURL の同名別場所を検証する。表示不能でも kind.isMedia なら除外しない

- [ ] T015 [P] [US9] 新規 `Tests/MediaViewerCoreTests/SlideshowSessionTests.swift` に、任意 now による3秒未満0回・期限で pending→commit 1回・20周期・遅延で最大1回・重複 start 無変化・古い世代拒否・stop と due の両到着順・終了後0回を追加する。decode／動画終端／一覧更新が期限を変えないことも検証する。モーダル開閉や不適格な Esc を App が session へ通知しないイベント列でも元の期限で最大1回だけ送り、閉じた直後に期限を取り直さないことを任意 now で固定する（U1）

- [ ] T016 [P] [US9] `Tests/MediaViewerCoreTests/BrowserModelSlideshowTests.swift` に、同じ動画の開始・1件 tick で preview 世代／stop signal が変わらないこと、別対象で停止すること、フィルタ／検索追加／削除／rename／zip 変更／消失の選択整理、置換前停止、遅い reload／decode の拒否を追加する

- [ ] T017 [P] [US9] `Tests/MediaViewerCoreTests/HistoryNavigatorTests.swift` に presentation host の復帰 layout 投影を使う試験を追加し、開始／終了／選択で履歴を増やさず、通常閲覧の形式・サイズ・フィルタ変更は復帰 layout で記録、検索中は非記録・後の解除時に現在表示を反映することを検証する

### Implementation for US9

- [ ] T018 [US9] 新規 `Sources/MediaViewerCore/Slideshow/SlideshowSequence.swift` に対象抽出・startTarget・nextTarget を実装する。visibleFiles は「`BrowserModel.listing.files` 全体。順序を保つ」、candidates は「`kind.isMedia` の項目だけ。都度導出し、開始時の固定列を正本にしない」、selected は「既存 `SelectionState.selected`」、focused は「既存 `SelectionState.focused`。現在位置の正本」を守る。MediaFile.id == url と ArchiveURL を再利用し、独立 index・データ本体を保持しない

- [ ] T019 [US9] 新規 `Sources/MediaViewerCore/Slideshow/SlideshowSession.swift` に外部 now 入力の値型を実装する。phase は idle / running / waitingAfterArrow とし、「waiting は最後の矢印からの3秒待ち。専用一時停止機能ではない」、interval は「常に3秒。変更・永続化しない」、deadline は「active のとき1つ。idle は nil」、generation は「開始・再設定・終了で古い待機と pending due を無効化」、pendingDue は「timeout 到来後、選択確定前の保留。最大1つ」を守る。sleep せず timeout と commit を分け、stop > arrow > due、commit 時刻から次の3秒、遅延の追い付きなしとする（矢印の App 接続は Phase 4）

- [ ] T020 [US9] `Sources/MediaViewerCore/Browser/BrowserModel.swift` にスライドショー用の単一選択整理経路を追加する。最新 listing 内の URL だけを採用し、同じ有効対象なら selection だけ整理して loadPreview／先読み／stopPlaybackSignal を再発行しない。別対象は既存 select 経路へ渡し、消去済み選択は復帰時に補完しない

- [ ] T021 [US9] 新規 `Sources/MediaViewerApp/Slideshow/SlideshowCoordinator.swift` に MainActor の開始・単発 ContinuousClock.sleep(until:tolerance: .zero)・due 保留・commit・停止を実装する。待機 Task と commit 再予約は各最大1件。research.md R3 の順序付き RunLoop.perform と default／eventTracking／modalPanel mode、期限が過去の nextEvent(.keyDown, dequeue: false) で通常 dispatch を優先し、世代を直前照合する。キーの独自 dequeue／再送信・手動 run loop・Task.yield のみの調停は使わない。モーダル表示中も元の deadline で送り、開閉で session の停止・再作成・期限再設定をしない。modalPanel mode の commit 接続を確認し、モーダル／編集の未処理キーをスライドショー優先入力として待ち続けない。遅延時は最大1回だけ送る（U1）

- [ ] T022 [US9] `Sources/MediaViewerApp/App/MainSplitViewController.swift` と `Sources/MediaViewerApp/Slideshow/SlideshowCoordinator.swift` に SlideshowRestoreState と通常ウィンドウの開始／終了を接続する。normalPaneLayout は「開始前の通常ウィンドウの表示。全画面からなら全画面化前」、normalFocusedPane は「復帰後に表示される開始前ペインへフォーカスを戻す」、threePaneWidths は「tree / list / preview。既存 saved widths を継承し、有限・正値を検証」、presentationGeneration は「遅れて届く復帰 callback が新しい表示を上書きしないための照合」を守る。3要素の幅だけ保持し、window frame・選択・閲覧先・表示設定をコピーしない。内部 presentation は選択補完と履歴記録をせず、開始対象の確定後に preview を表示し focus を移す

- [ ] T023 [US9] `Sources/MediaViewerApp/App/MainSplitViewController.swift` で一覧の選択整理完了後に coordinator へ最新候補を渡し、候補0件で自動終了・残りありなら期限不変とする。onWillReplaceLocation では session を同期停止して復帰先 layout を確定してから返す。rename・検索バッチ・一時 loading を置換と誤判定せず、外部削除／zip 変更／ボリューム消失時の既存移動先・空 preview を保つ

- [ ] T024 [US9] `Sources/MediaViewerApp/App/MainSplitViewController.swift` の historyPresentation を active／restoring 中は復帰先 layout＋現在の形式／サイズ等として返す。`Sources/MediaViewerCore/History/HistoryNavigator.swift` の既存 recordViewChange 経路と検索中の抑止を維持し、開始／終了・一時的 layout に履歴記録を発行しない

- [ ] T025 [P] [US9] `Sources/MediaViewerApp/Shared/IconCatalog.swift` に既存の自前描画方式の開始アイコンを追加する（外部画像・新依存は追加しない）

- [ ] T026 [US9] `Sources/MediaViewerApp/App/MainToolbarController.swift` の pane group 右隣へ開始ボタンを追加し、T022 の開始経路を共通 action として公開して可否更新へ接続する。label は「スライドショーを開始」、tooltip は「スライドショーを開始（⇧⌘S）」とし、実行中は無効な開始ボタンのままにする

- [ ] T027 [US9] `Sources/MediaViewerApp/App/MainMenu.swift`・`Sources/MediaViewerApp/App/AppDelegate.swift`・`Sources/MediaViewerApp/App/MainSplitViewController.swift` に「表示 > スライドショーを開始」と ⇧⌘S、共通 start action／validation／内部 guard を接続する。全3種の名前編集と sheet／アプリモーダルを判定し、toolbar 非表示・検索／読み込み中・全画面でも候補があれば許可する。active／restoring 中のペイン・履歴操作は全入口で抑止する

- [ ] T028 [US9] `Sources/MediaViewerApp/App/MainSplitViewController.swift` の対象ウィンドウ用キー monitor と `Sources/MediaViewerApp/App/MainWindowController.swift` の cancelOperation fallback に、T008 の FR-123 共通受理条件を満たす場合だけ Esc 優先消費を接続する。stop は冪等にして pending／Task／callback を世代で破棄し、検索解除へ伝播させない。close／quit は `Sources/MediaViewerApp/App/AppDelegate.swift` も含め資源を破棄し、Settings・HistoryEntry に新状態を保存しない。条件外ではキーを既存の入力先へ渡し、スライドショーによる終了・全画面解除・検索解除・期限変更を行わない。モーダル／編集を閉じた同じ Esc を fallback で再適用しない。既存のシート／アプリモーダルの提示経路を使った接続確認で、Esc 取消と期限不変を検証し、方法・結果・未実施項目を `specs/006-add-slideshow/quickstart.md` の「入力調停検証記録」へ追記する（U1）

- [ ] T029 [US9] `Sources/MediaViewerApp/Slideshow/SlideshowCoordinator.swift` に既存 `Sources/MediaViewerApp/App/AppDelegate.swift` の OSSignposter 方式を合わせ、local.my-img-viewer.MediaViewer / Performance の SlideshowStart・SlideshowAdvance（実選択 commit）・SlideshowStop を追加する。名前・パス・メディア情報を記録せず、同じ1件維持を実選択移動と混同しない

- [ ] T030 [US9] `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗は最大3回の修正までとする。結果を `specs/006-add-slideshow/quickstart.md` の「Phase 検証記録」へ追記する

- [ ] T031 [US9] ユーザーに `cd /Users/igachan/projects/my_img_viewer` と `open .build/MediaViewer.app` の実行を依頼し、通常起動の3ペイン表示とUS9-AS1〜16 の通常ウィンドウでの対象・循環・開始不可・動画維持・更新・検索／履歴・空選択復帰・Esc 後6秒間0回を確認してもらう。結果を `specs/006-add-slideshow/quickstart.md` へ追記し、GUI 未実施ならこのタスクを未チェックに保つ。US9-AS16 は実行中のシート／アプリモーダル・編集欄への Esc を確認し、モーダル表示中の送り継続・開閉で期限不変・同じ Esc で終了しないこと、入力先が戻ってからの別の Esc で終了することを記録する（U1）

- [ ] T032 [US9] 直前の自動・GUI ゲート合格後、当該 Phase のソース・テスト・`specs/006-add-slideshow/tasks.md`・明示された quickstart 追記だけを確認して Phase 単位でコミットする（push は行わない）

**Checkpoint**: US9 の通常ウィンドウ増分が検証済み。要件全体の P1 MVP は US10 まで含む。

## Phase 4: User Story 10 — 矢印キーで見たいメディアへ割り込む（P1）

**Goal**: 端・無移動・反復を含む全ての修飾キーなし矢印入力で待機を取り直し、手動移動を自動送りより優先する。

**Independent Test**: 1秒間隔で10回入力し、操作間の自動送り0回、最終入力から3秒後に次へ1回を確認する。リスト左右・端・サムネイル・キー反復・due 直前操作も同様（US10-AS1〜6）。

### Tests for US10

- [ ] T033 [P] [US10] `Tests/MediaViewerCoreTests/SlideshowSessionTests.swift` に due→arrow→commit と arrow→due→commit、due と Esc の両順序、反復・端・リスト左右で世代無効化と now+3秒、修飾付き矢印／Space／シーク／全画面／形式変更で期限不変という試験を追加する。最後の矢印から3秒未満0回・期限で1回を任意 now で検証する。不適格な矢印を session へ通知しない列では期限・世代が不変で、due の前後でも手動移動・3秒再設定がないことを追加する。再び受理可能になった後の矢印は now+3秒とする（U1）

- [ ] T034 [P] [US10] `Tests/MediaViewerCoreTests/FocusNavigatorTests.swift` に全表示行上の非メディア読み飛ばし・端停止・空選択時先頭、隠す前の幅と現在サムネイルサイズからの列数による移動を検証する。候補だけに圧縮した列や preview 幅を使わない規則を固定する

### Implementation for US10

- [ ] T035 [US10] `Sources/MediaViewerCore/Slideshow/SlideshowSession.swift` の矢印受理を仕上げ、移動成否と無関係に古い待機／pending を無効化し waitingAfterArrow と now+3秒へ移す。現世代 commit だけを1回許可し、最新 focused の次または候補先頭から通常周期へ戻す

- [ ] T036 [US10] `Sources/MediaViewerApp/FileList/FileListViewController.swift` の HiddenListNavigation を再利用し、隠す直前の width を保持、すでに preview-only／全画面なら既存値を継承する。現在の形式・サイズと全表示行に FocusNavigator を適用して非メディアを飛ばす。開始／復帰の選択補完禁止を維持し、手動は非循環とする

- [ ] T037 [US10] `Sources/MediaViewerApp/App/MainSplitViewController.swift` の hidden-list キー処理で、対象 window・修飾キーなしの全4矢印を移動より前に coordinator へ通知する。リスト左右も消費して期限を更新し、動画シークへ渡さない。編集／モーダルの処理を横取りせず、Space・<／>・動画 controls は既存操作のまま期限不変とする。T008 と同じ入力受理条件を通知・消費の前に使い、不適格な矢印は選択・期限を変えず既存入力先へ渡す。モーダルを閉じるキーを同じ入力のまま再適用しない（U1）

- [ ] T038 [US10] `Sources/MediaViewerApp/Slideshow/SlideshowCoordinator.swift` に矢印時の Task 再設定と SlideshowArrow signpost を接続する。R3 の commit 境界で未処理キーあり／なし・取消後 callback・両到着順を確認し、再予約は最大1件を維持する。確認結果と AppKit dispatch の手動再現条件を `specs/006-add-slideshow/quickstart.md` の「入力調停検証記録」へ追記する

- [ ] T039 [US10] `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗は最大3回の修正までとする。結果を `specs/006-add-slideshow/quickstart.md` の「Phase 検証記録」へ追記する

- [ ] T040 [US10] ユーザーに `cd /Users/igachan/projects/my_img_viewer` と `open .build/MediaViewer.app` の実行を依頼し、通常起動の3ペイン表示とUS10-AS1〜6（リスト左右・端・反復・隠れた列数・due 直前の二重送りなし・最後の押下から再開）を確認してもらう。結果を `specs/006-add-slideshow/quickstart.md` へ追記し、GUI 未実施ならこのタスクを未チェックに保つ。US10-AS6 のモーダル／編集欄・別ウィンドウへの矢印が手動移動や期限再設定を起こさず、元の周期が続くこと、対象ウィンドウへ戻った次の矢印で通常の割り込みが行えることも記録する（U1）

- [ ] T041 [US10] 直前の自動・GUI ゲート合格後、当該 Phase のソース・テスト・`specs/006-add-slideshow/tasks.md`・明示された quickstart 追記だけを確認して Phase 単位でコミットする（push は行わない）

**Checkpoint**: US9＋US10 の P1 MVP が揃う。SC-035 の実時間合否は最終 Phase で記録する。

## Phase 5: User Story 11 — 全画面でも鑑賞と手動操作を続ける（P2）

**Goal**: 全画面切替で実行・期限・再生を保ち、Esc 一回で通常表示へ一度だけ復帰する。

**Independent Test**: 3種 layout と開始前から全画面の各条件で、全画面 enter／exit を3回、矢印割り込み、Esc 終了を確認する。狭めた window の寸法を維持し、幅160/240/320pt・focus・現在選択の最小スクロールを確認する（US11-AS1〜4）。

### Tests for US11

- [ ] T042 [P] [US11] `Tests/MediaViewerCoreTests/PaneLayoutTests.swift` に復帰 layout と PaneWidths.dividerPositions の通常幅・狭幅・不正 saved widths を検証する試験を追加し、preview→list→tree の圧縮順と160/240/320pt下限を固定する。空選択を復帰で補完しない App 接続は T049 で確認する

- [ ] T043 [P] [US11] `Tests/MediaViewerCoreTests/SlideshowSessionTests.swift` に、残り待ち時間を持つ session を再作成せず継続する遷移列と、復帰開始の stop 後は古い pending／timeout／commit が0回、再開始は新世代となる試験を追加する。Core へ AppKit の全画面状態を追加せず、実際の enter／exit 接続と復帰中の開始拒否は T049 で確認する

### Implementation for US11

- [ ] T044 [US11] `Sources/MediaViewerApp/App/MainSplitViewController.swift` の enterFullScreenPresentation／leaveFullScreenPresentation でスライドショーの復帰 snapshot を上書きせず、非 Esc 解除後も preview-only を維持する。すでに全画面で開始する場合は paneLayout・focusBeforeFullScreen・savedPaneWidths の通常状態を採用し、hidden-list 幅と期限・選択を変えない

- [ ] T045 [US11] `Sources/MediaViewerApp/Slideshow/SlideshowCoordinator.swift` と `Sources/MediaViewerApp/App/MainSplitViewController.swift` に idle→active→restoring→idle を接続する。終了で先に Core を無効化し、全画面解除通知後に幅・focus を最終適用する。presentationGeneration で古い callback を拒否し、復帰完了まで開始を拒否、close／quit はアニメーションを待たず破棄する

- [ ] T046 [US11] `Sources/MediaViewerApp/App/MainWindowController.swift` の全画面 delegate／Esc 経路を復帰処理に接続し、T028 と同じ受理条件を満たす Esc 一回で終了と解除を完了する。window frame は戻さず、既存 PaneWidths と minimumThickness で収め、有効な現在選択だけを最小スクロールで可視にする。消去済み選択・古い閲覧先を復活させない

- [ ] T047 [US11] `Sources/MediaViewerApp/Preview/PreviewViewController.swift` と `Sources/MediaViewerApp/App/MainSplitViewController.swift` の visibility 経路を確認・調整し、全画面切替や終了のみで同じ動画を再構成／停止せず、復帰先 file-list-only では停止・消音する。画像ダブルクリック・⌃⌘F・メニューでも同じ再生維持規則を適用する

- [ ] T048 [US11] `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗は最大3回の修正までとする。結果を `specs/006-add-slideshow/quickstart.md` の「Phase 検証記録」へ追記する

- [ ] T049 [US11] ユーザーに `cd /Users/igachan/projects/my_img_viewer` と `open .build/MediaViewer.app` の実行を依頼し、通常起動の3ペイン表示とUS11-AS1〜4、開始前から全画面の場合、3回の全画面切替、矢印、動画位置／状態と残り時間、狭幅復帰、Esc 後6秒間0回を確認してもらう。結果を `specs/006-add-slideshow/quickstart.md` へ追記し、GUI 未実施ならこのタスクを未チェックに保つ。全画面中も US9-AS16・US10-AS6 を確認し、モーダルを閉じる Esc だけでは全画面もスライドショーも終了せず、開閉で期限が変わらないことを記録する（U1）

- [ ] T050 [US11] 直前の自動・GUI ゲート合格後、当該 Phase のソース・テスト・`specs/006-add-slideshow/tasks.md`・明示された quickstart 追記だけを確認して Phase 単位でコミットする（push は行わない）

**Checkpoint**: 全 Story の機能ゲートが揃う。最終計測と仕様反映へ進める。

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 大量一覧・実時間・キーボード完結の証拠を揃え、検証後に Living spec へ移す。

- [ ] T051 [P] 新規 `Tests/MediaViewerPerformanceTests/SlideshowPerformanceTests.swift` に10,000件の通常／検索相当一覧の対象抽出・次位置探索を計測する試験を追加する。線形走査・メディア本体の複製なし・全件先読みなしを確認し、既存 `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift` の基準と併せて評価する。仮想時刻テストで実機 SC-034/035 合格を代用しない

- [ ] T052 [P] `README.md` の利用方法と手動確認へ、開始ボタン／「表示」メニュー／⇧⌘S、固定3秒・最新一覧対象、矢印で待機再設定、Esc 終了、全画面、実行中の禁止操作と非保存を追記する。間隔設定や専用一時停止など範囲外の機能を案内しない

- [ ] T053 `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` の最終ゲートを実行する。`Tests/MediaViewerPerformanceTests/SlideshowPerformanceTests.swift` と既存性能テストの結果を回収し、Core の AppKit 非依存・重処理の UI 非実行・既存キャッシュ上限も確認する。結果を `specs/006-add-slideshow/quickstart.md` へ追記する

- [ ] T054 `specs/006-add-slideshow/quickstart.md` の全手動シナリオと実時間計測をユーザーへ依頼する。`open .build/MediaViewer.app` の3ペイン起動後、通常／zip／検索で2周、toolbar 非表示のキーボード完結、表示不能1周・全件不能、再起動、3種 layout／全画面3回・狭幅復帰を確認し、Instruments で画像連続20区間と1秒／10秒動画の3.0〜3.2秒、矢印1秒間隔10回中0回／最終入力後3.0〜3.2秒に1回、Stop後6秒以上0回を測る。端・反復・全画面も測り、10,000件／大量検索の UI 応答と既存性能基準を確認する。未実施なら未チェックに保つ

- [ ] T055 `specs/006-add-slideshow/quickstart.md` に「最終検証結果」を追記し、環境（macOS・機種・build 種別）、SC-033〜037、20区間の最小／最大／範囲外件数、矢印操作中／停止後の送り件数、既存性能基準と大量一覧測定を記録する。GUI の実施者・未実施項目も明記し、全ゲート合格前に後続の product 反映へ進まない。U1 のシート／アプリモーダル・編集欄・別ウィンドウの入力、同じ Esc の再適用なし、モーダル中の送りと期限不変、通常／全画面の確認結果も含める

- [ ] T056 T001〜T055 の実装・検証完了後に限り、`specs/006-add-slideshow/spec.md` の反映先表どおり `specs/product/preview.md`・`specs/product/window-layout.md`・`specs/product/navigation-history.md`・`specs/product/overview.md`・`specs/product/contracts/keyboard-and-menus.md`・`specs/product/contracts/settings.md` へ全追加／変更 ID を移す。契約は参照で記載して ID 本文を重複定義せず、Clarifications は feature に残す。`specs/product/README.md` の領域案内を必要に応じ更新し、feature spec 冒頭へ移行済み・凍結注記を付す

- [ ] T057 `specs/006-add-slideshow/spec.md` の反映先表と `specs/product/` の ID・リンク・契約を照合し、FR-114〜126、変更 FR-036/090/094/107/112、EC-39/66〜72、US9〜11、SC-033〜037、A-14/47〜53 の反映漏れ・重複がないことを確認する。`specs/001-three-pane-media-viewer/` が未変更であることも確認する

- [ ] T058 T053 の自動ゲート・T054 の GUI／性能確認・T057 の文書照合合格後、最終 Phase のソース・テスト・`README.md`・`specs/product/`・`specs/006-add-slideshow/` の差分を確認し、本書の完了チェックとともにコミットする（push は行わない）

## Dependencies & Execution Order

### Phase Dependencies

```text
Phase 1: Setup (T001–T006)
  → Phase 2: Foundational (T007–T013)
    → Phase 3: US9 (T014–T032)
      → Phase 4: US10 (T033–T041)
        → Phase 5: US11 (T042–T050)
          → Phase 6: 最終検証・反映 (T051–T058)
```

### User Story Dependencies

- **US9 (P1)**: Foundational が前提。通常ウィンドウの基礎増分として個別検証できる。
- **US10 (P1)**: US9 の session・coordinator・hidden-list の開始／終了経路が前提。入力を追加した増分として個別検証する。
- **US11 (P2)**: US9 の復帰状態と US10 の矢印を再利用し、全画面の受け入れを追加する。
- Story 間で MainSplitViewController・SlideshowCoordinator・SlideshowSession を共有するため、Story の実装は直列とする。
- コア試験→実装→App 接続→自動ゲート→GUI→コミット。GUI 未実施なら Phase 完了として次へ進めない。

### Within Each Phase

- T001 → T002 → T003 → T004 → T005 → T006。
- Phase 2 は T007 → T008 と T009 → T010。その後 T011 → T012 → T013。
- US9 は T014〜T017 のテストを先に追加。T018 → T019 → T020 → T021 → T022 → T023 → T024 を順次接続する。T025 は独立、T026 は T025 と T022 の共通開始経路を前提とする。T027 でメニューと共通 action を仕上げ、T028 → T029 → T030 → T031 → T032。
- US10 は T033・T034 → T035 → T036 → T037 → T038 → T039 → T040 → T041。
- US11 は T042・T043 → T044 → T045 → T046 → T047 → T048 → T049 → T050。
- T051・T052 → T053 → T054 → T055 → T056 → T057 → T058。未実施の GUI／実時間計測を仮想テストで置き換えて T056 を進めない。

### Parallel Opportunities

既定の Codex 実装は順次実行する。`[P]` は明示的に並列化する場合の候補を示すだけで、内部 subagent に同じディレクトリを編集させる指示ではない。

並列実装を行う場合は、未コミット変更を先にコミットまたは stash し、現在の Phase ブランチをベースに専用 worktree と `agent/<task-id>-<slug>` ブランチを作る。担当者は自分の worktree だけを編集し、小さなコミットの SHA を報告する。インテグレータが統合して各統合後に `swift build` / `swift test` を実行し、GUI は統合後に一つずつ行う。最後に worktree と作業ブランチを削除する。同一ファイルの変更は直列化する。

## Parallel Example: US9

Phase 2 完了後、独立したテストファイルを準備できる。

```text
T014: Tests/MediaViewerCoreTests/SlideshowSequenceTests.swift
T015: Tests/MediaViewerCoreTests/SlideshowSessionTests.swift
T016: Tests/MediaViewerCoreTests/BrowserModelSlideshowTests.swift
T017: Tests/MediaViewerCoreTests/HistoryNavigatorTests.swift
```

T025 の IconCatalog.swift も Core 実装とは別ファイルで作業できる。テストで未実装型を参照する場合、統合後に意図した失敗を確認してから本実装へ進む。

## Parallel Example: US10

US9 完了後、T033 の SlideshowSessionTests.swift と T034 の FocusNavigatorTests.swift は別 worktree で準備できる。その後の T035〜T038 は入力契約と同じ App 接続に依存するため直列。

## Parallel Example: US11

US10 完了後、T042 の PaneLayoutTests.swift と T043 の SlideshowSessionTests.swift は別 worktree で準備できる。T044〜T047 は全画面と復帰の同一接続を触るため直列。

## Implementation Strategy

### MVP First

1. Setup と Foundational を完了する。
2. US9 を通常ウィンドウで実装・個別検証する（鑑賞の核）。
3. 明示された主要要件である US10 まで実装・検証して **P1 MVP** とする。
4. US11 の全画面と最終計測を加えて feature 全体を完了する。US9 だけでは仕様全体の完了としない。

### Incremental Delivery

各 Phase を自動・GUI ゲートで確認してコミットする。実時間性能を最後に測り、SC と既存性能の証拠が揃った後だけ product へ反映し、feature を凍結する。スライドショー状態や専用設定を保存しない。

## Requirement Coverage

| 対象 | 主なタスク |
|---|---|
| FR-114 / 開始契約・全入口ガード | T007–T008、T025–T027、T031、T054 |
| FR-115/116 / 対象・識別・開始位置 | T014、T018、T020、T031 |
| FR-117 / preview-only・snapshot | T022、T031、T044–T046 |
| FR-118/119 / 3秒循環・モーダル中の期限維持・同一動画維持 | T015–T016、T019–T021、T029–T031、T054 |
| FR-120/121 / 手動移動・入力受理条件・入力優先 | T033–T040、T054 |
| FR-122 / 全画面継続 | T042–T044、T047、T049、T054 |
| FR-123 / 入力受理・Esc・空選択・狭幅復帰 | T007–T008、T015–T016、T022、T028、T031、T033、T037、T040、T042–T049 |
| FR-124 / エラー・遅延・旧結果拒否 | T009–T010、T014–T016、T019–T021、T054 |
| FR-125/126 / 更新・rename・置換・破棄・非保存 | T009–T010、T016、T023、T028、T045、T054 |
| 変更 FR-036/090/094/112・EC-39 | T007–T008、T022、T027–T028、T036–T037、T044–T049 |
| 変更 FR-107・既存 FR-113 / 履歴・検索 | T017、T024、T031、T054 |
| EC-66〜72 / 1件・異常・更新・遅延・重複・再起動 | T014–T016、T019–T023、T028、T031、T054 |
| SC-033〜037 / 受け入れ・実時間・性能 | T029、T031、T038、T040、T049、T051、T053–T055 |
| A-14/47〜53・全変更の Living spec 反映 | 上記実装の範囲制約、T052、T056–T057 |

## Notes

- 本書が進捗の正本。全て未着手として生成した。
- GUI／Instruments 未実施は該当タスクを未チェックに保ち、完了と報告しない。
- テスト失敗の修正が3回で解決しない場合は止めて状況を報告する。
- 起動不良では推測で直さず、AGENTS.md の lldb 例外停止コマンドをユーザーに依頼する。
