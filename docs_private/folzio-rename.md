# Folzioへの改名: 設定移行とディレクトリ移動

この手順は公開前の開発用環境だけに適用する。アプリ本体には旧設定の自動移行を組み込まない。

## 旧設定を引き継ぐ

MediaViewerとFolzioの両方、および `swift run` で起動したアプリを終了する。Folzioを初めて起動する前に、引き継ぐ起動方法に対応するコマンドを実行する。2つの設定は別々である。

```bash
cd /Users/igachan/projects/my_img_viewer
scripts/migrate-folzio-settings.sh app
scripts/migrate-folzio-settings.sh swift-run
```

旧 `.app` の `local.my-img-viewer.MediaViewer` は `local.folzio.Folzio` に、旧 `swift run` の `MediaViewerApp` は `FolzioApp` に移される。旧ドメインは残る。アプリ設定、ウインドウの位置、3ペインの幅を含む旧ドメインをコピーし、保存パスは変えない。

バックアップは `~/Library/Application Support/Folzio/SettingsBackups/` 内の毎回異なる非公開ディレクトリに保存され、実行時に表示される。移行元が存在しない場合は変更しない。移行先が存在する場合は上書きせず停止する。エラー時は表示されたバックアップを保持し、移行先を確認する。復元途中に失敗した場合は、既存の移行先を消す・上書きする前にその内容をバックアップし、必要な復旧方法を判断する。

移行後、両起動方法で言語、お気に入り、表示設定、ウインドウ位置、ペイン幅を確認する。Macのファイルアクセス許可を再度求められたら必要な範囲で許可する。旧プロジェクトディレクトリ内を指すお気に入りや前回のフォルダは、移動後に手動で確認し、必要なものだけ変更する。

## ディレクトリを移動する

featureの実装・検証、仕様反映と凍結が終わってから実施する。すべてのFolzio・MediaViewer、IDE、開発エージェントと両リポジトリを使う端末セッションを終了する。`git worktree list` で追加worktreeの有無を確認し、存在する場合は移動前にその参照を整理する。

移動先が存在しないことを次の手順で確かめて移動する。公開側のGit管理外 `.vscode/` もディレクトリとともに移動する。

```bash
cd /Users/igachan/projects
if [ -e folzio ] || [ -L folzio ] || [ -e folzio-oss ] || [ -L folzio-oss ]; then
  echo '移動先が存在します。移動を中止します。'
else
  mv my_img_viewer folzio && mv my_img_viewer-oss folzio-oss
fi
```

途中で失敗した場合は両ディレクトリの現在位置を確認し、残った方だけ移す。新しい `~/projects/folzio/folzio.code-workspace` をIDEで開き、Codexの書き込み対象も新ディレクトリで開始し直す。必要ならビルド生成物を再生成して、`swift build`、`swift test`、3つの検査スクリプト、`scripts/make-app.sh` とユーザーによるGUI起動を確認する。公開側のGit履歴と `.vscode/` の保持も確認する。

実施日・OS・対象・確認結果はこの文書の末尾に追記する。凍結済みfeatureには追記しない。
