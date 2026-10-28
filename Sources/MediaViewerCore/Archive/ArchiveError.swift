import Foundation

public enum ArchiveError: Error, Sendable, Equatable {
    case notFound
    case accessDenied
    /// 終端レコードが見つからない・構造が壊れている
    case notAZip
    /// 分割 zip
    case multiDisk
    case entryEncrypted
    case unsupportedMethod(UInt16)
    /// 画像の 512MB 上限（research.md R24）
    case tooLarge
    case corrupted(ArchiveCorruption)
}

/// zip の内容が壊れている理由（表示言語に依存しない値）。文言は `MediaViewerLocalization` が決める
public enum ArchiveCorruption: Error, Sendable, Equatable {
    case cannotStartInflate
    case compressedDataDamaged
    case dataTruncated
    case compressedDataTruncated
    case headerDamaged
    case invalidOffset
    case centralDirectoryTooLarge
    case invalidLocation
    case entryNotFound
    case sizeMismatch
    case dataOutsideFile
    case readCancelled
    case readFailed
    case unreadable
}
