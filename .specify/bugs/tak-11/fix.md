# Bug Fix: 重複するフォルダ列挙の結果順序

- **Slug**: tak-11
- **Fixed**: 2026-11-01
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

通常フォルダ列挙の各要求に世代を割り当て、後続の列挙要求があれば古い成功・失敗を無視する。初回列挙と再読み込みも同じ世代を共有する。

## Changes

| File | Change | Notes |
|------|--------|-------|
| `Sources/FolzioCore/Browser/BrowserModel.swift` | modified | 列挙要求ごとの世代と結果・後続選択のガードを追加。既存の navigation generation は維持。 |
| `Tests/FolzioCoreTests/BrowserModelTests.swift` | modified | 完了順を制御できる lister と回帰テストを追加。 |

## Tests Added or Updated

- `overlappingReloads` — 逆順に完了する成功・失敗と一覧、選択、プレビューを検証。
- `reloadSupersedesInitialLoad` — 初回列挙より後に要求した再読み込みの結果を維持。
- 既存の `keepsOnlyLastFolder` は移動後の古い列挙結果を検証する。

## Local Verification

- 2026-11-03: `origin/master`（`28d72be`）をマージした後、macOS のローカルで確認した。
- `swift build`、`swift test`: pass（FolzioCoreTests 1032件ほか全件）。
- 回帰テスト2件を20回繰り返し実行: すべて pass。
- ネットワーク API、README 同期（`master`）、英語コメント、skill 同期、spec ID、`git diff --check`: pass。

## Deviations from Assessment

なし。

## Follow-ups

- 保守者が GUI の起動スモークを行う。
