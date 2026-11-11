# Tasks: TAK-97

- [x] T001 Issue と既存のメニュー、選択、zip 内の条件を確認する。
- [x] T002 単一ファイルの判定、アプリ候補のサブメニュー、起動失敗時の表示を実装する。
- [x] T003 Core の判定テストと日英の表示文言、利用ガイドを更新する。
- [x] T004 Cloud の `scripts/dev/check-all.sh` を通す。
- [x] T005 macOS の CI で `swift build` と通常の `swift test` を確認する。
  - [実行 42967962291](https://github.com/yoshidax/folzio-dev/actions/runs/42967962291): ビルド成功、通常テスト 1,172 件成功。
    失敗を許容する性能テストは 27 件中 4 件が時間基準を超えた。
- [ ] T006 保守者の macOS で [quickstart.md](quickstart.md) の GUI 確認を行う。
- [ ] T007 PR の最後に最新の `origin/master` を取り込み、`specs/product/` へ FR-368 を反映する。
