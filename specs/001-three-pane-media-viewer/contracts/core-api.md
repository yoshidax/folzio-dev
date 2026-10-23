# Contract: MediaViewerCore の公開インターフェース

UI（`MediaViewerApp`）が依存する、Core ライブラリの境界。テストはこの境界に対して書く（原則 IV）。
シグネチャは設計上の意図を示すもので、引数名などの細部は実装時に調整してよい。ただし責務の分担は変えない。
エンティティの定義は [data-model.md](../data-model.md) を参照。

## 形式判定

```swift
public enum MediaKind: Sendable {
    public init?(fileExtension: String)   // 大文字小文字を区別しない。非対応形式なら nil
    public var isVideo: Bool { get }
}

/// ファイルリストの行の種類（FR-068〜070・076・077、data-model.md）。MediaFile.kind の型
public enum ListItemKind: Sendable, Hashable {
    case media(MediaKind)
    case archive        // 通常のフォルダの zip ファイル
    case folder         // 通常のフォルダのサブフォルダ（ファイル操作の対象）
    case directory      // zip の中のディレクトリ（読み取り専用）
    case parent         // 先頭行 `..`（zip の中と、ツリーのルート以外の通常のフォルダ）
    public var isMedia: Bool { get }
    public var mediaKind: MediaKind? { get }
    public var isVideo: Bool { get }          // .media の動画だけ true
    public var opensAsContainer: Bool { get } // .archive / .folder / .directory / .parent
}
```

## ディレクトリ・ボリューム

```swift
public protocol DirectoryListing: Sendable {
    /// 直下のサブフォルダ（kind = .folder。判定は subfolders(of:) と同じで、隠しフォルダ・パッケージは除く）、
    /// 対応メディアファイル、zip ファイル（.zip、kind = .archive）を返す（隠しファイル・非対応形式は除く。FR-008・068・076）。
    /// 1回のディレクトリの列挙から作り、並べ替えはしない
    func mediaFiles(in folder: URL) async throws(ListingError) -> [MediaFile]
    /// 直下のフォルダのみを返す（隠しフォルダ・パッケージは除く）。名前の自然順
    func subfolders(of folder: URL) async throws(ListingError) -> [URL]
    /// subfolders(of:) が返すフォルダが直下に1つでもあるか。最初の1件で打ち切る（FR-054・055）
    func hasSubfolders(in folder: URL) async throws(ListingError) -> Bool
}

extension DirectoryListing {
    /// 既定実装: !subfolders(of:).isEmpty。DirectoryLister は列挙を打ち切る実装で置き換える
    public func hasSubfolders(in folder: URL) async throws(ListingError) -> Bool
}

public enum ListingError: Error { case accessDenied, notFound, other(String) }

public struct SubfolderProbeResult: Sendable {
    public let url: URL
    public let result: Result<Bool, ListingError>
}

public enum SubfolderProbe {
    /// urls を表示順に確認し、URL ごとに1回ずつ結果を流す。同時に実行する確認は maxConcurrent 件まで。
    /// ストリームの終了（取り消し）で未実行の確認は行わない
    public static func results(
        for urls: [URL],
        lister: any DirectoryListing,
        maxConcurrent: Int = 4
    ) -> AsyncStream<SubfolderProbeResult>
}

extension FolderNode {
    // AccessState に .unavailable（権限以外の理由で展開時に読めない。再展開で読み直す）を追加する
    public enum AccessState: Sendable { case unknown, accessible, denied, unavailable }
    public enum SubfolderState: Sendable { case unknown, present, absent, failed }
    public var subfolderState: SubfolderState            // 既定 .unknown
    public var isExpandable: Bool { get }                 // accessState != .denied && (.present || .failed)
    public mutating func applySubfolderProbe(_ result: Result<Bool, ListingError>)
    public mutating func applySubfolderListing(_ result: Result<Int, ListingError>)  // 子の件数
}

public enum FolderDisclosure {
    public enum Toggle: Sendable, Equatable { case expand, collapse, none }
    /// ツリーの行のダブルクリックで行う開閉（FR-053）
    public static func doubleClickToggle(isExpandable: Bool, isExpanded: Bool) -> Toggle
}

public protocol VolumeProviding: Sendable {
    func rootNodes() -> [FolderNode]                    // ホームフォルダ + マウント中のボリューム
    var changes: AsyncStream<[FolderNode]> { get }      // マウント・取り外しのたびに最新のルートを流す
}

public protocol FileSystemWatching: Sendable {
    /// 監視対象を差し替える。直下の追加・削除・名前変更が起きたフォルダの URL を流す。
    /// ツリーは表示中のフォルダ（ルートと展開中のフォルダの子）も渡し、三角の有無を追従させる（FR-054）。
    /// subtrees のフォルダは配下のすべての階層を監視し、変更のあったパスの親フォルダを流す（検索結果の整理、FR-087・R38）。
    /// 流す URL は渡された起点の URL に相対の要素をつないで組み立て、FSEvents の /private 付きの実体パスをそのまま流さない。
    /// 起点自身またはその祖先の削除・移動も、渡された起点の URL として流す（kFSEventStreamCreateFlagWatchRoot）。
    /// subtrees の配下でも、隠しフォルダ（名前が "." で始まる、または isHidden。例: ~/Library）の中の変更は流さない。
    /// 送出は最後の変更から 0.3 秒後、ただし最初の未送出の変更から最大 1 秒で必ず行う（変更が続いても通知を止めない）
    func watch(_ folders: Set<URL>, subtrees: Set<URL>)
    var events: AsyncStream<Set<URL>> { get }
}

extension FileSystemWatching {
    /// 既定実装: watch(folders, subtrees: [])（既存の呼び出しを壊さない）
    public func watch(_ folders: Set<URL>)
}
```

