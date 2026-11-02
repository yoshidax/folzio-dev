# Data Model: Folzio について（About）ダイアログ

永続化するデータはない。

## AboutInfo（Core、値と関数のみ）

| 項目 | 型 | 内容 |
|---|---|---|
| `repositoryURL` | `URL` | `https://github.com/yoshidax/folzio`（固定。表示する文字列は `absoluteString` と一致させる） |
| `displayVersion(from:)` | `(Any?) -> String?` | Info.plist の値を受け取り、`String` で前後の空白を除いて空でなければその値、それ以外は `nil` |

### 状態遷移

| 状態 | 条件 | 操作 → 結果 |
|---|---|---|
| なし | 起動直後 | 「Folzio について」→ 作成して前面表示 |
| 表示中 | ウィンドウがある | 同じ項目 → 前面へ（位置を保つ） |
| 表示中 | ⌘W・閉じるボタン・メインウィンドウを閉じる | → 閉じる（controller は保持し、再表示で再利用） |
| 閉じた | | 同じ項目 → 再表示 |

## About dialog（App）

| 部品 | 内容 | 翻訳 |
|---|---|---|
| アイコン | `NSApp.applicationIconImage` | 説明文を翻訳（アクセシビリティ） |
| アプリ名 | 「Folzio」 | しない |
| バージョン行 | `displayVersion` が非 nil のときだけ。「Version %@」／「バージョン %@」 | 語のみ |
| リンク | `repositoryURL.absoluteString` | しない（アクセシビリティの補足は翻訳） |

## 追加する文言（TextKey）

| キー | en | ja |
|---|---|---|
| `menu.app.about` | About Folzio | Folzio について |
| `about.window` | About Folzio | Folzio について |
| `about.version` | Version %@ | バージョン %@ |
| `about.icon` | Folzio app icon | Folzio のアイコン |
| `about.link` | Opens the Folzio repository in your default web browser | Folzio のリポジトリを既定の Web ブラウザで開きます |
