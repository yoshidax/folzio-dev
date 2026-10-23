# Data Model: 3ペイン型メディアビューア

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-19（zip ファイルの表示制御: 2026-10-23、zip 対応・ファイルリストのフォルダ・ツリーのフォルダのゴミ箱: 2026-10-21）

型はすべて `MediaViewerCore` に置き、AppKit に依存しない。永続化するのは表示設定と動作オプションだけで
（[contracts/settings.md](./contracts/settings.md)）、それ以外はファイルシステムから都度読み出す。

## MediaKind

対応形式の判定結果。拡張子だけで判定し、大文字小文字は区別しない（FR-009）。

| 値 | 拡張子 | 区分 |
|----|--------|------|
| `jpeg` | jpg, jpeg | image |
| `png` | png | image |
| `gif` | gif | image |
| `webp` | webp | image |
| `mp4` | mp4 | video |
| `mov` | mov | video |

- `MediaKind(fileExtension:)` は上の表以外の拡張子に対して `nil` を返す。`nil` のファイルはリストに表示しない（FR-008）
- `isVideo` プロパティで画像と動画を区別する
- zip ファイル（.zip）は `MediaKind` に含めない。一覧の行の種類は `ListItemKind` で表す

## ListItemKind（ファイルリストの行の種類・永続化しない）

ファイルリストの1行が何を表すか（FR-068〜070・075〜077、research.md R23・R29・R30）。

| 値 | 出る場所 | 説明 |
|----|----------|------|
| `.media(MediaKind)` | 通常のフォルダ・zip の中 | 対応メディアファイル。プレビュー・縮小画像・種類フィルタの対象 |
| `.archive` | 通常のフォルダ | zip ファイル（拡張子 .zip、大文字小文字を区別しない）。開くと zip の中の最上位を表示する |
| `.folder` | 通常のフォルダ | サブフォルダ（隠しフォルダ・パッケージを除く。ツリーの `subfolders(of:)` と同じ判定）。開くとそのフォルダの一覧へ移り、ツリーの選択を同期する。ファイル操作の対象 |
| `.directory` | zip の中 | zip の中のディレクトリ。開くとその中を表示する。読み取り専用 |
| `.parent` | 先頭行（zip の中、および ツリーのルート以外の通常のフォルダ） | `..`。開くと1つ上の階層へ戻る。並べ替えの対象にせず、常に先頭に置く。ファイル操作の対象にしない |

| プロパティ | 型 | 値 |
|------------|----|----|
| `isMedia` | Bool | `.media` のときだけ true |
| `mediaKind` | MediaKind? | `.media` のときだけその値 |
| `isVideo` | Bool | `.media` の動画のときだけ true |
| `opensAsContainer` | Bool | `.archive` / `.folder` / `.directory` / `.parent` で true（ダブルクリック・⌘↓ で開ける） |

## FolderNode（ツリーのノード）

| フィールド | 型 | 説明 |
|------------|----|------|
| `url` | URL | フォルダの場所（同一性のキー） |
| `name` | String | 表示名（ボリュームの場合はボリューム名） |
| `kind` | `.home` / `.volume` / `.folder` | ルートの種類 |
| `children` | `[FolderNode]?` | `nil` は未読み込み。展開時に読み込む |
| `accessState` | `.unknown` / `.accessible` / `.denied` / `.unavailable` | 読み取り可否（エッジケース）。`.denied` は権限なし、`.unavailable` は権限以外の理由（応答なし・取り外し等）で展開時に読めなかった状態で、再展開で読み直す |
| `subfolderState` | `.unknown` / `.present` / `.absent` / `.failed` | サブフォルダの有無。既定は `.unknown`（未確認）。永続化しない（FR-054・055） |
| `isExpandable`（計算） | Bool | `accessState != .denied` かつ `subfolderState` が `.present` または `.failed`。開閉の三角の表示と、展開できるかの判断に使う |

- 子に含めるのはフォルダだけで、隠しフォルダとパッケージ（`.app` 等）は除く（FR-006）
- 並び順は名前の自然順（数字を数値として比較）
- ルートはホームフォルダ + マウント中のボリューム（FR-004）。ボリュームは取り外し通知で削除する
- `kind` はルートの種類の判定に使い、ツリーの行頭アイコンの選択にも使う（`IconPresentation`、FR-047）
- サブフォルダの有無の判定条件は `children` と同じ（隠しフォルダ・パッケージは数えない）。確認するのは
  ツリーに表示されているノードだけで、その直下1階層だけを調べる（FR-055、research.md R19）

### サブフォルダの有無の状態遷移

| 現在 | 契機 | 結果 | 三角 |
|------|------|------|------|
| `.unknown` | 確認の結果が `true` | `.present`、`accessState = .accessible` | 出す |
| `.unknown` | 確認の結果が `false` | `.absent`、`accessState = .accessible` | 出さない |
| `.unknown` | 確認が `.accessDenied` で失敗 | `accessState = .denied` | 出さない |
| `.unknown` | 確認が `.notFound` / `.other` で失敗 | `.failed` | 出す |
| `.present` / `.failed` | 展開して子が1件以上 | `.present`、`accessState = .accessible` | 出す |
| `.present` / `.failed` | 展開して子が0件 | `.absent`（折りたたむ） | 出さない |
| `.present` / `.failed` | 展開時の読み込みが `.accessDenied` で失敗 | `accessState = .denied`、`children = []` | 出さない |
| `.present` / `.failed` | 展開時の読み込みが `.notFound` / `.other` で失敗 | `accessState = .unavailable`、`.failed`、`children = nil`（折りたたみ、次の展開で読み直す） | 出す |
| 任意 | 外部の変更（FR-042）の通知 | 折りたたみ中は再確認、展開中は子を読み直して上の規則を適用 | 結果に従う |

- `FolderNode.applySubfolderProbe(_ result: Result<Bool, ListingError>)` が確認結果の行を、
  `FolderNode.applySubfolderListing(_ result: Result<Int, ListingError>)` が展開時の読み込みの行を担う
- `.denied` と `.unavailable` の行は、どちらも既存の「アクセスできません」の表示（グレーの文字とツールチップ）にする。
  ドロップ先の判定（`accessState != .denied`）は変えないため、`.unavailable` のフォルダにはドロップでき、失敗は FR-026 で伝える
- 子を読み直すとき、同じ URL の既存ノードの `subfolderState` と `accessState` は引き継ぎ、新しく現れた子だけを
  `.unknown` から確認する

## FolderDisclosure（ツリーのダブルクリック開閉・永続化しない）

| 入力 | 型 | 説明 |
|------|----|------|
| `isExpandable` | Bool | `FolderNode.isExpandable` |
| `isExpanded` | Bool | ダブルクリック時点で展開中か |

| 条件 | 結果 |
|------|------|
| `isExpanded == true` | `.collapse` |
| `isExpanded == false` かつ `isExpandable == true` | `.expand` |
| それ以外（確認中・サブフォルダなし・権限なし） | `.none`（選択だけが行われる） |

- ダブルクリックの対象は行全体（アイコンとフォルダ名）。1回目のクリックでの選択は既存の経路で行う（FR-053）

## FavoriteFolders（お気に入りの登録内容・永続化）

ツリー最上部の「お気に入り」の下に並べるフォルダの一覧（FR-061〜067、research.md R21）。`SettingsStore.favorites` に
保存し、次回起動時に復元する（キー `favorites.paths`、[contracts/settings.md](./contracts/settings.md)）。

| フィールド | 型 | 説明 |
|------------|----|------|
| `urls` | `[URL]` | 登録順（新しいものを末尾）。同一性は `standardizedFileURL.path` で判定し、重複を持たない |

| 操作 | 結果 |
|------|------|
| `add(url)`（未登録） | 末尾に追加して `true` |
| `add(url)`（登録済み。末尾の `/`・`..` の違いを含む） | 変更せず `false`（FR-062） |
| `remove(url)`（登録済み） | 取り除いて `true`。実際のフォルダには触れない（FR-064） |
| `remove(url)`（未登録） | 変更せず `false` |
| `init(urls:)` | 重複は先勝ちで除き、順序を保つ |

- 登録・削除はファイルシステムを変更しない
- 登録したフォルダが移動・名前変更されても追従しない（FR-067）。見つかるかどうかは保存せず、`FavoriteAvailability` で表す

