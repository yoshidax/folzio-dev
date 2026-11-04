# Quickstart: 製品仕様の形式の検査

## 形式の検査

```bash
python3 scripts/dev/check-spec-format.py
```

- 成功（終了コード 0）: エラーが 0 件で、警告がすべて基準値以下
- エラーが出たら、表示された行を直す。書き方は `specs/product/README.md` の「書き方のルール」
- 警告が基準値を超えたら、増えた警告を直す。直せない理由があれば、理由を PR に書いて基準値を更新する

```bash
python3 scripts/dev/check-spec-format.py --update-baseline
```

## 形式のみの変更の確認

```bash
python3 scripts/dev/check-spec-equivalence.py origin/master
```

- 成功（終了コード 0）: 本文の追加・削除がない。表示された「移動」は、文脈が変わっていないかを人間が確かめる
- 失敗（終了コード 1）: 表示された「追加」「削除」が意図したものかを確かめる。形式のみの PR では直す

## 回帰テスト

```bash
python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_spec_*.py"
```

## この feature の検証

1. 形式の検査が、修正後の `specs/product/` で成功する（SC-157）
2. 回帰テストがすべて成功する（SC-158、SC-159）
3. 分断の修正のコミットの後、`check-spec-equivalence.py origin/master` が差分なしで成功する（SC-160）
4. Cloud の検証ゲート: `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、
   `scripts/dev/check-skill-sync.sh`、`scripts/dev/check-spec-ids.sh`、
   `python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py"`
5. アプリのコードは変えないため、CI の `swift build`・`swift test` と起動スモークの結果は変わらない見込み。
   PR を作る場合は CI が動くので、結果を確かめる
