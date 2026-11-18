# Quickstart: フォルダの右クリックメニューの整理

## 自動検証（Agent）

設計承認後、Core の対象・順序・貼り付け先のテストと AppKit の実メニュー／action のテストを追加する。
コピー・複製・ペースト・移動はテスト用の一時フォルダで検証する。
リポジトリルートで次の順に実行する。

```bash
swift build
swift test
scripts/dev/check-all.sh
scripts/make-app.sh
```

## 手動確認（保守者）

古い Folzio を終了し、次を実行する。

```bash
cd /Users/igachan/.codex/worktrees/2347/folzio
open .build/Folzio.app
```

テスト用の親 P、子 A・B、別のコピー元 S、画像と zip を用意する。
実データを壊さない確認用フォルダで行い、移動時は S の場所が変わることを確認する。

1. **起動**: 3ペインが表示される。
2. **共通メニュー**: 同じ通常フォルダをツリー・リスト・サムネイルで右クリックする。
   契約の共通操作・並びが一致し、通常フォルダには新規フォルダがなく、一覧の外部で開く2項目もない。
   一覧の中を表示・上の階層へは従来どおり。背景の新規フォルダと ⇧⌘N も使える。
3. **ツリーのコピー**: 単一・複数の通常フォルダを右クリックと ⌘C・メニューバーでコピーして別の場所へペーストする。
   対象すべてが中身ごとコピーされる。選択外の右クリックはその1件だけになる。
4. **ツリーの複製**: 単一・複数で右クリックと ⌘D・メニューバーを試す。
   各対象の親に既存の採番規則で作られ、元の内容は変わらない。
5. **ペースト先**: P を一覧表示し B を選択したまま A を右クリックする。
   コピー／移動ペーストは A の中だけに書き込み、P や B の中へは書き込まない。
   同じ A をツリーで対象にした場合も同じ先になる。両表示形式で試す。
6. **背景・キー**: 一覧で A を選んでも、背景・メニューバー・⌘V・⌥⌘V は P へ書き込む。
   直前に A の項目メニューを開いた後も、キーの行先に古い対象が使われない。
7. **複数・混在**: フォルダ2件やフォルダと画像の選択では、項目メニューのフォルダ向けペーストが無効。
   通常フォルダ複数のコピー・複製・Finder に表示は両ビューで全対象に使える。
   名前変更・パス名コピー・お気に入り追加は複数では無効。ルートの名前変更・ゴミ箱も保護される。
8. **検索・zip・消失・失敗**: 検索結果のフォルダ1件へ項目メニューから貼り付けられ、検索は維持される。
   検索結果の背景とキーは無効。zip 内・`..` への操作も無効。
   対象が消えた場合は別の先へ書き込まない。読み取り専用・自己の中への操作・同名衝突は既存の検証・確認を使う。
9. **お気に入り**: 一覧の選択外・選択中・検索結果・絞り込み・一覧のみ表示で1件を登録できる。
   選択・フォーカス・スクロール・検索・展開状態が維持され、既存の表示名・順序・重複防止が再起動後も保たれる。
   ツリー・プレビューのフォーカス時の登録対象と、名前編集中・検索欄の文字入力中の無効状態も確認する。
10. **回帰**: メディア／zip ファイルの外部で開く操作、背景の新規フォルダ、お気に入りの仮想項目の登録削除・表示名変更を確認する。
    フォルダ→メディア→背景→複数選択とメニューを繰り返し開き、項目・区切り・文言・可否が残らないことを確認する。
11. **言語・キー・VoiceOver**: 日本語・英語、既存のコピー・複製・登録のキー割り当て変更を確認する。
    VoiceOver で項目名と有効・無効が読み上げられる。

報告: 対象コミット／ビルド、macOS、ツリーと両表示形式、項目1〜11の各成否。
未実施・失敗・一部成功では手動タスクを未チェックで残す。

## 記録先

tasks.md の記録タスクに従い、自動検証・GUI 報告・converge の結果をこのファイル末尾へ追記する。

## 設計承認

