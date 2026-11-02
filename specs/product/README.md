# プロダクト仕様

Folzio の現在の仕様（Living spec）を領域ごとに分けたもの。
`specs/001-three-pane-media-viewer/spec.md` から移行した。FR・SC の ID は元のまま引き継いでいる。

## 領域

| ファイル | 領域 | 機能要件 |
|---|---|---|
| [overview.md](overview.md) | 概要と横断要件 | 保存と復元（1）、対応形式（2）、横断要件（3）、国際化（10）、アプリアイコン（3）、製品名と開発環境（3）、GitHub Releases での配布（9）、公開用と開発用スクリプト（4） |
| [window-layout.md](window-layout.md) | ウィンドウの構成 | 画面構成（2）、国際化の配置（1）、ツールバー（4）、ツールバーのカスタマイズ（5）、ペインの表示切り替え（7）、ショートカット一覧（7）、設定ウインドウの配置（2）、ショートカットの割り当て（14）、About ダイアログ（7） |
| [navigation-history.md](navigation-history.md) | 操作の履歴 | 戻る・進む（7） |
| [directory-tree.md](directory-tree.md) | ディレクトリツリー | ディレクトリツリー（14）、お気に入り（13） |
| [file-list.md](file-list.md) | ファイルリスト | ファイルリスト（10）、種類フィルタ（5）、ファイルリストのフォルダ（5）、クイックルックと既定のアプリで開く（7）、行頭アイコンの色（4） |
| [zip.md](zip.md) | zip ファイル | zip ファイル（8）、zip ファイルの表示制御（4） |
| [file-operations.md](file-operations.md) | ファイル操作 | ファイル操作（25） |
| [search.md](search.md) | 検索 | 検索（17） |
| [preview.md](preview.md) | プレビュー | プレビュー（8）、フルスクリーン（6） |

## 横断の契約

| ファイル | 内容 |
|---|---|
| [contracts/keyboard-and-menus.md](contracts/keyboard-and-menus.md) | キーボード操作とメニュー。ショートカットの衝突を1か所で確認するため、領域ごとには分けない |
| [contracts/settings.md](contracts/settings.md) | 永続化する設定のキー |
| [contracts/localization.md](contracts/localization.md) | 表示言語・翻訳・地域の書式 |
| [contracts/app-bundle.md](contracts/app-bundle.md) | アプリバンドルの構成とアイコン |
| [contracts/scripts.md](contracts/scripts.md) | 公開用と開発用スクリプトの配置・公開書き出し |

## ID の付け方

- 各領域のファイルにある項目は、次のラベルを持つ。1つのラベルは1つのファイルだけで定義し、ほかの領域からは ID で参照する
  - `FR-xxx`（機能要件）・`SC-xxx`（成功基準）: 新しい ID は全領域を通した最大値の次の番号にする
  - `USn-ASm`（受け入れシナリオ）・`EC-xx`（エッジケース）・`A-xx`（前提）: 001 の spec.md での位置を示す。
    新しく追加するものも同じ形式で、全領域を通した最大値の次の番号にする
- 項目を削除しても ID は再利用しない

## 更新の流れ

1. 新しい要件は、`/speckit-specify` で新しい feature ディレクトリ（`specs/NNN-xxx/`）を作って扱う。
   同じ名前の feature ブランチは、git 拡張の `before_specify` フックが今の HEAD から切る（クリーンな master から始める）。
   その spec.md には変更点（追加・変更・削除する項目）だけを書き、関係する既存の項目はこのディレクトリの ID で参照する
2. plan・tasks・実装・converge は、その feature ディレクトリで行う
3. 実装と検証が終わったら、変更点をこのディレクトリの該当する領域のファイルへ反映し、feature ディレクトリは凍結する

完了した feature ディレクトリ（`001-three-pane-media-viewer` など）の plan.md・research.md・tasks.md は、実装の経緯の記録として残す。

## feature の spec.md の書き方

- 節立ては Spec Kit のテンプレートのまま使い、各節には変更点だけを書く
- 追加する項目は新しい ID で書く。既存の項目を変える場合は、同じ ID で変更後の全文を書き、見出しに「（変更）」と付ける。
  削除する場合は ID と理由だけを書く
- 既存の項目を参照するときは、ID と領域のファイルを書く（例: `FR-084（search.md）`）
- 末尾に「## 反映先」の表を置き、追加・変更・削除する項目ごとに反映先の領域のファイルを書く

  | ID | 種別 | 反映先 |
  |---|---|---|
  | FR-099 | 追加 | search.md |
  | FR-084 | 変更 | search.md |

- 反映するときは、決定後の本文だけを領域のファイルへ移す。`## Clarifications` のセッションログは feature 側に残す
- 反映が終わったら、feature の spec.md の冒頭に、001 と同じ形式で移行済み・凍結の注記を入れる
