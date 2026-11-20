# Research: コピー元を移動した後もペーストできるようにする

## R1 クリップボードの中身を読まずに、書き換えてよいかを決める

- **Decision**: Folzio がクリップボードに書いたとき（`PasteboardFileURLs.write`）と、ペースト・移動ペーストで読んだとき
  （`FileOperationCoordinator.paste`）に、ファイルの並びと `NSPasteboard.changeCount` を覚える。移動の後は
  `changeCount` だけを読み、覚えたときと同じなら、覚えた並びから新しい並びを作って書き直す。
- **Rationale**: FR-354（file-operations.md）は「クリップボードの中身は、ユーザーがペーストを実行したときだけ読む」と定めている。
  `changeCount` はクリップボードの版の番号で、中身ではない。`changeCount` が変わっていなければ、覚えた並びはクリップボードの
  ファイルと同じである。別のアプリがコピーした後は `changeCount` が増えるため、書き換えない（US94-AS6）。
- **Alternatives considered**:
  - 移動の後にクリップボードの file URL を読んで書き換える: ペーストの実行時以外に中身を読むため、FR-354 に反する。
    別のアプリのコピーを Folzio でペーストせずに移動した場合（US94-AS8）も対象にできるが、保守者の選んだ範囲（Q3）の
    報告の手順は R1 で満たせる。
  - ファイルの参照（file reference URL・ブックマーク）をクリップボードに置く: ほかのアプリが読めるかと、Finder の仕組みが
    確かめられていない（A-248）。Folzio の外での移動は対象外と決めたため（Q1）、必要がない。

## R2 移動前と移動後の対応の取り方

- **Decision**: `FileOperationCoordinator.transferItems` は項目ごとに `service.execute` を呼ぶので、移動の結果の
  `succeeded` の最初の URL を、その項目の移動後の場所とする。対応を `RenamedFolder(from:to:)` の配列として返す。
  名前の変更は、`rename` の `result.succeeded.first` を使う。
- **Rationale**: 衝突の「両方残す」で付いた名前（EC-283）、別のボリュームへの移動（EC-284）、途中の中止・失敗（EC-281）が、
  実際の結果から決まる。ファイルシステムをもう一度調べなくてよい。
- **Alternatives considered**: 移動先のフォルダと元の名前から推測する: 「両方残す」の名前と失敗を反映できない。

## R3 付け替えの規則

- **Decision**: 既存の `RenamedFolder.rebase(_:)` を使う。項目そのものと、その中の項目（子孫）を付け替え、名前の前方が
  一致するだけの兄弟（`Photo` と `Photos`）は付け替えない。1回の操作の対応を順に適用し、変わった URL が1つもなければ書き直さない。
- **Rationale**: フォルダの名前の変更（FR-104・FR-105（directory-tree.md））で使い、10,000 件の付け替えの性能も確かめた型である
  （`RenamedFolder` のコメントの R67）。パスの文字列だけを比べ、ファイルシステムにアクセスしない。`/private` を
  付けるか外すかが存在に依存する `standardizedFileURL` を使わない理由も同じ型に書いてある。
- **Alternatives considered**: 新しく比較を書く: 同じ規則の重複になる。

## R4 書き直す形

- **Decision**: 書き直しは `PasteboardFileURLs.write`（Folzio の ⌘C と同じ。`clearContents` の後に `NSURL` の並びを
  `writeObjects`）で行い、書いた後の `changeCount` で記録を更新する。
- **Rationale**: Folzio のコピーと同じ形にするため、Folzio と別のアプリの両方で同じくペーストできる（FR-414）。記録を更新するため、
  続けて移動ペーストした場合も書き換えが続く（EC-285）。
- **未確認**: Finder で Folzio のコピーを ⌘V できることは、リポジトリの検証記録にない。SC-237 として手動確認で確かめる。
- **Alternatives considered**: 別のアプリが置いた表現（ファイル名の文字列など）を残す: その表現を読むには中身を読む必要があり、
  R1 に反する（A-250）。

## R5 記録の持ち方

- **Decision**: `PasteboardFileURLs` に、クリップボードの名前（`NSPasteboard.Name`）ごとの記録を static に持つ。
  `FileOperationCoordinator` は書き換える先のクリップボード（既定は `.general`）を property で持ち、テストでは
  一意の名前のクリップボードを使う。
- **Rationale**: ファイルリストとツリーのコピーは `PasteboardFileURLs.write` を通るため、記録の場所を1か所にできる。
  名前ごとに分けると、テストが一般クリップボードを使わずに済み、並行するテストが干渉しない。ドラッグ用のクリップボードに
  書いた記録は、書き換えに使わない（書き換えは一般クリップボードだけ）。
- **Alternatives considered**: Coordinator に記録を持たせる: コピーはファイルリストとツリーの view controller から直接書くため、
  記録の経路が分かれる。
