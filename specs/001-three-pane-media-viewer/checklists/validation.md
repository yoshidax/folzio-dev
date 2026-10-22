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

## ファイルリストのフォルダ・`..`・ツリーの同期・フォルダの操作（FR-076〜078、Phase 22・23）

2026-10-21 に macOS 26.6.2 で `scripts/make-app.sh` により `.build/MediaViewer.app` を生成し、GUI で確認した。

| 確認項目 | 結果 | 根拠 |
|----------|------|------|
| 自動テスト（`swift test`） | PASS | Core 338 テスト、性能 10 テスト成功。`FolderNavigationTests`・`ParentLinkTests`・`BrowserModelFolderTests`（新規）と、`DirectoryListerTests`・`ListItemCommandsTests`・`NameValidationTests`・`FileOperationServiceTests`・`SortingTests`・`MediaTypeFilterTests`・`FocusNavigatorTests` の追加ケースを含む |
| T216: 10,000 ファイルと 1,000 サブフォルダの列挙（基準 1 秒） | PASS | 実測 0.40 秒（ロードアベレージ約 8）。ロードアベレージ約 20 の間は 0.75〜2.5 秒で、既存の 24MP デコード・zip の索引・10,000 件の列挙のテストも同時に基準を超えたため、負荷が下がってから再計測した。フォルダなしの 10,000 件と比べて増加は見られない。基準は計画時の 0.5 秒からユーザーの判断で 1 秒（SC-003 の列挙と同じ）に変更した |
| 外部通信の不在（`scripts/check-no-network.sh`） | PASS | `no network API references in Sources` |
| フォルダの行・`..`・ダブルクリック / ⌘↓ / ⌘↑ での移動とツリーの同期、ルートでの `..` の扱い | PASS | GUI でユーザー確認（quickstart「ファイルリストのフォルダ」、FR-076〜078） |
| フォルダの操作（コピー・名前の変更・ゴミ箱・移動）とツリーへの反映 | PASS | GUI でユーザー確認（quickstart「US4」7〜9、FR-018・076） |

### 検証中に見つけた不具合（Phase 22 の実装）

- 症状: 一覧でフォルダへ入る・戻ると、キーボードフォーカスが外れ、マウスでクリックし直すまで矢印キーが効かない
- 原因: 読み込み中（`.loading`）は一覧のビューを隠すため、AppKit がフォーカスを次のキービュー（プレビューの `ImagePreviewView`）へ移していた。
  zip の中の移動は読み込みが同期的に終わり一覧が隠れないため、起きていなかった。firstResponder の変化を標準エラーへ出す一時的な調査用コードで
  呼び出し元（`updateModeVisibility()` の `isHidden`）を特定した（調査用コードは削除済み）
- 修正: `FileListViewController.updateModeVisibility()` で、一覧を隠したことでフォーカスが移った先を覚え、一覧を出し直したときにフォーカスが
  まだそこにあればファイルリストへ戻す。読み込み中にユーザーが別のペインへ移った場合は戻さない。UI の配線のため自動テストは追加せず、
  修正後の `.app` でユーザーが確認した

## zip ファイルの中の閲覧（FR-068〜071・073〜075、SC-015、Phase 20）

2026-10-21 に macOS 26.6.2 で `scripts/make-app.sh` により `.build/MediaViewer.app` を生成し、GUI で確認した。

