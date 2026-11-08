# Research: TAK-85 スワイプのジェスチャで履歴を戻る・進む

調査の基準: 作業ブランチ `claude/brave-knuth-vm9q9a`（`origin/master` の `835b82c` を含む）。
Cloud 環境には macOS と Swift がないため、AppKit の振る舞いは Apple の API の文書の記述と、既存のコードから判断した。
実機でしか確かめられない点は「未確認」と書き、quickstart.md の確認項目にした。

## R1 スワイプの受け取り方（2 本指・Magic Mouse）

- **Decision**: スクロールのイベント（`NSEvent` の `.scrollWheel`）から、AppKit の `NSEvent.trackSwipeEvent(options:dampenAmountThresholdMin:max:usingHandler:)`
  でスワイプを追跡する。追跡を始めるかどうかは、毎回 `NSEvent.isSwipeTrackingFromScrollEventsEnabled` を読んで決める。
- **Rationale**:
  - `isSwipeTrackingFromScrollEventsEnabled` は、システム設定の「ページ間をスワイプ」がスクロールの動き（トラックパッドの 2 本指、Magic Mouse の 1 本指）
    で有効かを返す（AppKit の API 文書）。読むたびに今の設定を返すため、再起動せずに設定の変更が反映される（FR-350）。
  - `trackSwipeEvent` は、指の量に合わせた `gestureAmount`（-1〜1）と、終了の `phase`（`.ended` は成立、`.cancelled` は取り消し）を返す。
    実行に必要な量と、指を戻したときの取り消しの判定は OS が行う（spec の Assumptions。独自のしきい値を持たない）。
  - `dampenAmountThresholdMin` / `max` に、使えない向きを 0 で渡すと、その向きには量が伸びない。追跡を始めるときに `min = canGoForward ? -1 : 0`、
    `max = canGoBack ? 1 : 0` を渡し、どちらの向きかを自分で決めずに OS の `gestureAmount` に従う（R4）。
- **Alternatives considered**:
  - スクロールの量を自分で積算してしきい値で判定する: 慣性・取り消しの振る舞いが標準のアプリと変わり、しきい値を独自に決めることになるため採らない。
  - `NSPanGestureRecognizer`: トラックパッドの 2 本指のスクロールは pan として認識されないため使えない。

## R2 スワイプの受け取り方（3 本指）

- **Decision**: `.swipe` の種類のイベント（`NSEvent.EventType.swipe`）を受け取り、`deltaX` の符号で戻る・進むを決める。途中の量はないため、受け取った時点で実行し、
  矢印を短く表示する（EC-242）。
- **Rationale**: システム設定が「3 本指でスワイプ」（または「2 本指か 3 本指」）のとき、3 本指の左右のスワイプは、スクロールではなく 1 回の `.swipe`
  のイベントとして届く（AppKit の `swipe(with:)` の文書）。
- **未確認**: システム設定が「2 本指か 3 本指でスワイプ」のとき、3 本指のスワイプが `.swipe` とスクロールのイベントの両方で届くか（届くと 1 回で 2 件移る恐れがある。
  quickstart.md の Q3）。両方で届く場合は、`.swipe` を受け取ったジェスチャのスクロールを追跡しない、などの対策を保守者と決める。
- **未確認**: `deltaX` の符号と戻る・進むの対応。Chromium・Firefox の実装と同じく「`deltaX > 0` を戻る」と置き、実機で Safari と同じ向きかを確かめる
  （quickstart.md の Q3）。逆なら Core の対応表の 1 か所を直す。

## R3 イベントを受け取る場所

- **Decision**: `MainSplitViewController` に、`NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .swipe])` のモニタを 1 つ置く。
  - 対象は、メインウインドウに届いたイベントで、1 回のスクロールの `.began` のときにポインタの下のビューが 3 ペイン（ツリー・ファイルリスト・プレビュー）
    のどれかのビューの中にあったものだけ（EC-245）。対象かどうかは `.began` のときだけ判定し、そのスクロールの終わりまで同じ結果を使う（R7）。
  - スワイプとして扱うと決めたイベントは、モニタで `nil` を返して、下のビューに渡さない。それ以外はそのまま渡す。
