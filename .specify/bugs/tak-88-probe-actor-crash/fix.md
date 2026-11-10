# Bug Fix: TAK-88 確認スクリプトの actor 隔離

- **Slug**: tak-88-probe-actor-crash（assessment の文脈から継続）
- **Fixed**: 2026-11-09
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

reader の非隔離と Sendable を明示し、バックグラウンドでファイルの情報を取得してから MainActor へ通知する。
起動時の MainActor を明示し、ログを即時出力する。

## Changes

| File | Change | Notes |
|---|---|---|
| `scripts/dev/pasteboard-probe.swift` | modified | `makePromiseReader`、起動部、ログ、回帰確認 |

## Tests Added or Updated

- `checkPromiseReader`: 実運用の reader を OperationQueue から3回呼ぶ。成功・受け取りエラー・情報取得エラーを確認し、情報取得はバックグラウンド、通知は MainActor であることを検査する。

## Local Verification

- 適用前の修正案を通常モード・Swift 6 の両方で `swiftc -warnings-as-errors -typecheck`: 成功。
- reader の回帰確認を両モードで実行: 成功。
- 適用後の全自己検査と必要な検査は `test.md` へ記録する。
- 実際の GUI ドラッグは未確認。

## Deviations from Assessment

なし。

## Follow-ups

- 保守者が JPEG のドラッグを再確認する。T006・T007 は未完了のまま残す。