## FavoriteAvailability（お気に入りの項目の存在・永続化しない）

各項目の「登録時の場所にフォルダがあるか」（FR-067）。ツリーの項目ごとに持ち、保存しない。

| 現在 | 契機 | 結果 | 表示 |
|------|------|------|------|
| `.unknown`（起動時・登録直後） | 確認の結果がディレクトリあり | `.available` | 通常の文字 |
| `.unknown` | 確認の結果がなし（存在しない・ファイル） | `.missing` | 淡色の文字、ツールチップ「見つかりません」 |
| `.available` | 再確認の結果がなし | `.missing` | 同上 |
| `.missing` | 再確認の結果がディレクトリあり | `.available` | 通常の文字に戻す |

- 再確認の契機: ボリュームのマウント/取り外し、アプリがアクティブになったとき、登録したフォルダの親フォルダの
  FSEvents、その項目を選択したとき（research.md R21）
- 権限のないフォルダは存在するので `.available`。選んだときのファイルリストは既存の「アクセスできません」
- `.unknown` は `.available` と同じ見た目にする（確認が終わるまで淡色にしない）
- `.missing` の項目を選んだときのファイルリストは、既存の `.failed("フォルダが見つかりません")` の表示になる

## TreeItemRole と FavoriteCommands（ツリーの行の役割と操作の可否・永続化しない）

ツリーの行を、お気に入りの操作とゴミ箱に入れる操作の判断に必要な役割へ写したもの（research.md R21・R33）。

| `TreeItemRole` | 対象の行 |
|----------------|----------|
| `.favoritesHeader` | 「お気に入り」の見出し（仮想。ファイルシステム上にない） |
| `.favorite(URL)` | 見出しの下の各項目 |
| `.folder(URL)` | ホーム・ボリュームのルートと、その下の通常のフォルダ |

| 役割 | 追加（⌃⌘T） | ⌘⌫ | 右クリックメニュー | 選択したとき | ドロップ・ペースト |
|------|--------------|-----|--------------------|--------------|--------------------|
| `.folder`（ルート以外・未登録） | 有効 | ゴミ箱に入れる（確認モーダル → ゴミ箱。FR-079） | ゴミ箱に入れる / ─ / ここにペースト / ここに移動ペースト / ─ / お気に入りに追加 / ─ / Finder に表示 | `selectFolder` | 受け付ける（既存） |
| `.folder`（ルート以外・登録済み） | 無効 | 同上 | 同上（「お気に入りに追加」は無効） | `selectFolder` | 受け付ける（既存） |
| `.folder`（ホーム・ボリュームの最上位） | 未登録なら有効 | 無効（何もしない） | ここにペースト / ここに移動ペースト / ─ / お気に入りに追加 / ─ / Finder に表示 | `selectFolder` | 受け付ける（既存） |
| `.favorite` | 無効 | お気に入りから削除（確認モーダル → 登録だけ削除） | お気に入りから削除 | `selectFolder`（実際の階層は動かさない） | 受け付けない |
| `.favoritesHeader` | 無効 | 無効 | なし | 何もしない（一覧・プレビュー・`lastFolder` を変えない） | 受け付けない |
| 選択なし | 無効 | 無効 | — | — | — |

- ⌘⌫ のメニュー項目名は、`.favorite` のとき「お気に入りから削除」、それ以外は「ゴミ箱に入れる」
- ルートかどうかは `FolderNavigation.enclosingFolder(of:roots:)` が nil かどうかで決める（`..` を出すかどうかと同じ規則。R30・R33）。
  ゴミ箱の対象は `FavoriteCommands.trashTarget(_:roots:)` が返す
- 右クリックメニューは右クリックした行の役割で決める（選択中の行ではない）

## MediaFile（ファイルリストの項目）

| フィールド | 型 | 説明 |
|------------|----|------|
| `url` | URL | ファイルの場所（同一性のキー）。`.folder` はフォルダのファイル URL。zip の中の項目は `ArchiveURL` の `mvzip` URL。通常のフォルダの `.parent` は `ParentLink` の `mvparent` URL |
| `name` | String | 拡張子を含むファイル名。zip の中の項目は FR-074 で判定した名前。`.parent` は `..` |
| `kind` | ListItemKind | 行の種類（2026-10-21 に `MediaKind` から変更） |
| `typeDescription` | String | 「種類」列に出す OS のローカライズ名（例: 「JPEG イメージ」）。`.folder` と zip の中のディレクトリは「フォルダ」、`.parent` は空 |
| `creationDate` | Date? | 「作成日」列。取得できない場合は `nil` で、表示は「--」。`.folder` はフォルダの作成日時。zip の中の項目は zip に記録された更新日時 |
| `fileSize` | Int64 | バイト数（並べ替えと a11y 用。列は表示しない）。zip の中の項目は展開後のサイズ、`.folder`・ディレクトリ・`.parent` は 0 |

- リスト形式の行頭アイコンは `kind` からフォールバックを選び、`url` をキーに非同期取得した
  縮小画像で置き換える（`IconPresentation`）。`MediaFile` 自体には画像を保持しない
- 型の名前は `MediaFile` のまま、zip ファイル・フォルダ・ディレクトリ・`..` の行にも使う（research.md R23・R29）

## FolderListing（ファイルリストの内容）

| フィールド | 型 | 説明 |
|------------|----|------|
| `folder` | URL | 対象フォルダ。zip の中を表示中も、zip ファイルを含むフォルダのまま |
| `archive` | ArchiveLocation? | zip の中を表示中なら、その zip と階層。通常のフォルダでは `nil` |
| `search` | SearchListing? | 検索結果を表示中なら、その検索の条件と進み具合（FR-084・085）。それ以外は `nil`。表示中は `folder` を検索前のフォルダのまま変えず、`archive` は `nil` |
| `files` | `[MediaFile]` | 対応形式（と zip ファイル・サブフォルダ、zip の中ではディレクトリ。先頭に `..`）で絞り込み、並べ替えたうえで、種類フィルタ（`MediaTypeFilter`）を適用した行。UI・選択・先読み・フルスクリーン移動はこの配列だけを見る |
| `state` | `.loading` / `.loaded` / `.empty` / `.noMatches` / `.denied` / `.failed(String)` | 表示状態 |

- `.empty` は対応メディアが元々1件もなく、`..` 以外の行（zip ファイル・フォルダ・ディレクトリ）もない状態、`.noMatches` は対応メディアは
  あるが種類フィルタで1件も残らない状態（FR-060）。種類フィルタが絞り込んでいないとき `.noMatches` にはならない
- メディアが0件でも zip ファイル・フォルダ・ディレクトリの行があれば `.loaded`。これらと `..` は件数の判定で数えない
- `.empty` / `.noMatches` / `.denied` / `.failed` でも、`files` に `..`（とフォルダ・ディレクトリ）が残ることがある。通常のフォルダを読めないとき（`.denied` / `.failed`）は、
  `files` を `..` だけにする（ツリーのルートで `..` がなければ空）。UI は行を出したまま、一覧の下端にメッセージを出す（research.md R26・R30、FR-077）
- zip を開けないときは `.failed("zip を開けません: <理由>")` で、`files` は `..` だけ
- `BrowserModel` は種類フィルタを適用する前の並べ替え済みの全件を非公開で保持し、絞り込みの変更では
  ディスクを読み直さない
- 検索結果の表示中（`search != nil`）は、`files` に `..`・フォルダ・zip ファイルを含めず、一致したメディアファイルだけを置く。状態は既存の値を使う:
  検索中で結果がまだない間は `.loading`、1件以上あれば `.loaded`、終わって0件なら `.empty`、種類フィルタで0件なら `.noMatches`。
  UI は `search` の有無で文言を替える（`.loading` は「検索中…」、`.empty` は「該当するファイルはありません」。research.md R37）

**状態遷移**:

```text
(フォルダ選択) → loading → loaded ─┐
                         ├→ empty   │← FSEvents による差分反映（loaded ⇄ empty ⇄ noMatches）
                         ├→ noMatches│← 種類フィルタの変更（loaded ⇄ noMatches）
                         ├→ denied  │
                         └→ failed  │
(別フォルダ選択) ── 任意の状態 → loading（前の読み込みは取り消す。種類フィルタは保つ。zip の状態は捨てる）
(zip・フォルダ・ディレクトリ・`..` を開く) ── loaded / empty / noMatches / failed → loading → （上と同じ分岐）
```

