# Bug Fix: Codex workflow の手動確認による停止

- **Slug**: codex-manual-gates（assessment の文脈から継承）
- **Applied**: 2026-10-27
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

`waiting_for_manual` を導入し、Phase 途中のユーザー操作・報告待ちを実装失敗と区別する。ランナーが報告を受領・保存して該当する既定手動タスクだけをチェックし、同じ run の implement へ戻す。設計レビューだけの手動タスクには同じ run の review_gate の approve を引き継ぐ。GUI の確認は代替しない。

## Changes

| File | Change | Notes |
|---|---|---|
| scripts/sdd-codex.py | modified | 手動要求の検証、承認の引継ぎ、TTY報告受領、非TTYの75中断、同一run再開、状態/タスク/アプリの照合 |
| scripts/sdd-codex-implementation.schema.json | modified | waiting_for_manual / manual_requests の追加 |
| .specify/workflow-src/sdd-increment-codex.yml | modified | v0.3.0、レビュー範囲・中断指示の明示、未実施手動タスクを一括チェックする record を削除、最終起動gateは維持 |
| .specify/workflows/sdd-increment-codex/workflow.yml | regenerated | specify workflow add --dev で登録 |
| .specify/workflows/workflow-registry.json | regenerated | Codex workflow のバージョンと更新日時 |
| scripts/sdd-run-codex.sh | modified | refresh 引数と終了コード75のコメント |
| scripts/tests/test_sdd_codex.py | modified | 実Spec Kitと偽Codex、PTYの端末入力による回帰テスト |
| docs/codex-speckit.md | modified | Phase毎の報告・再開、古い要求の再生成、既存runの互換性 |

## Tests Added or Updated

- 正当な待機、未分類/不明/重複/空手順の拒否、実失敗やblockersを待機で隠さないこと。
- 手動タスクの自己承認と完了状態の巻戻しを拒否する既存の検査を保持。
- 実Spec Kitのdo-while内で、2回のPhase手動報告を挟み同じrunを完了すること。
- 保存済みreview_gateのapproveを設計レビューへ適用し、GUIには適用しないこと。
- 非TTYで75中断し、statusで要求を表示、TTYの空行で未完了のまま保留すること。
- タスク/アプリ変更後の古い報告を拒否し、要求を退避して再生成できること。
- 既存のblocked再開、CLI失敗、非構造化の旧完了runを保護する検査も継続。

## Local Verification

- `python3 -m unittest discover -s scripts/tests -v`: 28件成功（新しいネストしたPhase中断を含む）。
- `specify workflow add --dev .specify/workflow-src/sdd-increment-codex.yml`: 登録成功。
- `git diff --check`: 成功。
- Swift の検証ゲートとユーザーによる起動スモークの結果は test.md に記録する。

## Deviations from Assessment

- 登録済みworkflowとregistryも更新した。ソースだけの修正では新規runの定義が更新されないため。
- sdd-run-codex.shのコメントも更新した。新引数と終了コードの入口での説明のため。
- 最終ビルドの独立した起動gateは維持した。削除したのはそのapproveで手動タスクを一括チェックする記録処理。

## Follow-ups

2026-10-27にユーザーから3ペインの表示成功（macOS 26.6.2 / 25G83）を受領した。ソース変更とこのbugディレクトリを1つのコミットにする。既存spec 010の進捗・実runの状態は変更せず、再開自体はユーザーが行う。
