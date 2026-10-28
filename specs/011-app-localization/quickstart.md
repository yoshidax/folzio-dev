# Quickstart: 日本語・英語への国際化の検証

> 表示言語はアプリの設定で選び、即時反映・保存する。地域書式の確認には `-AppleLocale` 等を使う。

**Feature**: `011-app-localization` | **Plan**: [plan.md](plan.md) | **契約**: [contracts/localization.md](contracts/localization.md)・[contracts/app-bundle.md](contracts/app-bundle.md)

自動検証（Q1）・バンドルの確認（Q2）の後、GUI の確認（Q3〜Q9）をユーザーに依頼する。GUI の起動と目視はユーザーが行い、未実施の確認を完了扱いにしない（AGENTS.md）。
期待する英語の表示名は契約 §5 の用語対応表、表示言語の期待値は契約 §1 の表を正とする。

## 前提

- macOS 15 以降。リポジトリのルートで作業する
- フィクスチャ: `scripts/make-fixtures.sh ~/MediaViewerFixtures`（空のフォルダ・壊れた画像・暗号化された zip・大量のファイルを含む）
- 古いプロセスが残っていないこと: `pgrep -fl MediaViewer`
- 表示言語はアプリの設定で選択し、変更後に再起動せず確認する。地域書式だけは必要に応じて `-AppleLocale` などの引数で起動する。

```bash
app=.build/MediaViewer.app/Contents/MacOS/MediaViewer
"$app" -AppleLocale ja_JP
"$app" -AppleLocale en_US
"$app" -AppleLocale de_DE
"$app" -AppleLocale en_US -AppleICUForce24HourTime YES
```

## Q1. 自動検証（Phase の検証ゲート 1〜3）

```bash
swift build
swift test
scripts/check-no-network.sh
scripts/check-readme-sync.sh master
```

期待結果:

- すべて成功する。`swift test` に research.md R10 の 1〜10 が含まれ、訳の欠け・未使用のキー・値の数や種類の不一致が 0 件（FR-157、SC-069）
- 既存のテスト（Core の値の比較に書き換えたものを含む）がすべて通る

## Q2. 配布用 `.app` の構成（契約 app-bundle.md）

```bash
scripts/make-app.sh
ls .build/MediaViewer.app/Contents/Resources/ja.lproj .build/MediaViewer.app/Contents/Resources/en.lproj
plutil -extract CFBundleDevelopmentRegion raw .build/MediaViewer.app/Contents/Info.plist
plutil -extract CFBundleLocalizations json -o - .build/MediaViewer.app/Contents/Info.plist
codesign --verify --deep --strict .build/MediaViewer.app
```

期待結果: 両方の lproj に `Localizable.strings` と複数形の表（`Localizable.stringsdict`、または R1 の試作で控えた同等の表）がある。`en`、`["ja","en"]`。署名の検証が成功する。

## Q3. 英語の UI（US17、SC-061）

アプリを起動して設定で英語を選び、次を順に確かめる。

1. メニューバーのすべてのメニュー（アプリ・File・Edit・View・Go）: 項目名が用語対応表どおりの英語。並び・区切り線・ショートカット・チェックマーク・有効／無効が日本語のときと同じ。
   View に Sort By のサブメニューがあり、選択中の列に (Ascending)／(Descending) が付く（R9 の識別子での探索の確認）
2. ファイルを1つ選んで右クリック → `Copy “<名前>”`。3つ選んで右クリック → `Copy 3 Items`。ツリーの右クリック → Paste Here・Move Item Here ほか
3. ⇧⌘T でツールバーを表示 → 各ボタンのツールチップとパレットの名前（ツールバーの右クリック > ツールバーをカスタマイズ）が英語
4. 複数のファイルを ⌘Delete（確認が有効な状態で）→ 見出し・`Items: N`・ボタン・Don’t ask again が英語。Esc で取り消せる
5. 同名のファイルがあるフォルダへコピー → 衝突ダイアログの Replace・Keep Both・Stop・Apply to all
6. ⌘F → 存在しない起点で検索 → 理由が英語。有効な起点で検索 → 検索バーが `Results for “<キーワード>” — <フォルダ名> — N items`、検索中は Searching…
7. ⌘, → 区分・チェックボックス・seconds・Transition の選択肢が英語。変更が保存・反映される
8. 空のフォルダ、種類フィルタで0件、壊れた画像、暗号化された zip の中の画像 → 空状態・プレビューのエラー・zip の理由が英語
9. どの画面にも、日本語のアプリ管理文言・`menu.` などの内部キー・`%@` などの置換されていない記号が出ない（OS が提供する文言は数えない）

