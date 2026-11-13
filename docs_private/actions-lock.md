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
2026-11-13 の保守者の画面確認では、この既存ジョブが `protect-master` の必須チェックに指定されている。
発行元は `Any source` のため、GitHub Actions に限定することを推奨する。
実際の確認項目は [ブランチ保護の確認記録](repository-and-release.md#master-のブランチ保護保守者が設定する) を参照。

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
これは現在の接続の制約であり、画面での利用可否とは区別する。

2026-11-13 に保守者が管理画面で確認した結果（エージェントによる画面の直接確認ではない）:

| 対象 | Require lockfile の項目 | ポリシーの作成・有効化 |
|---|---|---|
| 開発用 `folzio-dev` | Settings → Actions → Policies で設定できる項目を確認済み | まだ作成しておらず、未有効化 |
| 公開用 `folzio` | 設定項目の利用可否は未確認 | 現在は未使用（保守者確認） |

開発用の正しい画面は [Actions Policies](https://github.com/yoshidax/folzio-dev/settings/actions/rules)。
以前案内した画面の `/settings/actions/policies` は 404 だった（保守者確認）。
上の REST API の `/actions/policies` は別のエンドポイントであり、画面の URL に合わせて変更しない。
公開用は Settings → Actions → Policies から画面を開き、利用可否と実際の URL を確認して記録する。
公開用には Ruleset も従来の Branch protection rule も存在しない（同日の保守者確認）。
既存の自動同期は GitHub App が公開用 `main` へ直接 push するため、開発用と同じブランチ保護をそのまま追加しない。
Require lockfile は Actions の実行ポリシーであり、導入のために公開用へ PR 必須のブランチ保護を追加する必要はない。
運用の確認結果は [公開用 main の保護設定](repository-and-release.md#公開用-main-の保護設定を変更する前の確認) を参照。

lock が生成・検証できること、runner が lock の SHA を使うこと、Require lockfile で未登録 workflow を拒否することは
それぞれ別の確認である。開発用の PR CI では runner ログの `Using locked action versions from the workflow's lockfile`
と SHA の一致を確認済みだが、ポリシーが有効化された証拠にはしない。

### マージから有効化までの順序

保守者が各リポジトリの管理権限で進める。**対象リポジトリの既定ブランチへの lock 反映と検証を終えてから、
そのリポジトリの Require lockfile を Active にする。開発用と公開用は別々に判断できる。**

1. 開発用 PR の文書・レビューを確定し、最新 head の CI と保守者のローカル確認を終える。
   `protect-master` の既存必須ジョブを維持する。発行元を GitHub Actions に限定することも推奨する。
2. 保守者が PR を開発用 `master` にマージする。
3. マージ済み `master` で両方の lock を `python3 scripts/dev/actions-lock.py --verify` により確認する。
   または macOS Swift CI を `master` 指定で手動実行して確認する。利用中の作業ブランチや手動実行する古い参照に
   lock がない場合、その参照の実行がポリシーで止まるため、対象と移行方針も確認する。
4. 開発用の Actions Policies で全 workflow を対象とする Require lockfile ポリシーを作成し、Active にする。
   Evaluate が選べる場合は先に評価する。既存の許可アクションの設定も確認する
   （lock 採用後はタグではなく固定した SHA に対して許可が判定される）。
5. 開発用の通常 CI を実行し、ポリシーが適用された実行と有効化したポリシーの URL・状態を記録する。
6. 公開用の管理画面で Require lockfile の利用可否を確認する。この読み取りは開発用の有効化を待たずに行ってよい。
   [通常の公開手順](repository-and-release.md#通常の公開-リリース-pr-と-ci-候補) に従い、
   次の通常リリースで管理元の `release.yml` と `actions.lock` を対で公開用 `main` に反映する。
   この lock 導入 PR は `release.json` を変更しないため、マージだけでは通常の自動同期は行われない。
   早期のソースのみの反映が必要な場合は、既存のリリース判定と writer への影響を別途検討する。
   公開用の直接編集、通常経路を外れた手動 push、ブランチ保護の追加をこの導入手順として行わない。
7. 公開用 `main` の実際のツリーで `gh actions-lock --verify` を実行し、全 workflow の登録と依存の整合を確認する。
   利用できる場合は公開用のポリシーも作成・有効化し、通常の公開 workflow 実行時に適用を確認する。
   通常 CI の検証のためだけに公開・配布 workflow を起動しない。
   有効化後も、次の通常リリースで同期 App の `main` 更新と公開用 workflow の起動が成功することを確認する。
8. 各リポジトリの確認日・ポリシーの URL と状態・確認した実行を追記する。
   公開用で利用できない場合は画面や公式情報を根拠として記録し、固定済み依存の実行と検証を維持する。

現在の残作業は、PR の最新 head の確認とマージ、各既定ブランチへの反映後の検証、開発用ポリシーの作成・有効化、
公開用の利用可否確認・反映・有効化、およびその実行記録。設定画面で項目を確認しただけでは有効化済みにしない。

公式情報:

- [workflow dependency lockfiles](https://docs.github.com/en/actions/concepts/security/workflow-dependency-lockfiles)
- [作成・更新](https://docs.github.com/en/actions/how-tos/secure-your-work/lock-workflow-dependencies)
- [ポリシーの導入](https://docs.github.com/en/actions/how-tos/administer/enforce-workflow-lockfiles)
- [workflow 実行のポリシー](https://docs.github.com/en/actions/how-tos/administer/control-workflow-execution)
- [Actions policies API](https://docs.github.com/en/rest/actions/policies)
- [公式 CLI](https://github.com/github/gh-actions-lock)
