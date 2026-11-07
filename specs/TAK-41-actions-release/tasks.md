# Tasks: リリース PR と確認用 CI 成果物

**Input**: この feature の spec / plan / research / data-model / contracts。
**Tests**: FR-330 と候補の同等性を、一時 Git と API / gh stub、macOS 回帰で検証する。
**Organization**: US74（入口）→ US71（配布）→ US72（復旧）→ US73（確認）。進捗の正本はこのファイル。

## Phase 1: Setup — 改訂設計

- [x] T001 最新 master と追加要望を確認し、`specs/TAK-41-actions-release/spec.md` に release.json 変更 PR とローカル確認を反映する
- [x] T002 `specs/TAK-41-actions-release/plan.md`・research・data-model・contracts・quickstart と品質チェックを作る
- [x] T003 `specs/TAK-41-actions-release/tasks.md` に実装と導入検証の順序・要件対応を作る
- [x] T004 保守者の改訂設計のレビュー結果を `specs/TAK-41-actions-release/tasks.md` に追記する

T004 の承認前には実装しない。PR と本番設定も、今回の設計作業では作成・変更しない。

## Phase 2: Foundational — 共通の公開生成と要求

- [x] T005 `scripts/dev/tests/test_publish_folzio.py` に除外、README 調整、workflow 配置・内容、ホームパス、リンクと入力 source SHA の検証を追加する（FR-334）
- [x] T006 `scripts/dev/export-public.sh` を現行 publish から分離し、検証済み公開候補だけを生成する（FR-333・334）。`scripts/dev/publish.sh` は通常手順から外し、残す場合も共通処理へ委譲する（FR-179・339）
- [x] T007 `scripts/dev/tests/test_check_release_workflow.py` に metadata・ノートの不備、未知/重複キー、symlink・パス逸脱、push 比較不能・初回 before と、version の01.2.0 / 1.02.0 / 1.2.00・build の007の拒否、0単独の受理を追加する（FR-324・330）
- [x] T008 `scripts/release.py` に要求とイベントの共通検証を実装する。version は「文字列。`(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)` に全体一致」、build_number は「文字列。`(0|[1-9][0-9]*)` に全体一致」、notes_file は「`release-notes/` 配下の `.md` への相対パス」とし、値を補正せず data-model の全制約を検証する

## Phase 3: US74 — リリース PR と同期（P1）

**Goal**: 候補を確認した PR のマージから同期し、tree が変わった場合は固定 M の再候補と確認待ちへ進める。
**Independent Test**: 通常 PR、preview と M の一致/不一致、M+3 からの固定 M 復旧、初回 base、同時 writer を再現する。

- [x] T009 [US74] `.github/workflows/release-candidate.yml` と `scripts/dev/validate-release-candidate.sh` に PR preview と手動 source_sha の候補生成を実装する。必須検査の即時中断、性能の非ブロッキングと結果記録、30日 artifact・source/run/attempt 共通の名前を定義する（FR-311・328・340・341）
- [x] T010 [US74] `scripts/package-release.sh` に VERSION / BUILD / SOURCE_DIR / OUTPUT_DIR の隔離ビルド・ZIP と checksum・再展開検証を実装し、公開候補と最終配布で共用する（FR-325・340）
- [x] T011 [US74] `scripts/dev/tests/test_check_public_sync.py` に preview 後の別 PR マージによる tree のずれと M の再候補・確認待ち、M+3 から M を指定する復旧、手動間の HEAD 進行、候補欠落/失効/別対象、古い source と公開先競合を再現する。初回 base の欠落/不一致/一致、初期化済みの指定・不正 trailer の拒否、初期化時だけの同一 tree コミットも検証する（FR-330・333・336・338・342）
- [x] T012 [US74] `scripts/dev/sync-public.py` に固定 M・merged PR・候補 run の照合、候補の必須検証を再利用する静的同期、明示的 bootstrap、書き込み直前の base/source 再取得と非 force 更新を実装する（FR-335〜338・342）
- [x] T013 [US74] `.github/workflows/sync-public.yml` に release.json 差分の判定、tree 不一致時だけの固定 M の再候補生成・確認待ち、source_sha / candidate_run_id / bootstrap_public_base の手動再開、Secret 分離の writer を定義する。通常同期は Ubuntu だけとし、repo 共通 concurrency を使わない（FR-311・312・332・333・337）
- [x] T014 [US74] `scripts/dev/tests/test_check_public_sync.py` と既存 discover で、通常 push が待機中の同期を取り消さない構成、2 writer の競合と無差分・古い対象拒否を検証する。候補のコマンド記録で必須失敗後の後続停止、性能失敗後の通信検査続行・結果記録、成功 run でも必須結果不正の候補拒否を確認する（FR-311、SC-171・175〜177）

