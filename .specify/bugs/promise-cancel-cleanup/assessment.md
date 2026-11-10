# Bug Assessment: 受け取りを取り消すと写真アプリに書き出しエラーが出る

- **Slug**: promise-cancel-cleanup
- **Created**: 2026-11-10
- **Source**: pasted text / スクリーンショット / TAK-88 T031
- **Verdict**: valid
- **Severity**: medium
- **Issue**: TAK-88

## Report

保守者は写真アプリからのMOV受信を約1分後にFolzioの受け取りパネルの「取り消す」で取り消し、書き出し結果のエラー画面が出たと報告した。最初はクラッシュと表現したが、追加確認で「アプリは終了せず、エラー画面が出た」と回答。Folzioと写真アプリのプロセスは両方実行中で、新しい両アプリのクラッシュレポートも見つからなかった。

スクショは `IMG_1134.MOV` について、UUIDのフォルダに `received` を保存するアクセス権がないと表示する。画面の「書き出し結果」「書き出し完了（エラーあり）」はFolzioのエラー表示の文言・構成と異なり、写真アプリ側の書き出し結果と考えられる。

## Symptom

Folzioで取り消した受信について、写真アプリの書き出しがまだ動いている間に受け取り用フォルダが消え、写真アプリ側で保存先へのアクセスエラーが表示される。Folzioの取り消しは保存を止めて静かに終える必要がある。

## 仕様との照合

- 現行product `specs/product/file-operations.md` FR-347・FR-026は操作結果・失敗の表示を扱う。新しい受信の取り消しは進行中のTAK-88のUS77-AS9・FR-363、後片付けはFR-350・FR-355・FR-361で定める。
- SDKのNSFilePromiseReceiverは、書き出し元の処理が完了してからreaderを呼び、書き出しの失敗・取り消しでもエラー付きでreaderを呼ぶ。受信を要求するメソッドはvoidを返し、直接のcancelメソッドは公開ヘッダーにない。
- **判定: 実装が仕様の取り消し・遅延結果の扱いに反する。** 受け取り先の削除は外部の書き出しの終了に合わせて行い、取り消し時に宛先へ保存しないことと、後で一時領域・記録を掃除することを両立させる。期限・容量の判断は既存のCoreを使う。仕様の選択規則を変える問題ではない。
- 指定ブランチ `claude/clever-knuth-udimb8` のTAK-88を継続する。既存の未コミットのphotos-video-thumbnailの修正は保持し、Phase 4へ進まない。

## Reproduction

1. 写真アプリから長めのMOVをFolzioへドラッグする。
2. Folzioの受け取りパネルが表示され、書き出しが終わる前に「取り消す」を押す。
3. 保守者の1回の観測では写真アプリ側の書き出し結果にアクセス権エラーが表示された。アプリ自体の終了ではない。

スクショのUUID `92ABCE00-2AFC-4C60-A724-060F0F3A60C6` の一時領域は調査時に存在せず、現在の未掃除の記録は別の待機用2組だけだった。動画の元データ・保存先の実ファイルは今回の証拠として未採取。

## Suspected Code Paths

- `Sources/FolzioApp/Operations/ImportSession.swift` `cancel` → `finish` → `cleanup`: 受信元が未完了でも一時領域を直ちに削除する。
- 同ファイル `makeImportPromiseReader`: 取り消し後の最初の通知でも一時領域を削除するため、同じドラッグの他のwriterがまだ動いている場合に衝突する。
- 同ファイルの受信クロージャはsessionをweakで保持し、取り消しでsessionsから外すとreceiverの保持も終わり得る。
- `ImportStaging.remove`: receivedとcheckedを含むルート全体を再帰的に削除する。

## Root Cause Hypothesis

**Confidence: high（早期削除）/ medium（外部エラーの直接原因）**。Folzioの取り消しは自分の状態と保存だけを止め、写真アプリのwriterを停止するAPIは呼んでいない。その直後にwriterの宛先を消すため、遅いwriterが保存先を作り直す際にエラーとなる説明が、スクショと消えたUUIDに整合する。写真アプリの内部処理そのものは観測していないため、その部分は推定として区別する。