- **Rationale**:
  - スクロールのイベントは、ファーストレスポンダではなく、ポインタの下のビューへ届き、`NSScrollView` が受け取って使う。ペインごとに `scrollWheel(with:)`
    を上書きすると、ツリー・リスト形式・サムネイル形式・プレビューの画像・動画の 5 か所以上に同じ処理が散らばる。
  - 既存の `installVideoSeekKeyMonitor()`（`Sources/FolzioApp/App/MainSplitViewController.swift:839`）が、同じ `addLocalMonitorForEvents` の形で
    キーを 3 ペインに共通に処理している。
  - モニタは、ウインドウの `sendEvent` より前に呼ばれるため、横スクロールの前に判定できる。
- **未確認**: `trackSwipeEvent` を、ビューの `scrollWheel(with:)` ではなくローカルモニタの中から呼んで動くか。API 文書は「スクロールのイベントの処理の中で呼ぶ」
  と書くだけで、モニタからの呼び出しを禁じていない。実装の最初に保守者の macOS で確かめる（tasks.md の Phase 2、quickstart.md の Q1）。
  - 動かない場合の代わり: メインウインドウを `NSWindow` のサブクラスにして `sendEvent(_:)` の中で同じ判定をする。判定の Core は変わらない。
- **Alternatives considered**: 各ペインの `scrollWheel(with:)` の上書き（上記の理由で採らない）。

## R4 横スクロールとの区別

- **Decision**: 1 回のスクロール（`phase` が `.began` から `.ended` / `.cancelled` まで。慣性の `momentumPhase` を含む）ごとに、Core の
  `SwipeGestureTracker` が状態を持つ。
  - `.began` のとき、ポインタの下のペインが左右にあとどれだけスクロールできるか（`HorizontalScrollRoom`）を記録する。
  - その後、左右の動きが主（|dx| > |dy|）の最初のイベントで決める（EC-239）。`.began` のイベント自体に動きがあれば、そのイベントで決める。
  - 横スクロールの余地は、`scrollingDeltaX` の符号の向き（`> 0` は左側が見える向き）で調べる。`.began` で記録した余地がその向きに残っていなければスワイプとして追跡し、
    残っていれば、その 1 回のスクロールの終わりまで横スクロールとして扱う（FR-351、US7-AS19）。
  - 戻る・進むの向きは、`scrollingDeltaX` からは決めず、追跡中の `gestureAmount` の符号だけで決める（data-model.md の「向きの扱い」）。
    向きの情報源を 1 つにして、OS の判定と食い違わないようにするため。
  - 新しい `.began` を受け取ったら、前の追跡が終わっていなくても判定し直す。追跡を終えた後の同じジェスチャの慣性は、次の `.began` まで渡さない。
  - `.began` は判定の前にビューへ渡すため、スワイプと決めた後も、同じジェスチャの `.ended` / `.cancelled` はビューへ渡し、`NSScrollView` に始まりだけが残らないようにする。
    - **未確認**: `trackSwipeEvent` を始めた後、`.ended` がモニタに届くか（AppKit の追跡が受け取ってしまわないか）と、届かない場合に `NSScrollView`
      のスクロールバーなどが残るか（quickstart.md の Q4）。
    - 残る場合の代わり: `.began` をモニタで止めて保持し、横スクロールと決めたときに、保持した `.began` をポインタの下のビューの `scrollWheel(with:)`
      に先に渡してから、そのイベントを渡す。
  - 慣性で表示が動いている途中に始めたスクロールは、常に横スクロールとして扱う（保守者の決定、2026-11-08。spec の FR-351）。直前の慣性のイベントの時刻で判定する（data-model.md）。
  - 上下の動きが主のとき、慣性のイベント、`.began` を受け取っていないスクロール（マウスホイールなど、`phase` のないもの）は、スワイプにしない。