**zip の中の移動**（FR-069・070、research.md R23・R26）:

```text
フォルダの一覧 ─(zip の行を開く)→ zip の最上位 ─(ディレクトリを開く)→ zip の中の階層
      ↑                            │  ↑                                │
      └──(`..` / ⌘↑)──────────────┘  └────────(`..` / ⌘↑)─────────────┘
      ↑
      └──(ツリーで別のフォルダ / FSEvents で zip が変わった・消えた)── zip の中の任意の階層
```

- 中へ入ったときは選択を空にし、プレビューを空にする（`selectFolder` と同じ）
- 戻ったときは、直前まで中を表示していた zip ファイルまたはディレクトリの行だけを選択し、フォーカスにする（FR-070）
- 階層の移動では zip を読み直さず、開いたときの `ArchiveIndex` から一覧を作る。zip の最上位から戻ったときは、
  フォルダの一覧をディスクから読み直す

**通常のフォルダの移動**（FR-076〜078、research.md R30・R31）:

```text
親フォルダの一覧 ─(`.folder` の行を開く: ダブルクリック・⌘↓)→ サブフォルダの一覧
      ↑                                                          │
      └──────────────(`..` / ⌘↑。ツリーのルートでは `..` を出さず、⌘↑ は何もしない)──┘
```

- どちらの向きも `selectFolder` と同じく読み込みを取り消してから読み直し、`lastFolder` を保存し、種類フィルタは保つ
- 中へ入ったときは何も選択しない。戻ったときは直前まで表示していたフォルダの行だけを選択し、フォーカスにする
- どちらの向きも `TreeSyncRequest` を出す。ツリーからの選択（`selectFolder`）、zip の中の移動、FSEvents でフォルダが消えて親へ戻る経路では出さない

**検索結果の表示**（FR-080〜087、research.md R36〜R38）:

```text
任意の一覧（通常のフォルダ・zip の中・検索結果）─(検索のモーダルで「検索」)→ 検索中（.loading → .loaded）─(列挙の完了)→ 完了（.loaded / .empty / .noMatches）
                                                     │                                         │
                                                     └──────────(新しい検索: 前の検索を止めて結果を置き換える)──┘
検索中・完了 ─(ツリーでフォルダ・お気に入りの項目を選ぶ、選択中のフォルダの行をクリック)→ そのフォルダの一覧（loading → …）。実行中の検索は止める
検索中・完了 ─(ツリーで検索前のフォルダかその祖先をゴミ箱に入れる)→ 親フォルダの一覧（FR-079 と同じ）
```

- 検索を始めたときは、選択とプレビューを空にし、再生中の動画を止める（`selectFolder` と同じ `resetForNavigation`）。`lastFolder` と
  `treeSyncRequest` は変えない。種類フィルタは保つ
- 結果はバッチで届くたびに並べ替え済みの全件へマージし、選択・フォーカスは保つ
- 結果からは、元の場所から消えたファイルを外す（ゴミ箱・移動・アプリの外での削除と移動）。名前を変更したファイルは新しい URL と名前で残す。
  新しく現れたファイルは加えない（FR-087）

## FolderNavigation（通常のフォルダの戻る先・永続化しない）

ツリーのルートの一覧から、通常のフォルダの1つ上の階層を決める純粋計算（FR-077、research.md R30）。

| 入力 | `enclosingFolder(of:roots:)` |
|------|------------------------------|
| `folder` がルートのどれかと同じ（ホーム・ボリュームの最上位） | `nil`（`..` を出さない。⌘↑ は何もしない） |
| `folder` を含むルートがある | 含むルートのうち最も深いものの中での親（例: ルートが `/` と `/Users/me` のとき、`/Users/me/a` → `/Users/me`、`/Users/x` → `/Users`） |
| どのルートにも含まれない、またはルートの一覧が空 | `nil` |

- 比較は `standardizedFileURL` のパスの要素で行う（`/Users/me2` は `/Users/me` の配下ではない）
- ルートの一覧は `BrowserModel.setNavigationRoots(_:)` で App から受け取る（ツリーのルートと同じ。ボリュームの増減で渡し直す）

ツリーでフォルダをゴミ箱に入れたあとに表示するフォルダも、同じ型の純粋計算で決める（FR-079、research.md R33）。

| 入力 | `folderToShow(afterTrashing:showing:roots:)` |
|------|-----------------------------------------------|
| `showing`（表示中のフォルダ。zip の中なら zip を含むフォルダ）が、ゴミ箱に入れたフォルダのどれか自身か、その配下 | そのフォルダの `enclosingFolder`（親）。該当が複数なら最も浅いフォルダの親 |
| 該当するフォルダがルート（`enclosingFolder` が nil） | `nil`（ルートはゴミ箱の対象にならないため、通常は起きない） |
| どのフォルダとも祖先・子孫の関係にない（兄弟・無関係・`showing` の配下だけ） | `nil`（一覧とツリーの選択を変えない） |
| ゴミ箱に入れたフォルダが空 | `nil` |

- 祖先かどうかも `standardizedFileURL` のパスの要素で比べる（`/a/b2` は `/a/b` の配下ではない）

## ParentLink（通常のフォルダの `..` の行の URL）

| 関数 | 内容 |
|------|------|
| `url(for folder: URL) -> URL` | `mvparent:` スキームとフォルダの絶対パスからなる URL。同じフォルダには同じ URL |
| `isParentLink(_ url: URL) -> Bool` | `mvparent` スキームなら true |

- `FileManager`・`NSWorkspace`・ペーストボードに渡さない（`.parent` の行はファイル操作の対象外）
- zip の中の `..` は従来どおり `ArchiveURL.parentLink(of:)`

## TreeSyncRequest（ツリーの選択の同期の依頼・永続化しない）

ファイルリストの中での移動をツリーに伝える値（FR-078、research.md R31）。`BrowserModel.treeSyncRequest` で公開する。

| フィールド | 型 | 説明 |
|------------|----|------|
| `folder` | URL | ツリーで選択するフォルダ（ファイルリストに表示しているフォルダ） |
| `id` | Int | 依頼のたびに増やす。ツリーは最新の `id` の結果だけを選択に反映する |

- ツリーは実際の階層（お気に入りの項目ではない）でこのフォルダを選択し、祖先を展開し、必要最小限スクロールする。
  キーボードフォーカスは移さない。選択の変更から `selectFolder` を呼び返さない

## MediaTypeFilter（種類フィルタ・永続化しない）

ファイルリストに出す種類を絞り込む2つのオン・オフ（FR-056〜058、research.md R20）。
`BrowserModel.mediaTypeFilter` に1つだけ置き、起動中はフォルダを移っても保つ。`SettingsStore` には保存せず、
起動のたびに既定に戻る。

| フィールド | 型 | 既定値 | 説明 |
|------------|----|--------|------|
| `imagesOnly` | Bool | false | 「画像のみ表示」。ツールバーの左ボタン、⇧⌘I |
| `videosOnly` | Bool | false | 「動画のみ表示」。ツールバーの右ボタン、⇧⌘M |

| `imagesOnly` | `videosOnly` | 表示するもの | `isFiltering` | `noMatchesMessage` |
|--------------|--------------|--------------|---------------|--------------------|
| false | false | 画像と動画すべて | false | nil |
| true | false | 画像（`!kind.isVideo`）だけ | true | 「画像のみ表示中: 該当するファイルはありません」 |
| false | true | 動画（`kind.isVideo`）だけ | true | 「動画のみ表示中: 該当するファイルはありません」 |
| true | true | 画像と動画すべて | false | nil |

- `apply(to:)` は入力の並び順を保つ（並べ替えは先に済ませる）
- `apply(to:)` は `kind` が `.media` 以外の行（zip ファイル・ディレクトリ・`..`）を常に残す（FR-056）
- ツールバーのセグメントの押された状態とメニューのチェックは、各フィールドの値をそのまま映す
  （両方オンでもボタンは両方押された見た目のまま）
- zip ファイルの表示（`ZipFileVisibility`）とは独立した設定で、`BrowserModel.rebuildListing()` が種類フィルタを通したあとに zip の表示を適用する（R46）

## ZipFileVisibility（zip ファイルの表示設定・`ViewSettings` で永続化）

