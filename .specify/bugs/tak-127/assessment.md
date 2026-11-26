# Bug Assessment: リスト形式の行頭の縮小画像が縦横比を保たずに正方形へ引き伸ばされる

- **Slug**: tak-127
- **Created**: 2026-11-26
- **Source**: Linear [TAK-127](https://linear.app/takyoshida/issue/TAK-127)（Linear の MCP の `get_issue` で取得。コメントはなし）
- **Verdict**: valid
- **Severity**: low

## Report (verbatim or summarized)

TAK-127「リスト形式の行頭の縮小画像が縦横比を保たずに正方形へ引き伸ばされる」（ラベル: Bug、状態: Backlog、作成 2026-11-25）の要約:

- 症状: リスト形式で、各行の先頭の縮小画像（画像の内容・動画の代表フレーム）が、元の縦横比を保たずに 16×16 の正方形に引き伸ばされる。保守者が GUI で歪みを確認した（2026-11-25）。
- 再現: 横長または縦長の画像・動画を含むフォルダを開き、リスト形式にして行頭の縮小画像を見る。歪みが出る条件の詳細（画面、macOS の版、縦横比）は未確認。
- 期待: 縦横比を保ったまま 16pt の枠の中に収まる（サムネイル形式と同じ）。
- 調査メモ: 原因の候補は `ListModeView.swift` の `NSImage(cgImage: image, size: NSSize(width: 16, height: 16))`。関連: TAK-106（リスト形式の行頭にも動画のバッジを重ねる。バッジは描かれた代表フレームの右下に置くので、この修正でバッジの位置の基準も変わる）。

## Symptom

リスト形式の行頭の縮小画像が、生成された画像の縦横比（例: 16:9 の動画なら 64×36 px）に関係なく 16×16pt の正方形に描かれ、横長・縦長の画像が歪む。期待する動作は、縦横比を保ったまま 16×16pt の枠に収め、余る方向は中央に寄せること。

## 仕様との照合

- 該当: [FR-048](specs/product/file-list.md#L71)（リスト形式の行頭の縮小画像。「画像は内容を、動画は代表フレームを縮小したものを使う」）、[FR-418](specs/product/file-list.md#L413)（行頭の縮小画像の右下に、その大きさに合わせてバッジを重ねる）、[EC-286](specs/product/file-list.md#L1033)・[SC-239](specs/product/file-list.md#L1137)（縦横比が極端な代表フレームでもバッジをその内側に収める）
- 判定: **実装が仕様に反している**（fix へ進む）
- 根拠: FR-048 は縦横比を明記していないが、「縮小したもの」は形を変えない縮小と読むのが自然で、サムネイル形式（[FR-013](specs/product/file-list.md#L53)）の実装も縦横比を保っている。また EC-286・SC-239 は代表フレームが縦横比を持つことを前提にしており、正方形に引き伸ばす描き方はこれらの前提と合わない。
- 保守者に確認したい点: FR-048 に「縦横比を保つ」と明記するかどうか。明記するなら、この修正とは別の仕様の変更（sdd-increment、`clarify_mode=skip`）で扱う。明記しなくても、この修正は進められる。

## Reproduction

1. 横長（例: 16:9）または縦長の画像・動画を含むフォルダを開く
2. 表示形式をリスト形式にする
3. 縮小画像の生成が終わった後の行頭のアイコンを見る → 正方形に引き伸ばされている

[NEEDS CLARIFICATION: 保守者が GUI で確認した際のファイルの縦横比と画面の倍率。ただし、以下のとおりコード上は 1:1 以外のすべての縦横比で再現するはずで、画面の倍率には依存しない]

## Suspected Code Paths

- `Sources/FolzioApp/FileList/ListModeView.swift:892` — 生成された `CGImage` を `NSImage(cgImage: image, size: NSSize(width: 16, height: 16))` にしている。`NSImage` の大きさ（point）を縦横比に関係なく 16×16 に固定するため、縦横比が描画の前に失われる。
- `Sources/FolzioApp/FileList/ListModeView.swift:70` — `iconView.imageScaling = .scaleProportionallyDown`。縦横比を保つ指定だが、`NSImage` の大きさがすでに 16×16 なので、16×16 の枠にそのまま 16×16 として描かれる。
- `Sources/FolzioCore/Imaging/ThumbnailProvider.swift:17`・`:207`・`:225` — 縮小画像の生成は `kCGImageSourceThumbnailMaxPixelSize` または `AVAssetImageGenerator.maximumSize` に正方形の上限（16pt × 2 倍 → 段階 64px）を渡しており、長い辺を上限に合わせて縦横比を保つ。生成側に問題はない。
- `Sources/FolzioApp/FileList/ThumbnailModeView.swift:293` — 比較対象。サムネイル形式は `NSImage(cgImage:size:)` に `image.width`×`image.height` を渡しており、縦横比が保たれる。
- `Sources/FolzioApp/FileList/VideoBadgeImageView.swift:58` — バッジの位置は `image.size` から `VideoBadgeLayout.imageRect` で求める。今は `image.size` が 16×16 なので、バッジは 16pt の枠の右下に置かれる。修正後は描かれた代表フレームの右下に移る。

## Root Cause Hypothesis

縮小画像の生成（`ThumbnailProvider`）は縦横比を保った `CGImage`（例: 64×36 px）を返すが、リスト形式のセルがそれを大きさ 16×16pt の `NSImage` に包むため、画像は描画の時点で正方形に引き伸ばされる。`imageScaling` は `NSImage` の大きさの縦横比に従うので、`.scaleProportionallyDown` でも歪みを防げない。サムネイル形式は画素の大きさを `NSImage` の大きさにしているので歪まない。Confidence: **high**（コードの読解による。実行時の確認は fix の回帰テストと GUI の確認で行う）。

## Proposed Remediation

**Preferred**: `NSImage` の大きさを、生成された画像の縦横比を保ったまま 16×16pt の枠に収まる大きさにする。縦横比の計算は AppKit に依存しない純粋な関数なので `FolzioCore` に置く。既存の `FitCalculator.fit(imageSize:in:)`（`Sources/FolzioCore/Layout/FitCalculator.swift`）で、画素の大きさを 16×16 に収めた矩形の `size` が求められるので、新しい関数を足すか、`FitCalculator` をそのまま呼ぶ。`ListModeView` では `NSImage(cgImage: image, size: <その大きさ>)` とする。`imageScaling = .scaleProportionallyDown` と組み合わせると、16pt 以下の画像は拡大されずにその大きさで中央に描かれる。`VideoBadgeImageView` は `image.size` からバッジの位置を求めるので、追加の変更なしに描かれた代表フレームの右下へバッジが移る。

**Alternatives**:
- サムネイル形式と同じく画素の大きさ（例: 64×36）を `NSImage` の大きさにして、`.scaleProportionallyDown` に縮小を任せる。変更は 1 行で済み、2 つの形式の書き方がそろう。ただし `NSImage` の point の大きさが実際の表示より大きくなり、表示の大きさが `imageScaling` に依存する。バッジの計算（`VideoBadgeLayout.imageRect` の `allowsUpscaling: false`）でも結果は同じになる。
- 画像を 16×16 の透明な正方形のキャンバスに縦横比を保って描き直す。描画のたびに画像を作るので、上の 2 案より処理が重く、利点がない。

**Files likely to change**:
- `Sources/FolzioApp/FileList/ListModeView.swift`
- `Sources/FolzioCore/Layout/FitCalculator.swift`（大きさだけを返す関数を足す場合）
- `Tests/FolzioCoreTests/`（縦横比を保った大きさの計算のテスト）
- `Tests/FolzioAppTests/`（リスト形式のセルに設定される画像の大きさのテスト）

**Tests to add or update**:
- Core: 64×36・36×64・64×64・極端な縦横比（例: 16×64）の画素の大きさから、16×16 の枠に収まる大きさ（16×9、9×16、16×16、4×16）が求まること
- App: 縦横比が 1:1 でない `CGImage` を返す偽の `ThumbnailProviding` を `ListModeView` に渡し、行頭のセルの `iconView.image?.size` の縦横比が元の画像と一致し、長い辺が 16pt であること（`Tests/FolzioAppTests/ExternalImageDragTests.swift` に `ListModeView(model:provider:)` を作る例がある）
- App（任意）: 横長の動画の代表フレームで、バッジの外形が描かれた代表フレームの内側に収まること（[SC-239](specs/product/file-list.md#L1137) のリスト形式版）

## Risks & Considerations

- バッジの大きさと位置が変わる: `VideoBadgeLayout.listIcon` は長い辺の 0.5 倍（上限 8pt）と短い辺の 0.5 倍の小さいほうなので、16:9 の代表フレーム（16×9pt）ではバッジの直径が 8pt から 4.5pt に縮み、描かれたフレームの右下（枠の下端から 3.5pt 上）に移る。これは [EC-286](specs/product/file-list.md#L1033) と FR-418 の意図どおりだが、保守者の GUI の確認で、バッジが小さすぎないかを見てもらう。
- 汎用アイコン（生成中・生成失敗）は `IconCatalog` のアイコンをそのまま使うので変わらない。
- 縮小画像のキャッシュのキーやメモリ量は変わらない（`NSImage` の point の大きさだけを変える）。
- 性能の影響は無視できる（大きさの計算だけ）。

## Open Questions

- [NEEDS CLARIFICATION: FR-048 に「縦横比を保つ」と明記する仕様の変更を、別に行うか]
- [NEEDS CLARIFICATION: 横長の動画でバッジが 4.5pt 程度に縮むことを許容するか。許容しない場合は `VideoBadgeLayout.listIcon` の調整が要り、FR-418・EC-286 の範囲の仕様の判断になる]
