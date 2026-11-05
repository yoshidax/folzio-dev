# スキル・Codex・Spec Kit の構成

**適用範囲**: 【共通】（「Codex の自動実行」の節は【ローカル】）

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
- 直接の `brew install` について、Claude は確認、Codex は `forbidden`、Kilo は `deny` の規則を設定する。Codex では実セッションでの禁止を確認済み。Kilo は禁止が効かないとの報告があり調査中。必要な導入は保守者へ依頼し、保守者が実行する
- 自動承認モードでは `prompt`・`ask` が人の確認なしに承認され得る。Claude の `.claude/settings.json` は保守者が編集する
- `pip install` や `npm install -g` を含む他の依存ツールの導入も、`AGENTS.md` の規則に従い事前に保守者へ確認する
- 権限設定は OS のアクセス制御ではなく、絶対パス、ラッパー、入れ子のシェルなど全実行経路を保証しない。変更は新しいセッションから確認する

## Codex の自動実行【ローカル】

- Codex の自動実行は `scripts/dev/sdd-run-codex.sh` を使う。run／resume／status と更新手順は
  [codex-speckit.md](../codex-speckit.md) を参照する。既定の integration は Claude のままとする
- Codex での並列化の可否は [parallel-worktree.md](parallel-worktree.md)
