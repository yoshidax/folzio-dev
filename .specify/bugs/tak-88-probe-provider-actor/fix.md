# Bug Fix: TAK-88 の provider のキュー問い合わせ

- **Slug**: tak-88-probe-provider-actor（assessment から継続）
- **Fixed**: 2026-11-09
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

`SamplePromise.operationQueue(for:)` に nonisolated を明示し、不変のキューの問い合わせに UI の actor 条件を要求しない。

## Changes

| File | Change | Notes |
|---|---|---|
| `scripts/dev/pasteboard-probe.swift` | modified | nonisolated と `checkPromiseProvider` の自己検査 |

## Tests Added or Updated

`checkPromiseProvider` は2つの画像について、バックグラウンドで Objective-C のキュー・名前の入口を呼び、返された専用キューで書き出す。出力の中身は ImageIO で確認する。

## Local Verification

- 修正前に新しい回帰確認を追加した一時コピー: SIGTRAP、終了コード133。
- nonisolated の修正を含む同じ回帰確認: 成功。
- 修正案の全自己検査: 画像2種、非圧縮 TIFF、reader、provider が成功。
- 修正案の通常モード / Swift 6 型検査: 警告なしで成功。
- 実際の GUI の自己ドラッグは確認待ち。

## Deviations from Assessment

なし。先の reader の修正は維持し、書き出し側の別の入口を修正する。

## Follow-ups

自己ドラッグ2件を保守者に再確認してもらう。T006・T007 は未チェックのまま残す。
