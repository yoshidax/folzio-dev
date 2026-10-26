# Research: スライドショーのオプション設定

**Date**: 2026-10-26 | **Branch**: `007-slideshow-options`

調査入力は [spec.md](spec.md)、spec が参照する 006 の [spec.md](../006-add-slideshow/spec.md)・[data-model.md](../006-add-slideshow/data-model.md)・[contracts/slideshow.md](../006-add-slideshow/contracts/slideshow.md)、`specs/product/`（overview.md・preview.md・contracts/settings.md・contracts/keyboard-and-menus.md）、憲章 v1.2.0、既存コード。以下の型・接続点は実装方針であり、実装済みの API ではない。

Technical Context に NEEDS CLARIFICATION は残っていない。spec の Clarifications（2026-10-26）で決まった5点（前の動画の静止、準備待ち、繰り返しオフの終了条件、Tab 順と Esc、動作オプションへの所属）を前提とする。

## R1 — 設定の保存と読み出しの時点

**Decision**: 3項目は既存の `SettingsStore` に `slideshow` プロパティとして追加し、`UserDefaults` のキー `slideshow.intervalSeconds`（Int）・`slideshow.repeats`（Bool）・`slideshow.transition`（String: `none` / `crossfade` / `slide` / `zoom`）に保存する。値の型は Core の `SlideshowOptions`（`Model/Settings.swift` の `PlaybackOptions` の隣）とする。`SlideshowCoordinator` は設定を保持・購読せず、判断の時点ごとに `SettingsStore.slideshow` を読む。

| 判断の時点 | 読む項目 | 結果 |
|---|---|---|
| 開始（`start`） | 間隔 | 最初の期限 = 開始時刻 + 間隔 |
| 受理した矢印（`arrow`） | 間隔 | 待機の期限 = 押下時刻 + 間隔 |
| 自動送りの確定（`commit`） | 間隔・繰り返し・効果 | 次の対象または終了、次の期限 = 確定時刻 + 間隔、使う効果 |

**Rationale**: 既存の `BrowserModel.playbackRequest` は `settings.playback` を使うたびに読み、設定ウインドウは `SettingsStore(defaults: .standard)` へ直接書く。同じ方式なら、設定の変更通知や購読の仕組みを追加しなくても FR-132 を満たせる。すでに計算済みの期限は書き換えないので、予定されている次の切り替えの時刻は変わらない（US12-AS9）。矢印による待機の期限も変わらない。繰り返しは次の `commit`、効果も次の `commit` で読むので、EC-77 の「次の自動送りの判断から」とも一致する。`.app` と `swift run` の UserDefaults ドメインの違いは既存設定と同じ扱い。

**EC-75（読み込み時の検証）**: 項目ごとに検証し、不正な項目だけを既定値にする。

- 間隔: `NSNumber` で、Bool（`CFBoolean`）ではなく、`Int` へ正確に変換でき、1〜3600 のとき採用する。`3.5` や `true` や文字列は 3。
- 繰り返し: 既存の `storedBool` と同じく `as? Bool`。それ以外はオン。
- 効果: `String` で4つの raw value のいずれかのとき採用する。それ以外は `none`。

**Alternatives considered**: 実行中のセッションに間隔をコピーし、設定変更を通知で反映する方式は、通知の配線と「どの期限に適用するか」の分岐が増える。`NSUserDefaultsController` / Cocoa Bindings は既存コードで使っておらず、検証のタイミングを制御しにくい。秒の Double 保存は小数を受け付けない仕様（A-56）と合わない。

**Evidence**: `Sources/MediaViewerCore/Settings/SettingsStore.swift`、`Model/Settings.swift`、`Browser/BrowserModel.swift` の `playbackRequest`、`Sources/MediaViewerApp/Settings/SettingsWindowController.swift`。FR-127・FR-132、EC-75・EC-77、US12-AS8・AS9。

## R2 — 切り替え間隔の解析と確定