## Phase 4: US71 — 公開コミットから配布（P1）

**Goal**: 公開用への push から、その SHA の検証済み ZIP とドラフトを作る。
**Independent Test**: 要求の追加/同一と、実行中の HEAD の進行を再現し、固定した SHA と添付物を照合する。

- [x] T015 [US71] `scripts/dev/tests/test_package_release.py` に既存出力保護、隔離、先頭0の拒否、arm64、両バージョン、署名、日英リソース、ZIP の余計な項目・チェックサムの異常系を追加する（FR-324・325・330）
- [x] T016 [US71] `scripts/release.py` に plan / draft、GitHub 状態の検証、タグ作成、ZIP と checksum だけのドラフト添付を実装し、`scripts/dev/tests/test_check_release_workflow.py` で新規/同一要求・SHA 固定を確認する（FR-173・322〜327）
- [x] T017 [US71] `scripts/dev/oss-workflows/release.yml` に公開 repo / default branch の照合、read-only preflight、通常テスト、公開用 SHA の archive からの package と draft を実装する（FR-322・325・328）
- [x] T018 [US71] `scripts/dev/tests/test_publish_folzio.py` と `.github/workflows/macos-swift-ci.yml` に公開 workflow と依存の書き出し、パッケージ・公開回帰テストを組み込む（FR-329・330）

## Phase 5: US72 — 復旧（P1）

**Goal**: 再実行で既存の公開内容と配布物を保護する。
**Independent Test**: 同名タグ・Release、API 障害、競合と部分失敗を再現する。

- [x] T019 [US72] `scripts/dev/tests/test_check_release_workflow.py` に同一/別 SHA の軽量/注釈タグ、既存 draft/公開済み Release、404 と403/5xx/通信障害、タグ作成競合・部分失敗を追加する（FR-326・327・330）
- [x] T020 [US72] `scripts/release.py` と `scripts/dev/sync-public.py` に再照合と再開案内を整え、候補再生成と同期で source_sha=M を使い続けること、source/run/attempt の artifact 照合、bootstrap の誤用拒否、競合の可視化と安全な再実行を検証する（EC-225〜235）
- [x] T021 [US72] `scripts/dev/release-distribution.sh` の prepare を公開済み SHA の archive と共通 package へ委譲し、既存 CLI・出力先・release-info の4行を維持する（FR-169・339）
- [x] T022 [US72] `scripts/dev/tests/test_release_distribution.py` の fixture と回帰検証を共通 package に合わせ、remote HEAD・欠落ツール・不正 ZIP・既存 Release の保護を確認する（FR-330）

## Phase 6: US73 — 確認と公開（P2）

**Goal**: 保守者が CI の ZIP をローカルで確認し、出自を追跡して公開できる。
**Independent Test**: preview と固定 M の新候補を取得・展開・起動し、確認待ちでは書き込まず、明示した M/run で再開できることを確認する。

- [x] T023 [US73] `release.example.json` と `docs/releasing.md` に PR preview の取得・外側 ZIP の展開・ローカル確認後のマージ、M が異なる場合の新候補の再確認と M/run 指定の再開、初期 base と復旧を説明する（FR-324・339・340・343）。実 release.json は次の配布時まで作らない
- [x] T024 [US73] `docs_private/repository-and-release.md`・`scripts/dev/oss-workflows/README.md` と必要な Cloud 手順を新しい経路にそろえる。master 追従不要は維持し、性能の例外・必須失敗後の中断、同期時の検証再利用、App / Secret・初期 base・保護規則の設定と復旧を説明する（FR-169・179・311・312・339）
- [x] T025 [US73] `scripts/release.py` と `scripts/dev/sync-public.py` の summary / metadata に source / public SHA、PR / head / run / attempt、source_kind、tree・version / build・toolchain・checksum、必須検証・性能結果と確認待ち/省略/失敗理由を示してテストする（FR-331・341）

