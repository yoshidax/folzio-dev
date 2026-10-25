# Implementation Plan: スライドショー

**Branch**: `006-add-slideshow` | **Date**: 2026-10-25 | **Spec**: [spec.md](spec.md)

**Input**: `specs/006-add-slideshow/spec.md` と同書が参照する `specs/product/` の領域・契約。憲章 v1.2.0。

## Summary

現在の一覧の対応メディアを、プレビューのみ表示で3秒ごとに表示順で循環する。ツールバー・「表示」メニュー・⇧⌘S から開始し、矢印入力ごとに送りを3秒先へ延期し、Esc で終了する。通常フォルダ・zip の現在階層・検索結果、動画、全画面に同じ規則を適用する。

既存の `BrowserModel.listing.files` と URL による識別・選択・プレビューを再利用する。Core に対象選定と時刻を入力できる実行状態、App に単発待機・入力調停を接続する小さな `SlideshowCoordinator` を置く。全画面とは独立した復帰スナップショットを持ち、一時的な表示を履歴や設定へ混入させない。根拠は [research.md](research.md)、状態は [data-model.md](data-model.md)、公開操作は [contracts/slideshow.md](contracts/slideshow.md) を参照。

## Technical Context

**Language/Version**: Swift 6（Package の `swiftLanguageModes: [.v6]`）

**Primary Dependencies**: Foundation / Swift Concurrency、AppKit、既存の ImageIO・AVFoundation・AVKit。外部パッケージ追加なし。Core は AppKit 非依存。

**Storage**: 既存のローカル UserDefaults のみ。実行状態・deadline・復帰情報はメモリだけに置く。新しい設定キーや永続化形式なし。

**Testing**: Swift Testing。Core の仮想時刻・イベント調停・BrowserModel・履歴テスト、既存性能テスト、ユーザーによる `.app` の手動確認。

**Target Platform**: macOS 15 以降

**Project Type**: AppKit デスクトップアプリ + Core ライブラリ、単一 Swift Package

**Performance Goals**: SC-034 の20回の選択間隔と SC-035 の最終入力からの送りを各3.0〜3.2秒で実測。既存の先読み済み切替100ms、24MP JPEG 表示0.5秒、初回画像1秒、動画開始1秒、10,000件で UI を止めない基準を維持。選択とデコード／再生完了の時刻を分ける。

**Constraints**: オフライン・ネットワーク API 不使用。列挙・デコード・展開・ファイル操作を UI スレッドで行わず、既存キャッシュ上限を維持。3秒固定で設定・専用一時停止・ランダム再生・トランジションは追加しない。GUI 起動はユーザーが行う。

**Scale/Scope**: 現在の1つの一覧全体（画面外を含む）。フォルダや zip を自動で開かず、サブ階層へ移らない。10,000件の一覧・大量検索結果でも線形の対象走査に留め、メディア本体の複製や全件先読みを追加しない。

**Resolved design questions**: 対象と識別、動画維持、期限と入力競合、閲覧先置換、全画面復帰、履歴への表示投影は R1〜R8 に記す。U1 は既存の編集・モーダルの入力優先と固定周期を維持して明確化した。I1（実行中の並べ替え操作経路）は人の判断待ちで、今回の修正では確定しない。

## Constitution Check

*Phase 0 前と Phase 1 後に評価。PASS は設計の適合判定であり、実装・GUI 検証済みという意味ではない。*

| 原則・ゲート | Phase 0 前 | Phase 1 後の設計と検証方針 |
|---|---|---|
| I ローカル完結 | PASS | 通信・送信・ファイル変更なし。既存読み込み経路と no-network チェックを利用 |
| II 性能 | PASS | 単発待機と現在一覧の走査だけを追加。非同期デコード・キャッシュ上限を維持。SC-034/035 と既存性能基準を測定・記録 |
| III キーボード・アクセシビリティ | PASS | ⇧⌘S・矢印・Esc・全画面操作、日本語ラベル・キー入りツールチップ、全入口で同じ可否判定 |
| IV テスト必須 | PASS | 対象・開始位置・取消・競合・一覧更新・履歴・異常系を Core で検証。描画・再生・全画面は手動ゲート |
| V シンプルさ | PASS | 既存 URL・一覧・選択・隠れたリスト移動・幅計算を再利用。新依存や汎用再生基盤なし |
| 技術制約・AppKit 不変条件 | PASS | MainActor、minimumThickness 160/240/320pt、既存 collapse 手順を維持。禁止 delegate override を追加しない |
| 仕様管理・検証ゲート | PASS | 成果物は本 feature に限定。実装中は tasks のチェックと明示タスクの追記のみ。product 反映は実装・検証後。GUI 未確認を完了にしない |

