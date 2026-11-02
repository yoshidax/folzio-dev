# Bug Assessment: サムネイルの名前変更を終えるとファイル名が左寄せのままになる

- **Slug**: thumbnail-rename-name-alignment（Issue の内容から自動生成）
- **Created**: 2026-11-01
- **Source**: https://linear.app/takyoshida/issue/TAK-37/サムネイル形式で名前変更の入力を終えるとファイル名が左寄せのままになる
- **Issue**: TAK-37（In Progress）。host は `linear.app`、URL trust policy は `allowlisted`
- **Branch**: `claude/zen-hamilton-bn7osd`（Cloud が指定した作業ブランチ）
- **Assessed revision**: `22e0a3c86f3fefee84163ebdf792b16c1ed9e103`（`origin/master` と同じ。fetch 済み）
- **Verdict**: likely valid, needs reproduction（静的なコードの確認のみ。エージェントによる GUI 再現は未実施）
- **Severity**: low（表示の見た目だけの不具合。名前の値・ファイル操作には影響しない）

## Report (verbatim or summarized)

TAK-37 の本文を Linear MCP で取得した。コメントはなし。

サムネイル形式で、ファイル名の入力状態から確定またはキャンセルで通常状態に戻ると、ファイル名が左寄せで表示される。
変更前は中央寄せだった。期待は、通常状態に戻ったら変更前と同じ中央寄せで表示されること。
Issue の調査メモは、確定・Escape・フォーカス移動のどれで発生するか、セルの再構成で中央寄せに戻るかを未確認としている。

## Symptom

名前変更の入力状態を終えると、サムネイルのファイル名ラベルの配置が `.center` から `.left` になったままになる。
期待は、入力状態を終えたら元の中央寄せに戻ること。

## 仕様との照合

- `specs/product/file-list.md` **FR-013**: サムネイル形式では縮小画像とファイル名を表示する。**配置は定めていない**。
- `specs/product/` 全体で、ファイル名の配置（中央寄せ・左寄せ）を定める要件は見つからなかった（`中央`・`左寄せ`・`alignment` を検索）。
- **判定（要確認）**: AGENTS.md の分類では「仕様が定めていない」に当たりうる。ただし次の理由から、実装の不具合として扱う案を推す。
  - 通常状態の配置は `loadView`（`ThumbnailModeView.swift:105`）で `.center` と実装済みで、他のどの操作でも変わらない。
  - 名前変更の前後で同じ表示に戻ることは、FR-013 の「ファイル名を表示する」状態が名前変更の前後で保たれる前提と読める。
  - `endRenaming` が通常状態へ `.center` を設定しており、コードの意図は中央寄せで明らかである。
- 別案: 配置を要件として `specs/product/file-list.md` に足す変更として sdd-increment で扱う。小さい変更だが、仕様の追加になる。
- どちらで進めるかは保守者の確認事項（Open Questions）。

## Reproduction

1. ファイルリストをサムネイル形式にする。
2. ファイルまたはフォルダの名前変更を始めて入力状態にする（Return キー）。
3. 確定（Return）、キャンセル（Escape）、フォーカス移動（別の場所をクリック）のそれぞれで通常状態に戻す。
4. 名前の配置が左寄せになることを確認する。別フォルダへ移動して戻ったときに中央寄せへ戻るかも確認する。

上記は Issue の報告に基づく手順で、この Cloud セッションでは GUI 実行も `swift` の実行もしていない。
[NEEDS CLARIFICATION: 確定・Escape・フォーカス移動のすべてで発生するか。Issue も未確認としている。]

## Suspected Code Paths

- `Sources/FolzioApp/FileList/ThumbnailModeView.swift:226-240` — `setRenamingAppearance`。
  入力中は `alignment = .left`、通常状態は `.center`。
- 同 `:242-265` — `endRenaming`。249 行で `setRenamingAppearance(false)` を呼ぶ。この時点ではフィールドエディタがまだ
  `nameLabel` に接続されている。フォーカスを戻す `makeFirstResponder(collectionView)`（263 行）は、その後で実行される。
- 同 `:277-299` — 3つの終了経路。すべて `endRenaming` を呼ぶ。
  - Return: `control(_:textView:doCommandBy:)` が 285 行で `endRenaming(commit: true, restoreFocus: true)`。
  - Escape: 同 289 行で `endRenaming(commit: false, restoreFocus: true)`。
  - フォーカス移動: `controlTextDidEndEditing` が 297 行で `endRenaming(commit: true, restoreFocus: false)`。
    この通知は `NSTextField` の編集終了処理の途中で送られる。
