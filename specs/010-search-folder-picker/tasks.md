# Tasks: 検索起点フォルダの GUI 選択

**Input**: `specs/010-search-folder-picker/` の plan.md、spec.md、research.md、data-model.md、contracts/search-folder-picker.md、quickstart.md。
**Prerequisites**: 上記の設計文書、`.specify/memory/constitution.md` v1.2.0、`AGENTS.md`。既存仕様は plan.md の product 参照領域と、統合済み・product 未反映の `specs/009-folder-search/spec.md` を併読する。
**Tests**: plan.md・quickstart.md と憲章 IV が求める Core ロジック・異常系・競合の自動テストを含む。Swift Testing と FixtureKit を使い、外部依存・新 target は追加しない。
**Organization**: 本 feature のストーリーは **US16（P1）1件**。既存のストーリー番号を維持し、US1 へ振り直さない。
**Design update**: 独自のフォルダ選択シートではなく、macOS 標準の `NSOpenPanel` を検索シートの子シートとして使う。隠し項目は標準動作（既定は非表示、⌘⇧. で切替可能）に従い、パッケージは選択・内部移動できない。旧設計の独自ピッカー用タスクは本改訂で置き換えた。

## Format: `[ID] [MANUAL?] [P?] [Story?] Description`

- 全タスクは `- [ ] Tnnn ...`。ユーザーの操作・報告が必要なら **ID の直後**に `[MANUAL]` を置く。ストーリー Phase のみ `[US16]` を付ける。
- `[MANUAL]` は GUI 起動、目視、実機操作、VoiceOver、Instruments、およびユーザーによる設計レビュー。実装・自動テスト・文書作成・コミットを同じタスクへ混ぜない。報告の受領は手動タスク、文書への転記は別の文書タスクとする。
- **分類は実装前の設計レビュー T002 で確認する。実装中は `[MANUAL]` を追加・削除・移動しない。** 実装中に分類の不備が見つかったら該当作業を完了扱いにせず、設計レビューへ戻して扱う。自動化できたという理由で手動確認を代替しない。
- ユーザーの報告がない `[MANUAL]` は未チェックにする。非対話実行でも省略・推測による合格にしない。非手動タスクの完了で手動タスクをチェックしない。
- `[P]` は依存が満たされた後、別ファイルで作業できる候補。既定は順次実装。並列化を明示する場合だけ `AGENTS.md` に従い独立 worktree と `agent/<task-id>-<slug>` を使う。同じファイルを触るタスクと GUI スモークは直列。

## Path Conventions

- 判断・列挙・検証: `Sources/MediaViewerCore/Search/`（AppKit を import しない）。
- 描画・入力・標準パネル: `Sources/MediaViewerApp/Search/`（MainActor）。
- 一時データ: `Sources/FixtureKit/FixtureSets.swift`。自動テストは一時ディレクトリに生成し、権限を戻して削除する。
- 自動検証: `Tests/MediaViewerCoreTests/`、`Tests/MediaViewerPerformanceTests/`。
- 実装中の仕様文書の変更は tasks.md のチェックと、本タスクで明示する quickstart.md への追記だけ。product 反映と feature 凍結は検証完了後の T038・T039 で行う。

## Phase 1: Setup — 設計レビューと基準確認

**Purpose**: 手動分類を実装前に確定し、既存アプリの基準状態と記録先を整える。新たな Package・target・依存は作らない。

