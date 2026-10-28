# Implementation Plan: 拡大プレビューのスクロール

**Branch**: `012-preview-scroll` | **Date**: 2026-10-28 | **Spec**: [spec.md](spec.md)

## Summary

画像のはみ出す軸にスクロールバーを重ねて表示し、ポインタとプレビューにフォーカスした ⌥方向キーで移動する。フィット倍率はスクロールバーで変えず、表示位置の変換と制限は Core に分離する。通常・全画面・スライドショーの画像表示、既存のアニメーションや遷移を維持する。

## Technical Context

**Language/Version**: Swift 6  
**Primary Dependencies**: AppKit、標準フレームワークのみ  
**Storage**: 位置は一時状態、保存しない  
**Testing**: Swift Testing、手動 GUI 確認  
**Target Platform**: macOS 15 以降  
**Project Type**: Swift Package デスクトップアプリ  
**Performance Goals**: 憲章 II の既存性能基準を維持し、スクロール・倍率変更でデコードを再実行しない  
**Constraints**: オフライン、UI スレッドでデコードしない、AppKit は App 層に限定  
**Scale/Scope**: 画像プレビューのみ。動画・ドラッグパン・ピンチは対象外。

## Constitution Check

- I: ネットワーク、ファイル書き込みや永続化を追加しない。
- II: 既存の非同期デコードとキャッシュを維持し、位置計算のみ UI 更新時に実施。既存性能テストと GUI で応答を確認する。
- III: プレビューにフォーカスした ⌥方向キーとアクセス可能なスクロールバーを提供し、既存の修飾なし方向キーを維持する。
- IV: フィット・両軸・片軸・境界・位置維持・不正寸法の Core 計算を Swift Testing で確認。UI は手動で検証する。
- V: 外部依存や新設定なし。標準スクロール機構を優先する。

設計後も適合。違反なし。

## Project Structure

```text
Sources/MediaViewerCore/Layout/       # 画像位置・スクロール範囲の計算
Sources/MediaViewerApp/Preview/       # AppKit の表示・スクロール・入力
Sources/MediaViewerApp/               # 必要なキールーティング
Tests/MediaViewerCoreTests/           # 位置・境界の回帰テスト
Tests/MediaViewerPerformanceTests/    # 既存性能検証
specs/012-preview-scroll/             # 仕様・設計・検証記録
```

**Structure Decision**: 描画・入力は App、座標計算は Core。既存の `ImagePreviewView` のレイヤーとアニメーションは維持し、重ね合わせ型スクロールバーとクリップを持つ標準スクロール機構を検討する。画像表示のラッパーを導入する場合も、メッセージ表示・ダブルクリック・アクセシビリティ・スライドショー snapshot の座標変換を保持する。バーの有無によるレイアウトの再帰・フィット寸法の変化を避ける。既存のキールーティングを調査し、修飾なし方向キーとツリーの ⌥方向キーに干渉しないようプレビューのフォーカスに限定する。

## Complexity Tracking

違反なし。
