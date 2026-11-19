# Codex で Spec Kit を使う

macOS のローカル Codex CLI で、既存の仕様・憲章・タスクを共有する。
Claude／Kilo の設定と既定の Claude integration は維持する。

## セットアップ

このリポジトリには Codex integration、標準 10 スキル、git／bug 拡張 8 スキル、
`sdd-increment-codex` を登録済み。Codex CLI 0.164.0 と Spec Kit 1.2.2 で検証する。
別の Mac では Swift 6 と macOS 15 以降、Python 3、Codex CLI、Spec Kit が必要。

```bash
cd /Users/igachan/projects/folzio
export PATH="$HOME/.local/bin:$PATH"
codex --version
specify --version
codex login status
# 未認証の場合
codex login
```

プロジェクトを Codex で開いて信頼を確認する。`.codex/` の設定・ルールは信頼済みの
プロジェクトで読み込まれる。追加したスキルが一覧に出なければ新しいセッションで開き直す。
CLI の `/skills`、または `$` の候補で `speckit-*` を確認する。

## 対話で各工程を実行する

クリーンな master から始める。アプリの現在の仕様は `specs/product/`、
作業中の feature は `.specify/feature.json`、進捗はその feature の `tasks.md`。

```text
$speckit-specify 追加したい機能
$speckit-clarify
$speckit-plan
$speckit-tasks
$speckit-analyze
$speckit-implement
$speckit-converge
```

進行中の spec の変更に関する問題は、その作業で対処する。完了した成果物の不具合を独立した
修正タスクとして扱う場合は、[agents/bugfix.md](agents/bugfix.md) に従って判断し、
`$speckit-bug-assess` → 診断のユーザー確認 → `$speckit-bug-fix` → `$speckit-bug-test` と進める。
`$speckit-git-feature` などの git 拡張も利用できる。

## increment を対話で進める

プロジェクトのスキルを使うと、要件から設計レビュー、実装・検証、製品仕様への反映まで
現在の Codex セッションで進められる。Issue URL も指定できる。

```text
$folzio-sdd-increment 追加したい要件
$folzio-sdd-increment https://linear.app/takyoshida/issue/TAK-123
```

既定の `clarify_mode` は `auto`。`manual` や `skip` を使う場合は依頼に明記する。
設計レビュー、GUI などの手動確認、製品仕様への反映の確認では、ユーザーの判断や報告を待つ。
スキルが候補に表示されない場合は新しいセッションを開く。
以下の自動実行とは別の進め方なので、同じ feature で同時に実行しない。
共通手順と Claude Code・Kilo Code での使い方は `shared-skills/folzio-sdd-increment.md` を参照する。

## Linear に Issue を登録する

やりたいことやバグを登録するときは、プロジェクトのスキルを使える。

```text
$folzio-register-issue プレビュービューで拡大時にスクロールバーのレイアウトが崩れる
# Linear から直接登録した Issue の整理
$folzio-register-issue https://linear.app/takyoshida/issue/TAK-123 の内容を整理して
```

関連する仕様とコード、既存 Issue を調べ、必要な確認をしてから Linear の Folzio プロジェクトに登録する。
既存 Issue を指定すると、その内容を保持しながら調査結果を追記する。
Issue の形式は Linear の TAK チームにある `Folzio -` で始まる4種類のテンプレートを正とする。
Linear から直接登録するときも該当するテンプレートを選べる。未確認の項目は空欄でもよい。
この段階の調査は概略であり、正式なバグ診断や新機能の詳細な仕様化は着手時に行う。
スキルが候補に表示されない場合は新しいセッションを開く。
共通手順と Claude Code・Kilo Code での使い方は `shared-skills/folzio-register-issue.md` を参照する。

## increment を自動実行する

設計レビューと GUI 確認に回答するため、通常のターミナルで直接実行する。
同じリポジトリで Claude／Kilo／Codex の workflow を同時に run／resume しない。

