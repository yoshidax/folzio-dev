# Research: お気に入りの名前の変更

番号は 001 の research.md（R1〜R47）から続ける。コードのコメントで `R48` のように参照する。
Technical Context に NEEDS CLARIFICATION は残っていない。以下は設計上の判断の記録。

## R48. 表示名の持ち方（FR-100・101、EC-41・44）

- **Decision**: `FavoriteFolders` に、同一性のキー（`standardizedFileURL.path`）から表示名への辞書 `customNames` を持たせる。
  `urls` はこれまでどおり登録順の配列のまま残す。表示名を付けていない項目は辞書に載せない。`remove(_:)` は表示名も消し、
  `add(_:)` は表示名を付けない（EC-44）。既定の名前（登録したフォルダの名前）は保存せず、表示のたびに App が決める
  （ホーム・ボリュームの最上位はツリーのルートの名前、それ以外は `lastPathComponent`。既存の `rebuildFavoriteEntries` と同じ）
- **Rationale**: 既存の呼び出し側（`urls`・`contains`・`add`・`remove`）を変えずに済む。既定の名前はボリューム名のように
  Core からは決められないものを含むため、Core は「付けた名前があるか」だけを持つ
- **Alternatives considered**:
  - `urls` を `[FavoriteFolder]`（url と名前の組）の配列に置き換える: 既存の呼び出し側とテストを広く書き換える必要があり、
    得るものがない
  - 既定の名前も保存する: ボリューム名の変更に追従できず、旧形式の読み込みで名前を作る処理も要る

## R49. 保存形式と旧形式の読み込み（FR-101、EC-45、contracts/settings.md）

- **Decision**: `favorites.paths`（[String]、登録順）はそのまま使い、新しいキー `favorites.displayNames`
  （[String: String]、キーは登録したフォルダの絶対パス（`standardizedFileURL.path`）、値は表示名）を足す。
  - 読み込み: `favorites.displayNames` がない・辞書でないときは、すべて表示名なし。値が文字列でない項目、
    `favorites.paths` に登録されていないパスの項目は捨てる。値は R50 の確定時の規則で正規化し、空になれば捨てる
  - 書き込み: `favorites.paths` を従来どおり書き、表示名があれば `favorites.displayNames` に登録中のものだけを書く。
    表示名が1つもなければキーを消す
- **Rationale**: この機能より前のバージョンの保存内容は `favorites.paths` だけなので、そのまま「表示名なし・登録順」として
  読める（EC-45）。読み替えの処理も、移行済みの印も要らない。古いバージョンに戻しても `favorites.paths` は読めて、
  表示名だけが無視される
- **Alternatives considered**:
  - 新しいキー `favorites.entries`（`[{path, displayName?}]`）に移し、旧キーから読み替える: 移行処理と、両方のキーが
    あるときの優先順位の規則が要る。古いバージョンに戻すと、移行後に追加・削除した登録が見えない
  - `favorites.paths` の要素を辞書に変える: 古いバージョンが要素を文字列でないとして捨て、お気に入りがすべて消える

## R50. 確定時と編集中の名前の扱い（FR-100、EC-40・41）

- **Decision**: Core に純粋関数の名前空間 `FavoriteName` を置く。
  - `maximumLength = 255`。長さは `String.count`（書記素クラスタの数）で数える。絵文字や結合文字も見た目の1文字を1と数える
  - `sanitizedForEditing(_:)`: 編集中の入力から改行（`CharacterSet.newlines`）を取り除き、255 文字で打ち切る。
    App の `FavoriteNameFormatter` がこれを `isPartialStringValid(_:proposedSelectedRange:originalString:originalSelectedRange:errorDescription:)`
    で使い、ペーストを含めて改行と 256 文字目以降が入らないようにする
  - `normalized(_:)`: 確定時の入力を `sanitizedForEditing` に通し、前後の空白（改行を含む）を取り除く。空なら nil（表示名の解除）
  - `FavoriteFolders.commitDisplayName(_:for:defaultName:) -> Bool`: 正規化した名前が編集前の表示名
    （表示名があればそれ、なければ `defaultName`）と同じなら何もしない。nil なら表示名を解除し、それ以外は表示名にする。
    ほかの項目と同じ名前、`defaultName` と同じ名前、`/`・`:` を含む名前も拒否しない（EC-41）。変更したら true
