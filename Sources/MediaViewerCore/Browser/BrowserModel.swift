import Foundation
import Observation

@MainActor
@Observable
public final class BrowserModel {
    public private(set) var listing: FolderListing
    public private(set) var selection: SelectionState
    public private(set) var preview: PreviewContent
    public private(set) var stopPlaybackSignal = 0
    public private(set) var mediaTypeFilter = MediaTypeFilter()
    public var screenMaxPixel: Int
    public var playbackRequest: PlaybackOptions { settings.playback }
    /// zip の中を表示中か（FR-069）
    public var isBrowsingArchive: Bool { listing.archive != nil }
    public var sortOrder: SortOrder {
        didSet {
            guard sortOrder != oldValue else { return }
            var settingsValue = settings.viewSettings
            settingsValue.sortOrder = sortOrder
            settings.viewSettings = settingsValue

            if listing.state == .loaded || listing.state == .empty || listing.state == .noMatches {
                allFiles = sorted(allFiles, by: sortOrder)
                rebuildListing()
            }
        }
    }

    private let lister: any DirectoryListing
    private let decoder: any ImageDecoding
    private let cache: DecodedImageCache
    private let settings: SettingsStore
    private let archiveReader: any ArchiveReading

    /// 表示中の zip の索引。zip の外、または開いている途中・開けなかったときは nil
    private var archiveIndex: ArchiveIndex?
    /// フォルダ・zip の移動のたびに増やし、古い非同期処理の結果を捨てるのに使う
    private var navigationGeneration = 0
    /// 並べ替え済み・種類フィルタ適用前の行。`...` は含めず、`rebuildListing()` で1回だけ加える
    private var allFiles: [MediaFile] = []
    private var listingTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var previewGeneration = 0
    private var prefetchTasks: [URL: Task<Void, Never>] = [:]

    private enum ArchiveImageResult {
        case image(DecodedImage)
        case animated(Data)
        case failure(String)
    }

    public init(
        lister: any DirectoryListing,
        decoder: any ImageDecoding,
        cache: DecodedImageCache,
        settings: SettingsStore,
        archiveReader: any ArchiveReading = ZipArchiveReader()
    ) {
        self.lister = lister
        self.decoder = decoder
        self.cache = cache
        self.settings = settings
        self.archiveReader = archiveReader
        self.sortOrder = settings.viewSettings.sortOrder
        self.screenMaxPixel = 4096

        let folder = settings.viewSettings.lastFolder
            ?? FileManager.default.homeDirectoryForCurrentUser
        self.listing = FolderListing(folder: folder, files: [], state: .empty)
        self.selection = SelectionState()
        self.preview = .empty
    }

