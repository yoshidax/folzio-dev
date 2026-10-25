# Bug Assessment: Codex の判断待ちを実装完了として保存し、resume が GUI 確認へ進む

- **Slug**: codex-resume-skips-implementation（提案した識別名をユーザーが承認）
- **Created**: 2026-10-26（JST）
- **Source**: ユーザー提供の貼り付けたテキスト.txt、run `f1cf656f` のローカル記録
- **Verdict**: valid
- **Severity**: high — 実装していない機能の検証・GUI 確認へ進む。完了判定と後続の記録を誤らせる
- **Scope**: assess のみ。修正・既存 run の再開・状態変更は実施していない

## Report (summarized)

`scripts/sdd-run-codex.sh` から `006-add-slideshow` の仕様文書を生成したが、途中でエラーになった。
`resume f1cf656f` すると実装完了後のように GUI 確認へ進み、ユーザーが reject した。

## Symptom

実装エージェントは「実装開始前の判断待ち」「ファイル変更なし」「T001〜T058 はすべて未完了」と返した。
しかし workflow は `implement` を `completed / exit_code: 0` と保存し、verify の失敗後に resume すると
implement を再実行せず GUI 確認へ進んだ。本来は実装未完了として後続を止める必要がある。

## 仕様との照合

- 本件は開発ツールの不具合で、`specs/product/` に直接該当するアプリ機能の FR／SC ID はない。
  アプリの Living spec が未定義であることを、不具合の根拠にはしない。
- 開発環境の正本 `specs/005-codex-speckit-support/spec.md` の User Story 2 / Acceptance Scenario 2 は
  「失敗・中断・成果物不足は後続工程を進めない」と定めている（同 spec:26）。
- `specs/006-add-slideshow/tasks.md:38` と `plan.md:33,105` は I1 を人の判断待ちとし、
  実装開始前に仕様・契約・タスクを揃えるよう明記している。
- **判定: 実装が仕様に反している。** 開発環境側の既定の停止要件を満たしておらず、
  新要件の追加ではなく bug-fix の対象。診断と方針をユーザーに確認してから fix へ進む。
- I1（スライドショー実行中の並べ替え操作を追加するか）は 006 の未解決事項であり、
  今回の workflow 不具合の修正とは別にユーザーの決定が必要。

## Evidence / Timeline

対象: `/Users/igachan/projects/my_img_viewer/.specify/workflows/runs/f1cf656f/`。
時刻は log.jsonl の UTC を JST に換算。

| 2026-10-26 JST | 記録 | 意味 |
|---|---|---|
| 00:14:44 | log.jsonl:59 `implement` 開始 | I1 未解決のまま実装工程へ入る |
| 00:15:34 | log.jsonl:60 `implement completed` | 実際の最終回答は「判断待ち、未実装」 |
| 00:15:34 | log.jsonl:61 `verify` 開始 | 未実装を検出するゲートがない |
| 00:16:48 | log.jsonl:62–64 `verify failed`, exit 1 | 初回の実際の CLI エラーは verify 工程 |
| 00:19:25 | log.jsonl:65 `verify` 再実行 | resume は implement を再実行しない |
| 00:21:04 | log.jsonl:66–69 verify 成功 → gui_smoke | 既存アプリが build/test を通過した |
| 00:23:59 | log.jsonl:70–71 gui_smoke paused / reject | record・converge・仕様反映へは進んでいない |

追加確認:

- 006 の `tasks.md` は完了 0 件、未完了 58 件。
- `git diff --stat master..006-add-slideshow` は 006 配下の文書 8 ファイルだけ。
  `Sources/` と `Tests/` の差分はない。スライドショーは未実装。
- 保存状態は `status: paused`, `current_step_id: gui_smoke`。
  `implement: completed, exit_code: 0`、`verify: completed, exit_code: 0`、`gui_smoke.choice: reject`。
- streaming の implement は stdout を保存していないため、その最終回答は添付ログと progress.log で照合した。

## Root Cause

**確度: high。以下の連鎖をコード・実 run・隔離した再現で確認した。**

1. **CLI の正常終了と、実装作業の完了を区別していない。**
   `scripts/sdd-codex.py:68–93` は agent_message、turn.completed、CLI exit 0 を確認して 0 を返す。
   これは Codex が回答を終えたことの確認であり、タスクを完了したことの確認ではない。
   「判断待ち」「何も変更していない」も正常な最終回答なので成功扱いになる。
2. **実装完了を確認する契約・ゲートがない。**
   `.specify/workflow-src/sdd-increment-codex.yml:220–235` は未完了事項を最終回答へ残すよう指示するが、
   その回答や tasks.md の未完了状態を機械判定せず、そのまま verify へ進む。
   既存コードの build/test 成功では、新機能の実装済みは証明できない。
