# Implementation Plan: 検索起点フォルダの GUI 選択

**Branch**: `010-search-folder-picker` | **Date**: 2026-10-27 | **Spec**: [spec.md](spec.md)

**Input**: 本 feature の spec、`specs/product/search.md` の FR-081・082・085・086・EC-34、`overview.md` の FR-003・040・041・042、`directory-tree.md` の FR-065、`zip.md` の FR-069、`contracts/keyboard-and-menus.md`・`contracts/settings.md`。憲章 v1.2.0。`009-folder-search` は統合済みだが product 未反映の差分も参照し、検索対象・結果・保存の扱いを維持する。

## Summary

検索シートの起点欄の近くに「選択…」を加え、macOS 標準のフォルダ選択パネル（`NSOpenPanel`）を子シートとして開く。直接入力と既存の検索開始経路を保つ。確定では起点欄だけを更新して古い起点エラーを消し、取消では入力とエラーを保つ。選択パネルを閉じた後に非同期で再検証し、失敗時は検索シートに理由を出して選び直せる。開く・確定・取消では検索を開始・停止せず、既存検索の結果更新も続ける。

標準パネルを使うため、独自のフォルダ一覧・場所一覧・親移動・表示切替・独自キー処理は実装しない。隠し項目は標準パネルの動作（既定は非表示、⌘⇧. で切替可能）に従い、隠しフォルダも選択できる。パッケージは `treatsFilePackagesAsDirectories = false` と `canChooseFiles = false` により選択・内部移動できない。判断は Core の入力状態と初期位置の解決だけに置き、表示とパネルは App に置く。

## Technical Context

**Language/Version**: Swift 6、`swiftLanguageModes: [.v6]`。

**Primary Dependencies**: Foundation、Swift Concurrency、AppKit の `NSOpenPanel`・`NSSearchField`・`NSTextField`・`NSButton`。既存 `SearchRoot`。外部依存・新 target なし。Core は AppKit を import しない。

**Storage**: シートのメモリ内だけ。選択 URL と入力元は検索シートの終了時に破棄。UserDefaults のキー、起点履歴、ブックマークは追加しない。選択操作で `view.lastFolderPath` を変えない。

**Testing**: Swift Testing。入力元、初期候補の順序、入力世代、確定後の再検証を Core で検証。`SearchRoot.validate` の既存回帰を維持する。標準パネルの外観・標準キーボード・VoiceOver・既存検索の継続は `.app` の手動確認を必須とする。

**Target Platform**: macOS 15 以降。

**Project Type**: AppKit デスクトップアプリ + Core ライブラリ、単一 Swift Package。

**Performance Goals**: 初期位置の解決と確定後の検証は非同期で行い、UI スレッドで列挙・メタデータ・権限確認をしない。標準パネルは OS が管理する。既存の 10,000 件検索・操作停止 100ms 未満・検索 3 秒以内を維持する。

**Constraints**: オフライン、ネットワーク API 不使用、AppKit のみ、ファイル変更なし。GUI の表示制限を直接入力の検証へ追加しない。確定後も検索時に再検証する。GUI 起動はユーザーへ依頼する。

**Scale/Scope**: 親にボタン1つと標準パネル1画面。単一選択のみ。複数起点、新規フォルダ作成、最近使った場所、独自のフォルダ一覧は追加しない。

**Resolved design questions**: 未解決事項なし。部品、入力元、初期候補、非同期検証、シート所有関係、テスト方法、既定値と合格条件は research.md R1〜R9 で決定した。

## Constitution Check

*Phase 0 前に評価し、Phase 1 後に再評価した。PASS は設計適合を示し、実装・GUI 検証の完了ではない。*

