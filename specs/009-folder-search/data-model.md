# Data Model: 検索でフォルダも検索対象にする

**Date**: 2026-10-27 | **Spec**: [spec.md](spec.md)

以下は設計上の型と責務。実装時の名前は対応関係を保てば調整してよい。Core の型は AppKit に依存しない。既存の検索・一覧・履歴の型は、ここに記した変更以外は変えない。根拠は [research.md](research.md) の R1〜R10。

## 1. 検索結果の行 — MediaFile（既存、変更なし）

検索結果の一覧は従来どおり `[MediaFile]`。フォルダの行は通常の一覧のフォルダの行と同じ値を持つ（FR-139）。

| フィールド | メディアの行 | フォルダの行（新たに検索結果に現れる） |
|---|---|---|
| `url` | ファイル（ファイルへのリンクはリンク自身）の URL。起点の形（`/var/...`）に組み直す | フォルダの URL。起点の形に組み直す |
| `name` | `lastPathComponent` | `lastPathComponent`（「.」を含んでも全体） |
| `kind` | `.media(MediaKind)` | `.folder` |
| `typeDescription` | `localizedTypeDescription` | `"フォルダ"` |
| `creationDate` | ファイルの作成日 | フォルダの作成日 |
| `fileSize` | ファイルのサイズ | `0` |

**一致の規則**（FR-082・FR-083、R1）:

| 項目 | 照合 | 中を辿る |
|---|---|---|
| 対応メディアファイル（拡張子で判定。ファイルへのリンクを含む） | 名前全体 | — |
| 通常のフォルダ（隠しでない・パッケージでない・リンクでない） | 名前全体 | 辿る（一致してもしなくても） |
| 読み取り権限のないフォルダ | 名前全体 | 辿らない |
| 検索起点そのもの | しない（名前を変えた未照合のフォルダを追加で列挙する場合を除く。§3） | 辿る |
| 隠しファイル・隠しフォルダ | しない | 辿らない |
| パッケージ（`.app` など） | しない | 辿らない |
| フォルダへのシンボリックリンク | しない | 辿らない |
| zip ファイル | しない | 辿らない |

親のフォルダが一致したことを理由に、中の項目を一致とはしない（EC-92）。

対応: FR-082・FR-083・FR-139、US15-AS1・AS2・AS6・AS9、EC-33・EC-91・EC-92・EC-97、A-78・A-79。

## 2. 検索の要求と照合済みの記録 — SearchRequest・SearchVisitLog（Core、新規）

`Sources/MediaViewerCore/Search/FileNameSearcher.swift`（同じファイルに置くか、`Search/SearchRequest.swift` を新規に作る）

### SearchRequest

| フィールド | 型 | 意味 |
|---|---|---|
| `root` | `URL` | 列挙を始めるフォルダ |
| `pattern` | `SearchPattern` | キーワード |
| `matchesRoot` | `Bool` | `root` そのものもフォルダとして照合するか。検索の開始・起点か祖先の名前の変更では false。未照合のフォルダの名前を変えたときの追加の列挙だけ true（R3） |
| `visits` | `SearchVisitLog` | 列挙がディレクトリを照合する直前に記録する先 |

### SearchVisitLog

| API | 意味 |
|---|---|
| `record(_ path: String)` | 標準化したディレクトリのパス（起点の形）を記録する。列挙のスレッドから呼ぶ |
| `contains(_ path: String) -> Bool` | 記録があるか。MainActor から呼ぶ |

- `final class`、`@unchecked Sendable`、`NSLock` で保護した `Set<String>`。
- ディレクトリだけを記録する。ファイルは記録しない。
- 列挙ごとに1つ。検索を止めたとき（`resetForNavigation`）に捨てる。

### FileNameSearching（変更）

```text
search(_ request: SearchRequest) -> AsyncStream<[MediaFile]>   // 要求（唯一の要件）
search(in:matching:) -> AsyncStream<[MediaFile]>               // 拡張。matchesRoot: false と新しい記録で要求を作る
```

**不変条件**:

- 記録はディレクトリを照合する前に行う。記録がなければ、その時点でそのディレクトリはまだ照合されていない。
- バッチの分け方（件数・経過時間）・取り消し・起点の形への組み直しは既存のまま。

対応: FR-085・FR-105、EC-52・EC-94、R2。