**Decision**: 文字列から秒を求める処理を Core の純粋関数 `SlideshowIntervalInput.parse(_:) -> Int?` に置く。App のテキストフィールドは `NSTextFieldDelegate` で確定と取り消しを扱い、`NumberFormatter` は使わない。

解析の規則:

1. 前後の空白・改行（`CharacterSet.whitespacesAndNewlines`。全角スペース U+3000 を含む）を除く。
2. 全角数字 U+FF10〜U+FF19 だけを半角数字へ置き換える。そのほかの全角文字は置き換えない。
3. 空、または ASCII の `0`〜`9` 以外の文字を含めば nil（`+5`・`-1`・`2.5`・`1,000`・`abc` を拒否）。
4. `Int` に変換できない（桁あふれ）なら nil。先頭の `0` は許す（`007` → 7、EC-74）。
5. 1〜3600 の範囲外なら nil。

確定の経路:

| 操作 | 処理 |
|---|---|
| Return | `controlTextDidEndEditing` で解析。成功なら保存してフィールドを正規化した数字（例 `15`）で表示し直す。失敗なら保存せず直前の有効値を表示する |
| Tab／⇧Tab・クリックによるフォーカスの移動 | 同上（`controlTextDidEndEditing`） |
| 設定ウインドウを閉じる | `windowWillClose` で `window.makeFirstResponder(nil)` を呼び、編集を終わらせて同じ検証を通す（EC-73） |
| 編集中の Esc | `control(_:textView:doCommandBy:)` で `cancelOperation(_:)` を受け、フィールドを直前の有効値に戻して `true` を返す。保存しない。ウインドウは閉じない |

**Rationale**: 規則を Core に置けば、US12-AS3・AS4、EC-74、SC-039 の全入力を単体テストで確かめられる。`NumberFormatter` はロケールによって桁区切りを受け付け、全角数字や前後空白の扱いを細かく決められない。設定ウインドウは `NSPanel` ではなく通常の `NSWindow` なので、Esc で閉じる既定動作はない。編集中の Esc はフィールドエディタの `cancelOperation:` として届くため、delegate で消費すれば responder chain へ伝わらない。スライドショーのキー受理は、対象ウインドウ（メインウインドウ）がキー入力先であることを条件にしている（006 の FR-123、`SlideshowInputPolicy`）。そのため、設定ウインドウでの Esc でスライドショーは終了しない。

**Alternatives considered**: `NSStepper` との組み合わせは要求外の操作を増やす（憲章 V）。入力中の1文字ごとの検証や入力の拒否は、全角入力の変換途中（IME の未確定文字列）を壊す。

**Evidence**: FR-128、EC-73・EC-74、US12-AS3・AS4、SC-039。006 の FR-123 と `Sources/MediaViewerCore/Model/PaneLayout.swift` の `SlideshowInputPolicy`。

## R3 — 設定ウインドウのキーボード操作とアクセシビリティ

**Decision**: 設定ウインドウのチェックボックスとポップアップメニューを、`canBecomeKeyView` を常に `true` にする小さなサブクラス（例: `KeyViewCheckbox`・`KeyViewPopUpButton`、App 内 private）で作る。`window.autorecalculatesKeyViewLoop = false` にし、`nextKeyView` を「動画を自動再生する → 動画をループ再生する → 確認する → 切り替え間隔 → 繰り返す → 切り替え効果 → 先頭へ戻る」の順に明示し、`initialFirstResponder` を先頭にする。アクセシビリティのラベルは `setAccessibilityLabel` で「切り替え間隔（秒）」「最後まで表示したら先頭から繰り返す」「切り替え効果」とする。

**Rationale**: AppKit のボタン類は、システムの「キーボードナビゲーション」がオフのとき `canBecomeKeyView` が false になり、Tab で止まらない。FR-127・SC-042 は設定に関わらずすべての項目に止まることを求める。そのため、`canBecomeKeyView` を上書きするのが最小の変更になる。フォーカスを持ったチェックボックスは Space で切り替わり、`NSPopUpButton` は Space でメニューを開き、矢印キーと Return で選べる。どちらも AppKit 標準の動作で、追加の実装はいらない。テキストフィールドは常に key view になる。チェックボックスはタイトルがそのまま読み上げられる。繰り返しのタイトルを FR-127 の文言にすれば、ラベルの明示は確認のためだけになる。

