# Implementation Plan: Folzio について（About）ダイアログ

**Branch**: `claude/great-lamport-eudxq0` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-45-about-dialog/spec.md` / [TAK-45](https://linear.app/takyoshida/issue/TAK-45)

## Summary

アプリメニューの先頭に「Folzio について」を追加し、アプリ全体で最大 1 つの独立した非モーダルウィンドウ（閉じるボタンのみ）を開く。内容はアプリアイコン・「Folzio」・バージョン（`CFBundleShortVersionString`。取得不能なら行ごと省略）・公開リポジトリの URL リンク。バージョン値の整形と固定 URL は Core の純粋な関数・定数に置いて Swift Testing で検証し、ウィンドウとリンクの描画・入力は `FolzioApp` に置く。ウィンドウの所有と終了処理は設定ウインドウ（`SettingsWindowController`）の既存パターンを踏襲する。

本資料は設計レビュー用。`docs_private/cloud-agent-workflow.md` の「承認の前に実装しない」に従い、設計の承認後に tasks.md の実装を始める。

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: Foundation、AppKit、既存 FolzioCore / FolzioLocalization。外部依存なし。

**Storage**: 永続化なし。位置・状態を保存しない（FR-243）。

**Testing**: Swift Testing。Core にバージョン整形と固定 URL（`Tests/FolzioCoreTests`）、`FolzioAppTests` にウィンドウの体裁・1 枚だけ・リンク動作（URL を開く処理は差し替え可能にする）、既存のカタログ整合性検査（`Tests/FolzioCoreTests/Localization`）で両言語の揃いを確認。GUI は quickstart.md で実機確認。

**Target Platform**: macOS 15 以降。Cloud Linux では Swift コマンドも GUI も実行しない。

**Project Type**: Swift Package のデスクトップアプリ。

**Performance Goals**: 固定の少数の部品のみ。デコード・列挙・ファイル操作なし。メニュー選択からウィンドウ表示まで体感で即時。

**Constraints**: Core は AppKit を import しない。ウィンドウ操作は MainActor。`URLSession` などのネットワーク API を使わず、URL は `NSWorkspace.shared.open` に渡すだけ（`scripts/check-no-network.sh` を通す）。Auto Layout は addSubview 後に有効化。`NSSplitViewDelegate` には触れない。

**Scale/Scope**: ウィンドウ 1 種・文言 5 件前後・Core の関数 1 つ。

## Constitution Check

| 原則 | Phase 0 前 / Phase 1 後の判断 |
|---|---|
| I ローカル完結・プライバシー | PASS / PASS。アプリは通信しない。ブラウザ起動は OS への URL の受け渡しで、閲覧・操作の情報は送らない（A-146、research.md R3）。ネットワーク API は使わず `check-no-network.sh` で確認する。 |
| II 体感パフォーマンス | PASS / PASS。既存の描画・デコード経路に変更なし。 |
| III キーボードファースト & アクセシビリティ | PASS / PASS。リンクは Tab で到達し Space/Return で開ける。⌘W で閉じる。VoiceOver にアイコン・版・リンクを提供。 |
| IV テスト必須 | PASS / PASS。Core のバージョン整形と文言の揃いを自動検証。GUI は別途記録し、CI と保守者の確認前は完了扱いにしない。 |
| V シンプルさ（YAGNI） | PASS / PASS。標準 About パネルの置き換えに必要な最小限。ビルド番号・ヘルプ・設定項目・ショートカットなし。 |
| 仕様管理 | PASS / PASS。新しい feature のみ作成。`specs/product/` への反映は実装・検証後。ID は FR-238 / SC-118 / EC-166 / A-146 / US45 から採番（反映時に master と突き合わせる）。 |

## Project Structure

### Documentation (this feature)

```text
specs/TAK-45-about-dialog/
├── spec.md
├── plan.md                      # 本ファイル
├── research.md
├── data-model.md
├── contracts/about-dialog.md
├── quickstart.md
├── checklists/requirements.md
└── tasks.md                     # /speckit-tasks で作成
```

### Source Code (repository root)

```text
Sources/FolzioCore/About/AboutInfo.swift                # 新規: 公開リポジトリ URL と、版の値の整形（取得不能は nil）
Sources/FolzioLocalization/TextKey.swift                # 追加: menu.app.about / about.window / about.version / about.icon / about.link
Sources/FolzioLocalization/Resources/{en,ja}.lproj/Localizable.strings
Sources/FolzioApp/About/AboutWindowController.swift     # 新規: ウィンドウ・リンク・言語追随
Sources/FolzioApp/App/AppDelegate.swift                 # showAbout(_:)・所有・メイン終了時に閉じる
Sources/FolzioApp/App/MainMenu.swift                    # 項目の追加と翻訳バインド
Tests/FolzioCoreTests/AboutInfoTests.swift              # 新規
Tests/FolzioAppTests/AboutWindowTests.swift             # 新規
specs/product/ ...                                      # 実装・検証後に反映（反映先は spec.md）
```

**Structure Decision**: 既存の `Settings/` と `Shortcuts/` と同じく機能別ディレクトリ `About/` を App 側に置き、判断の部分だけ Core に分ける。

## 設計

1. **メニュー**: `MainMenu.install` で、アプリメニューの先頭に `showAbout(_:)`（`target = nil`、ショートカットなし）と区切り線を追加し、既存の「設定…」の前に並べる。`bindings` に `(aboutItem, .menuAppAbout)` を足し、言語切り替えで `refreshTitles` が更新する。
2. **所有**: `AppDelegate` が `aboutWindowController` を 1 つ保持する（`showSettings` と同じ）。選ぶたびに、無ければ作り、あれば `makeKeyAndOrderFront` で前面へ出す。位置は保つ。`mainWindowWillClose` で設定ウインドウとともに閉じる（FR-243）。閉じたあとの再表示は同じ controller を再利用する。
3. **ウィンドウ**: `NSWindow(styleMask: [.titled, .closable])`、`isReleasedWhenClosed = false`、`titleVisibility = .hidden`、最小化・ズームのボタンを非表示にし、`window.title` には「Folzio について」を入れておく（アクセシビリティとウィンドウ名のため。画面には出ない。FR-239）。リサイズ不可。初期位置は画面中央。コンテンツは縦の `NSStackView`（中央揃え）。
4. **部品**: アイコンは `NSApp.applicationIconImage`（バンドルのアイコンと同じ。FR-043）。アプリ名は固定文字列「Folzio」（翻訳しない。FR-147）。バージョンは `AboutInfo.displayVersion(...)` が nil でなければ `about.version`（「Version %@」／「バージョン %@」）で表示し、nil なら行そのものを作らない（スタックから外す）。
5. **リンク**: `NSButton`（枠なし）に URL の文字列を `.link` 色・下線の属性文字列で設定し、カーソルをポインターに、アクセシビリティの role を `.link` にする。`canBecomeKeyView = true`（システムのキーボードナビゲーション設定に関わらず Tab で止まる）。アクションは注入された `openURL` クロージャ（既定は `NSWorkspace.shared.open`）を呼び、戻り値の成否は無視する（EC-166）。
6. **言語追随**: `LanguageChangeObserver` で、`window.title`、バージョン行、アクセシビリティの文言を更新する。更新後にウィンドウの内容サイズを再計算し、位置は保つ。
7. **Core**: `AboutInfo.repositoryURL`（固定）と `AboutInfo.displayVersion(from: Any?) -> String?`（文字列でなければ nil、前後の空白を除いて空なら nil）。呼び出し側が `Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")` を渡す。

## 検証

[quickstart.md](quickstart.md) のとおり。Cloud の静的検査、macOS CI の `swift build` / `swift test`、保守者のローカル確認（起動スモークと GUI）を分けて記録する。

## Complexity Tracking

憲章の違反なし。
