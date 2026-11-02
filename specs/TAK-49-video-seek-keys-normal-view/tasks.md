# Tasks: 通常表示でも動画を < / > で5秒戻す・送る

- [x] T001 `MainSplitViewController` に `videoSeekKeyMonitor` を追加し、通常表示のときだけ入れる・外す（`Sources/FolzioApp/App/MainSplitViewController.swift`）
- [x] T002 `<` / `>` の判定（ウインドウ番号・`NSTextView`・⌘⌥⌃・スライドショー中）を既存分岐と同じ規則で実装し、動画以外なら消費しない
- [x] T003 `shortcuts.condition.videoSeek` の ja・en の文言を更新する（`Sources/FolzioLocalization/Resources/*/Localizable.strings`）
- [x] T004 ローカライズの既存テストが通ることを確かめる。判定の条件に Core の純粋なロジックが生じた場合は `Tests/FolzioCoreTests` に追加する
- [x] T005 Cloud の検査（`check-no-network`・`check-readme-sync`・`check-english-comments`・`check-skill-sync`）を実行する
- [ ] T006 作業ブランチへ push し、CI（`swift build`・`swift test`）の結果を確認する（PR は保守者の依頼後）
- [ ] T007 保守者に起動スモーク（plan.md の「保守者のローカル」）を依頼する
- [x] T008 `git merge origin/master` の後、`specs/product/`（preview.md・window-layout.md・contracts）と `docs/usage*.md` に変更を反映し、ID の重複がないことを確かめる
