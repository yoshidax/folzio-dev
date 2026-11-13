# Research: TAK-86 ツールバーの検索欄による名前の絞り込み

調査の基準は、作業ブランチ `claude/peaceful-bell-dj1h3u`（`origin/master` の `d3fe85b` を含む）のコード。
Cloud には Swift と macOS がないため、AppKit の実際の動作は確かめていない。確かめていない点は各項目の「未確認」に書き、quickstart.md の GUI 確認で確かめる。

## R1 絞り込みを置く場所

- **Decision**: 名前の絞り込みは、種類フィルタと同じく `BrowserModel` の状態として持ち、表示する行を作るただ1か所の `rebuildListing()` で適用する。
  適用の順は「種類フィルタ → zip の表示（検索結果では適用しない） → 名前の絞り込み」。`..` の行は、絞り込みの後に従来どおり先頭へ加える
- **Rationale**:
  - `rebuildListing()` は `allFiles`（`..` を含まない）から表示する行を作る（`BrowserModel.swift` の 997 行付近）。ここで絞れば、通常のフォルダ・zip の中・検索結果のすべてに働き、
    `..` は自然に残る（FR-381・FR-382）
  - `allFiles` を変えないので、アプリの外での変更・名前の変更・検索中に見つかった項目は、次の `rebuildListing()` でその時点の名前で照合される（EC-250・EC-251）
  - 表示中の一覧を使う操作（矢印キーでの移動・すべてを選択・スライドショー）は `listing.files` を読むので、種類フィルタと同じく絞り込んだ後の一覧が対象になる（FR-387）
- **Alternatives considered**: ファイルリストの画面（`FileListViewController`）側で行を隠す。モデルの選択・プレビュー・スライドショーが非表示の行を対象にしてしまうため採らない
- **未確認**: `listing.files` を読まずに `allFiles` を直接使う操作がないこと（実装の時にコードで確かめる。T017）

## R2 照合の型

- **Decision**: Core に値型 `NameFilter`（`Sources/FolzioCore/Model/NameFilter.swift`）を作る。入力した文字（そのまま）と、既存の `SearchPattern`（`SearchPattern(keyword:)`）を持つ。
  `apply(to:)` は `pattern.matches(fileName:)` で `MediaFile.name` を照合する
- **Rationale**: `SearchPattern` は、前後の空白の除去・空のときの `nil`・ワイルドカード・大文字小文字と正規化の扱いを実装済みで、検索のモーダルが使っている。
  同じ型を使えば、照合の結果が検索と食い違わない（FR-381・SC-208）。入力した文字をそのまま持つのは、検索欄の表示と突き合わせるため（R5）

## R3 一致する項目がないときの状態

- **Decision**: `FolderListing.State` に新しい case を足さない。名前の絞り込みで（`..` を除く）行が1つも残らず、絞り込みの前には行があった場合は、
  `listing.state` を既存の `.noMatches` にし、モデルの `nameFilterHidesAllRows`（Bool）を真にする。画面は `.noMatches` のとき、この値が真なら名前のメッセージ、偽なら従来の種類フィルタのメッセージを出す
- **Rationale**: `State` の case を足すと、`switch` で網羅している約10か所（`BrowserModel`・`FileListDropTarget`・`FileListViewController`・`MainSplitViewController`・テスト）を
  すべて直す必要がある。`.noMatches` は「項目はあるが絞り込みで表示されない」という意味で、名前の絞り込みにも当てはまる
- 行が1つでも残るときは、従来の判定（`hasMedia` と `filtered` から決める）を、名前の絞り込みの前の行で行う（FR-386 の最後の子項目）

## R4 解除する時点

- **Decision**: `BrowserModel.resetForNavigation()` で名前の絞り込みを空にする
- **Rationale**: `resetForNavigation()` を呼ぶのは、`selectFolder`・`startSearch`・`openItem`・`goToEnclosingLevel`・`openArchive`・`returnToFolder`・`showHistoryLocation` で、
  どれも表示する一覧が別の場所へ替わる操作（FR-384）。同じ場所の再読み込み（`reloadCurrentFolder()`）は呼ばないので、アプリの外での変更の反映では解除されない
