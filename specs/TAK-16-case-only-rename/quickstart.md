# Quickstart: TAK-16

設計段階。以下は実装後の検証手順であり、実行済みではない。

## Prerequisites

Apple silicon、macOS 15 以降、Swift 6。大文字小文字を区別しない APFS と区別する APFS の、書き込めるテスト用フォルダを用意する。既存データを使わない。Cloud では Swift・GUI のコマンドを実行しない。

## Automated validation (macOS / CI)

```bash
swift build
swift test --no-parallel --skip FolzioPerformanceTests
swift test --filter FolzioPerformanceTests
```

新規テストで成功 URL と親の実際の保存名、ファイルのバイト列・フォルダの子ファイルを検証する。旧パスが存在しないことだけを成功条件にしない。CI のボリュームの性質、条件付きで実行しなかったテストを報告する。

## GUI validation (maintainer, both volumes)

```bash
scripts/make-app.sh
open .build/Folzio.app
```

各ボリュームの一時テストフォルダに photo.png、子ファイルを含む Album、別項目 taken.png を作る。case-sensitive 側だけ photo.png と Photo.png の共存も作る。

1. 一覧・サムネイル・検索結果から photo.png → Photo.png、続いて photo.PNG。常時確認、追加の拡張子確認なし、Finder でも保存名と内容を確認。
2. リストとツリーから Album → album。子ファイルをプレビューしたまま親を改名し、ツリーの選択・展開・一覧・スクロール・プレビュー・履歴・検索の場所表示を確認（FR-104・FR-105）。
3. taken.PNG への変更、および case-sensitive 側の PHOTO.PNG への競合を試す。エラーを表示し、双方の名前・内容を保ち、置換の選択肢を出さない。
4. Esc・確認キャンセル・完全に同じ表記を試し、変更なしを確認。拡張子の実際の変更は既存の確認を保つ。
5. 3 ペインの起動スモークと通常の改名・コピー/移動の回帰を確認する。

## Cloud checks

```bash
scripts/check-no-network.sh
scripts/check-readme-sync.sh master
scripts/dev/check-english-comments.sh
python3 -I -m unittest discover -s scripts/dev/tests -p 'test_check_git_push.py'
```

結果と未確認事項は tasks.md に記録する。両ボリュームの操作・CI・起動スモークが揃うまで完了扱いしない。
