# Tasks: ID 重複解消規則の整合

**Input**: `specs/TAK-76-spec-id-policy/spec.md`、`plan.md`、`research.md`、`data-model.md`、`quickstart.md`

## Phase 1: 前提

- [x] T001 `specs/product/README.md` の書き方と `.specify/memory/constitution.md` の ID 規則を再確認する
- [x] T002 最新の `master` を取り込み、`scripts/dev/check-spec-ids.sh` で反映前の重複を確認する

## Phase 2: User Story 1 - ID の重複を一貫して解消する (P1)

**Independent Test**: EC-135 から憲章と共通手順をたどり、2 ケースの対象と反映順序を判断できる。

- [x] T003 [US1] `docs_private/spec-id-conflicts.md` を新設し、番号の採り方・凍結記録・参照追従・判別不能時・検査の限界を Cloud 固有の操作と分離して集約し、対象の判断を憲章に委ねる
- [x] T004 [US1] `docs_private/cloud-agent-workflow.md` 7章を Cloud 固有の取り込み・PR 手順と共通手順への参照に整理し、共通の判断規則・操作の重複を取り除く
- [x] T005 [US1] `.specify/memory/constitution.md` の詳細手順の参照先を共通手順へ変更し、`speckit-constitution` の手順で PATCH 改定、改定日、Sync Impact Report と TAK-76 による EC-135 追従の完了を記録する
- [x] T006 [US1] `specs/product/overview.md` の EC-135 を `specs/TAK-76-spec-id-policy/spec.md` の変更後の内容に更新し、対象ラベル・検出時点・反映前の振り直し・マージ済み ID の保護を維持する
- [x] T007 [US1] `specs/TAK-76-spec-id-policy/quickstart.md` の両ケースで、憲章の判断規則と共通手順が正しくたどれることを照合する

## Phase 3: User Story 2 - 正本と参照先を見つける (P2)

**Independent Test**: ローカルと Cloud の双方で、FR-193・EC-135・README・憲章・`AGENTS.md` から適用範囲の正しい手順へ到達する。

- [x] T008 [US2] `specs/product/README.md` の ID の付け方から `docs_private/spec-id-conflicts.md` への参照を追加する
- [x] T009 [US2] `docs_private/agents/README.md` を読み、`AGENTS.md` の ID 衝突時の参照先を `docs_private/spec-id-conflicts.md` に変え、`scripts/dev/check-agents-md.sh` で行数と参照先を確認し、変更理由を PR 本文に記録する
- [x] T010 [US2] `specs/product/overview.md` の FR-193・EC-135、`specs/product/README.md`、`AGENTS.md`、`.specify/memory/constitution.md`、`docs_private/spec-id-conflicts.md`、`docs_private/cloud-agent-workflow.md` の参照と適用範囲を照合する

## Phase 4: 検証・レビュー・凍結

- [x] T011 `scripts/dev/check-spec-ids.sh` と `scripts/dev/check-spec-format.py` で反映後の ID と形式を検証する
- [x] T012 `scripts/dev/check-all.sh` と `specs/TAK-76-spec-id-policy/quickstart.md` の照合を実行し、未実施の検証を記録する
- [x] T013 `specs/product/`・`AGENTS.md`・`.specify/memory/constitution.md`・`docs_private/` の完成差分と反映項目を保守者に示し、コミット前に承認を得る（`docs_private/cloud-agent-workflow.md` 7 章）
- [ ] T014 [MANUAL] `docs_private/cloud-agent-workflow.md` 4章に従い、PR の対象コミットの macOS CI を確認し、追加起動・再実行が必要なら保守者の許可を得る
- [ ] T015 [MANUAL] 保守者が `scripts/make-app.sh` と `open .build/Folzio.app` で起動し、3 ペインの表示を確認する
- [ ] T016 `specs/TAK-76-spec-id-policy/tasks.md` に検証と承認結果を記録し、凍結手順を除く未完了事項を解消する
- [ ] T017 `specs/TAK-76-spec-id-policy/spec.md` に移行済み・凍結の注記を付ける前にその注記案を含む最終差分を保守者に示して承認を得る
- [ ] T018 `specs/TAK-76-spec-id-policy/spec.md` の先頭に承認済みの移行済み・凍結注記を付け、これを同 feature ディレクトリ最後の編集とする

## 依存関係と実装戦略

- T001〜T002 → US1 → US2 → T011〜T013。設計承認後に実装する。
- T013 の承認対象に憲章・製品仕様・共通手順を含め、承認後に内容を変更した場合は再承認を得る。
- T014〜T015 を済ませ、T016 で結果を記録してから T017〜T018 で凍結する。T018 の後に feature ディレクトリを編集しない。
- T017 の承認は `tasks.md` の最後の更新として記録する。T018 は作業後に同ファイルを編集できないため未チェックのまま残し、完了は凍結注記と PR で確認できるようにする。
- 凍結の注記のみを含む最終コミットは、検証対象コミットと異なることを PR に明記する。CI の追加起動・再実行は保守者の許可を得る。
- 共通手順の新設と Cloud 固有部分の整理は関連するため直列に照合し、Cloud では Issue 内をサブエージェントに分割しない。
