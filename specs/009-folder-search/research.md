# Research: 検索でフォルダも検索対象にする

**Date**: 2026-10-27 | **Branch**: `009-folder-search`

調査入力は [spec.md](spec.md)、spec が参照する `specs/product/` の領域（search.md・file-list.md・file-operations.md・directory-tree.md・navigation-history.md・preview.md・zip.md・overview.md）、[contracts/keyboard-and-menus.md](../product/contracts/keyboard-and-menus.md)、憲章 v1.2.0、既存コード。以下の型・接続点は実装方針であり、実装済みの API ではない。

Technical Context に NEEDS CLARIFICATION は残っていない。spec の Clarifications（2026-10-27）の3点（既存の4項目のフォルダへの適用、EC-99 の履歴、EC-100 の zip の中で始めた検索）を前提とする。spec が定めていなかった1点（検索前の場所を含むフォルダの行をゴミ箱に入れた場合）は R8 で決め、spec に EC-101 として加えた（2026-10-27 にユーザーがゴミ箱・移動とも採用。tasks の T001 に記録済み）。ツリーに表示されないフォルダの同期は、同日の回答を EC-102 として spec に追加し、R10 に設計を記す。

## 既存コードの調査結果

| 領域 | 現状 | 本 feature への影響 |
|---|---|---|
| `FileNameSearcher`（`Search/FileNameSearcher.swift`） | `FileManager` の列挙器（`.skipsHiddenFiles`・`.skipsPackageDescendants`）で辿り、ディレクトリは `return nil` で捨てる。ファイルへのリンクはリンクの URL で返し、フォルダへのリンクは除く | ディレクトリを照合して `.folder` の行を返すように変える（R1） |
| `DirectoryLister.mediaFiles` | フォルダの行を `kind: .folder`・`typeDescription: "フォルダ"`・作成日・`fileSize: 0` で作る。パッケージは `isPackageKey` で除く | フォルダの行を作る関数を共有し、通常の一覧と検索結果で同じ値にする（R1） |
| `BrowserModel.rebuildListing` | メディアの有無は `allFiles`、それ以外の行は表示する行で判定する。メディアがなく、ほかの行があれば `.loaded` | FR-139・EC-96 の判定は既に満たす。変えない（R5） |
| `sorted`・`sortedMerge`・`SearchListing.location(of:)` | 種類で区別せず並べ、「場所」は親フォルダのパスで比べる。場所の文字列は `deletingLastPathComponent` | フォルダの行にもそのまま使える（R5） |
| `BrowserModel.openItem` の `.folder` | `navigateToFolder` → `selectFolder` → `resetForNavigation`（検索の列挙の取り消し）・`leaveSearchIfNeeded`（「場所」の並べ替えの解除）・`lastFolder` の保存・ツリーの同期の依頼 | 検索結果のフォルダの行を開く処理はほぼ既存の経路で足りる。履歴の通知だけを分ける（R6・R7） |
| `ListItemKind.opensAsContainer`・`ListItemCommands.canOpenContainer` | `.folder` は検索結果でも開ける判定になる。右クリックメニューの「中を表示」は常に出し、有効・無効を判定で決める（product の contracts/keyboard-and-menus.md の右クリックメニュー（ファイルリスト）は、フォルダ・zip ファイルの行にだけ「中を表示」を加えると定めており、既存の実装と食い違う。R6 の注記） | ⌘↓・ダブルクリック・右クリックメニューは追加の分岐なしで有効になる（R6） |
| `FocusNavigator`（フルスクリーンの移動）・`SlideshowSequence` | `kind.isMedia` でない行を飛ばす・含めない | FR-139 のフルスクリーンとスライドショーは変更不要 |
| `BrowserModel.didRenameFolder`・`rebaseSearchIndex` | 行の URL を付け替え、`.folder` の行が名前を変えたフォルダそのものなら名前も変える。索引は「結果を含むフォルダ」のキーごとに付け替える | キーが変わらないエントリ（名前を変えたフォルダの行そのもの）の URL が古いまま残る。直す（R4） |
| `BrowserModel.appendSearchResults` | 名前の変更より前の列挙の結果を `searchRenames` で付け替え、重複を捨てる。名前は付け替えない | フォルダの行の名前の付け替えと、未照合のフォルダの判定を加える（R3） |
| `FileOperationCoordinator.trash` | ゴミ箱の後に `leaveTrashedFolders` を呼び、表示中のフォルダ（検索中は検索前のフォルダ）かその祖先なら親へ移る。ファイルリストからは対象にならない前提 | 検索結果ではファイルリストから検索前のフォルダの祖先を選べるようになる。親へ移るかの判断（`BrowserModel.leaveTrashedFolders` → `FolderNavigation.folderToShow`）は操作の経路を受け取らないため、経路を渡して Core で判断する（EC-101・R8） |
| `HistoryNavigator.handleLocationEvent` | `.navigated` で、同じ場所なら現在の履歴の表示の状態を書き換え、違えば記録する | 違う場所でも先に表示の状態を反映してから判定する（R7） |
| `FileListViewController.refresh` | 検索結果の `.empty` に「該当するファイルはありません」 | 「該当する項目はありません」に変える（R5） |

