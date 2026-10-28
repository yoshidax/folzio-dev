import Foundation

/// zip の構造（終端レコード・中央ディレクトリ・ローカルヘッダ）の解析（research.md R22）。
/// `Data` を受けて値を返す純粋関数の集まりで、ファイルは読まない。
/// すべての読み出しで範囲を確かめ、範囲外は `.notAZip` か `.corrupted` にする。
enum ZipStructure {
    static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50
    static let zip64LocatorSignature: UInt32 = 0x0706_4B50
    static let zip64EndOfCentralDirectorySignature: UInt32 = 0x0606_4B50
    static let centralHeaderSignature: UInt32 = 0x0201_4B50
    static let localHeaderSignature: UInt32 = 0x0403_4B50

    static let endOfCentralDirectorySize = 22
    static let zip64LocatorSize = 20
    static let zip64EndOfCentralDirectorySize = 56
    static let centralHeaderSize = 46
    static let localHeaderSize = 30
    /// コメントの最大長（65,535）を含めた終端レコード探索の範囲
    static let maxEndSearchBytes = 65_535 + endOfCentralDirectorySize

    /// 中央ディレクトリの場所
    struct CentralDirectoryLocation: Equatable, Sendable {
        var entryCount: UInt64
        var size: UInt64
        var offset: UInt64
    }

    struct EndOfCentralDirectory: Equatable, Sendable {
        var location: CentralDirectoryLocation
        /// 終端レコードのファイル先頭からの位置（ZIP64 のロケータはこの 20 バイト前）
        var recordOffset: UInt64
        /// 項目数・サイズ・位置のどれかが ZIP64 の目印の値で、ZIP64 の終端レコードを読む必要がある
        var needsZip64: Bool
    }

    struct CentralEntry: Equatable, Sendable {
        var nameBytes: Data
        var flags: UInt16
        var method: UInt16
        var dosTime: UInt16
        var dosDate: UInt16
        var crc32: UInt32
        var compressedSize: UInt64
        var uncompressedSize: UInt64
        var localHeaderOffset: UInt64
        var extraField: Data
    }

    // MARK: - 終端レコード

    /// 末尾 `min(fileSize, 65_557)` バイトから、署名を後ろから探す。ディスク番号が 0 以外なら `.multiDisk`
    static func endOfCentralDirectory(
        inTail tail: Data,
        fileSize: UInt64
    ) throws(ArchiveError) -> EndOfCentralDirectory {
        let bytes = [UInt8](tail.suffix(maxEndSearchBytes))
        let size = endOfCentralDirectorySize
        guard bytes.count >= size, UInt64(bytes.count) <= fileSize else { throw .notAZip }

        var position = bytes.count - size
        var found: Int?
        while position >= 0 {
            if try readUInt32(bytes, position) == endOfCentralDirectorySignature {
                let commentLength = Int(try readUInt16(bytes, position + 20))
                if position + size + commentLength <= bytes.count {
                    found = position
                    break
                }
            }
            position -= 1
        }
        guard let start = found else { throw .notAZip }

        let disk = try readUInt16(bytes, start + 4)
        let centralDisk = try readUInt16(bytes, start + 6)
        guard disk == 0, centralDisk == 0 else { throw .multiDisk }

        let entryCount = try readUInt16(bytes, start + 10)
        let directorySize = try readUInt32(bytes, start + 12)
        let directoryOffset = try readUInt32(bytes, start + 16)
        let recordOffset = fileSize - UInt64(bytes.count - start)

        let needsZip64 = entryCount == 0xFFFF || directorySize == 0xFFFF_FFFF || directoryOffset == 0xFFFF_FFFF
        let location = CentralDirectoryLocation(
            entryCount: UInt64(entryCount),
            size: UInt64(directorySize),
            offset: UInt64(directoryOffset)
        )
        if !needsZip64 {
            try validate(location, within: recordOffset)
        }
        return EndOfCentralDirectory(location: location, recordOffset: recordOffset, needsZip64: needsZip64)
    }

    /// ZIP64 終端レコードのロケータ（20 バイト）から、ZIP64 終端レコードの位置を返す
    static func zip64Locator(_ data: Data) throws(ArchiveError) -> UInt64 {
        let bytes = [UInt8](data.prefix(zip64LocatorSize))
        guard bytes.count >= zip64LocatorSize,
              try readUInt32(bytes, 0) == zip64LocatorSignature else { throw .notAZip }
        guard try readUInt32(bytes, 4) == 0, try readUInt32(bytes, 16) <= 1 else { throw .multiDisk }
        return try readUInt64(bytes, 8)
    }