- [X] T001 `specs/010-search-folder-picker/quickstart.md` の末尾に「実装・検証記録」欄を追記する。Phase 別自動コマンドの結果、ユーザー報告の受領日・OS・端末・対象ビルド、シナリオ別の回数・起点・結果、権限や外部ボリュームを含む未実施理由、性能値の記録枠を用意し、未実施を成功で埋めない。
- [X] T002 [MANUAL] `specs/010-search-folder-picker/tasks.md` 全件の設計レビューをユーザーに依頼し、GUI・目視・VoiceOver・性能計測等の独立性、ID 直後の `[MANUAL]`、文書作成との分離、依存順と実装中の分類固定について確認報告を受ける。実装タスク T007 以降はこの確認後に開始する。
- [X] T003 リポジトリルートで `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、既存基準の成否と失敗内容を収集する（対象: `Package.swift`、`.build/MediaViewer.app`）。GUI は起動しない。
- [X] T004 [MANUAL] T003 成功後、ユーザーへ `cd /Users/igachan/projects/my_img_viewer` の後に `open .build/MediaViewer.app` を実行するよう依頼する。ツリー・ファイルリスト・プレビューの3ペイン、⌘F の既存検索シート、取消で元の画面へ戻ることについて報告を受ける（手順: `specs/010-search-folder-picker/quickstart.md`）。
- [X] T005 T002・T003・T004 の確認済み結果と未実施事項を `specs/010-search-folder-picker/quickstart.md` の記録欄へ追記する。設計レビューを受けていない分類や GUI 未報告を合格として記録しない。
- [X] T006 T001〜T005 完了後、今回の設計・タスク文書を差分確認し、`specs/010-search-folder-picker/` の対象ファイルだけを Phase 1 のコミットにする。既存の未追跡設計文書も内容を確認し、無関係なファイルを含めず、push は行わない。

**Checkpoint**: 手動分類を確認済み、既存アプリの自動・起動ゲートを通過。文書を作成しただけでは確認済みにしない。

## Phase 2: Foundational — 再現可能な共通フィクスチャ

**Purpose**: US16 の通常・異常・性能ケースに共通する入力を用意する。T006 完了後に開始し、この Phase が US16 の前提となる。

- [X] T007 `Tests/MediaViewerCoreTests/SearchFolderPickerFixtureTests.swift` を新設し、`FixtureSets.searchFolderPicker(in:)` が quickstart の構成を生成する契約を Swift Testing で検証する。`Photos` と `Photos ` の区別、異なる子フォルダ・画像、dot/isHidden、パッケージ内部、3種類のリンク、file/zip、空・削除用・権限用フォルダ、直下10,000フォルダと各JPEGを確認する。生成先は一時領域とし後始末を保証する。
- [X] T008 `Sources/FixtureKit/FixtureSets.swift` に `searchFolderPicker(in:)` を追加し makeAll から呼ぶ。`specs/010-search-folder-picker/quickstart.md` の検証データ表を実装し、既存JPEG・zip生成を再利用する。locked は読取可能な状態で生成し、many-folders は直下10,000フォルダ・各小さなJPEGとする。新たな WebP ツールは導入しない。
- [X] T009 T007・T008 後、`swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行する（対象: `Tests/MediaViewerCoreTests/SearchFolderPickerFixtureTests.swift`、`.build/MediaViewer.app`）。失敗を3回修正しても解消しなければ止めて報告する。
- [X] T010 [MANUAL] T009 成功後、ユーザーへ `cd /Users/igachan/projects/my_img_viewer` の後に `open .build/MediaViewer.app` を依頼し、3ペインと既存検索シートに起動上の退行がない報告を受ける（手順: `specs/010-search-folder-picker/quickstart.md`）。
- [X] T011 T009・T010 の結果を `specs/010-search-folder-picker/quickstart.md` の Phase 2 記録欄へ追記し、GUI の未確認と自動検証の成功を別々に記載する。
- [X] T012 T007〜T011 完了後、`Sources/FixtureKit/FixtureSets.swift`、`Tests/MediaViewerCoreTests/SearchFolderPickerFixtureTests.swift`、本 feature の進捗・記録を Phase 2 のコミットにする。

**Checkpoint**: 以後の Core テストで共通入力を使える。GUI 用データのユーザー領域への生成は手動確認の準備として T022 で行う。

