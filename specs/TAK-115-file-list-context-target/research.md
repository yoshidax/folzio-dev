# Research: ファイルリストの右クリックの対象を Finder に合わせる

## R1 選択を変える契機

- **Decision**: リスト形式の `NSTableView` とサムネイル形式の `NSCollectionView` のサブクラスで `menu(for:)` を
  override し、`super.menu(for:)` を返す前に、右クリックした位置の項目を選択する。
- **Rationale**: `menu(for:)` は右クリック・Control クリック・2本指のクリックのすべてで、メニューを出す前に呼ばれる（A-237）。
  `FileContextMenu.menuNeedsUpdate(_:)` より前に選択が変わるため、メニューの文言（「“B”をコピー」など）と
  各操作の対象（`selectedFileURLs`）が、追加の引数なしに右クリックした項目になる。
  列見出しの右クリックは `NSTableHeaderView` が処理し、この経路を通らない（A-239）。
- **Alternatives considered**:
  - 選択を変えずに、メニューの各操作へ「右クリックした項目」を渡す（ツリーの A-21 の方式）。
    保守者の決定（Finder と同じく選択する）と異なり、メニューの操作ごとに対象の決め方を変える必要がある。
  - `rightMouseDown(with:)` を override する。Control クリックはこの経路を通らないため、取りこぼす。

## R2 判断ロジックの置き場所

- **Decision**: 「右クリックした項目と今の選択から、新しい選択を決める（変えないなら nil）」を、`FolzioCore` の
  `ContextClickSelection` に純粋な関数として置き、単体テストで確かめる。
- **Rationale**: 憲章の原則 IV と AGENTS.md の「判断ロジックは `FolzioCore`」に従う。リスト形式とサムネイル形式で同じ規則を共有できる。
- **Alternatives considered**: 2つのビューにそれぞれ条件を書く。規則が食い違うおそれがあり、AppKit なしにテストできない。

## R3 選択の変更の通知

- **Decision**: リスト形式は `selectRowIndexes(_:byExtendingSelection: false)` で選択し、`tableViewSelectionDidChange(_:)`
  から従来どおり `BrowserModel.select(_:focused:)` を呼ぶ。サムネイル形式は `selectionIndexPaths` を設定してから、
  クリックで選んだときと同じ `selectionDidChange(newlySelected:)` を呼び、範囲選択の起点（`selectionAnchor`）も
  右クリックした項目にする。
- **Rationale**: `NSTableView` はプログラムからの選択でも選択の変更を通知するが、`NSCollectionView` はプログラムからの選択では
  `didSelectItemsAt` を呼ばない。どちらも既存の経路を通すことで、プレビューの切り替えと動画の停止（EC-266）が、
  クリックで選んだときと同じになる。

## R4 名前の編集中の右クリック（EC-265）

- **Decision**: 名前の編集中に選択外の項目を右クリックしたときは、選択を変える前に、編集中のフィールドから
  一覧のビューへ first responder を戻して編集を終える（確定は既存の `controlTextDidEndEditing(_:)`・
  `textDidEndEditing(_:)` の規則のまま）。
- **Rationale**: 名前の編集中のキーボードフォーカスはもともとファイルリストにあるため、一覧のビューへ戻しても
  ペインのフォーカスは移らない（A-238 と矛盾しない）。ほかの項目をクリックしたときと同じ確定の経路を使える。

## R5 キーボードフォーカス（A-238）

- **Decision**: 名前の編集中の場合を除き、右クリックでは `makeFirstResponder(_:)` を呼ばない。
- **Rationale**: 現行の右クリックはフォーカスを移さない。FR-079（file-operations.md）も、右クリックメニューからの削除では
  フォーカスを移さないと定めている。
