# Contract: 表示言語・翻訳・地域の書式

要件は [overview.md](../overview.md) および本契約の FR-145〜157、EC-107〜116 を参照。

## 1. 表示言語

| 項目 | 契約 |
|---|---|
| 対応言語 | 日本語（`ja`）・英語（`en`） |
| 開発言語（最終フォールバック） | 英語。Info.plist の `CFBundleDevelopmentRegion = en` と `Package.swift` の `defaultLocalization: "en"` |
| 決め方 | アプリの設定で選んだ言語。未設定・不正な保存値は英語。macOS の言語設定・優先言語には依存しない（FR-145、EC-107） |
| 決める時 | 起動時に保存値を復元し、アプリ設定で変更したら即時反映する。地域設定の変更は遅くとも次回起動時に反映する（EC-108） |
| 保存 | 安定した言語識別子をアプリの設定に保存する |
| 切り替えの手段 | アプリの設定ウインドウで日本語・英語から選ぶ |
| OS が提供する文言 | 種類名・OS が返すエラーの理由・標準パネル・動画コントロール・テキスト編集のメニュー・ウインドウメニューなどが AppKit で自動で入る項目は OS の翻訳のまま。言語は OS が決める（EC-111） |

期待する表示言語（SC-062）:

| 状況 | 表示言語 |
|---|---|
| 保存値なし・未知の保存値 | 英語 |
| 設定で日本語を選択 | 日本語に即時変更し保存 |
| 設定で英語を選択 | 英語に即時変更し保存 |
| 保存した後に再起動 | 保存した言語 |
| OS の言語を変更 | アプリ設定で選んだ言語を維持 |

## 2. 翻訳の対象と対象外

- **対象**（FR-146）: アプリが管理し画面に表示する文言すべて。メニューバー・右クリックメニュー・ツールバー（項目名・パレットの名前・ツールチップ）・設定ウインドウ・
  ショートカット一覧（タイトル・目的別見出し・説明・条件）・列見出しと並べ替え・ツリーの固定の行（「お気に入り」）とツールチップ・検索シートと検索バー・空状態・プレビューのエラー・確認モーダル・衝突ダイアログ・お気に入りの削除の確認・
  拡張子の変更の確認・操作の失敗・名前の検証・zip のエラー・Core の値の文言・種類名のフォールバック・アクセシビリティのラベル・値・ヘルプ・読み上げ
- **翻訳・変形しない**（FR-147）: ファイル名・フォルダ名・パス・お気に入りの表示名・検索キーワード・zip の中の名前・アプリ名「Folzio」・キーボードショートカットの表記・
  OS が返す種類名と理由
- **表示言語に依存させない**（FR-148）: ログ・内部識別子・表示言語自体を除く保存キーと値・履歴・メニューやツールバーの探索（識別子で行う）・作成するファイル名（「名前 2」「両方残す」）・検索の一致判定
- 切り替え後、アプリが管理する文言に表示言語以外の言語を混在させない。表示中の状態と入力内容を保持する

## 3. 翻訳単位の書き方

| 規則 | 内容 |
|---|---|
| キー | `<領域>.<項目>[.<変化>]`（英小文字と `.`）。領域は `TextKey` の接頭辞 |
| 管理元 | `Sources/FolzioLocalization/Resources/{ja,en}.lproj/Localizable.strings` と `Localizable.stringsdict` |
| 説明 | 全キーに、使われる場所と各値の意味を書く（FR-149） |
| 値 | 位置指定（`%1$@`・`%2$@`）で入れる。訳ごとに順を変えてよい。ユーザーデータは必ず値として入れ、書式として解釈しない（EC-109） |
| 文の単位 | 値を含む文は文全体を1つのキーにする。断片をつないで文を作らない。箇条書きの各行は1行1キーで、改行で並べる。完結した件数の句を値として入れてよい |
| 件数 | 文法上の数が変わる文は `count`（複数形の判定と整形済みの文字列）、ラベルの値として出す件数は `number`（整形済みの文字列） |
| 複数形 | 英語は `one`・`other`、日本語は `other`。0 件は `other`。0 件の専用の文がある箇所はそれを使う（EC-114） |
| 欠けたとき | 英語の訳を出す。内部キー・空欄を出さない（EC-110）。欠けは `swift test` で検出する（FR-157） |
| 英語の書き方 | macOS の Finder・標準アプリに合わせる。メニュー項目・ボタン・チェックボックス以外の見出しは各語の頭文字を大文字（Title Case）、ダイアログやパネルを開く項目は末尾に「…」、
  チェックボックス・説明文・エラーの理由は文頭だけを大文字（Sentence case）。名前の引用は “ ” |