**Alternatives considered**: `NSApp.isFullKeyboardAccessEnabled` を見て案内を出す方式では、FR-127 の「設定に関わらず」を満たさない。`keyDown` で Tab を独自に処理する方式は、⇧Tab・フィールドエディタ・VoiceOver の扱いを作り直すことになる。

**Evidence**: FR-127、SC-042、Clarifications の4問目。`SettingsWindowController.makeContentView`。

## R4 — 可変間隔の実行状態

**Decision**: `SlideshowSession` が保持していた固定の `interval` をやめ、`start(now:interval:)`・`arrow(now:interval:)`・`commit(now:interval:)` の引数で受け取る。期限・世代・pending due・終了 > 矢印 > due の優先順位は 006 のまま変えない。`timeout` は既存の期限と比べるだけなので、間隔を受け取らない。

**Rationale**: 間隔を受け取るのは期限を計算する3か所だけになる。古い期限は書き換わらないので、FR-132 の「予定済みの時刻は変えない」「矢印による待機の期限は変えない」を型の上で保証できる。006 の仮想時刻のテスト（`SlideshowSessionTests`）は、間隔 3 秒を渡すだけで同じ意味を保てる。切り替え効果の長さ（0.5秒）は Session に入れず、期限を延ばさない（FR-118、EC-80）。

**Alternatives considered**: Session に `var interval` を持たせ、設定変更のたびに書き換える方式は、書き換えた瞬間に既存の期限を再計算するかどうかが曖昧になる。期限を `deadline + interval` で積み上げる方式は、006 の「確定時刻から数える」「遅延時は最大1回」（FR-124）と合わない。

**Evidence**: `Sources/MediaViewerCore/Slideshow/SlideshowSession.swift`、`Sources/MediaViewerApp/Slideshow/SlideshowCoordinator.swift`。FR-118・FR-121・FR-132、US12-AS2・AS9、SC-038。

## R5 — 繰り返しオフの終了判断

**Decision**: `SlideshowSequence` に `advance(in:focused:repeats:) -> SlideshowAdvance` を加える。結果は `.target(URL)`（次の対象。1件で繰り返しオンなら同じ URL）、`.finish`（繰り返しオフで、最新のフォーカスが表示順の末尾）、`.empty`（対象0件）の3つ。既存の `nextTarget(in:focused:)` は `repeats: true` の結果を返すラッパーとして残す。`SlideshowCoordinator.commitPendingDue` は `.finish` のとき `stop()` を呼び、受理した Esc と同じ復帰経路（全画面の解除、開始前のペイン表示・フォーカス、選択の保持）を通す。

判断の規則:

| 最新のフォーカス | 繰り返しオン | 繰り返しオフ |
|---|---|---|
| 対象にあり、末尾ではない | 次の対象 | 次の対象 |
| 対象にあり、末尾 | 先頭 | 終了 |
| 対象が1件だけで、その1件 | 同じ1件（再ロードしない、EC-66） | 終了（EC-66） |
| 対象にない・選択なし | 先頭（FR-125） | 先頭（FR-125） |
| 対象0件 | 終了（既存の自動終了） | 同左 |

矢印による待機の期限が来た場合も、同じ `commit` → `advance` を通る。そのため、末尾で矢印を押した場合は最後の押下から間隔の後に終了する（FR-121・FR-129、US12-AS7）。末尾の判定は commit の時点の `listing.files` で行う。そのため、一覧の更新で末尾になった・末尾でなくなった場合（EC-76）や、実行中に繰り返しを切り替えた場合（EC-77）にも、追加の処理はいらない。

**Rationale**: 006 の設計は、送るたびに最新の一覧とフォーカスから次を導く。終了の判断を同じ純粋関数に入れれば、通常フォルダ・zip・検索結果（SC-040）を同じテストで扱える。新しい終了経路を作らず `stop()` を再利用するので、A-52 の「Esc と同じ表示復帰」が自動的に揃う。

