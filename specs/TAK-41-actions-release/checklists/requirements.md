# Specification Quality Checklist: リリース PR からの公開と配布

**Created**: 2026-11-06
**Feature**: [spec.md](../spec.md)

## 要望と範囲

- [x] 2リポジトリ、release.json 変更 PR 起点、CI ZIP のローカル確認を反映した
- [x] 通常 master 更新と公開先への書き込みを区別した
- [x] PR・候補と公開 writer の資格情報を分離した
- [x] 最終の GUI 確認と Release 公開を保守者の操作として残した
- [x] 既存要件の変更後全文と領域参照・反映先を記載した
- [x] 成功基準と異常系・実装タスクの対応を確認した
- [x] 未解決の NEEDS CLARIFICATION がない

## レビュー10件の反映

- [x] master 追従不要でも、候補のずれは固定 M の再生成とローカル再確認で扱える
- [x] 同期の安全性を共通 concurrency の pending 待機列に依存させない
- [x] 性能は既存 CI と同じ非ブロッキングとし、結果を記録する
- [x] 手動 source_sha とイベント共通の artifact 名を定義した
- [x] 初回 bootstrap_public_base の入力・拒否条件・テスト対象を定義した
- [x] 同期で候補 CI を再利用し、同一コードを macOS で3回検証しない
- [x] 性能の明示的な例外以外は、失敗時点で後続を中断する
- [x] 既存 ID の参照には領域ファイルを添えた
- [x] version / build の先頭0を拒否し、検証タスクへ加えた
- [x] リモートブランチ名と Cloud のローカル checkout を区別した

設計案の品質確認であり、実装・本番設定・実 CI・GUI 確認の完了を意味しない。
