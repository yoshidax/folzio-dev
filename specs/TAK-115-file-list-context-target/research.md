# Research: ファイルリストの右クリックの対象をツリーに合わせる

当初は「選択外の項目を右クリックしたらその項目を選択する」方式で実装した（03fca52）。保守者の見直しで、ツリー（A-21）と同じく
「選択を変えずに、右クリックした項目を対象にする」方式に改めた。以下は改めた後の決定である。

## R1 対象の決め方と置き場所

- **Decision**: 右クリックした項目の位置（背景なら nil）と選択中の項目の位置から、メニューの対象を
  「背景」「選択中の全体」「その項目だけ」のどれかに決める処理を、`FolzioCore` の `ContextMenuTarget` に純粋な関数として置く。
- **Rationale**: 憲章の原則 IV と AGENTS.md の「判断ロジックは `FolzioCore`」に従う。ツリーの `TreeBatchTargets`
  （右クリックした行が選択中なら選択全体、選択外ならその行だけ）と同じ規則で、リスト形式とサムネイル形式が共有する。
- **Alternatives considered**: 当初の方式（右クリックで選択を変える）。保守者の決定により採らない。

## R2 メニューを開いたときの対象の記録

- **Decision**: `FileContextMenu.menuNeedsUpdate(_:)` で、右クリックした項目の位置（リスト形式は `clickedRow`、
  サムネイル形式は `lastMenuLocation` の項目）から対象を決め、`FileListViewController` に記録する。
  次にメニューを開くまで、その記録を使う。
- **Rationale**: メニューの項目の有効・無効（`validateMenuItem(_:)`）と文言は、メニューを開く前に決まっている必要がある。
  AppKit はメニューの項目の action を、メニューを閉じた後（`menuDidClose(_:)` の後）に送るため、閉じたときに記録を消すと
  action が対象を失う。

## R3 操作の対象の切り替え

- **Decision**: `FileListViewController` の各 action と `validateMenuItem(_:)` は、`sender` が右クリックメニュー
  （`fileContextMenu.menu`、またはその下の「このアプリケーションで開く」のサブメニュー）の項目なら記録した対象を、
  そうでなければ従来どおり選択を使う。対象は「URL の一覧」「操作の可否（`ListItemCommands`）」「名前を変える項目」
  「中を表示する項目」をまとめた1つの値（`OperationTarget`）として渡す。
- **Rationale**: 右クリックメニューとメニューバーは同じ action を共有している。`sender` で分けると、キーボードと
  メニューバーの操作は選択を対象にしたまま（A-239）、右クリックメニューだけを切り替えられる。
- **Alternatives considered**: ツリーと同じく各メニューの項目の `representedObject` に対象を持たせる。
  右クリックメニューの項目はメニューバーの項目と同じ action・同じ文言の束縛（`MainMenu.bind`）を使っており、
  メニューを開くたびに項目へ値を配るより、1か所に記録する方が変更が少ない。

## R4 名前の変更（FR-398）

- **Decision**: リスト形式は `ListModeView.beginRenaming` に、名前を変える項目の URL を受け取る形を加え、
  選択とフォーカスのある項目を条件にしない。サムネイル形式は既存の `beginRenamingItem(_:)`（選択を条件にしない）を使う。
- **Rationale**: 名前の編集を終えた後の確定・検証・確認は、既存の経路のままにできる。

## R5 右クリックした項目の枠

- **Decision**: リスト形式は `NSTableView` が右クリックした行に描く標準の枠を使う。サムネイル形式は、
  メニューを表示している間だけ、右クリックした項目（選択外のとき）に選択の枠と同じ色の枠を描き、`menuDidClose(_:)` で消す。
- **Rationale**: `NSCollectionView` には右クリックした項目を示す標準の表示がない。選択とは別の項目が対象になることを、
  2つの形式で同じように示す。

## R6 名前の編集中の右クリック（EC-265）

- **Decision**: ツリーと同じく、`menuNeedsUpdate(_:)` の最初で、ファイルリストの名前の編集を確定して終える。
- **Rationale**: ツリーの `menuNeedsUpdate(_:)` と同じ扱い。編集中の項目が対象のまま残ることを防ぐ。
