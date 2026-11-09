#!/usr/bin/env swift
// TAK-88 の事前確認用。製品には組み込まず、公開用ツリーにも書き出さない。
// macOS: swift scripts/dev/pasteboard-probe.swift
// 画像の自己検査だけを実行: swift -swift-version 6 scripts/dev/pasteboard-probe.swift --self-test

import AppKit
import ImageIO
import UniformTypeIdentifiers

enum ProbeError: Error {
    case imageCreation
    case imageEncoding
    case unexpectedFixture(String)
}

// 大きな画像の生成とファイルの読み書きは、呼び出す側でメインスレッドから外す。
func makeImageData(width: Int, height: Int, type: UTType) throws -> Data {
    let pixels = Data(repeating: 255, count: width * height * 4)
    guard let provider = CGDataProvider(data: pixels as CFData),
          let image = CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
          ) else { throw ProbeError.imageCreation }
    let buffer = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(buffer, type.identifier as CFString, 1, nil) else {
        throw ProbeError.imageEncoding
    }
    // 圧縮の効く白い画像でも、TIFF の大きさを測れるよう非圧縮にする。
    let properties: [CFString: Any] = type == .tiff
        ? [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFCompression: 1]] : [:]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw ProbeError.imageEncoding }
    return buffer as Data
}

enum Sample: CaseIterable, Sendable {
    case jpegNamedPNG
    case pngNamedSVG

    var name: String { self == .jpegNamedPNG ? "cat.png" : "logo.svg" }
    var contentType: UTType { self == .jpegNamedPNG ? .jpeg : .png }
    // 拡張子の検査を確かめるため、両方とも画像（PNG）の約束として渡す。
    var declaredType: UTType { .png }
    var label: String { self == .jpegNamedPNG ? "cat.png（中身は JPEG）" : "logo.svg（中身は PNG）" }

    func write(to url: URL) throws {
        try makeImageData(width: 32, height: 32, type: contentType).write(to: url, options: .atomic)
    }
}

// 不変の値だけを持ち、書き出しは AppKit が指定した専用キューで実行する。
final class SamplePromise: NSObject, NSFilePromiseProviderDelegate, @unchecked Sendable {
    let sample: Sample
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Folzio.PasteboardProbe.Writer"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    init(sample: Sample) { self.sample = sample }

    nonisolated func filePromiseProvider(_ provider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        sample.name
    }

    // Foundation がファイル調整のキューから問い合わせるため、UI の隔離を引き継がない。
    nonisolated func operationQueue(for provider: NSFilePromiseProvider) -> OperationQueue { queue }

    func filePromiseProvider(
        _ provider: NSFilePromiseProvider, writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            try sample.write(to: url)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }
}

@MainActor
final class SampleDragView: NSView, NSDraggingSource {
    private let promise: SamplePromise
    private var provider: NSFilePromiseProvider?

    init(sample: Sample) {
        promise = SamplePromise(sample: sample)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 6
        let label = NSTextField(labelWithString: "ここからドラッグ: \(sample.label)")
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) は使わない") }

    override func mouseDown(with event: NSEvent) {}

    override func hitTest(_ point: NSPoint) -> NSView? {
        // ラベルの上からも、このビューのドラッグを始められるようにする。
        guard let hit = super.hitTest(point) else { return nil }
        return hit === self || hit.isDescendant(of: self) ? self : nil
    }

    override func mouseDragged(with event: NSEvent) {
        let provider = NSFilePromiseProvider(fileType: promise.sample.declaredType.identifier, delegate: promise)
        self.provider = provider
        let item = NSDraggingItem(pasteboardWriter: provider)
        let location = convert(event.locationInWindow, from: nil)
        item.setDraggingFrame(
            NSRect(x: location.x - 16, y: location.y - 16, width: 32, height: 32),
            contents: NSImage(systemSymbolName: "photo", accessibilityDescription: promise.sample.label)
        )
        beginDraggingSession(with: [item], event: event, source: self)
    }

