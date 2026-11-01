# Validation Guide: TAK-22

以下は実装後の検証手順。実行結果と未確認事項は第5章に記録する。

## 1 Cloud の静的検査

リポジトリのルートで実行する。

```bash
scripts/check-no-network.sh
scripts/check-readme-sync.sh master
scripts/dev/check-english-comments.sh
python3 -I -m unittest discover -s scripts/dev/tests -p 'test_check_git_push.py'
git diff --check
```

期待結果: 全検査成功、README両言語の内容と構造が対応、新しい通信なし。
specs/product の反映前には最新 master を取り込み、全領域のID重複を調べる。

## 2 macOS CI

実装後、保守者の依頼でPRを作った際の macOS Swift CI を確認する。追加の修正後は必要な1回の workflow_dispatch で再確認する。
期待結果: swift build、通常テスト、カタログ・翻訳テストに成功。性能テスト結果も確認し、失敗許容のステップでも失敗を隠さない。
CloudではSwiftを実行せず、CI結果がない場合は未確認と記録する。

## 3 保守者のローカル準備

macOS 15以降、対象コミットを取り込んだ開発リポジトリで実行する。

```bash
swift build
swift test
scripts/make-app.sh
open .build/Folzio.app
```

3ペインが表示されることを確認し、画像・動画・サブフォルダ・zipがあるフォルダを用意する。
以下はGUI起動を伴うため保守者が行う。英語・日本語の両方、可能な範囲でUS/JIS両配列で確認する。

## 4 シナリオ

| 番号 | 操作 | 期待結果 / 対象 |
|---|---|---|
| Q1 | ファイルメニューから開き、閉じて⌘/で開く | 同じ7区分・44項目。キーが説明と区別できる（US32-AS1〜2、SC-096） |
| Q2 | 一覧を親の横へ移動し、親で選択・フォルダ移動 | 一覧を閉じずに通常操作できる。背景の覆いなし（US32-AS3、SC-099） |
| Q3 | 親と一覧から⌘/を合計10回実行 | 1枚を前面化。位置・サイズ・参照位置を保持（US33-AS1、SC-097） |
| Q4 | 一覧を閉じるボタン、再表示後⌘Wで閉じる | 一覧だけ閉じる。親と選択が残り、再表示時の位置・スクロール保持（US33-AS2） |
| Q5 | 親を閉じるボタン、別の起動で親に⌘W | どちらも対応一覧が閉じる。一覧が終了を妨げない（US33-AS3） |
| Q6 | 設定を残して親を閉じ、起動メニューを確認 | 一覧の項目は無効。閉じた親は再表示されない（EC-136） |
| Q7 | リスト・ツリーのお気に入り・通常フォルダの名前の編集中に起動操作 | 無効。編集内容の確定・取消を起こさない（EC-137） |
| Q8 | 検索sheet・確認modal・全画面・slideshow中に起動操作 | 無効。既存一覧は閉じない。状態終了後は再び開ける（EC-137〜138） |
| Q9 | 画面の右端・左端に親を配置して初回表示。小さい画面・複数画面でも確認 | visibleFrame 内へ配置。並べられない場合のみ重なり許可。親は移動しない（EC-139） |
| Q10 | 一覧を途中までスクロールし設定で英語→日本語→英語 | タイトル・見出し・説明・条件・読み上げ文言が即時更新。キー表記・位置・サイズ・先頭項目を維持（US34-AS1、SC-098） |
| Q11 | 最小サイズで↑↓・Page Up/Down・Home/End、Escを入力 | 全項目を参照可能。親の選択・履歴・再生・終了へ伝播しない（US34-AS2、EC-140） |
| Q12 | 両言語・最小サイズ・明暗モードで確認し、VoiceOverで辿る | 文字欠け・横スクロール不要。見出しとキー・説明・条件を対応して読める（US34-AS3、SC-098） |
| Q13 | contracts/shortcut-cheatsheet.md の各行を親の対応する状態で実行 | 掲載キーと実動作・条件が全44項目で一致。⌘/と単独/が衝突しない。既存の⌘+等の動作維持（FR-203、SC-096） |
| Q14 | 一覧を開いた状態で終了・再起動 | 一覧は自動表示されない。新しく開くと初期状態（FR-204） |

