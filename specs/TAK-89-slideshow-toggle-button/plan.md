# Implementation Plan: TAK-89 スライドショーのボタンを開始・停止のトグルにする

**Branch**: `claude/practical-einstein-4f58rd` | **Date**: 2026-11-08 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-89-slideshow-toggle-button/spec.md`

## Summary

ボタンの状態（オン・オフ、有効・無効、押したときの操作）は、Core の新しい値型 `SlideshowToggleState` で決める（R1）。
入力は、今の `SlideshowStartPolicy` の開始の可否と、実行状態・シート・アプリモーダル・名前の変更の編集の有無だけにする。
ツールバーのボタンは OS 標準のトグル（`NSButton` の `.pushOnPushOff`）に変え、押すとツールバーのコントローラが
`MainSplitViewController.toggleSlideshow(_:)` を呼ぶ（R2）。停止は、Esc と同じ `SlideshowCoordinator.stop()` を使う（R3）。
押した後に AppKit が反転したボタンの状態は、実際の実行状態で上書きする。実行状態の変化は、今の `onSlideshowAvailabilityChange` の経路で
ボタンへ伝える（R4）。実行中にシートが開閉したときの更新のため、メインウインドウのシートの通知を加える（R5）。
メニュー「表示 > スライドショーを開始」と ⇧⌘S は、今の `startSlideshow(_:)` と `canStartSlideshow` のまま変えない（A-208）。

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: Foundation / AppKit。外部依存なし

**Storage**: なし（新しい設定・永続データを追加しない）

**Testing**: Swift Testing（`Tests/FolzioCoreTests`）、macOS CI、保守者の GUI 確認（quickstart.md）

**Target Platform**: macOS 15 以降

**Project Type**: Swift Package のデスクトップアプリ

**Performance Goals**: 状態の判定は 6 つの真偽値の計算だけで、UI スレッドでファイルシステムを読まない。既存の性能の基準（SC-001）を変えない

**Constraints**: 判断ロジックは FolzioCore（AppKit を import しない）、描画と入力は FolzioApp に置く（AGENTS.md）。
メニューと ⇧⌘S の動作を変えない（SC-189）。ネットワーク API を使わない

**Scale/Scope**: ツールバーの「スライドショー」ボタン 1 つ（あふれたメニュー・文字だけの形式を含む）と、その文言 1 つ（日英）

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判定 | 根拠 |
|---|---|---|
| I. ローカル完結・プライバシー | 適合 | ネットワーク・ファイル操作を加えない |
| II. 体感パフォーマンス | 適合 | 状態の判定は真偽値の計算だけ。デコード・列挙に触れない |
| III. キーボードファースト & アクセシビリティ | 適合 | 停止のキーボードの手段は既存の Esc（A-208）。ボタンは固定のアクセシビリティラベル「スライドショー」と、状態に合った説明を持ち、トグルの値（オン・オフ）を VoiceOver へ渡す（FR-353・A-211） |
| IV. テスト必須 | 適合 | 判断を `SlideshowToggleState` に分け、真理値表のテストを書く。文言は既存の翻訳の検査に加える（R6） |
| V. シンプルさ | 適合 | 新しい型は値型 1 つ。メニューと ⇧⌘S は変えない。あふれたメニューの名前は切り替えない（spec の EC-240） |

設計の後の再確認: 違反なし。Complexity Tracking は不要。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-89-slideshow-toggle-button/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── toolbar-slideshow-toggle.md
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks で作る
```

### Source Code (repository root)

```text
Sources/FolzioCore/Slideshow/
└── SlideshowToggleState.swift          # 追加。オン・オフ、有効・無効、押したときの操作（R1）

Sources/FolzioApp/App/
├── MainSplitViewController.swift       # slideshowToggleState と toggleSlideshow(_:) を追加（R2・R3）。シートの通知（R5）
└── MainToolbarController.swift         # ボタンをトグルにし、状態と文言を適用する（R2・R4）。あふれたメニュー（R7）

Sources/FolzioLocalization/
├── TextKey.swift                       # toolbarStopSlideshowHelp を追加（R6）
└── Resources/{ja,en}.lproj/Localizable.strings

docs/
├── usage.md・usage.ja.md              # スライドショーの節とショートカットの表に、ボタンでの終了を加える（T018）
└── development.md・development.ja.md  # 手動の確認にボタンでの開始と終了を加える（T018）

Tests/FolzioCoreTests/
├── SlideshowToggleStateTests.swift     # 追加。真理値表（R1）
└── Localization/ShortcutSettingsTextTests.swift などの翻訳の検査に新しいキーを加える（R6）
```

**Structure Decision**: 既存の Swift Package の構成のまま。Core の判断は `Sources/FolzioCore/Slideshow/` に、AppKit の適用は `Sources/FolzioApp/App/` に置く。

## Complexity Tracking

なし。
