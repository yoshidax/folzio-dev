# Tasks: 検索起点フォルダの GUI 選択

**Input**: `specs/010-search-folder-picker/` の plan.md、spec.md、research.md、data-model.md、contracts/search-folder-picker.md、quickstart.md。
**Prerequisites**: 上記の設計文書、`.specify/memory/constitution.md` v1.2.0、`AGENTS.md`。既存仕様は plan.md の product 参照領域と、統合済み・product 未反映の `specs/009-folder-search/spec.md` を併読する。
**Tests**: plan.md・quickstart.md と憲章 IV が求める Core ロジック・異常系・競合の自動テストを含む。Swift Testing と FixtureKit を使い、外部依存・新 target は追加しない。
**Organization**: 本 feature のストーリーは **US16（P1）1件**。既存のストーリー番号を維持し、US1 へ振り直さない。

## Format: `[ID] [MANUAL?] [P?] [Story?] Description`

- 全タスクは `- [ ] Tnnn ...`。ユーザーの操作・報告が必要なら **ID の直後**に `[MANUAL]` を置く。ストーリー Phase のみ `[US16]` を付ける。
- `[MANUAL]` は GUI 起動、目視、実機操作、VoiceOver、Instruments、およびユーザーによる設計レビュー。実装・自動テスト・文書作成・コミットを同じタスクへ混ぜない。報告の受領は手動タスク、文書への転記は別の文書タスクとする。
- **分類は実装前の設計レビュー T002 で確認する。実装中は `[MANUAL]` を追加・削除・移動しない。** 実装中に分類の不備が見つかったら該当作業を完了扱いにせず、設計レビューへ戻して扱う。自動化できたという理由で手動確認を代替しない。
- ユーザーの報告がない `[MANUAL]` は未チェックにする。非対話実行でも省略・推測による合格にしない。非手動タスクの完了で手動タスクをチェックしない。
- `[P]` は依存が満たされた後、別ファイルで作業できる候補。既定は順次実装。並列化を明示する場合だけ `AGENTS.md` に従い独立 worktree と `agent/<task-id>-<slug>` を使う。同じファイルを触るタスクと GUI スモークは直列。

## Path Conventions

- 判断・列挙・検証: `Sources/MediaViewerCore/Search/`（AppKit を import しない）。
- 描画・入力・シート: `Sources/MediaViewerApp/Search/`（MainActor）。
- 一時データ: `Sources/FixtureKit/FixtureSets.swift`。自動テストは一時ディレクトリに生成し、権限を戻して削除する。
- 自動検証: `Tests/MediaViewerCoreTests/`、`Tests/MediaViewerPerformanceTests/`。
- 実装中の仕様文書の変更は tasks.md のチェックと、本タスクで明示する quickstart.md への追記だけ。product 反映と feature 凍結は検証完了後の T045・T046 で行う。

## Phase 1: Setup — 設計レビューと基準確認

**Purpose**: 手動分類を実装前に確定し、既存アプリの基準状態と記録先を整える。新たな Package・target・依存は作らない。

