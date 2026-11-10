# Research: TAK-89 スライドショーのボタンを開始・停止のトグルにする

調査の基準: `origin/master`（`835b82c`）。GUI での動作は未確認で、AppKit の挙動は保守者の確認（quickstart.md）で確かめる。

## R1 状態の判定を Core の値型に分ける

- **Decision**: `FolzioCore` に `SlideshowToggleState` を加える。入力は `canStart`（`SlideshowStartPolicy.canStart`）、`isActive`、`isRestoring`、
  `hasSheet`、`hasAppModal`、`isEditingText` の 6 つ。出力は `isOn`、`isEnabled`、`action`（`.start` か `.stop`）。
  - `isOn = isActive && !isRestoring`（FR-350。復帰中はオフ）
  - `action = isOn ? .stop : .start`
  - 実行中の `isEnabled = !hasSheet && !hasAppModal && !isEditingText`（FR-352。キー入力先の条件は含めない）。
    型の中で `SlideshowInputPolicy(isActive:isRestoring:isTargetWindowKey: true, hasSheet:hasAppModal:isEditingText:menuOwnsInput: false).acceptsKeys` として求める
  - 停止中の `isEnabled = canStart && !isRestoring`。今も復帰中は `SlideshowStartPolicy` が `false` を返す（`PaneLayout.swift:276`）が、
    型の中で「復帰中は無効」（FR-352・EC-239）を保証する（コードレビューの指摘）
- **Rationale**: 憲章 原則 IV の「コアロジックは UI から分離し、単体でテスト可能に保つ」。今の `SlideshowInputPolicy`・`SlideshowStartPolicy`
  （`Sources/FolzioCore/Model/PaneLayout.swift`）と同じ形にし、真理値表でテストできる（`Tests/FolzioCoreTests/SlideshowInputPolicyTests.swift` と同じ方法）。
  - 実行中の条件を `SlideshowInputPolicy` から求めるのは、A-209 が「Esc の受理の条件と揃える」と決めており、条件の出どころを1つにするため。
    FR-123 の条件が後で変わったとき、ボタンの条件だけが古いまま残らない（コードレビューの指摘）
- **Alternatives considered**:
  - App 側で `SlideshowInputPolicy` を `isTargetWindowKey: true` で直接使う: ボタンの判断（オン・オフ、押したときの操作、停止中の条件）が App に散らばる。
    `SlideshowToggleState` の中に閉じ込めて使う。キー入力向けの `menuOwnsInput` は、型の中で `false` に固定する
  - `SlideshowToggleState` の中で 3 つの条件を書き直す: Esc の条件と二重になり、片方だけ変わる恐れがある。採らない
  - App 側で直接 `if` を書く: テストできない。採らない

## R2 ボタンを OS 標準のトグルにし、ツールバーのコントローラで受ける

- **Decision**: ボタンを `setButtonType(.pushOnPushOff)` にし、`state` をオン・オフに使う。ボタンとツールバー項目のアクションは、
  `MainToolbarController` の `slideshowToggled(_:)` にする。これは `panes.toggleSlideshow(_:)` を呼んだ後、ボタンの状態を実際の実行状態で上書きする。
  - `.pushOnPushOff` のボタンは、押すとアクションの前に AppKit が `state` を反転する。開始の条件が直前に崩れて何もしなかった場合に、表示が実行状態とずれるため、上書きする
  - アクセシビリティでは、トグルのボタンとしてオン・オフの値が読まれる（FR-353・US77-AS8。GUI で確認する）
- **Rationale**: FR-350 の「OS の標準のトグルボタンの表示」。表示形式の切り替えなど既存のツールバーの操作も、ツールバーのコントローラが受けてから
  ビューへ渡している（`zipVisibilitySelected(_:)`、`MainToolbarController.swift:397`）。
- **Alternatives considered**:
  - アイコンを停止のアイコンに差し替える: Issue は「トグルのオン状態で実行中であることを示す」と書いている。項目の見た目が状態で変わると、
    カスタマイズの画面の見本と食い違う。採らない
  - アクションの target を `MainSplitViewController` のままにする: 押した後の表示の上書きを、表示を持たないビューコントローラが行うことになる。採らない

## R3 停止は Esc と同じ処理を使う

- **Decision**: `MainSplitViewController.toggleSlideshow(_:)` は、`slideshowToggleState` を計算し直し、`isEnabled` でなければ何もしない。
  `action` が `.start` なら今の `startSlideshow(_:)` を、`.stop` なら `slideshowCoordinator.stop()` を呼ぶ。
