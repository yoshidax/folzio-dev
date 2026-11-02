# Implementation Plan: 通常表示でも動画を < / > で5秒戻す・送る

**Feature**: [spec.md](spec.md) | **Issue**: [TAK-49](https://linear.app/takyoshida/issue/TAK-49)

## 現状（根拠）

- `MainSplitViewController.installHiddenListKeyMonitor` は、`navigatesHiddenFileList`（ファイルリストが隠れ、プレビューが見える。
  プレビューのみ表示とフルスクリーン）になったときだけ `NSEvent` のローカルモニタを入れる（`MainSplitViewController.swift:671`・`696`・`827`）。
- `handleHiddenListKey` が `.less` / `.greater` で `previewViewController.seekVideo(by:)`（`PreviewViewController.swift:110`）を呼ぶ。
  同じガード（`:856-861`）が、ウインドウ番号の一致・`NSTextView` が first responder でないことを確かめる。
- 通常表示ではモニタ自体がないため、`<` / `>` はどこにも届かない（Issue の記述と一致）。

## 設計

1. `MainSplitViewController` に、`<` / `>` だけを扱う別のローカルモニタ（`videoSeekKeyMonitor`）を足す。
   - 理由: 既存のモニタは矢印キーとスライドショーのキーも扱う。通常表示でそれを入れると、矢印キー・スライドショーの経路が変わる。別のモニタなら影響は `<` / `>` に限られる。
   - 入れる時期: `appliedPresentation.showsAllPanes`（通常表示）になったとき。外すのは、通常表示を出たとき。既存モニタと同時には存在しない（`navigatesHiddenFileList` と `showsAllPanes` は排他）。
2. キーの判定は、既存の `.less` / `.greater` の分岐と同じ規則に揃える（ウインドウ番号一致、`NSTextView` でない、⌘・⌥・⌃ なし）。
   判定を `HiddenListKeyPress` から共通の純粋関数に切り出し、Core の `FolzioCoreTests` で表を検証する案は、判定が AppKit の型に依存するため採らない。
   代わりに、判定に使う条件（修飾キー集合）を1か所の定数にして重複を避ける。
3. 動画以外を表示中は `seekVideo(by:)` が `false` を返す。このときはキーを消費せずにファイルリストへ渡す（US5-AS15）。
4. スライドショー実行中は通常表示にならない（全画面）ため、競合しない。念のため `slideshowCoordinator.isActive` のときは何もしない。
5. 文言: `shortcuts.condition.videoSeek`（ja・en）を「動画を表示中に使えます。」に更新する。

## 仕様・文書の更新（実装と検証の後、PR の最後に反映）

- `specs/product/preview.md`: FR-033 の `<` / `>` の記述、FR-269・SC-133・A-164・US5-AS13〜17・EC-188〜190 を追加
- `specs/product/window-layout.md`: FR-093 の「同じく `<`・`>` キー」の記述
- `specs/product/contracts/keyboard-and-menus.md`: videoSeek 行（105）、プレビューのみ表示の表（331）、プレビューの表（565）
- `docs/usage.ja.md`（と英語版）、必要なら README の記述

## 検証

- Cloud: `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`
- CI: `swift build`、`swift test`（キー判定は AppKit 依存のため、単体テストは文言キーの存在と ja/en の整合を既存のローカライズテストで確認）
- 保守者のローカル: 3ペイン表示で動画を選び、ファイルリスト・プレビューのそれぞれにフォーカスして `<` / `>`、検索欄に `<` を入力、画像表示中に `<` を押す
