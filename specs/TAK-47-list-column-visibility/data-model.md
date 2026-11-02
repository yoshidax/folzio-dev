# Data Model: リスト形式の列の表示・非表示

## ListColumn（FolzioCore）
`creationDate` / `kind` / `size` / `modificationDate`。この順がメニューと列の順。ファイル名は列として常に表示し、ポップアップの対象ではないため含めない。場所（`location`）は含まない（検索中の自動列）。

## ListColumnVisibility / ViewSettings.visibleColumns
- 表示する `ListColumn` の集合（ファイル名は常に表示のため含めない。空もあり得る）。
- 既定: `{name, creationDate, kind}`。
- 保存: `UserDefaults` の `view.list.visibleColumns`（rawValue の文字列配列）。読み込み時、未知の値（`name` を含む）を捨てる。型が違うときは既定。

## MediaFile
- 追加: `modificationDate: Date?`（既定 nil）。通常のファイル・フォルダは `contentModificationDate`、zip の項目は entry の更新日時。
- 既存: `fileSize`。フォルダと `..` では意味を持たない。表示は `--`（種類で判定）、並べ替えでは 0 バイトとして扱う。
- 保存: ファイル名で最後に使った並べ替えの方向を `view.sort.nameAscending` に保存する（既定は昇順）。並べ替えの列が `name` のときは `view.sort.ascending` と同じ値。

## SortColumn
- 追加: `size`, `modificationDate`。`location` は従来どおり保存しない。
- 保存済みの `view.sort.column` に新しい値が入っても読み込める（rawValue を共有）。

## 状態遷移
列の表示切り替え → `ViewSettings.visibleColumns` 更新 → 保存 → `ListModeView` が列の `isHidden` を更新（再読み込みなし）。並べ替えの列は変えない。
