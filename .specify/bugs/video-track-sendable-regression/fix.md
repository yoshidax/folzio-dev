# Bug Fix: 最新の Swift（macOS SDK 27.2）で VideoPreviewView がビルドできない

- **Slug**: video-track-sendable-regression
- **Fixed**: 2026-10-31
- **Assessment**: ./assessment.md
- **Status**: applied（ビルドの確認は CI と保守者のローカルで行う。「Local Verification」を参照）
- **Issue**: [TAK-31](https://linear.app/takyoshida/issue/TAK-31)

## Summary

TAK-28 で足した補助関数 `loadHasVideoTrack(of:)` を取り除いて、TAK-28 より前のコードに戻し、`VideoPreviewView.swift` の `AVFoundation` のインポートを `@preconcurrency import AVFoundation` にした。

## Changes

| File | Change | Notes |
|------|--------|-------|
| `Sources/FolzioApp/Preview/VideoPreviewView.swift` | modified | 補助関数を削除し、`Task` の中で `asset.loadTracks(withMediaType:)` を直接呼ぶコードに戻した。インポートを `@preconcurrency import AVFoundation` にし、理由を英語のコメントで書いた |

## Diff Highlights (optional)

`72753a3`（TAK-28 より前）との差分は、インポートの行とそのコメントだけ。

```swift
// `[AVAssetTrack]` is not `Sendable` in the Swift 6.0 SDK. `@preconcurrency` keeps that diagnostic a warning,
// so the same code builds with both the oldest supported and the latest toolchains.
@preconcurrency import AVFoundation
```

## Tests Added or Updated

- なし。ビルドそのものが回帰の確認になる（assessment の「Tests to add or update」）。

## Local Verification

- この環境（クラウド）には Swift がなく、`swift build` は実行できない。
- 実行した検査（クラウド）: `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`
- Swift 6.0（Xcode 16.0）でのビルドとテスト: PR の CI で確認する
- 最新の版（macOS SDK 27.2）でのビルド: 保守者が `swift build`、`swift build --build-tests`、`swift test` を実行して報告する

## Deviations from Assessment

なし。

## Follow-ups

- CI（macos-15、Xcode 16.0）には最新の SDK がないため、この種の回帰は CI では見つからない。最新の版でのビルドは、保守者のローカルでの確認が必要
- TAK-28 の `test.md` の記録を訂正した（`.specify/bugs/swift-6x-typed-throws-closure/test.md` の末尾）
