# Validation: パス名のコピー

**Feature**: [spec.md](../spec.md) | **Plan**: [plan.md](../plan.md) | **Date**: 2026-10-30

## 自動検証

| 確認項目 | 結果 | 根拠 |
|----------|------|------|
| `swift build` | PASS | 成功 |
| `swift test --filter FolzioCoreTests` | PASS | 826 件合格（ListItemCommands・FavoriteCommands の新規テストを含む） |
| `swift test --filter FolzioPerformanceTests` | PASS | 27 件合格（単独で再実行）。全体を一度に実行した2回は、実行ごとに別の性能テストが閾値を超えた（負荷による揺れ） |
| `scripts/check-no-network.sh` / `scripts/check-readme-sync.sh master` / `scripts/dev/check-english-comments.sh` | PASS | 全て合格 |

## GUI 確認（macOS、ユーザー実施）

`scripts/make-app.sh` の後に `open .build/Folzio.app` で確認した。結果は「問題なし」の報告（quickstart.md の手順 1〜9）。

| 手順 | 確認項目 | 対応 | 結果 |
|------|----------|------|------|
| 1 | メディアの行で貼り付けた文字列が絶対パスと一致。選択・プレビューが変わらない | FR-181・185、SC-086・089 | PASS |
| 2 | フォルダ・zip ファイル・検索結果の行でも一致 | FR-181、SC-086 | PASS |
| 3 | 複数選択・`..` で淡色 | FR-183、SC-087 | PASS |
| 4 | zip の中の項目で淡色、⌥⌘C は何もしない | FR-183、SC-087 | PASS |
| 5 | ツリーの右クリック（フォルダ・ホーム・お気に入り）で一致。ツリーの選択が変わらない | FR-182・185、SC-086・089 | PASS |
| 6 | 見出しはメニューなし、見出し選択中の編集メニューは淡色 | FR-182・183、SC-087 | PASS |
| 7 | ⌥⌘C（ファイルリスト・ツリー）で一致 | FR-184、SC-086 | PASS |
| 8 | ファイルの ⌘C の後にパス名をコピーすると「ペースト」が淡色 | FR-181 | PASS |
| 9 | 英語に切り替えると「Copy as Pathname」 | FR-186 | PASS |
