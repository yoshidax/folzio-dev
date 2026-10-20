# Validation: 3ペイン型メディアビューア

**Feature**: [spec.md](../spec.md) | **Plan**: [plan.md](../plan.md) | **Date**: 2026-10-20

## アプリアイコン（FR-043〜045、SC-011）

`scripts/make-app.sh` で `.build/MediaViewer.app` を生成して確認した。

| 確認項目 | 結果 | 根拠 |
|----------|------|------|
| `Contents/Resources/AppIcon.icns` が存在する | PASS | `test -f` |
| `CFBundleIconFile` が `AppIcon` | PASS | `plutil -extract CFBundleIconFile raw` |
| iconset の10スロットが揃う | PASS | `iconutil -c iconset` で全10ファイルを展開 |
| 16 / 32 / 64 / 128 / 256 / 512 / 1024 px が生成される | PASS | `sips -g pixelWidth -g pixelHeight` |
| 16px と 32px で3ペインの図案が判別できる | PASS | 生成 PNG を 256px に拡大して目視確認 |
| Finder・Dock・⌘Tab・About で同じアイコンが表示される | 未確認 | GUI での確認が必要 |
| ライト・ダークの両方で同じアイコンが表示される | 未確認 | GUI での確認が必要 |
| `swift run` では標準アイコンになる | 未確認 | バンドルがないため想定どおり |

### 再確認コマンド

```bash
scripts/make-app.sh
open .build/MediaViewer.app
```

確認ポイント:

1. Finder で `.build/MediaViewer.app` を表示し、3ペインのアイコンになっている
2. Dock と ⌘Tab に同じアイコンが出る
3. メニューの「MediaViewer について」に同じアイコンが出る
4. システム設定で外観をライト／ダークに切り替え、どちらでも同じアイコンが出る
5. 16px 相当（Finder のリスト表示や小さい Dock）でも3ペインの図案が判別できる

## フルスクリーン中の矢印キーによるファイル移動（FR-046）

2026-10-20 に `scripts/make-app.sh` で `.build/MediaViewer.app` を生成し、GUI で確認した。

| 確認項目 | 結果 | 根拠 |
|----------|------|------|
| 自動テスト（`swift test --filter MediaViewerCoreTests`） | PASS | 91 テスト成功。`FocusNavigatorTests` を含む |
| 性能テスト（`swift test --filter MediaViewerPerformanceTests`） | PASS | 6 テスト成功 |
| 外部通信の不在（`scripts/check-no-network.sh`） | PASS | `no network API references in Sources` |
| サムネイル形式で ↑↓←→ によりプレビューが切り替わる | PASS | GUI でユーザー確認 |
| 先頭・末尾で選択が循環しない | PASS | GUI でユーザー確認 |
| 解除後も移動先が選択され、必要ならスクロールする | PASS | GUI でユーザー確認 |
| リスト形式では ↑↓ のみ有効で、←→ は何もしない | PASS | GUI でユーザー確認 |
| 動画のフルスクリーンで矢印移動すると再生が停止する | PASS | GUI でユーザー確認 |
| 動画のフルスクリーンで `<` / `>` が 5 秒シークする | PASS | GUI でユーザー確認 |

### 再確認コマンド

```bash
swift build
swift test --filter MediaViewerCoreTests
swift test --filter MediaViewerPerformanceTests
scripts/check-no-network.sh
scripts/make-app.sh
open .build/MediaViewer.app
```

確認ポイントは [quickstart.md](../quickstart.md) の「US5: フルスクリーン」3〜5。

## ツリーとリスト形式の行頭アイコン（FR-047・048、SC-012・013）

2026-10-20 に `scripts/make-app.sh` で `.build/MediaViewer.app` を生成し、GUI で確認した。

