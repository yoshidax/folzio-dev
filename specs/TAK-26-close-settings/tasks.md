# Tasks: メインウインドウと設定ウインドウの終了連動

**Input**: `specs/TAK-26-close-settings/` の仕様・設計。

**Status**: 2026-10-31 に保守者が設計を承認。実装済み。Cloud の4検査と差分検査は通過。保守者承認により agent/tak-26-close-settings へ改名し、実装コミット bb0d0f0 を origin に push 済み。macOS の build/test・GUI 確認、依頼後の PR と CI、product 反映は未完了。

## Phase 1: Setup

- [x] T001 最新 origin/master を work へ取り込み、specs/TAK-26-close-settings/spec.md に TAK-26 と既存仕様の参照・追加要件を記録する。
- [x] T002 specs/TAK-26-close-settings/plan.md、research.md、data-model.md、contracts/window-lifecycle.md、quickstart.md を作成する。

## Phase 2: Foundational

- [x] T003 specs/TAK-26-close-settings/plan.md と spec.md の設計レビュー承認を保守者から受ける。承認前にソースを実装しない。
- [x] T004 AppKit の文書または SDK ヘッダーで NSWindow.willCloseNotification と NSWindowController.close() の存在と動作を確認し、specs/TAK-26-close-settings/quickstart.md に確認元を記録する。

## Phase 3: User Story 1 — 設定だけを残さず閲覧を終了する (P1 / MVP)

**Goal**: FR-200〜203、EC-136〜138、A-116 を満たす一方向の終了連動。

**Independent Test**: quickstart.md の全8ケース。SC-096・097 の合否を記録する。

- [x] T005 [US1] Sources/FolzioApp/App/AppDelegate.swift でメイン window に限定した終了通知を showWindow 前に登録し、通知元を確認して保持済み設定コントローラを close() する。設定未生成なら生成しない（FR-200・201、EC-136）。
- [x] T006 [US1] Sources/FolzioApp/App/AppDelegate.swift の通知範囲と既存の最終 window 終了判定、Sources/FolzioApp/App/MainSplitViewController.swift の停止処理、Sources/FolzioApp/Settings/SettingsWindowController.swift の編集確定処理を静的レビューし、設定だけ閉じる操作・再表示を維持する（FR-202・203、EC-137・138、A-116）。
- [x] T007 [US1] scripts/check-no-network.sh、scripts/check-readme-sync.sh master、scripts/dev/check-english-comments.sh、scripts/dev/tests/test_check_git_push.py の4検査を実行し、specs/TAK-26-close-settings/quickstart.md に結果を記録する。
- [ ] T008 [US1] 保守者に specs/TAK-26-close-settings/quickstart.md の全 GUI ケースと最新 Swift の build/test を依頼し、結果を同ファイルに記録する。実施されるまで未チェックを保つ（SC-096・097）。

## Phase 4: Polish & Delivery

- [x] T009 specs/TAK-26-close-settings/plan.md に記載した work の命名制限について保守者に確認し、許可された作業ブランチ名でコミット・push する。PR は依頼があったときだけ作成する。
- [ ] T010 PR 作成後に .github/workflows/macos-swift-ci.yml の macOS build/test 結果を確認し、specs/TAK-26-close-settings/quickstart.md に記録する。失敗時はログを読んで修正する。
- [ ] T011 実装・検証後、PR 最後に最新 master を取り込み、ID の衝突を確認して specs/product/contracts/settings.md に spec.md の反映表の項目を反映する。差分の保守者承認後にコミットし、specs/TAK-26-close-settings/spec.md を凍結する。

## Dependencies & Execution Order

T001 → T002 → T003 → T004 → T005 → T006 → T007。
T007 後に T008 と T009。PR 作成の依頼後 T010。T008・T010 成功後に T011。
GUI・CI の完了を Cloud の静的検査で代替しない。

## Parallel Opportunities

US1 の独立した並列実装はない。Cloud の4検査は個別実行できる。サブエージェントは使わない。

## Implementation Strategy

US1 が全体の MVP。設計承認後、AppDelegate の最小変更を実装し、既存終了処理と設定編集を確認してから配布へ進める。新しい抽象化・設定・テストターゲットは追加しない。
