# Bug Verification: リスト形式の行頭の縮小画像が縦横比を保たずに正方形へ引き伸ばされる

- **Slug**: tak-127
- **Tested**: 2026-11-26
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

自動テストでは、行頭のアイコンが縦横比を保った大きさになり、16:9 の代表フレームのバッジが描かれたフレームの内側に収まることを確かめた。build・全テスト・`check-all.sh`・アプリの組み立ては通った。保守者が起動スモークと GUI での再現手順を行い、問題がないことを確かめた（2026-11-26）。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (pre-fix, automated) | `swift test --filter "ListIconImageTests\|FitCalculatorTests"`（修正前の描き方のまま） | fail（期待どおり） | fix のときに実施。1:1 以外の 4 件の大きさと、バッジの位置の 1 件が失敗した |
| New / updated tests | `swift test --filter "ListIconImageTests\|FitCalculatorTests\|VideoBadge"` | pass | fix のときに実施。33 件 |
| Gate 1: build | `swift build` | pass | |
| Gate 2: tests | `swift test` | pass | 1189 件（130 suites）と性能テスト 28 件。fix のときに一度揺れた性能テストも今回は通った |
| Gate 3: checks | `scripts/dev/check-all.sh` | pass | all checks passed |
| Gate 4: launch smoke | `scripts/make-app.sh` → `open .build/Folzio.app` | pass | `make-app.sh` は成功。保守者が起動して 3 ペインの表示を確認した |
| Reproduction (post-fix, GUI) | assessment の再現手順をリスト形式で行う | pass | 保守者が確認した。横長・縦長の画像と動画の行頭の縮小画像が歪まず中央に描かれ、横長の動画のバッジが描かれたフレームの右下に収まり、大きさにも問題がない |

## Output Excerpts

```
Build complete! (0.83秒)
✔ Test run with 28 tests in 1 suite passed after 41.339 seconds.
✔ Test run with 1189 tests in 130 suites passed after 33.311 seconds.
all checks passed
created .build/Folzio.app
```

## Residual Risks

- 自動テストは、行頭のアイコンにする関数（`ListModeView.listIconImage(from:pointSize:)`）とバッジ付きの画像ビューを個別に試している。表の行のセルに実際に設定される画像は、GUI でだけ確かめた
- 横長の動画では、バッジの直径が 8pt から約 4.5pt に縮む（EC-286 の意図どおり）。保守者は GUI で大きさに問題がないことを確かめた
- 性能テスト「Decodes a 24 MP JPEG within 0.5 seconds」は、fix のときに全テストの実行中に一度だけ 0.61 秒で失敗した。今回の変更とは関係しないが、負荷によって揺れることがある

## Recommendation

閉じてよい。自動テストと、保守者による起動スモーク・GUI での再現手順の確認で、症状が出なくなったことを確かめた。FR-048 に「縦横比を保つ」と明記するかは、assessment の Open Questions のとおり保守者の判断に残る。
