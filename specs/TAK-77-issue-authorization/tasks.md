# Tasks: Issue 対応の操作とレビュー

**Input**: [spec.md](spec.md)、[plan.md](plan.md)

## Phase 1: 設計と前提

- [x] T001 `specs/product/README.md`、関連仕様、`AGENTS.md` と Cloud 手順を確認する
- [x] T002 `specs/TAK-77-issue-authorization/spec.md` と `plan.md` と `tasks.md` を作成し、保守者に設計レビューを提示する
- [x] T003 [MANUAL] `specs/TAK-77-issue-authorization/` の設計レビューの承認を受ける。承認前に実装しない
  - 2026-11-06、保守者が提示した設計と実装への着手を承認。

## Phase 2: Issue 対応と CI（US1・US2）

**Independent Test**: 依頼に含まれる PR と自動 CI、手動 CI、レビューの停止条件を規約間で照合する。

- [ ] T004 [US1] `AGENTS.md` の PR と CI の規則を Issue 対応の依頼に整合させ、変更理由を PR に記録する
  - 規則は更新済み。PR 本文への理由の記録は PR 作成時に行う。
- [x] T005 [US1] `docs_private/cloud-agent-workflow.md` と `docs_private/agents/linear.md` の PR 手順を更新する
- [x] T006 [US2] `docs_private/cloud-agent-workflow.md` と `shared-skills/folzio-sdd-increment.md` で設計レビュー、反映差分レビュー、手動 CI の停止条件を明確にする
- [x] T007 [US2] `.specify/workflow-src/sdd-increment-codex.yml` と `.specify/workflows/sdd-increment-codex/workflow.yml` の両ゲートと説明を照合し、必要な変更を登録手順で同期する
  - review_gate と merge_back_gate は現行のまま。両ファイルは一致し registry は 0.3.0。変更・再登録は不要と判断した。

## Phase 3: push と実行環境の保護（US3）

**Independent Test**: 許可ケースと禁止ケース、フック無効時、実行環境の承認を区別する。

- [x] T008 [US3] `.codex/rules/sdd.rules`、`.codex/hooks.json`、`scripts/dev/check-git-push.py` の適用範囲と信頼条件を検証する
- [x] T009 [US3] 安全な限定が可能な場合に限り `.codex/rules/sdd.rules` と `scripts/dev/check-git-push.py` を更新し、不可なら現行の確認を維持して理由を記録する
  - 一時的な試験規則 `git push origin` の allow は master、強制、削除も許可する。フックが適用されない経路もあるため既存の prompt を維持する。
- [ ] T010 [US3] `scripts/dev/tests/test_check_git_push.py` と利用可能な権限規則検査で安全な操作と拒否ケース、フック無効時の挙動を検証する
- 模擬フックの許可・拒否と実行ポリシーの prompt は確認済み。フックが無効・未承認の実セッションの動作は未確認。
- [x] T011 [US3] `docs_private/agents/skills-and-codex.md` と `docs_private/codex-speckit.md` に実行環境とアプリの承認の限界を記載する

## Phase 4: 検証と製品仕様

- [x] T012 `scripts/dev/check-all.sh` と関連テストを実行し `specs/TAK-77-issue-authorization/` に結果・未実施を記録する
- 実施結果: `check-all.sh` 成功（73 件）、push フック単体 5 件成功。規則の `prompt` を通常の作業ブランチと master で確認。フックの無効・未承認の実セッションは未確認。Swift・GUI・CI は未実施。
- [x] T013 最新 master を取り込み `scripts/dev/check-spec-ids.sh` を実行した後、`specs/product/overview.md` に変更 ID を反映する
- [x] T014 `scripts/dev/check-spec-ids.sh` と `python3 scripts/dev/check-spec-format.py` で反映後の仕様を確認する
  - ID 重複なし、形式エラー 0、警告 88（基準値 88）。
- [x] T015 [MANUAL] 反映 ID と `specs/product/overview.md` の差分、凍結注記案を保守者に示し、承認を受ける
  - 2026-11-06、保守者が反映差分と凍結注記案を承認。
- [ ] T016 承認結果を `specs/TAK-77-issue-authorization/tasks.md` に記録してから `specs/TAK-77-issue-authorization/spec.md` に凍結注記を付け、承認済み仕様をコミットする
- [ ] T017 [MANUAL] PR 対象コミットの CI と `scripts/make-app.sh`・`open .build/Folzio.app` による保守者の起動確認を記録する

## 依存関係

T001〜T003 の後に実装し、T004〜T011 の検証後に T012〜T015 を行う。T016 の凍結後に feature ディレクトリを編集しない。T017 は結果を PR に記録する。手動 CI の追加実行には別途許可が必要。