## Phase 3: User Story 16 — 標準パネルで検索起点を設定する（Priority: P1）🎯 MVP

**Goal**: 起点の直接入力を維持し、標準のフォルダ選択パネルから単一フォルダを選べる。確定では起点と古い起点エラーだけを更新、取消では親を保持し、有効な検索操作で初めて検索する。既存検索と外部変更の更新を止めない。隠し項目は標準パネルの動作に従い、パッケージは選択できない。

**Independent Test**: 別フォルダを選んで確定し、親を保ったまま起点全体だけが更新され、検索ボタンでその起点の結果になる。取消10回、キーボード経路5回、5種類の場所と末尾空白、初期位置・異常系・既存検索の継続を quickstart シナリオ1〜9で独立に確認する。

### Tests for User Story 16

T013〜T015 は設計契約に基づいて先に追加し、対応実装がないための失敗を確認する。未実装によるコンパイル失敗と、実装後のアサーション失敗を区別する。検証処理・完了順を小さな注入境界で制御し、sleep や実ユーザーのホーム属性に依存させない。

- [X] T013 [P] [US16] `Tests/MediaViewerCoreTests/SearchRootInputTests.swift` に typed/picked と親入力世代のテストを追加する。typed の trim・`~`・末尾 `/`、picked の末尾空白・表示URLとリンク解決URLの区別、同じ文字列へ戻した編集による typed 化、キーワード編集・パネル取消での入力元維持、初期化・終了を検証する（AS3・AS10、EC-106）。初期位置解決中・確定後検証中の検索受理、解決→検索検証/検索検証→解決の完了順、検索成功/失敗、選択検証成功/失敗の組合せで、失効したパネル提示・選択反映・旧理由反映が0回、有効な検索成功の採用1回（失敗は0回）を固定する。検索失敗後の再試行、パネル表示済みの親検索拒否、検証中の重複検索拒否、空キーワードの無操作、検証中に採用されないことを検証する（U1、FR-143）。
- [X] T014 [P] [US16] `Tests/MediaViewerCoreTests/SearchFolderInitialLocationTests.swift` を新設し、現在入力→開始時既定→ホームの順序と全滅、候補の重複除外、入力欄を書き換えないこと、既定パスを trim せず使うことを検証する。注入した検証処理で、存在しない・ファイル・zip・パッケージ・読取不能を次候補へ進め、隠しフォルダを許可することを固定する。EC-102 で既定の F が無効ならホームへ進み、V を候補に加えない（AS4・AS5・AS11、EC-103、FR-143）。
- [X] T015 [P] [US16] `Tests/MediaViewerCoreTests/SearchRootTests.swift` と `Tests/MediaViewerCoreTests/BrowserModelSearchTests.swift` で不足する既存回帰を追加する。直接入力の解釈・既存エラー・隠し祖先を新たに拒否しないこと・パッケージ自身の拒否、リンク解決後URL、選択後の消失/権限変更を再検証で拒否すること、有効な検索開始でだけ検索AをBへ置換し旧バッチを捨てることを固定する。既存の009のフォルダ検索・結果処理の期待値を保持し、EC-102 で一覧の folder が F のまま、検索結果表示中は検索前・zip内はzipを含むフォルダを既定に渡せることを回帰確認する（I1、FR-081）。

### Core implementation for User Story 16

