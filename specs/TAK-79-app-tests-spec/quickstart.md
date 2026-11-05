# 検証: TAK-79

1. `Package.swift` の 3 つのテストターゲットと `specs/product/contracts/app-bundle.md`、日英の開発ガイドの一覧を照合する。既存の製品ターゲットと補助ツールについての記載も確認する。
2. `scripts/dev/check-all.sh` を実行し、仕様 ID を確認する。製品仕様変更後は `python3 scripts/dev/check-spec-format.py` で形式も検査する。
3. アプリコードを変更しないため macOS CI・ローカル起動確認の要否を保守者に示す。実施・省略の状態と理由を `tasks.md` に記録する。
4. 製品仕様の差分を保守者に提示して承認を得る。最後に凍結注記案を示して承認を得た後、`spec.md` に注記を付ける。
