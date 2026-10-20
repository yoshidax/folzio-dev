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

## 未実施の検証

- T079: Accessibility Inspector によるラベル確認
- T080: US1〜US6、キーボードのみの操作、異常系の手動シナリオ