## R1 — 照合の対象とフォルダの行の作り方

**Decision**: `FileNameSearcher` の列挙で、ディレクトリも名前（`lastPathComponent` 全体）を `SearchPattern` と照合する。一致の対象にするのは、`isDirectory == true` かつ `isSymbolicLink != true` かつ `isPackage != true` のディレクトリだけとする。`isPackage` は名前が一致したディレクトリにだけ問い合わせる。列挙器は起点そのものを返さないため、起点は対象にならない。隠しフォルダは `.skipsHiddenFiles` で中ごと飛ぶ。読み取り権限のないディレクトリは列挙器が URL を返してから中へ入れずに `errorHandler` へ渡すため、名前が一致すれば行になり、中は飛ばされる（EC-33・EC-91）。zip ファイルはディレクトリでも対応メディアでもないため行にならない（FR-083・A-79）。

フォルダの行は `DirectoryLister` に `folderRow(at:creationDate:)`（`internal static`）を置いて作る。`kind: .folder`、`name: url.lastPathComponent`、`typeDescription: "フォルダ"`、`creationDate`、`fileSize: 0` は通常の一覧の行と同じ値にする（FR-139）。作成日は一致したディレクトリだけ `.creationDateKey` で読む。URL は既存の `rebaser` で起点の形（`/var/...`）に組み直す。

照合の関数は `SearchPattern.matches(fileName:)` をそのまま使う。この関数は名前全体を正規化して比べ、拡張子を分けないため、「.」を含むフォルダ名も全体で照合される（FR-082・EC-97）。引数名は互換のため変えず、ドキュメントコメントに「ファイル名とフォルダ名」を記す。

**Rationale**: 1回の列挙の中で判定でき、走査の回数は変わらない。一致しないディレクトリには `isDirectory`・`isSymbolicLink`（既に先読みしているキー）しか使わないため、SC-054 の 10,000 件の階層でも追加の費用は名前の照合だけになる。フォルダの行を作る関数を共有すれば、通常の一覧と検索結果の値の差（US15-AS1 の種類・アイコン・作成日）をテストで固定できる。

**Alternatives considered**: 全ディレクトリに `isPackage` を問い合わせる（重い。名前の照合を先にすれば足りる）。`DirectoryLister.mediaFiles` を各フォルダで呼ぶ再帰（列挙器の取り消し・隠し・パッケージの扱いを作り直すことになる）。フォルダの行を検索結果専用の種類（`.searchFolder` など）にする（FR-139 の「通常のフォルダの行と同じく扱う」に反し、操作の判定がすべて分岐する）。

**Evidence**: FR-082・FR-083・FR-139、US15-AS1・AS2・AS6・AS9、EC-33・EC-91・EC-92・EC-97、A-78・A-79。`Search/FileNameSearcher.swift`、`FileSystem/DirectoryLister.swift`。

## R2 — 検索の要求と照合済みの記録

**Decision**: `FileNameSearching` の要求を `search(_ request: SearchRequest) -> AsyncStream<[MediaFile]>` の1つにする。`SearchRequest` は `root`・`pattern`・`matchesRoot`（起点そのものもフォルダとして照合するか。既定 false）・`visits`（`SearchVisitLog`）を持つ。既存の呼び出し（テスト・性能試験）のために、`search(in:matching:)` をプロトコル拡張で残し、`matchesRoot: false` と新しい記録で要求を作る。

`SearchVisitLog` は `final class`（`@unchecked Sendable`、`NSLock` で保護した `Set<String>`）で、列挙器がディレクトリを照合する直前に、その標準化したパス（起点の形に組み直したもの）を記録する。`BrowserModel` は列挙ごとに1つ作って要求に渡し、名前の変更のときに「そのフォルダを照合済みか」を問い合わせる（R3）。記録するのはディレクトリだけで、ファイルは記録しない。

