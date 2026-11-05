# 検証: ID 重複解消規則

1. `scripts/dev/check-spec-ids.sh` を反映前と反映後に実行し、重複がないことを確認する。
2. `python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-all.sh` を実行する。
3. EC-135 の `FR`・`SC`・`EC`・`A`・`US`、master 取り込み後の検出、反映前の振り直し、マージ済み ID の保護を確認する。
4. 未マージと両方マージ済みの 2 ケースで、EC-135 と共通手順から憲章をたどり、同じ対象を指定できることを確認する。
5. FR-193 → EC-135 → 憲章・共通手順、README・AGENTS.md・憲章・Cloud 7章 → 共通手順を確認する。`scripts/dev/check-agents-md.sh` で AGENTS.md の行数と参照先を検査する。
6. 共通手順に最大番号・凍結記録・参照・判別不能時・検査の限界があり、Cloud 固有の PR・master 取り込み操作が含まれないことを確認する。
7. 憲章の改定日・PATCH バージョン・Sync Impact Report と TAK-76 の追従記録を確認する。
8. 保守者がローカルで必要なビルド・テストと起動スモークを確認する。GUI の確認が済むまで完了にしない。
