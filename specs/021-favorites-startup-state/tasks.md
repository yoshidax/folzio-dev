# Tasks: 起動時のお気に入りの開閉状態

**Input**: `specs/021-favorites-startup-state/` の spec・plan・research・data-model・contracts・quickstart。
**Status**: 設計レビュー待ち。進捗は本ファイルを正とする。

## Format

`- [ ] Tnnn [MANUAL?] [USn?] 内容と対象パス`。
`[MANUAL]` は ID 直後のユーザーの判断・実機報告だけに使用し、実装中に分類を変更しない。
設計レビュー承認の実際の回答は T001 にだけ適用し、他の手動確認へ流用しない。
全タスクをこのセッションで順次実施するため `[P]` は付けない。

## Phase 1: Setup — 設計の承認と記録

- [X] T001 [MANUAL] `specs/021-favorites-startup-state/spec.md`・`plan.md`・`tasks.md` と analyze 結果を保守者が確認し、既定値・保存の寿命・手動タスク・単一の実装単位を承認する。
- [X] T002 T001 の回答を受け、レビュー済みの `specs/021-favorites-startup-state/` の文書と tasks の確認済み項目だけをコミットする。

## 実装 Phase: Foundation → US87 → US88 → 検証

以下の作業グループを1つの実装 Phase とする。
Core とツリーと設定 UI が揃った後に、T010〜T012 の検証・手動確認・コミットを1回行う。
新しい依存・プロジェクト・基盤を準備するタスクは不要。

### Foundational — 共有する設定の保存と起動時判断

- [X] T003 `Tests/FolzioCoreTests/SettingsStoreTests.swift` に、新しい2キーの未設定・往復・全4通りの起動時判断・不正な型・既存の登録と表示名と他設定の保持を検証するテストを追加する（値は CFBoolean のときだけ採用する。未設定・文字列・整数（0と1も含む）・小数・配列・辞書は false として読む）。
- [X] T004 `Sources/FolzioCore/Settings/SettingsStore.swift` に `restoresFavoritesExpansion`・`favoritesExpanded` と読み取り専用の `favoritesExpandedOnLaunch` を追加し、各 setter が対応キーだけを書くようにして T003 を通す（キー・型・既定値は `specs/021-favorites-startup-state/data-model.md` に従う）。

### US87 — 前回の開閉状態で起動する（P1）

**Goal**: 見出しの起動時復元と以後の開閉保存を行い、更新中の一時状態で保存値を破壊しない。
**Independent Test**: 設定を注入した controller で実際の outline 状態と保存結果を検証する。

- [X] T005 [US87] `Tests/FolzioAppTests/FavoritesExpansionTests.swift` に、初期表示の全4条件、開閉通知、`focusFavoritesHeader()`、通常ノード通知の除外、オフ→オンで追加開閉なしの次回復元、オフ起動による旧状態の置き換え、登録0件・登録先不在、スタブのボリューム更新前後の保存維持を確認する結合テストを追加する。
- [X] T006 [US87] `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` の初期 reload 後に見出しだけを1回復元し、実際の開閉を通知で保存し、`applyRoots` 等の一時的な更新を保存しないようにして T005 を通す（選択・通常階層・監視の既存動作を保つ）。

### US88 — 毎回閉じる動作を選ぶ（P1）

**Goal**: 既定オフの設定を英日・キーボード・読み上げから操作できるようにする。
**Independent Test**: 設定を切り替えて閉じて再表示し、保存されるが現在のツリーが動かないことを確かめる。

- [X] T007 [US88] `Sources/FolzioLocalization/TextKey.swift` と `Sources/FolzioLocalization/Resources/en.lproj/Localizable.strings`・`ja.lproj/Localizable.strings` に `specs/021-favorites-startup-state/contracts/localization.md` の2キーと用途を追加する。
- [X] T008 [US88] `Sources/FolzioApp/Settings/SettingsWindowController.swift` に「プレビュー」と「動画」の間の新しい区分とチェックボックス、再表示時の同期、即時保存、次回起動からの適用、英日と読み上げラベルの更新、Tab/Shift+Tab の順序を実装する（幅620pt、区分間20pt、項目間8ptを維持する）。
- [X] T009 [US88] `Tests/FolzioCoreTests/Localization/SettingsTextTests.swift` で英日2キーを確認し、既存のカタログ整合性テストも通す。

