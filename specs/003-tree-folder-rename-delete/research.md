# Research: ツリーのフォルダの名前の変更と削除

番号は 002 の research.md（R48〜R56）から続ける。コードのコメントで `R57` のように参照する。
Technical Context に NEEDS CLARIFICATION は残っていない。以下は設計上の判断の記録。

## R57. パッケージになる名前の検証（EC-53・EC-14、US1-AS39）

- **Decision**: `validateNewName(_:for:existingNames:isDirectory:)` に、`isDirectory` が true のときだけ、新しい名前の拡張子が
  パッケージの型（`UTType(filenameExtension:conformingTo: .directory)` が `.package` に適合する）なら
  `.invalid(reason: "この名前にするとフォルダがパッケージとして扱われ、表示されなくなります")` を返す検査を足す。
  検査は既存の4つの検査（空・`/` `:`・先頭の `.`・同名）の後、`isDirectory` の早期 return の前に置く。
  判定は Core の純粋関数 `PackageName.isPackage(_:)` に分ける（`UniformTypeIdentifiers` は AppKit ではないため Core で使える）
- **Rationale**: ツリーとファイルリストのフォルダの名前の変更は、どちらも `FileOperationCoordinator.rename` から
  `validateNewName` を呼ぶため、1か所の変更で両方に効く（EC-14 の変更）。ディスクの状態（バンドルビット）ではなく
  名前だけで決めるため、名前を変える前に判定でき、テストもファイルを作らずに書ける。`.app`・`.bundle`・`.rtfd` など
  システムに登録された型を、ハードコードした一覧なしで拾える
- **Alternatives considered**:
  - 名前を変えた後に `isPackageKey` を見て、パッケージになっていたら元に戻す: ファイルシステムを2回変え、戻すのに
    失敗すると部分的な変更が残る（EC-47・EC-08 に反する）
  - 拡張子の一覧（`app`・`bundle` など）を持つ: インストール済みのアプリが登録するパッケージ型（`photoslibrary` など）を
    取りこぼし、一覧の保守も要る
  - `FileOperationService.rename` 側で拒否する: 失敗の表示（FR-026）になり、ファイルリストの検証エラーの表示（EC-14）と揃わない
- **確認すること（テスト）**: `Photos.app`・`Docs.rtfd`・`X.bundle` は true、`2025.01`・`Photos`・`a.txt` は false。
  大文字の拡張子（`Photos.APP`）の扱いは UTType の照合に従い、テストで結果を固定する

## R58. 確認モーダルを省略できるかの判断を Core に移す（FR-024・FR-079 の変更、A-33、SC-027）

- **Decision**: 省略できるかの判断を Core の `ConfirmationPolicy.isSkippable(_ kind: FileOperation.Kind, origin: OperationOrigin)`
  に置く。`OperationOrigin` は `.fileList` と `.tree` の2つ。`.trash` は `.fileList` のときだけ省略でき、`.tree` では省略できない。
  `.copy` はどちらの経路でも省略でき（ツリーのフォルダへのペースト・ドロップのコピーを含む。従来どおり。FR-024 の変更）、
  `.move`・`.rename` はどちらでも省略できない（既存どおり）。`ConfirmationPresenter.confirm` は
  `origin` と、確認モーダルに添える絶対パス `location` を受け取り、省略できないときは「今後この確認を表示しない」も出さない
- **Rationale**: 今は判断が App の `ConfirmationPresenter.isSkippable` にあり、テストがない。今回の変更で「同じゴミ箱でも
  経路で変わる」規則になり、取り違えると SC-027（確認なしの削除 0 件）を破るため、Core に移してテストで固定する（憲章 IV）
- **Alternatives considered**:
  - `FileOperation.Kind` に `.trashFromTree` を足す: `FileOperationService` の実行には違いがなく、確認の都合で操作の種類を
    増やすことになる
  - ツリーだけ専用の `confirmTrashingFolder` を `ConfirmationPresenter` に足す: お気に入りの削除と同じ形で書けるが、
    判断がテストのない App に残る
