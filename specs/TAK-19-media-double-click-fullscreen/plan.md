# Implementation Plan: メディア表示区画のダブルクリックによる全画面の切り替え

**Branch**: `claude/zen-goodall-wtxkca` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-19-media-double-click-fullscreen/spec.md` / [TAK-19](https://linear.app/takyoshida/issue/TAK-19)

## Summary

ダブルクリックの認識を、画像ビューからプレビューのルートビュー（画像・動画・切り替え効果の共通の祖先）へ移し、画像と動画を同じ規則で扱う。
全画面中はプレビューが画面全体を占めるため、同じ認識で「画面のどこでも解除」を満たす。再生コントロールとスクロールバーは、認識の delegate で
`NSControl` へのヒットを除外する。空のプレビューを除く判断は FolzioCore の純粋な関数にし、Swift Testing で検証する。⌃⌘F・Esc・メニューは変えない。

本資料は設計レビュー用。`docs_private/cloud-agent-workflow.md` の「承認の前に実装しない」に従い、設計の承認後に tasks.md の実装タスクを始める。

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: Foundation、AppKit、AVKit（既存）、FolzioCore。外部依存なし。

**Storage**: なし。

**Testing**: Swift Testing（`Tests/FolzioCoreTests`）。AppKit・AVKit の実機の挙動は quickstart.md の M1〜M8。

**Target Platform**: macOS 15 以降。Cloud（Linux）では Swift と GUI を実行しない。

**Project Type**: Swift Package のデスクトップアプリ。

**Performance Goals**: マウスイベントの判断だけで、デコード・列挙・キャッシュの経路は変えない。既存の性能基準（先読み済み画像の切り替え100ms・初回画像1秒）を維持する。

**Constraints**: Core は AppKit を import しない。ビューの操作は MainActor。ネットワーク API を使わない。AppKit UI の不変条件（AGENTS.md）を守る（制約や split view の delegate には触れない）。

**Scale/Scope**: 変更するファイルは App 3〜4、Core 1（新規）、テスト 1（新規）、docs 4。

## Constitution Check

| 原則 | Phase 0 前 / Phase 1 後の判断 |
|---|---|
| I ローカル完結 | PASS / PASS。通信もファイル操作も追加しない。 |
| II 体感性能 | PASS / PASS。ダブルクリックのときだけ判断を1回行う。既存の性能テストは CI で確認する。 |
| III キーボード・アクセシビリティ | PASS / PASS。ダブルクリックはマウスの補助手段で、同じ操作は既存の ⌃⌘F・Esc・メニュー（FR-036）でキーボードから行える。アクセシビリティの要素とラベルは変えない。 |
| IV テスト必須 | PASS / PASS。判断を Core に置いて自動テストを付ける。GUI の確認は quickstart.md に記録し、CI と保守者の確認の前に完了扱いにしない。 |
| V YAGNI | PASS / PASS。新しい設定・抽象化・依存を追加しない。認識を2か所から1か所にまとめる。 |
| 仕様管理 | PASS / PASS。新しい feature ディレクトリだけを作る。ID は最新の product の最大値 FR-207 / SC-101 / EC-140 / A-118 の次から採り、US5 の AS は既存の AS6 の次から採る。product への反映は実装と検証の後に行う。 |

## Project Structure

### Documentation (this feature)

`specs/TAK-19-media-double-click-fullscreen/` に spec.md、plan.md、research.md、data-model.md、contracts/keyboard-and-menus.md、quickstart.md、checklists/requirements.md、tasks.md を置く。

### Source Code (repository root)

```text
Sources/FolzioCore/Model/PreviewDoubleClick.swift          # 新規: 判断と PreviewContent.hasMedia
Tests/FolzioCoreTests/PreviewDoubleClickTests.swift        # 新規
Sources/FolzioApp/Preview/PreviewViewController.swift      # ルートビューに認識と delegate（NSControl の除外）
Sources/FolzioApp/Preview/ImagePreviewView.swift           # 画像ビューの認識と onDoubleClick を削除
Sources/FolzioApp/App/MainSplitViewController.swift        # onDoubleClick で Core の判断を通してから togglePreviewFullScreen()
docs/usage.md / docs/usage.ja.md                           # 「画像のダブルクリック」をメディアに改める
docs/development.md / docs/development.ja.md               # 起動スモークの全画面の項目を同様に改める
```

**Structure Decision**: 判断は Core、ヒットテストと認識は App。全画面の切り替えそのもの（`togglePreviewFullScreen()`、全画面の通知、スライドショーの復帰）は変えない。

## Phase 0: Research

[research.md](research.md) の R1〜R5 に、根拠・採用案・代替案を記録した。AVKit の再生コントロールの除外（R2）と、映像のシングルクリックで再生状態が変わらないこと（R3）は、
公開 API で確かめられないため、実機の確認（quickstart.md の M2・M3）を前提とする。期待どおりでなければ作業を止めて保守者と方式を相談する。

## Phase 1: Design

1. Core に `PreviewDoubleClick.togglesFullScreen(isFullScreen:hasMedia:isOverControl:)` と `PreviewContent.hasMedia` を追加する（[data-model.md](data-model.md)）。
2. `PreviewViewController.loadView()` で、`containerView` に `NSClickGestureRecognizer` を取り付ける（`numberOfClicksRequired = 2`、`delaysPrimaryMouseButtonEvents = false`）。
   制約の追加とは独立で、`addSubview` の順序の不変条件に影響しない。
3. `PreviewViewController` を `NSGestureRecognizerDelegate` にし、`gestureRecognizer(_:shouldAttemptToRecognizeWith:)` でイベントの位置を `containerView.hitTest(_:)` で調べ、
   当たったビューから `containerView` までの祖先に `NSControl` があれば false を返す。
4. 認識が終わったら `onDoubleClick` を呼ぶ。`onDoubleClick` は `imageView` への転送をやめ、`PreviewViewController` 自身のプロパティにする。
5. `ImagePreviewView` から `doubleClickRecognizer`・`onDoubleClick`・`handleDoubleClick(_:)` を削除する（同じダブルクリックで2回切り替わるのを防ぐ）。
6. `MainSplitViewController` の `onDoubleClick` で、`PreviewDoubleClick.togglesFullScreen(isFullScreen: isFullScreenPresentation, hasMedia: model.preview.hasMedia, isOverControl: false)`
   が true のときだけ `togglePreviewFullScreen()` を呼ぶ。全画面中はプレビューの内容によらず解除する。
7. docs の英語版と日本語版を同じコミットで更新する（research.md の R5）。

契約の変更は [contracts/keyboard-and-menus.md](contracts/keyboard-and-menus.md)。キーボードの割り当ては変えない。

## Validation & Delivery

[quickstart.md](quickstart.md) に、Cloud・CI・保守者の実機の担当と期待結果を分けた。設計資料の段階では Swift の build・test と GUI の確認は行っていない。
実装の後に Cloud の検査を行って作業ブランチに push し、PR は保守者の依頼があったときだけ作る。`specs/product/` への反映は PR の最後の作業とし、
直前に最新の master を取り込んで ID の衝突を確かめ、反映の差分を示して承認を得てからコミットする。

## Complexity Tracking

憲章違反なし。新しい外部依存なし。
