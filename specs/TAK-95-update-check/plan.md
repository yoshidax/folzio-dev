# Implementation Plan: アップデートの確認

**Branch**: `claude/modest-darwin-quinyf` | **Date**: 2026-11-26 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/TAK-95-update-check/spec.md`

## Summary

アプリメニューに「アップデートを確認…」を足し、選んだときに GitHub の REST API で公開用リポジトリの最新の公開版を
1回問い合わせる。今の版と比べ、新しい版があれば Release ページを既定のブラウザで開けるダイアログを出す。最新・失敗の
ときもダイアログで知らせる。あわせて、初回の起動で自動の確認への同意を尋ね、同意した利用者には起動時（24 時間に1回まで）に
同じ問い合わせを行い、まだ知らせていない新しい版だけをダイアログで知らせる（最新・失敗は黙る）。設定ウインドウに切り替えの
チェックボックスを置く。ダウンロードと置き換えは行わない。憲章 原則 I を改定して許す通信をこの確認に限り、
`scripts/check-no-network.sh` の許可を同じ範囲に限って広げる。README と利用ガイドを英日で更新する。

## Technical Context

**Language/Version**: Swift 6.0（`swiftLanguageModes: [.v6]`）

**Primary Dependencies**: AppKit、Foundation（`URLSession`）。外部依存を追加しない

**Storage**: `UserDefaults` に3キー（`updates.automaticCheck`・`updates.lastAutomaticCheck`・`updates.lastNotifiedVersion`）

**Testing**: XCTest（`FolzioCoreTests`・`FolzioAppTests`）、Python の unittest（`scripts/dev/tests`）

**Target Platform**: macOS 15 以降、Apple silicon

**Project Type**: デスクトップアプリ（Swift Package）

**Performance Goals**: 問い合わせは UI のスレッドの外で行い、最長 15 秒で結果を出す（FR-427・SC-245）

**Constraints**: 通信はメニューの操作か、利用者が同意した起動時の自動の確認（24 時間に1回まで）でだけ始める。
送る情報は contracts/update-check.md の表のとおり

**Scale/Scope**: 新しいファイル 6（Core 4・App 2）と各テスト、既存のファイルの変更 約 12

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判定 | 根拠 |
|---|---|---|
| I ローカル完結・プライバシー | 改定で適合 | 下記 |
| II 体感パフォーマンス | 適合 | 通信は `async` で UI のスレッドを止めない。画像の処理・キャッシュに触れない |
| III キーボード・アクセシビリティ | 適合 | メニューバーから到達でき、`NSAlert` は Return・Esc・Tab と標準のラベルを持つ |
| IV テスト必須 | 適合 | 版の解析・比較・応答の評価の全分岐（異常系を含む）を通信なしで Core のテストで確かめる |
| V シンプルさ | 適合 | 外部依存なし。設定は1項目。起動中のタイマー・進捗のウインドウ・知らせ直しの見張りを足さない |

**表の詳細**

- **I ローカル完結・プライバシー**（根拠）: 原則 I は、ネットワークを必要とする機能の追加に「spec で明示」「ユーザーの明示的な
  操作でのみ通信を開始」「本憲章の改定」を求める。spec で明示し（FR-423・FR-424・FR-431）、メニューの操作と、初回に同意を得た
  自動の確認でだけ通信する。後者は今の文言に合わないため、この feature で憲章を 1.6.0 に改定し、「ユーザーが明示的に有効にした
  自動の処理」を許す形にする（research.md R8・R9）。画像・メタデータ・パスは送らない。ほかの全機能はオフラインで動く。
- 改定の後の再評価（Phase 1 の後）: 設計は改定後の原則 I の文言（許す通信の範囲・送る情報・自動の確認をしない）の中にある。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-95-update-check/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/update-check.md
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/FolzioCore/Update/
├── AppVersion.swift              # 版の解析と比較（新規）
├── UpdateSource.swift            # 要求と Release ページの URL（新規。API の URL のリテラルはここだけ）
├── UpdateChecker.swift           # UpdateTransport・UpdateCheckResult・UpdateCheckFailure・check（新規）
└── AutomaticUpdateCheckPolicy.swift  # 起動時の動作・24 時間・知らせる版と保存の判定（新規）
Sources/FolzioCore/Settings/SettingsStore.swift  # 3つのキーの読み書き
Sources/FolzioApp/Update/
├── URLSessionUpdateTransport.swift  # ephemeral の URLSession（新規。URLSession はここだけ）
└── UpdateCheckController.swift      # 確認中の状態、同意・結果のダイアログ、起動時の動作（新規）
Sources/FolzioApp/Settings/SettingsWindowController.swift  # 区分「アップデート」とチェックボックス
Sources/FolzioApp/App/
├── MainMenu.swift                # 項目の追加と refreshTitles
└── AppDelegate.swift             # checkForUpdates(_:)、validateMenuItem、起動時の呼び出し
Sources/FolzioLocalization/
├── TextKey.swift                 # 新しいキーと翻訳者向けの説明
└── Resources/{en,ja}.lproj/Localizable.strings
scripts/check-no-network.sh       # 許可をファイルと行の組の一覧にする
scripts/dev/tests/test_check_no_network.py
Tests/FolzioCoreTests/AppVersionTests.swift、UpdateCheckerTests.swift、AutomaticUpdateCheckPolicyTests.swift、
  SettingsStoreTests.swift（3キー）
Tests/FolzioAppTests/UpdateCheckMenuTests.swift
README.md、README.ja.md、docs/usage.md、docs/usage.ja.md
.specify/memory/constitution.md
```

