# Tasks: TAK-88 ブラウザの画像をフォルダへ保存する

**Input**: `specs/TAK-88-browser-image-import/` の設計文書

**Prerequisites**: spec.md / plan.md / research.md / data-model.md / contracts/browser-image-import.md / quickstart.md

**Tests**: 憲章 原則 IV に従い、Core の判断（受け取るデータの選び方・名前・中身の判別・構造・大きさ・記録・期限・状態）と、App のペーストボードの判定・
メニューの有効・無効・受け取りの流れに自動テストを付ける。ブラウザ・写真アプリとの受け渡しと GUI は、保守者が macOS で確かめる（`[MANUAL]`）。
Cloud では `swift` を実行できないので、build とテストは macOS CI で確かめる（`docs_private/cloud-agent-workflow.md` の 4 章・5 章）。

**注意**: `scripts/check-no-network.sh` は `Sources` の中の語 `http` と `https://` を、コメントを含めて拒否する。URL の例は `Tests` にだけ書く（R6）。

**ストーリーの対応**: [US1] = spec の US77（ドラッグ）、[US2] = spec の US78（ペースト）。

**タスクの番号**: 全 43 件。分析 C1 の修正で T042・T043 を Phase 2 に加えた。既存の番号は変えず、番号の大小ではなく Phase と依存関係の順に実行する。

## Phase 0: 設計

- [x] T001 `spec.md` と `checklists/requirements.md` を作り、TAK-88 と保守者の決定（Clarifications）を記録する
- [x] T002 `plan.md`・`research.md`・`data-model.md`・`contracts/browser-image-import.md`・`quickstart.md` に設計と検証方法を記録する
- [x] T003 保守者の設計レビューと実装の承認を得る。`scripts/check-no-network.sh` の例外（R6）の承認も得る。承認がなければ T004 以降に進まない
  （2026-11-09、このチャットで設計と R6 の例外を示した確認に対し、保守者が「進めてください」と承認）

## Phase 1: Setup（先に行う確認。R1）

**Purpose**: ブラウザ・写真アプリが渡すものを確かめ、結果で spec・plan を確定する。確定するまで Phase 2 以降を始めない

- [x] T004 `scripts/dev/pasteboard-probe.swift` を作る（開発用。コメントは日本語。公開用リポジトリへ書き出さないことを `scripts/dev/export-public.py` の除外で確かめる）。
  `swift scripts/dev/pasteboard-probe.swift` で開くウインドウが、(1) ドロップされたドラッグの型、`NSFilePromiseReceiver` の `fileTypes`・`fileNames`、
  ドラッグ元のマスク、約束を一時フォルダへ書き出させた結果（名前・大きさ・かかった時間・`reader` が呼ばれた回数）、
  (2) ボタンで一般のペーストボードの型と大きさ、一般のペーストボードから `NSFilePromiseReceiver` を読み出して書き出させた結果、
  (3) 選んだ型の `data(forType:)` を UI スレッドで読むのにかかった時間、を表示する。
  (4) 中身が JPEG で名前が `cat.png` のファイルと、名前が `logo.svg` で中身が PNG のファイルを約束で渡すドラッグ元のビューを持つ（R4 の確認用）
- [x] T005 `scripts/dev/check-all.sh` を実行し、T004 をコミットして作業ブランチへ push する
  （`10590ed`・`ff748f5`。macOS CI に Swift 6 でのコンパイルと確認用画像の自己検査も追加。GUI と実アプリの確認は T006 で行う）
- [x] T006 [MANUAL] 保守者に、quickstart.md の「先に行う確認」を実行してもらい、結果を `specs/TAK-88-browser-image-import/checklists/validation.md` に記録する
  （Safari・Chrome の画像のドラッグとコピー、写真アプリの写真・動画のドラッグとコピー、200 MB 程度の TIFF の読み出しの時間）
  （2026-11-09、保守者が各ケースと追加3件を実施。失敗・再試行・診断版の成功も validation.md に記録。
  測定完了であり、製品の動作保証・SIGBUSの原因解消を意味しない。T007の変更案は同日の「OKです。」で承認済み）