3. **resume は誤って保存された成功状態に従った。**
   Spec Kit 1.2.2 の command step は exit 0 を COMPLETED とし、execution engine は
   phase=done の工程を再実行しない。再開位置の破損や、006 を別 feature と取り違えた現象ではない。
   I1 が残っていたことと、設計レビューで approve されたことは前提条件だが、
   エージェントが改めて停止を報告した後も進めた点がツール側の不具合である。

## Initial verify Failure / Observability

初回 verify は `swift build && swift test && scripts/check-no-network.sh && scripts/make-app.sh`
の終了コード 1 で失敗した。どのコマンドが、何を理由に失敗したかは現存記録から特定できない。

- shell step は stdout/stderr を一時的に StepResult に保存し、画面には一般的な exit-code エラーだけを出す。
- resume で同じ verify を成功させると state.json 内の結果が成功時の stdout/stderr に置き換わる。
- log.jsonl は初回失敗と時刻を残すが、失敗時の stdout/stderr を残していない。
- state.json のネストした execution も走査したが、現在は失敗の結果・非 0 exit の保存コピーがない。
- よって「性能テストの揺れ」「sandbox」「ビルドエラー」などとは断定しない。
  この診断不能は、実装未完了を成功扱いにする主因とは別のログ保持の問題である。

## Reproduction

ユーザーの run は再開せず、既存 `scripts/tests/test_sdd_codex.py` の一時リポジトリ用 fixture と
実 Spec Kit 1.2.2、偽 Codex を使った。アプリ・ユーザー画像・元の workflow 状態は操作していない。

1. 偽 Codex が agent_message「実装開始前の判断待ち、全タスク未完了」、turn.completed、exit 0 を返す。
2. `delivery` 内に implement → verify → gui_smoke を置く。
3. verify の初回を意図的に exit 1 にする。
4. 一時 fixture 内だけで verify が成功する条件を作り、resume する。

結果:

```text
first: status=failed, implement=completed, implement.exit_code=0, verify=failed
resume: status=paused, current_step_id=gui_smoke
implement の実行回数=1、verify の実行回数=2、gui_smoke の実行回数=1
初回 verify の stderr は再開後の保存結果から消失
```

これにより、未完了の回答の誤分類・実装のスキップ・失敗出力の上書きを再現した。

## Proposed Remediation

**Preferred**:

- implement の出力に機械判定できる状態（例: ready_for_verification / blocked / failed）、
  未解決事項、完了タスクと残る手動確認タスクを持たせる。
  自然文の単語検索だけで成否を判断しない。
- 構造化結果に加え tasks.md の状態を照合し、未完了の実装タスクがあれば verify へ進めない。
  GUI・手動確認タスクを残せることと、実装タスクを残してよいことを区別する。
- 判定を implement と同じ step の成功条件に含める。後ろにガードを足すだけでは、
  resume 時に implement が completed のままスキップされる問題が残る。
- 各 verify 試行のコマンド・終了コード・stdout/stderr を上書きしない実行ログへ保存し、
  画面にも失敗した段階とログパスを示す。

**Files likely to change**:

- `scripts/sdd-codex.py`（または implement 専用実行ブリッジ）
- `.specify/workflow-src/sdd-increment-codex.yml` と登録済み workflow.yml
- `scripts/tests/test_sdd_codex.py`
- `docs/codex-speckit.md`

**Tests to add or update**:

- exit 0 + turn.completed + blocked 回答でも implement を成功にしない。
- 実装タスク未完了のまま、既存コードの build/test が通っても GUI ゲートへ進まない。
- 判断待ち解消後の resume は implement 自体を再実行し、完了判定後だけ verify へ進む。
- 手動 GUI タスクだけ残った正当な状態は GUI ゲートへ進める。
- verify の初回失敗 → resume 成功後も初回の失敗ログを参照できる。

## Risks & Considerations

- 以前の 10 テストはプロセス／通信レベルの失敗と一般的な gate 再開を確認していたが、
  「回答は正常終了、依頼された実装は未完了」のケースを網羅していなかった。
- 既存 run の workflow.yml と execution tree は実行時のスナップショットを使う。
  登録済み YAML を修正するだけでは、f1cf656f の保存済み implement=completed は直らない。
- 現在の f1cf656f をそのまま resume すると再び GUI ゲートへ進む。
  006 の I1 解決と、修正後の安全な再実装の開始点／既存 run の扱いを決める必要がある。
- 状態ファイルの手編集や、未完了タスクの機械的な完了チェックは行わない。
- 元の 006 のブランチは維持。診断は master 起点の
  `bugfix/codex-resume-skips-implementation` worktree に記録した。

## Open Questions

- 初回 verify の詳細出力の別コピー（ターミナル保存・外部ログ等）があれば、その直接原因は追加調査可能。
  現存の run 記録だけでは断定不能。
- 006 の I1 は未解決。workflow のバグ修正とは別に決定が必要。
- fix は未実施。ユーザーに診断と修正方針を確認してから
  `$speckit-bug-fix slug=codex-resume-skips-implementation` へ進む。
