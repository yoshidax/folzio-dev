# Data Model: TAK-106

保存するデータは増えない（設定のキーも増やさない）。表示のための値だけを扱う。

## VideoBadgeLayout.Metrics（Core。値型）

| フィールド | 意味 | `thumbnail` | `listIcon` |
|---|---|---|---|
| `diameterRatio` | 長い辺に対する直径の比率 | 0.2 | 0.5 |
| `minDiameter` | 直径の下限（pt） | 10 | 0 |
| `maxDiameter` | 直径の上限（pt） | 40 | 8 |
| `marginRatio` | 長い辺に対する余白の比率 | 0.04 | 0 |
| `minMargin` | 余白の下限（pt） | 2 | 0 |
| `maxMargin` | 余白の上限（pt） | 8 | 0 |

**規則**（`r` は描かれた代表フレームの矩形、`L`・`S` はその長い辺・短い辺）

- 直径 `d = min(clamp(L × diameterRatio, minDiameter, maxDiameter), S × 0.5)`（FR-416・EC-286。短い辺の制限が下限より優先）
- 余白 `m = min(clamp(L × marginRatio, minMargin, maxMargin), S × 0.25)`
- frame（非 flipped の座標）: `x = r.maxX − m − d`、`y = r.minY + m`、幅と高さ `d`（FR-415）
- `r` の幅か高さが 0 以下、または有限でないときは frame を返さない（バッジを表示しない）
- 結果の frame は常に `r` の内側に収まる（`m + d ≤ 0.75 × S`）

## バッジの有無（Core）

`isShown(kind:showingRepresentativeFrame:)` は、次をすべて満たすときだけ真（FR-415・FR-417・FR-418）。

- `kind` が `.media` で、その `MediaKind` が動画（`mp4`・`mov`。A-252）
- 表示中の画像が縮小画像の生成結果である

## 画像ビューの状態（App）

| 状態 | 設定する箇所 | バッジ |
|---|---|---|
| 画像なし | 初期、再利用（`prepareForReuse`） | 表示しない |
| 汎用アイコン | サムネイル形式の `configure`、リスト形式の `fallbackIcon` | 表示しない |
| 種類のアイコン（フォルダ・zip・`..`） | `showListItemIcon`、リスト形式の非メディア行 | 表示しない |
| 縮小画像の生成結果 | `setThumbnailImage`、リスト形式の生成の Task | 動画だけ表示する |

**状態の遷移**

- 画像なし → 汎用アイコン（項目の表示）→ 生成結果（生成の完了）
- 生成に失敗したら汎用アイコンのまま（EC-289）
- 内容の置き換え（FR-228）では、新しい生成結果が届くまで古い生成結果のまま（EC-287）
- 別の項目に再利用されたら画像なしに戻る

## 読み上げのラベル（App）

| 項目 | サムネイル形式の画像ビューのラベル |
|---|---|
| 動画 | `a11y.videoThumbnail`（動画のサムネイル / Video thumbnail） |
| それ以外 | `a11y.thumbnail`（サムネイル / Thumbnail。従来どおり） |