    /// ZIP64 終端レコード（固定部 56 バイト）から中央ディレクトリの場所を返す
    static func zip64EndOfCentralDirectory(
        _ data: Data,
        fileSize: UInt64
    ) throws(ArchiveError) -> CentralDirectoryLocation {
        let bytes = [UInt8](data.prefix(zip64EndOfCentralDirectorySize))
        guard bytes.count >= zip64EndOfCentralDirectorySize,
              try readUInt32(bytes, 0) == zip64EndOfCentralDirectorySignature else { throw .notAZip }
        guard try readUInt32(bytes, 16) == 0, try readUInt32(bytes, 20) == 0 else { throw .multiDisk }

        let location = CentralDirectoryLocation(
            entryCount: try readUInt64(bytes, 32),
            size: try readUInt64(bytes, 40),
            offset: try readUInt64(bytes, 48)
        )
        try validate(location, within: fileSize)
        return location
    }

    private static func validate(
        _ location: CentralDirectoryLocation,
        within limit: UInt64
    ) throws(ArchiveError) {
        let (end, overflow) = location.offset.addingReportingOverflow(location.size)
        guard !overflow, end <= limit else { throw .notAZip }
    }

    // MARK: - 中央ディレクトリ

    /// 中央ディレクトリ全体を解析する。ZIP64 拡張（0x0001）は、値が 0xFFFFFFFF の項目だけを順に読む
    static func centralDirectoryEntries(
        _ data: Data,
        count: UInt64
    ) throws(ArchiveError) -> [CentralEntry] {
        let bytes = [UInt8](data)
        guard count <= UInt64(bytes.count / centralHeaderSize) else { throw .notAZip }

        var entries: [CentralEntry] = []
        entries.reserveCapacity(Int(count))
        var position = 0
        for _ in 0..<count {
            guard try readUInt32(bytes, position) == centralHeaderSignature else { throw .notAZip }
            let flags = try readUInt16(bytes, position + 8)
            let method = try readUInt16(bytes, position + 10)
            let dosTime = try readUInt16(bytes, position + 12)
            let dosDate = try readUInt16(bytes, position + 14)
            let crc = try readUInt32(bytes, position + 16)
            let compressed = try readUInt32(bytes, position + 20)
            let uncompressed = try readUInt32(bytes, position + 24)
            let nameLength = Int(try readUInt16(bytes, position + 28))
            let extraLength = Int(try readUInt16(bytes, position + 30))
            let commentLength = Int(try readUInt16(bytes, position + 32))
            let localOffset = try readUInt32(bytes, position + 42)

            let nameStart = position + centralHeaderSize
            let extraStart = nameStart + nameLength
            let next = extraStart + extraLength + commentLength
            guard next <= bytes.count else { throw .notAZip }

            let extra = Array(bytes[extraStart..<extraStart + extraLength])
            var entry = CentralEntry(
                nameBytes: Data(bytes[nameStart..<extraStart]),
                flags: flags,
                method: method,
                dosTime: dosTime,
                dosDate: dosDate,
                crc32: crc,
                compressedSize: UInt64(compressed),
                uncompressedSize: UInt64(uncompressed),
                localHeaderOffset: UInt64(localOffset),
                extraField: Data(extra)
            )
            if uncompressed == 0xFFFF_FFFF || compressed == 0xFFFF_FFFF || localOffset == 0xFFFF_FFFF {
                try applyZip64Extra(extra, to: &entry, uncompressed: uncompressed, compressed: compressed, offset: localOffset)
            }
            entries.append(entry)
            position = next
        }
        return entries
    }

    private static func applyZip64Extra(
        _ extra: [UInt8],
        to entry: inout CentralEntry,
        uncompressed: UInt32,
        compressed: UInt32,
        offset: UInt32
    ) throws(ArchiveError) {
        guard let block = extraBlock(0x0001, in: extra) else { throw .notAZip }
        var cursor = block.lowerBound
        func take() throws(ArchiveError) -> UInt64 {
            guard cursor + 8 <= block.upperBound else { throw .notAZip }
            let value = try readUInt64(extra, cursor)
            cursor += 8
            return value
        }
        if uncompressed == 0xFFFF_FFFF { entry.uncompressedSize = try take() }
        if compressed == 0xFFFF_FFFF { entry.compressedSize = try take() }
        if offset == 0xFFFF_FFFF { entry.localHeaderOffset = try take() }
    }

