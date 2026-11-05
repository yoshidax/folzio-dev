# 検証: TAK-70

1. 設定の差分を点検し、Claude の変更は保守者に提示した具体案と一致することを確かめる。
2. インストールを実行せず `codex execpolicy check --rules .codex/rules/sdd.rules -- brew install webp` の判定を確認する。`brew list` も照合して当該規則の対象外であることを確認する。
3. JSON/JSONC 構文と規則、`scripts/dev/check-all.sh` の結果を記録する。環境で実行できない検証は未実施として記録する。
4. Claude・Kilo・Codex の新規セッションで直接の `brew install` を実行する前の確認表示を、実行を許可せずに確認する。環境がなければ未確認と記録する。
5. Claude 設定は保守者に変更を依頼する。実動確認、検証状況および承認待ちの項目を明確にする。
