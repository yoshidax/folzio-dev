# Implementation Plan: 検索起点フォルダの GUI 選択

**Branch**: `010-search-folder-picker` | **Date**: 2026-10-27 | **Spec**: [spec.md](spec.md)

**Input**: 本 feature の spec、`specs/product/search.md` の FR-081・082・085・086・EC-34、`overview.md` の FR-003・040・041・042・EC-19・A-09、`directory-tree.md` の FR-065、`zip.md` の FR-069、`contracts/keyboard-and-menus.md`・`contracts/settings.md`。憲章 v1.2.0。`009-folder-search` は統合済みだが product 未反映の差分も参照し、検索対象・結果・保存の扱いを維持する。

## Summary

検索シートの起点欄の近くに「フォルダを選択…」を加え、階層を辿って1つのフォルダを選べる子シートを開く。直接入力と既存の検索開始経路を保つ。確定では起点欄だけを更新して古い起点エラーを消し、取消では入力とエラーを保つ。開く・確定・取消では検索を開始・停止せず、既存検索の結果更新も続ける。

小さな AppKit の専用選択画面を使う。`NSOpenPanel` の `showsHiddenFiles = false` はユーザーの表示切替を禁止せず、公開 delegate だけではパッケージの非表示・内部移動禁止・非同期の確定検証を同時に保証できない。A-83 で許容される同等 GUI を採る（[research.md](research.md) R1）。既存 `DirectoryLister` を使い、判断・列挙・検証は Core、表示と入力は App に置く。

## Technical Context

**Language/Version**: Swift 6、`swiftLanguageModes: [.v6]`。

**Primary Dependencies**: Foundation、Swift Concurrency、AppKit の `NSViewController`・`NSTableView`・`NSButton`・アクセシビリティ API。既存 `DirectoryLister`、`SearchRoot`、`VolumeProvider` を利用。外部依存・新 target なし。Core は AppKit を import しない。

**Storage**: シートのメモリ内だけ。選択 URL と入力元は検索シートの終了時に破棄。UserDefaults のキー、起点履歴、ブックマークは追加しない。選択操作で `view.lastFolderPath` を変えない。

**Testing**: Swift Testing。入力元、候補順、GUI 到達可否、処理世代、異常系を Core で検証。ファイル・zip・削除・権限・隠し・パッケージ・リンク・末尾空白を含める。FixtureKit で一時フィクスチャを生成・削除する。シート、Tab・Return・Esc、VoiceOver、既存検索の継続は `.app` の手動確認を必須とする。

**Target Platform**: macOS 15 以降。

**Project Type**: AppKit デスクトップアプリ + Core ライブラリ、単一 Swift Package。

**Performance Goals**: アプリが行う列挙・メタデータ取得・存在確認・権限確認は UI スレッドの外。現在位置の直下だけを列挙し、全階層を先読みしない。処理中も取消可能にする。既存の 10,000 件検索・操作停止 100ms 未満・検索 3 秒以内を維持する。大量の直下フォルダと既存検索の同時更新を計測する（quickstart シナリオ 9）。

**Constraints**: オフライン、ネットワーク API 不使用、AppKit のみ、ファイル変更なし。GUI の表示制限を直接入力の検証へ追加しない。確定後も検索時に再検証する。GUI 起動はユーザーへ依頼する。

**Scale/Scope**: 親にボタン1つ、入力元の状態、子シート1画面。ホーム・ルート・表示可能なマウント済みボリューム、親、直下のフォルダへ移動できる。単一選択のみ。ファイル表示、新規作成、隠し項目の表示切替、子でのパス直接入力、最近使った場所は追加しない。

**Resolved design questions**: 未解決事項なし。部品、入力元、到達可否、非同期検証、シート所有関係、テスト方法、既定値と合格条件は research.md R1〜R9 で決定した。

## Constitution Check

*Phase 0 前に評価し、Phase 1 後に再評価した。PASS は設計適合を示し、実装・GUI 検証の完了ではない。*

