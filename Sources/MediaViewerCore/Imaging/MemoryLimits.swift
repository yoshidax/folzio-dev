public enum MemoryLimits {
    public static let previewCacheBytes = 256 * 1024 * 1024
    public static let thumbnailCacheBytes = 128 * 1024 * 1024
    /// zip の中の画像 1 項目として読み込む展開後のサイズの上限（research.md R24）
    public static let archiveImageBytes = 512 * 1024 * 1024
}