- **Rationale**: 判断をすべて Core に置いてテストできる。編集前と同じ名前の確定を何もしない扱いにすることで、
  表示名を付けていない項目で Return を2回押しても表示名が付かない
- **Alternatives considered**:
  - 改行や長すぎる入力を含む変更を丸ごと拒否する（`isPartialStringValid` で false だけを返す）: 末尾に改行の付いた
    テキストのペーストがまるごと入らなくなり、使いにくい
  - `defaultName` と同じ名前で確定したら表示名を解除する: EC-41 の「そのまま受け付ける」と食い違い、ボリューム名が
    後で変わったときにユーザーの意図した名前が残らない
  - 長さを UTF-16 の長さで数える: 見た目の文字数と合わず、絵文字が途中で切れる

## R51. ツリーの行の中での編集（FR-099・102、US1-AS30〜33）

- **Decision**: ファイルリストの `ListModeView.beginRenaming` / `finishRenaming` と同じ方式で、お気に入りの行のセル
  （`makeFolderCell` の `NSTableCellView.textField`）を編集中だけ編集可能にする。
  - 開始: 対象の行を見える位置へスクロールし、`view(atColumn:row:makeIfNecessary: true)` のセルのテキストフィールドに
    現在の表示名を入れ、`isEditable`・背景・フォーカスリングを編集の見た目にし、`FavoriteNameFormatter` を付けて
    first responder にする。フィールドエディタの選択を全体にする。ツリーの選択・ファイルリスト・プレビューは変えない（FR-102）
  - 確定と取り消し: テキストフィールドの delegate（ツリー）で、`insertNewline(_:)` は確定、`cancelOperation(_:)` は取り消し。
    `controlTextDidEndEditing` が来たら（ほかの場所のクリックなど）確定する（A-31）。終了処理は1回だけ走るよう
    `isFinishingEdit` で守り、セルを非編集の見た目に戻して `Formatter` を外す。終了処理の順は「入力値を取る → 見た目を戻す →
    編集を終える（フォーカスを戻すとき `makeFirstResponder(outlineView)`、戻さないとき `window.endEditing(for:)`）→ 表示名の確定 →
    `reloadItem`」とする。`ListModeView.finishRenaming` と同じく編集を終えてから行を更新し、フィールドエディタが
    再読み込みで切り離されたセルに残らないようにする
  - フォーカス: Return・Esc で終えたときは、キーボードフォーカスをツリー（`outlineView`）に戻す。ほかの場所のクリックで終えたとき
    （`controlTextDidEndEditing`）は、クリックした先のフォーカスを変えない。
    ツリーの側から編集を確定するとき（右クリックメニューを開いたとき（`menuNeedsUpdate`）・ボリュームの接続や取り外し（`applyRoots`）・
    「お気に入り」の見出しの折りたたみ）は、編集欄にフォーカスがあった（フィールドエディタがまだ編集中のフィールドに付いていた）なら
    ツリーに戻す。`window.endEditing(for:)` だけで終えるとウインドウが first responder になり、ツリーを右クリックしただけで
    クリックし直すまで Return・⌘⌫・矢印キーが効かなくなるため。フィールドエディタがすでにほかへ移っていれば、そのフォーカスを奪わない
  - 編集中の状態は `editingFavorite: FavoriteEntry?` とする。セルはフォルダの行と共有のため、`viewFor` では毎回
    非編集の見た目とアクセシビリティラベルを戻す
- **Rationale**: すでに動いているファイル名の変更と同じ操作感・同じ実装の型にそろえる。セルを作り替えずに編集できる
- **Alternatives considered**:
  - `NSOutlineView.editColumn(_:row:with:select:)`: view-based のアウトラインでは使えない（cell-based 用）
  - 名前の入力をモーダル（シート）で受ける: ファイルリストのリネームと操作が揃わず、SC-020（説明なしで完了）に不利

### 編集中に起こるツリーの再読み込み（EC-42・43）

