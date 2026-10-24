# Quickstart: お気に入りの名前の変更の検証

AGENTS.md の「Phase の検証ゲート」に沿って確かめる。仕様は [spec.md](./spec.md)、保存形式は [contracts/settings.md](./contracts/settings.md)、
キーとメニューは [contracts/keyboard-and-menus.md](./contracts/keyboard-and-menus.md)。

## 1. 自動の検証

```bash
cd /Users/igachan/projects/my_img_viewer
swift build
swift test
swift test --filter MediaViewerCoreTests   # FavoriteName・FavoriteFolders・FavoriteCommands・SettingsStore
scripts/check-no-network.sh
```

期待: すべて成功。新しいテストは [data-model.md](./data-model.md) の「テスト」の表の項目を含む。

## 2. 準備（GUI の確認の前に）

```bash
# 場所の違う同じ名前のフォルダを作る
mkdir -p ~/MediaViewerFavTest/Photos/2025 ~/MediaViewerFavTest/Backup/Photos/2025
# 編集中のボリュームの接続・取り外し（3. の 24）に使うディスクイメージを作る（ここでは接続しない）
hdiutil create -size 10m -fs APFS -volname FavTestVol ~/MediaViewerFavTest/FavTestVol.dmg
# 旧形式の保存内容（表示名なし）を入れる。.app のドメインを使う
pgrep -fl MediaViewer   # 残っているプロセスがないこと
# 次の write は .app のドメインにある実際のお気に入りを上書きする。先にドメインごと退避する
# （退避先は後で消す ~/MediaViewerFavTest の外に置く）
defaults export local.my-img-viewer.MediaViewer ~/MediaViewer-defaults-backup.plist
defaults write local.my-img-viewer.MediaViewer favorites.paths -array \
  "$HOME/MediaViewerFavTest/Photos/2025" "$HOME/MediaViewerFavTest/Backup/Photos/2025"
defaults delete local.my-img-viewer.MediaViewer favorites.displayNames 2>/dev/null || true

scripts/make-app.sh
open .build/MediaViewer.app
```

`defaults export` が「ドメインがない」で失敗したときは、退避するものがない（`.app` を一度も使っていない）。その場合は
元に戻すときにドメインごと消す（下の2つ目の手順）。

元に戻すとき（アプリを終了してから行う。起動中だと終了時の書き込みで上書きされる）:

```bash
pgrep -fl MediaViewer   # 残っているプロセスがないこと
# 退避したとき: 確認で付いた表示名を消してから、退避した内容を書き戻す
defaults delete local.my-img-viewer.MediaViewer favorites.displayNames 2>/dev/null || true
defaults import local.my-img-viewer.MediaViewer ~/MediaViewer-defaults-backup.plist
defaults read local.my-img-viewer.MediaViewer favorites.paths   # 元のお気に入りに戻ったこと
rm ~/MediaViewer-defaults-backup.plist
# 退避するものがなかったとき: ドメインごと消す
# defaults delete local.my-img-viewer.MediaViewer
hdiutil detach /Volumes/FavTestVol 2>/dev/null || true   # 24 のディスクイメージが接続されたままなら外す
rm -rf ~/MediaViewerFavTest
```

## 3. 手動確認（ユーザーに依頼する）

起動スモーク: 3ペインが表示されること。以下は「お気に入り」を展開して行う。

