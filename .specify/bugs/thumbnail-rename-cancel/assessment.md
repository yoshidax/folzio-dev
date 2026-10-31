# Bug Assessment: サムネイルの名前変更を拒否・キャンセルしても入力名が残る

- **Slug**: thumbnail-rename-cancel（Issue の内容から自動生成）
- **Created**: 2026-10-31
- **Source**: https://linear.app/takyoshida/issue/TAK-13/サムネイル形式で名前変更を拒否キャンセルしても編集後の名前が表示に残る
- **Issue**: TAK-13（In Progress）
- **Branch**: work（Cloud の作業ブランチを継続）
- **Assessed revision**: bfe63d52b8426e3ab18d10527f2e902964796b47（最新の origin/master を取り込み後に再照合）
- **Verdict**: valid（静的な制御フローで確認。エージェントによる GUI 再現は未実施）
- **Severity**: medium（表示とアクセシビリティ名の不整合。検証・キャンセルの早期 return では実ファイルの操作は始まらない）

## Report (verbatim or summarized)

TAK-13 の本文とコメントを Linear MCP で取得した。コメントはなし。
取得した Issue URL の host は `linear.app`、URL trust policy は `allowlisted`。

ユーザー報告では、サムネイル形式でファイル・フォルダ名を編集し、名前変更確認をキャンセルしても入力名が表示に残る。
ツリーにあるフォルダ名は元のままで、ファイルは別フォルダへ移動して戻ると表示が元に戻る。リスト形式では発生しない。
AI レビューでは無効な名前 `bad/name.jpg` を拒否した場合にも同様の問題が指摘された。
実ファイル名の GUI セッション中の直接検証は未実施との報告。

## Symptom

名前変更の検証エラー・確認キャンセルの後も、サムネイルの表示名とアクセシビリティ名に入力後の名前が残る。
期待は元の名前を維持し、名前変更が成功した場合だけ結果を表示すること。

## 仕様との照合

- `specs/product/file-list.md` **FR-013**: サムネイルには各ファイルの縮小画像とファイル名を表示する。
- `specs/product/file-operations.md` **US4-AS2**: 確認後にファイル名を変更して一覧へ反映する。
- 同 **FR-027**: 操作の結果をツリー・リスト・プレビューへ反映する。
- 同 **EC-14**: 使用できない文字・同名・パッケージになるフォルダ名はエラーを表示し確定しない。
- 同 **FR-022 / US4-AS6**: 確認のキャンセルではファイルシステムを変更しない。
- **判定**: 実装が既存仕様に反している。仕様変更ではなく bug fix として扱う。
  FR-022 単独のファイルシステム変更違反は確認していない。表示の不整合は FR-013 / FR-027 と照合した。

## Reproduction

1. 通常フォルダのファイル一覧をサムネイル形式にし、ファイルまたはフォルダの名前編集を開始する。
2. 新しい名前を確定し、名前変更確認モーダルでキャンセルする。
3. 入力後の名前が残ることを確認する。ツリーに同じフォルダがあれば元の名前と比較する。
4. 別フォルダへ移動して戻った場合に表示が元に戻ること、リスト形式では症状が出ないことを比較する。
5. 別経路として `bad/name.jpg` を確定し、検証エラーを閉じた後の表示を確認する。

上記は Issue の報告とコードに基づく確認手順であり、この Cloud セッションで GUI 実行はしていない。
拡張子変更確認のキャンセルもコード上は同じ早期 return を通るため、修正後の検証対象に加える。

## Suspected Code Paths

- `Sources/FolzioApp/FileList/ThumbnailModeView.swift:235` — `ThumbnailItemView.endRenaming`。
  243–245 行で元の名前を戻すが、250–252 行で入力名を表示名・ラベル・ビューのアクセシビリティ名へ再設定する。
- 同 `:754` — `commitRename` は非同期 Task で `onRename` を呼び、成功・失敗をセルへ返さない。
- 同 `:944` — セルのコールバックを `commitRename` へ接続する。
- `Sources/FolzioApp/Operations/FileOperationCoordinator.swift:101` — `rename`。
  検証エラー（109 行）、拡張子確認キャンセル（111 行）、操作確認キャンセル（122 行）は service 実行前に return する。
  これらの経路ではモデルの再読み込みも発生しない。
- 同 `:124–142` — service 実行後は成功項目の URL を反映し、`reloadCurrentFolder` を呼ぶ。
- `Sources/FolzioApp/FileList/ThumbnailModeView.swift:582` — `applyModel` は URL 配列が同じなら `reloadData` しない。
  単に選択のモデル通知を受けても、誤表示を必ず復元できるわけではない。
