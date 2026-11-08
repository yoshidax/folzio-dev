# Implementation Plan: TAK-85 スワイプのジェスチャで履歴を戻る・進む

**Branch**: `claude/brave-knuth-vm9q9a` | **Date**: 2026-11-08 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-85-swipe-history-navigation/spec.md`

## Summary

`MainSplitViewController` に、スクロールと 3 本指のスワイプのイベントを見るローカルモニタを 1 つ置き（R3）、3 ペインの上で受け取ったものを判定する。
2 本指・Magic Mouse のスワイプは、システム設定（`NSEvent.isSwipeTrackingFromScrollEventsEnabled`）がオンのときだけ、AppKit の
`trackSwipeEvent` で追跡する（R1）。追跡を始めるかどうかは Core の `SwipeGestureTracker` が決める。1 回のスクロールの始まりに、ポインタの下のペインが
左右にスクロールできる余地（`HorizontalScrollRoom`）を記録し、その向きに余地がなければスワイプ、あれば横スクロールとする（R4・R5、FR-351）。
3 本指のスワイプは 1 回のイベントで届くため、受け取った時点で実行する（R2、EC-242）。
スワイプの間は、3 ペインの領域に重ねた子ウインドウに矢印を出し、量に合わせて大きさと濃さを変える（R6、FR-352）。
使えるかどうかは ⌘[ / ⌘] と同じ関数で判定し、成立したら既存の `goBack(_:)` / `goForward(_:)` を呼ぶ（R7、FR-112）。
ローカルモニタからの `trackSwipeEvent` と、向きの対応は実機でしか確かめられないため、実装の最初に保守者の macOS で確かめる（tasks.md の Phase 2）。

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: AppKit（`NSEvent` のスワイプの追跡、ローカルモニタ、子ウインドウ）。外部依存なし

**Storage**: なし（新しい設定・永続データを追加しない。スワイプの状態は一時的）

**Testing**: Swift Testing（`Tests/FolzioCoreTests`、`Tests/FolzioAppTests`）、macOS CI、保守者の GUI 確認（quickstart.md）

**Target Platform**: macOS 15 以降（`Package.swift` の `platforms`）

**Project Type**: Swift Package のデスクトップアプリ

**Performance Goals**: スクロールのイベントごとの判定は、ビューの階層を上へたどる数回の比較だけで、ファイルシステムを読まない。
矢印は指に遅れずに追従し、操作が 100ms 以上止まらない（SC-189）。移った後の表示は SC-029 のとおり

**Constraints**: ネットワーク API を使わない（憲章 原則 I）。判断ロジックは FolzioCore（AppKit を import しない）に置く。
AppKit UI の不変条件（AGENTS.md）を守り、`NSSplitView` に部品を加えない（R6）。履歴の記録・復元の規則（FR-107〜FR-113）を変えない

**Scale/Scope**: 3 ペインの上での、システム設定の「ページ間をスワイプ」のスワイプ。マウスのサイドボタン・ピンチ・履歴の一覧は対象外（A-44・A-64）

## Constitution Check

| 原則 | Phase 0 / Phase 1 の確認 |
|---|---|
| I ローカル完結 | 適合。通信なし。ファイルを変更しない |
| II 性能・UI スレッド | 適合。イベントごとの判定はメモリ上の比較だけで、デコード・列挙・ファイル操作をしない。移動は既存の `goBack`・`goForward` の経路（SC-029） |
| III キーボード・アクセシビリティ | 適合。スワイプは既存の ⌘[ / ⌘] と同じ操作の別の手段で、キーボードの手段はすでにある。矢印は飾りで、アクセシビリティの要素にしない。視差効果を減らす設定ではフェードを省く（R6） |
| IV テスト | 適合する計画。判定（状態遷移・余地・向き）を Core に置いて Swift Testing で網羅し、App の余地の読み取りもテストする。ジェスチャの実機の確認は quickstart.md。まだ実行していない |
| V YAGNI | 適合。新しい依存・設定項目・ショートカットを追加しない。スワイプのしきい値を独自に持たない（R1） |
| 仕様の管理 | 適合。変更はこの feature に記録し、検証後に `specs/product/` へ反映する |

設計の前後で違反はない。設計レビューの承認前に実装しない（docs_private/cloud-agent-workflow.md の「全体の流れ」）。

## Project Structure

### Documentation (this feature)

`spec.md`、`plan.md`、`research.md`、`data-model.md`、`contracts/swipe-history-navigation.md`、`quickstart.md`、`tasks.md`、`checklists/requirements.md`

### Source Code (repository root)

- `Sources/FolzioCore/History/SwipeNavigation.swift`（新規）: `HistoryDirection`、`HorizontalScrollRoom`、`ScrollSample`、`SwipeGestureTracker`、
  3 本指の `deltaX` の対応、矢印の表示の量（data-model.md）
- `Sources/FolzioCore/Layout/PreviewScrollLayout.swift`: 表示中の画像の左右の余地を返す（R5）
- `Sources/FolzioApp/App/SwipeNavigationController.swift`（新規）: ローカルモニタ、3 ペインの判定、余地の読み取り、`trackSwipeEvent` の呼び出し、
  矢印の子ウインドウ（R1〜R7）
- `Sources/FolzioApp/App/SwipeArrowOverlay.swift`（新規）: 矢印の子ウインドウとビュー（R6）
- `Sources/FolzioApp/App/MainSplitViewController.swift`: `SwipeNavigationController` を作り、使えるかどうかと `goBack`・`goForward` をつなぐ
- `Sources/FolzioApp/Preview/ImagePreviewView.swift`: `HorizontalScrollRoomProviding` に適合する（R5）
- `Tests/FolzioCoreTests/SwipeNavigationTests.swift`（新規）
- `Tests/FolzioCoreTests/PreviewScrollLayoutTests.swift`: 余地のテストを加える
- `Tests/FolzioAppTests/SwipeScrollRoomTests.swift`（新規）: `NSScrollView` と `ImagePreviewView` の余地の読み取り
- `docs/usage.md`・`docs/usage.ja.md`: 戻る・進むの手段とスワイプ（2 言語を同じコミットで。R9）
- 反映（PR の最後）: `specs/product/navigation-history.md`、`specs/product/contracts/keyboard-and-menus.md`

**Structure Decision**: 既存の FolzioCore（判断）と FolzioApp（描画と入力）の分け方に従う。履歴の手段の追加なので、Core は `History/` に、
App は戻る・進むの入口がある `App/` に置く。

## Complexity Tracking

違反はない。子ウインドウ（R6）は、`NSSplitView` に部品を加える単純な方法が AppKit UI の不変条件に触れるため選んだ。
