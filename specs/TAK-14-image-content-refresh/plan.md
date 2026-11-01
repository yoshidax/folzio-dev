# Implementation Plan: 同一パスのファイルの内容更新をサムネイルとプレビューに反映する

**Branch**: `claude/admiring-allen-cf97f7` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-14-image-content-refresh/spec.md`

## Summary

一覧の各メディアの行に、内容の識別情報（大きさ・内容の更新日時・inode。zip の中は zip ファイルの識別情報）を持たせ、
プレビューのデコード済み画像と縮小画像のキャッシュを「URL と識別情報の組」で引くように変える。変更の通知で一覧を取り直したとき
（検索結果では存在の確認と一緒に）新旧の識別情報を比べ、変わった行だけを App が読み込み直し、フォーカス中のファイルが変わっていれば
プレビューを読み込み直す。設計の根拠は [research.md](research.md)、型の変更は [data-model.md](data-model.md)。

## Technical Context

**Language/Version**: Swift 6（CI は Xcode 16.0 / Swift 6.0）

**Primary Dependencies**: Foundation、ImageIO、QuickLookThumbnailing（既存）、AppKit（App のみ）。外部依存の追加なし

**Storage**: なし（識別情報は永続化しない）。新しい設定キーなし

**Testing**: Swift Testing（`Tests/FolzioCoreTests`）。FixtureKit で一時ディレクトリに画像を作り、同じパスで寸法の違う画像に上書きする。
Cloud では実行できないため macOS CI で確認する。GUI は quickstart.md で保守者が確認する

**Target Platform**: macOS 15 以降

**Project Type**: Swift Package の desktop-app（`FolzioCore` + `FolzioApp`）

**Performance Goals**: 一覧の取得に資源値のキーを2つ足すだけで、ファイルの内容は読まない。変わっていない行の縮小画像は作り直さない（SC-116）。
10,000 ファイルのフォルダの読み込みの基準（001 quickstart の「性能の検証」）を保つ

**Constraints**: 資源値の取得とデコードは UI スレッドで行わない（既存の `DirectoryLister.run` と検索の `Task.detached` の中で行う）。
デコード済み画像のキャッシュのメモリ上限を変えない（憲章 II）。ネットワーク API を使わない

**Scale/Scope**: Core 6 ファイル（`MediaFile`・`DirectoryLister`・`ArchiveIndex`・`DecodedImageCache`・`ThumbnailProvider`・`BrowserModel`）、
App 2 ファイル（`ListModeView`・`ThumbnailModeView`。`PreviewViewController` は変更不要の見込み）

## Constitution Check

設計前・設計後とも適合。

- I（ローカル完結）: 通信なし。ユーザーのファイルを変更しない（読むだけ）
- II（体感パフォーマンス）: 資源値は既存のバックグラウンドの列挙で前もって取得する。キャッシュの上限は変えない。変わった行だけを
  読み込み直す。性能テスト（`FolzioPerformanceTests`）の結果を PR に記載する
- III（キーボード）: 新しい操作なし
- IV（テスト必須）: 識別情報の生成、キャッシュの版の照合、一覧の再読み込みでの変更の検出、プレビューの読み込み直し、検索結果、
  zip の各ロジックに Core のテストを付ける。異常系（置き換え後のファイルが壊れている（EC-159））も含める
- V（シンプルさ）: 新しい型は `FileContentVersion` の1つ。汎用のキャッシュ無効化の仕組みや監視の層は作らない
- マージ前: CI の成功と、保守者の起動スモーク・GUI 確認（quickstart.md）が必要。未実施を完了扱いにしない

## 設計

### Core

1. `FileContentVersion`（新規、`Sources/FolzioCore/Model/FileContentVersion.swift`）: data-model.md のとおり。
   `init(resourceValues:)` と `init(archiveIdentity:)` を持つ
2. `MediaFile.contentVersion` を追加。`DirectoryLister` の `fileKeys`・`mediaKeys` に `.contentModificationDateKey`・`.fileIdentifierKey` を加え、
   メディアの行で設定する（検索の `FileNameSearcher` は `DirectoryLister.mediaFile(at:kind:)` を共有するため同時に対応する）
3. `ArchiveIndex` が作るメディアの行に、その index の `identity` から作った版を設定する
4. `DecodedImageCache.get(_:version:)`・`put(_:for:version:)`（R2）
5. `ThumbnailProviding` と `ThumbnailProvider` に `version` を加え、キャッシュのキーと実行中の要求の照合に使う（R3）
6. `BrowserModel`
   - `decodedImage(for:)`・`archiveImage(for:maxPixelSize:)`・先読みが、`listing.files` の行の `contentVersion` でキャッシュを引く
   - `reloadCurrentFolder()` で版の違う URL を求め、`changedContentURLs`・`contentChangeGeneration` を更新し、該当する先読みを取り消し、
     フォーカス中なら `reloadPreviewForContentChange(_:)` を呼ぶ（R4）
   - `reloadPreviewForContentChange(_:)`: 静止画は表示を保ったままデコードして差し替え、アニメーション画像は `.animatedImage(url)` を設定し直す。
     種類が変わった・失敗した場合は通常の `loadPreview(for:)` の結果に従う（R5、EC-159、EC-162）
   - `pruneMissingResults(under:)` で、存在の確認と一緒に版を取り直し、変わった結果を差し替えて同じ処理を行う（R6）

### App

7. `ListModeView`・`ThumbnailModeView` が `contentChangeGeneration` を観察し、URL の並びが同じとき、`changedContentURLs` の行だけを
   読み込み直し、その行の縮小画像の要求を取り消してから新しい版で要求し直す（R8）。縮小画像の要求に `file.contentVersion` を渡す
8. `ThumbnailCell.configure` は、URL か版が変わったときに代替アイコンへ戻す

## Project Structure

### Documentation (this feature)

```text
specs/TAK-14-image-content-refresh/
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
├── Model/FileContentVersion.swift        # 新規
├── Model/MediaFile.swift                 # contentVersion
├── FileSystem/DirectoryLister.swift      # 資源値のキーと版
├── Archive/ArchiveIndex.swift            # zip の中の行の版
├── Imaging/DecodedImageCache.swift       # 版の照合
├── Imaging/ThumbnailProvider.swift       # 版を含むキー
└── Browser/BrowserModel.swift            # 変更の検出、プレビューの読み込み直し、検索結果
Sources/FolzioApp/FileList/
├── ListModeView.swift                    # 変わった行の読み込み直し
└── ThumbnailModeView.swift               # 同上、セルの代替アイコン
Tests/FolzioCoreTests/
├── FileContentVersionTests.swift         # 新規
├── DecodedImageCacheTests.swift
├── DirectoryListerTests.swift
├── ThumbnailProviderTests.swift
├── BrowserModelFolderTests.swift         # または新規 BrowserModelContentRefreshTests.swift
├── BrowserModelSearchTests.swift
└── BrowserModelArchiveTests.swift
```

**Structure Decision**: 既存の Swift Package の構成のまま。判断ロジック（版の比較、変更の検出、プレビューの読み込み直しの判断）は Core に置き、
App は観察と行の読み込み直しだけを行う（AGENTS.md）。

## リスク

- QuickLook が OS 側で古い縮小画像を返す可能性（research.md R3）。GUI 確認で判別し、残れば別の課題にする
- `fileIdentifier` が安定しないファイルシステム（ネットワークボリュームなど）では、版が不要に変わり、縮小画像を作り直すことがある（表示は正しい）
- TAK-7（ThumbnailProvider のテストの断続的な失敗）があるため、縮小画像のテストは QuickLook に頼らない zip の経路と、キーの計算で行う

## Complexity Tracking

違反なし。