- [x] T007 T006 の結果で spec・plan・research・contracts を確定する。特に次を決め、変えた点を保守者に示して確かめる
  - 登録する画像の型（R2・R5）と、約束が示す種類の実際の値（FR-348）
  - 一般のペーストボードの約束を使えるか（R11）。使えなければ EC-241・US78-AS8・FR-354 を改める
  - 画像データの読み出しを UI スレッドで行うか（0.2 秒を超えれば R5 の代わりの方法）
  - ブラウザのマスクに `.copy` があるか（FR-356）
  （2026-11-09、保守者がvalidation.mdの変更案に「OKです。」と承認。spec・plan・research・contractsを確定し、
  data-model・quickstart・後続タスクも整合させた。Phase 2以降は未着手）

## Phase 2: Foundational（Core の判断と検査。全ストーリーの前提）

**Purpose**: `FolzioCore`（AppKit を import しない）に、細工された入力を拒む判断を置き、テストで網羅する

- [x] T008 [P] `Tests/FolzioCoreTests/ImportedFileNameTests.swift` を作り、先に失敗させる（R6・FR-352・FR-357・FR-360・EC-243）。
  `isAcceptable` は「空でない、`/`・`:` を含まない、`.` で始まらない、`Cc`・`Cf` の文字を含まない、UTF-8 で 200 バイト以下」を、
  境界（200 バイトと 201 バイト、U+202E・U+2066・U+200E・NUL・改行、`..`、全角の名前）で確かめる。
  `nameFromURL` は `https://example.com/a/cat.jpg?w=1` → `cat.png`、`%2F`・`%00` を含む名前、`data:`・`blob:`・`file:`・`ftp:` の URL、
  パスのない URL、最後の要素が `..` の URL を確かめる。`datedName` はタイムゾーンとロケール（`ja_JP`・`ar`）に依らず ASCII の数字になること。
  `corrected` は spec の FR-360 の例（`cat.png`・`photo.jpg_large`・`download`・`photo.jpg.command`・`cat.JPG`・`.jpeg`・`.jfif`・`.jpe`）と、動画（`.mov`・`.mp4`）。
  `uniqueNames` は同じ名前・大文字小文字だけ違う名前に、既存の `uniqueName(for:existingNames:)` と同じ連番が付くこと
- [x] T009 `Sources/FolzioCore/Operations/ImportedFileName.swift` を実装して T008 を通す。`scripts/check-no-network.sh` に、
  このファイルの `"http"` と `"https"` のリテラルだけを許す例外を、`AboutInfo.swift` と同じ形で加える（T003 で承認されたとき。R6）
- [x] T010 [P] `Tests/FolzioCoreTests/ImportPayloadPolicyTests.swift` を作り、先に失敗させる（R2・R5・R11・FR-348・FR-351・EC-241）。
  file URL があるとき常に `.fileURLs`、約束の種類（画像・動画・不明・`public.data`・空・PDF だけ・PDF と画像）、画像データの型の選び方（PNG → JPEG → TIFF。項目にない合成TIFFと未観測の直接HEICは対象にしない）、
  どれもないとき `nil` を確かめる
- [x] T011 `Sources/FolzioCore/Operations/ImportPayloadPolicy.swift` を実装して T010 を通す（data-model.md の `ImportPayloadPolicy`・`ExpectedKind`）
- [x] T012 [P] `Tests/FolzioCoreTests/ImportInspectorTests.swift` を作り、先に失敗させる（R4・FR-357・FR-359・FR-362・SC-190・SC-196）。
  テストの中で作るファイルで、PNG・JPEG・GIF・TIFF（ImageIO で書き出す）、SVG・PDF の中身、画像でない中身（スクリプトの文字列）、
  `ftyp` が `qt  `・`isom`・`mp42` の先頭、`moov` で始まる QuickTime、AVI の先頭（`RIFF`）、シンボリックリンク、フォルダ、`.app` の名前のフォルダ、
  共通の受け取り用フォルダの外を指すリンク、256 MB を超える画像の大きさ（`ftruncate` で疎なファイルを作る）、4 GB を超える動画の大きさを確かめる。
  複製を作った後に元のファイルを書き換えても、検査と保存の対象（複製）が変わらないこと、元のファイルの拡張属性（テストで付けた
  `com.apple.quarantine`）が複製に残ることを確かめる