| 原則・ゲート | Phase 0 前 | Phase 1 後の設計と検証方針 |
|---|---|---|
| I ローカル完結 | PASS | ローカル読み取りのみ。通信・送信・ファイル変更・保存なし。no-network チェックを維持 |
| II 性能 | PASS | 直下の非同期列挙、候補・確定の非同期検証、古い結果の排除。取消は I/O 終了を待たない。既存検索を止めず、大量件数と同時更新を検証 |
| III キーボード・アクセシビリティ | PASS | Tab 順序、Space、子の階層移動・Return・Esc、親へのフォーカス復帰、ラベル・エラー読み上げを契約化 |
| IV テスト必須 | PASS | 入力元・候補順・表示可否・世代を単体検証。異常系と取消後の遅い完了を含める。GUI 未確認を完了にしない |
| V シンプルさ | PASS | 依存・汎用ファイラ・設定追加なし。専用 UI の理由は Complexity Tracking に記載 |
| 技術制約・AppKit 不変条件 | PASS | Core に判断、App に MainActor の UI。ビュー追加後に制約を有効化。split view は変更不要 |
| 仕様管理 | PASS | 本 feature の設計文書のみ作成。進捗は後続 tasks.md。product 反映・凍結は実装と検証の後 |

## Project Structure

### Documentation (this feature)

```text
specs/010-search-folder-picker/
├── spec.md
├── checklists/requirements.md
├── plan.md
├── research.md
├── data-model.md
├── contracts/search-folder-picker.md
├── quickstart.md
└── tasks.md                       # 次の speckit-tasks で生成
```

### Source Code (repository root)

以下は実装先の予定。新規型名は設計名であり実装済み API ではない。

```text
Sources/MediaViewerCore/Search/
├── SearchRoot.swift               # 既存 parse/validate の意味を維持
├── SearchRootInput.swift          # 新規: 入力元と親の入力世代の状態
├── SearchFolderAccess.swift       # 新規: 候補順・到達可否・列挙・検証
└── SearchFolderPickerState.swift  # 新規: 移動・選択・処理世代
Sources/MediaViewerApp/Search/
├── SearchPanelController.swift    # ボタン・入力元・子シート・復帰
└── SearchFolderPickerController.swift # 新規: フォルダ単一選択
Sources/FixtureKit/FixtureSets.swift # searchFolderPicker(in:) を追加
Tests/MediaViewerCoreTests/
├── SearchRootInputTests.swift     # 新規
├── SearchFolderAccessTests.swift  # 新規
├── SearchFolderPickerStateTests.swift # 新規
├── SearchRootTests.swift          # 既存直接入力の回帰
└── BrowserModelSearchTests.swift  # 既存開始・置換の回帰
Tests/MediaViewerPerformanceTests/
└── PerformanceBaselineTests.swift # 既存検索基準を維持
```

**Structure Decision**: `DirectoryLister.subfolders` と `SearchRoot.validate` を再利用する。GUI 専用の到達可否を別に置き、一般の一覧・検索対象は変更しない。小さな状態値で非同期の順序を単体検証し、UI テスト target は増やさない。

## Phase 0 — Research

[research.md](research.md) に決定・根拠・代替案を記録した。既存コードに加え、読み取り専用の調査エージェントでローカル SDK と Apple 公開ドキュメントを確認した。未解決事項・仕様の確認待ちはない。

## Phase 1 — Design

1. **入力元**: `.typed(String)` / `.picked(URL)` を保持する。起点欄のユーザー編集だけで直接入力へ戻し、同じ文字列へ戻しても直接入力とする。キーワード編集・子の取消では変えない。検索と初期位置は同じ解釈を使う。
2. **初期位置**: 現在入力 → シート開始時の既定値 → ホームの順に検証する。候補とその経路の GUI 到達可否を確認し、全滅なら親に理由を示す。入口はホーム・`/`・表示可能なマウント済みボリューム。隠し・パッケージとその内部へ移動しない。
   既定値は既存の `MainSplitViewController.showSearch` とキー契約に合わせ、一覧に表示中（検索結果中は検索前、zip 内は zip を含む）のフォルダを開始時に捕捉する。EC-102 の一覧 F・ツリー V では F。F が GUI 対象外なら F の候補を飛ばしてホームへ進み、V は候補に追加しない。取消でも親の F を保持する。
   既存 US1-AS25 も本 feature の変更対象に含め、FR-081 と同じ一覧基準で受け入れを判定する。実装・検証後の T045 で両 ID を search.md へ反映する。
