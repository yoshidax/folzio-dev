import Foundation

public enum FixtureSets {
    public static func makeAll(in directory: URL) throws {
        try mixed(in: directory)
        try broken(in: directory)
        try huge(in: directory)
        try bigImage(in: directory)
        try ops(in: directory)
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
