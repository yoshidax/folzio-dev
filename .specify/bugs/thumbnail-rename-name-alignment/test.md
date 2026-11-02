# Bug Verification: サムネイルの名前変更を終えるとファイル名が左寄せのままになる

- **Slug**: thumbnail-rename-name-alignment
- **Tested**: 2026-11-01
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Issue**: TAK-37
- **Result**: verified

## Summary

macOS CI で、ビルドと全テストが成功した（`5edf692`）。新しい回帰テストは、確定・Escape・フォーカス移動の3経路で通った。
保守者のローカルでの GUI 確認では、問題がなかったと報告を受けた。症状は再現しなくなった。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | 保守者がローカルの GUI で、サムネイル形式の名前変更を確定・Escape・フォーカス移動で終える | pass | 保守者の報告による（「問題ありませんでした」）。確認したビルドと各経路の詳細は聞き取っていない |
| New / updated tests | macOS CI: `ThumbnailRenameTests.alignmentAfterEditing` | pass | 3経路 × ファイル・フォルダ。run 55（`workflow_dispatch`） |
| Regression suite | macOS CI: `swift build` / `swift test`（918 件程度） | pass | 既存の `ThumbnailRenameTests` を含む。run 55 は `5edf692` で成功 |
| Cloud の検証ゲート | `scripts/check-no-network.sh`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`、`scripts/check-readme-sync.sh master` | pass | Cloud で実行 |
| Lint / type-check | — | not-run | リポジトリに専用の設定はない。型チェックは CI のビルドに含まれる |

## Output Excerpts

- 1回目の CI（`df50965`、override のみ）: Return・Escape の4ケースで `Expectation failed: (field.alignment → .left) == (.center)`
  （`ThumbnailRenameTests.swift:116`）。他のテストは通過。
- 2回目の CI（`5edf692`、`endRenaming` の最後の設定を追加）: 失敗なし、`Build and test (macOS 15 / arm64)` は success。

## Residual Risks

- 修正前（変更なし）のコードで、新しいテストが失敗するかは確かめていない。1回目の失敗は override だけを入れた状態のもの。
- `endRenaming` の最後の設定と override のどちらが効いたかは、単独では切り分けていない。両方を残している。
- 原因は仮説のままである（AppKit が編集終了時に左寄せを書き戻す、という推測）。症状の解消は CI と GUI で確認したが、メカニズムは未検証。
- GUI 確認は保守者の報告による。確認したビルドの SHA と、各終了経路の個別の結果は記録していない。
- `maximumNumberOfLines`・`lineBreakMode` は回帰テストの対象にしていない（fix.md の「Deviations from Assessment」）。GUI では問題の報告はない。

## Recommendation

修正は検証済み。PR（yoshidax/folzio-dev#27）はマージ可能な状態である。マージは保守者が行い、マージ後に依頼があれば Linear の TAK-37 を `Done` にする。
原因の仮説は未検証のまま残るため、再発した場合は assess からやり直す。