    nonisolated func draggingSession(
        _ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation { .copy }
}

@MainActor
final class DropView: NSView {
    weak var controller: ProbeController?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes(Array(Set(
            NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
            + [.fileURL, .png, .tiff, .URL, .string, .pdf,
               NSPasteboard.PasteboardType(UTType.jpeg.identifier),
               NSPasteboard.PasteboardType(UTType.heic.identifier)]
        )))
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        layer?.cornerRadius = 8
        let label = NSTextField(labelWithString: "ブラウザ・写真アプリの画像／動画をここへドロップ")
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 76),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) は使わない") }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        controller?.inspect(sender.draggingPasteboard, label: "drag-enter", readData: false)
        controller?.log("sourceOperationMask=\(sender.draggingSourceOperationMask.rawValue) \(maskNames(sender.draggingSourceOperationMask))")
        return sender.draggingSourceOperationMask.contains(.copy) ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingSourceOperationMask.contains(.copy) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard sender.draggingSourceOperationMask.contains(.copy), let controller else { return false }
        // データの取得と約束の要求は、どちらもドロップを返す前に行う。
        let start = ProcessInfo.processInfo.systemUptime
        controller.inspect(sender.draggingPasteboard, label: "drop", readData: true)
        let accepted = controller.receivePromises(from: sender.draggingPasteboard, startedAt: start)
        controller.log("drop-return accepted=\(accepted)（request-begin はこの行より前）")
        return accepted
    }

    private func maskNames(_ mask: NSDragOperation) -> String {
        let operations: [(NSDragOperation, String)] = [
            (.copy, "copy"), (.move, "move"), (.link, "link"), (.generic, "generic"),
            (.private, "private"), (.delete, "delete"),
        ]
        return operations.filter { mask.contains($0.0) }.map(\.1).joined(separator: ",")
    }
}

// AppKit は reader を指定した OperationQueue で呼ぶ。MainActor の隔離を引き継がない。
// UI に渡すのは値だけとし、ファイルの情報は reader が有効な間に読む。
func makePromiseReader(
    startedAt: TimeInterval,
    report: @escaping @MainActor @Sendable (TimeInterval, String, Bool) -> Void
) -> @Sendable (URL, Error?) -> Void {
    { @Sendable url, error in
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        let result: String
        if let error {
            // エラーのときの URL は API の契約に従って使わない。
            result = "error=\(String(describing: error))"
        } else {
            do {
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                result = "name=\(url.lastPathComponent.debugDescription) bytes=\(values.fileSize.map { String($0) } ?? "unknown") regular=\(values.isRegularFile == true)"
            } catch {
                result = "metadataError=\(String(describing: error))"
            }
        }
        let readOnMainThread = Thread.isMainThread
        Task { @MainActor in report(elapsed, result, readOnMainThread) }
    }
}

// 宛先は起動時と補充時にバックグラウンドで作る。ドロップでは作成を待たずに取り出す。
@MainActor
final class PreparedProbeFolders {
    private(set) var folders: [URL] = []
    private(set) var isPreparing = false
    private let targetCount: Int
    private let create: @Sendable () throws -> URL
    private let report: @MainActor (String) -> Void

    init(targetCount: Int = 2, create: @escaping @Sendable () throws -> URL = {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Folzio-Pasteboard-Probe-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        return folder
    }, report: @escaping @MainActor (String) -> Void) {
        self.targetCount = targetCount
        self.create = create
        self.report = report
    }

    func replenish() {
        guard !isPreparing, folders.count < targetCount else { return }
        isPreparing = true
        Task { [self] in
            do {
                let folder = try await Task.detached { [create] in try create() }.value
                folders.append(folder)
                isPreparing = false
                report("受け取りフォルダ準備完了（待機数=\(folders.count)）")
                replenish()
            } catch {
                isPreparing = false
                report("受け取りフォルダ準備失敗: \(error)")
            }
        }
    }

    func take() -> URL? {
        defer { replenish() }
        guard !folders.isEmpty else { return nil }
        return folders.removeFirst()
    }
}

