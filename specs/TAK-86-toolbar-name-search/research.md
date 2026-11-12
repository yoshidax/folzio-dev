# Research: TAK-86 ツールバーの名前検索欄

調査の基準は、作業ブランチ `claude/peaceful-bell-dj1h3u`（`origin/master` の `d3fe85b` を含む）のコード。
Cloud には Swift と macOS がないため、AppKit の実際の動作は確かめていない。確かめていない点は各項目の「未確認」に書き、quickstart.md の GUI 確認で確かめる。

## R1 ツールバー項目の種類

- **Decision**: 既存のセットと同じく、通常の `NSToolbarItem` の `view` に検索フィールド（`NSSearchField` のサブクラス `ToolbarSearchField`）を置く。
  幅は Auto Layout の固定の制約（180pt）にする（サムネイルサイズのスライダーと同じ方法。`MainToolbarController.makeSizeSlider()`）
- **Rationale**: `MainToolbarController` は「項目ごとに新しいコントロールを作り、状態は `toolbar.items` を識別子で探して適用する」構成（TAK-23 の R-2）で、
  同じ構成に乗せられる。あふれたとき・文字だけの形式の動作を `menuFormRepresentation` で自分で決められる（FR-389）
- **Alternatives considered**: `NSSearchToolbarItem`（macOS 11 以降）。狭いときに虫眼鏡のボタンへ畳まれて押すと広がる標準の動作を持つが、
  その畳まれる動作と文字だけの形式の動作を Cloud で確かめられず、FR-389（あふれたら検索のモーダルを開く）と両立するか分からないため採らない

## R2 虫眼鏡アイコンの押下

- **Decision**: `NSSearchFieldCell.searchButtonCell` の `target` と `action` を差し替え、押下で `MainToolbarController` の `showSearch(_:)` を呼ぶ。
  虫眼鏡だけのツールチップは、`ToolbarSearchField` が `searchButtonRect(forBounds:)` の矩形に `addToolTip(_:owner:userData:)` で付け、レイアウトのたびに付け直す
- **Rationale**: `searchButtonCell` は差し替えと設定のために公開されているセルで、`NSSearchField` は `searchButtonRect(forBounds:)` を公開している（A-227）
- **未確認**: 差し替えた `action` が押下で呼ばれること、既定の動作（検索の `action` の送信）が同時に起きないこと、矩形のツールチップが出ること、
  VoiceOver が虫眼鏡を別の要素として読むこと。GUI 確認で確かめる（quickstart.md の 3）
- **代替（確認で動かなかった場合）**: `ToolbarSearchField` で `mouseDown(with:)` を上書きし、クリックの位置が `searchButtonRect(forBounds:)` の中なら同じ処理を呼ぶ

## R3 Return での検索

- **Decision**: 検索フィールドの `action` は使わない。`NSSearchFieldDelegate` の `control(_:textView:doCommandBy:)` で `insertNewline(_:)` を受けたときだけ検索を始め、`true` を返す
- **Rationale**:
  - 検索フィールドの `action` は、×ボタンの押下や編集の終了でも送られ得るため、「Return を押したときだけ」（FR-382）を `action` だけでは保証しにくい
  - 日本語入力の変換中の Return は入力メソッドが処理し、`insertNewline(_:)` はデリゲートへ届かない。変換の確定では検索が始まらない（FR-382・US81-AS7）
  - 検索のモーダルも `NSSearchFieldDelegate` を使っている（`SearchPanelController`）
- **未確認**: 変換の確定の Return で `insertNewline(_:)` が届かないこと。GUI 確認で確かめる（quickstart.md の 2）

## R4 ×ボタンと Esc

- **Decision**: 標準の検索フィールドのクリア（×）ボタンと Esc の動作（文字を消す）をそのまま使い、独自の処理を足さない。
  文字を消したときに検索の処理を呼ばない（R3 で `action` を使わないため、自然にそうなる）
- **Rationale**: Issue の検討事項「×ボタンの表示・クリアは、標準の検索フィールドの機能で実現できるか」への回答。
  `NSSearchField` は、文字が入ると×ボタンを表示し、押すと文字を消して隠す（FR-381・A-227）
- **未確認**: 表示の細部（1文字目で現れること）。GUI 確認で確かめる（quickstart.md の 1）

## R5 検索の起点

