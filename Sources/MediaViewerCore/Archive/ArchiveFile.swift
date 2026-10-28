import Darwin
import Foundation

/// 読み取り専用で開いた zip ファイルの記述子。参照カウントで共有し、最後の参照が消えたときに閉じる。
/// 読み出しはすべて `pread`（オフセット指定）なので、複数の読み出しで共有しても互いに干渉しない（research.md R22）。
/// zip 全体を読み込まない・メモリマップしない。
final class ArchiveFile: Sendable {
    let url: URL
    let size: UInt64
    let identity: ArchiveIdentity
    private let descriptor: Int32

    private init(url: URL, descriptor: Int32, size: UInt64, identity: ArchiveIdentity) {
        self.url = url
        self.descriptor = descriptor
        self.size = size
        self.identity = identity
    }

    deinit {
        close(descriptor)
    }

    static func open(_ url: URL) throws(ArchiveError) -> ArchiveFile {
        let descriptor = Darwin.open(url.path, O_RDONLY | O_CLOEXEC)
        guard descriptor >= 0 else { throw error(forErrno: errno) }

        var info = stat()
        guard fstat(descriptor, &info) == 0 else {
            let code = errno
            close(descriptor)
            throw error(forErrno: code)
        }
        guard (info.st_mode & S_IFMT) == S_IFREG else {
            close(descriptor)
            throw .notAZip
        }
        let identity = makeIdentity(info)
        return ArchiveFile(url: url, descriptor: descriptor, size: identity.fileSize, identity: identity)
    }

    /// パスの `stat`。ファイルが消えていれば nil
    static func currentIdentity(of url: URL) -> ArchiveIdentity? {
        var info = stat()
        guard stat(url.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { return nil }
        return makeIdentity(info)
    }

    /// `offset` から最大 `length` バイトを読む。ファイルの終わりを越える分は読まない（短くなる）
    func read(at offset: UInt64, length: Int) throws(ArchiveError) -> Data {
        guard length > 0, offset < size else { return Data() }
        let count = Int(min(UInt64(length), size - offset))
        let raw = UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 1)
        defer { raw.deallocate() }
        let read = try read(into: raw, at: offset)
        guard read > 0, let base = raw.baseAddress else { return Data() }
        return Data(bytes: base, count: read)
    }

    /// `offset` から `buffer` の大きさまで読み、読めたバイト数を返す（ファイルの終わりでは 0）
    func read(into buffer: UnsafeMutableRawBufferPointer, at offset: UInt64) throws(ArchiveError) -> Int {
        guard let base = buffer.baseAddress, !buffer.isEmpty,
              offset < size, offset <= UInt64(Int64.max) else { return 0 }
        var total = 0
        while total < buffer.count {
            let position = offset + UInt64(total)
            guard position <= UInt64(Int64.max) else { break }
            let result = pread(descriptor, base + total, buffer.count - total, off_t(position))
            if result > 0 {
                total += result
            } else if result == 0 {
                break
            } else if errno == EINTR {
                continue
            } else {
                throw .corrupted(.readFailed)
            }
        }
        return total
    }

    private static func makeIdentity(_ info: stat) -> ArchiveIdentity {
        let seconds = TimeInterval(info.st_mtimespec.tv_sec)
        let fraction = TimeInterval(info.st_mtimespec.tv_nsec) / 1_000_000_000
        return ArchiveIdentity(
            fileSize: UInt64(clamping: info.st_size),
            modificationDate: Date(timeIntervalSince1970: seconds + fraction),
            inode: UInt64(info.st_ino)
        )
    }

    private static func error(forErrno code: Int32) -> ArchiveError {
        switch code {
        case ENOENT, ENOTDIR:
            return .notFound
        case EACCES, EPERM:
            return .accessDenied
        default:
            return .corrupted(.unreadable)
        }
    }
}
