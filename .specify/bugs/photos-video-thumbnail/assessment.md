# Bug Assessment: 写真アプリの動画がJPEGとして保存される

- **Slug**: photos-video-thumbnail
- **Created**: 2026-11-10
- **Source**: pasted text / TAK-88 のT031手動確認
- **Verdict**: valid
- **Severity**: high
- **Issue**: TAK-88

## Report

保守者の報告:

> mov、mp4はサムネイル画像のjpegとして保存された。
> HEIC、JPEGはJPEGとして保存された。

## Symptom

写真アプリからMOV・MP4をFolzioへドラッグすると、動画の代わりにJPEGが保存される。US79-AS8は動画の実体を保存することを要求する。HEICからJPEGへの変化はT007の形式保持を保証しない契約の範囲内であり、この問題の失敗件数には含めない。

## 仕様との照合

- 現行productの `specs/product/file-operations.md` FR-346・FR-347はfile URLによる既存の移動・コピーを定め、A-204はブラウザ画像取り込みを範囲外とする。今回の機能は未反映のTAK-88で定める。
- TAK-88のUS77-AS8・FR-362はMOV・MP4の動画保存を要求する。
- 一方、T007確定後のEC-241はfile URLを無条件に最優先にし、FR-350はfile URLがないときだけ約束を使う。この選択規則どおりに動いても、写真アプリのfile URLがJPEGを指す場合に動画を保存できない。
- **判定: 仕様の選択規則が動画保存の要求と衝突する。** 単なる実装バグのfixへは進まず、同じTAK-88の仕様の明確化として扱う。指定ブランチ `claude/clever-knuth-udimb8` と進行中のfeatureを継続し、productの反映はT041まで行わない。

## Reproduction

1. `6c139d0` に対して作成した `.build/Folzio.app` を起動する。
2. 写真アプリでMOVまたはMP4を選び、Folzioのフォルダへドラッグする。
3. 保守者の報告では、保存された項目は動画ではなくJPEG。

実行中のアプリのパスは `/Users/igachan/projects/folzio/.build/Folzio.app/Contents/MacOS/Folzio` と読み取り確認済み。今回のドラッグのfile URLの文字列・実体と動画出力のバイト比較は未採取。T006の型の観測とコードの選択規則で原因を絞り、修正後に同じ2形式で再確認する。

## Suspected Code Paths

- `Sources/FolzioApp/Shared/ExternalDrag.swift` `urls`・`operation`・`dropOperation`: file URLを先に読むため、約束の受信経路へ進まない。
- `Sources/FolzioApp/Shared/ExternalImageDrag.swift` `payload(in:)`: file URL型を見つけると直ちに `.fileURLs` を返す。
- `Sources/FolzioCore/Operations/ImportPayloadPolicy.swift` `select`: hasFileURLsがtrueなら約束の種類を調べず `.fileURLs` を返す。
- `Sources/FolzioApp/Operations/ImportSession.swift`: 選択された約束を受け取る仕組みは既存。優先順位修正後は同じ受信・検査・保存処理を使う。

## Root Cause Hypothesis

**Confidence: high（選択経路）/ medium（今回のfile URLの実体）**。T006では写真MOVの提供型にpublic.file-url・public.jpegがあり、同時に約束のfileTypesはcom.apple.quicktime-movieだった。MP4も同様にpublic.mpeg-4の約束を持ち、診断版で実際にMOV・MP4が書き出された。現在の無条件のfile URL優先により、この動画の約束を使う前にfile URLの項目を保存する。JPEGが保存されたという手動結果と整合する。今回のfile URL自体は未採取のため、縮小画像を指すことは推定として区別する。

## Proposed Remediation

**Preferred（保守者承認済み）**: 写真アプリのドラッグで、受け取り可能な書き出し約束がある場合はfile URLよりその約束を優先する。Appは写真アプリの項目を示す型と約束の宣言型を渡し、Coreで選ぶ。ホバーで画像データやファイルを読まず、通し番号ごとのキャッシュを共有する。file URL経路に入る前に同じ判断を使い、全ペインで同じ選択になるようにする。

選んだ約束が失敗・期限超過・キャンセルとなっても、JPEGやfile URLに切り替えない。Finderなど写真アプリ以外のfile URL、内部ドラッグ、一般クリップボードの選択規則は維持する。一般クリップボードは約束を使わず、file URL→画像データのまま。

**Files likely to change**:
- `Sources/FolzioCore/Operations/ImportPayloadPolicy.swift`
- `Sources/FolzioApp/Shared/ExternalImageDrag.swift`
- `Sources/FolzioApp/Shared/ExternalDrag.swift`
- 対応するCore/Appの回帰テスト
- TAK-88のspec・plan・research・data-model・contract・quickstart・tasks・validationの今回の決定に関わる箇所

**Tests to add or update**:
- 写真アプリの型＋JPEGのfile URL＋MOV/MP4の約束で約束が選ばれる。
- 写真のJPEG/HEICも受け取り可能な約束があれば同じ規則。
- 写真アプリの型がないFinderのfile URLは従来どおり最優先。
- 写真アプリでも約束がない場合はfile URL、画像・動画以外の約束だけなら既存のfile URL経路を維持する。
- 約束を選んだ後の失敗で、確認・保存にJPEGの経路を使わない。
- ホバーで画像データやFSを読まず、既存の登録型・copyマスク・3つのビューの経路を維持する。

## Risks & Considerations

- 写真アプリの型は識別の手掛かりであり信用の境界にしない。約束の中身・構造・大きさ・名前は今と同じCoreの検査を必ず通す。
- 写真アプリのHEICの書き出しがJPEGになる場合がある。元のHEIC形式を保持する保証は追加しない。
- 受信先が未準備なら約束は拒否し、縮小画像へ切り替えない。
- 今回のCIは旧実装6c139d0に対するもの。修正後のbuild・全通常テスト・規約チェック・起動と動画の手動再確認・CIが必要。

## Approval and Next Step

2026-11-10、記録ID `photos-video-thumbnail` と上記の写真アプリ限定の優先規則変更に対し、保守者が「このIDと変更案で進める」と承認。診断を記録し、TAK-88の追加明確化としてspec/計画へ反映後に回帰テストと実装を進める。Phase 4には進まない。

## Open Questions

- 修正後にPhotosのMOV・MP4が動画として保存され、再生できるかは手動再確認待ち。
