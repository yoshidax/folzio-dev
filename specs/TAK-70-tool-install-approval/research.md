# 調査: エージェントの権限設定

- `AGENTS.md` は既に依存ツールの導入前にユーザーに確認することを定めている。
- 既存の実例は `scripts/make-webp-fixtures.sh` や日英の開発ガイドで案内している `brew install webp` である。
- `.claude/settings.json` の `permissions.ask`、`.kilo/kilo.jsonc` の bash 権限、`.codex/rules/sdd.rules` の接頭辞に現在この導入ルールはない。Claude の設定ファイルは ISSUE の指示に従って保守者が編集する。
- Codex の `execpolicy check --help` で、実行せずにルールファイルとコマンドを照合するインターフェースを確認した。
- 権限設定の適用対象はエージェントごとに異なり、全てのシェル表記やコマンド実行経路を覆う OS 権限ではない。`pip`・`npm` を含む他の導入も既存の文章規則の対象とする。
