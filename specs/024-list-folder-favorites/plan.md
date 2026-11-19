# Implementation Plan: フォルダの右クリックメニューの整理

**Branch**: `codex/024-list-folder-favorites` | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)
**Input**: [TAK-113](https://linear.app/takyoshida/issue/TAK-113)

## Summary

ツリーと一覧の通常フォルダの操作を共通化する。フォルダの外部アプリ起動項目を一覧から外し、
ツリーへコピー・複製、一覧へお気に入り登録を加える。項目メニューの貼り付け先は対象のフォルダとする。
ナビゲーションは表示場所に固有の項目として残す。通常フォルダの新規作成は背景・メニューバー・キーへ集約する案とする。

## Technical Context

**Language/Version**: Swift 6 / Swift Package
**Primary Dependencies**: 既存の AppKit・Foundation・FolzioCore・FolzioLocalization
**Storage**: 既存の SettingsStore・FavoriteFolders。新しい保存形式なし。
**Testing**: Swift Testing / FolzioCoreTests / FolzioAppTests
**Target Platform**: macOS 15 以降
**Project Type**: desktop-app
**Performance Goals**: メニューの決定はメモリ上の対象情報だけで行う。
**Constraints**: ファイル操作・列挙・デコードを UI スレッドで行わず、通信と依存を増やさない。
**Scale/Scope**: 通常フォルダの単一・複数対象、ツリー・リスト・サムネイル・検索結果・絞り込み。

## Constitution Check

| 原則 | 設計前 | 設計後の根拠 |
|---|---|---|
| I ローカル完結 | 適合 | 既存の明示操作・確認・取り消し可能性・衝突解決を共用 |
| II 体感性能 | 適合 | 対象計算はメモリ上、実操作は既存の非同期 coordinator |
| III キーボード・支援機能 | 適合 | コピー・複製の既存キーをツリーにも接続、標準メニューを使用 |
| IV テスト | 適合 | 対象計算に加えて一時フォルダ内で実操作・誤行先防止を検証 |
| V シンプルさ | 適合 | 小さな共通方針と既存の coordinator、汎用基盤は作らない |

調査前と設計後で違反なし。閲覧・画像表示の経路と性能基準を変えない。
コピー・複製の大量データ処理は既存の非同期サービスへ委譲する。

## Project Structure

### Documentation (this feature)

```text
specs/024-list-folder-favorites/
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
Sources/FolzioCore/Model/FolderContextMenu.swift       # 新規、共通順序・対象・貼り付け先
Sources/FolzioCore/Model/FavoriteCommands.swift
Sources/FolzioCore/Model/TreeBatchTargets.swift
Sources/FolzioCore/Model/PaneLayout.swift
Sources/FolzioApp/Tree/DirectoryTreeViewController.swift
Sources/FolzioApp/FileList/FileContextMenu.swift
Sources/FolzioApp/FileList/FileListViewController.swift
Sources/FolzioApp/App/MainSplitViewController.swift
Tests/FolzioCoreTests/FolderContextMenuTests.swift    # 新規
Tests/FolzioCoreTests/FavoriteCommandsTests.swift
Tests/FolzioCoreTests/TreeBatchTargetsTests.swift
Tests/FolzioCoreTests/PaneLayoutTests.swift
Tests/FolzioAppTests/FolderContextMenuTests.swift     # 新規
Tests/FolzioAppTests/FileListContextClickTests.swift
```

**Structure Decision**: 判断は Core、描画・入力・クリップボード・既存サービスへの接続は App。

## Phase 0: Research

[research.md](research.md) の R7〜R11 が目的変更後の判断を示す。
R1〜R6 と変更前の比較表は当初の設計・調査の経緯として残す。
別の feature やブランチを作らず、未承認の同じ設計を改訂する。

## Phase 1: Design

1. Core の FolderContextMenu に共通操作の列挙・順序と、対象の役割・件数による可否を置く。
   FileList の MediaFile と TreeItemRole から、実フォルダの URL・ルートかどうかを受け取る。
   ディスクへの問い合わせは行わず、ルートの識別は既存の navigation roots と同じ情報で判断する。
   単一先を要する操作は「`..` を除外する前の対象全体が1件」であることを確認する。
   入力元・対象・表示フォルダ・検索／zip 状態から貼り付け先 URL? を返す純粋な判断も Core に置く。
2. TreeBatchTargets に通常フォルダ全体のコピー・複製・Finder 対象を返す経路を設ける。
   trashTarget を転用してコピー可能範囲を狭めず、ゴミ箱・名前変更の既存のルート保護を保つ。
   FavoriteCommands の通常フォルダメニューを共通順序へ接続する。
3. DirectoryTreeViewController に copy・duplicate とその validateMenuItem を実装する。
   copy は Pasteboard に全対象の URL、duplicate は既存 coordinator.duplicate に全対象を渡す。
   ⌘C・⌘D・メニューバーは現在のツリー選択、右クリックは記録した対象全体を使う。
   Finder に表示も通常フォルダの複数対象へ広げる。お気に入りの別メニューは保つ。
4. FileContextMenu は対象がすべて実フォルダなら共通操作の列から項目を組み立て、先頭に既存ナビゲーションを付ける。
   実フォルダを含む混在対象では open・openWith を隠し、項目へのペーストを無効にする。
   ルートを含む対象のゴミ箱・名前変更の保護は、混在メニューの場合も共通の判断で適用する。
   フォルダからメディア、複数、背景へ切り替えるたびに項目・区切り・文言・状態を再計算する。
   背景メニューとメディア／zip ファイルだけの項目メニューは既存の構成を使う。
5. FileListViewController のペースト先を入力元で分ける。
   項目メニューの実フォルダ1件はその URL、背景・メニューバー・キーは model.listing.folder とする。
   対象消失・複数・混在・zip 内のフォルダの場合に表示中のフォルダへ戻さない。
   検索結果でも実フォルダの項目メニューなら許可し、背景・キーでは既存の禁止を保つ。
   既存の clipboard availability・coordinator.paste を共用し、実行時も再判定する。
6. お気に入りへの登録は元の設計を共用する。
   純粋な対象判定 → URL によるツリーの既存保存入口へ接続する。
   一覧のフォーカスは一覧対象、ツリー・プレビューはツリー対象。
   一覧のみ表示でも登録できるよう PaneCommands を対象ペインで判断する。
   名前編集・ToolbarSearchField の文字入力では登録を無効にし、候補なしでも他ペインへ戻さない。
7. 共通メニューは既存の翻訳キーと MenuShortcutApplier を使う。
   新規フォルダの行メニューの削除、ルート保護の一覧への適用も同じ対象方針で決定する。
8. 既存の確認・衝突解決・受信画像保存・失敗表示を保つ。
   権限・存在の検査や実コピーは Core の既存サービスで非同期に行う。

契約は [contracts/keyboard-and-menus.md](contracts/keyboard-and-menus.md)、
データは [data-model.md](data-model.md)、検証は [quickstart.md](quickstart.md)。

## Validation & Delivery

設計承認・文書コミット後、関連する3ストーリーを1つの実装 Phase で仕上げる。
共通メニューの接続を完成させた上で `swift build` → `swift test` → `scripts/dev/check-all.sh` → `scripts/make-app.sh`。
保守者の GUI・言語・VoiceOver の確認後に Phase をコミットする。
最終の同じ自動検証・起動確認を経て converge を行い、追加があれば最大3反復まで実装・検証する。
その後に製品仕様・契約の反映案と凍結注記を準備し、別の承認後にコミットする。

## Complexity Tracking

共通の操作列は両ビューの再乖離を防ぐために必要。外部依存・保存変更・汎用メニューフレームワークは不要。
