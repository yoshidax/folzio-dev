# Quickstart: 製品仕様の形式の検査のゲートへの組み込み

## CI の Linux のジョブと同じコマンド

```bash
python3 --version
python3 scripts/dev/check-spec-format.py
python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_spec_*.py"
```

## 失敗することの確認（SC-163）

一時的なコピーで `specs/product/` を崩し、検査が終了コード 1 で終わることを確かめる。作業ツリーは変えない。

```bash
tmp="$(mktemp -d)"
git archive HEAD | tar -x -C "$tmp"
printf '\n- 引用「途中で\n  改行した」行\n' >> "$tmp/specs/product/search.md"
(cd "$tmp" && python3 scripts/dev/check-spec-format.py); echo "exit=$?"
rm -rf "$tmp"
```

- `quote-split` のエラーが表示され、`exit=1` になる

## 記述の確認（SC-162）

```bash
grep -n "check-spec-format.py" AGENTS.md docs_private/cloud-agent-workflow.md .github/workflows/macos-swift-ci.yml \
  .github/pull_request_template.md shared-skills/folzio-sdd-increment.md .specify/workflow-src/*.yml .specify/workflows/*/workflow.yml
```

- ローカルの Phase の検証ゲート、Cloud の検証ゲート、CI、PR のテンプレート、SDD increment の手順と workflow のそれぞれに出る

## macOS のジョブが変わらないことの確認（SC-164）

```bash
git diff origin/master -- .github/workflows/macos-swift-ci.yml
```

- 差分は、`spec-checks` のジョブの追加（とその説明のコメント）だけである

## この feature の検証

1. 上のコマンドがすべて期待どおりになる
2. Cloud の検証ゲート: `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、
   `scripts/dev/check-skill-sync.sh`、`scripts/dev/check-spec-ids.sh`、`python3 scripts/dev/check-spec-format.py`、
   `python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py"`
3. workflow の YAML が読めること: `python3 -c 'import yaml'` が使えれば、変えた YAML を読み込んで確かめる
4. PR を作った場合は CI が動くので、Linux のジョブと macOS のジョブの結果を確かめる（US67-AS3 の失敗側は、上の手動の確認で代える）
