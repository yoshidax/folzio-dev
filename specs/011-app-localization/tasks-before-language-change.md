# Tasks: 日本語・英語への国際化

> **再設計中**: 2026-10-28 のユーザー指示により、OS の優先言語からの決定をやめ、アプリの設定で英語・日本語を選び即時反映する。以下の旧方式のタスクや GUI 確認は未改訂であり、そのまま実行・完了判定しない。設計改訂後に依存関係と検証を更新する。

## 再設計の作業候補（依存順・未確定）

- [ ] T084 `specs/011-app-localization/` の仕様・設計・契約・既存タスクの旧方式を整理し、設定値、英語の既定値、即時反映、翻訳欠落時の英語、OS が提供する文言の境界を一貫させる。
- [ ] T095 [MANUAL] T084 の後、ユーザーに `specs/011-app-localization/spec.md`・`plan.md`・`tasks.md` と検証手順の変更をレビューしてもらい、実装開始の承認または修正点の報告を受ける。
- [ ] T085 言語の識別子の保存・復元、未設定／不正値の英語、OS の言語からの独立、他の設定に影響しないことの Core 自動テストを作る。
- [ ] T086 `SettingsStore` に表示言語を追加し、設定ウインドウの言語選択から読み書きする。初期表示と再起動後の復元を確かめる。
- [ ] T087 表示言語を変更可能な共有状態へ移し、設定変更時に MainActor で各表示へ伝える。言語を固定した `Localizer.shared` とグローバル `l10n` の呼び出しを追従させ、地域書式を再計算する。
- [ ] T088 メニュー・ツールバー・設定・ツリー・ファイルリスト・検索・プレビュー・エラーとアクセシビリティの更新方法を実装する。選択、スクロール、編集途中の値、検索・再生・スライドショーなど既存状態を保持する。
- [ ] T089 `Sources/MediaViewerCore/Model/MediaFile.swift`・`FileSystem/DirectoryLister.swift`・`Archive/ArchiveIndex.swift`・`Browser/BrowserModel.swift` と該当テストで種類名の OS 由来とアプリの代替名を区別する。既存一覧・検索結果・zip の表示と種類順を言語変更に追従させ、OS 由来の名前、選択、進行中処理を保つ。古い非同期結果による巻き戻しを防ぎ、大量データの処理を UI スレッド外で行う。
- [ ] T090 翻訳欠落時の英語フォールバック、切り替え前後の複数形・書式・新規作成する UI、言語変更の通知と保持できる状態を自動テストする。管理元は `.strings`／`.stringsdict`。
- [ ] T091 README 両言語と quickstart を更新し、既定言語・設定での切り替え・即時反映・保存を説明する。旧 `-AppleLanguages` 依存の言語検証を設定操作に置き換え、地域設定だけ OS の手段で検証する。
- [ ] T092 `swift build`、`swift test`、no-network、README 同期、配布用アプリ作成とバンドル確認を順に実行し、結果を記録する。
- [ ] T093 [MANUAL] 最終ビルドで英語→日本語→英語を設定画面から切り替え、各画面・編集中と閲覧中の状態・再起動後の復元・OS 言語からの独立を `specs/011-app-localization/quickstart.md` で確認し、結果を報告する。
- [ ] T096 [MANUAL] `specs/011-app-localization/quickstart.md` Q8 に従い、両言語で VoiceOver の読み上げを確認し、結果を報告する。
- [ ] T094 T092・T093・T096 の結果と各受け入れ基準の証拠を `specs/011-app-localization/quickstart.md` に記録し、旧タスクとの対応を整理した上で converge と product 反映のレビューへ進む。

**Input**: `specs/011-app-localization/` の plan.md、spec.md、research.md、data-model.md、contracts/localization.md、contracts/app-bundle.md、quickstart.md。
**Prerequisites**: 上記の設計文書、`.specify/memory/constitution.md` v1.2.0、`AGENTS.md`。既存仕様は spec.md 冒頭の基準（`specs/product/overview.md` の FR-040・041、`contracts/keyboard-and-menus.md`・`settings.md`・`app-bundle.md`、`preview.md` の FR-138、`search.md` の FR-084 ほか）を併読する。
**Tests**: FR-157・research.md R10・憲章 IV が求める自動テスト（R10 の 1〜10）を含む。Swift Testing を使い、`Tests/MediaViewerCoreTests/Localization/` に置く。外部パッケージは追加しない。
**Organization**: 本 feature のストーリーは **US17（P1）・US18（P1）・US19（P2）・US20（P2）**。既存のストーリー番号を維持し、US1 へ振り直さない。
**Design note**: 表示言語の決定・翻訳の参照・Core の値の文言化・`.app` への lproj の同梱は、どのストーリーも前提とするため Phase 2（Foundational）に置く。各ストーリーの Phase は、その上に画面の文言・書式・アクセシビリティを積む。

## Format: `[ID] [MANUAL?] [P?] [Story?] Description`

- 全タスクは `- [ ] Tnnn ...`。ユーザーの操作・報告が必要なら **ID の直後**に `[MANUAL]` を置く。ストーリー Phase のタスクだけ `[US17]`〜`[US20]` を付ける。
- `[MANUAL]` は GUI 起動、目視、VoiceOver、システム設定の変更、ユーザーによる設計レビュー。実装・自動テスト・文書作成・コミットを同じタスクへ混ぜない。報告の受領は手動タスク、文書への転記は別のタスクとする。
- **分類は実装前の設計レビュー T002 で確認する。実装中は `[MANUAL]` を追加・削除・移動しない。** 分類の不備が見つかったら該当作業を完了扱いにせず、設計レビューへ戻して扱う。自動化できたという理由で手動確認を代替しない。
- ユーザーの報告がない `[MANUAL]` は未チェックにする。非対話実行でも省略・推測による合格にしない。非手動タスクの完了で手動タスクをチェックしない。
- `[P]` は依存が満たされた後、別ファイルで作業できる候補。既定は順次実装。並列化を明示する場合だけ `AGENTS.md` に従い独立 worktree と `agent/<task-id>-<slug>` を使う。
- **翻訳単位を足すタスクは、すべて `Sources/MediaViewerLocalization/TextKey.swift` と管理元（下の「R1 試作の結果」）を編集するため並列化しない。**
- T082・T083 は `/speckit-analyze` の指摘（G1）で後から加えたタスクで、既存の ID を振り直していない。実行の順は ID の順ではなく、各 Phase の並びと「Dependencies & Execution Order」に従う。

## Path Conventions

- 文言・表示言語・書式・Core の値の文言化: `Sources/MediaViewerLocalization/`（Foundation のみ。AppKit を import しない）。
- 判断ロジック: `Sources/MediaViewerCore/`（AppKit を import しない。表示言語に依存する文字列を返さない）。
- 描画・入力: `Sources/MediaViewerApp/`（MainActor）。
- テスト用の固定値・一時バンドル: `Sources/FixtureKit/`。自動テストは一時ディレクトリに生成し、テスト後に削除する。
- 自動検証: `Tests/MediaViewerCoreTests/Localization/`、既存の `Tests/MediaViewerCoreTests/`、`Tests/MediaViewerPerformanceTests/`。
- 翻訳単位を足すときは、毎回 (1) `TextKey` のケース（rawValue は `<領域>.<項目>[.<変化>]`、引数の並び `arguments`、翻訳者向けの `comment`）、(2) 管理元の日本語・英語の訳（`state` は `translated`、`comment` は `TextKey` と同じ）、(3) 呼び出し側の置き換えを同じタスクで行う。日本語の訳は本変更の前の文言をそのまま使い、英語の訳は `contracts/localization.md` §5 の用語対応表に従う。
- 実装中の仕様文書の変更は、tasks.md のチェックと「R1 試作の結果」欄、quickstart.md の記録欄、T047 で明示する `contracts/localization.md` §5 への追記、T083 での §5 の英語の修正、下の英語の文言の修正だけ。product 反映と feature 凍結は検証完了後の T079・T080 で行う。
- 英語の文言の修正（A-88）: 実装の前の §5 のレビューは T082・T083 で行う。実装中にユーザーが手動確認（T049・T050・T056 ほか）の報告で英語の文言の修正を指示した場合は、§5 の既存の行の英語を直すことを T047 と同じ明示の例外とし、管理元の英語の訳と §5 の該当行を同じ変更で直す。修正後は T048（または修正した Phase の自動ゲート）から影響する検証をやり直し、修正後のビルドで受けた報告だけを合格とする。日本語の訳・キー・引数の数と種類・文の分け方を変える修正は、この例外に含めず設計の工程へ戻す。

## R1 試作の結果（T005・T006 で記入）

- 判定: 通常の複数形の試作は合格。件数を表示しない複数形の追加試作は不合格。`.strings` + `.stringsdict` を採用する
- 管理元: `Sources/MediaViewerLocalization/Resources/{en,ja}.lproj/Localizable.strings` と `Localizable.stringsdict`（`defaultLocalization: "en"`）
- 生成物（`swift build -c release` のリソースバンドル内の lproj とファイル名。複数形の表のファイル名を含む）: `<ターゲット名>.bundle/Contents/Resources/{en,ja}.lproj/Localizable.strings` と `Localizable.stringsdict`（Debug・Release とも同じ）。試作は `Spike_Spike.bundle`
- R4 の確認（`Bundle.preferredLocalizations(from: ["ja","en"], forPreferences:)` の戻り値。`["fr"]`・`["fr","de"]`・`[]`）: `["en"]`・`["en"]`・`["en"]`（一致がなくても空を返さず、開発言語を返す）
- 複数形の確認: 1つのキーで `%1$lld`（判定用の整数）と `%2$@`（整形済みの件数）を渡す形が、英語の 0・1・2・1000 で `other`・`one`・`other`・`other` に分かれ、`1,000` が入る。`localizedString(forKey:)` の戻り値は `%#@value@` で、`String(format:locale:arguments:)` が複数形を解決する
- 追加試作（2026-10-28）: `xcstringstool compile` は `Copy this item?`／`Copy these items?` の数値を表示しない複数形を「Plural variation requires referencing the number in the string」として拒否した。単数・複数の別キーへの分割は、件数による分岐を各呼び出し側へ広げるため採用しない。Swift Package 経由のビルド・実行は未検証
- 以降のタスクで「管理元」と書いたものは、この判定に従う

