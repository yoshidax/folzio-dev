# Research: TAK-88 ブラウザの画像をフォルダへ保存する

spec の要件を実装する方法の決定。参照する行番号は 2026-11-08 の `master`（`835b82c`）のもの。

## R1 先に行う確認（A-212）

- **Decision**: 実装の最初に、開発用の確認スクリプト `scripts/dev/pasteboard-probe.swift`（公開用リポジトリへ書き出さない）を作り、
  保守者が macOS で次を確かめる。結果を `checklists/validation.md` に記録し、結果に合わせて spec と plan を直してから残りを実装する。
  1. Safari・Chrome の Web の画像のドラッグで、ペーストボードにある型（file promise・PNG・TIFF・URL）、file promise が示す種類（`fileTypes`）、
     ドラッグ元が許可する操作（マスク）、書き出されるファイルの名前と形式、書き出しにかかる時間
  2. Safari・Chrome の「画像をコピー」、写真アプリの写真・動画の「コピー」で、一般のペーストボードにある型と大きさ
  3. 一般のペーストボードから `NSFilePromiseReceiver` を読み出し、書き出させられるか（写真アプリのコピー）
  4. ドロップの間に、ペーストボードの画像データ（数 MB と、作った 200 MB 程度の TIFF）を読むのにかかる時間
- **Rationale**: 受け付ける型・ホバー中の判定・読み出し方法は、ブラウザが渡すものに依存し、Cloud と CI では確かめられない。
  TAK-74 の T005 と同じく、先に事実を確かめてから仕様を確定する。
- **Alternatives considered**: Folzio に診断用の機能を入れる案。製品のコードに開発用の機能を残さないため採らない。
  スクリプトは `swift scripts/dev/pasteboard-probe.swift` で実行でき、Xcode を要しない。

### T006の結果とT007の承認（2026-11-09）

測定と修正後のGUI確認を完了し、保守者が変更案に「OKです。」と承認した。実測値とログはchecklists/validation.mdにある。
以下のR2〜R5・R10・R11をこの結果で確定した。測定の完了は製品実装の完了を意味しない。

- ドラッグの約束の型はpublic.png / public.jpeg / org.webmproject.webp / com.compuserve.gif / com.apple.quicktime-movie / public.mpeg-4を観測。
  写真HEICケースの提供はJPEG、写真2枚はPNGの組とPNG / JPEGの組だった。元の形式の保持は保証しない。
- コピーは全ケースreceivers=0。一般クリップボードの約束を今回の範囲に含めない。Photosのfile URLの実体と製品への保存は未確認で、T031・T037に残す。
- Safari・写真のマスクはcopy、Chromeはcopyを含む全マスク。copy必須の規則を維持する。
- 旧版の要求時機ではキャンセルがあり、事前作成先へドロップ内で要求する診断版と通常版で成功した。全キャンセルの原因が時機だけとは断定しない。
- 17:59のSIGBUSの原因は未確定。要求時機の修正で解消したとは扱わない。

## R2 受け付ける型とホバー中の判定（FR-348・FR-356）

- **Decision**: 3つのビュー（`DirectoryTreeViewController.swift:1059`、`ListModeView.swift:262`、`ThumbnailModeView.swift:642`）の
  `registerForDraggedTypes` に、`.fileURL` に加えて `NSFilePromiseReceiver.readableDraggedTypes`、`.png`、`NSPasteboard.PasteboardType(UTType.jpeg.identifier)`、`.tiff` を登録する。
  App の `ExternalImageDrag` が、ドラッグの通し番号ごとに1回だけペーストボードを調べ、受け取るデータ（`ImportPayload`。data-model.md）を決める。
  - file URL があれば、今の `ExternalDrag`（TAK-74）の経路のまま（EC-241）
  - file promise は、`NSFilePromiseReceiver` を読み出し、`fileTypes` を Core の `ImportPayloadPolicy.acceptsPromise(declaredTypes:)` で判定する
    （画像・対応形式の動画・不明だけを受け付ける。FR-348）
  - 画像データは各NSPasteboardItem.typesだけを見てPNG → JPEG → TIFFを選び、ホバー中にデータを読まない。全体のpasteboard.typesに合成された型だけでは選ばない
  - HEICの直接データは今回未観測のため固定リストに加えない。約束の型はUTTypeの適合で判定し、固定の文字列一覧に制限しない
  - 約束を選んだ場合は、準備済みのImportStagingがあるときだけ受け付ける（R3・R10）
  - 受け付けるときの操作は `.copy`（ドラッグ元のマスクが `.copy` を含むときだけ）。修飾キーで変えない（FR-356）
  - 宛先の有効性は、今の各ビューの宛先の判断（`FileListDropTarget` など）をそのまま使う。画像の保存は自分自身・配下への転送の検査
    （`InternalDropValidation`）を要しないので、ファイルシステムを読まずに即答する
