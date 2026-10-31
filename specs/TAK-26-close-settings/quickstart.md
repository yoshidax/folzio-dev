# Validation: TAK-26

## 前提

2026-10-31 に設計承認後、AppDelegate に終了通知の監視と設定の close() を実装した。Cloud は GUI を起動しない。macOS のビルド・テスト・GUI 動作確認は未実施。

## Cloud の検査

```bash
scripts/check-no-network.sh
scripts/check-readme-sync.sh master
scripts/dev/check-english-comments.sh
python3 -I -m unittest discover -s scripts/dev/tests -p 'test_check_git_push.py'
```

## macOS CI とローカル

PR 作成は保守者の依頼後に行う。CI で swift build / swift test の成功を確認する。
保守者は最新のローカル Swift でも以下を実行する。

```bash
swift build
swift test
scripts/make-app.sh
open .build/Folzio.app
```

## GUI シナリオ

各終了ケースは起動し直して確認する。3ペインの起動スモークも確認する。

| 操作 | 期待結果 |
|---|---|
| 設定を開き、メインの閉じるボタンを押す | 両方が閉じ、Dock の起動中表示とプロセスが終了する |
| 設定を一度も開かずメインを閉じる | 設定が出現せず正常終了する |
| 設定を開いて閉じ、その後メインを閉じる | 正常終了する |
| 設定だけを閉じ、閲覧してから ⌘, を押す | メインが残り、設定を再表示できる |
| 設定を開き、メインを最小化・復元する | 設定は閉じず、復元後に閲覧を継続できる |
| 設定の間隔に 7 を入力し、未確定のままメインの閉じるボタンを押す | 終了後、再起動して設定を開くと 7 が保存されている |
| 間隔の直前の保存値を確認し、0 を未確定入力してメインを閉じる | 再起動後、不正値は保存されず直前の有効値が残る |
| スライドショー中に設定を開き、メインを閉じる | 設定も閉じ、スライドショーやプロセスが残らない |

編集のケースは Return を押さずにメインの閉じるボタンを押す。フォーカス移動時点で既存の確定処理が走ることも含めて確認する。

## API の確認（T004、2026-10-31）

- [NSWindow.willCloseNotification](https://developer.apple.com/documentation/appkit/nswindow/willclosenotification): 閉じる直前に発行され、通知の object は対象 window。メインの実インスタンスを監視対象にする。
- [NSWindowController.close()](https://developer.apple.com/documentation/appkit/nswindowcontroller/close%28%29): 管理する window を閉じる。確認ダイアログを挟まないため、確認を要求しない現行の設定 window に利用する。
- [NSWindowDelegate.windowWillClose(_:)](https://developer.apple.com/documentation/appkit/nswindowdelegate/windowwillclose%28_%3A%29): 終了通知に対応する delegate 呼び出し。既存の設定編集終了とスライドショー停止を保持する。

## 実装の静的レビュー（T006）

- メインの参照を保持し、その実 window に対して表示前に通知を登録する。ハンドラでも通知元を同一性で確認する。
- 設定未生成では optional chaining により何もしない。設定だけの終了通知ではメイン終了の処理を行わない。
- 設定コントローラの close() から既存 windowWillClose の makeFirstResponder(nil) を通る。既存の入力解析・保存処理を変更していない。
- MainSplitViewController の delegate とスライドショー停止、AppDelegate の最終 window 終了判定を変更していない。
- 上記は静的確認であり、終了順序・保存結果の GUI 確認は引き続き必要。

## Cloud 検査の結果（T007、2026-10-31）

| 検査 | 結果 |
|---|---|
| scripts/check-no-network.sh | PASS |
| scripts/check-readme-sync.sh origin/master | PASS。ローカル master が存在しないため取得済み origin/master を基準に使用 |
| scripts/dev/check-english-comments.sh | PASS |
| python3 -I -m unittest discover -s scripts/dev/tests -p 'test_check_git_push.py' | PASS（3 tests） |
| git diff --check | PASS |

macOS CI の build/test と GUI シナリオは未実施。Cloud の検査通過はこれらの代替ではない。
