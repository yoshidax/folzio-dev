# Bug Assessment: 通常表示でプレビューの動画にフォーカスしても Space で再生・一時停止できない

- **Slug**: tak-48（Issue ID から生成。既存の `tak-9`・`tak-12`・`tak-44` に合わせた）
- **Created**: 2026-11-02
- **Source**: [TAK-48](https://linear.app/takyoshida/issue/TAK-48)（host: linear.app、allowlisted。Linear MCP で取得）
- **Verdict**: likely valid, needs reproduction（保守者の実機確認の報告による。Cloud では GUI を起動できず、エージェントは再現していない）
- **Severity**: medium（TAK-18 により、通常表示で Space による再生／一時停止の手段が実質なくなる。マウスの再生コントロールで代替でき、データの損失はない）

## Report

Issue の要約（2026-11-02 起票、`origin/master` `14c1c78` で静的確認）:

> 3ペイン表示またはプレビューのみ表示で動画を表示しているとき、プレビューのペインにフォーカスを移して Space を押しても、
> 動画の再生／一時停止が切り替わらない。フルスクリーンでは効く。再生コントロールをクリックしてフォーカスを合わせると反応する。

## Symptom

プレビューペインにフォーカスがある状態で Space を押しても、動画が再生／一時停止しない。
期待する動作は、FR-033・FR-248 と契約（`keyboard-and-menus.md` の videoPlay）のとおり、プレビューの動画にフォーカスがあれば Space で切り替わること。

## 仕様との照合

実装が仕様に反していると判断する（fix へ進む）。

- `specs/product/preview.md` FR-033: Space で再生／一時停止。
- 同 FR-248: Space の再生／一時停止は、プレビューの動画にフォーカスがあるときに限る。
- `specs/product/contracts/keyboard-and-menus.md`: videoPlay は Space「プレビューの動画にフォーカス中。標準の動画コントロール」。
  同 462〜464 行は ← / → ・↑ / ↓（3ペイン表示で動画にフォーカスがあるとき）も標準の動画コントロールの動作と定めている。

仕様が誤っている・未定義という事情はない。

## Reproduction

1. 動画ファイルを選択し、3ペイン表示でプレビューに動画を表示する。
2. プレビューペインにフォーカスを移す（⌥⌘3、Tab、クリックのいずれか）。
3. Space を押す。再生状態が切り替わらない。

[NEEDS CLARIFICATION: フォーカスの移し方による差。クリックは動画の `AVPlayerView` に当たる可能性があり、Tab / ⌥⌘3 とは経路が違う]

## Suspected Code Paths

- `Sources/FolzioApp/Preview/PreviewViewController.swift:81` `primaryFocusView` — 動画表示中は `VideoPreviewView` を返す。
  ⌥⌘3（`focusPane`）と Tab のキービューループ（`configureKeyViewLoop`）の受け先になり、ファーストレスポンダになる。
- `Sources/FolzioApp/Preview/VideoPreviewView.swift:38` — `acceptsFirstResponder` が true だが `keyDown` がない。
  Space は子の `AVPlayerView` に渡らず、レスポンダチェーンを上へ流れる（処理されない）。
- `VideoPreviewView.swift:setup()` — `AVPlayerView`（`controlsStyle = .inline`）が子ビュー。
  `AVPlayerView` 自身がファーストレスポンダなら Space が標準動作で効くと推測できる（再生コントロールをクリックすると効く報告と合う）。
- `Sources/FolzioApp/App/MainSplitViewController.swift:828` `handleHiddenListKey` — Space の経路はなく、`/` と `<` `>` だけを扱う。

## Root Cause Hypothesis

動画表示中のフォーカスの受け先が `VideoPreviewView`（コンテナ）であり、実際にキーを処理する `AVPlayerView` ではない。
コンテナは `keyDown` を処理せず転送もしないため、Space（と ← → ↑ ↓）が動画に届かない。
確信度: medium（静的確認のみ）。フルスクリーンで効く理由は未確認（フルスクリーンでは別の経路で `AVPlayerView` にフォーカスが移る可能性）。

## Proposed Remediation

**Preferred**: フォーカスをコンテナから `AVPlayerView` へ渡す。`VideoPreviewView` が `AVPlayerView` を `primaryFocusView` の受け先として公開する
（または `becomeFirstResponder` で `playerView` を first responder にする）。これで Space・← →・↑ ↓ が標準の動画コントロールの動作になり、
FR-033 と契約を満たす。`focusedPane()` は祖先をたどるので、`AVPlayerView` がフォーカスしてもプレビューと判定される。

**Alternatives**:
- `VideoPreviewView` に `keyDown` を足し、Space だけ `togglePlayPause()` にする。小さいが、← → ↑ ↓ は届かないまま残る。

**Files likely to change**:
- `Sources/FolzioApp/Preview/VideoPreviewView.swift`
- `Sources/FolzioApp/Preview/PreviewViewController.swift`

**Tests to add or update**:
- AppKit のフォーカスは `FolzioCore` に置けないため、自動テストは難しい。`primaryFocusView` が動画表示中に `AVPlayerView` 配下のビューを返すことを
  アプリ側のテストで固定できるか実装時に確認する。できなければ、`quickstart.md` の M6 を回帰の手動確認とし、判定は `partial` にする。

## Risks & Considerations

- `AVPlayerView` が first responder を受け入れるか、キービューループ（Tab）で正しく循環するかは GUI でしか確かめられない。保守者の実機確認が必要。
- フォーカスリングや VoiceOver のラベル（`VideoPreviewView` に設定した accessibility）が、フォーカスの移動で変わらないか確認する。
- スライドショー・フルスクリーンの既存経路（`/`、`<` `>`）を壊さない。

## Open Questions

- [NEEDS CLARIFICATION: フルスクリーンで Space が効く理由]
- [NEEDS CLARIFICATION: クリック・Tab・⌥⌘3 のどれで再現するか]
