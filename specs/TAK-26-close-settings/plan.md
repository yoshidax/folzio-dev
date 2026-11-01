# Implementation Plan: メインウインドウと設定ウインドウの終了連動

**Branch**: `work` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-26-close-settings/spec.md`

## Summary

AppDelegate が実際のメイン NSWindow の willCloseNotification を監視し、保持している SettingsWindowController に close() を送る。既存の最終ウインドウ終了判定によってアプリを終了する。設計レビュー承認後に実装する。

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: AppKit、Foundation。外部依存の追加なし。

**Storage**: 既存 SettingsStore / UserDefaults。新規キーなし。

**Testing**: 既存 Swift Testing（macOS CI）と quickstart.md の GUI 確認。

**Target Platform**: macOS 15 以降

**Project Type**: Swift Package の desktop-app

**Performance Goals**: クローズ時の同期処理のみ。デコード・走査・継続的な監視処理を増やさない。

**Constraints**: MainActor で UI 操作。オフライン。MainSplitViewController の window delegate を置き換えない。

**Scale/Scope**: メイン1個・既存設定コントローラ最大1個の寿命の連動。

## Constitution Check

設計前・設計後とも適合。

- I: 通信、ユーザーメディアの変更、新規永続化なし。
- II: 重い処理や表示経路の変更なし。
- III: 既存の閉じる操作と ⌘, を使い、新規操作なし。
- IV: Core の判断ロジックを追加しない UI の終了連動。既存自動テストに加え GUI の振る舞いを quickstart.md で検証する。AppKit テスト用ターゲットの新設は行わない。
- V: AppDelegate の既存所有関係で実装し、汎用ライフサイクル層を作らない。
- マージ前: CI 成功と保守者の macOS 起動スモーク・最新 Swift 確認が必要。未実施を完了扱いにしない。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-26-close-settings/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/window-lifecycle.md
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/FolzioApp/App/AppDelegate.swift                 # 実装対象
Sources/FolzioApp/App/MainSplitViewController.swift     # 既存終了処理の確認対象
Sources/FolzioApp/Settings/SettingsWindowController.swift # 設定確定処理の確認対象
specs/product/contracts/settings.md                    # 検証後・PR 最後に反映
```

**Structure Decision**: ウインドウ同士の所有者である AppDelegate だけを変更する。コントローラ間の新しい依存は作らない。

## Implementation Design

1. MainWindowController 生成後、その window を object に指定して、selector 方式で NSWindow.willCloseNotification を登録する。showWindow より前に登録する。
2. MainActor の @objc ハンドラで通知元が保持するメイン window と一致することを確認し、settingsWindowController?.close() を呼ぶ。設定未生成なら何もしない。設定終了の通知には反応しない。
3. close() は既存の SettingsWindowController.windowWillClose → makeFirstResponder(nil) を通す。orderOut や直接 terminate は用いない。
4. MainSplitViewController の windowWillClose によるスライドショー停止と、applicationShouldTerminateAfterLastWindowClosed の true を維持する。通知の処理順には依存しない。
5. 既存の selector 通知方式に合わせ、非同期 Task やクロージャ observer のトークンは追加しない。AppDelegate はアプリ寿命中保持される。

## Verification and Delivery

- quickstart.md の条件で終了・編集確定・再表示・スライドショー停止を確認。
- Cloud の4検査を実施し、macOS CI と保守者確認を区別して報告。
- product 反映直前に最新 master を取り込み、ID の競合を解消する。反映差分は保守者承認後にコミット。
- 現在の Cloud 指定ブランチ work は push 許可プレフィックスに含まれない。ブランチを無断変更せず、push が必要になった段階で命名を保守者に確認する。

## Complexity Tracking

憲章違反なし。追加の抽象化や依存なし。
