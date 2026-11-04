# アプリが起動しないときの初動と、設定の保存先

AGENTS.md から参照する、ローカル（macOS）でアプリを起動して調べるときの手順。
Cloud では GUI を起動できないため、実行する内容と確認する点を示して、保守者に依頼する。
経緯は [2026-10-19 の振り返り](../retrospective/2026-10-19-startup-debugging.md) にある。

## 起動しない・ウインドウが出ないとき（lldb）

クラッシュレポートがなく、終了コードが 0 でも、AppKit が Objective-C 例外を握りつぶしていることがある。
推測でコードを直す前に、まず lldb で例外を止める。GUI を起動するため、実行前にユーザーへ依頼する。

```bash
cd /Users/igachan/projects/folzio
lldb -b \
  -o 'breakpoint set -E objc' \
  -o 'run' \
  -o 'bt 30' \
  -o 'po $x0' \
  -o 'quit' \
  -- .build/Folzio.app/Contents/MacOS/Folzio
```

- 例外を1つ直したら、ユーザーに GUI 確認を戻さず、もう一度 lldb を実行して次の例外を確認する
- 例外がなくなり、ウインドウが表示されてから、ユーザーに視覚確認を依頼する
- 古いプロセスが残っていないか `pgrep -fl Folzio` で確認する
- ターミナルから直接実行すると、起動時の出力を確認できる
  （`.build/Folzio.app/Contents/MacOS/Folzio`）

## 設定（UserDefaults）の保存先

起動のしかたによって UserDefaults のドメインが異なる。設定を `defaults read` で調べるときは、起動に使った方のドメインを読む。

| 起動のしかた | ドメイン |
|---|---|
| `.app`（`open .build/Folzio.app`） | `local.folzio.Folzio`（`scripts/make-app.sh` の `CFBundleIdentifier`） |
| `swift run FolzioApp` | `FolzioApp`（バンドル ID がないため、プロセス名） |

- 片方で保存した設定は、もう片方の起動では読まれない。「設定が消えた」「保存されない」という報告は、まず起動のしかたを確かめる