- 履歴（`HistoryEntry`）には種類フィルタと違って記録しない。戻る・進むは `showHistoryLocation` を通るので、絞り込みのない状態になる（EC-254）

## R5 検索欄とモデルの同期

- **Decision**: モデルの絞り込みの文字を正とする。検索欄の入力は `FileListViewController.applyNameFilter(_:)` を通してモデルへ渡し、
  モデルの変化（解除を含む）は、種類フィルタと同じ Observation の監視（`observeMediaTypeFilter()` と同じ形）で `onNameFilterChange` からツールバーへ伝える。
  ツールバーは、検索欄の文字がモデルの文字と違うときだけ検索欄を書き換える
- **Rationale**: 移動で解除されたときに検索欄を空にする（FR-384）経路が、既存の種類フィルタの経路と同じ形になる。
  文字が同じときに書き換えないので、入力中のカーソルや末尾の空白を壊さない

## R6 入力の受け取り

- **Decision**: 検索フィールドの `action` は使わない。`NSSearchFieldDelegate` の `controlTextDidChange(_:)` で絞り込みを反映し、
  `control(_:textView:doCommandBy:)` で `insertNewline(_:)` を受けたらファイルリストへフォーカスを移す
- 変換中: `controlTextDidChange(_:)` で、フィールドエディタ（`NSTextView`）の `hasMarkedText()` が真の間は絞り込みを変えない（FR-389）
- ×ボタンと Esc: 標準の動作で文字が消え、`controlTextDidChange(_:)` が呼ばれて絞り込みが解除される（FR-383）
- **未確認**: (1) 変換の確定で `controlTextDidChange(_:)` が未確定でない状態で呼ばれること、(2) ×ボタンと Esc で `controlTextDidChange(_:)` が呼ばれること、
  (3) 変換の確定の Return で `insertNewline(_:)` が届かないこと。GUI 確認で確かめる（quickstart.md の 1・2）
- **代替（確認で動かなかった場合）**: (1) は `NSTextView` の変化の通知を直接受ける。(2) は検索フィールドの `action`（文字が空のとき）でも解除する

## R7 ツールバー項目の種類

- **Decision**: 既存のセットと同じく、通常の `NSToolbarItem` の `view` に検索フィールド（`NSSearchField` のサブクラス `ToolbarSearchField`）を置く。幅は固定の制約（180pt）にする
- **Rationale**: `MainToolbarController` の「項目ごとに新しいコントロールを作り、状態は `toolbar.items` を識別子で探して適用する」構成（TAK-23 の R-2）に乗せられる。
  あふれたとき・文字だけの形式の動作を `menuFormRepresentation` で決められる（FR-392）
- **Alternatives considered**: `NSSearchToolbarItem`。狭いときに虫眼鏡のボタンへ畳まれる標準の動作を Cloud で確かめられず、虫眼鏡の押下でモーダルを開く動作（FR-390）と両立するか分からないため採らない
- 項目を作り直したとき（カスタマイズ・再追加）は、`applyState(to:)` でモデルの文字を新しい検索欄へ入れる

## R8 虫眼鏡アイコンの押下とツールチップ

- **Decision**: `NSSearchFieldCell.searchButtonCell` の `target` と `action` を差し替え、押下で `MainToolbarController` の `showSearch(_:)` を呼ぶ。
  虫眼鏡だけのツールチップは、`ToolbarSearchField` が `searchButtonRect(forBounds:)` の矩形に `addToolTip(_:owner:userData:)` で付ける。検索欄の残りの部分には、検索欄のツールチップを同じ方法で付ける