- [X] T016 [US16] `Sources/MediaViewerCore/Search/SearchRootInput.swift` に SearchRootInput と SearchPanelInputState を実装する。データモデルの制約「初期状態は typed。picked は標準パネルの検証成功からのみ作る。」「起点欄のユーザー編集は常に typed にする。同じ文字列へ戻しても picked には戻さない。」「キーワード編集、パネルの取消・失敗・再表示は状態を変えない。」を守る。typed は「`SearchRoot.parse(text, home:)` の既存規則」、picked は「標準パネルで確定した絶対 file URL」「`url.path`、引用符・エスケープなし」「選択 URL をそのまま返す。trim しない」。pendingOperation は「idle / resolvingInitialLocation / validatingSelection / validatingSearch」、requestGeneration は「処理開始・失効で進める依頼世代」とし、完了は「捕捉した revision・requestGeneration・処理種別と isActive がすべて一致した場合だけ採用する」。panelPresented を入力として親アクションの受理も純粋に判断する。検索受理時は旧提示・旧選択検証を失効させてから検索検証へ遷移し、失敗後も復活させず新依頼を発行する（T013・T015、U1）。
- [X] T017 [US16] `Sources/MediaViewerCore/Search/SearchFolderInitialLocation.swift` に初期位置の候補順・検証・理由型を実装する。`SearchRootInput` と `SearchRoot.validate` を再利用し、全 I/O を UI スレッド外へ置く。現在入力→開始時既定→ホームを重複なく試し、存在・フォルダ・パッケージ拒否・読取りを確認する。隠しフォルダは許可し、失敗は次候補へ進め、全滅だけを理由として返す。検証処理はテストから注入できる境界にする。成功は解決後の URL を返し、起点欄を変更しない（T014・T015・T016）。

### App integration for User Story 16

