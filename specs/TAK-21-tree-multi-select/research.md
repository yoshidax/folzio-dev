# Research: TAK-21 ツリーでのフォルダの複数選択と一括操作

調査基準: `origin/master` bc97861（2026-10-31）。静的調査のみ。AppKit の挙動のうち（R4・R5）は CI と保守者の GUI 確認で検証する。

## R1 対象の決定と可否を Core に置く

- **Decision**: `FolzioCore/Model/` に `TreeBatchTargets`（仮称）を追加する。入力は選択中の行の `TreeItemRole` の配列、操作を始めた行の role とそれが選択に含まれるか、
  ルートの一覧。出力は、操作の対象（FR-217）と、ゴミ箱・ドラッグ用の URL 配列（すべて通常のフォルダのときだけ）、単一の対象を前提とする操作の可否（FR-218）、
  親子の重なり（EC-146）。
- **Rationale**: 現行の `FavoriteCommands` は1行の role から判断している（`trashTarget`・`renameTarget` など）。複数の判断を同じ層に置けば、AppKit なしで
  Swift Testing で網羅できる（AGENTS.md「判断ロジックは Core」）。単一行は既存の `FavoriteCommands` に委ね、振る舞いを変えない。
- **Alternatives**: ViewController 内で判定する → テストできないため不採用。

## R2 親子の重なり（EC-146）は I/O なしで判定する

- **Decision**: ゴミ箱に入れる対象の重なりは `standardizedFileURL.pathComponents` の前方一致で判定する（UI スレッドで実行してよい）。
- **Rationale**: ツリーの行の URL は列挙で得た実際のパスで、シンボリックリンクを辿らない。`InternalDropValidation` の `resolvingSymlinksInPath` はディスクを読むため、
  メニューの有効化や ⌘⌫ の即時判定には使わない。移動・コピーは従来どおり `InternalDropValidation`（detached task）で検証する。
- **Alternatives**: 確認モーダルの前に detached task で `InternalDropValidation` を流用 → 宛先がない操作には合わず、`.overlappingSources` 以外の結果も混ざるため不採用。

## R3 ゴミ箱の実行と確認は既存の経路を使う

- **Decision**: `FileOperationCoordinator.trash(_:origin: .tree)` に複数の URL を渡す。確認モーダルの `location` を、複数のときは各フォルダの「名前 — 絶対パス」の行
  （先頭5件と残りの件数）に変える。`ConfirmationPolicy` は変えない（`.tree` は省略不可のまま）。
- **Rationale**: `trash` は既に URL 配列を受け取り、失敗の表示・履歴からの除去・`leaveTrashedFolders` を配列で扱う。`FolderNavigation.folderToShow(afterTrashing:)` も配列を受け取る。
  現状は `location: urls.first?.path` で1件目のパスしか出さないため、ここだけを複数に対応させる。
- **Alternatives**: 新しい確認モーダルを作る → 既存の文言・件数表示（`dialogConfirmItems`・`dialogConfirmMore`）を再利用できるため不要。

## R4 主の行（FR-216）の追跡

- **Decision**: 選択を広げる操作（⌘クリック・Shift クリック・Shift+↑↓）は、すべて `DragAwareOutlineView` が自分で処理し、AppKit の範囲選択を使わない。
  - `mouseDown(with:)`: 修飾キーが ⌘ または Shift だけ（Control・Option を含まない）で、行の上（開閉の三角を除く）を押したときは、`super` を呼ばずに選択を決める。
    ⌘ は行の追加・除外、Shift はアンカーから押した行までの範囲を `selectRowIndexes(_:byExtendingSelection: false)` で選ぶ。それ以外のクリックは従来どおり `super`
    （通常のクリック・ダブルクリック・ドラッグ・開閉の三角）。Control クリックは右クリックメニュー（`menu(for:)`）のままにする。
  - `keyDown(with:)`: Shift+↑↓ を処理し、主の行を1行動かして、アンカーから主の行までを選ぶ。Shift なしの ↑↓ は主の行の前・次の1行を選ぶ（複数選択の解除を含む）。
    ほかのキーは `super`（`ListModeView.keyDown` と同じ形）。
  - 主の行とアンカーは item で持つ（data-model.md）。`outlineViewSelectionDidChange` は、主の行が変わったときだけ主の行の role で `model.selectFolder` を呼ぶ。
- **Rationale**: `NSTableView` は Shift の範囲選択の起点（アンカー）と端（lead）を公開していない。AppKit の内部の起点に合わせる方式では、どちらの起点が使われるかを
  コードから確定できない（前回まで「未検証」としていた点）。修飾キー付きのクリックと Shift+↑↓ を自前で扱えば、起点・主の行・選択の結果がこちらのコードだけで決まり、
  AppKit の内部の状態に依存しない。通常のクリックとドラッグは `super` に任せるため、現行のドラッグ・ダブルクリック・開閉の振る舞いは変わらない。
- **Alternatives**: AppKit の範囲選択を使い、選択の差分から主の行を推定 → Shift で縮めたときの主の行と、Shift クリックの起点が AppKit の内部の状態次第になるため不採用。
- **制約**: ⌘・Shift を押しながらの行からのドラッグは始まらない（`super` を呼ばないため）。修飾キー付きのドラッグは現行の仕様にない操作で、Option（コピー）はドロップ時に
  押すキーのため影響しない。
- **同期による更新**: `syncSelection`（ファイルリストのフォルダを開く・親に戻る・履歴・検索結果から開く）で1行を選択したときは、アンカーと主の行をその行にする（FR-216）。
- **検索結果の表示中のクリック**: 現行は `trackingEnded` で「選択が変わらなければ `clickedRow`（FR-086）」としている。複数選択の中の行の通常のクリックは選択を1行に縮めるため
  選択が変わる。主の行が変わらない場合も、クリックによる縮小なら `clickedRow` と同じく検索結果の表示を終える（FR-216）。

