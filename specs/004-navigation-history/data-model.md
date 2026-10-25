# Data Model: 操作の履歴を戻る・進む

既存のモデルは `specs/001-three-pane-media-viewer/data-model.md`・`specs/002-favorite-folder-rename/data-model.md`・
`specs/003-tree-folder-rename-delete/data-model.md` を参照。ここでは追加・変更する部分だけを書く。判断の根拠は
[research.md](./research.md) の R68〜R78。API の形は [contracts/core-api.md](./contracts/core-api.md)。

## HistoryLocation（新規、Core）

履歴の「場所」（FR-108）。ファイルリストに表示していたフォルダと、zip の中の位置の組。

| フィールド | 型 | 意味 |
|---|---|---|
| `folder` | `URL` | 表示していたフォルダ。zip の中なら zip を含むフォルダ（`FolderListing.folder` と同じ） |
| `archive` | `ArchiveLocation?` | zip の中なら zip ファイルと階層。通常のフォルダでは nil |

| 操作 | 振る舞い |
|---|---|
| `==` | `folder` と `archive.archive` は `.`・`..` を取り除いたパスの文字列で、`archive.directory` は文字列のまま比べる（R69） |
| `isWithin(_ url: URL) -> Bool` | `url` 自身か配下を指すか。`folder` が `url` の配下、または `archive.archive` が `url` 自身か配下なら true。区切りの `/` まで比べ、`Photo` と `Photos` を取り違えない（`RenamedFolder` と同じ比較） |
| `rebased(by: RenamedFolder) -> HistoryLocation?` | `folder`・`archive.archive` を新しい場所にする。関係がなければ nil |

`BrowserModel.historyLocation` が今の表示から作る。検索結果の表示中と、読み込みが「見つからない」で終わった表示（EC-62）では nil。

## HistoryPresentation（新規、Core）・HistoryViewState（新規、Core）

履歴の「表示の状態」（FR-108）。App が持つ部分を `HistoryPresentation` に分ける（R74）。

| 型 | フィールド | 持ち主 |
|---|---|---|
| `HistoryPresentation` | `displayMode: DisplayMode`・`thumbnailSize: Double`・`paneLayout: PaneLayout` | App（`FileListViewController`・`MainSplitViewController`） |
| `HistoryViewState` | `presentation: HistoryPresentation`・`mediaTypeFilter: MediaTypeFilter`・`showsZipFiles: Bool` | 種類フィルタと zip ファイルの表示は `BrowserModel` |

どちらも `Equatable`。`thumbnailSize` は `ViewSettings.clampThumbnailSize` 済みの値。

## HistoryEntry（新規、Core）

| フィールド | 型 | 意味 |
|---|---|---|
| `location` | `HistoryLocation` | 場所 |
| `viewState` | `HistoryViewState` | 表示の状態 |
| `focusedItem` | `URL?` | その履歴から離れたときにフォーカスしていた行（記録した直後は nil）。比較には含めない |

`hasSameState(as:)` は `location` と `viewState` が等しいとき true（FR-107 の「同じ場所・同じ表示の状態」、EC-59）。

## HistoryRecordKind・HistoryDirection（新規、Core）

```text
HistoryRecordKind = .navigation      // フォルダの選択・フォルダの移動（FR-107 の（1）（2））
                  | .viewChange      // サムネイルサイズ以外の表示の変更（（3））
                  | .thumbnailSize   // サムネイルサイズの変更。続けて行ったものを1件にまとめる（R71）
HistoryDirection  = .back | .forward
```

## NavigationHistory（新規、Core。値型）

履歴の列（主なエンティティ）。規則はすべてこの型が持つ（R68）。