- [ ] T001 `specs/010-search-folder-picker/quickstart.md` の末尾に「実装・検証記録」欄を追記する。Phase 別自動コマンドの結果、ユーザー報告の受領日・OS・端末・対象ビルド、シナリオ別の回数・起点・結果、権限や外部ボリュームを含む未実施理由、性能値の記録枠を用意し、未実施を成功で埋めない。
- [ ] T002 [MANUAL] `specs/010-search-folder-picker/tasks.md` 全件の設計レビューをユーザーに依頼し、GUI・目視・VoiceOver・性能計測等の独立性、ID 直後の `[MANUAL]`、文書作成との分離、依存順と実装中の分類固定について確認報告を受ける。実装タスク T007 以降はこの確認後に開始する。
- [ ] T003 リポジトリルートで `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、既存基準の成否と失敗内容を収集する（対象: `Package.swift`、`.build/MediaViewer.app`）。GUI は起動しない。
- [ ] T004 [MANUAL] T003 成功後、ユーザーへ `cd /Users/igachan/projects/my_img_viewer` の後に `open .build/MediaViewer.app` を実行するよう依頼する。ツリー・ファイルリスト・プレビューの3ペイン、⌘F の既存検索シート、取消で元の画面へ戻ることについて報告を受ける（手順: `specs/010-search-folder-picker/quickstart.md`）。
- [ ] T005 T002・T003・T004 の確認済み結果と未実施事項を `specs/010-search-folder-picker/quickstart.md` の記録欄へ追記する。設計レビューを受けていない分類や GUI 未報告を合格として記録しない。
- [ ] T006 T001〜T005 完了後、今回の設計・タスク文書を差分確認し、`specs/010-search-folder-picker/` の対象ファイルだけを Phase 1 のコミットにする。既存の未追跡設計文書も内容を確認し、無関係なファイルを含めず、push は行わない。

**Checkpoint**: 手動分類を確認済み、既存アプリの自動・起動ゲートを通過。文書を作成しただけでは確認済みにしない。

## Phase 2: Foundational — 再現可能な共通フィクスチャ

**Purpose**: US16 の通常・異常・性能ケースに共通する入力を用意する。T006 完了後に開始し、この Phase が US16 の前提となる。

- [ ] T007 `Tests/MediaViewerCoreTests/SearchFolderPickerFixtureTests.swift` を新設し、`FixtureSets.searchFolderPicker(in:)` が quickstart の構成を生成する契約を Swift Testing で検証する。`Photos` と `Photos ` の区別、異なる子フォルダ・画像、dot/isHidden、パッケージ内部、3種類のリンク、file/zip、空・削除用・権限用フォルダ、直下10,000フォルダと各JPEGを確認する。生成先は一時領域とし後始末を保証する。
- [ ] T008 `Sources/FixtureKit/FixtureSets.swift` に `searchFolderPicker(in:)` を追加し makeAll から呼ぶ。`specs/010-search-folder-picker/quickstart.md` の検証データ表を実装し、既存JPEG・zip生成を再利用する。locked は読取可能な状態で生成し、many-folders は直下10,000フォルダ・各小さなJPEGとする。新たな WebP ツールは導入しない。
- [ ] T009 T007・T008 後、`swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行する（対象: `Tests/MediaViewerCoreTests/SearchFolderPickerFixtureTests.swift`、`.build/MediaViewer.app`）。失敗を3回修正しても解消しなければ止めて報告する。
- [ ] T010 [MANUAL] T009 成功後、ユーザーへ `cd /Users/igachan/projects/my_img_viewer` の後に `open .build/MediaViewer.app` を依頼し、3ペインと既存検索シートに起動上の退行がない報告を受ける（手順: `specs/010-search-folder-picker/quickstart.md`）。
- [ ] T011 T009・T010 の結果を `specs/010-search-folder-picker/quickstart.md` の Phase 2 記録欄へ追記し、GUI の未確認と自動検証の成功を別々に記載する。
- [ ] T012 T007〜T011 完了後、`Sources/FixtureKit/FixtureSets.swift`、`Tests/MediaViewerCoreTests/SearchFolderPickerFixtureTests.swift`、本 feature の進捗・記録を Phase 2 のコミットにする。

**Checkpoint**: 以後の Core テストで共通入力を使える。GUI 用データのユーザー領域への生成は手動確認の準備として T028 で行う。

## Phase 3: User Story 16 — フォルダを画面で選んで検索起点を設定する（Priority: P1）🎯 MVP

**Goal**: 起点の直接入力を維持し、子シートから単一フォルダを選べる。確定では起点と古い起点エラーだけを更新、取消では親を保持し、有効な検索操作で初めて検索する。既存検索と外部変更の更新を止めない。

**Independent Test**: 別フォルダを選んで確定し、親を保ったまま起点全体だけが更新され、検索ボタンでその起点の結果になる。取消10回、キーボード経路5回、5種類の場所と末尾空白、初期位置・異常系・既存検索の継続を quickstart シナリオ1〜9で独立に確認する。

### Tests for User Story 16

T013〜T016 は設計契約に基づいて先に追加し、対応実装がないための失敗を確認する。未実装によるコンパイル失敗と、実装後のアサーション失敗を区別する。I/O の完了順・メタデータ・候補結果を小さな注入境界で制御し、sleep や実ユーザーのホーム属性に依存させない。

