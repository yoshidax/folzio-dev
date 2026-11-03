# Data Model: TAK-18

永続化するデータはない。Core に追加する純粋な判断だけを定める。

## QuickLookTargets（FolzioCore、新規）

Space で Quick Look に渡す対象を選ぶ（FR-249・250、EC-171）。

| 入力 | 型 | 説明 |
|---|---|---|
| files | `[MediaFile]` | 表示中の一覧（検索結果を含む）の行。並び順がそのまま対象の順になる |
| selected | `Set<URL>` | 選択中の行 |
| isBrowsingArchive | `Bool` | zip の中を表示中か（A-150） |

| 出力 | 型 | 規則 |
|---|---|---|
| `urls` | `[URL]` | `files` のうち `selected` に含まれ、`kind.isMedia` の行の URL を一覧の順に並べる。`isBrowsingArchive` なら空。フォルダ・zip・`..` は除く |

- 選択が空、メディアが0件、zip の中のときは空配列（EC-171 の「何もしない」の根拠）。
- 一覧に存在しない URL は含めない（EC-172 の再計算でも同じ関数を使う）。

## ListItemKind の拡張（FolzioCore、変更）

`opensInDefaultApp(isBrowsingArchive:) -> Bool`: `.media` かつ `isBrowsingArchive == false` のとき true（FR-251、US3-AS31〜33）。
`opensAsContainer`（既存）とは排他。zip の中のメディアは false。

## 状態（App、永続しない）

| 名前 | 場所 | 内容 |
|---|---|---|
| `QuickLookCoordinator.items` | App | 現在パネルに渡している URL の並び（`QuickLookTargets.urls` の結果）。ファイルリストの選択が変わるたびに再計算する（FR-254） |
| `isQuickLookVisible` | App | パネルの表示中か。プレビューペインの動画の自動再生を抑える判断に使う（EC-175） |
| パネルの表示状態 | `QLPreviewPanel` | 開閉は OS が持つ。Folzio は `isVisible` を見るだけ |

状態遷移: 閉 → (Space、対象あり、フォーカスがファイルリスト) → 開 → (矢印キーで選択が変わる → 項目を再計算 → 対象ありなら開のまま / 0件なら閉) →
(Space / Esc / 閉じるボタン / EC-172 / ダブルクリック) → 閉。
ショートカット一覧のカタログには `ShortcutID.quickLook`（keys: "Space"、section: files）を追加する。