## お気に入り

```swift
public struct FavoriteFolders: Sendable, Equatable {
    public private(set) var urls: [URL]                 // 登録順。standardizedFileURL.path で一意
    public init(urls: [URL] = [])                       // 重複は先勝ちで除く
    public func contains(_ url: URL) -> Bool
    @discardableResult public mutating func add(_ url: URL) -> Bool     // 末尾に追加。登録済みなら false（FR-062）
    @discardableResult public mutating func remove(_ url: URL) -> Bool  // 登録だけを取り除く（FR-064）
}

public enum FavoriteAvailability: Sendable, Equatable { case unknown, available, missing }  // FR-067

public enum TreeItemRole: Sendable, Equatable {
    case favoritesHeader
    case favorite(URL)
    case folder(URL)                                    // ホーム・ボリュームのルートを含む
}

public enum TreeContextMenuItem: Sendable, Equatable {
    case pasteHere, movePasteHere, addToFavorites, revealInFinder, removeFromFavorites
    case moveToTrash                                    // ツリーのフォルダをゴミ箱に入れる（FR-079、R33）
    case separator
}

public enum FavoriteCommands {
    /// ⌃⌘T と「お気に入りに追加」。.folder かつ未登録のときだけ true
    public static func canAdd(_ role: TreeItemRole?, favorites: FavoriteFolders) -> Bool
    /// ⌘⌫ と「お気に入りから削除」の対象。.favorite のときだけ URL を返す
    public static func removalTarget(_ role: TreeItemRole?) -> URL?
    /// ⌘⌫ と右クリックメニューの「ゴミ箱に入れる」の対象。.folder で、かつルート（FolderNavigation.enclosingFolder が nil）でない
    /// ときだけ URL を返す。.favorite・.favoritesHeader・nil は nil（FR-064・079）
    public static func trashTarget(_ role: TreeItemRole?, roots: [URL]) -> URL?
    /// 右クリックメニューの項目と並び。.favoritesHeader は空。trashTarget が URL を返す行では先頭に .moveToTrash と区切り線を置く。
    /// roots の既定値は空（このとき .moveToTrash を出さない）
    public static func contextMenu(for role: TreeItemRole, roots: [URL] = []) -> [TreeContextMenuItem]
    /// 選択したときに一覧を切り替えるフォルダ。.favoritesHeader は nil（FR-065）
    public static func folderToShow(for role: TreeItemRole) -> URL?
    /// ドロップ・ペーストを受け付けるか。.folder だけ true（アクセス可否は従来どおり UI 側で見る）
    public static func acceptsFiles(_ role: TreeItemRole) -> Bool
}

public struct FavoriteProbeResult: Sendable, Equatable {
    public let url: URL
    public let exists: Bool                             // ディレクトリとして存在するか
}

public enum FavoriteProbe {
    /// 既定の判定: fileExists(atPath:isDirectory:) がディレクトリを返すか。UI スレッドから呼ばない
    public static func folderExists(_ url: URL) -> Bool
    /// urls を順に確認し、URL ごとに1回ずつ結果を流す。同時に実行する確認は maxConcurrent 件まで。
    /// ストリームの終了（取り消し）で未実行の確認は行わない
    public static func results(
        for urls: [URL],
        maxConcurrent: Int = 4,
        exists: @escaping @Sendable (URL) async -> Bool = { folderExists($0) }
    ) -> AsyncStream<FavoriteProbeResult>
}
```

- 判断（追加・削除・ゴミ箱の可否、右クリックメニュー、選択時の一覧の切り替え、ドロップの可否）は `FavoriteCommands` だけで行い、
  UI は行から `TreeItemRole` を作って渡す。表 [data-model.md](../data-model.md) の「TreeItemRole と FavoriteCommands」と一致させる
- `FavoriteProbe` は `SubfolderProbe` と同じく、取り消しに追従し、URL ごとの失敗をほかに波及させない

## 並べ替え

```swift
public enum SortColumn: String { case name, creationDate, kind, location }  // location は検索結果の表示中だけ（FR-084）。保存しない
public func sorted(_ files: [MediaFile], by order: SortOrder) -> [MediaFile]
/// 並べ替え済みの2つの配列から、sorted(existing + incoming, by: order) と同じ順序の配列を1回の走査で作る。同順位は existing が先（R36）。
/// 列の値と名前の第2キーが同じ行は同順位で、相対順は届いた順（別フォルダの同名ファイルは起動や検索のたびに変わりうる）
public func sortedMerge(_ existing: [MediaFile], _ incoming: [MediaFile], by order: SortOrder) -> [MediaFile]
```

- `.location` はファイルを含むフォルダのパスの自然順で比べ、同じ値なら名前の自然順を第2キーにする

## ブラウザ状態（UI から呼ぶ中心のモデル）

