# Tasks: 大きな連番のファイル操作

## Phase 1: Core

- [X] T001 [US1] `Tests/FolzioCoreTests/NameValidationTests.swift` に `Int.max`、その手前での衝突、上限超えの入力と複数衝突、先頭ゼロ、桁上がり、拡張子なし、通常名の回帰テストを追加する（FR-018、FR-025）。
- [X] T002 [US1] `Sources/FolzioCore/Operations/NameValidation.swift` で桁数に依存しない半角十進数の解析と加算を実装する。通常の衝突判定と公開 API を維持する（T001 後）。
- [X] T003 [US1] `Tests/FolzioCoreTests/FileOperationServiceTests.swift` で複製・「両方残す」の元と衝突先の内容保全を確認する（T002 後）。

## Phase 2: 検証

- [X] T004 Cloud の検証ゲートを実行し、結果を記録する。`origin/master` を基準とした README 同期、通信 API、英語コメント、スキル同期、push 制約テスト 3 件、`git diff --check` は成功。
- [ ] T005 macOS CI で `swift build` / `swift test` を実行し結果を確認する。保守者はローカルでビルド・テストが成功したと報告した。CI run 41955014790（9f37375）はビルドと通常テスト 1,056 件が成功したが、性能テスト 27 件中 1 件が失敗（20 万件のスライドショー候補抽出: 0.20199225 秒、基準 0.2 秒未満）。性能テストは non-blocking のためジョブ全体は成功と表示される。
- [ ] T006 [MANUAL] 保守者が [quickstart.md](quickstart.md) の起動スモークと複製・「両方残す」を確認する。2026-11-05 に複製と「両方残す」は問題なしと報告されたが、3 ペインの表示は明示的な報告がなく未確認。
- [ ] T007 検証後、最新 master を取り込み、FR-018・FR-025 を `specs/product/file-operations.md` に反映してレビューを受ける。
