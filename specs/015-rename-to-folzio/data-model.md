# Data Model: 設定と名前

## 設定ドメイン

| 起動方法 | 移行元 | 移行先 |
|---|---|---|
| `.app` | `local.my-img-viewer.MediaViewer` | `local.folzio.Folzio` |
| `swift run` | `MediaViewerApp` | `FolzioApp` |

両者は独立して移行する。設定値は `specs/product/contracts/settings.md` のキーと型を保持する。ウインドウ位置の `NSWindow Frame MainWindow` と3ペイン幅の `NSSplitView Subview Frames MainSplit` も保持する。コピーする値はplistとして扱い、パスを自動書き換えしない。

## 移行状態

`未実行` → `旧ドメインの確認` → `移行先が未作成か確認` → `旧ドメインのバックアップ` → `新ドメインへ復元` → `結果確認`。旧ドメインの不存在、移行先の存在、バックアップ／復元失敗はいずれも移行完了とせず、旧ドメインを残す。部分的な復元が発生した場合は既存バックアップを保持し、手動復旧の手順を表示する。

## 作業場所

開発側は `~/projects/my_img_viewer` → `~/projects/folzio`、公開側は `~/projects/my_img_viewer-oss` → `~/projects/folzio-oss`。どちらも既存Git履歴・Git管理外ファイルを保持して移動する。移動先が存在する場合は中止する。
