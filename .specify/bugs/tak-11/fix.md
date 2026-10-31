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

- ネットワーク API、英語コメント、skill 同期、git push 検査: pass。
- README 同期: `scripts/check-readme-sync.sh origin/master` pass。ローカルの `master` が存在しないため代替参照を使用。
- `git diff --check`: pass。
- Swift build/test および GUI: 未実施。Cloud では macOS CI と保守者による確認が必要。

## Deviations from Assessment

なし。

## Follow-ups

- macOS CI でビルドと回帰テストを実行し、保守者が GUI 起動スモークを行う。