- [x] T013 `Sources/FolzioCore/Operations/ImportInspector.swift` を実装して T012 を通す。`lstat`・`isAliasFile`・`realpath` による構造の検査、
  `copyfile(_:_:nil, COPYFILE_CLONE | COPYFILE_ALL)` の複製、`CGImageSourceGetType`・`CGImageSourceGetCount` と先頭 64 バイトによる判別（画像を展開せず、動画を再生しない）、
  中身の種類の上限（「画像 256 MB、動画 4 GB」）を実装する。構造確認と複製はreaderの専用キューから同期的に呼べるように分け、readerを返す前に完了する。結果は data-model.md の `ImportRejection` で返す
- [x] T014 [P] `Tests/FolzioCoreTests/ImageDataWriterTests.swift` を作り、先に失敗させる（R5・FR-351・FR-359・EC-244）。
  PNG のデータがバイト単位で同じに書かれること、TIFF（複数ページを含む）が 1 枚目だけの PNG になること、
  1 枚目が 1 億画素を超える TIFF の情報で `tooManyPixels`（画像を展開しない）、256 MB を超えるデータで `tooLarge`、壊れたデータで `notImageOrVideo` を確かめる
- [x] T015 `Sources/FolzioCore/Operations/ImageDataWriter.swift` を実装して T014 を通す（ImageIO の `CGImageSource`・`CGImageDestination`）
- [x] T016 [P] `Tests/FolzioCoreTests/ImportStagingTests.swift` と `ImportCleanupRecordTests.swift` を作り、先に失敗させる（R3・R10・FR-350・FR-361・SC-188・SC-196）。
  起動ディスクの `Folzio-Import/<UUID>` の作成、共通の受け取り用と検査用のフォルダ、宛先との同一 / 別ボリューム判定、受け取り用だけの大きさの合計、`remove()` の後に何も残らないこと、
  記録の追加と削除、起動時の掃除で、ボリュームの識別子が違う記録・名前の形が違う記録（ホームのフォルダを指す記録を含む）・30 日を過ぎた記録を消さずに外すこと、
  ボリュームがない記録を持ち越すこと、型が不正な要素を捨てることを確かめる。`UserDefaults` はテスト用のスイートを使う
- [x] T017 `Sources/FolzioCore/Operations/ImportStaging.swift` と `ImportCleanupRecord.swift` を実装して T016 を通す（キー `internal.pendingImportFolders`）
- [x] T042 [P] `Tests/FolzioCoreTests/ImportBudgetTests.swift` と `ImportReceptionStateTests.swift` を作り、先に失敗させる（R3・FR-355・FR-359・FR-363）。
  経過時間を値で渡し、画像・不明の 60 秒、動画の 600 秒の直前と期限ちょうど、画像・動画が混在する約束の期限を確かめる。
  容量は約束ごとの上限の合計と同じ値を許し、1 バイト超過で操作全体を打ち切ることを確かめる。
  正常な状態の移り変わり、画像データは `checking` から始まること、取り消し・失敗・完了の後の結果や重複した通知で状態が変わらないことを確かめる
- [x] T043 `Sources/FolzioCore/Operations/ImportBudget.swift` と `ImportReceptionState.swift` を実装して T042 を通す。
  時計・タイマー・ファイル操作・AppKit を持たず、経過時間・観測した大きさ・イベントから判断する（data-model.md・R3）。T024 はこの判断を使う
