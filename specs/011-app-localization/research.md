# Research: 日本語・英語への国際化

**Feature**: `011-app-localization` | **Date**: 2026-10-28 | **Plan**: [plan.md](plan.md)

各項目は「Decision / Rationale / Alternatives considered」で記録する。追加試作の結果、管理形式は R1 のとおり `.strings` と `.stringsdict` を採用する。

## 調査で確かめた現状

- `swift build` は Swift Build（`.build/.buildSystem_debug` が `swiftbuild`）で動いている。生成物は `.build/out/Products/{Debug,Release}`
  （`.build/debug`・`.build/release` はそのシンボリックリンク）。リソースバンドルは `my_img_viewer_<Target>.bundle/Contents/Resources/` の形で作られる
- Swift Build が生成する `Bundle.module`（`.build/out/Intermediates.noindex/.../DerivedSources/resource_bundle_accessor.swift`）は、
  `Bundle.main.resourceURL` → `Bundle(for:).resourceURL` → `Bundle.main.bundleURL` の順に `<名前>.bundle` を探し、見つからなければ `fatalError` する。
  ビルドディレクトリの絶対パスへのフォールバックはない（従来のビルドシステムの accessor にはある）
- `Package.swift` は `defaultLocalization` を持たない。リソースを持つのは `FixtureKit` だけ
- `scripts/make-app.sh` は実行ファイルとアイコンだけを `.app` に入れ、Info.plist に `CFBundleDevelopmentRegion`・`CFBundleLocalizations` がない
- 表示文言の棚卸し（日本語の文字列リテラル）: App 205 件（19 ファイル）、Core 58 件（13 ファイル）。Core のテストのうち 53 か所が日本語の理由・種類名を比べている
- 表示文言を判断に使っている箇所: `NSApp.mainMenu` から `submenu?.title == "表示"` で表示メニューを探す（`MainSplitViewController`・`FileListViewController`・`ListModeView`）、
  `title == "並べ替え"` で並べ替えのサブメニューを探す（`ListModeView`）。FR-148 に反するため識別子へ置き換える
- 日時・数値・割合の表示箇所: 作成日（`ListModeView` の `DateFormatter`、`.medium` / `.short`、ロケール未指定）、件数（検索バー・コピーの項目名・確認モーダル・衝突ダイアログ・
  操作の失敗の「ほか N 件」）、倍率（`ImagePreviewView.percentText` の `"\(percentage)%"`）。切り替え間隔は `NumberFormatter` を使っていない。ファイルサイズの表示はない（A-93）
- 並べ替え（`Sorting.swift`）は `localizedStandardCompare`、検索の一致判定（`SearchPattern`）は `locale: nil` の折りたたみで、どちらも変更不要（EC-112）

## R1. 翻訳の管理形式

- **Decision**: `Resources/{ja,en}.lproj/Localizable.strings` と `Localizable.stringsdict` を管理元とする。両言語のキー、書式、複数形と説明を自動検証する。
- **試作**: 件数を表示する String Catalog の通常の複数形は以前の Debug・Release 試作で成功した。その後、件数を表示しない `Copy this item?`／`Copy these items?` の複数形を `xcstringstool compile` が「Plural variation requires referencing the number in the string」として拒否した。
- **Rationale**: 仕様は件数を表示せず複数形だけ変える見出しを求める。`.stringsdict` は数を判定に使用して表示しない文を表現でき、呼び出し側に言語別の分岐を置かずに済む。
- **Alternatives considered**: String Catalog で単数・複数を別キーに分ける: 言語別の語形選択をアプリ側に広げる。ソースに訳を直接書く: 翻訳リソースと文言が分散する。
- **検証状況**: ユーザー報告では従来実装の `swift test` 806 件が通過。ビルドの出力は未確認。新しい即時切り替えの実装・Debug／Release・配布バンドルは未検証。

## R2. ターゲットの構成

- **Decision**: Foundation だけを使うライブラリターゲット `MediaViewerLocalization` を追加する。翻訳リソース・翻訳単位の一覧・表示言語の決定・書式・
  Core の値から文言への変換をここに置く。依存は `MediaViewerLocalization → MediaViewerCore`、`MediaViewerApp → MediaViewerLocalization, MediaViewerCore`。
  `Package.swift` に `defaultLocalization: "en"` を加える。自動テストは既存の `MediaViewerCoreTests` に `MediaViewerLocalization` への依存を足し、
  `Tests/MediaViewerCoreTests/Localization/` に置く（AGENTS.md のテストの置き場所とフィルタを変えない）。