## Q4. 日本語の UI と既存の文言（US18-AS1、SC-067）

アプリの設定で日本語を選び、Q3 の 1〜8 を日本語で確かめる。メニュー・確認モーダル・設定ウインドウの文言が既存仕様（`specs/product/contracts/keyboard-and-menus.md`・
`settings.md`）と同じであること。件数が 1,000 件以上のとき桁区切りが付くこと以外に変化がないこと。

## Q5. 表示言語の設定と即時反映（US18、SC-062）

1. 設定の保存値がない環境で起動し、OS の言語が日本語でも英語で表示されることを確認する。既存設定の削除が必要な場合は、ユーザーのデータを消さずに検証用の環境を使う。
2. ⌘, の設定ウインドウで日本語を選び、同ウインドウ・メニュー・ツールバー・3ペイン・検索結果・アクセシビリティが再起動なしで日本語になることを確認する。
3. 英語に戻し、同じ画面が即時に英語になることを確認する。切り替え前のフォルダ・選択・スクロール・検索や入力値が維持されることを確かめる。
4. 日本語、英語をそれぞれ選択して終了・再起動し、最後の設定が復元されることを確認する。
5. OS の優先言語・アプリごとの言語を変更してもアプリの設定言語が変わらないことを確認し、OS の設定を元に戻す。OS が提供する文言は EC-111 の対象とする。

## Q6. 配布の独立性（US18-AS5、SC-066）

```bash
tmp=$(mktemp -d)
ditto .build/MediaViewer.app "$tmp/MediaViewer.app"
mv .build .build-away
"$tmp/MediaViewer.app/Contents/MacOS/MediaViewer"   # 設定で英語・日本語を切り替えて確認し、終了
mv .build-away .build
```

期待結果: どちらも翻訳された文言で表示され、内部キーが出ない。確認後に `.build` を元の名前へ戻す。

## Q7. 地域の書式（US19、SC-063）

フィクスチャのフォルダをリスト形式（⌘2）で開き、「作成日」列・検索バーの件数（1,000 件以上が一致するキーワード）・画像を 125% に拡大したときの VoiceOver の読み上げを確かめる。

| 起動の引数 | 期待結果 |
|---|---|
| 英語を選択し `-AppleLocale ja_JP` | 列見出しは Date Created。日付と時刻は日本の並びと24時間表示。件数 `1,234` |
| 日本語を選択し `-AppleLocale en_US` | 列見出しは作成日。日付と時刻は米国の並びと12時間表示 |
| 英語を選択し `-AppleLocale de_DE` | 件数 `1.234`、倍率の読み上げとアクセシビリティの値が `125 %` |
| 日本語を選択し `-AppleLocale en_US -AppleICUForce24HourTime YES` | 作成日の時刻が24時間表示（US19-AS4） |
| `-AppleLocale de_DE` で ⌘, | 切り替え間隔が桁区切りなしの整数。`１２`（全角）・`3600`・`3601` の入力の扱いが従来どおり（US19-AS5） |

作成日を取得できないファイル（zip の中の項目など）は、どの組み合わせでも `--`（EC-116）。

## Q8. VoiceOver（US20、SC-068）

英語と日本語のそれぞれで VoiceOver（⌘F5）をオンにし、ツールバーの各ボタンとスライダー、検索シートの入力欄と Choose…／選択…、設定ウインドウの全項目、お気に入りとフォルダの名前の編集欄、
プレビューの倍率を読み上げさせる。ラベル・ヘルプ・値が表示言語で読まれ、ショートカットの表記がツールチップと同じであること。検索起点の検証エラーと倍率の変更が表示言語で読み上げられること。

