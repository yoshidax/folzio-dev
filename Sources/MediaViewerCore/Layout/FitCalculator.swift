import CoreGraphics

public struct FitCalculator {
    public static func fit(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              container.width > 0, container.height > 0 else {
            return .zero
        }

        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    /// フィットの矩形を、中心を保ったまま `zoom.scale` 倍する（FR-029・FR-133）。
    /// コンテナより大きいときは原点が負になる。丸めはしない。
    public static func frame(imageSize: CGSize, in container: CGSize, zoom: PreviewZoom) -> CGRect {
        let fitted = fit(imageSize: imageSize, in: container)
        guard fitted != .zero else { return .zero }
        guard zoom != .fit else { return fitted }

        let size = CGSize(width: fitted.width * zoom.scale, height: fitted.height * zoom.scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}