| 確認項目 | 結果 | 根拠 |
|----------|------|------|
| 自動テスト（`swift test --filter MediaViewerCoreTests`） | PASS | 91 テスト成功。`ThumbnailProviderTests` の 64px 段階を含む |
| 性能テスト（`swift test --filter MediaViewerPerformanceTests`） | PASS | アプリ終了後に再実行して 6 テスト成功 |
| 外部通信の不在（`scripts/check-no-network.sh`） | PASS | `no network API references in Sources` |
| ホーム・ボリューム・通常フォルダの3種類のツリーアイコンが判別できる | PASS | GUI でユーザー確認（SC-013） |
| リスト形式のファイル名の先頭に縮小画像が出る（画像・動画） | PASS | GUI でユーザー確認 |
| 生成中・失敗時は形式別の SF Symbol にフォールバックする | PASS | `broken/` を含む GUI 確認 |
| 名前変更中もテキストがアイコンの右にあり、操作を妨げない | PASS | GUI でユーザー確認 |
| `huge/` のスクロール・選択がアイコン生成を待たない | PASS | GUI でユーザー確認（SC-012）。100ms 以上の停止は観測されず |
| リスト⇔サムネイル形式の切替でサムネイルが欠けない | PASS | GUI でユーザー確認（サイズ単位キャンセルの回帰確認） |

### 再確認コマンド

```bash
swift build
swift test --filter MediaViewerCoreTests
swift test --filter MediaViewerPerformanceTests
scripts/check-no-network.sh
scripts/make-app.sh
open .build/MediaViewer.app
```

確認ポイントは [quickstart.md](../quickstart.md) の「US1」2 と「US3」5〜7。

## 表示を切り替えられるツールバー（FR-049〜052）

2026-10-20 に macOS 26.6.2 で `scripts/make-app.sh` により `.build/MediaViewer.app` を生成し、GUI で確認した。

| 確認項目 | 結果 | 根拠 |
|----------|------|------|
| 自動テスト（`swift test`） | PASS | Core 96 テスト、性能 6 テスト成功（Phase 16 コミット時）。`SettingsStoreTests`・`FileListChromeTests` を含む |
| 外部通信の不在（`scripts/check-no-network.sh`） | PASS | `no network API references in Sources` |
| 保存値がない初回起動ではツールバーが出ず、画面が追加前と同じ | PASS | GUI でユーザー確認（quickstart 1、FR-049）。R18 の代替案（`window.toolbar = nil`）は不要だった |
| 「表示」メニューの「ツールバーを表示／隠す」と ⇧⌘T で切り替わり、下部サイズバーが連動する | PASS | GUI でユーザー確認（quickstart 2・3、FR-050・052） |
| 表示形式の2択ボタンとメニュー・⌘1 / ⌘2 の状態が一致し、リスト形式でスライダーが無効になる | PASS | GUI でユーザー確認（quickstart 4・5、FR-051） |
| スライダーと ⌘+ / ⌘- が連動し、横スクロールが出ない | PASS | GUI でユーザー確認（quickstart 6） |
| フルスクリーン中はツールバーが自動で隠れ、解除後に元の表示に戻る | PASS | GUI でユーザー確認（quickstart 7） |
| 表示状態が再起動後に復元される | PASS | GUI でユーザー確認（quickstart 8、FR-003） |

## ツリーのダブルクリック開閉と開閉の三角（FR-053〜055）

2026-10-20 に macOS 26.6.2 で `scripts/make-app.sh` により `.build/MediaViewer.app` を生成し、GUI で確認した。