ファイルリストに zip ファイル（`.archive` の行）を出すかどうか（FR-095、research.md R46）。
`ViewSettings.showsZipFiles` として保存し、`BrowserModel` が1つだけ持つ。ツールバーのボタン・「表示」メニュー・⌃⌘Z は
この値を共有する（research.md R47）。

| フィールド | 型 | 既定値 | 説明 |
|------------|----|--------|------|
| `showsZipFiles` | Bool | false | 「zipファイルを表示」。オンのときだけ zip ファイルの行を出す。保存する |

- `apply(to:)` は `showsZipFiles` が true なら入力をそのまま返し、false なら `kind == .archive` の行だけを除く。並び順を保ち、
  `.media`・`.folder`・`.directory`・`.parent` の行は残す
- 適用するのは通常のフォルダの一覧だけ。zip の中の一覧と検索結果には `.archive` の行がないため結果は変わらない（FR-095・098）
- 切り替えで非表示になった選択は `SelectionState.restricted(toVisible:)` で整理する（FR-097。種類フィルタと同じ表）
- zip の中を表示中の切り替えは値を保存するだけで、一覧・選択・プレビュー・表示形式・フルスクリーンを変えない。`..` / ⌘↑ で戻った先では
  zip ファイルの行が表示されないため、行の選択もスクロールも行わない（FR-098）
- 一覧の状態は表示する行で判定する。`hasMedia` は列挙済みの全件（メディアは zip の表示設定に影響されない）、`hasOtherRows` は表示する行から求める。
  zip ファイルだけのフォルダ（`..` を除く）を非表示にすると `.empty` になり、既存の空のメッセージを出す
- 値は `SettingsStore` のキー `view.showsZipFiles` に保存し、キーがない・Bool でない場合は false（初回起動は非表示）。値を戻しても
  外した選択は選択に戻らない（種類フィルタと同じ）

## SortOrder

| フィールド | 型 | 説明 |
|------------|----|------|
| `column` | `.name` / `.creationDate` / `.kind` / `.location` | 並べ替え列（FR-012）。`.location` は検索結果の表示中だけ選べる（FR-084） |
| `ascending` | Bool | 昇順なら true |

- 既定は `.name` の昇順。名前は Finder と同じ自然順（`localizedStandardCompare`）で比較する
- 同じ値が並んだ場合は、名前の自然順を第2キーにする
- `.location` は、ファイルを含むフォルダのパス（`url.deletingLastPathComponent().path`）を自然順で比べる。同じ起点の中では「場所」列の文字列の順と一致する
- `.location` は保存しない。検索結果の表示中でないときは `.location` への代入を受け付けず、`oldValue` に戻す（戻す代入の間は設定の書き込みと
  並べ直しを行わない）。検索結果の表示を終えたときに `.location` が選ばれていれば、保存済みの並べ替えに戻す（research.md R37）
- 列の値と名前の第2キーがすべて同じ行（別のフォルダにある同じ名前のファイルなど）は同順位とし、相対順は届いた順（既存の結果が先）になる。
  検索結果では起動や検索のたびに順番が変わりうる（パスを第3キーにはしない。research.md R36）
- 検索結果のマージ（`sortedMerge(_:_:by:)`）は、並べ替え済みの2つの配列から、`sorted(a + b, by:)` と同じ順序の配列を1回の走査で作る。
  同順位では先の配列（既存の結果）の行を先に置く。50,000 件の結果で1バッチの処理が 100ms 未満に収まらなければ、挿入位置を二分探索で決める方式に
  置き換える（順序は同じ。research.md R36）

## SelectionState

| フィールド | 型 | 説明 |
|------------|----|------|
| `selected` | `Set<URL>` | 選択中のファイル（複数選択: FR-016） |
| `focused` | URL? | 最後に選択・フォーカスされたファイル。プレビューの対象（FR-017） |

- 選択中のファイルが外部で削除されたら選択から外す。`focused` が消えた場合はプレビューを空にする
- 種類フィルタの変更で選択中のファイルが非表示になったら、`restricted(toVisible:)` で整理する（FR-059）

| 変更前 | 変更後の `selected` | 変更後の `focused` |
|--------|---------------------|--------------------|
| `focused` が nil（選択はある） | 表示中のものだけ | nil のまま（フォーカスを作らない） |
| `focused` が表示中のまま | 表示中のものだけ | 変えない（プレビューも読み直さない） |
| `focused` が非表示になり、表示中の選択が残る | 表示中のものだけ | 残った選択のうち `files` の並び順で最後のもの |
| 表示中の選択が残らない | 空 | nil（プレビューは空。動画は停止する） |

- 外した選択は記録しない。絞り込みを戻して再び表示されても、選択には戻らない
- 表示形式を切り替えても選択状態は維持する（US3-1）

## ThumbnailScroll（サムネイル形式の追従スクロール・永続化しない）

フォーカス項目をビューポート内に保つための計算。状態として保存せず、キーボード移動のたびに
レイアウト結果から求める（FR-017、research.md R15）。

| 入力 | 型 | 説明 |
|------|----|------|
| `itemMinY` / `itemMaxY` | Double | フォーカス項目の縦範囲（コレクションビュー座標） |
| `visibleMinY` | Double | 現在の可視領域の上端（クリップビュー座標） |
| `visibleHeight` | Double | 可視領域の高さ。可視領域の下端は `visibleMinY + visibleHeight` |
| `contentHeight` | Double | スクロール内容の全高 |

| 出力 | 型 | 説明 |
|------|----|------|
| `offsetY` | Double | 項目全体が見える最小の縦スクロール原点。`0...(contentHeight - visibleHeight)` にクランプする |

- 項目全体が見えている場合は `visibleMinY` をそのまま返す（スクロールしない）
- 項目がビューポートより高い場合は上端を可視領域の上端に合わせる
- 横方向の値は持たない。横スクロールは発生させない（FR-015）
- フォーカスは `SelectionState.focused`（最後に移動した項目）と一致する。Shift+矢印で範囲を広げた場合も
  移動先の項目を基準にする
- サムネイルサイズ・ペイン幅・ウィンドウサイズの変更では追従スクロールを行わない（spec Clarifications）

## FocusNavigator（矢印キーによる選択移動・永続化しない）

ファイルリストとフルスクリーンの両方で使う、移動先インデックスの純粋計算（FR-017・046、research.md R16）。

| 入力 | 型 | 説明 |
|------|----|------|
| `currentIndex` | Int? | 現在のフォーカス位置。`nil` は未選択 |
| `fileCount` | Int | リストの件数 |
| `move` | `.left` / `.right` / `.up` / `.down` | 押された矢印キー |
| `layout` | `.list` / `.grid(columns:)` | 表示形式。グリッドの列数は 1 以上 |

| 出力 | 型 | 説明 |
|------|----|------|
| `targetIndex` | Int? | 移動先。空リスト、リスト形式の ←→、端での移動は `nil`（選択を変えない） |

- `.list` は ↑ で -1、↓ で +1、←→ は移動なし
- `.grid(columns:)` は ← で -1、→ で +1、↑ で -列数、↓ で +列数
- 結果は `0...(fileCount - 1)` にクランプする。リスト形式の ←→ は `currentIndex` に関わらず `nil`。
  それ以外で `currentIndex` が `nil` の場合は 0 を返す
- 列数が 0 以下の場合は 1 として扱う（ゼロ除算・同一行内の無限移動を避ける）
- フルスクリーンでは `isNavigable`（行がメディアか）を渡し、移動先がメディア以外の行なら同じ方向に同じ規則で
  移動を繰り返す。メディアの行に当たらないまま端に達したら `nil`（選択を変えない）（FR-046、research.md R26）。
  通常表示では `isNavigable` を渡さず、メディア以外の行にも止まる。プレビューのみ表示（FR-093）もフルスクリーンと同じ関数を使う

`entryIndex(currentIndex:fileCount:isNavigable:)`（プレビューのみ表示に切り替えたときの最初のファイル。FR-093、research.md R43）:

| 入力の状態 | 出力 |
|------------|------|
| `currentIndex` の行がメディア | `currentIndex`（選択を変えない） |
| `currentIndex` の行がメディア以外（フォルダ・zip ファイル・zip の中のディレクトリ・`..`） | その行より後ろの最初のメディア。後ろになければ、前にある最も近いメディア |
| 一覧が読み込み済みで `currentIndex` が `nil`（未選択） | 先頭から最初のメディア |
| メディアが1件もない・空リスト | `nil`（選択を変えず、プレビューにメッセージを出す） |