- **Rationale**: 型を登録しなければビューは反応しないので、URL・文字列だけのドラッグは今と同じく無視される（FR-348）。
  ホバー中にファイルシステムを読まないので、`DropOperationCache` の非同期の判定は不要で、通し番号ごとの結果だけを保持する。
- **Alternatives considered**: `NSImage.imageTypes` をすべて登録する案。PDF・EPS が含まれ、FR-357 で拒否するものに宛先を強調するため採らない。

## R3 受け取りの流れと打ち切り（FR-350・FR-355・FR-359・FR-363）

- **Decision**: AppのImportSession（MainActor）が1回のドロップ、または画像データのペーストを担う。
  1. R10で背景作成しておいたImportStagingを、約束のドロップ中に同期的に1組確保する。未準備ならドロップを拒否し、要求を後へ保留しない
  2. acceptDropの中でNSFilePromiseReceiverの配列を読み、全receiverへ共通のreceptionFolderを渡してreceivePromisedFilesを呼んでから返す。フォルダ作成やTaskの後まで要求を遅らせない。readerには専用のOperationQueueを渡す
  3. readerはMainActorを引き継がない明示的な非隔離のSendableコールバックとする。エラーならURLを使わない。成功ならreaderが返る前にR4の構造確認と複製を専用キュー上で行い、MainActorへは複製の結果だけを渡す
  4. 待つ時間は約束の種類で60秒（画像・不明）または10分（動画）。打ち切り・取り消し後の結果は保存に加えない
  5. 待つ間は1秒ごとにreceptionFolderの大きさを背景で調べ、約束ごとの上限（画像・不明256 MB、動画4 GB）の合計を超えたら全体を打ち切る。自分で作る検査用複製は書き出し量へ二重計上しない
  6. 全約束の結果がそろったら、R4で複製の中身を検査し、R7で確認して保存する。画像データだけの経路はcheckingから始め、フォルダ作成・書き込みを背景で行う
  7. 成功・失敗・取り消しのどれでも一時フォルダを削除してR10の記録から外す。遅い通知でも宛先へ保存せず、残った一時ファイルを掃除する
- **判断と副作用の分離**: CoreのImportBudgetが期限・容量を、ImportReceptionStateが状態と遅い結果の拒否を判断する。AppKit・時計・タイマーは持たせず、Appが経過時間と観測値を渡す。
  Appのテストでは時計・受け取り・確認を差し替え、共通宛先、要求がドロップ内で始まること、未準備時の拒否、取り消し、掃除、宛先の失敗、同時操作の独立と確認の直列化を確かめる。
- **複数のファイルと同名**: readerが報告したファイルだけを対象とする。報告されない付随ファイルは保存しない。1つのreceiverが複数のファイルを返す場合も通知ごとに別の複製を作り、全ファイルを検査する。
  別のreceiverが同じrealpathのファイルを報告した場合はsourceFailedとして操作全体を失敗にし、複製済みの分も宛先へ保存しない（EC-243）。同じreceiverの重複通知は二重に数えない。
- **Rationale**: 現行macOS 27.2 SDKのNSFilePromiseReceiver.hは同じドラッグの全receiverに共通のdestinationを要求する。readerの呼び出しはNSFilePromiseProviderの場合は協調読み出しで保護されるので、その有効期間に複製する。
  通常版のGUIでSafari PNGと写真2枚の成功、全request-beginがdrop-returnより前であること、背景でのフォルダ補充を確認した。
