# Bug Assessment: Codex workflow の手動確認による停止

- **Slug**: codex-manual-gates（診断内容から自動選定）
- **Created**: 2026-10-27
- **Source**: pasted text / run 356c45b4
- **Verdict**: valid
- **Severity**: high（Phase の確認を守る feature の実装が進まない）

## Report

`./scripts/sdd-run-codex.sh resume 356c45b4` が implement で終了コード1。最終回答は `status: blocked`、T002 の設計レビュー報告未受領、T003以降未実施。直前の調査結果を提示した後、ユーザーから「workflowを修正してください」と修正指示を受領した。

## Symptom

設計レビュー gate が approve 済みでも、その証拠が実装に渡らず、T002 が未完了のまま止まる。Phase 途中の手動確認と後続の自動タスクがあると、implement 成功後にしか到達しない GUI gate へ進めない。

## 仕様との照合

- `specs/product/` は MediaViewer アプリの仕様で、開発用 workflow の要件 ID はない。本件でアプリの FR/SC を変更しない。
- 直接の運用契約は `AGENTS.md` の「Phase の検証ゲート」「Codex / Spec Kit」、`docs/codex-speckit.md` の設計レビュー・GUI確認・resume手順。
- 判定: **実装が既存の運用契約に反している**。手動確認を省略せず Phase 単位で進行する既存要件を修正するため fix へ進む。新しいアプリ要件・product仕様変更ではない。

## Reproduction

1. 非手動→手動→非手動の依存を持つ tasks.md を用意する。
2. review_gate で approve し implement へ進む。
3. 手動タスクで blocked になり、GUI gate へ到達できない。報告なしの resume は同じ場所で止まる。
4. 実 run の保存状態で `review_gate: completed / approve` と `implement: failed / 1` を確認済み。

## Suspected Code Paths

- `scripts/sdd-codex.py`: validate_delivery / execute_codex / run_workflow
- `.specify/workflow-src/sdd-increment-codex.yml`: review_gate / implement / gui_smoke
- `scripts/sdd-codex-implementation.schema.json`: 待機と失敗を区別できない

## Root Cause Hypothesis

確度 high。全非手動タスク完了を要求する implement の後にしか GUI gate がない。一方、Phase の記録・コミットは GUI 後が前提。保存したレビュー承認も実装プロンプトへ渡していない。

## Proposed Remediation

ランナーに明示的な `waiting_for_manual` の中断・再開を追加する。Codex は現在実施可能な既定の手動タスク ID と具体的な手順を構造化して返す。ブリッジはタスク定義・分類・チェック状態を検査し、待機要求を run 別の補助ファイルへ保存する。外側のランナーが TTY で確認報告を受領し、対象のタスクだけをチェックして同じ implement から再開する。非 TTY は専用終了コード75と手動確認待ちの表示で止める。実装未完了や権限不足は引き続き失敗とする。

review_gate の承認を実装へ渡す。設計レビューだけを求める既定タスクについて、同じ run の approve を証拠にランナーが記録する。GUI タスクをレビュー承認で完了にしない。旧 run の failed implement もこのブリッジを通るため、保存 workflow/state の書換えなしで対応する。

**Files likely to change**:
- scripts/sdd-codex.py
- scripts/sdd-codex-implementation.schema.json
- .specify/workflow-src/sdd-increment-codex.yml
- scripts/tests/test_sdd_codex.py
- docs/codex-speckit.md

**Tests to add or update**:
- waiting の ID・分類・チェック状態・手順・blockers の検査
- レビュー承認の引継ぎと GUI への誤適用拒否
- 非TTY中断、TTY報告、同一run再開、拒否・途中終了
- 変更後の古い確認要求の拒否、実失敗・未完了・旧完了runの保護
- 実 Spec Kit と偽 Codex を用いた Phase 複数回の確認・再開

## Risks & Considerations

- 未確認タスクを完了扱いにしない。承認と対象タスク状態を紐付け、後続の記録タスクには受領証拠を渡す。
- Spec Kit 自体の failed 状態は書換えず、ランナーが補助記録に基づき手動確認待ちを表示する。
- 新旧 run の扱いと非TTYの終了コードを文書化する。実 run を試験として進めない。
- spec 010 の未コミット変更を保持するため、クリーンな master から bugfix worktree を作成した。

## Open Questions

なし。前の診断に対する今回の修正指示を fix の承認として扱う。GUI の起動確認はユーザー報告が必要。