- プレビューのみ表示に切り替えたときにだけ使う。一覧の状態が `.loading` のときは `entryIndex` を呼ばず、読み込みが終わっても
  自動選択しない（spec FR-093・Edge Cases）。その後に選択がなくなっても（種類フィルタで非表示になった、外部で削除された）選び直さない。
  メディアがあれば `showsNoMediaMessage` は false でプレビューは空のまま。次の矢印キーは `targetIndex(…isNavigable:)` の
  `currentIndex` が `nil` の規則で先頭から最初のメディアへ移る（spec Edge Cases、research.md R43）

## HiddenListNavigation（ファイルリストを隠している間の矢印キーの移動・永続化しない）

フルスクリーン中とプレビューのみ表示中に、隠れたファイルリストの選択を矢印キーで動かすための文脈（FR-046・093、research.md R16・R43）。
従来の `FullScreenNavigationContext` を置き換える。

| フィールド | 型 | 説明 |
|------------|----|------|
| `width` | Double | ファイルリストを隠す直前のサムネイルのコレクションビューの幅（pt）のスナップショット |

- 移動のレイアウトはキーを押すたびに決める: 表示形式がリストなら `.list`、サムネイルなら
  `.grid(columns: ThumbnailGridLayout.columns(availableWidth: width - 左右の余白, thumbnailSize: 現在のサイズ, spacing:).count)`。
  隠している間に表示形式・サムネイルサイズを変えても追従する
- 始まり: `PanePresentation.navigatesHiddenFileList` が false から true になったとき（プレビューのみ表示への切り替え、フルスクリーンに入るとき）。
  プレビューのみ表示からフルスクリーンに入る・出るときは取り直さない
- 終わり: ファイルリストが表示に戻ったとき。文脈を捨て、選択は移動後の `SelectionState` のまま、フォーカス項目へ必要最小限のスクロールを行う
  （リスト形式・サムネイル形式の両方。FR-017・093）
- 永続化しない。`ViewSettings` や `UserDefaults` には追加しない

## PaneLayout（ペインの表示状態・永続化しない）

ペインの表示切り替えの状態（FR-088〜090、research.md R40）。`MainSplitViewController` が1つだけ持ち、ツールバー・メニュー・ショートカットで共有する。
起動のたびに `.all` で始める。

| 値 | ツリー | ファイルリスト | プレビュー | ツールバーの押下（`soloPane`） | 「表示」メニューのチェック |
|----|--------|----------------|------------|-------------------------------|------------------------------|
| `.all`（既定） | 表示 | 表示 | 表示 | どちらも押されていない（`nil`） | なし |
| `.fileListOnly` | 隠す | 表示（幅いっぱい） | 隠す | ファイルリストのみ表示（`.fileList`） | ファイルリストのみ表示 |
| `.previewOnly` | 隠す | 隠す | 表示（幅いっぱい） | プレビューのみ表示（`.preview`） | プレビューのみ表示 |

- ツリーだけを隠す・ツリーだけを表示する・ファイルリストとプレビューの両方を隠す状態は、値として存在しない（FR-088）
- `Pane`: `.tree` / `.fileList` / `.preview`。`SoloPane`: `.fileList` / `.preview`（ボタンとメニュー項目の対象）

状態遷移（メニュー・ショートカット: `toggling(_:)`）:

| 現在 | ⌃⌘2（ファイルリストのみ表示） | ⌃⌘3（プレビューのみ表示） |
|------|-------------------------------|---------------------------|
| `.all` | `.fileListOnly` | `.previewOnly` |
| `.fileListOnly` | `.all` | `.previewOnly` |
| `.previewOnly` | `.fileListOnly` | `.all` |

ツールバーのボタングループ（`selectAny`）から（`applyingToolbarSelection(fileListSelected:previewSelected:)`）:

| 現在 | ボタングループが報告した押下（ファイルリスト, プレビュー） | 次 |
|------|-----------------------------------------------------------|----|
| 任意 | (false, false) | `.all` |
| 任意 | (true, false) | `.fileListOnly` |
| 任意 | (false, true) | `.previewOnly` |
| `.fileListOnly` | (true, true) | `.previewOnly`（後から押した側だけを残す） |
| `.previewOnly` | (true, true) | `.fileListOnly` |
| `.all` | (true, true) | `.all`（1回のクリックでは起きない。変えずにボタンを書き戻す） |

結果は必ず `soloPane` でボタングループに書き戻し、2つが同時に押された見た目を残さない（FR-089）。

切り替え後のフォーカス（`focusTarget(afterSwitchingFrom focused: Pane?) -> Pane?`、FR-091）:

| 切り替え先 | フォーカスがあったペイン | 移し先 |
|------------|--------------------------|--------|
| `.fileListOnly` | ファイルリスト | 移さない（`nil`） |
| `.fileListOnly` | ツリー・プレビュー・どこでもない | `.fileList` |
| `.previewOnly` | プレビュー | 移さない |
| `.previewOnly` | ツリー・ファイルリスト・どこでもない | `.preview` |
| `.all` | 任意 | 移さない（切り替え前に表示していたペインに残る） |

`showsNoMediaMessage(in listing: FolderListing) -> Bool`（FR-093）: `self == .previewOnly` かつ `listing.state != .loading` かつ
`listing.files` にメディアの行（`kind.isMedia`）が1件もないとき true。プレビューに「表示するメディアファイルがありません」を出す

`static func shouldAutoSelectEntry(in listing: FolderListing) -> Bool`（FR-093）: `listing.state != .loading` のとき true。`.loading`（通常の読み込み中と
検索中を含む）のとき false とし、プレビューのみ表示へ切り替えたときに `FocusNavigator.entryIndex` を呼ばず、読み込み完了後も自動選択しない。
`FileListViewController.beginHiddenListNavigation(selectingEntry:)` は `selectingEntry && PaneLayout.shouldAutoSelectEntry(in: model.listing)`
のときだけ最初のファイルを選ぶ（`PaneLayoutTests` で検証する）

## PanePresentation（実際に表示するペイン・永続化しない）

表示状態とフルスクリーンから、実際に表示するペインを決める純粋計算（FR-094、research.md R41・R44）。

| 入力 | 型 |
|------|----|
| `layout` | `PaneLayout` |
| `isFullScreen` | Bool |

| 出力 | 規則 |
|------|------|
| `visiblePanes: [Pane]` | フルスクリーン中は `[.preview]`。それ以外は `layout` で表示するペインを、ツリー → ファイルリスト → プレビューの順に（Tab の巡回順） |
| `isVisible(_ pane:)` | `visiblePanes.contains(pane)` |
| `showsAllPanes` | 3つとも表示（`!isFullScreen && layout == .all`）。ペイン幅の保持・復元と自動保存の再開に使う |
| `navigatesHiddenFileList` | ファイルリストが隠れていてプレビューが見えている（フルスクリーン中、またはプレビューのみ表示）。矢印キーのモニタを入れる |

- 隠すペインは `canCollapse = true` → `isCollapsed = true`、表示するペインは `isCollapsed = false` → `canCollapse = false` の順で反映し、
  表示に戻すペインを先に出す（3つとも隠れた途中の状態を作らない）
- フルスクリーンを解除すると `layout` に戻る（フルスクリーン前の表示状態）

## PaneCommands（隠したペインに関わる操作の可否・永続化しない）

`PaneCommands(layout:isFullScreen:isEditingText:)`（FR-062・065・080・090・092・094、research.md R42）。

| 出力 | 対象 | 規則 |
|------|------|------|
| `canChangeLayout` | ⌃⌘2・⌃⌘3・ツールバーのボタン | `!isFullScreen && !isEditingText` |
| `canFocus(_ pane:)` | ⌥⌘1・⌥⌘2・⌥⌘3 | `layout` でそのペインを表示している |
| `canGoToFavorites` | ⇧⌘F | `!isFullScreen && !isEditingText && layout` でツリーを表示している |
| `allowsAddingFavorite` | ⌃⌘T | `!isEditingText && layout` でツリーを表示している（ツリー側の `canAddSelectedFolderToFavorites` と AND） |
| `canSearch` | ⌘F | `!isFullScreen && !isEditingText && layout` でファイルリストを表示している |

