# Contract 差分: 永続化する設定

`specs/product/contracts/settings.md` への変更点。実装と検証が終わってから、この内容を反映する（spec.md の「反映先」）。

## 1. キーの表に行を追加する（FR-101）

`favorites.paths` の行の後に追加する。`favorites.paths` の行は変えない。

| キー | 型 | 既定値 | 対応 |
|------|----|--------|------|
| `favorites.displayNames` | [String: String]（キーは登録したフォルダの絶対パス、値は表示名） | （未設定 = どの項目も表示名なし） | FR-099〜101 |

## 2. 箇条書きに追加する（FR-101、EC-44・45、research.md R49）

「お気に入りはパスだけを保存し、…」の項目の後に追加する。

> - お気に入りの表示名は `favorites.displayNames` に、表示名を付けた登録の分だけ保存する。キーは `favorites.paths` の各パスを
>   標準化した絶対パス（`standardizedFileURL.path`）とする。表示名を付けていない登録はキーに載せず、表示名が1つもなければ
>   `favorites.displayNames` 自体を消す。お気に入りから削除した登録の表示名は残さない
> - 読み込み時は、`favorites.displayNames` が辞書でなければ無視する。値が文字列でない項目、`favorites.paths` にないパスの項目、
>   前後の空白と改行を除くと空になる項目は捨てる。値の中の改行は取り除き、255 文字（書記素クラスタ）を超える分は切り捨てる
> - この機能より前のバージョンの保存内容（`favorites.paths` だけ）は、そのまま登録順に、全件を表示名なしとして読む。
>   保存形式の移行処理は持たない。古いバージョンは `favorites.displayNames` を読まないため、戻しても登録は失われない
> - 表示名は登録したフォルダの名前と独立に保存する。フォルダが見つからない間（FR-067）も消さない

## 保存の例

```text
favorites.paths        = ["/Users/me/Photos/2025", "/Volumes/Backup/Photos/2025"]
favorites.displayNames = { "/Volumes/Backup/Photos/2025": "2025（バックアップ）" }
```

ツリーの表示: 「2025」「2025（バックアップ）」（登録順）。
