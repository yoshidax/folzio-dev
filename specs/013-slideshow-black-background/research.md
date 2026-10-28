# Research: スライドショーの背景色

## 表示とライフサイクル

- 決定: `MainSplitViewController` のスライドショー開始・復帰・破棄経路と `PreviewViewController` の描画領域を連携する。
- 理由: プレビューのみ表示は通常時にも使われるため、ペイン配置からスライドショーを推測できない。
- 代替: プレビューのみ表示を一律に黒くする案は通常時まで変わるため採用しない。

## 切り替え中

- 決定: `SlideshowTransitionOverlayView` の背景も黒にする。
- 理由: 現在は `windowBackgroundColor` を設定し、切り替え効果中に通常色が現れる。
- 代替: コンテナだけを黒くする案はオーバーレイに覆われるため不十分。