## Proposed Remediation

**Preferred（保守者承認済み）**:

1. 取り消しではUIの行を消し、確認・保存を始めない。未完了のwriterがあるsession・receiver・受け取り先は別に保持する。
2. readerは取り消し後も完了を報告し、画像の複製・検査は行わない。各receiverの全ファイルの完了を数え、重複通知を二重に数えない。共通宛先を最後のwriterの終了前に消さない。
3. 保持中も既存Coreの期限・容量を監視する。正常な遅延完了で掃除し、通知が来ない場合や容量超過にも後片付けの経路を持つ。終了で未完了のwriterが残る場合は記録を保持し、起動時の掃除へ渡す。
4. 完了済みの受信、画像データだけの処理、検査後の取り消しの掃除を遅らせない。
5. 受信待ち・reader内複製・検査・保存の経過時間をローカルログで確認できるようにする。ファイル名・宛先・元URL・画像内容はログへ含めず、session IDと段階・件数・時間だけを使う。

**Files likely to change**:
- `Sources/FolzioApp/Operations/ImportSession.swift`
- 受信結果とローカル診断の小さなApp型（必要に応じて同じOperationsディレクトリに分離）
- `Tests/FolzioAppTests/ImportSessionTests.swift`
- 必要な純粋な判断が新たに生じる場合だけFolzioCoreと対応テスト
- `.specify/bugs/promise-cancel-cleanup/` の記録、T031のvalidationの結果とtasksのチェック

**Tests to add or update**:
- 取消直後もwriterの受け取り先が存在し、writerは作り直さずに書き込める。
- 遅延readerで保存・確認せず、複製も作らず、最後の通知後にフォルダと記録が消える。
- 2つのreceiver、単一receiverの複数ファイル、重複通知で早く消えない。
- 取消後もreceiverの保持が続き、終了後に解放される。
- 通知がない場合の期限、保持中の容量超過、同時操作の独立、正常終了・起動時掃除を確かめる。
- 従来の成功・部分失敗・宛先消失・確認の直列化・ショートカット・未使用プールの掃除が変わらない。

## Performance Observation

保守者は同じ比較について、約40秒の動画が432 MBあり、写真アプリ→Finderで書き出しに約23秒、写真アプリ→Folzioも同程度だったと補足した。Finder側は処理中の状態が分からず、Folzioは進捗を示すためUXは良いとの評価。初回の約1分の待ちと、この約23秒の比較を区別する。異常な速度劣化が再現したとは現時点で断定しない。区間の計測で内訳を確かめる。

## Risks & Considerations

- UIで取り消しても、外部アプリの書き出し自体が直ちに停止する保証はない。宛先への保存は必ず防ぐ。
- 書き出し中の一時領域を保持する間も容量と期限を監視し、任意の場所を消さない。既存の所有形状・記録の検証を使う。
- 期限・容量を超えるwriterの保護と、取消直後の正常なwriterの後片付けを区別する。
- 画像・動画の検査、安全な名前、quarantine、Photosの約束優先、file URLの既存経路は変更しない。
- GUIの再現で写真アプリ側のエラーが消えたことを確かめるまでは検証結果をpartialにする。

## References

- ローカルmacOS SDK: `AppKit.framework/Headers/NSFilePromiseReceiver.h`（readerの契約と公開APIを確認）。
- [Apple: NSFilePromiseProviderDelegate](https://developer.apple.com/documentation/appkit/nsfilepromiseproviderdelegate)（書き出し側の役割）。
- [Apple: ファイルの約束を使うテーブルビューのドラッグ](https://developer.apple.com/documentation/appkit/supporting-table-view-drag-and-drop-through-file-promises)（写真アプリからの受信例）。

## Approval and Open Questions

2026-11-10、保守者がID `promise-cancel-cleanup` と上記の取り消し時の保持・後片付け・時間記録の修正を「1.で進めるで良いです」と承認。速度の比較先は写真アプリ→Finderとの補足を受領。修正後の同じ動画での取消と写真アプリのエラーの有無は手動確認待ち。
