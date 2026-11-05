# Tasks: TAK-70 Homebrew ガード拡張

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[quickstart.md](quickstart.md)

## Phase 1: 設計

- [x] T001 `specs/TAK-70-brew-guard-extension/` に、保守者が選択した対象拡大と Claude deny の設計・タスクを記録する。

## Phase 2: US1 対象拡大 (P1)

- [x] T002 [US1] `.codex/rules/sdd.rules` と `.kilo/kilo.jsonc` に直接の `brew reinstall`・`upgrade`・`bundle` の禁止を追加する。
- [x] T003 [US1] `AGENTS.md`、`docs_private/agents/skills-and-codex.md`、`docs_private/codex-speckit.md` を禁止対象に追従させる。
- [ ] T004 [US1] `scripts/dev/tests/test_check_tool_install_permissions.py` で Kilo の対象と Claude の deny を検査する。
- [ ] T005 [US1] 保守者による `.claude/settings.json` の deny 変更を確認する。
- [ ] T006 [US1] `specs/TAK-70-brew-guard-extension/quickstart.md` に沿って検証し、結果と未確認事項を `specs/TAK-70-brew-guard-extension/tasks.md` に記録する。

検証記録（2026-11-06）: Codex の単体判定は `brew install webp`・`brew reinstall webp`・`brew upgrade`・`brew bundle`・`brew bundle check` で `forbidden`、`brew list` では対象外。Kilo の設定検査を対象に追加し `scripts/dev/check-all.sh` は成功（73 テスト）。Claude の deny 変更と追加規則の実セッションでの確認は未了。

凍結手順: タスクの状態と検証結果を記録した後、凍結注記案を保守者に提示し、承認後に `specs/TAK-70-brew-guard-extension/spec.md` へ追記する。注記を feature 記録の最後の編集とする。
