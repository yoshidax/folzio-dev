# コードコメント翻訳の用語集

ソースコードのコメントを英語化するときの用語と書式をそろえるための内部資料です。
書式の正本は `AGENTS.md` の「コードコメント（英語）」とし、このファイルは訳語の判断だけを扱います。
`docs_private/` は公開用リポジトリから除外されます。

## 基本方針

- コメントだけを変更し、コード・識別子・文字列リテラルは変更しない
  - 例外: `TextKey.comment`（翻訳者向け説明）と `Localizable.strings` のコメントは、承認済みの対象として翻訳する
- `FR-*`、`EC-*`、`R*`、`SC-*`、`A-*` などの ID は翻訳せず、そのまま残す
- UI の用語は `Sources/FolzioLocalization/Resources/en.lproj/Localizable.strings` の値を正とする
- 日本語の句読点（、。「」・）は ASCII（`,` `.` `"`）に置き換える
- 識別子・型名・関数名・引数名はバッククォートで囲む
- 1行は100〜120文字を目安に折り返す
- doc comment は三人称単数・現在形。Boolean は `Whether ...`

## UI 用語

| 日本語 | English | 備考 |
|---|---|---|
| お気に入り | Favorites | UI の固定行 |
| ファイルリスト | file list | |
| ディレクトリツリー | directory tree | 単に tree と呼ぶ箇所も可 |
| プレビュー | preview | |
| スライドショー | slideshow | |
| ペイン | pane | 3ペインは three-pane |
| サムネイル | thumbnail | |
| 一覧表示 | List | UI の表示形式 |
| サムネイル表示 | Thumbnails | UI の表示形式 |
| 表示形式 | view mode | |
| 検索 | search | |
| 検索起点 | search root | UI の "Search In" は引用する場合だけ使う |
| 検索シート | search sheet | |
| 検索バー | search bar | |
| 並べ替え | sort | |
| 名前の変更 | rename | |
| ゴミ箱 | Trash | 大文字 |
| 項目（zip） | entry | |
| 項目（ファイル・フォルダ） | item | |
| 展開 | inflate | |
| 圧縮 | deflate | |
| 表示倍率 | zoom | |
| フルスクリーン | full screen | |
| 種類 | kind | メディアの種類 |
| 種類フィルタ | media type filter | |
| 拡張子 | file extension | |
| 設定ウインドウ | Settings window | |
| 確認モーダル | confirmation modal | |
| 衝突ダイアログ | conflict dialog | |
| アクセシビリティラベル | accessibility label | |
| ツールチップ | tooltip | |
| 切り替え間隔 | interval | スライドショー |
| 切り替え効果 | transition | スライドショー |
| 空状態 | empty state | |
| 見出し | title / heading | ダイアログは title、区分は heading |
| 注記 | note | |

## コメント用語

| 日本語 | English | 例 |
|---|---|---|
| 翻訳単位 | translation unit | `TextKey` の1項目 |
| 文言 | text / string | UI に出る文字列 |
| 書式 | formatting | 日時・件数・割合 |
| 地域 | region | ロケールの地域 |
| 表示言語 | display language | |
| 開発言語 | development language | 英語 |
| 件数 | count | |
| 件数の句 | count phrase | 検索バーの `%3$@` |
| 整形済みの件数 | formatted count | |
| 語形が変わる | wording changes with the count | 複数形の説明 |
| 上限で打ち切り | truncated at the limit | |
| 理由 | reason | OS が返す理由も reason |
| 前置き | lead-in | |
| 文字どおりに入れる | inserted verbatim | |
| 位置指定の書式 | positional format specifiers | |
| 直列化する | serialize | スレッド |
| 呼び出し側 | caller | |
| 先頭から展開し直す | inflate again from the beginning | |
| 中身ごと | with their contents | フォルダ操作 |
| 残りの件数 | remaining count | |
| 対象の1行 | one line for an item | 確認モーダル |
| 固定の行 | fixed row | ツリーのお気に入り |
| 編集欄 | edit field | |
| 完了時の文 | completed-state sentence | 検索バー |

## MARK 見出し

| 日本語 | English |
|---|---|
| Core の値 | Core Values |
| メニューバー | Menu Bar |
| 右クリックメニュー | Context Menu |
| ツールバー | Toolbar |
| 設定ウインドウ | Settings Window |
| ファイルリスト・ツリー | File List and Tree |
| 検索 | Search |
| 確認モーダル・ダイアログ | Confirmation Modals and Dialogs |
| アクセシビリティ | Accessibility |
| 文言 | Text |
| 書式 | Formatting |
| 内部 | Internals |
| 記録 | Recording |
| 戻る・進む | Back and Forward |
| 存在の確認 | Existence Checks |
| 出力先 | Output |
| 組み立て | Assembly |
| フィクスチャ | Fixtures |

## 訳し方の例

- `展開後の \`target\` まで、読み捨てて進む`
  → `Advances to offset \`target\` in the inflated data, discarding the bytes in between.`
- `圧縮データの終わりより先を求められたら、展開できた分だけを返す`
  → `If asked for data past the end of the compressed data, returns only the bytes that could be inflated.`
- `状態でゴミ箱とお気に入りから削除が入れ替わる`
  → `The Trash and Remove from Favorites items swap depending on the state.`
- `件数で語形が変わる`
  → `The wording changes with the count.`

## レビュー時の確認

- 条件（「〜のときだけ」「〜より前」「〜しない」）が弱まっていないか
- ID とコード要素が欠けていないか
- UI 用語が `en.lproj` の値と一致しているか
- 一行が長すぎないか
- コメント以外の差分が混ざっていないか
