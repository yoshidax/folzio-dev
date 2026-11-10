# Bug Assessment: ブラウザの同名ドロップで衝突確認が表示されない

- **Slug**: drop-conflict-parent
- **Created**: 2026-11-10
- **Source**: pasted text / TAK-88 T031 GUI
- **Issue**: TAK-88
- **Verdict**: valid
- **Severity**: medium

## Report

保守者はSafari・Chromeの各6か所へのドロップ操作は問題ないと報告したが、同名時の「置き換える・両方残す・中止」の確認が表示されなくなったと報告。「表示される」は「表示されない」への訂正を受領。2026-11-10に本IDと「受信開始時のドロップ先ウインドウを確認・衝突ダイアログへ渡す」方針を承認した。

## Symptom

ブラウザから同名画像をドロップした後、衝突の選択肢が出ず、利用者が保存を選べない。確認用の6つの宛先にはsample.pngが1件ずつある。2回目の保存が実行されたことや上書きされたことは確認していない。

## 仕様との照合

- specs/product/file-operations.mdのFR-025・US4-AS8は、コピー・移動の同名時は確認設定に関わらず「置き換える / 両方残す / 中止」を選ばせる。FR-347は外部からの移動・コピーにもこの規則を適用する。
- 実装中のTAK-88のUS77-AS4とFR-347の接続も同じ規則。EC-246は複数受信の確認・衝突を直列化する。
- 判定: 実装が承認済み仕様に反するためfixへ進む。仕様の変更ではなく、product本文は変更しない。

## Reproduction

1. Folzioの専用宛先へSafari・Chromeの確認ページのPNGをドロップする。
2. 同じ名前の画像をもう一度ドロップする。
3. 衝突確認が表示されないと保守者が報告した。
4. 保存先はDesktop/pics/TAK88-routes内の6フォルダ。各sample.pngは188 bytes・image/png。

## Suspected Code Paths

- Sources/FolzioApp/Operations/FileOperationCoordinator.swift: importDrop — NSDraggingInfoの宛先ウインドウを保存せず、非同期処理へURLだけを渡す。
- 同ファイルのsaveReceived — 確認と衝突の呼び出しに親ウインドウを渡さない。
- Sources/FolzioApp/Operations/ConflictPrompt.swift: resolve — NSApp.keyWindow / mainWindowがnilなら、確認せずabortを返す。
- Sources/FolzioApp/Operations/ConfirmationPresenter.swift: present — 親がなく省略可能な操作なら確認を出さずtrueを返す。

## Root Cause Hypothesis

確度は中。ブラウザからのドロップ後にFolzioがキー・メインウインドウを持たない状態になると、受信後の非同期処理が宛先のウインドウを復元できず、衝突確認を省略して中止する。名前編集や受信取消の⌘.とは別の確認の親の選択経路である。キー・メインウインドウを使えない状態をテストで固定して検証する。

## Proposed Remediation

**Preferred**: importDropでdraggingDestinationWindowを得て、非同期受信の保存時まで弱く保持し、確認と衝突へ明示的に渡す。指定された親をグローバルなキーウインドウより優先し、既存のsheet待ちにもその親を含める。元の親が失われた場合は別のウインドウへ確認を付けず、保存を取り消す。受信中の非アクティブな進捗パネルや、⌘.のキー処理は変更しない。通常の既存呼び出しは既定引数で維持する。

**Files likely to change**:
- Sources/FolzioApp/Operations/FileOperationCoordinator.swift
- Sources/FolzioApp/Operations/ConflictPrompt.swift
- Sources/FolzioApp/Operations/ConfirmationPresenter.swift
- Tests/FolzioAppTests/の親ウインドウと実保存結果の回帰テスト
- .specify/bugs/drop-conflict-parent/{fix,test}.md
- specs/TAK-88-browser-image-import/checklists/validation.md（T031の結果）

**Tests to add or update**:
- キー・メインウインドウが取れなくても、指定の親へ実際の確認・衝突NSAlertを渡す。
- 確認設定の有効・無効、同一・別ボリューム方針で、replace / keepBoth / abortの選択と保存データが一致する。
- 無関係なフォールバックのウインドウより指定の親を優先する。
- 保存前の確認の取消で既存・受信ファイルを変更せず、衝突を始めない。
- 実機でブラウザを前面にしたまま同名ドロップし、3つの衝突選択を確認する。

## Risks & Considerations

- 親の指定以外の転送処理やCoreの衝突規則を変えない。NSAlertの構築・表示はMainActorで、ファイル操作は既存の背景処理を使う。
- 複数の受信は既存のImportConfirmationQueueで直列化し、指定した親に既にシートがある場合も待つ。
- テストではシートの表示部分を差し替え、アラートと指定の親・実ファイルの保存結果を検証する。GUIの起動・元の症状の確認は保守者が行う。
- 作業ブランチclaude/clever-knuth-udimb8を維持。masterや依存ツールは変更しない。

## Maintainer Constraint

「次の修正で直らなければ対応の方針を変更したい」「⌘.のショートカットは廃止しても良い」を受領。今回の方針を一度実装して実機で検証し、直らなければ同じ方針の修正を重ねず、⌘.の廃止を含めて方針を見直す。承認済み仕様の変更が必要になる場合は、その変更点を明示する。

## Open Questions

なし。実機での原因の確定は修正後の再現確認で行う。上書きやデータ破損が発生したとは断定しない。
