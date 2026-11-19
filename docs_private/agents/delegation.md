# 依頼済みの作業で委ねる操作

**適用範囲**: 【共通】（「Claude Code の権限」の節は、ローカルと Cloud の違いを表で示す）

AGENTS.md から参照する。保守者が依頼した作業（Issue への対応、レビューの指摘への対応など）の中で、エージェントが保守者に改めて確認せずに進めてよい操作と、保守者の判断を待つ場面を分ける。

ここでいう委任は運用の取り決めで、ツールが確認ダイアログを出すかどうか（権限の設定）とは別に扱う。

- 委ねた操作でも、権限の設定によっては確認が出る
- 保守者の判断を待つ場面では、権限の設定で通る操作であっても待つ

## 確認なしに進める操作

| 操作 | 条件・範囲 |
|---|---|
| 既存の仕様・承認済みの設計に沿う実装と、レビューの指摘の修正 | 仕様・設計・要件の変更が要るなら、次の節に従って保守者に確認する |
| ビルド・テスト・検査と、失敗を直した後の再実行 | `swift build`、`swift test`（【ローカル】）、`scripts/dev/check-all.sh`、仕様の検査（`check-spec-format.py`、`check-spec-ids.sh`）。同じ原因の失敗を 3 回直して解決しなければ、止めて報告する（AGENTS.md） |
| 確認用のアプリの作成 | `scripts/make-app.sh`（【ローカル】）。アプリの起動と GUI の確認は保守者が行う |
| GitHub の PR・レビュー・CI の情報の読み取り | CI の再実行は [cloud-agent-workflow.md](../cloud-agent-workflow.md) の 4 章に従う |
| 作業ブランチの作成と切り替え | ローカルは `master` から作る。接頭辞は `scripts/dev/check-git-push.py` の `ALLOWED_PREFIXES`。Cloud は指定された作業ブランチを使う |
| 対象ファイルのステージとコミット | 所定の検証の後に、今回の作業の差分だけを入れる。所定の検証は、ローカルでは Phase の検証ゲートの 1〜3、Cloud では 5 章の Cloud の検査。無関係な変更を含めない |
| `origin` の作業ブランチへの通常の push | PR のため、または Cloud の手順の区切りで行う |
| Draft の PR の作成と、Ready 化 | 次の「PR の作成と Ready 化の条件」を満たしたとき |
| 作業ブランチの PR の本文の更新 | PR のテンプレートの見出しを保つ |
| Linear の Issue の状態の更新 | [linear.md](linear.md) が定める時点だけ |

## PR の作成と Ready 化の条件

PR は Draft で作り、条件を満たしたら Ready にする。どちらも保守者の依頼を待たない。マージは保守者が行う。

Draft の PR は、次をすべて満たしたら作る。

- 保守者の承認が要るゲートを通っている（feature は設計の承認、独立したバグ修正は assessment の判定と診断の確認）
- 作業ブランチを push し、所定の検証が通っている
- 同じ作業ブランチの PR がまだない（あれば、その PR を更新する）

Ready には、次をすべて満たしたらする。

- `tasks.md` の未チェックのタスクが `[MANUAL]` だけになっている（`tasks.md` のない作業では、依頼された作業が終わっている）
- 自分で行う検査が通り、PR の最新の head で CI が成功している
- 本文の「確認していないこと」に、保守者が行う確認（起動スモーク、GUI の確認など）を、実行するコマンドと確認する点とともに書いている

PR の本文は公開される（開発用リポジトリは公開されている）。ローカルのパス（`/Users/...` など）や、作業用の一時ファイルの場所を書かない。

PR を作ったときと Ready にしたときに、Linear の Issue を [linear.md](linear.md) に従って更新し、PR の URL を保守者に知らせる。

## 保守者の判断を待つ場面

