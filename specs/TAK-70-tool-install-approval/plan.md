# 実装計画: 依存ツール導入時の確認

**Branch**: `chore/tak-70-tool-install-approval` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

## 概要

直接の `brew install` を Claude の ask、Kilo の deny と Codex の forbidden の対象にする。Codex の接頭辞は `pattern = ["brew", "install"]` とし、模擬コマンドの判定と読み取り系コマンドの非該当を検査する。保守者が編集する Claude 設定の具体案と、手元での確認方法を示す。

保守者は 2026-11-06 に、自動承認モードで Codex・Kilo が確認なしに導入した結果を受け、禁止して保守者が実行する方針を承認した。

## 設定案

- Claude: `.claude/settings.json` の `permissions.ask` に `Bash(brew install *)` を追加。ISSUE の指示に従い保守者が編集する。
- Kilo: `.kilo/kilo.jsonc` の `permission.bash` に `"brew install *": "deny"` を追加する。
- Codex: `.codex/rules/sdd.rules` に `brew install` の接頭辞を `forbidden` とする規則を追加する。`match` と `not_match` を設ける。
- `docs_private/agents/skills-and-codex.md` 等の運用文書に範囲・新規セッション・バイパス可能な表記・他の導入方法での既存の確認義務を記載する。
- Python パッケージや npm のグローバル導入は今回の機械的な規則に含めず、既存の人による確認規則を適用する。既存のプログラムでこれらの自動導入は確認できず、対応対象の無制限な拡大を避ける。

## 検証と限界

- `codex execpolicy check` で `brew install webp` が forbidden、`brew list` が当該規則に一致しないことを検査し、設定全体との競合も確認する。実インストールはしない。
- JSON/JSONC の構造と規則を検査する。Claude と Kilo の実セッションが使えない場合、設定されたことと確認ダイアログが実際に表示されたことを区別する。
- 絶対パス、別コマンド、環境やラッパー、入れ子などのすべての経路を検出する保証はない。権限の確認は新しいセッションで行い、設定を書き換えた現在のセッションへの即時反映を前提にしない。
- 必要な設定・文書の変更と Claude 向けの具体的編集案を先に準備し、実動確認や保守者編集の結果は未確認なら正直に記録する。

## 憲章チェック

- 原則 I〜III: アプリの通信・性能・UI・操作に変更はない。
- 原則 IV: 実インストールの代わりに、判定テストと設定構文の検証を行う。
- 原則 V: 新たな依存ツールは導入しない。製品の要件・動作は変更しない。

## 成果物

- [research.md](research.md): 確認済みの現状と設計上の範囲。
- [quickstart.md](quickstart.md): 実行せずに検査する方法と保守者の確認項目。
- [tasks.md](tasks.md): 順序と未完了の記録。
- 新しい製品の API・データモデルはない。
