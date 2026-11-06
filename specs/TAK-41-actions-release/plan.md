# Implementation Plan: リリース PR と CI 候補による公開

**Branch**: `agent/tak-41-release-design` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)
**Local checkout**: `work`（同じコミットを追跡する Cloud のブランチ）
**Input**: `specs/TAK-41-actions-release/spec.md`

## Summary

release.json 変更 PR の CI で公開用の構成から ZIP を作り、保守者がローカルで確認してマージする。
実際の merge commit M と候補の公開 tree が一致すれば、候補 CI の検証を再利用して Ubuntu で同期する。
master 追従を必須にしない既存の運用では不一致も起こるため、その場合は M に固定した候補を作り直し、
ローカル再確認待ちとする。保守者が M と候補 run を指定して再開するまで公開用へ書き込まない。
公開用 push から公開済み SHA の最終ビルドとドラフト作成へつなぎ、保守者が確認後に公開する。

## Technical Context

**Language/Version**: Bash、Python 3.9 以降の標準ライブラリ、GitHub Actions YAML。
**Primary Dependencies**: Git、gh、Swift / Xcode、ditto、lipo、codesign、PlistBuddy、shasum。
公式 checkout / upload-artifact / download-artifact / create-github-app-token Action。
**Storage**: 要求・ノート、候補 artifact（30日）、同期 payload、GitHub のタグ・ドラフト。
**Testing**: 一時 Git と API / gh stub の unittest、macOS の回帰、実 CI とローカル GUI。
**Target Platform**: 判定・同期は Ubuntu、候補と最終配布は macos-15 arm64 / Xcode 16.0。
**Performance Goals**: 同一公開 tree の同期では macOS を再実行せず、候補と最終配布の2段階とする。
**Constraints**: 2リポジトリ、公開除外、単一対象 SHA、PR への公開 Secret 非提供、非 force 更新。
**Scale/Scope**: 候補・同期・配布の3 workflow、共通 exporter / 候補検証 / package、回帰と運用文書。

## Constitution Check

| 原則 | 設計前・設計後 | 根拠 |
|---|---|---|
| I ローカル完結・プライバシー | 適合 | 通信は開発・配布ツールのみ。アプリへ追加しない |
| II 体感パフォーマンス | 適合 | アプリ実装は変えず、性能測定を候補で実行し結果を残す |
| III キーボード・アクセシビリティ | 対象外 | UI の変更なし |
| IV テスト必須 | 適合 | 必須テストは失敗時に中断。性能の測定失敗は既存 CI と同じ明示的な例外 |
| V シンプルさ | 適合 | 検証・生成を共通化。追加 DB、独自の承認 UI、強制同期を作らない |

公式 App-token Action は独自の署名・トークン更新を避けるため必要（research R5）。
設計の承認前に実装しない。製品仕様の正本への反映は実装後のレビュー対象とする。

## Project Structure

### Documentation (this feature)

spec / plan / tasks / research / data-model / quickstart / checklists/requirements と
contracts/release-workflow、背景の github-publishing-proposal をこの feature に置く。

### Source Code (repository root)

```text
.github/workflows/release-candidate.yml       # PR preview / source_sha 指定の候補生成
.github/workflows/sync-public.yml             # 同期判定、必要時だけ M の再候補、手動再開
.github/workflows/macos-swift-ci.yml          # 公開・配布回帰テストを組み込む
scripts/dev/export-public.sh                 # 固定 SHA → 公開用 tree と静的検査
scripts/dev/validate-release-candidate.sh     # 共通の build / 通常 / 性能 / 通信検査と package
scripts/dev/sync-public.py                   # 対象・候補・初期 base の照合と書き込みを分離
scripts/dev/publish.sh                       # 通常経路から外し、残すなら共通処理へ委譲
scripts/dev/oss-workflows/release.yml         # 公開用の最終ビルドと draft
scripts/dev/release-distribution.sh          # ローカル復旧
scripts/release.py / scripts/package-release.sh # 公開用 CLI
scripts/dev/tests/test_check_release_workflow.py
scripts/dev/tests/test_check_public_sync.py
scripts/dev/tests/test_package_release.py
scripts/dev/tests/test_release_distribution.py
scripts/dev/tests/test_publish_folzio.py
release.example.json                        # 例だけ同梱。実要求とノートはリリース PR で追加
docs/releasing.md / docs_private/repository-and-release.md
scripts/dev/oss-workflows/README.md
specs/product/{overview,README}.md
specs/product/contracts/{scripts,app-bundle}.md
```

