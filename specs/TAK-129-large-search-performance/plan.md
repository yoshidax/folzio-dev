# Implementation Plan: 5万件のメディアがある階層の検索を速くし、PC の負荷を下げる

**Branch**: `claude/speckit-bug-assess-tak-129-fpt0ix` | **Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/TAK-129-large-search-performance/spec.md`（[TAK-129](https://linear.app/takyoshida/issue/TAK-129)）

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

検索中の一覧を、並べ替えずに見つかった順で末尾へ足す形に変え（FR-085（変更））、検索が終わったときに1回だけ UI スレッドの外で
並べ替える（FR-437）。一覧への反映は、件数に応じて最大1秒ごとにまとめる。表示側は、末尾への追加を差分の挿入として扱い、見えている
項目を作り直さない。検索中は表示範囲の項目だけの縮小画像を作り、先読みを検索の終了後に回す（FR-435）。列挙は、ファイルごとの
属性の読み取りを減らして速くする（SC-249）。

根拠（計測）: CI の性能テスト（2026-11-13、master、debug ビルド、macOS 15 の共有ランナー）で、`BrowserModel` が 5万件の結果へ 256 件を
並べ替えて合流する1回の処理が 0.110 秒、1万件（5千件が一致）の列挙が 0.97 秒だった（research.md R1）。5万件ではまとまりが数百回届き、
そのたびに全件の合流と一覧の作り直しが UI スレッドで走る。名前順では新しい結果が先頭近くにも入るので、見えている項目が入れ替わり続け、
縮小画像を要求し直す（保守者の観察とも一致）。

本資料は設計レビュー用。承認の前に実装しない。

## Technical Context

**Language/Version**: Swift 6（CI は Xcode 16.0 / Swift 6.0）

**Primary Dependencies**: Foundation（Core）、AppKit・QuickLookThumbnailing（App・Core の `ThumbnailProvider`）。外部依存なし

**Storage**: N/A（保存する設定のキーは増やさない）

**Testing**: Swift Testing（`FolzioCoreTests`・`FolzioAppTests`・`FolzioPerformanceTests`）。GUI の時間と見え方は quickstart.md で保守者が確認

**Target Platform**: macOS 15 以降。Cloud では Swift も GUI も実行しないので、ビルド・テストは macOS の CI で確認する

**Project Type**: desktop-app（Swift Package。`FolzioCore`・`FolzioLocalization`・`FolzioApp`）

**Performance Goals**: SC-249〜SC-253（5万件で検索の終了まで 3 秒、表示範囲の縮小画像まで 3 秒、操作の停止 100ms 未満、1回の追加 50ms 以内）

**Constraints**:

- Core は AppKit を import しない。判断ロジック（反映の間隔・追加・終了時の並べ替え）は Core、表示と縮小画像の要求は App に置く（AGENTS.md）
- UI スレッドでディレクトリの列挙と 5万件の並べ替えをしない（憲章の原則 II）
- 通常のフォルダ・zip の中の一覧の動作は変えない（A-269）
- ソースのコメントは英語（公開用リポジトリへ書き出される）
- 並行する TAK-104（複数の検索起点）が `BrowserModel.startSearchStream` 付近を変える。マージの順序で競合を解く（R8）

**Scale/Scope**: Core 3 ファイル（`BrowserModel`・`FileNameSearcher`・`DirectoryLister`）、App 2 ファイル（`ThumbnailModeView`・`ListModeView`）、
フィクスチャ 2 ファイル（`FixtureSets`・`make-fixtures`）、
テスト 3〜4 ファイル

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判断 |
|---|---|
| I ローカル完結 | PASS。通信なし。ユーザーのファイルを変更しない |
| II 体感パフォーマンス | PASS。5万件の並べ替えを UI スレッドの外へ移し、UI スレッドの処理を件数に比例させない。基準値に対する計測を PR に記載する |
| III キーボード・アクセシビリティ | PASS。操作は変えない。終了時の並べ替えで、フォーカス項目を見える位置に保つ（FR-437） |
| IV テスト必須 | PASS。追加・反映の間隔・終了時の並べ替えは Core、縮小画像の要求は App のテスト、時間は性能テスト |
| V シンプルさ | PASS。設定を足さない。並べ替えの適用は既存の「UI スレッドの外で並べ替えて版を照合する」形（`setKindNames`）に揃える |

**設計後の再確認（Phase 1 の後）**: 変更なし。すべて PASS。

## 設計

詳細と代替案は [research.md](research.md)、状態は [data-model.md](data-model.md)。

### 1. 検索中の追加（FR-085（変更）・FR-436。research.md R2・R3）

- `BrowserModel.appendSearchResults` は、届いた結果を `pendingSearchResults` にためる。反映の時刻になったら、ためた結果を
  `allFiles` の末尾へ足す（`sortedMerge` を使わない）
- 種類フィルタ・zip の表示・名前の絞り込みは、足す分だけに適用して `listing.files` の末尾へ足す（全件の `rebuildListing` をしない）
- 反映の間隔は件数で決める: 1,000 件未満は 0.1 秒、1万件未満は 0.25 秒、3万件未満は 0.5 秒、それ以上は 1 秒（FR-085 の上限 1 秒）
  - 最初の結果はすぐに反映する。ストリームが終わったら、ためた分を待たずに処理する
- 選択の制限（`selection.restricted(toVisible:)`）は、種類フィルタで隠れた行が選択にあるときだけ行う（足すだけでは選択は隠れない）

### 2. 検索の終了時の並べ替え（FR-437・EC-302〜EC-304。research.md R4）

- すべての列挙が終わったら、`allFiles` の写しを `Task.detached` で並べ替え、UI スレッドで `allFiles` の版（既存の `kindFilesRevision`。`allFiles` を変えるたびに進む）が変わっていなければ
  `allFiles` に入れて `rebuildListing` する。変わっていれば、並べ替えをやり直す（`setKindNames` と同じ形）
- 並べ替えを適用したときに `listing.search?.phase = .finished` にする（件数の確定と並びが同時に変わる。EC-303）
- 適用後に `searchOrderGeneration` を進める。表示側はこれを見て、フォーカス項目があればそれを、なければ先頭を表示する
- 検索中に並べ替えの列・向きを変えたとき（`sortOrder` の `didSet`）は、同じ仕組みでその時点の結果を UI スレッドの外で並べ替える
- 検索中の名前の変更（`didRenameItem`・`didRenameFolder`）は、行の値だけを書き換え、位置を動かさない（`resortRow` を使わない。EC-304）
  - `allFiles` が並んでいる前提（R67 の二分探索）は、検索が終わって並べ替えた後に戻る。検索中はその前提を使う処理を通らない
- 検索を止めたとき（EC-302）は並べ替えない。既存の世代（`navigationGeneration`）の照合で、適用を捨てる

### 3. 表示側（FR-435・FR-436。research.md R5・R6）

- `ThumbnailModeView.applyModel`: 新しい URL の列が前の列で始まり、長くなっただけなら、`insertItems(at:)` で末尾だけを足す。
  見えている項目を作り直さず、縮小画像を要求し直さない。それ以外は従来どおり `reloadData`
- フローレイアウトの項目の大きさを、項目ごとの問い合わせ（`sizeForItemAt`）から、レイアウトの `itemSize` に移す（全項目が同じ大きさ）
- 検索中は、先読み（`prefetchItemsAt`）で要求しない。一覧が変わったら、見えている項目以外の要求を取り消す（`pruneRequests` を見えている
  項目で行う）。検索の終了（`searchOrderGeneration` の変化）で並べ替わった後は、見えている項目を要求し、以後の先読みを再開する
- `ListModeView.applyModel`: 末尾への追加だけなら `noteNumberOfRowsChanged()` にし、見えている行を作り直さない。行頭の縮小画像は、
  今も見えている行だけを要求しているので変えない
- 終了時の並べ替えの後のスクロール: フォーカス項目があれば見える位置へ、なければ先頭へ（両方の表示形式）

### 4. 列挙を速くする（SC-249。research.md R7）

- `FileNameSearcher` の列挙で、行に使う属性（作成日・変更日・サイズ・`FileContentVersion` のキー）も前もって読む（`includingPropertiesForKeys`）
- 種類の名前（`localizedTypeDescription`）は、1回の検索の中で拡張子（小文字）ごとに1回だけ問い合わせ、以後は同じ値を使う

### 5. 計測（research.md R1・R9）

- 性能テストを足す: (a) 5万件の階層の列挙だけ、(b) 5万件の階層を本物の `FileNameSearcher` で `BrowserModel` から検索し、件数の確定と並べ替えまで、
  (c) その間の UI スレッドの最大の空白（操作の停止の代わり）、(d) 5万件へ 256 件を足す1回の処理（既存のテストの基準を 100ms から 50ms へ）
- 実装の前に (a)〜(c) を先に足して CI で現状を計り、効果を比べる（R9）
- 5万件の階層は、`FixtureSets.largeSearch(in:)`（500 フォルダ × 100 ファイル、8×8 の JPEG、半数が `cat_`）で作り、性能テストと
  `scripts/make-fixtures.sh <dir> --large-search`（保守者の GUI 確認。quickstart.md）の両方で使う。`makeAll` には含めない（5万件の書き込みを避ける）

## Project Structure

### Documentation (this feature)

```text
specs/TAK-129-large-search-performance/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
│   └── requirements.md
└── tasks.md            # /speckit-tasks で作る
```

契約（`contracts/`）は作らない。キーボード操作・メニュー・設定・文言は変えない。

### Source Code (repository root)

```text
Sources/FolzioCore/
├── Browser/BrowserModel.swift        # 追加・反映の間隔・終了時の並べ替え・名前の変更の扱い
├── Search/FileNameSearcher.swift     # 属性の先読み、種類の名前のキャッシュ
└── FileSystem/DirectoryLister.swift  # 読んだ属性と種類の名前から行を作る入口（今は private の mediaFile(at:kind:values:) を internal にする）

Sources/FixtureKit/FixtureSets.swift  # 5万件の階層（largeSearch）
Sources/make-fixtures/main.swift      # --large-search の選択肢

Sources/FolzioApp/FileList/
├── ThumbnailModeView.swift           # 差分の挿入、itemSize、検索中の先読みの停止と要求の取り消し、終了時のスクロール
└── ListModeView.swift                # 差分の挿入、終了時のスクロール

Tests/
├── FolzioCoreTests/BrowserModelSearchTests.swift      # 見つかった順・反映の間隔・終了時の並べ替え・名前の変更（既存の並び順のテストを更新）
├── FolzioCoreTests/FileNameSearcherTests.swift        # 種類の名前のキャッシュと属性の先読みで行の値が変わらない
├── FolzioAppTests/SearchThumbnailRequestTests.swift   # 検索中は見えている項目だけを要求する（新規）
└── FolzioPerformanceTests/PerformanceBaselineTests.swift  # 5万件の計測
```

**Structure Decision**: 既存の Swift Package の構成のまま。新しいモジュール・ターゲットは作らない。

## Complexity Tracking

憲章の違反はない。
