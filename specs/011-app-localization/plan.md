# Implementation Plan: 日本語・英語への国際化

> **設計レビュー待ち**: 2026-10-28 のユーザー指示により、表示言語はアプリの設定で選択・保存し、英語を初期値として即時反映する。ユーザーのレビュー（T099）後に実装へ進む。

## 言語の即時切り替えの設計

- 表示言語の設定値は安定した言語識別子として保存し、未設定・未知の値は英語とする。起動時は OS の優先言語を参照しない。
- 設定ウインドウの選択を更新すると、MainActor 上の共有状態を更新して永続化し、表示中の各画面へ変更を通知する。固定インスタンス `Localizer.shared` とグローバル `l10n` は、現在の言語を参照できる構成に改める。
- メニュー、ツールバー、各ペイン、列見出し、空状態、エラー、検索結果、設定画面、アクセシビリティを更新対象として棚卸しする。既存の表示・選択・検索・履歴・入力途中の値を維持し、操作や表示状態をリセットしない。起動後に開くメニューやダイアログも新しい言語を使う。
- 現在の `MediaFile.typeDescription` は OS 由来の種類名と `KindNames` による代替名を同じ文字列にしており、文字列だけでは切り替え対象を判別できない。種類名の由来を値で区別し、フォルダ・zip のアプリ管理の代替名だけ新しい `KindNames` で表示・種類順の比較を行う。OS 由来の名前はそのまま使う。既存の通常一覧・検索結果・zip 索引・進行中の非同期処理も同じ規則に従い、古い結果で表示を巻き戻さない。大量データの変換・並べ替えは UI スレッド外で行い、再列挙を避ける。
- 英語既定、未対応の保存値、永続化、OS の言語設定からの独立、双方向の即時切り替え、表示・入力状態の保持を自動テストと GUI 確認に追加する。日時・数値の地域書式と翻訳の欠落検出は維持する。
- String Catalog の件数を表示しない複数形は追加試作で拒否されたため、`.strings`／`.stringsdict` を使う。デバッグとリリースのビルド、英語の単数・複数、日本語、配布バンドルを検証する。
- 翻訳が欠けた場合は英語の訳を表示し、欠けを自動テストで検出する。

**Branch**: `011-app-localization` | **Date**: 2026-10-28 | **Spec**: [spec.md](spec.md)

**Input**: 本 feature の spec（FR-145〜157、US17〜20、EC-107〜116、SC-061〜069、A-87〜93）、`specs/product/overview.md` の FR-040・041、`file-list.md` の FR-012、
`file-operations.md` の FR-018、`preview.md` の FR-138、`search.md` の FR-074・082・084、`window-layout.md` の FR-002、`contracts/keyboard-and-menus.md`・`settings.md`・`app-bundle.md`。憲章 v1.2.0。

## Summary

アプリが管理する表示文言を日本語・英語の `.strings`／`.stringsdict` で持ち、アプリ設定で表示言語を選択・保存し、変更を即時反映する。初期値は英語とする。
日時・件数・倍率は表示言語と区別した地域設定で整形する。翻訳・表示言語の決定・書式・Core の値から文言への変換は、Foundation だけを使う新しいライブラリターゲット
`MediaViewerLocalization` に集める。Core は日本語の文言を返すのをやめ、表示言語に依存しない値（理由の種類）を返す。App はすべての文字列リテラルを `Localizer` 経由に置き換え、
メニューの探索を表示文言から識別子へ改める。`scripts/make-app.sh` はコンパイル済みの lproj を `.app` 本体へ入れ、Info.plist で開発言語（英語）と対応言語を OS へ示す。
訳の欠け・未使用・値の不一致、フォールバック、複数形、書式、言語の決定は `swift test` で検証する。

## Technical Context

**Language/Version**: Swift 6、`swiftLanguageModes: [.v6]`、swift-tools-version 6.0。ビルドは Swift Build（`.build/.buildSystem_debug` = `swiftbuild`）。

**Primary Dependencies**: Foundation（`Bundle`・`Locale`・`DateFormatter`・`FormatStyle`）、AppKit（App のみ）、`.strings`／`.stringsdict`。外部パッケージなし。
新しいライブラリターゲット `MediaViewerLocalization`（Foundation のみ、`MediaViewerCore` に依存）。Core は AppKit を import しない。

