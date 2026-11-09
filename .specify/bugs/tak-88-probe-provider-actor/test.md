# Bug Verification: TAK-88 自己ドラッグの provider

- **Slug**: tak-88-probe-provider-actor（fix から継続）
- **Tested**: 2026-11-09
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified（自己ドラッグの provider のクラッシュについて。T006 全体は未完了）

## Summary

修正前に新しい provider の回帰確認で SIGTRAP（終了133）を再現し、nonisolated を明示した修正案では成功した。
適用後の全自己検査も通常モードで成功した。2026-11-09 16:59 JST、保守者の実際の自己ドラッグ2件がクラッシュせず完了し、ログと実ファイルの中身を確認した。

## Checks Performed

| Check | Command / Action | Result | Notes |
|---|---|---|---|
| 修正前の再現 | 元のソースに checkPromiseProvider を追加した一時コピーの `--self-test` | fail as expected | 終了133。Objective-C 経由のキュー問い合わせをバックグラウンドから呼ぶ |
| 修正案の型検査 | `swiftc [-swift-version 6] -warnings-as-errors -typecheck` | pass | 通常モードと Swift 6。警告なし |
| 修正案の全自己検査 | `swift -swift-version 6 ... proposal.swift --self-test` | pass | 画像2種、TIFF、reader、provider |
| 適用後の全自己検査 | `swift -module-cache-path /tmp/folzio-tak88-swift-cache scripts/dev/pasteboard-probe.swift --self-test` | pass | 通常モード。画像2種、TIFF、reader、provider |
| 規約検査 | `scripts/dev/check-all.sh` | pass | 全件成功。ログ `/tmp/folzio-tak88-provider-fix/check-all.log` |
| 差分 | `git diff --check` | pass | 適用後 |
| GUI の自己ドラッグ | cat.png と logo.svg | pass | 保守者が実行。readerCount はそれぞれ1、719 / 188 bytes、0.041559 / 0.034727秒。file コマンドで JPEG / PNG の中身も確認 |
| 製品全体の build/test | 今回は再実行しない | not-run | 製品ソース・製品テストは未変更。前の修正時の結果と全体テストの未解決事項は `../tak-88-probe-actor-crash/test.md` を参照 |

## Output Excerpts

```
OK: cat.png（中身は JPEG）, declared=public.png
OK: logo.svg（中身は PNG）, declared=public.png
OK: 非圧縮 TIFF の生成。file promise の実際の受け渡しは macOS で手動確認してください。
OK: バックグラウンド reader の成功・受け取りエラー・情報取得エラー。通知は MainActor。
OK: provider のキュー・名前の Objective-C 呼び出しと専用キューの書き出し（2画像）。
```

## Residual Risks

- 今回確認した GUI はスクリプトの自己ドラッグ2件。ブラウザ・写真アプリの全形式の受け渡しを確認したわけではない。
- Safari JPEG の約束がキャンセルになる観測は、今回の修正で解消したとは扱わない。
- T006・T007 は未完了のまま。Phase 2 以降には進まない。

## Recommendation

自己ドラッグのクラッシュ修正は検証済み。続けて T006 の Safari JPEG のドラッグを再試行し、コピーの2つのボタンの結果も取得する。
ログは `/tmp/folzio-tak88-provider-fix/self-drag-success-20261109-1659.log` に複製して保存した。T006・T007 は未完了のまま残す。
