# Data Model: 日本語・英語への国際化

**Feature**: `011-app-localization` | **Plan**: [plan.md](plan.md) | **Research**: [research.md](research.md)

表示言語を UserDefaults に言語識別子で保存する。お気に入り・履歴など既存の保存形式は変えない（FR-145・148）。
以下は起動中のメモリ上の値と、Core と表示の層の間で受け渡す値である。名前は設計上の仮の名前で、実装時に既存の命名に合わせてよい。

## MediaViewerLocalization の値

### DisplayLanguage（表示言語）

| 項目 | 内容 |
|---|---|
| `code` | 言語のコード（`ja`・`en`）。参照先のバンドルの lproj の名前と同じ |

- 起動時は保存された対応言語を読み、未設定・未知の値は英語を使う。OS の優先言語を参照しない。
- 設定で言語を選ぶと保存し、共有状態の変更を各画面に通知して即時反映する（EC-108）。

### FormattingLocale（書式のロケール）

| 項目 | 内容 |
|---|---|
| `locale` | 日時・件数・割合の整形に使う `Locale` |

- 起動時と表示言語の変更時に決める（R7）。`Locale.current` の言語が表示言語と同じなら `Locale.current`、違えば言語だけを表示言語に置き換えたロケール（地域・`hourCycle`・
  `firstDayOfWeek`・暦・数字の体系は `Locale.current` から引き継ぐ）
- テストでは任意のロケールを直接与える

### TextKey（翻訳単位）

| 項目 | 内容 |
|---|---|
| `rawValue` | 翻訳のキー（`<領域>.<項目>[.<変化>]`、英小文字と `.`） |
| `arguments` | 引数の並び。`[TextArgument]` |
| `comment` | 翻訳者向けの説明（使われる場所と各値の意味） |

- `CaseIterable`。全ケースが `.strings` または `.stringsdict` に両言語の訳を持つ（FR-157、R10）
- 領域の接頭辞: `menu`（メニューバー）、`context`（右クリックメニュー）、`toolbar`、`settings`、`list`（列見出し・並べ替え）、`tree`、`search`、`empty`（空状態）、
  `preview`、`dialog`（確認モーダル・衝突ダイアログ・お気に入りの削除・拡張子の確認）、`error`（Core の値の文言・操作の失敗）、`a11y`（画面に出ないアクセシビリティの文言）、`kind`（種類名）

### TextArgument（引数の種類）

| ケース | 書式指定 | 内容 |
|---|---|---|
| `text` | `%n$@` | ファイル名・パス・キーワード・OS の理由・件数の句など。文字どおりに入れる（EC-109） |
| `count` | `%n$lld` + `%m$@` | 件数。複数形の判定に使う整数と、`FormattingLocale` で整形した文字列の2つを渡す（R6）。訳によっては件数を表示せず、語形の判定にだけ使う（確認の見出しの Copy this item?／Copy these items?） |
| `number` | `%n$@` | 語形が変わらないラベルの値としての件数（「成功: 3」「ほか 2 件」）。整形済みの文字列だけを渡す |

- 書式指定は位置指定に限る。訳ごとに値の順を変えてよい（FR-149）
- 引数の数と種類が `arguments` と合わない訳は、自動検証で検出する（R10-2）

### Localizer（文言と書式の窓口）

| 項目 | 内容 |
|---|---|
| `language` | `DisplayLanguage` |
| `table` | 表示言語の lproj のバンドル |
| `fallbackTable` | 英語（開発言語）の lproj のバンドル |
| `locale` | `FormattingLocale.locale` |

| 操作 | 内容 |
|---|---|
| `text(_ key: TextKey, _ args: …)` | `table` で引き、無ければ `fallbackTable` の訳を使う（EC-110）。引数を位置指定で入れる |
| `count(_ n: Int)` | 件数の整形（桁区切りは地域） |
| `percent(_ percentage: Int)` | 倍率の整形（記号の位置・間の空白は地域） |
| `dateTime(_ date: Date?)` | 作成日の整形（日付は中程度、時刻は短い形式）。`nil` は `--`（EC-116） |
| `kindNames` | Core へ渡す `KindNames` |
| `text(for: <Core の値>)` | 下の「Core から受け取る値」を文言にする |