| 状態 | 型 | 意味 |
|---|---|---|
| `backEntries` | `[HistoryEntry]` | 戻る側。古い順（末尾が1つ前） |
| `current` | `HistoryEntry?` | 現在の履歴。表示が空・見つからない場所のときは nil（EC-62・EC-65） |
| `forwardEntries` | `[HistoryEntry]` | 進む側。近い順（先頭が1つ後） |
| `lastRecordKind` | `HistoryRecordKind?`（非公開） | サイズの変更のまとめに使う（R71） |
| `version` | `Int` | 変更のたびに増やす。確認中に履歴が変わったかを `HistoryNavigator` が見る（R72） |

不変条件:

- `count`（戻る側＋現在＋進む側）は `capacity = 100` 以下（FR-110）
- 隣り合う2つの履歴は同じ状態にならない（EC-59。各操作の最後にまとめる）
- `canGoBack` は `backEntries` が空でないとき、`canGoForward` は `forwardEntries` が空でないとき true

| 操作 | 振る舞い |
|---|---|
| `record(location:viewState:kind:leavingFocus:) -> Bool` | 現在と同じ状態なら何もせず false。`kind == .thumbnailSize` かつ `lastRecordKind == .thumbnailSize` かつ現在があれば、現在の `viewState` を書き換える（まとめた結果、1つ前と同じ状態ならまとめて `lastRecordKind = nil`）。それ以外は、現在があればその `focusedItem = leavingFocus` にして戻る側の末尾へ移し、新しい履歴を現在にし、進む側をすべて取り除く。100 件を超えたら戻る側の先頭から取り除く。`lastRecordKind = kind` |
| `candidate(_ direction) -> HistoryEntry?` | 戻る側の末尾、または進む側の先頭。なければ nil |
| `dropCandidate(_ direction)` | 見つからなかった候補を取り除く（FR-109）。その後にまとめる |
| `move(_ direction, leavingFocus:) -> HistoryEntry?` | 現在があれば `focusedItem = leavingFocus` にして反対側へ移し、候補を現在にして返す。`lastRecordKind = nil` |
| `updateCurrentViewState(_:)` | 現在の表示の状態を書き換える（検索結果の表示を終えたとき。R76）。その後にまとめる |
| `replaceCurrentLocation(_:)` | 現在の場所を置き換える（EC-60）。表示の状態と進む側は変えない。その後にまとめる |
| `detachCurrent()` | 現在を戻る側の末尾へ移し、現在を nil にする（EC-62。R75） |
| `removeCurrent()` | 現在を取り除き nil にする（EC-65）。`lastRecordKind = nil` |
| `removeEntries(within urls: [URL], keepingCurrent: Bool)` | いずれかの `url` 自身か配下を指す履歴を取り除く（FR-109）。`keepingCurrent` なら現在は残す。その後にまとめる |
| `removeEntries(at:)` | 存在の確認で見つからなかった履歴を取り除く（外部の変更。現在を含みうる。R75） |
| `renameFolder(_ renamed: RenamedFolder)` | 現在の場所が関係すれば `rebased` で置き換え、ほかの関係する履歴は取り除く（FR-109）。その後にまとめる |

まとめ（EC-59）: 戻る側・現在・進む側を1列に並べ、隣り合う同じ状態の組を、現在を含むなら現在を、含まなければ新しい方を残して1つにする。

### 状態の遷移の例

```text
起動直後:        back=[]        current=A    forward=[]        （FR-111。最初の .navigated で記録）
B・C を選ぶ:     back=[A,B]     current=C    forward=[]
戻る×2:          back=[]        current=A    forward=[B,C]
E を選ぶ:        back=[A]       current=E    forward=[]        （US7-AS5）
外部で B を削除して C から戻る: B を飛ばして取り除く → back=[]  current=A  forward=[C]   （US7-AS6）
表示中の C のボリュームを取り外す: back=[A,B]  current=nil  forward=[]   （EC-65）
```

## LocationEvent（新規、Core）・BrowserModel（変更）

`BrowserModel` が場所を変えたときの同期の通知（R70）。