**Rationale**: EC-94 の後半（検索中は、名前を変えた時点でまだ照合していないフォルダを照合する時点の名前で照合する）と FR-105 の「名前の変更を照合済みの項目の一致を判定し直す契機にはしない」を両立するには、名前を変えた時点で、列挙がそのフォルダに達していたかを知る必要がある。列挙は別スレッドで進むため、ロックで保護した記録を列挙と `BrowserModel` で共有するのが最小の仕組みになる。記録はディレクトリだけで、10,000 ファイルの階層では数百件、ホーム全体でも10万件程度（数 MB）に収まる。リポジトリの既存のロックは `NSLock` で、同じ書き方にそろえる。

**Alternatives considered**: 記録を持たず、名前を変えたフォルダを常に新しい名前で照合し直す（照合済みで一致しなかったフォルダが、名前の変更で一覧に加わり EC-94 の前半に反する）。記録を持たず、名前を変えたフォルダを常に照合しない（未照合のフォルダが古い名前でも新しい名前でも照合されず、EC-94 の後半に反する）。全項目（ファイルを含む）を記録する（メモリが件数に比例して増える。ファイルの判定には使わない）。`Synchronization.Mutex`（macOS 15 で使えるが、リポジトリの既存の書き方と異なる）。

**Evidence**: FR-085・FR-105、EC-52・EC-94。`Search/FileNameSearcher.swift`、`Archive/ArchiveAssetLoader.swift`（`NSLock` の既存例）。

## R3 — 検索中のフォルダの名前の変更

**Decision**: 検索中の名前の変更の付け替えと判定を、Core の値型 `SearchRenameLedger` にまとめる。`BrowserModel` の `searchRenames`（`[RenamedFolder]`）はこの型へ移す。

- 列挙を始めるたびに、その列挙の記録（`SearchVisitLog`）と、その時点までの名前の変更の件数を登録する。
- 結果のバッチは、その列挙を始めた後の名前の変更だけを順に当てて付け替える（既存は全件を当てていた。始めた後の列挙の URL は既に新しい場所のため、当てても変わらないが、当てる範囲を正しくする）。付け替えで `.folder` の行の URL の最後の要素が変わったら、`name` も新しい名前にする（FR-105 の「新しい名前で表示」。列挙が古い名前で照合して、結果が名前の変更の後に届いた場合）。
- 起点の配下のフォルダの名前を変えたとき、名前の変更より前に始めた列挙の記録に、そのフォルダの元の場所（その列挙が見た形へ、後の名前の変更を逆に当てて戻したもの）が1つでもあれば「照合済み」とする。
  - 照合済み: 既存どおり、新しい場所の中だけを追加で列挙する（`matchesRoot: false`）。そのフォルダが行なら、`didRenameFolder` が新しい名前に付け替える。行でなければ加えない（EC-94 の前半）。
  - 未照合: 新しい場所の追加の列挙を `matchesRoot: true` で始め、そのフォルダを新しい名前で照合する。あわせて、名前の変更より前に始めた列挙から、そのフォルダの元の場所そのものの結果が後から届いたら捨てる（列挙器は名前の変更の前に読んだ親の一覧から古い URL を返すことがあり、先読みした値で古い名前の照合が通ってしまうため）。
- 起点そのものか祖先の名前を変えた場合は、既存どおり新しい起点を `matchesRoot: false` で列挙し直す（起点は行にしない）。
- 重複は既存どおり「同じ標準化したパスが既に一覧にある結果を捨てる」で除く。親の一覧の読み込みが名前の変更の後なら、元の列挙も新しい名前でそのフォルダを返すが、追加の列挙との重複として1件になる。

判定の順序の根拠: 名前の変更はディスク上で終わってから `didRenameFolder` が呼ばれる。列挙はディレクトリを照合する直前に記録するため、問い合わせの時点で記録がなければ、そのフォルダの照合は名前の変更の後に起きる。そのときの結果は「捨てる」規則に当たり、新しい名前の照合だけが残る。記録があれば、照合は名前の変更より前に古い名前で行われており、その結果（一致していれば行）を新しい場所へ付け替えて残す。

**Rationale**: EC-52・EC-94・FR-105 の「名前を変える前に見つかった項目は新しい場所で残す」「照合済みは判定し直さない」「未照合は照合する時点の名前で」を、ディスクを読み直さずに満たす。判定を値型に置くことで、列挙の進み具合と名前の変更の順序の組み合わせを、偽の検索器（`FakeSearcher`）と記録を使って AppKit なしで単体テストできる（憲章 IV）。

