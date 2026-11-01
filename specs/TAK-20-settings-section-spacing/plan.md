# Implementation Plan: 設定ウインドウのセクション間隔の統一と確認オプションの補足説明の分離

**Branch**: `claude/festive-babbage-ick4ki` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-20-settings-section-spacing/spec.md` / [TAK-20](https://linear.app/takyoshida/issue/TAK-20)

## Summary

設定ウインドウ（`SettingsWindowController`）の縦の `NSStackView` に、区分の前だけ広い間隔（20pt）を個別に設定し、区分の中の間隔（8pt）と分ける。
確認のチェックボックスに付けていた最小の高さ 60pt の制約（大きな空白の原因）を外し、確認の文言を主文と補足説明の2つの翻訳キーに分ける。
補足説明は小さい文字・二次的な文字色の折り返しラベルとして、チェックボックスの直下（4pt）にチェックボックスの文言の先頭へ揃えて置き、
読み上げではチェックボックスのヘルプとして結び付ける。ウインドウの高さの下限（320pt）を外し、内容と表示言語の切り替えに合わせて高さを合わせ直す。
確認の設定の保存・判定（Core の `SettingsStore`・`ConfirmationPolicy`）は変えない。

本資料は設計レビュー用。`docs_private/cloud-agent-workflow.md` の「承認の前に実装しない」に従い、設計の承認後に tasks.md の実装タスクを始める。

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: Foundation、AppKit、既存の FolzioCore / FolzioLocalization。外部依存なし

**Storage**: 変更なし（`fileOps.confirmBeforeExecuting` をそのまま使う）

**Testing**: Swift Testing（`Tests/FolzioCoreTests/Localization/`）。翻訳の欠け・未使用は既存の `CatalogConsistencyTests` が検出する。
主文と補足説明の値を固定する回帰テストを追加する。見た目（間隔・揃え・色）は自動テストせず、quickstart.md の手順で保守者が GUI で確認する（憲章 原則 IV の「UI の見た目そのものの自動テストは必須としない」）

**Target Platform**: macOS 15 以降。Cloud（Linux）では `swift` と GUI を実行しない。ビルドとテストは CI、GUI は保守者

**Project Type**: Swift Package のデスクトップアプリ

**Performance Goals**: 設定ウインドウの静的な配置の変更だけで、デコード・列挙・ファイル操作の経路に変更はない

**Constraints**: Core は AppKit を import しない（今回 Core の変更はない）。ウインドウ・ビューの操作は MainActor。制約は `addSubview` の後に有効化し、
配置は leading / trailing で指定する（FR-153）。ネットワーク API なし

**Scale/Scope**: 1ファイルの UI（`Sources/FolzioApp/Settings/SettingsWindowController.swift`）、翻訳キー1つの追加と1つの値の変更、テスト1ファイル

## Constitution Check

| 原則 | Phase 0 前 / Phase 1 後の判断 |
|---|---|
| I ローカル完結 | PASS / PASS。通信・外部リソースなし |
| II 体感性能 | PASS / PASS。設定ウインドウの配置だけ。UI スレッドで重い処理を追加しない |
| III キーボード・アクセシビリティ | PASS / PASS。Tab の移動順は変えない。補足説明はチェックボックスのアクセシビリティのヘルプとして読み上げる。OS の標準の二次的な文字色で、外観とコントラストの設定に従う |
| IV テスト必須 | PASS / PASS。翻訳の値と欠けを自動テストで検証。GUI は quickstart.md の手順で保守者が確認し、確認前は完了にしない |
| V YAGNI | PASS / PASS。汎用の「説明付き設定行」部品は作らず、確認の項目だけに補足説明を付ける（A-138） |
| 仕様管理 | PASS / PASS。新しい feature ディレクトリだけを作る。`specs/product/` への反映は実装・検証の後、PR の最後に行う。ID は最新の product の最大値 FR-221 / SC-109 / EC-152 / A-135 / US38 の次から採った（2026-11-01 に master を取り込み、TAK-17・19・21 との衝突を避けて振り直した） |

## Project Structure

### Documentation (this feature)

```text
specs/TAK-20-settings-section-spacing/
├── spec.md
├── plan.md                    # この文書
├── research.md                # R1〜R6
├── data-model.md              # 翻訳の単位（新しい保存データはない）
├── contracts/settings-window.md  # 設定ウインドウの配置と文言の契約（product の contracts へ反映する差分）
├── quickstart.md              # CI と GUI の確認手順・結果の記録
├── checklists/requirements.md
└── tasks.md                   # /speckit-tasks の出力
```

### Source Code (repository root)

```text
Sources/FolzioApp/Settings/SettingsWindowController.swift   # 間隔・補足説明・高さの合わせ直し
Sources/FolzioLocalization/TextKey.swift                     # settingsConfirmNote の追加と説明
Sources/FolzioLocalization/Resources/en.lproj/Localizable.strings  # settings.confirm の値の変更、settings.confirm.note の追加
Sources/FolzioLocalization/Resources/ja.lproj/Localizable.strings  # 同上
Tests/FolzioCoreTests/Localization/SettingsTextTests.swift   # 主文と補足説明の値の回帰テスト（新規）
```

**Structure Decision**: 判断ロジックの追加がないため Core は変えない。描画と入力は `FolzioApp`、文言は `FolzioLocalization` に置く既存の構成に従う。

## 設計の要点

1. **間隔**（R1）: 縦の stack の `spacing` は 8pt のまま（区分の中の間隔・見出しと最初の項目の間隔）。区分の前（言語の行・ループのチェックボックス・補足説明の後）に
   `setCustomSpacing(20, after:)` を設定する。ウインドウの上下左右の余白 20pt と同じ値にする
2. **空白の原因の除去**（R2）: `confirmFileOperationsCheckbox.heightAnchor >= 60` を削除する。主文が短くなり、両言語とも1行に収まる
3. **折り返し**（R3）: 確認のチェックボックスは、幅に合わせて高さを計算する小さな subclass（`WrappingCheckbox`）にして、将来の長い訳でも欠けずに折り返す（EC-153）。
   補足説明は `NSTextField(wrappingLabelWithString:)` で、幅の制約から高さが決まる
4. **補足説明の見た目と揃え**（R4）: `NSFont.smallSystemFontSize` のシステムフォント、`NSColor.secondaryLabelColor`。選択不可・編集不可。
   チェックボックスの直後の間隔は `setCustomSpacing(4, after:)`。先頭の位置はチェックボックスのセルの文言の位置（`titleRect(forBounds:)`）から求めた字下げ
5. **アクセシビリティ**（R5）: `confirmFileOperationsCheckbox.setAccessibilityHelp(補足説明)`、補足説明のラベルは `setAccessibilityElement(false)`。言語の切り替えで両方を更新する
6. **ウインドウの高さ**（R6）: 初期化と `updateLocalizedLabels()` の最後で `fittingSize.height` に合わせ、上端の位置を保って高さだけを変える。下限 320pt は外す

## Complexity Tracking

違反なし。