```text
LocationEvent = .navigated(leavingFocus: URL?)   // ツリーの選択・行を開く・..・⌘↑・zip の中の移動・Esc など、ユーザーの操作
              | .relocated(vanished: [URL])      // 表示中の場所（または祖先）が消えて自動で移った（EC-60）
              | .notFound(HistoryLocation)       // 通常のフォルダの読み込みが「見つからない」で終わった（EC-62・EC-65）
```

| 呼び出し元 | 通知 |
|---|---|
| `selectFolder(_:)`（ツリー・Esc・検索結果の表示中のツリーのクリック） | `.navigated` |
| `openItem(_:)`（フォルダ・zip ファイル・zip の中のディレクトリ・`..`）、`goToEnclosingLevel()` | `.navigated` |
| `handleFileSystemEvent(_:)` で表示中のフォルダが消えて親へ移る | `.relocated(vanished: [元のフォルダ])` |
| `handleFileSystemEvent(_:)` で zip が変わって zip を含むフォルダへ戻る | `.relocated(vanished: zip ファイルが存在しなければ [zip ファイル]、あれば [])` |
| `leaveTrashedFolders(_:)` | `.relocated(vanished: ゴミ箱に入れた場所)` |
| `loadFolder` が `.notFound` で終わる（世代が今のものの場合だけ） | `.notFound(その場所)` |
| `startSearch`・`showHistoryLocation`・`reloadCurrentFolder`・`didRenameFolder` | 通知しない |

追加する状態・操作は [contracts/core-api.md](./contracts/core-api.md)。`resolveHistoryLocation` の結果:

```text
HistoryLocationResolution = .available(ResolvedHistoryLocation)   // 見つかった。zip の中なら索引か開けなかった理由を持つ
                          | .missing                              // 見つからない（R73）
                          | .superseded                           // 確認中に BrowserModel の移動の世代が変わった
```

## ArchiveIndex（変更、Core）

| 操作 | 振る舞い |
|---|---|
| `containsDirectory(_ path: String) -> Bool` | 追加。最上位（空文字）なら true。`a/b/` の形のパスが索引のディレクトリ（`children` のキー、またはディレクトリの項目）にあれば true（R73） |

## HistoryNavigator（新規、Core。`@MainActor @Observable`）

戻る・進むの実行と、記録・取り除きの契機をまとめる（R72〜R76）。`BrowserModel` の `onLocationEvent` を自身に設定する。

| 状態 | 意味 |
|---|---|
| `history: NavigationHistory` | 公開（読み取りのみ）。Observation でボタンを更新する |
| `canGoBack` | `model.isShowingSearchResults \|\| history.canGoBack`（FR-113） |
| `canGoForward` | `!model.isShowingSearchResults && history.canGoForward` |
| 要求のキュー（非公開） | `goBack()`・`goForward()` の要求。1つずつ処理する（R72） |
| 直前の記録の控え（非公開） | `.navigated` で記録する前の `NavigationHistory` と、記録した場所。`.notFound` で使う（R75） |

| 契機 | 処理 |
|---|---|
| `.navigated(leavingFocus:)` | `model.historyLocation` が nil なら何もしない。現在と場所が同じなら `updateCurrentViewState`（R76）。違えば控えを取ってから `record(kind: .navigation)` |
| `.relocated(vanished:)` | `historyLocation` があれば `replaceCurrentLocation`、`removeEntries(within: vanished, keepingCurrent: true)` |
| `.notFound(location)` | 控えが有効（その後に履歴が変わっていない・場所が同じ）なら控えに戻して `detachCurrent()`。そうでなく現在の場所が `location` なら `removeCurrent()` |
| `recordViewChange(kind)` | 検索結果の表示中・`historyLocation` が nil なら何もしない。そうでなければ `record(kind:)` |
| `goBack()`・`goForward()` | キューに積む。処理は R72 |
| `didRenameFolder(from:to:)` | `renameFolder(RenamedFolder(from:to:))` |
| `didRenameItem(from:to:)` | `removeEntries(within: [from], keepingCurrent: false)`（zip ファイルの名前の変更。現在が zip の中のことはない） |
| `didRemoveItems(_ urls:)` | `removeEntries(within: urls, keepingCurrent: true)` |
| `handleFileSystemEvent(_ folders:)` | 変更のあったフォルダの配下を指す履歴の存在を UI スレッドの外で確かめ、見つからないものを `removeEntries(at:)`。確認中に履歴が変わっていたら捨てる |
| `revalidateAll()` | ボリュームの増減で、すべての履歴について同じ確認をする |

