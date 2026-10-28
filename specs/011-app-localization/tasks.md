# Tasks: 日本語・英語への国際化（表示言語の即時切り替え）

**Input**: `spec.md`、`plan.md`、`research.md`、`data-model.md`、`contracts/`、`quickstart.md`、`.specify/memory/constitution.md`、`AGENTS.md`。

**引き継ぎ**: 旧方式の T001〜T094・T095・T096 は [tasks-before-language-change.md](tasks-before-language-change.md) に保存した。新方式では以下の T097 以降を進捗の正とする。旧リストのチェックは新方式の完成を意味しない。旧仕様の実装は存在するが未コミットであり、各タスクで差分と自動テストを調べてから再利用する。旧 GUI 確認の未報告は引き継がない。

**実行規則**: 既定は順次実施。`[MANUAL]` はユーザーの実施・報告が必要で、ユーザーの報告なくチェックしない。GUI は起動しない。設計レビュー・Phase の自動ゲート・GUI スモーク・コミットを順に行う。実装中の仕様文書更新は本ファイルのチェックと明示した記録だけに限る。

## Phase 1: 設計の確定

- [X] T097 `specs/011-app-localization/` の spec・plan・research・data-model・contracts・quickstart を照合し、アプリ設定での言語の選択・保存・英語既定・即時反映・翻訳欠落時の英語・OS の文言・`.strings`／`.stringsdict` の扱いを整合させる。旧 tasks の要件を以下へ対応付ける。
- [X] T098 `specs/011-app-localization/tasks.md` と各設計文書を `speckit-analyze` で検証し、重大な矛盾と未対応の要件を修正する。分析は読み取り専用で行い、修正はその後に行う。
- [X] T099 [MANUAL] ユーザーに `specs/011-app-localization/spec.md`・`plan.md`・`tasks.md`・`quickstart.md` の変更を提示し、設計レビューの承認または修正点の報告を受ける。

## Phase 2: 基盤と保存（US17・US18）

- [X] T100 `Tests/MediaViewerCoreTests/SettingsStoreTests.swift` と `Tests/MediaViewerCoreTests/Localization/DisplayLanguageTests.swift` に、未設定・未知／不正型の保存値は英語、英語・日本語の保存と復元、他の保存値の保持、OS の優先言語からの独立を検証するテストを追加する。
- [X] T101 `Sources/MediaViewerCore/Settings/SettingsStore.swift` と必要な値型で表示言語の安定した識別子を保存・復元する。未設定・未知の値は英語とし、UI・翻訳に Core を依存させない。T100 を通す。
- [X] T102 `Sources/MediaViewerLocalization/DisplayLanguage.swift`・`Localizer.swift`・`FormattingLocale.swift` と `Sources/MediaViewerApp/App/LocalizationSupport.swift` を、保存された言語から起動し設定変更を MainActor の共有状態で通知する構成にする。表示言語変更時に書式の言語を更新し、地域・時刻設定を保つ。固定された古い Localizer を捕捉しない。
- [X] T103 `Sources/MediaViewerApp/Settings/SettingsWindowController.swift` と `Sources/MediaViewerLocalization/TextKey.swift`・`Resources/{en,ja}.lproj/Localizable.strings` に言語選択と英語・日本語の選択肢を追加する。変更を保存して即時通知し、設定画面自体の文言・選択状態・未確定入力を保持する。
- [X] T104 `Tests/MediaViewerCoreTests/Localization/` の既存テストを現在の契約へ追従させる。英語への翻訳欠落時のフォールバック、変更前後の両言語と地域、複数形・値・書式、各キーと翻訳の一致を確認する。
- [X] T105 `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/check-readme-sync.sh master` → `scripts/make-app.sh` → `specs/011-app-localization/quickstart.md` Q2 の非 GUI 検証を順に行う。失敗を3回修正しても解決しなければ止める。
- [X] T106 [MANUAL] ユーザーに `pgrep -fl MediaViewer` と `open .build/MediaViewer.app` を依頼し、3ペインと設定が開き、初期言語と選択した言語の変更が反映されることを確認してもらう。確認範囲と結果を受け取る。
- [X] T107 T105・T106 の結果を `specs/011-app-localization/quickstart.md` の記録欄へ記録する。
- [X] T108 T100〜T107 完了後、差分を確認し Phase 2 をコミットする。push しない。

