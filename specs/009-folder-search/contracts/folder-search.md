# Contract: 検索でフォルダも検索対象にする

**Date**: 2026-10-27 | **Branch**: `009-folder-search`

本 feature の差分契約。要件の本文は [spec.md](../spec.md) を正とする。既存の `specs/product/` の [search.md](../../product/search.md)・[file-list.md](../../product/file-list.md)・[navigation-history.md](../../product/navigation-history.md)・[directory-tree.md](../../product/directory-tree.md)・[overview.md](../../product/overview.md)、および [contracts/keyboard-and-menus.md](../../product/contracts/keyboard-and-menus.md) に対する追加・変更を記す。実装・検証の後に spec の「反映先」に従って product へ反映するまでは本 feature 内に置く。外部サービス・HTTP API・CLI は追加しない。

## MediaViewerCore の公開 API

`Sources/MediaViewerCore/Search/`

```swift
public struct SearchRequest: Sendable {
    public var root: URL
    public var pattern: SearchPattern
    public var matchesRoot: Bool          // 既定 false
    public var visits: SearchVisitLog
    public init(root: URL, pattern: SearchPattern, matchesRoot: Bool = false, visits: SearchVisitLog = SearchVisitLog())
}

public final class SearchVisitLog: @unchecked Sendable {
    public init()
    public func record(_ path: String)
    public func contains(_ path: String) -> Bool
}

public protocol FileNameSearching: Sendable {
    /// 一致したメディアファイルとフォルダをバッチで流す。全階層を辿り終えたら終える。ストリームの終了で列挙を止める
    func search(_ request: SearchRequest) -> AsyncStream<[MediaFile]>
}

extension FileNameSearching {
    public func search(in root: URL, matching pattern: SearchPattern) -> AsyncStream<[MediaFile]>
}

public struct SearchRenameLedger: Sendable {
    public init()
    public var isEmpty: Bool { get }
    public mutating func addStream(visits: SearchVisitLog) -> Int
    public func hasVisited(_ folder: URL) -> Bool
    public mutating func recordRename(_ renamed: RenamedFolder, visited: Bool)
    public func place(_ file: MediaFile, fromStream index: Int) -> MediaFile?
}
```

`Sources/MediaViewerCore/Browser/BrowserModel.swift`

```swift
public enum LocationEvent: Sendable, Equatable {
    case navigated(leavingFocus: URL?)
    case openedSearchResultFolder(leavingFocus: URL?)   // 新規
    case relocated(vanished: [URL])
    case notFound(HistoryLocation)
}
```

```swift
// 操作の経路を加える。既定値 .tree で既存の呼び出しの意味を保つ（EC-101）
@discardableResult
public func leaveTrashedFolders(_ trashed: [URL], origin: OperationOrigin = .tree) async -> Bool
```

`BrowserModel` の公開 API は、`leaveTrashedFolders` に `origin` を加えるほか、`public func completeSearchResultTreeSync(_ request: TreeSyncRequest, selectedFolder: URL)` を追加する（EC-102）。同期完了の保留 ID・現在の依頼・一覧・選択先の祖先関係を Core で検査し、検索結果から開いた依頼の `lastFolder` だけを更新する（research.md R10）。`openItem(_:)` は検索結果のフォルダの行でも中を表示する（従来から `.folder` の行で動く）。

