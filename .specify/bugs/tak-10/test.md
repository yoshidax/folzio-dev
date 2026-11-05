# Bug Verification: 連番の整数オーバーフロー

- **Slug**: tak-10
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: partial

## Checks Performed

| Check | Result | Notes |
|---|---|---|
| 修正後の GUI | 保守者から問題なしと報告 | 複製、「両方残す」と起動スモークを確認済み。修正前の再現は未確認。 |
| ローカルのビルド・テスト | 保守者から成功と報告 | 詳細な実行結果は未提示。 |
| macOS CI | 部分成功 | [run 41955014790](https://github.com/yoshidax/folzio-dev/actions/runs/41955014790)、commit `9f37375`: ビルドと通常テスト 1,056 件成功。性能テスト 27 件中 1 件失敗。 |
| 性能テスト | fail | スライドショー候補抽出が 0.20199225 秒で、0.2 秒未満の基準を超過。今回の変更との因果関係は未確認。 |
| macOS CI（2 回目） | 部分成功 | [run 41970101570](https://github.com/yoshidax/folzio-dev/actions/runs/41970101570)、commit `9f37375`: ビルドと通常テスト 1,056 件成功。性能テスト 27 件中 1 件失敗（フォルダ改名後の検索結果反映の中央値 0.103758125 秒、基準 0.1 秒未満）。ジョブ全体は成功と表示される。 |
| レビュー後のコード・名前長テスト | 未実行 | 上記 CI はレビュー対応前の commit に対するもの。 |

## Residual Risks

性能テストの失敗と、レビュー後のコード・追加テストの macOS での検証が残る。修正前の実行再現は確認できていない。
