# Validation Guide: TAK-19

実装後の検証手順。実行結果と未確認事項は第5章に記録する。

## 1 Cloud の静的検査

リポジトリのルートで実行する。

```bash
scripts/check-no-network.sh
scripts/check-readme-sync.sh master
scripts/dev/check-english-comments.sh
scripts/dev/check-skill-sync.sh
python3 -I -m unittest discover -s scripts/dev/tests -p 'test_check_git_push.py'
git diff --check
```

期待結果: すべて成功。新しい通信なし。README は変更しない（docs/ の英語版と日本語版は同じコミットで直す）。

## 2 macOS CI

保守者の依頼で PR を作ったときの macOS Swift CI を確認する。追加の修正の後は、必要なときだけ1回 `workflow_dispatch` で再確認する。
期待結果: `swift build`、通常のテスト（`PreviewDoubleClickTests` を含む）に成功。性能テストはログの末尾で成否を確かめる（失敗許容のステップでも結果を隠さない）。
Cloud では Swift を実行しないため、CI の結果がない間は未確認と記録する。

## 3 保守者のローカルの準備

macOS 15 以降、対象のコミットを取り込んだ開発用リポジトリで実行する。

```bash
swift build
swift test
scripts/make-app.sh
open .build/Folzio.app
```

起動して3ペインが表示されることを確かめる（起動スモーク）。画面より小さい画像・横長の画像・アニメーション GIF・動画（音声つき）・
表示できないファイル・サブフォルダがあるフォルダを用意する。

## 4 シナリオ（GUI。保守者が行う）

| 番号 | 操作 | 期待結果 / 対象 |
|---|---|---|
| M1 | 3ペイン表示とプレビューのみ表示のそれぞれで、静止画・アニメーション GIF の画像の上と周りの余白を各5回ダブルクリックし、全画面中にメディアの上・上下左右の余白・画面の四隅を各5回ダブルクリックする | 毎回、全画面化と解除が切り替わる。解除後のペイン表示・ペイン幅・フォーカスが全画面前と同じ（US5-AS8・AS10、SC-108） |
| M2 | 再生中と一時停止中の動画で、映像の上と周りの余白をダブルクリックして全画面にし、全画面中の映像・余白・四隅のダブルクリックで解除する。映像の上をシングルクリックもする | 毎回切り替わる。再生位置と再生状態がダブルクリックの前と同じ。シングルクリックで再生状態が変わらない。動画自身の別の全画面表示が始まらない（US5-AS7・AS10、FR-221、research.md の R3） |
| M3 | 通常表示と全画面中で、動画の再生ボタン・シークバー・音量の上を各5回ダブルクリックする。画像を拡大してスクロールバーを出し、その上を各5回ダブルクリックする | 全画面が切り替わらない。コントロールとスクロールバーは従来どおり操作できる（US5-AS9、EC-150、SC-109、research.md の R2） |
| M4 | 何も選択していない状態、フォルダの行・zip ファイルの行を選んだ状態で、プレビューをダブルクリックする。表示できないファイルを選んでダブルクリックする | 空のプレビューでは何もしない。表示できない旨の表示ではダブルクリックで全画面になり、全画面中のダブルクリックで解除する（EC-149、SC-109） |
| M5 | 全画面中に矢印キーで別のメディアへ移ってからダブルクリックする | 解除され、移動後のファイルが選択・プレビューされた状態になる（US5-AS11） |
| M6 | スライドショーを全画面で実行し、画像と動画を表示中にそれぞれダブルクリックする。切り替え効果の表示中にもダブルクリックする | スライドショーを続けたまま全画面が解除され、プレビューのみ表示で続く。もう一度のダブルクリックで全画面に戻る（US5-AS12、EC-151、FR-122） |
| M7 | 画像を拡大してスクロールした状態で、画像の上をダブルクリックして全画面にし、もう一度ダブルクリックして戻す | 1回目のクリックで倍率と表示位置が変わらない。全画面の前後の位置は FR-159 に従う（EC-152） |
| M8 | ⌃⌘F・Esc・表示メニューの「フルスクリーン」で切り替え、ファイルリストのみ表示から ⌃⌘F を使う | 従来どおり動く（A-135、FR-036、FR-094（window-layout.md）） |

M2 または M3 が期待どおりでない場合は、推測で直さず、結果（OS のバージョン、操作した位置、起きたこと）を Cloud Agent に知らせる（research.md の R2・R3）。

## 5 結果の記録（実装の後に追記する）

- 2026-10-31: 保守者が設計レビューを承認した（会話で「OKです」）。research.md の R2・R3 の実機での確認と、読み込み中・表示できない表示を対象に含める方針（EC-149）を含めて承認された（T001）。
- 2026-10-31: Cloud の検査（T010）。`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、
  `scripts/dev/check-skill-sync.sh`、`test_check_git_push.py`（3件）、`git diff --check` がすべて成功した。Swift の build・test と GUI は未実施（CI と保守者の確認を待つ）。
- 2026-11-01: master（5b6988b。TAK-17 のフォルダ作成、TAK-21 のツリーの複数選択）を取り込んだ。テキストの競合はなかった。
  - ID の衝突: 本 feature の FR-208〜209・SC-102〜103・EC-141〜144・A-119〜121 を TAK-17・TAK-21 が file-operations.md で先に使っていたため、
    FR-220〜221・SC-108〜109・EC-149〜152・A-133〜135 へ振り直した（feature の文書、`PreviewDoubleClick.swift`、テスト、追加したコメント）。US5-AS7〜12 は衝突なし
  - コードへの影響: master はプレビュー（`Sources/FolzioApp/Preview/`）を変更していない。`MainSplitViewController.swift` の変更はファイル操作の接続の追加だけで、
    本 feature が使う `isFullScreenPresentation`・`model.preview`・`togglePreviewFullScreen()` は変わっていない。`PreviewContent` の case も変わっていない
  - 文書: `docs/usage*.md` の master の追記は別の行で、全画面の行は本 feature の変更のまま。`specs/product/contracts/keyboard-and-menus.md` の変更対象の3行は master でも同じ文言
  - Cloud の検査を再実行し、すべて成功した。Swift の build・test は CI で確認する