## 5 結果の記録（実装後、T016〜T019で追記）

Cloud: 静的検査成功。CI: ビルド・通常833件・性能27件成功（下記の最終CI記録を参照）。保守者から動作確認「問題なし」の報告あり。ローカルbuild/testの個別結果・GUI各Qの詳細は未報告。
記録する項目: コミットSHA、macOS・Swift版、配列・表示言語、各Qの結果、CI URL、失敗・未確認事項。
GUI未確認のまま feature 完了・凍結・Done更新をしない。

### 2026-10-31 実装着手の記録（T001〜T002）

保守者が会話で設計案に対して「続けて」と回答し、設計レビュー承認として実装を開始した。
作業ブランチはCloud指定の work。最新origin/master（bfe63d5）をfetchし取り込み済みであることを確認。
44項目を既存のメニューとペインの入力処理、キーボード契約と照合。既存のキー処理は変更しない。
新規利用APIはAppleの公式文書で確認した:

- [NSWindow](https://developer.apple.com/documentation/appkit/nswindow): performClose、willCloseNotification。
- [NSTextField](https://developer.apple.com/documentation/appkit/nstextfield): wrappingLabelWithString、preferredMaxLayoutWidth。
- [preferredMaxLayoutWidth](https://developer.apple.com/documentation/appkit/nstextfield/preferredmaxlayoutwidth): 指定幅で全文を表示する高さ。
- [NSScrollView.documentView](https://developer.apple.com/documentation/appkit/nsscrollview/documentview): スクロール対象のビュー。
- [NSView.isFlipped](https://developer.apple.com/documentation/appkit/nsview/isflipped): 上端起点のレイアウト。

T003〜T010、T012〜T014、T016の実装を追加した。チェックは実装作業の完了を表し、Swiftのビルド・テスト成功やGUI確認を表さない。
カタログは7区分44項目。翻訳は用途別のTextKeyで管理し、既存CatalogConsistencyTestsが追加キーも検査する。
CI・ローカルのSwift実行・GUIのQ1〜Q14は引き続き未確認。

### 2026-10-31 Cloud検査の結果（T017）

- check-no-network.sh: 成功。SourcesにネットワークAPI参照なし。
- check-readme-sync.sh origin/master: 成功。ローカルmaster参照がないため、fetch済みのorigin/masterを基準に使用。
- check-english-comments.sh: 成功。
- test_check_git_push.py: 3件成功。
- git diff --check: 成功。
- カタログ静的照合: 44項目・7区分のID、順序、キーを承認済み契約へ照合。
- 翻訳静的照合: 各言語94個の追加キーが揃い、空欄・重複・未使用キーなし。パーセントは書式用にエスケープ。

表示上の調整: 契約の「⇧ + 矢印」は翻訳しないキー列に日本語を混在させないため、同じ意味の「⇧↑ / ⇧↓ / ⇧← / ⇧→」で表示する。割り当て・掲載範囲は変更していない。
互換性確認: 新しいSDKで追加されたHeadingRole定数は使用せず、標準の静的ラベルと翻訳されたアクセシビリティラベルで各見出しを公開する。

追加したSwift Testingの5テストはCloudでは未実行。CIのbuild/test、VoiceOver・スクロール・ウィンドウの終了連動を含むGUI Q1〜Q14、保守者のローカルbuild/testは未確認。
T011・T015・T018〜T020は未チェック。product仕様の反映・凍結・Linear Done更新は行っていない。

### 2026-10-31 PR提出と初回CI（T018）

保守者の「OK」を受け、ブランチを agent/TAK-22-shortcut-cheatsheet に変更して提出した。
[PR #10](https://github.com/yoshidax/folzio-dev/pull/10) を作成し、TAK-22へリンクを追加してIn Reviewに更新した。
[初回CI](https://github.com/yoshidax/folzio-dev/actions/runs/41190274601) はmacOS 15.8.2 / arm64 / Xcode16.0・Swift6.0で実行。
NSWindowController.document と参照ビューの私有プロパティ名が衝突しビルド失敗、通常・性能テストは未実行。
完了済みログを確認して参照ビューの名前をreferenceViewへ変更した。新しいAPIへの置換はない。

追加push後の再確認: GitHub接続ツールにworkflow_dispatchがなく、gh workflow runはAPIアクセス時にForbiddenを返したため、既存のready_for_reviewトリガーを使用した。PRを一時DraftにしReadyへ戻して修正済みコミットのCIを起動した。失敗したコミットの再実行はしていない。

### 2026-10-31 修正後CIの結果と翻訳検査の調整

[2回目CI](https://github.com/yoshidax/folzio-dev/actions/runs/41190672576)（6d1423b）: ビルド成功。通常テスト833件を実行し、追加したカタログ・翻訳の5件はすべて成功。既存CompiledBundleTestsの1テストだけが4件の失敗を報告した。
失敗は倍率説明の25%、800%、100%を未置換書式とみなす一律のパーセント禁止検査が原因。実際の倍率表記とエスケープ解除は新規テストで成功している。
CompiledBundleTestsを、翻訳元の%%の数と結果の%の数が一致し、未置換の%@・%lld・位置指定子・複数形参照が残らないことを検証する形に調整した。テスト用の値は文字列sample・件数2のため、複数形は両言語ともotherを参照する。
性能テストは通常テストの失敗により未実行。調整後に再確認する。

### 2026-10-31 最終CI結果（T018完了）

[CI run #19](https://github.com/yoshidax/folzio-dev/actions/runs/41191088999) が成功。対象コミットは e06a754e55a1792f09bf80ed0c143fe9bf043ea9。macOS15.8.2 / arm64 / Xcode16.0 / Swift6.0。

- swift build: 成功（14.17秒）。
- 通常テスト: 833件成功（113.903秒）。追加したカタログ・翻訳の5件と調整した既存翻訳テストを含む。
- 性能テスト: 27件成功（89.953秒）。失敗許容ステップも実際に成功。
- Cloudの静的検査は修正後も成功。README基準はorigin/master。

この結果とT018チェックの記録は文書だけの追記で、検証対象のアプリ・テストのソースからの追加変更はない。
残りはT011・T015・T019の保守者確認と、検証後のT020（product仕様反映と承認後の凍結）。
GUI Q1〜Q14、ローカル最新Swiftのbuild/test、公開・配布用の開発スクリプト検証は未確認。CI成功だけで実機検証済みとは扱わない。
Linear TAK-22はIn Review、PR #10を紐付け済み。

### 2026-10-31 保守者の動作確認と文書の別PR

保守者から会話で「動作確認は問題ありませんでした」と報告を受けた。Agent自身がGUIを実行したものではない。
直前に依頼した主な確認点は一覧の起動（⌘/）、一覧だけを閉じる操作（⌘W）、親の終了連動。
Q1〜Q14ごとの結果、VoiceOver、US/JIS両配列、両言語最小幅、反復10回、最新Swiftのbuild/test、公開・配布スクリプトの個別結果は示されていないため、個別に成功したとは記録しない。
T011・T015・T019は詳細検証の未報告事項を残す。動作確認の報告自体は受領済み。

実装PR #10がmasterの6a6a700へマージ済みであることをfetchで確認した。CI成功コミットe06a754とmasterのSources・Tests・READMEに差分なし。
未提出の検証記録205c852は、保守者の別PR作成の依頼を受け、新しいdocs/TAK-22-shortcut-recordsブランチへcherry-pickした（新SHA:9ddfa10）。元の実装ブランチへの追加pushは行っていない。

保守者が「追記分を残りの仕様反映とまとめた別の文書PR」に同意したため、承認済みfeature仕様のFR-200〜207・SC-096〜099・EC-136〜140・A-116〜118・US32〜34をproductへ反映する。
反映先はwindow-layout.md、overview.md、contracts/keyboard-and-menus.md、contracts/localization.md。7区分44項目の固定一覧もキーボード契約へ移す。
仕様IDは最新masterとの衝突なし。アプリ・テスト・README・CI設定の変更なし。

文書PRの検査: productの29個の追加IDが各1回だけ定義され、既存IDにも重複なし。44項目のキー表記が実装カタログと一致。ローカルMarkdownリンクを確認し、git diff --check・通信禁止・英語コメント・README同期（origin/master基準）・push保護テスト3件は成功。変更はspecs配下の文書8ファイルだけである。
