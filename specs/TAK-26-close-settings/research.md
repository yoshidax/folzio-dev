# Research: TAK-26

## 終了連動の場所

- Decision: AppDelegate がメイン window に限定した終了通知を受け取る。
- Rationale: 両方のコントローラを所有しており、設定の生成を強制せず連動できる。MainSplitViewController は既に window.delegate を担当し、windowWillClose でスライドショーを停止している。
- Alternatives considered: delegate を AppDelegate に移すと既存停止処理を壊す。MainSplitViewController から設定を参照すると所有関係を複雑にする。アプリ終了だけに頼ると設定が最後の window になり終了判定に到達しない。

## 設定の閉じ方

- Decision: 保持済み SettingsWindowController に close() を送る。
- Rationale: SettingsWindowController.swift:279 の windowWillClose が makeFirstResponder(nil) を呼び、既存の controlTextDidEndEditing で入力を検証・保存する。isReleasedWhenClosed は false で、設定だけ閉じた後の再表示も既存設計のまま。
- Alternatives considered: orderOut は閉じる処理ではない。強制 terminate は編集確定と既存ウインドウ終了処理の検証を難しくする。

## 検証と制約

- Decision: 既存 CI の build/test と GUI 受け入れ確認を使う。Core モデルやテストターゲットを新設しない。
- Rationale: 変更は AppKit の実ウインドウのライフサイクルであり、現行の Package.swift は App のテストターゲットを持たない。通知の文字列やソース配置だけを検査しても実際の終了を証明できない。
- GUI 再現・動作確認は未実施。API の実装前確認と macOS での終了順序・編集中入力の確認は tasks.md に明記する。
- Linear get_agent_context は Tool not found を返したため、共有ノートは利用できなかった。判断はリポジトリの静的確認に基づく。
- 未解決の仕様質問なし。実装開始には cloud-agent-workflow.md の設計承認が必要。