- **Alternatives considered**: 約束ごとの別宛先はSDKの契約に反するため採らない。フォルダ作成後に要求する旧版の方法も採らない。単一receiverの複数ファイルと同一パス衝突は実測できていないため、実装時の自動テストで固定する。

## R4 検査と複製（FR-357・FR-360・FR-359、拡張属性）

- **Decision**: CoreのImportInspectorが、複製と中身の検査を分けて次を行う。構造確認と複製はreaderの専用キュー上で、その通知が返る前に同期的に実行し、中身の検査は複製に対して背景で行う。
  1. 構造: `lstat` でシンボリックリンクをたどらずに通常のファイルであること、パッケージ・エイリアス（`URLResourceValues.isAliasFile`）でないこと、
     親のフォルダが共通のreceptionFolderであること（`standardizedFileURL` の比較ではなく、`realpath` で解いた親）
  2. 複製: ドラッグ元へ知らせないinspectionFolderへ、通知ごとのUUID等の別名で `copyfile(_:_:nil, COPYFILE_CLONE | COPYFILE_ALL)` により複製する。
     APFS では内容を共有する複製になり、ほかのボリュームでは通常の複製になる（`COPYFILE_CLONE` は複製できないときに複製へ切り替わる）。
     `COPYFILE_ALL` で拡張属性（ブラウザが付けた quarantine の印を含む）を保つ（spec の5回目のレビューで plan に回した点）
  3. 大きさ: 複製の大きさ（`stat`）を、中身の種類の上限（画像 256 MB・動画 4 GB）と比べる（FR-359）
  4. 中身: 画像は `CGImageSourceCreateWithURL` の `CGImageSourceGetType` と `CGImageSourceGetCount` だけを読み、画像を展開しない。
     種類が `public.image` に適合し、SVG・PDF・EPS・PostScript（`UTType.svg`・`.pdf`・`com.adobe.encapsulated-postscript`・`com.adobe.postscript`）でないこと。
     動画は先頭の 64 バイトだけを読み、ISO の形式の `ftyp` の箱の銘柄（`qt  ` なら QuickTime、`isom`・`mp41`・`mp42`・`avc1`・`M4V ` などなら MP4）か、
     QuickTime の最初の箱（`moov`・`mdat`・`wide`・`free`・`skip`）で判別する。AVFoundation で開かない（再生しない）
  5. 名前: R6 の規則で、中身の形式の拡張子と名前の条件に合わせる
  6. 検査に通った複製の名前を、宛先に作る名前に変える（検査用のフォルダの中で。EC-243 の連番もここで付ける）
- **Rationale**: 複製を検査し、その複製を保存するので、ドラッグ元が元のファイルを開いたまま書き換えても影響しない（FR-357）。
  `copyfile` は Foundation と同じく UI に依存せず、Core で使える。ImageIO の型と枚数の読み出しはヘッダーだけで足りる（ImageIO の文書）。
- **Alternatives considered**: 識別子・大きさ・変更日時を比べる案。開いたままの書き込みと変更日時の書き戻しで通るため、4回目のレビューで採らなかった。
  動画を AVFoundation で開く案。攻撃者が作った動画のデコーダの処理を走らせることになり、形式の判別だけなら先頭の箱で足りるため採らない。
- **未検証**: `COPYFILE_CLONE` が exFAT・SMB で通常の複製に切り替わること、`COPYFILE_ALL` が拡張属性を保存できないボリュームで失敗しないこと（R1 とあわせて確かめる）。

## R5 画像データの読み出しと変換（FR-351・FR-352・FR-355・FR-359）

