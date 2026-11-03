# Bug Assessment: ツリーから新規フォルダを作成するとファイルリストに新しいフォルダが表示されない

- **Slug**: tak-57（Issue ID から生成。既存の `tak-9`・`tak-12`・`tak-44` に合わせた）
- **Created**: 2026-11-03
- **Source**: [TAK-57](https://linear.app/takyoshida/issue/TAK-57)（host: linear.app、allowlisted。Linear MCP で取得）
- **Verdict**: likely valid, needs reproduction（保守者の GUI 操作による報告。Cloud では GUI を起動できず、エージェントは再現していない）
- **Severity**: medium（作成したフォルダが一覧に見えず混乱するが、再読み込み（別フォルダへ移動して戻る）で回復し、データの損失はない）
- **Linear**: TAK-57（Bug）。着手時に `In Progress` へ更新済み
- **基準**: 開発用 master `aa1a30f`（Cloud 作業ブランチ `claude/compassionate-keller-815prt` は同じコミット）

## Report

Issue の要約（2026-11-03 起票）:

> ツリーでフォルダを選択した状態から「新規フォルダ」（右クリック、⇧⌘N、「ファイル > 新規フォルダ」）でフォルダを作成すると、
> ツリーには新しい行が作られて名前の編集が始まるが、ファイルリストは更新されない。別のフォルダへ移動して戻ると表示される。

未確認の範囲（Issue より）: 一覧の形式（リスト／サムネイル）、検索結果の表示中かどうか、毎回再現するか。

## Symptom

作成先フォルダをファイルリストが表示中でも、ツリーからの作成直後にファイルリストへ新しい行が加わらない。
期待する動作は、並べ替えの位置に即座に加わること（FR-214）。作成先を表示していなければ、ファイルリストは変わらなくてよい。

## 仕様との照合

実装が仕様に反している可能性が高い（fix へ進む前提。ただし再現は未実施）。

- `specs/product/file-operations.md` FR-214: 「作成先がファイルリストに表示中なら新しい行を並べ替えの位置に加え」る。
- 同 FR-208 (1)(3)、FR-209: ツリーからの作成の手段と既定名。
- 同 FR-210 (2): ツリーからの作成は、ツリーの選択・ファイルリストの表示と選択・プレビュー・最後に選択していたフォルダを変えない。
  ファイルリストの内容を更新しない根拠にはならない（表示を変える規定ではなく、行を加える規定は FR-214）。
- 仕様の誤り・未定義を示す根拠は見つからなかった。

## Reproduction

1. ツリーでフォルダ A を選択し、ファイルリストに A の内容を表示する。
2. A の行の右クリックメニュー「新規フォルダ」（またはツリーにフォーカスがある状態で ⇧⌘N）を実行する。
3. ツリーに新しい行が加わり名前の編集が始まるが、ファイルリストに行が加わらない。

[NEEDS CLARIFICATION: ファイルリストがリスト形式かサムネイル形式か。毎回起きるか。右クリックと ⇧⌘N の両方で起きるか。
ファイルリストが表示していたのは確かに作成先 A だったか（右クリックした行が選択中の行と別のフォルダだった場合は仕様どおり）。]

## Suspected Code Paths

- `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift:634-668` `createFolder(for:)` / `beginNamingNewFolder(_:in:)` —
  ツリーだけを更新し、ファイルリストの更新は coordinator に任せている。
- `Sources/FolzioApp/Operations/FileOperationCoordinator.swift:123-136` `createFolder(in:)` —
  `model.listing.folder.standardizedFileURL.path == parent.standardizedFileURL.path` のときだけ
  `await model.reloadCurrentFolder()` を呼ぶ。パスの比較は symlink を解決しない。
- `Sources/FolzioCore/Browser/BrowserModel.swift:798-856` `reloadCurrentFolder()` —
  列挙（`lister.mediaFiles`、`Task.detached`）の完了順を保証する仕組みがない。`navigationGeneration` は
  フォルダ移動でしか進まないため、同じフォルダの再読み込み同士の前後は判別できない。完了した結果が `allFiles` を無条件に置き換える。
- `Sources/FolzioCore/Browser/BrowserModel.swift:858-913` `handleFileSystemEvent(_:)` — FSEvents でも表示中のフォルダを同じ関数で再読み込みする。
- `Sources/FolzioApp/FileList/ListModeView.swift:384-430` `applyModel()`、`ThumbnailModeView.swift:682-724` —
  `listing.files` の URL 列が変わると `reloadData()`。`isHidden` のときは再読み込みを `viewDidUnhide` まで遅らせる。

読んだ範囲では、コード上に「ツリーからの作成だけファイルリストを更新しない」分岐は見つからなかった
（coordinator の条件が成り立てば再読み込みされる設計）。

## Root Cause Hypothesis

**未確定（confidence: low）。** 候補を可能性の高い順に挙げる。

1. 同じフォルダの再読み込みの競合（TAK-11 と同系統）。`reloadCurrentFolder()` が直列化されておらず、作成前に始まった古い列挙が
   coordinator の再読み込み（または後続の FSEvents による再読み込み）より後に完了すると、新しいフォルダを含まない一覧で
   `allFiles` が上書きされる。「別のフォルダへ移動して戻ると表示される」という症状と整合する。
   ただし、作成後に始まる列挙は必ず新しいフォルダを含むため、成立には作成前に始まった列挙が遅れて完了する必要がある。
2. 作成先の URL とファイルリストの `listing.folder` のパス表現が一致せず（symlink、`/private` 等）、coordinator の条件が偽になる。
   このとき再読み込みは FSEvents 任せになる。
3. 表示側（`applyModel()`）が条件によって再読み込みをスキップしている（ペインが隠れている等）。

仮説 1 は TAK-11 の PR #20（未マージ）の修正対象と重なる可能性がある。

## Proposed Remediation

**Preferred**: 原因の特定を先に行う。Cloud では GUI を起動できないため、次の順で進める。

1. 仮説 1 を Core のテストで固定する。`BrowserModel` に、列挙を遅らせて順序を入れ替えられる `DirectoryListing` のテスト用スタブを渡し、
   「古い列挙が新しい列挙より後に完了しても、新しい結果が残る」ことを確かめるテストを `Tests/FolzioCoreTests` に足す。
   現状で失敗すれば原因の一つを再現できたことになる。
2. 失敗した場合の修正: `reloadCurrentFolder()` に再読み込み専用の世代番号（フォルダ移動の `navigationGeneration` とは別）を設け、
   完了時に最新でない結果を捨てる。TAK-11 の修正と衝突しないよう、PR #20 のマージ状況を確認してから着手する。
3. 仮説 2 を調べる。coordinator の比較をパスの文字列から、表示中のフォルダと同じ基準（`standardizedFileURL` に加えて必要なら
   `resolvingSymlinksInPath`）に揃えるかを、ツリーの URL とファイルリストの URL の作り方を読んで判断する。
   coordinator の条件を `FileOperationCoordinator` から切り出して Core の関数にできれば、テストで固定できる。

**Alternatives**:
- 作成後に coordinator が成功した `created` を `BrowserModel` へ直接渡し、一覧へ行を加える。列挙結果に依存せず確実だが、
  並べ替え・フィルターの規則を二重に持つことになり、FSEvents の再読み込みとの整合に注意が要る。

**Files likely to change**:
- `Sources/FolzioCore/Browser/BrowserModel.swift`
- `Sources/FolzioApp/Operations/FileOperationCoordinator.swift`（仮説 2 の場合）
- `Tests/FolzioCoreTests/` の `BrowserModel` のテスト

**Tests to add or update**:
- 古い列挙が遅れて完了しても、新しい一覧が残る（仮説 1）。
- 作成先と表示中のフォルダが同じ場所を別の表現で指すときに再読み込みされる（仮説 2）。

## Risks & Considerations

- 修正は TAK-11（PR #20）と同じ関数に触れる。マージ順によって競合するため、先に PR #20 の状態を確認する。
- 再現できないまま修正すると、原因を外す恐れがある。GUI での再現と修正後の確認は保守者に依頼する（判定は、再現を確かめるまで `partial`）。
- `reloadCurrentFolder()` はファイル操作・FSEvents・設定変更など複数の経路から呼ばれる。順序の変更は選択・プレビューの更新に影響しうる。

## Open Questions

- [NEEDS CLARIFICATION: 保守者の環境で、ファイルリストはリスト形式・サムネイル形式のどちらだったか。毎回再現するか。]
- [NEEDS CLARIFICATION: 作成したフォルダは名前の編集を確定した後もファイルリストに現れなかったか（確定後の FSEvents で現れるか）。]
- [NEEDS CLARIFICATION: TAK-11 の PR #20 のマージ予定。修正を #20 の後に載せるか、同じ原因として #20 に含めるか。]