- 存在の確認の結果（`applyFavoriteProbe`）が編集中の項目に当たったときは、`availability` だけ更新して `reloadItem` をしない。
  編集の終了時に必ずその行を `reloadItem` するので、淡色の表示はそのとき反映される。これで、編集中に登録したフォルダが
  アプリの外で削除・移動されても編集は続けられる（EC-43）
- ボリュームの接続・取り外し（`applyRoots` の `reloadData`）は全行のセルを作り直すため、その前に編集を確定する
  （入力した名前は失わない）。編集欄にフォーカスがあったならツリーに戻す（上の「フォーカス」）。
  EC-43 が挙げる「削除・移動・名前変更」ではこの経路を通らない
- フォルダの子の読み直し（`applyListing` の `reloadItem(node, reloadChildren:)`）はお気に入りの行より下の行だけを
  作り直すため、編集を止めない
- お気に入りの追加・削除（`reloadFavorites`）は、編集中はメニューの検証で無効にする（R53）ため起こらない
- 右クリックメニューを開いたとき（`menuNeedsUpdate`）は、編集を確定してからメニューを作る（ほかの場所のクリックと同じく確定する）。
  右クリック先はツリーなので、編集欄にフォーカスがあったならツリーに戻す（上の「フォーカス」）
- 「お気に入り」の見出しを折りたたむとき（開閉ボタンのクリック。`outlineViewItemWillCollapse`）は、行が消える前に編集を確定する。
  開閉ボタンのクリックでは first responder が変わらないことがあり、`controlTextDidEndEditing` が来ないまま行が消えると、
  フィールドエディタが切り離されたセルに残るおそれがあるため。クリック先はツリーなので、フォーカスはツリーに戻す

## R52. 開始の手段とメニューの経路（FR-099、US1-AS35）

- **Decision**:
  - Return と「編集 > 名前を変更」: 既存のメニュー項目（`#selector(FileListViewController.rename(_:))`、`target = nil`、
    キー等価は修飾なしの Return）をそのまま使い、`DirectoryTreeViewController` に `@objc func rename(_:)` を実装する。
    ツリーにフォーカスがあるときは応答チェーンでツリーが受け、ファイルリストにフォーカスがあるときは従来どおり
    `FileListViewController` が受ける（⌘⌫ の `moveToTrash(_:)` と同じ仕組み）。対象は選択中の行
  - 右クリックメニュー: `TreeContextMenuItem.renameFavorite` を足し、`FavoriteCommands.contextMenu(for: .favorite)` を
    `[.renameFavorite, .removeFromFavorites]` にする。項目は「名前を変更」（Return を表示）で、`representedObject` の行
    （右クリックした行。A-21）を対象にする
  - 判定: `FavoriteCommands.renameTarget(_:)` は `.favorite(url)` のときだけ URL を返す。見出し・ホーム・ボリュームの最上位・
    通常のフォルダ・nil では nil。ツリーの `validateMenuItem` はこれが nil のとき「名前を変更」を無効にする
  - zip の中・検索結果の表示中も、ツリーの判定は `BrowserModel` の状態を見ない（FR-099、EC-46）
- **Rationale**: メニューとキーの割り当てを増やさずに済み、Return・メニュー・右クリックの3つが同じ処理に集まる
- US1-AS35（お気に入り以外で Return）: メニュー項目が無効になるため、Return は従来どおり `NSOutlineView` に届き、
  名前の編集は始まらない。この挙動は現状から変えない（quickstart.md で、編集が始まらないことと、実際のフォルダの名前が
  変わらないことを確かめる）
- **Alternatives considered**:
  - `NSOutlineView` のサブクラスで Return を拾う（`FileListTableView.onReturn` と同じ）: メニュー項目の Return が先に
    処理されるため、メニューの検証と二重の経路になる

## R53. 「名前の変更中」の無効化（FR-102、contracts/keyboard-and-menus.md）

