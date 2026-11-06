# Tasks: リリース PR と確認用 CI 成果物

**Input**: この feature の spec / plan / research / data-model / contracts。
**Tests**: FR-330 と候補の同等性を、一時 Git と API / gh stub、macOS 回帰で検証する。
**Organization**: US74（入口）→ US71（配布）→ US72（復旧）→ US73（確認）。進捗の正本はこのファイル。

## Phase 1: Setup — 改訂設計

- [x] T001 最新 master と追加要望を確認し、`specs/TAK-41-actions-release/spec.md` に release.json 変更 PR とローカル確認を反映する
- [x] T002 `specs/TAK-41-actions-release/plan.md`・research・data-model・contracts・quickstart と品質チェックを作る
- [x] T003 `specs/TAK-41-actions-release/tasks.md` に実装と導入検証の順序・要件対応を作る
- [ ] T004 保守者の改訂設計のレビュー結果を `specs/TAK-41-actions-release/tasks.md` に追記する

T004 の承認前には実装しない。PR と本番設定も、今回の設計作業では作成・変更しない。

## Phase 2: Foundational — 共通の公開生成と要求

- [ ] T005 `scripts/dev/tests/test_publish_folzio.py` に除外、README 調整、workflow 配置・内容、ホームパス、リンクと入力 source SHA の検証を追加する（FR-334）
- [ ] T006 `scripts/dev/export-public.sh` を現行 publish から分離し、検証済み公開候補だけを生成する（FR-333・334）。`scripts/dev/publish.sh` は通常手順から外し、残す場合も共通処理へ委譲する（FR-179・339）
- [ ] T007 `scripts/dev/tests/test_check_release_workflow.py` に metadata・ノートの不備、未知/重複キー、symlink・パス逸脱、push 比較不能・初回 before と、version の01.2.0 / 1.02.0 / 1.2.00・build の007の拒否、0単独の受理を追加する（FR-324・330）
- [ ] T008 `scripts/release.py` に要求とイベントの共通検証を実装する。version は「文字列。`(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)` に全体一致」、build_number は「文字列。`(0|[1-9][0-9]*)` に全体一致」、notes_file は「`release-notes/` 配下の `.md` への相対パス」とし、値を補正せず data-model の全制約を検証する

## Phase 3: US74 — リリース PR と同期（P1）

**Goal**: 候補を確認した PR のマージから同期し、tree が変わった場合は固定 M の再候補と確認待ちへ進める。
**Independent Test**: 通常 PR、preview と M の一致/不一致、M+3 からの固定 M 復旧、初回 base、同時 writer を再現する。

- [ ] T009 [US74] `.github/workflows/release-candidate.yml` と `scripts/dev/validate-release-candidate.sh` に PR preview と手動 source_sha の候補生成を実装する。必須検査の即時中断、性能の非ブロッキングと結果記録、30日 artifact・source/run/attempt 共通の名前を定義する（FR-311・328・340・341）
- [ ] T010 [US74] `scripts/package-release.sh` に VERSION / BUILD / SOURCE_DIR / OUTPUT_DIR の隔離ビルド・ZIP と checksum・再展開検証を実装し、公開候補と最終配布で共用する（FR-325・340）
- [ ] T011 [US74] `scripts/dev/tests/test_check_public_sync.py` に preview 後の別 PR マージによる tree のずれと M の再候補・確認待ち、M+3 から M を指定する復旧、手動間の HEAD 進行、候補欠落/失効/別対象、古い source と公開先競合を再現する。初回 base の欠落/不一致/一致、初期化済みの指定・不正 trailer の拒否、初期化時だけの同一 tree コミットも検証する（FR-330・333・336・338・342）
- [ ] T012 [US74] `scripts/dev/sync-public.py` に固定 M・merged PR・候補 run の照合、候補の必須検証を再利用する静的同期、明示的 bootstrap、書き込み直前の base/source 再取得と非 force 更新を実装する（FR-335〜338・342）
- [ ] T013 [US74] `.github/workflows/sync-public.yml` に release.json 差分の判定、tree 不一致時だけの固定 M の再候補生成・確認待ち、source_sha / candidate_run_id / bootstrap_public_base の手動再開、Secret 分離の writer を定義する。通常同期は Ubuntu だけとし、repo 共通 concurrency を使わない（FR-311・312・332・333・337）
- [ ] T014 [US74] `scripts/dev/tests/test_check_public_sync.py` と既存 discover で、通常 push が待機中の同期を取り消さない構成、2 writer の競合と無差分・古い対象拒否を検証する。候補のコマンド記録で必須失敗後の後続停止、性能失敗後の通信検査続行・結果記録、成功 run でも必須結果不正の候補拒否を確認する（FR-311、SC-171・175〜177）

## Phase 4: US71 — 公開コミットから配布（P1）

**Goal**: 公開用への push から、その SHA の検証済み ZIP とドラフトを作る。
**Independent Test**: 要求の追加/同一と、実行中の HEAD の進行を再現し、固定した SHA と添付物を照合する。