---

## Phase 1: Setup — 設計レビュー・基準確認・管理形式の試作

**Purpose**: 手動分類を実装前に確定し、既存アプリの基準状態を確かめ、R1（String Catalog の `swift build` でのコンパイル）の合否で管理形式を決める。リポジトリの Package.swift と Sources はこの Phase で変えない。

- [ ] T001 `specs/011-app-localization/quickstart.md` の末尾に「実装・検証記録」欄を追記する。Phase 別の自動コマンド（`swift build`・`swift test`・`scripts/check-no-network.sh`・`scripts/check-readme-sync.sh master`・`scripts/make-app.sh`・Q2 のバンドル確認）の結果、R1 試作の結果、ユーザー報告の受領日・macOS の版・起動の引数（`-AppleLanguages`・`-AppleLocale`）、Q3〜Q9 の項目別の合否、不合格の文言、未実施の理由の記録枠を用意し、未実施を成功で埋めない。
- [X] T002 [MANUAL] `specs/011-app-localization/tasks.md` 全件の設計レビューをユーザーに依頼し、GUI・目視・VoiceOver・システム設定の変更の独立性、ID 直後の `[MANUAL]`、文書作成との分離、依存順（特に Core の値の変更 T019〜T026 を1つの流れで行うこと）、実装中の分類固定について確認の報告を受ける。T008 以降の実装はこの確認後に開始する。
- [X] T082 [MANUAL] T002 の後、ユーザーへ `specs/011-app-localization/contracts/localization.md` §5 の用語対応表の英語の列のレビューを依頼し（A-88）、表ごとの承認、または修正する行と修正後の英語の報告を受ける。§3 の英語の書き方（Title Case・Sentence case・「…」・“ ”）と、件数の扱い（`count`／`number`）に合っているかも見てもらう。
- [X] T083 T082 の報告に従い、`specs/011-app-localization/contracts/localization.md` §5 の該当行の英語を直し、承認・修正した行を `specs/011-app-localization/quickstart.md` の記録欄に記入する。日本語の列・キー・引数の種類は変えない。修正が値の数・種類や文の分け方の変更を伴う場合は本タスクで直さず、設計の工程（`/speckit-plan`）へ戻す。修正がなければその旨を記録する。
- [ ] T003 リポジトリルートで `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/check-readme-sync.sh master` → `scripts/make-app.sh` を順に実行し、既存基準の成否と失敗内容を集める（対象: `Package.swift`、`.build/MediaViewer.app`）。GUI は起動しない。
- [ ] T004 [MANUAL] T003 成功後、ユーザーへ `cd /Users/igachan/projects/my_img_viewer` の後に `pgrep -fl MediaViewer`（残っていれば終了）→ `open .build/MediaViewer.app` を依頼し、3ペインが表示されること、メニューバー（ファイル・編集・表示・移動）と ⌘, の設定ウインドウが日本語で表示されることの報告を受ける。
- [ ] T005 R1 の試作を行う。`.build/l10n-spike/` に使い捨ての Swift Package を作り（`swift-tools-version: 6.0`、`defaultLocalization: "en"`、ライブラリターゲットに `resources: [.process("Resources")]`、`Resources/Localizable.xcstrings` に `sourceLanguage: "en"`・`extractionState: "manual"` の通常のキー2つと、`%1$lld`（複数形の判定）と `%2$@`（整形済みの件数）を持つ複数形のキー1つ（英語は `one`／`other`、日本語は `other`）、それを読む実行ファイル）、`swift build` と `swift build -c release` を実行する。research.md R1 の合格基準 1〜3（`<名前>.bundle/Contents/Resources/{ja,en}.lproj/` の `Localizable.strings` と複数形の表、言語別 lproj から `localizedString(forKey:value:table:)` で両言語を取得でき英語の複数形が 0・1・2・1000 で正しく変わり `String(format:locale:arguments:)` で `1,000` が入ること、release でも同じ構成）をすべて確かめる。生成物の実際のパスとファイル名（複数形の表を含む）を控える。同じ実行ファイルで、research.md R4 の `Bundle.preferredLocalizations(from: ["ja","en"], forPreferences:)` に `["fr"]`・`["fr","de"]`・`[]` を与えた戻り値を控える（一致がなくても空を返さないことの確認。T016 の判定の前提）。リポジトリの `Package.swift`・`Sources/` は変更しない。
- [ ] T006 T005 の結果を本ファイルの「R1 試作の結果」欄（判定・管理元・生成物のパスとファイル名・R4 の確認）と `specs/011-app-localization/quickstart.md` の記録欄に記入する。不合格なら管理元を `.strings` + `.stringsdict` に切り替える旨を明記し、以降のタスクの文言は書き換えない（「管理元」の参照で吸収する）。
- [ ] T007 T001〜T006・T082・T083 完了後、`specs/011-app-localization/` の設計文書一式（spec.md・plan.md・research.md・data-model.md・contracts/・quickstart.md・checklists/・tasks.md）を差分確認し、Phase 1 のコミットにする。`.build/l10n-spike/` はコミットしない。push は行わない。

**Checkpoint**: 手動分類を確認済み、§5 の英語をレビュー済み、既存アプリの基準を通過、管理形式が確定。文書を作成しただけでは確認済みにしない。

---

## Phase 2: Foundational — Localization ターゲット・Core の値・`.app` への同梱

**Purpose**: どのストーリーにも必要な基盤を作る。`MediaViewerLocalization` ターゲット、翻訳単位の一覧と自動検証、表示言語と参照先の決定、Core が返す日本語の文字列の値への置き換え、`.app` への lproj の同梱。この Phase の終わりでも、アプリの見た目は本変更の前と同じ日本語であること。

**⚠️ CRITICAL**: この Phase が終わるまでストーリーの作業を始めない。T019〜T026 の間は Core の API の変更で App のビルドが通らない期間があるため、この範囲を1つの流れで行い、途中でコミットしない（Phase 2 のコミットは T032）。このため T019〜T026 は、担当ごとのコミットと統合のたびの `swift build`／`swift test` を求める worktree の並列化（`AGENTS.md`）の対象外とし、`[P]` を付けない。

### 骨組み

- [ ] T008 `Package.swift` に `defaultLocalization: "en"` を加え、`.target(name: "MediaViewerLocalization", dependencies: ["MediaViewerCore"], resources: [.process("Resources")])` を追加する。`MediaViewerApp` の依存に `MediaViewerLocalization` を、`MediaViewerCoreTests` の依存に `MediaViewerLocalization` を加える。`FixtureKit` の依存に `MediaViewerCore` を加える（T023 の `KindNames` の固定値のため）。管理元を空の状態で作る（String Catalog なら `{"sourceLanguage":"en","strings":{},"version":"1.0"}`、lproj なら空の `Localizable.strings`）。`swift build` が通ることを確かめる。
- [ ] T009 `Sources/MediaViewerLocalization/TextKey.swift` に `TextArgument`（`text`＝`%n$@` で文字どおり入れる値、`count`＝`%n$lld` の複数形の判定用整数と `%m$@` の整形済み件数の2つ、`number`＝`%n$@` の整形済み件数だけ）と、`TextKey: String, CaseIterable, Sendable`（`arguments: [TextArgument]`、`comment: String`）を作る。最初のケースは Core の値と種類名の翻訳単位とし、data-model.md「Core の値」の表と contracts/localization.md §5 の「名前の検証・ファイル操作・zip の理由」「検索」の起点の検証、「ファイルリスト・ツリー・プレビュー」の空状態（`empty.filter.images`・`empty.filter.videos`・`empty.folderNotFound`）・プレビューの理由・種類名のフォールバックに対応させる（領域の接頭辞は `error`・`empty`・`preview`・`kind`。例: `error.searchRoot.empty`・`error.searchRoot.noUsableFolder`・`error.zip.cannotOpen`（`text` 1つ）・`error.zip.corrupted.headerDamaged`・`error.name.forbiddenCharacter`・`error.operation.trashExistingFailed`（`text` 1つ＝OS の理由）・`preview.failure.unsupportedFormat`・`kind.folder`・`kind.zipArchive`）。

### Tests for Foundational（先に書き、未実装による失敗を確認する）