2026-11-17: 保守者が「この設計で実装へ進めてよいですか？」へ「OK」と回答。
共通メニュー、新規フォルダの配置、複数対象、検索結果のペースト、手動確認の分類を承認済み。
T001 を受領し、T002 として設計文書を先にコミットしてから実装する。

## 実装・関連検証（2026-11-18）

- T003〜T014: 共通メニュー・ツリーのコピーと複製・一覧の貼り付け先・登録経路を実装した。
- 右クリック時の全対象を保持し、対象消失・選択変更でも別の対象へ切り替えない。
- ツリーの複製は Task 開始前に対象を確定する。
- 関連テスト: Core 58件・App 8件が通過した（`/tmp/folzio-tak113-targeted.log`）。
- App テストでは隔離した pasteboard と一時フォルダでコピー・複製・移動ペーストの実結果を確認した。
- `swift build`: 成功（`/tmp/folzio-tak113-build.log`）。
- `swift test`: 終了コードは0、性能28件・Core 1,146件の完了を確認したが、App の最終完了記録が欠けた。
- `swift test --filter FolzioAppTests --no-parallel`: App 114件・22 suite の通過を確認した。
  ログ: `/tmp/folzio-tak113-app-serial-tests.log`。
- `scripts/dev/check-all.sh`: 成功（`/tmp/folzio-tak113-check-all.log`）。
- 全体の最終検証は `swift test --no-parallel` で実行中であり、T015 はまだ完了扱いにしない。

### 全体検証と性能閾値の扱い（2026-11-18）

- `swift test --no-parallel`: Core 1,146件・126 suite、App 114件・22 suite は通過した。
  ログ: `/tmp/folzio-tak113-all-serial-tests.log`。
- 同実行の性能テストは28件中、名前の絞り込み（最大142ms／100ms）と列挙（1.047秒／1秒）の閾値超過があった。
- 同じコードの再実行では、名前の絞り込み（最大129ms／100ms）の1件だけが超過し、列挙は0.438秒で通過した。
  ログ: `/tmp/folzio-tak113-all-serial-recheck.log`。
- 保守者が「性能テストの閾値超過はスキップして問題ないです」と明示したため、今回の性能閾値超過は検証ゲートの阻害条件から除く。
- 性能テスト・基準値・既存の絞り込み処理と列挙処理は変更しない。元コードとの追加比較は取りやめる。
- 性能以外の機能テストと、規約チェック・アプリ作成・保守者のGUI確認は引き続き必要。

### T015 完了・手動確認待ち（2026-11-18）

- 保守者が「性能テストの閾値超過はスキップして問題ない」と指示したため、既存の性能閾値超過を今回の検証ゲートから除外した。
  閾値・性能テスト・対象処理は変更していない。元の master との比較は取りやめた。
- 全体の直列実行で Core 1,146件・126 suite、App 114件・22 suite の機能テストが通過した。
  最初の実行ログ: `/tmp/folzio-tak113-all-serial-tests.log`。
- 性能の記録: 最初の直列実行は名前絞り込み142ms、列挙1.047秒で超過した。
  再確認では列挙0.438秒で通過し、名前絞り込み129msだけが超過した。
  再確認ログ: `/tmp/folzio-tak113-all-serial-recheck.log`。
- 最終 `scripts/dev/check-all.sh`: 成功（`/tmp/folzio-tak113-final-check-all.log`）。
- `scripts/make-app.sh`: 成功（`/tmp/folzio-tak113-make-app.log`）。
- `codesign --verify --deep --strict .build/Folzio.app`: 成功。
- 起動対象: `/Users/igachan/.codex/worktrees/2347/folzio/.build/Folzio.app`（arm64）。
- 実行ファイル SHA-256: `68f4b8a21184e1bcdb57c7904b1909ef6bb1a41dda83f0aac11e670f62e76bdf`。
- ソース: 設計コミット `22bd5fa` と作業ツリーの実装変更。実装 Phase はまだコミットしていない。
- 確認用データ: `/private/tmp/folzio-tak113-manual-zwuukdcj/`。
  `P` が一覧の親、`P/A`・`P/B` が対象、`S/source.png` がコピー元。
  `P/image.png` と `P/sample.zip` でメディアと zip の回帰も確認できる。
