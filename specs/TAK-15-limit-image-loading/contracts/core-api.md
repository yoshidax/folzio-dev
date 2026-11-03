# Contract: FolzioCore の API の変更（TAK-15）

FolzioApp と FolzioCore の間の、この feature で変わる API。アプリの外部への契約（キーボード・設定・保存キー）は変えない。
FolzioApp の呼び出しは変わらない。

## ImageLoadPriority / ImageLoadScheduler（新規）

```swift
public enum ImageLoadPriority: Sendable { case preview, prefetch }

public actor ImageLoadScheduler {
    public static let defaultLimit = 2
    public static let defaultPrefetchLimit = 1

    public init(limit: Int = defaultLimit, prefetchLimit: Int = defaultPrefetchLimit)

    /// Returns true when a slot was acquired. Returns false when cancelled before or while waiting.
    public func acquire(_ priority: ImageLoadPriority) async -> Bool
    public func release(_ priority: ImageLoadPriority)

    /// The largest number of slots held at the same time since creation.
    public var peakRunning: Int { get }
}
```

## BrowserModel

- `init` に `loadScheduler: ImageLoadScheduler = ImageLoadScheduler()` を加える（既定値のため、既存の呼び出しは変わらない。テストが上限を観測する）。
- 公開メンバーの追加・削除なし。プレビューと先読みの内部の経路だけが変わる。

## ImageDecoding

- プロトコルは変えない。`ImageDecoder.decode(_:maxPixelSize:)`・`decode(data:maxPixelSize:)` は、呼び出し側の取り消しを内側のタスクに伝える。
  取り消されたときは `DecodeError` を投げる（既存の型のまま。新しい case は足さず、呼び出し側は取り消しを `Task.isCancelled` で判別する）。
