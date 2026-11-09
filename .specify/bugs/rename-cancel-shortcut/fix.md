# Bug Fix: 名前の編集中の⌘.を編集取消へ渡す

- **Slug**: rename-cancel-shortcut
- **Fixed**: 2026-11-10
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

メインメニューでCommandのみのピリオドを受けた時、テキスト編集中ならフィールドエディタの既存cancelOperationへ渡す。受信取消のtargetは呼ばず、編集していない時は元のメニュー処理を使う。

## Changes

| File | Change | Notes |
|---|---|---|
| Sources/FolzioApp/App/MainApplicationMenu.swift | added | 標準の編集取消を受信取消より先に扱うNSMenu。シート・モーダルと他のキーはAppKitへ渡す |
| Sources/FolzioApp/App/MainMenu.swift | modified | メインメニューを上記の型で作る |
| Tests/FolzioAppTests/MainMenuCancellationTests.swift | added | 実際に設置したメニューと名前のフィールドエディタ、修飾キー、既存target、モーダルの回帰テスト |

## Diff Highlights

- 現在のキーウインドウとシート・モーダルの有無をMainActorで読む。Command・Control・Option・ShiftのうちCommandのみであるピリオドだけを対象とし、Caps Lockは妨げない。
- NSTextView.doCommand(by:)を通すため、既存の名前編集のdelegateが取消・表示の復元を行う。名前の確定やファイル操作は追加しない。
- 編集がなければsuper.performKeyEquivalentで元の受信取消項目を実行する。ImportSessionManagerやCoreの判断は変更しない。
- テストではGUIを表示しないウインドウはNSApp.keyWindowにならないため、現在の状態だけを差し替える。実際のMainMenu.installで使われるメニューと、実際のThumbnailItemViewのフィールドエディタを通して検証する。

## Tests Added or Updated

- commandPeriodCancelsRename: 受信の有無の2ケースで名前の編集が終わり、元の表示名に戻り、受信取消のtargetや名前の確定を呼ばない。
- commandPeriodWithoutEditor: 編集していない場合は元の受信取消targetを呼ぶ。
- otherModifiers / otherKey: 修飾キーの組合せと別のCommandキーを横取りしない。
- modalCancellation: シート・モーダル側の標準の処理へ残す。
- capsLock: Caps Lock中も編集取消を妨げない。

## Local Verification

- 修正前の本再現: 受信の有無の2ケースとも編集が続き、元の名前に戻らず失敗（0.474秒、4 issues）。最初のテストは隠れたウインドウのkeyWindowがnilとなる準備不足もあったため、状態の差し替えを入れた後の結果を本再現とする。
- 修正後の対象: swift test --filter 'MainMenuCancellationTests|ThumbnailRenameTests|ImportSessionTests'で33件成功（1.019秒）。
- swift build成功。全通常テストはCore 1,082件・App 69件、計1,151件成功。Core 97.007秒・App 0.809秒。
- 規約チェック成功（Python 179件）、scripts/make-app.sh成功、git diff --check成功。元のGUI症状は最新アプリで保守者が再確認し、受信なし・ありの編集取消と非編集中の受信取消がすべて成功（2026-11-10）。今回のコードのCIは未実施。
- ログは /tmp/folzio-tak88-rename-fix/ のred-tests.log、green-tests.log、build.log、tests.log、check-all.log、make-app.log。

## Deviations from Assessment

なし。別ファイルの小さなNSMenuの型を追加する選択肢を使い、名前編集や受信処理自体には変更を加えていない。before/after_bug_fixの登録hookはなし。

## Follow-ups

保守者が最新の.build/Folzio.appへ起動し直し、3ペインの表示、受信なし・ありの両方の編集中の⌘.と、非編集中の受信取消の3項目すべてを成功と確認した。今回の修正のCIとT031の残る確認を進め、Phase 4へ進まない。直前a3e9065のCI（通常1,145件成功、性能5件超過）を今回のCIと混同しない。
