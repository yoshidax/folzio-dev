import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum DecodeError: Error, Sendable, Equatable {
    case unreadable
    case unsupported
    case corrupted
}

public protocol ImageDecoding: Sendable {
    func decode(_ url: URL, maxPixelSize: Int) async throws(DecodeError) -> DecodedImage
    func isAnimated(_ url: URL) -> Bool
}

public struct ImageDecoder: ImageDecoding {
    public init() {}

    public func decode(_ url: URL, maxPixelSize: Int) async throws(DecodeError) -> DecodedImage {
        do {
            return try await Task.detached(priority: .userInitiated) {
                try Self.decodeSynchronously(url, maxPixelSize: maxPixelSize)
            }.value
        } catch let error as DecodeError {
            throw error
        } catch {
            throw DecodeError.corrupted
        }
    }

    public func isAnimated(_ url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return false
        }
        return CGImageSourceGetCount(source) > 1
    }

    private static func decodeSynchronously(_ url: URL, maxPixelSize: Int) throws(DecodeError) -> DecodedImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw DecodeError.unreadable
        }
        guard let typeIdentifier = CGImageSourceGetType(source) as String? else {
            throw DecodeError.unreadable
        }
        guard supportedTypeIdentifiers.contains(typeIdentifier) else {
            throw DecodeError.unsupported
        }
        guard CGImageSourceGetCount(source) > 0 else {
            throw DecodeError.corrupted
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let pixelWidth = properties?[kCGImagePropertyPixelWidth] as? Int
        let pixelHeight = properties?[kCGImagePropertyPixelHeight] as? Int

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize),
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw DecodeError.corrupted
        }

        let pixelSize = CGSize(width: image.width, height: image.height)
        let originalPixelSize = CGSize(
            width: pixelWidth ?? image.width,
            height: pixelHeight ?? image.height
        )
        let byteCost = image.width * image.height * 4

        return DecodedImage(
            cgImage: image,
            pixelSize: pixelSize,
            originalPixelSize: originalPixelSize,
            byteCost: byteCost
        )
    }

    private static let supportedTypeIdentifiers: Set<String> = [
        UTType.jpeg.identifier,
        UTType.png.identifier,
        UTType.gif.identifier,
        "org.webmproject.webp",
    ]
}
