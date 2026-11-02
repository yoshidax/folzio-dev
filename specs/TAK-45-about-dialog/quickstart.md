# Validation Guide: TAK-45

実装後の検証手順。実行結果と未確認事項は第 5 章に記録する（実装後に追記）。

## 1 Cloud の静的検査

```bash
scripts/check-no-network.sh
scripts/check-readme-sync.sh master
scripts/dev/check-english-comments.sh
scripts/dev/check-skill-sync.sh
python3 -I -m unittest discover -s scripts/dev/tests -p 'test_check_git_push.py'
git diff --check
```

期待結果: すべて成功。通信 API の追加なし（`NSWorkspace.shared.open` のみ）。`specs/product` への反映前に最新 master を取り込み、ID の重複がないことを確認する。

## 2 macOS CI

保守者が PR を依頼したときの macOS Swift CI で、`swift build`、通常のテスト（`AboutInfoTests`・`AboutWindowTests`・文言の整合性）を確認する。性能テストは失敗を許容するステップなので、ログで件数を確認して報告する。Cloud では Swift を実行しない。

## 3 保守者のローカル準備

```bash
swift build
swift test
scripts/make-app.sh
open .build/Folzio.app
```

3 ペインが表示されることを確認する。以下は GUI を伴うため保守者が行う。英語・日本語の両方で確認する。

## 4 シナリオ

| # | 操作 | 期待結果 | 仕様 |
|---|---|---|---|
| 1 | アプリメニューを開く | 「Folzio について」/ ─ / 設定… / ─ / 終了 の順。About にショートカットなし | US45-AS3 |
| 2 | 「Folzio について」を選ぶ | 閉じるボタンだけのタイトルバーで、アイコン・Folzio・バージョン・URL を表示。メインウィンドウは操作できる | US45-AS1・AS2 |
| 3 | `plutil -extract CFBundleShortVersionString raw .build/Folzio.app/Contents/Info.plist` と見比べる | 表示のバージョンと一致 | SC-118 |
| 4 | リンクをクリック | 既定の Web ブラウザで `https://github.com/yoshidax/folzio` が開く。ダイアログは開いたまま | US46-AS2 |
| 5 | Tab でリンクへ移り Space / Return | 同じくブラウザが開く | US46-AS3 |
| 6 | ダイアログ内の操作要素を数える | リンクだけ | US46-AS4 |
| 7 | 「Folzio について」を 10 回選ぶ | 常に 1 枚で、前面に出る。位置は保たれる | US47-AS1 |
| 8 | ⌘W、閉じるボタン | ダイアログだけ閉じ、メインは変わらない。再び開ける | US47-AS2 |
| 9 | ダイアログを開いたままメインウィンドウを閉じる | ダイアログも閉じ、アプリが終了する | US47-AS3 |
| 10 | 開いたまま設定で言語を切り替える | バージョン行の語とメニュー項目名が再起動なしで切り替わる。URL とバージョンの数値は変わらない | US47-AS4 |
| 11 | スライドショー・全画面・名前の変更中・シート表示中に選ぶ | 選べて、これらの状態を壊さない | US47-AS5 |
| 12 | ネットワークを切ってリンクを押す | アプリは何も表示せず、ダイアログは開いたまま（ブラウザ側の表示に従う） | EC-166・167 |
| 13 | `swift run` で起動して選ぶ | バージョン行がなく、アイコン・Folzio・リンクを表示。クラッシュしない | US45-AS4 |
| 14 | VoiceOver で読む | ウィンドウ名、アイコン、バージョン、リンク（リンクとして）を順に読める | FR-245 |
| 15 | ダイアログを開いた直後にリンクを見る。次に Tab を押す | 開いた直後は青い枠（フォーカスの枠）がない。Tab を押すと枠が出て、Space・Return で開ける。クリックでは枠が出ない | US46-AS5 |

## 5 結果の記録

実装後に、Cloud の検査、CI、保守者の確認を分けて記録する。未確認の項目は未確認と書く。

### 実装時の記録（2026-11-01、Cloud）

- 保守者が設計を承認（会話での回答）。次の 2 点が確定した: メインウィンドウを閉じるとダイアログも閉じる（FR-243）、`make-app.sh` の既定の版を `1.0.0` にする（FR-246）。
- 実装後の Cloud の静的検査: 下の「静的検査の結果」を参照。
- 未確認: `swift build`・`swift test`（CI で確認）、GUI の全シナリオ（保守者）、`swift run` で版が取得できないこと（シナリオ 13）。
- 静的検査の結果（Cloud）: `check-readme-sync.sh master`、`check-english-comments.sh`、`check-skill-sync.sh`、`test_check_git_push.py`（3 件）、`git diff --check` は成功。`check-no-network.sh` は、公開リポジトリの URL リテラルが禁止パターン（`https?://`）に一致して失敗したため、保守者の承認（2026-11-02）を得て、そのリテラル 1 箇所（`Sources/FolzioCore/About/AboutInfo.swift` の `"https://github.com/yoshidax/folzio"`）だけを許可する例外を追加した。ほかのファイルの同じリテラル、同じファイルのほかの URL、通信 API は引き続き失敗することを、一時ファイルで確認した。
- `master`（TAK-23、#30）の取り込みで ID が衝突したため、このfeatureの ID を振り直した（FR-238〜246、SC-118〜120、EC-166〜169、A-146〜148、US45〜47）。
- 保守者の GUI の確認（2026-11-02）: 振る舞いは問題なし。ただし、開いた直後にリンクへ常にフォーカスの枠（青い枠）が出ていた（スクリーンショットの指摘）。原因は、リンクがウィンドウ内の唯一のキービューで、開いた直後に最初のフォーカスを受けること。キー操作で移ったときだけ枠を表示するように直した（FR-242、US46-AS5、シナリオ 15）。修正後の確認は未実施。