| 日本語 | 既存の日本語の文言を保つ。件数の桁区切り（`1,000 件`）と日時の地域の書式だけが変わりうる（FR-152、SC-067） |

## 4. 地域の書式

| 対象 | 書式 | 語 |
|---|---|---|
| リスト形式の「作成日」 | 日付は中程度・時刻は短い形式。並び・区切り・12／24時間表示は地域設定（と「日付と時刻」の設定）。取得できないときは `--` | 月名などは表示言語 |
| 件数（検索バー・コピー・確認モーダル・衝突ダイアログ・操作の失敗） | 桁区切りは地域設定 | — |
| 倍率のアクセシビリティの値と読み上げ（FR-138） | 割合の書式（記号の位置・空白）は地域設定 | — |
| 設定の切り替え間隔 | 桁区切りなしの整数。入力の解釈（半角・全角の数字、1〜3600）は従来どおり | — |

期待する例（SC-063）:

| 表示言語 / 地域 | 作成日の例（2026-10-28 15:04） | 1234 件 | 125% |
|---|---|---|---|
| 英語 / 日本 | 日本の並び（年・月・日）と24時間表示。月名を出す場合は英語 | `1,234` | `125%` |
| 日本語 / 米国 | 米国の並び（月・日・年）と12時間表示。午前・午後などの語は日本語 | `1,234` | `125%` |
| 英語 / ドイツ | ドイツの並び（日・月・年）と24時間表示。月名は英語 | `1.234` | `125 %` |

例の正確な文字列は OS（ICU）の版で変わりうる。合否は「並び・区切り・時刻表記が地域に、語が表示言語に従う」ことで判定する。

## 5. 用語対応表（英語の表示名の正本）

日本語は既存仕様の表示名。`{名前}`・`{N}` は値。英語の最終確認はユーザーが行う（A-88）。表にない文言は、実装時の棚卸しで同じ規則（§3）に従って加え、
この表に追記する。

### メニューバー

