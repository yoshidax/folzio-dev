# Implementation Plan: 連続選択時の画像読み込み数と不要な先読みを制御する

**Branch**: `claude/elegant-planck-mq7dkd` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-15-limit-image-loading/spec.md`

## Summary

プレビューと先読みが共有する「読み込みの枠」を管理する小さな型 `ImageLoadScheduler`（actor）を Core に追加する。同時実行数は 2、そのうち先読みは 1 まで。
枠の待機はプレビューを先に通し、取り消された待機は枠を取らずに終わる。`BrowserModel` は、通常画像のデコードと zip の画像の読み出し・デコードを枠の中で実行し、
フォーカスが移るたびに前後 1 件に入らない先読みを取り消す。先読み中の画像をプレビューするときは、先読みの結果を待って使う。
`ImageDecoder` は、開始前の取り消しを検出して無駄なデコードを始めない。設計の根拠は [research.md](research.md)、型は [data-model.md](data-model.md)、
Core の API は [contracts/core-api.md](contracts/core-api.md)。

## Technical Context

**Language/Version**: Swift 6（CI は Xcode 16.0 / Swift 6.0）

**Primary Dependencies**: Foundation、ImageIO（既存）。外部依存の追加なし

**Storage**: なし。新しい設定キーなし

**Testing**: Swift Testing（`Tests/FolzioCoreTests`）。完了を制御できる偽の decoder（同時実行数の最大値を記録する）と偽の zip リーダーで、
40 回の連続選択を検証する。Cloud では実行できないため macOS CI で確認する。大きな画像・zip の連続送りは quickstart.md で保守者が目視する

**Target Platform**: macOS 15 以降

**Project Type**: Swift Package の desktop-app（`FolzioCore` + `FolzioApp`）

**Performance Goals**: SC-001（初回表示 0.5 秒以内、先読み済みの切り替え 0.1 秒以内）を保つ（SC-119）。キャッシュ参照は枠を通さない

**Constraints**: デコード・読み出しを UI スレッドで行わない（既存どおり）。デコード済みキャッシュのメモリ上限を変えない（憲章 II）。ネットワーク API を使わない

**Scale/Scope**: Core 3 ファイル（`ImageLoadScheduler` 新規、`BrowserModel`、`ImageDecoder`）。App の変更なし

## Constitution Check

設計前・設計後とも適合。

- I（ローカル完結）: 通信なし。ファイルを変更しない
- II（体感パフォーマンス）: 同時実行数の上限でピークの一時メモリを抑える。キャッシュの上限は変えない。プレビュー優先と、先読み済みの参照を枠に通さないことで
  基準値を保つ。性能テスト（`FolzioPerformanceTests`）の結果を PR に記載する
- III（キーボード）: 新しい操作なし
- IV（テスト必須）: スケジューラの上限・優先度・取り消し・枠の解放（EC-166）と、`BrowserModel` の連続選択（通常・zip）に Core のテストを付ける
- V（シンプルさ）: 新しい型は `ImageLoadScheduler` と、先読みの 1 件分を表す小さな `PrefetchEntry` の 2 つ。設定や汎用のジョブ基盤は作らない
- マージ前: CI の成功と、保守者の起動スモーク・目視確認（quickstart.md）が必要。未実施を完了扱いにしない

## 設計

### Core

1. `ImageLoadScheduler`（新規、`Sources/FolzioCore/Imaging/ImageLoadScheduler.swift`）: data-model.md のとおり。
   `acquire(_:) async -> Bool` で枠を取り、`release(_:)` で返す。待機中に取り消されると `false` を返し、枠を取らない（EC-166）。
   空いた枠は、待機中のプレビューを先に、次に先読み（先読みの実行中が 1 件未満のとき）に渡す（FR-235）
2. `BrowserModel`
   - 枠の中で行う処理: 通常画像は「キャッシュ参照 → 枠の取得 → 取得後にもう一度キャッシュ参照 → デコード → キャッシュへ格納 → 枠の返却」。
     zip の画像は「キャッシュ参照 → 枠の取得 → 項目の読み出し → デコード → 格納 → 返却」。キャッシュ参照だけで済む場合は枠を通さない（EC-165）
   - プレビューは `.preview`、先読みは `.prefetch` で枠を取る。枠の待機中に取り消されたら何もせずに終わる
   - `schedulePrefetch(around:)`: 対象は前後 1 件（次の画像、前の画像の順）。対象に入らない `prefetchTasks` の項目を `cancel()` して外す（FR-234）。
     すでにある項目は作り直さない
   - プレビューの引き継ぎ（FR-236、R3）: `loadPreview` が、フォーカスする URL の `PrefetchEntry` を `prefetchTasks` から取り出す。
     実行中（枠を取得済み）なら、プレビューのタスクはその完了を待ってからキャッシュを参照する（取得できなければ通常の読み込みに進む）。
     待機中なら、その先読みを取り消して通常のプレビューとして読み込む
   - 取り消し後に終わった結果は、`previewGeneration` の照合でプレビューに反映せず、キャッシュにだけ入れる（FR-237、EC-164）
   - `resetForNavigation()` は既存どおり全先読みを取り消す（EC-167）
3. `ImageDecoder`: `decode` を `withTaskCancellationHandler` で包み、内側の `Task.detached` に取り消しを伝える。デコード本体の開始前に
   取り消されていれば `DecodeError` ではなく取り消しとして扱い、`decodeSynchronously` を始めない。開始済みのデコードは止められない（R2、EC-164）

### App

変更なし。`PreviewViewController` などは `BrowserModel.preview` を観察するだけで、読み込みの経路を知らない。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-15-limit-image-loading/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/core-api.md
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/FolzioCore/
├── Imaging/ImageLoadScheduler.swift   # 新規
├── Imaging/ImageDecoder.swift         # 取り消しの伝播
└── Browser/BrowserModel.swift         # 枠の利用、先読みの取り消し、引き継ぎ
Tests/FolzioCoreTests/
├── ImageLoadSchedulerTests.swift      # 新規
└── BrowserModelImageLoadTests.swift   # 新規（連続選択。通常・zip）
```

**Structure Decision**: 既存の Swift Package の構成のまま。判断ロジック（上限、優先度、取り消し、引き継ぎ）は Core に置き、App は変えない（AGENTS.md）。

## リスク

- 開始済みのデコードは止められず、取り消し後も枠を占める。素早く送ると、新しいプレビューが古いデコードの終了を待つことがある（EC-164）。
  最悪でも大きな画像 1 枚分のデコード時間。ImageIO の `CGImageSourceCreateThumbnailAtIndex` は途中で止められないため、設計では許容する
- zip の画像は項目の読み出しが枠の中に入るため、読み出しが長い zip では先読みだけで枠が埋まらないよう、先読みを 1 件に制限している（FR-235）
- アニメーション画像かどうかの判定（ファイルの先頭の読み取り）は、枠の対象外で現行のまま（A-145）
- 引き継ぎで先読みの完了を待つ間に先読みが失敗すると、プレビューは通常の読み込みでやり直す。二重のデコードはその失敗時だけ起きる
- 実メモリの削減量は計測していない（A-146）。上限の値（2、1）が適切かは、保守者が大きな画像で目視する

## Complexity Tracking

違反なし。