- 同 `:145` — `configure` が編集していないセルの表示名・アクセシビリティ名をモデルの `file.name` に合わせる。
- `Sources/FolzioApp/FileList/ListModeView.swift:468` — `finishRenaming` は元の名前を表示してから非同期処理を呼び、入力名を先行表示しない。

## Root Cause Hypothesis

**Confidence: high.** サムネイルの編集終了処理が未確定の入力名を先行表示し、戻り値のないコールバックへ処理を渡す。
コーディネーターの検証・確認で拒否すると、実操作もモデルの再読み込みも行わず終了するため、入力名だけがセルに残る。
モデルやファイルシステムを変更しなくても成立し、リスト形式との差、ツリーとの不一致、再表示で復旧する観察に整合する。
service 実行後の失敗では再読み込みが呼ばれるが、同一 URL の場合に必ずセルが再構成されるとは限らないため、
「すべての失敗で残る」「service 後なら必ず戻る」とは断定しない。

## Proposed Remediation

**Preferred**: `ThumbnailItemView.endRenaming` で `oldName` を戻した後、入力名を表示・アクセシビリティへ再設定しない。
入力名は既存コールバックの引数として渡すだけにする。成功後は既存のモデル更新・一覧再読み込みで新しい名前を反映する。
リスト形式と同じ責務分担にそろえ、コーディネーターの API や確認フローは変更しない。

**Alternative**: コールバックから成功・失敗を返して表示を更新する。ただし非同期処理中のセル再利用や別フォルダへの移動を考慮する必要があり、
既存の成功反映経路とも重複するため、この局所的な不具合に対して変更範囲が広い。

**Files likely to change**:

- `Sources/FolzioApp/FileList/ThumbnailModeView.swift`
- `.specify/bugs/thumbnail-rename-cancel/fix.md`
- `.specify/bugs/thumbnail-rename-cancel/test.md`
- AppKit の回帰テストを追加する場合は `Package.swift` と新しい App 用テストファイル。
  現状は Core・性能のテストターゲットのみであり、AppKit のセルを Core に持ち込まない。

**Tests to add or update**:

- 回帰を固定するテストは、変更前に失敗し、変更後に通るものにする。セル編集を確定し、処理が成功しないコールバックでも
  表示名・ラベルとビューのアクセシビリティ名が元のままで、コールバックには入力名が渡ることを検証する。
- AppKit のテストターゲット導入が必要か、既存テスト構成と macOS CI で実行できるかを fix 段階で確定する。
  Core の名前検証テストだけではこの UI の回帰を検出できない。
- GUI: ファイル・フォルダの操作確認キャンセル、無効名・既存名の拒否、拡張子変更確認キャンセル、Escape、空名・同名。
- GUI: 成功した名前変更が一覧・ツリー・アクセシビリティへ反映されること。処理中のフォルダ移動やセル再利用も確認する。
- Cloud の静的検査、macOS CI のビルド・テスト、保守者の起動スモークを分けて記録する。

## Risks & Considerations

- 成功する操作でも完了までは元の名前が見える。既存のリスト形式と同じ動作である。
- キャンセル時に再列挙する修正は不要。結果に先行するセルの書き換えを取り除く。
- 入力の空白処理や検証ルールは今回の変更対象に含めない。
- ソース変更・回帰テスト・CI・GUI 検証はまだ実施していない。assessment のみ作成した。
- 最初の `git fetch origin master` はプロキシ接続エラー、次の試行は中断となったが、その後ネットワーク権限付きで取得に成功した。
  `git merge origin/master` で bfe63d52b8426e3ab18d10527f2e902964796b47 へ fast-forward 済み。
  関連するソース・仕様・Package.swift は当初の確認対象 0477deff から変更がなく、診断は変わらない。
- Linear の `get_agent_context` は `Tool get_agent_context not found` を返した。共有ノートは取得できず、コードを根拠に診断した。
- `.specify/extensions.yml` に `before_bug_assess` / `after_bug_assess` の登録はない。

## Open Questions

- [NEEDS CLARIFICATION: 発生したアプリの正確なバージョン・ビルド。現行コードで同じ制御フローを確認済みのため、修正方針の前提にはしない。]
- 診断と修正方針の保守者確認後、`$speckit-bug-fix slug=thumbnail-rename-cancel` へ進む。
  `AGENTS.md` の「assess の判定と診断をユーザーに確認してもらってから fix へ進む」に従う。