- 次は T016・T017。保守者による起動・項目1〜11の報告前にはチェックしない。
  製品仕様への反映・凍結と実装 Phase のコミットは未実施。

### 動作確認前のコードレビュー依頼（2026-11-18）

- 保守者から「動作確認の前にコードレビューを行いたいのでPRを作成」と依頼があった。
- この依頼に従い、現在の実装と検証記録をレビュー用に先行コミットし、作業ブランチから master 向けの PR を作成する。
- T016・T017 の手動確認と T018 の Phase 完了は未完了のまま残す。製品仕様への反映・feature の凍結もまだ行わない。
- PR 本文に機能テストの通過、保守者が許容した性能閾値超過、GUI 確認待ちを明記する。

### PR #91 レビュー指摘の判定と対応（2026-11-18）

PR: https://github.com/yoshidax/folzio-dev/pull/91

| 指摘 | 判定・対応 |
|---|---|
| [名前変更が対象外のフォーカスに作用する](https://github.com/yoshidax/folzio-dev/pull/91#discussion_r4610906462) | 妥当。対象集合にフォーカスが含まれる条件を復元した。選択A・フォーカスBの回帰テストで修正前の失敗を確認した。 |
| [一覧外の選択が操作対象から落ちる](https://github.com/yoshidax/folzio-dev/pull/91#discussion_r4610906590) | 一部妥当。メニューを開いた時点の operableSelection を保存し、最初から一覧外の選択URLもコピー等の対象に保つ。一覧にあった対象が後で消えた場合は全体を無効にする。未知の種類を含む複数対象へのペースト・登録は、単一実フォルダの条件を満たさないので無効のままとする。 |
| [ルートの複製](https://github.com/yoshidax/folzio-dev/pull/91#discussion_r4610906780) | 方針変更を保守者に確認して承認された。ツリー・一覧ともホーム・ボリューム・「/」を含む対象の複製を無効にする。メニュー検証と実行の両方で既存のルート保護を共用する。コピーとFinder表示はルートにも許可する。 |
| [ペイン外フォーカス時の登録](https://github.com/yoshidax/folzio-dev/pull/91#discussion_r4610906917) | 保守者に確認して、表示中のツリーの選択を使う方針が承認された。文字入力中と対象ペイン非表示時は無効にし、一覧にフォーカスがある場合は一覧に不適切な対象しかなくてもツリーへ切り替えない。 |
| [ペースト項目のショートカット表示](https://github.com/yoshidax/folzio-dev/pull/91#discussion_r4610907085) | 変更しない。contracts/keyboard-and-menus.md の「ここでキーの経路は項目メニューを閉じた状態を指し、開いているメニュー内のキー操作はそのメニューの対象に従う」に従う。メニュー項目をsenderとする経路と、メニューを閉じたキー経路の貼り付け先は既存の統合テストで分けて検証している。 |
| [メニュー検証の不要な走査](https://github.com/yoshidax/folzio-dev/pull/91#discussion_r4610907283) | 妥当。ルート保護を必要とするアクションか先に確認し、無関係な項目ではfolderPolicyを作らない。 |
| [ルート保護の再実装](https://github.com/yoshidax/folzio-dev/pull/91#discussion_r4610907447) | 妥当。FavoriteCommands.trashTargetを共用し、ルート外のフォルダもツリーと同じ条件で保護する。判定名はcontainsProtectedFolderとした。 |
| [コマンド判定の重複](https://github.com/yoshidax/folzio-dev/pull/91#discussion_r4610907595) | 妥当。BrowserModelの生成ヘルパーを共用し、親リンクにフォーカスがある選択の判定をCoreのListItemCommands.forSelectionへ集約した。 |
| [背景判定の未使用コード](https://github.com/yoshidax/folzio-dev/pull/91#discussion_r4610907774) | 妥当。3箇所のisContextClickOnBackgroundを削除し、記録済みcontextMenuIsBackgroundを使う。 |
| [コピー処理と対象解決の重複](https://github.com/yoshidax/folzio-dev/pull/91#discussion_r4610907964) | 妥当。PasteboardFileURLs.writeを共用し、コピー項目の文言もrepresentedObject設定後のbatchTargetsで決める。 |

- 本節の保守者承認をルート複製・ペイン外フォーカスについての設計変更として扱う。最終の整合確認と製品仕様反映で同じ条件を反映する。
- GUI確認は引き続き未実施。T016・T017・T018は未完了のままとし、修正はPRレビュー用に先行コミットする。
- 追加した回帰テストで、修正前の名前変更2件・一覧外選択3件のアサーション失敗を確認した。
  ログ: `/tmp/folzio-tak113-review-red.log`。
- 修正後の対象テストはCore 69件・4 suite、App 11件・2 suiteが通過した。
  ログ: `/tmp/folzio-tak113-review-targeted.log`。
- `swift build`: 成功（`/tmp/folzio-tak113-review-build.log`）。
- `swift test --filter 'FolzioCoreTests|FolzioAppTests' --no-parallel`: Core 1,148件・126 suite、App 117件・22 suiteが通過した。
  保守者の許容に従い性能テストはこの再検証から除外した。ログ: `/tmp/folzio-tak113-review-functional.log`。
- `scripts/dev/check-all.sh`: 全チェック成功（`/tmp/folzio-tak113-review-check-all.log`）。
- `scripts/make-app.sh`: 成功（`/tmp/folzio-tak113-review-make-app.log`）。
- `codesign --verify --deep --strict .build/Folzio.app` と `git diff --check`: 成功。
- 更新したGUI確認用アプリ: `/Users/igachan/.codex/worktrees/2347/folzio/.build/Folzio.app`。
- 更新後の実行ファイル SHA-256: `1c721637513ef1b943cddd20270162ea4cffed0a779af223f1a629689f32a9d9`。
- GUIで追加確認する点: 両ビューの単一・複数対象でルートの複製が無効なこと、ペイン外の非文字入力フォーカスでは表示中のツリーを登録対象にすること。

### Swift 6.0 のCIビルド失敗への対応（2026-11-18）

- 元の失敗: https://github.com/yoshidax/folzio-dev/actions/runs/44269880397
  CIのSwift 6.0がFileContextMenu.swiftのcompactMap(folderItem)をthrowingな関数引数と判定し、ビルドが失敗した。
  性能テストの閾値とは無関係で、通常テストの実行前に停止していた。
- 保守者が導入したSwiftlyとSwift 6.0.0を使い、純粋なSwiftの最小例で同じrethrows診断を再現した。
  MainActorのメソッド参照を明示的なクロージャに変えた例とループの例は型検査に通り、MainActorを外した比較例も通った。
- ローカルのXcodeはSwift 6.4.2で、新しいmacOS SDKをSwift 6.0で読むと別の互換性エラーになる。
  最小例の成功とアプリ全体の成功を区別し、全体はXcode 16.0を使うCIで確認する。
- 保守者の「CIで確認」の指示に従い、FileContextMenu.refreshItemsの変換を明示的なクロージャへ変更した。
  メニューの順序・操作・対象条件は変えない。
- ローカルのswift build: 成功（`/tmp/folzio-tak113-swift60-fix-build.log`）。
- メニュー関連の回帰テスト: Core 6件・1 suite、App 11件・2 suiteが通過した。
  コマンド: `swift test --filter 'FolderContextMenuTests|FileListContextClickTests' --no-parallel`。
  ログ: `/tmp/folzio-tak113-swift60-fix-menu-tests.log`。
- Swift 6.0の修正形の最小例: 型検査成功（`/tmp/folzio-tak113-compactmap-pure-fixed.swift`）。
- `scripts/dev/check-all.sh` と `git diff --check`: 成功（`/tmp/folzio-tak113-swift60-fix-check-all.log`）。
- 修正はレビュー用のPR #91へ先行コミットする。CIの結果はPR本文に記録し、GUI確認とPhase完了は未完了のまま残す。
