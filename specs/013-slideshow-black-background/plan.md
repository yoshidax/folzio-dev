# Implementation Plan: スライドショーの背景色

**Branch**: `013-slideshow-black-background` | **Date**: 2026-10-28 | **Spec**: [spec.md](spec.md)

## Summary

スライドショーのライフサイクルからプレビューの背景を黒に切り替え、終了・中止時に通常背景へ復帰する。切り替え効果のオーバーレイも黒にする。画像、動画、透明部分、状態表示の描画階層を確認し、必要なビューの背景と文字の見やすさを調整する。

## Technical Context

- Swift 6、macOS 15 以降、AppKit、Swift Package、外部依存なし。
- UI は `MediaViewerApp`、Core に AppKit を持ち込まない。永続設定・通信・データモデルの追加なし。
- Swift Testing と手動 GUI 確認を使用。色・表示階層は GUI で確認する。
- 既存のデコード・切り替えタイミング・性能目標を維持する。

## Constitution Check

I: 通信・ファイル変更なし。II: 描画色のみの変更で重い処理を追加しない。III: 既存の操作とアクセシビリティを維持し、状態表示の可読性を確認する。IV: 既存テストおよび GUI で検証する。新たな Core 判断が必要なら Core テストを付ける。V: 新しい設定や依存を追加しない。設計後も全項目に適合。

## Project Structure

- `Sources/MediaViewerApp/App/MainSplitViewController.swift`: 開始、復帰、中止の状態連携。
- `Sources/MediaViewerApp/Preview/PreviewViewController.swift`: プレビュー背景と各子ビューの扱い。
- `Sources/MediaViewerApp/Preview/ImagePreviewView.swift`、動画ビュー: 透明部分・状態表示を確認し必要に応じて修正。
- `Sources/MediaViewerApp/Preview/SlideshowTransitionOverlayView.swift`: 切り替え中の背景。
- `specs/013-slideshow-black-background/quickstart.md`: 手動確認。

## Design

プレビュー用の一時的な状態を開始成功時に有効化し、通常復帰・全画面復帰・即時中止のすべての経路で解除する。View の描画順と背景を調査し、画像の透明部分や動画周囲まで黒が届くようにする。オーバーレイはスライドショー用なので黒い背景で表示する。通常時は既存の外観を保持する。通知文字や動画操作部品の可読性を維持する。画面遷移・アニメーションに起因する色のちらつきは手動で確認する。

## Complexity Tracking

憲章違反なし。新しい外部契約・永続モデルはない。