- 同 `:63-77` — `RenameTextField`。配置を再設定するフックはない。
- 同 `:153-176` — `configure`。セルの再構成時は `alignment` を触らない。`loadView` 後に配置を設定するのは `loadView` と
  `setRenamingAppearance` だけ。
- `Tests/FolzioAppTests/ThumbnailRenameTests.swift` — 既存の名前変更のテスト。表示名とアクセシビリティ名は検証するが、
  配置は検証しない。編集を終える経路はフィールドエディタを残したまま `doCommandBy` を直接呼ぶため、実機のように
  `makeFirstResponder` による編集終了処理を通らない。

## Root Cause Hypothesis

**Confidence: medium-low（未検証）。**

3つの終了経路はいずれも、フィールドエディタが `nameLabel` に接続されたまま `alignment = .center` を設定している。
編集の終了処理（`NSTextField.textDidEndEditing` と `NSTextFieldCell` の編集終了）は、その後で実行される。
入力中にフィールドエディタが引き継いだ左寄せの段落スタイルが、この終了処理でセルへ書き戻されて `.center` を上書きする、
と考えると、Issue の症状（コードは `.center` を設定しているのに左寄せが残る）と整合する。

ただし、AppKit が実際に書き戻しているかどうかは、このセッションでは確認できない（Cloud に Swift がなく、GUI も起動できない）。
`endRenaming` を呼ぶ時点では `.center` になっているはずで、既存テストが配置を見ていないため、反証もできていない。
修正の前に、編集の終了処理を通した後で配置を調べる回帰テストを macOS CI で実行し、変更前に失敗することを確かめる。

## Proposed Remediation

**Preferred**: `RenameTextField` に、編集が終わった後に通常状態の配置を再設定する処理を足す。
`textDidEndEditing(_:)` を override して `super` を呼んだ後、編集中でなければ `alignment = .center` を設定する。
`NSTextField` の編集終了処理（セルへの書き戻しを含む）が済んだ後に実行されるので、3つの終了経路のどれでも最後に中央寄せになる。
`endRenaming` の既存の流れ・名前の復元・コールバックは変更しない。

**Alternatives**:

- `endRenaming` で先にフィールドエディタを外してから（`makeFirstResponder` を先に呼んでから）外観を戻す。
  フォーカス移動経路は通知の途中で呼ばれるため、フォーカスの復元順序が変わり、TAK-13 で直した名前の復元と干渉しうる。変更範囲が広い。
- `Task { @MainActor in nameLabel.alignment = .center }` で次のターンに再設定する。順序への依存は消えるが、
  1フレーム左寄せが見える可能性があり、タイミングに頼る。

**Files likely to change**:

- `Sources/FolzioApp/FileList/ThumbnailModeView.swift`
- `Tests/FolzioAppTests/ThumbnailRenameTests.swift`
- `.specify/bugs/thumbnail-rename-name-alignment/fix.md`、`test.md`

**Tests to add or update**（`Tests/FolzioAppTests/ThumbnailRenameTests.swift`）:

- 確定・Escape・フォーカス移動の3経路で、編集を終えた後に `field.alignment == .center` となる回帰テスト。
  フィールドエディタを実際に外すため、`window.makeFirstResponder(nil)` などで編集終了処理を通した後に検証する。
  変更前に失敗し、変更後に通ることを macOS CI で確かめる。
- 名前変更の開始前と終了後で、配置・`maximumNumberOfLines`・`lineBreakMode` が同じであることを併せて検証する。

## Risks & Considerations

- 入力中は左寄せのままにする（長い名前で先頭から編集できるようにするため）。通常状態の配置だけを戻す。
- 名前変更が成功して `configure` が呼ばれるセルの再構成にも影響しないこと（TAK-13 の挙動の維持）を、既存テストで確認する。
- 本 assessment では、ソース変更・回帰テスト・CI・GUI 検証は実施していない。
- Cloud では `swift build` / `swift test` を実行できない。ビルドとテストは macOS の CI で確認し、CI は PR の作成時にだけ動く。
  PR は保守者の依頼があったときだけ作る（AGENTS.md「Cloud Agent の作業」）。起動スモークは保守者に依頼する。
- `.specify/extensions.yml` に `before_bug_assess` / `after_bug_assess` の登録はない。

## Open Questions

- この不具合を、実装の不具合（bug fix）として扱ってよいか。それとも配置を `specs/product/file-list.md` の要件に足す変更
  （sdd-increment）として扱うか。FR-013 は配置を定めていない。
- [NEEDS CLARIFICATION: 確定・Escape・フォーカス移動のすべてで発生するか。セルの再構成で中央寄せに戻るか。]