## Phase 7: Polish — 実装 PR の検証と反映

- [x] T026 `scripts/dev/check-all.sh` を実行し、新しい判定・同期テストを含む Cloud の結果をこの tasks.md に記録する
- [x] T027 `.github/workflows/macos-swift-ci.yml` の build / test と公開・配布回帰の結果を確認し、この tasks.md に記録する
- [x] T028 保守者が作業ブランチで `scripts/make-app.sh` → `open .build/Folzio.app` の3ペイン・日英のマージ前スモークを確認し、この tasks.md に記録する
- [x] T029 最新 master と `scripts/dev/check-spec-ids.sh` を確認してから、`specs/product/overview.md` と `specs/product/contracts/scripts.md`・app-bundle.md・README.md に反映する。特に FR-311（overview.md）の検査場所・性能の例外・失敗後の即時中断と、scripts 契約の旧「同期後テスト」をそろえ、ID と形式・check-all を検査する
- [x] T030 `specs/product/` の反映差分を保守者に示し、承認後にコミットする。実装 PR は保守者の依頼時だけ作成する

## Phase 8: 導入・実リリースの確認（保守者、実装 PR のマージ後）

- [x] T031 `docs_private/repository-and-release.md` の手順で保守者が App / Secret と公開用 main の保護規則、初回 bootstrap_public_base を確認する。Cloud のトークンを Actions 設定済みとは扱わない
- [x] T032 保守者が初回の release.json 変更 PR を作り、`specs/TAK-41-actions-release/quickstart.md` の CI artifact を取得してローカル PC で checksum・3ペイン・日英・About を確認し、この tasks.md に記録する
- [ ] T033 保守者が確認した PR をマージし、`specs/TAK-41-actions-release/quickstart.md` の初回 base の明示と同期・配布の連鎖を確認する。preview 後の他 PR マージでは M の新候補を再確認して手動再開し、M+3 から M を復旧する場合も検証して tasks.md に記録する
- [x] T034 保守者が公開用ドラフトの最終 ZIP とノート・タグを確認し、GUI / Gatekeeper の確認後に公開して、この tasks.md に記録する
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

- 2026-11-07 12:47（日本時間）: 保守者から公開完了の報告を受け、Release437291898 が
  draft=false / published_at=2026-11-07T03:47:02Z であることを GitHub API で確認し、T034 を完了とした。
  公開URL: https://github.com/yoshidax/folzio/releases/tag/v1.0.1
  ZIP719449521 と SHA256SUMS719449523 は確認済みの ID・digest のまま uploaded、
  タグ v1.0.1 は公開コミット d351e0f3d5ed4f1ade89c0892eba6c5232f2363d を指している。
  初回 release.json PR → CI候補 → ローカル確認 → マージ → 初回同期 → 最終CI → GUI確認 → 公開の経路は完了。
  T033 の preview 不一致の再確認と M+3 復旧の実確認は未実施のため、同項目と T035 は未チェックのまま。
  feature 凍結と Issue Done は行わず、導入記録を agent/tak-41-release-rollout へ push する。

- 2026-11-07（日本時間）: 保守者が公開用ドラフト437291898の最終 ZIP について、
  起動・3ペイン・日英切り替え・About 1.0.1 の表示に問題なしと報告した。
  GitHub API で ZIP719449521 / SHA256SUMS719449523 の ID・digest が案内時から変わっていないことを確認した。
  ZIP SHA-256 は db969ab8b37f53349d693f555cbe45983cf89cad01b4316e56329cf660c73062。
  checksum・署名・ノートとタグの整合は CI / API で確認済み。最終 ZIP の保守者による checksum コマンドの結果は
  今回の報告には含まれていないため、明示的な成功報告としては記録しない。
  ドラフトは未公開のため T034 は未チェックを維持し、保守者による公開を待つ。
  T033 の preview 不一致・M+3 復旧の実確認、T035 の凍結も未実施のまま残す。