- [ ] T010 [P] `Tests/MediaViewerCoreTests/Localization/CatalogConsistencyTests.swift` を新設し、research.md R10 の 1〜3 を実装する。(1) リポジトリの管理元を `#filePath` からの相対位置で読み、`TextKey.allCases` と突き合わせて、キーの欠け・`TextKey` に無いキー（未使用）・`ja`／`en` の訳の欠け・`state` が `translated` でない訳・複数形の `other` の欠け・英語の `one` の欠け・空の `comment` を検出する。(2) 各訳（複数形の各形を含む）の書式指定がすべて位置指定で、位置と種類が `TextKey.arguments` と一致することを確かめる（`count` の整数は複数形の判定にだけ使い、表示しない形を許す）。(3) 各ケースの名前（`String(describing:)`）が `Sources/MediaViewerApp/` または `Sources/MediaViewerLocalization/`（`TextKey.swift` を除く）で `.<ケース名>` として参照されていることを確かめる。失敗メッセージには該当するキーと言語を出す。
- [ ] T011 [P] `Tests/MediaViewerCoreTests/Localization/CompiledBundleTests.swift` を新設し、R10-4 を実装する。`MediaViewerLocalization` が公開するパッケージのバンドルの参照（T014 の `LocalizationBundle.packageBundle`）の `ja.lproj`・`en.lproj` から全キーを `localizedString(forKey:value:table:)` で引き、キーそのもの・空文字・`value:` に渡した番兵を返さないこと、書式を適用した後に置換されていない `%` が残らないことを確かめる。
- [ ] T012 [P] `Sources/FixtureKit/LocalizationFixtures.swift` に、一時ディレクトリへ `ja.lproj`・`en.lproj` の `Localizable.strings` を任意の内容で書いたバンドルを作るヘルパーを追加し、`Tests/MediaViewerCoreTests/Localization/FallbackTests.swift` を新設して R10-5 を実装する。英語の訳を欠かせたキーは日本語の訳が返り、キー・空欄が返らないこと（EC-110）、両方にあるキーは表示言語の訳が返ることを確かめる。一時バンドルはテスト後に削除する。
- [ ] T013 [P] `Tests/MediaViewerCoreTests/Localization/DisplayLanguageTests.swift` を新設し、R10-9 を実装する。`DisplayLanguage.resolve(supported: ["ja","en"], preferences:, development: "en")` に contracts/localization.md §1 の8通り（`["ja"]`→ja、`["en"]`→en、`["en-GB"]`→en、`["fr","en"]`→en、`["fr"]`→en、`["zh-Hans","ja"]`→ja、アプリごとの言語を先頭に置いた `["ja","en"]`→ja・`["en","ja"]`→en）と、`en-IN`・`en-AU`・`ja-JP`、対応言語を含まない `["fr","de"]`→en、空の並び→en を与え、期待した言語になることを確かめる。
- [ ] T014 [P] `Tests/MediaViewerCoreTests/Localization/FormattingTests.swift` を新設し、`FormattingLocale.resolve(current:displayLanguage:)` と `Localizer.count(_:)` を検証する。`current` の言語が表示言語と同じならそのロケールを返し、違えば言語だけを置き換えて地域・`hourCycle`・`firstDayOfWeek`・暦・数字の体系を引き継ぐこと（置き換える組み合わせ: `ja_JP`＋表示言語 en → 地域 JP・`ja_JP` と同じ `hourCycle`（24時間表示）、`en_US`＋表示言語 ja → 地域 US・`en_US` と同じ `hourCycle`（12時間表示）、`fr_FR`＋表示言語 ja。置き換えない組み合わせ: `en_JP`＋表示言語 en、`ja_US@hours=h23`＋表示言語 ja）、件数 `1234` が `en_US`・`ja_JP` で `1,234`、`de_DE` で `1.234` になることを確かめる（日時・割合は US19 の T061 で足す）。

### Localization の実装

- [ ] T015 [P] `Sources/MediaViewerLocalization/LocalizationBundle.swift` を実装する。`resolve(main: Bundle = .main) -> Bundle` は、`main` の `en.lproj` に `Localizable` の表があれば `main`（`.app`）、無ければ `packageBundle`（`Bundle.module`）を返す。`.app` の経路では `Bundle.module` を評価しない。テストと `swift run` 用に `public static var packageBundle: Bundle` を公開する（research.md R3）。
- [ ] T016 [P] `Sources/MediaViewerLocalization/DisplayLanguage.swift` を実装する。`resolve(supported:preferences:development:)` は `Bundle.preferredLocalizations(from:forPreferences:)` の先頭を候補とし、候補の言語コードが `preferences` のいずれかの言語コード（`Locale.Language(identifier:).languageCode`）と等しいときだけ返す。等しくなければ（優先言語の言語コードが対応言語のどれとも一致しない。T005 で控えた戻り値のとおり、このメソッドは該当なしでも空を返さない）`development` を返す（research.md R4、data-model.md）。`supported` は参照先バンドルの `localizations` から `Base` を除いたもの、`development` は `developmentLocalization`。言語の名前で分岐しない（FR-156）。保存しない（T013 を通す）。
- [ ] T017 [P] `Sources/MediaViewerLocalization/FormattingLocale.swift` を実装する。`resolve(current:displayLanguage:)` は research.md R7 のとおり `Locale.Components(locale:)` の言語だけを置き換える。引き継ぐ項目は、`Locale.Components(locale:)` が値を持たない場合も `current` の実効値（`hourCycle`・`firstDayOfWeek` など）で設定する（置き換えたロケールの既定の書式に頼らない）。`count(_ n: Int, locale:)` は `IntegerFormatStyle` の `.number.locale(locale)` で整形する。`Locale.autoupdatingCurrent` を使わない（EC-108）（T014 を通す）。
- [ ] T018 `Sources/MediaViewerLocalization/Localizer.swift` を実装する。`Localizer`（`Sendable`）は `language`・表示言語の lproj のバンドル・英語（開発言語）の lproj のバンドル・書式のロケールを持つ。`text(_ key: TextKey, _ args: …)` は表示言語の lproj で引き、無ければ英語の訳を `value:` に渡して代わりに使い（EC-110）、引数を位置指定の書式で入れる（ユーザーデータは常に引数として渡し、書式文字列にしない。EC-109）。`count` 引数には整数と `count(_:)` の整形結果の2つを渡す。デバッグビルドでは引数の数と種類を `arguments` と照合する（`assert`）。`count(_:)` を公開する。`public static let shared` は起動時に1回、`LocalizationBundle.resolve()`・`DisplayLanguage.resolve(...)`（`Locale.preferredLanguages`）・`FormattingLocale.resolve(current: .current, ...)` から作り、起動中は変えない。テスト用にバンドル・言語・ロケールを与えるイニシャライザを持つ。T009 のキーの日本語・英語の訳を管理元に入れる（日本語は Core の現行の文言をそのまま、英語は §5）。T010（(3) のソースの参照は Core の値のキーを使う T025 の後に通る）と T011〜T014 が通ることを確かめる。

### Core の値への置き換え（research.md R8、data-model.md）