- **確認モーダルの本文**（ツリーから行うとき。FR-079・FR-103、Clarifications の2問目）: 既存の本文（対象の件数・名前・
  「フォルダは中身ごと…」）の後に「場所: <対象のフォルダの絶対パス>」を足す。ファイルリストからの操作の本文は変えない

## R59. ツリーの名前の変更の対象と右クリックメニュー（FR-103・FR-099 の変更、US1-AS35・45、A-37）

- **Decision**: `FavoriteCommands.renameTarget(_:)` の戻り値を `URL?` から `TreeRenameTarget?`（`.favorite(URL)` /
  `.folder(URL)`）に変える。`.folder` は `trashTarget` と同じく、ルート（`FolderNavigation.enclosingFolder` が nil）を除く。
  そのため引数に `roots` を足す。`TreeContextMenuItem` に `.renameFolder` を足し、通常のフォルダ（ルート以外）の
  右クリックメニューを `[.moveToTrash, .separator, .renameFolder, .separator, .pasteHere, .movePasteHere, .separator,
  .addToFavorites, .separator, .revealInFinder]` にする。ルートは従来どおり `.moveToTrash` も `.renameFolder` も出さない
- **Rationale**: Return・「編集 > 名前を変更」・右クリックの3つの経路が同じ判断を使い、見出し・ルートで何もしない規則
  （US1-AS35・45）を1か所で守れる。並びはファイルリストの右クリックメニュー（ゴミ箱に入れる → 区切り線 → 名前を変更）と
  揃える（A-37）
- **Alternatives considered**:
  - `renameTarget` を残し、`folderRenameTarget` を別に足す: 呼び出し側で2つの判断の優先順位を書くことになり、
    取りこぼすとお気に入りの項目の Return が実際のフォルダの名前の変更になる

## R60. ツリーの行の中での編集を、お気に入りと通常のフォルダで共有する（FR-103、US1-AS36〜39）

- **Decision**: `DirectoryTreeViewController` の編集の状態 `editingFavorite: FavoriteEntry?` を
  `editingTarget: EditingTarget?`（`.favorite(FavoriteEntry)` / `.folder(Node)`）に置き換え、002 の行内編集
  （R51：セルのテキストフィールドを編集可能にしてフィールドエディタで編集する）をそのまま両方に使う。違いは次のとおり
  - 開始時の選択範囲: お気に入りは全選択（FR-099）、フォルダはファイルリストと同じく最後の「.」より前
    （`deletingPathExtension`。`ListModeView.beginRenaming` と同じ）
  - Formatter: お気に入りは `FavoriteNameFormatter`、フォルダは付けない（ファイルリストの編集欄と同じ）
  - アクセシビリティラベル: お気に入りは「お気に入りの名前」、フォルダは「フォルダの名前」
  - 確定: お気に入りは `FavoriteFolders.commitDisplayName`。フォルダは前後の空白を除き、空・編集前と同じなら何もしない
    （EC-48。`ListModeView.finishRenaming` と同じ）。それ以外は編集を終えてから `FileOperationCoordinator.rename(_:to:origin: .tree)`
    に渡す。検証エラー（EC-14）・確認モーダル（FR-024）・失敗の表示（FR-026）は、ファイルリストと同じくコーディネータが出す
- **Rationale**: 編集の開始・確定・取り消し・メニューを開いたときやボリュームの増減での確定（002 の R51 の対処）は、
  対象がお気に入りでもフォルダでも同じ問題を持つ。状態を1つにまとめれば、`validateMenuItem` の編集中の無効化（R53）も
  そのまま両方に効く。「名前の変更中」の判定はフィールドエディタが first responder かで行っているため（002 の R53）、
  ツリーのフォルダの編集中も契約の無効化が自動で効く（FR-102 の変更）
- **Alternatives considered**:
  - フォルダ用に別の編集の状態と処理を持つ: 同じ不具合の対処を2か所に書くことになる
  - シートで新しい名前を入力させる: ファイルリスト（行の中で編集）と操作が揃わない（A-32）

## R61. 名前を変えたフォルダの配下の URL の付け替え（FR-104・105、EC-50）