- **Rationale**: 実行ファイルのターゲット（`MediaViewerApp`）はテストから扱いにくく、FR-157 の自動検証を `swift test` で行うにはライブラリに置く必要がある。
  Core に置くと、判断ロジックの層が UI の全文言とリソースを持つことになる。Core は表示言語に依存しない値を返し（R8）、文言への変換を 1 か所に集める。
- **Alternatives considered**:
  - Core に String Catalog を置く: ターゲットは増えないが、Core が表示の層を抱え、Core の値が表示言語に依存する
  - App に置き、`@testable import` で実行ファイルをテストする: `main.swift` を持つ AppKit の実行ファイルをテストへリンクすることになり、テストが AppKit に依存する
  - 新しいテストターゲット `MediaViewerLocalizationTests`: AGENTS.md のテストの置き場所の記述と `--filter` の案内を変える必要がある

## R3. `.app` への同梱と翻訳の参照先

- **Decision**:
  - `scripts/make-app.sh` は、`swift build -c release` が作る `my_img_viewer_MediaViewerLocalization.bundle/Contents/Resources/` の `*.lproj` を、
    `.app/Contents/Resources/` へそのままコピーする。`ja.lproj`・`en.lproj` に `Localizable.strings`（と複数形の表）が無ければ、`.app` を残さず非ゼロで終了する
  - Info.plist に `CFBundleDevelopmentRegion = en` と `CFBundleLocalizations = [ja, en]` を加える（FR-145 の「OS へ示す」）
  - 翻訳の参照先（`LocalizationBundle`）は次の順に決める。`Bundle.main` の `en.lproj` に `Localizable` の表がある（`.app`）→ `Bundle.main`。
    無ければ（`swift run`・テスト）→ `MediaViewerLocalization` の `Bundle.module`。`.app` では `Bundle.module` を評価しない
- **Rationale**:
  - 本体の `Contents/Resources/*.lproj` は、システム設定の「アプリケーション」の言語の一覧と、OS が提供する部品（標準パネル・テキスト編集のメニュー）の言語の選択に使われる
    従来どおりの構成で、OS の部品は OS が選ぶ言語で表示され、アプリが選択した言語と異なる場合がある（EC-111）
  - `.app` の参照はすべてバンドル内の相対位置で決まり、ビルドディレクトリを移しても変わらない（FR-155、SC-066）。リソースバンドルを `.app` の最上位に置く案と違い、コード署名を壊さない
  - `swift run` では実行ファイルの隣にリソースバンドルがあり、Swift Build の `Bundle.module` が `Bundle.main.bundleURL` から見つける。テストでも既存の `FixtureKit` と同じく `Bundle.module` で見つかる
- **Alternatives considered**:
  - リソースバンドルを丸ごと `.app/Contents/Resources/` に入れ、`Bundle.module` だけで引く: 本体に lproj が無いため、OS の言語の一覧と部品の言語の選択が
    `CFBundleLocalizations` だけに頼ることになる。参照先が見つからないと `fatalError` で起動しない
  - 訳の既定値（日本語）をソースにも持ち、バンドルが無くても日本語を出す: 日本語の訳が String Catalog とソースの2か所に分かれる
- **残る危険と対策**: `.app` の lproj が欠けると内部キーが出る。make-app.sh の存在確認と、quickstart の lproj の確認（Q2）で防ぐ

## R4. 表示言語の決定と即時切り替え

- **Decision**: アプリの設定で対応言語の識別子を選び、UserDefaults に保存する。保存値がない・未知のときは英語。OS の優先言語・アプリごとの言語には依存しない。
  起動時に復元し、起動中の変更は MainActor の共有状態に反映し、各画面に通知する。書式ロケールは地域を維持して表示言語だけ更新する。
- **Rationale**: 表示言語を明示的に選び、再起動なしに切り替えるというユーザーの変更指示に従う。
- **Alternatives considered**: OS の優先言語を使う、再起動時だけ反映する: いずれも変更後の要件に反する。

## R5. 翻訳単位のキーと引数

