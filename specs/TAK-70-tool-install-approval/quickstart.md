# 検証: TAK-70

1. 設定の差分を点検し、Claude の変更は保守者に提示した具体案と一致することを確かめる。
2. インストールを実行せず `codex execpolicy check --rules .codex/rules/sdd.rules -- brew install webp` が `forbidden` と判定されることを確認する。`brew list` も照合して当該規則の対象外であることを確認する。
3. JSON/JSONC 構文と規則、`scripts/dev/check-all.sh` の結果を記録する。環境で実行できない検証は未実施として記録する。
4. Claude・Kilo・Codex の新規セッションで、Claude は確認表示、Codex と Kilo はブロックを確認する。設定が効かずコマンドが実行される場合も考慮し、実際の Homebrew を使う前に安全なテスト方法を確認する。導入済みの formula でも更新され得るため、安全とは見なさない。環境がなければ未確認と記録する。
5. Claude 設定は保守者に変更を依頼する。実動確認、検証状況および承認待ちの項目を明確にする。
