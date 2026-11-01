# Validation: TAK-26

## 前提

2026-10-31 に設計承認後、AppDelegate に終了通知の監視と設定の close() を実装した。Cloud は GUI を起動しない。macOS CI の結果は末尾に記録。保守者のローカルビルド・テスト・GUI 動作確認は未実施。

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
| 設定とショートカット一覧を開いてメインを閉じる | 両補助ウインドウが閉じ、プロセスが終了する |
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

この時点では macOS CI の build/test と GUI シナリオは未実施。後日の CI 結果は末尾に記録。Cloud の検査通過は GUI 確認の代替ではない。

## master 取り込みによる影響（2026-11-01、T012）

基準 bfe63d5 から origin/master の 1dfccaa まで12コミット・134ファイルの変更を取り込んだ。merge は競合なし。

| 変更 | TAK-26 への影響・判断 |
|---|---|
| TAK-22: AppDelegate にショートカット表示・検証を追加 | 自動マージ後も両方の入口を維持。メイン終了監視の対象は同一の実 window |
| TAK-22: MainWindowController が親終了時に一覧を閉じる | 設定は AppDelegate、一覧は MainWindowController が閉じる。delegate を置き換えず、通知の順番に依存する相互呼び出しもない。両方を開いた終了を GUI ケースに追加 |
| TAK-20: 設定の間隔・補足説明・言語切替時の高さ調整 | 設定の所有・delegate・close 時の makeFirstResponder(nil)・入力解析は維持。終了連動の追加修正は不要と静的判断。言語切替後の編集確定もローカル確認対象 |
| TAK-19、TAK-17、TAK-21、改名修正 | プレビュー操作・ファイル操作の変更。MainSplitViewController の windowWillClose によるスライドショー停止は維持 |
| Package.swift: FolzioAppTests を新設 | 既存の通常 CI の対象が増える。旧 plan/research の「App テストターゲットなし」は作成当時の記録。今回、新しいテストターゲットや実装変更は加えない |
| AGENTS.md: check-skill-sync.sh を検証ゲートに追加 | 今回の検査に追加 |
| product に TAK-22 等の要件を反映 | ID が重複したため下表のとおり本 feature 内だけを振り直す。マージ済み product の ID と本文は変更しない |

| 旧 ID | 新 ID |
|---|---|
| FR-200〜203 | FR-224〜227 |
| SC-096〜097 | SC-113〜114 |
| EC-136〜138 | EC-156〜158 |
| A-116 | A-140 |

仕様IDの変更は参照整合の修正であり、承認済みの振る舞いを変更しない。product 反映は T011 として引き続き未完了。

### 取り込み後の Cloud 検査

ネットワーク API 禁止、README 同期（origin/master 基準）、英語コメント、共有スキル同期、push 制約の3テスト、git diff --check がすべて通過。feature と product の定義 ID の重複も0件。TAK-26 の実行コードは master 取り込み後も AppDelegate.swift の13行追加・1行削除のみ。

### CI 再実行の状況

2026-11-01、CLI の workflow_dispatch は Forbidden で失敗した。手順書の actions_run_trigger はこのセッションには公開されていないが、GitHub MCP の convert_pull_request_to_draft → mark_pull_request_ready_for_review により ready_for_review イベントで CI を起動できた。保守者の手動実行が必要とした先の記録を訂正する。PR は Ready に復元済み。

対象コミット: de19cecebbd3de8c467054f444d3f391923d8710。実行: [macOS Swift CI #41276591741](https://github.com/yoshidax/folzio-dev/actions/runs/41276591741)。GUI 確認は未実施。

### CI 結果（2026-11-01、T010）

- 実行 #41276591741: success。対象 head は de19cec、master 1dfccaa 取り込み後。
- macOS 15 / arm64、Xcode 16.0（Swift 6.0）で build 成功。
- 通常テスト: ログで `Test run with 881 tests passed` を確認。
- 性能テスト: continue-on-error のステップ表示だけで判断せず、ログで `Test run with 27 tests passed` を確認。
- CI 後の変更はこの検証記録と tasks.md の進捗だけで、実行コードの追加変更なし。GUI・ローカル最新 Swift の確認と product 反映は引き続き未完了。

### 保守者の動作確認（2026-11-01、JST）

保守者から「動作確認し意図通り動作することを確認しました」と報告を受けた。TAK-26 の意図する終了連動について確認済みとして記録する。個別の9ケースの実施内訳とローカル最新 Swift での build/test の結果は明示されていないため、それらを全件実施済みとは記録しない。

### 現行仕様への反映（2026-11-01、T011）

保守者が10項目の反映差分を承認した。最新取得済み master 1dfccaa を含むことを確認し、FR-224〜227・EC-156〜158・SC-113〜114・A-140 を specs/product/contracts/settings.md に反映した。product 全体の定義 ID の重複がないことと、feature の10定義の本文が反映先と一致することを確認し、feature の spec.md に移行済み・凍結の注記を付けた。実行コードの変更なし。