**Structure Decision**: 判断のロジックは `FolzioCore/Update` に置き、通信の実体は FolzioApp の1ファイルに隔離する
（research.md R5）。About と同じく AppDelegate がメニューの動作を受け、`UpdateCheckController` に渡す。

## 主な設計

- **メニュー**: `MainMenu.install` で About の直後に `checkForUpdatesItem`（`action: #selector(AppDelegate.checkForUpdates(_:))`、
  `target = nil`、`keyEquivalent: ""`）を足し、`refreshTitles` の表に加える。
- **有効の条件**: `AppDelegate.validateMenuItem` で `updateCheckController.canCheck`（版が `AppVersion` になり、確認中でない）を返す。
- **確認**: `UpdateCheckController.check()` は `isChecking = true` にし、`Task` で `UpdateChecker.check(current:transport:)` を
  待つ。`@MainActor` に戻って `isChecking = false` にしてからダイアログを出す。ダイアログの表示と URL を開く処理は、テストで
  差し替えられるようクロージャで持つ（`ConfirmationPresenter` の `runModal` と同じ形）。
- **URL を開く**: `NSWorkspace.shared.open(UpdateSource.releasePageURL(for: latest))`。
- **起動時**: `applicationDidFinishLaunching` の `controller.showWindow(nil)` と `NSApp.activate` の後に
  `updateCheckController.performLaunchAction()` を呼ぶ。`AutomaticUpdateCheckPolicy.launchAction` に、設定・今の版・前回の時刻・
  `Date()`・`mainWindowController.canShowShortcuts` を渡し、`.askConsent` なら同意のダイアログ、`.check` なら自動の確認を始める。
  ダイアログはメインウィンドウの表示が画面に反映された後に出すよう、`DispatchQueue.main.async` で次の周回に回す。
- **自動の結果**: 結果が出た時点の `canShowShortcuts` を `automaticOutcome` に渡し、返った保存と表示に従う。
  `canPresent` は `UpdateCheckController` に注入するクロージャにし、テストで切り替える。時刻も `now` のクロージャで注入する。
- **設定ウインドウ**: 「スライドショー」の後に `sectionSpacing` を空けて見出し「アップデート」とチェックボックスを置き、
  Tab の移動順を `transitionPopup → updatesCheckbox → languagePopup` にする。`syncFromStore` と `updateLocalizedLabels` に足す。
- **検査**: `check-no-network.sh` に許可の一覧（ファイル・許す行の条件）を持たせ、`awk` の既存の2つの例外を同じ一覧の形にする。
  コメントは英語（公開用スクリプト）。

## 公開文書への影響

- README（英日）: 冒頭の「Works locally without network communication」の表記と、更新の確認の案内（FR-429）。
- 利用ガイド（英日）: 「Checking the Version」の節に「アップデートを確認…」と起動時の自動の確認・同意・設定を足す。
- 公開文書から `specs/` などの非公開のパスへリンクしない。

## Complexity Tracking

憲章の違反なし（原則 I は改定で扱う）。
