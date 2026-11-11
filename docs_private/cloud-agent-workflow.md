# Cloud Agent の作業手順

**適用範囲**: 【Cloud】

Cloud Agent（Claude / Codex）が、Cloud 環境で feature またはバグ修正を進め、GitHub の PR にまとめるための手順。ローカルでの開発の手順は
[folzio-sdd-increment.md](../shared-skills/folzio-sdd-increment.md)、`AGENTS.md` の【ローカル】の節、そこから参照する [agents/](agents/) にあり、この手順書とは別に、そのまま使える。

この手順書は、feature の仕様（`specs/TAK-30-cloud-agent-workflow/`）の要件 FR-186〜FR-199 を実装したもの。規則の全体は `AGENTS.md` にあり、適用範囲（【共通】【ローカル】【Cloud】）は各見出しで示す。

## 全体の流れ

1. Issue を ID・URL・本文のどの形式で渡されても、対象を特定して Linear で内容を読み、`In Progress` にして、feature を始める（1、2 章）
2. `speckit-specify` → `speckit-plan` → `speckit-tasks` → `speckit-analyze` を順に実行し、**設計のレビューを保守者に受ける**。承認の前に実装しない
3. 実装し、Cloud でできる検査を行い、作業ブランチに push する（5、6 章）
4. 保守者が依頼したら、PR を作り、Linear を `In Review` にする（2、3 章）
5. CI の結果を読み、失敗なら直す（4 章）
6. 保守者がローカルで確認してマージする。完了の更新は、保守者の依頼があったときだけ行う（2、3 章）

`specs/product/` への反映は、PR の最後の作業にする（7 章）。

## 1 feature の始め方

1. **最新の `master` を取り込む**。ローカルの `master` ブランチは古いことがあるので、`git fetch origin master` の後、`origin/master` が作業ブランチの祖先であることを確かめる（`git merge-base --is-ancestor origin/master HEAD`）。祖先でなければ `git merge origin/master` で取り込む。履歴は書き換えない。
2. **Issue を特定して読む**。ID、URL、本文のどれを渡されても同じ手順で扱う。ID・URL からは対象を直接確認し、本文だけならタイトルや特徴的な文言で Linear を検索して候補を照合する。対象が一意に決まらなければ保守者に確認する。特定後は Linear の MCP（`get_issue`）で内容と関連情報を読む（[agents/linear.md](agents/linear.md)）。本文だけを渡されたことを、以後の工程を省く理由にしない。
3. **作業ブランチ上で作業する**。Cloud が指定した作業ブランチ（`git branch --show-current`）をそのまま使い、feature 用のブランチを新しく作らない。git 拡張の `before_specify` フック（`speckit.git.feature`。ブランチを作る）は**実行しない**。
4. **feature ディレクトリを指定する**。`specs/TAK-<nn>-<slug>` を `SPECIFY_FEATURE_DIRECTORY` として明示して、`speckit-specify` を実行する。`<slug>` は 2〜4 語の英小文字とハイフン。ブランチ名とディレクトリ名は独立している。`specs/TAK-<nn>-*` が既にあるときは、上書きせず保守者に確認する。
5. `speckit-specify` の前に、`specs/product/README.md` と関連する現行の仕様を読む。仕様書の `Input` に Issue の URL を記録する。
6. `.specify/feature.json` が、作った feature を指す。このファイルは `.specify/.gitignore` で管理対象外になっているため、コミットされず、並行する PR の間で競合しない。以後の `speckit-plan`、`speckit-tasks`、`speckit-analyze` は、このファイルから feature を見つける。
7. 作業の区切りでコミットし、作業ブランチに push する（`git push -u origin <ブランチ>`。6 章）。

### 実装前の設計ゲート

Issue の ID・URL・本文から対象を特定した後は、入力形式によらず次を順に行う。保守者からの「対応してください」などの作業依頼は、設計レビューの承認や省略許可として扱わない。

1. `speckit-specify` で feature の `spec.md` を作り、`speckit-plan` で `plan.md`、`speckit-tasks` で `tasks.md` を作る。
2. `speckit-analyze` を実行し、仕様・計画・タスクの整合性と指摘を確認する。手作成の計画文書やファイルの存在を、これらの工程を実行した証拠にしない。
3. 実装前に `.specify/feature.json` が今回の feature ディレクトリを指し、その中に `spec.md`・`plan.md`・`tasks.md` があることを確認する。状態ファイルや成果物が欠けていれば、該当する工程からやり直す。分析結果も得られていなければ `speckit-analyze` を実行する。
4. 成果物の差分、分析結果、残る判断事項を保守者に提示して設計レビューを依頼する。保守者がこの設計について明示的に実装を承認するまで、`speckit-implement` やアプリ・手順の実装を始めない。承認されず修正を求められたら、設計文書を直して再分析し、再レビューを受ける。