- [ ] T015 [US71] `scripts/dev/tests/test_package_release.py` に既存出力保護、隔離、先頭0の拒否、arm64、両バージョン、署名、日英リソース、ZIP の余計な項目・チェックサムの異常系を追加する（FR-324・325・330）
- [ ] T016 [US71] `scripts/release.py` に plan / draft、GitHub 状態の検証、タグ作成、ZIP と checksum だけのドラフト添付を実装し、`scripts/dev/tests/test_check_release_workflow.py` で新規/同一要求・SHA 固定を確認する（FR-173・322〜327）
- [ ] T017 [US71] `scripts/dev/oss-workflows/release.yml` に公開 repo / default branch の照合、read-only preflight、通常テスト、公開用 SHA の archive からの package と draft を実装する（FR-322・325・328）
- [ ] T018 [US71] `scripts/dev/tests/test_publish_folzio.py` と `.github/workflows/macos-swift-ci.yml` に公開 workflow と依存の書き出し、パッケージ・公開回帰テストを組み込む（FR-329・330）

## Phase 5: US72 — 復旧（P1）

**Goal**: 再実行で既存の公開内容と配布物を保護する。
**Independent Test**: 同名タグ・Release、API 障害、競合と部分失敗を再現する。

- [ ] T019 [US72] `scripts/dev/tests/test_check_release_workflow.py` に同一/別 SHA の軽量/注釈タグ、既存 draft/公開済み Release、404 と403/5xx/通信障害、タグ作成競合・部分失敗を追加する（FR-326・327・330）
- [ ] T020 [US72] `scripts/release.py` と `scripts/dev/sync-public.py` に再照合と再開案内を整え、候補再生成と同期で source_sha=M を使い続けること、source/run/attempt の artifact 照合、bootstrap の誤用拒否、競合の可視化と安全な再実行を検証する（EC-225〜235）
- [ ] T021 [US72] `scripts/dev/release-distribution.sh` の prepare を公開済み SHA の archive と共通 package へ委譲し、既存 CLI・出力先・release-info の4行を維持する（FR-169・339）
- [ ] T022 [US72] `scripts/dev/tests/test_release_distribution.py` の fixture と回帰検証を共通 package に合わせ、remote HEAD・欠落ツール・不正 ZIP・既存 Release の保護を確認する（FR-330）

## Phase 6: US73 — 確認と公開（P2）

**Goal**: 保守者が CI の ZIP をローカルで確認し、出自を追跡して公開できる。
**Independent Test**: preview と固定 M の新候補を取得・展開・起動し、確認待ちでは書き込まず、明示した M/run で再開できることを確認する。

- [ ] T023 [US73] `release.example.json` と `docs/releasing.md` に PR preview の取得・外側 ZIP の展開・ローカル確認後のマージ、M が異なる場合の新候補の再確認と M/run 指定の再開、初期 base と復旧を説明する（FR-324・339・340・343）。実 release.json は次の配布時まで作らない
- [ ] T024 [US73] `docs_private/repository-and-release.md`・`scripts/dev/oss-workflows/README.md` と必要な Cloud 手順を新しい経路にそろえる。master 追従不要は維持し、性能の例外・必須失敗後の中断、同期時の検証再利用、App / Secret・初期 base・保護規則の設定と復旧を説明する（FR-169・179・311・312・339）
- [ ] T025 [US73] `scripts/release.py` と `scripts/dev/sync-public.py` の summary / metadata に source / public SHA、PR / head / run / attempt、source_kind、tree・version / build・toolchain・checksum、必須検証・性能結果と確認待ち/省略/失敗理由を示してテストする（FR-331・341）

## Phase 7: Polish — 実装 PR の検証と反映

- [ ] T026 `scripts/dev/check-all.sh` を実行し、新しい判定・同期テストを含む Cloud の結果をこの tasks.md に記録する
- [ ] T027 `.github/workflows/macos-swift-ci.yml` の build / test と公開・配布回帰の結果を確認し、この tasks.md に記録する
- [ ] T028 保守者が作業ブランチで `scripts/make-app.sh` → `open .build/Folzio.app` の3ペイン・日英のマージ前スモークを確認し、この tasks.md に記録する
- [ ] T029 最新 master と `scripts/dev/check-spec-ids.sh` を確認してから、`specs/product/overview.md` と `specs/product/contracts/scripts.md`・app-bundle.md・README.md に反映する。特に FR-311（overview.md）の検査場所・性能の例外・失敗後の即時中断と、scripts 契約の旧「同期後テスト」をそろえ、ID と形式・check-all を検査する
- [ ] T030 `specs/product/` の反映差分を保守者に示し、承認後にコミットする。実装 PR は保守者の依頼時だけ作成する

## Phase 8: 導入・実リリースの確認（保守者、実装 PR のマージ後）

