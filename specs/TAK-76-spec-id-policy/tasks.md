# Tasks: ID 重複解消規則の整合

**Input**: `specs/TAK-76-spec-id-policy/spec.md`、`plan.md`、`research.md`、`data-model.md`、`quickstart.md`

## Phase 1: 前提の確認

- [ ] T001 `specs/product/README.md` の書き方と `.specify/memory/constitution.md` の ID 規則を再確認する
- [ ] T002 `scripts/dev/check-spec-ids.sh` を実行し、`specs/product/` への反映前に重複がないことを確認する

## Phase 2: User Story 1 - ID の重複を一貫して解消する (P1)

**Independent Test**: 2 つのマージ状態で、憲章・EC-135・7 章の指定する振り直し側が一致する。

- [ ] T003 [US1] `specs/product/overview.md` の EC-135 を `specs/TAK-76-spec-id-policy/spec.md` の変更後の内容に更新し、FR-193 の参照を確認する
- [ ] T004 [US1] `docs_private/cloud-agent-workflow.md` の 7 章で旧 ID の参照、凍結記録、未判別の場合、検査の限界を照合し、不足があれば明確にする
- [ ] T005 [US1] `specs/TAK-76-spec-id-policy/quickstart.md` のケースに従い、対象の選択と参照追従を文脈で照合する

## Phase 3: User Story 2 - 正本と参照先を見つける (P2)

**Independent Test**: 憲章・FR-193・EC-135・README から詳細手順の正本へ到達する。

- [ ] T006 [US2] `specs/product/README.md` の ID の付け方から `docs_private/cloud-agent-workflow.md` の 7 章への参照を追加する
- [ ] T007 [US2] `specs/product/overview.md` の EC-135、`specs/product/README.md`、`.specify/memory/constitution.md`、`docs_private/cloud-agent-workflow.md` の参照先と規則を照合する

## Phase 4: 検証と反映

- [ ] T008 `scripts/dev/check-spec-ids.sh` と `scripts/dev/check-spec-format.py` で反映後の ID と形式を検証する
- [ ] T009 `scripts/dev/check-all.sh` を実行し、`specs/TAK-76-spec-id-policy/quickstart.md` の照合結果と未実施の検証を報告する
- [ ] T010 `specs/product/` の反映項目と差分を保守者に示し、コミット前の承認を得る（`docs_private/cloud-agent-workflow.md` 7 章）
- [ ] T011 `specs/TAK-76-spec-id-policy/spec.md` の先頭に移行済み・凍結の注記を付ける
- [ ] T012 `.specify/memory/constitution.md` の Sync Impact Report の EC-135 追従 TODO を完了済みに更新し、憲章本文とバージョンを維持する
- [ ] T013 `specs/TAK-76-spec-id-policy/tasks.md` に完了した検証を記録し、未実施の CI・保守者確認は未チェックのまま残す
- [ ] T014 [MANUAL] PR が作成された場合、`docs_private/cloud-agent-workflow.md` 4 章に従い macOS CI の結果を確認する
- [ ] T015 [MANUAL] 保守者が `scripts/make-app.sh` と `open .build/Folzio.app` で起動し、3 ペインの表示を確認する

## 依存関係と実装戦略

- T001〜T002 → US1 → US2 → 検証と反映。EC-135 と README は関連するため、個別に検証できても直列に照合する。
- MVP は US1 の EC-135 の整合。US2 の参照経路は引き続き必須である。
- 別のファイルを使う T004 と T006 は独立して編集できるが、Cloud では Issue 内をサブエージェントに分割しない。
- 製品仕様への反映直前に最新の `master` を取り込み、T002 と衝突確認を行う。
