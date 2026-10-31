# Bug Verification: サムネイルの名前変更の拒否・キャンセル

- **Slug**: thumbnail-rename-cancel（会話中の fix から解決）
- **Tested**: 2026-10-31
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Issue**: TAK-13
- **Result**: partial

## Summary

Cloud の静的検査は通過した。回帰テストは追加済みだが、Swift のコンパイル・実行と GUI 再現は未実施。
元の症状が実機で解消したとはまだ判定しない。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| 差分の検査 | `git diff --check` | pass | 空白エラーなし |
| ネットワーク API | `scripts/check-no-network.sh` | pass | Sources に禁止 API なし |
| README 同期 | `scripts/check-readme-sync.sh master` | fail | ローカル master が存在しないため |
| README 同期（取得済み master を指定） | `scripts/check-readme-sync.sh origin/master` | pass | 最新 master を fetch・取り込み済み |
| 英語コメント | `scripts/dev/check-english-comments.sh` | pass | Sources / Tests / Package.swift を含む |
| push 制約の回帰 | `python3 -I -m unittest discover -s scripts/dev/tests -p 'test_check_git_push.py'` | pass | 3 tests |
| 追加した AppKit テスト | `swift test --filter FolzioAppTests` | not-run | Cloud で Swift を実行しない。macOS が必要 |
| ビルド・通常のテスト | `swift build` / `swift test --no-parallel --skip FolzioPerformanceTests` | not-run | CI 未起動。push は Codex の規則で保留 |
| 変更前後の回帰テスト実行 | 元の先行書き換えあり / なしで比較 | not-run | red / green の実行証拠はない |
| 起動・GUI 再現 | 保守者の macOS で実行 | not-run | 確認手順は下記 |

## Output Excerpts

```text
no network API references in Sources
README.md and README.ja.md are in sync
source comments are English-only
Ran 3 tests
OK
```

## Residual Risks

- 新設 App 用ターゲットのコンパイルと、macOS CI での非表示ウインドウ・field editor の利用は未検証。
- セルのコールバックでモデルを更新しないテストは検証拒否・確認キャンセルの戻り先の状態を検査する。
  コーディネーターの確認モーダルを操作する end-to-end テストではない。
- 成功後の実一覧再読み込み、ツリー・検索結果との整合、セル再利用、フォーカスの挙動は GUI で確認する必要がある。

## Recommendation

マージ・Done 更新は保留し、macOS でのビルド・テストと GUI 確認を行う。

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
