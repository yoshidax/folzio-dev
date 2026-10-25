# Codex で Spec Kit を使う

macOS のローカル Codex CLI で、既存の仕様・憲章・タスクを共有する。
Claude／Kilo の設定と既定の Claude integration は維持する。

## セットアップ

このリポジトリには Codex integration、標準 10 スキル、git／bug 拡張 8 スキル、
`sdd-increment-codex` を登録済み。Codex CLI 0.164.0 と Spec Kit 1.2.2 で検証する。
別の Mac では Swift 6 と macOS 15 以降、Python 3、Codex CLI、Spec Kit が必要。

```bash
cd /Users/igachan/projects/my_img_viewer
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

不具合は `$speckit-bug-assess` → 診断のユーザー確認 → `$speckit-bug-fix` →
`$speckit-bug-test`。仕様が未定義・誤りの場合は、AGENTS.md に従って feature に回す。
`$speckit-git-feature` などの git 拡張も利用できる。

## increment を自動実行する

設計レビューと GUI 確認に回答するため、通常のターミナルで直接実行する。
同じリポジトリで Claude／Kilo／Codex の workflow を同時に run／resume しない。

```bash
scripts/sdd-run-codex.sh run "追加したい要件"
# 小さな変更で clarify を省略する場合
scripts/sdd-run-codex.sh run "追加したい要件" -i clarify_mode=skip
# clarify に手動で回答する場合
scripts/sdd-run-codex.sh run "追加したい要件" -i clarify_mode=manual

scripts/sdd-run-codex.sh status
scripts/sdd-run-codex.sh status <run_id>
scripts/sdd-run-codex.sh resume <run_id>
```

別のターミナルで進捗を確認できる。

```bash
tail -f .specify/workflows/runs/progress.log
```

specify → clarify → plan → tasks → analyze／修正 → 設計レビュー → 実装 →
build／test／no-network／make-app → GUI 確認 → converge → specs/product/ への反映確認
の順で進む。GUI はユーザーが `open .build/MediaViewer.app` で起動し、3 ペインと
作業中の quickstart のシナリオを確認する。確認報告前に GUI タスクは完了にしない。
最後の master へのマージと push はユーザーが判断する。

非 TTY ではゲートで一時停止する。通常のターミナルから `resume` して回答する。
一時停止も終了コードは非 0 として報告するため、完了と取り違えない。

## モデル・権限・ログ

- モデルは個人の Codex 設定を継承する。ワークフローだけ変える場合は
  `SDD_CODEX_MODEL=<利用可能なモデルID> scripts/sdd-run-codex.sh run "要件"` とする。
  再開時にも同じ変数を渡す。Claude 固有の `sonnet`／`opus` は使わない。
- 対話の既定は `.codex/config.toml` の `workspace-write`／`on-request`。
  workflow は `codex exec --approve-for-me`（workspace-write を含む）を使い、
  sandbox 外の Git 操作や Swift キャッシュ書き込みなどは自動承認レビューへ渡す。
  ポリシーで拒否された操作は失敗として止まる。必要な対象・理由を確認して再開する。
- `git push`、`git reset --hard`、`git clean` の禁止ルールを `.codex/rules/sdd.rules` に置く。
  ルールはコマンド接頭辞を判定するもので、OS のアクセス制御の代替ではない。
- `scripts/sdd-codex.py` は公式 integration の実行ファイル差し替え機能を使う。
  Codex JSONL のイベントを進捗ログへ、最終回答だけをレビュー用 stdout へ渡す。
  CLI の非 0 終了、失敗イベント、最終回答を取得できない場合は失敗にする。
- グローバルな hook や認証設定は変更しない。実行時ファイルは既存の
  `.specify/workflows/runs/` に置き、Git の対象外とする。

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
python3 -m unittest discover -s scripts/tests -v
codex execpolicy check --rules .codex/rules/sdd.rules -- git push origin master
swift build
swift test
scripts/check-no-network.sh
scripts/make-app.sh
# ユーザーが起動して確認する
open .build/MediaViewer.app
```

- `specify` が見つからない: `~/.local/bin` を PATH に追加する。ランナー自身はこの場所も探す。
- 未コミット変更・元ブランチ違い: 状況を確認して整理してから run する。
- 失敗・中断: 表示された run_id の status と progress.log を確認してから resume する。
- ロックが残った: 実行プロセスがないことを確認した場合だけ
  `rmdir .specify/workflows/runs/.sdd-codex.lock` を実行する。
- GUI が起動しない: AGENTS.md の lldb 手順を使う。GUI 未確認のまま完了にしない。

公式資料: [Skills](https://learn.chatgpt.com/docs/build-skills)、
[Config](https://learn.chatgpt.com/docs/config-file/config-basic)、
[Non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode)、
[Rules](https://learn.chatgpt.com/docs/agent-configuration/rules)。
