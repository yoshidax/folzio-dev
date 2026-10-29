# Tasks: 公開用と開発用スクリプトの分離

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[research.md](research.md)、[contracts/scripts.md](contracts/scripts.md)

## Phase 1: 分離と既存操作の維持

変更は同一の実行経路を共有するため、以下を順次実施し、この Phase の最後に検証・GUI確認・コミットを行う。

### User Story 1: 開発専用ファイルの除外

**Independent Test**: 一時リポジトリで新規・入れ子の開発専用ファイルが除外され、公開用が残り、除外設定不備では同期前に止まる。

- [ ] T001 [US1] `scripts/tests/test_publish_folzio.py` に未知・入れ子の開発専用ファイルの除外、公開用保持、および除外不備時の同期前停止・既存対象の保護を検証する回帰テストを追加し、修正前の失敗を確認する。
- [ ] T002 [US1] `scripts/dev/` に `check-english-comments.sh`、`publish.sh`、`release-distribution.sh`、`migrate-folzio-settings.sh`、`merge-to-master.sh`、`sdd-*`、`tests/`、`spec-restructure/` を移し、実行権限と各ルート導出・内部パスを維持する。
- [ ] T003 [US1] `.gitattributes` の個別スクリプト除外を `scripts/dev/` の一括除外に置き換え、`scripts/dev/publish.sh` で同ディレクトリの混入を同期前に検出する。
- [ ] T004 [US1] `scripts/dev/tests/test_publish_folzio.py` のフィクスチャと実行パスを整理後に合わせ、正負両ケースを実行する。

### User Story 2: 整理後の開発・公開操作

**Independent Test**: 現行のスクリプト・workflow・検査・テストが新しい配置で動作し、公開用コマンドのパスが維持される。

- [ ] T005 [US2] `scripts/dev/` 内の SDD bridge、runner、schema、通知、配布・移行・テスト・spec-restructure の相互参照とルート導出を修正する。
- [ ] T006 [US2] `.specify/workflow-src/`、`.specify/workflows/`、`.claude/`、`.kilo/`、`.codex/`、`.agents/skills/` の現行実行設定とスキル内の旧開発用パスを調査・更新し、workflow ソースと導入済みコピーの整合を保つ。
- [ ] T007 [US2] `AGENTS.md`、`docs_private/codex-speckit.md`、`docs_private/repository-and-release.md` および現行の関連手順の旧開発用パス・分類・検査手順を更新する。凍結 feature・過去の記録は変更しない。
- [ ] T008 [US2] `scripts/dev/tests/` の全 Python unittest を実行し、現行の呼び出し元の旧パスと公開対象の開発専用依存を検索・確認する。
- [ ] T009 `swift build`、`swift test`、`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh` の順に実行する。
- [ ] T010 `scripts/make-app.sh` で `.build/Folzio.app` を作成する。
- [ ] T011 [MANUAL] ユーザーが `open .build/Folzio.app` を実行し、3ペイン表示と問題の有無を報告する。
- [ ] T012 GUI 報告を受けて `specs/017-separate-script-directories/tasks.md` の進捗を記録し、Phase の変更をコミットする。

## Dependencies & Execution Order

T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 → T010 → T011 → T012。US2 は移動後の配置に依存する。T011 は独立したユーザー確認であり、報告まで未チェックとする。並列実装は行わない。

## Implementation Strategy

US1 の archive 境界を回帰テストで守った後、US2 の全呼び出し経路を追従させる。一連の変更を単一 Phase として検証する。最終 GUI 確認後に converge を行い、追加があれば同じゲートで検証する。製品仕様の反映は実装・検証後の別レビューで扱う。
