# Contract: ツールバーの「スライドショー」ボタン（TAK-89）

反映先は `specs/product/contracts/keyboard-and-menus.md` と `specs/product/contracts/localization.md`。反映の時に、決定後の本文だけを移す。

## keyboard-and-menus.md の「スライドショー」の表

| 操作 | 動作 | 要件 |
|------|------|------|
| ⇧⌘S / 表示 > スライドショーを開始 | スライドショーを開始する。 | FR-114 |
| ツールバーの「スライドショー」ボタン | 停止中は開始し、実行中は停止する。 | FR-114・FR-350〜353 |
| Esc（実行中で入力受理条件を満たす） | スライドショーを終了する。 | FR-123 |

- ⇧⌘S / 表示 > スライドショーを開始: 今の「表の詳細」のまま（実行中は無効）
- ツールバーの「スライドショー」ボタン:
  - 実行中はオンの状態で表示する。停止は Esc と同じ終了の処理を行う
  - 実行中は、シート・アプリモーダル・名前の変更の編集の間だけ無効。表示の復帰中は無効でオフ

## keyboard-and-menus.md の「ツールバー」の表

| 操作 | 動作 | 要件 |
|------|------|------|
| 「スライドショー」ボタン | 停止中は ⇧⌘S と同じ。実行中は Esc と同じ。 | FR-114・FR-351 |

## localization.md の「ツールバー」の表

| 項目 | 日本語（名前・ツールチップ） | 英語 |
|---|---|---|
| スライドショー | 下記 | 下記 |

- 停止中: 「スライドショーを開始 / スライドショーを開始（⇧⌘S）」、`Start Slideshow / Start Slideshow (⇧⌘S)`（今と同じ）
- 実行中: 「スライドショーを停止 / スライドショーを停止（Esc）」、`Stop Slideshow / Stop Slideshow (Esc)`
- ツールバー上の項目名は、どちらも「スライドショー」 / `Slideshow`

## 文言のキー（Localizable.strings）

| キー | 日本語 | 英語 | 引数 |
|---|---|---|---|
| `toolbar.stopSlideshow` | スライドショーを停止 | Stop Slideshow | なし |
| `toolbar.stopSlideshowHelp` | スライドショーを停止（Esc） | Stop Slideshow (Esc) | なし |
