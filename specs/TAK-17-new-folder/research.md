# Research: TAK-17 フォルダの新規作成

調査基準: `origin/master`（bc97861）。Cloud では Swift を実行できないため、静的な調査に基づく。GUI の挙動の推定は quickstart で確かめる。

## R1 作成操作の置き場所

- **Decision**: `FileOperating` に `createFolder(in parent: URL, baseName: String) async -> Result<URL, OperationFailureReason>` を加え、
  `FileOperationService` で detached task として実行する。`FileOperation.Kind` には加えない
- **Rationale**: `Kind` は `ConfirmationPolicy.isSkippable` と `ConfirmationPresenter` の網羅的な switch で使われ、作成は確認モーダルの
  対象外（FR-209）。作成は「対象の項目群」を持たないため、`sources` を前提にした `perform` のループにも合わない
- **Alternatives**: `Kind.createFolder` を追加する（確認関係の switch に到達しないケースを足すことになる）。App で直接 `FileManager` を呼ぶ
  （UI スレッドでの操作の禁止と Core のテスト可能性に反する）

## R2 既定名と連番

- **Decision**: `newFolderName(baseName:existingNames:)` を `NameValidation.swift` に加える。既定名が（大文字小文字を区別せず）空いていれば
  そのまま返し、使われていれば既存の `uniqueName(for:existingNames:)` の結果（「名称未設定フォルダ 2」…）を返す
- **Rationale**: `uniqueName` は名前が空いていても常に「 2」を付ける（複製用）。作成では既定名をそのまま使う必要がある。連番の規則は
  FR-018 と同じにする（FR-209）。既定名は App が表示言語の文言を渡し、Core は言語に依存しない
- **Alternatives**: `uniqueName` を変更する（複製の挙動が変わる）

## R3 作成時の同名と失敗

- **Decision**: 親を列挙して名前を決め、`FileManager.createDirectory(at:withIntermediateDirectories: false)` で作る。作成時に同名が
  現れた（`CocoaError.fileWriteFileExists`）ら、その名前を使用済みに加えて次の番号で再試行する（上限 100 回）。親がない場合は
  `destinationNotFound`、親を列挙できない場合とその他の失敗は `systemFailure`（OS の理由をそのまま）とする
- **Rationale**: `withIntermediateDirectories: false` は既存の項目を上書きせず失敗するため、EC-142 を満たす。既存の失敗理由と
  失敗の表示（FR-026・EC-111）を流用できる
- **Alternatives**: 存在確認だけで作る（確認と作成の間の競合で既存の項目に重なる恐れはないが、失敗として扱われ EC-142 を満たさない）

## R4 作成直後の名前の確定と確認モーダル

- **Decision**: `FileOperationCoordinator.rename(_:to:origin:)` に「確認を省く」引数を加え、作成直後の名前の確定だけで使う。検証
  （`validateNewName`、フォルダとして）・失敗の表示・反映（`didRenameFolder` など）は既存の経路をそのまま通す
- **Rationale**: FR-211 は検証と反映を FR-103 と同じにし、確認だけを省く。既存の経路を使えば FR-104・FR-105・履歴の扱いも一致する
- **Alternatives**: 作成前に名前入力ダイアログを出す（保守者の回答で不採用。spec の Clarifications）

## R5 有効条件の判断（Core）

- **Decision**: ツリーは `FavoriteCommands.newFolderTarget(_ role:)`（`.folder` と `.favorite` は URL、見出しと nil は nil）を加え、見つからない
  お気に入りの判定は既存の `pathnameTarget` と同じく App の `FavoriteEntry.availability` で行う。右クリックメニューは `contextMenu(for:roots:)`
  の先頭に `.newFolder, .separator` を置く（通常のフォルダ・ホーム・ボリュームの最上位・お気に入りの項目）。ファイルリストは
  `ListItemCommands.allowsNewFolder`（`!isBrowsingArchive && !isShowingSearchResults`）を加え、表示中のフォルダが読み込めない状態
  （`FolderListing.State` の `.denied`・`.failed`）は App で無効にする
- **Rationale**: 既存の ⌥⌘C・ペーストと同じ判断の置き方で、Core の単体テストで条件を固定できる。Finder の右クリックメニューも「新規フォルダ」が先頭
- **Alternatives**: すべてを App の `validateMenuItem` に書く（テストできない）

## R6 メインメニューと ⇧⌘N の作成先

- **Decision**: 「ファイル」メニューの先頭に「新規フォルダ」（keyEquivalent `"N"`・`[.command]`）と区切りを置き、`target = nil` で
  `newFolder(_:)` をレスポンダチェーンに送る。`FileListViewController` と `DirectoryTreeViewController` の両方が `newFolder(_:)` を実装する