```bash
scripts/dev/sdd-run-codex.sh run "追加したい要件"
# 小さな変更で clarify を省略する場合
scripts/dev/sdd-run-codex.sh run "追加したい要件" -i clarify_mode=skip
# clarify に手動で回答する場合
scripts/dev/sdd-run-codex.sh run "追加したい要件" -i clarify_mode=manual

scripts/dev/sdd-run-codex.sh status
scripts/dev/sdd-run-codex.sh status <run_id>
scripts/dev/sdd-run-codex.sh resume <run_id>
# 確認待ちの後に tasks.md や対象アプリを変更した場合、古い要求を退避して再生成する
scripts/dev/sdd-run-codex.sh resume <run_id> --refresh-manual
```

別のターミナルで進捗を確認できる。

```bash
tail -f .specify/workflows/runs/progress.log
```

specify → clarify → plan → tasks → analyze／修正 → 設計レビュー →
（Phase の実装・自動検証 → 手動確認・報告 → 記録・コミット）→ 最終の自動検証・起動確認 → converge → specs/product/ への反映確認
の順で進む。Phase は tasks.md の依存順で繰り返す。GUI はユーザーが表示されたコマンドで
起動し、3 ペインと作業中の quickstart のシナリオを確認する。確認報告前に GUI タスクは完了にしない。
最後の master への統合は、作業ブランチの PR をユーザーが GitHub でマージして行う（`docs_private/repository-and-release.md` の
「開発用 master へのマージ」）。AI エージェントは PR をマージせず、master に直接マージしない。

非 TTY ではゲートで一時停止する。通常のターミナルから `resume` して回答する。
一時停止も終了コードは非 0 として報告するため、完了と取り違えない。

Phase 途中の `[MANUAL]` に達すると、ランナーが対象 ID とコマンド・確認点を表示する。
成功を確認してから対象ビルド・OS・端末・確認結果等の報告を入力し、`approve` で確定する。
未実施・失敗・保留の場合は空行または `approve` 以外で停止する。一部だけ成功した場合も
まとめて承認せず、必要な確認を揃える。報告を保存して対象タスクだけをチェックした後、
同じ run の implement を自動的に再開する。依存する記録・コミットは次の実装ターンが行う。

非 TTY の手動確認待ちは終了コード **75**。`status <run_id>` で対象と手順を再表示し、
通常のターミナルから `resume <run_id>` すると Codex を再実行する前に報告を受領する。
`manual-pending.json` に要求、`manual-receipts.jsonl` に受領日時・タスク・報告・アプリの
SHA-256 を run 別に残す。これは Spec Kit の `state.json` とは別のランナー用記録で、
Spec Kit 内部では implement の非 0 中断を failed と保存するが、ランナーは確認待ちと区別する。
run_id を省略した `status` は従来どおり Spec Kit の一覧表示になる。

設計レビュー gate の `approve` は実装に引き継ぐ。同じ設計レビューだけを求める既定の
手動タスクには保存済みの承認を使い、受領記録を残す。GUI・VoiceOver・性能計測は代替しない。
確認待ちの後に tasks.md またはアプリの実行ファイルが変わった場合は報告を適用せず停止する。
`--refresh-manual` は古い要求を今回の attempt に退避して再生成し、設計レビューの承認も
自動再利用しなくなる。Spec Kit の workflow/state を手で書き換える必要はない。

## モデル・権限・ログ

- モデルは個人の Codex 設定を継承する。ワークフローだけ変える場合は
  `SDD_CODEX_MODEL=<利用可能なモデルID> scripts/dev/sdd-run-codex.sh run "要件"` とする。
  再開時にも同じ変数を渡す。Claude 固有の `sonnet`／`opus` は使わない。
- 対話の既定は `.codex/config.toml` の `workspace-write`／`on-request`。
  workflow は `codex exec --approve-for-me`（workspace-write を含む）を使い、
  sandbox 外の Git 操作や Swift キャッシュ書き込みなどは自動承認レビューへ渡す。
  ポリシーで拒否された操作は失敗として止まる。必要な対象・理由を確認して再開する。
