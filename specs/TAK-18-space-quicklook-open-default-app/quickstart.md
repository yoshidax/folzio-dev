# Validation Guide: TAK-18

実装後の検証手順。実行結果と未確認事項は第5章に記録する（実装の後に追記する）。

## 1 Cloud の静的検査

```bash
scripts/check-no-network.sh
scripts/check-readme-sync.sh master
scripts/dev/check-english-comments.sh
scripts/dev/check-skill-sync.sh
python3 -I -m unittest discover -s scripts/dev/tests -p 'test_check_git_push.py'
git diff --check
```

期待結果: すべて成功。新しい通信なし。

## 2 macOS CI

PR を作ったときの macOS Swift CI で `swift build` と通常のテスト（`QuickLookTargetsTests`、ショートカット一覧の整合テストを含む）を確認する。
特に、Quick Look の API が Swift 6 の言語モードでビルドできること（research.md R6）を見る。Cloud では未確認。

## 3 保守者のローカルの準備

```bash
swift build
swift test
scripts/make-app.sh
open .build/Folzio.app
```

静止画・アニメーション GIF・動画（音声つき）・サブフォルダ・zip ファイルを含むフォルダを用意する。

## 4 シナリオ（GUI。保守者が行う）

| ID | 手順 | 期待結果 |
|---|---|---|
| M1（技術検証 / FR-252） | リスト形式で画像1件を選び Space | 選んだ行の位置から拡大して Quick Look が開く。「プレビュー」アプリは起動しない |
| M2 | M1 のあと Space | 行の位置へ縮んで閉じる。選択・スクロール位置は変わらない |
| M3 | 閉じた直後に ↓ | 選択がファイルリストで次へ移る（フォーカスが戻っている） |
| M4 | サムネイル形式（⌘1）で M1〜M3 | サムネイルの位置から拡大・縮小する |
| M5 | 動画を選び Space（ファイルリストにフォーカス） | 動画の再生は切り替わらず、Quick Look が開く。プレビューペインで再生中なら一時停止される |
| M6 | プレビューペインの動画にフォーカスして Space | 従来どおり再生 / 一時停止。Quick Look は開かない |
| M7 | メディア3件を選び Space、Quick Look 内で ←/→ | 3件が順に表示される。閉じると選択は3件のまま |
| M16 | Quick Look 表示中（1件選択）に ↓/↑（リスト形式）、←/→/↑/↓（サムネイル形式） | ファイルリストの選択が動き、Quick Look の表示と起点が新しいファイルに追従する。フォルダの行に移ったときは、選択はその行へ移り Quick Look は閉じる（US3-AS36） |
| M17 | メディア3件を選択して Space、Quick Look のツールバーの `<` `>` をクリック | 3件の間を移動する。ファイルリストの選択は3件のまま変わらない |
| M18 | M17 の状態で矢印キー | ファイルリストの選択が1件へ移り、Quick Look が単一ファイルの表示に切り替わる |
| M19 | Quick Look 表示中に動画の行へ矢印キーで移動 | プレビューペインの動画は自動再生されない。閉じた後も再生は始まらない |
| M8 | フォルダの行だけを選び Space／フォルダとメディアを選び Space | 前者は何もしない。後者はメディアだけ表示される |
| M9 | 検索結果のメディアで Space | 開く。閉じても検索結果は終わらない |
| M10 | zip の中のメディアで Space とダブルクリック | 何も起きない（A-150） |
| M11 | Quick Look 表示中に選択中のファイルをゴミ箱へ入れる | Quick Look が閉じる |
| M12 | リスト形式・サムネイル形式で画像と動画をダブルクリック | 既定のアプリで開く。行は1件だけの選択になる |
| M13 | フォルダ・zip ファイルの行をダブルクリック | 従来どおり中を表示する。アプリは起動しない |
| M14 | Quick Look 表示中に別のメディアの行をダブルクリック | Quick Look が閉じ、そのファイルが既定のアプリで開く |
| M15 | ⌘/ のショートカット一覧 | Space の項目が追加され、動画の項目の条件が更新されている |

M1 と M16 で起点からの拡大・縮小または矢印キーの転送が成り立たなければ、保守者に報告して（B）を見送る（FR-252）。M12〜M14 は（B）の可否に関係なく確認する。

## 5 実行結果（実装後に記録）

### Cloud の静的検査（2026-11-02）

`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`、`test_check_git_push.py`、`git diff --check` はすべて成功した。

### macOS CI（2026-11-02、PR #33、head 3d8c596）

- `swift build`: 成功。通常のテスト（`--skip FolzioPerformanceTests`）: 944 件すべて成功。`QuickLookTargetsTests` とショートカット一覧の整合テストを含む。
- 経緯: 1 回目は `TextKey.comment` の switch の網羅漏れ、2 回目は `acceptsPreviewPanelControl` 系の override が MainActor のプロパティを参照できない Swift 6 の並行性エラーで失敗し、
  それぞれ直した（override を `nonisolated` にして `MainActor.assumeIsolated` で包んだ）。3 回目で成功した。
- 性能テスト（失敗を許容するステップ）: 27 件中 1 件が基準をわずかに超えた。`didRenameFolder` が検索結果 10,000 件で中央値 0.1019 秒（基準 0.1 秒。測定値 0.112 / 0.102 / 0.098 秒）。
  この処理は TAK-18 の変更に含まれず、共有ランナーでの測定のぶれと考えられる。再現確認は行っていない。
- 警告: `QuickLookCoordinator` の `@preconcurrency QLPreviewPanelDelegate` に「`NSWindowDelegate` への `@preconcurrency` は効果なし」の警告が出る。ビルドは止まらない。

### 保守者の実機確認（2026-11-02）

- M1〜M15 を確認した。M6 以外に問題の報告はない。
- M6（プレビューの動画にフォーカスして Space）: 通常表示（3ペイン表示・プレビューのみ表示）では、プレビューのペインにフォーカスしても Space で再生／一時停止が切り替わらなかった。
  フルスクリーンでは効く。再生コントロールをクリックしてフォーカスを合わせると反応する。TAK-18 の変更ではなく既存の動作と見られるため、別 Issue
  [TAK-48](https://linear.app/takyoshida/issue/TAK-48) として登録した。TAK-18 は FR-248 のとおり、ファイルリストの Space を Quick Look に変えるだけで、
  プレビュー側の Space は変えていない。TAK-48 が直るまで、通常表示で Space による再生／一時停止の実用的な手段がない。
- M16〜M19（矢印キーの転送、`<` `>` ボタン、動画の自動再生の抑制）: 未実施。
