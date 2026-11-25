# Implementation Plan: 動画のサムネイルに動画を示すバッジを重ねる

**Branch**: `claude/awesome-franklin-05nex3` | **Date**: 2026-11-21 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/TAK-106-video-thumbnail-badge/spec.md`（[TAK-106](https://linear.app/takyoshida/issue/TAK-106)）

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

動画の代表フレームの上に、半透明の円と再生の記号からなるバッジを重ねる（FR-415〜421）。バッジの有無（項目が動画で、表示中の
画像が縮小画像の生成結果か）と、描かれた代表フレームの矩形から決める位置・大きさは、Core の純粋な関数（`VideoBadgeLayout`）に
置いて Swift Testing で検証する。App では、サムネイル形式の `ThumbnailItemView` とリスト形式の `FileListIconCell` の画像ビューを、
バッジを子ビューに持つ `NSImageView` のサブクラス（`VideoBadgeImageView`）に置き換え、`layout()` で子ビューの frame を Core の
関数から決める（research.md R1・R2）。サムネイル形式の動画の画像には、アクセシビリティのラベル「動画のサムネイル」を付ける
（文言のキー `a11y.videoThumbnail`）。

本資料は設計レビュー用。承認の前に実装しない。

## Technical Context

**Language/Version**: Swift 6（CI は Xcode 16.0 / Swift 6.0）

**Primary Dependencies**: Foundation・CoreGraphics（Core）、AppKit（App）。外部依存なし

**Storage**: N/A（保存するデータ・設定のキーは増やさない）

**Testing**: Swift Testing（`FolzioCoreTests`、`FolzioAppTests`）。見え方と VoiceOver は quickstart.md で保守者が GUI 確認

**Target Platform**: macOS 15 以降。Cloud では Swift も GUI も実行しないので、ビルド・テストは macOS の CI で確認する

**Project Type**: desktop-app（Swift Package。`FolzioCore`・`FolzioLocalization`・`FolzioApp`）

**Performance Goals**: 既存の基準値（憲章の原則 II）を変えない。バッジは表示中の項目にだけ、図形と記号を描く

**Constraints**:

- Core は AppKit を import しない。判断ロジックは Core、描画は App に置く（AGENTS.md）
- UI スレッドでデコード・ファイルの読み込みをしない（FR-421）。ネットワーク API を使わない
- AppKit UI の不変条件: 制約は `addSubview` の後に有効化し、異なる view hierarchy のアンカーを制約しない。
  バッジは制約を使わず `layout()` で frame を決める
- ソースのコメントは英語（公開用リポジトリへ書き出される）

**Scale/Scope**: Core に 1 ファイル（関数 2 つと定数 2 組）、App に 1 ファイル（画像ビューのサブクラスとバッジのビュー）、
描画側 2 か所の置き換え、文言のキー 1 つ、テスト 3 ファイル

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判断 |
|---|---|
| I ローカル完結 | PASS。通信なし。ユーザーのファイルを変更しない |
| II 体感パフォーマンス | PASS。追加のデコード・ファイルの読み込みなし（FR-421）。CI の性能テストの結果を PR に記載する |
| III キーボード・アクセシビリティ | PASS。操作は変えない（EC-290）。動画の画像に識別できるラベルを付ける（FR-419）。外観モードで判別できる配色にする（EC-288） |
| IV テスト必須 | PASS。判定と位置・大きさは Core、画像ビューと読み上げは App のテスト、文言は既存のカタログの検査 |
| V シンプルさ | PASS。設定項目を足さない。規則は 1 か所、描画は 1 つのビューを 2 か所で使う |

**設計後の再確認（Phase 1 の後）**: 変更なし。すべて PASS。

## 設計

### バッジの見た目（A-253 の確定案）

- 図柄: 円の上に SF Symbols の `play.fill`（白）。記号の大きさは直径の 0.45 倍、視覚的な中心に合わせて右へ直径の 0.04 倍ずらす
- 円: 黒の不透明度 0.45 で塗り、白の不透明度 0.7 の線（幅は直径の 0.06 倍、最小 0.75pt）で縁取る
  - 暗い代表フレームの上では縁取りで、明るい代表フレームの上では黒の塗りで判別できるようにする（EC-288）
  - 外観モード（ライト／ダーク）・アクセントカラー・選択の状態では変えない
- 値は案。保守者がこの案で始めることを了承した（2026-11-25）。GUI 確認（quickstart.md の 5）で最終の承認を得る。
  調整は定数の変更だけで済む

### 位置と大きさ（FR-415・FR-416・EC-286）

式と定数は [data-model.md](data-model.md)。代表的な値:

| サムネイルの大きさ | 画像ビューの辺 | 16:9 の直径 | 1:4 の直径 |
|---|---|---|---|
| 48pt | 40pt | 10pt | 5pt（短い辺の半分） |
| 128pt | 120pt | 24pt | 15pt |
| 512pt | 504pt | 40pt（上限） | 40pt |

- リスト形式（16×16）: 直径 8pt、余白 0
- SC-239（面積 20% 以下）は短い辺の半分の制限で、SC-240（1:2〜2:1 で 10〜40pt）は画像ビューの辺が 40pt 以上のときに満たす
  （research.md R3）

### 構成

- Core: `Sources/FolzioCore/Layout/VideoBadgeLayout.swift`
  - `VideoBadgeLayout.Metrics`（`Sendable`・`Equatable`）と定数 `thumbnail`・`listIcon`
  - `imageRect(imageSize:in:allowsUpscaling:) -> CGRect`（`allowsUpscaling` が `false` なら拡大率を 1 以下に抑える）
  - `badgeFrame(imageRect:metrics:flipped:) -> CGRect?`（`flipped` が `true` なら右下を `r.maxY` 側に置く）
  - `isShown(kind:showingRepresentativeFrame:) -> Bool`
- App: `Sources/FolzioApp/FileList/VideoBadgeImageView.swift`
  - `VideoBadgeImageView: NSImageView`。`showsVideoBadge`・`badgeMetrics` を持ち、`image` か `showsVideoBadge` が変わったら
    `needsLayout = true`。`setFrameSize(_:)` でも大きさが変われば `needsLayout = true` にする。`layout()` で `VideoBadgeLayout.imageRect`（`imageScaling` が `scaleProportionallyDown` なら `allowsUpscaling: false`）と
    `VideoBadgeLayout.badgeFrame`（`flipped: isFlipped`）から求め、`backingAlignedRect(_:options:)` で画素に揃えて子ビューの frame を
    決め、表示しないときは `isHidden = true`
  - 子ビュー `VideoBadgeView: NSView`。`draw(_:)` で円と記号を描く。`hitTest(_:)` は `nil`、アクセシビリティの要素にしない、
    ドラッグの型を登録しない（EC-290・FR-420、research.md R5）
- `ThumbnailItemView`（`ThumbnailModeView.swift`）
  - `thumbnailImageView` を `VideoBadgeImageView`（`badgeMetrics = .thumbnail`）に替え、表示中の項目の種類を保持する
  - `configure` の汎用アイコン・`showListItemIcon`・`prepareForReuse` で `showsVideoBadge = false`、`setThumbnailImage` で
    `isShown(kind:showingRepresentativeFrame: true)` を設定する（research.md R4）
  - 画像ビューのラベルを、動画なら `a11yVideoThumbnail`、それ以外は `a11yThumbnail` にする。`displayLanguageDidChange` でも
    同じ判定で更新する（FR-419）
  - 既存の `unregisterDraggedTypes()`（FR-163 の不具合の対処）は保つ
  - テスト用に、バッジの表示状態を読む内部（`internal`）の読み取り専用プロパティを足す（T005・T008。外から変更できない）
- `FileListIconCell`（`ListModeView.swift`）: `iconView` を `VideoBadgeImageView`（`badgeMetrics = .listIcon`）に替える。
  非メディア行と `fallbackIcon` で `false`、生成結果の設定で `isShown(...: true)`。`setAccessibilityElement(false)` を保つ（A-255）
  - `FileListIconCell` は `private` のため、組み込みの自動テストは書かず、GUI 確認（quickstart.md の 8）で確かめる
- 文言: `TextKey.a11yVideoThumbnail = "a11y.videoThumbnail"`（日本語「動画のサムネイル」、英語「Video thumbnail」）

### 公開文書（使い方）

- `docs/usage.md` と `docs/usage.ja.md` の「View Modes and Columns」「表示形式と列」の節に、動画のサムネイルと
  リスト形式の行頭に再生のバッジが付くことを 1 文ずつ、同じコミットで足す（保守者の決定。2026-11-25）
- 文書は公開用リポジトリへ書き出されるため、`specs/` などの開発用の文書へリンクしない（AGENTS.md）

### 変えないもの

- 縮小画像の生成・保持（`ThumbnailProvider`）、項目の大きさと配置、選択・強調の見た目、Quick Look の起点の矩形
- プレビュー・フルスクリーン・スライドショー・ツリー（A-256）
- リスト形式の行頭の縮小画像の描き方（16×16 の `NSImage` として設定する既存の扱い）。縦横比を保たずに正方形へ引き伸ばされる不具合は
  [TAK-127](https://linear.app/takyoshida/issue/TAK-127) で扱う。この feature のバッジは、今の描き方で描かれる 16×16 の右下に置く。
  TAK-127 の修正後にリスト形式のバッジが小さくなりすぎる影響は research.md R7

## 検証

- CI: `swift build`、`swift test`（Core の規則、App の画像ビューと読み上げ、既存の `CatalogConsistencyTests`）と性能テスト
- Cloud: `scripts/dev/check-all.sh`
- 保守者の GUI 確認: [quickstart.md](quickstart.md)

## Project Structure

### Documentation (this feature)

```text
specs/TAK-106-video-thumbnail-badge/
├── spec.md
├── plan.md              # このファイル
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   └── localization.md  # Phase 1（specs/product/contracts/localization.md への追加）
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks が作る
```

### Source Code (repository root)

```text
Sources/FolzioCore/Layout/VideoBadgeLayout.swift          # 新規。表示の判定と位置・大きさ
Sources/FolzioApp/FileList/VideoBadgeImageView.swift      # 新規。画像ビューのサブクラスとバッジのビュー
Sources/FolzioApp/FileList/ThumbnailModeView.swift        # ThumbnailItemView の画像ビューと読み上げ
Sources/FolzioApp/FileList/ListModeView.swift             # FileListIconCell の画像ビュー
Sources/FolzioLocalization/TextKey.swift                  # a11yVideoThumbnail
Sources/FolzioLocalization/Resources/ja.lproj/Localizable.strings
Sources/FolzioLocalization/Resources/en.lproj/Localizable.strings
docs/usage.md                                             # 使い方に 1 文を追加
docs/usage.ja.md                                          # 同じ内容の日本語

Tests/FolzioCoreTests/VideoBadgeLayoutTests.swift         # 新規
Tests/FolzioAppTests/VideoBadgeImageViewTests.swift       # 新規
Tests/FolzioAppTests/ThumbnailVideoBadgeTests.swift       # 新規
```

**Structure Decision**: 既存の Swift Package の構成（`Sources/FolzioCore`・`Sources/FolzioApp`・`Sources/FolzioLocalization`、
`Tests/FolzioCoreTests`・`Tests/FolzioAppTests`）に従う。規則は既存の `FitCalculator`・`ThumbnailGridLayout` と同じ
`FolzioCore/Layout` に置く。

## Complexity Tracking

憲章への違反はない。
