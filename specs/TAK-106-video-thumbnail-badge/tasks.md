---

description: "Task list for TAK-106 video thumbnail badge"
---

# Tasks: 動画のサムネイルに動画を示すバッジを重ねる

**Input**: Design documents from `specs/TAK-106-video-thumbnail-badge/`

**Prerequisites**: [plan.md](plan.md)、[spec.md](spec.md)、[research.md](research.md)、[data-model.md](data-model.md)、
[contracts/localization.md](contracts/localization.md)、[quickstart.md](quickstart.md)

**Tests**: spec.md の「検証方針」と憲章の原則 IV に従い、Swift Testing のテストを含める。テストを先に書き、実装の前に失敗することを
CI で確かめる（Cloud では Swift を実行できない）。

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.
Cloud ではサブエージェントで実装を分けず、同じセッションで順に行う。`[P]` は別ファイルで依存がないことを示す。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- **[MANUAL]**: 保守者が行う確認。報告を受けるまでチェックしない

## Path Conventions

- Swift Package: `Sources/FolzioCore/`、`Sources/FolzioApp/`、`Sources/FolzioLocalization/`、`Tests/FolzioCoreTests/`、`Tests/FolzioAppTests/`
- ソースのコメントは英語（公開用リポジトリへ書き出される）

## Phase 1: Setup (Shared Infrastructure)

既存のパッケージ構成と依存をそのまま使うため、タスクはない。

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: バッジの規則（Core）と、バッジを描く共通の画像ビュー（App）。すべてのストーリーが使う

### Tests for Foundational

- [ ] T001 [P] `Tests/FolzioCoreTests/VideoBadgeLayoutTests.swift` を追加し、Swift Testing で `VideoBadgeLayout` を検証する。data-model.md の式「直径 `d = min(clamp(L × diameterRatio, minDiameter, maxDiameter), S × 0.5)`」「余白 `m = min(clamp(L × marginRatio, minMargin, maxMargin), S × 0.25)`」「frame: `x = r.maxX − m − d`、`y = flipped ? r.maxY − m − d : r.minY + m`、幅と高さ `d`」を、`flipped` の両方の値と、画像ビューの辺 40・120・504pt と縦横比 16:9・9:16・1:1・1:4 の組み合わせで確かめる。あわせて、frame が常に `r` の内側にあること、円の面積（`π × d² / 4`）が `r` の面積の 20% 以下（SC-239）、1:2〜2:1 で `thumbnail` の直径が 10〜40pt（SC-240）、1:4 で直径が短い辺の半分以下（EC-286）、幅か高さが 0 以下または非有限の矩形で `nil`、`listIcon` の 16×16 で直径 8pt・余白 0 を確かめる。`imageRect(imageSize:in:allowsUpscaling:)` は、`true` で `FitCalculator.fit` と一致し、`false` では枠より小さい画像（例: 16×16 の枠に 12×7）を拡大せず中央に置くことを確かめる。`isShown(kind:showingRepresentativeFrame:)` は、全 `ListItemKind`（`.media` は全 `MediaKind`）と表示中の画像の 2 状態の組み合わせで、`mp4`・`mov` かつ生成結果のときだけ `true` になることを確かめる（FR-415〜418）
- [ ] T002 [P] `Tests/FolzioAppTests/VideoBadgeImageViewTests.swift` を追加し、`VideoBadgeImageView` を検証する。120×120 の画像ビューに 16:9 の画像を設定して `showsVideoBadge = true`・`layoutSubtreeIfNeeded()` の後、バッジの子ビューの frame が、`VideoBadgeLayout.badgeFrame(imageRect: VideoBadgeLayout.imageRect(...), metrics: .thumbnail, flipped: imageView.isFlipped)` を `backingAlignedRect(_:options:)` で揃えた矩形と一致し、子ビューの中心が描かれた矩形の下半分（原点の向きに合わせて判定）にあること。`showsVideoBadge = false` と `image = nil` で子ビューが `isHidden`。子ビューの `hitTest(_:)` が `nil`、`isAccessibilityElement()` が `false`、`registeredDraggedTypes` が空であること（FR-420・EC-290）

### Implementation for Foundational

