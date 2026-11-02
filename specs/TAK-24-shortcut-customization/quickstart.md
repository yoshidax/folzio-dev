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
| Q1 | ⌘, で設定を開く | 「一般」タブが選ばれ、言語・動画・ファイル操作・スライドショーが現行どおり（間隔 20pt / 8pt、補足説明、Tab 順）。高さは内容に合う（US48-AS5、SC-130） |
| Q2 | 「ショートカット」タブへ切り替える | 区分ごとに 32 行。既定のキーがショートカット一覧（⌘/）と一致。ウインドウが画面に収まり、一覧がスクロールできる（FR-257） |
| Q3 | 「新規フォルダ」の「記録」を押し、⌥⌘J | 行に ⌥⌘J と「変更済み」。メインウインドウで ⌥⌘J で新規フォルダが作られ、⇧⌘N では作られない。ファイルメニューの表示も更新（US48-AS1・2、SC-125） |
| Q4 | ツリーとファイルリストのコンテキストメニューを開く | 「新規フォルダ」のキー表示が ⌥⌘J（FR-261） |
| Q5 | 「スライドショーを開始」を変更し、ツールバーのボタンにポインターを重ねる | ツールチップと VoiceOver のラベルのキーが新しい割り当て（SC-128） |
| Q6 | 記録中に ⌘F | 行に「「検索…」で使われています」。割り当ては変わらず、記録中のまま。検索シートは開かない（US49-AS1、EC-178） |
| Q7 | 記録中に ⌘Q、⌥→、A、⇧A、Return | ⌘Q・⌥→ は「このキーは変更できません」、A・⇧A・Return は「⌘・⌃・⌥ のいずれかと…」。アプリは終了しない（US49-AS2・3） |
| Q8 | 記録中に Esc / 「一般」タブへ切り替え / ウインドウを閉じる / 言語を切り替え | 記録をやめ、割り当ては不変（US48-AS4・6・7） |
| Q9 | 現在と同じ組み合わせを再入力 | エラーなく記録を終え、変更なし（US49-AS5） |
| Q10 | 「新規フォルダ」を戻す。別のコマンドが ⇧⌘N を使っている状態でも試す | 戻る。重複するときは戻さず案内（US50-AS1・2、FR-263） |
| Q11 | 複数を変更して「すべて既定値に戻す」 | すべて既定値、メニューとツールチップも既定値（US50-AS3、SC-129） |
| Q12 | アプリを再起動 | 変更した割り当てが復元される。`defaults delete` 後は既定値（US48-AS3、SC-127） |
| Q13 | 不正な保存値: `defaults write local.folzio.Folzio shortcuts.overrides -dict newFolder "x" find "cmd+q"` | 起動でき、該当項目は既定値。ほかは保たれる（EC-179） |
| Q14 | キーボードだけで「ショートカット」タブを操作（Tab / Space） | 記録・取り消し・戻すが完了できる。VoiceOver が名前・キー・状態・エラーを読む（SC-131、FR-265） |
| Q16 | 「Folzio について」とツールバーのカスタマイズ（右クリック → ツールバーをカスタマイズ）を使う | 「Folzio について」にキーはなく、記録中の候補とも競合しない。ボタンを並べ替えた後も、ツールチップのキーは現在の割り当てを示す（R10） |
| Q17 | 2 つのコマンド（例: 「検索…」と「新規フォルダ」）のキーを入れ替える: 検索を「未設定にする」→ 新規フォルダに ⌘F を記録 → 検索に ⇧⌘N を記録 | 空きキーを探さずに入れ替わる。途中で検索は「未設定」と表示され、メニューにキーが出ず、元のキーを押しても何も起きない。メニューの項目のクリックでは実行できる。ツールチップ・ショートカット一覧にも反映される。再起動後も保たれ、「すべて既定値に戻す」で戻る（US50-AS4・5、FR-268、SC-132、EC-187） |
| Q15 | 拡大のキーを変更 | ⌘= が効かなくなる。戻すと再び効く（EC-181） |

## 結果の記録

設計の承認と GUI 確認の結果（実行日・OS・合否）は `checklists/validation.md` に記録する。

## 実装の記録

- **設計の承認**: 2026-11-02。保守者が analyze の指摘 F1〜F6 の修正と、master（TAK-23・TAK-45）取り込み後の影響確認を踏まえて承認した。範囲は spec.md・plan.md・tasks.md の全体。
- **T001（API の確認）**: Cloud から Apple の文書を参照して確かめてはいない。`NSMenuItem.keyEquivalent` / `keyEquivalentModifierMask` は既存のコードが使っている。`performKeyEquivalent(with:)`、`charactersIgnoringModifiers`、`NSAccessibility.post(…announcementRequested…)` も既存のコードまたは AppKit の標準 API。`NSTabView` は使わず、`NSSegmentedControl` と切り替え用のビューにした（Tab 順を変えないため）。CI のビルドと GUI 確認で確かめる。
- **T002（既定値の突き合わせ）**: `MainMenu.swift`・`FileListViewController.swift`・`MainSplitViewController.swift`・`DirectoryTreeViewController.swift`・`FileContextMenu.swift` の `keyEquivalent` を grep して contracts §1 と照合した。「ゴミ箱に入れる」は「ファイル」「編集」・ファイルリストとツリーのコンテキストメニューの 4 か所に現れ、すべて同じコマンド `trash` に結び付けた。ファイルリストのコンテキストメニューの「開く」はキー表示を持たない（`keyEquivalent` が空）ため登録していない。
- **CI（macOS 15 / Xcode 16.0）**:
  - 1da8559（PR #35 の作成時の実行）: ビルド成功、通常のテスト 985 件が全件成功、性能テスト 27 件が全件成功（ログの末尾 `Test run with 27 tests passed` で確認）。
  - ef60615（「ショートカット」タブの列の幅の修正。`workflow_dispatch`）: 同じく、ビルド成功、通常のテスト 985 件・性能テスト 27 件が全件成功。
  - 追加した 5 つのテストスイートが個別に走ったことは、ログの全文を取得できず（ログのホストにこのセッションから接続できない）確認していない。ログの末尾だけで判断した。
- **未実行**: GUI 確認 Q1〜Q17（保守者のローカル）。
