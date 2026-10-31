# Bug Fix: サムネイルの未確定の名前を先行表示しない

- **Slug**: thumbnail-rename-cancel（会話中の assessment から解決）
- **Fixed**: 2026-10-31
- **Assessment**: ./assessment.md
- **Issue**: TAK-13
- **Status**: applied（ビルド・回帰テストの実行と GUI 確認は未完了）

## Summary

保守者の `ok` を受け、診断時の推奨案を実装した。サムネイルの名前編集を確定しても、処理結果に先行して
入力名を表示しない。元の表示名・アクセシビリティ名を保ち、成功後のモデル再読み込みで新しい名前を反映する。

## Changes

| File | Change | Notes |
|------|--------|-------|
| `Sources/FolzioApp/FileList/ThumbnailModeView.swift` | modified | `endRenaming` の入力名への先行書き換え 3 行を削除。理由を英語コメントに記録 |
| 同上 | modified | `ThumbnailItemView` を private から internal にし、`@testable import` でセルを検証可能にした。メンバーの private は維持 |
| `Package.swift` | modified | AppKit の UI 回帰を Core に持ち込まず検査する `FolzioAppTests` ターゲットを追加 |
| `Tests/FolzioAppTests/ThumbnailRenameTests.swift` | added | セルの編集確定・キャンセルと、モデル反映を直接検査 |

## Tests Added or Updated

`ThumbnailRenameTests`（Swift Testing、MainActor、直列、15 ケース）:

- `unappliedRename`: ファイル・フォルダ × 4 入力（通常名・無効文字・既存名相当・拡張子変更）。
  コールバックはモデルを更新せず終了する。渡した URL・入力名、元の表示名、ラベルとビューのアクセシビリティ名を確認する。
  後続の編集終了通知で二重送信しないことも検査する。
- `successfulRename`: ファイル・フォルダ。編集確定後は元の表示、成功結果のモデルで再構成すると新しい表示になること。
- `escapeCancelsEditing`: ファイル・フォルダ。Escape で元の表示へ戻り、コールバックを呼ばないこと。
- `noOpRename`: 空名・空白のみ・同名でコールバックを呼ばないこと。

実際の NSTextField と field editor を使い、Return / Escape の delegate 経路を呼ぶ。
NSWindow は編集用に生成するが画面には表示しない。実ファイルの変更やモーダル表示はしない。
名前の検証・確認モーダル自体をテストするものではなく、操作が適用されない場合のセル状態を固定する。
変更前の 3 行がある場合は `unappliedRename` の元の名前に関するアサーションが破られる構成だが、
変更前後での実行による red / green 確認はしていない。

## Local Verification

- `git diff --check`: pass。
- `scripts/check-no-network.sh`: pass（`no network API references in Sources`）。
- `scripts/check-readme-sync.sh master`: failed（この checkout にローカル `master` がない）。
  最新を取得・取り込み済みの `origin/master` を指定して再実行し pass。
- `scripts/dev/check-english-comments.sh`: pass。
- `python3 -I -m unittest discover -s scripts/dev/tests -p 'test_check_git_push.py'`: pass（3 tests）。
- Swift ビルド・テスト、GUI: not-run。Cloud で実行しない規約に従う。CI / 保守者の macOS での確認が必要。

## Deviations from Assessment

修正方針の変更はない。assessment に含めた App 用テストターゲットを追加する案を採用した。
`ThumbnailItemView` のアクセス範囲を internal にする以外に、コーディネーターの API や入力の正規化は変更していない。

## Follow-ups

- `.codex/rules/sdd.rules` に `git push` の禁止があるため push しない。
  「SDD の実行中に push しない。結果を確認してからユーザーが実行する。」という規則に従い、CI も未起動。
  PR は保守者の明示的な依頼がないため作成しない。
- `swift build` と `swift test --no-parallel --skip FolzioPerformanceTests` を macOS CI で確認する。
- 保守者の macOS で `scripts/make-app.sh` → `open .build/Folzio.app` を実行し、3 ペインの起動と、
  キャンセル・検証拒否後の名前、成功時の名前反映を確認する。詳細は `test.md`。
- Linear は In Progress のまま。GUI 未検証のため完了扱いにしない。
- `.specify/extensions.yml` に `before_bug_fix` / `after_bug_fix` の登録はない。