| メニュー | 日本語 | 英語 |
|---|---|---|
| アプリ | Folzio について | About Folzio |
| アプリ | 設定… | Settings… |
| アプリ | 終了 | Quit Folzio |
| — | ファイル | File |
| ファイル | 新規フォルダ | New Folder |
| ファイル | 開く | Open |
| ファイル | 中を表示 | Show Contents |
| ファイル | 上の階層へ | Enclosing Folder |
| ファイル | Finder に表示 | Show in Finder |
| ファイル | お気に入りに追加 | Add to Favorites |
| ファイル | 検索… | Find… |
| ファイル | ショートカット一覧… | Keyboard Shortcuts… |
| ファイル | 閉じる | Close |
| ファイル・編集 | ゴミ箱に入れる | Move to Trash |
| ファイル・編集（ツリーでお気に入りを選択中） | お気に入りから削除 | Remove from Favorites |
| — | 編集 | Edit |
| 編集 | 取り消す | Undo |
| 編集 | やり直す | Redo |
| 編集 | カット | Cut |
| 編集 | コピー | Copy |
| 編集 | ペースト | Paste |
| 編集 | 移動ペースト | Move Item Here |
| 編集 | パス名をコピー | Copy as Pathname |
| 編集 | 複製 | Duplicate |
| 編集 | 名前を変更 | Rename |
| 編集 | すべてを選択 | Select All |
| — | 表示 | View |
| 表示 | ツールバーを表示 / ツールバーを隠す | Show Toolbar / Hide Toolbar |
| 表示 | フルスクリーン | Full Screen |
| 表示 | 拡大 | Zoom In |
| 表示 | 縮小 | Zoom Out |
| 表示 | 表示領域に合わせる | Zoom to Fit |
| 表示 | スライドショーを開始 | Start Slideshow |
| 表示 | ファイルリストのみ表示 | Show File List Only |
| 表示 | プレビューのみ表示 | Show Preview Only |
| 表示 | ディレクトリツリーへフォーカス | Focus Directory Tree |
| 表示 | ファイルリストへフォーカス | Focus File List |
| 表示 | プレビューへフォーカス | Focus Preview |
| 表示 | お気に入りへ移動 | Go to Favorites |
| 表示 | サムネイル | as Thumbnails |
| 表示 | リスト | as List |
| 表示 | サムネイルを拡大 | Larger Thumbnails |
| 表示 | サムネイルを縮小 | Smaller Thumbnails |
| 表示 | 画像のみ表示 | Show Images Only |
| 表示 | 動画のみ表示 | Show Videos Only |
| 表示 | zipファイルを表示 | Show Zip Files |
| 表示 | 並べ替え | Sort By |
| 表示 > 並べ替え | 名前 / 作成日 / 種類 / 場所 | Name / Date Created / Kind / Location |
| 表示 > 並べ替え（選択中の列） | {列}（昇順） / {列}（降順） | {列} (Ascending) / {列} (Descending) |
| — | 移動 | Go |
| 移動 | 戻る | Back |
| 移動 | 進む | Forward |

### ショートカット一覧（FR-206）

ウィンドウタイトルは「ショートカット一覧」/「Keyboard Shortcuts」。
キーの記号表記と安定した操作IDを変えず、言語の変更で見出し・説明・条件・読み上げ文言を更新する。
先頭可視項目を保持し、ウィンドウの位置・サイズを作り直さない。

| 日本語の区分 | 英語の区分 |
|---|---|
| ペインと表示 | Panes and View |
| フォルダと履歴 | Folders and History |
| 選択とファイル操作 | Selection and Files |
| 検索 | Search |
| 画像 | Images |
| 動画とスライドショー | Video and Slideshow |
| アプリとウィンドウ | App and Windows |

各操作の掲載範囲と条件は [keyboard-and-menus.md](keyboard-and-menus.md) の「ショートカット一覧」を参照する。

### About ダイアログ（FR-244）

| 用途 | 日本語 | 英語 |
|---|---|---|
| メニュー項目 | Folzio について | About Folzio |
| ウィンドウ名（画面には出さず、アクセシビリティに使う） | Folzio について | About Folzio |
| バージョン行（`%@` はバージョン番号） | バージョン %@ | Version %@ |
| アイコンの説明 | Folzio のアイコン | Folzio app icon |
| リンクのヘルプ | Folzio のリポジトリを既定の Web ブラウザで開きます | Opens the Folzio repository in your default web browser |

アプリ名「Folzio」と URL・バージョンの数値は翻訳しない（FR-147）。表示中の言語の切り替えで、バージョン行・ウィンドウ名・アイコンの説明・リンクのヘルプ・メニュー項目を即時更新する。

### 右クリックメニュー

| 場所 | 日本語 | 英語 |
|---|---|---|
| ファイルリスト（1件） | "{名前}" をコピー | Copy “{名前}” |
| ファイルリスト（複数） | {N} 項目をコピー | Copy {N} Item / Copy {N} Items（`count`） |
| ファイルリスト | コピー・ペースト・移動ペースト・パス名をコピー・複製・名前を変更・ゴミ箱に入れる・開く・中を表示・上の階層へ・Finder に表示 | メニューバーと同じ |
| ツリー | ここにペースト | Paste Here |
| ツリー | ここに移動ペースト | Move Item Here |
| ツリー | お気に入りに追加・お気に入りから削除・Finder に表示・パス名をコピー・ゴミ箱に入れる・名前を変更・新規フォルダ | メニューバーと同じ |
| ファイルリスト（背景） | 新規フォルダ・ペースト・移動ペースト・Finder に表示 | メニューバーと同じ |

