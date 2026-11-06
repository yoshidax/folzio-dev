# Research: 開発用リポジトリの公開の準備

**Feature**: [spec.md](spec.md) | **Date**: 2026-11-06

## R1: README の注記の範囲の示し方

- **Decision**: 1 行全体が `<!-- dev-repo-note:start -->` の行と `<!-- dev-repo-note:end -->` の行で範囲を示す。
  注記の本文は GitHub の Markdown のアラート（`> [!NOTE]`）で書き、`English | 日本語` の言語の切り替えの行の後に置く。
- **Rationale**:
  - HTML コメントは GitHub の表示に出ないので、開発用リポジトリの README の見た目を崩さない。
  - 行全体の一致で判定すると、本文中の言及を誤って範囲と見なさない。
  - 言語の切り替えの行の後に置くと、範囲と直後の空行を除いた結果が、注記を置く前の README と同じになる（FR-314）。
  - `scripts/check-readme-sync.sh` の構造の比較は、見出し・箇条書き・表・コードブロックだけを見る
    （`scripts/check-readme-sync.sh` の `skeleton`）。引用（`>`）と HTML コメントの行は比較の対象外なので、
    英語版と日本語版に同じ形の注記を置けば、検査はそのまま通る。
- **Alternatives considered**:
  - 見出しの直前（ファイルの先頭）に置く: 除いた後に先頭の空行の扱いが要り、書き出し前との一致が崩れやすい。
  - `check-readme-sync.sh` に印の数の比較を足す: このスクリプトは公開用（`scripts/` の直下）で、公開用リポジトリに
    開発用の印の知識を持ち込むことになる。印の検査は開発専用のスクリプトに置く。

## R2: 注記を除く処理の置き場所

- **Decision**: 開発専用のスクリプト `scripts/dev/strip-readme-dev-note.sh` を新しく作り、`scripts/dev/publish.sh` が
  `git archive` で取り出した一時ディレクトリの `README.md` と `README.ja.md` に対して呼ぶ。
  印の対応が崩れている場合と、除いた後に印の文字列が残る場合は、非ゼロで終了する。
- **Rationale**:
  - 一時ディレクトリでの処理なので、失敗しても公開先への同期の前に止まる（FR-315）。
  - 単体のスクリプトにすると、`rsync` のない Cloud でもテストできる（既存の `test_publish_folzio` は `rsync` を前提とし、
    Cloud では失敗する。`docs_private/cloud-agent-workflow.md` の 5 章）。
  - `scripts/dev/` は書き出しから除かれるので、公開用リポジトリに入らない（FR-177）。
  - macOS の bash 3.2 と BSD の awk で動く書き方にする（`publish.sh` と同じ前提）。
- **Alternatives considered**:
  - `publish.sh` の中に処理を直接書く: Cloud でテストできない。
  - Python で書く: 既存の書き出しの処理は bash と git だけで動いており、依存を増やさない。

## R3: CI を PR への push のたびに動かす

- **Decision**: `.github/workflows/macos-swift-ci.yml` の `pull_request` の `types` を
  `[opened, synchronize, reopened, ready_for_review]` にする。`workflow_dispatch`、`concurrency`
  （`cancel-in-progress: true`）、`permissions: contents: read`、ジョブの名前は変えない。
- **Rationale**:
  - `synchronize` は PR の head が更新されたとき（push）に起きる。`ready_for_review` は既定の種類に含まれないので、明示する。
    `reopened` は既定の種類に含まれ、閉じた PR を開き直したときの検証のために残す。
  - `concurrency` の group は `github.ref`（PR では PR ごとの ref）なので、続けて push すると古い実行が取り消される（US69-AS2）。
  - ファイルの変更による実行の条件（`paths` など）は付けない。workflow 全体がスキップされると、必須チェックが待ちのまま残る（EC-217）。
  - ジョブの名前（`Build and test (macOS 15 / arm64)`）を必須チェックの名前にするので、変えない（EC-218）。
- **Alternatives considered**: `types` を省いて既定にする: `ready_for_review` が含まれず、Draft から Ready にした時点の
  検証が抜ける。

## R4: `master` のブランチ保護の設定

- **Decision**: GitHub の rulesets を 2 つ作る手順を、`docs_private/repository-and-release.md` に書く。設定は保守者が行う。
  1. 「master の保持」: 対象は default ブランチ。「Restrict deletions」と「Block force pushes」。bypass の対象はなし。
  2. 「master への PR と CI」: 対象は default ブランチ。「Require a pull request before merging」（承認の数は 0）と
     「Require status checks to pass」（`Build and test (macOS 15 / arm64)`、GitHub Actions から）。bypass の対象に
     Repository admin を加える。
  - fork の workflow: Settings → Actions → General の「Approval for running fork pull request workflows from contributors」で、
    「Require approval for all external contributors」を選ぶ。
  - 必須チェックは、この PR の CI が 1 回動いた後に、ruleset の画面の候補から選ぶ（名前を手で入力しない）。
- **Rationale**:
  - 保守者は `scripts/dev/merge-to-master.sh` で、ローカルでマージした `master` を直接 push する（`merge-to-master.sh` の
    `git push origin "$commit:refs/heads/master"`）。「Require a pull request」を例外なく適用すると、このローカルの運用
    （FR-194）が拒否される。管理者だけを bypass にすると、Agent（保守者の権限で動く GitHub App や MCP）にも同じ権限が
    及ぶ可能性があるが、Agent の `master` への push とマージは、別の層（`scripts/dev/check-git-push.py`、
    `.claude/settings.json` の deny、AGENTS.md）で禁止している。
  - 強制 push と削除の禁止は、保守者のローカルの操作でも必要がないので、bypass なしの別の ruleset に分ける。
  - 承認レビューを必須にしない（保守者の決定）。保守者は 1 人で、自分の PR を承認できない。
  - 「Require branches to be up to date before merging」は使わない。PR はスカッシュマージで、`master` が進むたびに
    取り込みと CI の待ちが要るほどの並行はない。必要になれば後で有効にする。
  - README の運用方針（外部からの貢献は受け付けない）と合わせ、外部の貢献者の fork からの workflow はすべて承認制にする。