- [ ] T003 `Sources/FolzioCore/Layout/VideoBadgeLayout.swift` を追加する。`public enum VideoBadgeLayout` に、`Metrics`（`diameterRatio`・`minDiameter`・`maxDiameter`・`marginRatio`・`minMargin`・`maxMargin`。`Sendable`・`Equatable`）、定数 `thumbnail`（0.2・10・40・0.04・2・8）と `listIcon`（0.5・0・8・0・0・0）、`imageRect(imageSize:in:allowsUpscaling:) -> CGRect`、`badgeFrame(imageRect:metrics:flipped:) -> CGRect?`、`isShown(kind:showingRepresentativeFrame:) -> Bool`（`kind.isVideo && showingRepresentativeFrame`）を置く。CoreGraphics だけを import し、AppKit を import しない（data-model.md、FR-416・FR-421）
- [ ] T004 `Sources/FolzioApp/FileList/VideoBadgeImageView.swift` を追加する。`final class VideoBadgeImageView: NSImageView` は `showsVideoBadge: Bool`（既定 `false`）と `badgeMetrics: VideoBadgeLayout.Metrics`（既定 `.thumbnail`）を持ち、`image`・`showsVideoBadge` の変更で `needsLayout = true` にする。`layout()` で `VideoBadgeLayout.imageRect(imageSize: image.size, in: bounds.size, allowsUpscaling: imageScaling != .scaleProportionallyDown)` と `VideoBadgeLayout.badgeFrame(..., flipped: isFlipped)` から frame を求め、`backingAlignedRect(_:options: .alignAllEdgesNearest)` で画素に揃えて子ビューに設定し、表示しないときは `isHidden = true`。子ビュー `final class VideoBadgeView: NSView` は `draw(_:)` で plan.md の「バッジの見た目」（黒 0.45 の円、白 0.7 の縁取り（直径の 0.06 倍、最小 0.75pt）、直径の 0.45 倍の白い `play.fill` を右へ直径の 0.04 倍ずらす）を描き、`hitTest(_:)` で `nil` を返し、`setAccessibilityElement(false)` にする。子ビューは `addSubview` で加え、制約を使わない（AGENTS.md の AppKit UI の不変条件、research.md R1・R5）

**Checkpoint**: 規則と共通の画像ビューができ、T001・T002 が通る

---

## Phase 3: User Story 1 - サムネイル形式で動画を見分ける (Priority: P1) 🎯 MVP

**Goal**: サムネイル形式で、動画の代表フレームの右下にだけバッジを表示する

**Independent Test**: 画像と横長・縦長・正方形の動画を含むフォルダをサムネイル形式で開き、動画だけの右下にバッジが付く

### Tests for User Story 1

- [ ] T005 [P] [US1] `Tests/FolzioAppTests/ThumbnailVideoBadgeTests.swift` を追加する。`ThumbnailItemView()` に動画（`.mp4`）の `MediaFile` を `configure(with:iconPointSize:)` した直後はバッジが非表示、`setThumbnailImage(_:)` の後に表示、画像（`.jpeg`）とフォルダの `MediaFile` では `setThumbnailImage` の後も非表示、`prepareForReuse()` で非表示に戻ること（US95-AS1・AS2・AS4、FR-417）。既存の `ThumbnailRenameTests.swift` の項目の作り方に倣い、バッジの状態を読むための内部の読み取り用プロパティを `ThumbnailItemView` に足してよい

### Implementation for User Story 1

- [ ] T006 [US1] `Sources/FolzioApp/FileList/ThumbnailModeView.swift` の `ThumbnailItemView` の `thumbnailImageView` を `VideoBadgeImageView`（`badgeMetrics = .thumbnail`）に替え、表示中の項目の種類（`ListItemKind`）を保持する。`configure` で汎用アイコンを設定するとき・`showListItemIcon`・`prepareForReuse` で `showsVideoBadge = false`、`setThumbnailImage` で `showsVideoBadge = VideoBadgeLayout.isShown(kind:showingRepresentativeFrame: true)` にする。URL が同じで画像を残す経路（FR-228 の作り直し）では状態を変えない。既存の `unregisterDraggedTypes()` と `quickLookSourceView` は変えない（FR-415・FR-417・EC-287・EC-289、research.md R4）

**Checkpoint**: サムネイル形式の動画だけにバッジが付き、T005 が通る

---

## Phase 4: User Story 2 - サムネイルの大きさを変えても見分けられる (Priority: P1)

**Goal**: サムネイルの大きさ・ペインの幅の変更に、バッジの位置と大きさが追従する

**Independent Test**: サムネイルの大きさを 48pt から 512pt まで動かし、バッジが比例して大きさを変え、右下に収まる

### Tests for User Story 2