### ツールバー

| 項目 | 日本語（名前・ツールチップ） | 英語 |
|---|---|---|
| 履歴のグループ | 履歴 / 戻る / 進む | Back/Forward / Back / Forward |
| ペインのグループ | ペイン / ファイルリストのみ表示 / プレビューのみ表示 | Panes / Show File List Only / Show Preview Only |
| スライドショー | スライドショーを開始 / スライドショーを開始（⇧⌘S） | Start Slideshow / Start Slideshow (⇧⌘S) |
| 拡大・縮小のグループ | 拡大・縮小 / 拡大（⌘+） / 表示領域に合わせる（⌘0） / 縮小（⌘-） | Zoom / Zoom In (⌘+) / Zoom to Fit (⌘0) / Zoom Out (⌘-) |
| 種類のグループ | 種類 / 画像のみ表示 / 動画のみ表示 | Media Type / Show Images Only / Show Videos Only |
| zip | zipファイルを表示 | Show Zip Files |
| 表示形式のグループ | 表示形式 / サムネイル / リスト | View / Thumbnails / List |
| サイズ | サイズ / サムネイルのサイズ（⌃⌘. / ⌃⌘,） | Size / Thumbnail Size (⌃⌘. / ⌃⌘,) |

### 設定ウインドウ

| 日本語 | 英語 |
|---|---|
| 設定（ウインドウ名） | Settings |
| 言語 | Language |
| 英語 / 日本語（言語の選択肢。各言語の名称は常にその言語で表す） | English / 日本語 |
| 動画 | Video |
| 動画を自動再生する | Play videos automatically |
| 動画をループ再生する | Loop videos |
| ファイル操作 | File Operations |
| コピー・ゴミ箱に入れる・お気に入りから削除する前に確認する | Confirm before copying, moving to the Trash, or removing from Favorites |
| 名前の変更・移動と、ツリーのフォルダをゴミ箱に入れる操作は、この設定に関わらず常に確認します（確認の補足説明。アクセシビリティのヘルプにも使う） | Renaming, moving, and moving folders in the directory tree to the Trash are always confirmed, regardless of this setting |
| スライドショー | Slideshow |
| 切り替え間隔 / 秒 | Interval / seconds |
| 切り替え間隔（秒）（アクセシビリティ） | Interval (seconds) |
| 最後まで表示したら先頭から繰り返す | Repeat from the beginning after the last item |
| 切り替え効果 | Transition |
| なし / クロスフェード / スライド / ズーム | None / Crossfade / Slide / Zoom |

### ファイルリスト・ツリー・プレビュー

| 場所 | 日本語 | 英語 |
|---|---|---|
| 列見出し | 名前 / 作成日 / 種類 / 場所 | Name / Date Created / Kind / Location |
| ツリーの列 | フォルダ | Folders |
| ツリーの見出し | お気に入り | Favorites |
| ツリーのツールチップ | アクセスできません / 見つかりません | Not accessible / Not found |
| 空状態 | 読み込み中… / 検索中… | Loading… / Searching… |
| 空状態 | 対応するメディアファイルがありません | No supported media files |
| 空状態 | 該当する項目はありません | No matching items |
| 空状態 | アクセスできません | Can’t access this folder |
| 空状態 | フォルダが見つかりません | Folder not found |
| 空状態（種類フィルタ） | 画像のみ表示中: 該当するファイルはありません / 動画のみ表示中: 該当するファイルはありません | Showing images only: No matching files / Showing videos only: No matching files |
| プレビュー | 表示するメディアファイルがありません | No media file to display |
| プレビュー | 読み込み中… | Loading… |
| プレビュー | 表示できません\n{理由} | Can’t display\n{理由} |
| プレビューの理由 | ファイルを読み込めません / 対応していない形式です / ファイルが壊れています / アニメーションを表示できません | Can’t read the file / Unsupported format / The file is damaged / Can’t display the animation |
| 種類名のフォールバック | フォルダ / ZIP アーカイブ | Folder / ZIP archive |
| サムネイルの画像（アクセシビリティ） | サムネイル | Thumbnail |
| ツリーの名前の編集欄（アクセシビリティ） | お気に入りの名前 / フォルダの名前 | Favorite name / Folder name |
| 新規フォルダの既定名（作成時の表示言語で決め、作成後に言語を変えても名前は変えない） | 名称未設定フォルダ | untitled folder |

