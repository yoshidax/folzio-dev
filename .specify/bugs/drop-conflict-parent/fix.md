# Bug Fix: 同名ドロップの確認を受信先ウインドウへ表示する

- **Slug**: drop-conflict-parent
- **Fixed**: 2026-11-10
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

ドラッグの宛先ウインドウを非同期の受信後も確認へ渡し、キー・メインウインドウが取れない場合に衝突確認を省略することを防いだ。確認を表示する時点で親を前面にして、利用者が選択できるようにした。

## Changes

| File | Change | Notes |
|---|---|---|
| Sources/FolzioApp/Operations/FileOperationCoordinator.swift | modified | draggingDestinationWindowを弱く保持して保存へ渡す。親が取得できなければ受信を開始せず、後で失われた場合も保存を取り消す。親の既存シートも待つ |
| Sources/FolzioApp/Operations/ConfirmationPresenter.swift | modified | 明示した親を優先し、確認を表示する際に前面化。シート表示・フォールバック取得をテストで差し替え可能にした |
| Sources/FolzioApp/Operations/ConflictPrompt.swift | modified | 同じ親を使って必須の衝突確認を表示する。選択肢・抑止条件・既存のフォールバック規則は維持 |
| Tests/FolzioAppTests/ImportPromptParentTests.swift | added | 非アクティブ時の親、3つの衝突選択と実保存、通常確認の取消、無関係な親の回避、既存呼び出しを検証 |

## Diff Highlights

- importDropはNSDraggingInfo.draggingDestinationWindowを受信開始時に取得する。受信待ちの間は弱い参照とし、保存の直前に取得できた親を明示する。
- ImportConfirmationQueueによる直列化を保ち、指定した親に既存のシートがある場合も待つ。受信パネルと⌘.のキー処理は変更しない。
- 親を渡した確認・衝突はグローバルなkeyWindow/mainWindowを調べない。受信以外の既存呼び出しは既定引数で維持する。
- シート表示の直前にmakeKeyAndOrderFrontとactivateを呼ぶ。シートを出さない操作でアプリを前面にせず、受信中のパネルのフォーカスも変えない。
- 3つの衝突選択とFileOperationServiceの動作は既存を使用する。Core・仕様本文・依存ツールを変更しない。

## Tests Added or Updated

- collisionWithoutActiveWindow: 3つの選択×同一/別ボリューム方針の6ケース。コピー確認を省略する設定でも衝突を選び、replaceで新しいデータ、keepBothで元データと新しい連番、abortで元データと受信元が残る。
- explicitParentPrecedesUnrelatedWindow: 操作確認→衝突が順番に同じ指定の親へ表示され、無関係なグローバルの親を使わない。
- confirmationCancellation: 操作確認の取消で衝突を開始せず、既存・受信ファイルを変更しない。
- legacyFallback: 明示した親がない既存呼び出しのフォールバックを維持する。

## Local Verification

- 修正前: 本再現の4テストで17 issues（0.525秒）。確認が表示されず、連番のファイルも作られない。テスト準備時のFixtureの隔離はMainActorに明示してから本再現した。
- 修正後: 関連31件（ImportPromptParentTests / ReceivedFileTransferTests / ImportSessionTests）成功、0.577秒。
- swift build、全通常1,155件（Core 1,082件97.511秒・App 73件1.198秒）、規約チェック（Python 179件）、make-app成功。
- 差分確認で文面生成に不要な親の引数だけを削除した後、最終コードでbuild、全App 73件（1.674秒）、規約チェック（Python 179件）、make-app、git diff --checkを再確認し成功。Coreのソースは前後で変更なし。
- 実機は手順整理後のTAK88-recheck-01〜06でSafari・Chrome各3選択がすべて成功。既存/新規の内容・連番・中止後の不変をSHA-256で確認し、保存した新画像のquarantineも各ブラウザと一致。今回のCIは未確認。
- ログは /tmp/folzio-tak88-conflict-fix/ のred-tests.log、green-tests.log、build.log、tests.log、check-all.log、make-app.log、final-build.log、final-app-tests.log、final-check-all.log、final-make-app.log。

## Deviations from Assessment

確認を実際に選べるよう、指定の親の保持に加えてシート表示時の前面化を加えた。ブラウザの背後へ確認を残さないためであり、承認済みの「Folzioが前面でなくても確認を省略しない」の範囲。受信中に前面化する処理は加えていない。before/after_bug_fixの登録hookはなし。

## Follow-ups

保守者が手順を整理して1件ずつ行った実機確認で、全6件の確認表示と保存結果が成功した。初回の手順混在の結果は判定保留としてtest.mdへ残した。元の症状は解消し、CIを確認する。T030・T031は未チェック、Phase 4へ進まない。
