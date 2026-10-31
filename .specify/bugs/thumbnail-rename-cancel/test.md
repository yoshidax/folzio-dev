# Bug Verification: サムネイルの名前変更の拒否・キャンセル

- **Slug**: thumbnail-rename-cancel（会話中の fix から解決）
- **Tested**: 2026-10-31
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Issue**: TAK-13
- **Result**: partial

## Summary

Cloud の静的検査と macOS CI のビルド・追加したサムネイルの回帰テスト 15 ケースは通過した。
2026-10-31、保守者から「GUIスモークが完了しました」と報告を受けた。
CI 全体には既存の言語切り替えテスト 1 件の失敗があり、再実行を依頼した。
元の不具合の各再現条件・アクセシビリティ確認の個別結果は未報告のため、判定は partial を維持する。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| 差分の検査 | `git diff --check` | pass | 空白エラーなし |
| ネットワーク API | `scripts/check-no-network.sh` | pass | Sources に禁止 API なし |
| README 同期 | `scripts/check-readme-sync.sh master` | fail | ローカル master が存在しないため |
| README 同期（取得済み master を指定） | `scripts/check-readme-sync.sh origin/master` | pass | 最新 master を fetch・取り込み済み |
| 英語コメント | `scripts/dev/check-english-comments.sh` | pass | Sources / Tests / Package.swift を含む |
| push 制約の回帰 | `python3 -I -m unittest discover -s scripts/dev/tests -p 'test_check_git_push.py'` | pass | 3 tests |
| 追加した AppKit テスト | CI の通常のテストに含めて実行 | pass | run 41182992250 / attempt 1。Thumbnail rename の 15 ケースが成功 |
| ビルド | `swift build` | pass | 同 CI、macOS 15 / Xcode 16.0、対象 5d6e62e |
| 通常のテスト | `swift test --no-parallel --skip FolzioPerformanceTests` | fail | 832 tests / 1 issue。既存の BrowserModelTests.languageChangeDuringListing が失敗 |
| 通常のテスト再実行 | 失敗した CI ジョブを再実行 | pending | 初回失敗のログを確認後、同じソースで再実行を依頼 |
| 変更前後の回帰テスト実行 | 元の先行書き換えあり / なしで比較 | not-run | red / green の実行証拠はない |
| GUI スモーク | 保守者の macOS で実行 | pass（保守者の報告） | 2026-10-31。「GUIスモークが完了しました」。実行コマンド・ビルド ID の個別報告はなし |
| 不具合の GUI 再現確認 | 下記各条件で検証 | not-run（未報告） | 各キャンセル・拒否・アクセシビリティの個別結果は受け取っていない |

## Output Excerpts

```text
no network API references in Sources
README.md and README.ja.md are in sync
source comments are English-only
Ran 3 tests
OK

# macOS CI: run 41182992250 / attempt 1
Suite "Thumbnail rename" passed after 0.255 seconds.
Test "Enumeration started before a language change also displays the new kind names"
  Expectation failed: (model.listing.files.first?.typeDescription → "Folder") == "フォルダ"
Test run with 832 tests failed after 124.753 seconds with 1 issue.
```

## Residual Risks

- 新設 App 用ターゲットのコンパイルと、非表示ウインドウ・field editor の利用は macOS CI で成功した。
- CI 全体は未成功。失敗は `BrowserModelTests.swift:22` の言語切り替えテスト。
  このテストは 20ms の待機後に言語を切り替え、非同期の再変換完了を直接待たず結果を確認する。
  今回変更していない処理だが、今回の AppKit テスト追加による実行条件の影響も含め、原因は未確定。
- セルのコールバックでモデルを更新しないテストは検証拒否・確認キャンセルの戻り先の状態を検査する。
  コーディネーターの確認モーダルを操作する end-to-end テストではない。
- 成功後の実一覧再読み込み、ツリー・検索結果との整合、セル再利用、フォーカスの挙動は GUI で確認する必要がある。

## Recommendation

PR #8 は作成済み、Linear は In Review。マージ・Done 更新は保留し、CI 再実行結果と不具合の個別確認を記録する。
GUI スモーク完了の報告を、以下の全条件を確認した証拠には拡張しない。

保守者は作業変更を反映した macOS checkout で次を実行する:

```bash
swift build
swift test --filter FolzioAppTests
swift test --no-parallel --skip FolzioPerformanceTests
scripts/make-app.sh
open .build/Folzio.app
```

1. 3 ペインが表示されることを確認する。
2. サムネイル形式でファイルとフォルダの名前を編集し、確認モーダルでキャンセルする。
   元の表示名・VoiceOver の名前を保ち、ツリーの名前と一致することを確認する。
3. `bad/name.jpg` と既存名を入力し、検証エラーを閉じた後も元の名前を保つことを確認する。
4. ファイルの拡張子変更確認をキャンセルし、元の表示が残ることを確認する。
5. Escape・空名・同名で操作を適用しないこと、通常の名前変更を承認すると実ファイル名と表示名が更新されることを確認する。
6. 別フォルダへ移動して戻った場合、検索結果、リスト形式でも表示が整合することを確認する。

`.specify/extensions.yml` に `before_bug_test` / `after_bug_test` の登録はない。