- **Rationale**: Esc の停止は、受理の確認の後に `slideshowCoordinator.stop()` を呼ぶ（`MainSplitViewController.swift:648`、
  `SlideshowCoordinator.handleKeyEvent` の `keyCode == 53`）。`stop()` が送りと切り替え効果の取消、実行状態の更新、表示の復帰（全画面の解除を含む）を行う
  （`SlideshowCoordinator.swift:92`）。同じ関数を呼べば、FR-351 と SC-187 の「Esc と同じ」を満たす。
  - 押した時点で状態を計算し直すのは、表示の更新が遅れた場合にも条件を守るため（EC-239）
- **Alternatives considered**: `handleSlideshowEscapeFallback()` を呼ぶ: キー入力先の条件を含むため、設定ウインドウが前面のとき止まらない（US77-AS7 に反する）。採らない

## R4 実行状態の変化をボタンへ伝える経路

- **Decision**: 今の `onSlideshowAvailabilityChange` → `MainToolbarController.updateSlideshowAvailability()` の経路で、`isEnabled` に加えて
  `state`・アクセシビリティラベル・ツールチップ・説明も適用する（`applySlideshowState(to:)` にまとめる）。
- **Rationale**: `SlideshowCoordinator` は開始・停止・復帰の終わり・即時停止のすべてで `slideshowAvailabilityDidChange()` を呼び
  （`SlideshowCoordinator.swift` の `start`・`stop`・`stopImmediately`）、`MainSplitViewController` がそれを `onSlideshowAvailabilityChange` に流す
  （`MainSplitViewController.swift` の `slideshowAvailabilityDidChange`）。自動終了（`listingDidChange`・`commitPendingDue`）と閲覧先の変更
  （`handleWillReplaceLocation`）も `stop()` を経るので、SC-186 の経路はすべてこの通知を通る。
  - 名前の変更の開始・終了は、すでに `observeEditingAvailability()`（`MainToolbarController.swift`）が通知している
  - 表示言語の切り替えは、既存の文言の更新（`MainToolbarController.swift:164` のループ）で、状態に合った文言を選ぶ
- **Alternatives considered**: KVO で `isActive` を監視する: 通知の経路がすでにあり、二重になる。採らない

## R5 実行中のシートの開閉でボタンを更新する

- **Decision**: メインウインドウの `NSWindow.willBeginSheetNotification` と `NSWindow.didEndSheetNotification` を監視し、`DispatchQueue.main.async` で 1 回遅らせて
  `updateSlideshowAvailability()` を呼ぶ。
  - `willBeginSheetNotification` は名前のとおりシートが付く前に送られるため、その時点では `attachedSheet` がまだ nil の恐れがある（分析の C2）。
    既存の編集の監視（`observeEditingAvailability()`）も同じく 1 回遅らせている
- **Rationale**: 今はシートの開閉でツールバーの状態を更新する経路がない（`Sources/FolzioApp` に該当する監視がない）。停止中は、シートの表示中に AppKit が親のウインドウへの
  クリックを止めるため、問題が表に出なかった。実行中は、FR-352 のとおりシートの間にボタンを無効の表示にするため、更新が要る。
  - 実行中にシートが出る経路は、ファイルのコピー・移動の途中の衝突のダイアログと、終わった後の失敗の表示（`FileOperationCoordinator.swift` の `transferItems`・`presentFailures`）
- **アプリモーダル**: 開閉の公開の通知がない。実行中に出る経路も見つかっていない（`runModal` は `ConfirmationPresenter.swift:94` の、ウインドウがないときだけ）。
  押した時点の再計算（R3）と、モーダルの間に AppKit がほかのウインドウへのクリックを止めることで条件を守る。表示の更新のための監視は加えない（憲章 原則 V）
- **Alternatives considered**:
  - タイマーで定期的に検査する: 不要な処理になる。採らない
  - `NSToolbarItem` の派生型で `validate()` を上書きし、AppKit の項目の検証（`validateVisibleItems`）で状態を反映する（コードレビューの指摘）:
    シートとアプリモーダルを、通知なしで反映できる利点がある。しかし、今のツールバーの項目は、どれも通知を受けて状態を適用する形で、`NSToolbarItem` の派生型はない
    （拡大・縮小・サイズ・表示形式は `applyZoomAvailability` などで適用する）。この項目だけ別の形にすると、ツールバーの状態の更新の仕組みが2つになる。
    また、AppKit が検証を呼ぶ時機は、イベントのたびのウインドウの更新に従う。ファイル操作の途中で、ユーザーの操作なしにシートが出たときに、すぐ検証されるかは確かめていない。
    実行中にアプリモーダルが出る経路は見つかっておらず、押した時点の再計算（R3）で条件は守れる。そのため採らない。ツールバー全体の状態の更新を検証の形へ改めるなら、別の Issue で扱う

## R6 文言

