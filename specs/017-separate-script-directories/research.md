# Research

## R1: 分離の境界

- **Decision**: 公開用を `scripts/` 直下に残し、開発専用を `scripts/dev/` に移す。
- **Rationale**: 公開ユーザーの既存コマンドを維持し、個別指定の漏れを防ぐ。
- **Alternatives**: 両方を新規ディレクトリに移すと公開手順と契約に不要な変更が広がる。個別 export-ignore は追加漏れを防げない。

## R2: 二重の保護と回帰検証

- **Decision**: `.gitattributes` でディレクトリを除外し、公開前検査もディレクトリを検出する。テストは実際の `git archive` と意図的な属性不備の両方を使う。
- **Rationale**: 除外の正常動作と設定ミスでの同期前停止は別の性質である。
- **Alternatives**: 固定ファイル名の検査は未知のファイルを守れない。

## R3: 現行参照と記録

- **Decision**: スクリプト、テスト、設定、workflow ソースと導入済みコピー、現行ガイドと AGENTS を更新し、凍結 feature と過去の記録は残す。
- **Rationale**: 実行経路を維持しながら過去の事実を改変しない。
- **Alternatives**: すべてを機械的に置換すると履歴が誤った記録になる。
