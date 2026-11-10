# Bug Fix: 約束をドロップ内で要求する

- **Slug**: tak-88-probe-request-timing
- **Fixed**: 2026-11-09
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

受け取りフォルダをバックグラウンドで事前に用意し、ドロップを返す前に約束の書き出しを要求する。外部のPythonランチャーや16回の上限に依存しない。

## Changes

- PreparedProbeFoldersを追加。2個の待機、消費後の補充、失敗時のログを持つ。失敗時は無限再試行しない。
- receivePromisesを同期的なBoolの処理に変更。フォルダ未準備ならfalse、要求したらtrue。要求自体をTaskへ送らない。
- request-begin / drop-returnをログへ追加。共通宛先と非隔離readerの処理を維持。
- quickstartに準備完了を待つ手順を追加。

## Tests Added or Updated

--self-testのcheckPreparedFoldersで、未準備時のnil、作成スレッド、消費後の補充、別の実在フォルダを確認する。

## Local Verification

通常モードとSwift 6の警告をエラーとする型検査、Swift 6の全自己検査は修正候補で成功。適用するソースは候補と同じ。

## Deviations from Assessment

なし。製品Sources / Testsは変更しない。

## Follow-ups

19:47 JSTに通常スクリプトのGUIでSafari PNGと写真2枚の書き出し・要求順序・補充を確認した。診断版の5回のドロップ成功とは分けてtest.mdとvalidation.mdに記録した。T007の仕様案の確認後も製品のGUI確認はT031・T037として残す。