## Q9. 配置と保存内容（FR-153、SC-065、US17-AS7、EC-112・113）

1. 両言語で、ウインドウを最小サイズにし、各ペインを最小幅にする。メニュー項目・ボタン・チェックボックス・設定のラベル・既定の列幅の列見出し・空状態のメッセージが欠けない。
   確認モーダル・衝突ダイアログ・検索シート・設定ウインドウで、すべての文とボタンが読める
2. 長いキーワード・深いフォルダ名で検索 → 検索バーは省略記号で切り詰めてよく、ツールチップで全文が読める（EC-115）
3. 日本語で設定・お気に入り（表示名付き）・並べ替え・ツールバーの表示を変えて終了 → 英語で起動し直す → すべて復元され、お気に入りの表示名は翻訳されない
4. 英語で ⌘D（複製）と衝突時の Keep Both → 作られる名前が日本語で行ったときと同じ規則（「名前 2」）
5. 名前に `%@`・`%d`・`{0}`・アラビア文字を含むファイルを用意し、右クリックのコピー・確認モーダル・検索バーで文字どおりに出ること（EC-109）

## 報告

各 Q の合否と、不合格の画面（スクリーンショットまたは文言）を本ファイル末尾の「実装・検証記録」欄に記録する。tasks.md には該当タスクのチェックだけを付ける。
英語の文言の修正点があれば、tasks.md の「Path Conventions」の規則に従って管理元の英語の訳と契約 §5 の該当行を同じ変更で直し、Q1 から確かめ直す。

## 実装・検証記録

未実施の確認を成功として記入しない。自動検証の成功と、ユーザーによる GUI 確認を別々に記録する。

### Phase 1

- 基準（T003）: 成功（`swift build`・`swift test` 776 件・`check-no-network.sh`・`check-readme-sync.sh master`・`make-app.sh`）
- R1 試作（T005・T006）: 通常の件数表示では String Catalog の生成物と複数形を確認。追加試作では件数を表示しない複数形を `xcstringstool compile` が拒否したため、管理元は `.strings` + `.stringsdict` に切り替える。Swift Package 経由の再検証は未実施
- 設計レビュー（T002）: 2026-10-28、旧仕様についてユーザーはレビューを委ね、推奨案で進めることを承認。新しい即時切り替えの設計レビューは未実施
- 用語対応表の英語レビュー（T082・T083）: 2026-10-28、ユーザーはレビューを委ね、推奨案で進めることを承認。§5 の各表を確認し、英語の修正指示はなし

### 引き継ぎ時点の自動テスト

- 2026-10-28: ユーザー報告では `swift test` の 806 件・82 suites が通過。ビルドの出力は未確認。即時切り替えの実装前の結果である。

### 新方式の Phase 2（T105〜T107）

- 自動検証（2026-10-28、macOS 26.6.2）: `swift build`、`swift test`（808 件・82 suites）、ネットワーク禁止、README 同期、`make-app.sh`、両言語のリソース、Info.plist と署名の確認はいずれも成功。
- GUI（2026-10-28、ユーザー報告）: 3ペインを表示し、言語を初めて設定する前の表示は英語。設定で日本語から英語への変更時、設定画面の文言は即時切り替わった。メニューと右クリックメニューは再起動後に反映された。これらの即時反映は Phase 3 の未完了項目。

### 旧方式の Phase 別記録（参照用）

以下の T029〜T077 は旧タスクの番号であり、新方式の検証結果ではない。

### Phase 2

- 自動ゲート（T029）: 未記入
- GUI の確認（T030）: 未実施

### Phase 3（US17）

- 自動ゲート（T048）: 未記入
- GUI の確認（T049・T050）: 未実施

### Phase 4（US18）

- 自動ゲート（T055）: 未記入
- GUI の確認（T056〜T058）: 未実施

### Phase 5（US19）

- 自動ゲート（T066）: 未記入
- GUI の確認（T067）: 未実施

### Phase 6（US20）

- 自動ゲート（T071）: 未記入
- GUI の確認（T072）: 未実施

### Phase 7

- 最終ゲート（T076）: 未記入
- 最終 GUI の確認（T077）: 未実施
- SC-061〜SC-069 の証拠: 未記入
