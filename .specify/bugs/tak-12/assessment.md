# Bug Assessment: 表示中のフォルダ自体・祖先の外部改名・削除が一覧に反映されない

- **Slug**: tak-12（Issue ID から生成）
- **Created**: 2026-11-01
- **Source**: [TAK-12](https://linear.app/takyoshida/issue/TAK-12/通常閲覧中のフォルダ自体の外部改名削除が一覧に反映されない)（host: linear.app、allowlisted。Linear MCP で取得）
- **Verdict**: valid（保守者が GUI で祖先の削除を再現。他のケースはコード上で確認）
- **Severity**: medium（存在しないフォルダの内容を表示し続け、その一覧への操作は失敗する。データの損失はない）

## Report

folzio-oss main c22eee6 の AI レビューで、表示中のフォルダを外部で改名すると、存在しない旧フォルダの一覧が表示され続けると報告された（P2）。
起票時の調査は開発用 master `090bf46` の静的確認。

保守者が master `f458d78` の GUI で次を確認した（2026-11-01）: 親のある、中身のあるフォルダをツリーで選んだ状態で、アプリ外で親フォルダを削除すると、
ツリーからはフォルダが消えるが、リストは更新されず、削除されたはずのファイルとフォルダが表示されたままになる。

## Symptom

表示中のフォルダ自体、またはその祖先がアプリ外で改名・移動・削除されると、リストが古い内容のまま残る。ツリーは消えた行の代わりに祖先を選ぶため、
ツリーとリストの表示が食い違う。期待する動作は、リストが存在する場所へ移り、存在しない旧フォルダの内容を表示し続けないこと。

## 仕様との照合

実装が仕様に反していると判断する。FR-042（overview.md）は外部でのファイル・フォルダの追加・削除・名前変更をツリーとリストに反映することを、
EC-13（overview.md）は表示中のファイル・フォルダの外部での削除・リネームを反映することを要求する。表示中のフォルダが消えたときの移動先は
`specs/product/` に明記がない。既存の実装（表示中のフォルダ自体が通知されたときに親へ移る処理、`BrowserModel.handleFileSystemEvent`）と
FR-079 の親への退避に合わせ、存在する最も近い祖先へ移る。消えた場所の履歴は navigation-history.md の規則（外部の変更で消えた場所を取り除く）に従う。

## Reproduction

1. 親のある、中身のあるフォルダ `G/P/X` をツリーで選び、リストに `X` の内容を表示する。
2. アプリ外（Finder の「ゴミ箱に入れる」）で `P` を削除する。`X` 自体の改名・移動・削除、祖先の改名・移動でも同じ。
3. ツリーからは `P` が消えて `G` が選ばれるが、リストは `X` の内容のまま。

ターミナルの `rm -rf P` では `X` 自体も通知されるが、退避先が1つ上の `P`（消えている）に固定されているため、リストは「フォルダが見つかりません」になると予想される（未再現）。

## Suspected Code Paths

- `Sources/FolzioCore/FileSystem/FileSystemWatcher.swift:144-151, 214-232` — 通常閲覧の `folders` の stream は WatchRoot を使わず、
  イベントのパスの親が監視対象にあるときだけその親を通知する。改名・移動・ゴミ箱は消えた項目のパスの1件だけなので、`X` は通知されない。
- `Sources/FolzioCore/Browser/BrowserModel.swift:797-833`（修正前） — 現在のフォルダとの完全一致の通知だけを受け付ける。親・祖先の通知では存在を確かめない。
  `X` が消えていたときの移動先は `deletingLastPathComponent()` 固定。
- `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift:1646-1689` — ツリーは親の通知で子を読み直し、`isRestoringSelection` のまま
  残っている祖先を選び直すため、リストは移らない（R33）。
- `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift:1587-1601` — 監視対象に `subtrees` を渡すのは検索中だけ。

## Root Cause Hypothesis

確信度は高い。watcher は WatchRoot の file descriptor 枯渇への対策（bug: fsevents-watchroot-fd-exhaustion）として、フォルダ自体・祖先の消失を
親の変更として通知する。一方 `BrowserModel` は現在のフォルダ自体の通知でしか存在を確かめないため、親・祖先の通知が捨てられる。

同じ経路で起きるケース:

- A: `X` 自体の改名・移動・ゴミ箱
- B: 祖先の改名・移動・ゴミ箱（保守者が削除で再現）
- C: zip の中を表示中に、zip を含むフォルダか祖先が消える（`listing.folder` は zip を含むフォルダ）
- D: お気に入りから開いたフォルダ（またはその下）の改名・削除
- `rm -rf` で祖先ごと消えたとき、消えた親へ移って「見つかりません」になる

## Proposed Remediation

**Preferred**: `BrowserModel.handleFileSystemEvent`（通常閲覧）で、通知されたフォルダが現在のフォルダ自体か祖先なら、現在のフォルダの存在を
メインスレッド外で確かめる。消えていれば、存在する最も近い祖先へ `.relocated(vanished: [最も浅い消えたフォルダ])` で移る。存在していれば、
現在のフォルダ自体が通知されたときだけ従来どおり zip の確認か再読込を行う。祖先の判定と最も近い祖先の探索は `FolderNavigation` の純粋関数にする。
watcher は変えない（WatchRoot を使わない）。

**Alternatives**:
- `folders` の stream で WatchRoot を使う: file descriptor の枯渇を再発させるため採らない。
- 現在のフォルダだけを WatchRoot の別 stream で監視する: 深さ分の descriptor で済むが、stream の作り直しが増え、通知の経路が二重になる。
  親の通知で足りるため採らない。

**Files likely to change**:
- `Sources/FolzioCore/Browser/BrowserModel.swift`
- `Sources/FolzioCore/Model/FolderNavigation.swift`
- `Tests/FolzioCoreTests/BrowserModelFolderTests.swift`、`BrowserModelArchiveTests.swift`、`FolderNavigationTests.swift`

**Tests to add or update**:
- 親だけが通知されたときに、改名された表示中のフォルダから親へ移る。
- 祖先が消えたとき、存在する最も近い祖先へ移る。`rm -rf` 相当（現在のフォルダと祖先が通知される）でも、消えた親を飛ばす。
- 祖先の変更でも現在のフォルダが存在すれば、場所・選択・プレビューを保つ。
- 名前の前方一致だけの兄弟（`day1x` と `day1`）を祖先と誤認しない。`/private/var` と `/var` を同じとみなす。
- zip を含むフォルダの改名で zip から出る。

## Risks & Considerations

- 祖先の通知（展開中の祖先の中の変更など）のたびに stat が1回増える。メインスレッド外で行い、存在すれば再読込はしない。
- アプリ内の改名・移動・ゴミ箱は先に `didRenameFolder` / `leaveTrashedFolders` で場所を更新するため、後から届く通知では存在を確かめるだけで終わる。
- E（外部ボリュームの取り外し）は通知の経路が別（`volumes.changes`）のため、この修正の対象外。
- ツリーで自動的に選び直された祖先の行をクリックしても移動しない問題は、リストが同じ祖先へ移るため、この修正で実害がなくなる。
- Cloud では FSEvents・GUI・Swift のビルドとテストを実行できない。

## Open Questions

- なし（修正方針は保守者が 2026-11-01 に承認）。