**Storage**: 表示言語の識別子を UserDefaults に保存する。お気に入り・履歴など既存の保存形式は変えない。

**Testing**: Swift Testing。`Tests/MediaViewerCoreTests/Localization/` に R10 の 1〜10（管理元の突き合わせ・引数・ソースの参照・コンパイル結果・フォールバック・値を含む文・複数形・書式・言語の決定・Core の値）。
Core の既存テストで日本語の文字列を比べている 53 か所は値の比較へ書き換える。GUI・VoiceOver・システム設定・配布の独立性は quickstart の手動確認（ユーザーに依頼）。

**Target Platform**: macOS 15 以降。

**Project Type**: AppKit デスクトップアプリ + Core ライブラリ、単一 Swift Package。

**Performance Goals**: 言語・書式は起動時に初期化し、言語変更時に更新する。UI スレッドで重い処理をしない。文言の取得は `Bundle` のキャッシュ済みの表の参照。
作成日の整形器は使い回す。既存の性能基準（起動 1 秒・前後切替 100ms・10,000 件で固まらない）を維持する。

**Constraints**: オフライン・ネットワーク API 不使用。Xcode プロジェクトへの移行と外部パッケージの追加をしない。Core に表示言語への依存を持ち込まない。
翻訳する言語ごとの分岐をアプリの判断ロジックに持たない（FR-156）。ウインドウとペインの最小サイズを変えない。GUI 起動はユーザーへ依頼する。

**Scale/Scope**: 翻訳単位はおよそ 250（App の文字列リテラル 205 件と Core の 58 件から重複を除き、件数の文などを加えた見込み）。対応言語 2。
変更するファイルは App 19・Core 13 と、その Core のテスト 19 ファイル。

**Resolved design questions**: 管理形式・ターゲット構成・同梱と参照・言語の決定・キーと引数・複数形・地域の書式・Core の値・識別子での探索・自動検証・配置・GUI 検証・README は research.md R1〜R13 に記録する。R1 の追加試作に基づき `.strings` と `.stringsdict` を採用する。

## Constitution Check

*Phase 0 前に評価し、Phase 1 後に再評価した。PASS は設計の適合を示し、実装・GUI 検証の完了ではない。*

| 原則・ゲート | Phase 0 前 | Phase 1 後の設計と検証方針 |
|---|---|---|
| I ローカル完結 | PASS | 翻訳は `.app` 内のリソースだけ。通信・送信・保存の追加なし。no-network チェックを維持 |
| II 性能 | PASS | 言語の変更時も UI スレッドで重い処理をしない。文言の取得は表の参照。既存の性能テストを維持 |
| III キーボード・アクセシビリティ | PASS | 操作・ショートカット・有効条件は変えない。アクセシビリティのラベル・値・ヘルプ・読み上げを表示言語で提供（FR-154）。VoiceOver を両言語で手動確認 |
| IV テスト必須 | PASS | 翻訳の欠け・未使用・値の不一致・フォールバック・複数形・書式・言語の決定・Core の値をすべて自動テスト。異常系（訳の欠け・書式に似たユーザーデータ）を含む |
| V シンプルさ | PASS（Complexity Tracking あり） | 外部依存なし。ユーザーが要求した言語設定を追加する。追加するターゲットと型は下表で正当化 |
| 技術制約・AppKit 不変条件 | PASS | Core は Foundation のみ。表示の文言は App と Localization。MainActor で UI を更新。制約は追加後に有効化し、`leading`／`trailing` で書く。split view の delegate は変えない |
| 仕様管理 | PASS | 本 feature の設計文書だけを作る。`specs/product/` への反映（spec の「反映先」）と凍結は実装と検証の後 |

## Project Structure

### Documentation (this feature)

```text
specs/011-app-localization/
├── spec.md
├── checklists/requirements.md
├── plan.md
├── research.md
├── data-model.md
├── contracts/
│   ├── localization.md      # 表示言語・翻訳の規則・地域の書式・用語対応表（product に新設する契約の草案）
│   └── app-bundle.md        # product の app-bundle.md への差分
├── quickstart.md
└── tasks.md                 # /speckit-tasks で作る
```

### Source Code (repository root)