**Alternatives considered**: 開始時に残りの件数を数える方式は、一覧の更新に追従できない。末尾で止まって表示を保つ状態は、A-57 で設けないと決めている。

**Evidence**: `SlideshowSequence.swift`、`SlideshowCoordinator.commitPendingDue`・`stop`。FR-129、EC-66・EC-76・EC-77、US12-AS5〜AS7、A-52・A-57、SC-040。

## R6 — 切り替え効果の描画方式

**Decision**: `PreviewViewController` の中で、既存の `imageView`・`videoView` を新しい `contentHostView` に入れ、その上に前の表示を写した `SlideshowTransitionOverlayView`（新規。クリックを通し、アクセシビリティ要素にしない）を重ねる。効果は Core Animation の `CABasicAnimation` を2つのビューの layer に**追加するだけ**で表現し、layer のモデル値（frame・transform・opacity）は変えない。効果の長さは 0.5 秒、タイミングは `easeInEaseOut`。`containerView` は `masksToBounds` で切り抜く。

| 効果 | 前の表示（overlay） | 次のメディア（contentHost） |
|---|---|---|
| クロスフェード | opacity 1 → 0 | opacity 0 → 1 |
| スライド | translation.x 0 → −幅 | translation.x +幅 → 0 |
| ズーム | opacity 1 → 0 | 中心基準の scale 0.6 → 1.0、opacity 0 → 1 |

完了時（`CATransaction` の completion）は、世代を照合してから overlay を隠し、snapshot を手放す。layer-backed の NSView では anchorPoint が原点にある。そのため、ズームは「中心へ平行移動 → 拡大 → 戻す」の `CATransform3D` を from 値にする。

**Rationale**: 次のメディアは動画の場合も含めて実際のビューのまま見せる必要がある（EC-78: 次の動画は切り替えの開始から自動再生する）。前の表示は静止画でよい（Clarifications 1問目）。また、bug: slideshow-video-routing-context-crash の修正で `AVPlayer` は1つを使い回している。前後の動画を2つのプレーヤーで同時に表示する方式は取れない。そのため、「前は snapshot、次は実物」という非対称な構成が最小になる。AppKit が管理する layer のモデル値を変えずに presentation だけを動かすので、Auto Layout や AppKit の layer 管理と競合しない。スライドの向きは常に「右から入る」なので、末尾から先頭へ戻る場合も同じ設定で済む（FR-130）。

**Alternatives considered**: `CATransition`（`.fade` / `.push`）を container に付ける方式は、ズームを表現できない。また、AppKit が subview の layer を差し替える時点を制御できない。`NSAnimationContext` とビューの `animator()` による frame・alphaValue の変更は、モデル値を書き換える。そのため、Auto Layout の制約と競合し、打ち切りのときに戻し忘れる余地が残る。`AVPlayer` を2つ使う方式は、上記の bug 修正に反する。次のメディアも snapshot にする方式は、動画の自動再生の開始時点（EC-78）と合わない。効果の長さや向きの設定は範囲外（A-53）。

**Evidence**: `Sources/MediaViewerApp/Preview/PreviewViewController.swift`・`ImagePreviewView.swift`・`VideoPreviewView.swift`、`Sources/MediaViewerCore/Playback/VideoPlayback.swift`、コミット 5db16aa。FR-130、US13-AS2〜AS4、EC-78。

## R7 — 前の表示の snapshot

**Decision**: 切り替えの開始時に、前の表示の状態ごとに次の方法で `CGImage` と配置を得て、overlay に載せる。overlay の背景はプレビューの背景色で塗り、下で読み込み中の表示が透けないようにする。