| 確認項目 | 結果 | 根拠 |
|----------|------|------|
| 自動テスト（`swift test`） | PASS | Core 117 テスト、性能 7 テスト成功。`FolderDisclosureTests`・`SubfolderProbeTests`・`DirectoryListerTests` の `hasSubfolders(in:)` を含む |
| 外部通信の不在（`scripts/check-no-network.sh`） | PASS | `no network API references in Sources` |
| サブフォルダのない 10,000 ファイルのフォルダの `hasSubfolders(in:)`（基準 0.2 秒以内） | PASS | 実測 5〜9ms（6 回）。`FileManager.enumerator` 版は 0.05〜0.21 秒で基準を超えることがあったため `readdir` 版に変更（research.md R19） |
| 三角は `has-sub` にだけ付き、`hidden-only`・`package-only`・`empty`・`denied` には付かない。行の位置が揃う | PASS | GUI でユーザー確認（quickstart 1、FR-054・055） |
| 行（名前・アイコン）のダブルクリックで選択とトグルが行われる | PASS | GUI でユーザー確認（quickstart 2、FR-053） |
| 三角のないフォルダはダブルクリック・→ キーで展開しない | PASS | GUI でユーザー確認（quickstart 3） |
| 三角の素早い 2 回クリックで余計な開閉が起きない | PASS | GUI でユーザー確認（quickstart 4）。T130 の予備策は不要だった |
| 外部でのサブフォルダの追加・削除に三角が追従する | PASS | GUI でユーザー確認（quickstart 5、FR-042） |
| 展開直後もツリーの上下移動が止まらず、`huge` に三角が付かない | PASS | GUI でユーザー確認（quickstart 6） |
| 回帰（← / →、⌥→ / ⌥←、ドロップ、右クリックメニュー、前回フォルダの表示、行頭アイコン） | PASS | GUI でユーザー確認（quickstart 7） |

## 画像・動画の種類フィルタ（FR-056〜060）

2026-10-20 に macOS 26.6.2 で `scripts/make-app.sh` により `.build/MediaViewer.app` を生成し、GUI で確認した。

| 確認項目 | 結果 | 根拠 |
|----------|------|------|
| 自動テスト（`swift test`） | PASS | Core 140 テスト、性能 8 テスト成功。`MediaTypeFilterTests`・`BrowserModelTests`・`BrowserModelVideoTests` の種類フィルタのケースを含む。負荷平均 70〜90 の間は既存の性能テストとサムネイル生成のテストが時間超過で失敗したが、負荷が下がった後の再実行ではすべて成功した |
| 外部通信の不在（`scripts/check-no-network.sh`） | PASS | `no network API references in Sources` |
| 10,000 件への種類フィルタの適用（基準 0.05 秒以内） | PASS | `PerformanceBaselineTests` が成功（テストは実測値を出力しないため、値は基準内とだけ記録する） |
| ツールバーの並び（種類 → 表示形式 → サイズ）と、既定で両方オフ | PASS | GUI でユーザー確認（quickstart 1、FR-057） |
| 画像のみ・動画のみ・両方オンの絞り込みと、ボタン・メニューのチェックの一致 | PASS | GUI でユーザー確認（quickstart 2・3、FR-056・058）。`selectAny` の押された状態は判別でき、R20 の代替案は不要だった |
| ツールバー非表示での ⇧⌘I / ⇧⌘M | PASS | GUI でユーザー確認（quickstart 4）。キーはアプリに届いた |
| 隠れた動画の停止と選択の整理、戻しても選択が戻らない | PASS | GUI でユーザー確認（quickstart 5・6、FR-059） |
| 絞り込みで0件のときのメッセージと、元々空のフォルダのメッセージの区別 | PASS | GUI でユーザー確認（quickstart 7、FR-060） |
| フォルダ移動後の保持と、フルスクリーン中の移動が表示中の一覧に限られる | PASS | GUI でユーザー確認（quickstart 8・9） |
| 再起動で両方オフに戻る | PASS | GUI でユーザー確認（quickstart 10、FR-056） |
| `huge` での切り替え時の表示停止（基準 100ms 未満） | PASS | GUI でユーザー確認（quickstart 11、目視で停止なし）。画面収録・Instruments による計測値は未取得 |
| 回帰（⇧⌘T、⌘1 / ⌘2、⌘+ / ⌘-、⌃⌘F / Esc） | PASS | GUI でユーザー確認 |

## お気に入り（FR-061〜067）

2026-10-20 に macOS 26.6.2 で `scripts/make-app.sh` により `.build/MediaViewer.app` を生成し、GUI で確認した。