- `git reset --hard`、`git clean`、直接の `brew install`・`reinstall`・`upgrade`・`bundle` の禁止ルールを `.codex/rules/sdd.rules` に置く。
  これらの Homebrew 操作が必要な場合は保守者に依頼し、保守者が実行する。`brew bundle check` などの読み取りも対象に含む。
  `git push` は `prompt` とする。非対話の `--approve-for-me` では自動承認レビューに委ねられるため、
  この確認だけで拒否される保証はない。`.codex/hooks.json` の `PreToolUse` が Claude と同じ
  `scripts/dev/check-git-push.py` を呼び、Bash の push 先・オプションを検査する。フックは
  `origin` と作業ブランチの明示を求め、`master`・`main`、強制 push、削除などを拒否する。
  フックは信頼の承認後に有効になり、設定変更は新しいセッションで確認する。MCP や直接 API 呼び出しは
  この検査の対象ではない。フック定義や検査スクリプトを書き換えられる環境では、フックを改変できる。
  execpolicy の接頭辞ルールではあらゆる編集手段を防げないため、必要に応じて管理者が両ファイルを
  sandbox 外の読み取り専用領域に配置するなど、別途保護する。`AGENTS.md` の規則と GitHub の
  default ブランチ保護も使う。ルールやフックは OS のアクセス制御の代替ではない。
  フックがリポジトリのルートやスクリプトを見つけられないときは、理由を示して Bash を拒否する。
- `scripts/dev/sdd-codex.py` は公式 integration の実行ファイル差し替え機能を使う。
  Codex JSONL のイベントを進捗ログへ、最終回答だけをレビュー用 stdout へ渡す。
  CLI の非 0 終了、失敗イベント、最終回答を取得できない場合は失敗にする。
- グローバルな hook や認証設定は変更しない。実行時ファイルは既存の
  `.specify/workflows/runs/` に置き、Git の対象外とする。

### ローカルの定型操作と承認

作業を委ねる条件は [delegation.md](agents/delegation.md) を参照する。下の `allow` はサンドボックス外で
承認なしにコマンドを実行する。コマンドの許可と、作業を依頼された範囲は別に確認する。

| 操作 | `allow` にしたときの最悪の影響 | 判断と根拠 |
|---|---|---|
| Swift のビルド・テスト、確認用アプリの作成 | 編集したマニフェスト、プラグイン、テスト、シェルスクリプトがサンドボックス外で動き、個人環境への書き込みや通信ができる | `allow` を置かない。ビルド・テストは開発スクリプトで実行し、アプリ作成はその都度1回承認する |
| `git add`・`git commit`・`git switch` | 誤った対象をステージ・コミットしたり、作業ツリーやブランチを変更したりする | `allow`。ここでは `core.hooksPath`、稼働する Git フック、リポジトリのカスタムフィルターを使っていない。`.git` はサンドボックス内では書き込めない |
| `git fetch origin` | 明示した refspec で、使用していないローカルブランチの履歴を強制更新できる | `allow`。通常の fetch は、別の作業ツリーを含めチェックアウト中のブランチを保護する。通常の取得に使い、ローカルブランチを書き換える refspec は渡さない |
| `gh pr create --draft`・`gh pr ready` | 誤ったリポジトリやブランチで PR を公開したり、早く Ready にしたりする。Draft 作成時に `--body-file` でローカルの任意の読み取り可能なファイルの内容を公開 PR の本文に載せられる | `allow`。通常使う `gh` 本体と設定はサンドボックスから書き換えられない。本文ファイルの公開リスクは Claude Code と同じく受け入れ、公開用に用意した本文だけを渡す |
| GitHub CLI の読み取り | 別のリポジトリの情報を参照したり、`--web` でブラウザを開いたり、`--watch` で監視を続けたりする | `gh pr view`・`checks`・`list` と `gh run view`・`list` を `allow`。ブラウザ起動と監視も含め、読み取りの承認を減らすために受け入れる |
| push・PR のマージ | リモートの履歴やブランチの変更、保守者による確認前の統合 | push は `prompt` と信頼済みフックを使う。直接の `gh pr merge` に `forbidden` を設定する |