- **Decision**: `TextKey` に 1 つ加える。
  - `toolbarStopSlideshowHelp`（`toolbar.stopSlideshowHelp`）: 「スライドショーを停止（Esc）」 / 「Stop Slideshow (Esc)」。ツールチップとアクセシビリティの説明。引数なし
- **Rationale**: Esc はスライドショーの終了の固定のキーで、割り当てを変えられない（`ShortcutCatalog.swift:160` の `slideshowStop` はコマンドを持たない）。
  そのため、開始の文言（`toolbar.startSlideshowHelp`、引数でキーを受ける）と違い、引数を取らない。停止中の説明は今のまま（`toolbarStartSlideshowHelp`）。
  - アクセシビリティラベルは、どちらの状態でも項目名と同じ `toolbarSlideshowLabel`（「スライドショー」）にする（A-211）。今の `menuViewStartSlideshow` の使用はやめる。
    トグルのボタンは VoiceOver がオン・オフの値も読むため、ラベルで状態を伝えると二重になる（設計のレビュー）
  - 翻訳の検査（`CatalogConsistencyTests` の両言語の網羅・書式の一致・参照・翻訳者向けの説明）に自動で含まれる。
    説明（`TextKey` の翻訳者向けの記述）を加える
- **Alternatives considered**:
  - メニューの「スライドショーを開始」のキー（`menuViewStartSlideshow`）に合わせて `menuViewStopSlideshow` を作る: メニューには停止の項目を置かない（A-208）。採らない
  - アクセシビリティラベルを「スライドショーを停止」に切り替え、トグルの値を出さない（役割を普通のボタンにする）: 役割を上書きする処理が増える。
    状態を値で伝える、トグルの一般的な形にしない理由がない。採らない（保守者の決定）

## R7 あふれたメニューと文字だけの形式

- **Decision**: ツールバー項目の `action` も `slideshowToggled(_:)` にする。あふれたメニューの項目は、名前を「スライドショー」のままとし、実行中は `state` を `.on` にしてチェックマークを付ける（spec の EC-240）。
  そのため、項目に `menuFormRepresentation`（名前は `toolbarSlideshowLabel`、アクションは `slideshowToggled(_:)`、target はツールバーのコントローラ）を明示し、
  ツールバーのコントローラの `validateMenuItem(_:)` で `isEnabled` と `state` を適用する。
- **Rationale**: ビューを持つ項目のあふれたメニューの既定の表示が、状態をどう扱うかは確かめていない。明示した項目なら、メニューの検証の経路（`NSMenuItemValidation`）で状態を決められる。
  - 文字だけの形式は OS が項目名を描き、オン・オフの印を独自に描かない（A-210）。押したときの操作は `action` で同じになる
- **未確認**: あふれたメニューと文字だけの形式での表示と動作は、保守者の GUI 確認で確かめる（quickstart.md の 6）

## R8 テストの範囲

- **Decision**: 自動テストは `SlideshowToggleState` の真理値表（64 通り）と、文言の翻訳の検査。AppKit のボタンの見た目・クリック・あふれたメニューは、保守者の GUI 確認で確かめる。
- **Rationale**: 憲章 原則 IV の「UI の見た目そのものの自動テストは必須としない」。既存の `Tests/FolzioAppTests` にツールバーのテストはなく、
  ツールバーの生成にはウインドウと `MainSplitViewController` 全体が要る。

## R9 キー入力先でないウインドウへの最初のクリック（未確認）

- **Decision**: US77-AS7（設定ウインドウが前面のときにボタンで止める）は、1 回のクリックで止まるかを保守者の GUI 確認（quickstart.md の 6）で確かめ、
  結果に応じて扱いを決める。確認の前に、`acceptsFirstMouse(for:)` を上書きするボタンの派生型は作らない（憲章 原則 V）。
- **Rationale**: `NSView.acceptsFirstMouse(for:)` の既定は `false` で、キー入力先でないウインドウへの最初のクリックは、ウインドウを前面にするだけで
  ビューへ届かないことがある。ツールバーのボタンがこれにどう従うかは、確かめていない（コードレビューの指摘）。
  - 1 回で止まらなくても、最初のクリックでメインウインドウがキー入力先になるため、2 回目のクリックか Esc で止められる。FR-352 の「キー入力先でないことでは無効にしない」は、
    無効の表示にしないという意味で、どちらの結果でも成り立つ
- **確認の後**: 1 回で止まらなければ、保守者と相談する。US77-AS7 を「2 回目のクリックで止まる」に直すか、ボタンを派生型にして最初のクリックを受けるかを決める。
  前者なら、A-209 の「最初のクリックが届くかは確かめていない」の項目も、確かめた結果に直す
