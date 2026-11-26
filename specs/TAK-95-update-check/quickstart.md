# Quickstart: アップデートの確認（TAK-95）の検証

## 自動の検査

| 実行する者 | コマンド | 確かめること |
|---|---|---|
| Cloud（Agent） | `scripts/dev/check-all.sh` | ネットワーク API の検査（SC-246）、README の同期、コメントの英語 |
| Cloud（Agent） | `python3 -m unittest scripts/dev/tests/test_check_no_network.py` | 許可の追加と拒否の回帰 |
| CI | `swift build`、`swift test` | Core の版の解析・比較・応答の評価、メニュー項目の位置と有効の条件 |

## 保守者のローカルでの確認（GUI）

前提: macOS 15 以降、Apple silicon。公開用リポジトリ `yoshidax/folzio` の Releases で最新の公開版を確かめておく。
以下は最新の公開版が v1.7.0 の場合の例で、`1.6.0` にはそれより古い版、`1.7.0` には最新の公開版を指定する。

```bash
FOLZIO_VERSION=1.6.0 scripts/make-app.sh
```

```bash
open .build/Folzio.app
```

1. 3 ペインが表示される（起動スモーク）。
2. アプリメニューに「Folzio について」「アップデートを確認…」「─」「設定…」の順で並ぶ。
3. 「アップデートを確認…」を選ぶと、「新しいバージョンの Folzio があります」と v1.7.0・1.6.0 が表示される（US96-AS1）。
4. 「ダウンロードページを開く」で、既定のブラウザに `https://github.com/yoshidax/folzio/releases/tag/v1.7.0` が開く（US96-AS2）。
5. もう一度選び、Esc で何も開かずに閉じる（US96-AS3）。
6. `FOLZIO_VERSION=1.7.0 scripts/make-app.sh` で作り直して開き、「Folzio は最新です」と表示される（US97-AS1）。
7. Wi-Fi を切って選び、15 秒以内に「アップデートを確認できませんでした」が出て、その間もファイルリストを操作できる（US97-AS2・AS3）。
8. スライドショーの実行中・全画面の表示中に、メニューバーから選んで結果のダイアログが出て、スライドショーが止まらず、
   閉じた後も全画面のまま（EC-295）。
9. 設定で表示言語を日本語・英語に切り替え、メニュー項目とダイアログの文言が切り替わる。
10. `swift run FolzioApp` で起動したとき（Info.plist なし）は、「アップデートを確認…」が淡色で選べず、同意のダイアログも出ない
    （FR-422・EC-299）。

### 起動時の自動の確認（US98）

`.app` の設定のドメインは `local.folzio.Folzio`（`scripts/make-app.sh` の `CFBundleIdentifier`）。古い版（例: 1.6.0）のアプリで、
アプリを終了した状態から始める。3つのキーは次のコマンドで消す（キーがなければ `defaults` がエラーを出すが、問題ない）。

```bash
for key in updates.automaticCheck updates.lastAutomaticCheck updates.lastNotifiedVersion; do defaults delete local.folzio.Folzio "$key"; done
```

`updates.lastAutomaticCheck` だけを消すとき:

```bash
defaults delete local.folzio.Folzio updates.lastAutomaticCheck
```

11. 起動すると、メインウィンドウの表示の後に「アップデートを自動で確認しますか？」が出る（US98-AS1）。
12. 「確認しない」を選んで終了・再起動すると、もう尋ねられない。設定ウインドウの「アップデート」のチェックは外れている（US98-AS3）。
13. 設定でチェックを入れ、`updates.lastAutomaticCheck` を消して再起動すると、新しい版のダイアログが出る（US98-AS4・US98-AS7）。
14. もう一度、`updates.lastAutomaticCheck` を消して再起動すると、同じ版のダイアログは出ない（US98-AS5）。
15. `updates.lastAutomaticCheck` を消さずにすぐ再起動すると、通信が起きない（24 時間以内。任意で `nettop` で確かめる）。
16. 設定のキーをすべて消し、同意のダイアログで「自動で確認する」を選ぶと、そのまま新しい版のダイアログが出る（US98-AS2）。
17. 最新の版のアプリ、またはネットワークを切った状態で、`updates.lastAutomaticCheck` を消して起動すると、何も表示されない
    （US98-AS6）。

## 通信が起きないことの確認（SC-244）

任意。自動の確認を「確認しない」にした状態で、`nettop -p Folzio` またはファイアウォールのログで、起動から終了まで
（「アップデートを確認…」を選ばない）外部への接続がないことを確かめる。