| 前の表示 | 取得方法 |
|---|---|
| 静止画・アニメーション画像 | `ImagePreviewView` の `contentLayer` の現在の `contents`（`CGImage`）・frame・`contentsGravity` をそのまま使う。デコードや再描画をしない |
| 動画 | 先に `player.pause()` で再生と音声を止める。その時点のフレームを `AVPlayerItemVideoOutput.copyPixelBuffer(forItemTime:)` で取り、`VTCreateCGImageFromCVPixelBuffer` で `CGImage` にする。`AVMakeRect(aspectRatio:insideRect:)` で aspect-fit の位置に置く。フレームが取れない場合（最初のフレーム前・映像トラックなし）は背景だけ |
| エラー表示・メッセージ・空 | `imageView.layer` を `CALayer.render(in:)` でビットマップに描く（文字だけで小さい）。空は背景だけ（EC-79） |

`AVPlayerItemVideoOutput` は `VideoPlayback.load(asset:loop:)` でアイテムに付け、`unload()` で外す。ピクセル形式は `kCVPixelFormatType_32BGRA`。

**Rationale**: `NSView.cacheDisplay(in:to:)` は `draw(_:)` による描画を写す。そのため、`contents` を直接設定した layer や `AVPlayerLayer` の映像は写らない。画像は既に表示中の `CGImage` を共有すれば、メインスレッドで大きな描画をせずに済む（憲章 II）。動画のフレームは `AVAssetImageGenerator` でも取れる。ただし非同期で、zip 内動画では独自の resource loader を通るため、切り替えの開始時点に間に合わない。Video output は同期で現在のフレームを返す。`VideoPlayback` は Core にあるが、AVFoundation・CoreVideo・VideoToolbox だけを使い AppKit を import しないので、Core の制約に反しない。

**Risks**: 動画ごとに video output を付けると、デコード済みフレームの受け渡しが増える。実装 Phase で既存の動画開始1秒の基準（性能の検証）を確認し、問題があればスライドショーの実行中で効果が「なし」以外のときだけ付ける方式に絞る。

**Alternatives considered**: 前の動画を一時停止したままプレーヤーに残し、次のメディアを別のビューに出す方式は、次も動画のときに単一プレーヤーと衝突する。全体を `CGWindowListCreateImage` で写す方式は、画面収録の権限を要し、macOS 15 では非推奨。

**Evidence**: `ImagePreviewView` の `contentLayer`・`displayedImage`、`VideoPreviewView.stop`、`VideoPlayback.load`・`unload`。Clarifications の1問目、EC-78・EC-79。

## R8 — 次のメディアの準備完了と待機

**Decision**: `SlideshowCoordinator` は自動送りの commit で、次の対象が現在のフォーカスと異なる場合（R9）、選択を変える**前に**プレビューへ「対象 URL と使う効果」を渡して切り替えを準備させる（armed）。プレビューは snapshot を overlay に出して前の表示を保つ。その後、選択の同期で `model.preview` が変わり、下の実物の表示が更新される。プレビューは、armed の URL の表示が次の「準備完了」に達した時点で効果を始める。

| `model.preview` | 準備完了とみなす時点 |
|---|---|
| `.image` | すぐ（デコード済み） |
| `.animatedImage` / `.animatedImageData` | `showAnimated` を呼んだ時点（代替画像のデコード後） |
| `.video` | 最初のフレームを表示できる時点（`AVPlayerView`／`AVPlayerLayer` の該当 API、例えば `AVPlayerLayer.isReadyForDisplay` 相当を実装時に確認する）。`AVPlayerItem.status` が `.failed` になった場合は、その時点（エラー表示の判定済み）。映像トラックを持たない動画は、最初のフレームが来ないので `.readyToPlay` になった時点 |
| `.unavailable` | すぐ（判定済みのエラー表示、EC-80） |
| `.empty` | すぐ（背景だけ） |
| `.loading` | 準備中。待つ |

