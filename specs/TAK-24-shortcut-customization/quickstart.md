# Quickstart: ショートカット割り当ての検証

## 自動の検証

| 実行する者 | 検査 |
|---|---|
| Cloud | `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`、`python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py"` |
| CI | `swift build`、`swift test`（`Tests/FolzioCoreTests/Shortcuts/*`、`ShortcutSettingsTextTests`、`CatalogConsistencyTests`）。性能テストはログの末尾で合否を確かめる |
| 保守者（ローカル） | `swift build && swift test`、`scripts/make-app.sh`、`open .build/Folzio.app` による GUI の確認（下） |

## GUI の確認（保守者）

古い Folzio を終了してから起動する。日本語・英語の両方で行う。

| # | 手順 | 確認点（対応） |
|---|---|---|
| Q1 | ⌘, で設定を開く | 「一般」タブが選ばれ、言語・動画・ファイル操作・スライドショーが現行どおり（間隔 20pt / 8pt、補足説明、Tab 順）。高さは内容に合う（US44-AS5、SC-122） |
| Q2 | 「ショートカット」タブへ切り替える | 区分ごとに 32 行。既定のキーがショートカット一覧（⌘/）と一致。ウインドウが画面に収まり、一覧がスクロールできる（FR-234） |
| Q3 | 「新規フォルダ」の「記録」を押し、⌥⌘J | 行に ⌥⌘J と「変更済み」。メインウインドウで ⌥⌘J で新規フォルダが作られ、⇧⌘N では作られない。ファイルメニューの表示も更新（US44-AS1・2、SC-117） |
| Q4 | ツリーとファイルリストのコンテキストメニューを開く | 「新規フォルダ」のキー表示が ⌥⌘J（FR-238） |
| Q5 | 「スライドショーを開始」を変更し、ツールバーのボタンにポインターを重ねる | ツールチップと VoiceOver のラベルのキーが新しい割り当て（SC-120） |
| Q6 | 記録中に ⌘F | 行に「「検索…」で使われています」。割り当ては変わらず、記録中のまま。検索シートは開かない（US45-AS1、EC-164） |
| Q7 | 記録中に ⌘Q、⌥→、A、⇧A、Return | ⌘Q・⌥→ は「このキーは変更できません」、A・⇧A・Return は「⌘・⌃・⌥ のいずれかと…」。アプリは終了しない（US45-AS2・3） |
| Q8 | 記録中に Esc / 「一般」タブへ切り替え / ウインドウを閉じる / 言語を切り替え | 記録をやめ、割り当ては不変（US44-AS4・6・7） |
| Q9 | 現在と同じ組み合わせを再入力 | エラーなく記録を終え、変更なし（US45-AS5） |
| Q10 | 「新規フォルダ」を戻す。別のコマンドが ⇧⌘N を使っている状態でも試す | 戻る。重複するときは戻さず案内（US46-AS1・2、FR-240） |
| Q11 | 複数を変更して「すべて既定値に戻す」 | すべて既定値、メニューとツールチップも既定値（US46-AS3、SC-121） |
| Q12 | アプリを再起動 | 変更した割り当てが復元される。`defaults delete` 後は既定値（US44-AS3、SC-119） |
| Q13 | 不正な保存値: `defaults write local.folzio.Folzio shortcuts.overrides -dict newFolder "x" find "cmd+q"` | 起動でき、該当項目は既定値。ほかは保たれる（EC-165） |
| Q14 | キーボードだけで「ショートカット」タブを操作（Tab / Space） | 記録・取り消し・戻すが完了できる。VoiceOver が名前・キー・状態・エラーを読む（SC-123、FR-242） |
| Q15 | 拡大のキーを変更 | ⌘= が効かなくなる。戻すと再び効く（EC-167） |

## 結果の記録

設計の承認と GUI 確認の結果（実行日・OS・合否）は `checklists/validation.md` に記録する。
