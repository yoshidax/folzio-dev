# Tasks: TAK-70 Homebrew ガード拡張

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[quickstart.md](quickstart.md)

## Phase 1: 設計

- [x] T001 `specs/TAK-70-brew-guard-extension/` に、保守者が選択した対象拡大と Claude ask 維持の設計・タスクを記録する。

## Phase 2: US1 対象拡大 (P1)

- [x] T002 [US1] `.codex/rules/sdd.rules` と `.kilo/kilo.jsonc` に直接の `brew reinstall`・`upgrade`・`bundle` の禁止を追加する。
- [x] T003 [US1] `AGENTS.md`、`docs_private/agents/skills-and-codex.md`、`docs_private/codex-speckit.md` を禁止対象に追従させる。
- [x] T004 [US1] `scripts/dev/tests/test_check_tool_install_permissions.py` で Kilo の対象と Claude の ask を検査する。
- [x] T005 [US1] `.claude/settings.json` の ask が維持され、同じ規則が deny にないことを確認する。
- [x] T006 [US1] `specs/TAK-70-brew-guard-extension/quickstart.md` に沿って検証し、結果と未確認事項を `specs/TAK-70-brew-guard-extension/tasks.md` に記録する。

検証記録（2026-11-06）: Codex の単体判定は `brew install webp`・`brew reinstall webp`・`brew upgrade`・`brew bundle`・`brew bundle check` で `forbidden`、`brew list` では対象外。Kilo の設定検査を対象に追加し `scripts/dev/check-all.sh` は成功（73 テスト）。Claude の deny 変更と追加規則の実セッションでの確認は未了。

方針変更（2026-11-06）: 保守者は Claude を ask とすることを選択した。Claude の設定は従来どおり ask にあり、同じ規則は deny にないことを確認した。更新後の `scripts/dev/check-all.sh` は成功（73 テスト）。Codex・Kilo の追加規則は引き続き実セッションでは未確認。

凍結手順: タスクの状態と検証結果を記録した後、凍結注記案を保守者に提示し、承認後に `specs/TAK-70-brew-guard-extension/spec.md` へ追記する。注記を feature 記録の最後の編集とする。