| 確認項目 | 結果 | 根拠 |
|----------|------|------|
| 自動テスト（`swift test`） | PASS | Core 350 テスト、性能 12 テスト成功（下記の不具合の修正後） |
| 性能テスト（quickstart「性能の検証」の基準内） | PASS | 10,000 項目の zip の `ZipArchiveReader.open` + `items(in:)` 0.113 秒（基準 0.5 秒）。開いた後の `items(in:)` 0.0006ms（基準 10ms、下記の修正で追加）。10,000 ファイルと 1,000 サブフォルダの列挙 0.36 秒 |
| 外部通信の不在（`scripts/check-no-network.sh`） | PASS | `no network API references in Sources` |
| SC-015: `huge.zip` を開いた直後からのツリーの ↑↓・一覧のスクロールで、100ms 以上の停止 0 回、最初の項目 1 秒以内 | PASS | 下記の修正後に、リスト形式とサムネイル形式で 2 回ずつ計測した。最初の項目まで 96.91〜116.38 ms、zip を開いている間の 100ms 以上の停止 0 件。計測方法: 一時的な os_signpost `ArchiveOpenToFirstItem`（zip の行を開いてから中の一覧の最初の行が描かれるまで。計測後に削除）と、Instruments の Hangs（しきい値 100ms）を `xcrun xctrace record --template Logging --instrument Hangs --recording-options <hangsThreshold 100 の JSON>` で記録し、`xctrace export` の `OSSignpostIntervals`・`potential-hangs` から読んだ。同じ記録の起動中（`LaunchToList` の途中）に 116.53 ms の停止が 1 件あったが、zip の操作とは関係ない（SC-015 の対象外） |
| quickstart「zip ファイル」1〜7・10〜16 | PASS | GUI でユーザー確認 |
| ⌘↓ / ⌘↑ がアプリに届くこと | PASS | GUI でユーザー確認 |
| 回帰（通常のフォルダのリスト形式・サムネイル形式の矢印キー・⇧ + 矢印・⌘A・Return の名前の変更・⌘C / ⌘V / ⌥⌘V / ⌘D / ⌘Delete・ツリーへのドラッグ・右クリックメニュー、種類フィルタ、フルスクリーンの矢印移動、行頭アイコン、ツリーの操作） | PASS | GUI でユーザー確認 |
| 回帰（下記の修正 2: フォルダ・zip の中を移った後の ⌘1 / ⌘2 の切り替えでの一覧・選択行・スクロール位置、切り替え後の縮小画像、サムネイル形式で変えた並べ替えのリスト形式の列見出しへの反映） | PASS | GUI でユーザー確認 |

### 検証中に見つけた不具合（Phase 20 の実装）

- 症状: `huge.zip`（10,000 項目）を開くと、メインスレッドが 1 回あたり 120〜170ms 続けて処理し、Hangs で 226.29 ms と 144.78 ms の停止が
  記録された（SC-015 の 100ms 以上の停止 0 回を満たさない）。最初の項目までは 130〜316 ms で基準内だった
- 原因: Time Profiler（`xctrace symbolicate` で dSYM を当てて集計）で、zip を開いている間のメインスレッドの内訳を調べた
  - `ArchiveIndex.items(in:)` が約 50ms。MainActor の `BrowserModel.showArchiveLevel` から呼ばれ、10,000 項目の `MediaFile` と
    `ArchiveURL`（`ArchiveURL.encodePath`）をその場で作っていた
  - 表示していない形式のビュー（リスト形式のときの `ThumbnailModeView`）も、一覧が変わるたびに再読み込みしてセルを作っていた（約 16〜24ms）
- 修正:
  1. `ArchiveIndex` が、ディレクトリごとの行を索引の作成時（`ZipArchiveReader.open` のバックグラウンド）に作っておき、`items(in:)` はそれを
     返すだけにした。公開 API は変えていない。性能テスト「10,000 項目の zip を開いた後の items(in:) が 10ms 以内」を先に追加し、修正前に
     失敗（88ms）・修正後に成功することを確認した
  2. `ListModeView`・`ThumbnailModeView` は、非表示のときは行の再読み込みと選択の反映を `viewDidUnhide` まで遅らせる。リスト形式の
     並べ替えの列見出しとメニューは非表示でも従来どおり反映する。UI の配線のため自動テストは追加せず、修正後の `.app` での再計測と
     ユーザーの回帰確認で確かめた

## zip の中の動画のストリーミング再生（FR-071・072、SC-014、Phase 21）

2026-10-21 に macOS 26.6.2 で `scripts/make-app.sh` により `.build/MediaViewer.app` を生成し、GUI で確認した。