- **未確認**: 差し替えた `action` が押下で呼ばれること、矩形のツールチップが出ること、VoiceOver が虫眼鏡を別の要素として読むこと。GUI 確認で確かめる（quickstart.md の 3）
- **代替**: `ToolbarSearchField` で `mouseDown(with:)` を上書きし、クリックの位置が `searchButtonRect(forBounds:)` の中なら同じ処理を呼ぶ
- **結果（2026-11-13、GUI 確認）**: `searchButtonCell` の差し替えでは、虫眼鏡のクリックで action が呼ばれなかった。代替案に切り替えた。
  位置は `NSSearchField.searchButtonBounds` で求める。`NSSearchFieldCell.searchButtonRect(forBounds:)` は、上書きしなければ渡した矩形をそのまま返すため使わない

## R9 検索のモーダルへの引き継ぎ

- **Decision**: 引き継ぐキーワードの決め方は Core の `ToolbarSearchInput.modalKeyword(fieldText:previousKeyword:)` に置く。
  `MainSplitViewController.showSearch(_:)` の中身を `presentSearchPanel(keyword:)` へ移し、⌘F は前回のキーワード、虫眼鏡は引き継いだキーワードで呼ぶ
- モーダルで検索を始めると `startSearch` → `resetForNavigation()` で絞り込みが解除される（US82-AS4。R4）。キャンセルでは何も変わらない

## R10 検索欄にフォーカスがある間のコマンド

- **調査**: メニューの項目は `target = nil` で、レスポンダチェーンから `MainSplitViewController` などを探す（`MainMenu.swift`）。
  ツールバーのビューはウインドウの content view の外にあるため、検索欄が first responder の間、チェーンは content view の下の view controller を通らないと考えられる
- **Decision**:
  - ファイル操作のコマンドを検索欄から content 側へ転送しない（EC-257・SC-213）
  - `ToolbarSearchField` の `supplementalTarget(forAction:sender:)` で、`showSearch(_:)` に限って `MainToolbarController` を返し、⌘F を虫眼鏡と同じ処理へつなぐ（FR-390）
- **未確認**: 上のチェーンの理解。GUI 確認で、検索欄にフォーカスを置いて ⌘⌫・⌘C・⌘V・⌘D を押し、選択中のファイルに何も起きないことを確かめる（quickstart.md の 5）。
  届いてしまう場合は、検索欄の編集中はファイル操作を無効にする条件を足す方法を保守者と相談する
- **影響**: 検索欄にフォーカスがある間は、content 側を対象にするほかのメニューのコマンド（表示形式の切り替えなど）も無効になる見込み。Return で一覧へ戻れば使える

## R11 検索欄へ移るコマンド

- **Decision**: 割り当てを変更できるコマンドに `filterByName`（既定 ⌥⌘F、区分は検索）を加える。「ファイル」メニューの「検索…」の直後に「名前で絞り込む」を置く。
  `MainSplitViewController.filterByName(_:)` が、ツールバーが隠れていれば表示してから、ツールバーのコントローラへ検索欄へのフォーカスを頼む
- 有効の条件: `paneCommands.canSearch` が真、ツールバーの項目に `nameFilter` がある、表示の形式が文字だけでない（FR-391）
- **Rationale**: 憲章 原則 III。⌥⌘F は contracts/keyboard-and-menus.md の既存のキーと重ならない（⌘F・⇧⌘F・⌃⌘F は使用中）
- **影響の範囲**: `ShortcutCommandID`・`ShortcutCommands.all`・`ShortcutCatalog`・`ShortcutText`（名前・条件・メニューの対応）・`MainMenu`（項目と割り当ての対応）・
  コマンドの数を 32 と書いているテスト（`ShortcutCommandConsistencyTests`）と仕様（FR-268・contracts）
- **未確認**: ツールバーを表示した直後に検索欄を first responder にできること（表示の反映を待つ必要があるか）。GUI 確認で確かめる（quickstart.md の 4）

## R12 検索欄が見えないときの解除