成果物の欠落は既存の前提確認と上の手順で検出する。現時点では専用の検査スクリプトを追加しない。ファイルの存在だけでは、保守者のレビューや承認を確認できないため、承認は会話での明示的な回答を確認する。

たとえば ID や URL を添えずに「ファイルリストでファイルを選択したときの右クリックメニューに、Finder と同様の『このアプリケーションで開く』を追加する。対応してください」と渡された場合も、まず候補を検索して対象 Issue を確認し、上の 4 項目を経てから実装する。本文から対象を特定できないときは、対象の確認を待つ。

### Codex Cloud の Git 通信

GitHub 連携、Cloud 環境のネットワーク設定、コマンドのサンドボックス権限は別々に確認する。GitHub MCP が使えても、
シェルの `git fetch` が同じ通信権限を持つとは限らない。Cloud で適用される指示やネットワーク設定を先に確認する。

- `Failed to connect to proxy port 8080` が出た場合、プロキシや GitHub の障害と決めつけず、コマンドにネットワークアクセスが
  許可されているかを確認する。`github.com` の許可とリポジトリへの権限も別途確認する。
- Codex のコマンド実行でネットワークが制限されている場合、サポートされるコマンド単位のネットワーク権限を要求し、
  まず読み取り専用の `git ls-remote origin HEAD` で再確認する。利用できる権限や承認手順は実行環境の指示に従う。
  その後、必要な `git fetch` を実行し、`push` は `AGENTS.md` の Git の規則に従う。
- プロキシ設定の解除、TLS 検証の無効化、サンドボックスや承認の回避は行わない。権限を指定しても失敗した場合は、
  実際のエラーと Cloud のネットワーク設定を確認し、未解決の事実を報告する。認証情報を出力しない。
- 2026-11-01 の TAK-9 では、通常の `git ls-remote` が上記エラーで失敗し、コマンド単位のネットワーク権限を指定すると
  成功した。これは一例であり、同じエラーの原因が常に同じとは限らない。