| # | 操作 | 期待 | 対応 |
|---|---|---|---|
| 1 | 起動直後の「お気に入り」を見る | 「2025」が2つ、登録順に並ぶ（旧形式が失われず、並びも変わらない） | EC-45 |
| 2 | 2つ目の「2025」を選び、ツリーにフォーカスがある状態で Return →「2025（バックアップ）」と入力 → Return | 行の中で編集が始まり、開始時に名前が全選択されている。確定後はその行だけ新しい名前。確認モーダルは出ない。ファイルリスト・プレビューは変わらず、フォーカスはツリーに戻る | US1-AS30、FR-099 |
| 3 | Finder で `~/MediaViewerFavTest/Backup/Photos/` を開く | フォルダ名は `2025` のまま | SC-019 |
| 4 | 1つ目の「2025」を右クリック →「名前を変更」→ 名前を入力して、ほかの行をクリック | メニューは「名前を変更」「お気に入りから削除」の順。右クリックした行が編集され、ツリーの選択は変わらない。クリックで確定する | US1-AS31、A-21・31 |
| 5 | 名前を変えた項目で編集を始め、別の名前を入力して Esc | 編集前の名前に戻る | US1-AS32 |
| 6 | 名前を変えた項目で編集を始め、全部消して（または空白だけにして）Return | 「2025」に戻る | US1-AS33、EC-40 |
| 7 | 片方を「2025（バックアップ）」に戻し、もう片方も同じ名前で確定 | 拒否されず、同じ名前が2つ並ぶ | EC-41 |
| 8 | `/` と `:` を含む名前、絵文字を含む名前で確定 | そのまま表示される | FR-100 |
| 9 | 300 文字ほどのテキストや、改行を含むテキストを編集欄に ⌘V（「編集 > ペースト」）でペーストする | 編集欄へのテキストのペーストになる。改行は入らず、255 文字を超える分は入らない | FR-100、R53 |
| 10 | アプリを終了（⌘Q）して再び開く | 変更後の名前のまま、登録順も同じ | US1-AS34、SC-021 |
| 11 | 「お気に入り」の見出し・ホーム・ボリュームの最上位・通常のフォルダを順に選び、それぞれで Return | 編集は始まらず、何も変わらない。それらの右クリックメニューに「名前を変更」はない。それらを選択中の「編集 > 名前を変更」は淡色 | US1-AS35、FR-099 |
| 12 | お気に入りの項目を選択し、「編集」メニューを開く →「名前を変更」 | 有効で、選ぶと編集が始まる | FR-099（3） |
| 13 | ファイルリストにフォーカスを移してファイルを選び Return | 従来どおりファイル名の変更が始まる（ツリーの項目は編集されない） | FR-099 |
| 14 | ファイルリストで zip の中を表示（または ⌘F で検索結果を表示）したまま、ツリーのお気に入りの項目で Return → 名前を変えて確定 | 編集でき、ファイルリストの表示内容・選択・プレビューは変わらない | EC-46、FR-099 |
| 15 | お気に入りの項目の名前の編集中に、次を順に試す: ⌃⌘T、⇧⌘F、⌘F、⌃⌘2、⌃⌘3、⌃⌘Z、⇧⌘I、⇧⌘M、⌘⌫、⌥⌘V、ツールバーのペインの表示ボタン・「zipファイルを表示」ボタン、「ファイル」「表示」「編集」メニューの該当項目（[契約](./contracts/keyboard-and-menus.md)の §1 の表の操作と、§2 の段落に挙げたツリーのメニュー項目。「編集 > ペースト」（⌘V）は除く） | メニュー項目とツールバーのボタンは淡色で選べない。ショートカットはアプリの操作として働かない（ペインの切り替え・検索・フィルタ・zip の表示・お気に入りの追加や削除・移動ペーストなどが起こらない）。キーは編集欄に渡るため、⌘⌫ で編集欄の文字が消えるのは標準の編集動作で、不合格ではない。お気に入りは削除されない。編集はそのまま続く | FR-102 |
| 16 | 検索結果の表示中に、お気に入りの項目の編集を始めて Esc | 編集だけが取り消され、検索結果の表示は終わらない | FR-102 |
| 17 | 名前の編集中に、ターミナルで `mv ~/MediaViewerFavTest/Photos/2025 ~/MediaViewerFavTest/Photos/2025x` を実行し、数秒待ってから名前を確定 | 編集は途中で切れない。確定した名前が付き、項目は淡色（見つからない）になる | EC-43 |
| 18 | `mv ~/MediaViewerFavTest/Photos/2025x ~/MediaViewerFavTest/Photos/2025` で戻し、アプリをアクティブにする | 変更後の名前のまま通常の表示に戻る。見つからない間に名前を変えても同じ | EC-42 |
| 19 | 名前を変えた項目を ⌘⌫ で削除しようとする | 確認モーダルに表示名と登録したフォルダの絶対パスが出る。キャンセルすると何も変わらない | FR-064 |
| 20 | そのまま削除し、同じフォルダをツリーから ⌃⌘T で再登録 | 「2025」（フォルダの名前）で末尾に追加される | EC-44 |
| 21 | VoiceOver（⌘F5）をオンにし、名前を変えた項目へ移る → Return で編集を始める | 項目は表示名で読み上げられる。編集欄は「お気に入りの名前」と読み上げられる | FR-101 |
| 22 | お気に入りの項目の名前を編集中に、名前を入力してから「お気に入り」の見出しの開閉ボタンをクリックして折りたたむ → もう一度展開する | 入力した名前で確定してから折りたたまれる。編集欄が残ったり、ほかの行に編集の見た目が残ったりしない。展開すると確定した名前で表示され、フォーカスはツリーにある | R51、FR-099 |
| 23 | お気に入りの項目の名前を編集中に、名前を入力してから、ほかの行（別のお気に入りの項目と、通常のフォルダ）を右クリックする → Esc でメニューを閉じ、↑↓ キーと Return を押す | 入力した名前で確定してからメニューが開き、メニューは右クリックした行のものになる。編集の見た目は残らない。メニューを閉じた後、クリックし直さなくても ↑↓ でツリーの選択が動き、お気に入りの項目で Return を押すと編集が始まる（フォーカスはツリーにある） | 契約 §3、R51、T016 |
| 24 | お気に入りの項目の名前を編集中に、名前を入力してから、ターミナルで `hdiutil attach ~/MediaViewerFavTest/FavTestVol.dmg` を実行する → アプリに戻り ↑↓ キーを押す → もう一度編集を始めて名前を入力し、`hdiutil detach /Volumes/FavTestVol` を実行する | 接続・取り外しのどちらでも、入力した名前で確定してからツリーに「FavTestVol」が現れる（消える）。編集欄が残ったり、ほかの行に編集の見た目が残ったりしない。アプリに戻るとクリックし直さなくても ↑↓ でツリーの選択が動く。「FavTestVol」がツリーに現れない場合は、未確認として T018 の下に残す | R51、T016 |

## 4. 保存内容の確認（任意）

```bash
defaults read local.my-img-viewer.MediaViewer favorites.paths
defaults read local.my-img-viewer.MediaViewer favorites.displayNames
```

期待: `favorites.paths` は登録順のパスだけ。`favorites.displayNames` は名前を変えた項目のパスと名前だけを持ち、
すべて既定の名前に戻すとキーごと消える（[contracts/settings.md](./contracts/settings.md)）。

## 5. 完了の条件

- 1 の自動の検証がすべて成功
- 3 の手動確認がすべて期待どおり（GUI で確かめていない項目があれば、その旨を tasks.md に残す）
- Phase 単位でコミットする