```text
Package.swift                                  # defaultLocalization: "en"、MediaViewerLocalization ターゲット、App とテストの依存
Sources/MediaViewerLocalization/
├── Resources/{ja,en}.lproj/Localizable.strings・Localizable.stringsdict  # 管理元
├── TextKey.swift                              # 翻訳単位の一覧・引数の並び・説明
├── Localizer.swift                            # 文言の取得・フォールバック・起動時の共有インスタンス
├── LocalizationBundle.swift                   # 参照先のバンドルの決定（Bundle.main → Bundle.module）
├── DisplayLanguage.swift                      # 表示言語の決定（純粋な関数）
├── FormattingLocale.swift                     # 書式のロケール・日時・件数・割合の整形
└── CoreText.swift                             # Core の値（理由の種類）→ 文言、KindNames
Sources/MediaViewerCore/                       # 表示文言を値へ置き換える（data-model.md の表）
├── Search/SearchRoot.swift・SearchFolderInitialLocation.swift
├── Archive/ArchiveError.swift（ArchiveCorruption を追加）・InflateCursor.swift・ArchiveEntryStream.swift・ZipStructure.swift・ZipArchiveReader.swift・ArchiveFile.swift・ArchiveIndex.swift
├── Operations/NameValidation.swift・FileOperationService.swift
├── Model/MediaTypeFilter.swift・BrowserState.swift・MediaFile.swift（KindNames）
├── FileSystem/DirectoryLister.swift
└── Browser/BrowserModel.swift
Sources/MediaViewerApp/                        # 文字列リテラルを Localizer へ。メニューに識別子
├── App/MainMenu.swift・MainWindowController.swift・MainToolbarController.swift・MainSplitViewController.swift・AppDelegate.swift
├── FileList/FileContextMenu.swift・FileListViewController.swift・ListModeView.swift・ThumbnailModeView.swift
├── Tree/DirectoryTreeViewController.swift
├── Preview/PreviewViewController.swift・ImagePreviewView.swift
├── Operations/ConfirmationPresenter.swift・ConflictPrompt.swift・FileOperationCoordinator.swift
├── Search/SearchPanelController.swift
└── Settings/SettingsWindowController.swift
Tests/MediaViewerCoreTests/Localization/       # R10 の 1〜10
Tests/MediaViewerCoreTests/*.swift             # 日本語の文字列の比較を値の比較へ（19 ファイル）
Sources/FixtureKit/                            # テスト用の KindNames・訳を欠かせた一時バンドル
scripts/make-app.sh                            # lproj のコピーと存在確認、Info.plist のキー
README.md・README.ja.md                        # 対応言語・表示言語の決まり方・英訳の見直し（R13）
```

**Structure Decision**: 文言・言語・書式を `MediaViewerLocalization` に集め、App と Core の境界は「Core が値を返し、Localization が文言にする」にする。
Core に日本語の既定値を残さず、種類名だけは並べ替えに必要なため App から `KindNames` として注入する。`.app` は本体の lproj で翻訳を引き、`swift run` とテストは `Bundle.module` で引く。

## Phase 0 — Research

[research.md](research.md) に R1〜R13 の決定・根拠・代替案と、現状の調査結果（ビルドシステム・`Bundle.module` の探索順・文言と書式の棚卸し・表示文言を判断に使っている箇所）を記録した。
R1 の追加試作で件数を表示しない複数形が String Catalog で拒否されたため、`.strings` と `.stringsdict` を採用する。ユーザー報告で変更前のテスト 806 件は通過したが、新方式のビルドと GUI は未検証。

## Phase 1 — Design

1. **管理形式**（R1）: 試作の結果、`.strings` + `.stringsdict` を採用する。アプリで Debug・Release と両言語の複数形を検証する。
2. **ターゲットと参照先**（R2・R3）: `Package.swift` に `defaultLocalization: "en"` と `MediaViewerLocalization` を加える。`LocalizationBundle.resolve()` は `.app` では `Bundle.main`、
   それ以外では `Bundle.module`。表示言語（R4）を保存値から復元し、変更時は共有状態と書式のロケール（R7）を更新する。
3. **翻訳単位**（R5・R6）: `TextKey` と `.strings`／`.stringsdict` を、契約 §5 の用語対応表から作る。値は位置指定、件数は `count`／`number`。全キーに説明を付ける。
   自動検証（R10）を先に用意し、キーを足すたびに欠けを検出できるようにする。
