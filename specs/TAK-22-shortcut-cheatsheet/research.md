# Research: TAK-22

**Date**: 2026-10-31 | **Baseline**: `bfe63d5`（origin/master を取り込み済み）

## R1 起動キーと掲載範囲

- Decision: ⌘/。7区分の固定一覧とし、操作条件を説明に含める。
- Rationale: `specs/product/contracts/keyboard-and-menus.md`、`MainMenu.swift`、各ペインの追加メニューに ⌘/ はない。`MainSplitViewController.swift:804` の単独 / はスライドショーの動画再生で、修飾キーなしの条件がある。修飾の区別を実機確認する。
- Alternatives: ⌘? はヘルプ慣習と配列の Shift に依存。実行中メニューから自動収集すると矢印・条件付きキー・標準動画操作が欠ける。キー設定基盤の新設は過大。

## R2 所有と終了

- Decision: MainWindowController が遅延作成して保持する。通常の独立 NSWindow、親単位の終了通知。
- Rationale: `AppDelegate.swift:11` は現在主ウィンドウ1つ。`MainSplitViewController.swift:378` が window.delegate を設定し、同 `:1230` でスライドショー停止を行うため delegate の置換は不可。SettingsWindowController の `isReleasedWhenClosed = false` と再利用が前例。
- Alternatives: singleton は親との関係を失う。child window は移動と重なり順が連動する。sheet/modal は親を操作できない。
- Lifetime: selector observer は親 object を限定。閉じた親を再表示しない状態を持つ。親を閉じた時点で一覧を閉じ、保持状態も破棄できる。生存中の一覧単体の閉じる操作では再利用する。

## R3 ⌘W と入力先

- Decision: `NSWindow.performClose(_:)` を nil target の標準メニューアクションとして追加する。
- Rationale: 現在 MainMenu に Close/⌘W がない。主ウィンドウを明示 target にすると一覧から親を閉じる恐れがある。`AppDelegate.swift:45` は最後のウィンドウ終了でアプリを終了するため親終了に連動させる必要がある。
- Alternatives: アプリ全体のイベント監視は不要。既存 hiddenList monitor は windowNumber と keyWindow を条件にするため一覧へのキーを横取りしない設計を維持する。

## R4 表示の入口とガード

- Decision: AppDelegate を起動 target とし既存親へ転送する。親終了済み・rename・sheet/modal・full screen・slideshow で無効。
- Rationale: 一覧や設定がキーでも同じ親の一覧を前面化する必要がある。ズームの明示 target が既存例（AppDelegate.swift:67）。MainSplitViewController が編集・全画面・スライドショーの既存状態を所有するため、読み取り専用の表示可否を公開し状態を重複保存しない。
- Alternatives: 常時有効は編集の暗黙確定や全画面 Space の移動を招きうる。全画面中の新規補助画面表示は今回の参照用途には含めない。

## R5 翻訳とスクロール

- Decision: Core の安定IDと記号表記を FolzioLocalization の TextKey へ対応させる。LanguageChangeObserver で表示中に更新し、先頭可視IDを復元する。
- Rationale: LocalizationSupport.swift に同期通知と observer の既存実装がある。文字列は {en,ja}.lproj を使い、キー表記は翻訳対象外（FR-147）。行の高さが変わるため単なるスクロールのY座標保存では参照位置がずれる。
- Alternatives: 画面全体を作り直すとフォーカス・位置を失う。HTML/WebView・外部データ取得は不要。

## R6 検証と利用可能な情報

- Decision: カタログ・翻訳は既存 FolzioCoreTests へ追加し、AppKit の振る舞いは実機の契約確認に分ける。
- Rationale: Package.swift のテスト target は Core/Localization を参照し、AppKit のテスト基盤はない。静的な期待値テストだけで実際のキー動作を保証したとは扱わない。
- Alternatives: 今回だけの大規模な GUI テスト基盤は作らない。既存 macOS CI と保守者の quickstart 確認で検証する。
- Access: Linear issue とコメント（0件）を確認。共有ノート API は Tool not found のため取得できなかった。git fetch はネットワーク許可付き sandbox 内で成功。外部APIの置換はせず、実装で新規APIが必要な場合は利用前に公式ヘッダー・文書を確認する。