| 原則・ゲート | Phase 0 前 | Phase 1 後の設計と検証方針 |
|---|---|---|
| I ローカル完結 | PASS | ローカル読み取りのみ。通信・送信・ファイル変更・保存なし。no-network チェックを維持 |
| II 性能 | PASS | 初期位置・確定検証は非同期。標準パネルは OS 管理。既存検索を止めず、大量件数の性能基準を維持 |
| III キーボード・アクセシビリティ | PASS | 親の Tab 順序・Space、標準パネルの標準キー・VoiceOver、パネル後のフォーカス復帰を契約化 |
| IV テスト必須 | PASS | 入力元・初期候補・世代・確定後検証を単体検証。異常系と遅い完了を含める。標準パネルの GUI は手動確認 |
| V シンプルさ | PASS | 標準パネルを使い、独自のファイルブラウザ・状態機械・依存を追加しない |
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
└── tasks.md
```

### Source Code (repository root)

```text
Sources/MediaViewerCore/Search/
├── SearchRoot.swift               # 既存 parse/validate の意味を維持
├── SearchRootInput.swift          # 入力元と親の入力世代の状態
└── SearchFolderInitialLocation.swift # 初期位置の候補順と検証
Sources/MediaViewerApp/Search/
└── SearchPanelController.swift    # 標準検索欄・パス欄・選択…・NSOpenPanel
Tests/MediaViewerCoreTests/
├── SearchRootInputTests.swift     # 入力元・初期位置解決・確定後検証の世代
├── SearchFolderInitialLocationTests.swift # 候補順・全滅・隠し/パッケージ
├── SearchRootTests.swift          # 既存直接入力の回帰
└── BrowserModelSearchTests.swift  # 既存開始・置換の回帰
Sources/FixtureKit/FixtureSets.swift # searchFolderPicker(in:) を追加
```

**Structure Decision**: `SearchRoot.validate` を初期位置と確定後の検証に再利用する。GUI 専用の到達可否・一覧状態・独自パネルは作らない。標準パネルの設定と表示は `SearchPanelController` に置き、Core は候補順と入力世代だけを扱う。

## Phase 0 — Research

[research.md](research.md) に決定・根拠・代替案を記録した。Apple の Open/Save パネルのガイド、`NSOpenPanel`、`showsHiddenFiles`、`treatsFilePackagesAsDirectories` の公開仕様を確認した。未解決事項・仕様の確認待ちはない。

## Phase 1 — Design

1. **入力元**: `.typed(String)` / `.picked(URL)` を保持する。起点欄のユーザー編集だけで直接入力へ戻し、同じ文字列へ戻しても直接入力とする。キーワード編集・パネルの取消では変えない。検索と初期位置は同じ解釈を使う。
2. **初期位置**: 現在入力 → シート開始時の既定値 → ホームの順に `SearchRoot.validate` で確認し、最初の有効なフォルダを `NSOpenPanel.directoryURL` にする。隠しフォルダは許可し、パッケージ・読み取り不能は次候補へ進む。全滅なら親に理由を示し、パネルを開かない。
   既定値は既存の `MainSplitViewController.showSearch` とキー契約に合わせ、一覧に表示中（検索結果中は検索前、zip 内は zip を含む）のフォルダを開始時に捕捉する。EC-102 の一覧 F・ツリー V では F。F が無効なら F の候補を飛ばしてホームへ進み、V は候補に追加しない。取消でも親の F を保持する。
3. **標準パネル**: `NSOpenPanel` を検索シートの親ウインドウに `beginSheetModal(for:)` で表示する。`canChooseFiles = false`、`canChooseDirectories = true`、`allowsMultipleSelection = false`、`canCreateDirectories = false`、`resolvesAliases = true`、`treatsFilePackagesAsDirectories = false`、`showsHiddenFiles = false`。タイトル・メッセージ・選択ボタン名を設定する。
4. **非同期処理**: 初期位置の解決は選択操作の入力世代・依頼世代を捕捉し、編集・親終了・検索受理で失効させる。パネル表示中の親操作を防御する。確定後は選択 URL を捕捉して非同期検証し、編集・親終了・検索受理で古い完了を採用しない。失敗時はパネルを閉じたまま親シートに理由を表示し、起点欄・キーワードを保持する。
5. **シートとキー**: 検索 controller 自身が標準パネルを開き、`runModal` を使わない。標準パネル表示中は親を操作できない。パネル後の Return・Esc は標準パネルが処理し、親へ伝播しない。終了後は親の「選択…」へフォーカスを戻す。親の初期キーワード全選択は初回だけにする。
6. **検索との接続**: 選択パネルは URL / 取消だけを返し、`BrowserModel`・`onSearch` を呼ばない。親は確定成功時だけ欄を置換して古い起点エラーを消す。検索ボタンで `SearchRoot.validate` が通ったときだけ既存 `onSearch` を呼ぶ。履歴・最後のフォルダの操作は追加しない。
7. **検証と引渡し**: [data-model.md](data-model.md)、[UI 契約](contracts/search-folder-picker.md)、[quickstart.md](quickstart.md) を tasks 生成の入力にする。実装 Phase は build → test → no-network → make-app → ユーザーの起動スモークの順。GUI 未確認のタスクは未チェックに保つ。
   SC-058 の5ケースは検索開始の成立・検索バーの起点・既知の一致結果で合格を判定する。全走査の完了は要求せず、照合後の解除を許す。EC-102 から開く既定値・初期位置・取消の回帰も手動確認する。

### Constitution Check（Phase 1 後の再評価）

上表のとおり全項目 PASS。入力元は末尾空白の保持、初期位置は標準パネルの開始位置、世代は非同期の競合対策に必要である。新しい依存・保存項目はない。

## Complexity Tracking

憲章違反はない。標準パネルの採用により、独自のフォルダブラウザ・選択状態・表示制限の実装を持たない。

| 追加する複雑さ | 必要な理由 | 採らなかった単純な案と理由 |
|---|---|---|
| 入力元と入力世代 | GUI パスの空白保持、非同期の初期位置・確定検証で古い結果を採用しない | 文字列だけでは入力元を区別できず、完了順の競合を防げない |
| 初期位置の候補解決 | 現在入力・既定・ホームの優先順を保ち、無効な候補でパネルを開かない | 現在入力だけでは空・無効時にパネルが開けない |
