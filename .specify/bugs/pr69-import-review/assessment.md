# Bug Assessment: PR #69 の受け取りUIのレビュー再評価

- **Slug**: pr69-import-review
- **Created**: 2026-11-10
- **Source**: https://github.com/yoshidax/folzio-dev/pull/69#pullrequestreview-5843521554
- **Verdict**: valid（下記2・3・4のみ）
- **Severity**: medium

## Report

6件のレビューコメントを、保守者の「妥当性を確認した上で、妥当であれば修正」という依頼に基づいて再評価する。
PRの作業ブランチを維持する。新機能や凍結済みfeatureの仕様変更は含めない。
GitHubはallowlistedの報告元として接続ツールでレビュー本文を取得した。

## Symptom

受け取り先ウインドウが存在しても、失敗通知は現在のkey/main windowだけを探す。
宛先検査前に受信の取消が無効になり、進捗更新では取消ボタンのビューが毎秒破棄される。

## 仕様との照合

| コメント | 判定 | 根拠・扱い |
| --- | --- | --- |
| 1 全画像Dataの同時保持 | 今回のバグ修正としては採用しない | FR-355はドロップ・ペースト中の同期取得、FR-359は1件ごとの256 MB上限を規定する。R5では取得前の確保量・待ち時間を制限できないことを明記している。多数項目のピーク使用量は設計上の課題として残るが、計測による障害は確認していない。合計上限やドロップ後の逐次取得への変更は、承認済みの受入条件・ペーストボード有効期間の前提を変えるため、本修正へ混ぜない。 |
| 2 失敗通知のparentWindow欠落 | valid | FR-026・EC-244・EC-245は失敗理由の表示を求める。確認前の失敗でglobal windowがない場合、runSheetが通知せず戻る。保存した宛先ウインドウへ失敗通知も渡す。 |
| 3 宛先検査中の取消不能 | valid | FR-363・SC-200の取消と応答性、既存のchecking中は取消可能という状態設計に反する。willConfirmを事前検査後・確認直前に移す。 |
| 4 取消ボタンの毎秒再作成 | valid | FR-363のフォーカスを奪わない進捗表示とキーボード操作を損なう。行とボタンをUUIDごとに維持する。 |
| 5 保存全体の直列化 | バグという断定を撤回 | EC-246は別セッションの受信・取消の独立とダイアログの直列化を定め、実ファイル転送の同時実行は要求していない。I/Oの並列化は性能改善であり、同一宛先の衝突確認から書き込みまでの競合対策も必要。本修正では既存の直列化を維持する。 |
| 6 書き込み権限のホバー検査 | invalid（比較説明を訂正） | 既存InternalDropValidationも書き込み権限を検査しない。元のレビューの「既存file URL経路は書き込み不可を拒否する」という前提が誤り。EC-08・EC-245に従って実行時に失敗を表示する現在の扱いを維持する。 |

## Reproduction

1. global windowの検索をnilへ差し替え、明示した宛先ウインドウがある状態で検査失敗のリクエストを保存する。
2. 宛先検査を停止できる差し替えで、検査開始時にwillConfirmがまだ呼ばれず、取消後に確認へ進まないことを調べる。
3. 進捗行を複数回更新し、既存の取消ボタンの同一性と対象UUIDが保たれることを調べる。

## Suspected Code Paths

- FileOperationCoordinator.saveReceived / transferReceived / presentFailures / runSheet
- ImportSessionManager.control / rows
- ReceivingPanelController.update

## Root Cause Hypothesis

失敗通知にだけ明示parentの引数がなく、確認開始イベントの通知順が早い。
パネルは表示内容の更新を全ビューの再生成で実装している。コード上の確信度はhigh。
実機のVoiceOver操作と遅いボリュームでの再現は未実施。

## Proposed Remediation

- 失敗通知とrunSheetへparentWindowを通し、明示parentをfallbackより優先する。
- 事前検査中はcheckingを保ち、取消後は確認を始めない。
- UUIDに対応する行を再利用し、消えた行だけを削除する。言語変更も既存ラベルとボタンの更新で処理する。

**Files likely to change**:
- Sources/FolzioApp/Operations/FileOperationCoordinator.swift
- Sources/FolzioApp/Operations/ReceivingPanelController.swift
- Tests/FolzioAppTests/ImportPromptParentTests.swift
- Tests/FolzioAppTests/ReceivedFileTransferTests.swift
- Tests/FolzioAppTests/ReceivingPanelControllerTests.swift

## Risks & Considerations

親ウインドウの表示と既存シートの待ち合わせを維持する。確認・衝突・転送の直列化は変更しない。
テスト用差し替えは既存presenterと同じ形で追加する。GUIの実測を自動テストの成功で置き換えない。

## Open Questions

起動スモークとGUIでのフォーカス・エラー通知の実測は保守者確認待ちとする。