**Alternatives considered**: 名前の変更のたびに検索をやり直す（FR-105 の「止めずに続ける」に反し、結果と選択が消える）。名前を変えたフォルダの照合をディスクの存在確認で判定する（列挙器の先読みした値と競合し、順序が保証できない）。`BrowserModel` の中に判定を直接書く（既に1400行あり、組み合わせのテストが書きにくい）。

**Evidence**: FR-105、EC-52・EC-94、A-34。`Browser/BrowserModel.swift` の `didRenameFolder`・`startSearchStream`・`appendSearchResults`、`Model/RenamedFolder.swift`。

## R4 — 検索結果の索引とフォルダの行の付け替え・取り除き

**Decision**:

- `rebaseSearchIndex` で、キー（結果を含むフォルダ）が変わらないエントリの URL にも `moved` の対応を当てる。名前を変えたフォルダの行そのものは、キーが親フォルダのままで URL だけが変わるため、現状では古い URL が索引に残り、以後の外部の削除で外れない。
- 消えたフォルダの中の結果の取り除き（FR-087・EC-35・EC-95）は、既存の `pruneMissingResults` の存在確認で行う。フォルダが消えると、その中の結果も存在しなくなるため、同じ確認で外れる。届いたフォルダ以下の結果だけを確かめる絞り込みは、索引のキーの前方一致のため、フォルダの行（キーは親）とその中の結果（キーはフォルダ以下）の両方が対象に入る。
- ゴミ箱に入れる・移動は、操作の後の `reloadCurrentFolder` → `pruneMissingResults(under: nil)` でフォルダの行と中の結果を外す。外したものがプレビュー中ならプレビューを空にし、動画を止める（既存の `removeSearchResults`）。
- フォルダの行の名前の変更は、コーディネーターが既にディレクトリとして `didRenameFolder` を呼ぶ。行の名前と中の結果の「場所」、並べ替えは既存の処理で付け替わる（FR-087・FR-105・US15-AS7）。
- 複製・新しく作られたフォルダは既存どおり加えない（FR-087・EC-95）。

**Rationale**: フォルダの中の結果を親子関係で辿って外す専用の処理を作らなくても、存在確認だけで同じ結果になる。消えたフォルダの中の項目は必ず存在しないため、取りこぼしがない。索引の不整合は、フォルダの行ができて初めて表に出る既存の欠陥であり、本 feature の中で直す。

**Alternatives considered**: フォルダの行を外すときに、URL の前方一致で中の結果をまとめて外す（存在確認と二重になる。外部での移動の直後に同じ場所へ別のフォルダが作られた場合を誤って外す余地もない代わりに、利点もない）。索引を名前の変更ごとに全件から作り直す（001 の R67 で避けた 10,000 件の費用が戻る）。

**Evidence**: FR-087・FR-105、US15-AS7・AS8、EC-35・EC-36・EC-95、SC-056。`BrowserModel` の `rebaseSearchIndex`・`pruneMissingResults`・`removeSearchResults`、`Operations/FileOperationCoordinator.swift`。

## R5 — 一覧の状態・メッセージ・件数

**Decision**: `BrowserModel.rebuildListing` の判定は変えない。フォルダの行は `.media` でないため、メディアの有無と絞り込みの判定（FR-060）では数えず、種類フィルタ（`MediaTypeFilter.apply`）でも常に残る。このため次が既存の判定で成り立つ。

| 一致の内容 | 種類フィルタ | `listing.state` | 表示 |
|---|---|---|---|
| なし | 問わない | `.empty` | 「該当する項目はありません」（EC-32） |
| フォルダだけ | 問わない | `.loaded` | フォルダの行。メッセージなし（EC-96） |
| フォルダとメディア、フィルタで残るメディアあり | オン／オフ | `.loaded` | 行のみ |
| フォルダとメディア、フィルタで残るメディアなし | オン | `.noMatches` | フォルダの行と絞り込み中のメッセージ（US15-AS5） |
| メディアだけ、フィルタで残るものなし | オン | `.noMatches` | 絞り込み中のメッセージ（従来どおり） |

検索中に結果がまだなければ `.loading`（「検索中…」）のまま。件数は `allFiles.count`（フォルダとファイルの合計、種類フィルタ適用前）のまま（FR-084・FR-085・A-81・US15-AS10）。変更は `FileListViewController.refresh` の検索結果の `.empty` の文言を「該当する項目はありません」にすることだけとする。

