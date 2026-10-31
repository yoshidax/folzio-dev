# Quickstart: 設定ウインドウのセクション間隔の統一と確認オプションの補足説明の分離

## 自動の検証

| 実行する者 | 検査 |
|---|---|
| Cloud（Agent） | `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`、`python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py"` |
| CI（macOS） | `swift build`、`swift test`（`CatalogConsistencyTests` と新しい `SettingsTextTests` を含む） |

## GUI の確認（保守者のローカル）

古い Folzio を終了してから、次を実行する。

```bash
scripts/make-app.sh
```

```bash
open .build/Folzio.app
```

3ペインが表示されることを確認してから、⌘, で設定ウインドウを開く。

| # | 手順 | 確認する点 | 対応 |
|---|---|---|---|
| Q1 | 日本語表示で設定ウインドウを開く | 「動画」「ファイル操作」「スライドショー」の見出しの前の間隔が同じで、区分の中の間隔より広い。「ファイル操作」の確認の項目の上下に大きな空白がない。最後の項目（切り替え効果）の下の余白が上端の余白と同じ | US35-AS1、FR-208、SC-102 |
| Q2 | Q1 の「ファイル操作」を見る | 1行目にチェックボックスと「コピー・ゴミ箱に入れる・お気に入りから削除する前に確認する」（1行に収まる）、その直下に「名前の変更・移動・ツリーのフォルダのゴミ箱は常に確認する」が小さく淡い文字で、チェックボックスの文言の先頭に揃って表示される | US36-AS1、FR-209 |
| Q3 | 補足説明の文字をクリック・ドラッグする | チェックボックスが切り替わらず、文字が選択されない。チェックボックスの文言のクリックでは従来どおり切り替わる | US36-AS3 |
| Q4 | 設定ウインドウを開いたまま「言語」を English にする | ウインドウを閉じずに英語に変わり、同じ間隔の規則で並び直る。主文「Confirm before copying, moving to the Trash, or removing from Favorites」と補足説明「Renaming, moving, and moving tree folders to the Trash are always confirmed」が別の行で、欠けずに読める。最後の項目の下の余白が上端と同じ | US35-AS2〜3、US36-AS2、EC-141・143 |
| Q5 | システム設定の外観をライト・ダークに切り替える（可能なら「コントラストを上げる」も） | 補足説明が主文より淡く、どちらの外観でも読める | EC-142 |
| Q6 | VoiceOver（⌘F5）をオンにし、言語のポップアップから Tab を順に押す | 言語 → 自動再生 → ループ → 確認 → 切り替え間隔 → 繰り返し → 切り替え効果 の順に移る。確認のチェックボックスで、名前と状態に続いて補足説明が読まれ、補足説明が別の項目として二重に読まれない | US36-AS4 |
| Q7 | 確認の設定をオフにし、ファイルリストでファイルをコピー・ペースト、名前を変更する | コピーは確認なしで実行され、名前の変更は確認モーダルが出る（本変更の前と同じ） | US36-AS5 |

## 結果の記録

（実装・CI・保守者の確認の後に記入する）