    /// 拡張フィールドの中から指定の ID のデータ部の範囲を探す。壊れていれば nil
    private static func extraBlock(_ identifier: UInt16, in extra: [UInt8]) -> Range<Int>? {
        var position = 0
        while position + 4 <= extra.count {
            let id = UInt16(extra[position]) | UInt16(extra[position + 1]) << 8
            let size = Int(UInt16(extra[position + 2]) | UInt16(extra[position + 3]) << 8)
            let start = position + 4
            guard start + size <= extra.count else { return nil }
            if id == identifier { return start..<start + size }
            position = start + size
        }
        return nil
    }

    // MARK: - ローカルヘッダ

    /// ローカルヘッダの先頭 30 バイトから、データの開始位置（ローカルヘッダの位置 + 30 + 名前 + 拡張）を返す。
    /// 中央ディレクトリと拡張フィールドの長さが異なることがあるため、ローカルヘッダの値を使う
    static func dataOffset(
        localHeader: Data,
        localHeaderOffset: UInt64
    ) throws(ArchiveError) -> UInt64 {
        let bytes = [UInt8](localHeader.prefix(localHeaderSize))
        guard bytes.count >= localHeaderSize,
              (try? readUInt32(bytes, 0)) == localHeaderSignature else {
            throw .corrupted(.headerDamaged)
        }
        let nameLength = UInt64(try readUInt16(bytes, 26))
        let extraLength = UInt64(try readUInt16(bytes, 28))
        let (sum, overflow) = localHeaderOffset.addingReportingOverflow(
            UInt64(localHeaderSize) + nameLength + extraLength
        )
        guard !overflow else { throw .corrupted(.invalidOffset) }
        return sum
    }

    // MARK: - 日時

    /// 0x5455 の更新時刻（UTC）があれば使い、なければ DOS 日時を `TimeZone.current` の現地時刻として読む。
    /// 日付として成り立たない DOS 日時（0 など）は nil
    static func modificationDate(dosDate: UInt16, dosTime: UInt16, extra: Data) -> Date? {
        if let unix = unixModificationTime(in: extra) {
            return Date(timeIntervalSince1970: TimeInterval(unix))
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return dosDateTime(dosDate: dosDate, dosTime: dosTime, calendar: calendar)
    }

    /// 拡張タイムスタンプ（0x5455）の更新時刻。なければ nil
    static func unixModificationTime(in extra: Data) -> UInt32? {
        guard !extra.isEmpty else { return nil }
        let bytes = [UInt8](extra)
        guard let block = extraBlock(0x5455, in: bytes), block.count >= 5,
              bytes[block.lowerBound] & 1 != 0,
              let value = try? readUInt32(bytes, block.lowerBound + 1) else { return nil }
        return value
    }

    static func dosDateTime(dosDate: UInt16, dosTime: UInt16, calendar: Calendar) -> Date? {
        let day = Int(dosDate & 0x1F)
        let month = Int((dosDate >> 5) & 0x0F)
        guard (1...12).contains(month), day >= 1 else { return nil }
        let components = DateComponents(
            year: Int(dosDate >> 9) + 1980,
            month: month,
            day: day,
            hour: Int(dosTime >> 11),
            minute: Int((dosTime >> 5) & 0x3F),
            second: Int(dosTime & 0x1F) * 2
        )
        return calendar.date(from: components)
    }

    // MARK: - 範囲を確かめる読み出し

    private static func readUInt16(_ bytes: [UInt8], _ offset: Int) throws(ArchiveError) -> UInt16 {
        guard offset >= 0, offset + 2 <= bytes.count else { throw .notAZip }
        return UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func readUInt32(_ bytes: [UInt8], _ offset: Int) throws(ArchiveError) -> UInt32 {
        guard offset >= 0, offset + 4 <= bytes.count else { throw .notAZip }
        return UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
    }

    private static func readUInt64(_ bytes: [UInt8], _ offset: Int) throws(ArchiveError) -> UInt64 {
        guard offset >= 0, offset + 8 <= bytes.count else { throw .notAZip }
        var value: UInt64 = 0
        for index in 0..<8 {
            value |= UInt64(bytes[offset + index]) << UInt64(8 * index)
        }
        return value
    }
}
