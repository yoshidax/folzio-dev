import Foundation
import Observation

@MainActor
@Observable
public final class BrowserModel {
    public private(set) var listing: FolderListing
    public private(set) var selection: SelectionState
    public private(set) var preview: PreviewContent
    public var screenMaxPixel: Int
    public var sortOrder: SortOrder {
        didSet {
            guard sortOrder != oldValue else { return }
            var settingsValue = settings.viewSettings
            settingsValue.sortOrder = sortOrder
            settings.viewSettings = settingsValue

            if listing.state == .loaded || listing.state == .empty {
                listing.files = sorted(listing.files, by: sortOrder)
                listing.state = listing.files.isEmpty ? .empty : .loaded
            }
        }
    }

    private let lister: any DirectoryListing
    private let decoder: any ImageDecoding
    private let cache: DecodedImageCache
    private let settings: SettingsStore

    private var listingTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var previewGeneration = 0
    private var prefetchTasks: [URL: Task<Void, Never>] = [:]

    public init(
        lister: any DirectoryListing,
        decoder: any ImageDecoding,
        cache: DecodedImageCache,
        settings: SettingsStore
    ) {
        self.lister = lister
        self.decoder = decoder
        self.cache = cache
        self.settings = settings
        self.sortOrder = settings.viewSettings.sortOrder
        self.screenMaxPixel = 4096

        let folder = settings.viewSettings.lastFolder
            ?? FileManager.default.homeDirectoryForCurrentUser
        self.listing = FolderListing(folder: folder, files: [], state: .empty)
        self.selection = SelectionState()
        self.preview = .empty
    }

    public func selectFolder(_ url: URL) async {
        listingTask?.cancel()
        previewGeneration += 1
        previewTask?.cancel()
        previewTask = nil
        for task in prefetchTasks.values {
            task.cancel()
        }
        prefetchTasks.removeAll()

        selection = SelectionState()
        preview = .empty
        listing = FolderListing(folder: url, files: [], state: .loading)

        var viewSettings = settings.viewSettings
        if viewSettings.lastFolder?.standardizedFileURL != url.standardizedFileURL {
            viewSettings.lastFolder = url
            settings.viewSettings = viewSettings
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadFolder(url)
        }
        listingTask = task
        await task.value
    }

    public func select(_ urls: Set<URL>, focused: URL?) {
        selection = SelectionState(selected: urls, focused: focused)
        loadPreview(for: focused)
        schedulePrefetch(around: focused)
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

    private func loadFolder(_ url: URL) async {
        do {
            let files = try await lister.mediaFiles(in: url)
            guard !Task.isCancelled, listing.folder == url else { return }

            let ordered = sorted(files, by: sortOrder)
            listing.files = ordered
            listing.state = ordered.isEmpty ? .empty : .loaded
        } catch {
            guard !Task.isCancelled, listing.folder == url else { return }

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

    private func loadPreview(for url: URL?) {
        previewGeneration += 1
        let generation = previewGeneration
        previewTask?.cancel()
        previewTask = nil

        guard let url else {
            preview = .empty
            return
        }

        guard let kind = MediaKind(fileExtension: url.pathExtension) else {
            preview = .unavailable(name: url.lastPathComponent, reason: "対応していない形式です")
            return
        }

        if kind.isVideo {
            preview = .video(url)
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
            guard !file.kind.isVideo, !decoder.isAnimated(file.url) else { continue }
            guard prefetchTasks[file.url] == nil else { continue }

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
