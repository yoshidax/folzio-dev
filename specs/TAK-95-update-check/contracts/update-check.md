# Contract: アップデートの確認（TAK-95）

本文は `specs/product/` の書き方のルールに合わせる。反映時に keyboard-and-menus.md・settings.md・localization.md へ分ける。

## メニュー

| メニュー | 項目 |
|---|---|
| アプリ名 | Folzio について / アップデートを確認… / ─ / 設定…（⌘,） / ─ / 終了（⌘Q） |

- 「アップデートを確認…」にショートカットは割り当てない。メニューバーからキーボードで到達できる（FR-422）。
- 有効の条件: 実行中の版が `<数>.<数>.<数>` で、確認中（自動を含む）でない。メインウィンドウの状態には依存しない。

## 起動時の動作（FR-430〜433）

| 自動の確認の設定 | 起動してメインウィンドウを表示した後 |
|---|---|
| 未回答 | 邪魔をしない状態なら同意のダイアログを出す。そうでなければ何もしない |
| 有効 | 前回の自動の確認から 24 時間以上なら問い合わせる（下記の通信と同じ） |
| 無効 | 何もしない |

- 「邪魔をしない状態」は `MainSplitViewController.canShowShortcuts`（文字の編集中・シート・モーダル・全画面・スライドショー
  のどれでもない）。
- 自動の確認の結果: 知らせていない新しい版で、邪魔をしない状態ならダイアログ（メニューの「新しい版」と同じ）。それ以外は
  何も表示しない。保存の規則は data-model.md の `AutomaticUpdateCheckPolicy`。
- 版を取得できないときは、どの場合も何もしない（EC-299）。

## 設定

| キー | 型 | 既定値 | 対応 |
|---|---|---|---|
| `updates.automaticCheck` | Bool | （未設定 = 未回答） | FR-430・FR-434 |
| `updates.lastAutomaticCheck` | Date | （未設定） | FR-431 |
| `updates.lastNotifiedVersion` | String | （未設定） | FR-432 |

- 設定ウインドウの「一般」の最後（「スライドショー」の後）に区分「アップデート」と、`updates.automaticCheck` の
  チェックボックスを置く。区分の間隔は既存と同じ（20pt・8pt）、Tab の移動順は既存の最後の項目の後。
- 未回答はチェックなしで表示する。操作するとその値を保存し、以後は尋ねない。
- 3つのキーは CFBoolean・Date・`<数>.<数>.<数>` の文字列だけを有効とし、それ以外は未設定として読む。移行処理は持たない。

## 通信（アプリが行う唯一の通信）

| 項目 | 値 |
|---|---|
| 方法と URL | `GET https://api.github.com/repos/yoshidax/folzio/releases/latest` |
| `User-Agent` | `Folzio` |
| `Accept` | `application/vnd.github+json` |
| `X-GitHub-Api-Version` | `2022-11-28` |
| `Accept-Language` | `en` |
| Cookie・キャッシュ・資格情報 | 送らない・保存しない（ephemeral のセッション） |
| タイムアウト | 15 秒 |
| 使う応答の値 | `tag_name` だけ |

- 本文は送らない。画像・動画、メタデータ、パス、設定、利用者や端末の識別子を送らない（FR-424）。

## ダイアログの文言

| 用途 | 日本語 | 英語 |
|---|---|---|
| メニュー項目 | アップデートを確認… | Check for Updates… |
| 新しい版・見出し | 新しいバージョンの Folzio があります | A new version of Folzio is available |
| 新しい版・本文 | 下記 | 下記 |
| 新しい版・既定のボタン | ダウンロードページを開く | Open Download Page |
| 新しい版・取り消しのボタン | 閉じる | Close |
| 最新・見出し | Folzio は最新です | Folzio is up to date |
| 最新・本文 | 下記 | 下記 |
| 失敗・見出し | アップデートを確認できませんでした | Couldn't check for updates |
| 失敗・本文 | 下記 | 下記 |
| 最新・失敗のボタン | OK（既存の `dialog.ok`） | OK |
| 同意・見出し | アップデートを自動で確認しますか？ | Check for updates automatically? |
| 同意・本文 | 下記 | 下記 |
| 同意・既定のボタン | 自動で確認する | Check Automatically |
| 同意・取り消しのボタン | 確認しない | Don't Check |
| 設定・区分の見出し | アップデート | Updates |
| 設定・チェックボックス | アップデートを自動で確認する | Automatically check for updates |

**表の詳細**

- **新しい版・本文**（日本語）: 「Folzio %1$@ を入手できます。現在のバージョンは %2$@ です。」
  - 英語: 「Folzio %1$@ is available. You have version %2$@.」
  - `%1$@` は最新の公開版、`%2$@` は今の版。
- **最新・本文**（日本語）: 「バージョン %@ は最新のバージョンです。」
  - 英語: 「Version %@ is the latest version.」
- **失敗・本文**（日本語）: 「ネットワークの接続を確かめて、しばらくしてからもう一度お試しください。」
  - 英語: 「Check your network connection and try again later.」
- **同意・本文**（日本語）: 「Folzio は起動時に、1日に1回まで GitHub に新しいバージョンがあるかを問い合わせます。ファイルや
  その情報は送りません。設定でいつでも変えられます。」
  - 英語: 「Folzio can ask GitHub whether a new version is available when it starts, at most once a day. It sends no
    files or information about them. You can change this in Settings at any time.」

- アプリ名「Folzio」と版の数値は翻訳しない。表示言語の切り替えでメニュー項目の名前を即時更新する（既存の
  `MainMenu.refreshTitles`）。ダイアログは表示する時点の言語で作る。

## 開く URL

- `https://github.com/yoshidax/folzio/releases/tag/v<最新の公開版>`。`AboutInfo.repositoryURL` から組み立てる（FR-426）。

## ネットワーク API の検査（`scripts/check-no-network.sh`）

| ファイル | 許す行 |
|---|---|
| `Sources/FolzioCore/About/AboutInfo.swift` | `"https://github.com/yoshidax/folzio"` を含む行（既存） |
| `Sources/FolzioCore/Operations/ImportedFileName.swift` | `["http", "https"].contains(scheme),` だけの行（既存） |
| `Sources/FolzioCore/Update/UpdateSource.swift` | 下記 |
| `Sources/FolzioApp/Update/URLSessionUpdateTransport.swift` | 下記 |

**表の詳細**

- **`Sources/FolzioCore/Update/UpdateSource.swift`**（許す行）:
  `"https://api.github.com/repos/yoshidax/folzio/releases/latest"` を含む行だけ。
- **`Sources/FolzioApp/Update/URLSessionUpdateTransport.swift`**（許す行）: `URLSession` を含み、`https?://`・`\bhttp\b`・
  `NWConnection`・`import Network` を含まない行だけ。
- ほかのファイル、または許したファイルのほかの行に該当があれば失敗する。`NWConnection`・`import Network` はどこでも許さない。
