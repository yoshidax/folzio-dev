import AVFoundation
import CoreVideo
import Foundation

public enum VideoFixtures {
    public static func mp4(at url: URL, width: Int = 640, height: Int = 360, seconds: Double = 1.5) throws {
        try write(at: url, fileType: .mp4, width: width, height: height, seconds: seconds)
    }

    public static func mov(at url: URL, width: Int = 640, height: Int = 360, seconds: Double = 1.5) throws {
        try write(at: url, fileType: .mov, width: width, height: height, seconds: seconds)
    }

    private static func write(at url: URL, fileType: AVFileType, width: Int, height: Int, seconds: Double) throws {
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )

        guard writer.canAdd(input) else {
            throw FixtureError.videoWriterFailed("cannot add video input")
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw FixtureError.videoWriterFailed(writer.error?.localizedDescription ?? "startWriting")
        }
        writer.startSession(atSourceTime: .zero)

        let framesPerSecond: Int32 = 30
        let frameCount = max(1, Int(seconds * Double(framesPerSecond)))

        for index in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.005)
            }

            var pixelBuffer: CVPixelBuffer?
            if let pool = adaptor.pixelBufferPool {
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            }
            guard let buffer = pixelBuffer else {
                throw FixtureError.cannotCreatePixelBuffer
            }

            fill(buffer, frame: index, frameCount: frameCount)

            let time = CMTime(value: CMTimeValue(index), timescale: framesPerSecond)
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw FixtureError.videoWriterFailed(writer.error?.localizedDescription ?? "append")
            }
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        guard writer.status == .completed else {
            throw FixtureError.videoWriterFailed(writer.error?.localizedDescription ?? "finishWriting")
        }
    }

    private static func fill(_ buffer: CVPixelBuffer, frame: Int, frameCount: Int) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let width = CVPixelBufferGetWidth(buffer)

        let barX = (frame * width / max(1, frameCount)) % max(1, width)
        let barWidth = max(8, width / 8)

        for y in 0..<height {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let offset = x * 4
                let distance = abs(x - barX)
                let inBar = distance < barWidth / 2
                row[offset] = inBar ? 230 : 60
                row[offset + 1] = inBar ? 120 : 40
                row[offset + 2] = inBar ? 40 : 30
                row[offset + 3] = 255
            }
        }
    }
}
