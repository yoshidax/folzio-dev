# Implementation Plan: TAK-88 ブラウザの画像をフォルダへ保存する

**Branch**: `claude/clever-knuth-udimb8` | **Date**: 2026-11-08 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-88-browser-image-import/spec.md`

## Summary

アプリ外からのドラッグとペーストで、file URL がないときに、ファイルの書き出しの約束（file promise）と画像データを受け取り、画像と対応形式の動画をファイルとして保存する。
受け取るデータの選び方・名前・中身の判別・一時的なフォルダと、期限・容量・状態の判断は `FolzioCore` に置き（R2〜R4・R6・R10）、ペーストボード・ドラッグ・パネルは `FolzioApp` に置く（R2・R3・R9）。
約束は宛先と同じボリュームの一時的なフォルダへ書き出させ、ドラッグ元が書き込めない複製を検査してから、既存のコピーの確認・衝突の経路で宛先へ移す（R3・R4・R7）。
画像データは PNG で書く（R5）。ネットワークへ通信せず、細工された名前・種類・大きさ・構造を拒み、quarantine の印を付ける（R4・R6・R8）。
2 秒を超える受け取りはパネルで示し、ボタンと ⌘. で取り消せる（R9）。強制終了で残った一時的なフォルダは、次の起動で確かめてから消す（R10）。
ブラウザが渡すものは未検証なので、実装の最初に保守者が確認スクリプトで確かめ、結果で仕様を確定する（R1）。

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: Foundation、AppKit、ImageIO、UniformTypeIdentifiers（既存）。外部依存なし。AVFoundation は使わない（R4）

**Storage**: `UserDefaults` のキー `internal.pendingImportFolders`（起動時の掃除の記録。設定ではない。R10）

**Testing**: Swift Testing（`Tests/FolzioCoreTests`、`Tests/FolzioAppTests`）、macOS CI、保守者の確認（quickstart.md）

**Target Platform**: macOS 15 以降

**Project Type**: Swift Package のデスクトップアプリ

**Performance Goals**: ホバー中にファイルシステムを読まない（R2）。書き出し・複製・検査・変換は UI スレッドで行わない。
画像データの読み出しは UI スレッドで行うが、R1 で 200 MB の時間を測り、0.2 秒を超えれば R5 の代わりの方法に切り替える。
書き出しを待つ間、フォルダの切り替え・プレビューへの入力から表示が変わり始めるまでを 1 秒以内にする（SC-189）。
読み出しの時間と、変更前後のドラッグの反応の計測条件・結果を `checklists/validation.md` に記録し、PR に記載する（憲章 原則 II）

**Constraints**: ネットワーク API を使わない（FR-353、憲章 原則 I）。画像を展開せず、動画を再生せずに中身を判別する（R4）。
アプリ内のドラッグと file URL の受け取りの規則を変えない（SC-192）。AppKit UI の不変条件（AGENTS.md）を守る

**Scale/Scope**: 1回の受け取りで数件の画像・動画。画像 256 MB・動画 4 GB まで。宛先は FR-345 の範囲とペーストの宛先

## Constitution Check

| 原則 | Phase 0 / Phase 1 の確認 |
|---|---|
| I ローカル完結・破壊的操作の確認 | 下記 |
| II 性能・UI スレッド | 下記 |
| III キーボード操作 | 下記 |
| IV テスト | 下記 |
| V YAGNI | 下記 |
| 仕様の管理 | 適合。変更はこの feature に記録し、検証後に `specs/product/` へ反映する |

**表の詳細**

- **I ローカル完結・破壊的操作の確認**（Phase 0 / Phase 1 の確認）: 適合。Folzio は通信せず、URL は名前の文字列としてだけ使う（FR-353）。
  - 保存は既存のファイルを変えないコピーとして確認し、同じ名前は常に衝突のダイアログで選ばせる（FR-025・FR-347）
  - 起動時の掃除は、確かめた一時的なフォルダだけを消し、ユーザーの項目を消さない（R10）
- **II 性能・UI スレッド**（Phase 0 / Phase 1 の確認）: 適合する計画。重い処理は detached task（R3〜R5）。
  - 画像データの読み出しだけは、ペーストボードの制約で UI スレッドで行う。R1 で測り、遅ければ切り替える（R5）
- **III キーボード操作**（Phase 0 / Phase 1 の確認）: 適合。ドラッグと同じ保存を ⌘V・「ここにペースト」で行える（FR-354）。
  - 取り消しは編集メニューの項目と ⌘. で行える（R9）。パネルの行はボタンのアクセシビリティのラベルを持つ
- **IV テスト**（Phase 0 / Phase 1 の確認）: 適合する計画。名前・中身の判別・構造の検査・記録・受け取るデータの選び方を Swift Testing で網羅する。
  - 期限・容量・状態の判断は Core の純粋な型をテストする。App の時計・約束・確認を差し替えたテストで、遅い結果の拒否と掃除、宛先の消失、同時の受け取りを確かめる（R3）
  - ペーストボードの型の判定とメニューの有効・無効は、名前付きの `NSPasteboard` で App のテストにする
  - ブラウザ・写真アプリとの受け渡しは、quickstart.md で保守者が確かめる。まだ実行していない
- **V YAGNI**（Phase 0 / Phase 1 の確認）: 適合。新しい確認の種類を作らず、既存の `transferItems` と `ConfirmationPresenter` を使う（R7）。
  - 新しい依存はない。設定項目を増やさない（記録は内部のもの）

設計の前後で違反はない。設計レビューの承認前に実装しない（`docs_private/cloud-agent-workflow.md` の「全体の流れ」）。

## Project Structure

### Documentation (this feature)

`spec.md`、`plan.md`、`research.md`、`data-model.md`、`contracts/browser-image-import.md`、`quickstart.md`、`tasks.md`、
`checklists/requirements.md`、`checklists/validation.md`（R1 と保守者の確認の記録）

### Source Code (repository root)

- `scripts/dev/pasteboard-probe.swift`（新規。開発用。公開用リポジトリへ書き出さない）: ドラッグとクリップボードの型・約束・マスク・時間を表示し、
  検査の確認のために中身と拡張子を食い違わせた約束を渡す（R1）
- `Sources/FolzioCore/Operations/ImportPayloadPolicy.swift`（新規）: 受け取るデータの選び方（R2・R5・R11）
- `Sources/FolzioCore/Operations/ImportBudget.swift`・`ImportReceptionState.swift`（新規）: 期限・容量と状態の純粋な判断（R3）
- `Sources/FolzioCore/Operations/ImportedFileName.swift`（新規）: 名前の規則（R6）
- `Sources/FolzioCore/Operations/ImportInspector.swift`（新規）: 構造・複製・大きさ・中身の判別・quarantine の印（R4・R8）
- `Sources/FolzioCore/Operations/ImportStaging.swift`（新規）: 一時的なフォルダの作成・見張り・削除（R3・R10）
- `Sources/FolzioCore/Operations/ImportCleanupRecord.swift`（新規）: 起動時の掃除の記録と確認（R10）
- `Sources/FolzioCore/Operations/ImageDataWriter.swift`（新規）: 画像データの PNG への書き込み（R5）
- `Sources/FolzioCore/Operations/OperationFailureReason.swift`: `importRejected(ImportRejection)` を加える（R12）
- `Sources/FolzioApp/Shared/ExternalImageDrag.swift`（新規）: ホバー中の判定、ドロップの読み出し（R2・R3・R5）
- `Sources/FolzioApp/Shared/PasteboardImport.swift`（新規）: クリップボードの型の判定と読み出し（R11）
- `Sources/FolzioApp/Operations/ImportSession.swift`（新規）: 1回の受け取りの流れ（R3）
- `Sources/FolzioApp/Operations/ReceivingPanelController.swift`（新規）: 進み具合のパネル（R9）
- `Sources/FolzioApp/Operations/FileOperationCoordinator.swift`: `saveReceived`（R7）、`paste` の分岐（R11）
- `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift`・`FileList/ListModeView.swift`・`FileList/ThumbnailModeView.swift`:
  登録する型と、画像の受け取りの経路（R2）
- `Sources/FolzioApp/FileList/FileContextMenu.swift`・`FileListViewController.swift`・`Tree/DirectoryTreeViewController.swift`: ペーストの有効・無効（R11）
- `Sources/FolzioApp/App/MainMenu.swift`（または編集メニューを作る場所）: 「受け取りを取り消す」（R9）
- `Sources/FolzioCore/Shortcuts/ShortcutCatalog.swift`・`ShortcutCommand.swift`: ショートカット一覧と `ReservedShortcutKeys.combinations` に ⌘. を加える
- `Sources/FolzioApp/App/AppDelegate.swift`: 起動時の掃除（R10）
- `Sources/FolzioLocalization/TextKey.swift`・`Resources/{en,ja}.lproj/Localizable.strings`: 新しい文言（R12）
- `Tests/FolzioCoreTests/ImportPayloadPolicyTests.swift`・`ImportedFileNameTests.swift`・`ImportInspectorTests.swift`・
  `ImportStagingTests.swift`・`ImportCleanupRecordTests.swift`・`ImageDataWriterTests.swift`（新規）
- `Tests/FolzioCoreTests/ImportBudgetTests.swift`・`ImportReceptionStateTests.swift`（新規）: 時間と容量の境界・状態の移り変わり
- `Tests/FolzioAppTests/ImportSessionTests.swift`（新規）: 時計・約束・確認を差し替えた受け取り、掃除、宛先の失敗、複数の操作
- `Tests/FolzioCoreTests/ShortcutCatalogTests.swift`・`Shortcuts/ShortcutAssignmentsTests.swift`・`Localization/ShortcutTextTests.swift`: 一覧の件数・予約キー・文言
- `Tests/FolzioAppTests/ExternalImageDragTests.swift`・`PasteboardImportTests.swift`（新規）: 型の登録、ペーストボードの判定、メニューの有効・無効、⌘. の有効な条件
- `README.md`・`README.ja.md`・`docs/usage.md`・`docs/usage.ja.md`: ブラウザの画像の保存の説明（2 言語を同じコミットで）

**Structure Decision**: 判断と検査は `FolzioCore`、ペーストボード・ドラッグ・パネル・メニューは `FolzioApp`（AGENTS.md の設計の制約）。
保存は新しい実行の経路を作らず、既存の `FileOperationCoordinator.transferItems` と `ConfirmationPresenter` を使う（R7）。

## 実装の順序

1. 先に行う確認: `pasteboard-probe.swift` を push し、保守者が macOS で確かめ、結果で spec・plan を確定する（R1）
2. Core: `ImportedFileName`・`ImportPayloadPolicy`・`ImportBudget`・`ImportReceptionState`・`ImportInspector`・`ImportStaging`・`ImportCleanupRecord`・`ImageDataWriter` とテスト
3. App: ドラッグの型の登録とホバー中の判定、約束と画像データのドロップ、`saveReceived`（US77）
4. App: パネルと取り消し、編集メニューの項目（FR-363）
5. App: ペーストとメニューの有効・無効（US78）
6. App: 起動時の掃除、ローカライズ
7. 文書（README・usage）と、検証の後の `specs/product/` への反映（PR の最後）

## 未検証の点（保守者の macOS で確かめる）

- Safari・Chrome・写真アプリが渡す型・約束の種類・マスク・名前（R1）
- 一般のペーストボードの約束を読み出せるか（R1 の 3・R11）
- 画像データの読み出しの時間（R1 の 4・R5）
- `copyfile` の複製が exFAT・SMB で切り替わること、拡張属性を保存できないボリュームでの動き（R4・R8）
- パネルが操作を妨げず、⌘. が名前の変更・シート・ダイアログで優先されること（R9）

## Complexity Tracking

違反なし。
