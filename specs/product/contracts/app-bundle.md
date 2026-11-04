# Contract: アプリバンドルの構成とアイコン

配布用 `.app` の外形と、アイコンの生成・同梱に関する契約。仕様は [overview.md](../overview.md) の FR-043〜045、
SC-011、前提を参照。

製品とSwift Packageの名称は `Folzio`。ターゲットは `FolzioCore`、`FolzioLocalization`、`FolzioApp`、
`FolzioCoreTests`、`FolzioPerformanceTests` とし、`FixtureKit` と既存の補助ツールの名称は維持する（FR-166・168）。

## バンドル構成

`scripts/make-app.sh` は `.build/Folzio.app` を次の構成で作る。

```text
Folzio.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/
    │   └── Folzio                   # swift build -c release の実行ファイル
    └── Resources/
        ├── AppIcon.icns             # scripts/make-icon.sh の生成物
        ├── en.lproj/
        │   ├── Localizable.strings
        │   └── Localizable.stringsdict
        └── ja.lproj/
            ├── Localizable.strings
            └── Localizable.stringsdict
```

翻訳リソースは `Sources/FolzioLocalization/Resources/{ja,en}.lproj/` を管理元とし、Swift Package
のリソースバンドルから `.app` 本体へコピーする。両言語の `Localizable.strings` と `Localizable.stringsdict`
が揃わなければ `.app` を残さず失敗する。コピー後に署名する。`.app`
をビルドディレクトリの外へ移しても両言語を表示できる（FR-155）。表示言語はアプリ設定で選び、OS が提供する文言は OS
に従う（EC-111）。言語の追加時はリソース、アプリの選択肢、`CFBundleLocalizations` を更新する（FR-156）。

## Info.plist の必須キー

| キー | 値 | 用途 |
|------|----|------|
| `CFBundleDevelopmentRegion` | `en` | 開発言語と翻訳欠落時のフォールバック |
| `CFBundleLocalizations` | `ja`, `en` | 対応言語 |
| `CFBundleExecutable` | `Folzio` | 実行ファイル名 |
| `CFBundleIdentifier` | `local.folzio.Folzio` | アプリの同一性 |
| `CFBundleName` | `Folzio` | 表示名 |
| `CFBundleIconFile` | `AppIcon` | バンドルアイコン（拡張子なし） |
| `CFBundlePackageType` | `APPL` | アプリケーションバンドル |
| `CFBundleShortVersionString` | 開発時の既定値 `1.0.0`、配布時は指定したバージョン | バージョン（About ダイアログが表示する） |
| `CFBundleVersion` | 開発時の既定値 `1`、配布時は指定した数字 | ビルド番号 |
| `LSMinimumSystemVersion` | `15.0` | 対象 OS |
| `NSHighResolutionCapable` | `true` | Retina 対応 |
| `NSPrincipalClass` | `NSApplication` | AppKit アプリ |

配布時は公開用コミットから arm64 を明示してビルドし、アプリのバージョンを Release のタグと一致させる（FR-170・171）。
署名は ad hoc とする（FR-172）。

About ダイアログ（FR-238〜245（window-layout.md））は、実行中のアプリの `CFBundleShortVersionString`
を表示する。値がない、空、または Info.plist を持たない起動（`swift run`）では、バージョン行を表示しない（FR-241）。
`CFBundleVersion`（ビルド番号）は表示しない。開発時の既定値は `scripts/make-app.sh` の `FOLZIO_VERSION`
の既定（FR-246（overview.md））。

`CFBundleAllowMixedLocalizations` は設定しない。OS の部品がアプリの設定言語と一致することは保証しない。

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

- `iconutil -c icns` は上記スロットが揃わないと失敗する。
  - `scripts/make-icon.sh` は生成後に `sips -g pixelWidth -g pixelHeight` で各ファイルの寸法を検証する
- 生成物は `.build/AppIcon.iconset/` と `.build/AppIcon.icns` に置き、リポジトリにはコミットしない
- 途中で失敗した場合、`scripts/make-app.sh` は既存の `.app` を残さず非ゼロで終了する（汎用アイコンのまま出荷しない:
  spec エッジケース）

## 受け入れ確認

| 確認 | 期待結果 |
|------|----------|
| `test -f Folzio.app/Contents/Resources/AppIcon.icns` | 存在する |
| `plutil -extract CFBundleIconFile raw Folzio.app/Contents/Info.plist` | `AppIcon` |
| `iconutil -c iconset Folzio.app/Contents/Resources/AppIcon.icns -o /tmp/AppIcon.iconset` | 全スロットが展開できる |
| Finder で `.app` を表示 | 汎用アイコンではなく3ペインのアイコン |
| Dock / ⌘Tab / About | 同じアイコン |

書類アイコン、メニューバー常駐アイコン、ウィンドウタイトルバーのアイコンは対象外（FR-045）。
外観バリエーション（ライト/ダーク/ティント）は持たない（macOS 15 対象のため）。

### 翻訳リソースの確認

- `en.lproj`・`ja.lproj` に `Localizable.strings` と `Localizable.stringsdict` があり、Info.plist の開発言語が `en`、
  対応言語が `ja`・`en` である
- `codesign --verify --deep --strict` が成功し、ビルドディレクトリの外にコピーした `.app`
  でも両言語を表示できる（SC-066）
- アプリの設定で表示言語を切り替えると、再起動せずアプリ管理の文言が切り替わる
