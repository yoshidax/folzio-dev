# Bug Assessment: Command付きドラッグのコピー許可

- **Slug**: command-drag-mask
- **Created**: 2026-11-10
- **Source**: pasted text / T031実機確認・確認スクリプト
- **Issue**: TAK-88
- **Verdict**: valid（期待値の不一致。実装修正ではなく仕様の明確化）
- **Severity**: low

## Report

SafariのCommand付きドロップは「＋も出ない。保存もできない（キャンセルされる）」と保守者が報告。Chromeも＋表示なし・保存なし。Optionでは両ブラウザとも＋表示・保存が成功した。2026-11-10、保守者が本IDと「ドラッグ元がその状態でコピーを許可する場合だけコピーし、許可がなければ受け付けない」仕様変更を承認した。

## Symptom

US79-AS6の無条件の期待値ではCommandでもコピーできるはずだが、実機では拒否される。保存先08・10は空で、元の画像や個人ファイルを変更したという事実はない。

## 仕様との照合

- specs/product/file-operations.mdのFR-346・FR-347は既存のfile URLの操作と確認を規定する。既存のfile URLの規則は変えない。
- 実装中TAK-88のUS77-AS6は修飾キーによらずコピーを期待する一方、FR-356はドラッグ元がコピーを許可しなければ宛先を有効にしないと規定する。
- 判定: 修飾キーによって変わる現在のコピー許可を期待値へ明示する必要がある。既存実装はコピー許可を要求しているため、bug-fixへは進まず、承認済みの仕様の明確化として現在のTAK-88を更新する。productの反映はT041まで行わない。

## Reproduction and Evidence

- macOS 26.6.2（25G83）。Safari・Chromeの既知のPNG188 bytesを使用。
- 07 / Safari Option、09 / Chrome Option: 保守者が＋表示と保存を確認。画像のSHA-256は732710219cabbdf1ed6b847716f1f177da2fd08854cec8a3515c654ad68c23edと一致。quarantineも各ブラウザと一致。
- 08 / Safari Command、10 / Chrome Command: 保守者が＋表示なし・保存なしを確認。両フォルダは空。
- 同じCommand操作を確認スクリプトへ渡すと、SafariはsourceOperationMask=0（2026-11-10 16:04:11 JST）、Chromeは4 generic（16:06:11 JST）。どちらもcopyを含まない。提供型には画像データがあり、単にURLだけだったわけではない。
- 固定したログ: /tmp/folzio-tak88-command-mask/evidence.log。

## Suspected Code Paths

- Sources/FolzioApp/Shared/ExternalImageDrag.swift: operation / accept — copy許可を含まなければ受け付けない。
- specs/TAK-88-browser-image-import/spec.md: US79-AS6 / FR-356 — 現在の修飾キーでの許可という条件が不足。
- 同ディレクトリのquickstart.md・contracts/browser-image-import.md・research.md — 期待値と測定条件の明確化が必要。

## Root Cause

実測と[AppleのNSDraggingInfoの説明](https://developer.apple.com/documentation/appkit/nsdragginginfo/draggingsourceoperationmask)は、修飾キーでソースの許可操作が絞られることと一致する。Safariの0は許可された操作がなく、Chromeのgenericもcopyの許可ではない。Folzioはコピー必須の規則で拒否している。⌘.による受信取消のキー処理はこの操作で呼ばれず、廃止して解消する問題ではない。

## Proposed Remediation

承認済み: 現在の修飾キー状態でコピーが許可されるときだけコピーとして示し保存する。許可されない場合は宛先を有効にせず、保存しない。US79-AS6・FR-356と関連の契約・確認手順へ反映し、測定結果・保守者の承認を記録する。アプリのコード・⌘.・新しい依存は変更しない。

対象: spec.md、quickstart.md、contracts/browser-image-import.md、research.md、checklists/validation.md。現在の実装はbcdd40aのCIで通常1,155件成功、性能4件超過として別途記録済み。変更前後でSources/Testsの差分がないことも確認する。

## Risks and Considerations

- 無条件のCommandコピーという受け入れ条件を狭めるため、実装の修正と見せかけず保守者の仕様変更の承認を得た。
- マスクがcopyを含むドラッグ元ならCommand付きでもコピーする。すべてのCommandドラッグを一律に拒否する変更ではない。
- 許可のないコピーやgenericでの代替を強制しない。
- 現在進行中のfeatureの明確化であり、凍結したfeatureやproductは変更しない。Phase 4へ進まない。

## Open Questions

なし。IDと仕様変更は「このIDと仕様変更で進める」と承認済み。before/after_bug_assessの登録hookはなし。