- **Decision**: `MainToolbarController` で、(1) ツールバーの表示が偽になったとき（既存の `toolbarVisibilityChanged(_:)`）、(2) `nameFilter` の項目がツールバーから外れたとき
  （`toolbarDidRemoveItem(_:)`）、(3) 表示の形式が文字だけになったとき（既存の `displayMode` の監視）に、絞り込みを解除する（FR-393・A-226）
- あふれて見えない場合は解除しない（EC-253）
- **未確認**: フルスクリーンでツールバーが自動で隠れるときに (1) が呼ばれるか。呼ばれる場合は、EC-258（フルスクリーンでは絞り込みを保つ）と食い違うので、
  利用者の操作で隠したとき（`view.showsToolbar` を偽にする経路）だけ解除する。実装の時にコードで確かめる（T027）

## R13 有効・無効

- **Decision**: 検索フィールドと項目の `isEnabled` を `panes.paneCommands.canSearch` にする。既存の更新の経路（`apply(paneLayout:)`・`updateSlideshowAvailability()`・`applyState(to:)`）から適用する
- `observeEditingAvailability()` は全コントロールの編集の通知を受けるが、`canSearch` の `isEditingText` はファイルリストの名前の変更だけを指すので、検索欄の編集では無効にならない
  - **訂正（2026-11-13、GUI 確認の指摘）**: この前提は誤りだった。`FileListViewController.isEditingText` は「ウインドウの first responder が `NSTextView`（フィールドエディタ）か」で、
    ツールバーの検索欄での入力でも真になっていた。そのため、入力を始めると `canSearch` が偽になり、検索欄が自分を無効にして編集が終わり、フォーカスがファイルリストへ移った。
    判定を `FileListViewController.isRenaming(firstResponder:)` に分け、フィールドエディタの delegate がツールバーの検索欄（`ToolbarSearchField`）のときは名前の変更として扱わないように直した
- 無効にしてもモデルの絞り込みは変えない（EC-258）

## R14 並びの既定値と保存

- **Decision**: `ToolbarLayout.setIdentifiers` に `"nameFilter"` を加え、`defaultOrder` を「8つのセット → `NSToolbarFlexibleSpaceItem` → `nameFilter`」にする。
  `normalized(saved:)` の規則は変えない。`MainToolbarController` の既定と許可の一覧は、手書きの配列をやめて `ToolbarLayout` から作る
- **Rationale**: 保存は「既定の並びと違うときだけ」行うので、カスタマイズしていない利用者は新しい既定の並びに従い（US84-AS1）、保存済みの並びはそのまま復元される（US84-AS2）。
  既定の並びを2か所に手書きすると、食い違ったときに「既定と同じなら保存しない」の判定が壊れる

## R15 性能

- **Decision**: 絞り込みは `rebuildListing()`（UI スレッド）で、`allFiles` の各項目の名前を1回ずつ照合する。ファイルシステムは読まない
- **Rationale**: 種類フィルタと同じ場所・同じ計算量（項目の数に比例）で、照合は `SearchPattern.matches(fileName:)`（名前の正規化と文字列の比較）。
  検索はこれを UI スレッドの外で使っているが、絞り込みは表示中の項目だけが対象
- **検証**: 10,000 件の一覧で `setNameFilter` の1回の所要時間を性能テストで測り、SC-209（100ms 以内）を確かめる（憲章 原則 II）。
  超える場合は、正規化した名前を項目ごとに控える方法へ直す

## R16 テストの範囲

- **CI で確かめる（Core・文言）**: `NameFilter`、`BrowserModel` の絞り込み（適用・`..`・解除・選択・検索結果・一致なしの状態）、`ToolbarLayout`、`ToolbarSearchInput`、
  コマンドの定義の整合、文言の翻訳、性能
- **保守者の GUI 確認**: 検索欄の見た目、入力のたびの反映、変換、×ボタン・Esc、虫眼鏡、⌥⌘F、有効・無効、カスタマイズ、VoiceOver、フォーカス中のコマンド
