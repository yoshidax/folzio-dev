# Tasks: TAK-70 依存ツール導入時の確認

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[quickstart.md](quickstart.md)

## Phase 1: 設計

- [x] T001 `specs/TAK-70-tool-install-approval/` に仕様・設計・タスクを作成し、整合性を確認する。
- [x] T002 `specs/TAK-70-tool-install-approval/` の設計を保守者に提示し、実装前の承認を得る。

## Phase 2: US1 導入前の確認 (P1)

**Independent Test**: 実際の導入を行わずに設定と Codex の判定を確認し、各エージェントの実セッションでの未確認事項を記録する。

- [x] T003 [US1] `.kilo/kilo.jsonc` に直接の `brew install` の確認規則を追加する。
- [x] T004 [US1] `.codex/rules/sdd.rules` に直接の `brew install` の確認規則を追加する。
- [x] T005 [US1] `.claude/settings.json` の具体的な変更を保守者に提示し、保守者による変更と結果を確認する。
- [x] T006 [US1] `docs_private/agents/skills-and-codex.md` に対象と限界、他の依存ツールと新規セッションの扱いを記す。
- [ ] T007 [US1] `specs/TAK-70-tool-install-approval/quickstart.md` に沿って設定・判定・通常の検査を行い、保守者の編集と各エージェントの実動確認の結果または未確認理由を `specs/TAK-70-tool-install-approval/tasks.md` に記録する。

検証記録（2026-11-06）: `codex execpolicy check` は `brew install webp` を `prompt`、`brew list` を規則の対象外と判定した。Kilo の設定は JSON として読み込め、対象規則が `ask` と一致する。`scripts/dev/check-all.sh` は成功（71 テスト）。設定後の新規セッションでの確認表示は未確認。Claude の設定は保守者が PR 作成後に変更予定のため未実施。インストールは行っていない。

追記（2026-11-06）: 保守者がコミット `103c9f6` で Claude の `permissions.ask` に `Bash(brew install *)` を追加した。Claude・Kilo の設定構文と規則、Codex の `prompt` 判定を再確認し、`scripts/dev/check-all.sh` は成功（71 テスト）。新規セッションでの確認表示は引き続き未確認。

実動確認の報告（2026-11-06）: 保守者によると Claude は確認画面が表示された一方、Codex と Kilo では確認画面が表示されず実際にインストールされた。実行した正確なコマンド・設定の読み込み状態・承認モードを確認中。Cloud の `codex execpolicy check` では `brew install jq` は `prompt` と判定されるが、実セッションの動作を保証するものではない。T007 は原因と対応の確認まで未完了とする。

追加報告（2026-11-06）: Kilo は `brew install jq`、Codex は `brew install eza` を実行し、両方とも自動承認モードだった。Cloud の Codex 単体判定では両コマンドとも `prompt` に一致するが、自動承認時に保守者の確認画面が表示される保証はない。設定の読み込み状態は未確認。自動承認時の扱いについて保守者の判断を待つ。

凍結手順: 全タスクの状態を記録し、対象とならない注記案を保守者に示して承認を得てから `specs/TAK-70-tool-install-approval/spec.md` に凍結注記を付ける。注記は feature ディレクトリの最後の編集とする。