| 呼び出し | 検索結果の表示中の結果 |
|---|---|
| `openItem(folderRowURL)` | 列挙を止め、検索結果の表示を終え、そのフォルダの一覧を読み込む。`treeSyncRequest` を出し、開いた場所をいったん `lastFolder` に保存し、`onLocationEvent(.openedSearchResultFolder)` を送る。同期完了後は EC-102 に従い選択できた祖先を保存する |
| `openItem(mediaRowURL)` | 何もしない（従来どおり） |
| `didRenameFolder(from:to:)`（フォルダの行そのもの） | 行の URL・名前・中の結果の場所を付け替え、必要なら並べ直す。キーワードに一致しなくなっても残す |
| `reloadCurrentFolder()` / `handleFileSystemEvent(_:)` | 存在しなくなったフォルダの行と、その中の結果をすべて外す |
| `leaveTrashedFolders(_:origin: .fileList)`（検索前のフォルダかその祖先） | 親へ移らずに false を返す。検索結果の表示・`listing.folder`・`lastFolder` は変えない。続く `reloadCurrentFolder()` で行と中の結果が外れる（EC-101） |
| `leaveTrashedFolders(_:origin: .tree)`（同） | 従来どおり親へ移って検索結果の表示を終え、true を返す（FR-079） |
| 検索結果の一覧からの移動（`FileOperationCoordinator.transfer` → `reloadCurrentFolder()`。検索前のフォルダかその祖先） | `leaveTrashedFolders` を呼ばない（既存どおり）。検索結果の表示・`listing.folder`・`lastFolder` は変えず、行と中の結果が外れる（EC-101） |
| 上の2つの後の `selectFolder(listing.folder)`（Esc）・`HistoryNavigator.goBack()`（⌘[） | 検索結果の表示を終え、検索前のフォルダがないため `onLocationEvent(.notFound)` になり、その場所を履歴に記録しない（EC-101、EC-62） |

### ツリー同期の完了（EC-102）

`completeSearchResultTreeSync(_:selectedFolder:)` は、検索結果のフォルダを開く依頼の保留 ID と現在の同期依頼が一致し、一覧がそのフォルダのままで、選択先がその場所または祖先である場合だけ、`lastFolder` を選択先へ更新する。検索・zip の表示中、`.notFound`、次のナビゲーション後、重複、通常のフォルダ移動や履歴からの同期は受け入れない。App は行を選べたときに通知し、最も近い表示可能な祖先は既存の `expandAncestors(of:)` の戻り値を使う。Core は一覧・履歴・フォーカスを変えず、ディスクも読まない（R10、T061〜T063）。

## 検索の照合（search.md の差分）

| 入力 | 結果 |
|---|---|
| キーワード `kyoto`、起点の配下に `2024_Kyoto/`（中に `IMG_0001.jpg`）と `kyoto_map.png` | `2024_Kyoto`（フォルダの行）と `kyoto_map.png`。`IMG_0001.jpg` は出ない（US15-AS1） |
| `*_Kyoto`、`2024_Kyoto/` と `2024_Kyoto_old/` | `2024_Kyoto` だけ（US15-AS2） |
| 起点 `Kyoto/` の配下に `.kyoto/`・`Kyoto.app/`・`kyoto_link`（フォルダへのリンク）・`kyoto.zip` | どれも出ない。起点も出ない（US15-AS6） |
| `kyoto/` の中に `kyoto_01.jpg`・`kyoto_day2/`・`IMG_0002.jpg` | `kyoto`・`kyoto_01.jpg`・`kyoto_day2` の3件（US15-AS9） |
| `2024.10` と `*.jpg`、フォルダ `2024.10_trip/` と `photos.jpg/` | 前者は `2024.10_trip`、後者は `photos.jpg`（フォルダ）に一致（EC-97） |
| 名前が一致する読み取り権限のないフォルダ | 行として出る。中は辿らない（EC-33・EC-91） |

## UI の差分（contracts/keyboard-and-menus.md の「検索結果を表示している間」）

変更後の箇条（実装・検証の後に product へ反映する）:

- 一覧の上部の検索バーの件数は、一致したファイルとフォルダの合計（内訳は出さない。A-81）。検索中は途中の合計
- 先頭行の `..` は出ない。⌘↑ と「上の階層へ」は何もしない（淡色）。**⌘↓・ダブルクリック・「ファイル > 中を表示」・右クリックメニューの「中を表示」は、フォーカス行がフォルダの行なら、検索結果の表示を終えて（検索中なら止めて）そのフォルダの一覧を表示し、ツリーでもそのフォルダを選択する（表示されない場合は最も近い表示可能な祖先を選択・保存し、一覧と履歴は開いた場所のまま。EC-102。フォーカスはファイルリストのまま）。メディアの行では何もしない**（FR-140）
- リスト形式の「名前」「作成日」「種類」「場所」列は、フォルダの行でも通常のフォルダの一覧と同じ値（汎用フォルダのアイコン、種類「フォルダ」、作成日、場所はそのフォルダを含むフォルダ）。ファイルとフォルダは区別せず列の順に混ぜて並べる。サムネイル形式は汎用フォルダのアイコンと名前で、場所はツールチップ（FR-084・FR-139）
- フォルダの行を選ぶとプレビューは空になり、再生中の動画は止まる。フルスクリーン中の矢印キーの移動はフォルダの行を飛ばし、スライドショーの対象にならない（FR-139）
- 種類フィルタはフォルダの行を隠さない。一致したメディアがフィルタで1件も残らないときは、フォルダの行と絞り込み中のメッセージを出す。一致がフォルダだけのときはメッセージを出さない。何も一致しないときは「該当する項目はありません」（EC-32・EC-96、FR-139）
- Return（名前の変更）・⌘C・⌘D・⌘Delete・⌘O・ドラッグは、フォルダの行にも通常のフォルダの一覧と同じに使える。⌘V・⌥⌘V はフォルダの行を選択中も何もしない（淡色）（FR-087）
- ゴミ箱に入れた・移動したフォルダ（アプリの外での削除・移動を含む）は、その中の結果とともに一覧から消える。検索結果の一覧からのゴミ箱・移動では、検索前のフォルダやその祖先を入れた・移した場合も検索結果の表示を続け、続く Esc・⌘[ では「フォルダが見つかりません」になる（EC-101）。名前を変更したフォルダの行は新しい名前で残り、中の結果の場所も新しい名前になる（FR-087・FR-105）

## 右クリックメニュー（ファイルリスト）の差分

- 検索結果を表示中は、メディアの行には通常のフォルダのメディアの行と同じ項目を出し、**フォルダの行には通常のフォルダのフォルダの行と同じく、ファイル操作の前に「中を表示（⌘↓）」と区切り線を出す**。「ペースト」「移動ペースト」は淡色で選べず、「上の階層へ」はどの行でも出さない（FR-087・FR-140）
- 既存の実装は、メディアの行にも「中を表示」を淡色で出しており、product の契約（フォルダ・zip ファイルの行にだけ加える）と食い違う。本 feature の前からある食い違いのため、本差分では扱わない（research.md R6 の注記）。扱い（bug の候補か、契約を実装に合わせる別の feature の候補か）は、product への反映の前に tasks の T059 でユーザーに確認して記録する。product の契約へは FR-140 を spec の文言のまま反映し、右クリックメニューの既存の記述は変えない

## 履歴（navigation-history.md・contracts の「検索結果の表示中の履歴」の差分）

| 操作 | 履歴 |
|---|---|
| 検索結果でフォルダの行 F を開く（検索前の場所 A と異なる） | 検索結果の表示を終えた時点の表示の状態を A に反映し、F を新しい履歴として記録する。進む側は取り除く。続けて ⌘[ で A（検索結果には戻らない） |
| 検索結果で A のフォルダの行を開く（起点が A の祖先） | A の表示の状態を反映するだけで、新しい履歴は記録しない。続けて ⌘[ で A より前、なければ「戻る」は無効（EC-99） |
| zip の中の階層 D で始めた検索の結果でフォルダの行 F を開く | D の表示の状態を反映し、F を D の次に記録する。zip を含むフォルダの一覧は記録しない。続けて ⌘[ で D（EC-100） |
| Esc・⌘[・ツリーの選択による検索結果の終了 | 変更なし（FR-113 の既存の規則） |

## 変えないもの

- 検索のモーダル（入力欄・ボタン・キー）・検索起点の確認・前回のキーワードの扱い
- ツリーでのゴミ箱（FR-079）・ツリーからの検索結果の終了の履歴
- 通常のフォルダの一覧・zip の中の一覧の行・操作・メッセージ
- 保存する設定（UserDefaults のキー）。検索結果と検索条件は従来どおり保存しない
