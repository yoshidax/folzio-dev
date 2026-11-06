# Implementation Plan: リリース PR と CI 候補による公開

**Branch**: `work` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)
**Input**: `specs/TAK-41-actions-release/spec.md`

## Summary

release.json 変更 PR の CI で、実際に公開する構成から確認用 ZIP を作る。
保守者は Actions から取得してローカル PC で確認し、その PR をマージする。
マージ後に確認用候補と公開ツリーが一致することを検証し、公開用 main へ1コミットで同期する。
公開用の push を契機に公開済みコミットから最終ビルドし、タグと Release ドラフトを作る。
保守者が添付物を確認して公開する。通常の master 更新では同期しない。

## Technical Context

**Language/Version**: Bash、Python 3.9 以降の標準ライブラリ、GitHub Actions YAML。
**Primary Dependencies**: Git、gh、Swift / Xcode、ditto、lipo、codesign、PlistBuddy、shasum。
公式の checkout / upload-artifact / download-artifact / create-github-app-token Action を使う。
**Storage**: Git の要求・ノート、確認用 artifact（30日）、検証済み公開候補、GitHub のタグ・ドラフト。
**Testing**: unittest、一時 Git、API / gh stub、macOS 配布・公開回帰テスト、実 CI とローカル確認。
**Target Platform**: 判定・書き込みは Ubuntu、候補・検証・配布は macos-15 arm64 / Xcode 16.0。
ランナーでツールチェーンと arm64 を確認し、合わなければ停止する。
**Project Type**: 公開・配布の自動化。アプリの実行コード・UI は変更しない。
**Performance Goals**: 通常の master 更新で同期・配布の macOS job を動かさない。
**Constraints**: 2リポジトリ、単一コミット、公開除外、既存の署名・配布条件、PR への Secret 非提供。
**Scale/Scope**: 候補・同期・配布の3 workflow、共通 exporter とパッケージ処理、状態検証、回帰検証と運用文書。

## Constitution Check

| 原則 | 設計前・設計後 | 根拠 |
|---|---|---|
| I ローカル完結・プライバシー | 適合 | 通信は開発・配布ツールのみ。アプリへ追加しない |
| II 体感パフォーマンス | 適合 | 実行コードの変更なし。既存の同期前性能テストを維持 |
| III キーボード・アクセシビリティ | 対象外 | UI の変更なし |
| IV テスト必須 | 適合 | 同期・配布の異常系と候補の同等性を自動検証し、GUI 確認も残す |
| V シンプルさ | 適合 | 公開生成と package を共通化し、自動採番・強制同期・独自承認システムを追加しない |

新規の公式 App-token Action は独自の署名・トークン更新を避けるため必要（research R3）。
設計後も憲章違反はない。設計の承認前に実装しない。

## Project Structure

### Documentation (this feature)

spec / plan / tasks / research / data-model / quickstart / checklists/requirements と
contracts/release-workflow、背景の github-publishing-proposal をこの feature に置く。

### Source Code (repository root)

```text
.github/workflows/release-candidate.yml      # PR の確認用 ZIP、Secret なし
.github/workflows/sync-public.yml            # リリース PR のマージ後同期、復旧 dispatch
.github/workflows/macos-swift-ci.yml         # 新しい公開・配布回帰テストを組み込む
scripts/dev/export-public.sh                # source SHA → 公開候補、検査
scripts/dev/sync-public.py                  # 候補照合・PR / run 検証・同期、書き込みを分離
scripts/dev/publish.sh                      # 通常操作から外し、残すなら復旧 wrapper
scripts/dev/oss-workflows/release.yml        # 公開用の最終ビルドと draft
scripts/dev/oss-workflows/README.md          # 管理元の説明
scripts/dev/release-distribution.sh         # ローカル復旧、package へ委譲
scripts/release.py                          # 公開用の plan / draft
scripts/package-release.sh                  # 候補と最終配布で共通のアプリ ZIP 生成
scripts/dev/tests/test_check_release_workflow.py # 判定・API・候補同等性の異常系
scripts/dev/tests/test_check_public_sync.py  # 同期の状態遷移と公開保護
scripts/dev/tests/test_package_release.py    # macOS のパッケージ検査
scripts/dev/tests/test_release_distribution.py # 復旧 CLI 回帰
scripts/dev/tests/test_publish_folzio.py     # exporter と公開境界の回帰
release.example.json                        # 記入例。実際の要求は次のリリース PR で追加
release.json / release-notes/vX.Y.Z.md       # 保守者がリリース PR で管理
docs/releasing.md                           # 公開ガイド、要求・ZIP の取得・公開と復旧
docs_private/repository-and-release.md      # 日本語の運用と App 設定
specs/product/overview.md                   # 実装後、最後に反映
specs/product/contracts/{scripts,app-bundle}.md
```