この判定表と、holding／animating の遷移・世代の照合・打ち切りの条件は、Core の純粋な値型 `SlideshowTransitionState` に置き（[data-model.md の §5](data-model.md#5-プレビューの切り替え--slideshowtransitionstatecore新規)）、`PreviewViewController` は返された action の実行だけを行う。`.image`・`.unavailable`・`.empty` は URL を持たないため、その時点のフォーカスを表示の URL とみなす。

動画の準備完了を `AVPlayerItem.status == .readyToPlay` だけで判定しないのは、この状態が最初のフレームの描画を保証しないためである。その時点で効果を始めると、クロスフェードやズームの途中で黒い（空の）プレーヤーが見える（analyze U3）。`ready(url:)` に渡す URL は、`PreviewViewController.showVideo` が `configure` に渡した URL（`model.preview` の `.video(URL)`。zip 内の動画も `ArchiveAssetFactory` でアセットへ変換する前の URL）とする。`configure(asset:)` は URL を受け取らないため、`showVideo` が `configure` を呼ぶたびに、その URL を捕捉したクロージャを `VideoPreviewView.onReadyForTransition` に設定し直す。前の動画の監視は `stop()` と次の `configure` で外すので、古い動画の通知が新しい URL として届くことはない。

準備中の切り替えは、プレビュー側のタイマーでは打ち切らない。次の commit・矢印・Esc・終了のいずれかで必ず打ち切る（overlay を外し、効果なしで現在の表示にする）。次の commit が来たときは、まず前の準備中の切り替えを打ち切り、その時点で見えている表示を新しい snapshot にする。armed の URL と異なる URL の表示が来た場合も、holding・animating のどちらでも打ち切る（効果中に効果「なし」の次の commit が来た場合を含む）。armed の URL の表示が再び届いた場合は、holding なら準備完了を判定し直し、animating なら何もしない。

holding・animating の間は、画面に前の表示の写しが見えていても、選択はすでに armed の URL（次の対象）に移っている。この間に受理した矢印・Esc は、006 と同じく選択中のメディアを基準に処理する（矢印は `slideshowMoveFocus` で選択中のメディアから動かし、Esc は選択を保って終了する）。表示中の写しを基準にするには、表示と選択を別々に追跡する仕組みが要る。準備待ちは通常、次の commit より短い。また、リストの選択と VoiceOver はすでに次の対象を示している。そのため、この仕組みは追加しない（EC-80、analyze U5）。

**Rationale**: Clarifications の2問目と EC-80 は、準備を待つ時間も間隔に含め、次の予定時刻までに準備が終わらなければ効果をやめるとしている。次の予定時刻には必ず次の commit（または繰り返しオフの終了）が来る。そのため、打ち切りを次の commit に任せれば、プレビューは時刻を知らずに済み、Session の期限と二重に時刻を管理しない。commit の時刻は変えないので、SC-038 の時間枠に効果は影響しない。

状態遷移を Core に置くのは、憲章 IV（コアロジックを UI から分離して単体でテスト可能に保つ）と AGENTS.md の「判断ロジックは Core」に従うため。App に置くと、世代の照合や準備完了の判定表に自動テストがなくなる（analyze D1）。

**Alternatives considered**: 準備完了まで commit 自体を遅らせる方式は、FR-118 の「デコード完了を待って間隔を延長しない」に反する。プレビューが独自に期限を持つ方式は、Session の期限との不一致を生む。状態遷移を `PreviewViewController` の中に持つ方式は、上記のとおり自動テストできない。

**Evidence**: `PreviewViewController.updateFromModel`・`loadAnimatedImage`・`showVideo`、`SlideshowCoordinator.commitPendingDue`。Clarifications の2問目、FR-118・FR-130、EC-80。

## R9 — 打ち切り・効果を付けない場面・視差効果を減らす

**Decision**:

- 効果を付けるのは `commitPendingDue` からの自動送りで、選択が実際に変わる場合だけ。開始時の最初の表示、矢印による選び直し、終了時の復帰、スライドショー以外の選択の変更ではプレビューを arm しない（FR-131、US13-AS5・AS8）。arm より前に、`advance` の `.target(url)` が現在のフォーカスと同じか（EC-66 の1件・繰り返しオン）を判定し、同じなら arm しない（準備中の切り替えがあれば打ち切るだけ）。arm してから `synchronizeSlideshowSelection` の `false` で打ち切る順序では、arm の時点で前の動画が一時停止され、打ち切っても再生は再開せず、同じ対象なのでプレビューも読み込み直されない。そのため EC-66 の「同じ1件の表示を維持」と FR-119 の「再生状態を保つ」に反し、overlay も一瞬表示される（analyze C1）。`synchronizeSlideshowSelection` が `false` を返した場合のすぐの打ち切りは、防御として残す。
- 打ち切り（`cancelTransition`）は、受理した矢印の処理の先頭・`stop()`・`stopImmediately()`・閲覧先の置き換え（`stop()` 経由）で呼ぶ。プレビューは、`containerView` の大きさが変わったとき（全画面の切り替え・ウインドウのリサイズ、EC-80）にも自分で打ち切る。打ち切りでは animation を外し、overlay を隠し、世代を進めて遅れて届く completion を無視する。
- 使う効果は Core の純粋関数 `SlideshowTransitionEffect.effective(reduceMotion:)` で決める。視差効果を減らす設定がオンなら `slide`・`zoom` を `crossfade` に置き換える。`none`・`crossfade` はそのまま。App は commit のたびに `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` を読んで渡す。保存値は変えない（FR-131、A-59）。

**Rationale**: arm を自動送りの commit の経路だけに置けば、FR-131 の「付けてはならない」場面を列挙して除外する必要がない。打ち切りの呼び出し元は、006 で session の世代を進めている箇所と一致する。そのため、「効果の完了を待たない」（SC-041）を既存の入力調停と同じ順序で保証できる。視差効果を減らす設定は、既存の `ImagePreviewView` でもアニメーション画像の判断に同じ API を使っている。

**Evidence**: `SlideshowCoordinator.handleKeyEvent`・`stop`・`stopImmediately`・`handleWillReplaceLocation`、`ImagePreviewView.accessibilityDisplayOptionsDidChange`。FR-131、US13-AS5〜AS8、EC-80、A-58・A-59。

## R10 — 検証の方法

**Decision**:

- Core: 間隔の解析（US12-AS3・AS4、EC-74 の全入力）、`SettingsStore.slideshow` の既定値・往復・不正値（EC-75、SC-039）、可変間隔の Session（US12-AS9、矢印による待機中の変更）、`advance` の全分岐（EC-66・EC-76・EC-77、US12-AS5〜AS7）、効果の置き換え（US13-AS7）、切り替えの状態遷移と準備完了の判定（`SlideshowTransitionState`。同じ対象の arm をしないこと（EC-66）、古い世代の completion の無視、打ち切りの条件、EC-80）を Swift Testing で確かめる。期限を扱うものは仮想時刻を使う。
- 時間の実測: 既存の OSSignposter（`local.my-img-viewer.MediaViewer` / `Performance`）に `SlideshowTransitionBegin`（arm）・`SlideshowTransitionStart`（効果の開始）・`SlideshowTransitionEnd`・`SlideshowTransitionCancel` を加える。`SlideshowAdvance` との間隔を Instruments で読み、SC-038（設定値〜設定値＋0.2秒）と SC-041（0.7秒以内）を確かめる。イベントにファイル名やパスは含めない。
- GUI: 効果の見た目、前の動画の静止と無音、Tab 順、VoiceOver はユーザーによる手動確認とする（[quickstart.md](quickstart.md)）。

**Rationale**: 憲章 IV は UI の見た目の自動テストを求めない。一方で、判断のロジックを Core に寄せれば、要件の大半を自動テストで確かめられる。間隔 1・3・10 秒を各10回実時間で待つ自動テストは 140 秒を超え、既存の性能スイートを遅くするので、実時間は signpost による手動計測とする。

**Evidence**: `Tests/MediaViewerCoreTests/SlideshowSessionTests.swift`・`SlideshowSequenceTests.swift`・`SettingsStoreTests.swift`、`Tests/MediaViewerPerformanceTests/SlideshowPerformanceTests.swift`、006 の quickstart「計測」。