@MainActor
final class ProbeController: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var preparedFolders: PreparedProbeFolders?
    private let output = NSTextView()
    private let caseName = NSTextField(string: "")
    private let selectedType = NSPopUpButton()
    private let receiverQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Folzio.PasteboardProbe.Reader"
        queue.maxConcurrentOperationCount = 2
        return queue
    }()
    // fileNames は呼び出し前には空のことがある。遅い通知でも受け取り側を参照できるよう保持する。
    private var receivers: [UUID: [NSFilePromiseReceiver]] = [:]
    private var callbackCounts: [UUID: [Int: Int]] = [:]
    private let imageTypes = [UTType.png, .jpeg, .heic, .tiff]

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false
        )
        window.title = "Folzio — ペーストボードの確認（TAK-88）"
        window.minSize = NSSize(width: 860, height: 680)
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        window.contentView = content
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])
        caseName.placeholderString = "確認するケース（例: Safari / JPEG / ドラッグ）"
        stack.addArrangedSubview(caseName)
        caseName.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let controls = NSStackView(views: [
            button("クリップボードを調べる", #selector(inspectClipboard)),
            button("クリップボードの約束を書き出す", #selector(receiveClipboard)),
            button("ログを消す", #selector(clearLog)),
        ])
        stack.addArrangedSubview(controls)
        selectedType.addItems(withTitles: ["自動（PNG → JPEG → HEIC → TIFF）"] + imageTypes.map(\.identifier))
        stack.addArrangedSubview(NSStackView(views: [NSTextField(labelWithString: "ドロップで読む型:"), selectedType]))
        let drop = DropView(frame: .zero)
        drop.controller = self
        stack.addArrangedSubview(drop)
        drop.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let fixtures = NSStackView(views: Sample.allCases.map { SampleDragView(sample: $0) })
        fixtures.distribution = .fillEqually
        stack.addArrangedSubview(fixtures)
        fixtures.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stack.addArrangedSubview(NSStackView(views: [
            button("200 MB TIFF をコピー", #selector(copyLargeTIFF(_:)), tag: 200),
            button("256 MB TIFF をコピー", #selector(copyLargeTIFF(_:)), tag: 256),
        ]))
        let note = NSTextField(wrappingLabelWithString:
            "クリップボードを調べると、各型のデータを UI スレッドで読み、容量と時間を測ります。画像の中身はログに出しません。\n"
            + "約束の書き出し先はログに表示します。一時フォルダは終了後も残るので、確認後に Finder で削除してください。"
        )
        stack.addArrangedSubview(note)
        note.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.borderType = .bezelBorder
        output.isEditable = false
        output.isSelectable = true
        output.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        output.autoresizingMask = [.width]
        output.isVerticallyResizable = true
        output.textContainer?.widthTracksTextView = true
        scroll.documentView = output
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        let menu = NSMenu()
        let application = NSMenuItem()
        menu.addItem(application)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        application.submenu = appMenu
        NSApp.mainMenu = menu
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        log("macOS=\(ProcessInfo.processInfo.operatingSystemVersionString)")
        log("ログはウインドウと標準出力の両方へ表示。容量はバイト、時間は秒。約束の reader の回数を受け取りごとに記録します。")
        preparedFolders = PreparedProbeFolders { [weak self] message in self?.log(message) }
        preparedFolders?.replenish()
        log("「受け取りフォルダ準備完了」の表示後にドロップしてください。")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func button(_ title: String, _ action: Selector, tag: Int = 0) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.tag = tag
        return button
    }

    func log(_ text: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(text)\n"
        output.textStorage?.append(NSAttributedString(string: line))
        output.scrollToEndOfDocument(nil)
        FileHandle.standardOutput.write(Data(line.utf8))
    }

    @objc private func clearLog() { output.string = "" }

    @objc private func inspectClipboard() { inspect(.general, label: "clipboard", readData: true, allTypes: true) }

    @objc private func receiveClipboard() {
        let start = ProcessInfo.processInfo.systemUptime
        inspect(.general, label: "clipboard-promises", readData: false)
        _ = receivePromises(from: .general, startedAt: start)
    }

    func inspect(_ pasteboard: NSPasteboard, label: String, readData: Bool, allTypes: Bool = false) {
        log("=== \(label) case=\(caseName.stringValue.debugDescription) pasteboard=\(pasteboard.name.rawValue) changeCount=\(pasteboard.changeCount) ===")
        log("types=\((pasteboard.types ?? []).map(\.rawValue))")
        for (index, item) in (pasteboard.pasteboardItems ?? []).enumerated() {
            log("item[\(index)] types=\(item.types.map(\.rawValue))")
            guard readData else { continue }
            let types: [NSPasteboard.PasteboardType]
            if allTypes {
                types = item.types
            } else if selectedType.indexOfSelectedItem == 0 {
                types = Array(imageTypes.map { NSPasteboard.PasteboardType($0.identifier) }.filter { item.types.contains($0) }.prefix(1))
            } else {
                let chosen = NSPasteboard.PasteboardType(imageTypes[selectedType.indexOfSelectedItem - 1].identifier)
                types = item.types.contains(chosen) ? [chosen] : []
            }
            if types.isEmpty { log("item[\(index)] 選んだ画像の型なし（データを読まない）") }
            for type in types {
                // 遅延提供を含め data(forType:) そのものの所要時間だけを測る。
                autoreleasepool {
                    let start = ProcessInfo.processInfo.systemUptime
                    let data = item.data(forType: type)
                    let elapsed = ProcessInfo.processInfo.systemUptime - start
                    log("item[\(index)] type=\(type.rawValue) bytes=\(data.map { String($0.count) } ?? "nil") readSeconds=\(String(format: "%.6f", elapsed)) mainThread=\(Thread.isMainThread)")
                }
            }
        }
    }

    func receivePromises(from pasteboard: NSPasteboard, startedAt: TimeInterval) -> Bool {
        let promises = (pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver]) ?? []
        let id = UUID()
        let tag = String(id.uuidString.prefix(8))
        log("receive[\(tag)] receivers=\(promises.count) case=\(caseName.stringValue.debugDescription)")
        guard !promises.isEmpty else { return true }
        guard let folder = preparedFolders?.take() else {
            log("receive[\(tag)] 受け取りフォルダ準備中。準備完了の表示後にもう一度ドロップしてください。")
            return false
        }
        receivers[id] = promises
        callbackCounts[id] = [:]
        log("receive[\(tag)] destination=\(folder.path.debugDescription)（事前作成済み・終了後も残す）")
        // 同じドラッグの約束には共通の宛先を渡す。要求を Task へ遅らせない。
        for (index, receiver) in promises.enumerated() {
            log("receive[\(tag)] receiver[\(index)] fileTypes=\(receiver.fileTypes) fileNames(before)=\(receiver.fileNames)")
            let reader = makePromiseReader(startedAt: startedAt) { [weak self] elapsed, result, readOnMainThread in
                guard let self else { return }
                self.callbackCounts[id, default: [:]][index, default: 0] += 1
                let count = self.callbackCounts[id]?[index] ?? 0
                self.log("receive[\(tag)] receiver[\(index)] readerCount=\(count) seconds=\(String(format: "%.6f", elapsed)) \(result) readerMainThread=\(readOnMainThread)")
                if let receiver = self.receivers[id]?[index] {
                    self.log("receive[\(tag)] receiver[\(index)] fileNames(after)=\(receiver.fileNames)")
                }
            }
            log("receive[\(tag)] receiver[\(index)] request-begin mainThread=\(Thread.isMainThread)")
            receiver.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: receiverQueue, reader: reader)
            log("receive[\(tag)] receiver[\(index)] fileNames(requested)=\(receiver.fileNames)")
        }
        return true
    }

    @objc private func copyLargeTIFF(_ sender: NSButton) {
        let megabytes = sender.tag
        sender.isEnabled = false
        log("\(megabytes) MB の非圧縮 TIFF をバックグラウンドで生成します。クリップボードを置き換えます。")
        Task {
            defer { sender.isEnabled = true }
            do {
                let data = try await Task.detached {
                    try makeImageData(width: megabytes == 200 ? 10_000 : 8_000, height: megabytes == 200 ? 5_000 : 8_000, type: .tiff)
                }.value
                NSPasteboard.general.clearContents()
                let start = ProcessInfo.processInfo.systemUptime
                let written = NSPasteboard.general.setData(data, forType: .tiff)
                let elapsed = ProcessInfo.processInfo.systemUptime - start
                log("generatedTIFF bytes=\(data.count) clipboardWrite=\(written) writeSeconds=\(String(format: "%.6f", elapsed))")
                log("「クリップボードを調べる」で読み出し時間を測ってください。この TIFF は即時提供であり、実アプリの遅延提供の時間は別に確かめます。")
            } catch {
                log("TIFF の生成失敗: \(error)")
            }
        }
    }
}

// GUI を開かずに、意図した中身と名前の組み合わせを書き出せることを macOS CI で確かめる。
func checkFixtures() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Folzio-Probe-SelfTest-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: folder) }
    for sample in Sample.allCases {
        let url = folder.appendingPathComponent(sample.name)
        try sample.write(to: url)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetType(source) as String? == sample.contentType.identifier,
              CGImageSourceGetCount(source) == 1 else {
            throw ProbeError.unexpectedFixture(sample.name)
        }
        let delegate = SamplePromise(sample: sample)
        let provider = NSFilePromiseProvider(fileType: sample.declaredType.identifier, delegate: delegate)
        guard delegate.filePromiseProvider(provider, fileNameForType: provider.fileType) == sample.name else {
            throw ProbeError.unexpectedFixture("promise name")
        }
        print("OK: \(sample.label), declared=\(provider.fileType)")
    }
    let tiff = try makeImageData(width: 100, height: 100, type: .tiff)
    guard let source = CGImageSourceCreateWithData(tiff as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let metadata = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
          (metadata[kCGImagePropertyTIFFCompression] as? NSNumber)?.intValue == 1 else {
        throw ProbeError.unexpectedFixture("uncompressed TIFF")
    }
    print("OK: 非圧縮 TIFF の生成。file promise の実際の受け渡しは macOS で手動確認してください。")
}