```swift
@MainActor public final class BrowserModel {
    public private(set) var listing: FolderListing
    public private(set) var selection: SelectionState
    public private(set) var preview: PreviewContent
    public var sortOrder: SortOrder
    public private(set) var mediaTypeFilter: MediaTypeFilter  // 既定は両方オフ。保存しない（FR-056）

    public func selectFolder(_ url: URL) async        // 前の読み込みを取り消してから一覧を読み込む。種類フィルタは保つ
    public func setMediaTypeFilter(_ filter: MediaTypeFilter) // 一覧を絞り直し、選択を整理する（FR-059）。ディスクは読まない
    public func select(_ urls: Set<URL>, focused: URL?)
    public func moveFocus(_ direction: FocusDirection) // 前後の項目。プレビューと先読みを更新する
    public func handleFileSystemEvent(_ folders: Set<URL>) async

    // zip（FR-069・070、research.md R23・R26）
    public func openItem(_ url: URL) async              // zip の行・ディレクトリなら中へ、`..` なら上へ。メディアの行では何もしない
    public func goToEnclosingLevel() async              // zip の中なら1つ上へ（最上位ならフォルダの一覧へ）。zip の外では親フォルダへ（戻る先がなければ何もしない）
    public var isBrowsingArchive: Bool { get }          // listing.archive != nil

    // ファイルリストのフォルダ（FR-076〜078、research.md R29〜R31）
    public func setNavigationRoots(_ urls: [URL])       // ツリーのルート（ホーム・ボリューム）。変わったら一覧の `..` を作り直す。既定は空（`..` を出さない）
    public var hasEnclosingLevel: Bool { get }          // zip の中、または FolderNavigation.enclosingFolder が nil でない
    public var operableSelection: [URL] { get }         // 一覧の並び順の選択から `.parent` を除いたもの。ファイル操作・コピー・ドラッグの対象
    public private(set) var treeSyncRequest: TreeSyncRequest? // フォルダを開く・`..`・⌘↑ で親へ戻るたびに id を増やして出す

    // ツリーのフォルダのゴミ箱（FR-079、research.md R33）
    /// ゴミ箱に入れたフォルダが表示中のフォルダ（zip の中なら zip を含むフォルダ）自身か祖先なら、その親へ移って true を返す。
    /// 移り方は `..` で親へ戻るときと同じ（読み込みの取り消し・選択とプレビューを空に・動画の停止・lastFolder の保存・treeSyncRequest）。
    /// ただし直前のフォルダの行は選択しない。該当しなければ何もせず false
    @discardableResult public func leaveTrashedFolders(_ trashed: [URL]) async -> Bool

    // ファイル名の検索（FR-080〜087、research.md R36〜R38）
    public var isShowingSearchResults: Bool { get }     // listing.search != nil
    /// 実行中の検索を止め、選択・プレビューを空にして（動画は停止）検索を始める。結果はバッチごとに listing.files へ並べ替えて加える。
    /// listing.folder・lastFolder・treeSyncRequest は変えない。種類フィルタは保つ。列挙が終わるまで待たずに戻る
    public func startSearch(_ pattern: SearchPattern, root: URL)
    /// 検索結果の表示中だけ、名前を変更した行の URL・名前・種類を差し替えて並べ直し、選択とフォーカスも置き換える。
    /// 新しい名前が対応メディアでなければ行を外す。検索結果の表示中でなければ何もしない（FR-087）
    public func didRenameItem(at oldURL: URL, to newURL: URL)
}

public struct TreeSyncRequest: Sendable, Equatable {
    public let folder: URL
    public let id: Int
}

/// 通常のフォルダの戻る先（data-model.md の FolderNavigation）
public enum FolderNavigation {
    /// folder がルートと同じ、またはどのルートにも含まれなければ nil。含むルートのうち最も深いものの中での親を返す
    public static func enclosingFolder(of folder: URL, roots: [URL]) -> URL?
    /// showing が trashed のどれか自身かその配下なら、該当する最も浅いフォルダの enclosingFolder を返す。該当しなければ nil（FR-079）
    public static func folderToShow(afterTrashing trashed: [URL], showing: URL, roots: [URL]) -> URL?
}

/// 通常のフォルダの `..` の行の URL（data-model.md の ParentLink）
public enum ParentLink {
    public static let scheme: String                    // "mvparent"
    public static func url(for folder: URL) -> URL
    public static func isParentLink(_ url: URL) -> Bool
}
```

- `selectFolder(_:)` は zip の状態（`listing.archive` と索引）を捨ててから、そのフォルダを読み込む（FR-069）
- `openItem` で中へ入ったときは選択とプレビューを空にする。戻ったときは、出てきた zip ファイルまたはディレクトリの行だけを
  `select([url], focused: url)` と同じ経路で選択する（FR-070）。プレビューは FR-075 により空になる
- `select(_:focused:)` は、フォーカス行がメディアでなければプレビューを `.empty` にする（FR-075）。動画の停止通知は既存どおり
- `handleFileSystemEvent` は、zip の中を表示中なら `ArchiveIdentity` を比べ、zip が変わった・消えたときだけ zip を閉じてフォルダを読み直す
- `lastFolder`（FR-003）は zip の中へ入っても変えない
- `openItem` で `.folder` の行を開く、通常のフォルダで `..` を開く、`goToEnclosingLevel()` で親フォルダへ戻る、の3つは
  `selectFolder(_:)` と同じく読み込みを取り消してから読み直し、`lastFolder` を保存し、種類フィルタを保つ。親へ戻ったときは、
  直前まで表示していたフォルダの行だけを選択する。3つとも `treeSyncRequest` を出す。`selectFolder(_:)`（ツリーからの選択）、
  zip の中の移動、`handleFileSystemEvent` で表示中のフォルダが消えて親へ移る経路では出さない。`leaveTrashedFolders` で親へ移ったときは出す
  （ツリーの実際の階層で親を選ぶため。R33）