- **Decision**: Core に `RenamedFolder`（`from: URL`・`to: URL`）を置き、`rebase(_ url: URL) -> URL?` で、名前を変えたフォルダ
  自身またはその配下を指す URL を新しい場所の URL に付け替える（関係のない URL は nil）
  - `file` スキーム: `standardizedFileURL.pathComponents` が `from` の要素で始まるときだけ付け替える（`/a/Photo` と
    `/a/Photos` を取り違えない）。ディレクトリを表す末尾の `/` は保つ
  - `mvzip` スキーム（zip の中の項目）: クエリの zip の絶対パスを付け替え、`ArchiveURL.entry(archive:path:)` で作り直す
  - `mvparent` スキーム（`..`）は付け替えない（`rebuildListing` が表示中のフォルダから作り直す）
- **Rationale**: ツリーのノード・ファイルリストの行・選択・検索結果・zip の中の位置・最後に選択していたフォルダの
  すべてが同じ規則で付け替わり、どこか1つだけ古い場所を指す食い違いを防げる。URL の解析は既存の `ArchiveURL` に任せ、
  形式を2か所で知らない
- **Alternatives considered**:
  - 名前を変えた後にディスクから読み直す: 表示中のフォルダが消えたとして親へ移る（`handleFileSystemEvent`）、zip の中の表示が
    閉じる、プレビューと再生中の動画が止まるなど、FR-104 の「変えない」を守れない
  - `path` の文字列の前方一致で付け替える: 区切りを確かめないと兄弟のフォルダ（`Photos2`）まで付け替わる

## R62. ファイルリストと保存値の付け替え（FR-104、US1-AS40・41、EC-50・51、SC-024）

- **Decision**: `BrowserModel.didRenameFolder(from:to:)` を足す。ディスクは読まず、`RenamedFolder.rebase` で次を付け替える
  - `listing.folder`・`listing.archive`（zip の絶対パス）・`allFiles` の各行の `url`（行が名前を変えたフォルダ自身なら `name` も）・
    `selection`（選択とフォーカス）・`listing.search?.root`・検索結果の索引（`searchResultsByFolder`）・
    設定の `lastFolder`（FR-003）
  - 付け替えた後に `allFiles` を並べ直して `rebuildListing()` する（親フォルダを表示中なら行が並び順の位置へ移る。US1-AS41）
  - `preview` は変えず、`select` も呼ばない（プレビューを読み直さず、`stopPlaybackSignal` も増やさない。再生中の動画は
    開いた URL のまま続く）。`navigationGeneration` も増やさない（読み込み中の一覧の結果を捨てない）
  - `FileOperationCoordinator.rename` は、対象がフォルダで名前の変更に成功したとき、`didRenameItem` の代わりにこれを呼ぶ。
    呼ぶ順は「ツリーの付け替え（R64）→ `didRenameFolder` → `reloadCurrentFolder` → `onFoldersChanged`」とする
- **Rationale**: 付け替えを FSEvents より先に済ませれば、後から届く古い場所のイベントは表示中のフォルダに当たらず、
  `handleFileSystemEvent` が親へ移る処理に入らない。`reloadCurrentFolder` は新しい場所を読み、行の URL が付け替え後と
  同じなので選択はそのまま残る（`reloadCurrentFolder` は選択と一覧の積を取るだけ）
- **Alternatives considered**:
  - `selectFolder(新しい場所)` で開き直す: 選択・スクロール・プレビューが失われる（SC-024 に反する）
  - 一覧の URL は古いままにして、操作の時だけ付け替える: 古い URL を受け取るすべての経路（⌘C・ドラッグ・`..`・⌘↑・
    検索の起点の既定値）に付け替えを入れることになり、漏れが出る
- **残る差（GUI で確かめる）**: 一覧の行の URL が変わるため、`ListModeView`・`ThumbnailModeView` は `reloadData` する。
  行の並びと選択は同じなので、スクロールは `scrollRowToVisible` の最小限のまま。サムネイルのキャッシュのキーは URL のため、
  サムネイル形式では縮小画像を読み直す（一瞬の表示の差）。quickstart で確かめ、気になる場合は後の feature で扱う

## R63. 検索中・検索結果の表示中の名前の変更（FR-105、EC-52、US1-AS42、SC-025）

