# Research: プレビュー画像の拡大・縮小

**Date**: 2026-10-27 | **Branch**: `008-preview-image-zoom`

調査入力は [spec.md](spec.md)、spec が参照する `specs/product/` の領域（preview.md・window-layout.md・navigation-history.md・file-list.md・overview.md）、[contracts/keyboard-and-menus.md](../product/contracts/keyboard-and-menus.md)、憲章 v1.2.0、既存コード。以下の型・接続点は実装方針であり、実装済みの API ではない。

Technical Context に NEEDS CLARIFICATION は残っていない。spec の Clarifications（2026-10-27）で決まった14点を前提とする。

## R1 — 倍率の型と刻み

**Decision**: Core に `PreviewZoom` を置き、百分率を `Int` で持つ。`step = 25`、`minimum = 25`、`maximum = 800`、`fit = 100`。`zoomedIn()` は `percentage + 25`、`zoomedOut()` は `percentage - 25` とし、上下限では自分自身を返す。構築は25の倍数かつ25〜800の範囲だけを許し、それ以外は `nil` にする。`scale` は `CGFloat(percentage) / 100`。

**Rationale**: 25ポイントの加算は小数の誤差を持ち込まず、32段の有限な値になる。上限・下限で循環しないことを型の上で保証できる。`Double` の百分率は 100 → 125 → 150 のような加算で誤差が蓄積し、比較と表示のたびに丸めが必要になる。乗算（100 → 125 → 156.25）は Clarifications と A-62 で否定されている。列挙型で32段を持つ案は、値の検証は強いが `FitCalculator` との変換とテストの記述が増える。

**Alternatives considered**: `Double` の倍率（誤差・丸め）、乗算（仕様違反）、列挙型（過剰）。

**Evidence**: FR-133、US14-AS1・AS2・AS7、EC-82・EC-85、A-62、SC-043。既存の `Sources/MediaViewerCore/Layout/FitCalculator.swift`。

## R2 — フィットを基準にした矩形の計算

**Decision**: 既存の `FitCalculator.fit(imageSize:in:)` は変えず、`frame(imageSize:in:zoom:)` を追加する。フィットの矩形を求め、その中心を保ったまま幅・高さを `zoom.scale` 倍する。100% は既存の `fit` と完全に一致する。画像またはコンテナが0以下のときは `.zero` を返す。`ImagePreviewView` は既存どおりピクセル空間でフィットを求めてから backing scale で割り、その結果に倍率を適用する。

```text
fitted = fit(imageSize, container)
scaled = fitted.size * zoom.scale
origin = ((container.width - scaled.width) / 2,
          (container.height - scaled.height) / 2)
```

**Rationale**: ビューポートの大きさが変わるたびに「新しいビューポートのフィット × 現在の倍率」を計算するので、FR-029 と EC-81 をそのまま満たす。フィットの中心を基準にするため、拡大しても縮小しても中央配置が崩れない。ビューポートより大きいときは原点が負になり、はみ出した部分は描画側で切り抜く。`CGRect` の整数丸めはしない。丸めると125%ずつ変えたときの位置が1ポイントずつ揺れる。

**Alternatives considered**: `contentLayer.bounds` と `transform` を変える案は、切り替え効果の snapshot が使う frame と座標系がずれる。`NSImageView` に置き換える案は、既存のアニメーション・切り抜き・snapshot の経路を作り直す。画像を再デコードして倍率ごとの `CGImage` を作る案は、性能とメモリの両方で不利。

**Evidence**: FR-028・FR-029・FR-133、EC-81・EC-82、SC-044。`FitCalculator.swift`、`Tests/MediaViewerCoreTests/FitCalculatorTests.swift`、`ImagePreviewView.fittedFrame()`。

## R3 — 倍率の状態とリセットの判断

**Decision**: Core に `PreviewZoomTracker` を置く。`level: PreviewZoom` と、表示中の画像の同一性 `imageIdentity: URL?` を持つ。`present(_ identity: URL?)` は、前回と異なる同一性が来たときだけ `level` を100%に戻す。`nil` は画像を表示していない状態として100%に戻す。`reset()` は同一性を保ったまま100%に戻す（履歴移動用）。`zoomIn()` / `zoomOut()` / `fit()` は可否と変更の有無を返す。

