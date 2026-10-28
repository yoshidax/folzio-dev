# Tasks: スライドショーの背景色

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md)

## Phase 1: User Story 1 - 黒い背景で鑑賞する (P1)

**Independent Test**: `quickstart.md` の画像・動画・切り替えと開始・終了の各ケースを確認する。

- [X] T001 [US1] `Sources/MediaViewerApp/Preview/PreviewViewController.swift` と `Sources/MediaViewerApp/Preview/ImagePreviewView.swift` の描画階層を調べ、スライドショー時のみ余白・透明部分が黒になり状態表示を読めるようにする（FR-160）。
- [X] T002 [US1] `Sources/MediaViewerApp/Preview/SlideshowTransitionOverlayView.swift` の切り替え中の背景を黒にする（FR-160）。
- [X] T003 [US1] `Sources/MediaViewerApp/App/MainSplitViewController.swift` の開始・通常復帰・全画面復帰・破棄の各経路でプレビューの背景状態を連携し、終了時に元へ戻す（FR-161、EC-120）。
- [X] T004 [US1] 新たな Core の判断ロジックが必要になった場合は `Tests/MediaViewerCoreTests/` に正常系・異常系のテストを追加する。

## Phase 2: 検証

- [X] T005 `specs/013-slideshow-black-background/quickstart.md` に従い `swift build`、`swift test`、ネットワーク・README 同期チェックを順に実行し、`scripts/make-app.sh` でアプリを作る。
- [X] T006 `specs/013-slideshow-black-background/quickstart.md` の GUI シナリオと3ペイン起動をユーザーが確認し、結果を `specs/013-slideshow-black-background/checklists/validation.md` に記録する。

## Dependencies & Execution Order

T001〜T003 は同じ表示状態に関わるため順次実装する。T004 は必要時のみ。T005 は実装後、T006 は T005 後。GUI 検証まで完了後に converge し、仕様の正本への反映をレビューする。
