# Research: Folzio について（About）ダイアログ

## R1 標準の About パネルを使わない

- **Decision**: `NSApp.orderFrontStandardAboutPanel` は使わず、自前のウィンドウを作る。
- **Rationale**: 標準パネルは Credits・著作権・ビルド番号を自動で表示し、閉じるボタンのみの体裁・クリック可能な URL 一つだけという要件（FR-234〜237）を細かく制御しにくい。タイトルの扱いと言語の即時切り替えも、アプリ管理の文言として揃えるには自前の方が単純。Issue も標準パネルの実装は Sources にないと記録している。
- **Alternatives**: `orderFrontStandardAboutPanel(options:)` — Credits で近づけられるが、リンクの見た目・Tab 到達・言語切り替えの即時反映を保証しにくい。

## R2 バージョンの取得元

- **Decision**: `Bundle.main` の `CFBundleShortVersionString` を実行時に読む。取得できない（`swift run`、値が空・文字列以外）ときはバージョン行を作らない。
- **Rationale**: `.app` は `scripts/make-app.sh` が Info.plist にこの値を書き（既定 0.1.0、配布時は Release のタグと一致。FR-171）、コードに版を重複して持たないで済む。`swift run` では `Bundle.main` に Info.plist がなく nil になる。誤った版（固定の 0.1.0 など）を見せるより、行を省くほうが安全（保守者が決定）。
- **Alternatives**: コードに版の定数を持つ — `make-app.sh` と食い違う危険がある。「開発ビルド」などの固定文言 — 保守者が不採用。

## R3 リンクを開く方法と FR-041 / 憲章原則 I

- **Decision**: `NSWorkspace.shared.open(URL)` に固定 URL を渡す。`URLSession` など通信の API は使わない。
- **Rationale**: 既存の使用例が `FileListViewController` にある。アプリ自身は通信せず、URL を OS に渡して既定のブラウザに任せるだけなので、「閲覧・操作に関する情報を外部に送信しない」「全機能がオフラインで動作する」（FR-041）を満たす。オフラインでもウィンドウとバージョン表示は完全に動作し、リンク先が開けるかはブラウザの責任（EC-165）。`scripts/check-no-network.sh` は通信 API の使用だけを禁止するため、通る見込み（実装時に確認）。
- **Alternatives**: アプリ内の Web ビュー — ネットワーク API の利用に当たり、不採用。

## R4 リンクの実装

- **Decision**: 枠なしの `NSButton` に属性付き文字列（`.linkColor`・下線）を設定する。
- **Rationale**: `NSButton` は標準で Tab・Space・Return のキー操作に対応し、`canBecomeKeyView` を上書きするだけで FR-040 を満たせる。`NSTextField` の `.link` 属性は選択可能な編集可能テキストの設定が要り、フォーカスとキー操作が分かりにくい。アクセシビリティは role を `.link` にする。
- **Alternatives**: `NSTextView`＋`.link` 属性 — 文字選択やキー操作の追加検証が増え、YAGNI に反する。

## R5 メインウィンドウを閉じたときの扱い

- **Decision**: メインウィンドウを閉じたら、設定ウインドウと同じく About も閉じる。
- **Rationale**: 既存の `AppDelegate.mainWindowWillClose` が設定ウインドウを閉じ、`applicationShouldTerminateAfterLastWindowClosed` が `true` のため、ウィンドウが残るとアプリが終了しない。同じ扱いにすれば、ダイアログだけが残る状態を避けられる。
- **Alternatives**: 残す — アプリが終了しない・親のない補助画面が残る、という既存の設計に反する挙動になる。

## R6 ウィンドウ名とタイトルバー

- **Decision**: `window.title` に「Folzio について」を設定し、`titleVisibility = .hidden` で画面からは隠す。最小化・ズームのボタンは非表示にする。
- **Rationale**: 画面にはタイトルを出さず（参考とした About の体裁）、VoiceOver とウィンドウ一覧には正しい名前を残せる。
- **Alternatives**: `title = ""` — アクセシビリティ上の名前がなくなる。

## R7 版の文言

- **Decision**: 「Version 0.1.0」／「バージョン 0.1.0」の形にし、`about.version` に `%@` で数値を渡す。
- **Rationale**: 既存の `TextKey` の引数付き文言の仕組みを使え、数値は翻訳・変形されない（FR-147）。
