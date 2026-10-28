# Contract（差分）: アプリバンドルの翻訳リソース

**Feature**: `011-app-localization` | **基準**: `specs/product/contracts/app-bundle.md` | **Research**: [research.md](../research.md) R1・R3

実装と検証の後、`specs/product/contracts/app-bundle.md` へ反映する差分。アイコンの契約は変えない。

## バンドル構成（追加部分）

```text
MediaViewer.app/
└── Contents/
    ├── Info.plist                       # CFBundleDevelopmentRegion・CFBundleLocalizations を追加
    ├── MacOS/
    │   └── MediaViewer
    └── Resources/
        ├── AppIcon.icns
        ├── en.lproj/                    # 開発言語（最終フォールバック）
        │   ├── Localizable.strings
        │   └── Localizable.stringsdict  # 件数の文（R1 の検証で生成物の名前を確定する）
        └── ja.lproj/
            ├── Localizable.strings
            └── Localizable.stringsdict
```

- `*.lproj` は `Sources/MediaViewerLocalization/Resources/{ja,en}.lproj/` の `.strings` と `.stringsdict` を管理元とし、`swift build -c release` が作る
  `my_img_viewer_MediaViewerLocalization.bundle/Contents/Resources/` の lproj をそのままコピーしたもの
- lproj は本体（`Bundle.main`）に置く。アプリ管理の表示言語はアプリ設定で選ぶ。OS が提供する部品の言語は OS が決める（EC-111）
- `.app` の中の参照はすべて相対位置で決まる。ビルドディレクトリを移動・削除しても翻訳を表示できる（FR-155）
- 対応言語の追加は、翻訳リソースとアプリの選択肢、`CFBundleLocalizations` に言語を足すことで行う（FR-156）

## Info.plist の追加キー

| キー | 値 | 用途 |
|------|----|------|
| `CFBundleDevelopmentRegion` | `en` | 開発言語。対応言語に一致しないときの最終フォールバック |
| `CFBundleLocalizations` | `ja`, `en` | 対応言語を OS へ示す |

`CFBundleAllowMixedLocalizations` は設定しない。OS の部品がアプリの設定言語と一致することは保証しない。

## make-app.sh の失敗条件（追加）

- リソースバンドルの `ja.lproj`・`en.lproj` のどちらかに、`Localizable.strings` または複数形の表（`Localizable.stringsdict`、または R1 の試作（T005・T006）で
  控えた同等の表）が無いとき、`.app` を残さず非ゼロで終了する。複数形の表が欠けると、件数の文は日本語も含めて内部キーで表示される（フォールバックが効かない）ため
- コピーの後、コード署名（`codesign --force --sign -`）は lproj を含めて行う

## 受け入れ確認（追加）

| 確認 | 期待結果 |
|------|----------|
| `ls MediaViewer.app/Contents/Resources/ja.lproj MediaViewer.app/Contents/Resources/en.lproj` | 両方に `Localizable.strings` と複数形の表（R1 で控えた名前）がある |
| `plutil -extract CFBundleDevelopmentRegion raw MediaViewer.app/Contents/Info.plist` | `en` |
| `plutil -extract CFBundleLocalizations json -o - MediaViewer.app/Contents/Info.plist` | `["ja","en"]` |
| `codesign --verify --deep --strict MediaViewer.app` | 成功する |
| `.app` を一時フォルダへコピーし、`.build` を一時的に別名にして起動（日本語・英語） | どちらも翻訳された文言で表示され、内部キーが出ない（SC-066） |
| アプリの設定で言語を切り替える | 再起動せずアプリ管理の文言が切り替わる |