| 確認項目 | 結果 | 根拠 |
|----------|------|------|
| 自動テスト（`swift test`） | PASS | Core 350 テスト、性能 11 テスト成功。`ArchiveEntryStreamTests`・`ArchiveAssetLoaderTests`（新規）と `ThumbnailProviderTests` の zip の中の mp4 のケースを含む |
| T202: 展開後 1GB の deflate 項目の `ArchiveEntryStream` での読み出し（基準 増加 128MB 以下） | PASS | 最大増加 34MB、読み出し 2,072 回で 0.43 秒 |
| 外部通信の不在（`scripts/check-no-network.sh`） | PASS | `no network API references in Sources` |
| zip の処理に書き込み API がないこと（`scripts/check-no-archive-writes.sh`） | PASS | `no write API references in Sources/MediaViewerCore/Archive` |
| 無圧縮で格納した 1080p 動画の再生開始（基準 1 秒以内、SC-014） | PASS | `videos-stored.zip` の `video-1080p.mp4` で `VideoPlaybackStart` 49.77 ms（同じ記録の `LaunchToList` は 465.65 ms）。この環境の xctrace 27.1 には quickstart の `Points of Interest` テンプレートがないため、`xcrun xctrace record --template Logging` で記録し、`xctrace export` の `OSSignpostIntervals` から読んだ |
| quickstart「zip ファイル」8・9（ループ再生・シーク・音量・Space、`..` で停止、deflate の mp4 / mov の再生・シーク） | PASS | GUI でユーザー確認 |
| 一時ファイルを作らないこと（FR-072） | PASS | 再生中の `sudo fs_usage -w -f filesys MediaViewer` を zip の中の動画名・`.mp4`・`.mov`・`/T/`・`/tmp/` で絞り込み、該当なし（ユーザー確認） |
| zip の中の動画の代表フレーム（サムネイル形式・リスト形式の行頭アイコン） | PASS | GUI でユーザー確認 |
| SC-014: `zip-big/` の約 1.1GB の動画を 1 分以上操作したときのメモリ（基準 増加 128MB 以下） | PASS | `footprint` の `phys_footprint`。`big-video-stored.zip`: 選択前 51MB → 操作後 85MB（増加 34MB、ピーク 125MB で選択前比 74MB）。`big-video-deflated.zip`: 選択前 41MB → 操作後 122MB（増加 81MB、ピーク 147MB で選択前比 106MB）。増加の主な内訳は `MALLOC_SMALL`（チャンクキャッシュ 32MB を含む。deflate では 49MB が reclaimable）と AVFoundation の `CoreMedia HTTP cache`（約 30MB、両方式で同程度） |
| 回帰（通常のフォルダの動画の自動再生・ループ・シーク・Space・フルスクリーン再生、リスト形式・サムネイル形式の代表フレーム） | PASS | GUI でユーザー確認 |

## ツリーのフォルダをゴミ箱に入れる（FR-064・079、Phase 24）

2026-10-22 に macOS 26.6.2 で `scripts/make-app.sh` により `.build/MediaViewer.app` を生成し、GUI で確認した。

| 確認項目 | 結果 | 根拠 |
|----------|------|------|
| 自動テスト（`swift test`） | PASS | 365 テスト（37 スイート）成功。性能テスト 12 テストを含む。`FavoriteCommandsTests`（`trashTarget`・`contextMenu(for:roots:)`）、`FolderNavigationTests`（`folderToShow(afterTrashing:showing:roots:)`）、`BrowserModelFolderTests`（`leaveTrashedFolders`）の追加ケースを含む |
| 外部通信の不在（`scripts/check-no-network.sh`） | PASS | `no network API references in Sources` |
| quickstart「ツリーのフォルダのゴミ箱（FR-079）」1〜3（⌘⌫ の確認モーダル・キャンセル・確定後に親を選択して表示・プレビューが空・フォーカスがツリーに残る・Finder の「戻す」で復元） | PASS | GUI でユーザー確認 |
| 同 4（表示中のフォルダの祖先を右クリックメニューの先頭の「ゴミ箱に入れる」で削除、動画の停止、親の表示へ移る） | PASS | GUI でユーザー確認 |
| 同 5（無関係なフォルダの削除で選択と一覧が変わらない） | PASS | GUI でユーザー確認 |
| 同 6（ホーム・ボリューム・見出しに「ゴミ箱に入れる」がなく ⌘⌫ も無効、お気に入りの項目の ⌘⌫ は「お気に入りから削除」） | PASS | GUI でユーザー確認 |
| 同 7（お気に入りに登録したフォルダをツリーでゴミ箱に入れると、実際のフォルダは削除され、お気に入りの項目は淡色で残る。FR-067） | PASS | GUI でユーザー確認 |
| 同 8（確認 OFF で確認なしにゴミ箱へ） | PASS | GUI でユーザー確認 |
| US1 の受け入れシナリオ 24 | PASS | 上記 1〜6 で確認 |
| 回帰（アプリの外で表示中のフォルダを `rm -rf` したとき、一覧が親に移りツリーの選択が隣の行へずれない。T238 の `reloadChildren` の変更） | PASS | GUI でユーザー確認 |
| 回帰（ファイルリストからのファイル・フォルダのゴミ箱、お気に入りの削除、ツリーの同期） | PASS | GUI でユーザー確認 |

## 未実施の検証

- T079: Accessibility Inspector によるラベル確認
- T080: US1〜US6、キーボードのみの操作、異常系の手動シナリオ
- T085: アプリアイコンの GUI 確認（Finder・Dock・⌘Tab・About・ライト／ダークと `swift run` の標準アイコン）。
  コマンドラインの確認は「アプリアイコン（FR-043〜045、SC-011）」に記録済み
- T088: quickstart「プレビューのフィット（FR-028）」の手動確認と結果の記録
- T093: quickstart「サムネイル形式のキーボード追従スクロール（FR-017）」の手動確認と結果の記録
