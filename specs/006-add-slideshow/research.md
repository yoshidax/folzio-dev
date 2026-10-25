# Research: スライドショー

**Date**: 2026-10-25 | **Branch**: `006-add-slideshow`

調査入力は [spec.md](spec.md)、参照する `specs/product/`、憲章 v1.2.0、既存コード。Core と App の読み取り調査を分担して結果を照合した。以下の型・接続点は実装方針であり、実装済みの API ではない。

## R1 — 表示対象と識別

**Decision**: 対象は `BrowserModel.listing.files` を現在の順番のまま `kind.isMedia` で絞る。通常ファイルも zip 内も既存の `MediaFile.url` / `id` を使い、独自の連番 ID を設けない。

**Rationale**: `listing.files` はフィルタ後・並べ替え後の全表示項目であり、表示セルより広く、`allFiles` より適切に限定される。`MediaFile.id == url`。zip は `ArchiveURL.entry(archive:path:)` の `mvzip` URL が zip の場所と内部パスを含むため、同名・別場所や並べ替え後の対象を区別できる。対象の判定に画像のデコード成功は不要。読み込み中も表示済みメディアがあれば開始できる。

**Alternatives considered**: 開始時に固定した playlist は一覧更新を反映できない。画面内セルだけでは画面外を落とす。名前・行番号は検索結果の同名や再ソートで衝突する。`allFiles` は非表示項目を再混入させる。

**Evidence**: `Sources/MediaViewerCore/Model/MediaFile.swift`、`Archive/ArchiveURL.swift`、`Browser/BrowserModel.swift` の `rebuildListing`・`appendSearchResults`。FR-115/125、US9-AS14。

## R2 — 開始位置・同じメディアの維持

**Decision**: Core の `SlideshowSequence` が選択に含まれるフォーカスメディア、選択中メディアの一覧先頭、対象先頭の順で開始 URL を返す。開始時は1件選択へ整理するが、同じフォーカス／表示中の対象なら preview をロードし直さない。対象1件の自動 tick も再選択しない。

**Rationale**: 通常 preview-only への進入は非メディア行の後ろを探すため、FR-116 と異なる。`BrowserModel.select` はフォーカスが同じでも `loadPreview` と先読みを呼ぶ。`PreviewViewController.showVideo` の `configuredVideoURL` ガードは再構成を抑止するが、選択だけを整理する経路を設けた方が同一動画と読み込み中の preview を保てる。新しい対象への移動は既存の選択経路を使い、`stopPlaybackSignal` と preview 世代を維持する。隠れていた preview を表示する場合は通常の再表示を行う。

**Alternatives considered**: 常に通常の pane 切替を呼ぶと開始位置を変え得る。開始／tick ごとの player 再構成は US9-AS15 と EC-66 に反する。独自 player や動画ごとの再生位置保存は不要。

**Evidence**: `BrowserModel.select`、`loadPreview`、`PreviewViewController.showVideo`・`isPaneVisible`、`FileListViewController.beginHiddenListNavigation(selectingEntry:)`。FR-116/119、EC-66。

## R3 — 単発 deadline と手動入力の優先

**Decision**: Core の実行状態に固定3秒・単調時刻の deadline・取消世代・pending due を持つ。App が `ContinuousClock.sleep(until:tolerance: .zero)` の単発 Task を管理する。起床時に世代と実行有無を確認し、due を保留して入力 dispatch 後に確定する。同じ処理単位では終了 > 矢印 > due とする。実際に1回送った時刻から次の3秒を設定する。

**Rationale**: 単調時計は壁時計の変更の影響を避けられる。Swift の sleep は取消でエラーになるが、既に起床済みの処理まで取消だけで防げるとは限らない。世代照合で古い Task を無効化し、pending due の段階で同時に受理した入力を優先する。端・リスト左右・キー反復でも、移動結果に関係なく矢印の受理時に期限を更新する。描画完了や動画終端は時計の入力にしない。

**Arbitration boundary**: タイムアウト callback では選択を変えず、App の main event loop に commit を延期する。commit 前の現在の入力 dispatch／既に待ち行列にある対象ウィンドウの矢印・Esc を先に処理し、保留中の世代を無効化できるようにする。単なる `Task.yield()` や MainActor の直列実行を入力優先の保証としない。Core では due→arrow→commit と arrow→due→commit、due→stop→commit と stop→due→commit を固定試験する。App のイベント順も実装・手動確認で検証する。

**U1 clarification**: 上記の優先関係は FR-123 の受理条件を満たすキーに限定する。対象ウィンドウがキー入力先でない、対象のシート／アプリモーダルがある、編集欄やメニュー等がキーを処理する場合は、キーを既存の入力先へ渡し session には通知しない。モーダルを閉じた同じ Esc を終了として再適用しない。自動送りはモーダル表示中も元の deadline で継続し、開閉・そこでの Esc／矢印は deadline を変えない。modalPanel mode の commit 接続を確認し、モーダルの未処理キーをスライドショー入力として待ち続けない。実行が遅れた場合は既存の最大1回の送り規則を適用する。

