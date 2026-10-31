# Rename Contract: TAK-16

## UI

Return・右クリック・編集メニューから既存の編集を開始する。FR-024 の確認は常に表示する。別項目との競合は検証エラーとして表示し、置換ダイアログを出さない。拡張子の文字種だけの差は追加確認を出さない。フォルダの結果反映は FR-104・FR-105 に従う。

## validateNewName

公開シグネチャは変えない。existingNames は呼び出し側が元の保存名を完全一致で除外した兄弟名集合を渡す。集合に残る同名・case-only 名はすべて duplicate。自己名の除外は関数内で勝手に行わない。

## FileOperationService.execute

公開シグネチャは変えない。.rename の場合:

1. 既存の名前形式・元項目存在の検証。同じ表記は既存の no-op。
2. 親の列挙。失敗なら失敗結果。元エントリの完全一致だけを除外。
3. 別項目と大文字小文字を無視して一致すれば、resolution の値に関わらず sameNameExists。上書き・ゴミ箱移動・連番化をしない。
4. 自己の case-only で、ほかの競合がなければ target の存在だけで失敗にしない。通常改名で target が存在すれば競合として拒否する。
5. 既存の FileManager.moveItem を実行し、成功時に newName の表記の URL を返す。OS エラーは既存理由を表示する。

.copy / .move / .trash の振る舞いは変更しない。読み取りと書き込みの間の外部変更を完全に直列化する契約は追加しない。

## Acceptance matrix

| 状態 | 期待 |
|---|---|
| photo.png のみ、Photo.png へ | 両ボリューム種別で成功、保存名が Photo.png |
| Album のみ、album へ | 両ボリューム種別で成功、中身を保つ |
| photo.png と Photo.png の別エントリ | PHOTO.PNG への変更を拒否、両者を保つ |
| 別エントリが hard link / symlink / dangling symlink | 競合を拒否、リンクと元項目を保つ |
| 親の列挙不可 / 元項目なし / OS 移動失敗 | 失敗通知、成功結果を作らない |
| 同じ表記 / 確認キャンセル | 変更なし |
