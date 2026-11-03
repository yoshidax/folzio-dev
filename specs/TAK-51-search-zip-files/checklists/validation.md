# Validation: ファイル名検索で zip ファイルも検索対象にする

## 自動検証

| 項目 | 結果 | 備考 |
|---|---|---|
| Cloud の検査（`check-no-network.sh`、`check-readme-sync.sh master`、`check-english-comments.sh`、`check-skill-sync.sh`、`test_check_git_push.py`） | 合格 | 2026-11-02、master（TAK-46・47・49）取り込みと ID 振り直しの後 |
| macOS CI（`workflow_dispatch`、`83feaf8`）`swift build` | 成功 | [run 41468584247](https://github.com/yoshidax/folzio-dev/actions/runs/41468584247) |
| 同 通常のテスト（`swift test --no-parallel --skip FolzioPerformanceTests`） | 成功 | 追加した `FileNameSearcherTests` 6 件、`BrowserModelSearchTests` 6 件を含む |
| 同 性能テスト（非ブロッキング） | 成功 | ログ末尾で `Test run with 27 tests passed` を確認 |

PR は未作成のため、CI は `workflow_dispatch` で実行した（`4fe4815` でも成功）。

## 手動確認（GUI）

- 実施日: 2026-11-02
- 実施者: 保守者（ローカルの macOS）
- 手順: [quickstart.md](../quickstart.md) のシナリオ 1〜9

| シナリオ | 対応する受け入れシナリオ | 結果 |
|---|---|---|
| 1 設定オフで検索すると zip が出ない | US55-AS1 | 合格 |
| 2 設定オンで検索すると zip が出る（zip の中・隠しファイルは出ない） | US54-AS1・AS2・AS6 | 合格 |
| 3 同名の zip が「場所」で見分けられる | US54-AS3 | 合格 |
| 4 `*.zip` のワイルドカード | US54-AS4 | 合格 |
| 5 検索結果の表示中に設定を切り替えても結果が変わらない | US55-AS2・AS3 | 合格 |
| 6 zip の行を開く（ダブルクリック・⌘↓・「中を表示」）と、ツリー同期・⌘[ で戻る | US56-AS1 | 合格 |
| 7 zip の行でプレビューが空・フルスクリーンとスライドショーで止まらない | US56-AS3 | 合格 |
| 8 「画像のみ表示」と zip の行 | US56-AS4 | 合格 |
| 9 名前の変更・ゴミ箱 | US56-AS5・AS6 | 合格 |

保守者の報告: 「quickstart.md 1〜9 まで確認し、期待通り動作することを確認しました」。個々のシナリオの詳細な所見は報告されていない。