- **Decision**:
  - 表示中の検索結果は R62 の付け替えで新しい場所になる。「場所」列とツールチップは URL から作るため（`SearchListing.location(of:)`）、
    付け替えだけで新しい名前になる。検索起点そのものや祖先の名前を変えたときは `listing.search?.root` も付け替わり、
    検索バーの起点名とツールチップの絶対パスが新しくなる。「場所」列で並べ替えていれば並べ直しで反映される
  - 検索中（`phase == .searching`）は、検索を止めない。`BrowserModel` は検索ごとに名前の変更の記録（`[RenamedFolder]`）を持ち、
    後から届いたバッチの URL も記録の順に付け替えてからマージする。さらに、名前を変えたフォルダが検索起点の配下（起点そのものと
    祖先を含む）なら、新しい場所（起点そのものか祖先なら新しい起点）を同じ条件で追加で列挙し、URL が既に結果にあるものは捨てて
    マージする。元の列挙と追加の列挙がどちらも終わったときに `phase` を `.finished` にする
  - 検索の対象でなくなったファイルを外す規則（FR-105）は、アプリの中での名前の変更では起きない（先頭の「.」とパッケージに
    なる名前は FR-103・EC-53 で拒否する）。そのため専用の処理は持たない。アプリの外での名前の変更で消えたファイルは、既存の
    外部変更の反映（FR-087、`pruneMissingResults`）で外れる
- **Rationale**: 列挙中のディレクトリの名前を変えると、`FileManager` の列挙はまだ読んでいない配下を古いパスで辿れず、
  結果を取りこぼすおそれがある。新しい場所を追加で列挙し、URL で重複を除けば、列挙の内部の振る舞いに頼らずに EC-52 の
  「以後に見つかったファイルも新しい場所で加わる」を満たせる
- **Alternatives considered**:
  - 検索をやり直す: 結果が一度空になり、選択とプレビューが失われる（US1-AS42 に反する）
  - 追加の列挙をせず、元の列挙の結果の付け替えだけにする: 取りこぼしが起きうる
- **確認すること（テスト）**: スタブの searcher で、名前の変更の後に古い場所の結果が届く場合・新しい場所の追加の列挙と
  重なる場合に、結果が新しい場所で1件ずつになること

## R64. ツリーのノードの付け替えと展開状態の保持（FR-104、US1-AS36・37、SC-022）

- **Decision**:
  - `DirectoryTreeViewController` は、名前の変更の成功を `FileOperationCoordinator.onFolderRenamed` で受け、読み込み済みの
    ノードのうち名前を変えたフォルダ自身と配下の `Node.folder.url`（自身は `name` も）を `RenamedFolder.rebase` で付け替える。
    ノードのオブジェクトは作り直さないため、展開状態・選択・サブフォルダの有無の確認結果はそのまま残る
  - 既存の `applyListing` は、読み直しのたびに子の `Node` を作り直している（状態だけ引き継ぐ）。これを、同じ場所の既存の
    `Node` を使い回すように変える（`children` と展開状態を保つ）。名前の変更の後に親を読み直すと（`onFoldersChanged` →
    `refreshFolders`）、付け替え済みのノードがそのまま使い回され、兄弟の並び順の位置に移る
  - 選択中の行が名前を変えたフォルダか配下なら、読み直しの後に `scrollRowToVisible` で最小限スクロールする
  - 子の読み込み中（`loadChildrenIfNeeded` の `await` の間）に名前が変わったノードは、読み込みの結果を捨てて
    `children = nil` に戻す（次の展開で新しい場所を読む）。比べるのは読み込みを始めたときの URL と今の `node.url`
  - ファイルリストからフォルダの名前を変えた場合も同じ通知を受けるため、ツリーの展開状態が保たれる（EC-17 の変更）
- **Rationale**: NSOutlineView の展開状態は item のオブジェクトに結びつくため、オブジェクトを保てば展開と選択を保てる。
  使い回しは外部の変更の反映でも展開状態を保つことになり、振る舞いがよくなる方向の変更である