- **Decision**: 起点は `model.listing.folder` とする。検索のモーダルの既定の起点（`MainSplitViewController.showSearch(_:)` の `rootPath: model.listing.folder.path`）と同じ式を使う
- **Rationale**: FR-383 は起点を「検索のモーダルの既定の起点と常に同じフォルダ」と定める。同じ式を使えば、ツリーの単一選択・複数選択（FR-216）・検索結果の表示中・
  zip の中・EC-102 のどの状態でも、モーダルと同じ起点になることが構成から保証される（SC-208）。ツリーの選択を別に読む経路を作らない
- **Alternatives considered**: ツリーの選択（`DirectoryTreeViewController` の主の行）を直接読む。EC-102 と「お気に入り」の見出しで一覧と食い違い、状態ごとの分岐が要るため採らない（A-223）

## R6 起点の検証と失敗時の扱い

- **Decision**: Return で `SearchRoot.validate(_:)`（UI スレッドの外で実行される既存の検証）を呼び、成功したら `model.startSearch(_:root:)` を呼ぶ。
  失敗したら、検索のモーダルを、検索欄のキーワードと起点のパスを入れ、理由を表示した状態で開く。`SearchPanelController` に初期の理由（`SearchRootError?`）を渡す引数を加える
- **検証の間の変化**: 検証は非同期なので、終わった時点で (1) `model.listing.folder` が Return の時点と同じ、(2) `paneCommands.canSearch` が真、
  (3) メインウインドウにシートがない、の3つを確かめ、満たさなければ結果を捨てる（何もしない）。続けて Return を押した場合は、前の検証のタスクを取り消す
- **Rationale**: 検索のモーダルで「検索」を押して検証に失敗した場合と同じ状態にすると、理由の表示と起点の選び直しを既存の画面で行える（EC-252）。
  理由の文言は既存の `l10n.text(for: SearchRootError)` を使い、新しい文言を足さない
- **Alternatives considered**: 警告のダイアログだけを出す。理由は伝わるが、起点を選び直すには改めてモーダルを開く必要があるため採らない

## R7 有効・無効

- **Decision**: 検索フィールドの `isEnabled` と項目の `isEnabled` を `panes.paneCommands.canSearch`（⌘F と同じ条件。`PaneLayout.swift`）にする。
  適用は、既存の更新の経路（`apply(paneLayout:)`、`updateSlideshowAvailability()`、`applyState(to:)`）から呼ぶ `applySearchAvailability()` で行う
- **Rationale**: `canSearch` は「フルスクリーンでない・名前の変更中でない・ファイルリストが表示されている」で、FR-388 の条件そのもの。
  名前の変更の開始と終了は、既存の `observeEditingAvailability()` の通知で `updateSlideshowAvailability()` が呼ばれる
- **注意**: `observeEditingAvailability()` は `object: nil` で全コントロールの編集の通知を受けるため、ツールバーの検索欄自身の編集でも呼ばれる。
  `canSearch` の `isEditingText` はファイルリストの名前の変更だけを指す（`fileListViewController.isEditingText`）ので、検索欄の編集では無効にならない
- **未確認**: フルスクリーンへの出入りで上の経路のどれかが呼ばれること（実装の時にコードで確かめ、足りなければ呼び出しを足す）。
  名前の変更中に検索欄を押したときの名前の変更の扱い（FR-388 は「ほかの場所を押した場合と同じ」とする）

## R8 並びの既定値と保存

- **Decision**: `ToolbarLayout.setIdentifiers` に `"search"` を加え、`defaultOrder` を「8つのセット → `NSToolbarFlexibleSpaceItem` → `search`」にする。
  `normalized(saved:)` の規則は変えない。`MainToolbarController` の `toolbarDefaultItemIdentifiers` と `toolbarAllowedItemIdentifiers` は、
  手書きの配列をやめて `ToolbarLayout.defaultOrder`・`ToolbarLayout.setIdentifiers` から作る
- **Rationale**:
  - 可変スペースを検索の左に置くと、検索欄が右端に寄る（FR-380・FR-233（変更））
  - 保存は「既定の並びと違うときだけ」行う（`saveConfiguration()`）。カスタマイズしていない利用者は保存値がなく、新しい既定の並びに従う（US83-AS1）。
    保存済みの並びは `search` を含まないまま有効で、そのまま復元される（FR-390・US83-AS2）
  - 既定の並びを Core とデリゲートの2か所に手書きすると、食い違ったときに「既定と同じなら保存しない」の判定が壊れる。1か所にまとめる
