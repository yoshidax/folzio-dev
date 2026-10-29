# Quickstart: Folzioへの改名の確認

## 前提

- macOS 15以降、Swift 6、対象の旧アプリを終了済み。作業中のfeatureは `015-rename-to-folzio`。
- 設定移行は実行前に [移行契約](contracts/migration.md) と `docs_private/` の手順を確認する。新ドメインが存在する場合は上書きせず停止する。実設定の操作はユーザーが明示的に行う。
- 自動検証の設定サンプルは独立したテスト用ドメインを使う。GUIをエージェントが起動しない。

## 自動検証

リポジトリのルートから順番に実行する。

```bash
swift build
swift test
scripts/check-no-network.sh
scripts/check-readme-sync.sh master
scripts/check-english-comments.sh
python3 -m unittest discover -s scripts/tests -v
scripts/make-app.sh
```

`plutil` でBundle ID・名前・実行ファイル名を確認し、両言語の `Localizable.strings` と `Localizable.stringsdict`、アイコン、署名を検査する。移行の新規・衝突・旧設定なし・失敗・再実行、および公開先の `.vscode/` 保護は独立した一時データで検証する。

一時領域に、`.git`・`.build`・`.swiftpm` を除いた作業ツリーを `folzio` の名でコピーし、その中で `swift build` と `swift test` を実行してパス依存を検出する。実リポジトリと公開先は操作しない。

## GUI確認（ユーザー）

設定を引き継ぐ場合は、Folzioの初回起動より先に移行手順を実行する。ユーザーが次を実行する。

```bash
open .build/Folzio.app
```

3ペイン、アプリ名、日英切り替え、画像・動画・zip内の表示とファイル整理、設定変更と再起動後の復元を確認する。移行した場合はお気に入り・言語・表示設定・ペイン幅・ウインドウ位置も確認する。アプリを終了し、`swift run FolzioApp` で開発実行を起動して、別ドメインの設定移行と復元も確認する。確認日・macOS・起動方法と対象・結果を `specs/015-rename-to-folzio/checklists/validation.md` に記録する。

## 仕様反映後: 実ディレクトリの移動（ユーザー）

作業中のアプリ・IDE・端末セッションを閉じ、移動先2つが存在しないことを確認する。存在する場合は停止する。必要な設定と、公開側の未追跡 `.vscode/` を含むGit管理外ファイルを保護する。親ディレクトリで以下を実行する。

```bash
cd /Users/igachan/projects
if [ -e folzio ] || [ -L folzio ] || [ -e folzio-oss ] || [ -L folzio-oss ]; then
  echo '移動先が存在します。移動を中止します。'
else
  mv my_img_viewer folzio && mv my_img_viewer-oss folzio-oss
fi
```

途中で移動が失敗した場合は、両ディレクトリの現在位置を確認し、残りだけを移動する。新しい `folzio` をIDE・Codexで開き直し、必要に応じてビルド生成物を再生成して、上の自動検証とGUI確認を再実行する。`folzio-oss` のGit履歴と `.vscode/` が維持されていることを確認する。結果はfeature凍結後の運用記録 `docs_private/` に記録する。旧フォルダ名を含むお気に入りや前回フォルダは手動で確認し、必要なものだけ修正する。
