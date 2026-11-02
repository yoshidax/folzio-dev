# Quickstart: ファイル名検索で zip ファイルも検索対象にする

保守者のローカル（macOS）で行う確認。結果は実施後にこのファイルへ記録する。

## 準備

```bash
swift build
scripts/make-app.sh
open .build/Folzio.app
```

次の構成のフォルダ（例: `~/ZipSearchFixture`）を用意する。

```text
ZipSearchFixture/
├── Kyoto/                  （フォルダ）
├── kyoto_notes.zip
├── a/backup.zip
├── b/backup.zip
├── photos.zip              （中に kyoto/ というディレクトリと kyoto_01.jpg）
├── x.zip/                  （名前が .zip のフォルダ）
├── .kyoto_hidden.zip       （隠しファイル）
└── SHOUT.ZIP
```

## シナリオ

1. 「zipファイルを表示」をオフにして `ZipSearchFixture` を起点に `kyoto` を検索する → フォルダ `Kyoto` だけが出る（US52-AS1）。
2. Esc で戻り、「zipファイルを表示」（⌃⌘Z）をオンにして、同じ検索をする → `Kyoto` と `kyoto_notes.zip` が出る。`photos.zip` と `.kyoto_hidden.zip` は出ない（US51-AS1・AS2・AS6）。
3. `backup` を検索する → `a/backup.zip` と `b/backup.zip` が別の行で、「場所」列で見分けられる。サムネイル形式ではツールチップで見分けられる（US51-AS3）。
4. `*.zip` を検索する → `x.zip`（フォルダ）、`kyoto_notes.zip`、`backup.zip` ×2、`photos.zip`、`SHOUT.ZIP` が出る（US51-AS4）。
5. 検索結果の表示中に「zipファイルを表示」をオフにする → 件数も行も変わらない。同じキーワードで検索し直すと zip の行が消える（US52-AS2・AS3）。
6. `backup` の検索結果で `a/backup.zip` の行をダブルクリック（⌘↓、右クリックの「中を表示」でも）する → zip の中の最上位が開き、ツリーの選択は `a`。⌘[ で検索前の場所に戻り、検索結果には戻らない（US53-AS1）。
7. zip の行を選択する → プレビューは空。フルスクリーンの矢印キーとスライドショーで zip の行に止まらない（US53-AS3）。
8. 「画像のみ表示」をオンにして zip だけが一致する検索をする → zip の行は出て、絞り込み中のメッセージも出る（US53-AS4）。
9. 検索結果の zip の行の名前を `.zip` のまま変える → 残る。`.txt` に変える → 消える。ゴミ箱に入れる → 消える（US53-AS5・AS6）。

## 記録

（実施後に、実行日・OS・各シナリオの合否を `checklists/validation.md` に記録する。）
