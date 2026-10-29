# Tasks: Folzioへの改名

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**進め方**: 開発は順次実施する。設定移行は初回GUI起動前に必要であり、Packageとツールも同時に整合させる必要があるため、3ストーリーを1つの実装Phase内で依存順にまとめ、Phase末に検証・GUI確認・コミットする。

## Phase 1: 準備

- [X] T001 現在の参照と旧設定キーを棚卸しし、移行と残す履歴の境界を `specs/015-rename-to-folzio/quickstart.md` に確認する

## Phase 2: 実装・検証

### US1: Folzioとして閲覧する

- [X] T002 [US1] `Package.swift` と `Sources/MediaViewerCore/`、`Sources/MediaViewerLocalization/`、`Sources/MediaViewerApp/` を `Folzio`、`FolzioCore`、`FolzioLocalization`、`FolzioApp` に改名し、importとソース内の内部識別子を更新する
- [X] T003 [US1] `Tests/MediaViewerCoreTests/`、`Tests/MediaViewerPerformanceTests/`、`Sources/FixtureKit/` のターゲット名・import・ソースパス参照を新名称へ更新する
- [X] T004 [US1] `Sources/FolzioApp/App/MainMenu.swift`、`MainWindowController.swift`、`Sources/FolzioLocalization/Resources/` のアプリ名と両言語の終了メニューを Folzio に更新する
- [X] T005 [US1] `scripts/make-app.sh` の `.app`・バイナリ・Bundle ID・SwiftPM翻訳バンドル参照を変更し、実際のリソース構成と署名を検証できるようにする
- [X] T006 [US1] `scripts/check-english-comments.sh`、`scripts/check-no-archive-writes.sh`、`scripts/sdd-codex.py`、`scripts/tests/test_sdd_codex.py` の変更対象パスを更新する

### US2: 既存設定の引き継ぎ

- [X] T007 [US2] `scripts/migrate-folzio-settings.sh` を一度きりの明示的移行として実装し、`specs/015-rename-to-folzio/contracts/migration.md` の両ドメイン、バックアップ、上書き防止と失敗処理を満たす
- [X] T008 [US2] `scripts/tests/` に一時テストドメインを使う検証を追加し、成功、移行先あり、旧設定なし、失敗と再実行、旧データ・ペイン幅・ウインドウ位置の保持を確かめる
- [X] T009 [US2] `docs_private/` に各ドメインの初回起動前の移行・バックアップ・復旧手順と、旧パスのお気に入りの確認方法を記載する
- [X] T010 [US2] `.gitattributes` と `scripts/publish.sh` の検査を更新し、移行スクリプトと実設定・バックアップを公開物に含めない

### US3: Folzioとして開発・公開する

- [X] T011 [US3] `README.md` と `README.ja.md`、`docs/usage.md`・`docs/usage.ja.md`、`docs/development.md`・`docs/development.ja.md` を対になる形で改名する
- [X] T012 [US3] `AGENTS.md`、`docs_private/codex-speckit.md`、`docs_private/repository-and-release.md` の現行コマンドと開発・公開先を更新し、過去の記録を保持する
- [X] T013 [US3] `.specify/workflow-src/sdd-increment*.yml` と `.specify/workflows/sdd-increment/workflow.yml` の現行GUI指示を新アプリに変更し、既存ランナーの参照を整合させる
- [X] T014 [US3] `scripts/publish.sh` の既定先を `../folzio-oss` とし、公開先の `.vscode/` を同期と削除から保護する。`scripts/tests/` で一時公開先により保護を検証する
- [X] T015 [US3] Git管理外 `my_img_viewer.code-workspace` を `folzio.code-workspace` に改名し、移動前後で同じ明示的なworkspace名が使える設定とターゲット・起動タスク参照を更新する
- [X] T016 [US3] `docs_private/` に実ディレクトリ移動前の停止・移動先の確認・移動・IDE再起動・新パスでの再検証・結果記録の手順を用意する

### 検証ゲート

- [X] T017 `specs/015-rename-to-folzio/quickstart.md` の順に `swift build`、`swift test`、`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/check-english-comments.sh` を実行する
- [X] T018 `scripts/tests/` のPythonと移行・公開先保護の検証を実行する
- [X] T019 `scripts/make-app.sh` を実行し、`specs/015-rename-to-folzio/contracts/app-bundle.md` のplist・リソース・署名を確認する
- [X] T020 一時領域の `folzio` に作業ツリーをコピーし、`specs/015-rename-to-folzio/quickstart.md` に従いビルドと全テストを実行してパス非依存を確認する
- [X] T021 [MANUAL] 必要に応じ `docs_private/` の手順で旧 `.app` と `swift run` の設定をFolzio初回起動前にそれぞれ移行し、バックアップと結果を報告する
- [X] T022 [MANUAL] `open .build/Folzio.app` と `swift run FolzioApp` を順にユーザーが起動し、`specs/015-rename-to-folzio/quickstart.md` の3ペイン・日英・画像・動画・zip・各起動方法の設定復元を確認して結果を報告する
- [X] T023 T017〜T022の結果を `specs/015-rename-to-folzio/checklists/validation.md` に記録し、変更とfeatureの進捗をPhase単位でコミットする
- [ ] T024 `specs/015-rename-to-folzio/` と現在のコードのconvergeを行い、残作業があれば追加し、同じ検証ゲートを再実施する

## Dependencies & Execution Order

T001 → T002〜T016 → T017〜T020 → T021 → T022 → T023 → T024。T021は初回GUI起動前に行う。対象の旧設定がない場合は、T021を「移行不要」とユーザーが報告する。作業は同じワークツリーで直列に進める。

T024後はワークフローが product spec の反映・レビュー・凍結を行う。実ディレクトリの移動はその後、ユーザーが `quickstart.md` と `docs_private/` の運用手順で行い、新パスの実機確認とその結果は凍結済みfeatureを変更せず運用記録に残す。これが完了するまで改名全体は未完了と報告する。
