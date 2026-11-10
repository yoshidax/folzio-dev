# Bug Assessment: TAK-88 自己ドラッグのキュー問い合わせで停止する

- **Slug**: tak-88-probe-provider-actor（作業内容から採用）
- **Created**: 2026-11-09
- **Source**: このチャットの保守者の報告と添付クラッシュダンプ
- **Issue**: [TAK-88](https://linear.app/takyoshida/issue/TAK-88)
- **Branch**: claude/clever-knuth-udimb8（指定ブランチを継続）
- **Verdict**: valid
- **Severity**: high（T006 の自己ドラッグ確認を妨げる）

## Report (verbatim or summarized)

保守者が `cat.png（中身は JPEG）` の自己ドラッグでクラッシュしたと報告。
添付は `/Users/igachan/.codex/attachments/5be20851-9fcb-4eca-b3e7-729f20d2171a/貼り付けたテキスト.txt`。
2026-11-09 16:40:41 JST、SIGTRAP、`com.apple.FileCoordination.3`、`_checkExpectedExecutor`、`NSFileProviderXPCMessenger _makeProvider:provideItemAtURL:withInfo:completionHandler:` がある。

## Symptom

自己ドラッグの file promise を要求すると、書き出し完了より前にプロセスが停止する。期待する動作は約束の画像を書き出し、受け取り結果を記録すること。

## 仕様との照合

製品仕様の ID は該当しない。開発用確認ツールの T004（名前と中身が異なる2つの画像の約束）と、T006 / quickstart の自己ドラッグ確認に反する実装の不具合。要件変更は不要。
製品ソース、T007 の設計確定、Phase 2 以降には進まない。

## Reproduction

1. 修正済みの reader を持つ確認スクリプトを起動する。
2. 下部の `cat.png` を上部の欄にドラッグする。
3. ログは receivers=1、fileTypes=[public.png]、fileNames(requested)=[cat.png] まで進むが、その後 SIGTRAP となる。
4. GUI なしでも、`SamplePromise` の `operationQueueForFilePromiseProvider:` を OperationQueue から Objective-C の perform で呼ぶ自己検査を追加すると終了コード133で停止することを確認。

## Suspected Code Paths

- `SamplePromise.operationQueue(for:)`。省略した隔離指定がプロトコルから MainActor を引き継ぐ。
- 先の修正で扱った受け取り側 reader とは別の書き出し側の問い合わせ。

## Root Cause Hypothesis

確度: 高。現行 SDK の `NSFilePromiseProvider.h` では `operationQueueForFilePromiseProvider:` が `NS_SWIFT_UI_ACTOR` とされる。
実行時には Foundation のファイル調整キューから問い合わせられる。
元の SIL の Objective-C thunk は MainActor で、69行の入口に `_checkExpectedExecutor` がある。
前回の自己検査はこの Objective-C 入口をバックグラウンドから呼んでいなかった。

## Proposed Remediation

- 不変の専用キューを返すメソッドを明示的に nonisolated とする。
- `--self-test` に、2つのサンプルのキューと名前の Objective-C 入口をバックグラウンドから呼び、返された専用キューで書き出して実際の画像形式を検査する回帰確認を加える。

**Files likely to change**:
- `scripts/dev/pasteboard-probe.swift`
- T006 の `checklists/validation.md` と本バグの記録

**Tests to add or update**:
- 修正前は終了133、修正案では成功する provider の回帰確認。
- 画像と reader の既存自己検査、通常モードと Swift 6 の警告なしの型検査。

## Risks & Considerations

- キューは初期化後に差し替えない。返すメソッドは UI や他の可変状態を使わない。
- 回帰確認は実際のドラッグ全体を代替しない。保守者による GUI の再確認までは partial とする。
- Safari の約束がキャンセルとなる原因は、この書き出し側の修正で解消したとは扱わない。

## Open Questions

- 実際の自己ドラッグの修正後の結果は未確認。