`PreviewViewController.updateFromModel` の対応:

| `model.preview` | `present` に渡す同一性 | 結果 |
|---|---|---|
| `.empty` | `nil` | 100%。画像なし |
| `.loading(url)` | `url` | 新しい対象なら100% |
| `.image` | `model.selection.focused` | 同じ URL なら倍率を保つ |
| `.animatedImage(url)` | `url` | 同じ URL なら倍率を保つ |
| `.animatedImageData(url, _)` | `url` | 同じ URL なら倍率を保つ |
| `.video` | `nil` | 100%。動画 |
| `.unavailable` | `nil` | 100%。表示不能 |

**Rationale**: 「画像が別の画像に切り替わったときだけ100%に戻す」という FR-137 の条件を、ビューの再描画やレイアウトの回数から切り離せる。`updateFromModel` は選択変更・先読み・再生停止などで複数回呼ばれるため、表示更新のたびに戻す実装では、同じ画像のペイン復帰やフルスクリーンで倍率が失われる。履歴移動は同じ画像に戻る場合も100%にする必要があるので、`present` の同一性比較とは別に `reset()` を明示的に呼ぶ。`BrowserModel` に持たせると、保存しない UI 状態がモデルと履歴の関心に混ざる。

**Alternatives considered**: `PreviewViewController` に `var zoom` だけを置く案（リセット判断がテストできない）、画像ごとの辞書（A-64 で範囲外）、表示更新のたびに戻す案（FR-137 違反）、履歴の `HistoryPresentation` に倍率を足す案（FR-137・FR-108 違反）。

**Evidence**: FR-137、US14-AS5・AS8・AS15、EC-87・EC-88・EC-90、A-66・A-67・A-70。`PreviewViewController.updateFromModel`、`HistoryNavigator.perform` / `applyViewState`、`MainSplitViewController.applyHistoryPresentation`、`HistoryEntry.swift`。

## R4 — 描画とアニメーション

**Decision**: `ImagePreviewView` に現在の `PreviewZoom` を持たせ、`layout()` で R2 の矩形を `contentLayer.frame` に設定する。`imageView.layer?.masksToBounds = true` にして、ビューポートからはみ出した画像を切り抜く。倍率の変更では `contents`・`displayedImage`・アニメーションの状態を変えない。

**Rationale**: 既存の画像表示は `contentLayer.contents` に `CGImage` を入れ、`contentsGravity = .resize` で frame に合わせている。frame だけを変えれば、再デコードなしで拡大・縮小でき、アニメーション GIF / WebP の `CGAnimateImage...` を止めずに済む（EC-84）。`masksToBounds` はプレビューの外へ画像が描かれないようにする最小の変更で、切り替え効果の overlay は既存どおり `containerView` のクリップに従う。倍率変更中も `CGImage` は1枚のままなので、EC-83 の「倍率変更のためのデコード失敗」という経路は生じない。画像のデコード失敗は既存の FR-038 の表示がそのまま扱う。

**Alternatives considered**: 倍率ごとに `CGImage` を作る（重い・メモリ増・アニメーション再開）、`CALayer.transform` で拡大する（snapshot と座標がずれる）、`NSImageView`（既存機能の作り直し）。

**Evidence**: FR-028・FR-133、EC-83・EC-84、SC-048。`ImagePreviewView.swift` の `layout()`・`setDisplayed`・`fittedFrame`、`PreviewViewController.transitionSnapshot`。

## R5 — 有効条件の共有

**Decision**: Core に `PreviewZoomAvailability` を置く。入力は「画像を表示しているか」「プレビューが見えているか」「現在の倍率」。`isAvailable` は前者2つがともに true のときだけ true。`canZoomIn` は `isAvailable && level < 800`、`canZoomOut` は `isAvailable && level > 25`、`canFit` は `isAvailable`。