3. **選択画面**: 現在位置の読み取り専用ラベル、場所、親、直下フォルダの単一選択テーブル、エラー、取消・選択ボタン。行選択中はそのフォルダ、未選択時は現在位置を確定対象とし、空フォルダと `/` も選べる。ダブルクリック・⌘↓で内部、⌘↑で到達可能な親へ移る。
4. **非同期処理**: 世代と対象を捕捉し、移動・選択変更・取消で古い結果を失効させる。確定時に再検証し、失敗は子のエラーだけを表示・読み上げる。親の入力世代と採否も Core の小さな入力状態値で扱い、古い入力の結果で検索しない。
   親の処理種別・依頼世代も Core で管理する。初期位置解決中の検索操作を受理したら、提示依頼を先に失効させてから検索検証を始める（空キーワードは既存どおり無操作）。検索検証中は選択操作と重複検索を拒否し、失効した初期位置の成功・失敗は無視する。検索失敗でも旧依頼は復活させず、改めて選択を要求できる。MainActor 上で先に子を提示済みなら親の検索を拒否する。検索検証と初期位置解決の完了順の両方、検索失敗後の遅い完了、子の先行提示を決定的にテストする。
5. **シートとキー**: 検索 controller 自身から `presentAsSheet` し、`runModal` を使わない。表示中の親アクションを防御し、Return・Esc を子で消費する。終了後は親の選択ボタンへ戻す。親の初期キーワード全選択は初回だけにする。
6. **検索との接続**: 子は選択 URL / 取消だけを返し、`BrowserModel`・`onSearch` を呼ばない。親は確定成功時だけ欄を置換して古い起点エラーを消す。検索ボタンで `SearchRoot.validate` が通ったときだけ既存 `onSearch` を呼ぶ。履歴・最後のフォルダの操作は追加しない。
7. **検証と引渡し**: [data-model.md](data-model.md)、[UI 契約](contracts/search-folder-picker.md)、[quickstart.md](quickstart.md) を tasks 生成の入力にする。実装 Phase は build → test → no-network → make-app → ユーザーの起動スモークの順。GUI 未確認のタスクは未チェックに保つ。
   SC-058 の5ケースは検索開始の成立・検索バーの起点・既知の一致結果で合格を判定する。全走査の完了は要求せず、照合後の解除を許す。EC-102 から開く既定値・初期位置・取消の回帰も手動確認する。

### Constitution Check（Phase 1 後の再評価）

上表のとおり全項目 PASS。入力元は末尾空白の保持、到達可否は非表示規則、世代は非同期の競合対策に必要である。新しい要件・依存・保存項目はない。

本コマンドは Phase 1 の設計で終了する。tasks 生成、実装、ビルドと GUI 検証は後続工程で行う。

## Complexity Tracking

憲章違反はない。単純な案を採らない理由を記録する。

| 追加する複雑さ | 必要な理由 | 採らなかった単純な案と理由 |
|---|---|---|
| 専用のフォルダ選択子シート | FR-141 の非表示・表示切替禁止・内部移動禁止と非同期の確定検証 | `NSOpenPanel` の公開設定・delegate だけでは契約を保証できない。内部ビュー変更や移動後の巻戻しは使わない |
| 入力元と処理世代 | GUI パスの空白保持、古い結果による誤確定の防止 | 文字列だけでは入力元を区別できず、Task.cancel だけでは遅れて返る I/O を除けない |
