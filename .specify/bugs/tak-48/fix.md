# Bug Fix: 通常表示でプレビューの動画にフォーカスしても Space で再生・一時停止できない

- **Slug**: tak-48
- **Fixed**: 2026-11-02
- **Assessment**: ./assessment.md
- **Status**: partial（ビルド・テストは Cloud で実行できず、CI と保守者の実機確認が必要）

## Summary

動画表示中のフォーカスの受け先を、キーを処理しないコンテナ `VideoPreviewView` から、子の `AVPlayerView` に変えた。
Space・← →・↑ ↓ が標準の動画コントロールの動作として届くようにする（FR-033・FR-248）。

## Changes

| File | Change | Notes |
|------|--------|-------|
| `Sources/FolzioApp/Preview/VideoPreviewView.swift` | modified | `acceptsFirstResponder` を false にし、`focusTargetView`（`playerView`）を公開 |
| `Sources/FolzioApp/Preview/PreviewViewController.swift` | modified | `primaryFocusView` が動画表示中に `videoView.focusTargetView` を返す |
| `Tests/FolzioAppTests/VideoPreviewFocusTests.swift` | added test | フォーカスの受け先が内側の player view であることを固定 |

## Tests Added or Updated

- `VideoPreviewFocusTests.focusTargetIsInnerPlayerView` — コンテナはフォーカスを受けず、`focusTargetView` が子孫のビューであること。

## Local Verification

- Cloud では `swift build` / `swift test` を実行できない。CI で確認する。
- `AVPlayerView` が first responder を受け入れ、Space が効くかは GUI でしか確かめられない（未確認）。

## Deviations from Assessment

なし。保守者の回答により、フォーカスの移し方（クリック・Tab・⌥⌘3）による差はなかった。

## Follow-ups

- 保守者の実機確認: `quickstart.md` の M6、Tab / ⌥⌘3 でプレビューへ移ったときの Space・← → ・↑ ↓、フォーカスリングの見え方。
- フルスクリーンで効く理由は未確認のまま。
