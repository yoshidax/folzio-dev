# Research: リスト形式の列の表示・非表示

## R1 列見出しの右クリックメニュー
- **Decision**: `NSTableHeaderView.menu` に `NSMenu` を設定し、`NSMenuDelegate.menuNeedsUpdate` でチェックを更新する。
- **Rationale**: AppKit 標準で、Finder と同じ位置（列見出し）にだけ現れ、行の既存コンテキストメニュー（`tableView.menu`）と衝突しない。Ctrl+クリックも同じメニューになる。
- **Alternatives**: `NSTableView.headerView` のサブクラスで `rightMouseDown` を処理する案は不要に複雑。
- **確認事項**: 実装時に `FileListTableView` が `menu(for:)` を上書きしていないか、ヘッダー用に影響がないかを確認する。

## R2 変更日の取得
- **Decision**: `DirectoryLister` の読み取りキーに `contentModificationDateKey` を足す。zip の項目は entry の更新日時を使う（`creationDate` に渡している値と同じ）。
- **Rationale**: 列挙時に同時に取得でき、追加の I/O は発生しない。

## R3 サイズの表示
- **Decision**: `ByteCountFormatter`（`.file` スタイル）で表示する。フォルダ（zip 内を含む）・`..` 行は `--`。ファイルは 0 バイトを `0 バイト` と表示する。
- **Rationale**: 現状、フォルダの `fileSize` は 0 で、ファイルの 0 バイトと区別できないため、種類（`ListItemKind`）で判定する。
- **Alternatives**: `fileSize` を `Int64?` にする案は呼び出し箇所が多く、今回は種類で判定する。

## R4 並べ替えの値なし
- **Decision**: サイズの並べ替えでは、フォルダ・`..` を 0 バイトとして扱う（Finder と同じ。保守者が決定）。変更日は nil を昇順・降順とも末尾に置く（作成日と同じ規則）。
- **Rationale**: Finder の振る舞いに合わせる。昇順ではフォルダが先頭、降順では末尾になる。
- **Alternatives**: フォルダを常に末尾に置く案は、Finder と異なるため採らない。

## R5 保存形式
- **Decision**: `view.list.visibleColumns` に列の rawValue の配列を保存する。読み込み時に既知の列だけを採り、キーが無ければ既定。
- **Rationale**: 壊れた値・未知の列を無視でき（US52-AS7）、将来の列の追加と互換性を保てる。