- **Decision**: 既存の判定 `FileListViewController.isEditingText`（`view.window?.firstResponder is NSTextView`）を
  「名前の変更中」の判定としてそのまま使う。ツリーの行内編集もウインドウのフィールドエディタを使うため、次は変更なしで
  編集中に無効になる。
  - `PaneCommands`（⌃⌘T・⇧⌘F・⌘F・⌃⌘2 / ⌃⌘3）とツールバーのペインの表示ボタン・「zipファイルを表示」ボタン
  - 種類フィルタ・zip ファイルの表示の「表示」メニュー項目と ⌃⌘Z（`FileListViewController.validateMenuItem` と `apply*` の検査）
  - 「中を表示」「上の階層へ」: ツリーにフォーカスがある間は `FileListViewController` が応答チェーンにないため、そもそも無効
  - 検索結果の表示を終える Esc: Esc はフィールドエディタの `cancelOperation(_:)` として R51 で取り消しに使い、
    ファイルリストには届かない

  追加するのは、ツリー自身のメニュー項目の検証だけとする。編集中（`editingFavorite != nil`）は、`DirectoryTreeViewController.validateMenuItem`
  がすべての自分の項目（名前を変更（`rename(_:)`・右クリック）・`moveToTrash(_:)`（⌘⌫）・ゴミ箱に入れる（右クリック）・
  ここにペースト（右クリック）・ここに移動ペースト（右クリック）・移動ペースト（⌥⌘V）・Finder に表示・お気に入りに追加・
  お気に入りから削除（右クリック））で false を返す（契約 keyboard-and-menus.md の 2 と同じ並び）。とくに Return（名前を変更）と ⌘⌫ はメニューのキー等価がフィールドエディタより先に処理されるため、
  無効にしないと編集中の Return が確定にならず、⌘⌫ でお気に入りが削除されてしまう
  - 「編集 > ペースト」（⌘V）はツリーの `paste(_:)` と同じ `paste:` のセレクタだが、名前の変更中は応答チェーンの先頭の
    フィールドエディタが受けるため、ツリーには届かず、編集欄へのテキストのペーストになる（無効にしない。quickstart #9 はこの動作を使う）。
    ツリーの `paste(_:)` の検証で false を返して効くのは、右クリックの「ここにペースト」だけ。「移動ペースト」（⌥⌘V、`movePaste:`）は
    フィールドエディタが応答しないため応答チェーンでツリーに届き、検証で無効になる
- **Rationale**: 判定を1か所（ウインドウの first responder）に保ったまま、ツリーでの編集にも同じ規則が効く。
  `PaneCommands` などに新しい入力を足す必要がない
- **Alternatives considered**:
  - `PaneCommands` に `isEditingFavoriteName` を足し、各所で OR を取る: 同じ事実を2つの状態で持つことになり、
    更新漏れの原因になる

## R54. アクセシビリティ（FR-101、憲章 III）

- **Decision**: お気に入りの行のテキストフィールドの `stringValue` に表示名を入れる（既存どおり。VoiceOver はこれを項目名として
  読む）。編集の開始時にテキストフィールドへ `setAccessibilityLabel("お気に入りの名前")` を設定し、終了時と `viewFor` で nil に戻す
  （セルはフォルダの行と共有のため）
- **Rationale**: 表示とアクセシビリティの名前を同じ値から出せば食い違わない。ラベルは編集中だけにして、通常時の読み上げを
  表示名のままにする

## R55. お気に入りの削除の確認モーダル（FR-064 の変更）

- **Decision**: `ConfirmationPresenter.confirmRemovingFavorite(named:path:)` に変え、本文を
  「対象: <表示名>」「場所: <登録したフォルダの絶対パス>」「実際のフォルダは変更されません」の3行にする。
  呼び出し側（`removeFavorite`）は `entry.name`（表示名）と `entry.url.path` を渡す。省略設定（FR-023）の扱いは変えない
- **Rationale**: 同じ表示名の項目が複数あっても、パスで対象を見分けられる。フォルダが見つからない項目でも
  パスは登録内容から出せる

## R56. 検証の方針（憲章 IV、SC-018〜021）

- **Decision**: Core のテストで、名前の正規化（R50）、表示名の設定・解除・削除時の破棄（R48）、保存と旧形式の読み込み・
  不正な保存値（R49）、メニューの項目と対象の判定（R52）を確かめる。行内編集・メニューの検証・確認モーダル・
  VoiceOver の読み上げ・名前の変更中の無効化は、quickstart.md の手動確認で確かめる
- 性能に影響する変更はないため、性能テストの基準値の計測は追加しない（既存の `MediaViewerPerformanceTests` は
  Phase の検証ゲートで従来どおり実行する）
