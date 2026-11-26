# Tasks: アップデートの確認

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[research.md](research.md)、[data-model.md](data-model.md)、
[update-check.md](contracts/update-check.md)、[quickstart.md](quickstart.md)

**Tests**: 憲章 IV に従い、次を自動テストで確かめる。Swift のビルドとテストは CI で、GUI は保守者が確認する。
- Core: 版の解析・比較、応答の評価（異常系を含む）、自動の確認の判定、設定の読み書き
- App: メニューの位置と有効の条件、起動時の動作
- Python: ネットワーク API の検査

## Phase 0: 設計レビュー

- [X] T000 [MANUAL] 保守者が `specs/TAK-95-update-check/` の spec・plan・tasks と analyze の結果を確認し、実装の開始を承認する（2026-11-26、このチャット。2回目のレビューで起動時の自動の確認を加えた設計を承認）

## Phase 1: Setup（憲章と検査）

- [X] T001 `.specify/memory/constitution.md` の原則 I を改める。版を 1.6.0 にし、Sync Impact Report を更新する（research.md R8）
  - 「ユーザーの明示的な操作でのみ通信を開始」に、「ユーザーが明示的に有効にした自動の処理」を加える
  - 許す通信を最新の公開版の確認に限り、送らない情報・自動の確認の上限・更新の適用をしないことを書く
  - マージ前のゲートの「外部通信」の行を改める
- [X] T002 `scripts/dev/tests/test_check_no_network.py` に次のテストを足す（contracts/update-check.md の表）
  - 許すもの: `UpdateSource.swift` の API の URL の行、`URLSessionUpdateTransport.swift` の `URLSession` の行
  - 拒むもの: この2ファイルでの別の URL・`NWConnection`・`import Network`、ほかのファイルでの `URLSession`
- [X] T003 `scripts/check-no-network.sh` の例外を、ファイルと許す行の条件の一覧に改め、T002 の2ファイルを足す（FR-041・FR-176・SC-246）
  - 既存の2つの例外の動作を保つ。コメントは英語
  - `python3 -m unittest scripts/dev/tests/test_check_no_network.py` を通す

## Phase 2: Foundational（Core）

- [X] T004 [P] `Tests/FolzioCoreTests/AppVersionTests.swift` に、版の解析と比較のテストを足す（EC-293）
  - 解析: 正しい形、`v` 付き、空白、3つでない、数字以外、巨大な数
  - 比較: 1.10.0 > 1.9.0、等しい、各部分の順
- [X] T005 [P] `Sources/FolzioCore/Update/AppVersion.swift` に `AppVersion`（data-model.md）を実装する
- [X] T006 `Tests/FolzioCoreTests/UpdateCheckerTests.swift` に、固定の応答を返す transport で次のテストを足す（FR-423〜FR-426、EC-292・EC-294）
  - 結果: 新しい版・同じ版・古い版（FR-425）
  - 失敗: transport の失敗、404・403・429・500、HTTP でない応答、1 MiB 超、JSON でない、`tag_name` なし、形の違うタグ
  - 要求: URL、ヘッダー（`User-Agent`・`Accept`・`X-GitHub-Api-Version`・`Accept-Language`）、タイムアウト 15 秒
  - Release ページの URL
- [X] T007 `Sources/FolzioCore/Update/UpdateSource.swift` に要求と Release ページの URL を実装する
  - API の URL のリテラルはこの1行だけ。Release ページは `AboutInfo.repositoryURL` から組み立てる
- [X] T008 `Sources/FolzioCore/Update/UpdateChecker.swift` に `UpdateTransport`・`UpdateCheckResult`・`UpdateCheckFailure`・
  `UpdateChecker.check` を実装する（data-model.md）
- [X] T009 [P] `Tests/FolzioCoreTests/SettingsStoreTests.swift` に、3つのキーのテストを足す
  - 読み: 未設定・正しい値・不正な型（Bool でない・Date でない・形の違う版）
  - 書き: `notAsked` でキーを消す
