import Compression
import Foundation

/// zip の deflate 項目を先頭から順方向に展開するカーソル（research.md R24・R25）。
/// `compression_stream`（`COMPRESSION_ZLIB` はヘッダのない生の DEFLATE）を包み、入力は圧縮データの範囲から 64KB ずつ `pread` で読む。
/// 展開後の位置 `position` を覚え、前へ戻るときは `reset()` で先頭から展開し直す。
/// スレッドセーフではない。複数のスレッドから使うときは呼び出し側で直列化する。
final class InflateCursor {
    private static let inputChunkSize = 64 * 1024
    private static let scratchSize = 64 * 1024

    private let file: ArchiveFile
    private let dataOffset: UInt64
    private let compressedSize: UInt64

    private var stream: compression_stream
    private var streamReady = false
    private let input: UnsafeMutablePointer<UInt8>
    private let placeholder: UnsafeMutablePointer<UInt8>
    private var scratch: UnsafeMutablePointer<UInt8>?

    /// 圧縮データのうち、すでにファイルから読んだバイト数
    private var inputRead: UInt64 = 0
    /// 圧縮データの終わりまで読み終えた
    private var inputExhausted = false
    /// 圧縮データの終わり（または、これ以上は展開できない状態）に達した
    private var finished = false
    private var failed = false

    /// 展開後の位置
    private(set) var position: UInt64 = 0

    init(file: ArchiveFile, dataOffset: UInt64, compressedSize: UInt64) {
        self.file = file
        self.dataOffset = dataOffset
        self.compressedSize = compressedSize
        input = UnsafeMutablePointer<UInt8>.allocate(capacity: Self.inputChunkSize)
        placeholder = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        stream = compression_stream(
            dst_ptr: placeholder, dst_size: 0,
            src_ptr: UnsafePointer(placeholder), src_size: 0, state: nil
        )
        failed = !startStream()
    }

    deinit {
        if streamReady { compression_stream_destroy(&stream) }
        input.deallocate()
        placeholder.deallocate()
        scratch?.deallocate()
    }

    /// 先頭から展開し直す
    func reset() {
        if streamReady {
            compression_stream_destroy(&stream)
            streamReady = false
        }
        inputRead = 0
        inputExhausted = false
        finished = false
        position = 0
        failed = !startStream()
    }

    /// 展開後の `target` まで、読み捨てて進む。いまの位置より前なら先頭から展開し直す。
    /// 圧縮データの終わりが先にあれば、そこで止まる（`position` で確かめる）
    func skip(to target: UInt64) throws(ArchiveError) {
        if target < position { reset() }
        guard position < target else { return }
        let buffer: UnsafeMutablePointer<UInt8>
        if let scratch {
            buffer = scratch
        } else {
            buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Self.scratchSize)
            scratch = buffer
        }
        while position < target {
            let wanted = Int(min(UInt64(Self.scratchSize), target - position))
            let produced = try read(into: UnsafeMutableRawBufferPointer(start: buffer, count: wanted), maxLength: wanted)
            if produced == 0 { return }
        }
    }

    /// 最大 `maxLength` バイトを展開して `buffer` に書き、書いたバイト数を返す。
    /// 圧縮データの終わりより先を求められたら、展開できた分だけを返す（終わりでは 0）
    func read(into buffer: UnsafeMutableRawBufferPointer, maxLength: Int) throws(ArchiveError) -> Int {
        guard !failed else { throw .corrupted("展開を始められません") }
        let limit = min(maxLength, buffer.count)
        guard limit > 0, !finished, let base = buffer.baseAddress else { return 0 }

        stream.dst_ptr = base.assumingMemoryBound(to: UInt8.self)
        stream.dst_size = limit
        defer {
            stream.dst_ptr = placeholder
            stream.dst_size = 0
        }

        while stream.dst_size > 0, !finished {
            if stream.src_size == 0, !inputExhausted {
                try refillInput()
            }
            let before = (source: stream.src_size, destination: stream.dst_size)
            let flags: Int32 = inputExhausted && stream.src_size == 0
                ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
            let status = compression_stream_process(&stream, flags)
            if status == COMPRESSION_STATUS_END {
                finished = true
            } else if status == COMPRESSION_STATUS_OK {
                // 入力を使い切り、出力も増えないなら、これ以上は展開できない（圧縮データが途中で終わっている）
                if stream.src_size == before.source, stream.dst_size == before.destination, inputExhausted {
                    finished = true
                }
            } else {
                finished = true
                failed = true
                position += UInt64(limit - stream.dst_size)
                throw .corrupted("圧縮データが壊れています")
            }
        }
        let produced = limit - stream.dst_size
        position += UInt64(produced)
        return produced
    }

    // MARK: - 内部

    private func startStream() -> Bool {
        stream.dst_ptr = placeholder
        stream.dst_size = 0
        stream.src_ptr = UnsafePointer(placeholder)
        stream.src_size = 0
        let status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
        streamReady = status == COMPRESSION_STATUS_OK
        return streamReady
    }

    private func refillInput() throws(ArchiveError) {
        let remaining = compressedSize - inputRead
        let (start, overflow) = dataOffset.addingReportingOverflow(inputRead)
        guard remaining > 0, !overflow else {
            inputExhausted = true
            return
        }
        let wanted = Int(min(UInt64(Self.inputChunkSize), remaining))
        let count = try file.read(
            into: UnsafeMutableRawBufferPointer(start: input, count: wanted), at: start
        )
        guard count > 0 else {
            inputExhausted = true
            return
        }
        inputRead += UInt64(count)
        if inputRead >= compressedSize { inputExhausted = true }
        stream.src_ptr = UnsafePointer(input)
        stream.src_size = count
    }
}