// GUI なしで、実際に使う reader をバックグラウンドから複数回呼ぶ。
@MainActor
func checkPromiseReader() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Folzio-Probe-ReaderTest-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("reader.png")
    try Data([1, 2, 3]).write(to: file)
    var results: [(TimeInterval, String, Bool)] = []
    let reader = makePromiseReader(startedAt: ProcessInfo.processInfo.systemUptime) { elapsed, result, onMain in
        MainActor.assertIsolated()
        results.append((elapsed, result, onMain))
    }
    let queue = OperationQueue()
    queue.addOperation { reader(file, nil) }
    queue.addOperation { reader(file, NSError(domain: "Folzio.Probe.Test", code: 1)) }
    queue.addOperation { reader(folder.appendingPathComponent("missing"), nil) }
    let deadline = Date().addingTimeInterval(5)
    while results.count < 3 && Date() < deadline {
        RunLoop.main.run(until: min(deadline, Date().addingTimeInterval(0.01)))
    }
    guard results.count == 3,
          results.allSatisfy({ $0.0 >= 0 && !$0.2 }),
          results.contains(where: { $0.1 == "name=\"reader.png\" bytes=3 regular=true" }),
          results.contains(where: { $0.1.hasPrefix("error=") }),
          results.contains(where: { $0.1.hasPrefix("metadataError=") }) else {
        throw ProbeError.unexpectedFixture("background reader: \(results)")
    }
    print("OK: バックグラウンド reader の成功・受け取りエラー・情報取得エラー。通知は MainActor。")
}