- [ ] T007 [US2] `Tests/FolzioAppTests/VideoBadgeImageViewTests.swift` に、画像ビューの大きさを 40→120→504pt と変えるたびに `layoutSubtreeIfNeeded()` の後の子ビューの frame が `VideoBadgeLayout.badgeFrame` と一致すること、9:16 の画像で子ビューの `maxX` が描かれた矩形の `maxX` 以下（左右の余白に出ない）であることを加える（US95-AS3・AS6〜AS8、FR-416）
- [ ] T008 [US2] `Tests/FolzioAppTests/ThumbnailVideoBadgeTests.swift` に、`ThumbnailItemView` の `view` の frame を 48×84 と 512×548 に変えて `layoutSubtreeIfNeeded()` した後、動画のバッジの直径がそれぞれ 10pt と 40pt になることを加える（SC-240）

### Implementation for User Story 2

- [ ] T009 [US2] `Sources/FolzioApp/FileList/VideoBadgeImageView.swift` の `VideoBadgeImageView` で `setFrameSize(_:)` を override し、`super` を呼んだ後に大きさが変わっていれば `needsLayout = true` を立てる。サムネイルの大きさ・ペインの幅の変更（Auto Layout による画像ビューの大きさの変更）のたびに `layout()` が呼ばれ、バッジの frame が計算し直されるようにする（FR-416・US95-AS6）

**Checkpoint**: 大きさの変更に追従し、T007・T008 が通る

---

## Phase 5: User Story 3 - リスト形式と読み上げでも動画が分かる (Priority: P2)

**Goal**: リスト形式の行頭の縮小画像にもバッジを重ね、サムネイル形式の動画を「動画のサムネイル」と読み上げる

**Independent Test**: リスト形式の動画の行頭に小さいバッジが付き、VoiceOver でサムネイル形式の動画を「動画のサムネイル」と読む

### Tests for User Story 3

- [ ] T010 [US3] `Tests/FolzioAppTests/ThumbnailVideoBadgeTests.swift` に、動画の `configure` 後の画像ビューのアクセシビリティのラベルが `l10n.text(.a11yVideoThumbnail)`、画像では `l10n.text(.a11yThumbnail)` であること、生成結果の設定の前後で変わらないことを加える（FR-419・US95-AS10）

### Implementation for User Story 3

- [ ] T011 [P] [US3] `Sources/FolzioLocalization/TextKey.swift` に `case a11yVideoThumbnail = "a11y.videoThumbnail"` と説明（`"Accessibility label for a video thumbnail image"`）を足し、`Sources/FolzioLocalization/Resources/ja.lproj/Localizable.strings` に `"a11y.videoThumbnail" = "動画のサムネイル";`、`Sources/FolzioLocalization/Resources/en.lproj/Localizable.strings` に `"a11y.videoThumbnail" = "Video thumbnail";` を足す（contracts/localization.md）
- [ ] T012 [US3] `Sources/FolzioApp/FileList/ThumbnailModeView.swift` の `ThumbnailItemView` で、画像ビューのラベルを、保持した種類が動画なら `.a11yVideoThumbnail`、それ以外は `.a11yThumbnail` にする。`loadView`・`configure`・`prepareForReuse`・`displayLanguageDidChange` で同じ判定を使う（FR-419・US95-AS11）
- [ ] T013 [US3] `Sources/FolzioApp/FileList/ListModeView.swift` の `FileListIconCell.iconView` を `VideoBadgeImageView`（`badgeMetrics = .listIcon`）に替える。非メディア行と `IconCatalog.fallbackIcon` の設定で `showsVideoBadge = false`、生成の Task で縮小画像を設定するときに `showsVideoBadge = VideoBadgeLayout.isShown(kind: file.kind, showingRepresentativeFrame: true)` にする。`setAccessibilityElement(false)` と `imageScaling = .scaleProportionallyDown` を保つ（FR-418・A-255）。`FileListIconCell` は `private` のため、組み込みの自動テストは書かない。共通の画像ビューの振る舞いは T002・T007 で、組み込みの見え方は T018 [MANUAL]（quickstart.md の 8）で確かめる

**Checkpoint**: リスト形式のバッジと読み上げができ、T010 と既存の `CatalogConsistencyTests` が通る

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 影響範囲の確認、検査、PR、保守者の確認、製品仕様への反映