- `listing.files` の先頭の `..` は、zip の中では常に、通常のフォルダでは `hasEnclosingLevel` のときだけ置く。`.denied` / `.failed` の
  通常のフォルダでは、`files` を `..` だけにする（`hasEnclosingLevel` でなければ空）。ダブルクリック・⌘↓・⌘↑ のどれでも戻れる（FR-077）

検索結果の表示中（`isShowingSearchResults`）の既存のメソッドの振る舞い（research.md R37・R38）:

- `selectFolder(_:)`・`openItem(_:)` で別の一覧へ移る経路・`leaveTrashedFolders(_:)` で親へ移る経路は、`resetForNavigation` で実行中の検索を止め、
  `listing.search` を nil にする。`sortOrder.column == .location` なら保存済みの並べ替えに戻す
- `hasEnclosingLevel` は false、`listing.files` に `..` を置かない。`setNavigationRoots(_:)` も `..` を作らない
- `reloadCurrentFolder()` はディスクを列挙し直さず、結果の URL の存在を UI スレッドの外で確かめて、消えたものを外す。フォーカスが外れたらプレビューを空にする
- `handleFileSystemEvent(_:)` は、届いたフォルダのいずれか以下にある結果だけを同じく確かめて外す。`listing.folder` が消えても親へ移らない
- `sortOrder` の `didSet` は `.location` を設定に書かない。検索結果の表示中でなければ `.location` への代入を受け付けず `oldValue` に戻す。
  戻す代入の間は設定の書き込みと並べ直しを行わない（`didSet` の再入を避ける）
- `focusedItemCommands` / `selectionItemCommands` は `isShowingSearchResults` を `ListItemCommands` に渡す

```swift
/// 検索キーワード（data-model.md の SearchPattern、research.md R34）
public struct SearchPattern: Sendable, Equatable {
    public init?(keyword: String)            // 前後の空白を除いて空なら nil
    public var keyword: String { get }       // 前後の空白を除いたもの
    public var usesWildcards: Bool { get }   // `*` か `?` を含む
    /// ファイル名（拡張子を含む）だけと照合する。NFC と大文字小文字をそろえる。ワイルドカードなしは部分一致、ありは全体一致
    public func matches(fileName: String) -> Bool
}

/// 検索起点ディレクトリ（data-model.md の SearchRoot、research.md R35）
public enum SearchRootError: Error, Sendable, Equatable {
    case empty, notAbsolute, notFound, notAFolder, accessDenied
    public var message: String { get }       // モーダルの入力欄の下に出す文言
}

public enum SearchRoot {
    /// 前後の空白を除き、`~` / `~/` をホームに置き換え、末尾の `/` を除く。ディスクは読まない
    public static func parse(_ input: String, home: URL) -> Result<URL, SearchRootError>
    /// 存在・フォルダか（パッケージと zip ファイルは不可）・読めるかを UI スレッドの外で確かめる。シンボリックリンクはリンク先にする
    public static func validate(_ url: URL) async -> Result<URL, SearchRootError>
}

/// 検索結果の表示の状態（data-model.md の SearchListing）。FolderListing.search に置く
public struct SearchListing: Sendable, Equatable {
    public enum Phase: Sendable, Equatable { case searching, finished }
    public var keyword: String
    public var root: URL
    public var phase: Phase
    public var totalCount: Int               // 種類フィルタ適用前の件数
    /// 「場所」列の文字列。起点のフォルダ名から始まる、ファイルを含むフォルダのパス（起点が `/` なら絶対パス）
    public func location(of fileURL: URL) -> String
}

/// ファイル名の検索（research.md R36）
public protocol FileNameSearching: Sendable {
    /// root 以下のすべての階層を辿り、名前が pattern に一致する対応メディアファイル（FR-039）をバッチで流す。
    /// 隠しファイル・隠しフォルダ・パッケージの中・シンボリックリンクのフォルダは辿らず、読めないフォルダは飛ばす。zip の中は開かない。
    /// ファイルへのシンボリックリンクは、DirectoryLister と同じく通常のファイルとして拡張子と名前で照合する（FR-083）。
    /// 全階層を辿り終えたら終える。ストリームの終了（取り消し）で列挙を止める。UI スレッドで列挙しない
    func search(in root: URL, matching pattern: SearchPattern) -> AsyncStream<[MediaFile]>
}

public struct FileNameSearcher: FileNameSearching {
    public init(batchSize: Int = 256, batchInterval: Duration = .milliseconds(100))
}
```

- `BrowserModel` のイニシャライザに `searcher: any FileNameSearching = FileNameSearcher()` を足す（既存の呼び出しとテストを壊さない）
- `FileNameSearcher` が返す `MediaFile` は `DirectoryLister.mediaFiles(in:)` と同じ値の作り方（`kind: .media(...)`・種類の説明・作成日・サイズ）

- UI は `BrowserModel` の変化を監視して描画するだけにし、選択・プレビュー・先読みの判断を UI に持たせない
- `listing.files` は種類フィルタ適用後の配列。絞り込みで0件のときは `listing.state == .noMatches` になる（FR-060）
- `setMediaTypeFilter` は、フォーカスが変わらないときは `selection` だけを差し替え、プレビューを読み直さない。
  フォーカスが変わるとき（nil を含む）は `select(_:focused:)` と同じ経路で動画の停止・プレビュー・先読みを更新する

