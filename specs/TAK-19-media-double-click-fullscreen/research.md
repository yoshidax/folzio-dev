# Research: メディア表示区画のダブルクリックによる全画面の切り替え

調査の基準: `claude/zen-goodall-wtxkca`（`origin/master` の bc97861 を含む）。コードと仕様の静的な確認。Cloud では GUI と Swift を実行できないため、
AppKit・AVKit の実機の挙動は quickstart.md の手動確認で確かめる。

## R1 ダブルクリックを受ける場所

**Decision**: ダブルクリックの認識（`NSClickGestureRecognizer`、`numberOfClicksRequired = 2`、`delaysPrimaryMouseButtonEvents = false`）を、
`PreviewViewController` のルートビュー（`containerView`）に1つだけ置く。`ImagePreviewView` の既存の認識（`ImagePreviewView.swift:42`・`:137-141`・`:476-479`）と
`onDoubleClick` は削除し、`PreviewViewController.onDoubleClick` はルートビューの認識から呼ぶ。

**Rationale**:
- 現在は `PreviewViewController.onDoubleClick` が `imageView.onDoubleClick` に転送しているだけで（`PreviewViewController.swift:86-89`）、`VideoPreviewView` には
  認識がない。動画を表示している間は `imageView` が隠れる（`videoView.isHidden` の切り替え）ため、動画では反応しない。
- `containerView` は画像ビュー・動画ビュー・切り替え効果のオーバーレイの共通の祖先で（`PreviewViewController.swift:163-199`）、全画面中はプレビューが
  ウインドウ全体を占める（`PanePresentation` の全画面ではツリーとファイルリストを隠す）。1か所に置けば、通常表示（FR-208（1））と全画面（FR-208（2））の
  両方の反応領域を、画像・動画で同じ規則で覆える。
- AppKit のジェスチャー認識は、取り付けたビューの子孫で起きたマウスイベントも受け取る。`delaysPrimaryMouseButtonEvents = false` は既存の画像ビューと
  同じ設定で、1回目のクリックを遅らせずに子のビュー（再生コントロールなど）へ届ける。
- 切り替え効果のオーバーレイはクリックを下のプレビューへ通す（FR-131、`SlideshowTransitionOverlayView`）。認識を祖先に置けば、効果の表示中も同じ認識で受ける（EC-143）。

**Alternatives considered**:
- 画像ビューと動画ビューのそれぞれに認識を置く: 同じ判断を2か所に持ち、除外の規則がずれる恐れがある。採用しない。
- `mouseDown(with:)` の `clickCount` で判定する: `AVPlayerView` が内部でイベントを処理するため、親のビューの `mouseDown` には届かない場合がある。採用しない。

## R2 再生コントロールとスクロールバーの除外（FR-208、EC-142）

**Decision**: 認識の delegate（`NSGestureRecognizerDelegate.gestureRecognizer(_:shouldAttemptToRecognizeWith:)`）で、イベントの位置を `containerView.hitTest(_:)` で調べ、
当たったビューかその祖先（`containerView` まで）に `NSControl` があれば認識しない。

**Rationale**:
- 画像のスクロールバーは `NSScroller`（`NSControl` のサブクラス）で、`ImagePreviewView` の子として置かれている（`ImagePreviewView.swift` の `horizontalScroller`・`verticalScroller`）。
  現在の実装では、スクロールバーの上のダブルクリックでも全画面が切り替わる。この判定で除外できる。
- `AVPlayerView` の再生コントロール（`controlsStyle = .inline`）は公開 API で領域を取得できない。コントロールの部品はボタン・スライダーとして実装されているため、
  `NSControl` の判定で除外できると見込むが、AVKit の内部構成に依存する。**実機での確認が必要**（quickstart.md の M3）。