違反・例外申請はない。

## Project Structure

### Documentation (this feature)

```text
specs/006-add-slideshow/
├── spec.md
├── checklists/requirements.md
├── plan.md
├── research.md
├── data-model.md
├── contracts/slideshow.md
├── quickstart.md
└── tasks.md                 # 次の /speckit-tasks で生成。本コマンドでは作らない
```

### Source Code (repository root)

以下は実装先の予定。既存ファイルの修正を優先し、新規には「新規」を付す。

```text
Sources/MediaViewerCore/
├── Slideshow/
│   ├── SlideshowSequence.swift       # 新規: 抽出・開始位置・循環
│   └── SlideshowSession.swift        # 新規: deadline・世代・pending due・入力優先
├── Browser/BrowserModel.swift       # 選択整理・置換前通知・非同期結果の世代確認
├── Model/PaneLayout.swift            # コマンド抑止・復帰判断
└── History/HistoryNavigator.swift    # 既存記録規則を維持。必要な接続のみ
Sources/MediaViewerApp/
├── Slideshow/SlideshowCoordinator.swift # 新規: 単発待機・UI の開始終了を接続
├── App/
│   ├── MainSplitViewController.swift
│   ├── MainWindowController.swift
│   ├── MainToolbarController.swift
│   ├── MainMenu.swift
│   └── AppDelegate.swift
├── FileList/FileListViewController.swift
├── Preview/PreviewViewController.swift
└── Shared/IconCatalog.swift          # 既存方式で開始アイコンを追加
Sources/FixtureKit/FixtureSets.swift   # mixed / zip / 同名 / 1秒・10秒動画
Tests/MediaViewerCoreTests/
├── SlideshowSequenceTests.swift      # 新規
├── SlideshowSessionTests.swift       # 新規
├── BrowserModelSlideshowTests.swift  # 新規
├── PaneLayoutTests.swift
└── HistoryNavigatorTests.swift
Tests/MediaViewerPerformanceTests/
└── SlideshowPerformanceTests.swift   # 新規: 時刻・大量一覧走査の計測
```

**Structure Decision**: 単一 Package と2つの既存テスト target を保つ。Core の値型は時刻・イベント・最新一覧から判断し、AppKit オブジェクトや実待機を持たない。App が待機 Task を1つだけ所有し、MainSplit の presentation 経路へ接続する。汎用 scheduler framework や UI テスト target は追加しない。

## Phase 0 — Research

仕様・既存コードと標準 API の一次資料を確認し [research.md](research.md) を作成。Core の一覧・識別・置換・履歴と、App の入力・動画・ペイン・全画面を読み取り専用の調査で確認した。解析指摘のうち I1 は未解決であり、実装前に操作経路の判断が必要。

## Phase 1 — Design

### 1. 対象と選択

- 自動送りは毎回 `listing.files` からメディアを最新順序で抽出する。`MediaFile.id == url`、zip は既存 `ArchiveURL` の archive/path の組を使う。
- 開始位置は選択に含まれるフォーカスメディア → 選択中メディアの表示順先頭 → 一覧先頭。1件に整理し、通常の preview-only 進入の選択補完を開始／復帰へ流用しない。
- 表示中の同じ対象では再ロードを省く選択整理経路を設ける。動画の開始・1件の tick で player を再構成しない。別対象では通常の `select` による停止・preview 世代・先読みを利用する。

### 2. 時間と入力