- [ ] T019 `Sources/MediaViewerCore/Search/SearchRoot.swift` の `SearchRootError.message` を削除し、`Sources/MediaViewerCore/Search/SearchFolderInitialLocation.swift` の「利用できるフォルダが見つかりません」を理由の値（`noUsableFolder`）にする。日本語の文字列を比べている `Tests/MediaViewerCoreTests/SearchRootTests.swift`・`SearchFolderInitialLocationTests.swift`・`SearchFolderPickerFixtureTests.swift`・`BrowserModelSearchTests.swift` の該当箇所を値の比較へ書き換える（検索の一致判定は変えない。EC-112）。
- [ ] T020 `Sources/MediaViewerCore/Archive/ArchiveError.swift` に `ArchiveCorruption`（data-model.md の14ケース: 展開の開始不可・圧縮データの破損・データの途中終了・圧縮データの途中終了・ヘッダの破損・位置の不正・中央ディレクトリが大きすぎる・場所の不正・項目が見つからない・サイズの不一致・データがファイルの外・読み込みの中止・読み出しの失敗・読み込み不可）を追加し、`.corrupted(String)` を `.corrupted(ArchiveCorruption)` に、`message` を削除する。`InflateCursor.swift`・`ArchiveEntryStream.swift`・`ZipStructure.swift`・`ZipArchiveReader.swift`・`ArchiveFile.swift` の `throw .corrupted("…")` を対応するケースに置き換える。`Tests/MediaViewerCoreTests/` の `ZipArchiveReaderTests.swift`・`ZipStructureTests.swift`・`InflateCursorTests.swift`・`ArchiveEntryStreamTests.swift`・`ArchiveAssetLoaderTests.swift`・`ArchiveIndexTests.swift` の日本語の比較を値の比較へ書き換える。zip の名前の文字コードの判定（FR-074）は変えない。
- [ ] T021 `Sources/MediaViewerCore/Operations/NameValidation.swift` に `NameValidationFailure`（`empty`・`forbiddenCharacter`・`leadingDot`・`duplicate`・`becomesPackage`）を追加して `.invalid(reason: String)` を `.invalid(NameValidationFailure)` にする。`OperationFailureReason`（`noDestination`・`destinationNotFound`・`sourceNotFound`・`intoItself`・`invalidName(NameValidationFailure)`・`sameNameExists`・`sameNameAtDestination`・`trashExistingFailed(systemReason: String)`）を追加し、`OperationFailure` の `reason` をこの型にする。`Sources/MediaViewerCore/Operations/FileOperationService.swift` の12か所の `OperationFailure(reason: "…")` を置き換え、ゴミ箱の失敗は `error.localizedDescription` を `systemReason` にそのまま入れる（EC-111）。「複製」の「名前 2」と衝突時の「両方残す」の名前の規則は変えない（FR-018、EC-113）。`NameValidationTests.swift`・`FileOperationServiceTests.swift` を値の比較へ書き換える。
- [ ] T022 `Sources/MediaViewerCore/Model/MediaTypeFilter.swift` の `noMatchesMessage: String?` を、空状態に表示するフィルタ（画像のみ・動画のみ）を返す値の API に改める。`Sources/MediaViewerCore/Model/BrowserState.swift` に `ListingFailure`（`folderNotFound`）と `PreviewFailure`（`unreadable`・`unsupportedFormat`・`corrupted`・`archive(ArchiveError)`）を追加し、`ListingState.failed(String)` を `.failed(ListingFailure)` に、`PreviewState.unavailable(name:reason: String)` の `reason` を `PreviewFailure` にする。`Sources/MediaViewerCore/Browser/BrowserModel.swift` の `.failed("フォルダが見つかりません")`（2か所）・`.unavailable(... reason: "対応していない形式です")`・理由の文字列を返す関数（「ファイルを読み込めません」ほか）を値に置き換える。`MediaTypeFilterTests.swift`・`BrowserModelFolderTests.swift`・`BrowserModelTests.swift`・`BrowserModelArchiveTests.swift`・`BrowserModelHistoryTests.swift` ほか該当するテストを値の比較へ書き換える（T020 の後）。
- [ ] T023 `Sources/MediaViewerCore/Model/MediaFile.swift` に `KindNames`（`folder: String`・`zipArchive: String`、`Sendable`）を追加する。日本語の既定値を持たせず、`BrowserModel` の作成時に受け取り、`Sources/MediaViewerCore/FileSystem/DirectoryLister.swift`（「フォルダ」「ZIP アーカイブ」の2か所）と、zip の索引の作成経路（`Sources/MediaViewerCore/Archive/ZipArchiveReader.swift` の `ArchiveIndex` の作成、`Sources/MediaViewerCore/Archive/ArchiveIndex.swift` の「フォルダ」）へ渡す。OS が返す `localizedTypeDescription` はそのまま使う。`Sources/FixtureKit/` に固定値 `FixtureKit.kindNames` を追加し、`BrowserModel`・`DirectoryLister`・`ArchiveIndex` を作る `Tests/MediaViewerCoreTests/` と `Tests/MediaViewerPerformanceTests/` の全箇所（`DirectoryListerTests.swift`・`ArchiveIndexTests.swift`・`BrowserModel*Tests.swift` ほか）をこれで作るよう改める（T022 の後）。
- [ ] T024 `Tests/MediaViewerCoreTests/Localization/CoreTextTests.swift` を新設し、R10-10 を実装する。`SearchRootError`・`noUsableFolder`・`ArchiveError`（`ArchiveCorruption` の全ケースを含む）・`NameValidationFailure`・`OperationFailureReason`（全ケース）・空状態のフィルタ・`ListingFailure`・`PreviewFailure`・`KindNames` について、日本語・英語の両方で空でなくキーそのものでない文言になること、日本語の文言が本変更の前の Core の文字列と一致すること（SC-067。例: `trashExistingFailed(systemReason: "X")` →「既存の項目をゴミ箱へ移動できませんでした: X」）、英語が §5 と一致することを確かめる。`KindNames` を変えても「複製」と「両方残す」で作る名前が変わらないことを確かめる（EC-113）。
- [ ] T025 `Sources/MediaViewerLocalization/CoreText.swift` を実装する。`Localizer` に `text(for:)`（T024 の各型）と `kindNames`（`kind.folder`・`kind.zipArchive` の訳）を追加する。`ArchiveError` の「zip を開けません: {理由}」は `error.zip.cannotOpen` に理由の訳を値として入れる。OS の理由は訳し直さない（EC-111）。T024 を通す。
- [ ] T026 Core の API の変更に App を追従させる。`Sources/MediaViewerApp/App/MainSplitViewController.swift`（`DirectoryLister`・`BrowserModel` の作成時に `Localizer.shared.kindNames` を渡す）、`Sources/MediaViewerApp/Search/SearchPanelController.swift`（起点の検証の理由）、`Sources/MediaViewerApp/Operations/FileOperationCoordinator.swift`・`ConfirmationPresenter.swift`（操作の失敗・名前の検証の理由）、`Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift`（名前の検証）、`Sources/MediaViewerApp/FileList/FileListViewController.swift`（種類フィルタの空状態・フォルダが見つからない）、`Sources/MediaViewerApp/Preview/PreviewViewController.swift`・`ImagePreviewView.swift`（プレビューの理由）で、Core の値を `Localizer.shared.text(for:)` で文言にする。それ以外の App の日本語の文字列リテラルはこのタスクでは変えない（US17 で扱う）。`Sources/MediaViewerCore/` に日本語の文字列リテラルが残っていないこと（コメントを除く）を `grep` で確かめる。

### `.app` への同梱（contracts/app-bundle.md）

- [ ] T027 `scripts/make-app.sh` を改める。`swift build -c release --product MediaViewerApp` の後、`--show-bin-path` の下の `my_img_viewer_MediaViewerLocalization.bundle/Contents/Resources/` にある `*.lproj`（T006 で控えた生成物）を `.app/Contents/Resources/` へコピーする。`ja.lproj`・`en.lproj` のどちらかに `Localizable.strings` または複数形の表（T006 で控えたファイル名。`Localizable.stringsdict` または同等の表）が無ければ `.app` を削除して非ゼロで終了する（contracts/app-bundle.md）。Info.plist に `CFBundleDevelopmentRegion = en` と `CFBundleLocalizations = [ja, en]` を加え、`CFBundleAllowMixedLocalizations` は加えない。コード署名（`codesign --force --sign -`）は lproj のコピーの後に行う。
- [ ] T028 T027 後、`scripts/make-app.sh` を実行し、contracts/app-bundle.md の受け入れ確認のうち GUI を使わないもの（`ls .build/MediaViewer.app/Contents/Resources/ja.lproj .build/MediaViewer.app/Contents/Resources/en.lproj` で両方に `Localizable.strings` と複数形の表があること、`plutil -extract CFBundleDevelopmentRegion raw ...` が `en`、`plutil -extract CFBundleLocalizations json -o - ...` が `["ja","en"]`、`codesign --verify --deep --strict .build/MediaViewer.app` の成功）を確かめる。

### Phase 2 の検証ゲート

- [ ] T029 `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/check-readme-sync.sh master` → `scripts/make-app.sh` と T028 の確認を順に実行する。`swift test` で R10 の 1〜5・9・10 と既存テスト（値の比較へ書き換えたものを含む）がすべて通ることを確かめる。失敗を3回修正しても解消しなければ止めて報告する。
- [ ] T030 [MANUAL] T029 成功後、ユーザーへ `pgrep -fl MediaViewer`（残っていれば終了）→ `open .build/MediaViewer.app` を依頼し、3ペインが表示され、メニュー・設定ウインドウ・空のフォルダの空状態・種類フィルタで0件の空状態・壊れた画像のプレビューのエラー・⌘F で存在しない起点を入れたときの理由が本変更の前と同じ日本語であること、内部キー（`error.` など）が出ないことの報告を受ける（フィクスチャ: `scripts/make-fixtures.sh ~/MediaViewerFixtures`）。
- [ ] T031 T028〜T030 の結果を `specs/011-app-localization/quickstart.md` の記録欄（Phase 2）へ追記する。自動検証の成功と GUI の確認を別々に記載する。
- [ ] T032 T008〜T031 完了後、`Package.swift`・`Sources/MediaViewerLocalization/`・`Sources/MediaViewerCore/`・`Sources/MediaViewerApp/`（T026 の範囲）・`Sources/FixtureKit/`・`Tests/`・`scripts/make-app.sh`・本 feature の進捗と記録を差分確認し、Phase 2 のコミットにする。

**Checkpoint**: 翻訳の基盤・自動検証・Core の値・`.app` の lproj が揃い、日本語の見た目は変わらない。ストーリーの作業を始められる。

---

## Phase 3: User Story 17 — 英語環境のユーザーが英語の UI で操作する（Priority: P1）🎯 MVP

**Goal**: アプリが管理するすべての文言（メニュー・右クリックメニュー・ツールバー・設定・列見出し・検索・空状態・確認モーダル・衝突ダイアログ・エラー）を翻訳単位にし、英語の優先言語で英語に表示する。操作・ショートカット・有効条件は変えない。表示文言で判断している箇所を識別子へ置き換える（R9）。

**Independent Test**: `-AppleLanguages '(en)'` で `.app` を起動し、quickstart.md Q3 の 1〜9 を確かめる。日本語のアプリ管理文言・内部キー・置換されていない `%@` が0件（SC-061）。

### Tests for User Story 17（先に書き、未実装による失敗を確認する）

- [ ] T033 [P] [US17] `Tests/MediaViewerCoreTests/Localization/ValueSentenceTests.swift` を新設し、R10-6 を実装する。`text` 引数を持つ全キーについて、値に `%@`・`%d`・`{0}`・`%1$@`・アラビア文字・ヘブライ文字を含めて日本語・英語で整形し、値が文字どおりに入り、書式として解釈されないことを確かめる（EC-109）。`TextKey.allCases` を `arguments` で絞って回し、後から足したキーも自動で対象になるようにする。
- [ ] T034 [P] [US17] `Tests/MediaViewerCoreTests/Localization/PluralTests.swift` を新設し、R10-7 を実装する。`count` 引数を持つ全キーについて 0・1・2・1000 件を `en_US`・`ja_JP` のロケールで両言語に整形し、英語で 1 件だけが単数形・0 件と2件以上が複数形、日本語で語形が変わらないこと、1000 が `1,000` になることを確かめる。`number` 引数を持つ全キー（`Items: {N}`・`and {N} more`・`Succeeded: {N} / Failed: {M}`・`Conflicting items: {N}` ほか）も同じく `TextKey.allCases` を `arguments` で絞って回し、0・1・2・1000 件を両言語で整形して、整形済みの件数（`1,000`）が入ること、どの件数でも文の形（語形）が変わらないことを確かめる。§5 の文例（`Copy 1 Item`／`Copy 3 Items`、`1 item`／`1,000 items`、`Showing 2 of 1,000 items`、確認の見出しの `Copy this item?`／`Copy these items?`・`Move this item?`／`Move these items?`（件数を表示しない）、`Items: 1,000`・`and 1,000 more`、日本語の `3 項目をコピー`・`1,000 件`・`コピーしますか？`）を個別に確かめる（SC-064）。