**Structure Decision**: 公開用は公開ファイルだけで動かし、dev workflow は書き出さない。
公開コード・workflow のコメントは英語、書き出さない開発専用コードは日本語。
README を変える場合は日英を同時更新する。

## Phase 0: Research

[research.md](research.md) R1〜R6。既存の master 追従不要と性能測定の非ブロッキングを踏まえる。
元の公開ツリーが同じ場合に必須検証を再利用し、異なるコードを既確認とは扱わない。

## Phase 1: Design

契約は [data-model.md](data-model.md) と [contracts/release-workflow.md](contracts/release-workflow.md)。

1. PR preview はテスト用 merge SHA に固定し、公開 tree を生成する。
   共通の候補検証で build → 通常テスト → 性能（非ブロッキング）→ 通信 API → package を実行し、
   ZIP / SHA256SUMS / candidate.json を保持する。他の必須検査の失敗時は後続を実行しない。
2. 保守者が preview を確認して PR をマージする。同期の Ubuntu 判定は実際の対象 M と merged PR を照合する。
   通常 push は判定だけで省略する。同期全体に共通の concurrency group を置かない。
3. preview の必須検証・head と PR の関係・公開 tree が M と一致すれば、その結果を使う。
   不一致・欠落・失効なら sync 内の条件付き macOS job で M の候補を作り、writer を起動せず確認待ちとする。
   これは master 追従不要の規則で起こり得る通常分岐として扱う。
4. 新候補をローカル確認した保守者は default branch の同期 workflow に source_sha=M と candidate_run_id を渡す。
   手動の候補生成にも同じ source_sha を要求する。起動時点の HEAD へ読み替えず、M+3 の混入を防ぐ。
5. Ubuntu で M の公開 tree を再生成し、静的検査と候補照合を行う。候補 CI の build・テストはここでは繰り返さない。
   public main を expected_public_base として記録し、照合済み payload を writer へ渡す。
6. writer だけに App Secret を渡す。書き込み直前の public base と source を再取得して照合し、
   public main だけを親にしたコミットを非 force push する。同時更新が先に成功したら競合として停止する。
   古い M は拒否、無差分は省略する。共通 concurrency の pending 置換で要求を失わせない。
7. trailer のない初回は初期化待ち。保守者が bootstrap_public_base を明示した手動同期に限り一致を検証し、
   最初の source trailer を作る。候補や M の検査は省略しない。
8. 公開用の push は公開用 SHA に固定して通常テストと最終 package を実行し、タグと2添付物のドラフトを作る。
   性能を再実行せず、既存 Release も自動上書きしない。GUI と最終公開は保守者が行う。

通常は macOS 2段階。M が preview と違う場合だけ、別のコードを確認するため候補の追加ビルドがある。
最終 ZIP は公開済みコミットから再ビルドし、tree・両バージョン・toolchain を照合する。バイト列の一致は要求しない。

## 検証と導入順序

1. Cloud で check-all・一時 Git の状態遷移、macOS CI で build / test / package・回帰を確認する。
2. 実装 PR のマージ前に保守者が既存の起動スモークを行う。
3. 製品仕様反映前に最新 master と ID を照合する。
   FR-311（overview.md）の検査場所・性能の例外・即時中断を contracts/scripts.md にも反映する。
   反映後に ID・形式を検査し、差分を示して承認後にコミットする。
4. 実装 PR のマージ後、App / Secret・公開先の保護規則を設定する。初回の候補確認後、
   明示的な bootstrap_public_base による同期を検証する。
5. 通常経路に加え、preview 後に別 PR をマージした場合、M+3 から M を指定する復旧、
   pending 置換を起こさない構成、競合、性能失敗時の継続と必須失敗時の中断を確認する。
   実 CI・ローカル・公開の確認までは Issue を完了・feature を凍結しない。

## Complexity Tracking

候補の再生成と手動再開は、マージ結果が変わったコードを未確認で配布しないために必要。
独自の承認 UI と状態 DB を追加せず、固定 SHA・CI run と明示的な手動入力を使う。