// Foundation と同じ Objective-C の入口をバックグラウンドから呼ぶ。
// Swift の直接呼び出しでは、delegate の actor 検査を通らないことがある。
@MainActor
func checkPromiseProvider() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Folzio-Probe-ProviderTest-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: folder) }
    var results: [String] = []
    let report: @MainActor @Sendable (String) -> Void = { results.append($0) }
    let worker = OperationQueue()
    for sample in Sample.allCases {
        worker.addOperation {
            let result: String
            do {
                precondition(!Thread.isMainThread)
                let delegate = SamplePromise(sample: sample)
                let provider = NSFilePromiseProvider(fileType: sample.declaredType.identifier, delegate: delegate)
                guard let queue = delegate.perform(
                    #selector(NSFilePromiseProviderDelegate.operationQueue(for:)), with: provider
                )?.takeUnretainedValue() as? OperationQueue,
                      queue.name == "Folzio.PasteboardProbe.Writer", queue !== OperationQueue.main else {
                    throw ProbeError.unexpectedFixture("provider queue")
                }
                guard let name = delegate.perform(
                    #selector(NSFilePromiseProviderDelegate.filePromiseProvider(_:fileNameForType:)),
                    with: provider, with: sample.declaredType.identifier
                )?.takeUnretainedValue() as? String, name == sample.name else {
                    throw ProbeError.unexpectedFixture("provider name")
                }
                let url = folder.appendingPathComponent(name)
                // 書き出しの専用キューも実際に使い、完了と中身を検査する。
                queue.addOperation {
                    let writingProvider = NSFilePromiseProvider(fileType: sample.declaredType.identifier, delegate: delegate)
                    delegate.filePromiseProvider(writingProvider, writePromiseTo: url) { error in
                        let message: String
                        if let error {
                            message = "error: \(error)"
                        } else if Thread.isMainThread {
                            message = "error: provider write on main thread"
                        } else if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                                  CGImageSourceGetType(source) as String? == sample.contentType.identifier {
                            message = "OK: \(sample.name)"
                        } else {
                            message = "error: provider content"
                        }
                        Task { @MainActor in report(message) }
                    }
                }
                queue.waitUntilAllOperationsAreFinished()
                result = "queue: \(sample.name)"
            } catch {
                result = "error: \(error)"
            }
            Task { @MainActor in report(result) }
        }
    }
    let deadline = Date().addingTimeInterval(5)
    while results.count < Sample.allCases.count * 2 && Date() < deadline {
        RunLoop.main.run(until: min(deadline, Date().addingTimeInterval(0.01)))
    }
    guard results.sorted() == ["OK: cat.png", "OK: logo.svg", "queue: cat.png", "queue: logo.svg"].sorted() else {
        throw ProbeError.unexpectedFixture("background provider: \(results)")
    }
    print("OK: provider のキュー・名前の Objective-C 呼び出しと専用キューの書き出し（2画像）。")
}