- 現在の共有値は設定変更時に差し替える。テストでは言語・バンドル・ロケールを与えて作る
- 参照先のバンドルは `LocalizationBundle.resolve()` で決める（R3）: `Bundle.main` の `en.lproj` に表がある → `Bundle.main`、無い → `Bundle.module`
- `Sendable` に保つ。整形器（`DateFormatter`）を保持する場合は MainActor で使うか、呼び出しごとに作る

## Core の値（表示言語に依存しない）

| 型 | ケース・項目 | 文言のキーの対応 |
|---|---|---|
| `SearchRootError`（既存） | `empty`・`notAbsolute`・`notFound`・`notAFolder`・`accessDenied`。`message` を削除 | `error.searchRoot.*` |
| `SearchFolderInitialLocation` の失敗 | `noUsableFolder` | `error.searchRoot.noUsableFolder` |
| `ArchiveError`（既存） | `message` を削除。`.corrupted(String)` → `.corrupted(ArchiveCorruption)` | `error.zip.*` |
| `ArchiveCorruption`（新規） | 現行の `.corrupted("…")` の文言1つにつき1ケース（展開の開始不可・圧縮データの破損・データの途中終了・圧縮データの途中終了・ヘッダの破損・位置の不正・中央ディレクトリが大きすぎる・場所の不正・項目が見つからない・サイズの不一致・データがファイルの外・読み込みの中止・読み出しの失敗・読み込み不可） | `error.zip.corrupted.*` |
| `NameValidation`（既存） | `.invalid(reason: String)` → `.invalid(NameValidationFailure)` | — |
| `NameValidationFailure`（新規） | `empty`・`forbiddenCharacter`・`leadingDot`・`duplicate`・`becomesPackage` | `error.name.*` |
| `OperationFailure`（既存） | `reason: String` → `reason: OperationFailureReason` | — |
| `OperationFailureReason`（新規） | `noDestination`・`destinationNotFound`・`sourceNotFound`・`intoItself`・`invalidName(NameValidationFailure)`・`sameNameExists`・`sameNameAtDestination`・`trashExistingFailed(systemReason: String)` | `error.operation.*`。`systemReason` は OS の文言のまま値として入れる（EC-111） |
| `MediaTypeFilter`（既存） | 空状態の文を返す API を、表示中のフィルタ（画像のみ・動画のみ）を返す形にする | `empty.filter.images`・`empty.filter.videos` |
| `ListingState.failed`（既存） | `String` → `ListingFailure.folderNotFound` | `empty.folderNotFound` |
| `PreviewState.unavailable`（既存） | `reason: String` → `reason: PreviewFailure` | `preview.failure.*` |
| `PreviewFailure`（新規） | `unreadable`・`unsupportedFormat`・`corrupted`・`archive(ArchiveError)` | `preview.failure.*`・`error.zip.*` |
| `KindNames`（新規） | `folder: String`・`zipArchive: String` | `kind.folder`・`kind.zipArchive` |

- `KindNames` は App が `Localizer.kindNames` を `BrowserModel` の作成時に渡し、`DirectoryLister`・`ArchiveIndex` へ伝える。Core に日本語の既定値を持たせない。
  テストは `FixtureKit` の固定値を使う
- `OperationFailure` の比較・集計（失敗の一覧）は値で行う。表示は App が `Localizer.text(for:)` で行う
- 既存の回帰テストのうち日本語の文字列を比べている 53 か所は、値の比較へ書き換える。文言の確認は Localization のテストへ移す

## 変わらないもの

- 「複製」の「名前 2」と衝突時の「両方残す」で作るファイル名の規則（FR-018、EC-113）。表示言語・`KindNames` を参照しない
- 並べ替えの列と方向・種類フィルタ・表示形式・ペインの表示・お気に入り・履歴の保存値（識別子と raw value）
- 検索の一致判定（`SearchPattern` の `locale: nil` の折りたたみ）と zip の名前の文字コードの判定（FR-074・082）
- 名前・場所の並べ替えの比較（`localizedStandardCompare`）。表示言語・地域で一部の文字の順が変わりうる（EC-112）