- [x] T018 [P] quarantine の印のテストを `Tests/FolzioCoreTests/ImportInspectorTests.swift` に加える（R8・FR-358・SC-191）。印のない複製に付けた印が
  `LSQuarantineAgentName` が `Folzio` で、`LSQuarantineDataURL`・`LSQuarantineOriginURL` を含まないこと、すでにある印を変えないことを確かめ、実装する
- [x] T019 `Sources/FolzioCore/Operations/OperationFailureReason.swift` に `importRejected(ImportRejection)` を加え、
  `Sources/FolzioLocalization/TextKey.swift` と `Sources/FolzioLocalization/Resources/{en,ja}.lproj/Localizable.strings` に、
  spec の「新しい文言（追加）」の表のキーを両言語で加える（R12・A-213）。既存のローカライズのテスト（`Tests/FolzioCoreTests/Localization`）を通す。
  `timedOut(seconds:)` の文言を画像・不明の 60 秒、動画の 600 秒について両言語で確かめる。条件に合わない名前は日時の名前に直し、`nameTooLong` は加えない（FR-360）
- [x] T020 `scripts/dev/check-all.sh` を実行し、Phase 2 をコミットして push する。CI（`workflow_dispatch`）で build とテストの結果を確かめる
  （ローカル: `swift build`成功、`swift test`はCore 1,078件・App 28件・性能27件の計1,133件成功。
  `check-all.sh`は179件のPython検査を含め全件成功。`scripts/make-app.sh`で起動確認用アプリを作成済み。
  保守者がこのチャットで「表示されました」と報告し、3ペインの起動スモークも成功。
  Phase 1は`3f87ee4`、Phase 2実装は`caead23`として作業ブランチへpush済み。
  [`caead23`のmacOS CI](https://github.com/yoshidax/folzio-dev/actions/runs/42619448294)も成功。
  Xcode 16.0 / Swift 6.0でbuild・確認スクリプトの自己検査・通常テスト1,106件・性能テスト27件が成功し、
  性能テストは非ブロッキングのステップ状態だけでなくジョブログ末尾で全件成功を確認した。
  この後の進捗記録コミットはtasks.mdだけの変更で、CIの対象は実装コミット`caead23`。Phase 3以降は未着手。
  ログ: `/tmp/folzio-tak88-phase2/{build.log,full-tests-2.log,check-all.log,make-app.log}`）

**Checkpoint**: Core の判断と検査がテストで確かめられた

## Phase 3: User Story 1（spec の US77）ブラウザの画像をドラッグしてフォルダへ保存する（P1）🎯 MVP

**Goal**: ブラウザの画像と写真アプリの動画を、FR-345 の宛先へドラッグして保存できる

**Independent Test**: quickstart.md の「ドラッグ」の表を、Safari・Chrome・写真アプリで確かめる

- [ ] T021 [P] [US1] `Tests/FolzioAppTests/ExternalImageDragTests.swift` を作り、先に失敗させる。3つのビューが登録する型に `.fileURL`・
  `NSFilePromiseReceiver.readableDraggedTypes`・PNG・JPEG・TIFF（T007で確定した型）が含まれること、名前付きの `NSPasteboard` に置いた画像データ・URL だけ・文字列だけ・
  PDF を示す約束で、受け取るデータの判定が `ImportPayloadPolicy` と一致すること、マスクに `.copy` がないときに操作が空になることを確かめる（R2・FR-348・FR-356）
- [ ] T022 [US1] `Sources/FolzioApp/Shared/ExternalImageDrag.swift` を作り、ドラッグの通し番号ごとに1回だけペーストボードの型を調べて `ImportPayload` を保持し、
  ホバー中は `.copy` を返す（修飾キーで変えない。約束は準備済みフォルダがある場合だけ）。ドロップ中にNSFilePromiseReceiverの配列を読み、ImportSessionの全要求を始めてから返す。画像データは各項目のPNG → JPEG → TIFFから同期取得する（R2・R3・R5）。T021を通す
- [ ] T023 [US1] `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift`（1059 行付近）・`Sources/FolzioApp/FileList/ListModeView.swift`（262 行付近）・
  `Sources/FolzioApp/FileList/ThumbnailModeView.swift`（642 行付近）の `registerForDraggedTypes` に T022 の型を加え、`validateDrop`・`acceptDrop` で
  file URL がないときに `ExternalImageDrag` へ分ける。アプリ内のドラッグと file URL の経路は変えない（R13・SC-192）
- [ ] T024 [US1] `Sources/FolzioApp/Operations/ImportSession.swift` を作り、data-model.md の状態の移り変わりのとおり、事前作成したImportStagingの同期的な確保と背景での補充（T017）、
  全約束に共通宛先でドロップ内から行うreceivePromisedFiles（readerは専用のOperationQueue）、待つ時間（画像・不明 60 秒、動画 10 分）、1 秒ごとの大きさの見張り（「約束ごとの上限の合計」）、
  readerが報告したファイルの通知中の構造確認・複製と、複製だけの背景検査（T013）、画像データの書き込み（T015）、名前の連番（T009）、最後の一時的なフォルダの削除と記録の削除を行う（R3〜R6・FR-350・FR-355・FR-359）。
  打ち切り・取り消しの後に届いた結果は捨てる。期限・容量・状態の判断は T043 の Core の型に任せる。
  実装の前に `Tests/FolzioAppTests/ImportSessionTests.swift` を作り、時計・約束の受け取り・確認を差し替えて、実時間を待たずに次を確かめる
  - 受け取り先の背景での事前作成・補充、未準備時のドロップ拒否、全要求がドロップを返す前に始まり共通の宛先を使うこと
  - readerを返す前に別名の複製が作られること、単一receiverの複数ファイル、同じreceiverの重複通知、別receiverの同じ実体パスはsourceFailedとして全体を失敗にすること
  - 正常な受け取り、画像 60 秒・動画 600 秒での打ち切り、1 秒ごとの見張りの超過、受け取り中・検査中の取り消し
  - 打ち切り・取り消しの後に届く結果は保存と確認を始めず、残った一時的なファイルを掃除する。失敗・取り消し・完了で記録が残らず、取り消しは失敗の表示を出さない
  - 待つ間・確認の間に宛先が消えた・書き込めなくなった場合、T025 とつないで失敗を表示し、掃除する（EC-245）
  - 2つの宛先への同時の受け取りで、期限・結果・一時的なフォルダが独立し、片方の取り消しが他方に影響しない。
    T025・T027・T028 とつないで、確認が1つずつ表示され、パネルは行ごとに取り消せて、⌘. は最後に始めた操作だけを取り消すことを確かめる（EC-246）
- [ ] T025 [US1] `Sources/FolzioApp/Operations/FileOperationCoordinator.swift` に `saveReceived(_:to:sameVolume:)` を加える。`.copy` の `FileOperation` で確認し、
  `transferItems`（229 行付近）を同じボリュームなら `.move`、そうでなければ `.copy` で呼ぶ。後処理はコピーと同じ（宛先だけの `onFoldersChanged`、
  `didMoveSearchItems` と履歴の削除をしない）。失敗は `presentFailures` で示し、取り消しは示さない（R7・FR-347）。
  複数の受け取りの確認モーダル・衝突のダイアログを1つずつ表示し、宛先の消失・書き込み不可を含め、T024 のテストで確かめる（EC-245・EC-246）
- [ ] T026 [US1] `Sources/FolzioApp/FileList/FileListViewController.swift` と `DirectoryTreeViewController.swift` で、`ExternalImageDrag` のドロップを
  `ImportSession` と `saveReceived` へつなぐ。宛先はドロップの位置の宛先（FR-345・FR-349）
- [ ] T027 [US1] `Sources/FolzioApp/Operations/ReceivingPanelController.swift` を作り、R9 のとおり、1つの `NSPanel`（`.nonactivatingPanel`・`becomesKeyOnlyIfNeeded`）に、
  2 秒を超えた操作の行（宛先の名前・件数・書き出し済みの件数・大きさ・段階・「取り消す」）を出す。複製と検査の間も出し、確認モーダルの直前に行を消す。
  ボタンにアクセシビリティのラベルを付ける（FR-363・憲章 原則 III）
- [ ] T028 [US1] `Sources/FolzioApp/App/MainMenu.swift` の編集メニューに「受け取りを取り消す」（キー ⌘.）を、移動ペーストの後に加える。`validateMenuItem` は、待っている操作があり、キーのウインドウにシートがなく、
  モーダルがなく、最初の応答者が `NSText` でないときだけ有効にし、最後に始めた操作を取り消す。
  `Sources/FolzioCore/Shortcuts/ShortcutCommand.swift` の `ReservedShortcutKeys.combinations` に ⌘. を加え、
  `Sources/FolzioCore/Shortcuts/ShortcutCatalog.swift` の「選択とファイル操作」に載せる（R9・FR-363・A-124（変更））。
  `Tests/FolzioCoreTests/ShortcutCatalogTests.swift` の順序と件数（46 → 47）、`Shortcuts/ShortcutAssignmentsTests.swift` の予約キー、
  `Localization/ShortcutTextTests.swift` の文言を更新する。`Tests/FolzioAppTests/ImportSessionTests.swift` に有効な条件と最後の操作を取り消すテストを加える
- [ ] T029 [US1] `Sources/FolzioApp/App/AppDelegate.swift` の起動の後に、ImportCleanupRecordの掃除を背景で行い、その完了後に2組の受け取り先を事前作成する。正常終了時は未使用の待機用も掃除する（R10・FR-361）
- [ ] T030 [US1] `scripts/dev/check-all.sh` を実行し、Phase 3 をコミットして push する。CI で build とテスト（性能テストのログの末尾を含む）の結果を確かめる
- [ ] T031 [MANUAL] [US1] 保守者に、quickstart.md の準備と「ドラッグ」の表、「安全性」の保守者の確認、起動スモーク（3 ペインの表示）を実行してもらい、
  結果を `checklists/validation.md` に記録する。「受け取りの流れと性能」で、宛先の消失・書き込み不可と同時の受け取り（EC-245・EC-246）、
  検索結果のフォルダへのドラッグ（SC-186）、入力から表示が変わり始めるまで 1 秒以内（SC-189）、変更前後のドラッグの反応も測る

**Checkpoint**: ドラッグで画像・動画を保存できる（MVP）

## Phase 4: User Story 2（spec の US78）コピーした画像をペーストしてフォルダへ保存する（P1）

**Goal**: ブラウザの「画像をコピー」と写真アプリのコピーを、⌘V・「ペースト」・「ここにペースト」で保存できる（憲章 原則 III のキーボードの手段）

**Independent Test**: quickstart.md の「ペースト」の表を確かめる

- [ ] T032 [P] [US2] `Tests/FolzioAppTests/PasteboardImportTests.swift` を作り、先に失敗させる。名前付きの `NSPasteboard` で、file URL・約束・画像データ・URL だけ・文字列だけの
  ときの `availability` と、ペースト・移動ペーストの有効・無効（「ペースト」は `none` 以外、「移動ペースト」は file URL だけ）、型の判定でデータを読まないことを確かめる。約束だけならnone、約束と画像データならimageDataになることも確かめる（R11・FR-354）
- [ ] T033 [US2] `Sources/FolzioApp/Shared/PasteboardImport.swift` を作り、T032 を通す。一般クリップボードの約束は使わず、CoreへpromiseDeclaredTypes=[]を渡す。file URL → 画像データの順とする（T007確定、R11）
- [ ] T034 [US2] `Sources/FolzioApp/FileList/FileContextMenu.swift`（37 行・73 行付近）、`FileListViewController.swift`（`validateMenuItem`・`paste`）、
  `DirectoryTreeViewController.swift`（`validateMenuItem`・`paste`）のペーストの有効・無効を `PasteboardImport.availability` に置き換える
- [ ] T035 [US2] `FileOperationCoordinator.paste(into:move:)`（111 行付近）で、file URL がなければ `ImportSession` を始め、`saveReceived` で保存する。
  移動ペーストでは画像の保存を始めない
- [ ] T036 [US2] `scripts/dev/check-all.sh` を実行し、Phase 4 をコミットして push する。CI で build とテストの結果を確かめる
- [ ] T037 [MANUAL] [US2] 保守者に、quickstart.md の「ペースト」の表と「変わらないこと」を実行してもらい、結果を `checklists/validation.md` に記録する

**Checkpoint**: ドラッグとペーストの両方で保存できる

## Phase 5: Polish & Cross-Cutting

- [ ] T038 [P] `README.md`・`README.ja.md`・`docs/usage.md`・`docs/usage.ja.md` に、ブラウザの画像の保存（ドラッグ・⌘V）と取り消し（⌘.）の説明を、2 言語で同じ内容に、同じコミットで加える。
  `specs/`・`docs_private/` へリンクしない（AGENTS.md の書くときの規則）
- [ ] T039 `scripts/dev/check-all.sh` と `scripts/check-no-network.sh` を実行し、公開用の書き出し（`scripts/dev/export-public.py`）に `scripts/dev/pasteboard-probe.swift` が含まれないことを確かめる
- [ ] T040 T006 の画像データの読み出し時間と T031 のドラッグの反応・SC-189 の計測を、条件（macOS・機種・データの型と大きさ・変更前後のコミット）とともに
  `checklists/validation.md` にまとめ、PR の検証欄へ記載する本文を用意する（憲章 原則 II）。計測していない項目は未確認とする。
  保守者の依頼があれば PR を作り、この計測結果を記載し、Linear の TAK-88 に PR のリンクを加えて `In Review` にする（`docs_private/agents/linear.md`）
- [ ] T041 PR の最後に、`git merge origin/master` で最新の master を取り込み、`scripts/dev/check-spec-ids.sh` で ID の衝突を確かめてから、spec の「反映先」の表のとおり
  `specs/product/file-operations.md`・`contracts/keyboard-and-menus.md`・`contracts/settings.md`・`contracts/localization.md` へ反映する。
  `python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-spec-ids.sh` を反映の後にも実行し、反映した項目と差分を保守者に示して承認を得てからコミットする
  （`docs_private/cloud-agent-workflow.md` の 7 章）。spec.md の冒頭に移行済み・凍結の注記を入れる

## Dependencies & Execution Order

- Phase 0 → Phase 1（T006 の保守者の確認と T007 の確定まで） → Phase 2 → Phase 3（US1） → Phase 4（US2） → Phase 5
- Phase 4 は Phase 3 の `ImportSession`（T024）と `saveReceived`（T025）を使う。憲章 原則 III により、US1 と US2 は同じ PR で提供する
- T042 → T043 → T024。T024 の接続のテストは T025・T027・T028 と合わせて通し、T030 の CI で確かめる
- T041（product への反映）は PR の最後の作業

## Parallel Opportunities

- Phase 2 のテストの作成（T008・T010・T012・T014・T016・T018・T042）は、別のファイルなので並行できる。Cloud ではサブエージェントで分けず、1つのセッションで順に行う
  （AGENTS.md の作業別の手順）
- Phase 3 の T021 と Phase 4 の T032 は別のファイルで、テストの作成だけなら並行できる

## Implementation Strategy

1. Phase 1 で事実を確かめ、spec・plan を確定する（変える点は保守者に確かめる）
2. Phase 2 で Core の判断と検査をテストで固める（細工された入力の網羅）
3. Phase 3 でドラッグを通し、保守者の確認（T031）で MVP を確かめる
4. Phase 4 でペーストを加える（キーボードの手段。US1 と同じ PR で提供する）
5. 文書と product への反映で終える。GUI の確認が終わるまで、GUI のタスク（T031・T037）は未チェックで残す（AGENTS.md の完了の条件）