### Implementation for User Story 17（すべて `TextKey.swift` と管理元を編集するため順次）

- [ ] T035 [US17] 表示文言による探索を識別子に置き換える（R9、FR-148）。`Sources/MediaViewerApp/App/MainMenu.swift` のファイル・編集・表示・移動の各メニューと並べ替えのサブメニューに `NSUserInterfaceItemIdentifier`（例: `menu.file`・`menu.edit`・`menu.view`・`menu.view.sort`・`menu.go`）を付け、`Sources/MediaViewerApp/App/MainSplitViewController.swift` の `submenu?.title == "表示"`、`Sources/MediaViewerApp/FileList/FileListViewController.swift` の `submenu?.title == "表示"`、`Sources/MediaViewerApp/FileList/ListModeView.swift` の `submenu?.title == "表示"` と `title == "並べ替え"` を識別子での探索に改める。並べ替えの列・ツールバーの項目・保存キーの識別子は変えない。
- [ ] T036 [US17] `Sources/MediaViewerApp/App/MainMenu.swift` の文字列リテラル（33件）を `menu.*` の翻訳単位に置き換える。§5「メニューバー」の全行（アプリの Settings…／Quit MediaViewer、File・Edit・View・Go の各項目、Sort By と Name／Date Created／Kind／Location）を対象にし、ショートカット・並び・区切り線は変えない。状態で変わる項目名は同じタスクで扱う: `Sources/MediaViewerApp/App/MainWindowController.swift` のツールバーを表示／隠す（Show Toolbar／Hide Toolbar）、ゴミ箱に入れる／お気に入りから削除（Move to Trash／Remove from Favorites）の切り替え（`Sources/MediaViewerApp/App/MainMenu.swift` のメニューを開くたびに「ゴミ箱に入れる」へ戻す処理と、`Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` の ⌘⌫ の検証で項目名を変える処理）。`Sources/MediaViewerApp/App/MainSplitViewController.swift` が表示メニューに加える項目（ファイルリストのみ表示・プレビューのみ表示・ディレクトリツリー／ファイルリスト／プレビューへフォーカス・お気に入りへ移動）も同じタスクで扱う。アプリ名「MediaViewer」は訳さない（FR-147）。
- [ ] T037 [US17] `Sources/MediaViewerApp/FileList/FileContextMenu.swift` の文字列リテラル（13件）を置き換える。1件のコピーは `context.copy.single`（`text`＝ファイル名、`"{名前}" をコピー`／`Copy “{名前}”`）、複数件は `context.copy.multiple`（`count`、`{N} 項目をコピー`／`Copy {N} Item`・`Copy {N} Items`）、ツリーの Paste Here／Move Item Here を加え、メニューバーと同じ文言の項目は T036 のキーを使う。ファイル名は値として渡し、翻訳・変形しない（US17-AS2、FR-149・150）。
- [ ] T038 [US17] `Sources/MediaViewerApp/App/MainToolbarController.swift` の文字列リテラル（31件）を `toolbar.*` に置き換える。§5「ツールバー」の全行（各グループの名前・パレットの名前・ツールチップ・ショートカットの表記を含む）と、アクセシビリティのラベル・ヘルプ（ツールチップと同じ文言）を対象にする。ショートカットの記号（⇧⌘S・⌘+ など）は訳の中にそのまま書く（FR-147）。ツールバーの項目の識別子は変えない。
- [ ] T039 [US17] `Sources/MediaViewerApp/Settings/SettingsWindowController.swift` の文字列リテラル（16件）を `settings.*` に置き換える。§5「設定ウインドウ」の全行（ウインドウ名 Settings、区分 Video／File Operations／Slideshow、チェックボックス、Interval／seconds、アクセシビリティの Interval (seconds)、Repeat…、Transition と None／Crossfade／Slide／Zoom）を対象にする。切り替え間隔の値は桁区切りなしの整数のままとし、入力の解釈（`SlideshowIntervalInput`）と保存キーは変えない（US19-AS5、FR-148）。
- [ ] T040 [US17] `Sources/MediaViewerApp/FileList/ListModeView.swift`（14件）と `Sources/MediaViewerApp/FileList/ThumbnailModeView.swift`（2件）の文字列リテラルを置き換える。列見出し Name／Date Created／Kind／Location、並べ替えの選択中の列の `{列}（昇順）`／`{列}（降順）`（`list.sort.ascending`・`list.sort.descending` の `text` 1つ＝列名。`{列} (Ascending)`／`{列} (Descending)`）、サムネイルのアクセシビリティ（Thumbnail）、`..` の行のアクセシビリティ（Enclosing Folder）を対象にする。作成日の書式は US19 の T063 で扱い、このタスクでは変えない。
- [ ] T041 [US17] `Sources/MediaViewerApp/FileList/FileListViewController.swift` の文字列リテラル（19件）を置き換える。表示メニューに加える項目（サムネイル・リスト・サムネイルを拡大／縮小・画像のみ表示・動画のみ表示・zipファイルを表示。§5「メニューバー」の表示の行、T036 の `menu.*` のキー）、下部のサイズバー（サイズのラベル、サムネイルのサイズ（⌃⌘. / ⌃⌘,）のツールチップとアクセシビリティ。§5「ツールバー」のサイズの行、T038 と同じ `toolbar.*` のキー）、空状態（Loading…／Searching…／No supported media files／No matching items／Can’t access this folder）と、検索バーの文を1文1キーにする: 完了 `search.bar.results`（`text` 3つ＝キーワード・起点のフォルダ名・件数の句）、検索中 `search.bar.searching`（同じ3つ）、件数の句 `search.bar.count`（`count`。`{N} 件`／`{N} item`・`{N} items`）、上限の句 `search.bar.countLimited`（`count`＝全件と `text`＝整形済みの表示件数。`{全件} 件中 {表示} 件を表示`／`Showing {表示} of {全件} items`）。0件は専用の「該当する項目はありません」を使う（EC-114）。件数は `Localizer.shared.count(_:)` で整形する（FR-150・151）。
- [ ] T042 [US17] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` の文字列リテラル（16件）を `tree.*`・`context.*`・`a11y.*` に置き換える。列 Folders、固定の行 Favorites、ツールチップ Not accessible／Not found、右クリックメニュー（メニューバーと同じ文言は T036 のキー。⌘⌫ の検証での項目名の切り替えは T036 で置き換え済み）、名前の編集欄のアクセシビリティ Favorite name／Folder name を対象にする。お気に入りの表示名・フォルダ名は訳さない（FR-147）。
- [ ] T043 [US17] `Sources/MediaViewerApp/Search/SearchPanelController.swift` の文字列リテラル（15件）を `search.*` に置き換える。§5「検索」のシートの行（Keyword のラベル・プレースホルダ・アクセシビリティ、Search In、Choose…とヘルプ、Cancel／Search、エラーのアクセシビリティ Error）、選択パネルのタイトル・メッセージ・ボタン（Choose a Folder to Search／Choose the folder to search in.／Choose）、Couldn’t open the folder selection panel を対象にする。標準パネル自体の文言は OS に任せる（EC-111）。
- [ ] T044 [US17] `Sources/MediaViewerApp/Operations/ConfirmationPresenter.swift`（17件）と `Sources/MediaViewerApp/Operations/ConflictPrompt.swift`（9件）の文字列リテラルを `dialog.*` に置き換える。§5「確認モーダル・ダイアログ」の確認の見出し4種（コピー・移動は `count` で、操作の対象の件数を渡す。英語は Copy this item?／Copy these items? のように語形だけが変わり件数を表示しない。名前の変更・ゴミ箱は引数なし）・`対象: {N} 件`（`number`）・`・{名前}`（1行1キー）・`ほか {N} 件`（`number`）・フォルダの注記2種・`操作先: {パス}`／`場所: {パス}`・Continue／Cancel・Don’t ask again、お気に入りの削除（見出し・`対象: {名前}`・場所・注記・Remove／Cancel）、衝突（見出し・`衝突する項目: {N} 件`・行・Replace／Keep Both／Stop・Apply to all）を対象にし、各行を改行で並べる。既定ボタン・Esc の動作・ボタンの順は変えない（US17-AS3）。
- [ ] T045 [US17] `Sources/MediaViewerApp/Operations/FileOperationCoordinator.swift`（7件）、`Sources/MediaViewerApp/Preview/PreviewViewController.swift`（1件）、`Sources/MediaViewerApp/Preview/ImagePreviewView.swift`（倍率を除く3件）の文字列リテラルを置き換える。拡張子の変更の確認（Change the extension?、`「{名前}」の拡張子を「{拡張子}」に変更します。続けますか？` を `text` 2つで1文、Change／Cancel）、名前の変更の失敗、操作の失敗（The operation couldn’t be completed、`成功 {N} 件 / 失敗 {M} 件`（`number` 2つ）、`{名前}: {理由}`、`ほか {N} 件`）、プレビューの No media file to display／Loading…／`表示できません\n{理由}`（`text` 1つ）／Can’t display the animation を対象にする。倍率の `percentText` は US19 の T064 で扱う。
- [ ] T046 [US17] 配置を英語の長さに合わせる（R11、FR-153、EC-115）。`Sources/MediaViewerApp/Settings/SettingsWindowController.swift` と `Sources/MediaViewerApp/Search/SearchPanelController.swift` の固定幅を、ラベルの固有の幅と折り返し（`preferredMaxLayoutWidth`・`lineBreakMode`）と内容に合わせたウインドウ・シートの大きさへ改める。`Sources/MediaViewerApp/FileList/ListModeView.swift` の列の既定幅で英語の列見出しが欠けないようにする。`Sources/MediaViewerApp/FileList/FileListViewController.swift` の空状態のメッセージは折り返し、検索バーの文は末尾を省略記号で切り詰めて全文を `toolTip` とアクセシビリティの値に入れる。ツリーの名前も同様に切り詰めと全文の取得を確かめる。触る制約は `leading`／`trailing` で書き、制約は `addSubview` の後に有効化する。ウインドウの最小サイズとペインの `minimumThickness`（160／240／320pt）は変えない。
- [ ] T047 [US17] 文言の棚卸しを確かめる。`Sources/MediaViewerApp/`・`Sources/MediaViewerCore/`・`Sources/MediaViewerLocalization/`（管理元を除く）に、日本語の文字列リテラルが残っていないこと（コメント・ログ・`assert` のメッセージ（例: `Sources/MediaViewerApp/Slideshow/SlideshowCoordinator.swift` の `assert`）を除く）を `grep` で確かめ、残っていれば翻訳単位に置き換える。§5 の用語対応表に無い文言を足した場合は、本タスクで明示する追記として `specs/011-app-localization/contracts/localization.md` §5 の該当する表に日本語・英語の行を加える。
- [ ] T048 [US17] T033〜T047 後、`swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/check-readme-sync.sh master` → `scripts/make-app.sh` と T028 の確認を順に実行する。R10 の 1〜7・9・10 がすべて通ることを確かめる。失敗を3回修正しても解消しなければ止めて報告する。

### Manual acceptance for User Story 17

以下は T048 の成功ビルドを使い、ユーザーが操作して報告する。修正でビルドが変わった場合は T048 と影響する手動確認をやり直す。

- [ ] T049 [MANUAL] [US17] ユーザーへ `pgrep -fl MediaViewer`（残っていれば終了）の後、`.build/MediaViewer.app/Contents/MacOS/MediaViewer -AppleLanguages '(en)'` での起動を依頼し、`specs/011-app-localization/quickstart.md` Q3 の 1〜9（メニューバーと View の Sort By と (Ascending)／(Descending)、右クリックの `Copy “<名前>”`・`Copy 3 Items`・Paste Here、ツールバーのツールチップとパレット、確認モーダル、衝突ダイアログ、⌘F の理由と検索バー、⌘, の設定、空状態・プレビューのエラー・zip の理由、日本語・内部キー・`%@` が0件）の報告を受ける（US17-AS1〜AS6、SC-061）。
- [ ] T050 [MANUAL] [US17] ユーザーへ quickstart.md Q9 の 1〜5 を依頼する。両言語（`-AppleLanguages '(ja)'`・`'(en)'`）で最小サイズのウインドウと最小幅のペイン、確認モーダル・衝突ダイアログ・検索シート・設定ウインドウの文とボタンが欠けないこと（SC-065）、長いキーワードの検索バーの切り詰めとツールチップ（EC-115）、日本語で設定・お気に入り（表示名付き）・並べ替え・ツールバーを変えて英語で起動し直したときの復元（US17-AS7、EC-112）、英語での ⌘D と Keep Both の名前（EC-113）、`%@`・`%d`・`{0}`・アラビア文字を含む名前の表示（EC-109）の報告を受ける。
- [ ] T051 [US17] T048 の自動結果と T049・T050 の受領済みの報告を `specs/011-app-localization/quickstart.md` の記録欄へ追記する。不合格の文言・画面はそのまま記録し、修正した場合は修正後のビルドで受けた報告だけを合格とする。
- [ ] T052 [US17] T033〜T051 の全ゲートと受け入れ基準が満たされた後、`Sources/MediaViewerApp/`・`Sources/MediaViewerLocalization/`・`Tests/MediaViewerCoreTests/Localization/`・本 feature の進捗と記録（T047 の §5 の追記を含む）を差分確認し、Phase 3 のコミットにする。GUI 未確認のまま US17 完了・MVP 達成としない。

**Checkpoint**: 英語の UI が成立し、SC-061・SC-064・SC-065 を確認済み。MVP はこの Phase まで（Setup・Foundational を含む）。

---

## Phase 4: User Story 18 — 日本語のユーザーと対応外の言語のユーザーが日本語の UI を使う（Priority: P1）

**Goal**: 日本語の UI が本変更の前と同じであること、対応外の言語で英語へフォールバックすること、アプリごとの言語に従うこと、`.app` をどこへ置いても翻訳が失われないこと、`swift run` でも内部キーを出さないことを確かめる。

**Independent Test**: 優先言語を日本語・フランス語のみ・フランス語 → 英語にし、`.build` の外へコピーした `.app` を起動して、それぞれ日本語・英語・英語で表示されること（quickstart.md Q4〜Q6）。

- [ ] T053 [P] [US18] `Tests/MediaViewerCoreTests/Localization/LocalizationBundleTests.swift` を新設する。`LocalizationBundle.resolve(main:)` に、`ja.lproj/Localizable.strings` を持つ一時バンドル（T012 のヘルパー）を与えるとそのバンドルを返し、lproj を持たないバンドル（テストの `Bundle.main` 相当）を与えると `packageBundle` を返すことを確かめる。`packageBundle` から作った `Localizer` が日本語・英語の両方で内部キーを返さないことを確かめる（FR-155 の `swift run` の経路）。
- [ ] T054 [P] [US18] 日本語の文言が本変更の前と同じであることを確かめる（SC-067、FR-152）。`git show master:<path>` で `Sources/MediaViewerApp/` と `Sources/MediaViewerCore/` の本変更の前の日本語の文字列リテラルを集め、管理元の日本語の訳と突き合わせる。違いが件数の桁区切り・日時の書式に由来するもの以外にあれば、日本語の訳を本変更の前の文言へ戻す。突き合わせの結果（一致件数、違いとその理由）を `specs/011-app-localization/quickstart.md` の記録欄へ追記する。
- [ ] T055 [US18] T053・T054 後、`swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/check-readme-sync.sh master` → `scripts/make-app.sh` と T028 の確認を順に実行する。失敗を3回修正しても解消しなければ止めて報告する。

### Manual acceptance for User Story 18

- [ ] T056 [MANUAL] [US18] ユーザーへ `.build/MediaViewer.app/Contents/MacOS/MediaViewer -AppleLanguages '(ja)'` での起動を依頼し、quickstart.md Q4（Q3 の 1〜8 を日本語で行い、メニュー・確認モーダル・設定ウインドウの文言が `specs/product/contracts/keyboard-and-menus.md`・`settings.md` と同じで、1,000 件以上の桁区切り以外に変化がないこと）の報告を受ける（US18-AS1、SC-067）。続けて `swift run MediaViewerApp` で起動し、内部キーが出ずクラッシュせず、いずれかの対応言語の文言で表示されることの報告を受ける（FR-155）。
- [ ] T057 [MANUAL] [US18] ユーザーへ quickstart.md Q5 を依頼する。(1) 引数 `(ja)`・`(en)`・`(en-GB)`・`(fr, en)`・`(fr)`・`(zh-Hans, ja)` で起動して契約 §1 の表どおりの言語（日・英・英・英・英・日）になること、(2) システム設定 > 一般 > 言語と地域 > アプリケーション で MediaViewer に日本語・英語の選択肢があり、優先言語の先頭を英語にして MediaViewer に日本語を指定して起動 → 日本語、優先言語の先頭を日本語にして MediaViewer に英語を指定して起動 → 英語であること（SC-062 の7・8行目。確認後に指定を外し、優先言語を元の並びに戻す）、(3) 英語で起動中に優先言語を日本語へ変えても表示が英語のまま混在せず、起動し直すと日本語になること、の報告を受ける（US18-AS2〜AS4・AS6、SC-062、EC-107・108）。
- [ ] T058 [MANUAL] [US18] ユーザーへ quickstart.md Q6 のコマンド（`tmp=$(mktemp -d)`、`ditto .build/MediaViewer.app "$tmp/MediaViewer.app"`、`mv .build .build-away`、コピーした `.app` を `-AppleLanguages '(en)'`・`'(ja)'` で起動、確認後に `mv .build-away .build`）を依頼し、どちらも翻訳された文言で表示され内部キーが出ないこと、`.build` を元の名前へ戻したことの報告を受ける（US18-AS5、SC-066）。
- [ ] T059 [US18] T054・T055 の自動結果と T056〜T058 の受領済みの報告を `specs/011-app-localization/quickstart.md` の記録欄へ追記する。SC-062 の8通りを1行ずつ記録し、システム設定での確認と引数での確認を区別する。
- [ ] T060 [US18] T053〜T059 の全ゲートと受け入れ基準が満たされた後、変更したテスト・訳・本 feature の進捗と記録を差分確認し、Phase 4 のコミットにする。

**Checkpoint**: US17・US18 がそれぞれ成立し、SC-062・SC-066・SC-067 を確認済み。

---

## Phase 5: User Story 19 — 表示言語とは別の地域設定で日時と数値を読む（Priority: P2）

**Goal**: 作成日・件数・倍率を、表示言語と区別した地域設定の書式で表示し、月名などの語は表示言語にする（FR-151）。

**Independent Test**: 英語 UI＋日本の地域、日本語 UI＋米国の地域、英語 UI＋ドイツの地域で、作成日・1,000 件以上の件数・倍率の読み上げを確かめる（quickstart.md Q7、SC-063）。

- [ ] T061 [US19] `Tests/MediaViewerCoreTests/Localization/FormattingTests.swift` に R10-8 の日時と割合を足す。表示言語と地域の組み合わせは、実際の組み合わせを `FormattingLocale.resolve(current:displayLanguage:)` に通したロケールで与え、期待値もそのロケールで判定する（`en_JP` などを直接与えて固定の期待値と比べない。置き換えたロケールの既定の書式は ICU の版に左右されるため）。`Localizer.dateTime(_:)` は `resolve(current: ja_JP, displayLanguage: en)`（日本の並びと、`ja_JP` から引き継いだ24時間表示、語は英語）・`resolve(current: en_US, displayLanguage: ja)`（米国の並びと12時間表示、午前・午後などの語は日本語）・`resolve(current: de_DE, displayLanguage: en)`（ドイツの並び、月名は英語）・`ja_US@hours=h23`（24時間表示）で、日付は中程度・時刻は短い形式になり、`nil` は `--` になること（EC-116）。`Localizer.percent(125)` が `en_US`・`ja_JP` で `125%`、`de_DE` で `125 %`（間の空白は OS の空白文字を許す）になること。合否は固定の文字列ではなく、並び・区切り・時刻表記・語の言語の性質で判定する（contracts/localization.md §4 の注記）。
- [ ] T062 [US19] `Sources/MediaViewerLocalization/FormattingLocale.swift` と `Sources/MediaViewerLocalization/Localizer.swift` に `dateTime(_ date: Date?) -> String`（`DateFormatter`、`dateStyle = .medium`、`timeStyle = .short`、`locale` は書式のロケール、`nil` は `--`）と `percent(_ percentage: Int) -> String`（`percentage / 100` を `.percent.locale(書式のロケール)` で整形）を実装する。整形器は使い回し、`Sendable` を保つ（MainActor で使うか、ロックで守る）。T061 を通す。
- [ ] T063 [P] [US19] `Sources/MediaViewerApp/FileList/ListModeView.swift` の作成日の `DateFormatter`（ロケール未指定）を `Localizer.shared.dateTime(_:)` に置き換える。取得できない日付は従来どおり `--`（EC-116）。行ごとに整形器を作らない（性能の基準を保つ）。
- [ ] T064 [P] [US19] `Sources/MediaViewerApp/Preview/ImagePreviewView.swift` の `percentText`（`"\(percentage)%"`）を `Localizer.shared.percent(_:)` に置き換え、倍率のアクセシビリティの値と倍率の変更の読み上げに使う（FR-138、US19-AS3、US20-AS3）。読み上げの文に倍率以外の語があれば翻訳単位にする。
- [ ] T065 [US19] 日時・数値・割合の表示箇所の棚卸しを確かめる。`Sources/MediaViewerApp/` で `DateFormatter`・`NumberFormatter`・`formatted(`・`"\(` を含む数値の補間・`%` を `grep` し、T041・T044・T045・T063・T064 の範囲外で件数・日時・割合を表示している箇所があれば `Localizer.shared.count`／`dateTime`／`percent` に置き換える。`Sources/MediaViewerApp/Settings/SettingsWindowController.swift` の切り替え間隔が桁区切りなしの整数のままで、`SlideshowIntervalInput` を変えていないことを確かめる（US19-AS5）。
- [ ] T066 [US19] T061〜T065 後、`swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/check-readme-sync.sh master` → `scripts/make-app.sh` を順に実行する。`swift test --filter MediaViewerPerformanceTests` の結果が `specs/001-three-pane-media-viewer/quickstart.md` の基準を保つことを確かめる。失敗を3回修正しても解消しなければ止めて報告する。
- [ ] T067 [MANUAL] [US19] ユーザーへ quickstart.md Q7 の表の5通り（`-AppleLanguages '(en)' -AppleLocale ja_JP`、`'(ja)' -AppleLocale en_US`、`'(en)' -AppleLocale de_DE`、`'(ja)' -AppleLocale en_US -AppleICUForce24HourTime YES`、`-AppleLocale de_DE` での ⌘, の切り替え間隔と `１２`・`3600`・`3601` の入力）を依頼し、リスト形式（⌘2）の作成日・1,000 件以上が一致する検索の件数・125% の倍率の VoiceOver の読み上げ・作成日を取得できない項目の `--` について報告を受ける（US19-AS1〜AS5、SC-063）。
- [ ] T068 [US19] T066 の自動結果と T067 の受領済みの報告を `specs/011-app-localization/quickstart.md` の記録欄へ追記する。SC-063 の9か所（3通り × 作成日・件数・倍率）を1つずつ記録する。
- [ ] T069 [US19] T061〜T068 の全ゲートと受け入れ基準が満たされた後、変更したファイル・本 feature の進捗と記録を差分確認し、Phase 5 のコミットにする。

**Checkpoint**: US19 が成立し、SC-063 を確認済み。

---

## Phase 6: User Story 20 — VoiceOver の利用者が両言語で操作する（Priority: P2）

**Goal**: アクセシビリティのラベル・値・ヘルプ・読み上げをすべて表示言語で提供する（FR-154、憲章 原則 III）。

**Independent Test**: 英語と日本語のそれぞれで VoiceOver をオンにし、quickstart.md Q8 の項目を読み上げさせ、表示言語と異なる言語の読み上げが0件（SC-068）。

- [ ] T070 [US20] `Sources/MediaViewerApp/` の `setAccessibilityLabel`・`setAccessibilityHelp`・`setAccessibilityValue`・`setAccessibilityTitle`・`accessibilityLabel()` などの override・`NSAccessibility.post`（読み上げ）を `grep` で棚卸しし、表示文言を渡しているものがすべて `Localizer.shared` 経由であることを確かめる。直書きや未設定のものは `a11y.*` の翻訳単位を足して置き換える。ツールバーのヘルプがツールチップと同じ文言（ショートカットの表記を含む）であること（US20-AS1）、検索起点の検証エラーの読み上げが表示言語であること（US20-AS2）、設定ウインドウの切り替え間隔・繰り返し・効果（Transition）、お気に入りとフォルダの名前の編集欄、プレビューの倍率（T064）を含める。
- [ ] T071 [US20] T070 後、`swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/check-readme-sync.sh master` → `scripts/make-app.sh` を順に実行する。失敗を3回修正しても解消しなければ止めて報告する。
- [ ] T072 [MANUAL] [US20] ユーザーへ、`-AppleLanguages '(en)'` と `'(ja)'` のそれぞれで起動し VoiceOver（⌘F5）をオンにして quickstart.md Q8（ツールバーの各ボタンとスライダー、検索シートの入力欄と Choose…／選択…、設定ウインドウの全項目、お気に入りとフォルダの名前の編集欄、プレビューの倍率、検索起点の検証エラーと倍率の変更の読み上げ）を確かめるよう依頼し、表示言語と異なる言語で読み上げられた項目の有無の報告を受ける（US20-AS1〜AS3、SC-068）。
- [ ] T073 [US20] T071 の自動結果と T072 の受領済みの報告を `specs/011-app-localization/quickstart.md` の記録欄へ追記する。
- [ ] T074 [US20] T070〜T073 の全ゲートと受け入れ基準が満たされた後、変更したファイル・本 feature の進捗と記録を差分確認し、Phase 6 のコミットにする。

**Checkpoint**: US20 が成立し、SC-068 を確認済み。全ストーリーが独立に成立。

---

## Phase 7: Polish & Cross-Cutting Concerns — README・最終検証・仕様反映

**Purpose**: 利用者向けの文書を英語の UI に合わせ、最終ビルドで検証した後にだけ product へ反映して feature を凍結する。

- [ ] T075 `README.md` と `README.ja.md` を同じ変更で直す（research.md R13、A-92、AGENTS.md「README の英語版と日本語版」）。対応言語（日本語・英語）、表示言語の決まり方（アプリごとの言語 → 優先言語 → どちらにもなければ英語）、設定の場所（システム設定 > 一般 > 言語と地域）を同じ構成（見出し・箇条書き・表の行・コードブロックの1対1）で加える。`README.md` の「UI は日本語のみ」の記述を削り、UI の文言の英訳を contracts/localization.md §5 に合わせ、英語の UI と同じ名前になった項目では括弧の日本語の表示名を外す。README から `specs/`・`.specify/`・`AGENTS.md` へリンクしない。
- [ ] T076 最終状態に対して `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/check-readme-sync.sh master` → `scripts/make-app.sh` と T028 の確認を順に実行する。R10 の 1〜10 の全テストが通り、訳の欠け・未使用のキー・値の不一致が0件であること（SC-069）、性能テストの基準を保つことを確かめる。`git diff master -- README.md README.ja.md` を読み、両方に同じ内容が入っていることを確かめる。
- [ ] T077 [MANUAL] T076 成功後、ユーザーへ `pgrep -fl MediaViewer`（残っていれば終了）→ `open .build/MediaViewer.app` と、`.build/MediaViewer.app/Contents/MacOS/MediaViewer -AppleLanguages '(en)'` を依頼し、最終ビルドで3ペインが表示されること、両言語でメニューバーと ⌘, の設定ウインドウが表示言語どおりであることの報告を受ける。
- [ ] T078 T076・T077 の結果、最終ビルド、SC-061〜SC-069 のそれぞれの証拠（対応するタスクと記録）、未確認・制限・残件の有無を `specs/011-app-localization/quickstart.md` の記録欄へ追記する。T082・T049・T050・T056〜T058・T067・T072・T077 に未確認が残る場合は未完了を明示し、T079 へ進まない。
- [ ] T079 実装・自動検証・手動検証がすべて完了した後、`specs/011-app-localization/spec.md` の「反映先」表に従い反映する。`specs/product/overview.md` に FR-145〜148・151・152・154・155（横断要件「国際化」）、US17〜US20、EC-107〜116、SC-061〜069、A-87〜93 を、`specs/product/contracts/localization.md` を本 feature の `contracts/localization.md`（T047 の追記を含む）から新設し FR-145〜157 を、`specs/product/contracts/app-bundle.md` に本 feature の `contracts/app-bundle.md` の差分（R1 の判定どおりの生成物の名前）を、`specs/product/contracts/settings.md` に表示言語を保存しない旨と表示名の注記を、`specs/product/contracts/keyboard-and-menus.md` に表示名の注記を、`specs/product/file-list.md` に作成日の書式と FR-012 の自然順の注記（EC-112）を、`specs/product/preview.md` に FR-138 の倍率の書式の注記を、`specs/product/window-layout.md` に FR-153 を、`specs/product/README.md` の領域の表に「国際化」と `contracts/localization.md` を加える。ID を再利用せず、既存の日本語の表示名を変えない。
- [ ] T080 T079 の反映先・ID・本文の整合を確かめ、`specs/011-app-localization/spec.md` の冒頭に product へ移行済み・凍結の注記を付ける。設計内容を実装に合わせて書き換えない。最終の進捗は本 tasks.md で確定する。
- [ ] T081 T075〜T080 完了後、`README.md`・`README.ja.md`・`specs/product/`・本 feature の記録と凍結の注記を差分確認し、Phase 7 のコミットにする。文書のリンクと ID の整合を確かめる。push は行わない。

**Checkpoint**: 最終起動を含めた検証が揃い、product が更新され、本 feature は実装の記録として凍結される。

---

## Dependencies & Execution Order

### Phase Dependencies

```text
Phase 1: T001 → T002 [MANUAL] → T082 [MANUAL] → T083 → T003 → T004 [MANUAL] → T005 → T006 → T007
  ↓
Phase 2: T008 → T009 → (T010 ‖ T011 ‖ T012 ‖ T013 ‖ T014) → (T015 ‖ T016 ‖ T017) → T018
         → T019 → T020 → T021 → T022 → T023 → T024 → T025 → T026 → T027 → T028
         → T029 → T030 [MANUAL] → T031 → T032
  ↓
Phase 3: US17 (P1 / MVP)
  (T033 ‖ T034) → T035 → T036 → T037 → T038 → T039 → T040 → T041 → T042 → T043 → T044 → T045 → T046 → T047
  → T048 → T049 [MANUAL] → T050 [MANUAL] → T051 → T052
  ↓
Phase 4: US18 (P1)
  (T053 ‖ T054) → T055 → T056 [MANUAL] → T057 [MANUAL] → T058 [MANUAL] → T059 → T060
  ↓
Phase 5: US19 (P2)
  T061 → T062 → (T063 ‖ T064) → T065 → T066 → T067 [MANUAL] → T068 → T069
  ↓
Phase 6: US20 (P2)
  T070 → T071 → T072 [MANUAL] → T073 → T074
  ↓
Phase 7: T075 → T076 → T077 [MANUAL] → T078 → T079 → T080 → T081
```

### User Story Dependencies

- **US17（P1）**: Phase 2 の完了に依存する。他のストーリーに依存しない。
- **US18（P1）**: Phase 2 に依存する。表示言語の決定と `.app` の同梱は Phase 2 で成立しているが、Q4 の日本語の確認と T054 の突き合わせは、App の文言が翻訳単位に置き換わった後（US17 の T047 まで）でないと全範囲を確かめられないため、US17 の後に行う。
- **US19（P2）**: Phase 2 に依存する。件数の整形（T017）は Phase 2 にあり、日時と割合を足す。T063 は T040、T064 は T045 と同じファイルを触るため US17 の後に行う。
- **US20（P2）**: US17（画面の文言）と US19（倍率の読み上げ、T064）の後に行う。アクセシビリティの文言の多くは US17 の各タスクで置き換え、T070 は漏れの棚卸しと補完を行う。

### Within Each Phase

- テストを先に書き、未実装による失敗（コンパイル失敗を含む）を確かめてから実装する。未実装によるコンパイル失敗と、実装後のアサーションの失敗を区別する。
- Core の値の変更（T019〜T023）→ 文言化（T024・T025）→ App の追従（T026）は1つの流れで行い、途中でコミットしない。
- 翻訳単位を足すタスク（T018・T025・T036〜T045・T047・T064・T070）は `TextKey.swift` と管理元を共有するため直列にする。
- 手動報告を待つ間に独立した非手動作業を進めてよいが、未確認の Phase の合格・Phase のコミット・product 反映を先取りしない。
- 起動しない・クラッシュする場合は推測で直さず、`AGENTS.md` の lldb のコマンドで Objective-C 例外を止める手順をユーザーへ依頼する。

### Parallel Opportunities

- Phase 2: T010〜T014（別ファイルのテスト）、T015〜T017（別ファイルの実装）。T019〜T026 は途中でコミットせずビルドが通らない期間があるため、worktree の並列化の対象外（直列）。
- US17: T033・T034（テスト）。実装は直列。
- US18: T053・T054。
- US19: T063・T064（T062 の後）。

---

## Parallel Example: Phase 2 と User Story 17

並列化は可能性の提示であり実行指示ではない。既定は順次実装する。明示的に並列化する場合はクリーンな Phase ブランチから独立 worktree を用意し、各担当は自分の worktree 内だけを編集してコミット SHA を返す。

```text
# T009 後、別ファイルのテスト
T010: Tests/MediaViewerCoreTests/Localization/CatalogConsistencyTests.swift
T011: Tests/MediaViewerCoreTests/Localization/CompiledBundleTests.swift
T012: Sources/FixtureKit/LocalizationFixtures.swift + Tests/MediaViewerCoreTests/Localization/FallbackTests.swift
T013: Tests/MediaViewerCoreTests/Localization/DisplayLanguageTests.swift
T014: Tests/MediaViewerCoreTests/Localization/FormattingTests.swift

# T014 後、別ファイルの実装
T015: Sources/MediaViewerLocalization/LocalizationBundle.swift
T016: Sources/MediaViewerLocalization/DisplayLanguage.swift
T017: Sources/MediaViewerLocalization/FormattingLocale.swift

# US17 のテスト
T033: Tests/MediaViewerCoreTests/Localization/ValueSentenceTests.swift
T034: Tests/MediaViewerCoreTests/Localization/PluralTests.swift
```

統合担当が Phase ブランチへ `git merge --no-ff` または cherry-pick し、各統合後に `swift build` / `swift test`。GUI スモークは統合後の1つのアプリでのみ行い、不要になった worktree・作業ブランチを削除する。同じ作業ディレクトリでの内部 subagent の並列編集は行わない。

---

## Implementation Strategy

### MVP First（US17）

1. Phase 1 で分類の設計レビュー・既存アプリの基準・R1 の試作を済ませ、管理形式を確定する。
2. Phase 2 で Localization ターゲット・自動検証・Core の値・`.app` の lproj を揃える。日本語の見た目が変わらないことを起動スモークで確かめる。
3. Phase 3 で App の文言を翻訳単位に置き換え、英語の UI を成立させる。自動ゲートの後、ユーザーの Q3・Q9 の報告で US17 を MVP として検証する。

### Incremental Delivery

- US17 → US18（日本語の同一性・フォールバック・配布）→ US19（地域の書式）→ US20（VoiceOver の補完）の順に、各 Phase の終わりで検証ゲートとユーザーの確認を通してコミットする。
- 言語ごとの分岐をアプリの判断ロジックに持たない（FR-156）。表示言語・書式のロケールを保存しない（FR-145）。ネットワーク API・外部パッケージ・Xcode プロジェクトを追加しない。
- 自動テストの成功、手動確認済み、記録済みを別々のチェックで表す。GUI の報告待ちでも分類を変えず、未実施の理由を残す。
- 実装中に spec.md・plan.md・research.md・data-model.md・契約を書き換えない（T047 で明示した §5 への追記と、「Path Conventions」の英語の文言の修正を除く）。仕様の変更が必要なら実装の判断で吸収せず、設計の工程へ戻す。

---

## Coverage & Completion

| 要求 | 自動/実装 | 手動確認 |
|---|---|---|
| FR-145、EC-107・108：表示言語の決定・開発言語の宣言・保存しない | T013・T015・T016・T018・T027・T028 | T057 |
| FR-146、SC-061：アプリ管理文言の翻訳・混在0件 | T009・T018・T025・T026・T035〜T045・T047 | T049・T056 |
| FR-147、EC-109・111：ユーザーデータ・OS の文言を訳さない | T021・T025・T033・T037・T041〜T043 | T050 |
| FR-148、EC-112・113：表示文言を判断・保存に使わない | T019〜T024・T035 | T050 |
| FR-149・150、EC-114、SC-064：値を含む文・複数形 | T010・T033・T034・T037・T041・T044・T045 | T049 |
| FR-151、EC-116、SC-063：地域の書式 | T014・T017・T061〜T065 | T067 |
| FR-152、SC-067、A-88：既存の日本語の表示名・英語の用語対応表 | T024・T036〜T045・T047・T054・T083 | T082・T049・T056 |
| FR-153、EC-115、SC-065：配置 | T046 | T050 |
| FR-154、SC-068：アクセシビリティ | T038〜T040・T042・T043・T064・T070 | T072 |
| FR-155、SC-066：`.app` の自己完結・`swift run` | T011・T015・T027・T028・T053 | T056・T058 |
| FR-156：言語の追加が翻訳と宣言で済む | T016・T017・T018・T027 | — |
| FR-157、EC-110、SC-069：訳の欠けの自動検出・フォールバック | T010〜T012・T024・T033・T034・T053・T076 | — |
| A-92：README | T075・T076 | — |

全83タスク（US17: 20、US18: 8、US19: 9、US20: 5、ストーリー外: 41。T082・T083 は分析の指摘で追加）。`[MANUAL]` は12件、`[P]` は14件。各チェックはその作業の証拠が得られてから付け、手動確認の未実施を残したまま全体完了にしない。
