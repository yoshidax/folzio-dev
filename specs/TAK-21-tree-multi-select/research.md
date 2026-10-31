# Research: TAK-21 ツリーでのフォルダの複数選択と一括操作

調査基準: `origin/master` bc97861（2026-10-31）。静的調査のみ。AppKit の挙動のうち（R4・R5）は CI と保守者の GUI 確認で検証する。

## R1 対象の決定と可否を Core に置く

- **Decision**: `FolzioCore/Model/` に `TreeBatchTargets`（仮称）を追加する。入力は選択中の行の `TreeItemRole` の配列、操作を始めた行の role とそれが選択に含まれるか、
  ルートの一覧。出力は、操作の対象（FR-210）と、ゴミ箱・ドラッグ用の URL 配列（すべて通常のフォルダのときだけ）、単一の対象を前提とする操作の可否（FR-211）、
  親子の重なり（EC-141）。
- **Rationale**: 現行の `FavoriteCommands` は1行の role から判断している（`trashTarget`・`renameTarget` など）。複数の判断を同じ層に置けば、AppKit なしで
  Swift Testing で網羅できる（AGENTS.md「判断ロジックは Core」）。単一行は既存の `FavoriteCommands` に委ね、振る舞いを変えない。
- **Alternatives**: ViewController 内で判定する → テストできないため不採用。

## R2 親子の重なり（EC-141）は I/O なしで判定する

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

## R4 主の行（FR-209）の追跡

- **Decision**: `DragAwareOutlineView` で主の行を記録する。マウスは `clickedRow`（⌘クリックで外した場合は更新しない）、キーボードは Shift+↑↓ を
  サブクラスで処理し、アンカーから主の行までの範囲を自分で選択する。`outlineViewSelectionDidChange` は、選択が1行のときは従来どおり、複数のときは主の行の role で
  `model.selectFolder` を呼ぶ。主の行が変わらない選択の変化（⌘クリックで外す・折りたたみで外れる）では呼ばない。
- **Rationale**: `NSTableView` は Shift の範囲選択の端（lead）を公開していない。Shift+↑↓ を自前で扱えば、主の行が決定的になりテストしやすい。
  Shift クリックのアンカーは AppKit が最後のクリックの行を使うため、自前のアンカーも最後のクリックの行（⌘クリックを含む）に揃える。
- **Alternatives**: 選択の差分から推定 → Shift で縮めたときの主の行が曖昧になるため不採用。
- **同期による更新**: `syncSelection`（ファイルリストのフォルダを開く・親に戻る・履歴・検索結果から開く）で1行を選択したときは、アンカーと主の行をその行にする（FR-209）。
- **検索結果の表示中のクリック**: 現行は `trackingEnded` で「選択が変わらなければ `clickedRow`（FR-086）」としている。複数選択の中の行の通常のクリックは選択を1行に縮めるため
  選択が変わる。主の行が変わらない場合も、クリックによる縮小なら `clickedRow` と同じく検索結果の表示を終える（FR-209）。
- **未検証**: Shift クリックのアンカーが自前のアンカーと一致するか。GUI 確認（quickstart の S3）で確かめる。

## R5 ドラッグの対象と選択の復元

- **Decision**: `pasteboardWriterForItem` で、ドラッグする行が選択中で、選択中の行に通常のフォルダ以外が含まれるときは、すべての行に nil を返してドラッグを始めない（FR-211）。
  ドラッグ後の選択の復元（現行は `previousRow` の1行）を、ドラッグ前の選択全体（`IndexSet`）に広げる。
- **Rationale**: 複数選択の `NSOutlineView` は、選択中の行からのドラッグで選択中の全項目について `pasteboardWriterForItem` を呼び、nil の項目を黙って除く。
  除外を許すと EC-121 の「黙って除外しない」に反する。選択外の行からのドラッグは AppKit がその行だけを対象にし、現行は mouseDown で変わった選択を元に戻している。
- **未検証**: 一部の項目に nil を返したときの AppKit の振る舞い（ドラッグが始まらないこと）。CI ではなく GUI 確認（S5）で確かめる。

## R6 操作後のツリーの選択（FR-212）

- **Decision**: ツリーからの移動・ゴミ箱で1件以上が成功したら、ツリーは主の行（R4 で item として保持）を単一選択する。`syncSelection` と同じく
  `isRestoringSelection` の下で選択し、`selectFolder` を呼ばない。主の行が消えて表示中のフォルダが変わる場合（FR-079・EC-123）は、既存の `treeSyncRequest` による同期に任せる。
  コピー・キャンセル・すべて失敗では何もしない。表示中のフォルダが変わるかは `leaveTrashedFolders` の戻り値（ゴミ箱）と、移動の後の `listing.folder` の変化で判断し、
  変わったときは主の行の選択を行わない（同期が切り替え後の行を選ぶ）。
- **Rationale**: 消えた行の選択は AppKit が外すが、残った行の選択が不定になる。表示の元である主の行に揃えれば、FR-079 の「表示を変えない」と整合し、
  お気に入りの項目から表示している場合も実際の階層の行へ選択が移らない（US1-AS44 の「選択は A のまま」も保つ）。
- **Alternatives**: 失敗した項目の選択を保つ（ファイルリストの FR-165 に近い）→ A-121 のとおり不採用。

## R7 単一の対象を前提とする操作の無効化

- **Decision**: `validateMenuItem` と `menuNeedsUpdate`、`MainSplitViewController.canAddSelectedFolderToFavorites` の判断を、`TreeBatchTargets` の「単一の対象か」に通す。
  Return（`rename(_:)`）・⌘V・⌥⌘V・⌥⌘C は対象が複数なら何もしない。
- **Rationale**: 現行の `selectedItem` は `selectedRow`（複数選択では最後に選択した行）を返すため、そのままだと複数選択でも1行に対して実行してしまう。
- **影響する呼び出し**: `DirectoryTreeViewController` の `selectedItem` の利用（20 か所程度）、`MainSplitViewController` の 1014・1137 行付近。

## R8 ⌘A（A-119）

- **Decision**: ツリーにフォーカスがあるときの `selectAll(_:)` を無効にする（validate で false、実行しても何もしない）。
- **Rationale**: `allowsMultipleSelection = true` にすると `NSTableView` の既定の `selectAll:` が全行を選ぶようになり、A-119 に反する。

## R9 折りたたみで隠れる選択（EC-143）

- **Decision**: 折りたたみで隠れた行は AppKit の既定どおり選択から外し、ファイルリストの表示は変えない（主の行が隠れた場合も変えない）。
- **未検証**: `NSOutlineView` が隠れた子の選択を親に移すかどうか。移す場合は `outlineViewItemDidCollapse` で親の選択を外し、`isRestoringSelection` で `selectFolder` を抑止する。GUI 確認（S7）で確かめる。