- 設計の承認（feature の設計レビュー、独立したバグ修正の assessment の判定と診断）
- GUI の確認と起動スモーク（`[MANUAL]` のタスク）。報告を受けるまで完了にしない
- `specs/product/` への反映の承認
- 承認済みの仕様・設計の変更、要件の追加・変更、範囲外の問題を独立した修正にするか（[bugfix.md](bugfix.md)）
- PR のマージ。保守者が行う。Ready の PR でも、保守者の確認が終わるまではマージの準備ができたとは扱わない
- 依存ツールの導入・更新、権限の設定（`.claude/settings.json` など）の変更
- 委任と承認の規則（この文書、`AGENTS.md`、`docs_private/agents/`、`cloud-agent-workflow.md`）の変更。それ自体が依頼された作業のときを除く
- Issue の完了（`Done`）への更新。依頼されたときだけ行う

`master` への直接の push、強制 push、リモートブランチの削除、履歴の書き換えはしない（AGENTS.md の「Git と GitHub」）。

## Claude Code の権限

`.claude/settings.json` の `permissions` と `PreToolUse` のフックで、委ねる操作は確認なしに通し、禁止する操作は止める。

- この設定は保守者が編集する（エージェントの編集は deny にある）
- 委任と承認の規則の文書（`AGENTS.md`、`docs_private/agents/`、`cloud-agent-workflow.md`）の編集は `ask` にあり、ほかの `docs_private/` の編集（allow）より優先して確認が出る
  - Cloud ではファイルの編集がどのモードでも承認済みなので、この確認が出るかは未確認。上の「保守者の判断を待つ場面」の規則で守る
- 変更は、新しいセッションから有効になる

| | ローカル（保守者の macOS） | Cloud（Claude Code on the web） |
|---|---|---|
| 読む設定 | `~/.claude/settings.json`、リポジトリの `.claude/settings.json` と `.claude/settings.local.json` | リポジトリの `.claude/settings.json` だけ（リポジトリが 1 つのセッションのとき）。ユーザー設定は読まない |
| 権限のモード | Manual・Accept edits・Auto など。Manual では allow にない操作で確認が出る。Auto では allow にない操作を分類器が判定する | Accept edits・Plan・Auto。ファイルの編集は、どのモードでも承認済み |
| GitHub | `gh`（ユーザーの認証）と GitHub の MCP | GitHub のプロキシを通る。`gh pr` と `gh issue` は GraphQL を使うので 403 になる。REST の `gh api repos/...` か、組み込みの GitHub ツールを使う |
| push の制限 | フック、deny、GitHub のブランチ保護 | ローカルと同じ。プロキシはブランチを制限しない（ブランチの削除とタグの push は拒否する） |
| Swift | 使える | 使えない（Ubuntu の VM）。build と test は CI で確かめる |

