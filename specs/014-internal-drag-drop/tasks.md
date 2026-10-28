# Tasks: アプリ内ドラッグによる整理

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[contracts/drag-drop.md](contracts/drag-drop.md)

## Phase 1: US23 — 実装と検証

**独立検証**: 両ペインの全ドラッグ元・宛先の移動と Option コピー、無効条件、確認・衝突・結果同期を自動テストと実機操作で確認する。

- [X] T001 [US23] `Sources/MediaViewerCore/Operations/` と `Tests/MediaViewerCoreTests/` に集合全体の妥当性判定とテストを追加する。同じ親、自己・配下、シンボリックリンク、複数選択、コピー、消失を検証する。
- [X] T011 [US23] `Sources/MediaViewerCore/Operations/InternalDropValidation.swift` と `Tests/MediaViewerCoreTests/InternalDropValidationTests.swift` に選択内のフォルダと配下のファイル・フォルダの重複、同一性・シンボリックリンクを含む移動／コピー全体の拒否と回帰テストを追加する（T001 完了後の追加要件）。
- [X] T002 [US23] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` に通常フォルダのドラッグ元と内部セッションの認識、宛先の判定・ハイライトを実装する。お気に入りとルートの役割を区別し外部経路を保つ。
- [X] T003 [US23] `Sources/MediaViewerApp/FileList/ListModeView.swift` と `ThumbnailModeView.swift` に検索結果のフォルダを含む選択集合固定・フォルダ宛先、ハイライト、ドロップを実装し、`FileListViewController.swift` で共通処理をつなぐ。
- [X] T004 [US23] `Sources/MediaViewerApp/Operations/FileOperationCoordinator.swift` と `Sources/MediaViewerCore/Operations/FileOperationService.swift` で実行前再検証と既存の確認・衝突・エラーを統合し、キャンセル・部分成功・権限エラー・衝突・ドラッグ以外のコピーも含む同一元への置き換え拒否のテストを `Tests/MediaViewerCoreTests/` に追加する。
- [X] T005 [US23] `Sources/MediaViewerCore/Browser/BrowserModel.swift`、`Sources/MediaViewerApp/Tree/`、`Sources/MediaViewerApp/Operations/` で結果をツリー・選択・プレビュー・履歴・お気に入り・検索中の結果に同期し、通常・検索中の祖先移動と検索継続・表示中の祖先移動・部分成功の回帰テストを `Tests/MediaViewerCoreTests/` に追加する。
- [X] T006 [US23] `README.md` と `README.ja.md` に同じ内容でアプリ内ドラッグの対象・Option コピーと制限を記述する。
- [X] T007 [US23] `swift build`、`swift test`、`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/make-app.sh` をこの順に実行し結果を記録する。
- [X] T008 [MANUAL] [US23] ユーザーが `open .build/MediaViewer.app` で起動し、[quickstart.md](quickstart.md) の全シナリオと3ペインを確認し、実行日・OS・ビルド・各項目の結果を報告する。
- [X] T009 [US23] ユーザーの T008 報告を `specs/014-internal-drag-drop/checklists/validation.md` に記録し、成功した手動タスクのみチェックする。失敗は修正して T007・T008 を再実施する。
- [X] T010 [US23] 自動検証と手動検証が成功した後、今回の Phase の変更と検証記録をコミットする。

## Dependencies & Execution Order

T001 → T011 → T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 → T010。順次実施し、GUI をエージェントが起動しない。検証後 converge で不足を調べる。最終検証と最終起動スモークはワークフローの別ゲートとして実施する。
