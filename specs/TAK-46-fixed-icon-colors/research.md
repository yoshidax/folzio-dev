# Research: TAK-46

## R1: 青の定義
- **Decision**: 固定の sRGB 値（0.00, 0.48, 1.00）。
- **Rationale**: 保守者が「固定の青 NSColor」を選択した。`.systemBlue` はアクセントではないが、OS の版・外観で値が変わり得る。固定値なら FR-255 を確実に満たす。
- **Alternatives**: `.systemBlue`（OS 依存）、ツリーの実描画の色を測って合わせる（GUI でのスクリーンショットが必要。保守者の確認で微調整する）。

## R2: 黄の定義と明度
- **Decision**: sRGB（0.96, 0.72, 0.00）。青との HSB 明度差を 0.1 以内にする。
- **Rationale**: Issue は「青と明度を近づけ、統一感を出す」。明度を HSB の B で数値化するとテストできる。`.systemYellow` 基準で、白背景での視認性のためやや暗くした。
- **Alternatives**: `.systemOrange` 寄り（黄らしさが弱い）。知覚輝度（相対輝度）で揃える案は、黄が暗い茶色になるため採らない。

## R3: 適用範囲
- **Decision**: `contentTintColor` に固定色を指定。`..`・メディアは変更なし、ツリーは変更なし。
- **Rationale**: Issue の対象どおり。検索結果は同じビュー（A-157）。