Cloud の列は、Claude Code の文書（[Claude Code on the web](https://code.claude.com/docs/en/claude-code-on-the-web)、[Cloud environments](https://code.claude.com/docs/en/cloud-environments)、[Permission modes](https://code.claude.com/docs/en/permission-modes)、[Settings](https://code.claude.com/docs/en/settings)）に基づく（2026-11-19 に確認）。Cloud のセッションで実際には確かめていない。次の 2 点も未確認である。

- allow と deny に書いた GitHub の MCP の名前（`mcp__github__*`）が、Cloud の組み込みの GitHub ツールに当てはまるか
- Cloud で allow にない操作をしたときに、確認が出るか

### 確認が出ない書き方

ローカル・Cloud 共通。

- コミットのメッセージは、一時ファイルに書いて `git commit -F <ファイル>` で渡す
  - `git commit -m "$(...)"` のようなコマンド置換は、allow の規則に一致しても確認が出る
- ブランチの作成と切り替えは `git switch` で行う（`git checkout` は allow にない）
- 作業ブランチの名前に `main`・`master` を含めない
  - deny の `git push *main*`・`*master*` に一致して、push が拒否される（例: `claude/fix-maintenance`）
- `gh api` は `gh api repos/...` の形で、読み取りだけに使う
  - 書き込みになる `-X`・`--method`・`-f`・`-F`・`--field`・`--raw-field`・`--input` は deny にある
  - `gh api -X GET ...` のように、オプションを `repos/` の前に置くと確認が出る
- PR は、ローカルでは `gh pr create --draft --head <作業ブランチ> --base master --title <タイトル> --body-file <ファイル>` で作る
  - `--draft` を最初に置く。`--draft` のない `gh pr create` には確認が出る
  - タイトルに `git push` の文字列を書かない
    - push を検査するフックが入れ子の push と見なし、コマンド全体を拒否する
    - 本文は `--body-file` で渡すので、影響しない
  - Ready 化は `gh pr ready <番号>` で行う
- Cloud では、GitHub の MCP ツール `create_pull_request` に `draft: true` を渡して作る
  - Ready 化に使う `update_pull_request` は、base の変更やクローズもできるため allow にない。確認が出る

### 確認の手順

権限の設定を変えたら、新しいセッションを非対話で起動して確かめる。確認が必要な操作を自動で拒否させ、拒否された操作の一覧を見る。

```bash
PROBE_FILE=/tmp/permission-probe.md  # 試す手順を書いたファイル（リポジトリの外に置く）
claude -p --model haiku --permission-mode manual --permission-prompts none --output-format json < "$PROBE_FILE" | jq '.permission_denials'
```

- 手順のファイルには、試すコマンドを 1 行に 1 つ書く。「そのまま 1 回ずつ実行し、拒否されても次へ進む。ほかには何もしない」と指示する
- 書き込みが拒否されることを確かめる手順は、存在しないリポジトリや PR を宛先にする。拒否されなかったときに、実際に書き込まないため
- Cloud に近い条件は `--permission-mode acceptEdits --setting-sources project` で再現する（ユーザー設定を読まない）
  - `gh pr` の 403 など、プロキシの挙動は再現しない。これは Cloud のセッションで確かめる
- 適用前の規則は、足したい規則だけを `--settings '{"permissions":{"allow":[...]}}'` の JSON で渡して試す
  - `.claude/settings.json` を写したり書き換えたりしない
  - `Edit(/docs_private/**)` のような `/` で始まる規則は、JSON ではリポジトリを基準に解決されない
  - Edit の規則は、絶対パスの `Edit(//<リポジトリのパス>/docs_private/**)` に書き換えて試す

### 2026-11-19 の確認（TAK-121、Claude Code 2.1.326）

変更前の設定では、次の操作で確認が出た。

- 検査: `scripts/dev/check-all.sh`、`check-spec-format.py`、`check-spec-ids.sh`、`find-spec-id.sh`
- Git: `git fetch`、`git checkout`、コマンド置換を使う `git commit`
- GitHub: `gh pr view`・`checks`・`list`、`gh run list`
- 編集: `docs_private/`、`shared-skills/`、`.specify/memory/`

あわせて、次の問題が見つかった。

- `claude/tak-121-maintenance-probe` への push が、deny の `*main*` に一致して拒否された
- ユーザー設定の `Bash(gh api repos/*)` は、書き込み（`gh api -X PUT .../merge` によるマージなど）も許していた

TAK-121 で、allow に検査、`git fetch`、`gh api repos/*`、`gh pr`・`gh run` の読み取り、GitHub の MCP の読み取り、`docs_private/**` と `shared-skills/**` の編集を足した。deny には `gh pr merge` と、書き込みになる `gh api` を足した。

変更後は、ローカル相当（manual）と Cloud 相当（acceptEdits、リポジトリの設定だけ）の両方で、次のとおりになった。

- 通る: 上の読み取りと検査
- 拒否される: 書き込みになる `gh api`、`gh pr merge`
- フックが止める: `master` への push

`.specify/memory/`（憲章）の編集は、引き続き確認が出る。

PR の作成と Ready 化を委ねることにあわせて、allow に `gh pr create --draft *`、`gh pr ready *`、MCP の `create_pull_request` を足した。確認の結果は次のとおり（manual）。

- 通る: `gh pr create --draft` と `gh pr ready`
- 確認が出る: `--draft` のない `gh pr create`
- 拒否される: `gh pr merge`

PR #93 のレビューを受けて、委任と承認の規則の文書の編集を `ask` に足した。確認の結果は次のとおり（manual、JSON の絶対パスの規則で試した）。

- 確認が出る: `docs_private/agents/` の編集
- 通る: ほかの `docs_private/` の編集
