# Validation: 操作の進む・戻る（ナビゲーション履歴）

**Feature**: [spec.md](../spec.md) | **Plan**: [plan.md](../plan.md) | **Date**: 2026-10-25

- OS: macOS 26.6.2（25G83）、Mac15,12
- ブランチ: `004-navigation-history`（base: `ece5de1`）。ビルドは `scripts/make-app.sh`（release）で作った `.build/MediaViewer.app`
- 実装: T001〜T035。T033 の起動スモークと T034 の GUI の手動確認はユーザーが実施し、問題の指摘はなかった（2026-10-25）

## 自動の検証（T032）

| 確認項目 | 結果 | 根拠 |
|----------|------|------|
| `swift build` | PASS | Build complete（警告は既存の `MainToolbarController` の KVO のものだけ） |
| `swift test`（Core） | PASS | 612 件、54 スイート |
| `swift test`（性能） | PASS | 19 件、PerformanceBaseline |
| `scripts/check-no-network.sh` | PASS | no network API references in Sources |
| 10,000 ファイルのフォルダへ戻って最初の項目が表示されるまで（T024、基準 1 秒、SC-029） | PASS | 実測 0.421 秒（デバッグビルド。履歴の戻る要求から `listing.state == .loaded` かつ 10,000 件になるまで） |
| 戻る・進むの受付が 100ms 以上止まらない（T017、SC-029） | PASS | `HistoryNavigatorTests.navigationCallDoesNotBlock` で、300ms かかる zip の索引作成中でも `goForward()` の受付が 100ms 未満であることを検証 |

- 自動テストの内訳: 履歴の値型 31 件、`HistoryNavigator` 29 件、`BrowserModel` の通知・確認・表示 12 件、`ArchiveIndex.containsDirectory` 1 件、`PaneCommands.canNavigateHistory` 1 件、
  性能 1 件を追加した
- 既存の検索テストは、性能テストのフィクスチャ作成を MainActor の外へ移すまで、全件同時実行でタイムアウトした。移動後は 612 件すべて成功した

## 起動スモーク（T033）

| 確認項目 | 結果 | 根拠 |
|----------|------|------|
| `.app` が Objective-C 例外で止まらない | PASS | lldb の `breakpoint set -E objc` を有効にして起動し、例外なしでウインドウが作成された |
| 3ペインが表示される | PASS（プログラム確認） | ウインドウの `contentViewController.splitViewItems` が 3 件 |
| ツールバーの左端に戻る・進むのボタングループがある | PASS（プログラム確認） | ツールバーの項目が `history`, `paneLayout`, `mediaTypeFilter`, `zipVisibility`, `viewMode`, `thumbnailSize` の順で、先頭が `history`。その view は `NSSegmentedControl` で、セグメント数が 2 |
| `<`・`>` の見た目・淡色・アクセシビリティ | PASS | ユーザーの GUI の確認（quickstart 1・23） |

起動確認に使ったコマンド（lldb）:

```bash
lldb -b \
  -o 'breakpoint set -E objc' \
  -o 'breakpoint set -n "-[NSWindow makeKeyAndOrderFront:]"' \
  -o run \
  -o 'po [[[[[NSApplication sharedApplication] windows] objectAtIndex:0] contentViewController] splitViewItems]' \
  -o 'po [[[[[NSApplication sharedApplication] windows] objectAtIndex:0] toolbar] items]' \
  -o 'process kill' -o quit \
  -- .build/MediaViewer.app/Contents/MacOS/MediaViewer
```

初回の起動時に `com.apple.linkd.autoShortcut` への接続エラーがログに出るが、ウインドウの作成と3ペインの構築には影響しなかった。

## 手動確認（T034、quickstart.md の「3. 手動確認」）

2026-10-25 にユーザーが GUI で確認し、「問題なかった」と報告した（問題の指摘なし）。

| # | 確認項目 | 結果 |
|---|----------|------|
| 1 | 起動直後の `<`・`>` と「移動」メニューが淡色（US7-AS9、SC-032） | PASS |
| 2 | A → B → C から ⌘[ を2回で A に戻る（US7-AS1） | PASS |
| 3 | ⌘] とツールバーの `>` で B → C に進む（US7-AS2） | PASS |
| 4 | フォルダを開いた後に戻ると、フォーカスしていた行だけを選ぶ（US7-AS3） | PASS |
| 5 | zip の中を1階層ずつ戻り、最後にフォルダへ戻る（US7-AS4） | PASS |
| 6 | 戻った後に新しく選ぶと `>` が淡色になる（US7-AS5） | PASS |
| 7 | 外で名前を変えた B を飛ばして A に戻る（US7-AS6、SC-030） | PASS |
| 8 | 表示中のフォルダをゴミ箱に入れると戻れなくなる（US7-AS7） | PASS |
| 9 | 150 回の移動で履歴が 100 件に制限される（US7-AS8、SC-031） | PASS |
| 10 | ツールバーを隠しても ⌘[・⌘] が動く（US7-AS10） | PASS |
| 11 | 検索結果の表示中の ⌘[ は検索を終える（US7-AS11） | PASS |
| 12 | 起動直後の検索でも ⌘[ が使える（US7-AS12） | PASS |
| 13 | 表示形式の変更を戻す・進める（US8-AS1） | PASS |
| 14 | サムネイルサイズのドラッグを1回で戻す（US8-AS2） | PASS |
| 15 | 種類フィルタを戻す（US8-AS3） | PASS |
| 16 | ペインの表示を戻す（US8-AS4） | PASS |
| 17 | 場所と表示の状態を順に戻す（US8-AS5） | PASS |
| 18 | 記録しない操作（⇧⌘T・⌃⌘F・⌥⌘1）を戻さない（US8-AS6） | PASS |
| 19 | 戻った直後のサイズ変更が新しい履歴になる（US8-AS7） | PASS |
| 20 | 読めないフォルダは飛ばさずエラーを表示する（EC-55） | PASS |
| 21 | 名前の変更中とフルスクリーン中は履歴の操作を無効にする（EC-63） | PASS |
| 22 | 10,000 ファイルのフォルダを連打で移動しても止まらない（EC-61、SC-029。Instruments の Hangs とメインスレッド、または目視） | PASS |
| 23 | VoiceOver が `<`・`>` を「戻る」「進む」と読み上げる（FR-112） | PASS |
| 24 | JIS キーボードでも ⌘[・⌘] が動く | PASS |
| 25 | zip の中で始めた検索を ⌘[ で終え、もう一度 ⌘[ で zip へ戻る（FR-113、US7-AS13、R76） | PASS |
| 26 | ボリュームの取り外しで X の履歴が消え、ボリュームのルートでは EC-60 の扱いになる（EC-57・EC-65、R75） | PASS |

## 確認中に見つかった不具合

- なし（自動テストと lldb での起動確認の範囲）
