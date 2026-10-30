# Research

## R1: Cloud の手順書の置き場所

- **Decision**: 非公開の運用手順として `docs_private/cloud-agent-workflow.md` を新規に作り、`AGENTS.md` に Cloud 専用の節を設けて参照する。新しいスキルは作らない。
- **Rationale**: 既存の運用手順（`docs_private/folzio-sdd-increment.md`、`docs_private/codex-speckit.md`）と同じ場所で、公開版に含まれない。Agent は `AGENTS.md` を必ず読むので、そこから辿れる。
- **Alternatives**: `.claude/skills/` に Cloud 用のスキルを作ると、Codex（`.agents/skills/`）との二重管理になり、憲章 V（YAGNI）に反する。`AGENTS.md` だけに書くと、手順が長くなって共通の規則と混ざる。

## R2: `AGENTS.md` の分割の方法

- **Decision**: 全体の構成は変えず、各節の見出しに【共通】【ローカル】【Cloud】の区分を付け、先頭に区分の一覧表を置く。ローカルと Cloud が混ざった節（「Codex / Spec Kit」）は、行の単位で分けて、`git` の規則を【共通】の節に出す。
- **Rationale**: 節の順序と見出しを大きく動かさずに済み、差分が読みやすい。既存の参照（他の文書からの節名での参照）を壊しにくい。
- **Alternatives**: 3 つのトップレベルの見出し（共通／ローカル／Cloud）に組み替えると、既存の節がすべて 1 段下がり、差分が大きく、参照が壊れる。別のファイルに分けると、Agent が片方だけ読む危険がある。

## R3: Cloud での feature の始め方

- **Decision**: Agent は Cloud が指定した作業ブランチ上で作業し、git 拡張の `before_specify` フック（`speckit.git.feature`、ブランチを作る）を実行しない。feature ディレクトリは `SPECIFY_FEATURE_DIRECTORY=specs/TAK-nn-<slug>` を明示して作る。
- **Rationale**: `speckit-specify` の手順は、`SPECIFY_FEATURE_DIRECTORY` が明示されていればそれをそのまま使い、ブランチ名とディレクトリ名は独立としている（`.claude/skills/speckit-specify/SKILL.md`）。実際に、この feature（`specs/TAK-30-cloud-agent-workflow/`）をこの方法で作り、`plan`・`tasks` などの後続の手順が `.specify/feature.json` から feature を見つけることを確かめた。
- **Alternatives**: フックを無効にする（`.specify/extensions.yml` の `enabled: false`）と、ローカルの運用にも影響する。`GIT_BRANCH_NAME` で現在のブランチ名を渡す方法は、フック側の挙動（既存ブランチの扱い）の確認が要り、手順が増える。

## R4: CI の再実行

- **Decision**: 追加の push の後の再確認は、`workflow_dispatch` の手動実行で行う。Agent は GitHub MCP の `actions_run_trigger` で起動を試み、起動できなければ保守者に実行を頼む。
- **Rationale**: `.claude/settings.json` の拒否リストに `mcp__github__actions_run_trigger` は含まれていない（`merge_pull_request`、`push_files`、`create_or_update_file` などは含まれている）。ただし、実際に起動できるかは未確認なので、この feature の PR で試す。
- **Alternatives**: `synchronize` を trigger に戻すと、push のたびに macOS の使用時間を消費する（TAK-25 の設計に反する）。

## R5: Linear との連携

- **Decision**: Agent が Linear の MCP で、着手時に `In Progress` へ更新し、PR を作った後に PR のリンクを追加して `In Review` へ更新する。`Done` は、保守者がマージ後に依頼したときだけ更新する。
- **Rationale**: Linear の GitHub 連携は、PR の作成を検知していなかった。TAK-28 は、PR #3（タイトルに `TAK-28` を含む）が開いている間も `In Progress` のままで、リンクも付かなかった（Linear の状態の履歴と attachments で確認）。TAK-25 の `In Review` は、移行で Issue を作ったときの初期状態だった。
- **Alternatives**: 連携を保守者が設定し直す方法は、連携の動作確認が要り、直るまでは手で更新することになる。保守者が手で更新する方法は、手間が増える。

## R6: `specs/product/` への反映と競合

- **Decision**: 反映は、その feature の PR の最後の作業にする。反映の直前に最新の `master` を取り込み（`git merge origin/master`）、競合したら Agent が解消する。履歴は書き換えない。
- **Rationale**: 複数の feature が、同じ領域ファイル（例: `overview.md`）を変更する。最後に取り込めば、競合の範囲が最小になる。強制 push は禁止されているため（`scripts/dev/check-git-push.py`）、履歴を書き換える解決は使えない。
  ID（`FR`・`SC`・`EC`・`A`・`US`）は、並行する feature が同じ時点の最大値から採るため衝突し得る。反映の直前に `master` を取り込んだときに衝突が分かった場合は、まだマージされていない側が自分の feature の ID を振り直してから反映する（EC-135）。憲章の「振り直さない」は、マージ済みの ID に当てはまる。
- **Alternatives**: マージ後にまとめて反映する案は、反映漏れが起きやすい（決定済みで採らない）。ID を feature ごとに別の接頭辞にする案は、既存の ID の体系（全領域で一意の連番）を変えるため採らない。

## R7: 検証ゲートの Cloud 版

- **Decision**: 検査を 3 つに分ける。Cloud で実行する（`check-no-network.sh`、`check-english-comments.sh`、`check-readme-sync.sh master`）、CI で実行する（`swift build`、`swift test`、性能テスト）、保守者が行う（起動スモーク、ローカルの Swift 最新版でのビルド）。
- **Rationale**: Cloud に Swift がないため、ビルドとテストは CI でしか確認できない。`check-*.sh` の 3 本は、TAK-28 の作業で Cloud 上で実行できることを確認した。起動スモークは GUI で、保守者にしかできない（`AGENTS.md` の規則）。
  `scripts/dev/tests` の Python テストのうち、`test_check_git_push.py`（3 件）は Cloud で通る。公開・配布のテスト（`test_publish_folzio.py`、
  `test_release_distribution.py`）は Apple silicon の macOS と `rsync` を前提とし、Cloud（Linux）では 6 件が失敗する（2026-10-30 に確認）。
  これらは保守者のローカルの検査とする。
- **Alternatives**: `check-*.sh` を CI の Linux ジョブにする案は、別の Issue で扱う（対象外）。

## R8: 憲章

- **Decision**: 憲章は改定しない。「マージ前のゲート」は、Cloud では CI の成功と、保守者のローカルでの確認で満たすと解釈し、手順書に明記する。
- **Rationale**: 憲章の文言（自動テストの通過）は、CI の成功で満たされる。改定は MINOR の版の更新と影響範囲の記録が要り、この feature の範囲を超える。
- **Alternatives**: 憲章に Cloud 用のゲートを明記する案は、運用が固まってから別の変更として扱う。

## R9: マージ済みのブランチ

- **Decision**: PR がマージされた作業ブランチは再利用しない。最新の `master` から新しい `claude/` のブランチを作る。Cloud のセッションが指定したブランチと別の名前を使うときは、保守者の許可を得る。
- **Rationale**: PR はスカッシュマージされるため（PR #3 で確認）、作業ブランチの履歴は `master` と一致しなくなる。同じ名前で作り直すには強制 push が要り、禁止されている。PR #3 の後の作業（TAK-30）では、この方法を取り、保守者の許可を得た。
- **Alternatives**: 作業ブランチに `master` を取り込んで続ける案は、マージ済みの履歴が PR に残って長くなる。