### 検索

| 場所 | 日本語 | 英語 |
|---|---|---|
| シート | 検索キーワード（ラベル・プレースホルダ・アクセシビリティ） | Keyword |
| シート | 検索起点ディレクトリ（ラベル・アクセシビリティ） | Search In |
| シート | 選択… / 標準のフォルダ選択パネルを開きます（ヘルプ） | Choose… / Opens the standard folder selection panel |
| シート | キャンセル / 検索 | Cancel / Search |
| シート | エラー（アクセシビリティ） | Error |
| 選択パネル | 検索起点フォルダを選択（タイトル） / 検索起点にするフォルダを選択してください。（メッセージ） / 選択（ボタン） | Choose a Folder to Search / Choose the folder to search in. / Choose |
| シートの理由 | フォルダ選択パネルを開けませんでした | Couldn’t open the folder selection panel |
| 起点の検証 | 検索起点ディレクトリを入力してください | Enter a folder to search in |
| 起点の検証 | / または ~ で始まるパスを入力してください | Enter a path that begins with / or ~ |
| 起点の検証 | フォルダが見つかりません / フォルダではありません / フォルダを読み取れません | Folder not found / Not a folder / Can’t read the folder |
| 起点の検証 | 利用できるフォルダが見つかりません | No available folder was found |
| 検索バー（完了） | 「{キーワード}」の検索結果 — {フォルダ名} — {件数の句} | Results for “{キーワード}” — {フォルダ名} — {件数の句} |
| 検索バー（検索中） | 「{キーワード}」の検索結果 — {フォルダ名} — {件数の句} 検索中… | Results for “{キーワード}” — {フォルダ名} — {件数の句} Searching… |
| 件数の句 | {N} 件 | {N} item / {N} items（`count`） |
| 件数の句（上限で打ち切り） | {全件} 件中 {表示} 件を表示 | Showing {表示} of {全件} item / items（`count` は全件） |

### 確認モーダル・ダイアログ

| 場所 | 日本語 | 英語 |
|---|---|---|
| 確認の見出し（コピー・移動） | コピーしますか？ / 移動しますか？ | Copy this item? / Copy these items?、Move this item? / Move these items?（`count`。件数は語形の判定にだけ使い、表示しない。日本語は件数で変わらない） |
| 確認の見出し（名前の変更・ゴミ箱） | 名前を変更しますか？ / ゴミ箱に入れますか？ | Rename this item? / Move to the Trash? |
| 確認の本文 | 対象: {N} 件 | Items: {N}（`number`） |
| 確認の本文 | ・{名前} | • {名前} |
| 確認の本文 | ほか {N} 件 | and {N} more（`number`） |
| 確認の本文 | フォルダは中身ごとゴミ箱に入ります | Folders are moved to the Trash with their contents |
| 確認の本文 | フォルダは中身ごと操作します | Folders are processed with their contents |
| 確認の本文 | 操作先: {パス} / 場所: {パス} | Destination: {パス} / Location: {パス} |
| 確認のボタン | 実行 / キャンセル | Continue / Cancel |
| 確認のチェックボックス | 今後この確認を表示しない | Don’t ask again |
| お気に入りの削除 | お気に入りから削除しますか？ | Remove from Favorites? |
| お気に入りの削除 | 対象: {名前} / 場所: {パス} / 実際のフォルダは変更されません | Item: {名前} / Location: {パス} / The folder itself won’t be changed |
| お気に入りの削除のボタン | 削除 / キャンセル | Remove / Cancel |
| 衝突 | 同じ名前の項目があります | An item with the same name already exists |
| 衝突 | 衝突する項目: {N} 件 / ・{名前} / ほか {N} 件 / 操作先: {パス} | Conflicting items: {N} / • {名前} / and {N} more / Destination: {パス} |
| 衝突のボタン | 置き換える / 両方残す / 中止 | Replace / Keep Both / Stop |
| 衝突のチェックボックス | 残りすべてに適用 | Apply to all |
| 拡張子の変更 | 拡張子が変わります | Change the extension? |
| 拡張子の変更 | 「{名前}」の拡張子を「{拡張子}」に変更します。続けますか？ | Are you sure you want to change the extension of “{名前}” to “.{拡張子}”? |
| 拡張子の変更のボタン | 変更 / キャンセル | Change / Cancel |
| 名前の変更の失敗 | 名前を変更できません | Can’t rename the item |
| 操作の失敗 | 操作を完了できませんでした | The operation couldn’t be completed |
| 操作の失敗 | 成功 {N} 件 / 失敗 {M} 件 | Succeeded: {N} / Failed: {M}（`number`） |
| 操作の失敗 | {名前}: {理由} / ほか {N} 件 | {名前}: {理由} / and {N} more |
| ダイアログの共通 | OK | OK |

