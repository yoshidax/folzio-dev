# Verification quickstart

Cloud のセッションと、保守者のローカルで実施する。`master` へのマージは保守者が行う。

## A. 文書の整合（Cloud で実施）

1. `grep -n '^## ' AGENTS.md` で全ての節の見出しを出し、各見出しに【共通】【ローカル】【Cloud】のいずれかが付いていること、
   先頭の一覧表の行と見出しが 1 対 1 に対応することを確かめる（FR-195、US30-AS2）。
2. data-model.md の分類表（14 節と「Codex / Spec Kit」の 9 行）を、変更後の `AGENTS.md` と突き合わせ、抜けと二重の記載がないことを確かめる。
3. `git push`、検証ゲート、ブランチの切り方、完了の報告について、ローカル専用と Cloud 専用の規則を読み比べ、同じ状況に異なる指示を出す規則が
   ないことを確かめる（SC-094、US30-AS3）。
4. 変更前後の差分で、ローカル専用の規則（`merge-to-master.sh`、ローカルの検証ゲート、worktree）の意味が変わっていないことを確かめる
   （SC-093、US30-AS1）。
5. `specs/product/` への反映の後に、`grep -rhoE '^\s*- \*\*(FR|SC|EC|A)-[0-9]+\*\*' specs/product | sed -E 's/^\s*- //' | sort | uniq -d` が何も出力しないこと（重複した ID が 0 件。EC-135、SC-091）。

## B. 既存の検査（Cloud で実施）

`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、
`python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py" -v` を実行する。アプリのコードを変えないため、結果は変更前と同じになる。

`scripts/dev/tests` の公開・配布のテスト（`test_publish_folzio.py`、`test_release_distribution.py`）は、Apple silicon の macOS と `rsync` を前提とし、
Cloud（Linux）では 6 件が失敗する（2026-10-30 に確認。この feature とは無関係）。これらは保守者のローカルで実行する（D）。

## C. Cloud の実機確認（この feature の PR で実施）

PR は保守者の依頼で作る（FR-198）。作成後に、次を確かめて結果を記録する。

1. **Linear への反映（FR-199、US27-AS4）**: PR の作成後に、Agent が TAK-30 へ PR のリンクを追加して `In Review` に更新し、
   Linear 上で状態の履歴とリンクを確認できる。
2. **CI の自動実行（US28-AS1）**: PR の作成時に macOS の CI が自動で動き、Agent が GitHub MCP で成否を確認できる。
3. **CI の手動実行（US28-AS2、R4）**: 追加の push の後、Agent が `actions_run_trigger` で `workflow_dispatch` を起動できるか確かめる。
   起動できなければ、その旨を記録し、保守者に実行を頼む手順を手順書に書く。
4. **権限（US29-AS3）**: `master` への push、強制 push、PR のマージが、設定どおり拒否される（TAK-27 で確認済みの内容が、Cloud の手順で変わらないこと）。

## D. 保守者のローカルでの確認

マージ前に、保守者が最新の `master` に PR のブランチを取り込み、`swift build`、`swift test`、
`python3 -I -m unittest discover -s scripts/dev/tests -v`、`scripts/make-app.sh`、起動スモーク
（`open .build/Folzio.app` で 3 ペインの表示）を行う。この feature はアプリのコードを変えないため、結果は変更前と同じになる。

## E. 完了の更新

保守者が PR をマージし、完了更新を依頼したら、Agent がマージを確認して TAK-30 を `Done` にする（FR-197）。確認できなければ、完了にしない。

## 実施記録

### 2026-10-30: 文書の整合と既存の検査（T020、T023、T024）

