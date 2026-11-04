# Quickstart: 開発用と公開用の workflow の管理

検証の手順。詳細な規則は [contracts/publish-workflows.md](contracts/publish-workflows.md) と [data-model.md](data-model.md) にある。

## 1 自動テスト（Cloud とローカル）

前提: `git`、`rsync`、Python 3。`swift` はテストが偽物に置き換えるので要らない。

```bash
python3 -I -m unittest discover -s scripts/dev/tests -p "test_publish_folzio.py"
```

期待する結果: すべて `OK`。次を確かめる（FR-294）。

| テスト | 確かめること | 対応 |
|---|---|---|
| 開発用 workflow の除外 | `macos-swift-ci.yml` と、新しい名前の開発用 workflow が公開先に置かれない | US61-AS1、AS2 |
| 除外設定の不備 | `/.github/workflows export-ignore` がないと同期の前に失敗し、公開先が変わらない | US61-AS3 |
| 公開用 workflow の配置 | 管理元の `release.yml` が同じ内容で置かれ、`README.md` とサブディレクトリの中は置かれない | US62-AS1、EC-204、EC-205 |
| 変更と削除 | 管理元で変更・削除して書き出し直すと、公開先も変わる・消える | US62-AS2、AS3 |
| 定義がない | 公開先に `.github/` がない。公開先に直接置いた workflow も消える | US62-AS4、EC-203 |
| 同じ名前 | 開発用と管理元に同じ名前があると、管理元の内容が置かれる | US62-AS5 |

## 2 実際のリポジトリでの確認（Cloud とローカル）

`git archive` の結果に workflow がないこと（SC-153）:

```bash
git archive HEAD | tar -t | grep -E '^\.github/workflows/' || echo "workflow なし"
```

期待する結果: `workflow なし`。

## 3 Cloud の検証ゲート

`AGENTS.md` の「Cloud Agent の作業」の「検証ゲート」の検査を行う。

```bash
scripts/check-no-network.sh
scripts/check-readme-sync.sh master
scripts/dev/check-english-comments.sh
scripts/dev/check-skill-sync.sh
scripts/dev/check-spec-ids.sh
python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py"
```

## 4 CI（SC-156）

アプリのコードは変えないが、開発用 CI が今までどおり動くことを、PR の作成時の CI（`macOS Swift CI`）で確かめる。

## 5 保守者のローカルでの確認

1. 公開のテスト（上の 1）を macOS で実行する。
2. 実際の書き出しで、公開先に `.github/workflows/` がないことを確かめる。書き出し先は一時ディレクトリにし、`../folzio-oss` を変えない。

   ```bash
   scripts/dev/publish.sh "$(mktemp -d)/folzio-oss"
   ```

   期待する結果: 「公開用 workflow はありません」と表示され、ビルドとテストが通り、`git status --short` の一覧に `.github/` がない。
3. 起動スモーク: アプリのコードを変えないが、`AGENTS.md` の検証ゲートに従い、`scripts/make-app.sh` の後に `open .build/Folzio.app` で
   3 ペインが表示されることを確かめる。
