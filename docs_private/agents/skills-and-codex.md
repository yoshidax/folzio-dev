# スキル・Codex・Spec Kit の構成

AGENTS.md から参照する、スキルや各エージェントの設定を変えるとき、Codex を自動実行するときの規約。

## スキル

- Codex の Spec Kit スキルは `.agents/skills/`。CLI では `$speckit-specify`、`$speckit-plan`、
  `$speckit-tasks`、`$speckit-analyze`、`$speckit-implement`、`$speckit-converge` などで呼び出す
- 標準・git・bug スキルは Spec Kit が生成する。共通のプロジェクト規約は AGENTS.md で管理する
- 手書きの `folzio-*` スキルは、共通手順の本文を `shared-skills/<スキル名>.md` に置き、
  運用手順・開発記録は `docs_private/` に置く。`.agents/skills/` と `.claude/skills/` の
  `SKILL.md` には、`name`、`description`（両方で同じ内容）、本文を読む指示、各ツール固有の注意だけを書く。
  名前と説明の一致、共通本文の存在と参照先は `scripts/dev/check-skill-sync.sh` で確かめる

## 権限の設定

- `.codex/config.toml` と `.codex/rules/` は Codex 用。Claude（`.claude/settings.json`）／Kilo（`.kilo/kilo.jsonc`）の permissions 設定は Codex に適用されない

## Codex の自動実行（ローカル）

- Codex の自動実行は `scripts/dev/sdd-run-codex.sh` を使う。run／resume／status と更新手順は
  [codex-speckit.md](../codex-speckit.md) を参照する。既定の integration は Claude のままとする
- Codex の初期ワークフローは順次実装する。並列実装の規約は [parallel-worktree.md](parallel-worktree.md)