- **前の版へ戻した場合**: `search` を含む保存値は、前の版では未知の識別子を含む値として既定の並びになる（EC-165・A-225）。データは壊れない
- **未確認**: `NSToolbarItem.Identifier.flexibleSpace.rawValue` が `"NSToolbarFlexibleSpaceItem"` であること（既存の保存と復元が同じ前提で動いている。
  `ToolbarLayout.flexibleSpaceIdentifier` のコメント）

## R9 文言

- **Decision**: `TextKey` に3つ加える。
  - `toolbarSearchLabel`（`toolbar.searchLabel`）: 「検索」 / `Search`。セットのラベル（FR-236（変更））
  - `toolbarSearchPlaceholder`（`toolbar.searchPlaceholder`）: 「名前で検索」 / `Search by Name`。プレースホルダとアクセシビリティのラベル
  - `toolbarSearchFindHelp`（`toolbar.searchFindHelp`）: 「検索…（%1$@）」 / `Find… (%1$@)`。虫眼鏡のツールチップとアクセシビリティのラベル。
    引数はショートカットの表記で、`ToolbarShortcutText.commands(for:)` に `.find` を対応させる（FR-237）
- **Rationale**: メニューの項目名（`menuFileFind`）と共用しない（FR-236・FR-237）。表示言語とショートカットの割り当ての変更は、既存の `displayLanguageDidChange()` で更新する（EC-255）

## R10 文字だけの形式とあふれたメニュー

- **Decision**: 項目に `menuFormRepresentation`（名前は `toolbarSearchLabel`、`action` は `showSearch(_:)`、`target` は `MainToolbarController`）を設定する。
  `validateMenuItem(_:)` で `canSearch` を返す（スライドショーの項目と同じ方法）
- **未確認**: 文字だけの形式で、`view` を持つ項目を押したときに `menuFormRepresentation` の `action` が呼ばれること。GUI 確認で確かめる（quickstart.md の 6）

## R11 検索欄にフォーカスがある間のコマンド

- **調査**: メニューの項目は `target = nil` で、レスポンダチェーンから `MainSplitViewController` などを探す（`MainMenu.swift`）。
  ツールバーのビューはウインドウの content view の外にあるため、検索欄が first responder の間、チェーンは「検索欄 → ツールバーのビュー → ウインドウ」と進み、
  content view の下の view controller（ファイルリスト・ツリー・`MainSplitViewController`）を通らないと考えられる
- **Decision**:
  - ファイル操作のコマンドを検索欄から content 側へ転送しない。検索欄にフォーカスがある間、⌘⌫ などは検索欄の文字の編集になるか、無効になる（EC-258・SC-212）
  - ⌘F だけは、`ToolbarSearchField` の `supplementalTarget(forAction:sender:)` で `showSearch(_:)` に限って `MainToolbarController` を返し、
    虫眼鏡と同じ処理（キーワードを引き継いでモーダルを開く）へつなぐ（FR-386・US82-AS5）
- **未確認**: 上のチェーンの理解（content 側へ届かないこと）。GUI 確認で、検索欄にフォーカスを置いて ⌘⌫・⌘C・⌘V・⌘D を押し、選択中のファイルに何も起きないことを確かめる（quickstart.md の 5）。
  届いてしまう場合は、実装の中で止める方法（検索欄の編集中はファイル操作を無効にする条件を足す）を保守者と相談する

## R12 テストの範囲

- **CI で確かめる（Core・文言）**: `ToolbarLayout` の既定の並びと保存値の扱い、引き継ぐキーワードの決め方（`ToolbarSearchInput`）、新しい文言の翻訳
- **保守者の GUI 確認**: 検索欄の見た目、×ボタン、Return、変換の確定、虫眼鏡、有効・無効、カスタマイズ、文字だけの形式、VoiceOver、フォーカス中のコマンド
- **Rationale**: `MainToolbarController` と `SearchPanelController` は AppKit の画面で、既存のテスト（`Tests/FolzioAppTests`）にも対象がない。
  判断を Core の小さな型へ出し、残りは quickstart.md の手順で確かめる（憲章 原則 IV）
