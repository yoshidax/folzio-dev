# Implementation Plan: 起動時のお気に入りの開閉状態

**Branch**: `codex/tak-107-favorites-startup` | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

**Input**: [TAK-107](https://linear.app/takyoshida/issue/TAK-107)

## Summary

「一般」タブに復元のチェックボックスを追加し、既定では従来どおり閉じて起動する。
設定と最後の開閉状態は別の Bool キーに保存する。
起動時の判断・不正値の扱いは `FolzioCore.SettingsStore`、開閉の適用とイベントの受領は
`FolzioApp.DirectoryTreeViewController` に置く。
UI の追加は `SettingsWindowController` と既存の英日翻訳カタログに限定する。

## Technical Context

**Language/Version**: Swift 6（`Package.swift`）

**Primary Dependencies**: Foundation、AppKit、既存の FolzioLocalization（追加依存なし）

**Storage**: 注入されたアプリの `UserDefaults` ドメイン、2つの Bool キー

**Testing**: Swift Testing、分離した `UserDefaults` suite、既存の AppKit テストターゲット

**Target Platform**: macOS 15 以降

**Project Type**: オフラインの macOS デスクトップアプリ

**Performance Goals**: 通常のツリーを新たに走査せず、起動時は既存データから見出しを1回だけ復元する

**Constraints**: Core に AppKit を追加しない、UI スレッドで列挙やファイル操作を追加しない、ネットワークを追加しない

**Scale/Scope**: 単一メインウインドウの見出し1つ、チェックボックス1つ、保存キー2つ

## Constitution Check

| 原則 | 設計前 | 設計後 | 根拠 |
|---|---|---|---|
| I ローカル完結 | PASS | PASS | ローカル設定だけを保存し、ファイルや登録先を操作しない |
| II 体感性能 | PASS | PASS | 追加の列挙・デコード・深い展開を行わない |
| III キーボード・アクセシビリティ | PASS | PASS | 既存の KeyViewCheckbox、明示 Tab 順、英日ラベル、手動読み上げ確認 |
| IV テスト必須 | PASS | PASS | 判断と保存の単体テスト、実際の outline 通知と再構築の結合テスト |
| V シンプルさ | PASS | PASS | 新しいサービス・汎用状態機械・依存は作らない |

憲章違反なし。通常のデコード・列挙・キャッシュ経路は変更しないため性能ベンチマークの基準値変更は不要。
復元はお気に入りの見出しだけに適用し、通常フォルダの子は追加取得しないことをレビューする。

## Project Structure

### Documentation (this feature)

```text
specs/021-favorites-startup-state/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/requirements.md
├── contracts/settings.md
├── contracts/localization.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/
├── FolzioCore/Settings/SettingsStore.swift
├── FolzioApp/Tree/DirectoryTreeViewController.swift
├── FolzioApp/Settings/SettingsWindowController.swift
└── FolzioLocalization/
    ├── TextKey.swift
    └── Resources/{en,ja}.lproj/Localizable.strings
Tests/
├── FolzioCoreTests/SettingsStoreTests.swift
├── FolzioCoreTests/Localization/SettingsTextTests.swift
└── FolzioAppTests/FavoritesExpansionTests.swift
```

**Structure Decision**: 既存の設定・outline・ローカライズの責務を拡張する。
新しい AppKit テストでは `ExternalImageDragTests.swift` の controller 生成方法を参考に、
有限のスタブ VolumeProviding と FileSystemWatching を使う。

## 実装方針

### 保存と起動時判断

- `SettingsStore` に `restoresFavoritesExpansion` と `favoritesExpanded` の独立した読み書きを追加する。
- `favoritesExpandedOnLaunch` は「復元オンかつ最後が展開」のときだけ true とする読み取り専用の判断とする。
- 新キーは `NSNumber` の型 ID が CFBoolean のときだけ Bool として採用する。
  - 既存の `storedBool` の `as? Bool` は数値の橋渡しを受け入れ得るため、新キー用に厳密な読み取りを局所的に追加する。
  - 既存キーの読み取り動作は変更しない。
- それぞれの setter は対応するキーだけを書き、古い snapshot を一括保存して別の設定を上書きしない。

### ツリーへの適用

1. `viewDidLoad` の最初の `reloadData()` 後に `favoritesExpandedOnLaunch` を1回だけ読む。
2. 必要なら `favoritesHeader` を展開し、実際の状態を `favoritesExpanded` に保存する。
3. `outlineViewItemDidExpand/Collapse` で通知対象がこの見出しのときだけ実際の状態を保存する。
   - 三角、キーボード、`focusFavoritesHeader()` の展開を同じイベント経路で扱う。
   - 通常ノードの通知ではお気に入りの保存値を変更しない。
4. `applyRoots` などの再構築中は保存を抑止し、以前の見出しの状態を復元してから実際の状態を保存する。
   - 起動時の設定を再適用しない。
   - 言語更新・登録変更・ペイン切り替えでもこの規則を維持する。
   - 既存の選択復元・複数選択・監視の更新は保つ。

### 設定 UI

- 「プレビュー」の次に「お気に入り」の見出しとチェックボックスを置く。
- 既存の区分と同じ余白・間隔を使い、幅620ptと内容に合わせる高さを維持する。
- `syncFromStore` で状態を再読込し、操作時に復元設定のキーだけを保存する。
- `updateLocalizedLabels` で見出し・タイトル・アクセシビリティラベルを更新する。
- Tab 順を `previewModePopup → 新しいチェックボックス → autoplayCheckbox` とする。
- ツリーへの設定変更通知は追加しない（現在の表示は変更せず次回起動から適用するため）。

## 作業のまとまりと検証

Core、US87 のツリー、US88 の設定 UI を順次実装する1つの小さな追加変更として、
実装・検証・コミットの単位を1つにまとめる。
`tasks.md` はこの単位の中を Setup、Foundational、各ストーリーに分けて依存順を示す。

1. 設計レビューの承認を受領し、レビュー済み文書をコミットする。
2. Core、ツリー、UI の実装と対象テストを行う。
3. `swift build` → `swift test` → `scripts/dev/check-all.sh` → `scripts/make-app.sh` の順で実行する。
4. ユーザーに新しいアプリの3ペイン、起動時4条件、英日設定・Tab・読み上げの確認を依頼する。
5. 実際の報告を quickstart に記録して実装単位をコミットする。
6. 最終の自動検証と最終ビルドの起動確認後、`speckit-converge` を実行する（最大3反復）。
7. 完了後に製品仕様の反映案・凍結注記を準備し、ユーザー承認後にコミットする。

GUI 確認・最終起動・製品仕様の承認は独立した `[MANUAL]` タスクとし、報告なしに完了にしない。
実装中の仕様文書更新は tasks のチェックと、タスクが明示した quickstart の記録・最終反映に限る。

## Complexity Tracking

憲章違反と追加の複雑さはなし。
