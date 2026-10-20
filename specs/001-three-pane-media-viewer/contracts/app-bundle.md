# Contract: アプリバンドルの構成とアイコン

配布用 `.app` の外形と、アイコンの生成・同梱に関する契約。仕様は
[spec.md](../spec.md) の FR-043〜045、SC-011、前提条件を参照。

## バンドル構成

`scripts/make-app.sh` は `.build/MediaViewer.app` を次の構成で作る。

```text
MediaViewer.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/
    │   └── MediaViewer              # swift build -c release の実行ファイル
    └── Resources/
        └── AppIcon.icns             # scripts/make-icon.sh の生成物
```

## Info.plist の必須キー

| キー | 値 | 用途 |
|------|----|------|
| `CFBundleExecutable` | `MediaViewer` | 実行ファイル名 |
| `CFBundleIdentifier` | `local.my-img-viewer.MediaViewer` | アプリの同一性 |
| `CFBundleName` | `MediaViewer` | 表示名 |
| `CFBundleIconFile` | `AppIcon` | バンドルアイコン（拡張子なし） |
| `CFBundlePackageType` | `APPL` | アプリケーションバンドル |
| `CFBundleShortVersionString` | `0.1.0` | バージョン |
| `CFBundleVersion` | `1` | ビルド番号 |
| `LSMinimumSystemVersion` | `15.0` | 対象 OS |
| `NSHighResolutionCapable` | `true` | Retina 対応 |
| `NSPrincipalClass` | `NSApplication` | AppKit アプリ |

## アイコン生成の契約

- 入力: `Sources/make-icon/` の描画コードのみ。外部画像・フォント・ネットワークを使わない
- 出力: 次の 10 スロットを持つ iconset。各 PNG は該当するピクセルサイズで描画する

| ファイル | ピクセルサイズ |
|----------|----------------|
| `icon_16x16.png` | 16 |
| `icon_16x16@2x.png` | 32 |
| `icon_32x32.png` | 32 |
| `icon_32x32@2x.png` | 64 |
| `icon_128x128.png` | 128 |
| `icon_128x128@2x.png` | 256 |
| `icon_256x256.png` | 256 |
| `icon_256x256@2x.png` | 512 |
| `icon_512x512.png` | 512 |
| `icon_512x512@2x.png` | 1024 |

- `iconutil -c icns` は上記スロットが揃わないと失敗する。`scripts/make-icon.sh` は生成後に
  `sips -g pixelWidth -g pixelHeight` で各ファイルの寸法を検証する
- 生成物は `.build/AppIcon.iconset/` と `.build/AppIcon.icns` に置き、リポジトリにはコミットしない
- 途中で失敗した場合、`scripts/make-app.sh` は既存の `.app` を残さず非ゼロで終了する
  （汎用アイコンのまま出荷しない: spec エッジケース）

## 受け入れ確認

| 確認 | 期待結果 |
|------|----------|
| `test -f MediaViewer.app/Contents/Resources/AppIcon.icns` | 存在する |
| `plutil -extract CFBundleIconFile raw MediaViewer.app/Contents/Info.plist` | `AppIcon` |
| `iconutil -c iconset MediaViewer.app/Contents/Resources/AppIcon.icns -o /tmp/AppIcon.iconset` | 全スロットが展開できる |
| Finder で `.app` を表示 | 汎用アイコンではなく3ペインのアイコン |
| Dock / ⌘Tab / About | 同じアイコン |

書類アイコン、メニューバー常駐アイコン、ウィンドウタイトルバーのアイコンは対象外（FR-045）。
外観バリエーション（ライト/ダーク/ティント）は持たない（macOS 15 対象のため）。
