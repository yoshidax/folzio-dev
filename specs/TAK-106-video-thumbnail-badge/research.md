# Research: TAK-106 動画のサムネイルのバッジ

調査の基準: 作業ブランチ（`origin/master` 63f5523 を含む）。

## R1 バッジの置き方（子ビューか、縮小画像への合成か）

- **Decision**: `NSImageView` のサブクラスに子ビュー（バッジ）を持たせ、`layout()` で frame を決める
- **Rationale**:
  - 縮小画像（`CGImage`）にバッジを合成すると、`ThumbnailProvider` が保持する縮小画像が動画用に変わるか、表示のたびに
    合成の処理が要る（FR-421）。子ビューなら縮小画像に手を加えない
  - サムネイル形式（`ThumbnailItemView.thumbnailImageView`）とリスト形式（`FileListIconCell.iconView`）で同じビューを使える。
    大きさの変更は `layout()` に追従する（FR-416）
  - frame を直接決めるため Auto Layout の制約を足さない（AGENTS.md の AppKit UI の不変条件に触れない）
- **Alternatives considered**:
  - `CALayer` の sublayer: 外観の変更への追従と、テストでの検査が子ビューより手間がかかる
  - 項目のビュー（`cellView`）に兄弟ビューとして置く: 画像ビューの中の描かれた矩形を外から求める必要があり、
    リスト形式と共通にしにくい

## R2 描かれた代表フレームの矩形の求め方

- **Decision**: 既存の `FitCalculator.fit(imageSize:in:)`（`Sources/FolzioCore/Layout/FitCalculator.swift`）に、画像ビューの
  `bounds.size` と `image.size` を渡す
- **Rationale**:
  - サムネイル形式の画像ビューは `scaleProportionallyUpOrDown`・中央揃えで、`fit` と同じ規則で描く
    （`ThumbnailModeView.swift` の `loadView`）
  - リスト形式は `scaleProportionallyDown` で、縮小画像を 16×16 の `NSImage` として設定している（`ListModeView.swift` の
    生成の Task）。描かれる矩形は 16×16 の全体になる
  - この描き方で縦横比が崩れる不具合は、保守者が GUI で確かめ、[TAK-127](https://linear.app/takyoshida/issue/TAK-127)
    として別に扱う（2026-11-25）
- **Alternatives considered**: `NSImageCell` の描画矩形を返す公開 API はない（`imageRect(forBounds:)` は縮小の規則を反映しない）

## R3 大きさの定数（A-253・SC-240）

- **Decision**: サムネイル形式は直径を長い辺の 0.2 倍とし、10〜40pt に丸め、短い辺の半分以下にする。リスト形式は
  長い辺の 0.5 倍で 8pt 以下
- **Rationale**:
  - サムネイル形式の画像ビューの辺は、項目の幅（`ThumbnailGridLayout.columns` の `cellWidth`。サムネイルの大きさ以下）から
    8pt（左右の余白 4pt）を引いた長さ。48pt で 40pt、128pt で 120pt、512pt で 504pt
  - 10pt は、再生の記号（直径の 0.45 倍、約 4.5pt）を見分けられる下限として選んだ。40pt は、512pt でも代表フレームの
    右下の小さな範囲（辺の 8%）だけを覆う上限
  - 短い辺の半分の制限で、極端な縦横比でも代表フレームの内側に収まり、円の面積は `π/16 × S²` ≒ `0.196 × S × L` 以下になる
    （SC-239・EC-286）
  - 1:2〜2:1 では、画像ビューの辺が 40pt 以上なら短い辺が 20pt 以上で、直径は下限の 10pt 以上になる（SC-240）。
    ペインが 1 項目の幅より狭いときは画像ビューも小さくなり、バッジも比例して小さくなるが、はみ出さない
- **Alternatives considered**: 小さいサイズで中央に大きく重ねる案は、保守者が採らなかった（spec の Input）

## R4 「代表フレームを表示中か」の判定

- **Decision**: 画像を設定する箇所で App が状態を切り替える。判定の規則は Core の関数に置く
- **Rationale**:
  - 汎用アイコンと生成結果は、設定する関数が分かれている
    - サムネイル形式: `configure` が `NSWorkspace.shared.icon(forFile:)` を設定し、`setThumbnailImage` が生成結果を設定する
    - リスト形式: `IconCatalog.fallbackIcon` を設定し、生成の Task が結果を設定する
  - 生成に失敗すると `apply` は何もしない（`guard let image`）ので、汎用アイコンのまま残る（EC-289）
  - 内容の置き換え（FR-228）は新しい画像が届くまで古い画像を残す（`refreshReplacedThumbnails`）。状態を変えないので
    バッジも残る（EC-287）
- **Alternatives considered**: `NSImage` が `NSWorkspace` のアイコンかを調べる案は、AppKit の内部の表現に依存する

## R5 操作と読み上げへの影響（EC-290・FR-420）

- **Decision**: バッジのビューは `hitTest(_:)` で `nil` を返し、アクセシビリティの要素にしない。動画の読み上げは、既存の
  画像ビューのラベルを置き換える
- **Rationale**:
  - クリック・ダブルクリックは `ThumbnailCollectionView` が `indexPathForItem(at:)` で項目を決める。右クリックの対象、
    ドロップ先も座標から決めている。子ビューが `hitTest` に現れなければ、どれも変わらない
  - Quick Look の起点は `quickLookSourceView`（画像ビュー）の `bounds` で、子ビューを足しても変わらない
  - 画像ビューのラベル（`a11y.thumbnail`）を動画で `a11y.videoThumbnail` に替えるだけなので、要素の数と順序が変わらない。
    リスト形式の行頭の画像はもともと要素でない（`setAccessibilityElement(false)`。A-255）

## R6 Quick Look の縮小画像に動画の装飾が入っている可能性

- **Decision**: 対処しない。GUI 確認で、バッジと二重に見えないかを確かめる
- **Rationale**: `QLThumbnailGenerator` の `.thumbnail` は動画で代表フレームを返す。macOS の版によって枠などの装飾が付くかは、
  Cloud では確かめられない。zip の中の動画は `AVAssetImageGenerator` の最初のフレームで、装飾は付かない
