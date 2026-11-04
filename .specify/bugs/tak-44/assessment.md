# Bug Assessment: サムネイル形式でリスト内のファイルをリスト内のフォルダへドラッグ&ドロップできない

- **Slug**: tak-44（Issue ID から生成。既存の `tak-9`・`tak-12` に合わせた）
- **Created**: 2026-11-01
- **Source**: [TAK-44](https://linear.app/takyoshida/issue/TAK-44/サムネイル形式でリスト内のファイルをリスト内のフォルダへドラッグandドロップできない)（host: linear.app、allowlisted。Linear MCP で取得）
- **Verdict**: likely valid, needs reproduction（保守者の報告による。Cloud では GUI を起動できず、エージェントは再現していない）
- **Severity**: medium（サムネイル形式でアプリ内ドラッグによる整理（US23）ができない。リスト形式・メニュー・ツリーへのドロップで代替でき、データの損失はない）

## Report

Issue の要約（2026-11-01 起票、master `f458d787` で静的確認）:

> ファイルリストをサムネイル形式にしているとき、リスト内のファイルを同じリスト内のフォルダへドラッグ&ドロップしても、移動もコピーも行われない。
> リスト形式では同じ操作ができる。

起票時の調査メモは、`ThumbnailModeView` の `validateDrop` が `dropOperation.pointee == .on` を要求する点を推定の原因に挙げ、
ドラッグが始まっているか、`validateDrop` / `acceptDrop` が呼ばれるか、検索結果のフォルダでも起きるかを未確認としている。

## Symptom

サムネイル形式で、ファイルをリスト内のフォルダ項目へドロップしても、移動（⌥ なし）もコピー（⌥ あり）も起きない。
期待する動作は、リスト形式と同じく、確認のうえ移動またはコピーされること（FR-022〜FR-027）。

## 仕様との照合

実装が仕様に反していると判断する（fix へ進む）。

- `specs/product/file-operations.md` FR-163: 宛先は「通常一覧・検索結果の実フォルダ項目」。サムネイル形式を除外していない。
- 同 US23-AS2: 「リスト形式またはサムネイル形式の選択済みファイル・フォルダをツリーまたはリストのフォルダにドラッグすると…」。
- 同 FR-164 / US23-AS3: 有効な宛先を視覚的に示し、Option の変更に追従する。
- 同 SC-074: 「ツリー・リスト形式・サムネイル形式の各ドラッグ元とツリー・リストの両宛先について、移動・Option コピーをそれぞれ確認し…」。

なお SC-074 は「リストの宛先」を形式で分けていない。サムネイル形式のリストを宛先とする組み合わせは、仕様の範囲に含まれると読む。

## Reproduction

1. ファイルリストをサムネイル形式にする。
2. サブフォルダとファイルがあるフォルダを表示する。
3. ファイルを選び、リスト内のサブフォルダのサムネイル（画像の部分）へドラッグしてドロップする。
4. ⌥ なし・⌥ ありのどちらでも、移動・コピーが起きない。
5. リスト形式で同じ操作をすると、移動・コピーができる。

- [NEEDS CLARIFICATION: フォルダ項目の名前（サムネイルの下の文字）の上でドロップした場合も失敗するか。下の仮説 A の判別に使う]
- [NEEDS CLARIFICATION: サムネイル形式からツリーのフォルダへのドロップはできるか。できればドラッグの開始は正常と判断できる]

## Suspected Code Paths

- `Sources/FolzioApp/FileList/ThumbnailModeView.swift:81, 90-133`（`ThumbnailItemView.loadView`）— 各項目の上部（項目の幅の正方形。項目の大半）を
  `NSImageView` が覆う。`unregisterDraggedTypes()` を呼んでいない。
- `Sources/FolzioApp/FileList/ThumbnailModeView.swift:970-977`（`validateDrop`）— 提案された `dropOperation` が `.on` でなければ `[]` を返す。
  `.on` への付け替えは、操作が有効なときだけ行う。
- `Sources/FolzioApp/FileList/ThumbnailModeView.swift:979-988`（`acceptDrop`）— `dropOperation == .on` を要求する。
- `Sources/FolzioApp/Shared/InternalDrag.swift:35-56`（`operation`）— 宛先の検証は非同期。最初の呼び出しは `[]` を返して検証を始め、
  次の呼び出しでキャッシュの結果を返す。再度 `validateDrop` が呼ばれることを前提にしている。
- 比較: `Sources/FolzioApp/FileList/ListModeView.swift:38-72`（アイコンの `NSImageView` は 16pt で行の一部だけ）、`:580-596`
  （`validateDrop` は有効時に `setDropRow(row, dropOperation: .on)`）。
- ドラッグ元の設定（`:526-528` の `registerForDraggedTypes`・`setDraggingSourceOperationMask`・`InternalDrag.register`、
  `:1050` の `pasteboardWriterForItemAt`）はリスト形式と同等で、問題は見当たらない。

## Root Cause Hypothesis

信頼度: medium（GUI で未確認。A が最も有力）

- **A（有力）: 項目の `NSImageView` がドロップを横取りする**。`NSImageView` は自分でドラッグを受け付けるため、コレクションビューの項目の中にあると、
  その上のドロップが `NSCollectionView` に届かず、`validateDrop` が呼ばれない。`unregisterDraggedTypes()` で解消したという報告が複数ある
  （Stack Overflow 51639849「cannot drag onto image in nscollectionviewitem」、cocoa-dev 2008-05「NSImageView blocking drag -- solved」では
  無効化した `NSImageView` でも横取りした）。サムネイル形式では画像が項目の大半を覆うため、ほぼ常に失敗する。リスト形式では 16pt のアイコン以外
  （名前の部分）にドロップするため、症状が出にくい。報告の「サムネイル形式だけで起きる」と整合する。
- **B（補助）: 非同期の検証と再問い合わせ**。`InternalDrag.operation` は最初に `[]` を返す。`NSCollectionView` が同じ宛先について
  `validateDrop` を再び呼ばなければ、無効のまま残る。AppKit がそう振る舞うという資料は見つからず、未確認。
- **C（補助）: 提案される操作が `.on` でない**。項目の端や項目間では `.before` が提案され、`validateDrop` が即座に `[]` を返す。
  項目の中央では `.on` が提案されると考えられ、単独で「常に失敗する」原因にはなりにくい。

## Proposed Remediation

**Preferred**:

1. `ThumbnailItemView.loadView` で `thumbnailImageView.unregisterDraggedTypes()` を呼び、画像がドロップを横取りしないようにする（A）。
2. `validateDrop` で、提案された `dropOperation` に頼らず、ドラッグの位置（`info.draggingLocation` をコレクションビューの座標へ変換）の下にある
   項目を `indexPathForItem(at:)` で求める。それが実フォルダ項目なら、`proposedIndexPath` をその項目へ、`dropOperation` を `.on` に付け替えたうえで
   `InternalDrag.operation` を返す（C。リスト形式の `setDropRow(row, dropOperation: .on)` と同じ考え方）。項目の外・背景・`..`・ファイル・zip 内は
   従来どおり受け付けない（FR-163）。`acceptDrop` は付け替え後の `.on` を前提とするため、変更しない。
3. B は、1・2 の後の GUI 確認で、フォルダの上で止めても受け付けない場合だけ対処する（推測で AppKit の内部の振る舞いに依存した変更をしない）。

**Alternatives**:
- `NSImageView` を、ドラッグを受け付けないサブクラス（`draggingEntered` 等を持たない `NSView` + `layer.contents`）に置き換える。確実だが変更が大きい。
- リスト形式のアイコン（`ListModeView.swift:40`）とツリーのアイコン（`DirectoryTreeViewController.swift:1933`）にも同じ
  `unregisterDraggedTypes()` を入れる。16pt のアイコンの上でのドロップも受け付けるようになる。今回の症状の範囲外のため、保守者の判断で含める。

**Files likely to change**:
- `Sources/FolzioApp/FileList/ThumbnailModeView.swift`
- `Tests/FolzioAppTests/ThumbnailRenameTests.swift` または新しい `Tests/FolzioAppTests/ThumbnailDropTargetTests.swift`

**Tests to add or update**:
- 回帰テスト（FolzioAppTests）: `ThumbnailItemView` の `loadView` 後、`imageView?.registeredDraggedTypes` が空であること。
  あわせて、素の `NSImageView()` の `registeredDraggedTypes` が空でないことを確かめる前提の検査を置き、仮説 A の根拠を CI で確かめる
  （この前提が失敗したら、A は誤りと判断して作業を止め、報告する）。
- ドロップ位置の解決は `NSDraggingInfo` を要するため、自動テストは置かず、GUI の確認（SC-074 のサムネイル形式の行）で確かめる。

## Risks & Considerations

- 画像ビューの `unregisterDraggedTypes()` は、画像ビューへの外部ファイルのドロップ（画像の差し替え）を無効にする。`isEditable` は false で、
  その機能は使っていないため、影響はない。
- アプリ外からのドロップの動作は変えない（FR-163「アプリ外とのドラッグの動作変更は対象外」）。`InternalDrag.urls` が内部のドラッグ元だけを受け付ける点は変えない。
- Cloud では GUI もビルドもできない。ビルドとテストは CI、ドロップの確認は保守者のローカルで行う。GUI で再現を確かめるまで、bug-test の判定は `partial` とする。

## Open Questions

- [NEEDS CLARIFICATION: 名前の部分へのドロップ、サムネイル形式からツリーへのドロップの成否（Reproduction を参照）。分かれば A の確度が上がるが、修正の着手には必須でない]
- [NEEDS CLARIFICATION: Alternatives のリスト形式・ツリーのアイコンへの同じ対処を、この修正に含めるか]

## Sources

- [Stack Overflow 51639849: cannot drag onto image in nscollectionviewitem](https://stackoverflow.com/questions/51639849/cannot-drag-onto-image-in-nscollectionviewitem)（検索結果の要約で確認。本文は取得できなかった）
- [cocoa-dev 2008-05: Re: NSImageView blocking drag -- solved](https://lists.apple.com/archives/cocoa-dev/2008/May/msg00200.html)（検索結果の要約で確認）