- 固定3秒。Core は単調時刻を入力として deadline と取消世代を管理し、App は `ContinuousClock.sleep(until:tolerance:)` の単発 Task を1つだけ持つ。
- タイムアウトは pending due にする。現在の入力 dispatch 後の commit までに受理した終了・矢印がこれを無効化する。同一処理単位の優先順位は終了 > 矢印 > due。MainActor 直列化だけを同時押下対策としない。
- App は順序付き RunLoop perform で commit を延期し、直前に未処理キーを非 dequeue で照会し、FR-123 の条件を満たす Esc／矢印の通常 dispatch を優先する（R3）。延期 callback も世代照合し、再予約を1件に制限する。
- 矢印は端・リスト左右・キー反復でも移動より先に取消と `now + 3s` を行う。期限到来後は最新フォーカスの次、なければ先頭へ1回進み、切替時刻から次の3秒を数える。遅延の追い付き連打なし。
- 上記の終了・矢印優先は FR-123 の条件で受理した入力だけに適用する。App は対象ウィンドウがキー入力先か、対象のシート・アプリモーダル・編集欄・メニュー等が入力を所有していないかを monitor と responder fallback の両方で同じ条件により判定する。不適格なキーは既存処理へ渡し、Core に stop／arrow を送らず、閉じるキーを再適用しない。
- モーダル表示中も既存 deadline で自動送りを続ける。開閉・編集開始終了・そこで処理された Esc／矢印で期限を変えず、modalPanel mode でも due の commit を行えるよう接続する。モーダル等のキーはスライドショー入力との競合に数えない。処理遅延時は最大1回だけ送り、追い付き連打をしない。Core にモーダルや一時停止の状態を追加しない。
- due と入力の両到着順を仮想イベントで検証する。App の commit 境界と待ち行列も確認し、GUI の3秒直前操作で二重移動がないことをゲートにする。

### 3. 一覧更新と閲覧先置換

- 既存の選択整理完了後に対象0件で自動終了する。残りがあれば deadline を保ち、期限まで選び直さない。
- `resetForNavigation()` の入口に同期の置換前通知を設け、UI が取消・通常表示への復帰状態を確定してから一覧を置換する。履歴専用 `onLocationEvent` を上書きしない。全画面アニメーション完了時には幅・フォーカスだけを最終適用し、古いメディアを復元しない。
- `didRenameFolder` 等の場所の付け替えでは継続する。URL の単純な差分や loading 化だけで置換と判定しない。
- 列挙・reload・検索・デコードの古い結果を世代で拒否する。同じフォルダへ戻った場合も URL 一致だけで古い reload を採用しない。

### 4. ペイン・全画面・履歴

- 通常ウィンドウの layout・focus・3ペイン幅を保存し、隠れたリストの幅を引き継ぐ。全画面からの開始では全画面化前の状態を使う。
- 全画面の通常切替は再生・実行・deadline・隠れたリスト幅に触れない。FR-123 の条件で受理した Esc を全画面解除・検索解除・due より優先して消費し、session を無効化後、必要なら全画面を解除する。モーダルや編集欄の Esc ではこの終了経路へ入らない。解除待ちの復帰情報は実行状態と分け、再入を拒否して復帰を1回だけ完了する。
- 終了時は選択を作り直さず、有効な現在の選択だけを保つ。幅は `PaneWidths.dividerPositions` で収め、window frame は戻さない。ファイルリストのみへの復帰では停止・消音する。
- `historyPresentation` は実行中に復帰先の layout を返し、形式・サイズは現在値を返す。ユーザー表示変更だけを記録し、検索結果中の記録抑止を保つ。開始／終了は履歴を追加せず、検索を終えない。

### 5. Validation and handoff

要件対応は [quickstart.md](quickstart.md) を参照。実装 Phase の検証順は `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh`。その後ユーザーへ `open .build/MediaViewer.app` と確認点を依頼する。3ペイン起動スモークと対象シナリオが未確認なら GUI タスクは未チェックのままにする。性能結果を記録し、問題がない Phase をコミットする。実装・検証後にのみ spec の反映先表に従って `specs/product/` へ反映する。

実時間計測には既存の OSSignposter 方式を使い、開始・選択 commit・矢印受理・停止のイベントだけを追加する。ファイル名やパスは含めず、Instruments で SC-034/035 の区間を確認する。

本コマンドは Phase 1 の設計で終了する。tasks 生成・ソース実装・GUI 起動は次工程。

## Complexity Tracking

憲章違反なし。要求された競合制御のため、repeating timer に代えて取消世代と pending due を持つ。単発 Task だけでは投入済みの送りと矢印／Esc の競合を防げないためであり、汎用化せず本機能の状態に限定する。