- `PreviewViewController` は `imageView.isShowingImage` と `isPaneVisible` と現在の倍率からこれを組み立て、変更時に `onZoomAvailabilityChange` で知らせる。
- `MainSplitViewController` は通知をツールバーへ中継し、`MainWindowController` / `AppDelegate` はメニューの検証時に同じ値を読む。
- ツールバーは画像がないとき項目全体を無効にし、上限・下限では該当セグメントだけを無効にする。メニューは3項目とも画像がないとき無効、上限・下限では拡大・縮小だけを無効にする。

**Rationale**: 条件を1か所に集約しないと、ツールバー・メニュー・キーの間で「動画では無効」「ファイルリストのみでは無効」「上限では拡大だけ無効」がずれる。`imageView.isShowingImage` を使うことで、`.animatedImage` の最初のフレームがまだ届いていない状態も「画像を表示している」と誤判定しない。`PreviewContent` の列挙だけで判定すると、アニメーションの準備中を画像ありとしてしまう。

**Alternatives considered**: 各入口で `model.preview` と `paneLayout` を再判定する案（重複・ずれ）、`BrowserModel` に可否を持たせる案（UI 状態の混入）、ツールバーだけ独自条件にする案（SC-046 違反）。

**Evidence**: FR-134・FR-136、US14-AS6、EC-85・EC-89、SC-046。`PreviewViewController.isPaneVisible`・`paneLayout`、`MainToolbarController.validateToolbarItem`、`MainSplitViewController.validateMenuItem`。

## R6 — ツールバーの3ボタン

**Decision**: `MainToolbarController` に `previewZoom` の `NSToolbarItem` を追加する。view は `NSSegmentedControl`（trackingMode `.momentary`、3セグメント、各幅36）で、画像は SF Symbols の `plus.magnifyingglass`・`arrow.up.left.and.down.right.magnifyingglass`・`minus.magnifyingglass` を使う。この3つは macOS 15 の `NSImage(systemSymbolName:)` で取得できることを確認済み。項目は「スライドショーを開始」の右隣、種類フィルタの左に置く。セグメントのツールチップはショートカットを含め、画像の accessibilityDescription とセグメントのラベルに「拡大」「表示領域に合わせる」「縮小」を設定する。

**Rationale**: 3つの SF Symbols は虫眼鏡のレンズの中に `+`・両矢印・`-` を持つため、FR-134 の見た目を追加の描画コードなしで満たす。テンプレート画像なのでライト・ダークの両方で色が変わる（SC-049）。既存の履歴・ペイン・種類フィルタと同じ `NSSegmentedControl` のグループにすることで、幅・間隔・押した状態を揃えられる。3つの独立した `NSButton` はグループの見た目が崩れ、セグメント単位の有効化も自前になる。

**Alternatives considered**: 虫眼鏡と記号を自前で合成する（レンズの形・線幅を揃えるコードが増える）、`NSButton` 3つ（見た目・有効化）、`NSPopUpButton`（要件外）。

**Evidence**: FR-134・FR-045、US14-AS11、SC-049、A-61・A-65。`MainToolbarController.makeSegmentedControl`・`toolbarDefaultItemIdentifiers`、`IconCatalog`。macOS 15 での SF Symbols の取得確認（`plus.magnifyingglass`・`arrow.up.left.and.down.right.magnifyingglass`・`minus.magnifyingglass`）。

## R7 — 表示メニュー・キー割り当て・サムネイルとの移行

**Decision**: 「表示」メニューの「フルスクリーン」の下に区切り線を置き、次の3項目を追加する。

| 項目 | keyEquivalent | 修飾キー | action の target |
|---|---|---|---|
| 拡大 | `+` | ⌘ | `AppDelegate` |
| 縮小 | `-` | ⌘ | `AppDelegate` |
| 表示領域に合わせる | `0` | ⌘ | `AppDelegate` |

⌘= と ⇧⌘= の拡大は、同じ action・target を持つ非表示の `NSMenuItem`（keyEquivalent `=`、修飾キー ⌘、`isHidden = true`、`allowsKeyEquivalentWhenHidden = true`）で受ける。表示メニューとツールチップの表示は ⌘+ のまま変えない。target を `AppDelegate` にするのは、キー入力先がシート・設定ウインドウ・名前の変更中のテキストフィールドでも、メインウインドウのプレビューを操作するため。`AppDelegate` は `NSMenuItemValidation` で `PreviewZoomAvailability` を返す。

