# 起動不具合の振り返り（2026-10-19）

対象: MediaViewer（`001-three-pane-media-viewer` ブランチ）
範囲: Phase 1〜9 の実装後、`open .build/MediaViewer.app` でウインドウが表示されなかった事象

## 結論

起動できなかった直接の原因は、AppKit の Objective-C 例外が2つあったことです。

1. `NSSplitViewController` が Auto Layout 使用時に受け付けない `NSSplitViewDelegate` メソッドを override していた
2. `FileListViewController` で、親ビューへ追加する前に別ビューとの制約を有効化していた

どちらも起動直後に必ず発生する決定的な不具合でしたが、**Phase ごとの起動確認を行わず、Core のテストが通ったことだけを品質ゲートにしていた**ため、Phase 9 の最後まで残りました。

## 時系列

1. Phase 1〜9 を実装。並列実装は内部 `task` サブエージェントを同じ作業ツリーで動かし、ファイルが重ならない範囲に限定した
2. `swift build` と `swift test` は成功（Core 69件 + 性能 6件 = 75件）
3. `scripts/make-app.sh` で `.app` を作成
4. ユーザーが `open .build/MediaViewer.app` を実行 → メニューのみ表示、ウインドウなし
5. 設定ウインドウは開くが、閉じるとプロセスが終了（`exit=0`）
6. クラッシュレポート、設定ファイル、標準エラーを調査 → 有効な情報なし
7. ターミナルから直接実行 → やはり `exit=0`
8. 起動経過を stderr と `/tmp/mediaviewer-debug.log` に記録 → `MainSplitViewController.viewDidLoad()` の `super.viewDidLoad()` で止まる
9. lldb の Objective-C 例外ブレークポイントで1つ目の例外を特定
10. 非互換 delegate をすべて削除 → まだ起動せず
11. 再度 lldb → 2つ目の例外（Auto Layout の共通祖先なし）を特定
12. `bottomBar` を親へ追加してから制約を有効化する順序に修正
13. `swift build` / `swift test` は成功。GUI の最終確認はユーザーへ依頼

## 原因1: NSSplitViewController と非互換な delegate

例外メッセージ:

> SplitViewController's splitView is unable to use autolayout because the SplitViewController overrides an incompatible delegate method.

`NSSplitViewController` は内部で Auto Layout を使うため、次の delegate メソッドを override すると起動時に例外になります。

- `splitView(_:constrainMinCoordinate:ofSubviewAt:)`
- `splitView(_:constrainMaxCoordinate:ofSubviewAt:)`
- `splitView(_:shouldCollapseSubview:forDoubleClickOnDividerAt:)`

T070 では最小幅を `constrainMinCoordinate` / `constrainMaxCoordinate` で守る指示でしたが、この API は `NSSplitViewController` と両立しません。目的を満たす互換方法に変更しました。

- 最小幅: `NSSplitViewItem.minimumThickness`（160 / 240 / 320pt）
- 折りたたみ: 通常時 `canCollapse = false`、フルスクリーン時だけ true にして `isCollapsed` を設定
- ダブルクリックでの折りたたみ: `canCollapse = false` により防止

この判断は `specs/001-three-pane-media-viewer/tasks.md` の T070 に実装注記として残しています。

## 原因2: 制約の有効化順序

例外メッセージ:

> Unable to activate constraint with anchors ... because they have no common ancestor. Does the constraint or its anchors reference items in different view hierarchies? That's illegal.

`FileListViewController.loadView()` で、`bottomBar` を `container` に追加する前に、各モードビューの `bottomAnchor` を `bottomBar.topAnchor` に接続する制約を有効化していました。`bottomBar` を先に `addSubview` し、その後にモードビューの制約を有効化するよう修正しました。

## なぜ時間がかかったか

- **UI の実行時検証が Phase 3 以降なかった**: ビルドと Core テストは通るが、ビューの構築はテスト対象外だった
- **AppKit の例外はクラッシュとして見えない**: イベントループ内で握りつぶされ、クラッシュレポートなし・終了コード0になる
- **並列エージェントの統合をコンパイルだけで確認した**: Auto Layout や AppKit の実行時制約はビルドでは検出できない
- **例外を1つずつユーザー確認付きで潰した**: 1つ直した後に lldb を再実行せず、GUI 確認を挟んだため往復が増えた
- **仕様の API 指示を実装前に検証しなかった**: T070 の非互換 API に着手前に気づけなかった
- **Phase 7 と 8 を1コミットにまとめた**: 起動不能時に bisect しにくかった

## うまくいったこと

- Core のロジック・異常系・FSEvents・性能はテストで守られており、UI 以外の不具合は早期に検出できた
- 並列エージェントにより、独立した Core / UI タスクを短時間で進められた
- T070 の仕様矛盾に気づいた時点で止まり、代替案を提示して承認を得られた
- lldb とファイルへのデバッグログで、最終的に両方の原因を特定できた
- トラブルシューティングを含む README を残せた

## 再発防止（AGENTS.md に反映済み）

- 各 Phase の終わりに「ビルド・テスト・起動スモーク」を行う
- 起動しない場合は、推測より先に lldb の Objective-C 例外ブレークポイントを使う
- 例外を1つ直したら、GUI 確認を戻す前に lldb を再実行して次の例外を確認する
- `NSSplitViewController` の非互換 delegate を override しない
- 制約は `addSubview` の後に有効化する
- 異なる view hierarchy のアンカー同士を制約しない
- 並列実装は worktree を標準とし、インテグレータが統合後に検証する
- Phase 単位でコミットし、bisect できる履歴を残す

## 起動しないときの手順

```bash
cd /Users/igachan/projects/my_img_viewer

# 古いプロセスを確認
pgrep -fl MediaViewer

# GUI を起動するため、実行前にユーザーへ依頼する
lldb -b \
  -o 'breakpoint set -E objc' \
  -o 'run' \
  -o 'bt 30' \
  -o 'po $x0' \
  -o 'quit' \
  -- .build/MediaViewer.app/Contents/MacOS/MediaViewer
```

- 例外がなくなり、ウインドウが表示されるまで繰り返す
- その後、ユーザーに3ペインの表示と主要操作を確認してもらう

## 関連コミット

- `bbff83b` `fix: resolve launch-time AppKit constraint exceptions`
- `c2c3285` `docs: add project README`

## 関連文書

- `AGENTS.md`: 次回以降に守るルール
- `README.md`: 起動・検証・トラブルシューティング
- `specs/001-three-pane-media-viewer/quickstart.md`: 手動検証シナリオ
- `specs/001-three-pane-media-viewer/tasks.md`: T070 の実装注記