フォルダの行のアイコン・縮小画像（汎用フォルダ）、「種類」「場所」列、サムネイル形式のツールチップ、先読みとプレビューの除外（フォルダの行を選ぶとプレビューは空、動画は止まる。FR-075）は、`kind == .folder` による既存の分岐と `SearchListing.location(of:)`（親フォルダのパス）で表示される。

**Rationale**: FR-139・EC-96 は FR-060 と同じ判定を検索結果に当てたものであり、既存の判定がそのまま正しい。文言だけが「ファイル」に限られている。

**Alternatives considered**: 検索結果専用の状態（例 `.foldersOnly`）を足す（表示が同じで、状態が増えるだけ）。件数をファイルとフォルダの内訳で持つ（A-81 で表示しないと決めた）。

**Evidence**: FR-084・FR-085・FR-139、US15-AS1・AS4・AS5・AS10、EC-32・EC-96・EC-98、A-81。`BrowserModel.rebuildListing`、`Model/MediaTypeFilter.swift`、`FileList/FileListViewController.swift`、`FileList/ListModeView.swift`、`FileList/ThumbnailModeView.swift`、`Layout/FocusNavigator.swift`、`Slideshow/SlideshowSequence.swift`。

## R6 — フォルダの行を開く

**Decision**: 検索結果のフォルダの行は、既存の `BrowserModel.openItem` の `.folder` の分岐で開く。`navigateToFolder` が、ツリーの同期の依頼 → `selectFolder`（`resetForNavigation` で検索の列挙と先読みを止め、プレビューを空にし、動画を止める → `leaveSearchIfNeeded` で「場所」の並べ替えを保存済みの並べ替えに戻す → `lastFolder` を保存 → 読み込み）を行う。検索中に開いた場合も、列挙は `resetForNavigation` で取り消され、世代が変わるため後から届いたバッチは捨てられる（EC-93）。読み取り権限のないフォルダは通常の一覧と同じく「アクセスできません」になり、`..` の行で戻れる（EC-91）。

メニュー・キーの App 側には追加の分岐を作らない。`ListItemKind.folder.opensAsContainer` が true のため、ダブルクリック（`onOpenItem`）、⌘↓・「ファイル > 中を表示」（`openFocusedItem` と `validateMenuItem`）、右クリックメニューの「中を表示」（常に出し、`canOpenContainer` で有効）はフォルダの行で有効になり、メディアの行では従来どおり無効のまま。「上の階層へ」は検索結果の表示中は `canGoUp` が false のため出ない。キーボードフォーカスはファイルリストに残り、ツリーは `treeSyncRequest` で選択だけを同期する（FR-078 の既存の経路）。

`BrowserModel` では、検索結果の表示中に開いたときの履歴への通知の種類（R7）と、ツリー同期の完了後の保存（R10、EC-102）を変える。

注記（右クリックメニューのメディアの行）: spec の FR-140 と product の contracts/keyboard-and-menus.md（右クリックメニュー（ファイルリスト））は、「中を表示（⌘↓）」をフォルダ（と zip ファイル）の行にだけ加えると定める。既存の実装（`FileList/FileContextMenu.swift` の `buildMenu`）は「中を表示」をどの行にも出し、メディアの行では淡色にしている。これは本 feature の前からある契約と実装の食い違いであり、本 feature では実装を変えず、検証でもメディアの行の「中を表示」の表示の有無を合否の条件にしない（tasks の T037）。bug 拡張で実装を直すか、契約の文言を実装に合わせるかは別に決める。扱いは tasks の T059 で Living spec への反映（T056）の前にユーザーに確認し、bug の候補（憲章「仕様の管理」の bug 拡張）または別の feature の候補として quickstart.md の「最終検証結果」に記録する。

**Rationale**: FR-140 の基本の操作は通常のフォルダの行を開く経路を使う。履歴の通知は R7、ツリーに表示されない場所の保存は R10 で補い、それ以外の操作は共通に保つ。

**Alternatives considered**: 検索結果専用の「フォルダを開く」 API を作る（同じ処理の重複）。開いた後も検索結果を保つ（A-80 で範囲外）。

**Evidence**: FR-140・FR-085、US15-AS3、EC-91・EC-93、A-80・A-82、SC-055。`BrowserModel.openItem`・`navigateToFolder`・`selectFolder`・`resetForNavigation`、`FileList/FileListViewController.swift`、`FileList/FileContextMenu.swift`、`Model/ListItemCommands.swift`。

## R7 — 履歴（FR-113・EC-99・EC-100）

