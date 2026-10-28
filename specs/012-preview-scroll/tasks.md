# Tasks: 拡大プレビューのスクロール

## Phase 1: 表示位置の計算

- [X] T001 [US21] `Tests/MediaViewerCoreTests/PreviewScrollLayoutTests.swift` に片軸・両軸・フィット・端・中心位置保持・無効寸法のテストを追加する。
- [X] T002 [US21] `Sources/MediaViewerCore/Layout/PreviewScrollLayout.swift` に画像サイズ、ビューポート、相対中心位置から表示位置と範囲を計算するロジックを実装し T001 を通す。

## Phase 2: プレビュー操作

- [X] T003 [US21] `Sources/MediaViewerApp/Preview/ImagePreviewView.swift` と `Sources/MediaViewerApp/Preview/PreviewViewController.swift` に重ね合わせ型の軸別バー、スクロール、位置保持・リセットを実装し、表示・アニメーション・遷移を維持する。
- [X] T004 [US21] `Sources/MediaViewerApp/Preview/ImagePreviewView.swift` と必要なキー処理に、プレビューのフォーカス中だけの ⌥方向キーを実装し、既存のファイル移動とツリー操作を維持する。
- [X] T005 [US21] `Tests/MediaViewerPerformanceTests/` の既存性能テストを実行し、スクロール・倍率変更が再デコードを引き起こさない設計を確認する。

## Phase 3: 検証

- [X] T006 `swift build`、`swift test`、`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/make-app.sh` を順に実行する。
- [X] T007 `specs/012-preview-scroll/quickstart.md` の GUI シナリオと3ペイン起動をユーザーが確認し、結果を `specs/012-preview-scroll/checklists/validation.md` に記録する。

依存順: T001 → T002 → T003 → T004 → T005 → T006 → T007。GUI の成功後に converge と product 反映を行う。
