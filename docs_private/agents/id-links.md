# メッセージで挙げる ID のリンク

**適用範囲**: 【共通】

`AGENTS.md` の「書くときの規則」にある、エージェントがメッセージで ID を挙げるときの規則（TAK-82）の補足。
規則そのものは `AGENTS.md` にあり、この文書は、形式を選んだ根拠と、環境ごとに開けるかを確かめた結果を記録する。
エージェントは毎回この文書を読む必要はない。リンクが開けないと報告されたとき、または形式を見直すときに読む。

## 規則の範囲

- 対象: 仕様の ID（`FR-xxx`・`SC-xxx`・`EC-xx`・`A-xx`・`USn-ASm`）と、Linear の Issue ID（`TAK-xx`）
  - 仕様の ID は、`specs/product/` と、作業中の feature の `spec.md` で定義されたもの
  - 作業中の feature は、`specs/` の下の feature のディレクトリのうち、`origin/master`（なければ `master`）にまだないもの。
    spec を作るフロー（`speckit-specify` から実装まで）で、まだ `specs/product/` にない ID を挙げるため
  - 作業中の feature が `specs/product/` の既存の ID を定義し直しているときは、作業中の feature の定義だけにリンクする。
    そのフローで話題になっているのは変更後の定義のため
- 対象外
  - 作業中の feature の `spec.md` 以外の文書（`plan.md`・`tasks.md` のタスクの番号など）
  - 凍結した feature（`specs/NNN-*`・`specs/TAK-*`）の ID、憲章の原則
  - bug 拡張の記録（`.specify/bugs/`）。独自の ID を定義せず、仕様の ID を引用するだけなので、引用された ID を上の対象としてリンクする
- リンクにするのは各メッセージの初出だけ。同じ ID の繰り返しでトークンを増やさないため
- 会話の途中で仕様を変えると、過去のメッセージのリンクが別の行を指すことがある。これは許容する（保守者の判断）
- 仕様の ID は、`scripts/dev/find-spec-id.sh <ID>…` の出力（`[FR-080](specs/product/search.md#L8)`）をそのまま使う
  - リポジトリのルートからの相対パスに、定義の行の `#L<行>` を付けた Markdown リンク（下の形式 4）
  - Codex Cloud では `--absolute` を付ける。リポジトリのルートの絶対パス（`/workspace/folzio-dev/…`）から始まるリンクになる（形式 6）
  - 行番号は文書の更新で変わるので、メッセージを書く時点で引く。会話の中で既に引いた行が古くなっていないかに注意する
- `TAK-xx` は `https://linear.app/takyoshida/issue/TAK-xx` へのリンクにする

## 環境ごとの確認結果

同じ定義（FR-080、`specs/product/search.md` の 8 行目）を指す、次の形式で確かめた（2026-11-12、TAK-82 で保守者が確認）。

| 形式 | 書き方 |
|---|---|
| 1 平文の `path:line` | specs/product/search.md:8 |
| 2 コードスパンの `path:line` | `` `specs/product/search.md:8` `` |
| 3 相対パスの Markdown リンク | `[FR-080](specs/product/search.md)` |
| 4 行のアンカー付きの相対リンク | `[FR-080](specs/product/search.md#L8)` |
| 5 コミットに固定した GitHub の URL | `[FR-080](https://github.com/yoshidax/folzio-dev/blob/<commit>/specs/product/search.md?plain=1#L8)` |
| 6 行のアンカー付きの絶対パスのリンク | `[FR-080](/workspace/folzio-dev/specs/product/search.md#L8)` |

○ は行まで開ける、△ はファイルまで開ける、× はリンクにならないか開けない、— は試していない。

| 環境 | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| Claude Code のクラウド（Claude アプリ） | × | ○ | △ | ○ | ○ | — |
| Claude Code（デスクトップアプリ、ローカル） | — | — | — | ○ | — | — |
| Claude Code（VS Code） | × | × | △ | ○ | ○ | — |
| Codex（VS Code、ローカル） | × | × | △ | ○ | ○ | — |
| Codex（デスクトップアプリ、ローカル） | × | × | △ | △ | ○ | — |
| Codex Cloud（デスクトップアプリ） | × | × | × | × | ○ | ○ |

表の詳細:

- Claude Code のクラウド
  - 2・4: ファイルビューでファイルが開き、8 行目にカーソルが合った。3 は Markdown のプレビューで開いた
  - 5: `?plain=1` を付けない URL（`…/search.md#L8`）では、Markdown のプレビューで表示され、行の位置は示されなかった
    - GitHub は Markdown のファイルを既定でプレビューで表示するため、行のアンカーは `?plain=1` を付けたソースの表示でだけ効く
- Claude Code（デスクトップアプリ、ローカル）: 2026-11-25 に TAK-126 で保守者が確かめた
  - 4 はコードビューで開き、8 行目に移った。行の区切りを `:` にした `[FR-080](specs/product/search.md:8)` も同じだった
  - ほかの形式は試していない