既存の「サムネイルを拡大」「サムネイルを縮小」は `keyEquivalentModifierMask = [.command, .control]` にして ⌃⌘+ / ⌃⌘- に移す。ツールバーのサイズのスライダーと下部バーの説明にも ⌃⌘+ / ⌃⌘- を反映する。プレビューのみ表示でファイルリストが隠れていても、メニュー項目の target は `FileListViewController` なので ⌃⌘+ / ⌃⌘- は届く。

**Rationale**: メニューのキー等価は、明示的な target があればキーウィンドウの responder chain に依存せず、シート・設定ウインドウがキーのときも実行できる。`target = nil` のままでは、シートや設定ウインドウの responder chain に `MainSplitViewController` がいないため届かない。非表示の `NSMenuItem` はメニューに表示されず、既定ではキー等価の照合にも参加しない。`allowsKeyEquivalentWhenHidden`（macOS 10.13 以降、既定は false）を true にしたときだけ照合に参加するため、この設定を必須とする。ローカルの `NSEvent` モニタを足すより、既存のメニュー検証・キー等価の仕組みに乗る方が状態の二重管理を避けられる。⌘+ / ⌘- をプレビューに割り当てるため、サムネイルの操作を ⌃⌘ に移すのは Clarifications と FR-135 のとおり。

**Alternatives considered**: ローカルのキーモニタ（モーダル・シート・テキスト編集との順序が増える）、各ウィンドウの `keyDown`（設定ウインドウ・シートで届かない）、⌘= を可視の別項目にする（メニュー表示が要件と変わる）、⌘+ / ⌘- をサムネイルのままにする（要望と衝突）、⌥⌘+ / ⌥⌘- に移す（⌥⌘= / ⌥⌘- は macOS のアクセシビリティズームのショートカットと重なる。A-74）。`NSMenu.performKeyEquivalent` を直接呼ぶ確認は実際のキー入力の経路（メニューバーによる照合）を通らないため、根拠にしない。⌘= と ⇧⌘= が非表示項目に届くことは、`.app` の実キー操作で手動シナリオ 1 の 6 として確かめる。

**Evidence**: FR-014・FR-135、US14-AS4・AS9・AS12・AS14、EC-89、SC-045・SC-051、A-63・A-69・A-72・A-73。`MainMenu.swift`、`FileListViewController.installViewMenuItems`、`MainToolbarController` のサイズのスライダー、`specs/product/contracts/keyboard-and-menus.md` の ⌘+ / ⌘- の行。

## R8 — アクセシビリティ

**Decision**: `ImagePreviewView` は画像を表示している間、アクセシビリティの値に現在の倍率を `"125%"` の形式で公開する。ツールバー・メニュー・ショートカットによる明示的な操作で倍率が変わったとき、`NSAccessibility.post(element:notification:.announcementRequested)` で新しい百分率を読み上げる。優先度は medium。画像がない状態では値を公開せず、ツールバーの項目とメニューの3項目を無効にする。可視の数値ラベル・スライダーは追加しない。

**Rationale**: FR-138 は可視 UI を増やさずに現在の倍率と変更を伝えることを求める。`valueChanged` だけではフォーカスがファイルリストやメニューにあるときに読み上げられないことがあるため、明示的な announcement を使う。値は常に更新するので、VoiceOver が要素を読み直したときも実際の倍率と一致する。画像がない状態で値を `nil` にし、入口を無効にすることで「倍率を公開せず、3操作を無効として読み上げる」を満たす。

**Alternatives considered**: 可視の倍率ラベル（A-64・A-71 で範囲外）、スライダー（範囲外）、`valueChanged` のみ（読み上げの保証が弱い）、操作前の値を読み上げる（結果と一致しない）。