## PaneCommands（変更、Core）

| 操作 | 振る舞い |
|---|---|
| `canNavigateHistory: Bool` | 追加。`!isFullScreen && !isEditingText`（FR-112）。`HistoryNavigator.canGoBack`・`canGoForward` と AND を取る |

## App 側の状態（参考）

| 型 | 追加・変更 |
|---|---|
| `MainSplitViewController` | `HistoryNavigator` を作って持ち、`HistoryPresentationHost` を実装する。`goBack(_:)`・`goForward(_:)` のアクションと検証。`setPaneLayout` の記録あり・なしの経路 |
| `MainToolbarController` | `history` の項目（先頭）。`HistoryNavigator` の Observation と `validateToolbarItem` で有効・無効を更新 |
| `MainMenu` | 「移動」メニュー（「表示」の右）に「戻る」（⌘[）・「進む」（⌘]） |
| `FileListViewController` | 表示形式・サイズ・種類フィルタ・zip ファイルの表示のユーザーの入口で `recordViewChange`。復元用の記録しない setter |
| `DirectoryTreeViewController` | FSEvents のバッチとボリュームの増減で `HistoryNavigator` に知らせる |
| `FileOperationCoordinator` | 名前の変更・ゴミ箱・移動の成功で `HistoryNavigator` に知らせる |

## テスト

| 対象 | 主なケース | 根拠 |
|---|---|---|
| `NavigationHistory` | 記録と同じ状態の無視、分岐で進む側を取り除く、150 回の記録で 99 回戻れる、サイズのまとめ（連続・戻る後・元に戻してまとまる）、移動とフォーカスの記録、候補の取り除き、すべて取り除いて表示を変えない、置き換え・現在の取り除き・現在がない状態での記録と移動、名前の変更（現在は置き換え・ほかは取り除き）、配下の取り除き、まとめ（現在を残す） | FR-107・FR-109・FR-110、EC-54・EC-59・EC-60・EC-65、R68・R71・R75 |
| `HistoryLocation` | 末尾の `/`・`.`・`..` の同一、兄弟の前方一致を配下としない、zip の中の配下、`/` の配下、rebased | R69 |
| `ArchiveIndex.containsDirectory` | 最上位・存在する／しないディレクトリ・ディレクトリの項目がない zip（暗黙のディレクトリ） | R73 |
| `BrowserModel`（場所の通知） | 各呼び出し元の理由、`leavingFocus`、検索の開始で通知しない、`.notFound` の世代 | R70 |
| `BrowserModel`（確認と表示） | R73 の各場合、フォーカス行の選択・消えた行・種類フィルタで隠れた行、zip の中の表示とツリーへの依頼、`lastFolder`、`.superseded` | R73・R74、EC-55〜EC-57・EC-64 |
| `HistoryNavigator` | US7-AS1〜AS8・US7-AS11〜AS13・US8-AS1〜AS7 に当たる流れ、EC-65 の実際の取り外しの経路（`.relocated` → `.notFound`）、連打、確認中のユーザーの移動、検索結果の表示中、取り除きの各契機、`.relocated`・`.notFound`、スタブの `HistoryPresentationHost` への復元 | R72〜R76 |
| `PaneCommands` | `canNavigateHistory` の組み合わせ | FR-112 |
| 性能 | 10,000 ファイルのフォルダへ戻ったときの最初の項目の表示が 1 秒以内（100ms 以上止まらないことは quickstart.md の 22 で確かめる） | SC-029、R78 |
