# Quickstart: 操作の履歴を戻る・進むの検証

AGENTS.md の「Phase の検証ゲート」に沿って確かめる。仕様は [spec.md](./spec.md)、キーとメニューは
[contracts/keyboard-and-menus.md](./contracts/keyboard-and-menus.md)、Core の API は [contracts/core-api.md](./contracts/core-api.md)。

## 1. 自動の検証

```bash
cd /Users/igachan/projects/my_img_viewer
swift build
swift test
swift test --filter MediaViewerCoreTests          # NavigationHistory・HistoryLocation・HistoryNavigator・BrowserModel・ArchiveIndex・PaneCommands
swift test --filter MediaViewerPerformanceTests   # 10,000 ファイルのフォルダへ戻ったときの最初の項目の表示（SC-029）
scripts/check-no-network.sh
```

期待: すべて成功。新しいテストは [data-model.md](./data-model.md) の「テスト」の表の項目を含む。

## 2. 準備（GUI の確認の前に）

```bash
T=~/MediaViewerHistoryTest
mkdir -p "$T/A" "$T/B" "$T/C/Sub" "$T/E" "$T/Locked"
ICON=/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns
for d in A B C C/Sub E; do
  for n in 1 2 3; do sips -s format png "$ICON" --out "$T/$d/photo$n.png" >/dev/null; done
done
# 動画（種類フィルタの確認用）は手元のファイルを置く（例: cp ~/Movies/sample.mov "$T/A/"）
# zip の中の移動の確認用（中にディレクトリを持つ zip）
(cd "$T/C" && zip -qr ../A/album.zip Sub photo1.png)
# 権限のないフォルダ（EC-55）
chmod 000 "$T/Locked"

pgrep -fl MediaViewer   # 残っているプロセスがないこと
scripts/make-app.sh
open .build/MediaViewer.app
```

元に戻すとき: アプリを終了し、26 のボリュームを接続したままなら `hdiutil detach /Volumes/HistVol` を実行してから、
`chmod 755 ~/MediaViewerHistoryTest/Locked && rm -rf ~/MediaViewerHistoryTest`。

## 3. 手動確認（ユーザーに依頼する）

各項目の期待は spec.md の受け入れシナリオ（括弧内の ID）と同じ。