- [ ] T014 差分を読み、`Sources/FolzioCore/Imaging/ThumbnailProvider.swift`・プレビュー・フルスクリーン・スライドショー・ツリー（`Sources/FolzioApp/Tree/`）と、`Sources/FolzioApp/FileList/QuickLookCoordinator.swift` の起点の矩形の計算が変わっていないことを確かめる（FR-421・A-256）
- [ ] T015 [P] `docs/usage.md` の「View Modes and Columns」と `docs/usage.ja.md` の「表示形式と列」に、動画のサムネイルとリスト形式の行頭に再生のバッジが付くことを 1 文ずつ、同じコミットで足す。2 つの文書は同じ内容にし、`specs/` などの開発用の文書へリンクしない（保守者の決定（2026-11-25）、AGENTS.md の「書くときの規則」）
- [ ] T016 `scripts/dev/check-all.sh` を実行して通し、作業ブランチにコミットして push し、Draft の PR を `.github/pull_request_template.md` の見出しで作る（`docs_private/agents/delegation.md` の条件）。Linear の TAK-106 に PR のリンクを付ける
- [ ] T017 CI（`.github/workflows/macos-swift-ci.yml`）の `swift build`・`swift test` の成功と、性能テストのログの末尾（`passed` か `failed`）を確かめて PR の本文に記載する（憲章の原則 II）
- [ ] T018 [MANUAL] 保守者が `specs/TAK-106-video-thumbnail-badge/quickstart.md` の「保守者の GUI 確認」の 1〜11 を行う。自動テストで確かめられない SC-238・SC-241・SC-242・EC-288・US95-AS5・US95-AS9（FR-418）・A-256 を、この確認で確かめる。結果（実行日、OS、確認項目、合否）を `specs/TAK-106-video-thumbnail-badge/checklists/validation.md` に記録する。図柄・色・大きさの調整を依頼されたら `Sources/FolzioCore/Layout/VideoBadgeLayout.swift` と `Sources/FolzioApp/FileList/VideoBadgeImageView.swift` の定数を直して再確認を依頼する（A-253）
- [ ] T019 実装と検証の後、最新の `master` を取り込み、spec.md の「反映先」の項目を `specs/product/file-list.md` と `specs/product/contracts/localization.md` へ反映し、spec.md の冒頭に移行済み・凍結の注記を入れる。反映の前後に `scripts/dev/check-spec-ids.sh` と `python3 scripts/dev/check-spec-format.py` を実行し、反映した項目と差分を保守者に示して承認を得てからコミットする

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: タスクなし
- **Foundational (Phase 2)**: T001・T002（テスト）→ T003 → T004。すべてのストーリーの前提
- **User Stories (Phase 3〜5)**: Phase 2 の後。US1 → US2 → US3 の順に行う（同じ `ThumbnailModeView.swift` と
  `ThumbnailVideoBadgeTests.swift` を触るため）
- **Polish (Phase 6)**: すべてのストーリーの後。T014・T015 → T016 → T017 → T018 → T019

### User Story Dependencies

- **US1 (P1)**: Phase 2 の後。ほかのストーリーに依存しない
- **US2 (P1)**: Phase 2 の後。T008 は US1 の T006（`ThumbnailItemView` の置き換え）を使う
- **US3 (P2)**: Phase 2 の後。T012 は US1 の T006 が保持する種類を使う。T011・T013 は US1 に依存しない

### Within Each User Story

- テストを先に書き、CI で失敗を確かめてから実装する
- Core の規則 → App の画像ビュー → 各ビューへの組み込み

### Parallel Opportunities

- T001 と T002（Core と App の別ファイルのテスト）
- T005 と T003・T004 の後の作業は別ファイル
- T011（文言）は、ほかのストーリーと別ファイル
- T015（使い方の文書）は、アプリのコードと別ファイル

---

## Parallel Example: Foundational

```text
Task: "T001 Tests/FolzioCoreTests/VideoBadgeLayoutTests.swift"
Task: "T002 Tests/FolzioAppTests/VideoBadgeImageViewTests.swift"
```

Cloud では並列の作業者を起動せず、同じセッションで順に行う。

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 2（T001〜T004）で規則と画像ビューを作る
2. Phase 3（T005・T006）でサムネイル形式に組み込む
3. CI で確かめ、保守者の GUI 確認の 1・2・4 を先に依頼できる状態にする

### Incremental Delivery

1. Phase 2 + US1 → サムネイル形式のバッジ（MVP）
2. US2 → 大きさの変更への追従をテストで固める
3. US3 → リスト形式と読み上げ
4. Phase 6 → PR、保守者の確認、製品仕様への反映

---

## Notes

- `[P]` は別ファイルで依存がない作業
- `[Story]` のラベルで spec.md のストーリーと対応づける
- コミットは Phase の区切りで行う（Cloud の検査は `scripts/dev/check-all.sh`、build と test は CI）
- 同じ原因の CI の失敗を 3 回直しても解決しなければ止めて報告する
