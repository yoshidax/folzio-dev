import CoreGraphics
import Foundation

/// プレビューの表示倍率（FR-133）。100% は FR-028 のフィット表示であり、原寸ではない（A-62）。
/// 25%以上800%以下の25%刻みだけを取り、上下限では値を変えない。
public struct PreviewZoom: Sendable, Equatable, Comparable {
    public static let step = 25
    public static let minimum = 25
    public static let maximum = 800
    public static let fit = PreviewZoom(percentage: 100)!

    public let percentage: Int

    public init?(percentage: Int) {
        guard (Self.minimum...Self.maximum).contains(percentage),
              percentage % Self.step == 0 else { return nil }
        self.percentage = percentage
    }

    /// フィットの矩形に掛ける倍率
    public var scale: CGFloat { CGFloat(percentage) / 100 }

    public var canZoomIn: Bool { percentage < Self.maximum }
    public var canZoomOut: Bool { percentage > Self.minimum }

    public func zoomedIn() -> PreviewZoom {
        PreviewZoom(percentage: percentage + Self.step) ?? self
    }

    public func zoomedOut() -> PreviewZoom {
        PreviewZoom(percentage: percentage - Self.step) ?? self
    }

    public static func < (lhs: PreviewZoom, rhs: PreviewZoom) -> Bool {
        lhs.percentage < rhs.percentage
    }
}

/// 表示中の画像と倍率の対応（FR-137）。別の画像に切り替わったときだけ100%に戻す。
/// 保存も履歴への記録もしない。
public struct PreviewZoomTracker: Sendable, Equatable {
    public private(set) var level: PreviewZoom = .fit
    /// 表示中の画像の同一性。空・動画・表示不能は nil
    public private(set) var imageIdentity: URL?

    public init() {}

    /// 表示対象を伝える。同一性が変わったときだけ100%に戻し、true を返す。
    @discardableResult
    public mutating func present(_ identity: URL?) -> Bool {
        guard identity != imageIdentity else { return false }
        imageIdentity = identity
        level = .fit
        return true
    }

    /// 同じ画像のまま100%に戻す（履歴の移動用）。変わったら true。
    @discardableResult
    public mutating func reset() -> Bool {
        fit()
    }

    @discardableResult
    public mutating func zoomIn() -> Bool {
        update(level.zoomedIn())
    }

    @discardableResult
    public mutating func zoomOut() -> Bool {
        update(level.zoomedOut())
    }

    @discardableResult
    public mutating func fit() -> Bool {
        update(.fit)
    }

    private mutating func update(_ newLevel: PreviewZoom) -> Bool {
        guard newLevel != level else { return false }
        level = newLevel
        return true
    }
}

/// 拡大・縮小・表示領域に合わせるの可否（FR-134・FR-136）。
/// シート・名前の変更中・設定ウインドウがキーであることは条件に含めない（A-73）。
public struct PreviewZoomAvailability: Sendable, Equatable {
    /// プレビューが画像を実際に表示しているか（アニメーションの最初のフレーム待ちは false）
    public var isImageDisplayed: Bool
    /// 3ペイン・プレビューのみ表示・フルスクリーンのいずれかでプレビューが見えているか
    public var isPreviewVisible: Bool
    public var level: PreviewZoom

    public init(isImageDisplayed: Bool, isPreviewVisible: Bool, level: PreviewZoom) {
        self.isImageDisplayed = isImageDisplayed
        self.isPreviewVisible = isPreviewVisible
        self.level = level
    }

    public var isAvailable: Bool { isImageDisplayed && isPreviewVisible }
    public var canZoomIn: Bool { isAvailable && level.canZoomIn }
    public var canZoomOut: Bool { isAvailable && level.canZoomOut }
    public var canFit: Bool { isAvailable }
}
