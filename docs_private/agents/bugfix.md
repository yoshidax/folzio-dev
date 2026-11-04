# バグ修正の手順

AGENTS.md から参照する、バグを直すときの手順。ローカルと Cloud の両方で使う（違いは各手順に注記する）。

bug 拡張の `/speckit-bug-assess` → `/speckit-bug-fix` → `/speckit-bug-test` で直す（Kilo では `/speckit.bug.*`、Codex CLI では `$speckit-bug-*`）。
記録は `.specify/bugs/<slug>/` に残る。

1. クリーンな master から `bugfix/<slug>` ブランチを切る（ローカル。Cloud では Cloud が指定した作業ブランチをそのまま使う）
2. assess: `assessment.md` の「Symptom」の後に「## 仕様との照合」を置き、該当する `specs/product/` の ID と、次のどちらかの判定を書く
   - 実装が仕様に反している: fix へ進む
   - 仕様が誤っている、または定めていない: fix へ進まず、仕様の変更として sdd-increment（小さければ `clarify_mode=skip`）で扱う
3. assess の判定と診断をユーザーに確認してもらってから fix へ進む
4. fix: 再現を固定する回帰テストを足す（Core のロジックは `Tests/FolzioCoreTests`）
5. test: AGENTS.md の「Phase の検証ゲート」の 1〜4 を行う（Cloud では、ビルドとテストを CI で確認し、起動スモークを保守者に依頼する。
   [cloud-agent-workflow.md](../cloud-agent-workflow.md) の 5 章）。GUI で再現を確かめていなければ判定は `partial` にする
6. ソースの変更と `.specify/bugs/<slug>/` を1つのコミットにする（例: `fix: <内容> (bug: <slug>)`）

Linear の Issue を指定されたときは、assessment に Issue の URL または ID を記録する（[linear.md](linear.md)）。