- **Decision**: 各NSPasteboardItem.typesからPNG、JPEG、TIFFの順に1つ選ぶ。全体のtypesにだけある合成TIFFは選ばない。
  - 読み出し: ドロップ（`acceptDrop`）とペーストの中で、選んだ型の `NSPasteboardItem.data(forType:)` を UI スレッドで読む。
    同じ項目の `public.url`（http・https）の文字列も読む。HTML・リッチテキストは読まない（FR-353）
  - 256 MB を超えるデータは、読んだ直後に捨てて失敗とする
  - 変換と書き込みは detached task で、ImageIO の `CGImageSource`・`CGImageDestination` を使う。PNG のデータはそのまま書く。
    ほかの形式は、1 枚目の画像の画素数をプロパティで調べ、1 億以下なら PNG に変換する（FR-359）
- **Rationale**: ドロップを返した後のペーストボードの有効性に依存しない。実アプリの画像表現は最大2480836 bytes、取得時間の最大値は0.032769秒だった。即時提供の200013546 bytes TIFFは0.008885秒、256016210 bytes TIFFは0.013577秒で、今回の全実測は0.2秒未満。
- **限界と再評価**: 大きなTIFFの値は生成済みデータの即時提供で、実アプリの遅延提供とは別の条件。上限検査は取得直後であり、取得前の確保量や待ち時間を制限するものではない。
  将来0.2秒超を観測した場合は取得方法を再評価して保守者へ示す。ドロップ後のNSPasteboard(name: .drag)を背景から読めるとは検証していないため、その方式へ自動的には切り替えない。

## R6 名前（FR-352・FR-357・FR-360・EC-243）

- **Decision**: Core の `ImportedFileName` に純粋な関数を置き、Swift Testing で確かめる。
  - `isAcceptable(_:)`: 空でない、`/`・`:` を含まない、`.` で始まらない（`validateNewName` と同じ規則。`Sources/FolzioCore/Operations/NameValidation.swift`）、
    制御文字（Unicode の `Cc`）と書式の文字（`Cf`。文字の向きを変える U+202A〜U+202E・U+2066〜U+2069・U+200E・U+200F を含む）を含まない、UTF-8 で 200 バイト以下
  - `nameFromURL(_:)`: スキームが http・https のときだけ、最後のパスの要素のパーセントエンコードを解き、拡張子を除いて `.png` を付ける
  - `datedName(prefix:date:extension:)`: `<接頭辞> yyyy-MM-dd HH.mm.ss.<拡張子>`。ローカルのタイムゾーン、`en_US_POSIX` で ASCII の数字
  - `corrected(name:contentType:)`: FR-360。最後の拡張子を中身の形式の標準の拡張子（`UTType.preferredFilenameExtension`）に置き換える。
    今の拡張子が同じ形式で、かつ `MediaKind(fileExtension:)` が認める（`Sources/FolzioCore/Model/MediaKind.swift`）か標準の拡張子と大文字小文字だけ違うときは残す
  - `uniqueNames(_:)`: 1回の操作の中で重なる名前に、既存の `uniqueName(for:existingNames:)`（`NameValidation.swift`）で連番を付ける
- **Rationale**: 名前の規則は入力が細工される場所なので、純粋な関数にして境界の値を網羅的にテストする。既存の連番の関数を再利用する。
- **通信の検査との関係**: `scripts/check-no-network.sh` は `Sources` の中の語 `http` と `https://` を、コメントを含めて拒否する。
  スキームの比較に `"http"` の文字列が要るため、`AboutInfo.swift` の例外と同じ形で、`Sources/FolzioCore/Operations/ImportedFileName.swift` の
  `"http"` と `"https"` の2つのリテラルだけを許す例外を加える（文字列として比べるだけで、通信しない）。
  検査を変えることになるので、設計レビューで保守者の承認を得る。承認されなければ、http・https を見分けられないので、URL から名前を取らず、常に日時の名前にする（FR-352 を改める）。

## R7 保存の実行と確認（FR-347・FR-350・FR-356）