## Phase 3: 各画面の即時切り替え（US17・US18）

- [X] T109 [US18] `Sources/MediaViewerCore/Model/MediaFile.swift`・`FileSystem/DirectoryLister.swift`・`Archive/ArchiveIndex.swift`・`Browser/BrowserModel.swift` と関連テストで、OS 由来の種類名とアプリの代替名を区別する。既存一覧・検索結果・zip 内の行と種類順を新しい言語に更新し、OS 由来の名前を変えない。選択を維持し、古い非同期結果の巻き戻しを防ぎ、大量データの変換・並べ替えと列挙は UI スレッド外で行う。
- [X] T110 [US17] `Sources/MediaViewerApp/App/MainMenu.swift`・`MainSplitViewController.swift`・`MainToolbarController.swift` のメニュー、状態依存の項目、ツールバー、ツールチップとアクセシビリティを、識別子や操作・ショートカットを維持し言語変更時に更新する。
- [X] T111 [US17] `Sources/MediaViewerApp/Tree/`・`FileList/`・`Preview/` の見出し、列、空状態、種類名、プレビューのエラー・倍率とアクセシビリティを更新する。表示中のフォルダ・選択・スクロール・編集中の名前・再生状態を保持する。
- [X] T112 [US17] `Sources/MediaViewerApp/Search/`・`Operations/` の検索画面・検索結果・入力値・エラー、確認と衝突ダイアログの文言を更新する。実行中の検索・操作、長い文字列とユーザーの名前を損なわない。
- [X] T113 [US17] `Sources/MediaViewerApp/` と `Sources/MediaViewerLocalization/` の翻訳単位・日本語の直書き・アクセシビリティを棚卸しする。`specs/011-app-localization/contracts/localization.md` §5 と日本語既存文言を照合し、訳の欠け・未使用キー・値の不一致を修正する。必要な契約表の追加と結果を quickstart に記録する。
- [X] T114 [US18] `Tests/MediaViewerCoreTests/Localization/` と関連 Core テストで、言語変更の両方向、未知の値、非同期結果、フォールバック種類名と OS 由来の種類名、種類の並べ替え、ユーザー文字列の保持を検証する。
- [X] T115 `swift build` → `swift test` → no-network → README 同期 → `scripts/make-app.sh` → quickstart Q2 の非 GUI 検証を順に行い、性能テストが既存基準を保つことを確かめる。
- [X] T116 [MANUAL] `specs/011-app-localization/quickstart.md` Q3〜Q6・Q9 に従い、両言語と設定での即時切り替え、既存の文言、閲覧・編集・検索状態、保存復元、`.app` の独立性、OS 言語との独立をユーザーに確認してもらう。`swift run MediaViewerApp` でも内部キーが出ずクラッシュしないことを確認してもらう。
- [X] T117 T115・T116 の結果を `specs/011-app-localization/quickstart.md` に記録する。
- [X] T118 T109〜T117 完了後、差分を確認し Phase 3 をコミットする。push しない。

## Phase 4: 地域書式とアクセシビリティ（US19・US20）