- **Decision**:
  - キーは `<領域>.<項目>[.<変化>]` の形の英小文字の識別子（例: `menu.file.open`、`menu.edit.trash`、`dialog.conflict.replace`、`search.bar.searching`）。
    一覧は `TextKey`（`String` の raw value・`CaseIterable`）で持ち、各キーに引数の並び（`TextArgument` の配列: 文字列・件数）と翻訳者向けの説明を持たせる。説明は `TextKey` と翻訳リソースのコメントに書く
  - 値を含む文は文全体を1つのキーにし、値は位置指定（`%1$@`・`%2$@`）で渡す（FR-149）。ユーザーデータは必ず引数として渡し、書式文字列として扱わない（EC-109）
  - 箇条書きの各行（確認モーダルの「・名前」・「ほか N 件」・「操作先: パス」）は行ごとに1つのキーとし、改行で並べる。件数の句（「3 件」）を検索バーの文の値として入れるのは、
    完結した句を値として埋め込むものとし、文の断片の連結とは扱わない
  - 取得は `Localizer.text(_:_:)` を通す。表示言語の lproj で引き、無ければ英語の lproj の訳を代わりに使う（EC-110）。引数の数と種類はデバッグビルドで検査する
- **Rationale**: 日本語の文言をキーにすると、同じ日本語で意味の違う項目（「移動」メニューと「移動しますか？」など）を分けられず、日本語を直すとキーが変わる。
  `TextKey` を正とすると、翻訳リソースとの突き合わせ（欠け・未使用・引数の不一致）をテストで行える（R10）
- **Alternatives considered**: `String(localized:)` の文字列リテラル（キー = 日本語）を各所に書く: 抽出は Xcode でしか動かず、キーの一覧をテストで得られない

## R6. 複数形と件数の数値書式

- **Decision**: 件数を含む文は、引数を「複数形の判定に使う整数（`%1$lld`）」と「地域の書式で整形した件数の文字列（`%2$@`）」の2つにする。
  `.stringsdict` の英語は `one`／`other`、日本語は `other` だけを持ち、表示には `%2$@` を使う。件数の整形は `Localizer.count(_:)`（R7）。
  0件で専用の文を持つ箇所（検索の「該当する項目はありません」、種類フィルタの空状態）は、件数の文より先に分けて扱う（EC-114）。
  件数を「成功: 3」のようなラベルの値として出し、どの言語でも語形が変わらない文（「成功 N 件 / 失敗 M 件」「衝突する項目: N 件」「対象: N 件」「ほか N 件」）は、
  整形済みの件数の文字列だけを渡す（`number` の引数。data-model.md）。どちらにするかは用語対応表（contracts/localization.md）の英語の文で決まる。
- **Rationale**: `%lld` は桁区切りを付けないため、`1,000`／`1.000` を出せない。整数で複数形の規則を選び、整形済みの文字列を表示する形は、
  複数形の規則（Foundation が言語ごとに持つ CLDR の規則）に任せられ、アプリに言語の分岐を持たない（FR-150・156）
- **Alternatives considered**: 件数を `%lld` のまま出す: 桁区切りが地域に従わない（FR-151 違反）。件数ごとに文を分ける（`if count == 1`）: 言語の分岐になる

## R7. 日時・数値・割合の地域書式

- **Decision**:
  - 書式のロケールを起動時と表示言語の変更時に決める。`Locale.current` の言語が表示言語と同じならそのまま使う（地域・24時間表示・ユーザーの書式の上書きを保つ）。
    違えば `Locale.Components(locale: .current)` の言語だけを表示言語に置き換えたロケールを作り、`hourCycle`・`firstDayOfWeek`・暦・数字の体系は `Locale.current` から引き継ぐ
  - 作成日: `DateFormatter`（`dateStyle = .medium`、`timeStyle = .short`、`locale` = 書式のロケール）。取得できない日付は従来どおり `--`（EC-116）
  - 件数: `IntegerFormatStyle`（`.number.locale(書式のロケール)`）
  - 倍率: `percentage / 100` を `.percent.locale(書式のロケール)` で整形し、アクセシビリティの値と読み上げに使う（FR-138）
  - 切り替え間隔: 従来どおり桁区切りなしの整数の文字列。入力の解釈（`SlideshowIntervalInput`）は変えない（US19-AS5）
  - 書式の関数はロケールを引数に取り、テストでは `en_JP`・`ja_US`・`de_DE`・`en_US@hours=h23` などを直接与える。
    表示言語と地域の組み合わせの期待値は、実際の組み合わせ（`ja_JP`＋英語、`en_US`＋日本語、`de_DE`＋英語）を `FormattingLocale.resolve` に通したロケールで判定する。
    言語を置き換えたロケールの既定の書式（`en_JP` の12／24時間表示など）は ICU の版に左右されるため、引き継ぐ値は `Locale.Components(locale:)` が値を持たない項目も
    `Locale.current` の実効値（`hourCycle`・`firstDayOfWeek` など）で設定する
