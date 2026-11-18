# Implementation Plan: ファイルリストの削除後の選択

**Branch**: `023-select-after-trash` | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

**Input**: [TAK-109](https://linear.app/takyoshida/issue/TAK-109)

## Summary

削除前の表示順と選択を FolzioCore に保存し、成功した元 URL と更新後の一覧から次の選択を決める。
FolzioApp の FileOperationCoordinator はファイルリスト起点のゴミ箱操作だけでこの処理を使う。
元の選択が残れば保持し、すべて消えた場合は最も下の対象より後の残存候補を選ぶ。
後続候補がなければ選択なしにする。利用者が途中で表示条件・選択を変えた操作には適用しない。
選択なしの ↑・↓ は通常のファイルリストだけで末尾・先頭を選ぶ。

## Technical Context

**Language/Version**: Swift 6（既存 Package.swift）
**Primary Dependencies**: Foundation / Observation（Core）、AppKit / Quartz（App）、既存の Swift Testing
**Storage**: 操作中だけの値。永続化の追加なし。
**Testing**: FolzioCoreTests と FolzioAppTests、既存の Fake と一時ディレクトリを用いる。
**Target Platform**: macOS 15 以降
**Project Type**: desktop-app / Swift Package
**Performance Goals**: 1万行でも追加の選択判断を O(n + m) に保ち、ファイルごとの全一覧再走査をしない。
**Constraints**: オフライン、UI スレッドでのファイル I/O 禁止、新規依存なし、GUI は保守者が確認する。
**Scale/Scope**: 通常・検索一覧 × リスト・サムネイル。ツリーやプレビューのキー移動は対象外。

## Constitution Check

| 原則 | 設計前 | 設計後の根拠 |
|---|---|---|
| I ローカル・安全性 | PASS | 既存のゴミ箱経由・確認・失敗表示を維持。通信なし |
| II 体感性能 | PASS | 既存の非同期列挙・操作を再利用。URL 集合と表示順の線形走査 |
| III キーボード・アクセシビリティ | PASS | 既存キー・選択 API を使用。フォーカス先ペインは維持 |
| IV 自動テスト | PASS | 純粋判断・BrowserModel・coordinator・キー入力をテストし GUI も手動確認 |
| V シンプルさ | PASS | 既存の選択・プレビューを再利用。設定・汎用ジョブ管理を追加しない |

Phase 0 の調査後と Phase 1 の設計後に再評価した。憲章違反と未決事項はない。

## Project Structure

### Documentation (this feature)

```text
specs/023-select-after-trash/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/keyboard-and-menus.md
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/FolzioCore/Model/PostTrashSelection.swift             # 新規の小さな判断用の値型
Sources/FolzioCore/Browser/BrowserModel.swift                 # snapshot、世代、適用、preview
Sources/FolzioCore/Layout/FocusNavigator.swift                # 通常一覧の選択なしの入口判断
Sources/FolzioApp/Operations/FileOperationCoordinator.swift   # 削除開始・結果・再読込との接続
Sources/FolzioApp/FileList/ListModeView.swift                 # 空選択の上下キーの接続
Sources/FolzioApp/FileList/ThumbnailModeView.swift            # 同上と選択先の可視化
Tests/FolzioCoreTests/PostTrashSelectionTests.swift           # 新規
Tests/FolzioCoreTests/BrowserModelTrashSelectionTests.swift   # 新規
Tests/FolzioCoreTests/BrowserModelSearchTests.swift
Tests/FolzioCoreTests/FocusNavigatorTests.swift
Tests/FolzioAppTests/FileListTrashSelectionTests.swift        # 新規
Tests/FolzioAppTests/FileListEmptySelectionNavigationTests.swift # 新規
Tests/FolzioAppTests/FileListContextClickTests.swift
```

**Structure Decision**: 判断は AppKit を import しない FolzioCore、イベント・操作の接続は FolzioApp に置く。
既存テストの fixture / fake を優先して再利用し、必要な fake は当該テストファイル内に置く。

## Phase 0: Research

[research.md](research.md) に現状・判断・代替案を記録した。
既存コードの調査で選択制限、検索除去、成功元 URL、矢印キーの経路を特定した。
新しい技術や依存はなく、外部調査と別エージェントは不要。同じセッションで順次進める。

## Phase 1: Design

### 削除前の記録と判断

[data-model.md](data-model.md) の PostTrashSelection を操作開始時、最初の await より前に取得する。
origin が fileList で、すべての操作対象が選択済みの場合だけ記録を作る。
`..` が元の選択に含まれる場合は、削除後も残る元の選択として扱う。
表示順・元選択・元フォーカス・対象・操作の有効性を値として保持する。

後続候補は削除前の表示順の対象最大位置より後から探す。
成功 URL はゴミ箱内の結果 URL ではなく元の URL を使う。
失敗元 URL を対象から引く既存処理を使い、全件失敗やキャンセルでは自動選択を適用しない。
更新後の表示 URL 集合との積で消えた候補・検索の子孫・フィルタで隠れた行を除く。
元の選択が残れば優先し、元フォーカスが消えたときだけ表示順で最後の残存選択へ移す。

### 非同期処理中の意図の保護

BrowserModel の既存 navigationGeneration に加え、利用者の選択・表示条件の変更を示す世代を使う。
select / sortOrder / 種類フィルタ / 名前フィルタ / zip 表示の実際の変更で世代を進める。
検索の開始・終了・フォルダ移動は既存の世代と合わせて無効化する。
同じ状態へ戻しても世代は戻さず、古い snapshot が復活しないようにする。
FSEvents・検索結果追加・削除による選択の制限はこの利用者の世代を進めない。
これにより監視の通知が操作完了より先に選択を外しても次の候補を選べる。

### 完了処理との接続

FileOperationCoordinator.trash は snapshot を確保して既存の確認・サービス実行を行う。
履歴通知、親へ退避する leaveTrashedFolders、通常 reload / 検索 prune を維持する。
検索では成功元 URL と配下を didMoveSearchItems で除外して遅れて届く検索結果も抑止する。
親への退避が起きた場合や一覧更新に失敗した場合は snapshot を適用しない。
一覧更新を await した後に世代を再検査し、条件が合えば BrowserModel.select で選択・プレビューを同期する。
全件失敗と選択外の右クリックでは select を再発行せず、動画の再開・巻き戻しも避ける。

### UI と矢印キー

ListModeView.update はすでにフォーカス行へ scrollRowToVisible するため再利用する。
ThumbnailModeView は削除完了で変わったフォーカスも必要最小限可視化する。
常時のレイアウト変更では追従せず、既存の矢印移動・名前編集の可視化を壊さない。

通常一覧で選択・フォーカスがともに空の場合のみ、修飾キーなし ↑・↓ を Core の入口判断に渡す。
FocusNavigator の full screen / hidden list 用 isNavigable 経路の入口規則は変えない。
Shift・左右キーと選択中の移動は既存の経路を維持する。
リストの標準 NSTableView がすでに満たす場合も、実イベントの回帰テストで保証する。
詳細は [contracts/keyboard-and-menus.md](contracts/keyboard-and-menus.md) に記載する。

### 検証と製品仕様への反映

各実装 Phase は `swift build` → `swift test` → `scripts/dev/check-all.sh` →
`scripts/make-app.sh` の後、保守者の `open .build/Folzio.app` と報告を待ち、Phase 単位でコミットする。
性能は既存基準を変更せず、選択判断の1万行・5000選択の確認と既存の性能検証を記録する。
手動確認は独立した [MANUAL] タスクとし、確認前のコミットやチェックはしない。
最終の自動検証・起動スモーク後に converge を実行し、必要なら最大3回の実装・検証ループを行う。
製品仕様は実装・検証後にだけ反映し、反映先表と契約差分を提示して保守者の承認後にコミットする。

## Complexity Tracking

憲章違反なし。操作ごとの値型と世代以外に新しい抽象化は設けない。
既存の全 reload に自動選択を組み込む案は、ツリー・外部削除や別の操作へ影響するため採用しない。