- [X] T018 [US16] `Sources/MediaViewerApp/Search/SearchPanelController.swift` のキーワード欄を標準の `NSSearchField` にし、起点欄の近くに「選択…」を追加する。タイトル・メッセージ・選択ボタン名を設定し、Tab はキーワード→起点→選択…→キャンセル→検索、⇧Tab は逆順、Space で「選択…」を操作する。初期フォーカスは初回だけキーワードへ置き全選択し、標準色・標準コントロール・アクセシビリティ名を使う（T016、FR-081・144）。
- [X] T019 [US16] `Sources/MediaViewerApp/Search/SearchPanelController.swift` に初期位置の非同期解決と `NSOpenPanel` の提示を追加する。`canChooseFiles = false`、`canChooseDirectories = true`、`allowsMultipleSelection = false`、`canCreateDirectories = false`、`resolvesAliases = true`、`treatsFilePackagesAsDirectories = false`、`showsHiddenFiles = false`、`directoryURL` を設定し、親ウインドウへ `beginSheetModal(for:)` する。`runModal` は使わない。初期解決中の検索・編集・終了で依頼を失効させ、panelPresented で親の検索・選択を防御する。全滅は親に理由だけを示す（T017、FR-141・143・144）。
- [X] T020 [US16] `Sources/MediaViewerApp/Search/SearchPanelController.swift` を確定後の非同期検証へ接続する。パネルの成功 URL を捕捉し、`SearchRoot.validate` の完了を入力世代・依頼世代・処理種別で照合する。成功時だけ起点欄全体を picked に置換して古い起点理由を消し、失敗時は選択 URL を反映せず親に理由を表示・読み上げ、欄・キーワードを保持する。検証中も取消でき、編集・検索受理・終了後の古い結果で欄を変更しない。パネル終了後は「選択…」へフォーカスを戻す。検索では常に `SearchRoot.validate` を実行し、成功時だけ既存 `onSearch` を一度呼ぶ。BrowserModel・検索・保存を選択操作から呼ばない（T016・T019、AS1・AS2・AS9・AS12・AS13）。
- [X] T021 [US16] T013〜T020 後、`Sources/MediaViewerCore/Search/` の AppKit 非依存、App の I/O 委譲、標準パネルの設定、`Sources/MediaViewerApp/App/MainSplitViewController.swift` の有効 onSearch 境界と既存保存契約を差分レビューする。不要になった独自ピッカーの型・テスト・ファイルが残っていないことを確認する。その後 `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行して結果を収集する。3回修正してもテストが通らなければ止めて報告する。

### Manual acceptance for User Story 16

以下はすべて T021 の成功ビルドを使い、ユーザーが操作して報告する。実装・修正・文書転記は含まない。不具合の修正でビルドが変わった場合は自動ゲートと影響する手動確認を再実施し、対象ビルドを揃える。ユーザー領域へのフィクスチャ生成はユーザーのコマンドで行い、破壊的な再現は専用データだけを使う。

- [X] T022 [MANUAL] [US16] ユーザーへ `cd /Users/igachan/projects/my_img_viewer` の後に `open .build/MediaViewer.app` を依頼し、3ペイン表示と⌘Fから検索シート・標準のフォルダ選択パネルが開く起動スモークの報告を受ける。続いて `scripts/make-fixtures.sh ~/MediaViewerFixtures` で `specs/010-search-folder-picker/quickstart.md` の専用データを生成してもらう。WebPツールが不足する場合は導入前に確認し、生成未完了を後続確認の成功と扱わない。
- [X] T023 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ1をユーザーに実施してもらい、通常・日本語・空白名・`/`・外部ボリュームの5/5件で標準パネルから選択して有効な検索開始が成立し、検索バーの起点と既知の一致結果で選択場所と検索起点が一致、確定だけの検索開始0件、空フォルダ/ルート自身の選択、ファイル/zip/パッケージ/複数選択/作成の不可を報告してもらう（AS1・AS8、SC-058）。全走査の完了は要求せず照合後の解除を許すが、照合前終了と外部ボリューム未実施は未確認として保留し、成功に数えない（A1）。
- [X] T024 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ2をユーザーに実施してもらい、標準パネルの取消ボタン5回とEsc5回について検索シート終了・入力変更・選択操作によるツリー/一覧/プレビュー変更が各0回、元のエラー保持、フォーカス復帰、次の有効確定で古いエラーだけ消えることの報告を受ける（AS2・AS9、SC-059）。
- [X] T025 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ3をユーザーに実施してもらい、直接入力の空白/`~`/末尾`/`、空/相対/不存在/ファイル/zip/読取不能からのフォールバック、開始時既定の消失後のホーム、取消時の元文字列保持、選択後の直接編集と直接入力だけの検索について報告を受ける。EC-102で一覧F・ツリーVから⌘Fと「ファイル」メニューの「検索…」をそれぞれ開くと既定はFで、親の取消によって一覧・ツリー・プレビューが変わらないことを確認する（変更後のUS1-AS25）。子の初期位置は無効なFを飛ばしてホーム、Vは候補外、取消後もFを保持することも確認する。全候補不可は T014 の注入検証結果と区別する（AS3〜AS5、EC-103、I1）。
- [X] T026 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ4をユーザーに実施してもらい、未編集の `Photos ` で space-hit が一致し plain-hit を別起点として使わないこと、再表示・取消・キーワード編集後の保持、起点欄を編集して同じ文字列へ戻すと typed の trim へ戻ることの報告を受ける（AS10、EC-106、SC-058）。
- [X] T027 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ5をユーザーに実施してもらい、標準パネルで⌘⇧.により隠し項目が表示され、隠しフォルダを選択できること、パッケージは一覧に出ても選択・内部移動できず、パッケージを指す起点では既定/ホームから始まること、直接入力の既存規則が変わらないことを報告してもらう（AS11、FR-141・143）。
- [X] T028 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ6をユーザーに実施してもらい、専用 vanishing/locked の移動・権限喪失をパネル確定後の検証と親の検索時で各拒否し、理由・入力保持・復帰を確認した報告を受ける。`chmod 000 ~/MediaViewerFixtures/search-folder-picker/locked` の確認直後は必ず `chmod 755 ~/MediaViewerFixtures/search-folder-picker/locked` へ戻してもらう。取り外したボリューム、検証中のEscと遅い完了の無作用も確認する（AS7・AS12、EC-104）。
- [X] T029 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ7のキーボード操作をユーザーに5回実施してもらい、⌘F→Tab/逆順→Space→標準パネルの矢印/Return/Esc→親の検索が5/5回成功した報告を受ける。OSキーボードナビゲーションのオン/オフ、空フォルダ、パネルReturn/Escの分離、親へ戻るフォーカス、復帰後の親Escで既存検索を停止しないこと、VoiceOverで親ボタン・標準パネル・フォルダ名・エラーが識別できること、標準/ダークモードで表示が識別できることを確認する（AS6、EC-105、SC-060、FR-144）。
- [X] T030 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ8をユーザーに実施してもらい、検索A中のパネル表示・確定・取消でも途中件数/結果/外部更新が続き、無効なBでAを止めず有効なBだけで置換する報告を受ける。`defaults read local.my-img-viewer.MediaViewer` による最後のフォルダの不変、親を開き直した既定起点、再起動時に選択起点・入力元・結果を保存しないことも確認する（AS13、FR-003・085・086・142）。
- [X] T031 [MANUAL] [US16] `specs/010-search-folder-picker/quickstart.md` シナリオ9をユーザーに実施してもらい、many-folders を標準パネルで開き、直下10,000フォルダの表示・移動・取消が標準パネルで応答し、既存検索の同時更新が続くことを報告してもらう。Instruments Hangs等で端末・OS・件数・最大停止時間と主スレッド上の列挙/検証/権限確認の有無を測定し、100ms以上のUI停止がないか確認する。検索が速すぎて同時更新を観測できなければ専用データを増やして再試行し、未観測を合格にしない。
- [X] T032 [US16] T021 の自動結果と T022〜T031 の受領済み報告を `specs/010-search-folder-picker/quickstart.md` の記録欄へ追記する。SC-058の5/5（開始成立・起点・既知の一致結果・走査完了/照合後解除/未確認を各記録）と末尾空白、SC-059の10回/変更0回、SC-060の5/5と指定7ケースを対応付け、性能の環境・値・未実施理由を記載する。T014の注入結果と実操作を区別し、実施の代行や未報告の補完はしない。
- [X] T033 [US16] T013〜T032 の全ゲートと受け入れ基準が満たされた後、`Sources/MediaViewerCore/Search/`、`Sources/MediaViewerApp/Search/`、対象の `Tests/` と本 feature の進捗・記録を差分確認して Phase 3 のコミットにする。GUI未確認のまま US16 完了・MVP達成としない。

**Checkpoint**: US16 が独立に動作し、SC-058〜060 と既存検索の継続・性能を確認済み。MVP はこの Phase まで（Setup・Foundationalを含む）。

## Phase 4: Polish & Cross-Cutting Concerns — 引渡しと仕様反映

**Purpose**: T033 後、利用手順を整え、最終検証の後だけ product へ差分を反映して feature を凍結する。

- [X] T034 `README.md` の検索手順に、直接入力と「選択…」、確定と検索の違い、取消、キー操作、隠し項目・パッケージの標準パネルでの扱い、末尾空白の扱いを追記する。`specs/010-search-folder-picker/quickstart.md` への検証案内を追加し、未提供の履歴・新規作成・複数起点を案内しない。
- [X] T035 最終状態に対して `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行する（対象: `Package.swift`、`.build/MediaViewer.app`）。既存10,000件検索の性能基準と、未解決の失敗・未実施手動項目が残っていないか確認する。
- [X] T036 [MANUAL] T035 成功後、ユーザーへ `cd /Users/igachan/projects/my_img_viewer` の後に `open .build/MediaViewer.app` を依頼する。最終ビルドの3ペイン、検索シート→標準パネルで別フォルダ確定→検索、および取消での親入力保持について報告を受ける（手順: `specs/010-search-folder-picker/quickstart.md`）。
- [X] T037 T035・T036 の結果と最終ビルド、全受け入れ基準の証拠、性能値、制限・残件の有無を `specs/010-search-folder-picker/quickstart.md` の記録欄へ追記する。T022〜T031を含め未確認が残る場合は未完了を明示し、T038へ進まない。
- [X] T038 実装・自動検証・手動検証がすべて完了した後、`specs/010-search-folder-picker/spec.md` の「反映先」表に従い `specs/product/search.md` と `specs/product/contracts/keyboard-and-menus.md` に FR-081・US1-AS25の変更、FR-141〜144、US16-AS1〜13、EC-103〜106、SC-058〜060、A-83〜86を反映する。FR-081とUS1-AS25の既定値は一覧基準・EC-102のFへ統一し、キー契約の既定値を維持してsearch.mdの要件・受け入れシナリオのツリー基準を改める。US1-AS25の検索モーダル構成も変更後のFR-081に合わせる。FR-141の標準パネル・隠し項目・パッケージの扱いと、FR-143の検索受理による提示失効、SC-058の開始成立・起点一致（全走査不要）も移す。決定本文だけを移し、009の検索対象・結果・保存の差分を巻き戻さず、IDを再利用せず、`specs/product/contracts/settings.md` の保存キーを追加しない。
- [X] T039 T038 の反映先・ID・本文整合性を確認し、`specs/010-search-folder-picker/spec.md` 冒頭に product へ移行済み・凍結の注記を付ける。設計内容を実装へ合わせて書き換えず、最終の進捗は `specs/010-search-folder-picker/tasks.md` で確定する。
- [X] T040 T034〜T039 完了後、`README.md`、`specs/product/search.md`、`specs/product/contracts/keyboard-and-menus.md`、本 feature の記録と凍結注記を差分確認して Phase 4 のコミットにする。仕様反映後の文書リンク・ID整合性を確認し、pushは行わない。

