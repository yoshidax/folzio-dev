# Research: パス名のコピー

## R1: コピーする文字列

- **Decision**: `URL.path`（標準化しない絶対パス）をそのまま `NSPasteboard.general` に `.string` として書く。書く前に `clearContents()` で既存の内容（ファイルの URL を含む）を置き換える。
- **Rationale**: Finder の「パス名をコピー」と同じ。FR-181 の「引用符・エスケープ・末尾スラッシュなし」を満たす。フォルダの URL は `path` が末尾スラッシュを含まない。
- **Alternatives**: `standardizedFileURL` で正規化する案は、表示している場所と文字列が食い違うため却下。`fileURL` 型を併せて書く案は、ファイルのペースト先として扱われ「ペースト」が有効になるため却下（FR-185 の独立性）。

## R2: ⌥⌘C の衝突

- **Decision**: ⌥⌘C を「編集 > パス名をコピー」に割り当てる。
- **Rationale**: 既存仕様・コードに ⌥⌘C はない（grep 済み）。Finder と同じ。⌥⌘1〜3・⌥⌘V と衝突しない。
- **Alternatives**: ショートカットなしでメニュー項目のみ — 原則 III に反するため却下。

## R3: 有効・無効の判定の置き場所

- **Decision**: ファイルリストは `ListItemCommands` に `allowsCopyPathname(selectionCount:)` を追加（`allowsFileOperations` かつ件数が1）。ツリーは `FavoriteCommands.pathnameTarget(_:)` を追加し、`.folder` と `.favorite` の URL を返し `.favoritesHeader` と nil では nil を返す。
- **Rationale**: Core にテストを付けられる。zip 内の項目・`..` は `allowsFileOperations` が既に false を返すため（FR-073）、規則が二重にならない。
- **Alternatives**: View の中で判定 — 憲章 IV（UI から分離）に反するため却下。

## R4: 見つからないお気に入りの項目

- **Decision**: 既存の「Finder に表示」と同じ判定（`fileTargetNode(for:)` が nil）に揃えて淡色にする。
- **Rationale**: A-104。他の操作と同じ扱いで一貫する。

## R5: 右クリックした行と複数選択

- **Decision**: ファイルリストは既存のコピー項目と同じく選択集合（`selectedFileURLs`）で件数を数える。右クリック時の選択切り替えは既存の挙動に任せる。ツリーは右クリックした行を対象にする（`representedObject`、A-21）。
- **Rationale**: 既存の項目と対象の決め方を揃える。

## R6: 翻訳

- **Decision**: キー `menu.edit.copyPathname`（ja「パス名をコピー」、en「Copy as Pathname」）を1つ追加し、右クリックメニューと編集メニューで共有する。
- **Rationale**: FR-186 の固定名。ja/en の欠けは `swift test` で検出される（FR-157）。