- [ ] T013 [P] [US16] `Tests/MediaViewerCoreTests/SearchRootInputTests.swift` に typed/picked と親入力世代のテストを追加する。typed の trim・`~`・末尾 `/`、picked の末尾空白・表示URLとリンク解決URLの区別、同じ文字列へ戻した編集による typed 化、キーワード編集・子取消での入力元維持、初期化・終了、起点/キーワード編集・親終了後の古い検証不採用を検証する（AS3・AS10、EC-106）。さらに親の依頼世代・処理種別を検証し、初期位置解決中に検索を受理した後、解決→検索検証/検索検証→解決の両完了順と検索成功/失敗・初期位置解決成功/失敗の組合せで旧提示・旧理由反映の採用0回、有効な検索成功の採用1回（失敗は0回）を固定する。検索失敗後の再試行へ旧完了を混ぜた場合、childPresentedを入力した子の先行提示時の親検索拒否、検証中の重複検索拒否、空キーワードの無操作も検証する（U1、FR-143）。
- [ ] T014 [P] [US16] `Tests/MediaViewerCoreTests/SearchFolderAccessTests.swift` に入口・初期候補・一覧・確定検証の契約テストを追加する。現在入力→開始時既定→ホームの順序と全滅、EC-102で一覧F・ツリーVが異なる場合に捕捉済みFを使い、FがGUI対象外ならホームへ進みVを候補に加えず親入力を保持すること、ルートを追加フォールバックにしないこと、dot/isHidden/isPackage と祖先・リンク両経路、ホームの隠し祖先拒否、非隠しボリュームの独立入口と隠し入口拒否、不明メタデータ拒否、名前順の直下フォルダのみを検証する。実I/Oと注入を使い分け、削除・ファイル化・zip・権限拒否・リンク先変更・列挙失敗、同一一覧内の祖先検査共有と次操作での再検査も固定する（AS4・AS5・AS8・AS11・AS12）。
- [ ] T015 [P] [US16] `Tests/MediaViewerCoreTests/SearchFolderPickerStateTests.swift` に単一選択・未選択時の現在位置・移動時解除、空フォルダ・`/` の確定、二重確定、確定失敗からの再試行、列挙失敗からの移動・取消を追加する。完了順を制御し、取消後成功、移動後の旧一覧/旧確定、同じURLへの再移動、検証中の行変更と移動による失効、validating に残らないこと、成功の一度だけの返却を検証する。
- [ ] T016 [P] [US16] `Tests/MediaViewerCoreTests/SearchRootTests.swift` と `Tests/MediaViewerCoreTests/BrowserModelSearchTests.swift` で不足する既存回帰を追加する。直接入力の解釈・既存エラー・隠し祖先を新たに拒否しないこと・パッケージ自身の拒否、リンク解決後URL、選択後の消失/権限変更を再検証で拒否すること、有効な検索開始でだけ検索AをBへ置換し旧バッチを捨てることを固定する。既存の009のフォルダ検索・結果処理の期待値を保持する。EC-102でツリーがVでも一覧のfolderはFのまま、検索結果表示中は検索前・zip内はzipを含むフォルダを既定に渡せることを回帰確認する（I1、FR-081）。

### Core implementation for User Story 16

- [ ] T017 [US16] `Sources/MediaViewerCore/Search/SearchRootInput.swift` に SearchRootInput と SearchPanelInputState を実装する。データモデルの制約「初期状態は typed。picked は選択画面の検証成功からのみ作る。」「起点欄のユーザー編集は常に typed にする。同じ文字列へ戻しても picked には戻さない。」「キーワード編集、子の取消・失敗・再表示は状態を変えない。」を守る。typed は「`SearchRoot.parse(text, home:)` の既存規則」、picked は「フォルダ選択で確定した絶対 file URL」「`url.path`、引用符・エスケープなし」「選択 URL をそのまま返す。trim しない」。共通の表示/解釈と rootInput・keyword・revision・isActive を設け、編集・選択成功で revision、終了で失効し、捕捉した入力の採否を純粋に判断する。pendingOperation は「idle / resolvingPicker / validatingSearch」、requestGeneration は「処理開始・失効で進める依頼世代」とし、完了は「捕捉した revision・requestGeneration・処理種別と isActive がすべて一致した場合だけ採用する」。childPresentedを入力として親アクションの受理も純粋に判断する。検索受理時は旧提示を失効させてから検索検証へ遷移し、失敗後も復活させず新依頼を発行する（T013・T016、U1）。
- [ ] T018 [US16] `Sources/MediaViewerCore/Search/SearchFolderAccess.swift` に入口取得・初期位置・直下一覧・確定検証と表示用理由型を実装する。T017の入力型を使い、`DirectoryLister.subfolders`、`SearchRoot.validate`、`VolumeProvider` を再利用し、全I/Oを UI スレッド外へ置く。制約「対象は存在する読取り可能なフォルダである。通常ファイル・zip・パッケージは確定対象外。」「対象と GUI の入口までの経路に隠し項目・パッケージを含まない。名前の `.` だけでなく `isHidden` と `isPackage` を用いる。」「到達可能性を確定できない経路は拒否する。」を満たす。表示経路とリンク解決先の両方、ホームの祖先、ボリューム独立入口を検査し、候補順と全滅理由を保証する。同一一覧だけ祖先検査を共有し「確定・別の移動では新しく検査する。永続的な可否キャッシュは作らない。」を守る。成功では選択URLを保持し、一般の一覧・直接入力の検証へGUI制限を追加しない（T014・T016・T017）。
- [ ] T019 [US16] `Sources/MediaViewerCore/Search/SearchFolderPickerState.swift` に純粋な状態と遷移を実装する。T018で定義した入口・理由型を利用し、locations は「利用可能な入口の値（URL・表示名・種類）。永続化しない」、currentDirectory は「現在表示している場所。入力欄とは独立」、children は「直下の表示可能なフォルダだけ。名前順、単一選択」、selectedDirectory は「行で選択中の URL、未選択なら nil」、phase は「loading / ready / validating / failed / closed」、generation は「非同期処理の世代。対象 URL と組にして結果を照合」、reason は「子で表示する理由、なければ nil」とする。確定対象は `selectedDirectory ?? currentDirectory`。data-model.md の遷移表どおり移動・行変更・終了で失効し、行変更は ready、移動は loading、失敗は再試行可能にする。Task.cancel のみに依存せず世代・対象・寿命を照合する（T015・T018）。