## 3. 検索中の名前の変更の台帳 — SearchRenameLedger（Core、新規）

`Sources/MediaViewerCore/Search/SearchRenameLedger.swift`

`BrowserModel.searchRenames` を置き換え、列挙ごとの付け替えの範囲と、未照合のフォルダの扱いを持つ値型。ディスクを読まない。

| フィールド | 型 | 意味 |
|---|---|---|
| `renames` | `[RenamedFolder]` | 今の検索の間に行われたフォルダの名前の変更（順） |
| `streams` | `[Stream]` | 列挙ごとの `visits` と、開始時点の `renames.count` |
| `rejudged` | `[Int: String]` | 未照合として扱った名前の変更（`renames` の位置 → 元の場所の標準化したパス） |

| API | 結果 |
|---|---|
| `addStream(visits:) -> Int` | 列挙を登録し、その番号を返す |
| `hasVisited(_ folder: URL) -> Bool` | 今の時点で `folder` の場所にあるフォルダを、登録済みのどれかの列挙が照合済みか。各列挙について、開始後の名前の変更を逆順に戻した場所で `visits.contains` を問う |
| `recordRename(_ renamed: RenamedFolder, visited: Bool)` | 名前の変更を加える。`visited == false` なら `rejudged` に元の場所を記録する |
| `place(_ file: MediaFile, fromStream index: Int) -> MediaFile?` | 列挙の結果を今の場所にする。開始後の名前の変更を順に当て、`.folder` の行の最後の要素が変われば `name` も変える。途中の名前の変更 k が `rejudged` にあり、k の時点の場所が k の元の場所と同じなら nil（捨てる） |
| `isEmpty` | 名前の変更がないか（既存の高速経路の判定） |

**状態の遷移**（検索中に起点の配下のフォルダ F を F′ に変えたとき）:

| `hasVisited(F)` | 追加の列挙 | 前の列挙から後で届く F の結果 | F′ の照合 |
|---|---|---|---|
| true | F′ の中だけ（`matchesRoot: false`） | F′ に付け替え、行なら名前も F′ | しない（照合済み。EC-94 の前半） |
| false | F′ とその中（`matchesRoot: true`） | 捨てる | 追加の列挙で F′ の名前で照合（EC-94 の後半） |

起点そのものか祖先の名前の変更は、`hasVisited` を問わず、新しい起点を `matchesRoot: false` で列挙し直す（既存）。重複（同じ標準化したパスが一覧にある結果）は `BrowserModel` が既存どおり捨てる。

対応: FR-105、EC-52・EC-94、A-34、R3。

## 4. BrowserModel（Core、変更）

| 箇所 | 変更 |
|---|---|
| `startSearch` / `startSearchStream` | 列挙ごとに `SearchVisitLog` を作り、`SearchRenameLedger.addStream` で登録し、`SearchRequest` で検索器へ渡す。バッチに列挙の番号を添えて `appendSearchResults` へ渡す |
| `appendSearchResults` | 名前の変更があれば `ledger.place(_:fromStream:)` で付け替え・名前の変更・捨てる判定をしてから、既存の重複除き・マージ・索引の追加を行う |
| `didRenameFolder` | 検索中で起点の配下のフォルダなら、`ledger.hasVisited(oldURL)` で照合済みかを判定し、`recordRename` の後に追加の列挙を `matchesRoot: !visited` で始める |
| `rebaseSearchIndex` | キーが変わらないエントリの URL にも `moved` の対応を当てる（R4） |
| `openItem` の `.folder` | 検索結果の表示中なら、`navigateToFolder` の理由を `.openedSearchResultFolder` にする（R7）。`selectFolder` の reset 後にこの経路の同期依頼 ID だけを保留する（R10） |
| `completeSearchResultTreeSync(_:selectedFolder:)` | R10 の条件で同期完了を受け入れ、保留 ID を消し、選択できた場所そのもの・最も近い表示可能な祖先を `lastFolder` に保存する。一覧・履歴・フォーカスは変更しない（EC-102） |
| `resetForNavigation` | `searchRenames.removeAll()` を `ledger = SearchRenameLedger()` に置き換える。検索結果から開いたフォルダのツリー同期の保留 ID も消す（R10） |
| `leaveTrashedFolders(_:origin:)` | 操作の経路 `origin: OperationOrigin`（既定値 `.tree`）を加える。`origin == .fileList` かつ検索結果の表示中は親へ移らずに false を返す。それ以外は既存どおり `FolderNavigation.folderToShow` で判断する（EC-101、R8） |
| `rebuildListing`・`pruneMissingResults`・`removeSearchResults`・`didRenameItem` | 変えない（R4・R5） |