- [X] T010 [P] `Sources/FolzioCore/Settings/SettingsStore.swift` に、`AutomaticUpdateCheckSetting` と3つのプロパティを実装する（data-model.md）
- [X] T011 `Tests/FolzioCoreTests/AutomaticUpdateCheckPolicyTests.swift` に、次の分岐のテストを足す（FR-430〜FR-433、EC-296〜EC-299、
  SC-247・SC-248）
  - `launchAction`: 版なし、未回答で邪魔をしない状態とそうでない状態、無効、有効の期限内と期限切れ
  - `isDue`: ちょうど 24 時間、前回が未来
  - `automaticOutcome`: 未通知の新しい版、通知済みの版、より新しい版、最新、失敗、邪魔をしない状態でないとき
- [X] T012 `Sources/FolzioCore/Update/AutomaticUpdateCheckPolicy.swift` に `AutomaticUpdateCheckPolicy` を実装する（data-model.md）

## Phase 3: User Story 1 - 新しい公開版を知り、入手先を開く (Priority: P1) 🎯 MVP

**Goal**: メニューから確認し、新しい版があれば Release ページを開ける。

**Independent Test**: 最新の公開版より古い版のアプリで項目を選び、ダイアログから Release ページを開ける。

- [ ] T013 [P] [US1] `Sources/FolzioLocalization/` に、contracts/update-check.md の「ダイアログの文言」の全行を英日で足す
  - 対象: `TextKey.swift` と、`Resources/en.lproj`・`Resources/ja.lproj` の `Localizable.strings`
  - 範囲: メニュー項目、3種類の結果、同意、設定の文言と、翻訳者向けの説明
- [ ] T014 [P] [US1] `Sources/FolzioApp/Update/URLSessionUpdateTransport.swift` に、ephemeral の `URLSession`（Cookie・
  キャッシュなし）で `UpdateTransport` を実装する（research.md R4）
- [ ] T015 [US1] `Sources/FolzioApp/Update/UpdateCheckController.swift` に、メニューの確認を実装する
  - 確認中の状態、`UpdateChecker.check` の呼び出し、結果ごとの `NSAlert`（`runModal`）
  - 「ダウンロードページを開く」で `NSWorkspace` に URL を渡す。新しい版を知らせたら知らせた版を保存する（FR-432）
  - ダイアログ・URL を開く処理・`now`・`canPresent` はテストで差し替えられるクロージャにする
- [ ] T016 [US1] `Sources/FolzioApp/App/MainMenu.swift` と `Sources/FolzioApp/App/AppDelegate.swift` を変える
  - `MainMenu.swift`: About の直後に「アップデートを確認…」を足し、`refreshTitles` の表に加える
  - `AppDelegate.swift`: `checkForUpdates(_:)` と `validateMenuItem` の条件（FR-422）を足す
- [ ] T017 [US1] `Tests/FolzioAppTests/UpdateCheckMenuTests.swift` に、メニューの確認のテストを足す
  - 項目: 位置（About の直後・区切り線の前）、ショートカットなし、版がない・形の違う版で無効、確認中は無効
  - 新しい版の結果: 既定のボタンで URL を開き、取り消しのボタンでは開かない。知らせた版を保存する
  - 通信: コントローラの生成とメニューの構築では、transport が呼ばれない（SC-244）

## Phase 4: User Story 2 - 最新・確認できなかったことを知る (Priority: P2)

**Goal**: メニューから確認したとき、最新・失敗のときも結果を知り、作業を続けられる。

**Independent Test**: 最新の版と、ネットワークを切った状態で選び、それぞれのダイアログが出る。

- [ ] T018 [US2] `Tests/FolzioAppTests/UpdateCheckMenuTests.swift` に、`upToDate` と `failed` の結果のテストを足す
  - 「OK」だけのダイアログを出し、URL を開かない
  - 結果の後に項目が再び有効になる
  - T015 の実装で足りなければ直す

## Phase 5: User Story 3 - 起動時に自動で新しい版に気付く (Priority: P1)

**Goal**: 初回に同意を尋ね、同意した利用者には起動時に新しい版を各版1回知らせる。

**Independent Test**: 設定を消して起動し、同意すると新しい版のダイアログが出る。次の起動では同じ版について出ない。

- [ ] T019 [US3] `Sources/FolzioApp/Update/UpdateCheckController.swift` に、起動時の動作を足す（FR-430〜FR-433）
  - `performLaunchAction()`、同意のダイアログ、自動の確認
  - 自動の確認の結果は `AutomaticUpdateCheckPolicy` に従って保存・表示する