### 名前の検証・ファイル操作・zip の理由

| 日本語 | 英語 |
|---|---|
| 名前を入力してください | Enter a name |
| 名前に「/」または「:」は使用できません | Names can’t contain “/” or “:” |
| 名前の先頭に「.」は使用できません | Names can’t begin with “.” |
| 同じ名前の項目がすでに存在します | An item with this name already exists |
| この名前にするとフォルダがパッケージとして扱われ、表示されなくなります | With this name, the folder would be treated as a package and would no longer be shown |
| 操作先のフォルダが指定されていません / 操作先のフォルダが見つかりません | No destination folder is specified / The destination folder can’t be found |
| 対象のファイルが見つかりません | The item can’t be found |
| フォルダを自分自身またはその配下へ移動・コピーすることはできません | A folder can’t be moved or copied into itself or one of its subfolders |
| 同じ名前の項目があるため中止しました / 操作先に同じ名前の項目があるため中止しました | Stopped because an item with the same name exists / Stopped because an item with the same name exists at the destination |
| 既存の項目をゴミ箱へ移動できませんでした: {OS の理由} | Couldn’t move the existing item to the Trash: {OS の理由} |
| zip を開けません: {理由} | Can’t open the zip file: {理由} |
| zip ファイルが見つかりません / アクセスできません / zip ファイルとして読めません / 分割された zip には対応していません | The zip file can’t be found / Access denied / Not a readable zip file / Split zip archives aren’t supported |
| 暗号化されているため表示できません / 対応していない圧縮方式です / zip の中の画像が大きすぎるため表示できません | Can’t display an encrypted item / Unsupported compression method / The image in the zip file is too large to display |
| {OS の理由}（操作そのものが拒否されたとき） | {OS の理由}（訳し直さない） |

#### zip の破損の理由

`error.zip.cannotOpen` の値、またはプレビューの理由として出す。14ケース。

| 日本語 | 英語 |
|---|---|
| 展開を始められません | Can’t start decompressing |
| 圧縮データが壊れています | The compressed data is damaged |
| 項目のデータが途中で終わっています | The item data ends unexpectedly |
| 圧縮データが途中で終わっています | The compressed data ends unexpectedly |
| 項目のヘッダが壊れています | The item header is damaged |
| 項目の位置が不正です | The item offset is invalid |
| 中央ディレクトリが大きすぎます | The central directory is too large |
| 項目の場所が不正です | The item location is invalid |
| zip の中に項目が見つかりません | The item isn’t in the zip file |
| 項目のサイズが一致しません | The item size doesn’t match |
| 項目のデータがファイルの外にあります | The item data is outside the file |
| 読み込みを中止しました | Reading was canceled |
| zip の読み出しに失敗しました | Couldn’t read the zip file |
| zip を読み込めません | Can’t load the zip file |
| 暗号化されているため表示できません / 対応していない圧縮方式です / zip の中の画像が大きすぎるため表示できません | Can’t display an encrypted item / Unsupported compression method / The image in the zip file is too large to display |
| 展開を始められません / 圧縮データが壊れています / 項目のデータが途中で終わっています / 圧縮データが途中で終わっています | Can’t start decompressing / The compressed data is damaged / The item data ends unexpectedly / The compressed data ends unexpectedly |
| 項目のヘッダが壊れています / 項目の位置が不正です / 中央ディレクトリが大きすぎます / 項目の場所が不正です / zip の中に項目が見つかりません | The item header is damaged / The item offset is invalid / The central directory is too large / The item location is invalid / The item isn’t in the zip file |
| 項目のサイズが一致しません / 項目のデータがファイルの外にあります / 読み込みを中止しました / zip の読み出しに失敗しました / zip を読み込めません | The item size doesn’t match / The item data is outside the file / Reading was canceled / Couldn’t read the zip file / Can’t load the zip file |

