# GitHub Actions の依存の固定

[TAK-91](https://linear.app/takyoshida/issue/TAK-91) の運用手順。
workflow のアクションは公式 CLI が生成する `actions.lock` で固定する。
lock と `uses:` の変更は同じコミットでレビューする。

## 管理するファイル

| 対象 | workflow の管理元 | lock の管理元 |
|---|---|---|
| 開発用 `yoshidax/folzio-dev` | `.github/workflows/*.yml`・`*.yaml` | `.github/workflows/actions.lock` |
| 公開用 `yoshidax/folzio` | `scripts/dev/oss-workflows/*.yml`・`*.yaml` | `scripts/dev/oss-workflows/actions.lock` |

公開用の lock の workflow キーも `.github/workflows/release.yml` のような**書き出し先のパス**にする。
管理元のパスをキーにした lock は、公開用リポジトリでは使えない。
`scripts/dev/actions-lock.py` は両方の通常ファイルを、それぞれ一時的な `.github/workflows/` にコピーして
公式 CLI を実行する。両方の生成と全出力の確認が成功してから、lock と CLI が書き換えた workflow を管理元へ戻す。
前提チェック・どちらかの CLI・出力確認が失敗した場合と検証時には、両方の管理元を変更しない。
開発用と公開用を混ぜてひとつの lock にしない。

対象は Git の追跡対象の通常ファイル（ステージ済みの新規ファイルを含む）で、名前は exporter と同じ
`[A-Za-z0-9_.-]+`、拡張子は `.yml`・`.yaml` とする。新しい workflow は先に `git add` する。
直下に未追跡・ignore 対象の workflow があれば、下書きを lock に混ぜないよう CLI の前にエラーにする。
サブディレクトリと workflow のシンボリックリンクは書き出しと同様に除外する。
`actions.lock` のシンボリックリンクは拒否する。最後の workflow を削除するときは lock も削除する。

`export-public.sh` は指定したコミットの公開用 workflow と `actions.lock` を同じ名前・内容で書き出す。
開発用の lock は `.gitattributes` の除外対象なので書き出さない。公開用リポジトリを直接編集しない。

## 初回の準備

GitHub CLI と GitHub の認証が必要。依存ツールの導入・更新は `AGENTS.md` に従い保守者に確認する。
この手順と CI は公式拡張の `v0.4.1` を使う。導入済みの版は、下記のハッシュ照合後に `gh actions-lock --version` で確認する。

```bash
gh extension install github/gh-actions-lock --pin v0.4.1
```

タグ・リリースアセットも差し替わり得るため、実行前に導入したバイナリの SHA-256 を照合する。
CI は専用の `XDG_DATA_HOME` に導入し、下記の Linux x64 の値を workflow に固定して照合してから実行する。
ローカルでも `${XDG_DATA_HOME:-$HOME/.local/share}/gh/extensions/gh-actions-lock/gh-actions-lock` の
SHA-256 を `shasum -a 256`（macOS）または `sha256sum`（Linux）で求め、対応する値と一致することを確認する。

| v0.4.1 のアセット | SHA-256 |
|---|---|
| linux-amd64 | `39deb2fe714dbf74b073d8245fc7f3d50cd0eee18d5c0900e9e849ae933ae17e` |
| darwin-arm64 | `f205ea5dbbda67165e08aab1fb6395290ca62f0a038bf27d4b684abd0816635c` |
| darwin-amd64 | `4ef64599440398999f184321d5237df131721434901ecaaf3da6aa018bdd1f8f` |

2026-11-13 に公式 [v0.4.1 のリリース情報](https://api.github.com/repos/github/gh-actions-lock/releases/tags/v0.4.1)
の各アセットの `digest` を確認し、Linux x64 は導入済みバイナリの計算値との一致も確認した。
初回に採用するハッシュ値の信頼性と、CLI 自体の実装のレビューは別途必要であり、照合だけでコードの安全性を保証するものではない。
拡張の更新は保守者が版とアセットを確認し、ローカルと `.github/workflows/macos-swift-ci.yml` の版・ハッシュを揃える。
ハッシュ不一致時は新しい値を自動採用せず、上流の変更を調べる。
lock は手で編集しない。

## 作成・更新・検証

リポジトリのルートで実行する。引数なしは両方の workflow を全件走査し、追加・削除も反映する。

```bash
python3 scripts/dev/actions-lock.py
python3 scripts/dev/actions-lock.py --verify
git diff -- .github/workflows scripts/dev/oss-workflows
```

オフラインで依存の登録漏れだけ確認する場合:

```bash
python3 scripts/dev/actions-lock.py --verify-local
```

`--verify-local` は上流の履歴やリポジトリの同一性を確認しないため、マージ前にはオンラインの
`--verify` も通す。macOS Swift CI の `Verify workflow dependency lockfiles` ジョブも両方を
`--verify` で検査する。CI は lock を更新・コミットしない。

既存の必須チェック `Build and test (macOS 15 / arm64)` は検証ジョブに依存する。
検証失敗時も `always()` で起動し、最初のステップで検証結果が success でなければ失敗させる。
依存失敗で必須ジョブが単にスキップされ、成功扱いになることを避ける。
ブランチ保護の設定は保守者が上記のジョブを必須チェックとして維持する。
さらに `Verify workflow dependency lockfiles` も必須チェックに追加すると、失敗の理由を直接確認できる。
このセッションではブランチ保護の実際の設定までは確認していない。

更新は当面手動で行う。workflow の追加・削除、`uses:` の変更時に再生成し、月次および
利用アクションのセキュリティ修正時にも上流のリリースを確認する。更新担当は保守者。
Dependabot は今回導入しない。公開用の管理元は標準の `.github/workflows/` の外にあるため、
将来導入するときも両方の管理元が更新・検証されることを確認する。

CLI は `@v4` などを解決した完全なバージョンタグへ書き換える場合がある。
更新したいバージョンに `uses:` を変えてから再生成し、次を確認する。

- `commit` の差分が採用したい上流の変更であること
- `owner_id`・`repo_id` が変わる場合、そのリポジトリが意図したものか
- workflow の全件が登録されていて、削除した workflow・依存が残っていないこと
- 公開用のキーが `.github/workflows/` 配下であること

移動した参照を更新する必要があるときは、上流の履歴を確認してから実行する。

```bash
python3 scripts/dev/actions-lock.py --relock
python3 scripts/dev/actions-lock.py --verify
```

`--accept-moved` は自動化では使わない。このラッパーでも受け付けない。
履歴が書き換わったなどのエラーは、原因を確認してから保守者が個別に対処する。
今の workflow は reusable workflow・ローカルアクションを使っていない。将来追加する場合は、
ジョブ単位の reusable workflow 呼び出しやコンテナイメージがこの lock の対象外であることに注意する。

## Require lockfile の確認と有効化

2026-11-13（日本時間）の確認では、両方とも個人所有の公開リポジトリであることを API で確認した。
一方、次の読み取りは、両方とも `403 Resource not accessible by integration` だった。

```bash
gh api -H 'X-GitHub-Api-Version: 2026-03-10' repos/yoshidax/folzio-dev/actions/policies
gh api -H 'X-GitHub-Api-Version: 2026-03-10' repos/yoshidax/folzio/actions/policies
```

公式 REST 文書では、この API はリポジトリの `Administration: write` を要求する。
これは現在の接続で確認できなかった記録であり、個人の公開リポジトリでは利用不可だと確認した記録ではない。
生成・検証できることと、実行時に lock が適用されることも区別する。
ポリシーの利用可否と有効化は未確認・未実施であり、ここだけで依存固定が実証済みとは扱わない。

保守者が管理権限で次を確認する。**lock を含まない既存ブランチの workflow を止めないよう、
開発用 master と公開用 main にそれぞれ lock が反映され、全件の `--verify` が通ってから有効にする。**

1. 各リポジトリの Settings → Actions → Policies を開き、Require lockfile の利用可否を確認する。
2. 利用できる場合は、全 workflow を対象とするポリシーを作り、Active にする。
   Evaluate が使える場合は先に評価する。既存の許可アクションの設定も確認する
   （lock 採用後はタグではなく固定した SHA に対して許可が判定される）。
3. 各リポジトリの Actions で実行結果を確認する。通常 CI の検証のために公開・配布 workflow を起動しない。
4. 利用可否、確認日、ポリシーの URL と状態、確認した実行をここへ追記する。
   利用できない場合も画面の表示や公式情報を根拠として残す。

管理画面: [開発用](https://github.com/yoshidax/folzio-dev/settings/actions/policies)・
[公開用](https://github.com/yoshidax/folzio/settings/actions/policies)。

公式情報:

- [workflow dependency lockfiles](https://docs.github.com/en/actions/concepts/security/workflow-dependency-lockfiles)
- [作成・更新](https://docs.github.com/en/actions/how-tos/secure-your-work/lock-workflow-dependencies)
- [ポリシーの導入](https://docs.github.com/en/actions/how-tos/administer/enforce-workflow-lockfiles)
- [workflow 実行のポリシー](https://docs.github.com/en/actions/how-tos/administer/control-workflow-execution)
- [Actions policies API](https://docs.github.com/en/rest/actions/policies)
- [公式 CLI](https://github.com/github/gh-actions-lock)