**Structure Decision**: 公開ファイルだけで配布を動かす。dev の workflow は書き出さない。
公開されるコード・workflow のコメントは英語、書き出さない開発専用コードは日本語。
README の従来の入手先は同じ。変更する場合は日英を同時更新する。

## Phase 0: Research

[research.md](research.md) R1〜R6。過去のローカル publish 前提の案を、保守者の追加要望に合わせて置き換える。
同等性は commit SHA ではなく、変換後の公開 tree と version / build / toolchain で確認する。

## Phase 1: Design

[data-model.md](data-model.md) と [contracts/release-workflow.md](contracts/release-workflow.md) を契約とする。

1. リリース PR では現在の PR に対するテスト用 merge SHA を checkout し、公開用ツリーを生成する。
   要求と候補を検査し、共有 package で確認用 ZIP / SHA256SUMS / candidate.json を artifact にする。
2. 保守者が最新の artifact をローカルで確認して PR をマージする。
   PR の更新後は再生成した artifact を確認する。マージを確認後の進行操作とする。
3. master push の release.json 差分と merged PR を確認し、PR の最新 head に対する成功した candidate run を特定する。
   公開ツリーが一致しなければ、公開用へ書く前に停止する。master が先へ進んでも対象 SHA は読み替えない。
4. 公開候補で従来の同期前検査をすべて実行し、候補と digest を artifact で writer へ渡す。
5. writer だけが App Secret を受け取る。候補をコードとして実行せず、digest・source・base を検証し、
   公開用 main を親にしたコミットを作る。無差分は省略、古い候補と競合は停止、force は使わない。
6. App による公開用 push が公開用 release workflow を起動する。
   この workflow は公開用 SHA の git archive を隔離した source として package に渡す。
   通常テストと最終パッケージ検証に成功後、タグと2添付物のドラフトを作る。
7. 同名 Release は自動更新せず、タグのみ同一 SHA の場合に再利用する。復旧は元の run を再実行する。

PR と本番の source は同じ公開 tree とするが、最終 ZIP は公開済みコミットから再ビルドする。
署名や ZIP の時刻を含めたバイト列の一致を保証する設計ではない。

## 検証と導入順序

1. Cloud で check-all と同期・配布判断のテスト、macOS CI で build / test / package・公開回帰を確認する。
2. 実装 PR のマージ前に保守者が既存の起動スモークを行う。
3. 製品仕様の反映前に最新 master と ID を照合し、反映後は ID・形式を検査する。
   差分を示して承認後にコミットする。
4. 実装 PR のマージ後、App・Secret と保護規則を設定する。最初のリリース PR で実 candidate を取得し、
   保守者のローカル確認後にマージして、同期と公開用ビルドの連鎖を確かめる。
5. 公開側の実行・ZIP の確認は後続の導入検証として未完了で残し、確認まで Issue を Done・feature を凍結しない。

## Complexity Tracking

候補・同期・配布を分けるのは、公開前のローカル確認、2リポジトリ、PR への Secret 非提供に必要。
追加の状態 DB と専用承認 UI は作らず、Git tree・CI run・保守者による PR マージを使う。
