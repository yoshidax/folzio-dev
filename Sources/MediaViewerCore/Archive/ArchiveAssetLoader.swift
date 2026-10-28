import AVFoundation
import Foundation
import ObjectiveC
import UniformTypeIdentifiers

/// mvzip の URL を `AVURLAsset` に読ませるデリゲート（FR-072、research.md R25）。
/// 内容の情報と要求範囲を `ArchiveEntryStream` から 512KB ずつ返す。一時ファイルは作らない。
/// `stream(for:)` は asset（この読み込み器）ごとに 1 回だけ作って共有し、キャッシュとカーソルを asset 単位にする。
public final class ArchiveAssetLoader: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {
    private static let responseChunkSize = 512 * 1024

    /// Sendable でない `AVAssetResourceLoadingRequest` をタスクに渡すための入れ物
    private struct SendableBox<Value>: @unchecked Sendable {
        let value: Value
    }

    private let entryURL: URL
    private let reader: any ArchiveReading

    private let lock = NSLock()
    private var streamTask: Task<ArchiveEntryStream, any Error>?
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    init(entryURL: URL, reader: any ArchiveReading) {
        self.entryURL = entryURL
        self.reader = reader
    }

    /// 最初の要求で作り、以降は同じタスクを共有する（同時に来ても 1 回）
    private func sharedStream() -> Task<ArchiveEntryStream, any Error> {
        lock.lock()
        defer { lock.unlock() }
        if let streamTask { return streamTask }
        let url = entryURL
        let reader = reader
        let task = Task.detached { () async throws -> ArchiveEntryStream in
            try await reader.stream(for: url)
        }
        streamTask = task
        return task
    }

    // MARK: - AVAssetResourceLoaderDelegate

    public func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        let key = ObjectIdentifier(loadingRequest)
        let box = SendableBox(value: loadingRequest)
        let streamTask = sharedStream()
        let fileExtension = entryURL.pathExtension

        // 登録を済ませてからタスクを始める（終了時の削除が登録より先になるのを防ぐ）
        lock.lock()
        let task = Task.detached { [weak self] in
            let request = box.value
            do {
                let stream = try await streamTask.value
                try Self.fill(request, from: stream, fileExtension: fileExtension)
                if Task.isCancelled { return }
                request.finishLoading()
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                let message = String(describing: error)
                request.finishLoading(with: NSError(
                    domain: "MediaViewer.Archive", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: message]
                ))
            }
            self?.forget(key)
        }
        tasks[key] = task
        lock.unlock()
        return true
    }

    public func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        let key = ObjectIdentifier(loadingRequest)
        lock.lock()
        let task = tasks.removeValue(forKey: key)
        lock.unlock()
        task?.cancel()
    }

    private func forget(_ key: ObjectIdentifier) {
        lock.lock()
        tasks.removeValue(forKey: key)
        lock.unlock()
    }

    // MARK: - 応答

    private static func fill(
        _ request: AVAssetResourceLoadingRequest, from stream: ArchiveEntryStream, fileExtension: String
    ) throws {
        if let info = request.contentInformationRequest {
            info.contentType = UTType(filenameExtension: fileExtension)?.identifier
            info.contentLength = Int64(clamping: stream.length)
            info.isByteRangeAccessSupported = true
        }
        guard let dataRequest = request.dataRequest else { return }

        var offset = UInt64(max(0, dataRequest.currentOffset))
        let end: UInt64
        if dataRequest.requestsAllDataToEndOfResource {
            end = stream.length
        } else {
            end = min(stream.length, UInt64(max(0, dataRequest.requestedOffset)) + UInt64(max(0, dataRequest.requestedLength)))
        }
        while offset < end {
            try Task.checkCancellation()
            let count = Int(min(UInt64(responseChunkSize), end - offset))
            let data = try stream.read(offset: offset, maxLength: count)
            guard !data.isEmpty else { break }
            dataRequest.respond(with: data)
            offset += UInt64(data.count)
        }
    }
}

/// mvzip の URL から再生・代表フレーム用の `AVURLAsset` を作る。asset が生きている間、読み込み器を保持する（R25）
public enum ArchiveAssetFactory {
    /// `AVAssetResourceLoader` はデリゲートを弱参照するため、asset に関連付けて保持させる
    nonisolated(unsafe) private static var loaderKey: UInt8 = 0

    /// デリゲートのコールバックを受ける専用の直列キュー
    private static let loaderQueue = DispatchQueue(label: "MediaViewer.ArchiveAssetLoader")

    public static func makeAsset(for entryURL: URL, reader: any ArchiveReading) -> AVURLAsset {
        let asset = AVURLAsset(url: entryURL)
        let loader = ArchiveAssetLoader(entryURL: entryURL, reader: reader)
        asset.resourceLoader.setDelegate(loader, queue: loaderQueue)
        objc_setAssociatedObject(asset, &loaderKey, loader, .OBJC_ASSOCIATION_RETAIN)
        return asset
    }
}