- false の項目は「表示」「ファイル」メニューで淡色にし、ショートカットは何もしない
- ⌘↓・⌘↑・ファイル操作の項目は、ファイルリストを隠すとレスポンダーチェーンから外れるため、既存の検証で淡色になる（この型では扱わない）

## PaneWidths（3ペインへ戻すときの仕切りの位置・永続化しない）

`PaneWidths.dividerPositions(savedWidths:totalWidth:dividerThickness:minimumWidths:) -> [Double]`（FR-088、research.md R41）。

| 入力 | 型 | 説明 |
|------|----|------|
| `savedWidths` | [Double]（3要素） | 3つとも表示していた最後の、ツリー・ファイルリスト・プレビューの幅 |
| `totalWidth` | Double | 戻すときの分割ビューの幅 |
| `dividerThickness` | Double | 仕切りの太さ |
| `minimumWidths` | [Double]（3要素） | 160 / 240 / 320 |

- 出力は2本の仕切りの位置 `[tree, tree + dividerThickness + list]`
- プレビューの幅 = `totalWidth - tree - list - 2 × dividerThickness`。プレビューが最小幅以上ならツリーとファイルリストは保存した幅のまま
  （ウインドウが同じ幅なら切り替え前と同じ、広がった分はプレビューが受け取る）
- プレビューが最小幅に足りなければ、足りない分をファイルリスト（最小幅まで）、次にツリー（最小幅まで）から詰める
- 保存した幅がない・要素数が違う・有限でない値を含むときは、初回の既定（220 / 360 / 残り）を使う

## PreviewContent（プレビュー状態）

```text
empty ──(focused 設定)──→ loading ──→ image(DecodedImage) / animatedImage(URL) / animatedImageData(URL, Data) / video(URL)
                                  └──→ unavailable(name, reason)   ← 破損・非対応エンコード（FR-038）
任意 ──(focused が nil / ファイル消失 / focused がメディア以外の行)──→ empty
```

- `animatedImageData(URL, Data)` は zip の中のアニメーション画像だけで使う。`Data` は zip から読んだ項目の内容で、
  プレビューを離れたら捨てる（research.md R24）
- フォーカスが zip ファイル・ディレクトリ・`..` の行になったら `empty` にし、再生中の動画は停止する（FR-075）
- zip の中の画像で、暗号化・非対応の格納方式・512MB 超のときは `unavailable` にする（spec Edge Cases、research.md R24）

- 動画は `video` 状態になると、自動再生・ループの各オプションに従って再生を始める（FR-031・032）
- `focused` が変わったら、前の動画を停止してから遷移する（FR-034）
- 画像の表示矩形はレイアウトのたびに `FitCalculator` で求める。コンテナより小さい画像も拡大されるため、
  表示サイズは元画像の画素数を超えうる（FR-028）。拡大率は状態として保持しない（再計算で求まる）

## DisplayMode と ViewSettings（表示設定・永続化）

| フィールド | 型 | 既定値 | 制約 |
|------------|----|--------|------|
| `displayMode` | `.list` / `.thumbnails` | `.list` | FR-010 |
| `thumbnailSize` | Double（pt） | 128 | 48〜512 の範囲に丸める（FR-014） |
| `sortOrder` | SortOrder | 名前の昇順 | FR-012 |
| `lastFolder` | URL? | ホーム | 存在しない場合はホームに戻す（FR-003） |
| `showsToolbar` | Bool | false | 値がない・不正な型の場合は false（FR-003・049） |
| `showsZipFiles` | Bool | false | 値がない・不正な型の場合は false（FR-003・095）。zip ファイルの行を出すかどうか。`ZipFileVisibility` に対応する |
| ペイン幅 | （分割ビューの自動保存） | 220 / 360 / 残り | 最小幅 160 / 240 / 320 pt（FR-002）。1つのペインだけを表示している間は自動保存を止め、3ペインの幅だけを保存する（R41） |

## FileListChrome（下部バーとツールバーのスライダー・永続化しない）

表示形式とツールバーの表示状態から、ファイルリスト周辺の表示を決める純粋計算。

| 入力 | 型 |
|------|----|
| `displayMode` | `.list` / `.thumbnails` |
| `toolbarShown` | Bool |

| 出力 | 規則 | 要件 |
|------|------|------|
| `showsBottomSizeBar` | `displayMode == .thumbnails && !toolbarShown` | FR-052 |
| `toolbarSliderEnabled` | `displayMode == .thumbnails`（ツールバーが非表示でも値は同じ。表示時にそのまま使う） | FR-051 |

ツールバーの表示形式ボタンの選択位置は `displayMode` から直接決める（サムネイル = 0、リスト = 1）。

## PlaybackOptions と ConfirmationOptions（動作オプション・永続化）

| フィールド | 型 | 既定値 | 要件 |
|------------|----|--------|------|
| `autoplay` | Bool | true | FR-031・032 |
| `loop` | Bool | true | FR-031・032 |
| `confirmBeforeFileOperations` | Bool | true | FR-022〜024・064（false の場合はコピー・削除・お気に入りの削除で確認を省略する。名前の変更と移動は常に確認する） |

## FileOperation（ファイル操作）

| フィールド | 型 | 説明 |
|------------|----|------|
| `kind` | `.copy` / `.move` / `.rename(newName)` / `.trash` | 操作の種類（FR-018） |
| `sources` | `[URL]` | 対象（rename の場合は1件） |
| `destination` | URL? | 操作先フォルダ（copy・move の場合） |

**検証規則**:
- move: 移動先が元のフォルダと同じ場合は何もしない。フォルダを自分自身やその配下へ移動しようとした場合は拒否する
- rename: 空の名前、`/` または `:` を含む名前、先頭が `.` の名前、既存の名前（大文字小文字の違いのみも含む）は拒否する。
  既存の名前は衝突ダイアログ（FR-025）の対象にせず、名前の検証エラーとして扱う。拡張子が変わる場合は確認を求める
  （[research.md](./research.md) R10）
- copy・move: 操作先に同名がある場合は、確認モーダル設定に関わらず衝突ダイアログ（FR-025）を出す。rename では出さない

**実行の流れ**: 確認モーダルは名前の変更と移動では設定に関わらず表示し、コピーと削除では設定で省略できる
（FR-024）。複製は確認モーダルを通さず、`FileOperationCoordinator` から直接 `execute` に渡す（同じフォルダへの
`.copy` + `.keepBoth` でも、確認の設定を参照しない）。衝突判定は copy・move だけを行い、rename は
`validateNewName` で既存名を拒否する（FR-025）。

```text
requested ─(確認 ON)→ awaitingConfirmation ─(キャンセル)→ cancelled（ファイルシステムは変更しない: FR-022）
    │                       └─(OK)─┐
    └─(確認 OFF)───────────────────┴→ conflictCheck ─(衝突あり)→ awaitingConflictChoice
                                            │                    ├ 置き換える / 両方残す → executing
                                            │                    └ 中止 → cancelled
                                            └─(衝突なし)→ executing → completed(FileOperationResult)
```

## FileOperationResult

| フィールド | 型 | 説明 |
|------------|----|------|
| `succeeded` | `[URL]` | 操作後の URL（trash の場合はゴミ箱内の URL） |
| `failed` | `[(URL, reason: String)]` | 失敗した対象と理由（FR-026） |

- 1件の失敗で残りの処理を止めない。ただし各ファイルは「全部成功」か「変更なし」のどちらかにする
  （部分的にコピーされたファイルは削除する: エッジケース）

## IconPresentation（行頭アイコン・永続化しない）

ツリーとリスト形式の名前の先頭に出すアイコンの表現。モデルの状態としては保存せず、表示のたびに
`FolderNode.Kind` と `MediaKind` から決める（FR-047・048、research.md R17）。

