# Implementation Plan: 複数の検索起点

**Branch**: `claude/wizardly-volta-ie6ncn` | **Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/TAK-104-multi-root-search/spec.md`

## Summary

検索のモーダルの起点欄を、1〜10 行の「起点の行」の一覧に替える。各行は従来の起点欄・「選択…」に「削除」を加えたもので、
一覧の下に「起点を追加」を置く。「検索」では、空白だけの行を除くすべての行を従来の規則で解釈・検証し、1つでも無効なら
その行の番号と理由を示す。有効なら、同じフォルダと、別の起点の検索で辿られる配下の起点を除いて整理し、上の起点から1つずつ
順に辿って1つの検索結果にまとめる。検索バーは「{最初の起点} ほか {n} か所」とツールチップの全起点の絶対パスで、「場所」列は
項目を含む起点から始まるパスで示す。起点の名前の変更・削除・変更通知の規則は起点ごとに適用する。あわせて、検索キーワード欄の
直下にワイルドカードの説明を表示し、キーワード欄のアクセシビリティの説明にも加える。

判断（起点の整理・行の状態・検索バーの文字列の材料・場所の計算・順に辿る制御）は `FolzioCore` に置き、Core のテストで確かめる。
`FolzioApp` は行のビューの生成・並び・フォーカス・文言の表示だけを担う。

## Technical Context

**Language/Version**: Swift 6.0（`swiftLanguageModes: [.v6]`）

**Primary Dependencies**: AppKit、Foundation。外部依存を追加しない

**Storage**: なし（検索条件と起点の行は保存しない。contracts/settings.md は変えない）

**Testing**: Swift Testing（`FolzioCoreTests`・`FolzioAppTests`・`FolzioPerformanceTests`）。Cloud では CI で実行する

**Target Platform**: macOS 15 以降、Apple silicon

**Project Type**: デスクトップアプリ（Swift Package）

**Performance Goals**: 3つの起点に分けた合計 10,000 ファイルの検索を 3 秒以内に終え（SC-249）、検索中に UI を 100ms 以上止めない。
起点の整理（FR-437）は起点の数（最大 10）の2乗の比較と、配下の起点ごとに間の階層の属性の読み取りだけで、UI のスレッドの外で行う

**Constraints**: ディレクトリの列挙・属性の読み取り・起点の検証を UI のスレッドで行わない（AGENTS.md・憲章 原則 II）。
`NSOpenPanel` の構成（FR-141）と、行ごとの GUI 選択と直接入力の区別（FR-081）を保つ

**Scale/Scope**: 新しいファイル 約 4（Core 3・App 1）と各テスト、既存のファイルの変更 約 10（下の「ソースの変更」）

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判定 | 根拠 |
|---|---|---|
| I ローカル完結・プライバシー | 適合 | 通信を加えない。ファイルを変更しない |
| II 体感パフォーマンス | 適合 | 下記 |
| III キーボード・アクセシビリティ | 適合 | 下記 |
| IV テスト必須 | 適合 | 整理・行の状態・場所・検索バー・順の列挙・起点ごとの追随を Core のテストで確かめる。異常系（無効な行・空の行・消えた起点）を含む |
| V シンプルさ | 適合 | 外部依存なし。設定を加えない。並行の列挙・起点の履歴・起点ごとの結果の分割表示は作らない（A-263・A-266） |

**表の詳細**

- **II 体感パフォーマンス**（根拠）: 起点の検証・整理・列挙はすべて既存と同じく `Task.detached` で行う。起点を順に辿るので、
  合計の読み取り量は単一の起点の検索と同じで、既存の性能基準（SC-016・SC-054）と同じ枠（3 秒）に収める（research.md R3）。
  性能テストを1件加え、PR に計測結果を記載する。
- **III キーボード・アクセシビリティ**（根拠）: 追加・削除・選択のボタンはすべて Tab で到達でき（FR-081（変更））、行の番号を含む
  アクセシビリティのラベルを持つ（FR-435）。ワイルドカードの説明はキーワード欄の説明（ヘルプ）として読み上げる（FR-441）。
  新しいショートカットは加えない（A-86（search.md）と同じく Tab・Space を入口にする）。
- Phase 1 の後の再評価: data-model.md・contracts/ の設計は上の判定を変えない。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-104-multi-root-search/
├── spec.md
├── plan.md              # このファイル
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   └── search-sheet.md  # Phase 1（検索シートの構成・Tab の順・文言の追加）
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
Sources/FolzioCore/Search/
├── SearchRootInput.swift        # 変更: SearchPanelInputState を行の並びに広げる（data-model.md 1・2）
├── SearchRootList.swift         # 新規: 行の検証（最初の無効な行）と起点の整理（FR-436・FR-437）
├── SearchListing.swift          # 変更: root → roots。場所の計算と検索バーの材料（FR-084・FR-439）
├── SearchRemovalScope.swift     # 変更: 項目を含む起点で止める（FR-440）
└── SearchRootPlan.swift         # 新規: 順に辿る起点の待ち行列と、未着手の起点の名前の変更への追随（FR-438・FR-440）
Sources/FolzioCore/Browser/
└── BrowserModel.swift           # 変更: startSearch(_:roots:)、順の列挙、起点ごとの名前の変更・削除
Sources/FolzioLocalization/
├── TextKey.swift                # 変更: 追加の文言のキー
└── Resources/…/Localizable      # 変更: 日英の文言（contracts/search-sheet.md）
Sources/FolzioApp/Search/
├── SearchPanelController.swift  # 変更: 起点の行の一覧・追加・削除・行ごとの選択・説明の表示
└── SearchRootRowView.swift      # 新規: 1行分のビュー（起点欄・選択…・削除）
Sources/FolzioApp/App/MainSplitViewController.swift      # 変更: onSearch の起点を [URL] に
Sources/FolzioApp/FileList/FileListViewController.swift  # 変更: 検索バーの起点の表示とツールチップ
Sources/FolzioApp/Tree/DirectoryTreeViewController.swift # 変更: 変更通知の監視をすべての起点の配下に
Tests/FolzioCoreTests/           # SearchRootListTests・SearchPanelInputStateTests（拡張）・SearchListingTests・
                                 # BrowserModelSearchTests（拡張）・SearchRemovalScopeTests（拡張）
Tests/FolzioAppTests/            # SearchPanelRowsTests（行の追加・削除・Tab の順・フォーカス）
Tests/FolzioPerformanceTests/PerformanceBaselineTests.swift # SC-249
```

**Structure Decision**: 既存の Swift Package の構成（`FolzioCore`・`FolzioApp`・`FolzioLocalization`）のまま、検索の領域のファイルに
変更を閉じる。`FileNameSearcher` と `SearchRequest` は1つの起点の列挙のまま変えず、複数の起点は `BrowserModel` が1つずつ
順に `FileNameSearcher` を呼ぶ（research.md R3）。既存の名前の変更の台帳（`SearchRenameLedger`）は列挙ごとの記録を持つため、
起点ごとの列挙をそのまま登録できる。

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| 起点の待ち行列（`SearchRootPlan`）を加える | 起点を順に辿り（A-266）、まだ辿っていない起点の名前の変更を、追加の列挙を起こさずに反映する必要がある（research.md R4） | すべての起点を同時に列挙すれば待ち行列は要らないが、同じディスクで読み取りが競合し、SC-249 の時間が悪くなり得る。未着手の起点に既存の「配下の名前の変更で新しい場所を追加で辿る」規則を当てると、同じ場所を2回辿って結果が重複する |
