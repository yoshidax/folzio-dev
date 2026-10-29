# Contract: Folzioアプリバンドル

`scripts/make-app.sh` は `.build/Folzio.app` を作成し、`Contents/MacOS/Folzio`、両言語の `Localizable.strings` と `Localizable.stringsdict`、`AppIcon.icns` を含める。`CFBundleExecutable` と `CFBundleName` は `Folzio`、`CFBundleIdentifier` は `local.folzio.Folzio`。リソースを配置した後に署名し、翻訳資源が欠ける場合は不完全なアプリを残さず失敗する。既存の FR-155・FR-156 を維持する。

パッケージ名は `Folzio`、Swiftターゲットは `FolzioCore`、`FolzioLocalization`、`FolzioApp`、`FolzioCoreTests`、`FolzioPerformanceTests` とし、`FixtureKit` と既存の補助ツールの名称は維持する。
