# Data Model: TAK-16

永続モデルや設定は追加しない。

| 値 | フィールド / 制約 |
|---|---|
| Rename input | source: 親と保存名を持つ URL。newName: 空・禁止文字・先頭ドット・フォルダのパッケージ化の既存検証を適用する。 |
| Other sibling names | 「元項目の保存名と完全一致するエントリだけを除外する」。ファイル・フォルダ・非表示項目・リンクを含む。 |
| Name comparison | 「別項目の競合比較は大文字小文字を無視する」。ボリューム種別で変えない。 |
| Case-only change | source の保存名と newName が完全一致せず、大文字小文字を無視すると一致する。同じ親内だけ。 |
| Result | 既存の FileOperationResult。成功 URL は入力表記。失敗は sameNameExists / sourceNotFound / systemFailure 等の既存理由。 |

## State transitions

編集 → 検証 → 常時確認 → バックグラウンドで兄弟再検証 → 既存の改名 → 成功 URL 通知 → 表示反映。

同じ表記・空入力は既存 UI で no-op。Esc・確認キャンセルは書き込みなし。競合や列挙失敗は改名を始めず失敗を通知。OS の移動失敗は成功結果に含めない。元エントリと別エントリの判定に実体 ID の一致は使わない。
