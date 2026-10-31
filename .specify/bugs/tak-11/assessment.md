# Bug Assessment: 同じフォルダの再読み込み結果が逆順で反映される

- **Slug**: tak-11
- **Created**: 2026-11-01
- **Source**: [TAK-11](https://linear.app/takyoshida/issue/TAK-11/同じフォルダの再読み込みが重なると古い一覧が最新結果を上書きする)
- **Verdict**: likely valid, needs reproduction
- **Severity**: medium

## Report (summarized)

同じフォルダの列挙が重なり、後の要求が先に完了すると、遅れた以前の結果が最新の一覧を上書きする可能性がある。ファイル操作後の更新とファイルシステム変更通知が重なる場合などが対象。通常操作での発生頻度は未確認。

## Symptom

以前の一覧やエラーが最新の再読み込み結果の後に反映され、一覧・選択・プレビューが古い状態になる。後の要求が反映された後は以前の結果を無視するべきである。

## 仕様との照合

**判定: 実装が仕様に反している可能性が高い。** `specs/product/file-operations.md` FR-027 は操作結果の即時反映、`specs/product/overview.md` FR-042・EC-13 は外部変更の反映と消えたプレビューの消去を要求する。`specs/product/preview.md` FR-125・EC-69 はスライドショーが最新一覧に従うことを要求し、EC-70 は遅れた以前の読み込みによる表示の上書きを禁止する。逆順完了で古い結果が残る実装はこれらと整合しない。

## Reproduction

1. 同一フォルダに対して再読み込みを開始し、列挙結果を保留する。
2. ファイル構成の異なる後続の再読み込みを開始し、先に完了させる。
3. 最初の列挙を完了させ、最新の一覧・選択・プレビューが維持されるか確認する。以前のエラーについても同様に確認する。

[NEEDS CLARIFICATION: 通常操作での発生頻度。] この環境では再現テストおよび GUI 確認を実施していない。

## Suspected Code Paths

- `Sources/FolzioCore/Browser/BrowserModel.swift:732` — `reloadCurrentFolder` は列挙前に navigation generation を取得し、成功と失敗の両方で同じ値とフォルダを検査するが、再読み込みごとの識別がない。
- `Sources/FolzioCore/Browser/BrowserModel.swift:943` — `resetForNavigation` は移動時に generation を進めるため、同一フォルダの重複要求は区別しない。
- `Sources/FolzioCore/Browser/BrowserModel.swift:1068` — 初回の `loadFolder` も同一 navigation generation を用いる。初回読み込みと再読み込みが重なる場合も検討する必要がある。
- `Sources/FolzioCore/Browser/BrowserModel.swift:791` — ファイルシステム通知は再読み込みを呼ぶ。

## Root Cause Hypothesis

**Confidence: high (static analysis)**。`await lister.mediaFiles` の間に MainActor は別の再読み込みを開始できる。両者が同じ generation と folder を保持するため、新しい要求が先に結果を適用した後も古い要求のガードが通り、成功または失敗を適用できる。実行による再現は未確認。

## Proposed Remediation

**Preferred**: 通常フォルダ列挙の要求順を識別し、後続要求に置き換えられた成功・失敗のどちらも状態を変更しないようにする。初回 `loadFolder` と再読み込みの競合や移動・検索・zip への遷移も含め、既存の navigation 判定との関係を確認する。

**Files likely to change**:
- `Sources/FolzioCore/Browser/BrowserModel.swift`
- `Tests/FolzioCoreTests/BrowserModelTests.swift` または関連するテストファイル

**Tests to add or update**:
- 制御可能な lister で同一フォルダの二つの要求を逆順に完了させ、古い成功が一覧・選択・プレビューを上書きしないこと。
- 古い失敗が新しい成功を消去せず、古い成功が新しい失敗を上書きしないこと。
- 初回読み込みと再読み込み、移動後の遅延結果を検証する。

## Risks & Considerations

- 初回読み込みの状態、履歴通知、検索や zip への遷移を損なわないようにする。
- Swift ビルド・テストは macOS CI、GUI 確認は保守者の環境で必要。

## Open Questions

- [NEEDS CLARIFICATION: 実操作での発生頻度。]
