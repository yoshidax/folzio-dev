# Quickstart: エージェント向けの規約の置き場所を AGENTS.md に限らない

実装と反映の後に、Cloud（または保守者のローカル）で行う確認の手順。前提: TAK-71（PR #50）が `master` にマージされ、作業ブランチに
取り込んである（research.md の R1）。

## 1. 検査がすべて通る

```bash
scripts/dev/check-all.sh
python3 scripts/dev/check-spec-format.py
```

- 期待: `check-all.sh` は `all checks passed`。`check-agents-md.sh` の行で、警告も参照切れも出ない
- 期待: `check-spec-format.py` はエラー 0 件で、警告は基準値以下

## 2. AGENTS.md の行数が増えていない（SC-163）

```bash
awk 'END { print NR }' AGENTS.md
```

- 期待: 50 以下（research.md の R2 の設計では 46）

## 3. 仕様が AGENTS.md の本文を指定していない（SC-162）

```bash
grep -n 'AGENTS.md' specs/product/*.md specs/product/contracts/*.md
```

- 期待: 出てくる行のどれも、内容を `AGENTS.md` の本文に置くことを求めていない
  - 許されるもの: 「エージェント向けの規約（`AGENTS.md` と、そこから参照する文書）」、節の名前の参照（A-91 の「Phase の検証ゲート」）、
    FR-195（変更）と FR-306（変更）の「FR-307 の例外」として理由とともに定めたもの、FR-309・FR-310 の検査の対象としての `AGENTS.md`、記録としての前提（A-111・A-112）

## 4. 参照切れで検査が失敗する（SC-164）

```bash
git mv docs_private/agents/linear.md docs_private/agents/linear-renamed.md
scripts/dev/check-agents-md.sh; echo "exit $?"
git mv docs_private/agents/linear-renamed.md docs_private/agents/linear.md
```

- 期待: 終了コード 1 で、`docs_private/agents/linear.md` が切れた参照として表示される
- 最後の行で元に戻し、`git status` に差分が残らないことを確かめる

## 5. 行数の上限で検査が失敗する（SC-165）

```bash
python3 -I -m unittest discover -s scripts/dev/tests -p 'test_check_agents_md.py'
```

- 期待: すべて成功する。`test_fails_above_50_lines` と `test_counts_last_line_without_trailing_newline` が、上限より 1 行多いときの
  失敗を確かめている

## 6. 適用範囲を読み取れる（FR-195（変更）、US30-AS2（変更）、SC-094（変更））

- `AGENTS.md` の各見出しと「作業別の手順」の各行に【共通】【ローカル】【Cloud】のどれかがある
- `AGENTS.md` から参照する `docs_private/` の文書（9 個）の冒頭に `**適用範囲**:` の行がある

```bash
grep -L '^\*\*適用範囲\*\*:' docs_private/agents/*.md docs_private/cloud-agent-workflow.md \
  docs_private/comment-translation-glossary.md docs_private/repository-and-release.md
```

- 期待: 何も表示されない（すべての文書に適用範囲の行がある）
- `AGENTS.md` と参照先の文書を読み比べ、同じ状況（例: `git push`、検証ゲート、CI の再実行）に異なる指示がないことを確かめる

## 7. 参照が読むべき作業を示している（FR-308）

- `AGENTS.md` の参照の行（参照先のパスを含む行）を1行ずつ読み、どれも、その文書を読むべき作業や状況を示していることを確かめる
  （例: 「バグを直す: `docs_private/agents/bugfix.md`」）

## 8. 書き方のルールにたどり着ける（US66-AS2（変更）、SC-161（変更））

- `AGENTS.md` だけを読んで、`specs/product/` を変える前に `specs/product/README.md` の「書き方のルール」を読むことが分かる
- `specs/product/README.md` だけを読んで、書き方のルールと検査の実行方法を答えられる