- **Decision**: `FileOperationCoordinator` に `saveReceived(_ staged: [URL], to destination: URL, sameVolume: Bool)` を加える。
  - 確認: `FileOperation(kind: .copy, sources: staged, destination: destination)` で `ConfirmationPresenter.confirm` を呼ぶ。
    確認モーダルは項目の名前（`lastPathComponent`。`ConfirmationPresenter.swift:125-126`）と宛先を示すので、検査用のフォルダの場所は出ない（FR-347）
  - 実行: 既存の `transferItems`（`FileOperationCoordinator.swift:229`）を、同じボリュームなら `.move`（名前の変更で移す）、
    宛先が別のボリュームなら `.copy` で呼ぶ。衝突は既存の `ConflictPrompt` で扱う（FR-025）
  - 後処理: コピーと同じく `reloadCurrentFolder` と、宛先だけの `onFoldersChanged`。一時的なフォルダを通知に含めない。
    移動の後処理（`didMoveSearchItems`・履歴からの削除）は行わない
  - 動画も同じ経路で、コピーとして扱う。spec の FR-347 の文言を「画像・動画の保存」に直す（spec の5回目のレビューで plan に回した点）
- **Rationale**: 確認・衝突・失敗の表示を既存の経路で満たし、新しい種類の確認を作らない（憲章 原則 V）。
- **Alternatives considered**: `FileOperation.Kind` に `.import` を加える案。確認の省略設定・文言・衝突の処理をすべて複製することになるため採らない。

## R8 quarantine の印（FR-358）

- **Decision**: 検査用のフォルダの複製に対して、`URLResourceValues.quarantineProperties` を読み、なければ
  `["LSQuarantineAgentName": "Folzio", "LSQuarantineTimeStamp": 保存の日時, "LSQuarantineType": "LSQuarantineTypeOtherDownload"]` を設定する。
  URL のキー（`LSQuarantineDataURL`・`LSQuarantineOriginURL`）は設定しない。設定に失敗したとき（拡張属性を保存できないボリューム）は、印なしで続ける。
  宛先へ移す前に付けるので、印のないファイルは宛先に現れない（`.move` は拡張属性を保ち、`.copy` は `FileManager.copyItem` が保つ）。
- **Rationale**: Foundation の API で、LaunchServices を import せずに設定できる。キーの文字列は LaunchServices の定数の値と同じ。
- **未検証**: 設定した印が `xattr -p com.apple.quarantine` で読めること（macOS CI のテストで確かめる）。

## R9 進み具合のパネルと取り消し（FR-363）

- **Decision**: 1つの `ReceivingPanelController` が、待っている操作をすべて行として並べる、操作を妨げないパネル
  （`NSPanel`、`.nonactivatingPanel`、`becomesKeyOnlyIfNeeded`）を持つ（spec の5回目のレビューで plan に回した点。操作ごとにパネルを出さない）。
  - 行には、宛先のフォルダの名前、約束の件数、書き出し済みの件数、書き出された大きさの合計、段階（書き出し中・確認中）、行ごとの「取り消す」ボタンを示す
  - 操作の開始から 2 秒で終わらなければ、その行を出す。最後の行が消えたらパネルを閉じる
  - パネルは書き出しの間だけでなく、R4 の複製と検査の間も出し続ける（spec の5回目のレビューで plan に回した点）。確認モーダルを出す直前にその行を消す
  - ⌘. は、編集メニューの「受け取りを取り消す」（新しい項目。キーは ⌘.、割り当ての変更の対象外）にし、最後に始めた操作を取り消す
  - `validateMenuItem` は、待っている操作があり、キーのウインドウにシートがなく、アプリのモーダルがなく、最初の応答者がテキストの編集
    （`NSText`）でないときだけ有効にする。無効のときは、⌘. は既存の取り消し（`cancelOperation:`）へ渡る
- **Rationale**: メニューの項目にすると、キーボードで到達でき（憲章 原則 III）、メニューの有効・無効で ⌘. の優先順位を決められる。
  パネルを1つにすると、複数の操作が重ならない。
- **Alternatives considered**: パネルのボタンのキーとして ⌘. を割り当てる案。パネルはフォーカスを奪わないため、キーが届かないので採らない。

## R10 一時的なフォルダと起動時の掃除（FR-350・FR-361）