- **Rationale**: 既存の「パス名をコピー」（⌥⌘C）と同じ仕組みで、フォーカスのあるペインが作成先を決める（FR-208 の（3））。プレビューに
  フォーカスがあるとき・フルスクリーン中・スライドショー中・隠したペインは、レスポンダチェーンに該当のビューコントローラがないため
  自動的に無効になる（FR-212）。名前の変更中は各 `validateMenuItem` で無効にする。⇧⌘T（ツールバー）が `"T"` で同じ書き方をしている
- **Alternatives**: `MainSplitViewController` で作成先を判断する（フォーカスの判断を二重に持つことになる）

## R7 ファイルリストの背景の判定とメニュー

- **Decision**: `FileContextMenu.menuNeedsUpdate` で、右クリックした位置に項目があるかをホストに問い合わせる。リスト形式は
  `tableView.clickedRow < 0`、サムネイル形式は右クリックの位置の `indexPathForItem(at:)` が nil のとき背景とする。背景のときはメニューの
  項目を作り直し、「新規フォルダ / ─ / ペースト / 移動ペースト / ─ / Finder に表示」を出す。「Finder に表示」は表示中のフォルダを対象にする
  新しいアクション（`revealDisplayedFolderInFinder(_:)`）にする
- **Rationale**: 現在は `tableView.menu` / `collectionView.menu` に1つのメニューを付け、位置に関わらず選択中の項目向けの項目を出している
  （FileContextMenu.swift）。メニュー自体を差し替えず項目だけを作り直せば、既存の `install` とメニューの所有関係を変えずに済む
- **Alternatives**: 背景用の別の `NSMenu` を `menu(for:)` の override で返す（2つのビューのサブクラスに分岐が増える）
- **要確認（GUI）**: 背景の右クリックで、`NSTableView`・`NSCollectionView` が選択を変えないこと（A-121）。変わる場合は右クリック前の選択を保つ処理を加える

## R8 ファイルリストでの作成後の編集

- **Decision**: `FileListViewController.newFolder(_:)` は、作成後に表示中のフォルダが作成先のまま（ほかの場所へ移っていない）であれば、
  `reloadCurrentFolder` の後に `model.select([url], focused: url)` で新しい行だけを選び、スクロールして名前の編集を始める。編集の開始に
  「作成直後」の印を付け、確定時のハンドラ（`onRename`）へ渡す。取り消し・空・同じ名前の確定は既存の経路どおり何もしない（印も破棄される）
- **Rationale**: `ListModeView.beginRenaming()` と `ThumbnailItemView.beginRenaming()` は選択中の1件を対象に編集を始める。印を編集の状態に
  持たせれば、取り消し後に同じフォルダを通常どおり名前の変更をしたとき確認が省かれることはない
- **Alternatives**: `FileListViewController` に「作成直後の URL」を保持する（取り消し時に消す契機がなく、通常の名前の変更で確認を省く恐れ）

## R9 ツリーでの作成後の編集

- **Decision**: 通常のフォルダ・ホーム・ボリュームの最上位では、作成後に作成先のノードを読み込み直して展開し（既存の `loadAndExpand`）、
  新しい子ノードの行で `beginEditing(.folder(child))` を始める。ツリーの選択は変えない（FR-103 と同じ）。編集の状態に「作成直後」の印を持たせ、
  `finishEditing` の確定で `rename(..., origin: .tree, confirms: false)` を呼ぶ。お気に入りの項目では、ファイルリストが登録したフォルダを
  通常の一覧として表示中（zip の中・検索結果でない）なら、ファイルリストに作成した URL の編集を依頼し、フォーカスをファイルリストへ移す。
  そうでなければ作成だけを行う（FR-210 の（3））
- **Rationale**: 既存の右クリックからの名前の変更（`beginEditingFromMenu`）は、メニューの追跡中に `makeFirstResponder` が失敗することがあるため
  次のターンで再試行している。作成は非同期の後に編集を始めるため、メニューの追跡後に実行される
- **Alternatives**: お気に入りの項目の下に一時的な行を出す（FR-063 の「子を持たない」に反する）
- **補足（実装時）**: 作成の通知と FSEvents による親の読み直しは、名前の編集中に届くことが多い。既存の `applyListing` は編集中の子があると
  先に確定するため、入力の途中で確定されてしまう。作成直後の編集に限り、新しいフォルダが読み直しの結果に残っていれば、その結果を編集の終了まで
  遅らせて適用する。通常の名前の変更の扱い（R51）は変えない

## R10 文言とショートカット一覧

- **Decision**: `TextKey` に `menuFileNewFolder`（新規フォルダ / New Folder）、`newFolderDefaultName`（名称未設定フォルダ / untitled folder）、
  ショートカット一覧の説明と条件を加える。`ShortcutCatalog` に `newFolder`（⇧⌘N、`files`、`duplicate` の後）を加え、件数は 45 になる
- **Rationale**: Finder の表記に合わせる（A-119）。ショートカット一覧は契約の全行と照合するため、カタログ・契約・テストの件数を同時に変える（FR-203）
- **Alternatives**: なし
