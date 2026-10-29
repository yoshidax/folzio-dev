# Validation: Folzioへの改名

**日付**: 2026-10-29

**OS**: macOS 26.6.2（25G83、ユーザー報告）

**対象**: `015-rename-to-folzio` のPhase 2、`.build/Folzio.app/Contents/MacOS/Folzio` SHA-256 `6e6a7a3ea473d93d9ffaa93d36bd9935c7cc2ece650fef2dac7b06f47b50c101`

| 項目 | 結果 | 内容 |
|---|---|---|
| `swift build` | pass | 改名後のPackageと全ターゲット |
| `swift test` | pass | Core 821件、性能27件。通常の並列実行を再実行して成功 |
| `swift test --no-parallel` | pass | Core 821件、性能27件 |
| 既定の3検査 | pass | ネットワーク禁止、README同期、英語コメント |
| アーカイブ書き込み検査 | pass | `scripts/check-no-archive-writes.sh` |
| Python運用テスト | pass | 35件。設定移行と公開先の `.vscode` 保護を含む |
| 実際の設定機構の一時テスト | pass | ランダムなテストドメインで旧設定保持、復元、バックアップと再実行拒否を確認後、テストドメインのみ削除 |
| アプリ構成 | pass | Bundle ID、名前、実行ファイル、アイコン、日英リソース、署名 |
| 移動リハーサル | pass | 一時領域の `folzio` で `swift build` と `swift test --no-parallel`、Core 821件と性能27件 |
| 設定移行（手動） | pass | ユーザーが `.app` と `swift run` の両ドメインを移行し、各バックアップの作成を報告 |
| 起動・動作確認（手動） | pass | ユーザーが `.app` と `swift run FolzioApp` の両方について「問題なし」と報告。依頼した3ペイン、日英、画像・動画・zip、整理と設定復元を対象とする |

## 検証中の事象

最初の並列実行では `ThumbnailProvider` のキャッシュ同一性2件が失敗し、2回目は検索待機時間に関する複数のテストが失敗した。前者は改名前のソースとの比較で関連実装が同一であり、改名前と改名後の単独実行がそれぞれ成功した。並列なしの全テスト、および3回目の通常の `swift test` は成功した。負荷やキャッシュ状態の影響が考えられるが原因は確定していない。

実際の開発・公開ディレクトリの移動と新パスでの再確認は、仕様反映後に `docs_private/folzio-rename.md` に従って実施する。
