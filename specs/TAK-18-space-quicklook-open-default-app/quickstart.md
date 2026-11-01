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
| M1（技術検証 / FR-238） | リスト形式で画像1件を選び Space | 選んだ行の位置から拡大して Quick Look が開く。「プレビュー」アプリは起動しない |
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
| M10 | zip の中のメディアで Space とダブルクリック | 何も起きない（A-145） |
| M11 | Quick Look 表示中に選択中のファイルをゴミ箱へ入れる | Quick Look が閉じる |
| M12 | リスト形式・サムネイル形式で画像と動画をダブルクリック | 既定のアプリで開く。行は1件だけの選択になる |
| M13 | フォルダ・zip ファイルの行をダブルクリック | 従来どおり中を表示する。アプリは起動しない |
| M14 | Quick Look 表示中に別のメディアの行をダブルクリック | Quick Look が閉じ、そのファイルが既定のアプリで開く |
| M15 | ⌘/ のショートカット一覧 | Space の項目が追加され、動画の項目の条件が更新されている |

M1 と M16 で起点からの拡大・縮小または矢印キーの転送が成り立たなければ、保守者に報告して（B）を見送る（FR-238）。M12〜M14 は（B）の可否に関係なく確認する。

## 5 実行結果（実装後に記録）

未実施。
