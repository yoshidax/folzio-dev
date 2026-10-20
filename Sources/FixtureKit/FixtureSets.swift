import Foundation

public enum FixtureSets {
    public static func makeAll(in directory: URL) throws {
        try mixed(in: directory)
        try broken(in: directory)
        try huge(in: directory)
        try bigImage(in: directory)
        try ops(in: directory)
        try zip(in: directory)
    }

    public static func mixed(in directory: URL) throws {
        let folder = try prepare(directory.appendingPathComponent("mixed", isDirectory: true))

        try ImageFixtures.jpeg(at: folder.appendingPathComponent("01-photo.jpg"), width: 800, height: 600)
        try ImageFixtures.png(at: folder.appendingPathComponent("02-image.png"), width: 400, height: 300)
        try ImageFixtures.animatedGIF(at: folder.appendingPathComponent("03-animation.gif"), frames: 6)
        try WebPFixtures.staticImage(at: folder.appendingPathComponent("04-static.webp"))
        try WebPFixtures.animatedImage(at: folder.appendingPathComponent("05-animation.webp"))
        try VideoFixtures.mp4(at: folder.appendingPathComponent("06-video.mp4"))
        try VideoFixtures.mov(at: folder.appendingPathComponent("07-movie.mov"))

        try writeText("This file is not a supported media file.\n", to: folder.appendingPathComponent("notes.txt"))
        try writeMinimalPDF(to: folder.appendingPathComponent("document.pdf"))
        try ImageFixtures.jpeg(at: folder.appendingPathComponent(".hidden.jpg"), width: 32, height: 32)

        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("sub", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    public static func broken(in directory: URL) throws {
        let folder = try prepare(directory.appendingPathComponent("broken", isDirectory: true))

        let sourceURL = folder.appendingPathComponent("source.jpg")
        try ImageFixtures.jpeg(at: sourceURL, width: 320, height: 240)
        let sourceData = try Data(contentsOf: sourceURL)
        try Data(sourceData.prefix(100)).write(to: folder.appendingPathComponent("truncated.jpg"))
        try FileManager.default.removeItem(at: sourceURL)

        try ImageFixtures.png(at: folder.appendingPathComponent("fake.jpg"), width: 64, height: 64)
        FileManager.default.createFile(atPath: folder.appendingPathComponent("empty.mp4").path, contents: Data())
    }

    public static func huge(in directory: URL, count: Int = 10_000) throws {
        let folder = try prepare(directory.appendingPathComponent("huge", isDirectory: true))

        let templateURL = folder.appendingPathComponent("template.jpg")
        try ImageFixtures.jpeg(at: templateURL, width: 8, height: 8)
        let templateData = try Data(contentsOf: templateURL)
        try FileManager.default.removeItem(at: templateURL)

        for index in 1...max(0, count) {
            let name = String(format: "img_%05d.jpg", index)
            try templateData.write(to: folder.appendingPathComponent(name))
        }
    }

    public static func bigImage(in directory: URL) throws {
        let folder = try prepare(directory.appendingPathComponent("bigimage", isDirectory: true))
        try ImageFixtures.grayscalePNG(
            at: folder.appendingPathComponent("big.png"),
            width: 10_000,
            height: 10_000
        )
    }

    public static func ops(in directory: URL) throws {
        let folder = try prepare(directory.appendingPathComponent("ops", isDirectory: true))

        try ImageFixtures.jpeg(at: folder.appendingPathComponent("a.jpg"), width: 64, height: 64)
        try ImageFixtures.png(at: folder.appendingPathComponent("b.png"), width: 64, height: 64)
        try ImageFixtures.jpeg(at: folder.appendingPathComponent("c 2.jpg"), width: 64, height: 64)
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("dest", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    // MARK: - zip

    /// `zip/`（quickstart.md「検証用フォルダの準備」の表）を作る。
    public static func zip(in directory: URL) throws {
        let folder = try prepare(directory.appendingPathComponent("zip", isDirectory: true))
        let scratch = try makeScratchDirectory()
        defer { try? FileManager.default.removeItem(at: scratch) }

        let jpeg = try imageData(scratch, "a.jpg") { try ImageFixtures.jpeg(at: $0, width: 800, height: 600) }
        let smallJPEG = try imageData(scratch, "s.jpg") { try ImageFixtures.jpeg(at: $0, width: 8, height: 8) }
        let png = try imageData(scratch, "b.png") { try ImageFixtures.png(at: $0, width: 400, height: 300) }
        let gif = try imageData(scratch, "c.gif") { try ImageFixtures.animatedGIF(at: $0, frames: 6) }
        let webp = try imageData(scratch, "d.webp") { try WebPFixtures.staticImage(at: $0) }
        let animatedWebP = try imageData(scratch, "e.webp") { try WebPFixtures.animatedImage(at: $0) }
        let text = Data("This file is not a supported media file.\n".utf8)

        try Data(jpeg).write(to: folder.appendingPathComponent("cover.jpg"))

        // photos.zip: deflate。ディレクトリの項目は書かない。
        let inner = try ZipFixtureWriter.archiveData([
            ZipFixtureEntry(name: "inner.jpg", content: .bytes(smallJPEG), method: .deflated),
        ])
        try ZipFixtureWriter.write([
            ZipFixtureEntry(name: "01.jpg", content: .bytes(jpeg), method: .deflated),
            ZipFixtureEntry(name: "02.png", content: .bytes(png), method: .deflated),
            ZipFixtureEntry(name: "03-animation.gif", content: .bytes(gif), method: .deflated),
            ZipFixtureEntry(name: "04-static.webp", content: .bytes(webp), method: .deflated),
            ZipFixtureEntry(name: "05-animation.webp", content: .bytes(animatedWebP), method: .deflated),
            ZipFixtureEntry(name: "notes.txt", content: .bytes(text), method: .deflated),
            ZipFixtureEntry(name: ".hidden.jpg", content: .bytes(smallJPEG), method: .deflated),
            ZipFixtureEntry(name: "__MACOSX/._01.jpg", content: .bytes(Data(count: 82)), method: .deflated),
            ZipFixtureEntry(name: "inner.zip", content: .bytes(inner), method: .stored),
            ZipFixtureEntry(name: "sub/10.jpg", content: .bytes(jpeg), method: .deflated),
            ZipFixtureEntry(name: "sub/11.png", content: .bytes(png), method: .deflated),
            ZipFixtureEntry(name: "sub/deep/20.jpg", content: .bytes(jpeg), method: .deflated),
            ZipFixtureEntry(name: "sub/deep/21.png", content: .bytes(png), method: .deflated),
        ], to: folder.appendingPathComponent("photos.zip"))

        // videos-*.zip
        let mp4 = try imageData(scratch, "v.mp4") { try VideoFixtures.mp4(at: $0) }
        let mov = try imageData(scratch, "v.mov") { try VideoFixtures.mov(at: $0) }
        let fastMP4 = try imageData(scratch, "fast.mp4") { try VideoFixtures.mp4(at: $0, fastStart: true) }
        let mp4HD = try imageData(scratch, "hd.mp4") {
            try VideoFixtures.mp4(at: $0, width: 1920, height: 1080, seconds: 10, fastStart: true)
        }
        try ZipFixtureWriter.write([
            ZipFixtureEntry(name: "video-360p.mp4", content: .bytes(mp4), method: .stored),
            ZipFixtureEntry(name: "movie-360p.mov", content: .bytes(mov), method: .stored),
            ZipFixtureEntry(name: "video-1080p.mp4", content: .bytes(mp4HD), method: .stored),
        ], to: folder.appendingPathComponent("videos-stored.zip"))
        try ZipFixtureWriter.write([
            ZipFixtureEntry(name: "video-faststart.mp4", content: .bytes(fastMP4), method: .deflated),
            ZipFixtureEntry(name: "movie-tail.mov", content: .bytes(mov), method: .deflated),
        ], to: folder.appendingPathComponent("videos-deflated.zip"))

        // 名前の文字コード
        try ZipFixtureWriter.write([
            ZipFixtureEntry(
                name: "写真①.jpg", rawName: try cp932("写真①.jpg"),
                content: .bytes(jpeg), method: .deflated, utf8Flag: false
            ),
            ZipFixtureEntry(
                name: "フォルダ/画像.png", rawName: try cp932("フォルダ/画像.png"),
                content: .bytes(png), method: .deflated, utf8Flag: false
            ),
        ], to: folder.appendingPathComponent("names-sjis.zip"))
        try ZipFixtureWriter.write([
            ZipFixtureEntry(name: "写真①.jpg", content: .bytes(jpeg), method: .deflated),
            ZipFixtureEntry(name: "フォルダ/画像.png", content: .bytes(png), method: .deflated),
        ], to: folder.appendingPathComponent("names-utf8.zip"))

        // 非対応の項目
        try ZipFixtureWriter.write([
            ZipFixtureEntry(name: "encrypted.jpg", content: .bytes(jpeg), method: .stored, encryptedFlag: true),
            ZipFixtureEntry(name: "bzip2.png", content: .bytes(png), method: .raw(12)),
            ZipFixtureEntry(name: "plain.jpg", content: .bytes(jpeg), method: .deflated),
        ], to: folder.appendingPathComponent("locked.zip"))

        try ZipFixtureWriter.write([
            ZipFixtureEntry(name: "notes.txt", content: .bytes(text), method: .deflated),
        ], to: folder.appendingPathComponent("no-media.zip"))
        try ZipFixtureWriter.write([], to: folder.appendingPathComponent("empty.zip"))

        // 途中で切れた zip と、zip ではないファイル
        let whole = try ZipFixtureWriter.archiveData([
            ZipFixtureEntry(name: "01.jpg", content: .bytes(jpeg), method: .stored),
            ZipFixtureEntry(name: "02.png", content: .bytes(png), method: .stored),
        ])
        try whole.prefix(whole.count * 2 / 3).write(to: folder.appendingPathComponent("broken.zip"))
        try writeText("This is not a zip archive.\n", to: folder.appendingPathComponent("not-a-zip.zip"))

        // huge.zip: 10,000 個の小さな JPEG（SC-015）
        let hugeEntries = (1...10_000).map { index in
            ZipFixtureEntry(
                name: String(format: "img_%05d.jpg", index),
                content: .bytes(smallJPEG), method: .stored
            )
        }
        try ZipFixtureWriter.write(hugeEntries, to: folder.appendingPathComponent("huge.zip"))
    }

    /// `zip-big/`（SC-014 のメモリ確認用）を作る。時間とディスクを使うため `makeAll` には含めない。
    public static func bigVideoZips(in directory: URL) throws {
        let folder = try prepare(directory.appendingPathComponent("zip-big", isDirectory: true))
        // fastStart の書き出しが途中のファイル（.sb-…）を残すことがあるため、作業用フォルダごと消す。
        let scratch = try makeScratchDirectory()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let videoURL = scratch.appendingPathComponent("big-video.mp4")

        // 毎フレーム変わるノイズで、約 60Mbps × 150 秒 = 約 1.1GB にする。
        try VideoFixtures.mp4(
            at: videoURL, width: 1920, height: 1080, seconds: 150,
            fastStart: true, averageBitRate: 60_000_000, noisyFrames: true
        )
        let video = try Data(contentsOf: videoURL, options: .alwaysMapped)
        try ZipFixtureWriter.write([
            ZipFixtureEntry(name: "big-video.mp4", content: .bytes(video), method: .stored),
        ], to: folder.appendingPathComponent("big-video-stored.zip"))
        try ZipFixtureWriter.write([
            ZipFixtureEntry(name: "big-video.mp4", content: .bytes(video), method: .deflated),
        ], to: folder.appendingPathComponent("big-video-deflated.zip"))
    }

    private static func makeScratchDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FixtureKit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func imageData(_ scratch: URL, _ name: String, _ make: (URL) throws -> Void) throws -> Data {
        let url = scratch.appendingPathComponent(name)
        try make(url)
        defer { try? FileManager.default.removeItem(at: url) }
        return try Data(contentsOf: url)
    }

    /// CP932（Windows 版 Shift_JIS。丸数字などの機種依存文字を含む）。
    private static func cp932(_ string: String) throws -> Data {
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.dosJapanese.rawValue)
        ))
        guard let data = string.data(using: encoding) else {
            throw FixtureError.writeFailed(URL(fileURLWithPath: string))
        }
        return data
    }

    private static func prepare(_ folder: URL) throws -> URL {
        if FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.removeItem(at: folder)
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static func writeText(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url)
    }

    private static func writeMinimalPDF(to url: URL) throws {
        let pdf = """
        %PDF-1.4
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        2 0 obj
        << /Type /Pages /Kids [3 0 R] /Count 1 >>
        endobj
        3 0 obj
        << /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>
        endobj
        trailer
        << /Root 1 0 R >>
        %%EOF

        """
        try writeText(pdf, to: url)
    }
}
