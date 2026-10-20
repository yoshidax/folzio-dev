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
    case corrupted(String)

    /// UI にそのまま出す文言
    public var message: String {
        switch self {
        case .notFound:
            return "zip を開けません: zip ファイルが見つかりません"
        case .accessDenied:
            return "zip を開けません: アクセスできません"
        case .notAZip:
            return "zip を開けません: zip ファイルとして読めません"
        case .multiDisk:
            return "zip を開けません: 分割された zip には対応していません"
        case .entryEncrypted:
            return "暗号化されているため表示できません"
        case .unsupportedMethod:
            return "対応していない圧縮方式です"
        case .tooLarge:
            return "zip の中の画像が大きすぎるため表示できません"
        case .corrupted(let reason):
            return "zip を開けません: \(reason)"
        }
    }
}