- [ ] T020 [US3] `Sources/FolzioApp/App/AppDelegate.swift` の `applicationDidFinishLaunching` で、メインウィンドウの表示の後に
  `performLaunchAction()` を呼ぶ
  - `canPresent` に `mainWindowController.canShowShortcuts` を渡す
- [ ] T021 [US3] `Sources/FolzioApp/Settings/SettingsWindowController.swift` に、区分「アップデート」とチェックボックスを足す（FR-434）
  - 間隔・Tab の移動順は contracts/update-check.md の「設定」のとおり
  - `syncFromStore` と表示言語の切り替えに対応する
- [ ] T022 [US3] `Tests/FolzioAppTests/UpdateCheckLaunchTests.swift` に、起動時の動作のテストを足す
  - 同意のダイアログ: 未回答で出る、答えずに終了すると次回も出る
  - 答え: 「自動で確認する」で保存してすぐ確認する、「確認しない」で保存して通信しない
  - 自動の確認: 期限内なら通信しない、通知済みの版を出さない、最新・失敗で何も出さない
  - 邪魔をしない状態でないとき: 尋ねず・知らせず・保存しない
  - 実行中の版がないとき: 何もしない

## Phase 6: Polish（文書と検証）

- [ ] T023 [P] `README.md` と `README.ja.md` を同じ内容で改める（FR-429）
  - 冒頭の「ネットワーク通信なし」の表記
  - メニューと自動の更新の確認の案内
- [ ] T024 [P] `docs/usage.md` と `docs/usage.ja.md` を同じ内容で改める（FR-429）
  - 「Checking the Version」「バージョンの確認」の節: メニューの確認、起動時の自動の確認と同意、設定、通信の範囲
  - 「Where Settings Are Stored」「設定の保存先」の節: 3つのキー
- [ ] T025 `scripts/dev/check-all.sh` を実行して通す（ネットワーク API の検査・README・コメントの英語）
- [ ] T026 作業ブランチに push し、Draft の PR の CI で `swift build`・`swift test`（通常と性能）の成功を確かめる
  - 性能テストはログの末尾で件数を確かめる
- [ ] T027 [MANUAL] 保守者が `specs/TAK-95-update-check/quickstart.md` の「保守者のローカルでの確認（GUI）」の 1〜17 を行い、
  結果を報告する（SC-243・SC-245・SC-247 と GUI の受け入れシナリオ）
  - 報告を `specs/TAK-95-update-check/checklists/validation.md` に記録する

## Phase 7: 製品仕様への反映（PR の最後）

- [ ] T028 spec.md の「反映先」の表の項目を `specs/product/` へ反映し、保守者の承認を得る
  - 反映の前に `git merge origin/master` と `scripts/dev/check-spec-ids.sh` を実行する
  - 反映先は `specs/product/` の各ファイルと `specs/product/contracts/`
  - spec.md の冒頭に移行済み・凍結の注記を入れる
  - `python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-spec-ids.sh` を通す
  - 差分を保守者に示す

## Dependencies & Execution Order

- 実装は Phase 0 の承認の後に始める。
- Setup: T001 は独立。T002 → T003。
- Core:
  - T004 と T005 は並行できる
  - T006 → T007 → T008（T008 は T005 に依存）
  - T009 と T010 は並行できる
  - T011 → T012（T012 は T005・T008・T010 に依存）
- US1:
  - T013・T014 は T008 の後に並行できる
  - T015 は T008・T012・T013・T014 に依存
  - T016 は T015 の後、T017 は T016 の後
- US2: T018 は T017 の後。
- US3: T019 は T015 の後。T020・T021 は T019 の後。T022 は T020 の後。
- Polish:
  - T023・T024 はいつでも
  - T025 は T003・T023・T024 の後
  - T026 は全実装の後、T027 は T026 の後
- T028 は T027 の後（PR の最後の作業）。

## Implementation Strategy

- MVP は Phase 1〜3（US1）。US3（自動の確認）は、保守者の判断で US1 と同じ P1 とする。
- Cloud では Swift を実行できない。Core のテストと実装を先に書き、まとめて push して CI で確かめる。
- Phase の区切りでコミットする。CI の同じ原因の失敗を 3 回直しても解決しなければ、止めて報告する。