- 確認の結果、コントロールの上で全画面が切り替わる場合は、推測で別の判定（コントロールの帯の高さを決め打ちするなど）を足さず、作業を止めて保守者に報告し、方式を相談する
  （AGENTS.md「テスト」の、3回直しても解決しない場合の停止と同じ扱い）。

**Alternatives considered**:
- 動画の下端から一定の高さを除外する: コントロールの高さと表示・非表示は OS のバージョンとウインドウの大きさで変わり、要件の「コントロールの上」と一致しない。採用しない。
- AVKit の非公開クラス名で判定する: 非公開 API への依存になる。採用しない。

## R3 動画の再生状態の維持（FR-209、EC-144）

**Decision**: 1回目のクリックはそのまま子のビューへ届け、アプリ側では再生状態を操作しない。`AVPlayerView` の映像の上のシングルクリックで再生状態が変わらないこと、
ダブルクリックで `AVPlayerView` 自身の全画面表示が始まらないこと（`showsFullScreenToggleButton = false`、`VideoPreviewView.swift` の `setup()`）を実機で確かめる（quickstart.md の M2）。

**Rationale**: 全画面の切り替え自体は FR-037 のとおり再生位置と再生状態を保つ（既存の ⌃⌘F と同じ `togglePreviewFullScreen()` を使う）。リスクは、ダブルクリックの
1回目のクリックを `AVPlayerView` が再生・一時停止として扱う場合だけである。

**Risk**: 実機で、映像のシングルクリックが再生・一時停止を切り替えると分かった場合は、FR-209 を満たせない。その場合も推測で直さず、作業を止めて保守者に報告する。

## R4 プレビューが空のときの扱い（EC-141）

**Decision**: 「ダブルクリックで全画面を切り替えるか」を FolzioCore の純粋な判断 `PreviewDoubleClick.togglesFullScreen(isFullScreen:hasMedia:isOverControl:)` に置き、
`PreviewContent.hasMedia`（`.empty` だけ false）とあわせて Swift Testing で検証する。App 側（`MainSplitViewController` の `onDoubleClick` の処理）は、
全画面の状態（`isFullScreenPresentation`）と `model.preview` をこの判断に渡し、true のときだけ既存の `togglePreviewFullScreen()` を呼ぶ。

**Rationale**:
- 現在の `togglePreviewFullScreen()` は、プレビューの内容を確かめずに全画面へ切り替える（`MainSplitViewController.swift:773-784`）。画像ビューは空のプレビューでも
  表示されているため、空のプレビューのダブルクリックでも全画面になる。EC-141 では反応しないことにした。
- ⌃⌘F とメニュー（FR-036）の挙動は変えない（A-121）。そのため、判定は `togglePreviewFullScreen()` の中ではなく、ダブルクリックの経路だけに置く。
- 判断は AppKit に依存しないため Core に置ける（AGENTS.md「プロジェクト概要」）。
- 全画面中はプレビューの内容によらず解除する（EC-141）。スライドショーの扱いは既存の `togglePreviewFullScreen()` と全画面の通知の処理（FR-122）をそのまま使う。

**Alternatives considered**: `PreviewViewController` の内部で空かどうかを判定する: 全画面の状態を持たないため、全画面中の解除の規則を表せない。採用しない。

## R5 文書の更新

**Decision**: 公開のユーザーガイド（`docs/usage.md`・`docs/usage.ja.md`）と開発ガイドの起動スモーク（`docs/development.md`・`docs/development.ja.md`）の
「画像のダブルクリック」を、画像と動画を含むメディアの記述に改める。英語版と日本語版を同じコミットで直す。README には全画面のダブルクリックの記述がないため変更しない。

**Rationale**: `docs/usage.ja.md:71`・`:166`、`docs/development.ja.md:108` が「画像のダブルクリック」を案内している。ショートカット一覧（TAK-22）の項目はキーだけを
掲載しており（`ShortcutCatalog` の `.fullScreen` は ⌃⌘F）、ダブルクリックを含まないため変更しない。
