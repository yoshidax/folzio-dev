# Data Model: TAK-88 ブラウザの画像をフォルダへ保存する

新しい永続データは、起動時の掃除の記録（`ImportCleanupRecord`）だけ。ほかは準備済みフォルダのプール、または1回の受け取りの間だけ持つ値。

## Core（`FolzioCore`。AppKit を import しない）

### ImportPayloadPolicy（純粋な判断。R2・R5・R11）

| 入力 | 内容 |
|---|---|
| `hasFileURLs` | ペーストボードに file URL があるか |
| `promiseDeclaredTypes` | file promise が示す種類の識別子の配列（約束ごと） |
| `imageDataTypes` | 項目ごとの画像データの型の識別子 |

| 出力 | 内容 |
|---|---|
| `ImportPayload.fileURLs` | 今の file URL の経路（TAK-74）へ渡す |
| `ImportPayload.promises([ExpectedKind])` | 約束ごとの、示す種類から見た `image`・`video`・`unknown` |
| `ImportPayload.imageData([String])` | 各項目のtypesからPNG → JPEG → TIFFで選んだ型（R5） |
| `nil` | 受け付けない（宛先を有効にしない・ペーストを無効にする） |

- 一般クリップボードのAppアダプターはpromiseDeclaredTypes=[]を渡し、file URL → 画像データの順とする。約束だけならnil、約束と画像データならimageData。ドラッグではfile URL → 約束 → 画像データ（EC-241）
- 約束は、示す種類がすべて画像・動画でない（PDF など）ときに受け付けない（FR-348）
- `ExpectedKind` は待つ時間（60 秒・10 分）と書き出し中の上限（256 MB・4 GB）を決める。保存の上限には使わない（FR-359）

### ImportBudget・ImportReceptionState（純粋な判断。R3）

- `ImportBudget` は約束ごとの `ExpectedKind` と、ドロップ・ペーストからの経過時間、観測した大きさを入力にする。
  時計・タイマー・ファイルシステムには触れない。画像・不明は 60 秒、動画は 600 秒で未完了の約束を打ち切る。
  大きさは画像・不明 256 MB、動画 4 GB の合計を超えたときに操作全体を打ち切る。上限と同じ大きさは許す（FR-355・FR-359）
- `ImportReceptionState` は下記の状態の移り変わりと、結果を受け付けるかを判断する。
  `finished`・`failed`・`cancelled` からは遷移せず、打ち切り・取り消しの後の結果を保存の対象に加えない。
  画像データは `checking` から始める。App の `ImportSession` が、この判断に従って副作用を実行する
- それぞれの操作が別の値を持つ。時計を待たずに、期限と大きさの境界、状態の移り変わりを自動テストで確かめる

### ImportedFileName（純粋な関数。R6）

| 関数 | 規則 |
|---|---|
| `isAcceptable(_:)` | 下記 |
| `nameFromURL(_:)` | http・https の最後のパスの要素。拡張子を `.png` にする |
| `datedName(prefix:date:extension:)` | `<接頭辞> yyyy-MM-dd HH.mm.ss.<拡張子>` |
| `corrected(name:contentType:)` | FR-360 の拡張子の直し方 |
| `uniqueNames(_:)` | 1回の操作の中で重なる名前に連番を付ける（EC-243） |

- **isAcceptable**（規則）: 空でない、`/`・`:` を含まない、`.` で始まらない、`Cc`・`Cf` の文字を含まない、UTF-8 で 200 バイト以下（FR-357）

### ImportInspector（受け取り通知中の複製と、背景での検査。R4）

| 結果 | 内容 |
|---|---|
| `.accepted(InspectedFile)` | 検査用のフォルダの複製、中身の種類（`ContentKind`）、宛先に作る名前 |
| `.rejected(ImportRejection)` | 保存しない理由 |

- 構造確認と複製はreaderの有効期間中に専用キュー上で同期的に行い、通知ごとの別名でinspectionFolderへ作る。AppKitはCoreへ持ち込まない。後の検査はこの複製だけを対象にする
- 別receiverによる同じrealpathの再利用はsourceFailedとして操作全体を失敗にする。同じreceiverの重複通知は二重に数えない（R3・EC-243）
- `ContentKind`: `.image(UTType)`・`.video(MediaKind)`（`.mp4`・`.mov`）

### ImportRejection（失敗の理由。R12）

| 値 | 文言の対応（spec の「新しい文言」） |
|---|---|
| `notImageOrVideo` | 画像または動画として読めません |
| `unsupportedImageFormat` | この形式の画像は保存できません（SVG・PDF・EPS など） |
| `unsupportedVideoFormat` | この形式の動画は保存できません |
| `notRegularFile` | フォルダ・パッケージ・リンクは保存できません |
| `tooLarge(limit:)` | 256 MB / 4 GB を超えるため保存できません |
| `tooManyPixels` | 1 億画素を超えるため変換できません |
| `timedOut(seconds:)` | {秒数} 秒以内に書き出されませんでした（画像・不明 60、動画 600） |
| `sourceFailed` | ドラッグ元のアプリがファイルを書き出せませんでした |

