---
name: folzio-sdd-increment
description: Folzio の新規要件・仕様変更を、Spec Kit の仕様策定から設計レビュー、実装、検証、製品仕様への反映まで対話で進める。正式なバグ診断・修正には使わない。
---

# Folzio SDD increment

Folzio の新規要件・仕様変更を現在の会話で順次進める。開始前に `AGENTS.md` と `shared-skills/folzio-sdd-increment.md` を読み、共通手順を実行する。指示が競合するときは上位の指示と `AGENTS.md` を優先する。

Claude Code では `.specify/workflow-src/sdd-increment.yml` を読み、各工程で対応する `.claude/skills/speckit-*/SKILL.md` のスキルを使う。

対応する workflow の入力・条件・反復上限・レビューゲートに従う。自動ランナー専用の環境変数、通知、resume、別のエージェント起動や並列実装は対話実行の前提とせず、同じセッションで順次作業する。各スキルまたはコマンドの指示は使用時に読む。
