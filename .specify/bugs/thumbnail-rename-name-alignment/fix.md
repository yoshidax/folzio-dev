# Bug Fix: サムネイルの名前変更を終えるとファイル名が左寄せのままになる

- **Slug**: thumbnail-rename-name-alignment
- **Fixed**: 2026-11-01
- **Assessment**: ./assessment.md
- **Issue**: TAK-37
- **Status**: applied（ビルド・テストは未実行。macOS CI で確認する）

## Summary

`RenameTextField` で `textDidEndEditing(_:)` を override し、`super` の編集終了処理が済んだ後に `alignment = .center` を設定する。
入力中に引き継がれた左寄せが、編集終了時にセルへ書き戻されて、`endRenaming` が設定した `.center` を上書きする、という仮説に基づく。

## Changes

| File | Change | Notes |
|------|--------|-------|
| `Sources/FolzioApp/FileList/ThumbnailModeView.swift` | modified | `RenameTextField.textDidEndEditing` を追加。`isEditable == false`（`endRenaming` 実行後）のときだけ `.center` を設定する |
| `Tests/FolzioAppTests/ThumbnailRenameTests.swift` | added test | 3つの終了経路で、編集終了処理を通した後の配置を検証する |

`endRenaming`、名前の復元、コールバック、入力中の左寄せは変更していない。

## Diff Highlights

```swift
override func textDidEndEditing(_ notification: Notification) {
    super.textDidEndEditing(notification)
    if !isEditable {
        alignment = .center
    }
}
```

## Tests Added or Updated

- `ThumbnailRenameTests.alignmentAfterEditing(path:isFolder:)` — Return・Escape・フォーカス移動の3経路 × ファイル・フォルダで、
  入力中は `.left`、`window.makeFirstResponder(nil)` でフィールドエディタを外した後は `.center` で、名前が元のままであることを固定する。
  既存のテストは `doCommandBy` を直接呼ぶだけでフィールドエディタを外さないため、この症状を検出できなかった。

## Local Verification

- `swift build` / `swift test`: Cloud に Swift がないため未実行。macOS CI で確認する（CI は PR の作成時に動く）。
- `scripts/check-no-network.sh` → 通過
- `scripts/dev/check-english-comments.sh` → 通過
- `scripts/dev/check-skill-sync.sh` → 通過
- `scripts/check-readme-sync.sh master` → 通過
- GUI の確認は未実施。起動スモークは保守者に依頼する。

## Deviations from Assessment

- 回帰テストは配置（`alignment`）のみを検証した。assessment は `maximumNumberOfLines` と `lineBreakMode` の検証も挙げたが、
  実行できない状態で未検証の期待値を足すと、原因と無関係な失敗で CI を止めるおそれがあるため見送った。
  配置の修正が CI で確認できたら、必要に応じて足す。
- 原因の仮説は未検証のまま。新しいテストが変更前に失敗するかは、CI で確かめていない。
  変更前に失敗しない（修正の有無によらず通る）場合は、仮説が誤りなので、`$speckit-bug-assess` をやり直す。

## CI での確認と追加の修正

- 1回目（`df50965`、macOS CI）: 既存テストはすべて通過。新しい回帰テストだけが失敗した。
  Return・Escape の経路（ファイル・フォルダ）の4ケースで、編集を終えた後の `field.alignment` が `.left` のままだった
  （`ThumbnailRenameTests.swift:116`）。フォーカス移動の経路は、`textDidEndEditing` の override で `.center` になり通過した。
  回帰テストは、この不具合の症状を捉えている。ただし、修正前に失敗するかは確かめていない。
- 推測される理由: Return・Escape では、`endRenaming` の中での編集の終了が `textDidEndEditing` を経由せず、override が呼ばれない。
  書き戻しは `setRenamingAppearance(false)` の `.center` より後に起きる。
- 2回目の変更: `endRenaming` の最後（文字列とフォーカスの復元の後）にも `alignment = .center` を設定した。
  回帰テストには、Return・Escape で編集を終えた直後の配置の検証を足し、どの段階で `.left` になるかを切り分けられるようにした。
- 2回目でも同じテストが失敗する場合は、`makeFirstResponder(nil)` による切り離しの時点で書き戻されている可能性がある。
  その場合は、assessment の仮説を見直す。

## Follow-ups

- macOS CI で、新しいテストと既存の `ThumbnailRenameTests` が通ること。
- 保守者の GUI 確認: 確定・Escape・フォーカス移動のそれぞれで中央寄せに戻ること。入力中は左寄せのままであること。