- **Alternatives considered**:
  - 名前を変えたノードだけを `moveItem(at:inParent:to:inParent:)` で動かす: 後から届く FSEvents で親を読み直すと、
    今の `applyListing` が子を作り直して展開状態を失う
- **GUI で確かめること**: 名前を変えたフォルダを展開していた場合に、配下の展開状態がそのまま残ること

## R65. お気に入りの見つからない表示と復活（FR-106、US1-AS43、EC-51、SC-026）

- **Decision**: お気に入りの登録内容（場所・並び・表示名）は変えない。ツリーは名前の変更の通知を受けたら、
  `refreshFavoriteAvailability()` で登録したすべてのフォルダの有無を確かめ直す。元の名前に戻した場合も、名前の変更として
  同じ通知が来るため、元の場所にフォルダが戻り通常の表示に戻る。アプリの外で名前を変えた・戻した場合に備え、FSEvents の
  バッチ（`refreshFolders`）で、変更のあったフォルダがお気に入りの親だけでなく祖先（同じか、登録したフォルダの
  `pathComponents` の途中）であっても確かめ直すように、`refreshFavoriteAvailabilityIfNeeded` の判定を広げる。
  アプリのアクティブ化での確認（FR-067）は既存どおり
- **Rationale**: 既存の確認（`refreshFavoriteAvailabilityIfNeeded`）は、変更のあったフォルダがお気に入りの親かどうかで
  判断するため、祖先の名前を変えた場合を拾えない。登録は数十件程度で、確認は UI スレッドの外（`FavoriteProbe`）で行うため、
  毎回すべてを確かめても負担にならない。表示名と並びはキーが場所のため、元の場所に戻れば自然に元に戻る
- **Alternatives considered**:
  - お気に入りを新しい名前に追従させる: FR-106（ファイルリストでの名前の変更と同じく追従しない）に反する

## R66. ツリーのフォルダのゴミ箱（FR-079 の変更、US1-AS44、SC-027）

- **Decision**: `FileOperationCoordinator.trash(_:origin:)` に `origin` を足し、ツリーの ⌘⌫・「ファイル」「編集」メニューの
  「ゴミ箱に入れる」・右クリックメニューの「ゴミ箱に入れる」は `.tree` で呼ぶ。確認モーダルには絶対パスを添える（R58）。
  ゴミ箱に入れた後の処理（表示中のフォルダか祖先なら親へ移る、それ以外はツリーの選択を変えない）は既存どおり
- **Rationale**: 既存の経路をそのまま使い、確認の規則だけを変える。メニューバーの項目もツリーにフォーカスがあるときは
  ツリーの `moveToTrash(_:)` に届くため（応答チェーン）、追加の配線は要らない

## R67. 検証の方針（憲章 II・IV、SC-022〜027）

- **Core のテスト**（Swift Testing）:
  - `PackageName`・`validateNewName`（パッケージになる名前の拒否、ファイルには適用しないこと）
  - `ConfirmationPolicy`（経路と操作の種類のすべての組み合わせ）
  - `FavoriteCommands`（`renameTarget` の役割ごとの結果、ルートの除外、右クリックメニューの並び）
  - `RenamedFolder`（自身・配下・兄弟の前方一致・関係のない URL・zip の中の URL・末尾の `/`）
  - `BrowserModel.didRenameFolder`（表示中のフォルダ自身・祖先・親の一覧・zip の中・検索結果・検索中の後から届く結果と
    追加の列挙・`lastFolder`・プレビューと `stopPlaybackSignal` が変わらないこと・名前を変えた後の `handleFileSystemEvent` で
    親へ移らないこと）。異常系として、関係のないフォルダの名前の変更で何も変わらないことを含める
- **性能**: 10,000 件の検索結果を持つ状態で `didRenameFolder` を呼び、100ms 未満で終わることを `MediaViewerPerformanceTests` で
  確かめる（UI スレッドで行う処理のため。表示の停止の基準 SC-004 と同じ値）
- **GUI**（quickstart.md）: 行の中での編集・確認モーダル・ツリーの展開状態・ファイルリストのスクロールと動画の再生・
  検索結果の「場所」列・お気に入りの淡色表示と復活・VoiceOver の読み上げ