- **Alternatives considered**:
  - classic の branch protection: 同じことができるが、bypass の対象を細かく分けられない。公開リポジトリでは rulesets も
    無料で使えるので、rulesets を選ぶ。
  - bypass なしの 1 つの ruleset: `merge-to-master.sh` の push が拒否される。ローカルの運用を変える判断が要る。
- **未確認（保守者が設定時に確かめる）**:
  - GitHub Free の公開リポジトリで rulesets を使えるか。公式文書（About rulesets）には、明記した文が見つからなかった。
    使えない場合は classic の branch protection で同じ項目を設定する（classic では、管理者は既定で保護の対象外。出典 3）。
  - 必須チェックの名前がジョブの `name:` になるか。文書では確かめられなかったため、画面の候補から選ぶ手順にした。
  - bypass の「Always allow」の管理者の直接の push が、PR と必須チェックの規則があっても通るか。文書は「For pull requests only」
    との対比で示すだけなので、設定後に `merge-to-master.sh` の push で確かめる。

## R5: CI の起動・再実行の許可の規則（TAK-53）をなくす範囲

- **Decision**: 次の規則と設定を削除する。`.claude/settings.json` だけは Agent が編集できないので、保守者に依頼する（A-198）。
  - `AGENTS.md` の「CI の起動・再実行…保守者の許可を得る」の行
  - `docs_private/cloud-agent-workflow.md` の 4 章の「再確認（保守者の許可が必要）」と「権限設定」の段落、無料枠と費用の記述
  - `.codex/rules/sdd.rules` の `gh workflow run`・`gh run rerun` の `prompt` の規則
  - `.kilo/kilo.jsonc` の `gh workflow run *`・`gh run rerun *`・`github_actions_run_trigger` の `ask`
  - `.claude/settings.json` の `permissions.ask` の `mcp__github__actions_run_trigger`・`Bash(gh workflow run *)`・
    `Bash(gh run rerun *)`（保守者が編集する）
  - `docs_private/agents/README.md` の例（TAK-53 の CI の起動）を、今も有効な例（TAK-70 の依存ツールの導入）に替える
- **Rationale**: 費用の制約がなくなり（A-106 の変更）、許可を待つと CI の失敗の修正が遅れるだけになる。
  「PR は保守者の依頼があったときだけ作る」規則は、保守者の決定で残す。理由は、設計のレビューと Cloud での検査の後に、
  保守者が見る準備ができた状態で PR を作るため、と書き直す。
- **Alternatives considered**: 規則を残して理由だけ直す: 保守者の決定（2026-11-06）で採らない。

## R6: 「非公開」を前提にした記述の直し方

- **Decision**: 現行の文書・規約・設定・仕様のうち、開発用リポジトリを非公開とする記述を直す。完了した feature、
  `.specify/bugs/`、`docs_private/retrospective/`、`docs_private/release-notes/` は当時の記録として変えない（EC-219）。
  - 対象の一覧は、`grep -rn "非公開\|private リポジトリ\|private repository"` などで洗い出した結果を tasks に書く。
  - `docs_private/` という名前は変えない。多くの文書と検査（`publish.sh`、`.gitattributes`、AGENTS.md の参照）が
    この名前を使っている。「公開用リポジトリへ書き出さない文書」という意味だと、`repository-and-release.md` に書く。
- **Rationale**: 名前の変更は影響が大きく、この feature の目的（公開の前提に合わせる）には要らない。
- **Alternatives considered**: `docs_private/` を `docs_dev/` などへ改名する: 参照の更新と検査の変更が多く、別の Issue で扱う。

## 出典

2026-11-06 に確認した GitHub の公式文書。

1. [Events that trigger workflows](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows):
   「By default, a workflow only runs when a `pull_request` event's activity type is `opened`, `synchronize`, or `reopened`.」
   `ready_for_review` は既定に含まれない（R3）。
2. [Troubleshooting required status checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks):
   path などの絞り込みで workflow がスキップされると、「Associated checks stay in a 'Pending' state and block merging.」（EC-217）
3. [About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches):
   「By default, the restrictions of a branch protection rule don't apply to people with admin permissions to the repository.」
   classic の保護で bypass の一覧を使えるのは、組織のリポジトリだけ。
4. [Creating rulesets for a repository](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository):
   bypass の対象に Repository admin を選べる。「For pull requests only」を選ぶと PR が必要になり、既定の「Always allow」との違いになる。
   「Require branches to be up to date before merging」は、選ぶと base の最新を取り込むまでマージできない（R4 では使わない）。
5. [Available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets):
   「Restrict deletions」「Block force pushes」「Require a pull request before merging」（承認は必須でない）、
   「Require status checks to pass before merging」。
6. [Managing GitHub Actions settings for a repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository):
   Settings → Actions → General の「Approval for running fork pull request workflows from contributors」に、
   「Require approval for all external contributors」がある。既定は、初めての貢献者だけ承認が要る。
7. [About billing for GitHub Actions](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions):
   「The use of standard GitHub-hosted runners is free: In public repositories」。上限がないとは書かれていない（A-106 の変更）。