| 対象 | 入力 | 表示 |
|------|------|------|
| ツリー | `FolderNode.Kind.home` | `house` の SF Symbol |
| ツリー | `FolderNode.Kind.volume` | `externaldrive` の SF Symbol |
| ツリー | `FolderNode.Kind.folder` | `folder` の SF Symbol |
| リスト（生成中・失敗時） | `MediaKind.jpeg` | `photo` の SF Symbol |
| リスト（生成中・失敗時） | `MediaKind.png` | `photo.on.rectangle` の SF Symbol |
| リスト（生成中・失敗時） | `MediaKind.gif` | `photo.stack` の SF Symbol |
| リスト（生成中・失敗時） | `MediaKind.webp` | `photo.circle` の SF Symbol |
| リスト（生成中・失敗時） | `MediaKind.mp4` | `film` の SF Symbol |
| リスト（生成中・失敗時） | `MediaKind.mov` | `video` の SF Symbol |
| リスト（取得後） | `ThumbnailProviding` の 64px 画像 | 内容の縮小画像（動画は代表フレーム） |
| リスト・サムネイル | `ListItemKind.archive` | `doc.zipper` の SF Symbol（縮小画像は取得しない） |
| リスト・サムネイル | `ListItemKind.directory` | `folder` の SF Symbol（縮小画像は取得しない） |
| リスト・サムネイル | `ListItemKind.parent` | `arrowshape.turn.up.left` の SF Symbol。a11y のラベルは「上の階層へ」 |

- アイコンは装飾で、選択・フォーカス・並べ替えのキーにはならない。a11y 要素にはせず、
  フォルダ名・ファイル名の読み上げを維持する
- リストの縮小画像は可視行だけを非同期に取得し、取得後に同じ URL のセルへだけ差し替える。
  セル再利用時は同じ URL・要求サイズの取得だけを取り消し、他のサイズ（サムネイル形式の
  128 / 256 / 512px）の要求は残す。取得結果はメモリ上のサムネイルキャッシュにのみ置く
- ツリーのアイコンは展開状態で変化しない。アイコン自体は永続化しない

## ArchiveLocation（zip の中の現在位置・永続化しない）

`FolderListing.archive` に入る、表示中の zip とその中の階層（FR-069・070、research.md R23）。

| フィールド | 型 | 説明 |
|------------|----|------|
| `archive` | URL | zip ファイルのファイル URL |
| `directory` | String | zip の中の階層のパス。最上位は空文字、それ以外は `a/b/` のように末尾が `/` |

- `parent` は1つ上の階層。最上位の `parent` は `nil`（zip を含むフォルダへ戻る）
- 永続化しない。終了時に zip の中を表示していても、`lastFolder` は zip を含むフォルダのまま（FR-003）

## ArchiveURL（zip の中の項目の URL）

zip の中の項目・ディレクトリ・`..` を、既存の選択とキャッシュのキー（URL）で表すための形式（research.md R23）。

| 対象 | 形 |
|------|----|
| 項目 | `mvzip:///<項目のパス>?archive=<zip の絶対パス>` |
| ディレクトリ | `mvzip:///<ディレクトリのパス>/?archive=<zip の絶対パス>` |
| 最上位 | `mvzip:///?archive=<zip の絶対パス>` |
| `..` | 表示中の階層の URL + `#parent` |

- パスはどちらもパーセントエンコードする。生成と解析は `ArchiveURL` だけで行う
- `lastPathComponent` と `pathExtension` は項目の名前と拡張子を返すため、既存の形式判定（FR-009）がそのまま使える
- `isFileURL` は false。`FileManager`・`NSWorkspace`・ペーストボードには渡さない（FR-073）

## ArchiveIndex と ArchiveEntry（開いている zip の索引・永続化しない）

zip の中央ディレクトリを1回読んで作る索引。`BrowserModel` が開いている zip について1つだけ持つ（research.md R22・R23）。

| `ArchiveIndex` のフィールド | 型 | 説明 |
|-----------------------------|----|------|
| `archive` | URL | zip ファイル |
| `identity` | ArchiveIdentity | 開いたときの zip ファイルの同一性 |
| `entries` | `[String: ArchiveEntry]` | 項目のパス → 項目 |
| `children` | `[String: [String]]` | ディレクトリのパス → 直下の項目とディレクトリのパス（途中のディレクトリを補ったもの） |

| `ArchiveEntry` のフィールド | 型 | 説明 |
|-----------------------------|----|------|
| `path` | String | FR-074 で判定した名前による、zip の中のパス |
| `name` | String | パスの最後の要素 |
| `isDirectory` | Bool | ディレクトリか |
| `method` | UInt16 | 格納方式（0 = 無圧縮、8 = deflate、それ以外は非対応） |
| `isEncrypted` | Bool | 汎用フラグのビット 0 |
| `compressedSize` / `uncompressedSize` | UInt64 | 中央ディレクトリ（ZIP64 拡張を含む）の値 |
| `localHeaderOffset` | UInt64 | ローカルヘッダの位置。データの開始位置は初めて読むときに求める |
| `modificationDate` | Date? | 0x5455 の更新時刻、なければ DOS 日時（現地時刻） |

| `readability` | 条件 | 一覧 | プレビュー・縮小画像 |
|---------------|------|------|----------------------|
| `.readable` | 方式が 0 または 8、暗号化なし | 出す | 通常どおり |
| `.encrypted` | ビット 0 | 出す | 「暗号化されているため表示できません」、汎用アイコン |
| `.unsupportedMethod` | 方式が 0・8 以外 | 出す | 「対応していない圧縮方式です」、汎用アイコン |

- 一覧に出さない項目: 名前の要素が `.` で始まるもの、`__MACOSX/` 以下、`..` を含む名前、対応メディア以外のファイル（入れ子の zip を含む）
- 同じパスの重複は、中央ディレクトリで先に出たものを使う。ファイルとディレクトリが同じ名前ならディレクトリとして扱う
- 名前の判定は `ArchiveNameDecoder`（FR-074、research.md R27）

## ArchiveIdentity（zip ファイルの同一性・永続化しない）

| フィールド | 型 | 説明 |
|------------|----|------|
| `fileSize` | UInt64 | 開いたときのサイズ |
| `modificationDate` | Date | 開いたときの更新日時 |
| `inode` | UInt64 | 開いたときの inode |

- zip を含むフォルダの FSEvents を受けたら、いまの値と比べる。違っていれば（または zip が消えていれば）zip を閉じ、
  フォルダの一覧に戻ってプレビューを空にする（spec Edge Cases）

## ArchiveEntryStream（zip の中の項目の範囲読み出し・永続化しない）

動画の再生と代表フレームの取得で、項目の任意の範囲を読む（FR-072、research.md R25）。

| 格納方式 | 読み方 | メモリ |
|----------|--------|--------|
| 無圧縮 | 要求範囲を `pread` で直接読む | 応答中のチャンク（512KB）だけ |
| deflate | `InflateCursor`（最大 2 本、LRU）で展開。前へ戻るときは先頭から展開し直す | 1MB 単位のチャンクの LRU キャッシュ 32MB + カーソル 2 本 + 応答中のチャンク |

- 1つの asset が使うメモリは上の合計で決まり、動画のサイズに依存しない（SC-014: 追加分 128MB 以下）
- 一時ファイルを作らない。zip ファイルの読み出し以外のディスクの入出力を行わない

## ListItemCommands（一覧の行に対する操作の可否・永続化しない）

行の種類・「zip の中を表示中か」・「戻る先があるか」・「検索結果を表示中か」から、操作ごとの可否を返す純粋計算（FR-069・073・076・077・087、research.md R26・R30・R32・R38）。

| 操作 | 通常のフォルダのメディア・zip ファイル | 通常のフォルダの `.folder` | 通常のフォルダの `..` | zip の中（メディア・ディレクトリ・`..`） | 検索結果（メディアだけ） |
|------|----------------------------------------|----------------------------|-----------------------|-------------------------------------------|--------------------------|
| 中を表示（ダブルクリック・⌘↓） | メディアは何もしない。zip ファイルは中へ | そのフォルダの一覧へ | 親フォルダの一覧へ | ディレクトリは中へ、`..` は上へ。メディアは何もしない | 何もしない |
| 上の階層へ（⌘↑。どの行を選択中でも） | 戻る先があれば親フォルダへ | 同左 | 同左 | 1つ上へ | 何もしない |
| 開く（⌘O） | 可 | 可（既定のアプリ＝Finder で開く） | 不可 | 不可 | 可 |
| コピー・複製・名前の変更・ゴミ箱・Finder に表示 | 可 | 可（中身ごと） | 不可 | 不可 | 可（複製は元のファイルと同じフォルダに作り、一覧には加えない） |
| ペースト・移動ペースト（一覧へ） | 可 | 可（表示中のフォルダへ。選択中のフォルダの中ではない） | 可（同左） | 不可 | 不可（貼り付け先のフォルダがない） |
| ドラッグ | 可 | 可 | 不可 | 不可 | 可 |

