# Research: GitHub Releases での配布

- 配布先: GitHub Release はタグと添付ファイルを管理できる。`--verify-tag` はタグの自動作成を防ぎ、`--draft` は公開を保留する。参照: https://cli.github.com/manual/gh_release_create
- CPU: Intel 実機がなく検証できないため arm64 のみ。Universal は対象外。
- 署名: Developer ID と公証は使わず ad hoc 署名。Gatekeeper の案内を添える。参照: https://support.apple.com/en-us/102445
- ZIP: `ditto` を使い `.app` の構造を保存し、実際のアーカイブを展開して検証する。
- 公開: 公開用リポジトリのコミットと push はユーザーが行う。タグもユーザーが push する。固定コミットから一時環境でビルドし、ビルド中の作業ツリーの差分を混入させない。
