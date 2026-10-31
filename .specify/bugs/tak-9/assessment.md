# Bug Assessment: 競合ダイアログの中止後も後続項目が処理される

- **Slug**: tak-9（Issue ID から生成）
- **Created**: 2026-11-01
- **Source**: [TAK-9](https://linear.app/takyoshida/issue/TAK-9/コピー移動の競合ダイアログで中止を選んでも後続項目が処理される)
- **Verdict**: valid（コード上で確認、GUI 再現は未実施）
- **Severity**: medium（意図しない後続のコピー・移動が発生する）

## Report

複数項目のコピー・移動中に競合ダイアログで「中止」または Esc を選んでも、後続項目の処理が続く。中止前の成功分は表示に反映する必要がある。

## Symptom

競合項目は処理されないが、その後の項目が処理される場合がある。期待する動作は、その時点で後続の処理を止め、実行済みの結果を反映すること。

## 仕様との照合

実装が仕様に反していると判断する。FR-025・US4-AS8 は競合時の「中止」を定め、FR-165・US23-AS4 は部分成功を含む結果と表示の整合を要求する。「中止」後に後続を実行することはその選択と整合しない。FR-022・SC-006 の変更なしの規定は操作前の確認モーダルのキャンセルに関するものであり、途中の競合で既に成功した操作のロールバックを明示していない。

## Reproduction

1. 複数項目をコピーまたは移動し、途中の項目が移動先の同名項目と競合するようにする。
2. 競合ダイアログで「中止」または Esc を選ぶ。
3. 後続の非競合項目が処理されるか確認する。「すべてに適用」の有無も確認する。

GUI での再現は未実施。

## Suspected Code Paths

- `Sources/FolzioApp/Operations/ConflictPrompt.swift` — 中止・Esc を `.abort` として返す。
- `Sources/FolzioApp/Operations/FileOperationCoordinator.swift:156` — 項目単位で処理し、`.abort` で `continue` する。
- `Sources/FolzioCore/Operations/FileOperationService.swift:32` — サービスの `.abort` は競合項目を失敗として扱う内部方針であり、UI 操作全体の中止とは異なる。

## Root Cause Hypothesis

確信度は高い。コーディネータが中止応答をループ終了ではなく当該項目のスキップとして扱っている。「すべてに適用」を選ぶと後続にも `.abort` が共有され、選ばない場合とは挙動が変わる。

## Proposed Remediation

**Preferred**: コーディネータで `.abort` を受けたらループを終了し、既存の結果表示、履歴更新、フォルダ再読込の後処理は実行する。サービスの内部方針は変更しない。

**Files likely to change**:
- `Sources/FolzioApp/Operations/FileOperationCoordinator.swift`
- 関連する操作フローの回帰テスト

**Tests to add or update**:
- コピー・移動それぞれで、先行項目の成功後に中止し、競合項目と後続項目が未実行で、成功分が結果に反映されること。
- 中止と Esc、および「すべてに適用」の有無を確認する。先頭で中止するケースも確認する。

## Risks & Considerations

- 既に成功した項目は取り消さず、部分成功として表示と履歴を整合させる。
- macOS GUI での再現・検証と Swift ビルド・テストはこの環境では未実施。
- `git fetch origin master` はプロキシへの接続失敗で未完了。手元の `origin/master` は HEAD の祖先だが、リモートの最新状態は未確認。

## Open Questions

- なし。修正の前に診断と方針の確認が必要。
