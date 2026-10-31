# Data Model: TAK-21

新しい永続データはない（設定のキー・最後に選択していたフォルダの形式は変えない）。

## TreeBatchTargets（FolzioCore、値型）

| 入力 | 型 | 説明 |
|---|---|---|
| selection | `[TreeItemRole]` | ツリーで選択中の行の role（行の順） |
| origin | `TreeItemRole?` | 右クリック・ドラッグを始めた行。キーボード・メニューは nil |
| originIsSelected | `Bool` | origin が selection に含まれるか |
| roots | `[URL]` | ホームとマウント中のボリュームの最上位 |

| 出力 | 型 | 規則 |
|---|---|---|
| targets | `[TreeItemRole]` | origin が nil か選択中なら selection、選択外なら `[origin]`（FR-210） |
| isSingle | `Bool` | targets が1件。false なら名前の変更・パス名・お気に入り・Finder・ペーストは無効（FR-211（2）） |
| trashTargets(roots:) | `TrashTargets` | `.folders([URL])`（1件以上の通常のフォルダ）／`.unavailable`（通常のフォルダ以外を含む・空）／`.overlapping`（親子を含む。EC-141） |
| contextMenu(roots:) | `[TreeContextMenuItem]` | 1件ならその role のメニュー、複数なら通常のフォルダのメニュー（FR-211（3）） |
| dragURLs(roots:) | `[URL]?` | targets がすべて通常のフォルダなら URL の配列、そうでなければ nil（FR-211（1）） |

- 単一の対象のときは、既存の `FavoriteCommands`（`trashTarget`・`removalTarget`・`renameTarget` など）の結果と一致させる。
- 重なりの判定は `standardizedFileURL.pathComponents` の前方一致（R2）。ディスクを読まない。

## TreeSelectionLead（FolzioApp、DragAwareOutlineView の状態）

| 項目 | 説明 |
|---|---|
| anchor | 範囲選択の起点の行。通常のクリック・⌘クリック（追加）・↑↓・ファイルリストからの同期（`syncSelection`）で更新。Shift クリック・Shift+↑↓ の範囲はここから主の行まで（R4） |
| lead | 主の行（FR-209）。通常のクリック・⌘クリック（追加）・Shift クリック・↑↓・Shift+↑↓・ファイルリストからの同期で更新。⌘クリックで外したときは更新しない。ドラッグの後はドラッグ前の値に戻す（FR-210（3）） |

主の行が折りたたみで隠れた場合も item を保ち、キーボードの移動は `parent(forItem:)` をたどって最初に見える祖先の行を起点にする（EC-143）。

行番号は展開・折りたたみで変わるため、保持は行の item（`Node`／`FavoriteEntry`）で行い、使うときに `row(forItem:)` で行番号に直す。

## 一括操作の結果

既存の `FileOperationResult`（成功・失敗と理由）をそのまま使う。成功が1件以上の移動・ゴミ箱で FR-212 の選択の更新を行う。