- Codex（デスクトップアプリ、ローカル）: 3・4 はファイルのプレビューで開くため、行の指定は効かない
- Codex Cloud
  - 3・4: リンクにはなるが、リンク先がないエラーになった。作業ディレクトリが `/workspace/folzio-dev` で、相対パスを解決できないためと考えられる
  - 6: 行まで開いた。`#L8` を外すとファイルのプレビューで開き、`file:///workspace/folzio-dev/…#L8` は 6 と同じく行まで開いた
  - `scripts/dev/find-spec-id.sh --absolute FR-080` の出力のリンクも、行まで開いた
  - `scripts/dev/base-ref.sh` は `origin/master` を出力した。作業中の feature の判定に使う比べる基準がある
- 試していない環境: Claude Code と Codex のターミナルの CLI 版（保守者が使わないため）

## 形式を選んだ理由

- 形式 4 を既定にした
  - Codex Cloud 以外の 5 つの環境で開ける。そのうち 3 つでは行まで開ける
  - エディタやファイルビューで開くので、push していない変更も指せる
- Codex Cloud では形式 6 にした
  - 形式 4 は開けず、形式 6 は行まで開けた
  - 絶対パスはスクリプトに書かず、`--absolute` でリポジトリのルートから作る。パスが変わっても規則を直さずに済む
- 形式 5 を既定にしなかった
  - すべての環境で行まで開けるが、push していない変更を指せず、ブラウザで開く
  - URL が長く、ID 1 つにつき約 40〜50 トークンになる（形式 4 は約 15 トークン）
- 形式 2 は Claude Code のクラウドでしか行まで開けなかった。最初の規則はこの形式だったが、確認の結果で形式 4 に変えた

## Claude Code の表示の hook（TAK-126）

エージェントが規則を守らずに ID を平文で書いても、Claude Code では画面の表示でリンクになる。
`scripts/dev/link-spec-ids-hook.py` を `MessageDisplay` の hook として登録する。

- 置き換えるのは画面の表示だけで、会話の記録とエージェントが見る内容は変わらない
  - 会話の書き出し、PR の本文、コミットのメッセージにはリンクが付かない。これらでは上の規則に従う
- 仕様の ID は、`find-spec-id.sh` と同じ解析で探し、同じ定義を指す（形式 4）。`TAK-xx` は Linear へのリンクにする
  - ID ごとに定義の場所が 1 つでないときは、パスの順で最初の場所を指す
  - 既存のリンク・URL・インラインコード・コードフェンスの中の ID と、定義が見つからない ID は変えない
  - `/` や `.` の直後の ID（`specs/TAK-82-foo/` などのパスの一部）は変えない
- 行番号は表示した時点のもの。表示した後に文書を変えると、古い行を指す（規則と同じく許容する）
- 表示済みの行は描き直されない。失敗したときや hook が時間切れになったときは、元の文が表示される
- 表示のたびに定義を探す。ID を含む行のまとまりで約 0.1 秒、含まないもので約 0.05 秒かかる（2026-11-25、保守者の macOS で計測）
- Codex は `.claude/settings.json` を読まないので、この hook は効かない。`AGENTS.md` の規則は残す
  - Claude Code のエージェントが規則どおりにリンクを書いても、hook は既存のリンクを変えないので二重にならない

登録（`.claude/settings.json` の `hooks` に足す。この設定は保守者が編集する）:

```json
"MessageDisplay": [
  {
    "hooks": [
      { "type": "command", "command": "python3 -I \"$CLAUDE_PROJECT_DIR/scripts/dev/link-spec-ids-hook.py\"" }
    ]
  }
]
```

確認の結果:

| 環境 | 結果 |
|---|---|
| Claude Code の CLI（`claude -p`、`--settings` で登録、2.1.332） | 出力の ID がリンクに置き換わった（2026-11-25） |
| Claude Code（デスクトップアプリ、ローカル） | 未確認 |
| Claude Code のクラウド | 未確認。リポジトリの `.claude/settings.json` を読むので動く見込みだが、表示が置き換わるかは文書にない |

## 新しい環境を確かめる手順

1. その環境のエージェントに、上の形式の「書き方」の列を、コードブロックで囲まずにそのまま出力するよう頼む
   - 形式 5 の `<commit>` は、push 済みのコミット（例: `git ls-remote origin master` の値）に置き換える
   - 形式 6 のパスは、その環境のリポジトリのルートの絶対パスに置き換える
2. 各形式をクリックし、開くかどうかと、何が開くか（ファイル、その行、ブラウザ）を確かめる
3. 結果を上の表に記録する
4. 形式 4 が開けない環境があれば、その環境で開ける形式を使う規則を、この文書と `AGENTS.md` の規則に足す
   - 代わりの形式は、確かめた結果から決める。確かめていない形式を規則にしない

## コンテキストの消費（TAK-82 の見積もり）

規則を `AGENTS.md` に置くか判断したときの見積もり。トークン数は実測ではない。

- `AGENTS.md` の規則 1 行: 毎セッション約 100 トークン（`AGENTS.md` 45 行が `/context` で 2.1k トークン、約 0.67 トークン/文字から計算）
- 応答に入れるリンク: ID 1 つにつき約 15 トークン（`--absolute` では約 20 トークン）
- `find-spec-id.sh` の呼び出し: 1 回あたり約 50 トークンと、ID 1 つにつき約 15 トークン
  - 定義の行の全文を返す Grep では、ID 1 つにつき約 50 トークンになる（定義の行は平均 57 文字）
