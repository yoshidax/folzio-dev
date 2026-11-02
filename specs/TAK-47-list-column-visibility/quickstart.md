# Quickstart: リスト形式の列の表示・非表示

## 自動検査（Cloud）
```bash
scripts/check-no-network.sh
scripts/check-readme-sync.sh master
scripts/dev/check-english-comments.sh
scripts/dev/check-skill-sync.sh
```
`swift build` / `swift test` は CI（macOS）で実行する。

## 自動テスト（CI）
- 列の設定: 既定、未知の列・壊れた値の無視、保存と復元（SettingsStore）
- 並べ替え: サイズ・変更日の昇順・降順、フォルダは 0 バイト扱い（昇順で先頭・降順で末尾）、変更日 nil は末尾、同値は名前の自然順（Sorting）
- 取得: `DirectoryLister` が変更日を返す、zip の項目の更新日時（ArchiveIndex）
- 書式: サイズ文字列（フォルダは `--`、0 バイトのファイル）

## 保守者の手動確認（ローカル）
```bash
scripts/make-app.sh
open .build/Folzio.app
```
1. リスト形式で列見出しを右クリック → 作成日・種類・サイズ・変更日の4項目（ファイル名はない）、既定は作成日・種類にチェック。すべて外してもファイル名の列が残る (US48-AS1/3/4)
2. 「サイズ」「変更日」を選ぶ → すぐ列が現れ、再度選ぶと消える (US48-AS2)
3. サイズ・変更日の見出しをクリック → 昇順ではフォルダが先頭、降順では末尾 (US49-AS3)
4. 「表示 > 並べ替え」にサイズ・変更日がある。サイズで並べ替え中にサイズを隠すと、ファイル名の並べ替えに切り替わる。その方向は再起動後も復元される (US49-AS4/5)
5. zip の中を表示 → フォルダのサイズは `--`、変更日は entry の日時 (US49-AS1/2)
6. アプリを再起動 → 列の状態が復元される (US49-AS6)
7. 検索結果で場所列が従来どおり自動表示される。行の右クリックのメニューは変わらない (US48-AS5)
8. 表示言語を切り替える → 列名とポップアップの文言が追随する
