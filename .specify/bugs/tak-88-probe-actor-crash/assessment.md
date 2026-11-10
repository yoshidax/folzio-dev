# Bug Assessment: TAK-88 確認スクリプトの reader が SIGTRAP で停止する

- **Slug**: tak-88-probe-actor-crash（作業内容から採用）
- **Created**: 2026-11-09
- **Source**: pasted text（このチャットでの保守者のクラッシュ報告）
- **Issue**: [TAK-88](https://linear.app/takyoshida/issue/TAK-88)
- **Branch**: claude/clever-knuth-udimb8（保守者指定の引き継ぎブランチを継続）
- **Base**: 6f97268
- **Verdict**: valid
- **Severity**: high（T006 の確認が進められない。製品の変更ではない）

## Report (verbatim or summarized)

`swift -swift-version 6 scripts/dev/pasteboard-probe.swift` でウインドウが開くが、JPEG をドロップすると SIGTRAP で終了する。
スタックに `_dispatch_assert_queue_fail`、`_swift_task_checkIsolatedSwift`、`NSBlockOperation main` がある。
先行する `error messaging the mach port for IMKCFRunLoopWakeUpReliable` とクラッシュ原因の関連は確認できていない。

## Symptom

file promise の完了時に確認スクリプトが停止する。期待する動作は reader の結果を記録し、確認を続けられること。

## 仕様との照合

- 製品仕様の ID は該当しない。未完了の feature の開発用ツールであり、製品には組み込まれない。
- `specs/TAK-88-browser-image-import/tasks.md` T004 は約束の書き出し結果を表示する機能、T006 は実アプリとの受け渡し確認を要求する。
- 判定: **実装が T004 の要件に反している**。要件の変更は不要。Phase 2 以降の作業はしない。

## Reproduction

1. 保守者の macOS で `swift -swift-version 6 scripts/dev/pasteboard-probe.swift` を実行する。
2. JPEG をドロップする（報告ではブラウザ名は未特定）。
3. しばらくして SIGTRAP となる。

## Suspected Code Paths

- `scripts/dev/pasteboard-probe.swift:360`: `receivePromisedFiles` の reader。MainActor 内で非 Sendable のクロージャを作っている。
- 同ファイルの GUI 起動部: 言語モード指定なしだと MainActor の初期化がコンパイルできない（このチャットで先に報告、再現済み）。
- `ProbeController.log`: stdout のバッファによりクラッシュ直前の確認ログが tee に残らなかった。

## Root Cause Hypothesis

確度: 高。現行 SDK の `NSFilePromiseReceiver.h` は reader を指定した OperationQueue で呼ぶと定めるが、reader に Sendable の注釈がない。
コンパイラの SIL を確認すると、元の reader は `Isolation: global_actor. type: MainActor` で、360 行の入口に `_checkExpectedExecutor` が挿入される。
バックグラウンドキューでこの条件に違反し、報告されたスタックと一致する。
[Swift の移行資料](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/incrementaladoption/) の Unmarked Sendable Closures と一致する。

## Proposed Remediation

- reader を明示的な `@Sendable` の関数値として生成する補助関数へ分け、ファイルの情報をコールバック内で読み、値だけを MainActor の通知へ渡す。
- 通常の起動部も `MainActor.assumeIsolated` で囲み、言語モード指定なしの起動を可能にする。
- ログを FileHandle で即時出力し、クラッシュ前の観測を保持する。
- 既存の `--self-test` に、実際に使う reader を OperationQueue から複数回呼ぶ回帰確認を加える。

**Files likely to change**:
- `scripts/dev/pasteboard-probe.swift`
- 本バグの記録、および T006 の `checklists/validation.md` への観測の追記

**Tests to add or update**:
- reader の成功、受け取りエラー時に URL を使わない分岐、情報取得エラー、バックグラウンドでの実行、MainActor での通知。
- 通常モードと Swift 6 のコンパイル、および既存の画像自己検査。

## Risks & Considerations

- reader の回帰確認は AppKit の実際のドラッグを代替しない。ブラウザ・写真アプリとの GUI 確認は保守者が行うまで未確認。
- T006 と T007 を未チェックのまま残す。
- 本修正は確認スクリプトだけ。製品ソース・product 仕様を変更しない。

## Open Questions

- 修正後の実際のドラッグでクラッシュが解消するかは保守者の確認待ち。