## 種類フィルタ

```swift
public struct MediaTypeFilter: Sendable, Equatable {
    public var imagesOnly: Bool                     // 既定 false
    public var videosOnly: Bool                     // 既定 false
    public init(imagesOnly: Bool = false, videosOnly: Bool = false)
    public var isFiltering: Bool                    // 片方だけがオン
    public func includes(_ kind: MediaKind) -> Bool
    public func apply(to files: [MediaFile]) -> [MediaFile]   // 並び順を保つ。kind が .media 以外の行は常に残す（FR-056）
    public var noMatchesMessage: String?            // isFiltering のときだけ文言を返す（FR-060）
}

extension SelectionState {
    // 表示中の URL（一覧の並び順）に合わせて選択を整理する（FR-059）
    public func restricted(toVisible orderedURLs: [URL]) -> SelectionState
}
```

## プレビュー用デコード

```swift
public protocol ImageDecoding: Sendable {
    /// 長辺 maxPixelSize 以下にダウンサンプリングしてデコードする。アニメーションなら先頭フレーム
    func decode(_ url: URL, maxPixelSize: Int) async throws(DecodeError) -> DecodedImage
    func isAnimated(_ url: URL) -> Bool             // ファイル URL 専用（同期）。mvzip の URL では呼ばない
    /// zip の中の画像用。ArchiveReading.data(for:) で読んだ内容を渡す（research.md R24）
    func decode(data: Data, maxPixelSize: Int) async throws(DecodeError) -> DecodedImage
    func isAnimated(data: Data) -> Bool
}

public enum DecodeError: Error { case unreadable, unsupported, corrupted }

public actor DecodedImageCache {
    public init(costLimitBytes: Int)                   // 既定は 256MB（research.md R8）
}

public struct FitCalculator {
    /// 縦横比を保ってコンテナに収まる最大の矩形を、コンテナ中央に返す。拡大率に上限はなく、
    /// コンテナより小さい画像は拡大される（FR-028）。画像はトリミングしない
    public static func fit(imageSize: CGSize, in container: CGSize) -> CGRect
}
```

- スケールは `min(container.width / imageSize.width, container.height / imageSize.height)`。
  1 を上限にしないため、小さい画像では 1 を超える
- 返す矩形は `imageSize × スケール` をコンテナ内で中央に置いたもの。はみ出しも切り取りも生じない
- 幅・高さのいずれかが 0 以下の入力では `.zero` を返す（ゼロ除算を避ける）
- 呼び出し側は画像とコンテナを同じ単位（ピクセルまたはポイント）で渡す。`ImagePreviewView` は
  バッキング倍率を掛けたピクセルで計算し、結果をポイントに戻して配置する

## サムネイル

```swift
public protocol ThumbnailProviding: Sendable {
    /// 要求サイズは 64 / 128 / 256 / 512 の段階に丸める。結果はメモリにのみキャッシュする
    func thumbnail(for url: URL, pointSize: Double, scale: Double) async -> CGImage?
    /// 指定した URL と要求サイズの進行中要求だけを取り消す。他のサイズの要求は取り消さない
    func cancel(for url: URL, pointSize: Double, scale: Double)
}

public struct ThumbnailGridLayout {
    /// 利用可能な幅とサムネイルサイズから、列数と実際のセル幅を返す。
    /// セル幅は利用可能な幅を超えない（横スクロールを出さない: FR-015）
    public static func columns(availableWidth: Double, thumbnailSize: Double, spacing: Double) -> (count: Int, cellWidth: Double)
}

public struct ThumbnailScroll {
    /// フォーカス項目全体が見える最小の縦スクロール原点を返す（FR-017）。
    /// 既に見えていれば現在の可視原点を返す。0...(contentHeight - visibleHeight) にクランプし、
    /// ビューポートより高い項目は上端を合わせる。横方向は扱わない
    public static func offsetY(
        itemMinY: Double,
        itemMaxY: Double,
        visibleMinY: Double,
        visibleHeight: Double,
        contentHeight: Double
    ) -> Double
}
```

- `ThumbnailModeView` はレイアウト済みの `layoutAttributesForItem(at:)` のフレームと
  `scrollView.contentView.bounds` をこの関数へ渡し、結果をクリップビューの原点に適用する。
  UI は選択や移動量を自前で判断しない
- 不正な寸法（非有限値、負の高さ、可視高 0 など）では現在の原点を返し、クラッシュしない
- `mvzip` の URL では QuickLook を使わず、画像は `ArchiveReading.data(for:)` の内容から、動画は `ArchiveAssetFactory` の asset から
  `AVAssetImageGenerator` で作る。zip の中の取得は同時 4 件（動画 2 件）まで。暗号化・非対応方式・上限超えでは nil（research.md R24）
- `.archive` / `.directory` / `.parent` の行では縮小画像を要求しない。UI は SF Symbol を出す（data-model.md の IconPresentation）
- リスト形式の行頭アイコン（FR-048）は `pointSize: 16` とバッキング倍率で要求し、32px は
  64px 段階に丸められる。UI は取得中・失敗時に形式別の SF Symbol を表示し、取得後に同じ URL の
  セルへだけ差し替える（`IconPresentation`、[data-model.md](../data-model.md)）。
  セル再利用時は `cancel(for:pointSize:scale:)` で同じ 64px 要求だけを取り消す。
  サムネイル形式が同じ URL を 128px 以上で要求していても、それを巻き込んで取り消してはならない。
  ツリーのフォルダ種別アイコンは `FolderNode.Kind` から SF Symbol を選ぶ UI 表現で、Core の API は増やさない

