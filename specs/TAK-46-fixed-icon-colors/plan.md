# Implementation Plan: フォルダと zip の行頭アイコンの固定色

**Branch**: `claude/adoring-mccarthy-vgojyp` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-46-fixed-icon-colors/spec.md` / [TAK-46](https://linear.app/takyoshida/issue/TAK-46)

## Summary

行頭アイコンの色を、アイコンの種別（`ListItemKind`）から決める。種別→色の役割（フォルダ系は青、zip は黄、`..` は従来色）の判断は Core の純粋な関数に置いて Swift Testing で検証し、実際の `NSColor`（固定の sRGB 値）の定義と適用は `FolzioApp` の `IconCatalog` に置く。リスト形式（`ListModeView`）とサムネイル形式（`ThumbnailModeView`）は、いまそれぞれが直接書いている `.secondaryLabelColor` を、この 1 か所の定義の参照に置き換える。ツリー・メディアの縮小画像・`..` は変えない。

本資料は設計レビュー用。承認の前に実装しない。

## Technical Context

**Language/Version**: Swift 6 / **Dependencies**: Foundation・AppKit のみ（外部依存なし）

**Storage**: なし / **Testing**: Swift Testing（`FolzioCoreTests`、`FolzioAppTests`）。見え方は quickstart.md で保守者が GUI 確認

**Target Platform**: macOS 15 以降。Cloud では Swift も GUI も実行しないので、ビルド・テストは CI で確認する

**Constraints**: Core は AppKit を import しない。UI スレッドで重い処理をしない（色の指定のみ）。ネットワーク API は使わない

**Scale/Scope**: Core に 1 つの enum と 1 つのプロパティ、`IconCatalog` に色 2 つと対応関数 1 つ、描画側 2 箇所の置き換え

## Constitution Check

| 原則 | 判断 |
|---|---|
| I ローカル完結 | PASS。通信なし |
| II 体感パフォーマンス | PASS。色の指定のみで、描画経路は変えない |
| III キーボード・アクセシビリティ | PASS。操作・読み上げは変えない（EC-189）。固定色のコントラストは GUI で確認（EC-188） |
| IV テスト必須 | PASS。種別→色の役割は Core のテストで、固定色の値は App のテストで検証 |
| V シンプルさ | PASS。設定項目・抽象化の追加なし。色の定義は 1 か所 |

## Design

### 色の決め方（A-164 の確定案）

- 固定値は sRGB で持ち、外観モード・アクセントカラーに依存しない。
  - **青**: `sRGB(0.18, 0.64, 1.00)`（Apple の `systemBlue`（ライト）に近い値。HSB の明度 1.00）
  - **黄**: `sRGB(0.96, 0.72, 0.00)`（`systemYellow` より暗く寄せた値。HSB の明度 0.96）
  - 青と黄の HSB 明度の差を 0.1 以内に保つ（FR-270 の「明度を近づける」を、App のテストで数値として検証する）。
- ツリーの青は AppKit の既定描画に由来する可能性があり、実際の色はスクリーンショットなしでは確定できない。そのため上の値は**案**とし、保守者が GUI でツリーと見比べて、必要なら値だけを調整する（実装の構造は変わらない）。

### 構成

- Core: `ListItemKind` に `iconTone`（`.folderBlue` / `.archiveYellow` / `.secondary`）を返す拡張。`.folder`・`.directory` → `folderBlue`、`.archive` → `archiveYellow`、`.parent`・`.media` → `secondary`。
- App: `IconCatalog.tintColor(for: ListItemKind) -> NSColor?` が `iconTone` から `NSColor` を返す（メディアは従来どおり呼び出し側で `nil`）。
- `ListModeView.nameCell`（非メディア行）と `ThumbnailModeView.showListItemIcon` が `IconCatalog.tintColor(for:)` を使う。メディア行・再利用時の `nil` 戻しは変えない。

### 選択行の扱い（US51-AS6・EC-188）

`contentTintColor` は選択行でも変えない。選択行の背景（アクセントカラー）上で青が見えにくい場合は、保守者の GUI 確認で判断する。見えにくければ、選択時だけ明るい青にする案を別途提示する（本 feature では、ここまでは実装しない）。

## 検証

- 自動: Core の種別→色の役割、App の固定色の値と明度差。CI で `swift build` / `swift test`
- Cloud: `scripts/check-no-network.sh`、`check-readme-sync.sh master`、`dev/check-english-comments.sh`、`dev/check-skill-sync.sh`
- GUI（保守者）: [quickstart.md](quickstart.md)

## Project Structure

```
Sources/FolzioCore/Model/MediaKind.swift      # ListItemIconTone と ListItemKind.iconTone
Sources/FolzioApp/Shared/IconCatalog.swift    # tintColor(for:)
Sources/FolzioApp/FileList/ListModeView.swift
Sources/FolzioApp/FileList/ThumbnailModeView.swift
Tests/FolzioCoreTests/, Tests/FolzioAppTests/
```
