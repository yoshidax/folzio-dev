# 調査: 対象拡大

PR #60 のレビューで `reinstall`・`upgrade`・`bundle` も導入・更新に使えると指摘された。保守者は Codex・Kilo の禁止対象を広げ、Claude の `brew install` を deny とすることを選択した。

`brew bundle` の引数なしの実行やオプションを伴う導入も対象とするため、今回は接頭辞 `brew bundle` 全体を禁止し、`bundle check` も含まれることを明記する。静的検査はユーザー設定や環境全体が適用された実セッションを代替しない。