## 矢印キーによる選択移動

```swift
public enum FocusMove: Sendable {
    case left, right, up, down
}

public enum FocusLayout: Sendable {
    case list
    case grid(columns: Int)
}

public struct FocusNavigator {
    /// 現在位置・件数・移動方向・レイアウトから移動先インデックスを返す（FR-017・046）。
    /// リスト形式は ↑↓ を ±1、←→ は移動なし。グリッドは ←→ を ±1、↑↓ を ∓列数。
    /// 0...(fileCount - 1) にクランプし、空リスト・移動不能（端）では nil を返す。
    /// リスト形式の ←→ は常に nil。currentIndex が nil の場合は 0 を返す。
    public static func targetIndex(
        currentIndex: Int?,
        fileCount: Int,
        move: FocusMove,
        layout: FocusLayout
    ) -> Int?

    /// フルスクリーン用（FR-046）。移動先が isNavigable(index) == false なら、同じ方向に同じ規則で移動を繰り返す。
    /// 移動できる行に当たらないまま端に達したら nil。currentIndex が nil のときは、先頭から順に最初の移動できる行
    public static func targetIndex(
        currentIndex: Int?,
        fileCount: Int,
        move: FocusMove,
        layout: FocusLayout,
        isNavigable: (Int) -> Bool
    ) -> Int?

    /// プレビューのみ表示に切り替えたときの最初のファイル（FR-093）。currentIndex の行が isNavigable ならそのまま。
    /// そうでなければ後ろの最初の isNavigable な行、後ろになければ前の最も近い行。currentIndex が nil なら先頭から最初の行。
    /// 一覧が .loading のときは呼ばない（読み込み完了後も自動選択しない。FR-093・Edge Cases）。isNavigable な行がなければ nil
    public static func entryIndex(
        currentIndex: Int?,
        fileCount: Int,
        isNavigable: (Int) -> Bool
    ) -> Int?
}
```

- 通常表示のサムネイル形式（`ThumbnailModeView`）とフルスクリーン（`FileListViewController`）は
  同じ関数を使い、移動規則を二重実装しない
- 呼び出し側は返されたインデックスを `BrowserModel.select([url], focused: url)` に渡すだけで、
  インデックス計算を UI に持たない
- `columns` が 0 以下の場合は 1 として扱う

- フルスクリーンとプレビューのみ表示（`FileListViewController` の隠れたファイルリストの移動）は `isNavigable` に `files[i].kind.isMedia` を渡す。
  通常表示は `isNavigable` なしの関数を使い、メディア以外の行にも止まる
- `entryIndex` は、プレビューのみ表示に切り替えたときだけ `FileListViewController` が呼び、結果がフォーカス中の行と違えば
  `BrowserModel.select([url], focused: url)` に渡す。nil なら選択を変えない。一覧の状態が `.loading` のときは呼ばず、
  読み込みが終わっても自動選択しない（FR-093・Edge Cases）

## ペインの表示切り替え（FR-088〜094、research.md R40〜R44）

```swift
public enum Pane: Sendable, Equatable, CaseIterable {
    case tree, fileList, preview
}

/// ツールバーのボタンとメニュー項目の対象
public enum SoloPane: Sendable, Equatable {
    case fileList, preview
}

public enum PaneLayout: Sendable, Equatable {
    case all            // 3ペイン表示（既定）
    case fileListOnly   // ツリーとプレビューを隠す
    case previewOnly    // ツリーとファイルリストを隠す

    public init(soloPane: SoloPane?)
    /// ツールバーの押下とメニューのチェックの対象。.all は nil
    public var soloPane: SoloPane? { get }
    /// メニュー・ショートカット。いまその側だけの表示なら .all、そうでなければその側だけの表示（FR-089・090）
    public func toggling(_ pane: SoloPane) -> PaneLayout
    /// ツールバーのボタングループ（selectAny）が報告した押下状態から次の状態を決める（FR-089）。
    /// 両方 true なら直前に押されていなかった側だけを残す（直前が .all なら self）
    public func applyingToolbarSelection(fileListSelected: Bool, previewSelected: Bool) -> PaneLayout
    public func isVisible(_ pane: Pane) -> Bool
    /// 切り替え後にフォーカスを移す先。nil は移さない（FR-091）
    public func focusTarget(afterSwitchingFrom focused: Pane?) -> Pane?
    /// プレビューのみ表示で、読み込み中でなく、表示中の一覧にメディアが1件もないとき true（FR-093）
    public func showsNoMediaMessage(in listing: FolderListing) -> Bool
    /// プレビューのみ表示へ切り替えたときに最初のファイルを選んでよいか。.loading（通常の読み込み中・検索中）は false（FR-093）
    public static func shouldAutoSelectEntry(in listing: FolderListing) -> Bool
}

public struct PanePresentation: Sendable, Equatable {
    public init(layout: PaneLayout, isFullScreen: Bool)
    /// フルスクリーン中は [.preview]。それ以外は layout で表示するペイン（ツリー → ファイルリスト → プレビューの順）
    public var visiblePanes: [Pane] { get }
    public func isVisible(_ pane: Pane) -> Bool
    /// 3つとも表示（ペイン幅の保持・復元と自動保存の再開に使う）
    public var showsAllPanes: Bool { get }
    /// ファイルリストが隠れていてプレビューが見えている（矢印キーで隠れたファイルリストの選択を動かす。FR-046・093）
    public var navigatesHiddenFileList: Bool { get }
}

public struct PaneCommands: Sendable, Equatable {
    public init(layout: PaneLayout, isFullScreen: Bool, isEditingText: Bool)
    public var canChangeLayout: Bool { get }        // ⌃⌘2・⌃⌘3・ツールバー（FR-090・094）
    public func canFocus(_ pane: Pane) -> Bool      // ⌥⌘1〜3（FR-092）
    public var canGoToFavorites: Bool { get }       // ⇧⌘F（FR-065・092）
    public var allowsAddingFavorite: Bool { get }   // ⌃⌘T。ツリー側の判定と AND を取る（FR-062・092）
    public var canSearch: Bool { get }              // ⌘F（FR-080・092）
}

public enum PaneWidths {
    /// 3ペインへ戻すときの2本の仕切りの位置（FR-088）。savedWidths・minimumWidths は ツリー・ファイルリスト・プレビューの3要素。
    /// プレビューが最小幅に足りなければ、ファイルリスト → ツリーの順に最小幅まで詰める。不正な入力では初回の既定（220 / 360 / 残り）
    public static func dividerPositions(
        savedWidths: [Double],
        totalWidth: Double,
        dividerThickness: Double,
        minimumWidths: [Double]
    ) -> [Double]
}
```

