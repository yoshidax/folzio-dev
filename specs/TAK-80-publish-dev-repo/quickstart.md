# Quickstart: 開発用リポジトリの公開の準備の検証

## Cloud（Agent）

```bash
python3 -I -m unittest scripts.dev.tests.test_strip_readme_dev_note -v
scripts/dev/check-all.sh
python3 scripts/dev/check-spec-format.py
git diff --check
```

- 注記を除くスクリプトの単体テスト: 範囲の除去、注記を置く前の README との一致、印がない場合、崩れた印での失敗（FR-314〜FR-316）
- `check-all.sh`: README の同期（注記を追加しても構造がそろう）、`AGENTS.md` の行数と参照、仕様の ID
- 「非公開」の前提の記述が残っていないこと（SC-167）:

  ```bash
  grep -rnI "非公開\|private リポジトリ\|private repository\|無料枠\|使用時間" AGENTS.md docs_private .codex .kilo .github scripts specs/product \
    --exclude-dir=retrospective --exclude-dir=release-notes
  ```

  出力に残る行は、別の意味（例: `folzio-rename.md` の「非公開ディレクトリ」）であることを確かめる。

## CI（macOS、PR に push すると自動で動く）

- `Test publication script`（`scripts.dev.tests.test_publish_folzio`）: 書き出しで README から注記が消え、崩れた印で同期の前に止まる
- PR への追加の push で CI が自動で動くこと（US69-AS1）を、PR の checks で確かめる

## 保守者（GitHub とローカル）

1. 公開した開発用リポジトリの README の冒頭に、注記が表示される（US68-AS1）
2. `docs_private/repository-and-release.md` の「開発用リポジトリの公開とブランチ保護」に従って設定し、次を確かめる（US70）
   - CI が成功していない PR では、マージのボタンが使えない
   - 承認レビューなしで自分の PR をマージできる
   - 「Restrict deletions」「Block force pushes」が有効で、bypass の対象がない（ruleset の画面で確かめる）
3. `.claude/settings.json` の `permissions.ask` から、CI の起動・再実行の 3 項目を消す（2026-11-06 に対応済み）
4. マージ後に書き出して、公開先の README に注記がないことを確かめる

   ```bash
   cd ~/projects/folzio
   scripts/dev/publish.sh
   grep -n "dev-repo-note\|\[!NOTE\]" ../folzio-oss/README.md ../folzio-oss/README.ja.md
   ```

   `grep` が何も出さず、書き出し先の `git status` で README に差分がない（注記を置く前と同じ）こと。