### 実装 Phase の検証ゲート

- [X] T010 `specs/021-favorites-startup-state/quickstart.md` の自動検証を `swift build` → `swift test` → `scripts/dev/check-all.sh` → `scripts/make-app.sh` の順に行い、結果・ログ・対象 HEAD とアプリの SHA-256 を同ファイルの検証記録へ追記する。
- [X] T011 [MANUAL] 保守者が `open /Users/igachan/.codex/worktrees/e161/folzio/.build/Folzio.app` を実行し、`specs/021-favorites-startup-state/quickstart.md` の基本動作と表示、言語・キーボード・読み上げの全必須項目を確認して OS・端末・対象アプリ・結果を報告する。
- [X] T012 T011 の実際の報告を `specs/021-favorites-startup-state/quickstart.md` に追記し、成功した確認だけを tasks に反映して、実装 Phase をコミットする（失敗や必須項目の未実施があれば先に解決する）。

## 最終 Phase: 最終検証・収束・製品仕様への反映

- [X] T013 最終の `swift build` → `swift test` → `scripts/dev/check-all.sh` → `scripts/make-app.sh` を順に実行し、結果とアプリの SHA-256 を `specs/021-favorites-startup-state/quickstart.md` に追記する。
- [X] T014 [MANUAL] 保守者が古い Folzio を終了して T011 と同じコマンドで最終ビルドを起動し、`specs/021-favorites-startup-state/quickstart.md` の最終ビルドの起動確認を行い、3ペインと選択した復元設定の結果を報告する。
- [X] T015 T014 の報告を `specs/021-favorites-startup-state/quickstart.md` に追記し、最終検証の記録と tasks の進捗をコミットする。
- [ ] T016 `speckit-converge` で `specs/021-favorites-startup-state/spec.md`・`plan.md`・`tasks.md` と参照製品仕様に対する実装を確認し、追加タスクがあれば実装・自動検証・必要な手動確認を最大3反復まで行う（後続の製品仕様反映タスクはこの収束後に実施する）。
- [ ] T017 `scripts/dev/check-spec-ids.sh` を実行してから、`specs/021-favorites-startup-state/spec.md` の反映先の項目を `specs/product/directory-tree.md`・`window-layout.md`、2つの契約差分を `specs/product/contracts/settings.md`・`localization.md` へ反映し、feature の冒頭に凍結注記を追加する（README の領域別件数も合わせ、反映後に `python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-spec-ids.sh` を実行する）。
- [ ] T018 [MANUAL] 保守者が `specs/product/` への反映差分と `specs/021-favorites-startup-state/spec.md` の凍結注記を確認し、反映のコミットを承認する。
- [ ] T019 T018 の承認後に `specs/product/` と `specs/021-favorites-startup-state/` の最終進捗をコミットし、ブランチ・検証結果・残課題を報告する。

## Dependencies & Execution Order

- T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 → T010。
- T010 → T011 → T012 → T013 → T014 → T015 → T016 → T017 → T018 → T019。
- テストは本実装の前に追加し、必要な検証対象がないことによる失敗を確認してから実装する。
- 手動確認を飛ばして、依存する記録・コミット・次の検証へ進まない。
- 収束後にコードを追加変更した場合は、対象の自動検証と手動確認を新しいビルドでやり直す。
- PR 作成・push・master 統合・Linear の Done 更新はこのタスク列に含めない。

## Parallel Opportunities

この対話フローでは同じセッションで順次実施する。
依存上は T007・T009 の翻訳と T005・T006 のツリーは別ファイルだが、並列実装は行わない。

## Implementation Strategy

最小の提供単位は、Core の保存・US87 の見出し復元・US88 の設定 UI を揃えたものとする。
各ストーリーのテストは分離しつつ、1つの実装 Phase で自動検証と実機確認を完了する。
実装コードとテスト以外の仕様文書更新は、tasks のチェック、上記で指定した quickstart の記録と
最後の製品仕様反映・凍結だけに限る。
