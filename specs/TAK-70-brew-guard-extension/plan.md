# 実装計画: TAK-70 の Homebrew ガード拡張

**Branch**: `chore/tak-70-tool-install-approval` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

## 概要

Codex の `prefix_rule` と Kilo の bash 権限で、直接の `brew install`・`reinstall`・`upgrade`・`bundle` を禁止する。`bundle` は読み取り系のサブコマンドを含めて禁止する。Claude の `Bash(brew install *)` は `permissions.ask` のまま維持する。

## 設計と検証

- Codex の接頭辞ルールには 4 つの具体的なコマンドの match と、`brew list`・`brew info` の not_match を置く。`codex execpolicy check` で判定を確認し、パッケージは導入しない。
- Kilo の bash 権限に直接コマンドの deny を追加し、引数なしの `brew upgrade`・`brew bundle` にも明示的な deny を置く。静的検査で優先順位を検証し、実セッションでの確認と区別する。
- Claude の保護された設定は編集せず、既存の ask を維持していることを検査する。
- `AGENTS.md` と開発手順を追従させ、保守者が実行する対象、`brew bundle check` も禁止されること、絶対パスやラッパーなどの限界を明示する。
- `specs/TAK-70-tool-install-approval/` は凍結済みのため触らず、この別の feature に設計・タスクと検証の経緯を記録する。

## 憲章チェック

- 原則 I〜III: アプリの処理、通信、性能や操作には変更がない。
- 原則 IV: 権限設定の静的検証と Codex のルール判定を行い、実セッションの未確認事項を残す。
- 原則 V: 依存を追加しない。既存の権限設定とテストの仕組みを使う。
- 製品仕様・機能の変更はない。保護された Claude 設定は保守者が管理する。
