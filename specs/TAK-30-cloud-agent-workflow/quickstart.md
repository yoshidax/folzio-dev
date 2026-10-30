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