- **Rationale**: 「並び・区切り・時刻表記は地域、語は表示言語」（spec の Clarifications）を、OS 標準の書式に任せて実現する。`Locale.current` の言語がアプリの表示言語と
  一致しない場合（アプリが対応していない言語を優先しているときなど）にだけ言語を差し替え、それ以外はユーザーの設定をそのまま使う
- **Alternatives considered**:
  - 常に `Locale.current`: 対応外の言語を優先言語にしたユーザー（英語の UI に落ちる）で、月名が別の言語になりうる
  - 常に `Locale(identifier: 表示言語 + "_" + 地域)`: 「日付と時刻」の書式の上書き（24時間表示など）を失う
  - `Locale.autoupdatingCurrent`: 起動中に書式が変わり、文言の混在の原因になる（EC-108）

## R8. Core が返す表示文言の扱い

- **Decision**: Core は表示言語に依存しない値を返し、文言への変換は `MediaViewerLocalization` に置く。

  | 現在（Core） | 変更後の値 |
  |---|---|
  | `SearchRootError.message` | `message` を削除。`SearchRootError` をそのまま返す |
  | `SearchFolderInitialLocation` の「利用できるフォルダが見つかりません」 | 理由の値（`noUsableFolder`） |
  | `ArchiveError.message`、`.corrupted(String)` | `message` を削除。`.corrupted(ArchiveCorruption)`（ヘッダの破損・位置の不正・データの途中終了・サイズの不一致・中止など、現行の文言1つにつき1ケース） |
  | `NameValidation.invalid(reason: String)` | `.invalid(NameValidationFailure)`（空・使えない文字・先頭の「.」・同名あり・パッケージになる） |
  | `OperationFailure(reason: String)` | `OperationFailure(OperationFailureReason)`。名前の検証は `NameValidationFailure` を再利用し、ゴミ箱の失敗は OS の理由を `systemReason: String` として持つ（EC-111） |
  | `MediaTypeFilter` の空状態の文 | 表示中のフィルタの値を返し、文言は変換側で選ぶ |
  | `ListingState.failed(String)` | `.failed(ListingFailure)`（`folderNotFound`） |
  | `PreviewState.unavailable(name:reason: String)` | `reason` を `PreviewFailure`（読み込めない・形式に非対応・壊れている・zip のエラー）にする |
  | `typeDescription` の「フォルダ」「ZIP アーカイブ」 | App が起動時に `KindNames`（フォルダ・zip ファイルの種類名）を Core へ渡し、`DirectoryLister`・`ArchiveIndex` が使う。OS が返す種類名（`localizedTypeDescription`）はそのまま使う |

- **Rationale**: Core の判断と保存は表示言語から独立する（FR-148）。Core のテストは日本語の文字列ではなく値を比べるようになり、文言の正しさは変換側のテストで両言語を確かめる。
  種類名は「種類」の並べ替え（`Sorting`）で表示中の名前を比べる必要があるため、値ではなく表示名を注入する（EC-112）
- **Alternatives considered**: Core が `MediaViewerLocalization` に依存して文言を返す: Core の値が表示言語に依存し、Core のテストに表示言語の指定が要る

## R9. 表示文言を判断に使わない

- **Decision**: メインメニューの各メニューと並べ替えのサブメニューに `NSUserInterfaceItemIdentifier`（例: `menu.view`・`menu.view.sort`）を付け、探索は識別子で行う。
  並べ替えの列・ツールバーの項目・保存キーは既存の識別子のまま。訳した文言は表示（`title`・`label`・`toolTip`・アクセシビリティ）にだけ使う。
- **Rationale**: 英語の UI では `"表示"` のメニューが見つからず、並べ替えのメニューと表示形式の項目が入らなくなる（FR-148）
- **Alternatives considered**: 探索に訳した文言を使う（`Localizer.text(.menuView)` と比べる）: 表示の文言を判断に使うことになり、訳を直すと壊れる

## R10. 自動検証（`swift test` に含める）

