# Bug Fix: リスト形式の行頭の縮小画像が縦横比を保たずに正方形へ引き伸ばされる

- **Slug**: tak-127
- **Fixed**: 2026-11-26
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

リスト形式の行頭の縮小画像を、大きさ 16×16pt に固定した `NSImage` ではなく、生成された画像の縦横比を保ったまま 16pt の枠に収まる大きさの `NSImage` にした（[FR-048](../../../specs/product/file-list.md#L71)）。`VideoBadgeImageView` は `image.size` からバッジの位置を求めるので、動画のバッジは描かれた代表フレームの右下に移る（[FR-418](../../../specs/product/file-list.md#L413)）。

## Changes

| File | Change | Notes |
|------|--------|-------|
| `Sources/FolzioApp/FileList/ListModeView.swift` | modified | `ListModeView.listIconImage(from:pointSize:)` を足し、縮小画像の生成の Task から呼ぶ。大きさは `FitCalculator.fit` で求める |
| `Tests/FolzioAppTests/ListIconImageTests.swift` | added test | 行頭のアイコンの大きさと、16:9 のフレームでのバッジの位置 |
| `Tests/FolzioCoreTests/FitCalculatorTests.swift` | added test | 16pt の枠に収める大きさの代表値 |

## Diff Highlights (optional)

```swift
static func listIconImage(from image: CGImage, pointSize: Double) -> NSImage {
    let square = CGSize(width: pointSize, height: pointSize)
    let fitted = FitCalculator.fit(imageSize: CGSize(width: image.width, height: image.height), in: square)
    return NSImage(cgImage: image, size: fitted.isEmpty ? square : fitted.size)
}
```

## Tests Added or Updated

- `Tests/FolzioAppTests/ListIconImageTests.swift::keepsAspectRatio` — 64×36・36×64・64×64・16×64・8×4 px の画像が、16×9・9×16・16×16・4×16・16×8pt のアイコンになる。修正前の描き方（16×16 に固定）では 1:1 以外の 4 件が失敗することを確かめた
- `Tests/FolzioAppTests/ListIconImageTests.swift::badgeStaysInsideWideFrame` — 行頭のアイコンと同じ設定の `VideoBadgeImageView` で、16:9 の代表フレームのバッジが描かれたフレーム（y = 3.5〜12.5pt）の内側に収まる（[EC-286](../../../specs/product/file-list.md#L1033)）。修正前は失敗することを確かめた
- `Tests/FolzioCoreTests/FitCalculatorTests.swift::fitsListIcon` — 16pt の枠に収める大きさの代表値
- `Tests/FolzioAppTests/ListIconImageTests.swift::rowIconKeepsAspectRatio` — PR のレビュー（2026-11-26）を受けて足した。64×36 px を返す偽の `ThumbnailProviding` で `ListModeView` の行を作り、行頭のセルの画像が 16×9pt になることを確かめる。セルの Task の呼び出しを 16×16 に固定する書き方に戻すと失敗することを確かめた

## Local Verification

- Commands run:
  - `swift test --filter "ListIconImageTests|FitCalculatorTests"`（修正前の描き方のまま）→ `ListIconImageTests` が 5 件の issue で失敗（回帰テストが不具合を捉えることを確認）
  - `swift test --filter "ListIconImageTests|FitCalculatorTests|VideoBadge"`（修正後）→ 33 件すべて成功
  - `swift build` → 成功
  - `swift test` → 通常のテスト 1189 件（130 suites）は成功。性能テストの `PerformanceBaseline` で「Decodes a 24 MP JPEG within 0.5 seconds」が 0.610 秒で 1 件失敗
  - `swift test --filter PerformanceBaseline`（単独で再実行）→ 27 件すべて成功。今回の変更はデコードに触れないので、全テストを並列で走らせたときの負荷による揺れと判断した
  - `scripts/dev/check-all.sh` → all checks passed
- Manual checks: fix の時点では未実施。bug-test で保守者が起動スモークと GUI での確認を行った（./test.md）

## Deviations from Assessment

- Core に新しい関数を足さなかった。既存の `FitCalculator.fit(imageSize:in:)` の結果の `size` で足りるため、App 側の補助関数から直接呼んだ。Core には代表値のテストだけを足した。
- App のテストは、まず画像をアイコンにする部分を `ListModeView.listIconImage(from:pointSize:)` として切り出して試した。PR のレビューで、セルの Task の呼び出しを通るテストがないと指摘されたため、表の行を作って行頭のセルの画像を確かめるテスト（`rowIconKeepsAspectRatio`）も足した。
- 16pt より小さい画像（例: 8×4 px）は、修正前と同じく 16pt の枠まで拡大する（長い辺を 16pt にする）。サムネイル形式は小さい画像を拡大しないが、行頭のアイコンは大きさをそろえる。

## Follow-ups

- GUI での確認（保守者）: 横長・縦長の画像と動画を含むフォルダをリスト形式で開き、行頭の縮小画像が歪まず中央に描かれること、横長の動画のバッジが描かれたフレームの右下に収まり、小さすぎないこと
- FR-048 に「縦横比を保つ」と明記するかは、保守者の判断を待つ（assessment の Open Questions）