| 入力 | 型 | 説明 |
|------|----|------|
| `kind` | ListItemKind? | フォーカス行の種類。行がないときは nil |
| `isBrowsingArchive` | Bool | zip の中を表示中か |
| `hasEnclosingLevel` | Bool | ⌘↑ で戻る先があるか（`BrowserModel.hasEnclosingLevel`）。既定は `isBrowsingArchive`（既存の呼び出しを壊さない） |
| `isShowingSearchResults` | Bool | 検索結果を表示中か（`BrowserModel.isShowingSearchResults`）。既定は false。true なら `allowsPaste` と `canGoUp` を false にする |

- 不可の操作は、メニュー項目を淡色にし、キーボードショートカットとドラッグでは何もしない（FR-073）
- 複数選択の操作の対象は `BrowserModel.operableSelection`（一覧の並び順で `.parent` を除いた選択）。`..` だけが選択されているときは対象が空になり、操作しない

## SearchPattern（検索キーワード・永続化しない）

検索キーワードとファイル名の照合（FR-082、research.md R34）。

| フィールド | 型 | 説明 |
|------------|----|------|
| `keyword` | String | 入力から前後の空白を除いたもの。空にはならない（空なら `init?(keyword:)` が nil） |
| `usesWildcards` | Bool | `*` か `?` を含むか |

| キーワード | 照合 | 例 |
|------------|------|----|
| ワイルドカードなし | 正規化したファイル名（拡張子を含む）に対する部分一致 | `cat` は `Cat01.jpg`・`my_cat.mov` に一致 |
| ワイルドカードあり | ファイル名全体との一致。`*` は 0 文字以上、`?` は 1 文字（`Character` 単位） | `*.png` は `a.png` に一致し `a.png.txt` に一致しない。`IMG_????.jpg` は `IMG_0001.jpg` に一致 |
| 前後の空白だけ・空 | `init?(keyword:)` が nil（「検索」ボタンは無効、Return は何もしない） | `"  "` |

- 正規化: キーワードとファイル名の両方を NFC にし、大文字小文字をそろえる（`folding(options: [.caseInsensitive])`）。
  濁点の合成・分解の違い（`が` と `か` + `゙`）と英字の大文字小文字を区別しない。全角・半角、ひらがな・カタカナは区別する
- 照合するのは `lastPathComponent` だけで、フォルダのパスを含めない。`[`・`]`・`\` は通常の文字として扱う

## SearchRoot と SearchRootError（検索起点ディレクトリ・永続化しない）

検索起点ディレクトリの入力の解釈と確認（FR-081、research.md R35）。

| 入力（前後の空白を除いた後） | `parse(_:home:)` の結果 |
|------------------------------|--------------------------|
| 空 | `.failure(.empty)` |
| `~` / `~/a/b` | ホームフォルダ / ホームフォルダの `a/b` |
| `/a/b/`（末尾の `/`） | `/a/b` |
| `/` | `/` |
| `~user/a`・`a/b`・`./a` | `.failure(.notAbsolute)` |

| ファイルシステムの状態 | `validate(_:)` の結果 |
|------------------------|------------------------|
| フォルダ（シンボリックリンクならリンク先のフォルダ） | `.success(リンクを解決した URL)` |
| 存在しない | `.failure(.notFound)` |
| ファイル（zip ファイルを含む）・パッケージ | `.failure(.notAFolder)` |
| 開けない（権限なし） | `.failure(.accessDenied)` |

| `SearchRootError` | `message`（入力欄の下に出す） |
|-------------------|-------------------------------|
| `.empty` | 検索起点ディレクトリを入力してください |
| `.notAbsolute` | / または ~ で始まるパスを入力してください |
| `.notFound` | フォルダが見つかりません |
| `.notAFolder` | フォルダではありません |
| `.accessDenied` | フォルダを読み取れません |

- `validate` はディスクを読むため UI スレッドの外で行う。失敗したときはモーダルを閉じず、検索を始めず、ファイルリストの表示を変えない
- 既定値はモーダルを開いた時点の `BrowserModel.listing.folder` の絶対パス

## SearchListing（検索結果の表示・永続化しない）

`FolderListing.search` に置く、表示中の検索の条件と進み具合（FR-084・085、research.md R37）。

| フィールド | 型 | 説明 |
|------------|----|------|
| `keyword` | String | `SearchPattern.keyword`（検索バーに出す） |
| `root` | URL | 確かめた検索起点ディレクトリ |
| `phase` | `.searching` / `.finished` | 列挙中か、終わったか。取り消された検索の値は残らない（一覧ごと置き換わる） |
| `totalCount` | Int | 見つかった件数（種類フィルタ適用前）。検索中は途中の件数 |

| 関数 | 内容 |
|------|------|
| `location(of fileURL: URL) -> String` | 「場所」列とサムネイルのツールチップの文字列。起点のフォルダ名に、ファイルを含むフォルダまでの相対パスを `/` でつなぐ（例: 起点 `/Users/me/Pictures`、ファイル `/Users/me/Pictures/2024/trip/a.jpg` → `Pictures/2024/trip`。起点の直下 → `Pictures`）。起点が `/` なら `/` から始めた絶対パス |

- 検索バーの文言: 「「<keyword>」の検索結果 — <起点のフォルダ名> — <totalCount> 件」。`phase == .searching` のときは「検索中…」とスピナーを添える。
  種類フィルタで絞っているときは「<totalCount> 件中 <表示件数> 件を表示」。同じ名前の起点を見分けられるよう、検索バーのラベルに `root.path` の
  絶対パスをツールチップで示す
- 保存しない（`SettingsStore` に書かない）。起動のたびに検索結果のない状態で始まる。前回のキーワードは UI が起動中だけ覚える（R39）

## 検索結果の整理（ファイル操作と外部の変更・永続化しない）

検索結果の表示中に、どの出来事で結果がどう変わるか（FR-087、research.md R38）。

| 出来事 | 結果の一覧 |
|--------|------------|
| 検索結果からゴミ箱に入れる・移動する（ツリーへのドロップを含む） | 操作後の `reloadCurrentFolder()` で、存在しなくなった結果を外す |
| 検索結果で名前を変更する | `didRenameItem(at:to:)` で、その行の URL・名前を差し替えて並べ直す。選択・フォーカスも新しい URL へ。キーワードに一致しなくなっても残す。対応メディアの拡張子でなくなったら外す |
| 検索結果で複製する | 一覧に加えない（`reloadCurrentFolder()` は存在の確認だけで、列挙し直さない） |
| アプリの外で削除・移動・名前の変更 | FSEvents（`subtrees` に起点）で届いたフォルダ以下の結果を確かめ、元の場所から消えたものを外す。確かめる結果はフォルダごとの辞書（`searchResultsByFolder`）で引き、全件を走査しない |
| アプリの外で隠しフォルダ（`~/Library` など）の中が変わる | 監視の段階で捨てる（検索結果は隠しフォルダの中にない。FR-083）。ほかのフォルダの変更が続いても、通知は最初の変更から 1 秒以内に届く |
| アプリの外で新しいファイルが現れる | 加えない |
| 外した結果がフォーカス（プレビュー中）だった | 選択から外し、プレビューを空にし、再生中の動画を止める |

## AppIcon（ビルド時のみ・Core の型ではない）

アプリバンドルのアイコン。実行時のモデルや永続化設定には含めない（FR-043〜045、research.md R14）。

| 項目 | 内容 |
|------|------|
| 原画の設計座標 | 1024×1024。角丸スクエア + 3ペインの図案。文字なし |
| 生成解像度 | 16 / 32 / 64 / 128 / 256 / 512 / 1024 px（iconset の @1x / @2x スロットを埋める） |
| 中間生成物 | `.build/AppIcon.raw/icon_<size>x<size>.png`（7サイズ） |
| iconset | `.build/AppIcon.iconset/`（標準名の10スロット） |
| バンドル成果物 | `Contents/Resources/AppIcon.icns` |
| バンドル参照 | `Info.plist` の `CFBundleIconFile = AppIcon` |
| 失敗時の扱い | 描画・解像度検証・`iconutil` のいずれかが失敗したら `.app` を作らず非ゼロ終了する |

- 原画は `Sources/make-icon/` のコードを正とし、生成済みの `.icns` はコミットしない
