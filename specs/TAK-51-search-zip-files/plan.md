# Implementation Plan: ファイル名検索で zip ファイルも検索対象にする

**Branch**: `claude/great-johnson-41kca1` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)

**Input**: [TAK-51](https://linear.app/takyoshida/issue/TAK-51/ファイル名検索で-zip-ファイルも検索対象にする)

## Summary

検索（`FileNameSearcher`）が、「zipファイルを表示」がオンで始めた検索に限り、名前が一致する zip ファイル（拡張子 `.zip`）を `.archive` の行として返す。
設定の値は検索の開始時に固定し（`BrowserModel` が保持）、`rebuildListing` の zip 表示フィルタは検索結果には適用しない。
検索結果の zip の行は、フォルダの行と同じく `openItem` で開き（検索結果を終え、zip を含むフォルダへツリーを同期し、履歴に記録）、
名前の変更では `.zip` の拡張子を保つ間だけ行に残す。

## Technical Context

- 言語・基盤: Swift 6 / AppKit のみ / 外部依存なし。ロジックは `FolzioCore`、描画と入力は `FolzioApp`。
- 新しい UI・文字列・設定キーは作らない（ローカライズ・`contracts/settings.md` の変更なし）。
- テスト: Swift Testing（`Tests/FolzioCoreTests`）。Cloud には Swift がないため、ビルドとテストは CI で確認する。
- 制約: 列挙は UI スレッドで行わない（既存の `Task.detached`）。ネットワーク API は使わない。

## Constitution Check

AGENTS.md の【共通】規則に反しない。Core のみで判断し、App は `opensAsContainer` など既存の判定を再利用する。
`specs/product/` は実装と検証の後に反映する。

## 変更の対象

| 領域 | ファイル | 変更 |
|---|---|---|
| 検索の要求 | `Sources/FolzioCore/Search/SearchRequest.swift` | `includesArchives: Bool`（既定 false）を追加する |
| 検索の実行 | `Sources/FolzioCore/Search/FileNameSearcher.swift` | `.zip`（大文字小文字を区別しない）のファイルを、`includesArchives` のときだけ `.archive` の行で返す。コメントの「zip を開かない」を更新する |
| 行の生成 | `Sources/FolzioCore/FileSystem/DirectoryLister.swift` | `.archive` の行の生成を、検索と共有する static に取り出す（フォルダの行 `folderRow` と同じ方式） |
| 検索の開始と固定 | `Sources/FolzioCore/Browser/BrowserModel.swift` | `startSearch` で `showsZipFiles` を `searchIncludesArchives` として保持し、`startSearchStream`（名前変更後の追加の列挙を含む）で `SearchRequest` に渡す。`resetForNavigation` で破棄する |
| 一覧の構築 | 同上 `rebuildListing` | 検索結果の表示中は `ZipFileVisibility` を適用しない（FR-269） |
| 開く | 同上 `openItem` / `openArchive` | 検索結果の zip を開くとき、`listing.folder` を zip を含むフォルダにし、ツリー同期を要求し、`.openedSearchResultFolder` で位置の変更を通知する（FR-271） |
| 名前の変更 | 同上 `didRenameItem` | `.archive` の行は新しい名前の拡張子が `.zip` の間だけ残す。それ以外は外す（FR-272） |
| App | `Sources/FolzioApp/FileList/*` | 原則変更なし。`ListItemCommands.canOpenContainer`（`opensAsContainer`）が `.archive` を含むため、「中を表示」は有効になる。確認と、必要なら検索結果のメニューを調整する |

## 設計上の判断

1. **設定の固定**: 検索の開始時の `showsZipFiles` を `BrowserModel` に保持する（A-166）。`SearchRequest` に載せるので、Core 単体でテストできる。
2. **フィルタの適用範囲**: 通常の一覧にだけ `ZipFileVisibility` を適用し、検索結果と zip の中には適用しない。zip の中には `.archive` の行がなく影響しない。
3. **検索結果から zip を開く**: `openArchive` は現在 `listing.folder` を引き継ぐ。検索結果では `listing.folder` が検索前の場所になるため、
   zip の親フォルダに置き換える。ツリー同期はフォルダの行と同じ `TreeSyncRequest` を使い、ツリーに表示されない場合の EC-102 は既存の処理に任せる（research.md R1）。
4. **種類フィルタ・プレビュー・フルスクリーン**: `ListItemKind.archive` は `isMedia == false` なので、既存の規則（zip の行と同じ）がそのまま効く。テストで確認する。

## 検証

- Core: `FileNameSearcherTests`（zip の一致・オフ・隠し・パッケージ・シンボリックリンク・拡張子の大文字・`x.zip` フォルダ）、
  `BrowserModelSearchTests`（設定の固定・切り替えの無視・開く・履歴・名前の変更・ゴミ箱・種類フィルタ・件数）。
- Cloud の検査: `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`。
- CI: `swift build`、`swift test`。保守者のローカルでの起動スモーク（[quickstart.md](quickstart.md)）。

## Project Structure

```text
specs/TAK-51-search-zip-files/
├── spec.md
├── plan.md
├── research.md
├── quickstart.md
├── tasks.md
└── checklists/requirements.md
```
