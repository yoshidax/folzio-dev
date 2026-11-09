# Bug Assessment: TAK-88 の画像コピー確認中に SIGBUS

- **Slug**: tak-88-probe-clipboard-crash（作業内容から採用）
- **Created**: 2026-11-09
- **Source**: 保守者のこのチャットの報告、確認ログ、macOSクラッシュレポート
- **Issue**: [TAK-88](https://linear.app/takyoshida/issue/TAK-88)
- **Branch**: claude/clever-knuth-udimb8（引き継ぎブランチを継続）
- **Verdict**: valid（クラッシュは確認。原因と安定した再現条件は未確定）
- **Severity**: high（T006 の測定を中断）

## Report (verbatim or summarized)

保守者がChromeのGIFをドラッグした後、画像コピーの「クリップボードを調べる」でクラッシュしたと報告。
17:59:23 JSTのログは、クリップボードのpublic.png等の型を列挙した後、PNGのbytes/readSecondsが出る前に停止。
ダンプ `/Users/igachan/Library/Logs/DiagnosticReports/swift-frontend-2026-11-09-175929.ips` はメインスレッドのEXC_BAD_ACCESS / SIGBUS。
SerialExecutor.isMainExecutor、swift_task_isCurrentExecutorWithFlagsImpl等を含む。
前の2件のactor隔離違反のSIGTRAPとは区別する。

## Symptom

画像コピーのデータを調べる途中でプロセスが落ちる。期待する動作は型・容量・時間を記録して確認を続けられること。
保守者は再起動後に成功したと報告し、画像コピーの読み出し完了は確認できた。

## 仕様との照合

製品仕様のIDは該当しない。開発用確認スクリプトのT004と、macOSで実測するT006に関する不具合。
要件変更は必要と認められていない。原因未確定のためソースの修正には進まず、観測を記録する。
Phase 2以降には進まない。

## Reproduction

1. 確認スクリプトをSwift 6言語モードで直接実行する。
2. SafariのGIFの約束が未完了のまま、Chromeの128×96のGIFをドラッグする。
3. Chrome GIFの画像コピー後「クリップボードを調べる」を押すと、changeCount=2142の型列挙後にSIGBUSとなった。
4. 再起動後、保守者が同じ画像コピーを試し、changeCount=2144、PNG 677 bytes、0.000637秒、receivers=0で成功した。

常に再現するとは確認できていない。再起動後はdrag-enterのみでdropの記録がなく、初回と同じ操作順を再現した証拠にはならない。

## Suspected Code Paths

- `ProbeController.inspect` の画像データ読み出し前後とautoreleasepoolのクロージャ。
- `receivePromises` のTask内で行うlegacy promiseの要求。初回はfileNames(requested)も未記録で、未完了操作との関係は切り分けていない。
- Swiftの直接実行方式とconcurrency runtimeの影響も未確定。

## Root Cause Hypothesis

確度: 低。スタックだけで原因を特定できていない。PNGデータの破損、actor違反、Swift処理系の不具合のいずれとも断定しない。
別スレッドにNSLegacyFilePromiseCoordinatorの待機があるが、因果関係は不明。

## Proposed Remediation

現時点でソースの修正はしない。修正前に、同じコピーと操作順で再現したスタックをシンボル付きで取得する。
診断用に、現行スクリプトの一時コピーへread-beginログとGUIなしのクリップボード確認フラグを加え、`swiftc -g -Onone -swift-version 6`で `/tmp/folzio-tak88-clipboard-crash/probe-debug` を作った。
この診断用コピーはリポジトリへ適用していない。

## Checks

- 診断用実行ファイルの全自己検査は成功（画像2種・TIFF・reader・provider）。
- 診断用のGUIなしクリップボード確認はSwift直接実行とコンパイル済み実行の両方で成功したが、changeCountは2143に変化しており、画像の型もなく、クラッシュ時の2142とは別の内容だった。同条件での再現検証にはならない。
- LLDBによるGUIなしの事前確認は保守者が実行を見送ったため未実行。再試行しない。GUIを起動する診断も未実行。
- 再起動後のChrome GIF画像コピーの成功を確認。ソース修正で解決したとは扱わない。

## Risks & Considerations

- 再起動でコピーが成功しても、GIFの約束の書き出しや元のクラッシュ原因が解消した証拠にはならない。
- 元のログ: `/tmp/folzio-tak88-provider-fix/chrome-gif-crash-20261109-1759.log`
- 再起動後: `/tmp/folzio-tak88-clipboard-crash/chrome-gif-restart-20261109-1813.log`
- T006・T007は未完了。

## Open Questions

- 未完了の約束とクラッシュの関連。
- 画像コピーだけでも再現するか。
- シンボル付きのGUIで再現するか（未実施）。
