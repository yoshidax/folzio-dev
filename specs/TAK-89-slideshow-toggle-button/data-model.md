# Data Model: TAK-89 スライドショーのボタンを開始・停止のトグルにする

永続化するデータはない。ボタンの状態は、その時点の実行状態から毎回計算する。

## SlideshowToggleState（FolzioCore、値型）

| 入力 | 意味 | 出どころ（App） |
|---|---|---|
| `canStart` | FR-114 の開始の条件を満たす | `MainSplitViewController.canStartSlideshow`（`SlideshowStartPolicy`） |
| `isActive` | 実行中 | `SlideshowCoordinator.isActive` |
| `isRestoring` | 全画面の解除を待つ表示の復帰中 | `SlideshowCoordinator.isRestoring` |
| `hasSheet` | 対象ウィンドウにシートがある | `view.window?.attachedSheet != nil` |
| `hasAppModal` | アプリモーダルがある | `NSApp.modalWindow != nil` |
| `isEditingText` | 名前の変更の編集欄が入力を受けている | `fileListViewController.isEditingText` |

| 出力 | 規則 | 要件 |
|---|---|---|
| `isOn` | `isActive && !isRestoring` | FR-350 |
| `action` | `isOn` なら `.stop`、それ以外は `.start` | FR-351 |
| `isEnabled` | `isOn` なら `!hasSheet && !hasAppModal && !isEditingText`、それ以外は `canStart && !isRestoring` | FR-352 |

- 実行中の条件は、`SlideshowInputPolicy` に `isTargetWindowKey: true`・`menuOwnsInput: false` を渡した `acceptsKeys` で求め、Esc の受理の条件と出どころを1つにする（A-209、research.md の R1）
- 停止中の条件に `!isRestoring` を含めるのは、`canStart` の計算に頼らず、型の中で「復帰中は無効」（FR-352・EC-239）を保証するため

## 状態の遷移（ボタンから見た表示）

| 実行状態 | オン・オフ | 有効・無効 | 文言（ラベル / ツールチップ） |
|---|---|---|---|
| 停止中 | オフ | 開始の条件に従う | スライドショーを開始 / スライドショーを開始（⇧⌘S） |
| 実行中（シート・モーダル・編集なし） | オン | 有効 | スライドショーを停止 / スライドショーを停止（Esc） |
| 実行中（シート・モーダル・編集のいずれか） | オン | 無効 | スライドショーを停止 / スライドショーを停止（Esc） |
| 表示の復帰中 | オフ | 無効 | スライドショーを開始 / スライドショーを開始（⇧⌘S） |

- `isActive` と `isRestoring` は同時に真にならない（`SlideshowCoordinator.stop()` が `isActive = false` の後に `isRestoring = true` にする）。
  同時に真の入力でも、`isOn` は偽、`isEnabled` は偽（停止中の式の `!isRestoring` による）として扱う
