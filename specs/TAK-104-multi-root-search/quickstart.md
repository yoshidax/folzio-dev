# Quickstart: 複数の検索起点の検証

## 自動の検証

| 実行する者 | コマンド | 確かめること |
|---|---|---|
| Cloud | `scripts/dev/check-all.sh` | 形式・コメント・公開境界などの検査 |
| CI（macOS） | `swift build`、`swift test --no-parallel --skip FolzioPerformanceTests` | Core・App のテスト |
| CI（macOS） | 性能テスト（`FolzioPerformanceTests`） | SC-249 のテストと、既存の SC-016・SC-054 が基準内 |

## 保守者のローカルでの確認

```bash
scripts/make-app.sh
```

```bash
open .build/Folzio.app
```

### テストデータ

`FixtureSets.multiRootSearch(in:)` が `multi-root-search/` を作る（保守者の依頼で追加）。このデータだけを作るときは
`--multi-root-search` を付ける。付けないときは、ほかのテストデータと一緒に作る（`FixtureSets.makeAll`）。

```bash
scripts/make-fixtures.sh ~/FolzioFixtures --multi-root-search
```

以下の手順の A・B などは、`~/FolzioFixtures/multi-root-search/` の下の次のフォルダを指す。キーワードは `kyoto` を使う。

| フォルダ | 中身と用途 |
|---|---|
| `A/` | `kyoto_a.jpg`・`other_a.jpg`・フォルダ `kyoto_folder_a/`。重ならない起点の1つ目（US99） |
| `B/` | `kyoto_b.jpg`・`other_b.jpg`・`kyoto_folder_b/kyoto_b2.png`。重ならない起点の2つ目。10 で名前の変更と削除に使う |
| `A/C/` | `kyoto_c.jpg`。A の配下の起点で、A と重ねると除かれる（US100-AS2） |
| `A/.hidden/D/` | `kyoto_d.jpg`。A の隠しフォルダの中の起点で、A と重ねても両方を検索する（US100-AS3） |
| `link-to-A` | A へのシンボリックリンク。A と重ねると1つにまとまる（US100-AS4） |
| `same-name/tmp1/Photos/`・`same-name/tmp2/photos/` | 大文字小文字だけが違う同じ名前の起点。「場所」列が絶対パスから始まる（EC-305・US100-AS5） |
| `rows/01/`〜`rows/10/` | 各 `kyoto_rowNN.jpg`。10 行すべてを埋める起点（US99-AS7・SC-252） |

A と B だけで `kyoto` を検索すると、6 件（ファイル `kyoto_a.jpg`・`kyoto_c.jpg`・`kyoto_b.jpg`・`kyoto_b2.png` とフォルダ2つ）が一致する。
`other_*.jpg` と、隠しフォルダの中の `kyoto_d.jpg` は一致しない。

### 手順

1. 起動スモーク: 3 ペインが表示される。
2. ⌥⌘F でモーダルを開く。起点の行は1行で「削除」は無効、キーワード欄の下にワイルドカードの説明がある（US99-AS1・US101-AS1）。
3. 「起点を追加」で行を加えて B を入力し、`kyoto` で検索する。A と B の結果が1つの一覧に出て、検索バーが「A ほか 1 か所」、
   ツールチップに両方の絶対パスが出る。「場所」列が A・B から始まる（US99-AS2〜AS4）。
4. 行を3つにして2行目を削除し、残りの値とフォーカスを確かめる。2行目の「選択…」で別のフォルダを選ぶ（US99-AS5・AS6）。
5. 10 行まで加えると「起点を追加」が無効になり、モーダルが画面に収まる（US99-AS7・SC-252）。
6. 2行目に存在しないパスを入れて検索し、行の番号付きの理由とフォーカスを確かめる（US99-AS8）。
7. A と A、A と `A/`（末尾の `/`）、A と `link-to-A`、A と A/C、A と A/.hidden/D、`same-name` の2つで検索し、重複しないことと
   「場所」列を確かめる（US100）。
8. 日英の両方で、ワイルドカードの説明が切れずに表示され、VoiceOver がキーワード欄の説明として読み上げる（US101・SC-252）。
9. キーボードだけで行の追加・削除・入力・「選択…」・検索をする（SC-251）。
10. A と B の検索結果の表示中に B の名前を変え、検索バーのツールチップと「場所」列が追随する。B を削除すると B の結果だけが外れる
    （US99-AS10・AS11）。