- 2026-11-07（日本時間）: 保守者が App の権限更新を installation 側で承認したと報告した。
  公開用 main の base が ada5f31703afab1c1ee7082326c5f345bcab74dd のままであることを確認し、
  run 42331626203 の failed jobs を再実行（attempt 3）。前 attempt の入力 artifact を再利用し、
  App token 作成・writer・token 失効まで成功したため T031 を完了とした。
  公開用 main は d351e0f3d5ed4f1ade89c0892eba6c5232f2363d に更新され、親は上記 base、
  Development-Commit trailer は c8840c850628c3b437f89c3a0cae7c08e524f657。
  M 固有の exporter で再生成した tree fd6614fc571caa0dca1101778c8e8bde9a219b42 と公開 tree の一致を確認した。
  公開側の Build release draft run 42332962032 はこの公開 SHA で成功。
  Swift 通常1057件・production build・arm64 / 両バージョン / 日英 / 署名 / ZIP再展開の検証が成功し、
  タグ v1.0.1 が同じ公開 SHA を指すことを確認した。
  ドラフト437291898（v1.0.1 / build 2）に ZIP2136052 bytes と SHA256SUMS96 bytes が添付済み。
  ZIP のSHA-256は db969ab8b37f53349d693f555cbe45983cf89cad01b4316e56329cf660c73062。
  ノートが M の release-notes/v1.0.1.md と一致し、公開SHA・version・build・run の出自があることを確認した。
  ドラフト: https://github.com/yoshidax/folzio/releases/tag/untagged-082f5d93370336cbbb40
  T033 は初回同期成功の一部確認にとどまり、preview 不一致の再確認・M+3 復旧の実確認は未実施。
  T034 の最終 ZIP・GUI / Gatekeeper・公開と T035 の凍結は未実施のまま残す。

- 2026-11-07（日本時間）: PR #65 のマージを保守者が報告し、master の
  c8840c850628c3b437f89c3a0cae7c08e524f657 に含まれることを確認した。
  push の同期 run 42331407257 は確認済み候補の照合を通過し、初回 base の明示待ちで停止した。
  公開用 main の現在値 ada5f31703afab1c1ee7082326c5f345bcab74dd を取得し、
  source_sha=c8840c850628c3b437f89c3a0cae7c08e524f657 / candidate_run_id=42287354274 /
  bootstrap_public_base=ada5f31703afab1c1ee7082326c5f345bcab74dd で手動同期 run 42331626203 を開始した。
  plan は成功したが、writer の App token 作成で HTTP 422
  "The permissions requested are not granted to this installation." が返り、公開書き込みは未実施。
  Contents write / Workflows write の App 定義と installation の承認を保守者が再確認する必要があるため、
  T031 を未チェックに戻した。T032 は完了、T033〜T035 は未完了のまま。
  公開用の最終ビルド・ドラフトは今回の実行からは作成されていない。
  その後、保守者から Contents 権限の修正報告を受け、公開用 main が同じ SHA であることを確認して
  run 42331626203 の failed jobs を再実行した（attempt 2）。前 attempt の入力 artifact 取得は成功したが、
  App token 作成で同じ HTTP 422 が返り、公開書き込みは引き続き未実施。
  実際の対象 installation は 179372623、Actions の Client ID は Iv23liFeoQ6vm9wGlubj。
  https://github.com/settings/installations/179372623 で Contents / Workflows の Read and write と
  権限変更の承認を保守者が確認する。App 定義の変更だけで installation の権限更新済みとは判断しない。

- 2026-11-07（日本時間）: 保守者から v1.0.1 / build 2 の CI 候補について、checksum 成功と
  3ペイン・日英切り替え・About 1.0.1 の表示に問題なしとの報告を受け、T032 を完了とした。
  対象は PR #65 の HEAD 968951c06310242a09e123e46219c299b0e395ba、
  preview 60dc03cfa26e866ce45cc510143b74828ca770f9、run 42287354274 / attempt 1 / artifact 13538018754。
  PC 構成の詳細は未確認。最終配布 ZIP の GUI / Gatekeeper 確認（T034）は別途必要。
  確認結果は PR #65 と Linear にも記録した。確認済みリリース PR の HEAD は変更せず、
  マージ後の agent/tak-41-release-rollout で導入記録と合わせてコミットする。T033〜T035 は未実施のまま残す。