- 状態の持ち主は `MainSplitViewController`（`paneLayout`）だけ。`BrowserModel` には持たせない（一覧・選択・プレビューの状態はペインの表示に関わらず同じ）
- 保存しない（`SettingsStore` に書かない）。起動のたびに `.all` で始まる
- UI はこれらの値をメニューの検証・ツールバーの選択・`NSSplitViewItem` の折りたたみ・Tab の巡回・キーのモニタの有無に写すだけにする

## zip ファイルの表示（FR-095〜098、research.md R46・R47）

```swift
public struct ZipFileVisibility: Sendable, Equatable {
    public init(showsZipFiles: Bool = false)
    public var showsZipFiles: Bool
    /// false のとき kind == .archive の行だけを除く（並び順を保ち、メディア・フォルダ・zip の中のディレクトリ・`..` は残す）。
    /// true は入力をそのまま返す
    public func apply(to files: [MediaFile]) -> [MediaFile]
}

// BrowserModel
public private(set) var showsZipFiles: Bool    // 起動時に ViewSettings.showsZipFiles から読む
public func setShowsZipFiles(_ shows: Bool)    // 値を保存 → 一覧の作り直し → restricted(toVisible:) で選択を整理

// ViewSettings
public var showsZipFiles: Bool                 // 既定 false。キーは view.showsZipFiles
```

- 適用は `BrowserModel.rebuildListing()` の1か所だけ。`mediaTypeFilter.apply(to:)` のあとに通し、`allFiles`（列挙済みの全件）は変えない
- zip の中を表示中の `setShowsZipFiles` は設定を保存するだけで、一覧・選択・プレビューを変えない（FR-098）。検索結果の表示中は zip ファイルの行がないため結果は変わらない
- 一覧の状態（`.empty` など）は表示する行で判定する。zip ファイルだけのフォルダを非表示にすると `.empty`
- UI はツールバーの押下・メニューのチェック・`NSTextView` 中の無効化を写すだけで、絞り込みの判断を持たない

## zip（FR-068〜075、research.md R22〜R27）