- **Decision**: CoreのImportStagingを背景で作り、AppのMainActor上の準備済みフォルダのプールへ渡す。
  - 場所はFileManager.default.temporaryDirectory内のFolzio-Import/<UUID>。各rootに共通のreceptionFolderと、ドラッグ元へ知らせないinspectionFolderを作る。宛先が決まる前に準備するので、itemReplacementDirectoryによる宛先ボリュームの優先は行わない
  - 起動時に残存フォルダの掃除を終えてから2組を作り、消費後は背景で補充する。空なら約束のドラッグを受け付けない。ホバーではファイル操作をせず、準備済みの有無だけで判断する
  - 宛先へ保存するときの同一ボリューム判定は背景で行う。同一ならmove、異なるならcopyで保存する（R7）。別ボリュームへの保存は一時領域と宛先の両方の容量を使う
  - 記録はUserDefaultsのinternal.pendingImportFoldersに[path, volumeUUID, createdAt]の配列として保存する。待機用も作成直後に加え、消した後に外す。記録更新は直列化する。設定の書き出し・初期化の対象にしない
  - 起動時の掃除はAppDelegateが背景で行う。記録のvolumeUUIDと実体のボリューム、OSの一時領域内のFolzio-Import/<UUID>であることを確認してから消す。確かめられない・30日超は消さずに外し、ボリュームがないものは持ち越す
  - 操作の終了時と、正常終了時に残る未使用の待機用フォルダも掃除する。打ち切り後に遅く届く書き込みを保存へ進めず、残存分を掃除する規則は維持する
- **Rationale**: 宛先未確定でも受け取り先を用意でき、ドロップ内の要求とUIスレッドでファイル操作を行わない制約を両立する。名前とボリュームの確認で、記録の改変による一時領域外の削除を防ぐ。
- **Alternatives considered**: ドロップ後に宛先ボリュームの一時フォルダを作って要求する旧案は採らない。Application Supportに新しい記録ファイルも作らず、既存のUserDefaultsを使う。

## R11 ペーストとメニューの有効・無効（FR-354）

- **Decision**: FileContextMenuとツリー・ファイルリストの有効条件を、AppのPasteboardImport.availability(.general)にまとめる。各項目の型だけを見てfileURLs・imageData・noneを返し、データを読まない。
  - 一般クリップボードの約束は対象に含めず、CoreのImportPayloadPolicyへpromiseDeclaredTypes=[]を渡す。約束だけならnone、約束と画像データならimageDataになる
  - ペースト / ここにペーストはnone以外で有効。移動ペースト / ここに移動ペーストはfileURLsだけで有効
  - 実行時はfile URLがあれば既存のコピー経路へ渡し、失敗しても縮小JPEG等へ切り替えない。file URLがなければR5の画像データのImportSessionを始める
  - 写真アプリのコピーにはfile URLとJPEG表現を観測し、全コピーでreceivers=0だった。元のHEIC形式の保持は約束せず、file URLでの保存自体はT037で確認する
- **Rationale**: EC-241・US78-AS8・FR-354を実測に合わせる。一般クリップボードでAPIが一切使えないと証明したものではなく、今回の対象アプリから約束が提供されなかったため範囲から外す。動画のJPEG表現を動画取得として扱わない。

## R12 ローカライズ（A-213）

- **Decision**: `Sources/FolzioLocalization/TextKey.swift` と両言語の `Localizable.strings` に、spec の「新しい文言」の表のキーを加える。
  失敗の理由は `OperationFailureReason` に `importRejected(ImportRejection)` を加え、`ImportRejection`（data-model.md）ごとに文言を選ぶ。
  編集メニューの「受け取りを取り消す」/ `Cancel Receiving` と、パネルの段階（「書き出し中」/「確認中」、`Receiving` / `Checking`）も加える。
- **Rationale**: 既存の翻訳の仕組み（`contracts/localization.md`）に従う。

## R13 変えないもの

- アプリ内のドラッグ（`InternalDrag`）と、アプリ外の file URL の受け取り（`ExternalDrag`・`ExternalDropPolicy`）の規則と経路は変えない（SC-192）
- Folzio からアプリ外へ渡すデータは file URL だけのまま（A-205）
