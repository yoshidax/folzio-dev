# Quickstart: コピー元を移動した後もペーストできるようにする

## 自動の検証

Cloud では `scripts/dev/check-all.sh` だけを実行し、`swift build`・`swift test` は macOS の CI で確かめる。

```bash
swift build
swift test
scripts/dev/check-all.sh
scripts/make-app.sh
```

## GUI の確認

古い Folzio を終了してから `open .build/Folzio.app` で起動し、3ペインが表示されることを確かめてから行う。
消えても困らないファイル A とフォルダ F（中にファイルを入れる）、空のフォルダ B・C を用意する。

1. Folzio で A を選択して ⌘C、フォルダ B で ⌥⌘V、フォルダ C で ⌘V する。
   - A が B へ移動し、C に A のコピーができる。失敗の表示は出ない（US94-AS1）
2. Folzio で A をコピーし、Folzio で A の名前を A2 に変えてから、フォルダ C で ⌘V する。Finder で名前を変えた場合も同じく行う。
   - A2 が C へコピーされる（US94-AS2）
3. Folzio で F をコピーし、Finder で F を別のフォルダへ移動してから、Folzio のフォルダ C で ⌘V する。
   - 移動した F が中身ごと C へコピーされる（US94-AS3）
4. Folzio で A をコピーし、A をゴミ箱に入れてから、フォルダ C で ⌘V する。続けてフォルダ B で ⌥⌘V する。
   - ⌘V でゴミ箱の中の A が C へコピーされ、⌥⌘V で A がゴミ箱から B へ移動する（US94-AS4・US94-AS5）
5. Folzio で A をコピーし、Finder のフォルダで ⌘V する。テキストエディタでも ⌘V する。
   - Finder では A がコピーされ、テキストエディタでは A のファイル名が貼られる（US94-AS6・US94-AS7・SC-237）
6. Finder で A をコピーし、Folzio のフォルダ B で ⌥⌘V、フォルダ C で ⌘V する。
   - B へ移動した A が C へコピーされる（US94-AS8）
7. Folzio で A をコピーし、A を別のボリューム（外付けのディスクなど）へ移動してから、フォルダ C で ⌘V する。
   別のボリュームがなければ、A を削除してゴミ箱を空にしてから行う。
   - A の名前と「見つからない」理由を示して失敗する（US94-AS9）
8. Folzio で A をコピーした直後に、続けて ⌘V する（コピーとペーストを素早く続ける）。
   - A のコピーがペーストされる（前のクリップボードの内容がペーストされない。research.md R3）
9. 手順 1〜4 の後に、手順の前と同じコマンドでクリップボードを書き出す（research.md R1 のコマンド）。
   - `public.file-url` が `file:///.file/id=…` のまま変わっていない（SC-236）

## 検証の記録

### 自動の検証（2026-11-20）

| 項目 | 結果 |
|---|---|
| `scripts/dev/check-all.sh`（Cloud） | 成功（all checks passed） |
| CI の `swift build`（`815b880`） | 失敗。`CFURLCreateFileReferenceURL`・`CFURLCreateFilePathURL` の戻り値が `Unmanaged<CFURL>` で型が合わなかった |
| CI の `swift build`・通常のテスト（`4a59ef8`、修正後） | 成功。1326 件 |
| CI の性能テスト（`4a59ef8`） | 28 件中 7 件が基準値を超えた（名前の絞り込み・JPEG のデコード・フォルダへの戻り・名前の変更の付け替え・検索のまとめ・スライドショーの候補 2 件） |
| CI の `swift build`・通常のテスト（`ff947f8`、tasks.md だけの変更） | 成功 |
| CI の性能テスト（`ff947f8`） | 28 件中 2 件が基準値を超えた（JPEG のデコード 0.76 秒 / 0.5 秒、スライドショーの候補 200,000 件 0.2028 秒 / 0.2 秒） |

- 性能テストで基準値を超えたテストは、この feature が変えたコード（コピーとペースト）を通らない。同じソースの2回の実行で、
  超えたテストの数と組み合わせが変わった（7 件と 2 件）ため、共有のランナーでの測定のぶれと判断した
  （docs_private/cloud-agent-workflow.md の 4 章の 2026-10-31 の例と同じ）
- 新しいテスト: `ClipboardFileReferencesTests`（8件）、`ClipboardPasteTests`（6件）、`PasteboardFileURLsTests` への追加（4件）

### GUI の確認

[checklists/validation.md](checklists/validation.md) に記録した。
