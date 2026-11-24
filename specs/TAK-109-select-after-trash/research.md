# Research: ファイルリストの削除後の選択

調査日: 2026-11-17。リポジトリのコード・現行製品仕様・Issue を根拠とする。

## R1 — 削除処理の入口と成功の判定

**Evidence**: FileListViewController.moveToTrash は operationTarget の URL を coordinator.trash に渡す。
FileOperationCoordinator.trash は確認後に service.execute、履歴通知、leaveTrashedFolders、reloadCurrentFolder を行う。
FileOperationService.execute は trash で成功するとゴミ箱内の URL を result.succeeded へ格納する。

**Decision**: fileList 起点でのみ削除前の記録を取り、既存の失敗元 URL を引く処理で成功元 URL を求める。
**Rationale**: ゴミ箱内の URL では元の表示行を照合できず、汎用 reload では操作の理由が分からない。
**Alternatives considered**: result.succeeded の直接照合、すべての reload で次行選択。どちらも誤った適用範囲になる。

## R2 — 選択・プレビューと監視イベント

**Evidence**: BrowserModel.reloadCurrentFolder は新しい表示 URL との積で選択を制限する。
removeSearchResults も同様に選択を制限し、フォーカスを失うとプレビューを消す。
select はプレビュー読込・動画停止・先読みをまとめて行う。フォルダ監視も reload / prune を利用する。

**Decision**: 削除前の記録は最初の await より前。自動制限と利用者の選択操作を世代で区別する。
**Rationale**: 完了時の現在の選択だけでは監視通知で消えた元の選択や表示順を復元できない。
**Alternatives considered**: 完了時の行番号のみ、選択値の一致だけを検査。並び替え・先行監視・往復操作に弱い。

## R3 — 複数選択と右クリック

**Evidence**: file-list.md の FR-397 は、選択外の右クリック操作でも現在の選択を保つ。
BrowserModel.operableSelection は `..` を除外し、表示順で操作元を返す。

**Decision**: 全対象が元の選択に含まれる場合だけ次行選択の対象とする。残存選択を最優先する。
**Rationale**: 直近の製品仕様の操作対象と選択の分離を維持し、一部失敗も見失わない。
**Alternatives considered**: 常に削除対象の次を選ぶ。選択外の右クリックで既存の選択を失うため却下。

## R4 — 検索と遅れて届く結果

**Evidence**: search.md の FR-087 は消えたフォルダの子孫も除き、プレビュー中なら空にする。
BrowserModel.didMoveSearchItems は movedSearchPaths に元のパスを記録し、子孫や遅れて届く結果を抑止する。

**Decision**: ゴミ箱操作の成功元 URL にも同じ検索除外を使う。FR-087 に自動選択時のプレビューの例外を追加する。
**Rationale**: 次の候補が削除フォルダの中にある場合や検索中の再出現を防ぐ。
**Alternatives considered**: 直後の prune だけで判断。遅延結果を抑止できない。

## R5 — 選択なしの上下キー

**Evidence**: ListModeView の FileListTableView.keyDown は通常の矢印を NSTableView へ渡す。
ThumbnailModeView.handleArrowKey は FocusNavigator.targetIndex を使う。
現行の FocusNavigator は currentIndex が nil のとき上下とも先頭を返す。
Issue の「既に実現」との報告はリスト形式の実機確認までは未検証。

**Decision**: 通常の一覧での修飾キーなし・空選択の入口に限り ↑=末尾、↓=先頭を保証する。
**Rationale**: full screen / hidden list のメディアだけを辿る経路の先頭選択を変える必要はない。
**Alternatives considered**: 共通 targetIndex の全 overload を一律変更。プレビュー操作に波及するため却下。

## R6 — スクロールと検証

**Evidence**: ListModeView.update はフォーカス行を scrollRowToVisible する。
ThumbnailModeView は矢印と編集開始で scrollItemIntoView を呼ぶ。
Package.swift に FolzioCoreTests / FolzioAppTests / FolzioPerformanceTests が存在する。

**Decision**: 既存のスクロール関数とテスト環境を再利用する。新しい依存と表示文言は追加しない。
**Rationale**: 選択先の可視化を必要な契機だけに限定できる。
**Alternatives considered**: すべての再レイアウトでスクロール。既存のスクロール規定に反するため却下。

未解決の調査項目なし。実機上の標準テーブル挙動は実装後の手動確認で確かめる。