- 初回候補の run 42284638995 は通常テスト1057件・通信 API 検査・production build の成功後、
  make-app.sh が SwiftPM 6.0 の翻訳リソース配置を扱えず停止し、ZIP は未生成。
  保守者が診断 swiftpm-resource-layout と両配置への対応を承認したため、実 make-app の回帰4件と修正を追加した。
  Cloud は143件成功 / macOS・rsync33件skip。修正後の最新候補 CI とダウンロード候補のローカル確認は未実施で、
  T032 は未チェックのまま維持する。最新 CI と成果物の取得先は PR #65 に記録する。

- 初回リリース準備: 保守者から GitHub App・Actions の設定と公開用 main の保護規則の確認（T031）が完了したと報告を受けた。
  設定内容と App の実認証は Cloud から未検証。公開用 main は ada5f31703afab1c1ee7082326c5f345bcab74dd で、
  Development-Commit trailer がないため初回同期は bootstrap_public_base が必要。同期時に現在の SHA を再確認する。
  v1.0.0 は既存のタグとドラフトがあるため、初回の Actions リリース PR は未使用の v1.0.1 / build 2 を使う。
  T032 は候補の取得・ローカル PC での確認まで未チェック。T033〜T035 も未実施のまま残す。

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

- 2026-11-06: 保守者が spec を承認。1a87362 の改訂設計に沿った実装を開始する。

- 基盤実装: exporter の Python helper を export-public.sh から呼び出す。指定 SHA・dirty worktree・既存出力保護・公開境界の3件と metadata の3件を確認。旧 publish は共通 exporter を利用する復旧用。Cloud に rsync がないため旧ローカル復旧の18件は macOS CI で確認する。

- 候補・同期・配布の実装とテスト・ガイドを追加。Cloud の check-all は成功（判定系105件、README注記19件、exporter5件。macOS / rsync の29件は実行環境不足で明示的 skip）。候補のコマンド列、固定 M、API 障害、artifact digest、実 Git の非 fast-forward、部分アップロードを検証。macOS と実 workflow の導入確認は T027・T031以降で確認する。
- 公開ツリー検査では、既存 Swift テストの架空パス /Users/me・me2・x を Tests 内だけで区別する。個人パスは拒否する回帰テストを追加した。

- T026: 最新の check-all は129件成功、macOS / rsync 必須の29件は skip。再候補ソースは digest 付き tar で job 間転送し、実行権限を維持する回帰も成功。T027 は既存 CI の workflow_dispatch を作業ブランチで実行して確認する（PR は作成しない）。

- hosted account（runner / runneradmin）の一般語による誤検出を除き、パス検査を維持する回帰を追加。両バージョン不一致と ZIP 境界・checksum の異常系も追加した。

- macOS CI 42235998815: arm64 / Xcode16.0を確認。旧README注記なしのfixtureが英語版だけを更新していたため新しい構造照合で1件失敗。日英同等のfixtureへ修正して再検証する。build / Swift testは前段失敗で未実施。

- T028: 保守者が c2d0d53 の作業ブランチで make-app → open を実行し、3ペイン・日英・About の確認ができたと回答（2026-11-06）。CIと実装マージ後のダウンロード候補確認は別ゲートとして扱う。

- macOS CI 42236274776: publish23件・README19件は成功。package fixture の copy2(/bin/ls) が macOS の保護属性をコピーして PermissionError。fixture を属性不要の copyfile + 実行権限に変更し、再実行する。実アプリのコピー処理は対象外。

- macOS CI 42237257443: ZIP成功経路が通った後、Bash3.2で関数内の [[ ]] の失敗が errexit だけでは停止しない不具合を検出。共通 package の architecture / version / build 検査を明示的 return 1 に修正し、既存の異常系で再検証する。