App の延期は `RunLoop.perform(_:target:argument:order:modes:)` で現在イベントの後へ置く。commit 直前には `NSApplication.nextEvent(matching:until:inMode:dequeue:)` を `.keyDown`・期限は過去・`dequeue: false` で非ブロッキングに照会し、FR-123 の条件で受理できる未処理の Esc／矢印があれば選択変更を延期して通常の AppKit dispatch に任せる。条件外のキーは既存の入力先へ任せ、送りの取消や期限変更の理由にしない。キーを独自に dequeue／再送信したり、run loop を手動で回したりしない。再予約は最大1件とし、commit 時にも session と世代を再照合する。入力 dispatch 前後・未処理キーあり／なし・取消後の callback を検証する。この組み合わせは本機能の調停設計であり、API の呼び出しだけによる自動優先保証ではない。

延期と照会の一次資料: [RunLoop の順序付き perform](https://developer.apple.com/documentation/foundation/runloop/perform(_:target:argument:order:modes:))、[NSApplication の nextEvent](https://developer.apple.com/documentation/appkit/nsapplication/nextevent(matching:until:inmode:dequeue:))。default・eventTracking・modalPanel の必要な mode を明示し、nested tracking 中に通常キーとして受理されないイベントをスライドショー入力に変換しない。

**Alternatives considered**: repeating timer は遅延の追い付きや取消済み callback の扱いが複雑になる。デコード後の待機開始は FR-118 に反する。動画終端イベントによる送りは短い動画で早まり長い動画で遅れる。Task 取消だけでは入力との競合を十分に表せない。

**Primary references**: [Apple: ContinuousClock](https://developer.apple.com/documentation/swift/continuousclock)、[sleep(until:tolerance:)](https://developer.apple.com/documentation/swift/continuousclock/sleep(until:tolerance:)) は deadline・tolerance・取消時の動作を定義する。[local event monitor](https://developer.apple.com/documentation/appkit/nsevent/addlocalmonitorforevents(matching:handler:)) は dispatch 前の受理と `nil` による消費を定義する。ただし nested tracking loop では呼ばれない場合があるため、responder の Esc fallback と action guard も維持する。入力優先の調停方法は、これらの API を組み合わせる本 feature の設計判断であり、OS の自動保証ではない。

## R4 — 一覧更新と閲覧先置換

**Decision**: 表示更新後は最新の一覧・選択を参照し、期限は変更しない。閲覧先の置換前に同期通知で実行を終了・表示復帰へ移す。通知は `resetForNavigation()` の入口へ追加し、既存 `onLocationEvent` とは分ける。rename による場所の付け替えは継続する。

**Rationale**: `onLocationEvent` は HistoryNavigator が使い、通知は変更後である。検索開始や履歴復元では同じ通知が出ないため、単独では停止契約を満たせない。`resetForNavigation` は通常移動・zip 階層・検索置換・履歴復元に共通する。`didRenameFolder` はこの reset を通らず既存の一覧と選択を付け替えるので、場所文字列の変化だけで終了してはならない。外部削除・ボリューム消失の既存経路も、対象0件と置換前通知で覆い、既存の移動先／空表示を保つ。

**Async validation**: 列挙・検索・preview は既存の navigation/preview 世代を再利用する。`reloadCurrentFolder` は現状 folder/archive 一致だけで採用しているので、同じ場所への再移動や検索開始と重なる古い reload も拒否するよう世代を照合する。別機能の振る舞いは変えず、FR-124 と EC-70 の保証に必要な範囲に留める。

**Alternatives considered**: listing URL の監視だけでは rename を誤って終了する。loading 状態だけでは継続中検索を誤って止める。復帰時の再選択は、消えた対象や開始前選択を復活させる。

**Evidence**: `BrowserModel.resetForNavigation`・`didRenameFolder`・`reloadCurrentFolder`・`startSearch`・`showHistoryLocation`・`handleFileSystemEvent`。FR-124〜126、EC-68〜70、FR-104/105/109 の既存規則。

## R5 — 通常ウィンドウへの復帰と全画面

**Decision**: 開始前の通常 layout・focus・3ペイン幅を別の復帰値に保持する。実行中の全画面 enter/exit ではそれを上書きしない。すでに全画面なら `paneLayout`・`focusBeforeFullScreen`・`savedPaneWidths` にある全画面化前の値を使う。Esc／自動終了は session を先に無効化し、全画面解除待ちの復帰情報を保持して一度だけ復帰を完了する。

**Rationale**: 現在の MainSplit は通常の全画面復帰を管理しているが、スライドショーの一時的な preview-only と復帰先は別である。`setPaneLayout` はユーザー用の可否判定を含むため、内部の開始・復帰は履歴を記録しない別入口で適用する。幅は `PaneWidths.dividerPositions` を再利用し、プレビューを残り幅として縮め、不足した分をリスト→ツリーから最小幅まで詰める。window frame は復元しない。選択補完を無効にし、現在の選択だけを可視化する。

**Alternatives considered**: 全画面解除ごとに開始前表示へ戻すと実行中の preview-only が崩れる。ウィンドウサイズや開始前選択の復元は FR-123 に反する。別ウィンドウへ preview を移す必要はない。

**Evidence**: `MainSplitViewController.applyPanePresentation`・`enterFullScreenPresentation`・`leaveFullScreenPresentation` と NSWindowDelegate、`PaneWidths`、`MainWindowController` の最小幅。FR-117/122/123、US11-AS4。

## R6 — 隠れたリストの操作と UI の可否

**Decision**: 既存の `HiddenListNavigation.width` と `moveFocusInHiddenList` を再利用する。新規開始ボタンを toolbar の pane group 直後へ置き、メニュー・⇧⌘S と同じ action／可否判定を使う。PaneCommands に実行状態を加え、ペイン切替・履歴移動を入口でも抑止する。Esc は FR-123 の受理条件を満たす場合だけ local monitor で消費し、`MainWindowController.cancelOperation` も同じ条件で処理済みなら return する fallback を持つ。条件外では既存の編集・モーダル等の処理へ渡し、スライドショーによる全画面解除や検索解除を行わない。

**Rationale**: 現在の hidden width と現在の thumbnail size から列数を求める方式が FR-120 を満たす。すでに隠れている場合は幅を取り直さない。`cancelOperation` は現状全画面解除後に super へ進むため、検索結果の Esc と重ねない明示的な消費が必要。開始判定は「対象あり・非実行・名前編集なし・モーダルなし」を共用する。フォルダ名・お気に入り名・ファイル名の編集をすべて含め、sheet とアプリモーダルも判定する。

**Alternatives considered**: 全画面幅から列数を取り直すと隠す前の移動規則が変わる。メニューを淡色にするだけでは直接 action や shortcut を防げない。実行中に開始ボタンを停止へ変更することは今回の仕様外。

**U1 rationale / alternatives**: モーダルを閉じる Esc とスライドショー終了を重ねる案は既存の非横取り契約に反する。モーダル表示による送り停止や閉じた時点からの3秒再設定は FR-118 の固定周期に新たな例外を加えるため採用しない。入力の受理可否を App で共通判定し、既存の時計と遅延規則を維持する。Core の純粋な可否判断では AppKit 状態を真偽値にして試験し、実際の sheet／アプリモーダルと fallback の接続は GUI で確認する。

**Evidence**: `FileListViewController`、`MainSplitViewController.handleHiddenListKey`・`paneCommands`、`MainToolbarController`、`MainWindowController.cancelOperation`。FR-090/112/114/120/121/123。

## R7 — 履歴・検索・保存

**Decision**: `historyPresentation` の pane layout を実行中だけ復帰先に投影する。形式・サイズ・フィルタ等のユーザー変更は既存の記録経路を維持する。検索結果中の `recordViewChange` 抑止を優先する。実行・deadline・復帰値を Settings や HistoryEntry に追加しない。

**Rationale**: 現状は `historyPresentation` が現在の `paneLayout` を返すため、そのままでは実行中の表示変更で一時的な preview-only を記録してしまう。投影すれば通常時の表示変更と検索中の非記録を両立できる。終了だけでは検索を解除せず、後日の検索解除時には復帰した通常表示を現在履歴へ反映する。

**Alternatives considered**: 実行中の全履歴を抑止すると通常閲覧のユーザー表示変更が失われる。終了時に履歴を巻き戻すとユーザー変更を壊す。HistoryEntry への slideshow フラグ追加は不要。

**Evidence**: `HistoryNavigator.recordViewChange`、`HistoryPresentationHost`、MainSplit の `historyPresentation`。変更後 FR-107、既存 FR-113。

## R8 — 検証と計測

**Decision**: Core は仮想の単調時刻とイベント列で試験し、実時間の描画・入力・全画面は `.app` で検証する。FixtureKit にスライドショー用の混在・単独・空・同名・1秒／10秒動画のセットを加える。既存 `OSSignposter` の Performance 計測方式を使い、開始・選択 commit・矢印受理・停止のイベントをローカル計測する。パス・ファイル名などメディア情報を signpost に含めない。

**Rationale**: 実時間 sleep を単体テストで繰り返すと遅く不安定になる一方、仮想時刻だけでは SC-034/035 や AppKit の dispatch は検証できない。選択 commit の event と画像表示／再生開始を分けることで3秒の対象を正しく測れる。性能値は実装・手動確認後に記録し、計画時点では達成済みにしない。

**Alternatives considered**: 目視のストップウォッチだけでは200ms幅を精密に判定できない。デコード完了時刻の測定は送り間隔とは別。新しい外部計測パッケージや常時ファイルログは不要。

**Evidence**: `AppDelegate` の既存 OSSignposter、`Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift`、`Sources/FixtureKit/`、[既存性能手順](../001-three-pane-media-viewer/quickstart.md)。SC-033〜037。

## Resolution

U1 は R3・R6 に入力受理条件とモーダル中の周期を追記して明確化した。I1（実行中の並べ替え操作経路）は人の判断待ちで、A-51 や並べ替えの操作契約は変更していない。標準 API が200ms以内の scheduling を保証するとは扱わず、SC-034/035 は実機計測で合否を決める。外部依存・憲章例外は追加しない。