### App integration for User Story 16

- [ ] T020 [US16] `Sources/MediaViewerApp/Search/SearchFolderPickerController.swift` に MainActor の専用子シートを新設する。タイトル「検索起点フォルダを選択」、読取専用絶対パス、ホーム/ルート/ボリュームの場所、親ボタン、単一選択NSTableView、理由欄、取消/選択を配置する。ビュー追加後に同階層の制約を有効化し、標準色で表示する。ファイル・zip・パッケージ・隠し表示、新規作成、複数選択、パス入力・ドロップ、最近の場所を提供しない（T018・T019、FR-141）。
- [ ] T021 [US16] `Sources/MediaViewerApp/Search/SearchFolderPickerController.swift` を Core の非同期一覧・移動・確定へ接続する。処理開始時の対象と世代を捕捉し、完了採用は状態値で判断する。行選択は移動せず、ダブルクリックは内部へ移動する。取消はI/O完了を待たず、検証中も行変更・移動・取消を可能にする。確定失敗は子だけへ理由、成功は選択URLを一度だけ返す。BrowserModel・検索・保存を呼ばない（T020、AS8・AS12・AS13）。
- [ ] T022 [US16] `Sources/MediaViewerApp/Search/SearchFolderPickerController.swift` に UI 契約どおり矢印・⌘↓・⌘↑・Return・Esc・Space と、場所→親→一覧→取消→選択の Tab/逆順を実装する。初期フォーカスは一覧、無効な操作を飛ばし空一覧でも到達可能にする。Return/Esc、⌘⇧.、⌘⇧G を親へ伝播しない。画面・現在位置・行の元の名前・処理中・全操作のアクセシビリティ名とエラーの announcementRequested を設定する（T021、FR-144）。
- [ ] T023 [US16] `Sources/MediaViewerApp/Search/SearchPanelController.swift` の入力を SearchPanelInputState と同期する。initialRootPath は「開いた時点で一覧に表示中のフォルダの既定パス。変更しない。検索結果中は検索前、zip 内は zip を含むフォルダ。EC-102 では一覧の F」とし、`Sources/MediaViewerApp/App/MainSplitViewController.swift` の showSearch がその値を渡す境界を確認する。inputState は「Core の親入力状態。欄と同時に更新」とし、編集通知で入力元と世代を更新する。検索と初期位置が同じ resolvedInput を使い、検索では常に SearchRoot.validate を実行する。検索操作の受理時（空キーワードの無操作を除く）は初期位置の提示依頼を先に失効させ、その後で検索条件を検証する。検索検証中は選択ボタンと重複検索を防御し、入力変更・親終了後の古い成功で dismiss/onSearch を呼ばない。失敗は親に理由を示して選択を再試行可能にし、旧提示は復活させない。既存 SearchPattern の空欄規則と有効時だけの onSearch 境界を保つ（T017・T016）。
- [ ] T024 [US16] `Sources/MediaViewerApp/Search/SearchPanelController.swift` に「フォルダを選択…」と子の所有・提示を追加する。pickerRequestGeneration は「Core が発行した初期位置解決の依頼世代を捕捉する。重複・取消後・検索受理後の提示を防ぐ」、childPresented は「子が開いている間の親アクションを防御」とする。現在入力→捕捉済み既定→ホームを非同期解決し、全滅なら親へ理由だけを示す。親自身から presentAsSheet し runModal を使わず、初期解決中の起点/キーワード編集・終了・検索受理で依頼を失効する。完了時に入力世代・依頼世代・処理種別・親の寿命と子の未提示を照合し、検索検証との完了順によらず旧解決の成功・失敗を提示・エラーに反映しない。MainActor上で先に子を提示済みなら親の検索を拒否する。成功時のみ picked・欄全体を更新して古い起点エラーを消し、取消/失敗では入力とエラーを保持する。選択操作で検索・ツリー・一覧・履歴・設定を変更しない（T022・T023、FR-142・143）。
- [ ] T025 [US16] `Sources/MediaViewerApp/Search/SearchPanelController.swift` にキーワード→起点→選択→取消→検索の Tab/逆順と Space を追加し、OSのキーボードナビゲーション設定によらずボタンへ止める。initialFocusApplied は「初回だけキーワードへフォーカスし全選択する」とし、子の確定/取消後は選択ボタンへ戻す。子表示中の親検索/取消を防御し、親ボタン・全滅理由の表示/読み上げを設定する。親終了時に入力状態を破棄し、開き直しは既存既定値とする（T024、AS6、EC-105）。
- [ ] T026 [US16] `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift` で既存10,000件検索3秒以内の基準を維持し、直下10,000フォルダの選択用一覧の計測を追加する。生成時間を計測外とし件数・順序・結果を検証する。小さな計測用注入で共通祖先検査が行ごとの再走査にならないことも `Tests/MediaViewerCoreTests/SearchFolderAccessTests.swift` に追加する。GUIの応答100ms未満はこの自動計測で合格にせず T038 で扱う（T018・T021、quickstart シナリオ9）。
- [ ] T027 [US16] T013〜T026 後、`Sources/MediaViewerCore/Search/` の AppKit 非依存、App のI/O委譲、子の BrowserModel 非参照、`Sources/MediaViewerApp/App/MainSplitViewController.swift` の有効 onSearch 境界と既存保存契約を差分レビューする。その後 `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行して結果を収集する。3回修正してもテストが通らなければ止めて報告する。

### Manual acceptance for User Story 16

以下はすべて T027 の成功ビルドを使い、ユーザーが操作して報告する。実装・修正・文書転記は含まない。不具合の修正でビルドが変わった場合は自動ゲートと影響する手動確認を再実施し、対象ビルドを揃える。ユーザー領域へのフィクスチャ生成はユーザーのコマンドで行い、破壊的な再現は専用データだけを使う。

- [ ] T028 [MANUAL] [US16] ユーザーへ `cd /Users/igachan/projects/my_img_viewer` の後に `open .build/MediaViewer.app` を依頼し、3ペイン表示と⌘Fから親・子シートが開く起動スモークの報告を受ける。続いて `scripts/make-fixtures.sh ~/MediaViewerFixtures` で `specs/010-search-folder-picker/quickstart.md` の専用データを生成してもらう。WebPツールが不足する場合は導入前に確認し、生成未完了を後続確認の成功と扱わない。
- [ ] T029 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ1をユーザーに実施してもらい、通常・日本語・空白名・`/`・外部ボリュームの5/5件で有効な検索開始が成立し、検索バーの起点と既知の一致結果で選択場所と検索起点が一致、確定だけの検索開始0件、空フォルダ/ルート自身の選択、ファイル/zip/複数選択/作成の不可を報告してもらう（AS1・AS8、SC-058）。全走査の完了は要求せず照合後の解除を許すが、照合前終了と外部ボリューム未実施は未確認として保留し、成功に数えない（A1）。
- [ ] T030 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ2をユーザーに実施してもらい、取消ボタン5回とEsc5回について親終了・入力変更・選択操作によるツリー/一覧/プレビュー変更が各0回、元のエラー保持、フォーカス復帰、次の有効確定で古いエラーだけ消えることの報告を受ける（AS2・AS9、SC-059）。
- [ ] T031 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ3をユーザーに実施してもらい、直接入力の空白/`~`/末尾`/`、空/相対/不存在/ファイル/zip/読取不能からのフォールバック、開始時既定の消失後のホーム、取消時の元文字列保持、選択後の直接編集と直接入力だけの検索について報告を受ける。EC-102で一覧F・ツリーVから⌘Fと「ファイル」メニューの「検索…」をそれぞれ開くと既定はFで、親の取消によって一覧・ツリー・プレビューが変わらないことを確認する（変更後のUS1-AS25）。子の初期位置は対象外のFを飛ばしてホーム、Vは候補外、子の取消後もFを保持することも確認する。起点を無効値へ編集した場合の捕捉済み既定Fからのフォールバックも確認する。全候補不可は T014 の注入検証結果と区別する（AS3〜AS5、EC-103、I1）。
- [ ] T032 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ4をユーザーに実施してもらい、未編集の `Photos ` で space-hit が一致し plain-hit を別起点として使わないこと、再表示・取消・キーワード編集後の保持、起点欄を編集して同じ文字列へ戻すと typed の trim へ戻ることの報告を受ける（AS10、EC-106、SC-058）。
- [ ] T033 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ5をユーザーに実施してもらい、dot/isHidden/パッケージと内部からの初期位置フォールバック、一覧での非表示、禁止先リンクの拒否、⌘⇧./⌘⇧Gで迂回できないこと、直接入力の既存規則保持について報告を受ける（AS11、FR-141・143）。
- [ ] T034 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ6をユーザーに実施してもらい、専用 vanishing/locked の移動・権限喪失を子の確定時と親の検索時で各拒否し、理由・入力保持・復帰を確認した報告を受ける。`chmod 000 ~/MediaViewerFixtures/search-folder-picker/locked` の確認直後は必ず `chmod 755 ~/MediaViewerFixtures/search-folder-picker/locked` へ戻してもらう。取り外したボリューム、列挙/確定中のEscと遅い完了の無作用も確認する（AS7・AS12、EC-104）。
- [ ] T035 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ7のキーボード操作をユーザーに5回実施してもらい、⌘F→Tab/逆順→Space→矢印/⌘↓/⌘↑→Return→親の検索が5/5回成功した報告を受ける。OSキーボードナビゲーションのオン/オフ、空一覧、子Return/Escの分離、親へ戻るフォーカス、復帰後の親Escで既存検索を停止しないことも確認する（AS6、EC-105、SC-060）。
- [ ] T036 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ7のVoiceOver確認をユーザーに実施してもらい、親ボタン・子の画面名・現在位置・元のフォルダ名・全操作・処理中・親/子のエラー読み上げ、確定/取消後のフォーカス復帰について報告を受ける。標準表示とダークモードで文字・理由・ボタンも識別できることを確認する（FR-144、憲章 III）。
- [ ] T037 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ8をユーザーに実施してもらい、検索A中の子表示・確定・取消でも途中件数/結果/外部更新が続き、無効なBでAを止めず有効なBだけで置換する報告を受ける。`defaults read local.my-img-viewer.MediaViewer` による最後のフォルダの不変、親を開き直した既定起点、再起動時に選択起点・入力元・結果を保存しないことも確認する（AS13、FR-003・085・086・142）。
- [ ] T038 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ9をユーザーに実施してもらい、直下10,000フォルダの列挙/検証中も取消・別入口移動に応答し、既存検索の同時更新が続くことを報告してもらう。Instruments Hangs等で端末・OS・件数・最大停止時間と主スレッド上の列挙/祖先検査/権限確認の有無を測定し、100ms以上のUI停止がないか確認する。検索が速すぎて同時更新を観測できなければ専用データを増やして再試行し、未観測を合格にしない。
- [ ] T039 [US16] T027 の自動結果と T028〜T038 の受領済み報告を `specs/010-search-folder-picker/quickstart.md` の記録欄へ追記する。SC-058の5/5（開始成立・起点・既知の一致結果・走査完了/照合後解除/未確認を各記録）と末尾空白、SC-059の10回/変更0回、SC-060の5/5と指定7ケースを対応付け、性能の環境・値・未実施理由を記載する。T014の注入結果と実操作を区別し、実施の代行や未報告の補完はしない。
- [ ] T040 [US16] T013〜T039 の全ゲートと受け入れ基準が満たされた後、`Sources/MediaViewerCore/Search/`、`Sources/MediaViewerApp/Search/`、対象の `Tests/` と本 feature の進捗・記録を差分確認して Phase 3 のコミットにする。GUI未確認のまま US16 完了・MVP達成としない。

**Checkpoint**: US16 が独立に動作し、SC-058〜060 と既存検索の継続・性能を確認済み。MVP はこの Phase まで（Setup・Foundationalを含む）。

## Phase 4: Polish & Cross-Cutting Concerns — 引渡しと仕様反映

**Purpose**: T040 後、利用手順を整え、最終検証の後だけ product へ差分を反映して feature を凍結する。

- [ ] T041 `README.md` の検索手順に、直接入力と「フォルダを選択…」、確定と検索の違い、取消、キー操作、末尾空白の扱いを追記する。`specs/010-search-folder-picker/quickstart.md` への検証案内を追加し、未提供の履歴・新規作成・表示切替を案内しない。
- [ ] T042 最終状態に対して `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行する（対象: `Package.swift`、`.build/MediaViewer.app`）。T026の性能結果と、未解決の失敗・未実施手動項目が残っていないか確認する。
- [ ] T043 [MANUAL] T042 成功後、ユーザーへ `cd /Users/igachan/projects/my_img_viewer` の後に `open .build/MediaViewer.app` を依頼する。最終ビルドの3ペイン、検索シート→子で別フォルダ確定→検索、および子取消での親入力保持について報告を受ける（手順: `specs/010-search-folder-picker/quickstart.md`）。
- [ ] T044 T042・T043 の結果と最終ビルド、全受け入れ基準の証拠、性能値、制限・残件の有無を `specs/010-search-folder-picker/quickstart.md` の記録欄へ追記する。T028〜T038を含め未確認が残る場合は未完了を明示し、T045へ進まない。
- [ ] T045 実装・自動検証・手動検証がすべて完了した後、`specs/010-search-folder-picker/spec.md` の「反映先」表に従い `specs/product/search.md` と `specs/product/contracts/keyboard-and-menus.md` に FR-081・US1-AS25の変更、FR-141〜144、US16-AS1〜13、EC-103〜106、SC-058〜060、A-83〜86を反映する。FR-081とUS1-AS25の既定値は一覧基準・EC-102のFへ統一し、キー契約の既定値を維持してsearch.mdの要件・受け入れシナリオのツリー基準を改める。US1-AS25の検索モーダル構成も変更後のFR-081に合わせる。FR-143の検索受理による提示失効、SC-058の開始成立・起点一致（全走査不要）も移す。決定本文だけを移し、009の検索対象・結果・保存の差分を巻き戻さず、IDを再利用せず、`specs/product/contracts/settings.md` の保存キーを追加しない。
- [ ] T046 T045 の反映先・ID・本文整合性を確認し、`specs/010-search-folder-picker/spec.md` 冒頭に product へ移行済み・凍結の注記を付ける。設計内容を実装へ合わせて書き換えず、最終の進捗は `specs/010-search-folder-picker/tasks.md` で確定する。
- [ ] T047 T041〜T046 完了後、`README.md`、`specs/product/search.md`、`specs/product/contracts/keyboard-and-menus.md`、本 feature の記録と凍結注記を差分確認して Phase 4 のコミットにする。仕様反映後の文書リンク・ID整合性を確認し、pushは行わない。

