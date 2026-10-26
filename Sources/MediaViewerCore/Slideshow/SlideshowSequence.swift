import Foundation

public enum SlideshowAdvance: Equatable, Sendable {
    case target(URL)
    case finish
    case empty
}

/// スライドショーの対象列・開始位置・次の対象を、最新の一覧と選択から求める純粋計算。
/// 実行中の固定 playlist は持たず、呼ぶたびに `listing.files` から導出する。
public struct SlideshowSequence: Sendable {
    public init() {}

    /// 表示順を保ったまま、対応メディアの URL だけを取り出す。フォルダ・zip 自体・
    /// zip 内ディレクトリ・親リンクは `kind.isMedia` でないため含まれない。
    public static func candidates(in files: [MediaFile]) -> [URL] {
        files.compactMap { $0.kind.isMedia ? $0.url : nil }
    }

    /// 開始位置。選択中のフォーカスメディア → 選択中メディアの表示順先頭 → 対象先頭。
    /// 選択が非メディアだけ、または空なら対象先頭になる。
    public static func startTarget(
        in files: [MediaFile],
        selected: Set<URL>,
        focused: URL?
    ) -> URL? {
        let candidates = candidates(in: files)
        guard !candidates.isEmpty else { return nil }

        if let focused, selected.contains(focused), candidates.contains(focused) {
            return focused
        }
        if let firstSelected = candidates.first(where: { selected.contains($0) }) {
            return firstSelected
        }
        return candidates.first
    }

    /// 最新のフォーカスが対象に残っていればその次（末尾なら先頭）、残っていなければ先頭。
    /// 対象が空なら nil。
    public static func nextTarget(in files: [MediaFile], focused: URL?) -> URL? {
        if case .target(let url) = advance(in: files, focused: focused, repeats: true) {
            return url
        }
        return nil
    }

    /// 最新の一覧で次の対象を求める。繰り返さない場合、末尾では送らずに終了する。
    /// 選択が消えた場合は、繰り返しの設定にかかわらず先頭から続ける。
    public static func advance(in files: [MediaFile], focused: URL?, repeats: Bool) -> SlideshowAdvance {
        let candidates = candidates(in: files)
        guard let first = candidates.first else { return .empty }

        guard let focused, let index = candidates.firstIndex(of: focused) else {
            return .target(first)
        }
        if index + 1 < candidates.count {
            return .target(candidates[index + 1])
        }
        return repeats ? .target(first) : .finish
    }

    public static func hasMedia(in files: [MediaFile]) -> Bool {
        files.contains { $0.kind.isMedia }
    }
}