**Checkpoint**: 最終起動を含めた検証が揃い、productが更新され、本 feature は実装の記録として凍結される。

## Dependencies & Execution Order

### Phase Dependencies

```text
Phase 1: T001 → T002 [MANUAL] → T003 → T004 [MANUAL] → T005 → T006
  ↓
Phase 2: T007 → T008 → T009 → T010 [MANUAL] → T011 → T012
  ↓
Phase 3: US16 (P1 / MVP)
  T013 + T015 → T016 ─┬→ T017 ← T014
                      └→ T018 → T019 → T020 → T021
  T021 → T022 [MANUAL] → T023〜T031 [MANUAL] → T032 → T033
  ↓
Phase 4: T034 → T035 → T036 [MANUAL] → T037 → T038 → T039 → T040
```

- 全ストーリーは Phase 2 の完了に依存する。本 feature は US16 のみで、他の新規ストーリーへの依存はない。009は統合済みの基準として扱う。
- T013〜T015 は T012 後、別ファイルの契約テストとして並列化できる。T016はT013・T015、T017はT014・T015・T016を前提とする。T018〜T020は同じファイルなので直列。
- Core は入力型→初期位置の解決の順で実装する。App は標準検索欄・選択ボタン→初期位置と標準パネル→確定後検証の順。
- T023〜T031 はT022と必要なフィクスチャが前提。同じアプリ・専用データ・OS設定を扱うのでユーザーが1件ずつ順に行い、権限・移動・設定を各確認後に戻す。
- 手動報告待ちに独立した非手動作業を進めることはできるが、未確認 Phase の合格・Phaseコミット・product反映を先取りしない。各PhaseコミットはそのPhaseの全ゲート後。
- 起動失敗では推測修正を避け、`AGENTS.md` 記載のlldbコマンドによるObjective-C例外停止をユーザーへ依頼する。GUI起動の扱いと `[MANUAL]` 分類を変更しない。