| 確認項目 | 結果 | 根拠 |
|----------|------|------|
| 自動テスト（`swift test`） | PASS | Core 168 テスト、性能 8 テスト成功。`FavoriteFoldersTests`・`FavoriteCommandsTests`・`FavoriteProbeTests`・`SettingsStoreTests` の favorites のケースを含む。並列ビルド中の1回だけ「huge(10,000) の列挙と並べ替えが 1 秒以内」が 5.1 秒で失敗したが、負荷が下がった後の再実行ではすべて成功した |
| 外部通信の不在（`scripts/check-no-network.sh`） | PASS | `no network API references in Sources` |
| 起動時に最上部へ「お気に入り」（スター・開閉の三角・折りたたみ）が出る | PASS | GUI でユーザー確認（quickstart 1、FR-061） |
| 右クリックと ⌃⌘T による登録、項目に三角がない | PASS | GUI でユーザー確認（quickstart 2・3、FR-062・063）。⌃⌘T はアプリに届いた |
| 項目の選択で一覧が切り替わり、実際の階層は動かない | PASS | GUI でユーザー確認（quickstart 4、FR-063） |
| ⇧⌘F で見出しを選び、一覧・プレビュー・再生中の動画は変わらない | PASS | GUI でユーザー確認（quickstart 5・6、FR-065）。⇧⌘F はアプリに届いた |
| 右クリックメニュー（項目は削除だけ、見出しは出ない）と、確認モーダル付きの削除（右クリック・⌘⌫） | PASS | GUI でユーザー確認（quickstart 7〜11、FR-064）。実際のフォルダはゴミ箱に入らない |
| メニューの項目名の切り替え（「お気に入りから削除」⇄「ゴミ箱に入れる」） | PASS | GUI でユーザー確認（quickstart 9・18） |
| 再起動後の復元（登録順） | PASS | GUI でユーザー確認（quickstart 12、FR-066） |
| 見つからない項目の淡色表示と「フォルダが見つかりません」、戻すと通常表示 | PASS | GUI でユーザー確認（quickstart 13〜16、FR-067） |
| 設定ウインドウの文言が切れない | PASS | GUI でユーザー確認 |
| 存在の確認中のツリーの停止（基準 100ms 未満） | PASS | ユーザーの判断で目視確認とした。画面収録・Instruments による計測値は未取得 |
| 回帰（右クリックした行への「ここにペースト」「Finder に表示」、ドロップ、⌃⌘F / Esc、ファイルリストの ⌘Delete） | PASS | GUI でユーザー確認。ファイルリストの ⌘Delete は下記の不具合を修正した後に確認した |

### 検証中に見つけた不具合（Phase 6 から存在）

- 症状: ファイルリストの「ゴミ箱に入れる」（⌘Delete・右クリック）で、確認モーダルの「実行」を押してもゴミ箱に入らず、エラーも出ない。
  名前の変更も同じ原因で反映されなかった
- 原因: `FileOperationCoordinator` は `trash(_:)`・`rename(_:to:)` で `resolution: .abort`（同名があれば上書きしない）を渡すが、
  `FileOperationService.execute(_:resolution:)` が先頭で `.abort` のとき空の結果（成功 0・失敗 0）を返していた。既存テストはゴミ箱・
  名前の変更を `.replace` で呼んでいたため検出できなかった
- 修正: `execute` の早期 return を削除し、`.abort` は内側の処理（衝突した項目だけ中止）に任せた。再現テスト 4 件
  （ゴミ箱・名前の変更の同名なし／あり・コピーの衝突、すべて `.abort`）を追加し、修正前に失敗・修正後に成功することを確認した。
  不具合の挙動を固定していた `abortsWithoutChanges` は置き換えた
- 確認: 修正後の `.app` で、ゴミ箱（⌘Delete・右クリック）・名前の変更・キャンセルをユーザーが確認した

## 未実施の検証

- T079: Accessibility Inspector によるラベル確認
- T080: US1〜US6、キーボードのみの操作、異常系の手動シナリオ