**Decision**: `LocationEvent` に `.openedSearchResultFolder(leavingFocus: URL?)` を加える。`BrowserModel.openItem` は、検索結果の表示中に `.folder` の行を開いたとき、`navigateToFolder` の理由をこれにする（`LocationChangeReason` に対応する case を足す）。`HistoryNavigator` はこの通知で次を行う。

1. 現在の表示の状態（`currentViewState()`。検索結果の表示を終えた時点の表示形式・サイズ・ペイン・種類フィルタ・zip の表示）を、現在の履歴へ `updateCurrentViewState` で反映する。
2. 続けて `.navigated` と同じ記録をする。現在の履歴と同じ場所・同じ表示の状態なら `record` が false を返して記録しない（EC-99）。違えば開いたフォルダを FR-107 の（2）として記録し、進む側を取り除く。
3. 記録の取り消し（`.notFound` のときの snapshot、001 の R75）は、1 の反映の後の履歴を snapshot にする。

検索前の場所は、検索中も `history.current` に残っている（検索結果は記録しない）。zip の中で始めた検索なら、`history.current` は zip の中の階層 D のため、開いたフォルダは D の次に記録され、zip ファイルを含むフォルダの一覧は記録されない（EC-100）。この順序は 1・2 で自然に成り立ち、追加の分岐はいらない。

離れる履歴（検索前の場所）のフォーカス行には、既存のツリーからの終了と同じく、開いた時点のフォーカス（開いたフォルダの行）を渡す。戻ったときにその行があれば選択し、なければ選択なしになる（FR-108 の既存の扱い）。

ツリーでフォルダを選んで検索結果の表示を終えた場合（`.navigated`）の扱いは変えない。spec は FR-113 の変更として、フォルダの行を開いた場合の反映だけを定めている。

**Rationale**: 既存の `.navigated` の処理は「同じ場所のときだけ表示の状態を反映する」ため、開いたフォルダが検索前の場所と違うと、検索前の場所が古い表示の状態のまま戻る側に入る。FR-113 の変更（反映してから判定する）を満たすには、検索結果から開いたことを `HistoryNavigator` が知る必要がある。通知の種類を分けるのが、`BrowserModel` に履歴の判断を持ち込まない最小の方法になる。

**Alternatives considered**: `.navigated` に「検索結果を終えたか」の Bool を足す（既存の全呼び出しを変える。意味の違う通知が同じ case に混ざる）。すべての検索結果の終了で反映する（ツリーからの終了の挙動が変わり、spec の範囲を超える）。`BrowserModel` が履歴を直接書く（001 の R70 の責務分けに反する）。

**Evidence**: FR-107・FR-108・FR-113・FR-140、US15-AS3、EC-99・EC-100、SC-055。`History/HistoryNavigator.swift`、`History/NavigationHistory.swift`（`record`・`updateCurrentViewState`）、`BrowserModel` の `LocationEvent`。

## R8 — 検索前の場所を含むフォルダの行をゴミ箱に入れた・移動した場合

検索結果では、ファイルリストから、検索前のフォルダ A そのもの、または A の祖先のフォルダの行を選べるようになる（起点が A の祖先のとき）。spec は当初この場合を個別に定めていなかったため、以下の判断を spec の EC-101 として加えた。FR-087・US15-AS8 は「フォルダの行と中の結果を一覧から外す」、EC-36 は「起点が消えても検索結果の表示を続け、検索前のフォルダ・ツリーの選択・最後に表示していたフォルダは変えない」と定める。FR-079 の「表示中のフォルダかその祖先をゴミ箱に入れたら親へ移る」は、ツリーからの操作の規則である。

