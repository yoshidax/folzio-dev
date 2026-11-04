# Research: エージェント向けの規約の置き場所を AGENTS.md に限らない

## R1: TAK-71 との順序

- **Decision**: TAK-71（PR #50）が `master` にマージされた後に実装する。実装の前に `git merge origin/master` で取り込む。
- **Rationale**: FR-309・FR-310 の検査（`scripts/dev/check-agents-md.sh`）と、置き場所の基準（`docs_private/agents/README.md`）は
  TAK-71 で入る。取り込まずに実装すると、`AGENTS.md` の冒頭の行（TAK-71 で参照を足した行）と、`docs_private/agents/README.md` への
  適用範囲の行の追加が競合する。
- **Alternatives considered**: TAK-71 のブランチから作る案。TAK-73 と同じく PR の差分に TAK-71 の変更が混ざり、仕様の PR のレビューが
  読みにくくなるので採らない。

## R2: AGENTS.md の書き方の要点の置き換え

- **Decision**: 「仕様と進捗」の節の 4 行（要点の親項目と子項目 3 つ）と、検査の行を、次の 1 行にまとめる。
  - 「`specs/product/` を変える前に `specs/product/README.md` の「書き方のルール」を読む。変えたら `check-spec-format.py` を、
    反映の前と後に `check-spec-ids.sh` を実行する。ID が衝突したら `docs_private/cloud-agent-workflow.md` の 7 章に従う」
  - 行数は 50 → 46 になる（SC-163 を満たす）。
- **Rationale**: Clarifications の Q2。要点は `specs/product/` を変えるときにしか使わない（`docs_private/agents/README.md` の
  置き場所の基準の 3）。FR-306（変更）は「読むことを示す」だけを求める。検査の行は、変えた後の手順なので残す。
- **Alternatives considered**: 「作業別の手順」の節に移す案。`specs/product/` の変更は「仕様と進捗」の節の主題なので、節の中に置く方が
  見つけやすい。

## R3: 参照先の文書の適用範囲の示し方

- **Decision**: `AGENTS.md` から参照する `docs_private/` の Markdown の文書（9 個）の、見出しの直後の段落の先頭に、次の形の 1 行を置く。
  - `**適用範囲**: 【共通】` / `【ローカル】` / `【Cloud】`（必要なら括弧で補足）
  - 文書の中に区分の違う節があるときは、その節の見出しにも【】を付ける（`docs_private/agents/skills-and-codex.md` の
    「Codex の自動実行（ローカル）」など）。
- **Rationale**: Clarifications の Q1。`AGENTS.md` の見出しと同じ記号を使えば、読み手が同じ規則で区分を読み取れる。
- **Alternatives considered**: YAML の front matter に書く案。ほかの文書に front matter がなく、エージェントが本文として読むときに
  目立たないので採らない。
- **対象外**: `specs/product/README.md`、`.specify/memory/constitution.md`、`specs/001-three-pane-media-viewer/quickstart.md` は
  製品仕様と記録で、運用の文書ではないので、適用範囲の行を置かない（FR-195 の子項目は `docs_private/` の文書に限っている）。

## R4: 適用範囲の行を検査するか

- **Decision**: 検査しない。quickstart.md の手順で目で確かめる。
- **Rationale**: 対象は 9 個で、文書を足すのはまれ。憲章の原則 V（シンプルさ）に従い、現在の仕様が求めない検査は足さない。
  FR-195 は検査を求めていない。
- **Alternatives considered**: `check-agents-md.sh` で、参照先の `docs_private/` の文書に `**適用範囲**:` の行があるかを調べる案。
  必要になったら、TAK-71 の検査の延長として足せる。

## R5: specs/product/overview.md への反映の位置

- **Decision**:
  - FR-195・SC-094・US30-AS2 は「Cloud Agent の開発 workflow」の節とその受け入れシナリオ・成功基準の位置で書き換える。
  - FR-306・SC-161・US66-AS2 は「製品仕様の形式の検査」の節とその位置で書き換える。
  - 新しい US67 は US66 の後に、FR-307〜FR-310 は新しい節「エージェント向けの規約」（「製品仕様の形式の検査」の後）に置く。
  - EC-213・EC-214、SC-162〜SC-165、A-192〜A-195 は、それぞれの一覧の末尾に足す。
- **Rationale**: TAK-62 と TAK-40 の前例に合わせ、運用の要件は `overview.md` に節を作って置く。
- **Alternatives considered**: FR-307〜FR-310 を「Cloud Agent の開発 workflow」の節に置く案。ローカルにも適用するので採らない。

## R6: TAK-63 との競合

- **Decision**: 反映の直前に `origin/master` を取り込み、TAK-63 が FR-306 の近くや `AGENTS.md` を変えていたら、先にマージされた側に
  合わせる（A-194）。ID が衝突したら、まだマージされていないこの feature の ID を振り直す（`cloud-agent-workflow.md` の 7 章）。
- **Rationale**: TAK-63 は作業中で、形式の検査を検証ゲートに組み込むときに `AGENTS.md` の検査の行を変える可能性がある。

## R7: 憲章との関係

- **Decision**: 憲章は変えない。
- **Rationale**: 憲章は `AGENTS.md` の中身を指定していない。ID の振り直しの例外（憲章 L121）は TAK-67 で扱う。
