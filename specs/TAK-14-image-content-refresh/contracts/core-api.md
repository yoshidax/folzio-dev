# Contract: FolzioCore の API の変更（TAK-14）

FolzioApp と FolzioCore の間の、この feature で変わる公開 API。アプリの外部への契約（キーボード・設定・保存キー）は変えない。

## FileContentVersion（新規）

```swift
public struct FileContentVersion: Hashable, Sendable {
    public var fileSize: Int64
    public var modificationDate: Date?
    public var fileIdentifier: UInt64?
}
```

## MediaFile

- `public var contentVersion: FileContentVersion?` を追加。イニシャライザの引数は既定値 `nil` で追加し、既存の呼び出しを壊さない。

## DecodedImageCache

- `get(_ url: URL, version: FileContentVersion?) -> DecodedImage?`
- `put(_ image: DecodedImage, for url: URL, version: FileContentVersion?)`
- 旧 `get(_:)`・`put(_:for:)` は削除する（版を渡し忘れて古い画像が当たることを防ぐ）。

## ThumbnailProviding

```swift
func thumbnail(for url: URL, pointSize: Double, scale: Double, version: FileContentVersion?) async -> CGImage?
func cancel(for url: URL, pointSize: Double, scale: Double, version: FileContentVersion?)
```

## BrowserModel

- `public private(set) var contentChangeGeneration: Int`（観察対象）
- `public private(set) var changedContentURLs: Set<URL>`
- 呼び出し側の約束: App は `contentChangeGeneration` が変わったとき、`listing.files` の URL の並びが前回と同じなら、
  `changedContentURLs` に含まれる行だけを読み込み直す。並びが違えば従来どおり全体を読み込み直す。