| 項目 | 結果 |
|---|---|
| A1 見出しの区分と一覧表 | `AGENTS.md` の `##` 見出し 18 のうち、「運用の区分」を除く 17 すべてに【共通】【ローカル】【Cloud】が付き、一覧表の 17 行と 1 対 1 で一致（区分の食い違い 0 件） |
| A2 分類表との突き合わせ | `data-model.md` の変更前の 14 節の区分が、変更後の見出しと一致。「Codex / Spec Kit」の 9 行は、「Codex / Spec Kit」【共通】（4 行）、「Git の規則」【共通】（4 行）、「Codex の自動実行」【ローカル】（2 行）に置いた。抜けと二重の記載なし |
| A3 矛盾の読み合わせ | `git push`（【共通】と【Cloud】）、検証ゲート（【ローカル】と【Cloud】）、ブランチの切り方（「バグ修正」の手順 1 の注記と【Cloud】）、完了の報告（「Issue 管理」と【Cloud】）を読み比べ、同じ状況に異なる指示を出す規則は 0 件 |
| A4 ローカル専用の規則の差分 | 変更前に対して、`AGENTS.md` で消えた行は、見出し（区分の追加）、「Phase の検証ゲート」の導入文（Cloud 版への案内を追記）、「バグ修正」の手順 1 と 5（Cloud の注記を追記）だけ。移動した規則（`git push`、`reset --hard`、`merge-to-master.sh`、GUI の依頼）は、一字も変えずに残っている。`merge-to-master.sh`、ローカルの検証ゲート、worktree の規約の意味は変わっていない |
| T023 要件の対応 | `FR-186`〜`FR-199` と `EC-129`〜`EC-135` のすべてに、`docs_private/cloud-agent-workflow.md` または `AGENTS.md` の記述が対応している（キーワードの検索で確認。`FR-191` は「タイムアウト」の記述） |
| B `scripts/check-no-network.sh` | 通過 |
| B `scripts/check-readme-sync.sh master` | 通過 |
| B `scripts/dev/check-english-comments.sh` | 通過 |
| B `test_check_git_push.py` | 3 件通過 |

### 2026-10-30: Cloud の実機確認（T025、T026。PR #4）

| 項目 | 結果 |
|---|---|
| C1 Linear への反映（FR-199、US27-AS4） | TAK-30 に PR #4 のリンクを追加して `In Review` に更新できた。Linear の attachments にリンクが付き、状態は `In Review` |
| C2 CI の自動実行（US28-AS1） | PR の作成時に自動で動いた（run #10、19:31:56〜19:36:51、成功）。ステップ: ビルド 16 秒、通常のテスト 2 分 35 秒、性能テスト 1 分 52 秒 |
| C3 CI の手動実行（US28-AS2、R4） | `actions_run_trigger` の `run_workflow`（`workflow_id`: `macos-swift-ci.yml`、`ref`: 作業ブランチ）が `204` を返し、run #11（`workflow_dispatch`）が作られて PR #4 に関連づけられた。19:37:22〜19:42:17、成功。**Agent が起動できる** |
| C4 権限（US29-AS3） | `master` への push と、`--force` を付けた push を、副作用のない `--dry-run` で試した。前者は「master への push は禁止です」、後者は「オプション --force は許可リストにありません」で、どちらも `scripts/dev/check-git-push.py` が拒否した。`merge_pull_request` は拒否リストにあるが、誤ってマージされる恐れがあるため、呼んで確かめてはいない |
| 補足 | `actions_run_trigger` には `rerun_workflow_run`、`rerun_failed_jobs`、`cancel_workflow_run` もある（未試行） |
| 補足 | 上のフックは、コマンドの文字列のどこかに push の呼び出しの記述があると（ヒアドキュメントの文中も）、入れ子と見なしてコマンド全体を拒否する。文書の編集は、Edit ツールで行うか、その記述を含めない |

### 2026-10-31: `specs/product/` への反映（T028）

| 項目 | 結果 |
|---|---|
| 反映した項目 | `overview.md` に、User Story 27〜31（受け入れシナリオ 16 件）、`FR-186`〜`FR-199`（14 件）、`EC-129`〜`EC-135`（7 件）、`SC-090`〜`SC-095`（6 件）、`A-105`〜`A-115`（11 件）を追加。削除と変更は 0 行 |
| A5 ID の重複検査 | 反映後の `specs/product/` で重複した ID が 0 件（反映前の新しい ID の衝突も 0 件） |
| 既存の検査 | `check-no-network.sh`、`check-readme-sync.sh master`、`check-english-comments.sh`、`test_check_git_push.py` が通過 |
| 状態 | 保守者の承認（T029）を待っている。このコミットは未マージの専用ブランチにあり、PR は作っていない |
