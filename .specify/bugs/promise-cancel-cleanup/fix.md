# Bug Fix: 取消後も書き出し完了まで受け取り先を保持する

- **Slug**: promise-cancel-cleanup
- **Fixed**: 2026-11-10
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

取り消しでUIと保存を止める処理と、外部writerの完了を待って一時領域を消す処理を分離した。受け取り側のオブジェクトも完了まで保持し、取り消し直後に写真アプリの書き出し先が消えることを防ぐ。

## Changes

| File | Change | Notes |
|---|---|---|
| Sources/FolzioCore/Operations/ImportPromiseCompletion.swift | added | UIの終端状態と独立してreceiverごとの完了と重複を数える |
| Sources/FolzioApp/Operations/ImportPromiseDelivery.swift | added | 破棄したpayloadもwriterの完了を通知する値 |
| Sources/FolzioApp/Operations/ImportTiming.swift | added | 段階・時間・種類だけのローカル診断イベント |
| Sources/FolzioApp/Operations/ImportSession.swift | modified | 取消後の保持、最後のwriter後の掃除、保持中の期限・容量監視、時間記録 |
| Tests/FolzioCoreTests/ImportPromiseCompletionTests.swift | added tests | 複数receiver・複数ファイル・重複・名前未取得の失敗 |
| Tests/FolzioAppTests/ImportSessionTests.swift | updated tests | 取消、遅延通知、保持・解放、期限・容量、打ち切り後の再生成、診断の段階 |

## Diff Highlights

- cancelはUIの行と保存を直ちに止め、未完了のwriterをretiringSessionsへ保持する。通常の完了や検査後の取消では待たずに掃除する。
- readerは取消後に複製しないが、完了の識別子と結果をMainActorへ必ず通知する。エラーに付くURLは使わない。
- 保持中は既存のImportBudgetを使う。完了前でも容量超過または残るwriterすべての期限到達で掃除する。混在する画像・動画では、画像だけの60秒で動画の受け取り先を消さない。
- 打ち切り済みのsessionを後で再保持しない。打ち切り後にwriterが一時領域を再生成して通知した場合も再度掃除する。
- 正常終了時にwriterが残る場合はフォルダと掃除の記録を保持し、起動時の既存の掃除へ渡す。未使用のプールは正常終了で消す。
- ローカルLoggerのsubsystemはlocal.folzio.Folzio、categoryはImport。requested/reader/checking/checked/confirming/saving/finished/cancelled/failed/cleanupRequestedを記録する。ID・種類・経過時間・区間時間だけで、ファイル名・パス・元URL・画像内容は含めない。

## Tests Added or Updated

- cancelledProducerKeepsDestinationUntilItsCallback: 取消後に既に始まった掃除をflushしても受け取り先が残り、writerが書き込める。最後に削除し、保存しない。
- cancelledReaderStillAcknowledgesCompletionWithoutCloning: 取消後のreaderが完了を通知し、複製も早期削除もしない。
- cancellationWaitsForAllReceiversAndDeduplicatesTheirFiles: 共通宛先は全receiver・全ファイルまで保持し、重複で早く消さない。
- retiringReceiversKeepCapacityAndDeadlineLimits: 混在の60/600秒と取消後の容量上限を確認する。
- cancelledSessionRetainsItsProducerUntilCompletion: 受信元が保持され、完了後に解放される。
- timingSeparatesReceptionCheckingAndSaving: fake clockで受信23秒、確認待ち、保存1秒を区別する。
- lateProducerAfterDeadlineIsSweptWithoutSaving: 期限後の再生成を掃除し、保存しない。
- capacityFailureDoesNotRetireAgainAfterItsAlertEnds: 容量超過の表示が閉じた後に、打ち切り済みwriterを再保持しない。

## Local Verification

- 変更前: 対象2件は受け取り先が消えるassertionで両方失敗。red-tests.log。
- 対象テスト: Core 5件・App 20件成功。green-tests.log。
- 最終コード: swift build成功、swift test --no-parallel --skip FolzioPerformanceTestsでCore 1,082件・App 63件、合計1,145件成功。
- scripts/dev/check-all.sh成功（Python 179件）、git diff --check成功。
- scripts/make-app.sh成功。保守者が修正ビルドでPhotos MOVの受信中に取り消し、約1分待ってもPhotosにエラーが出ず、保存先が空のままと確認（2026-11-10）。
- ログ: /tmp/folzio-tak88-cancel-fix/。

## Deviations from Assessment

なし。完了の純粋な判断をCoreへ分離し、打ち切り後の再保持防止も同じ後片付けの範囲で追加した。

## Follow-ups

- Photosの通常保存ではMOV/MP4の動画実体を確認済み。今回のGUI再確認では途中取消後の元のエラーが出なかった。修正後CIとT031の他の確認は残る。
- 写真アプリ→Finderは約23秒、Folzioも同程度という保守者の比較を維持し、異常な速度劣化として扱わない。最初の約1分の待ちとは別の観測。
- 診断のreader.durationは複製に要した時間、checked.durationは検査・準備、finished.durationはsaving以降（衝突の判断待ちを含む）。confirmingとsavingの間は確認待ち。cleanupRequestedは掃除の開始要求であり削除完了の保証ではない。