    public func selectFolder(_ url: URL) async {
        resetForNavigation()
        archiveIndex = nil
        listing = FolderListing(folder: url, files: [], state: .loading)

        var viewSettings = settings.viewSettings
        if viewSettings.lastFolder?.standardizedFileURL != url.standardizedFileURL {
            viewSettings.lastFolder = url
            settings.viewSettings = viewSettings
        }

        let generation = navigationGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadFolder(url, generation: generation)
        }
        listingTask = task
        await task.value
    }

    /// 一覧の行を開く。zip ファイル・ディレクトリは中へ、`...` は上へ。メディアと一覧にない URL では何もしない（FR-069）
    public func openItem(_ url: URL) async {
        guard let file = listing.files.first(where: { $0.url == url }) else { return }

        switch file.kind {
        case .archive:
            guard listing.archive == nil else { return }
            await openArchive(file.url)
        case .directory:
            guard let location = listing.archive,
                  let index = archiveIndex,
                  let parsed = ArchiveURL.parse(file.url) else { return }
            resetForNavigation()
            showArchiveLevel(ArchiveLocation(archive: location.archive, directory: parsed.path), index: index)
        case .parent:
            await goToEnclosingLevel()
        case .media:
            break
        }
    }

    /// 1つ上の階層へ。zip の最上位からはフォルダの一覧へ戻る。zip の外では何もしない（FR-070）
    public func goToEnclosingLevel() async {
        guard let location = listing.archive else { return }

        if let parentLocation = location.parent {
            guard let index = archiveIndex else { return }
            let previous = ArchiveURL.entry(archive: location.archive, path: location.directory)
            resetForNavigation()
            showArchiveLevel(parentLocation, index: index)
            if listing.files.contains(where: { $0.url == previous }) {
                select([previous], focused: previous)
            }
        } else {
            await returnToFolder(selecting: location.archive)
        }
    }

    public func select(_ urls: Set<URL>, focused: URL?) {
        let previousFocused = selection.focused
        selection = SelectionState(selected: urls, focused: focused)
        if previousFocused != focused {
            stopPlaybackSignal &+= 1
        }
        loadPreview(for: focused)
        schedulePrefetch(around: focused)
    }

    public func setMediaTypeFilter(_ filter: MediaTypeFilter) {
        guard filter != mediaTypeFilter else { return }
        mediaTypeFilter = filter
        switch listing.state {
        case .loaded, .empty, .noMatches:
            rebuildListing()
        case .loading, .denied, .failed:
            break
        }

        let restricted = selection.restricted(toVisible: listing.files.map(\.url))
        if restricted.focused == selection.focused {
            selection = restricted
            schedulePrefetch(around: restricted.focused)
        } else {
            select(restricted.selected, focused: restricted.focused)
        }
    }

    public func reloadCurrentFolder() async {
        // zip の中では、フォルダの一覧で zip の中の一覧を上書きしない
        guard listing.archive == nil else { return }
        let folder = listing.folder
        do {
            let files = try await lister.mediaFiles(in: folder)
            guard listing.folder == folder, listing.archive == nil else { return }

            allFiles = sorted(files, by: sortOrder)
            rebuildListing()

            let available = Set(listing.files.map(\.url))
            let selected = selection.selected.intersection(available)
            let focused = selection.focused.flatMap { available.contains($0) ? $0 : nil }
            selection = SelectionState(selected: selected, focused: focused)
            if focused == nil {
                previewTask?.cancel()
                previewTask = nil
                previewGeneration += 1
                preview = .empty
            }
        } catch {
            guard listing.folder == folder, listing.archive == nil else { return }
            allFiles = []
            listing.files = []
            switch error {
            case .accessDenied:
                listing.state = .denied
            case .notFound:
                listing.state = .failed("フォルダが見つかりません")
            case let .other(message):
                listing.state = .failed(message)
            }
            previewTask?.cancel()
            previewTask = nil
            previewGeneration += 1
            selection = SelectionState()
            preview = .empty
        }
    }

    public func handleFileSystemEvent(_ folders: Set<URL>) async {
        let current = listing.folder.standardizedFileURL
        guard folders.contains(where: { $0.standardizedFileURL == current }) else {
            return
        }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: listing.folder.path,
            isDirectory: &isDirectory
        )
        guard exists, isDirectory.boolValue else {
            await selectFolder(listing.folder.deletingLastPathComponent())
            return
        }

        if let location = listing.archive {
            // 開いている途中は索引がないため、比べずに待つ
            if archiveIndex == nil, listing.state == .loading { return }
            if let identity = archiveReader.identity(of: location.archive),
               identity == archiveIndex?.identity {
                return
            }
            await returnToFolder(selecting: nil)
            return
        }

        await reloadCurrentFolder()
    }

    public func moveFocus(_ direction: FocusDirection) {
        let files = listing.files
        guard !files.isEmpty else { return }

        let currentIndex = selection.focused.flatMap { focused in
            files.firstIndex { $0.url == focused }
        }

        let targetIndex: Int
        switch direction {
        case .previous:
            targetIndex = max(0, (currentIndex ?? 0) - 1)
        case .next:
            targetIndex = min(files.count - 1, (currentIndex ?? -1) + 1)
        }

        let url = files[targetIndex].url
        if currentIndex == targetIndex, selection.selected == [url] {
            return
        }
        select([url], focused: url)
    }

    // MARK: - 一覧

    /// `allFiles`（`...` を含まない）から表示する行と状態を作る。`...` は zip の中のときだけここで1回加える
    private func rebuildListing() {
        let filtered = mediaTypeFilter.apply(to: allFiles)
        if let location = listing.archive {
            listing.files = [Self.parentRow(for: location)] + filtered
        } else {
            listing.files = filtered
        }

        // zip ファイル・ディレクトリ・`...` は「メディアがない」の判定で数えない（FR-060）
        let hasMedia = allFiles.contains { $0.kind.isMedia }
        let hasOtherRows = allFiles.contains { !$0.kind.isMedia }
        if !hasMedia && !hasOtherRows {
            listing.state = .empty
        } else if hasMedia && !filtered.contains(where: { $0.kind.isMedia }) {
            listing.state = .noMatches
        } else {
            listing.state = .loaded
        }
    }

    private static func parentRow(for location: ArchiveLocation) -> MediaFile {
        MediaFile(
            url: ArchiveURL.parentLink(of: location),
            name: "...",
            kind: .parent,
            typeDescription: "",
            creationDate: nil,
            fileSize: 0
        )
    }

    /// 読み込み・プレビュー・先読みの取り消し、動画の停止、選択とプレビューを空にする。
    /// `selectFolder` と zip の中の移動で共有する
    private func resetForNavigation() {
        navigationGeneration += 1
        listingTask?.cancel()
        listingTask = nil
        previewGeneration += 1
        previewTask?.cancel()
        previewTask = nil
        for task in prefetchTasks.values {
            task.cancel()
        }
        prefetchTasks.removeAll()

        if case .video = preview {
            stopPlaybackSignal &+= 1
        }

        selection = SelectionState()
        preview = .empty
        allFiles = []
    }

    /// zip を開いて最上位の一覧を作る。開く間は `.loading`
    private func openArchive(_ url: URL) async {
        resetForNavigation()
        archiveIndex = nil
        listing = FolderListing(
            folder: listing.folder,
            files: [],
            state: .loading,
            archive: ArchiveLocation(archive: url, directory: "")
        )

        let generation = navigationGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadArchive(url, generation: generation)
        }
        listingTask = task
        await task.value
    }

    private func loadArchive(_ url: URL, generation: Int) async {
        let result: Result<ArchiveIndex, ArchiveError>
        do throws(ArchiveError) {
            result = .success(try await archiveReader.open(url))
        } catch {
            result = .failure(error)
        }
        guard !Task.isCancelled, generation == navigationGeneration else { return }

        switch result {
        case let .success(index):
            archiveIndex = index
            showArchiveLevel(ArchiveLocation(archive: url, directory: ""), index: index)
        case let .failure(error):
            archiveIndex = nil
            allFiles = []
            if let location = listing.archive {
                listing.files = [Self.parentRow(for: location)]
            }
            listing.state = .failed(error.message)
        }
    }

    /// 開いている索引から、zip の中の1つの階層の一覧を作る（zip は読み直さない）
    private func showArchiveLevel(_ location: ArchiveLocation, index: ArchiveIndex) {
        listing = FolderListing(folder: listing.folder, files: [], state: .loading, archive: location)
        allFiles = sorted(index.items(in: location.directory), by: sortOrder)
        rebuildListing()
    }

    /// zip を閉じ、zip を含むフォルダの一覧をディスクから読み直す。`lastFolder` は書き換えない
    private func returnToFolder(selecting target: URL?) async {
        let folder = listing.folder
        resetForNavigation()
        archiveIndex = nil
        listing = FolderListing(folder: folder, files: [], state: .loading)

        let generation = navigationGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadFolder(folder, generation: generation)
        }
        listingTask = task
        await task.value

        guard generation == navigationGeneration, let target else { return }
        let standardized = target.standardizedFileURL
        if let row = listing.files.first(where: { $0.url.standardizedFileURL == standardized }) {
            select([row.url], focused: row.url)
        }
    }

    private func loadFolder(_ url: URL, generation: Int) async {
        do {
            let files = try await lister.mediaFiles(in: url)
            guard !Task.isCancelled, generation == navigationGeneration, listing.folder == url else { return }

            allFiles = sorted(files, by: sortOrder)
            rebuildListing()
        } catch {
            guard !Task.isCancelled, generation == navigationGeneration, listing.folder == url else { return }

            allFiles = []
            listing.files = []
            switch error {
            case .accessDenied:
                listing.state = .denied
            case .notFound:
                listing.state = .failed("フォルダが見つかりません")
            case let .other(message):
                listing.state = .failed(message)
            }
        }
    }

    // MARK: - プレビュー

    private func loadPreview(for url: URL?) {
        previewGeneration += 1
        let generation = previewGeneration
        previewTask?.cancel()
        previewTask = nil

        guard let url else {
            preview = .empty
            return
        }

        // 一覧の行の種類を先に見る。メディア以外（zip ファイル・ディレクトリ・`...`）はプレビューしない（FR-075）
        let kind: MediaKind
        if let file = listing.files.first(where: { $0.url == url }) {
            guard case let .media(mediaKind) = file.kind else {
                preview = .empty
                return
            }
            kind = mediaKind
        } else if let mediaKind = MediaKind(fileExtension: url.pathExtension) {
            kind = mediaKind
        } else {
            preview = .unavailable(name: url.lastPathComponent, reason: "対応していない形式です")
            return
        }

        if kind.isVideo {
            preview = .video(url)
            return
        }

        if let parsed = ArchiveURL.parse(url) {
            loadArchivePreview(for: url, path: parsed.path, generation: generation)
            return
        }

        if decoder.isAnimated(url) {
            preview = .animatedImage(url)
            return
        }

        preview = .loading(url)
        previewTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.decodedImage(for: url)
            guard !Task.isCancelled, self.previewGeneration == generation else { return }

            switch result {
            case let .success(image):
                self.preview = .image(image)
            case let .failure(error):
                self.preview = .unavailable(
                    name: url.lastPathComponent,
                    reason: Self.reason(for: error)
                )
            }
        }
    }

    private func loadArchivePreview(for url: URL, path: String, generation: Int) {
        if let entry = archiveIndex?.entry(at: path) {
            switch entry.readability {
            case .readable:
                break
            case .encrypted:
                preview = .unavailable(name: url.lastPathComponent, reason: ArchiveError.entryEncrypted.message)
                return
            case .unsupportedMethod:
                preview = .unavailable(
                    name: url.lastPathComponent,
                    reason: ArchiveError.unsupportedMethod(entry.method).message
                )
                return
            }
        }

        preview = .loading(url)
        let maxPixelSize = max(1, screenMaxPixel)
        previewTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.archiveImage(for: url, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled, self.previewGeneration == generation else { return }

            switch result {
            case let .image(image):
                self.preview = .image(image)
            case let .animated(data):
                self.preview = .animatedImageData(url, data)
            case let .failure(reason):
                self.preview = .unavailable(name: url.lastPathComponent, reason: reason)
            }
        }
    }

    /// zip の中の画像を、キャッシュ → `Data` の読み込み → デコードの順で得る。アニメーション画像は `Data` のまま返す
    private func archiveImage(for url: URL, maxPixelSize: Int) async -> ArchiveImageResult {
        if let cached = await cache.get(url) {
            return .image(cached)
        }

        let data: Data
        do throws(ArchiveError) {
            data = try await archiveReader.data(for: url, limit: MemoryLimits.archiveImageBytes)
        } catch {
            return .failure(error.message)
        }
        guard !Task.isCancelled else { return .failure("") }

        if decoder.isAnimated(data: data) {
            return .animated(data)
        }

        do {
            let image = try await decoder.decode(data: data, maxPixelSize: maxPixelSize)
            await cache.put(image, for: url)
            return .image(image)
        } catch {
            return .failure(Self.reason(for: error))
        }
    }

    private func decodedImage(for url: URL) async -> Result<DecodedImage, DecodeError> {
        if let cached = await cache.get(url) {
            return .success(cached)
        }

        do {
            let image = try await decoder.decode(url, maxPixelSize: max(1, screenMaxPixel))
            await cache.put(image, for: url)
            return .success(image)
        } catch {
            return .failure(error)
        }
    }

    private func schedulePrefetch(around url: URL?) {
        guard let url, let index = listing.files.firstIndex(where: { $0.url == url }) else {
            return
        }

        for neighborIndex in [index - 1, index + 1] where listing.files.indices.contains(neighborIndex) {
            let file = listing.files[neighborIndex]
            // 動画とメディア以外の行（zip ファイル・ディレクトリ・`...`）は先読みしない
            guard file.kind.isMedia, !file.kind.isVideo else { continue }
            guard prefetchTasks[file.url] == nil else { continue }

            if let parsed = ArchiveURL.parse(file.url) {
                if let entry = archiveIndex?.entry(at: parsed.path), entry.readability != .readable {
                    continue
                }
                let maxPixelSize = max(1, screenMaxPixel)
                let task = Task { [weak self] in
                    guard let self else { return }
                    _ = await self.archiveImage(for: file.url, maxPixelSize: maxPixelSize)
                    self.prefetchTasks[file.url] = nil
                }
                prefetchTasks[file.url] = task
                continue
            }

            guard !decoder.isAnimated(file.url) else { continue }
            let task = Task { [weak self] in
                guard let self else { return }
                _ = await self.decodedImage(for: file.url)
                self.prefetchTasks[file.url] = nil
            }
            prefetchTasks[file.url] = task
        }
    }

    private static func reason(for error: DecodeError) -> String {
        switch error {
        case .unreadable:
            return "ファイルを読み込めません"
        case .unsupported:
            return "対応していない形式です"
        case .corrupted:
            return "ファイルが壊れています"
        }
    }
}
