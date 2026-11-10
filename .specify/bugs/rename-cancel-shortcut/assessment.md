# Bug Assessment: 名前編集中の⌘.が編集を取り消さない

- **Slug**: rename-cancel-shortcut
- **Created**: 2026-11-10
- **Source**: pasted text / TAK-88 T031の保守者によるGUI確認
- **Issue**: TAK-88
- **Verdict**: valid
- **Severity**: low

## Report

保守者: 「⌘.で名前の編集は取り消されませんでした。」追加確認では「受信は続き、『両方残す』で2件保存できた」。2026-11-10にこのIDと「編集中の⌘.を既存の編集取消へ渡し、受信は継続する」方針を承認済み。

## Symptom

遅延する画像の書き出しを待つ間、既存ファイルの名前の編集中に⌘.を押しても編集が取り消されない。受信を誤って取り消す症状はなく、同名保存の「両方残す」も成功している。

## 仕様との照合

- 正本のspecs/product/contracts/keyboard-and-menus.mdはFR-019として名前の編集・Returnで確定・Escで取消を規定する。product本文は今回変更しない。
- 実装中のTAK-88のFR-363は、名前の編集欄・シート・ダイアログの⌘.をそちらの取消に使い、受信を取り消さないと規定する。quickstartの「名前の変更中に⌘.」も編集取消・受信継続を期待する。
- 判定: 実装がTAK-88の承認済み仕様に反する。仕様変更ではなくfixへ進む。Phase 4へは進まない。

## Reproduction

1. /tmp/folzio-tak88-phase3/delayed-provider.swiftを保守者が起動する。
2. cat.png（中身はJPEG）を既存cat.jpgがあるTAK88-concurrent-Aへドラッグする。
3. 20秒の待ち時間に既存cat.jpgを名前の変更で編集中にし、⌘.を押す。
4. 編集が終わらない。Escでは終了でき、受信の後「両方残す」でcat.jpgとcat 2.jpgが保存される。両方719 bytesのimage/jpegであることを読み取り確認した。

## Suspected Code Paths

- Sources/FolzioApp/App/MainMenu.swift: install — ⌘.はImportSessionManagerを明示的なtargetとするメニュー項目。
- Sources/FolzioApp/Operations/ImportSession.swift: canCancelFromMenu / validateMenuItem — テキスト編集中は受信取消を無効化するだけで、編集取消へ転送しない。
- Sources/FolzioApp/FileList/ListModeView.swift: control(_:textView:doCommandBy:) — cancelOperationを受ければ既存の名前編集を取り消せる。
- Sources/FolzioApp/FileList/ThumbnailModeView.swift: 同上 — 同じ編集取消の入口がある。

## Root Cause Hypothesis

確度は中。⌘.を明示targetのメニューで予約したことで、編集中の無効化だけでは既存のcancelOperationコマンドに届いていない。AppKitのメニューによるキー処理と実フィールドエディタを使うテストで確認する。受信の状態の判定自体は正しく、現時点で受信データや同名保存の修正は不要。

## Proposed Remediation

**Preferred**: メインメニューのキー処理で、修飾キーがCommandのみのピリオドかつテキスト編集中の場合を既存の編集取消コマンドへ渡す。受信の取消は呼ばない。ほかのキー、編集していない時の最新受信の取消、モーダル・シート側の標準処理は維持する。必要な範囲でメニューの小さな型を追加し、状態の取得を差し替えて実際のメニューとフィールドエディタで確認する。

**Files likely to change**:
- Sources/FolzioApp/App/MainMenu.swift
- 必要な場合のみSources/FolzioApp/App/内のメニューキー処理用ファイル
- Tests/FolzioAppTests/のメニューキー処理テスト
- Tests/FolzioAppTests/ThumbnailRenameTests.swift（既存の編集取消との接続を確認する場合）
- .specify/bugs/rename-cancel-shortcut/{fix,test}.md
- specs/TAK-88-browser-image-import/checklists/validation.md（T031の結果追記）

**Tests to add or update**:
- 実際のフィールドエディタで⌘.がcancelOperationへ届き、名前が確定されない。
- 無効な受信取消項目がある時と受信がない時も編集取消が働く。
- 編集中は受信取消のtargetを呼ばない。非編集中はメニューの既存targetを呼ぶ。
- Control/Option/Shiftを加えたキーや別のキーを横取りしない。
- シート・モーダルの処理を横取りしない。

## Risks & Considerations

- メインメニューのキー処理を扱うため、検索や他のテキスト編集、⌃⌘.のサムネイルサイズ変更、通常の⌘.に影響させない。
- UIのことなのでCoreにはAppKitを持ち込まない。ファイル操作やデコードは追加しない。
- アプリの起動と元の編集症状のGUI再確認は保守者が行う。未確認の間はtest.mdをpartialにする。
- 指定のclaude/clever-knuth-udimb8を使う。masterへの変更や新しいバグブランチは作らない。

## Open Questions

なし。元の症状と受信継続・保存の結果は保守者に確認済み。具体的なAppKitの配信は回帰テストで検証する。