**Checkpoint**: 最終起動を含めた検証が揃い、productが更新され、本 feature は実装の記録として凍結される。

## Dependencies & Execution Order

### Phase Dependencies

```text
Phase 1: T001 → T002 [MANUAL] → T003 → T004 [MANUAL] → T005 → T006
  ↓
Phase 2: T007 → T008 → T009 → T010 [MANUAL] → T011 → T012
  ↓
Phase 3: US16 (P1 / MVP)
  T013 + T016 → T017 ─┬→ T018 ← T014
                     └→ T023 ───────────────────┐
  T015 + T018 → T019 → T020 → T021 → T022 ───────┴→ T024 → T025
  T018 + T021 → T026
  T013〜T026 → T027 → T028 [MANUAL] → T029〜T038 [MANUAL]
                                      → T039 → T040
  ↓
Phase 4: T041 → T042 → T043 [MANUAL] → T044 → T045 → T046 → T047
```

- 全ストーリーは Phase 2 の完了に依存する。本 feature は US16 のみで、他の新規ストーリーへの依存はない。009は統合済みの基準として扱う。
- T013〜T016 は T012 後、別ファイルの契約テストとして並列化できる。T017はT013・T016、T018はT014・T016・T017、T019はT015・T018を前提とする。
- Core は入力型→アクセスの入口・理由型→選択状態の順で実装する。App の T020〜T022 と T023〜T025 はそれぞれ同じファイルなので直列。T023はCore入力と既存回帰に依存し、T024は子の準備とT023の両方を待つ。
- T026はT018・T021とT014の完了後。T014と同じテストファイルを編集するため同時実行しない。
- T029〜T038 はT028と必要なフィクスチャが前提。同じアプリ・専用データ・OS設定を扱うのでユーザーが1件ずつ順に行い、権限・移動・設定を各確認後に戻す。
- 手動報告待ちに独立した非手動作業を進めることはできるが、未確認 Phase の合格・Phaseコミット・product反映を先取りしない。各PhaseコミットはそのPhaseの全ゲート後。
- 起動失敗では推測修正を避け、`AGENTS.md` 記載のlldbコマンドによるObjective-C例外停止をユーザーへ依頼する。GUI起動の扱いと `[MANUAL]` 分類を変更しない。