// 事前作成・空のときの拒否・消費後の補充を、実際のバックグラウンド作成で確かめる。
@MainActor
func checkPreparedFolders() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("Folzio-Probe-FolderTest-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let pool = PreparedProbeFolders(create: {
        guard !Thread.isMainThread else { throw ProbeError.unexpectedFixture("folder creation on main thread") }
        let folder = root.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }, report: { _ in })
    guard pool.take() == nil else { throw ProbeError.unexpectedFixture("unprepared folder accepted") }
    func waitUntilReady() throws {
        let deadline = Date().addingTimeInterval(5)
        while (pool.folders.count != 2 || pool.isPreparing) && Date() < deadline {
            RunLoop.main.run(until: min(deadline, Date().addingTimeInterval(0.01)))
        }
        guard pool.folders.count == 2, !pool.isPreparing else {
            throw ProbeError.unexpectedFixture("folder preparation timed out")
        }
    }
    try waitUntilReady()
    guard let first = pool.take() else { throw ProbeError.unexpectedFixture("prepared folder missing") }
    try waitUntilReady()
    let all = [first] + pool.folders
    guard Set(all).count == 3,
          all.allSatisfy({ (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }) else {
        throw ProbeError.unexpectedFixture("folder reuse or missing directory")
    }
    print("OK: 受け取りフォルダの事前作成・未準備の拒否・補充（作成はバックグラウンド）。")
}

MainActor.assumeIsolated {
    if CommandLine.arguments.contains("--self-test") {
        do {
            try checkFixtures()
            try checkPromiseReader()
            try checkPromiseProvider()
            try checkPreparedFolders()
        } catch {
            print("自己検査失敗: \(error)")
            exit(1)
        }
    } else {
        let app = NSApplication.shared
        let controller = ProbeController()
        app.setActivationPolicy(.regular)
        app.delegate = controller
        app.run()
        withExtendedLifetime(controller) {}
    }
}
