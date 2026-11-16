# Implementation Plan: 操作ごとの実行前の確認の設定

**Branch**: `feature/tak-105-confirm-move-rename` | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

**Input**: [TAK-105](https://linear.app/takyoshida/issue/TAK-105/) と現行の file-operations.md・directory-tree.md・
window-layout.md・contracts/settings.md・contracts/localization.md

## Summary

1つの確認の設定（`fileOps.confirmBeforeExecuting`）を、コピー・移動・名前の変更・お気に入りから削除・ゴミ箱に入れるの
5つの設定に分ける。移動と名前の変更も省略できるようにし、ツリーのフォルダをゴミ箱に入れる操作だけを常に確認する。
確認の要否の判断は `FolzioCore` の `ConfirmationPolicy` に集め、`ConfirmationPresenter` と設定ウインドウはそれに従う。
以前の版の設定は読み込み時に引き継ぐ（移動・名前の変更はオンで始める）。

**見直し（GUI の確認の前）**: ツリーのフォルダをゴミ箱に入れる操作も、ファイルリストと同じ「ゴミ箱に入れる前に確認する」で
省略できるようにし、補足説明をなくす（research.md R7）。これに合わせて、製品仕様のうち「常に確認する」と書いた項目
（FR-079・US37-AS1・US1-AS44・A-32・A-33・contracts/keyboard-and-menus.md・overview.md の US4 の説明文）も書き換える。

## Technical Context

**Language/Version**: Swift 6（CI は Xcode 16.0）

**Primary Dependencies**: AppKit、FolzioCore、FolzioLocalization。追加依存なし

**Storage**: `UserDefaults`。新しい5つのキーを追加し、旧キーは読み込み元として残す（[contracts/settings.md](contracts/settings.md)）

**Testing**: Swift Testing（FolzioCoreTests の `ConfirmationPolicyTests`・`SettingsStoreTests`・`SettingsTextTests`、
FolzioAppTests の確認モーダルのテスト）、保守者の GUI 起動確認

**Target Platform**: macOS 15 以降の既存ターゲット

**Project Type**: デスクトップアプリ

**Performance Goals**: 変更なし（設定の読み込みは `UserDefaults` の数回の読み取り）

**Constraints**: オフライン。判断ロジックは AppKit を import しない `FolzioCore` に置く

**Scale/Scope**: 設定5項目、確認モーダルの呼び出し元5か所（コピー・移動・名前の変更・ゴミ箱・お気に入りの削除）

## Constitution Check

| 原則 | 設計上の確認 |
|---|---|
| I ローカル完結 | 外部通信を追加しない。ゴミ箱に入れる操作（ファイルリストとツリーのフォルダ）はゴミ箱経由で元に戻せるため、確認を省略しても「確認または取り消し可能性」を満たす。対象は利用者が右クリックまたは選択した項目に限られる（TAK-115・A-21）。移動・名前の変更は元の項目を失わず、利用者が明示的に確認を外したときだけ省略する（A-235）。同名の上書きは常に確認する（FR-025）。 |
| II 体感パフォーマンス | UI スレッドで重い処理を追加しない。 |
| III キーボードとアクセシビリティ | 5つのチェックボックスを Tab の移動順に入れる。補足説明はなくす（見直し後）。「今後この確認を表示しない」は標準の確認モーダルのチェックボックスでキーボードから操作できる。 |
| IV テスト | 操作と設定の対応・移行を `FolzioCore` に置き、単体テストで全組み合わせを確かめる。 |
| V シンプルさ | 設定は spec が求める5項目だけとし、ペインごとの設定は追加しない（A-232。ツリーのフォルダのゴミ箱専用の設定も見直しで取りやめた）。 |

**Post-design**: 上記を満たす。Complexity Tracking に記録する違反はない。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-105-confirm-move-rename/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/settings.md
├── contracts/localization.md
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/FolzioCore/
├── Model/Settings.swift                    # ConfirmationOptions を5項目に（ConfirmationTarget）
├── Operations/ConfirmationPolicy.swift     # 操作 → 確認の設定の対応（ツリーのゴミ箱は nil）
└── Settings/SettingsStore.swift            # 5つのキーの読み書きと旧キーからの引き継ぎ、変更の通知
Sources/FolzioLocalization/
├── TextKey.swift                           # settings.confirm.* のキー
└── Resources/{en,ja}.lproj/Localizable.strings
Sources/FolzioApp/
├── Operations/ConfirmationPresenter.swift  # 操作ごとの省略と「今後この確認を表示しない」
└── Settings/SettingsWindowController.swift # 5つのチェックボックス・補足説明・Tab 順・表示中の反映
Tests/FolzioCoreTests/
├── ConfirmationPolicyTests.swift
├── SettingsStoreTests.swift
└── Localization/SettingsTextTests.swift
Tests/FolzioAppTests/
└── ConfirmationPresenterTests.swift        # 新規。省略・抑止・親ウインドウなしの動作
```

**Structure Decision**: 既存の配置に従う。判断（どの設定に従うか、移行）は `FolzioCore`、モーダルの表示と設定ウインドウは
`FolzioApp` に置く。

## Complexity Tracking

記録する違反はない。
