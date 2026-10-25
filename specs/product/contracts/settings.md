# Contract: 永続化する設定

`UserDefaults`（アプリのドメイン）に保存するキーの契約。値の意味と既定値は [data-model.md](../../001-three-pane-media-viewer/data-model.md) を参照。
キー名を変える場合は、旧キーから読み替える移行処理を同時に入れる。

| キー | 型 | 既定値 | 対応 |
|------|----|--------|------|
| `view.displayMode` | String（`list` / `thumbnails`） | `list` | FR-010 |
| `view.thumbnailSize` | Double | 128 | FR-014 |
| `view.sort.column` | String（`name` / `creationDate` / `kind`） | `name` | FR-012 |
| `view.sort.ascending` | Bool | true | FR-012 |
| `view.lastFolderPath` | String（絶対パス） | （未設定 = ホーム） | FR-003（zip の中を表示中に終了しても、zip を含むフォルダ） |
| `view.showsToolbar` | Bool | false | FR-003・049 |
| `view.showsZipFiles` | Bool | false | FR-003・095 |
| `playback.autoplay` | Bool | true | FR-031・032 |
| `playback.loop` | Bool | true | FR-031・032 |
| `fileOps.confirmBeforeExecuting` | Bool | true | FR-022・023・024・064（お気に入りの削除の確認にも使う） |
| `favorites.paths` | [String]（絶対パス、登録順） | `[]` | FR-062・066 |
| `favorites.displayNames` | [String: String]（キーは登録したフォルダの絶対パス、値は表示名） | （未設定 = どの項目も表示名なし） | FR-099〜101 |

- ペイン幅は `NSSplitView` の自動保存名 `MainSplit` で別途保存する（FR-002・003）
- 読み込み時に型や値の範囲が不正なものは既定値に戻す（例: `thumbnailSize` を 48〜512 に丸める）
- フルスクリーン状態は保存しない。次回の起動は常に3ペイン表示から始める
- ペインの表示状態（「ファイルリストのみ表示」「プレビューのみ表示」）は保存しない。起動のたびに3ペイン表示で始まる（FR-088）。
  1つのペインだけを表示している間は分割ビューの自動保存を止め、`MainSplit` には3ペインを表示していたときの幅だけを残す（001 の research.md R41）。
  保存キーは追加しない
- 種類フィルタ（「画像のみ表示」「動画のみ表示」）は保存しない。起動のたびに両方オフで始まる（FR-056）。
  起動中はフォルダを移っても保つ
- zip ファイルの表示は `view.showsZipFiles` に保存し、初回起動（値がない）だけ非表示で始まる。以後は保存した値を復元し、
  キーが Bool でない場合も非表示として読む（FR-003・095）。ツールバーのボタン・「表示」メニュー・⌃⌘Z は同じ値を使う。
  zip の中の位置・選択・検索条件とは独立し、zip の中を表示中の切り替えもこの値だけを変える
- お気に入りの場所はパスで保存し、ブックマークデータは保存しない。登録したフォルダが移動・名前変更されても追従せず、
  見つからない項目として残す（FR-067）。見つかるかどうか（`FavoriteAvailability`）と「お気に入り」の見出しの
  開閉状態は保存しない。起動時の見出しは折りたたんだ状態で始まる
- お気に入りの表示名は `favorites.displayNames` に、表示名を付けた登録の分だけ保存する。キーは `favorites.paths` の各パスを
  標準化した絶対パス（`standardizedFileURL.path`）とする。表示名を付けていない登録はキーに載せず、表示名が1つもなければ
  `favorites.displayNames` 自体を消す。お気に入りから削除した登録の表示名は残さない（FR-101、EC-44）
- 読み込み時は、`favorites.displayNames` が辞書でなければ無視する。値が文字列でない項目、`favorites.paths` にないパスの項目、
  前後の空白と改行を除くと空になる項目は捨てる。値の中の改行は取り除き、255 文字（書記素クラスタ）を超える分は切り捨てる（FR-100）
- 表示名を保存する前のバージョンの保存内容（`favorites.paths` だけ）は、そのまま登録順に、全件を表示名なしとして読む。
  保存形式の移行処理は持たない。古いバージョンは `favorites.displayNames` を読まないため、戻しても登録は失われない（FR-101、EC-45）
- 表示名は登録したフォルダの名前と独立に保存する。フォルダが見つからない間（FR-067）も消さない。保存の例:

  ```text
  favorites.paths        = ["/Users/me/Photos/2025", "/Volumes/Backup/Photos/2025"]
  favorites.displayNames = { "/Volumes/Backup/Photos/2025": "2025（バックアップ）" }
  ```

  ツリーの表示は「2025」「2025（バックアップ）」（登録順）
- zip の中の位置（開いている zip と階層）は保存しない。zip の中へ入っても `view.lastFolderPath` は変えず、次回は zip を含む
  フォルダの一覧から始まる（FR-003）。保存キーは追加しない
- ツールバーの構成は保存しない（`NSToolbar.autosavesConfiguration = false`）。表示状態だけを
  `view.showsToolbar` に保存し、フルスクリーン中の自動非表示はこの値を変えない
- 検索の条件（キーワード・検索起点ディレクトリ）と検索結果は保存しない。前回のキーワードは起動中だけ覚える。検索を始めても
  `view.lastFolderPath` は変えない（FR-081・086）。並べ替えの「場所」（`location`）は検索結果の表示中だけ使い、`view.sort.column` には
  書かない（保存済みの値は `name` / `creationDate` / `kind` のまま）。保存キーは追加しない

## 設定ウインドウ（⌘,）

| 区分 | 項目 | 対応キー |
|------|------|----------|
| 動画 | 「動画を自動再生する」チェックボックス | `playback.autoplay` |
| 動画 | 「動画をループ再生する」チェックボックス | `playback.loop` |
| ファイル操作 | 「コピー・ゴミ箱に入れる・お気に入りから削除する前に確認する」チェックボックス（名前の変更・移動・ツリーのフォルダのゴミ箱は常に確認する） | `fileOps.confirmBeforeExecuting` |

チェックボックスの変更は即座に反映し、再起動を必要としない。