`git add`・`commit`・`switch` と、Draft 作成・Ready 化の許可は `.claude/settings.json` にそろえた。
Codex の接頭辞ルールは `git switch -f`・`--force`・`--discard-changes`・`-C`・`--force-create` を先に拒否する。
`git switch master -f` のようにオプションをブランチ名の後ろに置く形は、接頭辞ルールでは防げない。
作業ブランチの作成は `git switch -c`、
ステージは対象のパスを明示し、コミットは `git commit -F <メッセージファイル>` を使う。
fetch では Git 内部用の `--update-head-ok` を使わない。
[`git fetch` のオプション](https://git-scm.com/docs/git-fetch)、
[Codex のコマンドルール](https://developers.openai.com/codex/rules)

PR を作るときは `gh pr create --draft --head <作業ブランチ> --base master --title <タイトル> --body-file <本文ファイル>`
の形で、`--draft` を最初の引数に置く。タイトルに `git push` と書くと push のフックが拒否する。
Ready 化は条件を満たしてから `gh pr ready <番号>` を使う。シェルのリダイレクトやコマンド置換を
伴う場合はシェル全体で照合され、接頭辞ルールが適用されないことがある。

手動承認は `approval_policy = "on-request"` と `approvals_reviewer = "user"` を使う。
デスクトップでは `Ask for approval` を選ぶ。workflow の `--approve-for-me` や
`Approve for me` では、push の `prompt` も自動レビューに回る。リモートへ書き込む前にフックが
有効なことを確かめる。確認できない間は手動承認で宛先・ブランチ・引数を確認する。
`gh api` やラッパーを経由したマージは直接の禁止ルールの対象外。GitHub 側で強制するには、
保守者と実行主体の資格情報を分け、保護ブランチへの更新権限を制限する。
[Codex の承認とサンドボックス](https://developers.openai.com/codex/agent-approvals-security)、
[GitHub REST のマージ権限](https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request)

#### Swift のビルド・テストと確認用アプリ

ローカルの作業ツリーで、Codex の `workspace-write` サンドボックスを使う。

```sh
scripts/dev/codex-swift.sh build
scripts/dev/codex-swift.sh test
```

スクリプトは Clang と SwiftPM のモジュールキャッシュを作業ツリーの `.build/codex-swift/` に置き、
SwiftPM の内側のサンドボックスだけを `--disable-sandbox` で無効にする。
Codex の許可ルールにこのスクリプトや Swift を加える必要はない。

確認用アプリは `scripts/make-app.sh` を1回承認し、Codex のサンドボックス外で実行して
`.build/Folzio.app` を作る。

サンドボックス依存のテストは `test` の `--skip` と `test-system` の `--filter` で同じ一覧を使う。
`scripts/dev/codex-swift.sh test-system` は手動承認のうえ Codex のサンドボックス外で実行する。
このサブコマンドでは SwiftPM の通常のサンドボックスを使う。

| システム依存 | サンドボックス内で確認した症状 |
|---|---|
| ファイル操作・ゴミ箱 | ゴミ箱への移動、既存ファイルの置き換えに失敗 |
| ペーストボード・AppKit のダイアログ | ペーストボードからデータを取得できずドラッグのテストが失敗または異常終了。取り込みの確認ダイアログを待つテストが停止 |
| 動画 | AVFoundation の動画フィクスチャで `Cannot Encode` |
| ファイル監視、フォルダの列挙・型判定 | 監視イベントを受信できず、フォルダやパッケージ・拡張子の判定結果が通常時と異なる。フォルダ関連のメニューや取り込みセッションも影響を受ける |
| 性能 | 計測の前提が異なるため、速度・メモリの判定を通常の環境で行う |

スイートで分類できるテストは Swift の型名で指定し、混在するスイートはシステム依存のテスト関数だけを
指定する。テストを追加・移動・改名したときは両方の実行結果を照合して一覧を見直す。
新しい失敗はサンドボックス外の結果と比べ、依存関係が分かってから除外する。
保守者は `open -e ~/.codex/rules/default.rules` で個人のルールを開き、不要になった
`swift build` と `swift test` の `allow` を外してから新しいセッションを開く。

#### 新しいセッションで確認する

- `on-request`、レビュー先 `user` の新しいローカルセッションを開き、ルールとフックの読み込み元を
  確認する。リンクされた作業ツリーでは元のチェックアウトからフックが読み込まれる場合もある。
- コマンドを一つずつ実行し、終了コード、承認要求、フックや execpolicy による拒否を記録する。
  App Server を使う場合は `item/commandExecution/requestApproval` を記録し、試験では拒否する。
- 書き込みの試行は一時クローン内で行い、push URL を存在しないリポジトリへ向ける。
  PR の試行には存在しないリポジトリを `--repo` で指定し、Ready 化・マージには存在しない PR 番号も指定する。
- 検証後は一時クローンの実パスを確認する。`~/.codex/config.toml` に
  `[projects."<一時クローンの実パス>"]` があれば、そのクローンの `trust_level` の登録だけを消す。
  `rg -F '<一時クローンの実パス>' ~/.codex/config.toml` で登録が消えたことを確認する。
  対象が検証用クローンであることを確認してから `rm -r -- '<一時クローンの実パス>'` で削除し、
  `test ! -e '<一時クローンの実パス>'` で確かめる。
- `codex execpolicy check --rules .codex/rules/sdd.rules -- <コマンド>` で接頭辞の判定も確認できる。
  実行時の承認と拒否は新規セッションで確かめる。

#### [TAK-122](https://linear.app/takyoshida/issue/TAK-122) の検証結果

ローカル macOS の Codex CLI 0.169.0-alpha.11.1 で、サンドボックスは `workspace-write`、ネットワークは
無効、承認は `on-request`、レビュー先は `user` に設定した。

| 操作 | 新規セッションでの結果 |
|---|---|
| `git fetch origin`・`git add`・`git commit -F`・`git switch -c` | 一時クローンで、承認要求なしに成功 |
| Draft 作成・Ready 化 | 承認要求なしで GitHub に到達し、存在しないリポジトリを指定したため GitHub が拒否 |
| `git switch -f`・`--force`・`--discard-changes`・`-C`・`--force-create`、直接の `gh pr merge` | execpolicy が実行前に拒否 |
| `master` への push・強制 push・削除 | 信頼済みフックが実行前に拒否 |
| 通常の作業ブランチへの push、`--draft` のない PR 作成 | 承認要求を確認して拒否した。PR 作成はサンドボックス内で接続に失敗した後、再試行時に要求が出た |
| `codex-swift.sh build`・`test` | 承認要求なしに成功。サンドボックス内のテストは1,071件通過 |

サンドボックス外の `test-system` は一括実行で265件すべて通過した。ゴミ箱、ペーストボード、
動画のエンコード、ファイル監視、ダイアログに関するサンドボックス内の失敗は、
サンドボックス外では再現しなかった。

## 実装完了の判定と検証ログ

- `$speckit-implement` の最終回答は `scripts/dev/sdd-codex-implementation.schema.json` で検証する。
  `status` が `ready_for_verification`、`blockers` が空、`tasks.md` の未チェックが
  すべて `[MANUAL]` のときだけ implement を成功にする。現在実施可能な手動確認は
  `waiting_for_manual` と `manual_requests`（task_id / kind / instructions）で返す。
  後続の非手動タスクが残っていても確認待ちとして中断できるが、成功にはしない。
  権限不足・未決判断・実失敗は `blocked` / `failed` で止め、確認待ちへ置き換えない。
- `[MANUAL]` は GUI の起動や目視確認など、ユーザーの報告が必要なタスクだけに付ける。
  tasks の生成時に分類し、設計レビューで確認する。実装中に追加・変更しない。
  実装タスクが未チェックで残っている間は implement を失敗させ、resume では実装からやり直す。
- 旧バージョンで `implement: completed` と保存された run（最終回答が構造化されていない）は
  resume を停止する。状態ファイルを手で直さず、未決事項を解消して新しい run を開始する。
- 構造化結果のある `implement: failed` の既存 run は、そのまま resume できる。
  更新後のブリッジで Phase 途中の確認を仲介するため、保存済み workflow の移行は不要。
  旧 workflow 末尾の GUI gate は残るので、そこに達した場合は表示された起動確認も行う。
  新 workflow も最終ビルドの起動 gate は維持するが、その承認で手動タスクをまとめてチェックしない。
- verify は `python3 scripts/dev/sdd-codex.py verify` で実行し、build／test／no-network／readme-sync／make-app の
  各試行を `.specify/workflows/runs/attempts/<attempt>/verify-<id>/` に
  stdout／stderr／result.json として残す。再実行しても前回の失敗ログを上書きしない。
  失敗時は画面に段階とログのパスを表示する。

## 更新

標準スキルは公式 CLI で更新する。生成スキルを手で編集してプロジェクト規約を追加しない。
拡張の生成には一時的な integration 選択が必要なので、既定を最後に Claude に戻す。

```bash
specify integration upgrade codex
specify integration use codex
specify integration use claude
specify workflow add --dev .specify/workflow-src/sdd-increment-codex.yml
```

`integration use` は共有スクリプトも更新する場合がある。`git diff` で変更と実行権限を確認し、
既存のカスタマイズを保つ。`--force` による上書きは行わない。
新規に Codex integration を登録するリポジトリでは、最初に
`specify integration install codex` を実行する。

## 検証と問題の切り分け

```bash
python3 -m unittest discover -s scripts/dev/tests -v
codex execpolicy check --rules .codex/rules/sdd.rules -- git reset --hard
codex execpolicy check --rules .codex/rules/sdd.rules -- git push origin master
codex execpolicy check --rules .codex/rules/sdd.rules -- brew install webp
codex execpolicy check --rules .codex/rules/sdd.rules -- brew reinstall webp
codex execpolicy check --rules .codex/rules/sdd.rules -- brew upgrade
codex execpolicy check --rules .codex/rules/sdd.rules -- brew bundle
swift build
swift test
scripts/check-no-network.sh
scripts/check-readme-sync.sh master
scripts/make-app.sh
# ユーザーが起動して確認する
open .build/Folzio.app
```

Codex のフック接続は、設定を読み直した新しいセッションで信頼を承認し、エージェントに
`git push --dry-run origin HEAD:master` を実行させて確かめる。`git push guard` の拒否理由が
表示され、Git の通信より前に停止することを確認する。フックを無効または未承認にした場合は
この検査は働かず、`prompt` は承認設定によって自動レビューに回る。模擬入力の単体テストは
接続の実動確認に代わらない。Codex の入力形式は `tool_name` が `Bash`、
`tool_input.command` が文字列であることを前提とし、それ以外の Bash 入力は拒否する。

- `specify` が見つからない: `~/.local/bin` を PATH に追加する。ランナー自身はこの場所も探す。
- 未コミット変更・元ブランチ違い: 状況を確認して整理してから run する。
- 失敗・中断: 表示された run_id の status と progress.log を確認してから resume する。
- ロックが残った: 実行プロセスがないことを確認した場合だけ
  `rmdir .specify/workflows/runs/.sdd-codex.lock` を実行する。
- GUI が起動しない: [agents/launch-debugging.md](agents/launch-debugging.md) の lldb の手順を使う。GUI 未確認のまま完了にしない。

公式資料: [Skills](https://learn.chatgpt.com/docs/build-skills)、
[Config](https://learn.chatgpt.com/docs/config-file/config-basic)、
[Non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode)、
[Rules](https://learn.chatgpt.com/docs/agent-configuration/rules)。