`LocationEvent`（変更）:

| case | 送る時点 |
|---|---|
| `.navigated(leavingFocus:)` | 既存。フォルダ・zip の移動、ツリーからの選択、Esc・⌘[ による検索結果の表示の終了 |
| `.openedSearchResultFolder(leavingFocus:)` | 新規。検索結果の表示中にフォルダの行を開き、検索結果の表示を終えたとき |
| `.relocated`・`.notFound` | 既存 |

**一覧の状態**（変更なし。R5 の表）: フォルダの行は種類フィルタで隠れず、メディアの有無の判定で数えない。

## 5. HistoryNavigator（Core、変更）

`.openedSearchResultFolder(leavingFocus:)` を受けたとき:

1. `model.historyLocation`（開いたフォルダ）と `currentViewState()` を得る。得られなければ何もしない。
2. `history.updateCurrentViewState(viewState)` で、検索前の場所（`history.current`）の表示の状態を、検索結果の表示を終えた時点の状態にする。
3. 以降は `.navigated` と同じ: 同じ場所なら snapshot を消して終わる。違えば snapshot を取り、`record(..., kind: .navigation, leavingFocus:)` で記録する。

| 検索前の場所 | 開いたフォルダ | 記録の後の履歴 | 続けて ⌘[ |
|---|---|---|---|
| フォルダ A | A と異なる F | …, A（終了時の表示の状態）, **F** | A |
| フォルダ A | A（起点が A の祖先） | …, **A**（終了時の表示の状態）。新しい履歴なし（EC-99） | A より前。なければ無効 |
| zip の中の階層 D | F（zip を含むフォルダを含む） | …, D（終了時の表示の状態）, **F**。zip を含むフォルダの一覧は記録しない（EC-100） | D |

`canGoBack`・`canGoForward`・検索結果の表示中の「戻る」（`perform` の分岐）は変えない。

対応: FR-107・FR-108・FR-113・FR-140、EC-99・EC-100、SC-055、R7。

## 6. App（変更）

| 型 | 変更 |
|---|---|
| `DirectoryTreeViewController.syncSelection(to:)` | 既存の `expandAncestors` が返した最も深いノードを選択後、依頼とノードの URL を Core の `completeSearchResultTreeSync` へ渡す。保存の判断は Core で行う（EC-102・R10） |
| `FileListViewController.refresh` | 検索結果の `.empty` の文言を「該当する項目はありません」にする（EC-32） |
| `FileOperationCoordinator.trash` | 受け取った `origin` を `leaveTrashedFolders(_:origin:)` へ渡すだけにする。経路と検索結果の表示による判断は Core（§4）が行い、App に分岐を作らない（EC-101、R8） |
| `FileOperationCoordinator.transfer` | 変えない。移動の後は `leaveTrashedFolders` を呼ばずに `reloadCurrentFolder` するため、検索結果の一覧から検索前のフォルダやその祖先を移動しても検索結果の表示が続く（EC-101、R8） |
| `FileContextMenu`・`validateMenuItem`・`ListModeView`・`ThumbnailModeView`・`MainMenu` | 変えない。フォルダの行は `ListItemKind.folder` の既存の分岐で、汎用アイコン・種類・場所・「中を表示」の有効化・プレビューの除外になる（R5・R6）。メディアの行に「中を表示」を淡色で出す既存の実装と契約の食い違いは本 feature では扱わない（R6 の注記。扱いは tasks の T059 で確認して記録する） |

## 7. FixtureKit（変更）

`FixtureSets.folderSearch(in:)`（新規）が `folder-search/` を作り、`makeAll` から呼ぶ。構成は [quickstart.md](quickstart.md) の「検証データ」を参照。SC-053 の件数（一致するフォルダ50・ファイル50・一致しないフォルダ50・除外対象各5）は、引数で件数を変えられる関数として同じファイルに置き、テストからも使う。