**Decision**: ファイルリスト（検索結果の一覧）からのゴミ箱では、検索結果の表示を続け、行と中の結果を外すだけにする（spec の EC-101）。判断は Core に置く。`BrowserModel.leaveTrashedFolders` に操作の経路 `origin: OperationOrigin`（既存の呼び出しの意味を保つため既定値は `.tree`）を加え、`origin == .fileList` かつ検索結果の表示中は親へ移らずに false を返す。`FileOperationCoordinator.trash` は受け取った `origin` をそのまま渡すだけにし、false なら従来どおり `reloadCurrentFolder` を呼ぶ（`pruneMissingResults` で行と中の結果が外れる）。検索前のフォルダ・ツリーの選択・`lastFolder` は変えない（EC-36 と同じ）。この後に Esc・⌘[ で検索結果の表示を終えると、検索前のフォルダは存在しないため、既存の「フォルダが見つかりません」と履歴の取り除き（EC-62・EC-65 の経路）になる。ツリーからのゴミ箱（FR-079）の挙動は変えない。

検索結果の一覧からの移動（ツリーのフォルダへのドラッグ&ドロップ）も同じ扱いにする（spec の EC-101）。`FileOperationCoordinator.transfer` は移動の後に `historyNavigator.didRemoveItems`（FR-109）と `reloadCurrentFolder` を呼び、`leaveTrashedFolders` を呼ばないため、既存のコードのままで検索結果の表示が続き、行と中の結果が外れる。コードは変えず、tasks の T040 の (9) で挙動を固定する。続けて Esc・⌘[ で終えたときは、ゴミ箱と同じく検索前のフォルダが元の場所にないため「フォルダが見つかりません」になる。Esc は `FileListViewController.leaveSearchResults` から `BrowserModel.selectFolder(listing.folder)`、⌘[ は `HistoryNavigator.goBack()` を通るため、自動テストは前者を `BrowserModelSearchTests`、後者と履歴を `HistoryNavigatorTests` で確かめる（T040 の (8)・(9)）。

**Rationale**: US15-AS8 の文言（一覧から外れる）と EC-36 の前例（検索前の場所が消えても検索結果の表示を続ける）に合う。ファイルリストでの操作で一覧の種類が突然変わる（検索結果が終わる）ことを避ける。判断を Core の `BrowserModel` に置くことで、App の分岐を作らずに、経路と検索結果の表示の有無の組み合わせを単体テストできる（憲章 IV）。変更は1か所の条件で済む。

**Alternatives considered**: 既存どおり `leaveTrashedFolders` で親へ移り、検索結果の表示を終える（FR-079 をファイルリストの操作にも広げる解釈。US15-AS8 の「一覧から外れる」と、EC-36 の「表示を続ける」の前例に反する）。検索前のフォルダを残っている最も近い祖先へ付け替える（spec にない状態の変更で、ツリーの選択との対応も新たに定める必要がある）。`FileOperationCoordinator.trash` で `origin == .fileList` かつ検索結果の表示中なら `leaveTrashedFolders` を呼ばない（App の分岐になり自動テストできない。既存の EC-36 の経路のテストは、この分岐がなくても通ってしまう）。

**Evidence**: FR-079・FR-087、US15-AS8、EC-36・EC-62・EC-65・EC-101。`Operations/FileOperationCoordinator.swift`、`Browser/BrowserModel.swift`（`leaveTrashedFolders`）、`Model/FolderNavigation.swift`、`Operations/ConfirmationPolicy.swift`（`OperationOrigin`）。spec の EC-101 は、2026-10-27 にユーザーがゴミ箱と移動の両方について採用した（tasks の T001）。

## R9 — 性能・フィクスチャ・既存テストの更新

**Decision**:

- 性能: `PerformanceBaselineTests` に SC-054 の試験を足す。SC-016 と同じ 100 フォルダ × 100 ファイルの階層で、フォルダ名の半数がキーワードを含むようにし、ファイルとフォルダを合わせた件数と 3 秒以内を確かめる。既存の SC-016 の試験は、フォルダ名（`folder-%03d`）がキーワード `cat` を含まないため、件数（5,000）は変わらない。検索中の UI の応答（100ms 以上止まらない）は、既存の検索の手動確認と同じく `.app` で確かめる。
- 名前の変更の試験: 既存の `renameFolderWithHugeSearchResultsWithinBudget` を、フォルダの行を含む結果でも基準内であることの確認に広げる（索引の付け替えの修正が O(件数) を超えないこと）。
- フィクスチャ: `FixtureSets.folderSearch(in:)` を新設し、`folder-search/` に US15・SC-053 の階層を作る（`Kyoto` を起点にできる構成。`2024_Kyoto`・`2024_Kyoto_old`・`kyoto_map.png`・`.kyoto`・`Kyoto.app`・`kyoto_link`（フォルダへのリンク）・`kyoto.zip`・`2024.10_trip`・`photos.jpg`（フォルダ）・同じ名前の別の場所のフォルダ・権限なしにするフォルダ）。SC-053 の 50/50/50/各5 の件数は、テストの中で同じ関数の引数で生成する。`makeAll` からも呼ぶ。
- 既存テストの更新: `search` フィクスチャには `cat-folder` があり、キーワード `cat` でフォルダの行として一致するようになる。`FileNameSearcherTests` の「cat は対応メディアだけを返し…フォルダ名…を除く」と「権限のないサブフォルダ」の期待値を、`cat-folder` を含む5件に改める（`cat-folder/x.jpg` は含めない。EC-92）。「バッチは batchSize 件以下に分けて流す」も同じ `cat` の検索のため、合計の件数を 4 から 5 に改める。`BrowserModelSearchTests` の `FakeSearcher` と性能試験の `StreamingSearcher` は `SearchRequest` を受ける形に改める。

**Rationale**: 既存の基準（SC-016・001 の R67 の名前の変更の費用）を、フォルダの照合を加えた状態でも同じ方法で測れる。フィクスチャを一時ディレクトリに作り、テスト後に消す既存の規約（FixtureKit）に従う。

**Alternatives considered**: 10,000 個のフォルダの階層を別に作る（SC-054 は SC-016 の階層を起点にすると定めている）。既存テストの期待値を変えずにキーワードを変える（フォルダが一致するようになったこと自体を確かめる機会を失う）。

**Evidence**: SC-016・SC-053〜SC-057、憲章 II・IV。`Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift`、`Tests/MediaViewerCoreTests/FileNameSearcherTests.swift`・`BrowserModelSearchTests.swift`、`Sources/FixtureKit/FixtureSets.swift`。

### SC-054 の測定方法（設計レビュー A1 の反映）

完了までの 3 秒は T024 の `ContinuousClock` による自動試験で測る。UI 停止の 100ms は T055 で、ユーザーが Instruments の Hangs の検出しきい値を 100ms 未満（例: 33ms 超）に設定して測る。検索中に各操作を行い、検索区間の 100ms 以上のイベントが0件であることを確かめる。trace の保存先・しきい値・操作・イベント件数と最大継続時間を quickstart.md「最終検証結果」に記録する。目視は補助であり、未計測なら SC-054 は未検証とする。具体的な手順と Apple の根拠資料は quickstart.md 手動シナリオ 7 を参照する。


## R10 — ツリーに表示されない検索結果のフォルダ（EC-102）

**Decision**: 2026-10-27 のユーザー回答に従い、検索結果から開いた F がツリーに出ない場合、一覧と履歴は F のまま、ツリーの最も近い表示可能な祖先 V を選び、`lastFolder` は V にする。この例外を通常の一覧やお気に入りへ広げない。

既存の `DirectoryTreeViewController.expandAncestors(of:)` は、途中で子が見つからなければ辿れた最も深いノードを返す。選択とスクロールはこの戻り値を使う既存の `syncSelection(to:)` で足りる。ただし保存は `BrowserModel.selectFolder` で F になっているため、同期の完了を Core へ返す接続が要る。

`BrowserModel` に `completeSearchResultTreeSync(_:selectedFolder:)` を追加する。検索結果のフォルダを開く `selectFolder(_:reason:)` は `resetForNavigation()` の後、対応する同期依頼の ID を保留する。保留 ID は次の `resetForNavigation()` で消す。完了の通知は、保留 ID・現在の `treeSyncRequest`・現在の一覧の場所が依頼と一致し、検索結果・zip の表示中でも `.notFound` でもなく、選択先が依頼の場所そのものか祖先（標準化した pathComponents で比較）である場合だけ受け入れる。受け入れたら保留 ID を消して `lastFolder` を更新する。同じ場所の再訪でも古い依頼を受け入れず、重複した通知も無視する。

App は現在の依頼 ID と一覧の場所の検査、実際の行の選択、`isRestoringSelection` による逆向きの選択通知の抑制を保ち、行を選択できた後に依頼と選択したノードの URL を Core へ渡すだけにする。Core は一覧・履歴・フォーカスを変更せず、ファイルの存在確認や列挙も行わない。同期前は従来どおり F を保存し、有効な同期完了の後に V を保存する（ツリーの遅延・古い完了を検証する T061）。

**Alternatives considered**: App が直接 `SettingsStore` を書き換える（保存の判断と古い完了の排除が Core で検証できない）。V に `selectFolder` する（F の一覧を表示する要件に反する）。全ツリー同期で保存先を祖先へ変える（今回の回答の範囲を超えて既存の経路を変える）。

**Evidence**: FR-140、EC-102、FR-003・FR-078。`Tree/DirectoryTreeViewController.swift` の `expandAncestors`・`syncSelection`、`Browser/BrowserModel.swift` の `navigateToFolder`・`selectFolder`・`resetForNavigation`。実装と Core の回帰テストは T061〜T063、GUI は T037。