参照: [Agent approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security)、
[Cloud environments](https://developers.openai.com/codex/environments/cloud-environments)。

## 2 Linear

Linear の Issue の読み方と状態の更新（着手、PR の作成後、完了）は、[agents/linear.md](agents/linear.md) にある。ローカルと共通の手順。

## 3 PR とマージ

- **PR は、保守者が依頼したときだけ作る**。作業が終わっても、依頼なしには作らない。作成できる状態であること（作業ブランチが push 済みで、自己検査が通っている）を保守者に報告して、待つ。設計のレビューと Cloud での検査を終え、保守者が見る準備ができた状態で PR を作るため。Draft の PR の Ready 化も、保守者が依頼したときだけ行う。
- PR のタイトルと本文に、Issue 番号（`TAK-<nn>`）を入れる。本文には、変更の概要、検証の結果、**確認していないこと**を正直に書く。
- 本文の構成は、[.github/pull_request_template.md](../.github/pull_request_template.md) に従う（概要・変更・仕様の反映・検証・確認していないこと）。GitHub の画面から作る PR には自動で入るが、GitHub の MCP ツール `create_pull_request` で作るときは自動では入らない。Agent は、このファイルを読み、見出しを変えずに本文を作る。記入案内の HTML コメントは、記入後に消してよい。テンプレートは開発用リポジトリだけにあり、公開用リポジトリへは書き出さない（`.gitattributes` の `export-ignore`）。
- PR を作った後、保守者に確認して、PR の購読（`subscribe_pr_activity`）をする。CI の結果とレビューのコメントが、セッションに届く。
- **マージは保守者だけが行う**。`master` には、PR の最新の head で CI が成功しないとマージできないブランチ保護がある（[repository-and-release.md](repository-and-release.md) の「開発用リポジトリの公開とブランチ保護」）。Agent は、PR をマージしない（GitHub の MCP ツール `merge_pull_request` も、権限の設定の拒否リストにある。誤ってマージされる恐れがあるため、実際に呼んで確かめてはいない）。
- 保守者のローカルでの確認（起動スモークなど）が必要なことを、実行するコマンドと確認する点を具体的に示して知らせる。
- マージ後に保守者が完了更新を依頼したら、PR が `merged` であることと、変更が `master` に含まれることを確認して、`Done` に更新する。

## 4 CI の確認

Cloud 環境には Swift がないため、`swift build` と `swift test` は、GitHub Actions の macOS の CI（`.github/workflows/macos-swift-ci.yml`）でしか確認できない。

この CI は開発用で、公開用リポジトリには書き出さない（TAK-40）。開発用の workflow は `.github/workflows/`、公開用リポジトリだけで動かす workflow は `scripts/dev/oss-workflows/` に置く。詳細は [repository-and-release.md](repository-and-release.md) の「GitHub Actions の workflow」にある。

**CI の構成（2026-11-07 時点）**: `macos-15` のランナー、Xcode 16.0（Swift 6.0）。HEAD の公開ツリー検査 → 公開・配布スクリプトの回帰 → `swift build` → 通常のテスト（`swift test --no-parallel --skip FolzioPerformanceTests`、10 分のタイムアウト）→ 性能テスト（失敗を許容、10 分のタイムアウト）。ジョブ全体のタイムアウトは 30 分。テストの各ステップに、ジョブ全体より短いタイムアウトがあるため、止まったテストが 30 分間ランナーを占有することはなく、止まった箇所をログから読める。通常のテストを直列で実行するのは、3 コアのランナーで並列に実行すると進まなくなったため（原因は未調査）。

**いつ動くか**: PR を作ったとき、PR に push したとき（Draft の PR を含む）、閉じた PR を開き直したとき、Draft の PR を Ready にしたときに**自動で動く**。手動でも実行できる（`workflow_dispatch`）。続けて push すると、古い実行は取り消され、最新の head の実行だけが残る（`concurrency`）。開発用リポジトリは公開リポジトリなので、macOS を含む標準ランナーの使用は無料である（TAK-80）。

**結果の確認と修正**:

1. 成否は、GitHub の MCP の `pull_request_read`（`get_check_runs`）で確認する。ジョブのステップごとの状態は `actions_list`（`list_workflow_jobs`）で見られる。**ただし、性能テストのステップは `continue-on-error` のため、失敗しても check もステップも `success` と表示される**。性能テストの結果は、`get_job_logs` でログの末尾を読み、`Test run with 27 tests passed` か `failed` かを確かめてから報告する（2026-10-31 に、同じコミットで 27 件中 3 件が失敗した実行と、全件成功した実行があった。共有ランナーでの測定のぶれと考えられる）。
2. 失敗したら、`get_job_logs`（`job_id`、`return_content`、`tail_lines`）でログを読み、原因を判断する。**実行中のジョブのログは取得できない**（404）。完了またはタイムアウトを待ち、推測で修正しない。
3. 修正は、ログを読んで原因をまとめてから行い、まとめて push する。push すると CI が自動で動くので、その結果で再確認する。
4. **置き換える API は、使う前に、ヘッダーや文書で存在を確認する**。たとえば `mach_task_self()` は C のマクロで Swift から使えず、確認せずに置き換えたために CI を 1 回無駄にした。
5. 同じ原因の失敗を 3 回直しても解決しない場合は、作業を止めて、状況を保守者へ報告する。

**再実行**: 共有ランナーのぶれなど、コードを変えずに確かめ直したいときは、Agent は保守者の許可を待たずに再実行してよい。GitHub MCP の `actions_run_trigger`（`rerun_failed_jobs`、`rerun_workflow_run`、`run_workflow`）を使う。`run_workflow` では `workflow_id` に `macos-swift-ci.yml`、`ref` に作業ブランチを指定する。CI の起動・再実行に保守者の許可を求めていた規則（TAK-53）は、開発用リポジトリの公開で費用の制約がなくなったため、TAK-80 で削除した。

直接の `brew install` は Claude の `permissions.ask` でも確認対象とする。Codex と Kilo の禁止設定と制約は `docs_private/agents/skills-and-codex.md` を参照する。

## 5 検証ゲート（Cloud 版）

`AGENTS.md` の「Phase の検証ゲート」（【ローカル】）の Cloud 版。検査を、実行する場所で 3 つに分ける。

| 実行する者 | 検査 |
|---|---|
| Cloud（Agent） | `scripts/dev/check-all.sh`（実行する検査はスクリプトを参照） |
| CI | `swift build`、`swift test`（通常のテストと性能テスト） |
| 保守者（ローカル） | 起動スモーク（`scripts/make-app.sh` の後に `open .build/Folzio.app` で 3 ペインの表示）、ローカルの最新の Swift でのビルドとテスト、`scripts/dev/tests` の macOS 固有のパッケージ・ローカル復旧テスト（Cloud では必要機能のない項目を明示的に skip し、macOS CI で確認する） |

- **起動スモークを省略して「CI が通ったから完了」にしない**。GUI の確認は保守者に依頼し、実行するコマンドと確認する点を具体的に示す。
- 憲章の「マージ前のゲート」（自動テストの通過）は、Cloud では**CI の成功と、保守者のローカルでの確認**で満たすと解釈する（憲章は改定しない）。
- Cloud では `swift` を使うコマンドを実行できない。Cloud（Agent）の検査は、`scripts/dev/check-all.sh` だけを実行する。

## 6 ブランチ

- push してよいのは、作業ブランチだけ（`claude/*`、`ci/*`、`chore/*`、`docs/*`、`feature/*`、`bugfix/*`、`agent/*`）。`master` / `main` への push、強制 push（`--force`、`-f`、`+` 付きの refspec）、リモートブランチの削除は、行わない。Claude と Codex の Bash フックは `scripts/dev/check-git-push.py` で検査する。Claude は `.claude/settings.json` の deny でも禁止し、`master` と `--force` の push が `--dry-run` で拒否されることを 2026-10-30 に確認した。Codex のフックは信頼の承認が必要で、MCP や直接 API 呼び出しは検査しない。`AGENTS.md` の規則と GitHub の default ブランチ保護も使う。
- **マージ済みのブランチは再利用しない**。PR はスカッシュマージされるため、作業ブランチの履歴は `master` と一致しなくなる。同じ名前で作り直すには強制 push が要り、禁止されている。次の作業は、最新の `master` から新しい `claude/` のブランチを作る。Cloud が指定した名前と別の名前を使うときは、保守者の許可を得る。
- 作業の途中で `master` が先に進んだら、`git merge origin/master` で取り込んでから、PR を更新する。履歴を書き換えない。
- 権限の設定（`.claude/settings.json`）は、**セッションの起動時に読み込まれる**。途中で設定を変えても、実行中のセッションには反映されない。反映するには新しいセッションが要る。Agent は、この設定ファイルを編集できない。
- push を検査するフック（`scripts/dev/check-git-push.py`）は、Bash のコマンドの文字列のどこかに push の呼び出しの記述があると（ヒアドキュメントや引用符の中も）、入れ子と見なして、コマンド全体を拒否する。文書の編集は Edit ツールで行うか、その記述を含めない別のコマンドに分ける。
- 作業の前に、`git status` で作業ツリーがクリーンであることを確かめる。無関係な変更を、破棄したり、stash したり、コミットしたりして、条件を満たさない。

## 7 並行する作業と競合

- 並列の単位は **Issue（feature）**。別の Issue は別のセッションが担当する。サブエージェントによるタスク分割の並列実装は、Cloud では行わない（【ローカル】の worktree 規約は、Cloud には適用しない）。
- feature ディレクトリは Issue 番号を含む（`specs/TAK-<nn>-<slug>`）ので、別の Issue と衝突しない。`.specify/feature.json` は管理対象外で、PR に含まれない。
- `specs/product/` への反映は、**PR の最後の作業**にする。反映の直前に、`git merge origin/master` で最新の `master` を取り込む。同じ領域ファイルで競合したら、Agent が解消する。履歴を書き換えない（強制 push は禁止）。
- `specs/product/` の ID は並行する feature 間で衝突し得る。反映直前に取り込んだ `master` と突き合わせ、衝突があれば[仕様 ID の重複解消](spec-id-conflicts.md)に従ってから反映する。両方がマージ済みの重複も同じ共通手順で扱う（例: TAK-52）。
- 反映した項目と差分を保守者へ示し、承認を得てからコミットする。

## リリース PR の CI（TAK-41）

開発用 Release candidate は確認用 ZIP を作る読み取り専用の処理で、公開先へ書き込まない。
Publish release source は master の要求変更を判定し、候補一致時には静的検査だけで同期する。
候補がずれた場合は固定 M の候補を作り、ローカル再確認と M/run 指定の手動再開を待つ。
App Secret の設定や本番リリースは導入時の保守者の操作。通常開発の CI 検証のために同期・配布 workflow を起動しない。


### 通常 CI と実証の記録（TAK-41）

通常の macOS Swift CI は、checkout した実際の HEAD を共通 exporter で書き出してから build / test へ進む。
ホームパス・README・公開境界の不備は、release.json を変更しない PR でも検出する。

部分再実行は [CI 42259015217 attempt2](https://github.com/yoshidax/folzio-dev/actions/runs/42259015217/attempts/2) で実証済み。
生成 attempt1 の artifact13522914846 を、受取 job だけが attempt2 で再利用して成功した。
実証用の artifact-plan / artifact-retry job・verify_artifact_retry 入力と公開 API 参照 step は通常 CI から外す。
回帰テストと、この実証結果を維持する。再実証が必要なら、通常 PR の CI に常設せず、検証用の変更として扱う。

API は未再実行の job も新 ID / attempt で複製するため、候補は runner_id・実行時刻・全 steps が同一の実行を照合し、
実際に生成した最初の attempt へ結び付ける。整数の最新 attempt だけで生成済み artifact を拒否しない。