- **Rationale**:
  - 「端に着いた状態で新しく始めたスワイプだけ」（保守者の決定）は、`.began` の時点の余地で判定すれば満たせる。スクロールの途中で端に着いても、
    同じ 1 回のスクロールの状態は横スクロールのまま変わらない。
  - `scrollingDeltaX` は、OS のスクロールの方向の設定（ナチュラル）を反映した値（`ImagePreviewView.swift:223` のコメントと同じ）。ビューのスクロールも
    同じ値で動くため、余地の判定には `scrollingDeltaX` の符号がそのまま使える。
  - 戻る・進むの向きを `scrollingDeltaX` から決めると、ナチュラルなスクロールの設定で OS の判定（`gestureAmount`）と食い違う恐れがあるため、使わない。
- **未確認**: `gestureAmount` の符号（正を戻るとする。Firefox の実装と同じ）が、ナチュラルなスクロールのオン・オフのどちらでも Safari の向きと同じか（quickstart.md の Q2）。
  あわせて、端の判定の向き（余地の向き）と、OS が戻る・進むと判定する向きの組み合わせが、オン・オフで期待どおりか（左端に着いた画像で戻るになるか）を確かめる。

## R5 スクロールできる余地の求め方

- **Decision**: ポインタの位置で `hitTest` したビューから上へたどり、最初に見つかったものの余地を使う。3 ペインのルートで止める。
  - `HorizontalScrollRoomProviding` に適合するビュー（`ImagePreviewView`）: 画像の表示位置（`PreviewScrollLayout`）から求める。
  - `NSScrollView`: `contentView.bounds`（見えている範囲）と `documentView.frame`（内容の範囲）の左右の端の差から求める。
  - どれもなければ、余地なし（EC-243。サムネイル形式・はみ出していない一覧・動画・空のプレビュー）。
- **Rationale**:
  - `ImagePreviewView` は `NSScrollView` を使わず、独自にスクロールしている（`ImagePreviewView.swift:210-225`）。
  - リスト形式（`ListModeView.swift:117`）・ツリー（`DirectoryTreeViewController.swift:111`）・サムネイル形式（`ThumbnailModeView.swift:404`）は
    `NSScrollView` で、横のスクロールバーを出していなくても、内容が広ければトラックパッドで横にスクロールできる。
  - 余地の計算（端の比較と誤差）は Core の `HorizontalScrollRoom` に置き、App は数値を渡すだけにする（AGENTS.md の設計の制約）。

## R6 矢印の表示

- **Decision**: メインウインドウの子ウインドウ（枠なし・透明・`ignoresMouseEvents`）を、3 ペインの領域（`splitView` の画面上の範囲）に重ね、
  その左端または右端に矢印を描く。スワイプの間だけ表示し、終わったら隠す。
  - 矢印は SF Symbols の `chevron.left` / `chevron.right` を円の背景に置いた記号とし、文字を含まない（spec の Assumptions。翻訳を増やさない）。
  - 大きさと不透明度を `gestureAmount` の絶対値に合わせて変える（FR-352）。OS の「視差効果を減らす」がオンのときは、消すときのフェードを省く（憲章 原則 III）。
  - アクセシビリティの要素にしない。
- **Rationale**:
  - ウインドウの `contentViewController` は `MainSplitViewController` で、`contentView` は `NSSplitView` そのもの（`MainWindowController.swift:35`）。
    `NSSplitView` に部品を `addSubview` すると、ペインとして扱われる恐れがある。AGENTS.md の AppKit UI の不変条件（起動不能の事故）に触れる構成の変更を避ける。
  - 子ウインドウは、既存のビュー階層と制約に触れず、親ウインドウと一緒に動く。
  - 子ウインドウを `orderOut` すると親から外れるため、表示するたびに `addChildWindow(_:ordered:)` で付け、その時点の `splitView` の範囲にフレームを合わせる。
    隠すときは `removeChildWindow(_:)` してから `orderOut` する。
- **Alternatives considered**:
  - `contentViewController` を、`MainSplitViewController` を子に持つ入れ物に変える: ウインドウの構成とフォーカス・フルスクリーンの処理（`MainSplitViewController`）
    への影響が大きいため採らない。
  - 左端・右端のペインのビューに矢印を入れる: 見えているペイン（FR-088 のペインの表示切り替え）に合わせて付け替える処理が要り、3 つのペインのレイアウトに触れるため採らない。
  - 一覧を指に合わせて動かす: 保守者の決定で採らない（spec の Clarifications）。

