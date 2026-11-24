---
name: folzio-sdd-increment
description: Folzio の新規要件・仕様変更を、Spec Kit の仕様策定から設計レビュー、実装、検証、製品仕様への反映まで対話で進める。正式なバグ診断・修正には使わない。
---

# Folzio SDD increment

Folzio の新規要件・仕様変更を現在の会話で順次進める。開始前に `AGENTS.md` と `shared-skills/folzio-sdd-increment.md` を読み、共通手順を実行する。指示が競合するときは上位の指示と `AGENTS.md` を優先する。

Codex では `docs_private/codex-speckit.md` を読み、各工程で対応する `.agents/skills/speckit-*/SKILL.md` のスキルを使う。Kilo では、各工程で対応する `.kilo/commands/speckit.*.md` のコマンドを使う。現在の実行環境に対応するものだけを選ぶ。各スキルまたはコマンドの指示は使用時に読む。
