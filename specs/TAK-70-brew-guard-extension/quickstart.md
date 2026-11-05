# 検証: Homebrew ガード拡張

1. `codex execpolicy check --rules .codex/rules/sdd.rules -- brew install webp` を実行し、同じ方法で `brew reinstall webp`・`brew upgrade`・`brew bundle` が `forbidden` と判定されることを確認する。`brew list` は対象外であることも確認する。インストールコマンド自体は実行しない。
2. `scripts/dev/check-all.sh` で Claude・Kilo の設定と通常の検査を実行する。
3. 保守者が `.claude/settings.json` の `Bash(brew install *)` を `permissions.ask` から `permissions.deny` に移した後、設定内容と検査結果を再確認する。
4. 実セッションの禁止確認は、誤って実際の Homebrew を実行することがない方法を用い、未実施なら記録する。