```swift
/// zip の中の項目の URL（data-model.md の ArchiveURL）。生成と解析はここだけで行う
public enum ArchiveURL {
    public static let scheme: String                                   // "mvzip"
    public static func entry(archive: URL, path: String) -> URL       // ディレクトリはパスの末尾が "/"
    public static func parentLink(of location: ArchiveLocation) -> URL // 表示中の階層の URL + "#parent"
    public static func parse(_ url: URL) -> (archive: URL, path: String, isParentLink: Bool)?
}

public struct ArchiveLocation: Sendable, Hashable {
    public var archive: URL
    public var directory: String        // 最上位は ""、それ以外は "a/b/"
    public var parent: ArchiveLocation? { get }   // 最上位では nil
}

public enum ArchiveError: Error, Sendable, Equatable {
    case notFound
    case accessDenied
    case notAZip                // 終端レコードが見つからない・構造が壊れている
    case multiDisk              // 分割 zip
    case entryEncrypted
    case unsupportedMethod(UInt16)
    case tooLarge               // 画像の 512MB 上限（R24）
    case corrupted(String)
    public var message: String { get }   // 「zip を開けません: …」「暗号化されているため表示できません」など、UI にそのまま出す文言
}

public protocol ArchiveReading: Sendable {
    /// 中央ディレクトリを読んで索引を作る。UI スレッドで呼ばない（R22）
    func open(_ archive: URL) async throws(ArchiveError) -> ArchiveIndex
    /// 項目全体を読む（画像用）。展開後のサイズが limit を超えるなら .tooLarge
    func data(for entryURL: URL, limit: Int) async throws(ArchiveError) -> Data
    /// 項目の範囲読み出し（動画用、R25）。暗号化・非対応方式なら失敗する
    func stream(for entryURL: URL) async throws(ArchiveError) -> ArchiveEntryStream
    /// zip ファイルのいまの同一性。消えていれば nil
    func identity(of archive: URL) -> ArchiveIdentity?
}

public struct ArchiveIndex: Sendable {
    public var archive: URL { get }
    public var identity: ArchiveIdentity { get }
    /// 階層の直下の行（`..`・ディレクトリ・対応メディア）。並べ替え前。`..` は含めず、BrowserModel が先頭に加える
    public func items(in directory: String) -> [MediaFile]
    public func entry(at path: String) -> ArchiveEntry?
}

/// 名前の文字コードの判定（FR-074、R27）
public enum ArchiveNameDecoder {
    public static func decode(_ bytes: Data, utf8Flag: Bool) -> String
}

/// 項目の任意範囲の読み出し（R25）。メモリは格納方式ごとの上限で決まり、項目のサイズに依存しない
public final class ArchiveEntryStream: Sendable {
    public var length: UInt64 { get }
    public func read(offset: UInt64, maxLength: Int) throws(ArchiveError) -> Data
}

/// mvzip の URL から再生・代表フレーム用の AVURLAsset を作る。asset が生きている間、読み込み器を保持する（R25）
public enum ArchiveAssetFactory {
    public static func makeAsset(for entryURL: URL, reader: any ArchiveReading) -> AVURLAsset
}

/// 行の種類・「zip の中か」・「戻る先があるか」・「検索結果か」から操作の可否を返す（FR-073・076・077・087、data-model.md の ListItemCommands）
public struct ListItemCommands: Sendable {
    public init(
        kind: ListItemKind?,
        isBrowsingArchive: Bool,
        hasEnclosingLevel: Bool? = nil,        // nil は isBrowsingArchive と同じ
        isShowingSearchResults: Bool = false
    )
    public var canOpenContainer: Bool      // ダブルクリック・⌘↓
    public var canGoUp: Bool               // ⌘↑。hasEnclosingLevel。検索結果では false
    public var allowsFileOperations: Bool  // 開く・コピー・複製・名前の変更・ゴミ箱・Finder に表示・ドラッグ。zip の中と `.parent` では false
    public var allowsPaste: Bool           // 一覧へのペースト・移動ペースト。zip の中と検索結果では false
}
```

- `ArchiveReading` の既定の実装 `ZipArchiveReader` は、開いた zip のファイル記述子を参照カウントで共有し、`pread` だけで読む。
  一覧・縮小画像・再生のすべてで一時ファイルを作らない（FR-072）
- 名前の要素が `.` で始まる項目、`__MACOSX/` 以下、`..` を含む名前、対応メディア以外のファイルは `items(in:)` に出さない
- `ArchiveEntryStream` は無圧縮なら直接読み、deflate なら `InflateCursor`（2 本、LRU）と 32MB のチャンクキャッシュで読む
- `ArchiveAssetFactory` の asset は `contentType`（拡張子の UTType）・`contentLength`（展開後のサイズ）・範囲読み出しの可否を返し、
  要求範囲を 512KB ずつ応答する。取り消された要求はそこで止める

## ファイル操作

```swift
// 確認モーダルの省略は copy・trash とお気に入りの削除だけ。rename・move は設定に関わらず常に確認する（FR-024）。
// duplicate（同じフォルダへの複製）は確認モーダルの対象外で、設定にも影響されない（FR-018・024）
public protocol FileOperating: Sendable {
    func conflicts(for operation: FileOperation) -> [URL]       // copy・move の操作先に同名がある元ファイル（rename は validateNewName で拒否する）
    func execute(_ operation: FileOperation, resolution: ConflictResolution) async -> FileOperationResult
}

/// copy・move の衝突だけに使う。rename の既存名は NameValidation.invalid として扱う（FR-025）
public enum ConflictResolution: Sendable { case replace, keepBoth, abort }

public enum NameValidation { case ok, needsExtensionChangeConfirmation, invalid(reason: String) }
/// isDirectory が true（フォルダの名前の変更）のときは、拡張子の変更の確認（needsExtensionChangeConfirmation）を返さない（R32）
public func validateNewName(_ name: String, for file: URL, existingNames: Set<String>, isDirectory: Bool = false) -> NameValidation

/// 「両方残す」用の名前を返す: "a.jpg" → "a 2.jpg" → "a 3.jpg" …
public func uniqueName(for name: String, existingNames: Set<String>) -> String
```

## 設定

```swift
public struct SettingsStore {
    public init(defaults: UserDefaults)               // テストでは専用のスイート名を渡す
    public var viewSettings: ViewSettings { get nonmutating set }
    public var playback: PlaybackOptions { get nonmutating set }
    public var confirmation: ConfirmationOptions { get nonmutating set }
    public var favorites: FavoriteFolders { get nonmutating set }   // キー favorites.paths（FR-066）
}
// ViewSettings.showsToolbar: Bool（既定 false）。キーは view.showsToolbar
// ViewSettings.showsZipFiles: Bool（既定 false）。キーは view.showsZipFiles。値がない・Bool でない場合は false（FR-095）
// favorites: 値がない・配列でない場合は空。文字列でない要素・空文字・相対パスは捨て、重複は先勝ちで除く
```

## ファイルリストの周辺表示

```swift
public struct FileListChrome: Sendable, Equatable {
    public init(displayMode: DisplayMode, toolbarShown: Bool)
    public var showsBottomSizeBar: Bool    // サムネイル形式かつツールバー非表示（FR-052）
    public var toolbarSliderEnabled: Bool  // サムネイル形式（FR-051）
}
```