- [X] T119 [US19] `Tests/MediaViewerCoreTests/Localization/FormattingTests.swift` と `Sources/MediaViewerLocalization/FormattingLocale.swift`・`Localizer.swift`・`Sources/MediaViewerApp/FileList/ListModeView.swift`・`Preview/ImagePreviewView.swift` で、言語変更後の日時・件数・倍率が地域設定を保ち、語だけ表示言語に従うこと、日付がないと `--` であること、設定の切り替え間隔が従来どおりであることを検証・補完する。
- [X] T120 [US20] `Sources/MediaViewerApp/` の accessibility label・help・value・通知を棚卸しし、設定言語変更の前後で画面文言と一致するよう更新する。`specs/011-app-localization/contracts/localization.md` §5 の用語と既存操作を保つ。
- [X] T121 `swift build` → `swift test` → no-network → README 同期 → `scripts/make-app.sh` を順に実行し、性能テストを確認する。
- [X] T122 [MANUAL] `specs/011-app-localization/quickstart.md` Q7 の地域書式と入力、Q8 の両言語の VoiceOver をユーザーに確認してもらい、項目別に結果を受け取る。
- [X] T123 T121・T122 の結果を `specs/011-app-localization/quickstart.md` に記録する。
- [X] T124 T119〜T123 完了後、差分を確認し Phase 4 をコミットする。push しない。

## Phase 5: README・最終検証・仕様反映

- [ ] T125 `README.md` と `README.ja.md` を同じ構成・内容で更新し、対応言語、英語の初期値、アプリ設定での切り替え・即時反映・保存を説明する。訳を契約の用語と合わせ、両方の差分を確認する。
- [ ] T126 最終状態で `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/check-readme-sync.sh master` → `scripts/make-app.sh` → quickstart Q2 の非 GUI 確認を順に実行する。翻訳の一貫性・性能テスト・README の内容を確かめる。
- [ ] T127 [MANUAL] 最終ビルドを `open .build/MediaViewer.app` で起動し、3ペインと設定、両言語の即時切り替えをユーザーに確認してもらう。
- [ ] T128 T126・T127 と SC-061〜SC-069 の証拠・未確認項目を `specs/011-app-localization/quickstart.md` に記録する。GUI 未確認がある場合は完了としない。
- [ ] T129 `speckit-converge` で `specs/011-app-localization/` の仕様・実装・タスクを照合し、残作業があれば追加して検証ループへ戻る。
- [ ] T130 `specs/011-app-localization/spec.md` の反映先に従い `specs/product/` の各領域と契約を更新し、feature spec に移行済み・凍結を記す。コミットせず差分を提示する。
- [ ] T131 [MANUAL] `specs/product/` への反映と凍結の差分をユーザーにレビューしてもらい、承認または修正点の報告を受ける。
- [ ] T132 T125〜T131 完了後に文書・仕様の差分を確認してコミットする。feature の master へのマージと push は行わない。

## 依存関係と検証

T097 → T098 → T099 → Phase 2 → Phase 3 → Phase 4 → Phase 5。各 Phase は自動検証とユーザーの GUI 確認後にコミットする。手動報告の未受領を完了扱いにしない。既存の旧タスクは引き継ぎファイルを参照し、未実装の共通要件は T104・T113・T119・T120・T129 で照合する。並列編集は行わない。

| 要件 | 主なタスク | 手動確認 |
|---|---|---|
| FR-145、EC-107・108、SC-062: 言語選択・保存・即時反映 | T100〜T104、T109〜T114 | T106、T116、T127 |
| FR-146〜148、EC-109・111〜113、SC-061・067: 翻訳範囲・データ保持 | T109〜T114 | T116 |
| FR-149・150、EC-114、SC-064: 値と複数形 | T104、T113、T114 | T116 |
| FR-151、EC-116、SC-063: 地域書式 | T102、T104、T119 | T122 |
| FR-152・153、EC-115、SC-065・067: 文言と配置 | T103、T110〜T113 | T116 |
| FR-154、SC-068: アクセシビリティ | T110〜T112、T120 | T122 |
| FR-155、SC-066: バンドルと開発起動 | T105、T115、T126 | T116 |
| FR-156・157、EC-110、SC-069: 言語追加・翻訳の欠落検出 | T102〜T104、T113、T126 | T116 |
