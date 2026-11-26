# Contract: アップデートの確認

アプリが行う唯一の通信である更新の確認の、通信の内容・起動時の動作・ネットワーク API の検査の契約（TAK-95）。
メニューは [keyboard-and-menus.md](keyboard-and-menus.md)、保存するキーは [settings.md](settings.md)、
文言は [localization.md](localization.md) の「アップデートの確認」を参照する。

## 通信

| 項目 | 値 |
|---|---|
| 方法と URL | `GET https://api.github.com/repos/yoshidax/folzio/releases/latest` |
| `User-Agent` | `Folzio` |
| `Accept` | `application/vnd.github+json` |
| `X-GitHub-Api-Version` | `2022-11-28` |
| `Accept-Language` | `en` |
| Cookie・キャッシュ・資格情報 | 送らない・保存しない（ephemeral のセッション） |
| タイムアウト | 15 秒（FR-427（window-layout.md）） |
| 使う応答の値 | `tag_name` だけ |

- 本文は送らない。画像・動画、メタデータ、パス、設定、利用者や端末を識別する値を送らない（FR-424（window-layout.md））。
- `Accept-Language` は、OS の優先言語を送らないために固定値にする。
- 状態が 200 でない、本文が 1 MiB を超える、`tag_name` が `v<数>.<数>.<数>` でない場合は、確認できなかったとして扱う
  （EC-292・EC-294（window-layout.md））。
- 開く Release ページの URL は `https://github.com/yoshidax/folzio/releases/tag/v<版>` で、About の公開リポジトリの URL
  から組み立てる（FR-426（window-layout.md））。

## 起動時の動作

| 自動の確認の設定 | 起動してメインウィンドウを表示した後 |
|---|---|
| 未回答 | 邪魔をしない状態なら同意のダイアログを出す。そうでなければ何もしない |
| 有効 | 前回の自動の確認から 24 時間以上なら問い合わせる |
| 無効 | 何もしない |

- 「邪魔をしない状態」は、ショートカット一覧を開ける状態（文字の編集中・シート・モーダル・全画面・スライドショーの
  どれでもない）とする（EC-296（window-layout.md））。
- 自動の確認の結果は、まだ知らせていない新しい版で、邪魔をしない状態のときだけダイアログで知らせる（FR-432・433）。
- 保存の規則（FR-431・432、EC-296〜298（window-layout.md））:
  - 新しい版を知らせたとき: 前回の自動の確認の時刻と、知らせた版を保存する。
  - 知らせ済みの版か最新のとき: 時刻だけを保存する。
  - 確認できなかったとき、または邪魔をしない状態でなく知らせなかったとき: 何も保存しない。
- 実行中の版を取得できないときは、どの場合も何もしない（EC-299（window-layout.md））。

## ネットワーク API の検査（`scripts/check-no-network.sh`）

| ファイル | 許す行 |
|---|---|
| `Sources/FolzioCore/About/AboutInfo.swift` | `"https://github.com/yoshidax/folzio"` を含む行 |
| `Sources/FolzioCore/Operations/ImportedFileName.swift` | `["http", "https"].contains(scheme),` だけの行 |
| `Sources/FolzioCore/Update/UpdateSource.swift` | 下記 |
| `Sources/FolzioApp/Update/URLSessionUpdateTransport.swift` | 下記 |

**表の詳細**

- **`Sources/FolzioCore/Update/UpdateSource.swift`**（許す行）: API の URL のリテラルを含む行だけ。
- **`Sources/FolzioApp/Update/URLSessionUpdateTransport.swift`**（許す行）: `URLSession` を含み、
  ほかに URL・`NWConnection`・`import Network` を含まない行だけ。
- 許した行に、許したもの以外の URL やネットワーク API があれば失敗する。
- ほかのファイルでの該当、`NWConnection`・`import Network` はどこでも失敗する（FR-176・SC-246（overview.md））。