## Parallel Example: User Story 16

並列化は可能性の提示であり実行指示ではない。既定は順次実装する。明示的に並列化する場合はクリーンなPhaseブランチから独立worktreeを用意し、各担当は自分のworktree内だけ編集してコミットSHAを返す。

```text
# T012 後、別ファイルのテスト（依存する型は設計契約どおりに参照）
T013: Tests/MediaViewerCoreTests/SearchRootInputTests.swift
T014: Tests/MediaViewerCoreTests/SearchFolderAccessTests.swift
T015: Tests/MediaViewerCoreTests/SearchFolderPickerStateTests.swift
T016: Tests/MediaViewerCoreTests/SearchRootTests.swift + BrowserModelSearchTests.swift

# Core実装は型の依存順に直列
T017: Sources/MediaViewerCore/Search/SearchRootInput.swift
T018: Sources/MediaViewerCore/Search/SearchFolderAccess.swift
T019: Sources/MediaViewerCore/Search/SearchFolderPickerState.swift
```

統合担当がPhaseブランチへ `git merge --no-ff` または cherry-pick し、各統合後に `swift build` / `swift test`。GUIスモークは統合後の1つのアプリでのみ行い、不要になったworktree・作業ブランチを削除する。同じ作業ディレクトリでの内部subagent並列編集は行わない。