- **Decision**: `Tests/MediaViewerCoreTests/Localization/` に次のテストを置く。
  1. **管理元の突き合わせ**: リポジトリの lproj の `.strings`・`.stringsdict` を読み、`TextKey.allCases` と比べる。
     キーの欠け・`TextKey` に無いキー（未使用）・言語ごとの訳の欠け・複数形の `other` の欠け・英語の `one` の欠けを検出する
  2. **引数の突き合わせ**: 各訳の書式指定（位置・種類。複数形の各形を含む）が `TextKey` の引数の並びと一致すること
  3. **ソースの参照**: `TextKey` の各ケースが `Sources/MediaViewerApp` または `Sources/MediaViewerLocalization`（`TextKey` の定義を除く）から参照されていること
  4. **コンパイル結果の取得**: `Bundle.module` の `ja.lproj`・`en.lproj` から全キーを引き、キーそのもの・空文字・置換されていない `%` を返さないこと
  5. **フォールバック**: 日本語の訳を欠かせた一時バンドル（`FixtureKit` で作る）で、英語の訳が返ること
  6. **値を含む文**: ファイル名・キーワードに `%@`・`%d`・`{0}`・右から左へ書く文字を含めても文字どおりに入ること（EC-109）
  7. **複数形**: 件数を含む全キーについて、0・1・2・1000 件を両言語で整形し、英語の単数・複数と桁区切りが正しいこと（SC-064）
  8. **書式**: `ja_JP`＋英語・`en_US`＋日本語・`de_DE`＋英語を `FormattingLocale.resolve` に通したロケールと 24 時間表示の指定で、作成日・件数・倍率が地域の書式になり、
     月名などの語が表示言語になること（SC-063 の自動化できる部分）
  9. **表示言語の決定**: 未設定・未知の保存値は英語、選択値の保存・復元、OS 言語からの独立、両方向の変更で期待した言語になること
  10. **Core の値の変換**: R8 の各値（すべてのケース）が両言語で空でない文言になること。`KindNames` を変えても「複製」と「両方残す」で作る名前が変わらないこと（EC-113）
- **Rationale**: FR-157 の「`swift test` に含め、ゲートの手順を増やさない」に従う。管理元（R1）とコンパイル結果（R3）の両方を確かめ、どちらの欠けも検出する
- **Alternatives considered**: シェルスクリプトで検証する: Phase の検証ゲートの手順が増える（spec の Clarifications で否定）

## R11. 配置と右から左へ書く言語への備え

- **Decision**: 固定幅で文字を収めている箇所（設定ウインドウの行・検索シート・列の既定幅）を棚卸しし、ラベルは固有の幅と折り返し（`preferredMaxLayoutWidth`・`lineBreakMode`）で収める。
  設定ウインドウと検索シートは内容に合わせて大きさを決め、確認モーダルと衝突ダイアログは `NSAlert` の自動の大きさに任せる。本変更で触る制約は `leading`／`trailing` で書き、
  `left`／`right` を使わない（FR-153）。ユーザーデータを含む動的な文（検索バー・ツリーの名前）は末尾を省略記号で切り詰め、全文を `toolTip` とアクセシビリティの値に入れる（EC-115）。
  ウインドウとペインの最小サイズ（`minimumThickness` 160 / 240 / 320pt）は変えない。
- **Rationale**: 英語の文言は日本語より長いことが多い。AppKit の自動の大きさと折り返しに任せ、固定の数値を増やさない
- **Alternatives considered**: 言語ごとに幅を持つ: FR-156 に反する

## R12. GUI 検証の方法

- **Decision**: アプリの設定で英語・日本語を選んで即時反映、状態維持、再起動後の復元を確かめる。OS の言語を変えても選択が影響されないことを確かめる。地域書式は `-AppleLocale` などで確認する。
  GUI の起動と目視はユーザーに依頼する（AGENTS.md）。手順は [quickstart.md](quickstart.md)。
- **Rationale**: 実際に使用する設定操作と即時反映を検証する。

## R13. README

- **Decision**: `README.md` と `README.ja.md` に、対応言語・表示言語の決まり方・設定の場所（アプリの設定ウインドウ）を同じ構成で加える。
  `README.md` の「UI は日本語のみ」の記述を削り、UI の文言の英訳を [contracts/localization.md](contracts/localization.md) の用語対応表に合わせる。
  英訳の後に日本語の表示名を括弧で添える書き方は、英語の UI と同じ名前になった項目では外す（A-92）。両方を同じコミットで直し、`scripts/check-readme-sync.sh master` で確かめる。
