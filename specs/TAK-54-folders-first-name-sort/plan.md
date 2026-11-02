# Implementation Plan: リスト形式の名前順でフォルダを常に先頭にまとめる

**Feature**: `specs/TAK-54-folders-first-name-sort/`（[spec.md](spec.md)）
**Issue**: [TAK-54](https://linear.app/takyoshida/issue/TAK-54/リスト形式の名前順でフォルダを常に先頭にまとめるfinder-と同じ)

## 方針

並べ替えは `Sources/FolzioCore/Model/Sorting.swift` の `sorted` / `sortedMerge` が一括で担い、`BrowserModel` の全経路（通常の一覧・検索結果・zip の中・段階追加）が
この 2 関数を通る（`BrowserModel.swift` の `sorted(` 8 か所と `sortedMerge(` 1 か所）。したがって、**変更は `precedes`（比較関数）に集約**し、UI（AppKit）は変えない。

### 変更する比較（`precedes`）

- `order.column == .name` のときだけ、列の値の比較より前に「フォルダか」で比べる。
  - 一方だけがフォルダなら、昇順・降順に関係なくフォルダが前（`true`/`false` を方向に依存せず返す）。
  - 両方がフォルダ、または両方がフォルダでなければ、従来の名前の自然順（降順は反転）へ進む。
- フォルダ判定は `ListItemKind` の `.folder` と `.directory`。`.archive`・`.media`・`.parent` は含めない。`MediaFile` か `ListItemKind` に `isFolderRow` のような計算プロパティを足す（既存の `iconTone` の近く）。
- 他の列（作成日・種類・サイズ・変更日・場所）の分岐は触らない。
- `sorted` は `..` を先に外すので変更しない。`sortedMerge` は `precedes` を使うので、`sorted(a + b)` と同じ順序になる性質（R36・FR-085）は保たれる。
  `precedes` が全順序（推移的）であることを、フォルダ判定の追加後も確認する: 比較は「(フォルダか, 名前)」の辞書式順序で、降順はフォルダ判定を反転せず名前だけ反転するため、推移性は保たれる。

### 影響しないもの

- `SortOrder` の保存・復元（`view.sort.*`）、列の非表示時の切り替え（FR-277）、「表示 > 並べ替え」と列見出し（`ListModeView.swift`）は変えない。
- `localizedKindName` など種類名の処理は変えない。

## 仕様・文書の反映

- 実装と検証の後に、spec.md の「反映先」の表のとおり `specs/product/file-list.md`（FR-287・A-25・US57-AS1〜AS5・SC-148〜151）と `search.md`（FR-084）へ反映する。
  あわせて `contracts/keyboard-and-menus.md` の検索結果の並び、`docs/usage.ja.md` と `docs/usage.md` の検索結果の説明を直す。
- ID の衝突は、反映の直前に `git merge origin/master` した上で `docs_private/cloud-agent-workflow.md` 7 章の確認コマンドで調べる。
- `README.md` と `README.ja.md` は、並べ替えの説明がある場合だけ同じコミットで両方を直す（現時点では該当なし。タスクで確認する）。

## 検証

- Core: `Tests/FolzioCoreTests/SortingTests.swift` に、名前順の昇順・降順でフォルダ先頭になるテスト（folder・directory・archive・media・parent の組み合わせ）、
  他の列が変わらないテスト、`sortedMerge` が `sorted(a + b)` と一致するテスト（フォルダを混ぜたランダム入力）を追加し、
  「フォルダとファイルを混ぜる」前提の既存テスト（`mixesDirectoriesAndMediaByName`・`mixesFoldersWithFiles`）の期待値を新しい順序に直す。
- 既存の他のテスト（`BrowserModel*Tests`・`FileNameSearcherTests` など）のうち、名前順でフォルダとファイルが混ざる期待値を持つものを、`swift` を実行できないため、
  `grep` で洗い出して期待値を更新する（不足分は CI の失敗で検出する）。
- 性能: `PerformanceBaselineTests` の並べ替えと `sortedMerge` の基準（0.05 秒・0.1 秒・1 秒）を CI の性能テストのログで確認する。比較にフォルダ判定が加わるだけで計算量は変わらない。
- Cloud の検査: `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`。
- CI: `swift build`、`swift test`。保守者のローカルでの起動スモーク（[quickstart.md](quickstart.md)）。

## 憲章・規約との整合

- `FolzioCore` だけの変更で AppKit を import しない。UI スレッドの処理は増やさない。ネットワーク API は使わない。
- コードコメントは英語（`AGENTS.md`）。

## Project Structure

```text
specs/TAK-54-folders-first-name-sort/
├── spec.md
├── plan.md
├── tasks.md
├── quickstart.md
└── checklists/requirements.md
```
