import Foundation
import UniformTypeIdentifiers

/// 名前だけから、その名前のフォルダがパッケージとして扱われるかを判定する（EC-53、research.md R57）。
/// ディスクの状態（バンドルビット）は見ないため、名前を変える前に使える
public enum PackageName {
    /// 拡張子がパッケージの型（.app・.bundle・.rtfd など）なら true。拡張子がなければ false
    public static func isPackage(_ name: String) -> Bool {
        let fileExtension = (name as NSString).pathExtension
        guard !fileExtension.isEmpty else { return false }
        return UTType(filenameExtension: fileExtension, conformingTo: .directory)?.conforms(to: .package) == true
    }
}