**Evidence**: FR-138、US14-AS13、SC-050、A-64・A-71。`ImagePreviewView.setAccessibilityLabel`、憲章 原則 III、`specs/product/contracts/keyboard-and-menus.md`。

## R9 — スライドショー・履歴・レイアウトとの関係

**Decision**:

- スライドショーの自動送り・手動移動で画像が変わると、`updateFromModel` の `present(url)` が100%に戻す。切り替え効果の状態（`SlideshowTransitionState`）・期限・間隔には触れない。効果の途中で倍率を変えても、`contentHostView` の animation はそのまま続く。
- 履歴の戻る・進むは、`HistoryNavigator` が移動の成立時にだけ呼ぶ `HistoryPresentationHost.applyHistoryPresentation` で `resetZoom()` を呼ぶ。同じ画像に戻る場合も100%になる。履歴の記録（`HistoryNavigator.recordViewChange`）は呼ばない。移動先が見つからずに移動しなかった場合はリセットしない。
- フルスクリーンの切替・ウィンドウやペインのサイズ変更・ツールバーの表示切替・同じ画像を表示したままのペイン復帰では、`present` の同一性が変わらないため倍率を保つ。サイズ変更時は `layout()` が新しいビューポートで R2 を再計算する。
- 動画・空・表示不能・ファイルリストのみ表示では `PreviewZoomAvailability.isAvailable` が false。ファイルリストのみ表示の間も `model.preview` が画像のままなら同一性は変わらないので、プレビューへ戻したとき同じ画像なら倍率を保つ（EC-87）。

**Rationale**: リセットを「表示対象の同一性」と「履歴の明示的な移動」の2つに限定すると、FR-137 の保持条件と戻す条件を漏れなく分けられる。スライドショーや履歴の機構に倍率を混ぜないため、既存の期限・効果・履歴の件数に影響しない（EC-86・EC-90）。`layout()` が毎回フィットから計算するので、サイズ変更の追従は追加の状態を持たない。

**Alternatives considered**: スライドショーの coordinator に倍率リセットを足す（表示の都合が実行制御に混ざる）、履歴の `HistoryPresentation` に倍率を足す（FR-137 違反）、リサイズ時に倍率を再計算して保存する（状態が増える）。

**Evidence**: FR-029・FR-137、US14-AS8・AS10・AS15、EC-81・EC-86・EC-87・EC-88・EC-90、SC-047。`SlideshowCoordinator`、`SlideshowTransitionState`、`HistoryNavigator.applyViewState`、`MainSplitViewController.applyHistoryPresentation` / `applyPanePresentation` / `windowDidExitFullScreen`。

## R10 — 検証と性能

**Decision**: Core の単体テストで、倍率の加減・上下限・不正値、`PreviewZoomTracker` の同一性によるリセットと履歴用の明示リセット、`PreviewZoomAvailability` の条件、`FitCalculator.frame` の100%一致・125%/50%・はみ出し・中央配置・0以下を確かめる。UI は quickstart の手動シナリオで、ツールバー・メニュー・キー・VoiceOver・シート・設定ウインドウを確認する。SC-048 は24MP の JPEG を用意し、拡大・縮小・フィットを各10回行って、OS Signposts の `PreviewZoomApply` の区間と目視の応答性を記録する。`Tests/MediaViewerPerformanceTests` に、24MP 相当のサイズで32段の矩形計算を繰り返す基準を追加する。

**Rationale**: 倍率の判断は純粋な値型なので、異常系を含めて自動テストできる。描画・VoiceOver・入力経路は AppKit の実行環境が必要なため、既存の方針どおり手動ゲートにする。性能は再デコードがないことをコード構造で保証し、残るレイアウト計算をマイクロベンチマークと実機の signpost で二重に確かめる。

**Alternatives considered**: UI テストの自動化（既存方針にない）、性能を主観で判断（憲章 II 違反）、24MP のデコードを倍率変更のたびに行う（R4 で否定）。

**Evidence**: SC-043〜SC-052、憲章 原則 II・IV、`scripts/check-no-network.sh`、`Tests/MediaViewerPerformanceTests`、`specs/001-three-pane-media-viewer/quickstart.md` の性能の検証。