4. **Core の値**（R8）: data-model.md の表のとおり、表示文言を値に置き換える。`KindNames` を `BrowserModel` から `DirectoryLister`・`ArchiveIndex` へ渡す。
   既存テストの日本語の比較を値の比較へ書き換え、文言は Localization のテストで両言語を確かめる。「複製」と「両方残す」の名前の規則は変えない（EC-113）。
5. **App の文言**（FR-146・152・154）: 19 ファイルの文字列リテラルを `Localizer` に置き換える。状態で変わる項目名（ツールバーを表示／隠す、ゴミ箱に入れる／お気に入りから削除、並べ替えの昇順／降順）、
   ツールチップ、パレットの名前、アクセシビリティのラベル・ヘルプ・値・読み上げを含める。置き換えの後、App と Core に日本語の文字列リテラルが残っていないこと（コメント・ログ・テストを除く）を確かめる。
6. **識別子での探索**（R9）: メインメニューの各メニューと並べ替えのサブメニューに識別子を付け、`title == "表示"`・`"並べ替え"` の探索を置き換える。
7. **地域の書式**（R7、FR-151）: 作成日・件数・倍率を `Localizer` の整形に置き換える。切り替え間隔は変えない。
8. **配置**（R11、FR-153）: 設定ウインドウ・検索シート・列見出し・空状態・ツリーの見出しを英語の長さで確かめ、固定幅を固有の幅と折り返しへ改める。触る制約は `leading`／`trailing`。
   動的な文は末尾を切り詰め、全文をツールチップとアクセシビリティに入れる。
9. **バンドル**（契約 app-bundle.md）: `scripts/make-app.sh` に lproj のコピーと存在確認、Info.plist の `CFBundleDevelopmentRegion`・`CFBundleLocalizations` を加える。
10. **README**（R13）: 両言語の README に同じ変更を入れ、`scripts/check-readme-sync.sh master` で確かめる。
11. **検証と引き渡し**: [data-model.md](data-model.md)・[contracts/localization.md](contracts/localization.md)・[contracts/app-bundle.md](contracts/app-bundle.md)・[quickstart.md](quickstart.md) を tasks 生成の入力にする。
    各 Phase の終わりは build → test → no-network・readme-sync → make-app → ユーザーの起動スモークの順。GUI 未確認のタスクは未チェックのまま残す。

### Constitution Check（Phase 1 後の再評価）

上表のとおり設計上は各原則に適合する。新しい依存はなく、ユーザーが要求した表示言語の設定と保存項目を追加する。追加する複雑さは下表のとおり。

## Complexity Tracking

憲章違反はない。原則 V に照らし、追加する構造と採らなかった単純な案を記録する。

| 追加する複雑さ | 必要な理由 | 採らなかった単純な案と理由 |
|---|---|---|
| ライブラリターゲット `MediaViewerLocalization` | 翻訳・言語の決定・書式を `swift test` で検証する（FR-157）。Core を表示言語から独立させる | App に置く: 実行ファイルはテストしにくい。Core に置く: 判断の層が全 UI の文言とリソースを抱える |
| `TextKey`（翻訳単位の一覧と引数の並び） | 欠け・未使用・値の不一致をテストで検出する（FR-157）。同じ日本語で意味の違う項目を分ける | 日本語をキーにした `String(localized:)`: 一覧をテストで得られず、抽出は Xcode だけ |
| Core の理由の値（`ArchiveCorruption`・`NameValidationFailure`・`OperationFailureReason`・`PreviewFailure`・`ListingFailure`）と `KindNames` の注入 | Core の値と保存を表示言語から独立させる（FR-148）。Core のテストを言語に依存させない | Core が Localization に依存して文言を返す: Core のテストに表示言語の指定が要り、判断と表示が混ざる |
| 書式のロケールの組み立て（R7） | 表示言語と地域を区別し、語は表示言語に、並びは地域に従わせる（FR-151） | 常に `Locale.current`: 対応外の言語の利用者で月名などの語が混在しうる |
| メニューの識別子 | 訳した文言を判断に使わない（FR-148）。英語の UI で並べ替えのメニューが入らない不具合を防ぐ | 訳した文言で探す: 訳を直すと壊れる |
