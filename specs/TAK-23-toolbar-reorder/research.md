# Research: ツールバーのカスタマイズと復元

調査日: 2026-11-02。調査は Cloud の Web 検索と Apple 開発者文書の取得による。実機（macOS）での再現は保守者が行った。

## R-1 Apple の文書

**Decision**: 標準の自動保存で直らない場合、文書が代替として示す `configuration` / `setConfiguration(_:)` を、自前の並び保存より先に試す。

**根拠**:

- [`autosavesConfiguration`](https://developer.apple.com/documentation/appkit/nstoolbar/autosavesconfiguration): `true` のとき、構成の変更を自動で
  ユーザーデフォルトに書く。構成は `identifier` に関連付ける（同じ identifier の toolbar は構成を共有する）。`false` のときは保存せず、再起動で既定に戻る。
  既定値は `false`。「ユーザーがカスタマイズできるなら有効にする」「あるいは `configuration` と `setConfiguration(_:)` で自前の保存をする」と書いてある
- [`configuration`](https://developer.apple.com/documentation/appkit/nstoolbar/configuration): 現在の項目の識別子と `displayMode`、`isVisible` を含む辞書。
  ディスクへ自前で保存するために使う
- [`setConfiguration(_:)`](https://developer.apple.com/documentation/appkit/nstoolbar/setconfiguration(_:)): 保存した辞書から構成を復元する。
  認識しないキーは無視する。辞書の形式は `configuration` と一致させる

**未確認**: 上の2つの文書の availability は「macOS 10.0.0 - 15.0.0」と表示される。非推奨かどうかは文書から読み取れなかった。
最低が macOS 15 のため、SDK のヘッダー（`NSToolbar.h` の `API_DEPRECATED`）で確認する（保守者の実機または CI。Cloud には SDK がない）。
`isVisible` を含むため、`view.showsToolbar`（FR-049）と二重管理にならないよう、復元時は `isVisible` を除くか、`showsToolbar` を優先する。

**Alternatives**: 識別子の並びだけの自前保存（R-3 の段3）。文書化された方式が使えない場合の最終手段。

## R-2 参照が壊れる事象（実機で確認済み）

保守者の実機（`.app`、`allowsUserCustomization = true`）で、カスタマイズ画面を開いて閉じただけで履歴の有効・無効が逆になった。
セットを外して戻す・「デフォルトセット」を入れ直すと、履歴を操作できなくなった。カスタマイズしない場合は正常。
これは `toolbar(_:itemForItemIdentifier:willBeInsertedIntoToolbar:)` が `flag` を使わず、呼ばれるたびにプロパティを上書きする現行の実装と整合する
（`MainToolbarController.swift`）。**Decision**: 参照を持たず、`toolbar.items` から識別子で引く（plan.md Phase 1-1）。

## R-3 復元されない事象

**事実（実機）**:

- `autosavesConfiguration = true` にすると、`defaults read local.folzio.Folzio "NSToolbar Configuration MainToolbar"` に、カスタマイズ後の
  `TB Item Identifiers` と `TB Display Mode` が**保存される**
- 再起動すると、ツールバーは既定の並びに戻る。何も触らずに起動・終了しても、保存値は上書きされない（保存値は残る）
- `autosavesConfiguration` を `delegate` の設定より前に置いても直らない。元のコードも `displayMode`・`allowsUserCustomization` の後に
  `autosavesConfiguration` を置いていたため、設定順の違いではない
- `window.titleVisibility = .hidden` は使っていない（`MainWindowController.swift`。`toolbarStyle = .unified` のみ）

**Web の調査**:

- Apple Developer Forums の [NSToolbar doesn't restore displayMode when NSWindow.titleVisibility = .hidden](https://developer.apple.com/forums/thread/779805):
  `autosavesConfiguration = true` でも `displayMode` が復元されない不具合（2025年4月）。macOS 26 beta 2 で修正と回答済み。
  **項目の並びには言及がない**。本件と同一の事象ではない。ただし、復元の処理に不具合が過去にあったことを示す
- Cocoa-dev のメーリングリスト（2005〜2013）の一部の投稿が検索に出た（`lists.apple.com`）。初期の項目順は `toolbarDefaultItemIdentifiers` で決まり、
  ユーザーが並べ替えた順序は identifier に対して保存・復元される、という旧い説明。Cloud からは `lists.apple.com` に接続できず、本文は未取得
- 項目の並びが復元されない同一の報告は、見つからなかった（検索3回。`autosavesConfiguration`、`toolbarDefaultItemIdentifiers`、`configurationDictionary` の語を組み合わせた）

**実機の環境**: 保守者の macOS は 26.6.2（25G83）。上の Forums の不具合は macOS 26 beta 2 で修正済みのため、この版で起きている並びの不復元は、
その既知の不具合とは別の事象である。「OS 固有の既知不具合」の可能性は下がる（ただし、別の未知の不具合の可能性は残る）。

**未特定の原因の候補**（いずれも未検証）: (a) 項目が `view` を持つ項目で、復元時に項目を作る前提を満たさない、(b) 復元は `window.toolbar` の割り当て時に
行われるが、その後で別の処理が既定の項目を挿入する、(c) macOS のバージョン固有の不具合。

**Decision（方式の選び方）**: 次の順で試し、最初に直った方式を採る（plan.md Phase 1-3）。

0. 起動直後の `toolbar.items` の識別子を3点（`init` 後、`window.toolbar` 割り当て後、次の run loop）でログに出し、どこで既定になるかを確認する。
   原因が自分のコードにあれば、直して段1で済む
1. 標準の自動保存のまま直る設定・順序
2. 文書化された `configuration` / `setConfiguration(_:)`（R-1）
3. 識別子の並びだけの自前保存（最終手段）

保守者へ依頼すること: 段0 のログの確認と、使っている macOS のバージョンの共有。

## R-4 同じセットの重複追加

標準のカスタマイズでは、項目によって複数回追加できるか否かが変わる（スペースは可）。8種のセットが重複追加できるかは**未確認**。
実機で確かめ、可能なら、識別子で見つかるすべての項目に同じ状態を適用する（plan.md Phase 1-1）。

## R-5 文言の共有の実態（コードで確認）

| ラベルの現在の文言キー | 他の使用箇所 | 対処 |
|---|---|---|
| `toolbar.size`（サイズ） | `FileListViewController.swift:379,492`（サイズバーのラベル） | ツールバー用に `toolbar.thumbnailSizeLabel` を新設。サイズバーは変えない |
| `menu.view.startSlideshow`（スライドショーを開始） | メニュー項目 | ラベル専用の `toolbar.slideshowLabel` を新設。メニューは変えない |
| `menu.view.showZipFiles`（zipファイルを表示） | メニュー項目 | ラベル専用の `toolbar.zipFilesLabel` を新設。メニューは変えない |
| `toolbar.history` / `panes` / `zoomGroup` / `mediaType` / `viewMode` | ツールバーのみ | 値を新しい文言に変える |

セグメントのツールチップは、`menu.go.back` などメニューの文言と共用している。専用のヘルプキーを新設し、メニューと共用しない（FR-010）。
