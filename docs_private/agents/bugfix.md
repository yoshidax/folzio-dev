# バグ修正の手順

**適用範囲**: 【共通】（手順 1 と 5 はローカルと Cloud で違う）

AGENTS.md から参照する、バグを直すときの手順。ローカルと Cloud の違いは各手順に注記する。

## 適用の判断

- 進行中の spec の実装・検証・マージ前レビューで、その変更について見つかった問題は、予測外の問題・回帰・レビュー指摘も含め、現在の作業で扱う。bug 拡張や `.specify/bugs/`、独立した診断 ID や bug 専用の承認手順は使わない。
- 要件・設計の変更が必要なら、その spec の変更として整理して保守者へ確認する。
- 現在の spec と無関係な既存成果物の問題は、範囲外として報告する。保守者が独立した修正タスクとして扱うと決めたら、以下の手順を開始する。
- `specs/product/` への反映や feature の凍結の注記だけを理由に、マージ前の修正を独立した bug へ切り替えない。凍結前は現在の feature の作業・検証記録に残す。凍結後は feature を更新せず、レビューへの対応内容と検証結果を PR の本文またはレビュースレッドに記録する。

## 独立したバグ修正の手順

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