## Parallel Example: User Story 16

並列化は可能性の提示であり実行指示ではない。既定は順次実装する。明示的に並列化する場合はクリーンなPhaseブランチから独立worktreeを用意し、各担当は自分のworktree内だけ編集してコミットSHAを返す。

```text
# T012 後、別ファイルのテスト（依存する型は設計契約どおりに参照）
T013: Tests/MediaViewerCoreTests/SearchRootInputTests.swift
T014: Tests/MediaViewerCoreTests/SearchFolderInitialLocationTests.swift
T015: Tests/MediaViewerCoreTests/SearchRootTests.swift + BrowserModelSearchTests.swift

# Core実装は型の依存順に直列
T016: Sources/MediaViewerCore/Search/SearchRootInput.swift
T017: Sources/MediaViewerCore/Search/SearchFolderInitialLocation.swift

# Appは同じファイルなので直列
T018 → T019 → T020: Sources/MediaViewerApp/Search/SearchPanelController.swift
```

統合担当がPhaseブランチへ `git merge --no-ff` または cherry-pick し、各統合後に `swift build` / `swift test`。GUIスモークは統合後の1つのアプリでのみ行い、不要になったworktree・作業ブランチを削除する。同じ作業ディレクトリでの内部subagent並列編集は行わない。

## Implementation Strategy

