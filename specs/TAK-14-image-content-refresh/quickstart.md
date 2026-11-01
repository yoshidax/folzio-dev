# Validation: TAK-14

## 前提

Cloud は GUI を起動せず、Swift も実行できない。ビルドとテストは macOS CI で、GUI の確認は保守者がローカルで行う。

## Cloud の検査

```bash
scripts/check-no-network.sh
scripts/check-readme-sync.sh master
scripts/dev/check-english-comments.sh
scripts/dev/check-skill-sync.sh
python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py"
```

## macOS CI とローカル

CI で `swift build`・`swift test`（通常のテストと性能テスト）の成功を確認する。保守者は最新のローカル Swift でも次を実行する。

```bash
swift build
swift test
scripts/make-app.sh
open .build/Folzio.app
```

## 準備（GUI）

寸法で内容を判別できる画像を作る（`sips` は macOS の標準コマンド）。

任意の画像 `SRC`（PNG か JPEG）から、縦横比の違う2枚を作る。

```bash
mkdir -p ~/FolzioTAK14/a ~/FolzioTAK14/b
sips -s format png -z 80 80 "$SRC" --out ~/FolzioTAK14/a/photo.png
sips -s format png -z 160 320 "$SRC" --out ~/FolzioTAK14/b/photo.png
```

`a/photo.png` は正方形、`b/photo.png` は横長になるため、プレビューと縮小画像の形で内容を判別できる。

## GUI シナリオ

起動スモーク（3ペインが表示される）を先に確認する。

| # | 操作 | 期待結果 | 対応 |
|---|---|---|---|
| Q1 | `a/` を表示し `photo.png` をプレビュー中に、ターミナルで `cp ~/FolzioTAK14/b/photo.png ~/FolzioTAK14/a/photo.png` | 選択し直さずに、1 秒程度でプレビューが b の内容に変わる。選択は変わらない | US41-AS1、SC-115 |
| Q2 | サムネイル形式とリスト形式で Q1 と同じ上書きをする | 両形式で、その行の縮小画像だけが b の内容に変わる。ほかの行はちらつかない | US41-AS2、SC-116、research R3 |
| Q3 | `a/` で別の画像を選択中に `photo.png` を上書きし、その後 `photo.png` を選択 | 上書き後の内容が表示される | US41-AS3 |
| Q4 | Folzio で `b/photo.png` をコピーし、`a/` に貼り付けて「置き換える」 | 再起動せずに、縮小画像とプレビューが置き換え後の内容になる（TAK-43 の手順） | US41-AS4、FR-027 |
| Q5 | `photo.png` を 200% に拡大してから Q1 の上書きをする | 倍率を保ったまま新しい内容になり、読み込み中の表示が挟まらない | EC-162 |
| Q6 | `a/` に `x.zip`（中に `photo.png`）を置いて中の画像を表示し、一覧に戻ってから、同じ名前で中の `photo.png` の寸法が違う zip に置き換えて開き直す | 置き換え後の zip の内容が表示される | US42-AS1、FR-231 |
| Q7 | `x.zip` の中の画像をプレビュー中に `x.zip` を置き換える | `a/` の一覧に戻り、プレビューは空になる（従来どおり） | US42-AS2、EC-26 |
| Q8 | `photo` で検索し、結果の `a/photo.png` をプレビュー中に Q1 の上書きをする | 並びと選択を保ったまま、縮小画像とプレビューが新しい内容になる | US43-AS1、FR-232 |
| Q9 | `photo.png` を壊れたファイル（`echo broken > ~/FolzioTAK14/a/photo.png`）で上書き | クラッシュせず、表示できない旨が出る | EC-159 |

## 結果

（実施後に、日付・OS・合否を記録する）