### アクセシビリティ（画面に出ない文言）

| 日本語 | 英語 |
|---|---|
| お気に入りの名前 / フォルダの名前 | Favorite name / Folder name |
| サムネイル | Thumbnail |
| 上の階層へ（`..` の行） | Enclosing Folder |
| 切り替え効果 | Transition |
| 倍率の値と読み上げ | §4 の割合の書式（例: `125%`・`125 %`） |

ツールバー・設定・検索のアクセシビリティのラベルとヘルプは、画面の表示名と同じ文言を使う（ショートカットの表記を含む）（FR-154、US20-AS1）。

## 6. 配置

- ウインドウの最小サイズと各ペインの最小幅（160 / 240 / 320pt）で、メニュー項目・ボタン・チェックボックス・設定のラベル・既定の列幅の列見出し・空状態のメッセージが欠けない（FR-153）
- 設定ウインドウ・検索シートは内容に合わせて大きさを決める。確認モーダル・衝突ダイアログは `NSAlert` の自動の大きさに任せる
- ユーザーデータを含む動的な文は末尾を省略記号で切り詰めてよく、全文をツールチップとアクセシビリティで得られる（EC-115）
- 国際化に関わる配置の制約は `leading`／`trailing` で書く

## 7. 自動検証（`swift test`）

翻訳の取得・欠落・未使用・値の整合性・複数形・地域書式などを `Tests/FolzioCoreTests/Localization/` で検証し、`swift test` で実行する。Phase の検証ゲートの手順は増やさない（FR-157、SC-069）。

## 翻訳と検証の要件

- **FR-149**: 値（件数・ファイル名・フォルダ名・キーワード・パス・理由・倍率など）を含む文は、文全体を1つの翻訳単位とし、値の位置を訳ごとに変えられなければならない。
  文の断片をつなぎ合わせて文を作ってはならない。翻訳単位には、翻訳者が使われる場所と値の意味を判断できる文脈の説明を付ける。
- **FR-150**: 件数を含む文は、表示言語の複数形の規則に従わなければならない。英語では1件と2件以上（0件を含む）で語形を変え、日本語では語形を変えない。
  対象は少なくとも、検索バーの件数、コピーの項目名（複数選択時）、確認モーダルの対象の件数、その他件数を表示するすべての文とする。
  件数の数字は FR-151 の数値の書式で表示する。0件で専用のメッセージを持つ箇所はそれを使う（EC-114）。
- **FR-156**: 表示言語の決定・複数形・日時と数値の書式は、言語ごとの分岐をアプリの判断ロジックに持ってはならない。
  新しい言語の追加は、主にその言語の翻訳と対応言語の宣言を加えることで行えるようにする。
- **FR-157**: すべての翻訳単位は日本語と英語の訳を持たなければならない。訳の欠け・使われていない翻訳単位・値の数や種類が元の文と合わない訳を、
  自動検証で検出できなければならない。翻訳単位の取得・訳の欠けへの対応・値を含む文・複数形（0件・1件・2件以上）・表示言語と地域の組み合わせの書式は、
  自動テストで確かめる。これらの自動検証は `swift test` で実行するテストに含め、Phase の検証ゲート（AGENTS.md）の手順を増やさない。
