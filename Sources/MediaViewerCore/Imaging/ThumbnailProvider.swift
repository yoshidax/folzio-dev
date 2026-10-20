import CoreGraphics
import Foundation
import QuickLookThumbnailing

public protocol ThumbnailProviding: Sendable {
    func thumbnail(for url: URL, pointSize: Double, scale: Double) async -> CGImage?
    func cancel(for url: URL, pointSize: Double, scale: Double)
}

public final class ThumbnailProvider: ThumbnailProviding, @unchecked Sendable {
    private static let sizeSteps = [64, 128, 256, 512]

    public static func pixelSize(forPointSize pointSize: Double, scale: Double) -> Int {
        let target = pointSize * scale
        guard target.isFinite else { return sizeSteps[0] }
        for step in sizeSteps where target <= Double(step) {
            return step
        }
        return sizeSteps[sizeSteps.count - 1]
    }

    private final class CachedEntry {
        let image: CGImage

        init(image: CGImage) {
            self.image = image
        }
    }

    private struct InFlightRequest {
        let url: URL
        let pixelSize: Int
        let request: QLThumbnailGenerator.Request
    }

    private let generator: QLThumbnailGenerator
    private let cache = NSCache<NSString, CachedEntry>()
    private let lock = NSLock()
    private var inFlight: [UUID: InFlightRequest] = [:]

    public init() {
        generator = QLThumbnailGenerator.shared
        cache.totalCostLimit = MemoryLimits.thumbnailCacheBytes
    }

    public func thumbnail(for url: URL, pointSize: Double, scale: Double) async -> CGImage? {
        let pixelSize = Self.pixelSize(forPointSize: pointSize, scale: scale)
        let key = Self.cacheKey(for: url, pixelSize: pixelSize)

        if let cached = cache.object(forKey: key) {
            return cached.image
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: pixelSize, height: pixelSize),
            scale: 1,
            representationTypes: .thumbnail
        )
        let identifier = UUID()
        lock.withLock {
            inFlight[identifier] = InFlightRequest(
                url: url,
                pixelSize: pixelSize,
                request: request
            )
        }
        defer {
            lock.withLock {
                inFlight[identifier] = nil
            }
        }

        do {
            let representation = try await generator.generateBestRepresentation(for: request)
            let image = representation.cgImage
            let cost = image.width * image.height * 4
            cache.setObject(CachedEntry(image: image), forKey: key, cost: cost)
            return image
        } catch {
            return nil
        }
    }

    public func cancel(for url: URL, pointSize: Double, scale: Double) {
        let pixelSize = Self.pixelSize(forPointSize: pointSize, scale: scale)
        let requests: [QLThumbnailGenerator.Request] = lock.withLock {
            let matches = inFlight.filter {
                $0.value.url == url && $0.value.pixelSize == pixelSize
            }
            for identifier in matches.keys {
                inFlight[identifier] = nil
            }
            return matches.values.map(\.request)
        }

        for request in requests {
            generator.cancel(request)
        }
    }

    private static func cacheKey(for url: URL, pixelSize: Int) -> NSString {
        "\(url.absoluteString)#\(pixelSize)" as NSString
    }
}
