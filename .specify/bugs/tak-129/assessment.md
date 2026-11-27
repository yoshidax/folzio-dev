# Bug Assessment: 5万件以上のメディアがあるフォルダを起点にした検索が遅く、PC の負荷が高い

- **Slug**: tak-129
- **Created**: 2026-11-27
- **Source**: Linear [TAK-129](https://linear.app/takyoshida/issue/TAK-129)（Linear の MCP の `get_issue` で取得。コメントはなし。URL の取得ではないので、URL の扱いの方針は適用していない）
- **Verdict**: invalid（バグではない。現在の仕様が定めていない性能の要求を加える、仕様の変更として扱う。ただし「仕様との照合」の未確認の点を参照）
- **Severity**: medium（参考。大量のメディアを持つ利用者には検索が実用にならないが、データの損失はなく、1万件の基準は満たす前提）

## Report (verbatim or summarized)

TAK-129「配下に5万件以上のメディアファイルがあるフォルダを起点にした検索を速くし、PC の負荷を下げる」（ラベル: Feature、状態: Backlog、作成 2026-11-27）の要約:

- 症状: 配下に5万件以上のメディアファイルがあるフォルダを起点に検索すると、かなりの時間がかかり、PC の負荷も高い。保守者の観察では、最初に見える範囲のサムネイルが表示されるまで数分以上かかった。
- 保守者の印象: 検索（ファイルの列挙）とサムネイルの生成を同時に行っているように感じる。先にファイルの一覧を作り、サムネイルはその後に作る工夫を検討したい。
- Issue 自身の分類: 「現在の仕様に反する動作（バグ）とは判断していない。5万件規模での性能の要求を加える、仕様変更の扱いとする」。
- 未確認とされている点: 計測の条件（件数、階層、画像と動画の割合、表示形式、並べ替えの列）、目標値（最初のサムネイルまでの時間、検索を終えるまでの時間、CPU の負荷）、遅い原因（列挙・一覧の更新・サムネイルの生成のどれか）。
- Agent notes（Issue の作成時の、コードを読んだだけの仮説）: 1 一覧の更新が件数に比例して重くなる、2 サムネイルの要求が積み重なる、3 列挙中にファイルごとの属性を読む。
- 関連: TAK-90（フォルダの名前変更時の付け替え。別の Issue）、TAK-104（複数の検索起点。起点は順に列挙するので同時の列挙数は増えない）。

## Symptom

5万件以上のメディアがある階層を起点に検索すると、最初に見える範囲のサムネイルが出るまで数分以上かかり、検索中は PC 全体の負荷が高い。期待する動作は、実用的な時間で最初のサムネイルが出て検索が終わり、検索中に PC 全体が重くならないこと（目標値は未定）。

## 仕様との照合

- 該当:
  - [FR-085](../../../specs/product/search.md#L93): 検索は UI を止めずに行い、見つかった項目から順に一覧へ追加する（並び順は現在の並べ替え）。検索中もスクロール・選択・プレビュー・ツリーの操作を続けられる。結果の件数に上限は設けない
  - [FR-083](../../../specs/product/search.md#L60): 起点以下のすべての階層を辿る
  - [SC-016](../../../specs/product/search.md#L597)・[SC-054](../../../specs/product/search.md#L621): 10,000 ファイルの階層で 3 秒以内に検索が終わり、操作が 100ms 以上止まらない
  - [FR-013](../../../specs/product/file-list.md#L53): サムネイル形式では各ファイルの縮小画像を表示する（生成の順序・時間・同時実行数の要求はない）
- 判定: **仕様が定めていない**（fix へ進まず、仕様の変更として `folzio-sdd-increment` で扱う）
- 根拠:
  - 仕様の性能の基準は 1万件まで（SC-016・SC-054）で、5万件規模の時間の基準、最初のサムネイルが出るまでの時間、CPU の負荷の基準はどの文書にもない（`specs/product/*.md` を「CPU」「負荷」で検索して、該当は file-list.md の名前フィルタの注記 1 件だけ）。
  - 保守者の改善案「先に一覧を作り、サムネイルは後で作る」は、見つかった順に一覧へ追加する FR-085 の動作を変える可能性があり、仕様の判断が要る。
  - 既存の性能テスト（`Tests/FolzioPerformanceTests/PerformanceBaselineTests.swift` の SC-016・SC-054）は `FileNameSearcher` のストリームだけを計測し、`BrowserModel` への追加と一覧の表示・サムネイルの生成は計測していない。そのため、1万件で基準を満たすことも、一覧の更新を含めては確かめられていない。
- **保守者の回答（2026-11-27）**: 検索中に操作は止まらないが、反応は遅い印象。FR-085 の「UI を止めずに」「検索中も操作を続けられる」には反しない。反応の遅さを数える基準（SC-016 の「100ms 以上止まらない」）は 1万件までで、5万件では定めていないので、判定は「仕様が定めていない」のまま変えない。
- **保守者の目標（2026-11-27）**: 「できる限りの最適化を図りたいので、とりあえず 3 秒」。どの時間（最初の画面のサムネイル・検索の終了）に当てるかは、sdd-increment の仕様で確定する。

## Reproduction

1. 5万件以上のメディアファイル（サブフォルダを含む）を持つフォルダを用意する [NEEDS CLARIFICATION: 件数、階層の深さとフォルダ数、画像と動画の割合、ローカルディスクか外部ボリュームか]
2. そのフォルダを起点に、多くのファイルに一致するキーワードで検索する [NEEDS CLARIFICATION: キーワードと一致件数]
3. サムネイル形式で、最初に見える範囲のサムネイルが出るまでの時間と、検索が終わるまでの時間、CPU の使用率を見る [NEEDS CLARIFICATION: 表示形式（サムネイルかリストか）、並べ替えの列、サムネイルサイズ、検索中に操作が止まったか]

再現も計測もしていない（Cloud 環境は Linux で、アプリを起動できない）。

## Suspected Code Paths

以下は、コードを読んで確かめた事実と、そこから立てた仮説。計測はしていない。

- `Sources/FolzioCore/Search/FileNameSearcher.swift:39`・`:99` — 結果を 256 件か 100ms ごとにまとめて渡す。5万件では数百回の受け渡しになる。列挙自体は `Task.detached(priority: .userInitiated)` で UI スレッドの外。
- `Sources/FolzioCore/Search/FileNameSearcher.swift:219`・`Sources/FolzioCore/FileSystem/DirectoryLister.swift:143-157` — 一致したメディアごとに `resourceValues(forKeys: mediaKeys)` を読み、`localizedTypeDescription`・作成日・変更日・サイズを取る。UI スレッドの外だが、ファイルごとのシステムコールと UTI の照会になる。
- `Sources/FolzioCore/Browser/BrowserModel.swift:1550` `appendSearchResults` — 受け渡しのたびに UI スレッドで、`sortedMerge`（`Sources/FolzioCore/Model/Sorting.swift:70`、既存の全件と比較しながら新しい配列を作る O(n)）、`rebuildListing`（`BrowserModel.swift:1102`、種類フィルタ・名前フィルタを全件に適用し、`allFiles.contains` で全件を走査）、選択があれば `listing.files.map(\.url)` を作る。n 件を k 回に分けて受け取ると、合計は O(n·k)。名前順では比較に自然順の文字列比較を使う。
- `Sources/FolzioApp/FileList/ThumbnailModeView.swift:786` `applyModel` — 受け渡しのたびに全件の URL の配列を作り、前回の配列と比較し、`Set(urls)` を作り、`collectionView.reloadData()` と `flowLayout.invalidateLayout()` を行う。`NSCollectionViewFlowLayout` はレイアウトの作り直しで全項目の `sizeForItemAt`（`:1266`）を呼ぶので、これも 1 回あたり O(n)。
- `Sources/FolzioApp/FileList/ThumbnailModeView.swift:836` `pruneRequests` — 一覧から消えた URL の要求だけを取り消す。見えている項目は再利用時に古い URL の要求を取り消す（`:1250`）が、先読み（`:1329` `prefetchItemsAt`）で要求した項目が新しい結果に押されて画面外へ移ったとき、その要求が取り消されるかは `cancelPrefetchingForItemsAt` が呼ばれるかに依存し、未確認。
- `Sources/FolzioCore/Imaging/ThumbnailProvider.swift:93-115` — zip の外のファイルは `QLThumbnailGenerator.shared.generateBestRepresentation` を直接呼び、アプリ側の同時実行数の上限はない（zip の中は `:52`・`:54` の上限 4・2 がある）。QuickLook 側の内部の制限は未確認。
- `Sources/FolzioApp/FileList/ListModeView.swift:388` `applyModel` — リスト形式でも、受け渡しのたびに全件の URL の比較と `reloadData` を行う。フォーカスがあれば毎回 `scrollRowToVisible` を呼ぶ。リスト形式の行頭の縮小画像は見えている行だけ要求する（`:886`）。

## Root Cause Hypothesis

確度: **low〜medium**（コードからの推定で、計測していない）。最も疑わしいのは、結果の受け渡しのたびに UI スレッドで全件を作り直すこと（`appendSearchResults` の合流とフィルタ、`ThumbnailModeView` の `reloadData` とフローレイアウトの全項目のサイズ計算）で、5万件・数百回の受け渡しでは合計の処理が件数の2乗に近く増える。名前順などでは新しい結果が見えている範囲に入り続け、`reloadData` のたびに見えている項目と先読みの項目のサムネイルを要求し直すので、最初の画面のサムネイルが確定しにくく、QuickLook の生成も積み重なる（アプリ側に同時実行数の上限がない）。列挙中のファイルごとの属性の読み取りは UI スレッドの外で、主因ではないと推定するが、ディスクの負荷には加わる。Issue の「列挙とサムネイルの生成を同時に行っている」印象は、この推定と合う。どの要因が支配的かは、Instruments（Time Profiler で UI スレッドの `appendSearchResults`・`applyModel`・`sizeForItemAt` の時間、QuickLook の生成数）で計測して確かめる必要がある。

## Proposed Remediation

この判定では `/speckit-bug-fix` へ進まない。`folzio-sdd-increment` で新しい feature（例: `specs/TAK-129-large-search-performance`）として、次を決めてから設計する。

**仕様で決めること**:
- 計測の条件（件数、階層、画像と動画の割合、表示形式、並べ替えの列）と目標値（最初の画面のサムネイルが出るまでの時間、検索を終えるまでの時間、検索中に操作が止まらない基準、CPU の負荷の扱い）。SC-016・SC-054 と同じ形の5万件の成功基準を加えるか。
- FR-085 の「見つかった項目から順に一覧へ追加する」を保つか。保つなら、一覧への反映の間隔を件数に応じて広げてよいか（例: 件数が多いときは 0.5〜1 秒ごと）。

**設計の候補**（計測の後に選ぶ）:
- 優先: 一覧の更新を安くする。`appendSearchResults` で受け取った結果をため、UI への反映をまとめる（間隔を件数に応じて広げる）。`rebuildListing` を全件の作り直しから、追加分だけを合流させる形にする。`ThumbnailModeView` と `ListModeView` は、件数だけが増えたとき `reloadData` の代わりに差分の挿入（`insertItems`・`insertRows`）を使うか、レイアウトの作り直しで全項目のサイズを聞かない固定サイズのレイアウト（`itemSize` の指定）にする。
- サムネイルの生成を抑える: 検索中は見えている項目だけを要求し、先読みは検索が終わってから行う。押し出された項目の要求を確実に取り消す。zip の外の QuickLook の生成にも同時実行数の上限を設ける（zip の中の `ConcurrencyLimiter` を使う）。
- Issue の案「先に一覧を作り、サムネイルは後で作る」: 検索中はサムネイルを要求しない、または一覧を検索の終了時にまとめて出す。前者は FR-085 を保てるが、検索中に見ている項目のサムネイルも出ない。後者は FR-085 の変更になる。

**Files likely to change**:
- `Sources/FolzioCore/Browser/BrowserModel.swift`
- `Sources/FolzioCore/Model/Sorting.swift`
- `Sources/FolzioApp/FileList/ThumbnailModeView.swift`
- `Sources/FolzioApp/FileList/ListModeView.swift`
- `Sources/FolzioCore/Imaging/ThumbnailProvider.swift`（同時実行数の上限を入れる場合）
- `Tests/FolzioPerformanceTests/PerformanceBaselineTests.swift`
- `Tests/FolzioCoreTests/`（`BrowserModel` の検索結果の追加の単体テスト）

**Tests to add or update**:
- 5万件の階層の検索を、`FileNameSearcher` だけでなく `BrowserModel.startSearch` から結果が確定するまで計測する性能テスト（UI スレッドで1回の追加にかかる最大時間も記録する）
- 反映をまとめても、結果の順序・件数・選択の制限（`selection.restricted`）・名前の変更の付け替え（TAK-90 の範囲）が変わらない単体テスト
- サムネイルの要求の数の上限（同時実行数）を検査するテスト（上限を入れる場合）
- GUI: 5万件の階層で、最初の画面のサムネイルが出るまでの時間と、検索中の操作の止まりを保守者が確かめる手順（`specs/001-three-pane-media-viewer/quickstart.md` の「性能の検証」の形）

## Risks & Considerations

- 反映の間隔を広げると、FR-085 の「見つかった項目から順に」の見え方が変わる。件数の表示の更新も遅れる。
- 差分の挿入に変えると、選択・スクロールの位置・名前の変更中の編集（`ListModeView` の `finishRenaming`）の扱いが `reloadData` と変わり、回帰の範囲が広い。
- QuickLook に上限を設けると、通常のフォルダを開いたときのサムネイルの表示（[SC-003](../../../specs/product/file-list.md#L1048)）が遅くなる可能性がある。検索中だけに限るか、計測して決める。
- 1万件の性能テストが一覧の更新を含まないため、変更の前後で一覧の更新を含む基準値を先に取る必要がある。性能テストの基準値を変える場合は `specs/001-three-pane-media-viewer/quickstart.md` の「性能の検証」に従う。
- TAK-104（複数の検索起点、進行中）と `appendSearchResults`・`startSearchStream` が重なるので、マージの順序に注意する。

## Open Questions

- 解決: 検索中に操作は止まらない（反応は遅い印象）。FR-085 に反するバグではない（2026-11-27、保守者）
- [NEEDS CLARIFICATION: 計測の条件（件数、階層、画像と動画の割合、表示形式、並べ替えの列、ローカルか外部ボリュームか）]
- 一部解決: 目標は暫定で 3 秒（2026-11-27、保守者）。[NEEDS CLARIFICATION: 3 秒を、最初の画面のサムネイルまでの時間、検索を終えるまでの時間のどちら（または両方）に当てるか。CPU の負荷の基準を設けるか]
- [NEEDS CLARIFICATION: FR-085 の「見つかった項目から順に一覧へ追加する」を保つか、変えてよいか]