- T027: fd8b16f の macOS CI [42237534859](https://github.com/yoshidax/folzio-dev/actions/runs/42237534859) は成功。
  arm64 / Xcode16.0 / Swift6.0、Python158件（Cloud skip29件を含め全成功）、Swift通常1057件成功。
  性能27件中3件で閾値超過: 24MP JPEG 1.2117s > 0.5s、1万件フォルダ復帰1.0054s > 1s、
  rename rebase中央値0.1523s > 0.1s。continue-on-error の success 表示だけでなくログを確認した。
- T029: 最新 origin/master（03c80bc）を確認し、製品仕様4ファイルに承認済み要件を反映した差分を作成。
  新規50定義の本文一致、ID重複なし、形式エラー0・既存警告88件の増加なし、check-all129件成功 / 29件skip。
  最終コミットの公開書き出しも hosted account 条件で成功。製品仕様の差分は未コミットでT030の承認を待つ。
- T031以降の本番App/Secret設定、初回release PR・CI成果物の取得とローカル確認、公開連鎖は未実施。
  今回の起動スモークをダウンロード候補の実確認の代わりとは扱わず、IssueはIn Progressのままにする。


## 実装レビュー9件への対応（2026-11-07）

- ドラフト検出: 公式 REST 文書の published-only と draft 一覧の権限を照合。認証済み一覧の全ページから tag を探す。
  tag lookup が404でも2ページ目の draft を拒否し、部分添付失敗後の再実行で作成を繰り返さないテストを追加。
- 使用済み version: PR preview・同期判定・App writer の書き込み前に照合する。read-only では見えない draft も writer で拒否する。
- failed jobs 再実行: plan から入力 artifact ID を引き継ぎ、候補は実際に生成した最新 build job の attempt に照合する。
- 確認待ち: 専用 job を明示的 failure / Not published とし、成功した rebuild と同期完了を区別する。
  成功した候補 job と、待機以外の失敗がないことを API で確認してから再開に利用する。
- ホームパス: 名前による fixture 例外を廃止し、Swift テストの仮想パスを /test-homes/ に統一する。
- README: exporter の独自 skeleton を削除し、既存 check-readme-sync.sh の --structure-only に統合する。
- 固定 M: exporter 自体を M から読み、共通 package も M の公開ソース側を使う。後続 HEAD の規則変更の回帰を追加する。
- 公開履歴: 判定は blob なしの main 履歴、writer は1コミットの shallow fetch とし、全履歴の二重 clone を廃止する。
- T029: 製品仕様4ファイルは手元の未コミット差分で、リモートにはなく承認待ち。誤解を避けて未チェックへ戻す。
  既存差分を保持し、修正後の検証結果に合わせて更新する。T027も修正後のCI確認まで未チェックへ戻す。

- 修正後の Cloud 検証: check-all140件成功 / macOS・rsync29件skip。YAML構文と生成jobからのartifact ID参照、Python / Bash構文を確認。修正コードをpushし、読み取り専用public API確認を含むmacOS CIでT027を再検証する。

- download-artifact@v4 の実装を確認し、ID指定の展開は merge-multiple:true で固定する。github-token と run-id を明示して、前attemptも含むREST取得を使う。既存macOS CIに小さなhandoff probeを追加し、受取jobのみ初回を意図的に失敗させる任意入力から実際のfailed-job再実行を検証する。

- 実CI 42259015217 の failed-jobs 再実行で、artifact13522914846（生成attempt1）をattempt2の受取jobが再利用して成功。
  再実行しないjobもAPIでは新ID / attempt2に複製され、runner_id・実行時刻・全stepsは元のままという実データを確認。
  候補の照合もこの複製を元の生成attemptに結び付けるよう補強し、本当の新規buildとは区別する回帰を追加した。

- 2026-11-07 修正後の最終検証: 6bdbb2b の [CI 42261112029](https://github.com/yoshidax/folzio-dev/actions/runs/42261112029) は成功。
  macOS arm64 / Xcode16.0 / Swift6.0でPython170件（skipなし）・Swift通常1057件成功。
  公開用APIは開発用read-only GITHUB_TOKENから一覧とタグ（3件）を取得し、タグ解決も成功した。
  性能27件は4件で閾値超過: JPEG0.8229s > 0.5s、rename中央値0.1196s > 0.1s、batch0.1110s > 0.1s、
  slideshow0.2455s > 0.2s。非ブロッキングのまま実ログで確認した。
- [CI 42259015217 attempt2](https://github.com/yoshidax/folzio-dev/actions/runs/42259015217/attempts/2)で部分再実行の引き継ぎを実証。
  元artifact13522914846を受取jobだけが再利用し、生成・macOSの実行時刻とrunnerは変わらない。
  複製されたAPI jobデータにも最新の照合関数を適用し、生成1・受取2・macOS1と正しく識別した。
- 最終check-allは141件成功 / macOS・rsync29件skip、製品仕様の形式エラー0・既存警告88件で増加なし、ID重複なし。
  新規50定義は承認済みspecと一致。最新origin/masterは03c80bcで作業ブランチに含まれる。
  公開ツリーはdd6ad9aと6bdbb2bで同一。M固有のexporterによる書き出しも成功した。
- 製品仕様4ファイルの更新済み差分を提示。T029・T030は承認とコミットまで未チェックとし、作業ツリーの差分を保持する。

- 2026-11-07: 保守者が製品仕様4ファイルの更新済み差分のコミット・pushを承認。
  提示したpatchと作業ツリーの差分の完全一致を確認し、最新origin/master（03c80bc）が祖先であることを確認した。
  ID重複なし、形式エラー0・既存警告88件で増加なしを再確認し、承認差分とT029・T030の完了記録をコミットする。
  導入・実リリースのT031〜T035は未実施のまま残し、IssueはIn Progressを維持する。


## 追加レビュー3件への対応（2026-11-07）

- 通常 PR の macOS CI で、checkout した実 HEAD を共通 exporter で最初に生成・検査する。
  release.json の変更に関係なくホームパス・README・公開境界の不備を PR 内で検出する。
- 公開用 plan の contents read は維持し、既存の contents write を持つ release job の冒頭でも plan を実行する。
  read-only の一覧から隠れていた draft を通常テスト・配布ビルドの前に拒否する回帰を追加する。
  macOS 起動・checkout は残るが、ビルド後まで検出が遅れる問題を解消し、資格情報の権限を広げない。
- 実証用 artifact-plan / artifact-retry の2 job・verify_artifact_retry 入力と公開 API 参照 step を通常 CI から削除。
  実証結果と回帰テストを保持する。T027 は変更後の CI 確認まで未チェックへ戻す。

- 追加修正のCloud検証: check-all142件成功 / macOS・rsync29件skip。CIはmacOSの1jobだけでHEAD書き出しが先頭、公開用は既存の権限のままdraft再確認が通常テスト・buildの前であることをYAML構造で確認した。製品仕様の要件・契約と権限モデルは変更しない。

- 追加レビュー後の [CI 42266691659](https://github.com/yoshidax/folzio-dev/actions/runs/42266691659) は84df885で成功。
  実HEADの公開ツリー検査が先頭で成功し、macOSの1jobのみで実行された。
  Python171件（skipなし）・Swift通常1057件が成功。Cloudは142件成功 / macOS・rsync29件skip。
  性能27件中4件で閾値超過: JPEG0.5678s > 0.5s、rename中央値0.1057s > 0.1s、batch0.1537s > 0.1s、
  slideshow0.2420s > 0.2s。continue-on-error の結果を実ログで確認した。
  公開用workflowのdraft再確認はAPI権限差の回帰とstep順序で検証し、本番workflowの起動は行っていない。


## ローカル復旧時のユーザー名の誤検出への対応（2026-11-07）

- ユーザー名を識別子の語境界（英数字・underscore・dot・hyphenの外側）で照合し、re.escapeで名前をリテラルに扱う。
  yoshidaがyoshidax/folzioなどの一部として現れる場合は許可し、単独の署名の名前は拒否する。
- genericにrootを加え、CIアカウント名とrootが一般語・変数名に現れる理由をコメントに記録する。
  HOMEの実パスと /Users /home の名前非依存の検査は変更しない。
- 回帰で部分一致・単独名・dotを含む名前のescape、runner / runneradmin / rootの通常語を検証する。
  /Users /homeとroot自身の /root/private は引き続き拒否し、失敗時に出力を残さないことも確認する。
- T027は修正後のCI確認まで未チェックに戻す。アプリ本体・製品仕様・公開先の権限は変更しない。

- 修正後のcheck-allは143件成功 / macOS・rsync29件skip。root（HOME=/root）とyoshida（HOME=/Users/yoshida）の条件を
  getpass / Path.homeで模擬し、d4c8ad3のコミット済みコードとHEAD全体による書き出しが両方成功した。
- [CI 42271510306](https://github.com/yoshidax/folzio-dev/actions/runs/42271510306)はd4c8ad3で成功。
  HEAD書き出し、Python172件（skipなし）・Swift通常1057件が成功し、T027を再確認した。
  性能27件中2件で閾値超過: batch0.1568s > 0.1s、slideshow0.3226s > 0.2s。
  既存の非ブロッキング方針のまま実ログを確認した。
