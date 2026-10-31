# Data Model: TAK-26

新しい保存データはない。既存の実行時所有関係だけを利用する。

| 対象 | 所有者 | 状態・遷移 |
|---|---|---|
| メインウインドウ | AppDelegate.mainWindowController | 表示中 → 閉じる通知 → 閉じた状態 |
| 設定ウインドウ | AppDelegate.settingsWindowController（任意） | 未生成なら終了操作は何もしない。表示中なら通常の close。閉じた後も再表示可能 |
| 切り替え間隔の編集 | SettingsWindowController / SettingsStore | close 時に編集終了。有効整数 1〜3600 は保存。不正値は既存の保存値を保持（FR-128） |

メイン終了 → 設定終了の一方向連動。設定終了 → メイン終了の連動は作らない。
