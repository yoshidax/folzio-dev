# Quickstart: 検索でフォルダも検索対象にするの検証

**Date**: 2026-10-27 | **Branch**: `009-folder-search`

本書は実装後の検証ガイド。操作の契約は [contracts/folder-search.md](contracts/folder-search.md)、型と遷移は [data-model.md](data-model.md)、受け入れ条件は [spec.md](spec.md) を参照する。数値・文言の正本は spec と product の領域。

## 前提

- macOS 15 以降、Swift 6 の開発環境。
- ネットワーク接続・外部パッケージは不要。
- GUI の起動と操作はユーザーが行う。エージェントは build・test・bundle の作成までを行い、起動コマンドと確認点を渡す。
- 検索結果と検索条件は保存しないため、UserDefaults の削除・移行は不要。

## 検証データ

`FixtureSets.folderSearch(in:)` が `folder-search/` を作り、`FixtureSets.makeAll`（`scripts/make-fixtures.sh`）からも呼ばれる。

| 生成先以下 | 内容／用途 |
|---|---|
| `folder-search/Kyoto/` | 起点にするフォルダ（名前が `kyoto` に一致するが行にならない。US15-AS6） |
| `folder-search/Kyoto/2024_Kyoto/IMG_0001.jpg` | 一致するフォルダと、名前が一致しない中のファイル（US15-AS1・AS3） |
| `folder-search/Kyoto/2024_Kyoto_old/` | `*_Kyoto` で一致しないフォルダ（US15-AS2） |
| `folder-search/Kyoto/kyoto_map.png` | 一致するファイル（US15-AS1） |
| `folder-search/Kyoto/kyoto/kyoto_01.jpg`・`kyoto/kyoto_day2/`・`kyoto/IMG_0002.jpg` | 一致したフォルダの中も照合する（US15-AS9、EC-92） |
| `folder-search/Kyoto/.kyoto/`・`Kyoto.app/Contents/`・`kyoto_link`（`2024_Kyoto` へのリンク）・`kyoto.zip` | どれも行にならない（US15-AS6） |
| `folder-search/Kyoto/2024.10_trip/`・`photos.jpg/`（フォルダ） | 「.」を含むフォルダ名（EC-97） |
| `folder-search/Kyoto/east/kyoto_day1/`・`west/kyoto_day1/` | 同じ名前の別の場所のフォルダ（EC-98） |
| `folder-search/Kyoto/clips/kyoto_clip.mov` | 動画と種類フィルタ。`clip` ではフォルダ `clips` と動画だけが一致する（US15-AS4・AS5） |
| `folder-search/Kyoto/locked_kyoto/secret_kyoto.jpg` | 手動で `chmod 000` にする権限なしのフォルダ（EC-33・EC-91）。生成直後は読める |
| `folder-search/.hidden-parent/search-root/kyoto_open/IMG_0003.jpg` | 隠しの祖先の中を検索起点として直接指定し、結果のフォルダを開く。ツリーは `folder-search` を選択・保存する（EC-102） |
| `mixed/`・`search/`・`zip/` | 既存。zip の中で始めた検索（EC-100）と既存の検索の回帰確認 |

```bash
cd /Users/igachan/projects/my_img_viewer
scripts/make-fixtures.sh ~/MediaViewerFixtures
# 権限なしのフォルダの確認（シナリオ 6）の前だけ:
chmod 000 ~/MediaViewerFixtures/folder-search/Kyoto/locked_kyoto
# 確認の後に戻す:
chmod 755 ~/MediaViewerFixtures/folder-search/Kyoto/locked_kyoto
```

## 自動検証と起動ゲート

実装 Phase の終わりに次の順で行う。build/test の失敗を3回直しても解決しない場合は止めて報告する。

```bash
cd /Users/igachan/projects/my_img_viewer
swift build
swift test
scripts/check-no-network.sh
scripts/make-app.sh
```

成功後、ユーザーに次を実行してもらい、3ペインが表示されることを最初に確かめる。起動しない場合は推測で直さず、AGENTS.md の lldb による Objective-C 例外の停止手順をユーザーへ依頼する。

```bash
open .build/MediaViewer.app
```

自動テストで確かめる内容:

| テスト領域 | 確認する条件 | 対応 |
|---|---|---|
| `FileNameSearcher` | `folder-search` で `kyoto` が一致するフォルダとファイルだけを返し、起点・隠し・パッケージ・フォルダへのリンク・zip を返さない。`*_Kyoto`・`2024.10`・`*.jpg` の照合。一致したフォルダの中の照合。権限なしのフォルダが行になり中は辿らない。フォルダの行の値が `DirectoryLister` の行と同じ。`matchesRoot: true` で起点そのものを照合する | US15-AS1・AS2・AS6・AS9、EC-33・EC-91・EC-92・EC-97、FR-139 |
| `FileNameSearcher`（既存の更新） | `search` で `cat` が `cat-folder` を含み、`cat-folder/x.jpg` を含まない（5件）。権限なしのサブフォルダの確認とバッチの合計も `cat-folder` を含む5件に改める。取り消しの既存の確認 | FR-083・FR-085 |
| `SearchVisitLog` | ディレクトリを照合の前に記録する。ファイルは記録しない | R2 |
| `SearchRenameLedger` | 開始後の名前の変更だけを当てる。フォルダの行の名前の付け替え。照合済み・未照合の判定（逆順の戻し、複数の名前の変更、複数の列挙）。未照合の元の場所の結果を捨てる | FR-105、EC-52・EC-94 |
| `BrowserModel`（検索） | 件数がファイルとフォルダの合計。フォルダだけの一致で `.loaded`、0件で `.empty`、メディアがフィルタで残らないとき `.noMatches` でフォルダの行が残る。フォルダの行の選択でプレビューが空・動画が止まる | US15-AS4・AS5・AS10、EC-32・EC-96、FR-139 |
| `BrowserModel`（ツリー同期の完了） | 検索結果から開いた F の同期完了を受け取り、祖先 V を `lastFolder` に保存する。一覧・履歴・フォーカスは F のまま。古い依頼・祖先でない場所・重複・次のナビゲーション後・通常の同期は保存先を変更しない | EC-102、FR-140、T061〜T063 |
| `BrowserModel`（開く） | 検索中・検索後にフォルダの行を開くと列挙が止まり、後から届くバッチが捨てられ、一覧・`treeSyncRequest`・`lastFolder` がそのフォルダ、「場所」の並べ替えが解除される。メディアの行では何もしない | FR-140、US15-AS3、EC-93 |
| `BrowserModel`（ファイル操作・外部の変更） | フォルダの行の名前の変更で行と中の結果が新しい名前・場所になり、並べ直す。索引が新しい URL を持ち、続く外部の削除で外れる。フォルダの消失で行と中の結果が外れ、プレビュー中なら空になる。検索起点そのものが消えると、フォルダの行を含むすべての結果が外れ、検索結果の表示・検索前のフォルダ・`lastFolder`・ツリーの同期の依頼は変わらない | US15-AS7・AS8、EC-35・EC-36・EC-95、FR-087、SC-056 |
| `BrowserModel`（検索中の名前の変更） | 照合済みのフォルダの名前を新しくキーワードに一致する名前に変えても加えない。未照合のフォルダは新しい名前で照合する。照合済みで一致した行は新しい名前で残る | EC-52・EC-94、FR-105 |
| `BrowserModel`（検索後の名前の変更） | 検索が終わった後に、行でないフォルダの名前をキーワードに一致する名前に変えても、行は増えず、追加の列挙も始めない | EC-94 の前半、FR-105 |
| `HistoryNavigator` | A → 検索 → F を開くで A・F が記録され、A の表示の状態が検索終了時のもの。⌘[ で A。A の行を開くと記録なし、⌘[ は A より前・なければ無効。zip の中 D → 検索 → F で D・F、⌘[ で D | FR-113、EC-99・EC-100、SC-055 |
| `BrowserModel.leaveTrashedFolders(_:origin:)` | 検索結果の表示中に `origin: .fileList` で検索前のフォルダの祖先を渡すと false を返し、検索結果の表示・`listing.folder`・`lastFolder` が変わらず、続く `reloadCurrentFolder()` で行と中の結果が外れる。`origin: .tree` では従来どおり親へ移る。検索結果の一覧からの移動（`leaveTrashedFolders` を呼ばずに `reloadCurrentFolder()`）でも同じく表示が続く。どちらも続く `selectFolder(listing.folder)`（Esc）で `.notFound` になり、`HistoryNavigator` の `goBack()`（⌘[）では `.notFound` になって検索前の場所と配下が履歴に残らない | EC-101、EC-62、FR-079・FR-109、R8 |
| 性能 | SC-016 の階層で、フォルダも照合する検索が 3 秒以内。フォルダの行を含む 10,000 件の結果での名前の変更が既存の基準内 | SC-054、憲章 II |
| フィクスチャ | `folder-search/` の構成と、SC-053 の件数の生成 | 検証データ、SC-053 |

## 手動シナリオ

### 1. フォルダとファイルの一致（US15-AS1・AS2・AS6・AS9・AS10、EC-97・EC-98、SC-053）

1. ツリーで `folder-search` を選び、⌘F で検索のモーダルを開く。キーワード `kyoto`、起点に `folder-search/Kyoto` の絶対パスを入れて検索する。
2. 一覧に `2024_Kyoto`・`2024_Kyoto_old`・`kyoto_map.png`・`kyoto`・`kyoto_01.jpg`・`kyoto_day2`・`kyoto_day1`（2行）・`kyoto_clip.mov`・`locked_kyoto`・`secret_kyoto.jpg` が出る。`Kyoto`（起点）・`.kyoto`・`Kyoto.app`・`kyoto_link`・`kyoto.zip`・`IMG_0001.jpg`・`IMG_0002.jpg` は出ない。
3. フォルダの行は汎用フォルダのアイコン、種類「フォルダ」、作成日を持つ。「場所」列はそのフォルダを含むフォルダ（例 `Kyoto/east`）。2つの `kyoto_day1` は「場所」で見分けられる。サムネイル形式（⌘1）では場所がツールチップに出る。
4. 検索バーの件数が一覧の行数（ファイルとフォルダの合計）と一致する。
5. 「名前」「作成日」「種類」「場所」で並べ替える。ファイルとフォルダが区別されずに混ざって並ぶ。
6. キーワード `*_Kyoto` で検索し、`2024_Kyoto` だけが出る（`2024_Kyoto_old` は出ない）。`2024.10` で `2024.10_trip`、`*.jpg` で `photos.jpg`（フォルダ）とファイルの `.jpg` が出る。
7. 一致がフォルダ1件だけになるキーワード（例 `2024.10`）で、該当する項目がない旨のメッセージが出ない。何も一致しないキーワードで「該当する項目はありません」が出る。

### 2. フォルダの行を開く（US15-AS3、EC-93、SC-055）

1. ツリーで `folder-search/Kyoto/east` を表示してから、起点 `folder-search/Kyoto` で `kyoto` を検索する。
2. `2024_Kyoto` の行をダブルクリックする。検索バーが消え、ファイルリストは `2024_Kyoto` の一覧（先頭に `..`）になり、ツリーでも `2024_Kyoto` が選択される。キーボードフォーカスはファイルリストに残る（続けて矢印キーで一覧を移れる）。
3. ⌘[ を押す。`east` の一覧に戻り、検索結果には戻らない。⌘] で `2024_Kyoto` へ進む。
4. 同じ検索をして、`kyoto_day2` を選んで ⌘↓、別の検索で右クリックメニューの「中を表示」でも同じ結果になることを確かめる。右クリックメニューのフォルダの行には「中を表示（⌘↓）」と区切り線がファイル操作の前にあり、「上の階層へ」は出ない。メディアの行では ⌘↓ は何もしない。メディアの行の右クリックメニューに「中を表示」が出るかどうかは、既存の契約と実装の食い違い（research.md R6 の注記）のため合否の条件にせず、見えた状態を記録だけする。この記録をもとに、product への反映の前に tasks の T059 で扱い（bug の候補か、別の feature の候補か）をユーザーに確認し、「最終検証結果」に記録する。
5. ホームなど大きなフォルダを起点に検索し、検索中（スピナー表示中）にフォルダの行を開く。検索が止まり、開いたフォルダの一覧に後から結果が混ざらない。
6. 開いた後に `lastFolder` が保存されていることを、アプリを終了・起動して開いたフォルダが表示されることで確かめる。
7. ダブルクリック・⌘↓・「中を表示」を合わせて20回行い、毎回ファイルリストは開いたフォルダ、ツリーはそのフォルダ（表示されない場合は EC-102 の祖先）になり、⌘[ で検索前の場所に戻ることを記録する（SC-055）。

8. EC-102: `folder-search/Kyoto/east` を表示してから、検索起点に `folder-search/.hidden-parent/search-root` の絶対パス、キーワードに `kyoto` を指定する。`kyoto_open` の行を開くと、一覧には `kyoto_open` の内容が表示され、ツリーは表示できる最も近い祖先の `folder-search` を選択する。フォーカスはファイルリストに残る。⌘[ で `east` へ戻り、⌘] で開いた `kyoto_open` へ戻れること（祖先が履歴に挿入されないこと）を確認する。保存先は `open` で起動したアプリのドメインに対し `defaults read local.my-img-viewer.MediaViewer` で確認し、開いた直後の同期完了後に最後のフォルダが `folder-search` であることを記録する（設定は変更しない）。この経路による保存を確認するため、再検索して `kyoto_open` を開き、同期が終わってからアプリを終了・再起動して `folder-search` が復元されることも確かめる。

### 3. 履歴の特殊な場合（EC-99・EC-100）

1. ツリーで `folder-search/Kyoto/kyoto` を表示し、表示形式をリストにする。起点 `folder-search/Kyoto` で `kyoto` を検索し、検索結果の表示中にサムネイル形式へ変える。
2. `kyoto` の行（検索前の場所と同じ）を開く。`kyoto` の一覧がサムネイル形式で表示され、ツールバーの「進む」は無効のまま。⌘[ で `kyoto` より前の履歴へ移る（履歴がなければ「戻る」は無効）。
3. `zip/` の zip を開いて中の階層を表示し、⌘F で起点に zip を含むフォルダより上（例 `~/MediaViewerFixtures`）を入れて `kyoto` を検索する。フォルダの行を開いてから ⌘[ を押す。zip の中の階層へ戻り、zip を含むフォルダの一覧を経由しない。

### 4. プレビュー・フルスクリーン・スライドショー・種類フィルタ（US15-AS4・AS5、EC-96、SC-057）

1. `kyoto` の検索結果で `kyoto_clip.mov` を再生し、矢印キーでフォルダの行へ選択を移す。プレビューが空になり、再生が止まる。フォルダの行を20回選び、毎回プレビューが空になることを記録する。
2. 画像を選んでフルスクリーン（⌃⌘F）にし、↑ / ↓（サムネイル形式では ← / → も）で移動する。フォルダの行に止まらずに飛ばす。
3. 検索結果でスライドショー（⇧⌘S）を開始する。フォルダの行は表示されない。
4. 「画像のみ表示」（⇧⌘I）をオンにして、キーワード `clip` で検索する（フォルダ `clips` と動画 `kyoto_clip.mov` だけが一致する）。`clips` の行は表示され、動画は表示されず、「画像のみ表示中: 該当するファイルはありません」が出る。
5. 一致がフォルダだけのキーワード（`2024.10`）で「画像のみ表示」をオンにしても、メッセージは出ない。

### 5. ファイル操作と外部の変更（US15-AS7・AS8、EC-35・EC-95・EC-101、SC-056）

1. `kyoto` の検索結果で `kyoto` フォルダの行を選び、Return で名前を `zzz` に変える。行は `zzz` として残り、`kyoto_01.jpg`・`kyoto_day2` の「場所」が `Kyoto/zzz` になる。「名前」で並べ替え中なら位置が変わる。プレビュー中の項目と選択は保たれる。10回繰り返し、古い名前のまま残った項目が0件であることを記録する。
2. `2024_Kyoto` を選び ⌘Delete でゴミ箱に入れる。行が消える。`kyoto_01.jpg` をプレビュー中に `kyoto`（または名前を変えた `zzz`）をゴミ箱に入れると、行と中の結果がすべて消え、プレビューが空になる。10回繰り返し、残った件数が0件であることを記録する。Finder のゴミ箱から戻しても一覧に加わらない。
3. Finder で、一覧にあるフォルダの行のフォルダを別の場所へ移動する。行と中の結果が消える。Finder で新しく `kyoto_new` フォルダを作っても一覧に加わらない。
4. フォルダの行を ⌘C でコピーし、⌘V・⌥⌘V が淡色で何もしないことを確かめる。⌘D でフォルダを複製しても一覧に加わらない。フォルダの行をツリーのフォルダへドラッグして移動すると、行と中の結果が消える。
5. ツリーで `folder-search/Kyoto/east` を表示し、起点 `folder-search/Kyoto` で `east` に一致するキーワード（例 `east`）を検索する。一覧の `east` の行（検索前のフォルダ）を ⌘Delete でゴミ箱に入れる。行が消え、検索結果の表示が続く。ツリーが読み直されて `east` の行が消えた後も、ツリーで別のフォルダ（親の `Kyoto` や隣の `west` など）が選ばれた状態にならず、検索バーが残って検索結果の表示が続くことを、数秒待ってから確かめる（ツリーの選択が別の行へ移ると、ツリーからの選択として一覧がそのフォルダに切り替わり、検索結果の表示が終わる。Core の自動テストではこの経路を確かめられない。崩れた場合は tasks の T060 で扱う）。続けて Esc を押すと「フォルダが見つかりません」になる（EC-101。2026-10-27 にユーザーが採用済み）。比較のため、`scripts/make-fixtures.sh ~/MediaViewerFixtures` で作り直してから同じ検索をし、今度はツリーで `east` をゴミ箱に入れると、親フォルダへ移って検索結果の表示が終わる（FR-079）。
6. もう一度 `scripts/make-fixtures.sh ~/MediaViewerFixtures` で作り直し、5 と同じく `folder-search/Kyoto/east` を表示して `east` を検索する。一覧の `east` の行を、ツリーの `folder-search/Kyoto/west` へドラッグして移動する。行が消え、検索結果の表示が続き、ツリーの選択は変わらない（5 と同じく、ツリーの読み直しの後に別のフォルダが選ばれた状態にならず、検索バーが残ることを数秒待ってから確かめる。崩れた場合は tasks の T060 で扱う）。続けて ⌘[ を押すと「フォルダが見つかりません」になり、⌘] で検索結果にも `east` にも戻らない（EC-101 の移動。2026-10-27 にユーザーが採用済み）。

### 6. 権限のないフォルダ・検索中の名前の変更（EC-33・EC-52・EC-91・EC-94）

1. `locked_kyoto` を `chmod 000` にして `kyoto` で検索する。`locked_kyoto` の行は出るが、`secret_kyoto.jpg` は出ない。行を開くと「アクセスできません」になり、`..` で戻れる。確認の後に `chmod 755` で戻す。
2. ホームなど大きなフォルダを起点に、まだ照合されていないと思われる深い場所のフォルダ名と一致するキーワードで検索し、検索中にツリーでそのフォルダの名前を変える。検索は止まらず、名前を変える前に見つかった項目は新しい場所で残る。照合済みのフォルダを、キーワードに一致する名前に変えても一覧に加わらない。

### 7. 性能（SC-054）

1. 検索の完了時間は T024 の自動試験で測る。SC-016 と同じ 10,000 ファイルの階層を使い、フォルダ50件と一致したファイルの件数を確認し、`ContinuousClock` による実測が 3 秒以内であることを記録する。以下の Instruments での記録は UI 応答の確認に使い、計測による負荷がある完了時間とは分けて記録する。
2. ユーザーが `.build/MediaViewer.app` を起動し、Instruments の Time Profiler でその MediaViewer プロセスを対象にする。Hangs instrument の検出しきい値を 100ms より小さく設定する（設定例: `Include All Potential Interaction Delays`、33ms 超）。既定の 250ms のままでは SC-054 の 100ms を検証できない。設定名が異なる場合も、100ms 未満の遅延を記録できる設定であることを確認する。
3. 記録を始めてから、10,000 ファイル以上を含む検証用の階層を起点に、フォルダ名にも一致するキーワードで検索する。検索中にスクロール・選択・プレビュー・ツリーの操作を行い、目視でも応答を確認する。検索が短時間で終わる場合は同じ条件の検索を繰り返し、各操作を検索中に行った記録を揃える。
4. 検索開始から完了までの区間について、Hangs の各イベントの継続時間を確認し、100ms 以上のイベントが0件であることを合格条件にする。trace は `.build/` 内に保存し、そのパス、Instruments のバージョン・しきい値、測定した操作、検索回数、100ms 以上のイベント件数と最大継続時間（イベントがなければ「検出なし」）を「最終検証結果」に残す。計測環境が使えない・区間や操作を確認できない場合は未検証とし、目視だけで SC-054 を合格にしない。

検出しきい値の根拠: Apple の [Reducing main thread work by doing less](https://developer.apple.com/tutorials/instruments/reducing-main-thread-work-by-doing-less)。Hangs の検出結果で UI の停止時間を確認し、スレッドがイベント待ちで休止している時間を停止として数えない。

## 完了の判定

- 自動テストがすべて通り、`scripts/check-no-network.sh` が通る。
- 3ペインの起動スモークと、上の手動シナリオのうち GUI が必要なものをユーザーが確認する。
- GUI が未確認なら、該当タスクを未チェックのまま残し、判定を `partial` にする。
- 実装と検証が終わった後にだけ、spec の「反映先」の表に従って `specs/product/` を更新する。本 feature の spec・plan・research・data-model・contracts・quickstart は実装の記録として凍結する。


## Phase 検証記録

### 2026-10-27 — 設計の引き継ぎ・ユーザー判断（T001）

- EC-101: ユーザーが「ゴミ箱・移動とも提案を採用」を選択。検索結果から検索前の場所自身・祖先を操作しても検索表示を続け、消えた結果だけを外す。Esc・⌘[ は「フォルダが見つかりません」、その場所は履歴に記録しない。ツリーからのゴミ箱は従来どおり親へ移る。
- EC-102: ユーザーが「一覧は開いた先、ツリーは表示可能な最も近い祖先を選び保存」を選択。spec・plan・research R10・data-model・contracts・T061〜T063・手動シナリオ 2-8 に反映。
- 実装・build・test・GUI はこの記録では未実施。T001 のユーザー確認だけが完了している。元のランナー `f7431e69` は `failed` のまま保持し、このセッションで手動引き継ぎ中。

### 2026-10-27 — Phase 1（T002〜T005）

- `FixtureSets.folderSearch(in:)` と `folderSearchScale(in:matchingFolders:matchingFiles:otherFolders:excludedEach:)` を追加し、`makeAll` から `folderSearch(in:)` を呼ぶ形にした。`FixtureSets.search`・`mixed`・`zip` などの既存の生成内容は変えていない。
- `Tests/MediaViewerCoreTests/FolderSearchFixtureTests.swift` を追加（3 テスト）。quickstart の「検証データ」の構成、`kyoto_link` の行き先、`locked_kyoto` が生成直後に読めること、`folder-search-scale/kyoto_root/` の 50・50・50・各5 と件数の引数変更を確認した。
- `scripts/make-fixtures.sh .build/FolderSearchFixtures` を実行し、`.build/FolderSearchFixtures/folder-search/Kyoto/` が「検証データ」の表と一致することを `ls -la` で確認した（`.kyoto`・`Kyoto.app`・`kyoto_link -> 2024_Kyoto`・`kyoto.zip`・`photos.jpg` を含む）。外部ツール（`cwebp`・`img2webp`）の追加は不要だった。
- 自動ゲート: `swift build` 成功、`swift test` 700 テスト成功、`scripts/check-no-network.sh` 成功（`no network API references in Sources`）、`scripts/make-app.sh` 成功（`.build/MediaViewer.app` を作成）。
- 未実施: T006 の GUI 確認（3ペイン・既存の検索の回帰）、T007 のコミット。GUI はセッションでは実行していないため、T006 を未チェックに保つ。

### 2026-10-27 — Phase 2・3（T008〜T032、US15 の検索結果にフォルダを混ぜる）

- `SearchRequest`（`root`・`pattern`・`matchesRoot`・`visits`）と `SearchVisitLog`（ロック付きの記録）を追加し、`FileNameSearcher` を `search(_:)` に変えた。列挙はディレクトリを照合する直前に記録し、名前が一致したフォルダは `DirectoryLister.folderRow` と同じ値の行として返す。隠し・パッケージ・フォルダへのリンク・zip・起点は行にしない。
- 検索結果の URL は起点の形に組み直す（`rebaser`）。`standardizedFileURL` は macOS で `/private` を外して `/var/...` にするため、起点の形（`/private/var/...`）と履歴・一覧の URL が食い違う問題があり、`SearchPath.normalized`（`/private` を外さない正規化）を追加して記録と比較に使うようにした。
- 既存の `FileNameSearcherTests` の件数（cat の 4 → 5）・権限なしの期待値を更新し、フォルダの照合・ワイルドカード・`locked_kyoto`・行の値・`matchesRoot`・SC-053（50 + 50 = 100 件）のテストを追加した。`DirectoryLister.folderRow` のテストも追加。
- `BrowserModelSearchTests` にフォルダの行の件数・状態・種類フィルタ・フォルダへのフォーカス（プレビューが空になり再生が止まる）・並べ替え・`..` の行がないことを追加した。
- `FocusNavigatorTests` と `SlideshowSequenceTests` は、フォルダとメディアが混ざった並びを既に確かめているため追加していない（T023 にテスト名を記した）。
- 自動ゲート: `swift build` 成功、`swift test` 715 テスト成功、`swift test --filter MediaViewerPerformanceTests` 26 テスト成功（SC-054 の実測 0.71 秒）、`scripts/check-no-network.sh` 成功、`scripts/make-app.sh` 成功。
- 進め方の記録: Phase 2 と Phase 3 は、`FileNameSearcher` のフォルダの照合（T025）と、それに伴う既存テストの期待値の更新（T019）を分けて検証できないため、まとめて実装し、T016 と T029 のゲートを1回で通した（T016 はこの記録をもって完了とした）。
- 未実施: T017・T030（GUI）、T018・T031（コミット）。

### 2026-10-27 — Phase 4（T032〜T063、フォルダの行を開く・履歴・ツリー同期）

- `LocationEvent.openedSearchResultFolder(leavingFocus:)` を追加し、検索結果のフォルダはその通知で開く。`HistoryNavigator` は通知で現在の履歴の表示の状態を更新してから、同じ場所なら記録せず、違えば記録する（EC-99・EC-100）。
- `BrowserModel.completeSearchResultTreeSync(_:selectedFolder:)` を追加し、`DirectoryTreeViewController.syncSelection` の選択後に呼ぶ。保留 ID・依頼・一覧の場所・検索結果/zip/`.notFound` でないこと・選択先がフォルダ自身か祖先（pathComponents）であることを確かめ、`lastFolder` だけを更新する（EC-102）。保留 ID は `resetForNavigation` で消す。
- テスト: フォルダの行を開く（検索中・終了後・並べ替えの復帰・メディアの行・通知の種類・権限なし）、EC-99/EC-100/開く直前の削除（`HistoryNavigatorTests`）、EC-102 の 6 ケースを追加。
- 自動ゲート: `swift build` 成功、`swift test` 730 テスト成功、`scripts/check-no-network.sh` 成功、`scripts/make-app.sh` 成功。
- 未実施: T037（GUI）、T038（コミット）。

### 2026-10-27 — Phase 5（T039〜T052、ファイル操作・外部の変更・検索中の名前の変更）

- `SearchRenameLedger`（列挙ごとの `SearchVisitLog`・名前の変更・未照合として扱った変更）を追加し、`RenamedFolder.reversed` を足した。`BrowserModel` は `searchRenames` を台帳に置き換え、追加の列挙は照合済みなら `matchesRoot: false`、未照合なら `true` で始める（EC-94）。
- `rebaseSearchIndex` のキーが変わらない分岐でも `moved` を当てるようにし、名前を変えたフォルダ自身の行も新しい URL・名前になった（R4）。
- `leaveTrashedFolders(_:origin:)` を追加し、検索結果の一覧（`.fileList`）からのゴミ箱では検索結果の表示を続ける（EC-101）。`FileOperationCoordinator` は経路を渡すだけにした。
- テスト: `SearchRenameLedgerTests` 6 件、`RenamedFolderTests` に `reversed`、`BrowserModelSearchTests` に名前の変更（行・中の結果・削除・外部の移動・複製・起点の外・終了後）、EC-101（ゴミ箱・移動・ツリーとの違い）、EC-36 を追加。`HistoryNavigatorTests` に EC-101 の ⌘[ と履歴を追加。性能テストの didRenameFolder はフォルダの行（名前を変える行 + 100 件）を含めて 3 回測り、中央値 0.054 秒（0.1 秒以内）。
- 自動ゲート: `swift build` 成功、`swift test` 753 テスト成功、`swift test --filter MediaViewerPerformanceTests` 26 テスト成功、`scripts/check-no-network.sh` 成功、`grep -rn "import AppKit" Sources/MediaViewerCore` は 0 件、`scripts/make-app.sh` 成功。
- 注意: 性能テストは、`scripts/make-app.sh` の Release ビルドや全テストを同時に走らせると中央値が 0.1 秒を超えて落ちることがある（実測 0.078 秒までは通る）。ゲートでは他のビルドやテストを同時に走らせないこと。

### 2026-10-27 — Phase 6 のうち T053・T054（README・最終の自動ゲート）

- `README.md` の検索の箇条を「名前の検索（ファイル名とフォルダ名）」に直し、フォルダの行・除外・件数・開き方と ⌘[・ファイル操作・EC-101・0 件のメッセージ「該当する項目はありません」を追記した。キーボードの表にフォルダの行を開く行を足した。
- 自動ゲート（T054）: `swift build` 成功、`swift test` 753 テスト成功、`swift test --filter MediaViewerPerformanceTests` 26 テスト成功（SC-054 の実測 1.38 秒・didRenameFolder の中央値 0.054 秒）、`scripts/check-no-network.sh` 成功（`no network API references in Sources`）、`grep -rn "import AppKit" Sources/MediaViewerCore` は 0 件、`scripts/make-app.sh` 成功。
- 未実施: T055（GUI での成功基準の記録）、T059（右クリックメニューの扱いの確認。T037 の GUI の結果が必要）、T056（`specs/product/` への反映。T054・T055 の合格が条件）、T051・T052・T058（Phase 5・最終の GUI とコミット）。T060 は T051 の結果待ちのため未チェックのまま。

### 実装時の判断（T057 の照合に向けた記録）

- data-model.md §3・T043 は台帳のパスの比較を「`standardizedFileURL.path`」としているが、macOS の `standardizedFileURL` は `/private/var/...` を `/var/...` に変えるため、`FileNameSearcher` が記録する「起点の形」のパスと形が食い違い、`hasVisited` が常に false になる（`/private/var/...` を起点にした検証で実際に落ちた）。実装では `/private` を外さずに `.`・`..`・末尾の `/` だけを畳む `SearchPath.normalized` を `Sources/MediaViewerCore/Search/SearchRequest.swift` に追加し、記録と比較をこれにそろえた。設計文書の文言を直すかは T056（`specs/product/` への反映）とあわせて確認する
- `rebaser` も同じ理由で `standardizedFileURL` ではなく `SearchPath.normalized` を起点のパスに使い、`/private` の有無を入れ替えた形も受け付ける。これにより、検索結果の URL は起点・履歴・一覧と同じ形になる

## 最終検証結果

### 2026-10-27 — GUI の確認（T006・T017・T030・T037・T051）

- ユーザーが `scripts/make-fixtures.sh ~/MediaViewerFixtures` と `open .build/MediaViewer.app` を実行し、3ペインの表示と、本 feature の手動シナリオ（フォルダとファイルが混ざる検索結果・除外・件数・0件のメッセージ・フォルダの行を開く・⌘[ で戻る・名前の変更・ゴミ箱・Finder での移動・検索中の名前の変更・検索結果の一覧からの EC-101 とツリーとの違い）を確認し、「問題なかった」と報告した（2026-10-27）。不合格の報告はなかった。
- 環境: macOS（`darwin`、Apple Silicon）・ `.build/MediaViewer.app`（`scripts/make-app.sh` の Release ビルド）・フィクスチャは `~/MediaViewerFixtures`（`scripts/make-fixtures.sh` の既定）。

### T055（成功基準の回数・実時間）— 確認済み

- 2026-10-28 にユーザーから、依頼した操作はそれぞれ1回ずつ行い問題なかったと報告を受けた。その時点では反復回数と Instruments による計測が揃わなかったため、T055 を未チェックのままにした。
- 2026-10-28、ユーザーは残りの操作確認について「確認も終わり問題は発生しませんでした」と一括報告した。依頼した残りの反復確認（開く・戻る各20回、名前変更・ゴミ箱各10回、フォルダ選択・スライドショー各20回）を完了し、問題がなかったとの一括報告。各回数と失敗件数の個別の数値報告はない。
- 同日の自動テストでは、フォルダとファイルの検索は 0.518 秒（フォルダ 50 件、ファイル 5000 件）で完了した。
- Instruments 27.1 (27A9275)、macOS 26.6.2、対象 PID 90025 の trace を `.build/folder-search-ui-hangs.trace` に保存。しきい値 33ms、全記録 2分05秒中の Hangs は73件、100ms以上が2件（開始 01:48.952 に 119.60ms、01:49.072 に 102.55ms）。検索の実行区間、各操作との対応および検索回数は未確認のため、当時は検索中の100ms以上の停止が0件か判定保留とし、T055 を未完了とした。
- ユーザーは上記時刻に検索を実行していた可能性が高いと報告（確定ではない）。ユーザーは検索中にサムネイルサイズを変更したと報告した。同時刻のメインスレッドのサンプルにはサムネイル一覧のレイアウト更新とサイズ変更の処理が見られる。前後2秒の CPU サンプルに検索処理は見つからず、検索の実行区間を示す記録は確認できていない。
- 再計測: `.build/folder-search-ui-hangs_2.trace` の run 2（2026-10-28 21:51、約68秒）。Instruments 27.1、検出しきい値33ms、対象 MediaViewer PID 90025。実行ファイル SHA-256 `f44bac6fe463d81e4d16fb7c86a1be7ff4dbc2adc988cde614207b2e298e773d`。記録全体で検出19件、最大78.55ms、100ms以上0件。検索3回（ユーザー報告）。検索中のスクロール・選択・プレビュー・ツリー操作の確認を依頼し、ユーザーからその他の確認も終了し問題なしと一括報告を受領。記録全体で100ms以上の停止なし。
- 自動試験の SC-053（100件）・SC-054（検索 1.38 秒、所要 3 秒以内）は通っている（Phase 5・T054 の記録）。

### T059（右クリックメニューの契約との食い違い）— 判断済み

- `Sources/MediaViewerApp/FileList/FileContextMenu.swift` は「中を表示」を常にメニューへ加え、`autoenablesItems` と `validateMenuItem` で可否を決める。そのためメディアの行でも項目が淡色で出る。`specs/product/contracts/keyboard-and-menus.md`（右クリックメニュー（ファイルリスト））と FR-140 は「フォルダ・zip ファイルの行にだけ加える」と定める。
- 2026-10-28 にユーザーが、既存の契約を維持し、統合後に bug 拡張で修正する方針を選択した。本 feature では実装を変えず、bug 拡張の候補を次に記録する。slug 案: `context-menu-open-container-for-media-rows`、症状: メディアの行の右クリックメニューに「中を表示」が淡色で出る、該当 ID: FR-140、`specs/product/contracts/keyboard-and-menus.md` の「右クリックメニュー（ファイルリスト）」。契約の文言を実装に合わせる場合は、sdd-increment の候補とする。

### コミットの記録（T007・T018・T031・T038・T052）

- ブランチ `009-folder-search` に4つのコミットを作った。`f9b224b`（spec・plan・tasks）、`b05eab4`（Phase 1 のフィクスチャとテスト、T007）、`4cd940a`（Phase 2〜5 の実装とテスト。T018・T031・T038・T052）、`31043ac`（README）。
- Phase 2 と 3 をまとめて実装・検証したため（上の Phase 2・3 の記録）、T018・T031・T038・T052 は1つのコミット `4cd940a` にまとめた。Phase ごとの分割はしていない。`git push` は行っていない。

### T060 の判断

- T051 の確認で手動シナリオ 5-5・5-6 に不合格の報告がなかったため、条件付きの修正は不要。