- [ ] T031 `docs_private/repository-and-release.md` の手順で保守者が App / Secret と公開用 main の保護規則、初回 bootstrap_public_base を確認する。Cloud のトークンを Actions 設定済みとは扱わない
- [ ] T032 保守者が初回の release.json 変更 PR を作り、`specs/TAK-41-actions-release/quickstart.md` の CI artifact を取得してローカル PC で checksum・3ペイン・日英・About を確認し、この tasks.md に記録する
- [ ] T033 保守者が確認した PR をマージし、`specs/TAK-41-actions-release/quickstart.md` の初回 base の明示と同期・配布の連鎖を確認する。preview 後の他 PR マージでは M の新候補を再確認して手動再開し、M+3 から M を復旧する場合も検証して tasks.md に記録する
- [ ] T034 保守者が公開用ドラフトの最終 ZIP とノート・タグを確認し、GUI / Gatekeeper の確認後に公開して、この tasks.md に記録する
- [ ] T035 実確認がそろった後、`specs/TAK-41-actions-release/spec.md` に移行・凍結の注記を追記する

T031〜T034 は保守者による実際の確認まで未チェックにする。未確認の間は Issue を Done にしない。

## Dependencies & Execution Order

T001〜T004（承認）→ T005〜T008 → US74 → US71 → US72 → US73 → T026〜T030。
T027 は保守者が依頼して実装 PR を作った後の CI で確認する。
製品仕様への反映は Cloud・CI・マージ前 GUI の確認後に行う。
その後、保守者の実装 PR マージ → T031〜T034（リリース PR と実 CI 成果物の確認）→ T035。
実装 PR と製品のリリース PR は別のものとし、初回導入の候補確認を済んだことにはしない。

## Parallel Opportunities

Cloud の規約に従いサブエージェントで分割しない。[P] の指定なし。
候補の検証と package を共通化する。通常同期に macOS を使わず、M の再確認が必要な分岐だけで候補を追加生成する。

## Requirement Coverage

| 要件 | タスク |
|---|---|
| FR-169・173・179・311・312 | T006・T009・T013・T014・T016・T021・T024・T029 |
| FR-322〜324 | T007・T008・T016・T017・T023 |
| FR-325〜327 | T010・T015〜T017・T019〜T022 |
| FR-328〜330 | T007・T009・T011・T014・T015・T018・T019・T022 |
| FR-331 | T025 |
| FR-332〜334 | T005・T006・T009・T013・T014 |
| FR-335〜338 | T011〜T014・T020・T031・T033 |
| FR-339 | T006・T021・T023・T024 |
| FR-340〜343 | T009〜T013・T023・T025・T032 |
| SC-170〜174 | T016〜T022・T032〜T034 |
| SC-175〜177 | T011〜T014・T033 |
| SC-178・179 | T009〜T013・T032・T033 |

## Implementation Strategy

公開生成と候補検証・package を共通化する。一致時は検証結果を再利用し、不一致時は M の再候補 → 再確認 → 手動再開へ進む。
本番の push・認証設定をせずに大部分を一時 Git と stub で確認し、最後に保守者が導入・実リリースを検証する。

## 検証・承認の記録

- 2026-11-06: 2リポジトリ維持、release.json 変更 PR 起点、CI 成果物によるローカル確認の要望を反映。
- 設計段階の既存 check-all は成功（規則検査、unittest 73件と19件）。新機能の実装・実 CI・GUI は未確認。
- 環境切り替え前の未 push コミットは引き継がれていない。この環境で改訂設計を再作成した。


## 設計レビュー10件への対応（設計のみ）

| 指摘 | 修正した契約・仕様 | 実装時の確認 |
|---|---|---|
| 1 候補のずれ | 既存の master 追従不要を維持。M の新候補を生成して再確認・再開する正常分岐へ変更 | T009・T011〜T013・T033 |
| 2 pending の置換 | 同期の共通 concurrency を廃止し、base/source 再取得と非 force 更新で競合を扱う | T012〜T014 |
| 3 性能の失敗 | 性能は非ブロッキングと結果記録。他の必須検査は即時中断 | T009・T014・T024・T029 |
| 4 手動対象のずれ | source_sha 必須、M+3 の混入拒否、イベント共通の artifact 名を定義 | T009・T011・T013・T020 |
| 5 初回 base | bootstrap_public_base の入力、拒否条件と初期化専用遷移を定義 | T011〜T013・T020・T031・T033 |
| 6 重複 build | 同期で候補 CI を再利用し、通常の macOS 実行を候補と最終配布の2段階へ削減 | T009・T012〜T014 |
| 7 fail-fast の欠落 | FR-311（overview.md）の全文と scripts 契約の反映先に明記 | T014・T024・T029 |
| 8 領域参照 | 既存 ID の参照に overview.md を付記 | spec.md の参照と反映先を照合 |
| 9 先頭0 | version / build の形式を厳格化し補正しない | T007・T008・T015 |
| 10 ブランチ名 | リモート名 agent/tak-41-release-design とローカル work を区別 | spec / plan 冒頭を照合 |

コード・製品仕様の正本・既存 CI・保護規則はこの修正では変更していない。

設計修正後の検証: check-all 成功（既存73件 + 19件）、文書リンク・表・タスク ID・提案 ID の衝突なし、先頭0拒否の正規表現例を確認。新機能の実 CI・GUI は未実施。