## Implementation Strategy

### MVP First（US16）

1. Phase 1で分類の設計レビューと既存アプリの基準を確認する。
2. Phase 2で再現用データを用意し、Coreの契約テストから実装する。
3. 入力元・到達可否・世代をCoreで完結させ、専用子シートと親への接続を順に実装する。
4. 自動ゲートを通過後、ユーザーの起動・全手動シナリオの報告を受け、US16をMVPとして検証する。
5. 最終ゲート後に利用手順とproduct反映・凍結を完了する。

### Incremental Delivery

- 内部増分は「入力元と世代」→「可視フォルダの読取り」→「子の確定/取消」→「親との接続」→「キーと読み上げ」。US16の部分実装をストーリー完了として扱わない。
- 列挙・デコード・ファイル操作はUIスレッドに置かず、通信API・設定キー・起点履歴・外部依存を追加しない。
- 自動テスト成功、手動確認済み、記録済みを別々のチェックで表す。GUI報告待ちでも分類を変えず、未実施理由を残す。
- 実装中に spec.md・plan.md・research.md・data-model.md・契約を書き換えない。仕様変更が必要なら実装判断で吸収せず設計工程へ戻す。

## Coverage & Completion

| 要求 | 自動/実装 | 手動確認 |
|---|---|---|
| FR-081、US1-AS25、AS3・AS10、EC-106：直接入力・入力元・末尾空白、EC-102の一覧基準の既定値（I1） | T013・T016・T017・T023 | T029・T031・T032 |
| FR-141、AS8・AS11・AS12：単一選択・非表示・確定再検証 | T014・T015・T018〜T022 | T029・T033・T034 |
| FR-142、AS1・AS2・AS9・AS13：成功/取消の境界・検索継続 | T013・T015〜T017・T021・T023・T024 | T029・T030・T037 |
| FR-143、AS4・AS5、EC-103：初期候補・全滅、検索との提示競合（U1） | T013・T014・T017・T018・T023・T024 | T031・T033（全滅・完了順は注入検証） |
| FR-144、AS6、EC-105：キー・フォーカス・読み上げ | T020・T022・T025 | T035・T036 |
| AS7、EC-104：選択後の削除・権限喪失 | T014・T016・T018・T023 | T034 |
| SC-058：5種類の開始成立・起点一致（全走査不要、A1）と末尾空白・確定だけの開始0件 | T013・T014・T017・T018・T024 | T029・T032 |
| SC-059：取消10回・親と表示への変更0回 | T015・T021・T024 | T030 |
| SC-060：キーボード5回と指定7ケース | T013〜T025 | T030・T031・T033〜T037 |
| 性能・外部更新・保存契約 | T016・T018・T026・T027 | T037・T038 |

全47タスク（US16:28、ストーリー外:19）。`[MANUAL]` は15件、`[P]` は4件。各チェックはその作業の証拠が得られてから付け、手動確認の未実施を残したまま全体完了にしない。