- `OperationFailureReason` に `importRejected(ImportRejection)` を加え、FR-026 の表示に使う
- 取り消し（FR-363）は理由にせず、失敗の表示を出さない
- 名前の条件だけを満たさない場合は、FR-352・FR-360 の日時の名前に直す。名前の長さを失敗の理由にしない

### ImportStaging（一時的なフォルダ。R3・R10）

| 項目 | 内容 |
|---|---|
| `root` | 起動ディスクのOSの一時領域内の `Folzio-Import/<UUID>`。宛先決定前に背景で作成する |
| `sameVolumeAsDestination` | 操作へ割り当て後に背景で調べる。同じボリュームなら移動（`true`）、異なるならコピー（`false`） |
| `receptionFolder` | 同じドラッグの全receiverへ渡す共通の受け取り用フォルダ |
| `inspectionFolder` | 検査用のフォルダ（ドラッグ元に知らせない） |
| `currentSize()` | receptionFolderの大きさの合計（1秒ごとの見張り。自分で作る検査用複製を二重計上しない） |
| `remove()` | フォルダと中身を消し、記録から外す |

- AppのMainActor上のプールが2組を準備し、消費後に背景で補充する。未準備なら約束のドロップを拒否し、要求をTaskの後へ遅らせない。画像データだけなら実行後の背景作成でもよい
- 待機用も作成直後から記録し、未使用分は正常終了時に掃除する。起動時の残存フォルダ掃除の後に、新しい待機用を作る（R10）

### ImportCleanupRecord（永続。`UserDefaults` の `internal.pendingImportFolders`。R10）

| 項目 | 型 |
|---|---|
| `path` | String（一時的なフォルダの絶対パス） |
| `volumeUUID` | String |
| `createdAt` | Date |

- 起動時に、ボリュームの識別子とOSの一時領域内のFolzio-Import/<UUID>という名前の形を確かめてから消す。確かめられない・30 日を過ぎたものは消さずに外す。ボリュームがないものは持ち越す（FR-361）
- 読み込みで型が不正な項目は捨てる（今の設定の読み込みと同じ方針。`contracts/settings.md`）

## App（`FolzioApp`）

### 準備済みフォルダのプール（MainActor。R3・R10）

- 背景で作ったImportStagingを2組保持し、操作ごとに1組を同期的に確保して背景で補充する。空のときは約束のドラッグを有効にしない
- AppDelegateが残存フォルダの掃除の後に準備を始める。作成と掃除、記録の更新は競合しないように順序を守る

### ImportSession（1回の受け取り。MainActor。R3）

| 状態 | 次の状態 |
|---|---|
| `receiving` | 下記 |
| `checking` | `confirming`、`failed`、`cancelled` |
| `confirming` | `saving`、`failed`（宛先の消失・書き込み不可など）、`cancelled`（確認のキャンセル・衝突の中止） |
| `saving` | `finished` |

- ドロップ内で準備済みImportStagingを取得し、全receiverへ共通宛先でreceivePromisedFilesを呼んでから返す。reader中の複製を終えた結果だけをMainActorへ通知する
- **receiving**（次の状態）: すべての約束の結果がそろうと `checking`。打ち切り・大きさの超過で `failed`、取り消しで `cancelled`
- 画像データの受け取りは `checking` から始まる（変換と書き込み）
- `finished`・`failed`・`cancelled` で一時的なフォルダを消す。`failed` は FR-026 で表示し、`cancelled` は表示しない
- 2 秒を超えて `receiving` か `checking` にあるとき、`ReceivingPanelController` に行を出す（R9）
- 状態の判断は Core の `ImportReceptionState`、期限・大きさの判断は `ImportBudget` に任せる。
  App は単調増加する時計からの経過時間を渡し、1 秒ごとの大きさの読み出しと、約束・検査・保存・掃除を実行する
- 宛先が消えた・書き込めなくなった失敗も FR-026 で表示し、掃除する（EC-245）。複数のセッションは宛先・状態・一時的なフォルダを共有せず、
  確認モーダルとダイアログだけを1つずつ表示する（EC-246）。打ち切り後の結果でも宛先へは保存せず、残った一時的なファイルを掃除する

### ReceivingPanelController（R9）

- 待っている `ImportSession` を、始めた順に持つ。⌘. と編集メニューの「受け取りを取り消す」は最後のものを取り消す
- 行ごとの「取り消す」は、その行の操作を取り消す