### MVP First（US16）

1. Phase 1で分類の設計レビューと既存アプリの基準を確認する。
2. Phase 2で再現用データを用意し、Coreの契約テストから実装する。
3. 入力元・初期位置・世代をCoreで完結させ、標準パネルと親への接続を順に実装する。
4. 自動ゲートを通過後、ユーザーの起動・全手動シナリオの報告を受け、US16をMVPとして検証する。
5. 最終ゲート後に利用手順とproduct反映・凍結を完了する。

### Incremental Delivery

- 内部増分は「入力元と世代」→「初期位置の解決」→「標準パネルの表示」→「確定後検証と親への接続」→「キーと読み上げ」。US16の部分実装をストーリー完了として扱わない。
- 初期位置の解決・確定後の検証はUIスレッドに置かず、通信API・設定キー・起点履歴・外部依存を追加しない。
- 自動テスト成功、手動確認済み、記録済みを別々のチェックで表す。GUI報告待ちでも分類を変えず、未実施理由を残す。
- 実装中に spec.md・plan.md・research.md・data-model.md・契約を書き換えない。仕様変更が必要なら実装判断で吸収せず設計工程へ戻す。

## Coverage & Completion

| 要求 | 自動/実装 | 手動確認 |
|---|---|---|
| FR-081、US1-AS25、AS3・AS10、EC-106：直接入力・入力元・末尾空白、EC-102の一覧基準の既定値（I1） | T013・T015・T016・T018・T020 | T023・T025・T026 |
| FR-141、AS8・AS11・AS12：標準パネル・単一選択・パッケージ・確定後再検証 | T014・T016・T017・T019・T020 | T023・T027・T028 |
| FR-142、AS1・AS2・AS9・AS13：成功/取消の境界・検索継続 | T013・T016・T019・T020 | T023・T024・T030 |
| FR-143、AS4・AS5、EC-103：初期候補・全滅、検索との提示競合（U1） | T013・T014・T016・T017・T019 | T025・T027（全滅・完了順は注入検証） |
| FR-144、AS6、EC-105：キー・フォーカス・読み上げ | T018・T019・T020 | T029 |
| AS7、EC-104：選択後の削除・権限喪失 | T015・T017・T020 | T028 |
| SC-058：5種類の開始成立・起点一致（全走査不要、A1）と末尾空白・確定だけの開始0件 | T013・T014・T016・T017・T019 | T023・T026 |
| SC-059：取消10回・親と表示への変更0回 | T016・T019・T020 | T024 |
| SC-060：キーボード5回と指定7ケース | T016・T018〜T020 | T024・T025・T027〜T029 |
| 性能・外部更新・保存契約 | T015・T017・T020・T021 | T030・T031 |

全40タスク（US16:21、ストーリー外:19）。`[MANUAL]` は14件、`[P]` は3件。各チェックはその作業の証拠が得られてから付け、手動確認の未実施を残したまま全体完了にしない。