## R7 使えるかどうかの判定

- **Decision**: 既存の `paneCommands.canNavigateHistory` と `historyNavigator.canGoBack` / `canGoForward`（`MainSplitViewController.swift:1054-1063`）
  を、追跡を始めるときに読み、`trackSwipeEvent` の min / max に渡す（使えない向きには量が伸びず、矢印も出ない）。
  戻る・進むの向きは追跡が始まるまで分からない（R4）ため、どちらかが使えれば追跡を始める（片方だけが使えるときの、使えない向きの 1 回の動きは何もしない。EC-239）。
  3 本指のスワイプは、向きが `deltaX` で分かるため、その向きが使えるときだけ矢印を出して実行する。スワイプが成立したら既存の
  `goBack(_:)` / `goForward(_:)` を呼び、終わりの時点の判定（EC-240）はその guard に任せる（Core に同じ条件を重ねて持たない）。
  - 加えて、メインウインドウがキーウインドウである、メインウインドウにシートがない、アプリのモーダルがない、イベントがメインウインドウのもの、
    ドラッグの途中でない、を条件にする（EC-244）。スクロールのイベントはキーウインドウでなくてもポインタの下のウインドウに届くため、
    キーウインドウの条件がないと、設定・ショートカット一覧・Quick Look が前面のときも後ろのメインウインドウでスワイプが効いてしまう。
  - 対象かどうか（3 ペインの中、上の条件）は、1 回のスクロールの `.began` のときだけ判定し、その結果をそのスクロールの終わりまで使う。
    途中でポインタが境界線を越えても状態が途切れず、イベントごとの `hitTest` もしない。
  - ドラッグの途中は、マウスのボタンが押されている（`NSEvent.pressedMouseButtons` が 0 でない）か、Folzio のビューから始めたドラッグの途中か、で判定する。
    ボタンを押さないドラッグ（アクセシビリティの 3 本指のドラッグなど）でスワイプのイベントが届くかは未確認で、quickstart.md で確かめる。
- **Rationale**: ⌘[ / ⌘] と同じ条件（FR-112・FR-113）を、同じ関数で満たす。`goBack(_:)` の中でも同じ判定をしているため、二重に実行されない。
  検索結果の表示中の「戻る」（FR-113）も `historyNavigator.canGoBack` がすでに扱っている（`HistoryNavigator.swift:30-37`）。

## R8 テストの範囲

- **Decision**:
  - Core（Swift Testing）: `SwipeGestureTracker` の状態遷移（向き、余地、上下の動き、慣性、使えない向き、1 回のスワイプで 1 回）、
    `HorizontalScrollRoom` の計算、`PreviewScrollLayout` からの余地、3 本指の `deltaX` の対応、矢印の表示の量。
  - App（Swift Testing）: `NSScrollView` の余地の読み取り、`ImagePreviewView` の余地。
  - 実機の操作（ジェスチャ・向き・矢印の見た目・ローカルモニタでの追跡）は、CI では確かめられないため、quickstart.md で保守者が確かめる。
- **Rationale**: 憲章 原則 IV（コアロジックの自動テスト）。ジェスチャのイベントは合成できないため、判定を Core に寄せてテストする。

## R9 文書

- **Decision**: 契約 `specs/product/contracts/keyboard-and-menus.md` の「履歴の移動」に、スワイプの行と条件を加える（反映のとき）。
  ユーザーガイド `docs/usage.ja.md`・`docs/usage.md` の「フォルダ移動とお気に入り」に、戻る・進むの手段（⌘[・⌘]・ツールバー・スワイプ）と、
  横スクロールとの関係を短く書く。README は戻る・進むを書いていないため変えない。
- **Rationale**: 今のユーザーガイドは、戻る・進むを検索の節（`docs/usage.ja.md:370`）でしか書いていない。スワイプは見えない操作のため、ガイドに書かないと見つけにくい。
