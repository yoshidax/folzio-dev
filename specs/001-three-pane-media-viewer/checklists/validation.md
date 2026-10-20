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

## 未実施の検証

- T079: Accessibility Inspector によるラベル確認
- T080: US1〜US6、キーボードのみの操作、異常系の手動シナリオ