## R5 ドラッグの対象と選択の復元

- **Decision**: `DragAwareOutlineView` で `canDragRows(with:at:)` を override し、ドラッグを始める前に可否を決める。`rowIndexes` の各行の role から `TreeBatchTargets` を作り、
  `dragURLs` が nil（通常のフォルダ以外を含む）なら false を返してドラッグを始めない（FR-218（1））。可のときは `super` の結果を返す。
  `pasteboardWriterForItem` は従来どおり通常のフォルダの行だけに URL を返す（`canDragRows` を通った後は全行が URL を返すので、除外は起きない）。
  ドラッグ後の選択の復元（現行は `previousRow` の1行）を、ドラッグ前の選択全体（`IndexSet`）と主の行に広げる。
- **Rationale**: Apple の文書で次を確認した（2026-10-31、developer.apple.com の JSON 版）。
  `NSTableView.canDragRows(with rowIndexes: IndexSet, at mouseDownPoint: NSPoint) -> Bool` は「Return false to disallow the drag」。
  `tableView(_:pasteboardWriterForRow:)` は「Returning nil excludes the row from being dragged」。つまり nil を返す方式は一部の行を黙って除くため、EC-121 の
  「黙って除外しない」に反する。`canDragRows` ならドラッグ全体を開始前に拒否でき、AppKit の除外の振る舞いに依存しない。
  `rowIndexes` は AppKit がドラッグしようとする行（選択中の行からなら選択全体、選択外の行ならその行）で、FR-217（3）の対象と一致する。一致しない場合に備え、
  `TreeBatchTargets` の対象と `rowIndexes` の行の集合が異なるときも false を返す。
- **Alternatives**: `pasteboardWriterForItem` で全行に nil を返す → 文書上の意味は「各行の除外」で、全行の除外でドラッグが始まらないことは文書に書かれていないため不採用。

## R6 操作後のツリーの選択（FR-219）

- **Decision**: ツリーからの移動・ゴミ箱で1件以上が成功したら、ツリーは主の行（R4 で item として保持）を単一選択する。`syncSelection` と同じく
  `isRestoringSelection` の下で選択し、`selectFolder` を呼ばない。主の行が消えて表示中のフォルダが変わる場合（FR-079・EC-123）は、既存の `treeSyncRequest` による同期に任せる。
  コピー・キャンセル・すべて失敗では何もしない。表示中のフォルダが変わるかは `leaveTrashedFolders` の戻り値（ゴミ箱）と、移動の後の `listing.folder` の変化で判断し、
  変わったときは主の行の選択を行わない（同期が切り替え後の行を選ぶ）。
- **Rationale**: 消えた行の選択は AppKit が外すが、残った行の選択が不定になる。表示の元である主の行に揃えれば、FR-079 の「表示を変えない」と整合し、
  お気に入りの項目から表示している場合も実際の階層の行へ選択が移らない（US1-AS44 の「選択は A のまま」も保つ）。
- **Alternatives**: 失敗した項目の選択を保つ（ファイルリストの FR-165 に近い）→ A-128 のとおり不採用。

## R7 単一の対象を前提とする操作の無効化

- **Decision**: `validateMenuItem` と `menuNeedsUpdate`、`MainSplitViewController.canAddSelectedFolderToFavorites` の判断を、`TreeBatchTargets` の「単一の対象か」に通す。
  Return（`rename(_:)`）・⌘V・⌥⌘V・⌥⌘C は対象が複数なら何もしない。
- **Rationale**: 現行の `selectedItem` は `selectedRow`（複数選択では最後に選択した行）を返すため、そのままだと複数選択でも1行に対して実行してしまう。
- **影響する呼び出し**: `DirectoryTreeViewController` の `selectedItem` の利用（20 か所程度）、`MainSplitViewController` の 1014・1137 行付近。

## R8 ⌘A（A-126）

- **Decision**: ツリーにフォーカスがあるときの `selectAll(_:)` を無効にする（validate で false、実行しても何もしない）。
- **Rationale**: `allowsMultipleSelection = true` にすると `NSTableView` の既定の `selectAll:` が全行を選ぶようになり、A-126 に反する。

## R9 折りたたみで隠れる選択（EC-148）

- **Decision**: 2行以上を選択しているとき、`outlineViewItemWillCollapse`（現行は編集の確定だけを行う）で、折りたたむフォルダの子孫に当たる選択中の行を、
  `isRestoringSelection` の下で自分で選択から外す。`outlineViewItemDidCollapse` で、選択が外した後の集合と一致しなければ（AppKit が親を選んだ場合など）、
  同じく `isRestoringSelection` の下で外した後の集合に戻す。どちらも `model.selectFolder` を呼ばない。主の行が隠れた場合も主の行（item）は保ち、表示を変えない。
  隠れた主の行からのキーボードの移動は、主の行を隠したフォルダの行を起点にする（EC-148）。
- **Rationale**: 隠れた子の選択を AppKit がどう扱うか（外す・親へ移す）は文書に書かれていない（`collapseItem(_:collapseChildren:)` の文書は折りたたみと通知だけを述べる）。
  折りたたむ前に自分で外し、後で結果を検査して戻せば、AppKit の扱いに依存せずに EC-148 の結果が決まる。
- **範囲**: 1行だけを選択しているときの折りたたみは、現行の振る舞い（AppKit の既定）を変えない。現行仕様にこの場合の規定がなく、この feature の目的の外のため（A-131）。
