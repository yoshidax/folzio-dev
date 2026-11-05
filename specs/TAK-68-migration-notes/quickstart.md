# 検証: 仕様反映と凍結注記

1. `scripts/dev/check-spec-ids.sh` を `specs/product/` への反映前と反映後に実行する。
2. `python3 scripts/dev/check-spec-format.py`、`scripts/dev/check-all.sh`、`git diff --check` を実行する。
3. `specs/product/file-operations.md` の FR-018・FR-025 を、TAK-10 の仕様、`NameValidation.swift` と既存の回帰テストに照らし、拡張子を除いた末尾の半角十進数字、上限超過、ゼロだけの場合、先頭ゼロ、大文字小文字を区別しない衝突回避、既存項目の保護が一致することを確認する。
4. 005 が開発環境向けで製品仕様の反映対象外と明記され、TAK-46・TAK-49・TAK-10 は製品仕様へ反映済みであることを確認する。
5. 各 feature の先頭注記・リンクを確認し、TAK-49 の ID 対応表を含め、既存の本文に変更がないことを diff で確認する。
6. `research.md` の TAK-10・TAK-46・TAK-49 の過去の未チェック項目と検証記録を確認し、当時の未確認と後続コミットの結果を混同しない。
7. macOS CI とローカルの確認は実施した事実または保守者の判断を正確に記録し、未実施を成功と扱わない。