| # | 手順 | 確認すること |
|---|---|---|
| 1 | 起動直後にツールバーを表示する（⇧⌘T） | ツールバーの左端に `<`・`>` のボタングループがあり、どちらも淡色。「移動」メニューが「表示」の右にあり、「戻る」「進む」が淡色（US7-AS9、SC-032） |
| 2 | ツリーで A → B → C を順に選び、⌘[ を2回押す | A の一覧に戻り、ツリーでも A が選択される。`>` が使える（US7-AS1） |
| 3 | 続けて ⌘] を押し、さらにツールバーの `>` を押す | B、C の順に進み、C で `>` が淡色になる（US7-AS2） |
| 4 | C を表示して `Sub` の行を選び、⌘↓ で開いてから ⌘[ | C の一覧に戻り、`Sub` の行だけが選択されている。⌘] で `Sub` に戻る（US7-AS3） |
| 5 | A で「zipファイルを表示」をオンにし、`album.zip` → `Sub` を開いてから ⌘[ を繰り返す | zip の中を1階層ずつ戻り、最後に A の一覧に戻る。ツリーの選択は A のまま（US7-AS4） |
| 6 | A → B → C の後に ⌘[ を2回押し、ツリーで E を選ぶ | `>` が淡色になる（US7-AS5） |
| 7 | A → B → C を選び、ターミナルで `mv "$T/B" "$T/B2"` を実行してから ⌘[ | B を飛ばして A に戻り、「フォルダが見つかりません」は出ない。⌘] で C に進む（US7-AS6、SC-030）。確認後 `mv "$T/B2" "$T/B"` |
| 8 | A を選んでからアプリを再起動し（起動時に A が表示され、履歴は A の1件）、B を選ぶ。B を表示したままツリーで A の行を右クリックして「ゴミ箱に入れる」（確認モーダルで実行） | その時点で `<` と「戻る」が淡色になり、⌘[ は何もしない（US7-AS7）。確認後、ゴミ箱から A を戻す |
| 9 | ツリーで矢印キーを押し続けて 150 回以上フォルダを移り、⌘[ を押し続ける | 99 回で `<` が淡色になる（US7-AS8、SC-031。数えにくければ自動テストの結果で代える） |
| 10 | ツールバーを隠し（⇧⌘T）、⌘[・⌘] を押す | ツールバーを表示しているときと同じに動く（US7-AS10） |
| 11 | A を表示して ⌘F で `photo` を検索し、結果の表示中に ⌘[ | 検索結果の表示が終わり A の一覧に戻る。⌘] で検索結果に戻らない（US7-AS11） |
| 12 | A を選んでからアプリを再起動し、何も選ばずに ⌘F で検索してから、ツリーをクリックしてフォーカスを移し、`<` を見て ⌘[ | `<` は使える状態で、⌘[ で検索結果の表示が終わる。その後 `<` は淡色（US7-AS12） |
| 13 | A をリスト形式で表示し、⌘1 → ⌘[ → ⌘] | リスト形式に戻り、一覧と選択は変わらない。ツールバーの表示形式ボタンと「表示」メニューのチェックが一致する。⌘] でサムネイル形式に戻る（US8-AS1） |
| 14 | サムネイル形式でスライダーを大きくドラッグして離し、⌘[ | ドラッグ前の大きさに1回で戻る（US8-AS2） |
| 15 | ⇧⌘I → ⌘[ | 種類フィルタが両方オフに戻り、動画が一覧に戻る（US8-AS3） |
| 16 | 3ペインのまま仕切りを動かしておき、⌃⌘3 → ⌘[ | 3ペインに戻り、各ペインの幅は切り替え前と同じ（US8-AS4） |
| 17 | A をリスト形式で表示 → ⌘1 → ツリーで B → ⌘[ を2回 | 1回目で A のサムネイル形式、2回目で A のリスト形式になる（US8-AS5） |
| 18 | ⇧⌘T・⌃⌘F（解除も）・⌥⌘1 を行ってから ⌘[ | どれも戻されず、それより前に記録した操作が戻る（US8-AS6） |
| 19 | サムネイル形式で ⌘+ → ⌘[ → ⌘+ | `>` が淡色になり、続けて ⌘[ で元の大きさに戻る（US8-AS7） |
| 20 | `Locked` を選んでから別のフォルダを選び、⌘[ | `Locked` に戻り「アクセスできません」が表示される（飛ばさない。EC-55） |
| 21 | ツリーでフォルダの名前を変えている途中（編集欄が出ている間）と、⌃⌘F のフルスクリーン中に、⌘[・⌘]・`<`・`>`・「移動」メニューを試す | どれも何もしない・淡色（EC-63） |
| 22 | 10,000 ファイルのフォルダ（`scripts/make-fixtures.sh` で作ったもの）と別のフォルダを行き来し、⌘[・⌘] を素早く何度か押す。Instruments（Time Profiler テンプレート）で MediaViewer に接続して記録しながら行う | 最後の移動先の一覧が表示され、操作が止まらない（EC-61）。Instruments の Hangs のトラックに区間が出ず、メインスレッドの CPU の使用が 100ms 以上続けて張り付く区間がない（SC-029。Hangs のトラックが 100ms 未満の停止を報告しない場合があるため、メインスレッドのグラフでも確かめる）。Instruments を使えない場合は、連打の直後に矢印キーでのツリーの選択の移動とファイルリストのスクロールが引っかからないことを目視で確かめ、目視の判定であることを validation.md に書く |
| 23 | VoiceOver を有効にし、ツールバーの `<`・`>` にカーソルを当てる | 「戻る」「進む」と読み上げられ、ツールチップも同じ（FR-112） |
| 24 | 日本語（JIS）キーボードで ⌘[・⌘] を押す | US キーボードと同じに動く |
| 25 | A で「zipファイルを表示」をオンにし、`album.zip` → `Sub` を開く。⌘F で `photo` を検索し、結果の表示中に ⌘[ を押してから、もう一度 ⌘[ を押す。続けて ⌘] | 1回目で検索結果の表示が終わり、Esc と同じく A の一覧に戻る（FR-086）。2回目で zip の中の `Sub` に戻る。⌘] で A の一覧に進み、検索結果には戻らない（FR-113、US7-AS13）。Esc で終えた場合も同じ履歴になる |
| 26 | ターミナルで `hdiutil create -size 20m -fs APFS -volname HistVol "$T/HistVol.dmg" && hdiutil attach "$T/HistVol.dmg" && mkdir /Volumes/HistVol/X` を実行する。ツリーで A → `/Volumes/HistVol/X` を選び、`hdiutil detach /Volumes/HistVol` を実行してから ⌘[ | 取り外しの後に `>` は淡色のまま。⌘[ で A の一覧に戻り、「フォルダが見つかりません」は出ない（X の履歴は取り除かれている。EC-57・EC-65）。続けて、もう一度 attach してボリュームのルート（`/Volumes/HistVol`）を表示したまま detach し、表示がどうなるか（空・`/Volumes` へ移る・「フォルダが見つかりません」）と、`<` の状態・⌘[ の行き先を validation.md に記録する（ルートでは親が存在するため EC-60 の扱いになりうる。research.md の R75） |

## 4. 記録すること

- 3. の各項目の結果（OK / NG と、NG なら再現手順）
- 自動テストの件数と結果、性能テストの実測値（SC-029）
- 22 の 100ms の確認の方法（Instruments か目視か）と結果（SC-029）
- 26 のボリュームのルートを取り外したときの振る舞い
