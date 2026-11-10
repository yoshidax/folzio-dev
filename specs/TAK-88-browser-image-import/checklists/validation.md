# TAK-88 検証の記録

## 設計の承認

- 2026-11-09: このチャットで、分析の指摘を反映した設計（`9b8102e`）と R6 の検査例外を示した確認に対し、保守者が「進めてください」と承認（T003）
- 2026-11-09: T006完了後に示したT007の変更案に、保守者が「OKです。」と承認。共通宛先・事前作成・クリップボードの約束の除外・PNG → JPEG → TIFF・同一実体パスの拒否を含めて仕様と関連計画を確定した。Phase 2以降は未着手
- R6 は `ImportedFileName.swift` のスキームの文字列比較だけの例外。通信する機能の追加は含まない

## Cloud と CI

- Cloud: `scripts/dev/check-all.sh` 成功（176 件中 143 件成功、macOS 固有の 33 件はスキップ）、`git diff --check` 成功
- 公開用ツリー: `10590ed` を `scripts/dev/export-public.py` で書き出し、確認スクリプトを含む `scripts/dev/` が除外されることを確認
- macOS CI: [`ff748f5` の実行](https://github.com/yoshidax/folzio-dev/actions/runs/42572604387)（macOS 15.8.2 / arm64、Xcode 16.0 / Swift 6.0）。
  `swift build` 成功。スクリプトの Swift 6 でのコンパイルと `--self-test` 成功（名前と中身が異なる2つの画像、非圧縮 TIFF）。通常テスト 1,084 件成功
- 性能テストは 27 件中 24 件成功、3 件が時間の基準を超過。ステップが `continue-on-error` のため CI 全体は成功だが、性能テストが全件成功したとは扱わない。
  アプリの処理と性能テストは今回変更していない。原因と変更前との比較は未調査であり、共有ランナーのばらつきとも性能劣化とも断定しない
- GUI の実行、ブラウザ・写真アプリとの実際の受け渡し: 未確認。T006 の保守者による確認を待つ

| 基準を超過した性能テスト | 実測 | 基準 |
|---|---|---|
| フォルダ名変更後の検索結果 10,000 件の反映 | 中央値 0.138936084 秒 | 0.1 秒未満 |
| 50,000 件に対する 256 件のバッチ処理 | 0.105407375 秒 | 0.1 秒未満 |
| zip の 200,000 件からスライドショー候補を抽出 | 0.213059959 秒 | 0.2 秒未満 |

CI の対象はスクリプトを含む実装コミット `ff748f5`。この後の検証記録とタスクのチェックだけの更新では、実装・CI の定義・テストは変更していない。

## T006 の実測結果（保守者の macOS）

**状態**: T006 の実測完了（2026-11-09 19:21 JSTまで）。Safari・ChromeのJPEG・PNG・GIF・WebPのドラッグと画像コピー、写真アプリのJPEG・HEIC・MOV・MP4のドラッグとコピー、生成した200 / 256 MB TIFFの読み出しを記録。追加のTIFF指定2ブラウザと写真2枚の共通宛先での書き出しも確認した。成功・キャンセル・クラッシュ・再試行を区別する。T007の変更案も保守者の「OKです。」で承認され、仕様と関連計画へ反映した。Phase 2以降は未着手。

以下の途中経過にある「未確認」「未完了」は、その測定時点の記録。現在の判定はこの段落と末尾の「T007 の確定事項」を正とする。製品への保存（T031・T037）、実アプリから遅延提供される大きなTIFF、単一receiverから複数ファイルが届く場合、SIGBUSの原因は未確認のまま残す。

- 対象: `claude/clever-knuth-udimb8` / `6f97268` と、このチャットで適用した確認スクリプトの未コミット修正
- 測定環境: macOS 26.6.2（25G83）、Mac15,12、メモリ 16 GiB、Swift 6.4.2。Safari 26.6.2、Chrome 157.0.8103.39、写真 11.0
- 現在のログ: `/tmp/folzio-pasteboard-probe.log`。16:36 JST の Safari JPEG のドラッグを `/tmp/folzio-tak88-probe-fix/safari-jpeg-drag-20261109-1636.log` に複製して保存。16:09 JST の初回クラッシュはこのチャットとバグ記録に要約（初回のブラウザ名は未特定）
- 先に、言語モード指定なしの起動で `ProbeController()` の MainActor 初期化エラーを確認。`-swift-version 6` で画面は表示できた
- JPEG のドロップ後、`_dispatch_assert_queue_fail`・`_swift_task_checkIsolatedSwift`・`NSBlockOperation main` を含むスタックで SIGTRAP。これは受け渡しの成功や file promise の非対応を示す結果としては扱わない
- reader を明示的な非隔離の `@Sendable` コールバックへ変更し、MainActor へ値だけを通知する修正を適用。起動部の MainActor も明示し、標準出力を即時出力に変更
- 修正後の自己検査: 画像の名前と中身、非圧縮 TIFF、バックグラウンド reader の成功・受け取りエラー・情報取得エラーと MainActor への通知が成功。通常モードと Swift 6 の型検査も警告なしで成功
- 修正後の Safari JPEG ドラッグでクラッシュせず、`readerCount=1`、`readerMainThread=false` を確認。ただし書き出しは `NSCocoaErrorDomain Code=3072`。Safari JPEG の画像コピーは下表のとおり確認。生成した200 / 256 MB TIFF は下表のとおり確認。他の形式・アプリや実アプリからの大きな TIFF は未確認。T006・T007 は未チェック。詳細は `.specify/bugs/tak-88-probe-actor-crash/` に記録する


- コミット: `6f97268` + このチャットの未コミットの確認スクリプト修正
- macOS・機種・メモリ: macOS 26.6.2（25G83）/ Mac15,12 / 16 GiB
- Swift の版: 6.4.2（実行は `-swift-version 6`）
- Safari・Chrome・写真アプリの版: 26.6.2 / 157.0.8103.39 / 11.0
- ログの保存先: 上記

| アプリ | データ | 操作 | 項目ごとの型・約束の fileTypes | マスク | 書き出された名前・容量・時間・readerCount またはエラー |
|---|---|---|---|---|---|
| Safari | JPEG | ドラッグ（16:36 JST） | 1項目。`public.jpeg`・`public.tiff`・URL・文字列・WebKit の型・約束の型。file URL なし。receivers=1、fileTypes=[public.jpeg] | 1（copy） | readerCount=1、0.038413秒、NSCocoaErrorDomain Code=3072（キャンセル）、readerMainThread=false。fileNames(before/requested/after) はすべて空、書き出された名前・容量は未取得 |
| Safari | JPEG | ドラッグ再試行（17:11 JST） | 1項目。public.jpeg・public.tiff・URL・文字列・WebKit・約束の型。file URL なし。receivers=1、fileTypes=[public.jpeg] | 1（copy） | fileNames(before/requested)=[]。約94秒後は通知なし・宛先空。その後17:19:41 JSTにreaderCount=1、seconds=511.181290、NSCocoaErrorDomain Code=3072（キャンセル）、readerMainThread=false、fileNames(after)=[]。名前・容量は未取得 |
| Safari | WebP（ケース名はPNG） | ドラッグ（17:31 JST） | 1項目。org.webmproject.webp・public.tiff・URL・WebKit・約束の型。receivers=1、fileTypes=[org.webmproject.webp]、file URL なし | 1（copy） | TIFF 2480836 bytes、readSeconds=0.032769。約束はfileNames(before/requested/after)=[]、readerCount=1、78.915685秒でNSCocoaErrorDomain Code=3072、readerMainThread=false |
| Safari | PNG（ローカルHTTP / 32×32） | ドラッグ（17:38 JST） | 1項目。public.png・public.tiff・WebKit・URL・約束の型。file URLなし。receivers=1、fileTypes=[public.png] | 1（copy） | PNG 188 bytes、readSeconds=0.000840、mainThread=true。fileNames(before/requested/after)=[]、readerCount=1、34.237098秒でNSCocoaErrorDomain Code=3072、readerMainThread=false |
| Safari | GIF（ローカルHTTP / 1×1） | ドラッグ（17:44 JST） | 1項目。com.compuserve.gif・public.tiff・WebKit・URL・約束の型。receivers=1、fileTypes=[com.compuserve.gif] | 1（copy） | TIFF 3370 bytes、readSeconds=0.008071、mainThread=true。fileNames(before/requested)=[]。現記録範囲ではreaderの通知・fileNames(after)・出力名なし |
| Safari | PNG（ローカルHTTP / 32×32、要求時機の診断版） | ドラッグ（19:04 JST） | public.png・public.tiff・WebKit・URL・約束の型。receivers=1、fileTypes=[public.png] | 1（copy） | PNG 188 bytes、readSeconds=0.001004。request-beginがdrop-returnより前。fileNames(before)=[]、requested/after=[sample.png]、readerCount=1、0.294085秒、188 bytes、regular=true、readerMainThread=false。元のPNGとcmpでバイト一致 |
| Chrome | JPEG | ドラッグ（17:19 JST） | 1項目。public.jpeg・public.url・約束の型・org.chromium.*。一般の types には public.tiff もあるが item[0].types にはない。receivers=1、fileTypes=[public.jpeg]、file URL なし | 18446744073709551615（copyを含む全マスク） | fileNames(before)=[]、requested/after=[image01.jpg]。readerCount=1、0.319460秒、image01.jpg、872744 bytes、regular=true、readerMainThread=false。file コマンドで JPEG / 1024×768 を確認 |
| Chrome | WebP（ケース名はPNG） | ドラッグ（17:33 JST） | 1項目。org.webmproject.webp・URL・org.chromium.*・約束の型。一般のtypesにはpublic.tiffもあるがitem[0].typesにはない。receivers=1、fileTypes=[org.webmproject.webp] | 18446744073709551615（copyを含む全マスク） | 選んだ画像の型なし（PNG等の直接読み出しなし）。fileNames(before)=[]、requested/after=[Nature-Positive-Travel-Tourism-in-Action-April-2024_Page_01_Image_0001-e1713779436322.webp]、1048620 bytes、regular=true、readerCount=1、0.300560秒、readerMainThread=false。fileコマンドでWebPを確認 |
| Chrome | PNG（ローカルHTTP / 32×32） | ドラッグ（17:38 JST） | 1項目。public.png・URL・org.chromium.*・約束の型。一般のtypesにはTIFFもあるがitem[0]にはない。file URLなし。receivers=1、fileTypes=[public.png] | 18446744073709551615（copyを含む全マスク） | PNG 188 bytes、readSeconds=0.000661。fileNames(before)=[]、requested/after=[sample.png]。readerCount=1、0.349061秒、188 bytes、regular=true、readerMainThread=false。実ファイルはPNG、元のsample.pngとcmpでバイト一致 |
| Chrome | GIF（ローカルHTTP / 1×1） | ドラッグ試行 | ドロップ欄へのdrag-enter記録なし | 未取得 | 保守者が「画像を動かしてもドラッグが始まらない」と回答。受信拒否・書き出し失敗とは扱わない。128×96のGIFでは後述の再試行でドラッグ・書き出し成功 |
| Chrome | GIF（ローカルHTTP / 128×96） | ドラッグ（17:59 JST） | com.compuserve.gif・URL・org.chromium.*・約束の型。receivers=1、fileTypes=[com.compuserve.gif] | 18446744073709551615（copyを含む全マスク） | 選んだ画像の型なし。fileNames(before)=[]、宛先の作成まで記録。requested/after・readerの通知・出力ファイルは未取得。次の画像コピー確認でプロセスがクラッシュ |
| Chrome | GIF（ローカルHTTP / 128×96） | 再起動後のドラッグ試行（18:13 JST） | drag-enterにはcom.compuserve.gif・URL・org.chromium.*・約束の型あり | 18446744073709551615（copyを含む全マスク） | drag-enterのみでdrop・receiveの記録なし。ドロップと書き出しは未確認 |
| Chrome | GIF（ローカルHTTP / 128×96） | ドラッグ再試行（18:23 JST） | 1項目。com.compuserve.gif・URL・org.chromium.*・約束の型。receivers=1、fileTypes=[com.compuserve.gif]。一般のtypesにTIFFもあるがitem[0]にはない | 18446744073709551615（copyを含む全マスク） | 選んだ画像の型なし（直接読み出しなし）。fileNames(before)=[]、requested/after=[sample-128.gif]。readerCount=1、0.308312秒、292 bytes、regular=true、readerMainThread=false。fileコマンドでGIF87a / 128×96、元ファイルとcmpでバイト一致を確認 |
| 写真 | JPEG（保守者指定） | ドラッグ（18:43 JST） | 1項目。public.jpeg・public.file-url・com.apple.photos.object-reference.asset・約束の型。receivers=1、fileTypes=[public.jpeg]。一般のtypesにはTIFFもあるがitem[0]にはない | 1（copy） | JPEG 50764 bytes、readSeconds=0.002396。fileNames(before/requested/after)=[]。readerCount=1、84.708279秒でNSCocoaErrorDomain Code=3072、readerMainThread=false。書き出し名・容量は未取得 |
| 写真 | HEIC（保守者指定、提供型はJPEG） | ドラッグ（18:45 JST） | 1項目。public.jpeg・public.file-url・com.apple.photos.object-reference.asset・約束の型。receivers=1、fileTypes=[public.jpeg]。一般のtypesにはTIFFもあるがitem[0]にはない | 1（copy） | 直接のJPEGデータは145272 bytes、readSeconds=0.001872。約束はfileNames(before)=[]、requested/after=[IMG_2454.jpeg]、readerCount=1、1.316468秒、2776034 bytes、regular=true、readerMainThread=false。sipsで出力がJPEG / 5712×4284と確認 |
| 写真 | MOV（保守者指定） | ドラッグ（18:50 JST） | 1項目。public.jpeg・public.file-url・com.apple.photos.object-reference.asset・約束の型。receivers=1、fileTypes=[com.apple.quicktime-movie] | 1（copy） | 画像表現はJPEG 471039 bytes、readSeconds=0.001322。約束はfileNames(before)=[]、requested/after=[IMG_2448.MOV]、readerCount=1、4.342186秒、4493346 bytes、regular=true、readerMainThread=false。fileコマンドでQuickTimeコンテナを確認 |
| 写真 | MP4（保守者指定） | ドラッグ（18:55 JST） | 1項目。public.jpeg・public.file-url・com.apple.photos.object-reference.asset・約束の型。receivers=1、fileTypes=[public.mpeg-4] | 1（copy） | JPEG表現6127 bytes、readSeconds=0.001339、mainThread=true。約束はfileNames(before/requested/after)=[]、readerCount=1、0.038567秒でNSCocoaErrorDomain Code=3072、readerMainThread=false。動画の書き出し名・容量は未取得 |
| 写真 | MP4（要求時機の診断版） | ドラッグ（19:10 JST） | Photosの型・public.jpeg・public.file-url・約束の型。receivers=1、fileTypes=[public.mpeg-4] | 1（copy） | JPEG表現6127 bytes、readSeconds=0.001735。request-beginがdrop-returnより前。fileNames(before)=[]、requested/after=[02-video-1s.mp4]、readerCount=1、0.379456秒、9584 bytes、regular=true、readerMainThread=false。fileコマンドでMP4コンテナを確認 |
| Safari | PNG（TIFF指定、要求時機の診断版） | ドラッグ（19:19 JST） | 項目にpublic.pngとpublic.tiff。receivers=1、fileTypes=[public.png] | 1（copy） | TIFF 7462 bytes、readSeconds=0.005270。request-beginがdrop-returnより前。fileNames(before)=[]、requested/after=[sample.png]。PNG 188 bytes、0.300809秒、readerCount=1、readerMainThread=false |
| Chrome | PNG（TIFF指定、要求時機の診断版） | ドラッグ（19:20 JST） | 全体のtypesにはTIFF、item[0].typesにはTIFFなし。receivers=1、fileTypes=[public.png] | 18446744073709551615（copyを含む全マスク） | 「選んだ画像の型なし」でデータは読んでいない。TIFFのnil・0秒とは扱わない。request-beginがdrop-returnより前。fileNames(before)=[]、requested/after=[sample.png]。PNG 188 bytes、0.287712秒、readerCount=1、readerMainThread=false |
| 写真 | 2枚選択（元形式は未特定、要求時機の診断版） | ドラッグ（19:21 JST） | 2項目にJPEG表現とfile URL。receivers=2、両方fileTypes=[public.png] | 1（copy） | 共通宛先04へ各1回の通知。receiver[0]はIMG_2442.PNG / 423589 bytes / 1.711105秒、receiver[1]はIMG_2450.PNG / 386001 bytes / 1.199418秒。両方regular=true、readerMainThread=false、before=[]、requested/afterに各名。両要求がdrop-returnより前 |
| Safari | PNG（通常版の要求時機修正後） | ドラッグ（19:47:25 JST） | 項目にPNG・TIFF・WebKitの型。receivers=1、fileTypes=[public.png] | 1（copy） | PNG 188 bytes、readSeconds=0.001045。request-beginがdrop-returnより前、accepted=true。fileNames(before)=[]、requested/after=[sample.png]。readerCount=1、0.298310秒、188 bytes、regular=true、readerMainThread=false。元PNGとcmpで一致。消費後に待機数2へ補充 |
| 写真 | 2枚選択（通常版の要求時機修正後） | ドラッグ（19:47:42 JST） | 2項目にPhotosの型・JPEG表現・file URL。receivers=2、fileTypesは[public.png]と[public.jpeg] | 1（copy） | 共通宛先にIMG_2450.PNG / 386001 bytes / 0.418679秒、image01.jpg / 872744 bytes / 0.440082秒。各readerCount=1、regular=true、readerMainThread=false。両request-beginがdrop-returnより前、accepted=true。before=[]、requested/afterに各名。消費後に待機数2へ補充 |
| Safari | JPEG の画像アドレス | アドレスコピー（17:11:46 / 17:11:52 JST） | 1項目。public.url・public.url-name・public.utf8-plain-text と WebURLsWithTitles 系の動的型。画像の型・約束の型なし | 対象外 | clipboard と clipboard-promises は changeCount=2116 で一致。receivers=0。保守者が「画像のアドレスをコピー」を選んだと回答。画像コピーの結果には算入しない |
| Safari | JPEG | 画像コピー（17:15:19 / 17:15:22 JST） | 1項目。public.tiff・com.apple.flat-rtfd・com.apple.webarchive・public.html。PNG・JPEG・file URL・約束の型なし | 対象外 | changeCount=2118で両ボタンの結果が一致。TIFF 2362798 bytes、readSeconds=0.002281、mainThread=true。receivers=0（約束なし） |
| Safari | WebP（ケース名はPNG） | 画像コピー（17:32:25 / 17:32:27 JST） | 1項目。public.tiff・com.apple.flat-rtfd・com.apple.webarchive・public.html | 対象外 | changeCount=2129で両ボタンの結果が一致。TIFF 2480836 bytes、readSeconds=0.002340、mainThread=true。receivers=0 |
| Safari | PNG（ローカルHTTP / 32×32） | 画像コピー（17:38:28 / 17:38:29 JST） | 1項目。public.tiff・com.apple.flat-rtfd・com.apple.webarchive・public.html | 対象外 | changeCount=2134で両ボタンの結果が一致。TIFF 7462 bytes、readSeconds=0.000541、mainThread=true。receivers=0 |
| Safari | GIF（ローカルHTTP / 1×1） | 画像コピー（17:45:12 / 17:45:13 JST） | 1項目。public.tiff・com.apple.flat-rtfd・com.apple.webarchive・public.html | 対象外 | changeCount=2139で両ボタンの結果が一致。TIFF 3370 bytes、readSeconds=0.000478、mainThread=true。receivers=0 |
| Chrome | JPEG | 画像コピー（17:20:10 / 17:20:11 JST） | 1項目。item[0] は public.png・public.html・org.chromium.internal.source-rfh-token・org.chromium.source-url。一般の types には public.tiff もあるが item[0].types にはない | 対象外 | changeCount=2121で両ボタンの結果が一致。PNG 1529491 bytes、readSeconds=0.000883、mainThread=true。receivers=0（約束なし） |
| Chrome | WebP（ケース名はPNG） | 画像コピー（17:33:20 / 17:33:21 JST） | 1項目。public.png・public.html・org.chromium.internal.source-rfh-token・org.chromium.source-url。一般のtypesにはpublic.tiffもあるがitem[0].typesにはない | 対象外 | changeCount=2131で両ボタンの結果が一致。PNG 1358880 bytes、readSeconds=0.003031、mainThread=true。receivers=0 |
| Chrome | PNG（ローカルHTTP / 32×32） | 画像コピー（17:39:21 / 17:39:22 JST） | 1項目。public.png・public.html・org.chromium.internal.source-rfh-token・org.chromium.source-url。一般のtypesにはTIFFもあるがitem[0]にはない | 対象外 | changeCount=2136で両ボタンの結果が一致。PNG 200 bytes、readSeconds=0.000447、mainThread=true。receivers=0。ケース名はChromだが、保守者の報告とorg.chromium.*の型からChromeと特定 |
| Chrome | GIF（ローカルHTTP / 128×96） | 画像コピー初回（17:59:23 JST） | public.png・public.html・org.chromium.internal.source-rfh-token・org.chromium.source-urlを列挙 | 対象外 | changeCount=2142。最初のPNGのbytes/readSecondsログ前にEXC_BAD_ACCESS / SIGBUSでクラッシュ。画像の読み出し完了も約束の受け取りも未確認 |
| Chrome | GIF（ローカルHTTP / 128×96） | 再起動後の画像コピー（18:13:26 / 18:13:28 JST） | item[0]はpublic.png・public.html・org.chromium.internal.source-rfh-token・org.chromium.source-url。一般のtypesにはTIFFもあるがitem[0]にはない | 対象外 | changeCount=2144で両ボタンの結果が一致。PNG 677 bytes、readSeconds=0.000637、mainThread=true。receivers=0。保守者が再起動後の成功を報告 |
| 写真 | JPEG（保守者指定） | コピー（18:43:57 / 18:43:58 JST） | item[0]はcom.apple.photos.object-reference.asset・public.jpeg・public.file-url・Photosの動的cookie型。一般のtypesにはTIFF等もあるがitem[0]にはない | 対象外 | changeCount=2146で一致。JPEG 50764 bytes、readSeconds=0.002960、mainThread=true。file URL型のデータは144 bytes、0.000644秒。receivers=0 |
| 写真 | HEIC（保守者指定、提供型はJPEG） | コピー（18:45:14 / 18:45:15 JST） | item[0]はcom.apple.photos.object-reference.asset・public.jpeg・public.file-url・Photosの動的cookie型。一般のtypesにはTIFF等もあるがitem[0]にはない | 対象外 | changeCount=2147で一致。JPEG 145272 bytes、readSeconds=0.002251、mainThread=true。file URL型のデータは135 bytes、0.001338秒。receivers=0 |
| 写真 | MOV（保守者指定） | コピー（18:50:44 / 18:50:45 JST） | item[0]はcom.apple.photos.object-reference.asset・public.jpeg・public.file-url・Photosのcookie型。一般のtypesにはTIFF等もあるがitem[0]にはない | 対象外 | changeCount=2149で一致。画像表現はJPEG 471039 bytes、readSeconds=0.002705、mainThread=true。file URL型のデータ135 bytes、0.000630秒。receivers=0 |
| 写真 | MP4（保守者指定） | コピー（18:55:59 / 18:56:01 JST） | item[0]はcom.apple.photos.object-reference.asset・public.jpeg・public.file-url・Photosのcookie型。一般のtypesにはTIFF等もあるがitem[0]にはない | 対象外 | changeCount=2151で一致。JPEG表現6127 bytes、readSeconds=0.001673、mainThread=true。file URL型のデータ144 bytes、0.000549秒。receivers=0 |

- 要求時機の診断版で写真MP4の書き出しが19:10 JSTに成功。ケース名はSafari / MP4だが、保守者の報告とPhotosの型から写真アプリと特定。ログを `/tmp/folzio-tak88-sync-probe/photos-mp4-success-20261109-1910.log` に複製。旧版と直接のJPEG表現の容量6127 bytesが一致し、同じ素材の再試行として記録する。ただしソースの元ファイルとのバイト比較はしていない
- 診断版では旧版でキャンセルとなったSafari PNGと写真MP4の2件で書き出しが成功した。要求をドロップ内で行い、宛先を先に用意する設計を採用する根拠になるが、全形式の再検証や一度のSIGBUSの解消を証明したとは扱わない。診断用コピーはリポジトリのスクリプトへまだ適用していない
- 写真MP4のログを `/tmp/folzio-tak88-clipboard-crash/photos-mp4-20261109-1856.log` に複製。約束の型public.mpeg-4は確認できたが、書き出しはキャンセル。画像表現のJPEGを動画そのものの受け取り成功とは扱わない。コピーの非画像型の容量 / readSecondsはcom.apple.photos.object-reference.asset=342 / 0.002742、cookie型=42 / 0.000540（bytes / 秒）
- 呼び出し時機の診断用コピーを `/tmp/folzio-tak88-sync-probe/pasteboard-probe-sync.swift` に作成。receivePromisedFilesを外側のTaskへ送らず、performDragOperationが返る前に呼ぶ。受け取りフォルダは `/tmp/folzio-tak88-sync-probe/run-sync-probe.py` がSwift起動前に16個作るため、UIスレッドでのフォルダ作成はしない。同じドラッグの受け取り先は共通。request-beginとdrop-returnの順序もログに出す。元のリポジトリのスクリプトには未適用
- 診断用コピーの通常モード / Swift 6 の警告なし型検査と、画像・TIFF・reader・providerの全自己検査は成功。19:04 JSTに保守者がSafari PNGを実行し、ドロップ内で要求した順序と書き出し成功をログで確認した。元の確認画像とのバイト一致も確認。ログ保存先は `/tmp/folzio-pasteboard-probe-sync.log`、複製は `/tmp/folzio-tak88-sync-probe/safari-png-success-20261109-1904.log`。旧版との違いは要求時機に加え、事前に作った一時フォルダを使うことも含むため、1回の比較だけで因果関係や他ケースの解消まで断定しない
- T006のアプリ・形式の主項目は試行して観測を記録したが、Safari等の約束のキャンセルと、未完了要求の後に一度起きたSIGBUSの原因は未確定。現行スクリプトではドロップを返した後のTaskとフォルダ作成を経てreceivePromisedFilesを呼ぶため、呼び出し時機の影響を切り分ける前に非対応と判断しない。PNG / TIFF両表現の型切り替え再測定も未実施。T006は未チェックで維持する
- 写真MOVのログを `/tmp/folzio-tak88-clipboard-crash/photos-mov-20261109-1850.log` に複製。public.jpegの表現もあるが、約束はcom.apple.quicktime-movieで、MOVの書き出しが成功。JPEGの読み出し時間を動画そのものの取得時間として扱わない
- 写真MOVコピーの非画像型の容量 / readSecondsはcom.apple.photos.object-reference.asset=345 / 0.005048、cookie型=42 / 0.000331（bytes / 秒）。約束ボタンの後に追加のPhotos cookie型が現れたが、receivers=0
- 写真アプリのJPEG・HEICのログを `/tmp/folzio-tak88-clipboard-crash/photos-jpeg-heic-20261109-1845.log` に複製。元の形式は保守者が選んだケース名による。HEICの元ファイル自体は検査していないが、実際に提供された画像の型と約束の型はJPEG、書き出しの中身もJPEGだった
- 写真HEICケースの直接JPEGデータ145272 bytesと、約束で書き出されたJPEG 2776034 bytesは別の表現として記録。同じものや同じ解像度とは扱わない
- 写真JPEGの約束のキャンセルは、HEICケースのドロップと同時刻に通知された。因果関係は未確認
- 両コピーにpublic.file-urlがあり、既存設計のfile URLを優先する経路に関係する。追加のGUIなし確認でfile URLの実体を解決しようとしたが、クリップボードが2147から2148へ変化していたため実行をスキップ。file URL型があることと、指すファイルの実体が確認できたことは区別する。パスや画像の中身は出力していない
- 写真JPEGコピーの非画像型の容量 / readSecondsはcom.apple.photos.object-reference.asset=338 / 0.005487、cookie型=42 / 0.000250。HEICケースは同型が339 / 0.002335、42 / 0.001372。約束ボタン時には追加のPhotos cookie型も現れたが、両ケースともreceivers=0（bytes / 秒）
- 18:23 JSTにChrome GIFのドロップと約束の書き出しが成功。ログを `/tmp/folzio-tak88-clipboard-crash/chrome-gif-drop-20261109-1823.log` に複製。画像コピーの成功と合わせ、再起動後の各操作の観測として記録する。再起動前のクラッシュがソース修正で解消したとは扱わない
- 17:59 JSTのChrome GIFのドラッグと画像コピーでクラッシュしたログは `/tmp/folzio-tak88-provider-fix/chrome-gif-crash-20261109-1759.log`、ダンプは `/Users/igachan/Library/Logs/DiagnosticReports/swift-frontend-2026-11-09-175929.ips`。メインスレッドのEXC_BAD_ACCESS / SIGBUSで、前2件のactor違反SIGTRAPとは区別。原因は未確定。詳細は `.specify/bugs/tak-88-probe-clipboard-crash/assessment.md`
- 保守者が再起動後に成功と報告し、18:13 JSTの画像コピーの成功をログで確認。ログは `/tmp/folzio-tak88-clipboard-crash/chrome-gif-restart-20261109-1813.log` に複製。非画像型の容量 / readSecondsはpublic.html=100 / 0.000500、org.chromium.internal.source-rfh-token=24 / 0.000488、org.chromium.source-url=22 / 0.000515（bytes / 秒）。再起動しただけで、今回のクラッシュに対するソース修正は行っていない
- 18:13 JSTのドラッグはdrag-enterのみでdropの記録がなかったが、18:23 JSTの再試行でドロップ・書き出し成功を確認。旧プロセスで待機していたSafari GIFの約束は、終了のため最終結果を取得できていない
- 1×1のGIFのSafariの結果と、Chromeでドラッグが始まらなかった観測のログを `/tmp/folzio-tak88-provider-fix/gif-small-20261109-1745.log` に複製。Safariの非画像型の容量 / readSecondsはcom.apple.flat-rtfd=603 / 0.000451、com.apple.webarchive=1957 / 0.000376、public.html=689 / 0.000574（bytes / 秒）
- 最初の1×1のGIFはsipsによるPNGへのデコードに成功したが、Chromeがドラッグを始めない原因はまだ未確定。ChromeのGIF非対応とは断定しない
- サイズなどの条件を切り分けるため、ImageIOで青地に黄色い四角の128×96のGIFを `/tmp/folzio-tak88-fixtures/sample-128.gif` に生成（292 bytes）。ImageIOでGIF型と画像のデコード・寸法を検査し、fileコマンドでGIF87a / 128×96、HTTP 200 / Content-type: image/gif / Content-Length: 292も確認。確認ページのGIF画像をこの新しいURLへ変更。Chromeで再試行し、画像コピーは再起動後に成功。18:23 JSTにはドラッグの書き出しも成功
- 確認ページのPNGのログを `/tmp/folzio-tak88-provider-fix/local-png-20261109-1739.log` に複製。Safariの約束のキャンセルはChromeのドロップと同時刻。ローカルHTTPの既知のPNGでもSafariの約束がキャンセルになったが、スクリプトの呼び出し時機はまだ切り分けておらず、Safari全体の非対応とは判断しない
- PNGコピーでの非画像型の容量 / readSecondsは、Safariがcom.apple.flat-rtfd=751 / 0.000363、com.apple.webarchive=2104 / 0.000351、public.html=689 / 0.000526。Chromeがpublic.html=96 / 0.000352、org.chromium.internal.source-rfh-token=24 / 0.000328、org.chromium.source-url=22 / 0.000333（bytes / 秒）
- 続くGIF確認用に、標準的な1×1のGIF89aの42 bytesを `/tmp/folzio-tak88-fixtures/sample.gif` に用意し、同じページへ追加。fileコマンドとHTTP 200 / Content-type: image/gif / Content-Length: 42を確認。Safariでは上表のとおり確認し、Chromeではドラッグが始まらなかった。型の受け渡し用の小さな静止画像であり、性能やアニメーションの検査ではない
- PNGのつもりで行った17:31〜17:33 JSTの操作は、ドラッグのfileTypesが両ブラウザともorg.webmproject.webpであり、Chromeの出力もWebPだったためWebPとして記録。PNGの元画像の確認には算入しない。コピー時のPNGやTIFFは提供された表現の型で、元画像がPNGであることを示さない
- 上記のログは `/tmp/folzio-tak88-provider-fix/intended-png-webp-20261109-1733.log` に複製。Safariの約束はChromeのドロップと同時刻に78.915685秒でキャンセル通知を受信。因果関係は未確認
- Safari WebPコピーの非画像型の容量 / readSecondsは、com.apple.flat-rtfdが1065004 / 0.001043、com.apple.webarchiveが1699099 / 0.001535、public.htmlが1847 / 0.000485。Chromeはpublic.htmlが194 / 0.001041、org.chromium.internal.source-rfh-tokenが24 / 0.000779、org.chromium.source-urlが159 / 0.000476（bytes / 秒）
- 次のPNG切り分け用に、自己生成サンプルlogo.svgの中身（PNG）を `/tmp/folzio-tak88-fixtures/sample.png` へ複製。fileコマンドでPNG / 32×32 / 188 bytesを確認。標準のPython HTTPサーバーを127.0.0.1:8878に限定して起動し、`/sample.png` のHTTP 200 / Content-type: image/png / Content-Length: 188を確認。ページは `http://127.0.0.1:8878/`。17:38〜17:39 JSTに両ブラウザで確認し、結果は上表に記録。ローカルHTTPでの切り分けとして一般のWebページの測定と区別し、性能測定の代替にはしない
- Chrome JPEG のログを `/tmp/folzio-tak88-provider-fix/chrome-jpeg-20261109-1720.log` に複製。ケース名は Safari のままだが、保守者の「Chrome JPEG 完了」の報告と org.chromium.* の型から Chrome の操作として記録
- Chrome JPEG のドラッグでは、JPEG データ872744 bytesを0.001136秒で読み出し、その後 file promise でも同じ容量の image01.jpg の書き出しが成功。コピーでは public.html が132 bytes / 0.000220秒、org.chromium.internal.source-rfh-token が24 / 0.000132、org.chromium.source-url が79 / 0.000112。PNG 以外の値は画像の読み出し時間とは扱わない
- Safari の再試行の receive[1726BDAC] は、Chrome のドロップと同時刻に511.181290秒でキャンセル通知を受信。両者の因果関係は未確認。これは約束の非対応やスクリプトのタイムアウトを証明する結果としては扱わない
- 17:15 JST に画像そのもののコピーを確認。ログは `/tmp/folzio-tak88-provider-fix/safari-jpeg-image-copy-20261109-1715.log` に複製。TIFF 以外の容量 / readSeconds は、com.apple.flat-rtfd が889128 / 0.001872、com.apple.webarchive が875072 / 0.000928、public.html が590 / 0.000273（bytes / 秒）
- 17:11 JST のコピーは、保守者の回答により画像アドレスのコピーと確定。URL・文字列のみの結果は、その操作の観測として記録する
- 17:11 JST のドラッグ再試行・コピーのログを `/tmp/folzio-tak88-provider-fix/safari-jpeg-drag-copy-20261109-1711.log` に複製。コピーでの容量 / readSeconds は、WebURLsWithTitles 系の動的型が146 / 0.000503と129 / 0.000373、public.url が79 / 0.000381、public.url-name が11 / 0.000511、public.utf8-plain-text が79 / 0.072388（bytes / 秒）。画像の読み出し時間としては扱わない
- Safari のドラッグの約束がキャンセルになった原因は未確定。確認スクリプトの呼び出し時機や別の画像での受け渡しは切り分けていない。17:12:43 JST の宛先フォルダ確認は読み取りのみ
- 16:37 JST の `clipboard` はケース名がドラッグのまま、`public.utf8-plain-text` 135 bytes だけを示した。「画像をコピー」の実施は確認できていないので、Safari JPEG コピーの結果には算入しない。
- コピーの後には「クリップボードを調べる」と「クリップボードの約束を書き出す」の両方を確かめる。
  `receivers=0` の場合も、その観測を記録する。上表はアプリ・形式・操作ごとに行を分け、実測値を記入する
- `fileNames(before)` が空でも、それだけでは約束が使えないとは判断しない

| 読み出すデータ | 生成元／アプリ | 実際の容量（bytes） | 型 | UI スレッドでの readSeconds | R5 の 0.2 秒の判断 |
|---|---|---|---|---|---|
| Safari の JPEG（今回の1画像） | Safari のドラッグ | 872744 | public.jpeg | 0.001321 | この1回は0.2秒未満。大きな画像や他の型を含めた採用判断は未確定 |
| Safari の JPEG（再試行） | Safari のドラッグ | 872744 | public.jpeg | 0.001274 | この1回も0.2秒未満。全体の採用判断は未確定 |
| Safari JPEG の画像コピー | Safari の画像コピー（実アプリからの提供） | 2362798 | public.tiff | 0.002281 | この1回は0.2秒未満。大きな画像の採用判断は未確定 |
| Chrome の JPEG | Chrome のドラッグ | 872744 | public.jpeg | 0.001136 | この1回は0.2秒未満。全体の採用判断は未確定 |
| Chrome JPEG の画像コピー | Chrome の画像コピー（実アプリからの提供） | 1529491 | public.png | 0.000883 | この1回は0.2秒未満。全体の採用判断は未確定 |
| Safari の WebP（ケース名PNG） | Safari のドラッグ | 2480836 | public.tiff | 0.032769 | この1回は0.2秒未満。全体の採用判断は未確定 |
| Safari WebP の画像コピー | Safari の画像コピー | 2480836 | public.tiff | 0.002340 | この1回は0.2秒未満。全体の採用判断は未確定 |
| Chrome WebP の画像コピー | Chrome の画像コピー | 1358880 | public.png | 0.003031 | この1回は0.2秒未満。全体の採用判断は未確定 |
| Safari のPNG（ローカル確認画像） | Safariのドラッグ | 188 | public.png | 0.000840 | 小さなfixtureによる型の確認。大きな画像の採用判断には使わない |
| Safari PNGの画像コピー（ローカル確認画像） | Safariの画像コピー | 7462 | public.tiff | 0.000541 | 同上 |
| Chrome のPNG（ローカル確認画像） | Chromeのドラッグ | 188 | public.png | 0.000661 | 同上 |
| Chrome PNGの画像コピー（ローカル確認画像） | Chromeの画像コピー | 200 | public.png | 0.000447 | 同上 |
| Safari のGIF（ローカル確認画像1×1） | Safariのドラッグ | 3370 | public.tiff | 0.008071 | 小さなfixtureによる型の確認。大きな画像の採用判断には使わない |
| Safari GIFの画像コピー（ローカル確認画像1×1） | Safariの画像コピー | 3370 | public.tiff | 0.000478 | 同上 |
| Chrome GIFの画像コピー（ローカル確認画像128×96、再起動後） | Chromeの画像コピー | 677 | public.png | 0.000637 | 小さなfixtureによる型の確認。大きな画像の採用判断には使わない |
| 写真JPEG | 写真アプリのドラッグ | 50764 | public.jpeg | 0.002396 | この1回は0.2秒未満。全体の採用判断は未確定 |
| 写真JPEGのコピー | 写真アプリのコピー | 50764 | public.jpeg | 0.002960 | 同上 |
| 写真HEICケース（提供型JPEG） | 写真アプリのドラッグ | 145272 | public.jpeg | 0.001872 | 同上 |
| 写真HEICケースのコピー（提供型JPEG） | 写真アプリのコピー | 145272 | public.jpeg | 0.002251 | 同上 |
| 写真MOVの画像表現 | 写真アプリのドラッグ | 471039 | public.jpeg | 0.001322 | JPEG表現の読み出し。この1回は0.2秒未満。動画の取得時間とは別 |
| 写真MOVコピーの画像表現 | 写真アプリのコピー | 471039 | public.jpeg | 0.002705 | 同上 |
| 写真MP4の画像表現 | 写真アプリのドラッグ | 6127 | public.jpeg | 0.001339 | JPEG表現の読み出し。この1回は0.2秒未満。動画の取得時間とは別 |
| 写真MP4コピーの画像表現 | 写真アプリのコピー | 6127 | public.jpeg | 0.001673 | 同上 |
| Safari PNG（ローカル確認画像、要求時機の診断版） | Safariのドラッグ | 188 | public.png | 0.001004 | 小さなfixtureの参考値。大きな画像の採用判断には使わない |
| 写真MP4の画像表現（要求時機の診断版） | 写真アプリのドラッグ | 6127 | public.jpeg | 0.001735 | JPEG表現の読み出し。動画の取得時間とは別 |
| Safari PNGのTIFF指定（要求時機の診断版） | Safariのドラッグ | 7462 | public.tiff | 0.005270 | 小さなfixtureの型切り替え確認。0.2秒未満 |
| 写真2枚のJPEG表現・項目0（要求時機の診断版） | 写真アプリのドラッグ | 156915 | public.jpeg | 0.004361 | PNGでの約束の書き出しとは別の表現。0.2秒未満 |
| 写真2枚のJPEG表現・項目1（要求時機の診断版） | 写真アプリのドラッグ | 103874 | public.jpeg | 0.002911 | 同上 |
| Safari PNG（通常版の要求時機修正後） | Safariのドラッグ | 188 | public.png | 0.001045 | 小さなfixtureの参考値 |
| 写真2枚のJPEG表現・項目0（通常版の要求時機修正後） | 写真アプリのドラッグ | 103874 | public.jpeg | 0.003301 | PNGの書き出し結果とは別の表現。0.2秒未満 |
| 写真2枚のJPEG表現・項目1（通常版の要求時機修正後） | 写真アプリのドラッグ | 872744 | public.jpeg | 0.008024 | 約束での取得時間とは別。0.2秒未満 |
| 通常のWeb画像の数MBの表現 | 上記Safari JPEG / WebPコピー等 | 2362798 / 2480836 | public.tiff | 0.002281 / 0.002340 | 上記の実測を参照。異なる画像・遅延条件全般は保証しない |
| 約 200 MB の TIFF | スクリプトの即時提供（17:24 JST） | 200013546 | public.tiff | 0.008885 | この1回は0.2秒未満。実アプリの遅延提供の結果とは分ける |
| 約 256 MB の TIFF | スクリプトの即時提供（17:24 JST） | 256016210 | public.tiff | 0.013577 | この1回は0.2秒未満。実アプリの遅延提供の結果とは分ける |
| 大きな TIFF（実アプリからコピーできる場合） | 未記入 | 未計測 | 未確認 | 未計測 | 未判断 |

- 200 / 256 MB TIFF のログを `/tmp/folzio-tak88-provider-fix/generated-tiff-20261109-1724.log` に複製。両方とも generatedTIFF の容量と読み出し容量が一致し、clipboardWrite=true、mainThread=true。各1回の測定
- 200 MB: 17:24:09 JST に生成・書き込み、writeSeconds=0.101820、17:24:24 JST に読み出し（changeCount=2123）。256 MB: 17:24:43 JST に生成・書き込み、writeSeconds=0.104785、17:24:47 JST に読み出し（changeCount=2124）。書き込み時間と読み出し時間は別に扱う
- 即時提供の結果を、ブラウザ・写真アプリの遅延提供の計測結果として扱わない
- `cat.png`（JPEG）の自己ドラッグ（2026-11-09 16:40 JST）: receivers=1、fileTypes=[public.png]、マスク=1（copy）、fileNames(before)=[]、fileNames(requested)=[cat.png]。その後、書き出し側のキュー問い合わせで SIGTRAP。fileNames(after)・readerCount・ファイルの結果は未取得。ケース名は Safari JPEG のままだが、保守者の報告と requested の名前から自己ドラッグと特定
- 上記のログを `/tmp/folzio-tak88-provider-fix/cat-crash-20261109-1640.log` に複製。ダンプでは `com.apple.FileCoordination.3` / `NSFileProviderXPCMessenger` / `_checkExpectedExecutor` を確認
- キュー問い合わせの nonisolated 指定と、Objective-C 入口を通る provider の回帰確認を追加。2026-11-09 16:59 JST、保守者から「落ちずに動作しました」と報告。ログで両方の自己ドラッグの書き出し成功を確認。詳細は `.specify/bugs/tak-88-probe-provider-actor/`
- 成功ログの複製: `/tmp/folzio-tak88-provider-fix/self-drag-success-20261109-1659.log`。ケース名は空だが requested・after の名前と実ファイルからサンプルを特定

| 自己ドラッグのサンプル | 約束の型 | マスク | fileNames（before → requested → after） | 書き出し結果 | readerCount / readerMainThread | 実ファイルの中身 |
|---|---|---|---|---|---|---|
| cat.png | public.png、receivers=1 | 1（copy） | [] → [cat.png] → [cat.png] | regular=true、719 bytes、0.041559秒 | 1 / false | file コマンドで JPEG / 32×32 を確認 |
| logo.svg | public.png、receivers=1 | 1（copy） | [] → [logo.svg] → [logo.svg] | regular=true、188 bytes、0.034727秒 | 1 / false | file コマンドで PNG / 32×32 を確認 |

- 19:19〜19:21 JSTの追加3件を `/tmp/folzio-tak88-t006-final/additional-three-20261109-1921.log` に保存。ケース名の「PING」はPNG、「Chrom」はChromeとして、既知の確認画像・保守者の操作・アプリ固有の型から整理した。
- 追加3件の宛先は `/tmp/Folzio-Probe-Sync-h2yixv4e/{02,03,04}`。`file`で02/03のsample.pngはPNG / 32×32、04の2枚はともにPNG / 1179×2556と確認。画像の中身を表示せずメタデータだけ検査した。
- 写真2枚は「2つのreceiverが各1ファイルを返した」成功であり、「1つのreceiverが複数回readerを呼ぶ」実測とは区別する。2枚の元形式は未特定。縮小JPEG表現とPNGの出力ファイルは別に扱う。
- T006は測定・記録完了。診断版での成功は、旧版の全キャンセルやSIGBUSの原因が解明・修正されたことを意味しない。製品への保存と回帰はT031・T037で確認する。
- 通常版の修正後GUIを保守者が実施（19:47 JST）。ケース名は空だが、依頼した2ケースの完了報告、WebKit / Photosの型、出力名から上表へ整理。ログを `/tmp/folzio-tak88-t006-final/regular-probe-gui-success-20261109-1947.log` に保存した。
- 通常版の実ファイルは `file` でsample.png=PNG / 32×32、IMG_2450.PNG=PNG / 1179×2556、image01.jpg=JPEG / 1024×768と確認。Safariのsample.pngは元の確認画像とバイト一致。写真の2つの出力はPNGとJPEGであり、診断版の2枚ともPNGだった選択とは区別する。
- 通常版でも起動時に待機数2、各ドロップ後に待機数2への補充をログで確認。GUIで書き出し要求と結果まで確認できた。以前のキャンセル全件やSIGBUSの原因が解明したとの判断はしない。
- 要求時機修正後の `scripts/dev/check-all.sh` は176件のPython検査を含め全件成功（ログ `/tmp/folzio-tak88-t006-final/check-all.log`）。その後は検証記録だけを更新し、製品Sources / Testsは変更していない。
- 複数のファイルを書き出す約束（利用できる場合）での `readerCount`: 未確認

## T007 の確定事項（2026-11-09・保守者承認済み）

T006の実測に基づく以下の案を保守者が「OKです。」と承認した。spec・plan・research・contractsへ反映し、data-model・後続タスク・quickstartも整合させてT007をチェックした。製品のSources / Testsは変更していない。

| 論点 | 確定した内容 | 実測と限界 |
|---|---|---|
| 登録する画像の型（R2・R5） | file URL・NSFilePromiseReceiver.readableDraggedTypesにPNG・JPEG・TIFFを追加。直接データは各項目のtypesからPNG → JPEG → TIFFで1つ選ぶ | PNG・JPEG・TIFFを実測。全体のtypesに合成されるTIFFだけでは読み出しを選ばない。HEICの直接データは今回未観測で、固定リストへ追加しない |
| 約束の種類（FR-348） | 識別子の文字列列挙ではなくUTTypeの適合で画像・対応動画を判定し、従来案どおり不明も許す。PDF・SVG等の除外と最終的な中身の検査は残す | public.png / public.jpeg / org.webmproject.webp / com.compuserve.gif / com.apple.quicktime-movie / public.mpeg-4を観測。写真HEICケースも提供はJPEGだった |
| 一般のペーストボード（R11） | 今回の対象に一般クリップボードの約束の受け取りは含めない。file URL → 画像データの順。約束だけではペーストを有効にしない | 全コピーでreceivers=0。API全般が一般クリップボードで使えないと証明したのではなく、今回の対象アプリから提供がなかったという判断 |
| UIスレッドでの読み出し（R5） | ドロップ / ペーストの実行中に選んだNSPasteboardItemのデータだけを同期取得し、デコード・変換・書き込みはバックグラウンド。256 MB超は取得直後に拒否 | 実アプリの画像表現は最大2480836 bytes・0.032769秒、即時提供TIFFは200013546 bytes / 0.008885秒、256016210 bytes / 0.013577秒。すべて0.2秒未満。遅延提供の大きなTIFFは未測定で、将来0.2秒超を観測したら再評価する |
| マスク（FR-356） | .copy必須、修飾キーで変えない | Safari・写真は1、Chromeは全マスク。全てcopyを含む |
| 約束の要求時機（R3） | 事前作成した受け取り先を使い、全receiverへのreceivePromisedFilesをacceptDrop内で呼んでから返す。readerの完了だけを非同期に待つ | 診断版でSafari PNG・写真MP4・追加3件が成功。要求をTaskとフォルダ作成後まで遅らせない。旧版との比較には宛先の準備方法・場所の違いも含む |

### 共通の宛先と一時フォルダ（FR-350・FR-357・R3・R4・R10の確定内容）

現行のmacOS 27.2 SDKのNSFilePromiseReceiver.hも「同じドラッグの全receiverへ同じdestination」を要求する。実測でも写真2枚を共通宛先へ各1回の通知で書き出せた。従来案の「約束ごとの別フォルダへ書き出させる」は取り下げ、次の本文へ改める。

- **FR-350の確定内容**: 起動ディスクのOSの一時領域のFolzio-Import/<UUID>に、受け取り用と検査用のフォルダをバックグラウンドで事前作成する。ドラッグ元へ知らせるのは受け取り用フォルダだけ。同じドラッグの全ての約束へ、この共通フォルダを渡し、ドロップ処理を返す前に書き出しを要求する。
- 準備済みのフォルダを操作ごとに1組確保して背景で補充する。準備できていない間は約束のドラッグを受け付けず、ホバーやドロップのUIスレッドでフォルダを作らない。起動時の残存フォルダの掃除と新規フォルダの作成は順に行う。
- 宛先と同じボリュームへの事前作成は宛先未確定のため行わない。検査済みファイルと宛先が同一ボリュームなら移動、異なるならコピーする。旧案の「宛先と同じボリュームを優先する」条件はこの受け取りについて改める。外部ボリュームへは一時領域と宛先の両方に容量が必要となる。
- **FR-357の確定内容**: readerが報告した通常ファイルだけを対象とし、realpathで解いた親が共通の受け取り用フォルダであることを確認する。readerが有効な間に、専用キュー上で通知ごとの別名の複製を検査用フォルダへ作る。MainActorへ通知してreaderを返した後に元ファイルを読み始めない。検査と保存はその複製だけを使い、拡張属性を保つ。
- **同名の約束（EC-243の補足）**: 別のreceiverが同じ実体パスを報告した場合は、上書き前の内容を確実に保存できないため操作全体を失敗とし、宛先へ保存しない。ドラッグ元が別の出力名へ解決した場合と、検査後の拡張子補正で宛先名が重なる場合は、従来どおり連番にする。共通宛先で同名の出力を上書きさせずに受け取れるとは保証しない。
- 待機用を含むフォルダの記録・容量監視・取り消し・打ち切り後の掃除は既存のR3・R10の制約を維持する。単一receiverから複数ファイルが届く場合と同名衝突は、今後の自動テストで固定する（今回の2枚の実測では未検証）。

### コピーの契約（EC-241・US78-AS8・FR-354・R11の確定内容）

- **EC-241の確定内容**: ドラッグはfile URL → 約束 → 画像データ。一般クリップボードはfile URL → 画像データとする。file URLがあれば既存経路を優先し、その失敗を画像表現への切り替えで隠さない。
- **US78-AS8の確定内容**: 写真アプリからコピーし、file URLと縮小した画像データがあるときは、file URLの項目を既存のコピー経路で保存し、縮小画像を使わない。元のHEIC等の形式が保たれるとは約束しない。
- **FR-354の確定内容**: file URLがないときは、一般クリップボードの画像データをPNGで保存できる。約束だけでは有効にしない。移動ペーストは従来どおりfile URLがあるときだけ有効。
- 写真のコピーにfile URL型があることは実測したが、指すファイルの実体・保存結果までは確認していない。動画のコピーにもJPEG表現があるため、それを動画の取得成功と扱わない。file URL経路での実際の保存はT037、ドラッグでの優先経路はT031で必ず確かめる。

### 残る確認とゲート

- 確認スクリプトの要求時機の修正候補を `/tmp/folzio-tak88-t006-final/pasteboard-probe-ready.swift`、差分を同じ場所のprobe-ready.patchに用意した。起動後に受け取りフォルダを背景で2個用意・消費後に補充し、準備不足時はドロップを拒否する。16個を外部スクリプトで事前作成する診断版の制限を除く。通常の確認スクリプトへ同じ候補を適用した。通常モード / Swift 6の警告なし型検査と、Swift 6の全自己検査（フォルダ準備の背景実行・未準備時の拒否・補充を含む）は成功。適用後の通常スクリプトそのものも、19:47 JSTにSafari PNG・写真2枚で要求順序・書き出し・フォルダ補充の成功を確認した。記録は `.specify/bugs/tak-88-probe-request-timing/`。
- 17:59のSIGBUSは原因未確定の別件として残す。上記の変更で修正されたとは扱わない。LLDBの再試行は行わない。
- 保守者の承認を仕様本文と関連計画へ反映し、T007を完了にした。この引き継ぎ作業ではPhase 2以降へ進まない。製品のGUI確認はT031・T037として残す。


## Phase 3 のローカル検証（T021〜T031、2026-11-09）

- 対象: `b517f16` を基点にしたPhase 3の作業ツリー。コミット・pushとCI確認を進める。T030と、残る手動確認を含むT031は未チェック。
- 環境: macOS 26.6.2（25G83）/ arm64、Apple Swift 6.4.2。CIのSwift 6.0での確認はT030で行う。
- `swift build` 成功。終了処理の修正後に、`swift test --no-parallel --skip FolzioPerformanceTests` でCore 1,078件・App 52件、計1,130件が成功。
- `scripts/dev/check-all.sh` 成功（Python 179件、スキップなし）。`git diff --check` 成功。
- 名前付きペーストボードで、画像の型、URL・文字列だけ、PDFを示す実際のNSFilePromiseProvider、PNG/JPEG/TIFFの優先順、画像とURLの項目ごとの対応を確認。ホバーの判定が画像データを要求しないこと、通し番号ごとに型を一度だけ調べること、3つの実ビューの登録型とcopyマスクをテストした。
- 受け取り先の背景作成・未準備時の拒否・補充、共通宛先への同期的な要求開始、readerを返す前の複製、単一receiverの複数ファイル、重複通知、別receiverの同じ実体パスの拒否をテストした。
- 60秒・600秒の打ち切り、容量超過、受け取り中と検査中の取り消し、遅延到着の拒否と掃除、部分失敗、名前の連番、独立した操作とパネルの行、最後の操作の取り消し、確認の直列化、終了時の掃除をテストした。確認の返答待ちのままでも終了時の掃除が完了することを含む。
- 保存確認はcopyの方針、実転送は同一ボリュームmove・別ボリュームcopyになること、宛先だけの更新通知、受け取り中と確認中の宛先消失・書き込み不可、キャンセル時に失敗を示さないことを確認した。別ボリュームの方針は引数を差し替えた自動テストであり、外部ボリュームへの実保存は未確認。

### 時間制限のあるテストの結果

- 初回の`swift test`の並列実行は、Coreの既存の時間制限を持つ7件（重複reload、内容更新2件、zipの表示・先読み2件、画像ロードの終了、ファイル監視）に失敗。Core以外は成功した。
- CIと同じ直列設定で全通常テストを2回実行し、両方で全件成功した。初回の失敗原因は未確定。
- 性能テストは初回27件すべて成功。続く`swift test --filter FolzioPerformanceTests`は25件成功、次の2件が基準超過。結果の差を記録し、性能テストが常に成功したとは扱わない。負荷による変動かどうかを含め原因は未確定で、変更前との同条件の比較とCIの結果も未確認。

| 基準を超過した性能テスト | 再実行の実測 | 基準 |
|---|---|---|
| 10,000件のフォルダに戻った時の最初の表示 | 1.010202542秒 | 1秒未満 |
| フォルダ名変更後の検索結果10,000件の反映 | 中央値0.104689875秒（初回0.081755375秒） | 0.1秒未満 |

- ローカルログ: `/tmp/folzio-tak88-phase3/` の`build-final.log`・`tests-final.log`・`check-all.log`。初回の通常・性能テストは`tests.log`、直列の1回目は`tests-serial.log`、性能の再実行は`performance.log`。
- `scripts/make-app.sh` 成功。保守者にFolzioを終了してから`open .build/Folzio.app`で起動し、3ペインの表示とSafariのPNGのフォルダへのドロップ保存を確認するよう依頼し、「できました」と回答を得た。T031のうち、この2点を成功として記録する。画像の容量・保存先・バイト一致・quarantineは未確認。
- T031の残るブラウザ形式と写真アプリからの保存、宛先ごとの操作、進捗パネルとキャンセル、宛先の失敗、同時操作、安全性、検索結果へのドラッグ、反応時間の手動確認は保守者の実施待ち。ペーストの実装・確認（Phase 4）には未着手。


## Phase 3のCIと追加手動確認（2026-11-10記録）

- 実装コミット `6c139d05dc75b76d05104ded76e4cf70cf59be18` を指定ブランチへpush。GitHub CLIで新規実行し、結果・ログ取得と再実行はGitHub MCPで行った。
- [macOS Swift CI 42635155008](https://github.com/yoshidax/folzio-dev/actions/runs/42635155008) はmacOS 15 / arm64、Xcode 16.0 / Swift 6.0で実行。両方の試行で対象SHAをcheckoutしたことをログで確認した。公開用書き出し、build、確認スクリプトの自己検査、通常テスト1,130件が成功。
- 初回job `129221267446` は性能テスト27件中24件成功・3件失敗。再実行job `129282094366` は25件成功・2件失敗。ステップがcontinue-on-errorのためジョブ全体はsuccessだが、性能テスト全成功とは扱わない。2回とも全ログの結果と末尾を読んで確認した。

| 試行 | 基準を超過した性能テスト | 実測 | 基準 |
|---|---|---|---|
| 初回 | 24 MP JPEGのデコード | 0.669743291秒 | 0.5秒未満 |
| 初回 | フォルダ名変更後の検索結果10,000件の反映 | 中央値0.103652542秒 | 0.1秒未満 |
| 初回 | zip 200,000件からのスライドショー候補抽出 | 0.247167417秒 | 0.2秒未満 |
| 再実行 | 50,000件に対する256件のバッチ処理 | 0.138958375秒 | 0.1秒未満 |
| 再実行 | zip 200,000件からのスライドショー候補抽出 | 0.221263292秒 | 0.2秒未満 |

- 性能で失敗する項目は試行で変わった。原因は未確定で、変更前との同条件での比較は未実施。6c139d0で変わったCoreはShortcutCatalog・ShortcutCommandだけで、性能テストと上記の処理本体は変更していない。しきい値は変更していない。

### T031の追加確認

| 保守者がFolzio本体で行った確認 | 報告 | 実体の追加確認 |
|---|---|---|
| Chrome JPEG・PNGのドラッグ | 両方保存できた | 下記の保存先でJPEG・PNGのヘッダーとquarantineを確認 |
| Safari JPEG・GIF・WebP、Chrome GIF・WebPのドラッグ | すべて保存できた | JPEG・GIFのファイルは下記に存在。WebPは別の保存先のため未検査 |
| 写真アプリのJPEG・HEIC | どちらもJPEGとして保存された | 元のHEIC形式を保持する保証はないため、JPEGへの変化を失敗には数えない |
| 写真アプリのMOV・MP4 | どちらもサムネイルのJPEGとして保存された | **動画保存は失敗**。動画の実体の成功・再生成功には数えない |

`/Users/igachan/Desktop/pics` で読み取り確認したファイル:

| ファイル | バイト | fileの判定 | quarantineの印 |
|---|---|---|---|
| image01.jpg | 872744 | image/jpeg | 有・Chrome |
| image02.jpg | 738666 | image/jpeg | 有・Chrome |
| image03.gif | 30692 | image/gif | 有・Chrome |
| sample.png | 188 | image/png | 有・Chrome |
| sample-128.gif | 292 | image/gif | 有・Chrome |

- sample.pngとsample-128.gifは `/tmp/folzio-tak88-fixtures/` の同名fixtureとバイト一致。これらのファイルだけでは各ブラウザ・各操作への対応を断定しない。
- 保守者が示したWebPの保存先は `/Users/igachan/Downloads/release-candidate-1eff687e4529038bc6bdaea5cddc4518911d08cb-42448877124-1/名称未設定フォルダ/chrome`。権限を指定してもディレクトリ列挙がOperation not permittedとなり、中身・quarantineは未確認。保存できたという報告と実体の検査を区別する。
- 写真アプリの失敗を受け、実行中のアプリが `/Users/igachan/projects/folzio/.build/Folzio.app/Contents/MacOS/Folzio` であることを読み取り確認した。

### 写真アプリの優先順位の明確化と修正（photos-video-thumbnail）

- 診断: `.specify/bugs/photos-video-thumbnail/assessment.md`。US77-AS8の動画保存と、file URLの無条件優先が衝突するため、仕様の明確化として扱う。
- 2026-11-10、保守者が記録IDと「写真アプリのドラッグに受け取り可能な約束があればfile URLより優先する」変更を「このIDと変更案で進める」と承認。specのSession 2026-11-10、計画・契約・データモデル・quickstart・T044/T045に反映した。品質チェックは16/16を維持。形式エラー0、既存警告88件はbaselineと同数、ID重複なし。
- CoreにisPhotosDrag（既定false）を追加し、Appは全項目にPhotosの型があるかを渡す。ExternalDragのfile URL取得前とExternalImageDragは同じ通し番号のキャッシュを使う。写真アプリの約束を選んだ後にJPEGやfile URLへ切り替えない。Finderなど写真アプリ以外のfile URL、一般クリップボードの規則は維持する。
- 回帰テストを先に追加し、旧コードでは新しい選択APIが未実装で失敗することを確認。Core/Appの対象29件が成功し、正式なゲートでswift build、全通常テスト1,135件（Core 1,080・App 55）、規約チェック（Python 179件）が成功した。ログは `/tmp/folzio-tak88-photos-fix/`。
- 修正ビルドでのMOV・MP4の保存・再生と、起動の手動再確認は未実施。上記CIは6c139d0に対するものであり、今回の修正のCIではない。修正のコミット・push・CIを行うT030と、残る手動確認のT031は未チェック。Phase 4は未着手。
- 進捗・取り消し・宛先の失敗を確認するため、既存確認スクリプトのドラッグ元から `/tmp/folzio-tak88-phase3/delayed-provider.swift` を用意した。書き出しは専用キューで20秒後に行う。型検査とGUIを開かないJPEG/PNGの自己検査は成功。GUIでこのドラッグ元からFolzioへ渡す確認は未実施。


## T031: MOVの書き出し時間と取消後のエラー（2026-11-10）

- 保守者は約40秒の携帯動画のコピーを試し、1回は約1分の受信後にFolzioの「取り消す」を押してエラー画面が出たと報告した。追加確認で、アプリは終了していないと回答。Folzio・Photosのプロセスは両方存在し、新しい両アプリのクラッシュレポートも未検出。クラッシュが再現したとは扱わない。
- スクショの「書き出し結果」はIMG_1134.MOVの出力先UUID内のreceivedに保存するアクセス権がないと表示。Folzioのエラー画面と文言・構成が違い、写真アプリ側の表示と考えられる。調査時にそのUUIDの一時領域は消えていた。
- 速度の追加比較: 保守者が約40秒・432 MBの素材について、**写真アプリ→Finder**は約23秒、写真アプリ→Folzioも同程度と報告。Finderでは処理中の状態が分からず、Folzioでは進捗が分かるためUXが良いとの評価。比較先は写真アプリ→Finderとの訂正を受領した。初回の約1分と約23秒の比較は別々の観測として残し、異常なFolzioの速度低下が再現したとは断定しない。
- Desktop/picsに存在する7件の動画をfileで読み取り確認し、6件がvideo/quicktime、1件（02-video-1s.mp4）がvideo/mp4だった。すべてPhotosのquarantine属性あり。IMG_1134.MOVは145803301 bytes。この保存ファイルと432 MBと報告された元の素材のバイト対応は未検査であり、同一サイズを保持したとは扱わない。写真アプリの動画がJPEGになる問題の修正後、動画の実体が保存されることは確認できている。
- 取消の診断・承認は `.specify/bugs/promise-cancel-cleanup/assessment.md`、実装はfix.md、検証はtest.mdに記録。受け取り先の削除を最後のwriterの完了まで遅らせ、receiverを保持する。取消時にUIと保存は止める。保持中の期限・容量を監視し、打ち切り後の遅い通知も掃除する。
- 修正前の2件の自動再現はフォルダ消失で失敗。修正後の全通常テスト1,145件（Core 1,082件・App 63件）、ビルド、規約チェック（Python 179件）、make-appが成功した。続いて保守者による下記のGUI確認で元の取消症状が解消した。T030の修正分のコミット・CIとT031全体は未完了、Phase 4は未着手。
- ローカル診断はLoggerのsubsystem `local.folzio.Folzio` / category `Import`。段階と時間だけを記録し、元のURL・ファイル名・保存先は含めない。reader.durationは複製、checked.durationは検査と準備、finished.durationはsaving以降（衝突の判断待ちを含む）。confirmingからsavingの間で確認待ちを区別する。

### 取消修正後のGUI再確認（2026-11-10）

- 保守者へ修正した `.build/Folzio.app` で同じPhotos MOVを空の `/Users/igachan/Desktop/pics/TAK88-cancel-check` へドラッグし、Folzioの受け取りパネルで取り消し、約1分待つ確認を依頼。「写真アプリにエラーが出ず、保存先が空のまま」に対し「期待通りです」と回答を得た。
- こちらの読み取り確認でも保存先は空。pendingImportFoldersの記録は未使用の待機用2組だけで、各フォルダには空のreceivedとcheckedのみ存在した。今回の取消操作のデータや保存ファイルは残っていない。
- Loggerの実機イベントは捕捉できなかったため、今回の受信・検査・保存時間の数値は未計測とする。自動テストの時間を実測値の代用にはしない。
- promise-cancel-cleanupの元症状はローカル検証済み。T030の修正後CIと、T031の宛先・同時受信・キーボード取消・安全性・性能など残る項目は未完了。Phase 4には進まない。

## Phase 3修正後のCIと同時受信（2026-11-10）

- 修正を `a3e9065d31ea90e3b3716dc65c5045a1e3d060f3` として指定ブランチへpush。[macOS Swift CI 42694084414](https://github.com/yoshidax/folzio-dev/actions/runs/42694084414)、job 129421171935の全ログと末尾を確認し、このSHAをcheckoutしたことを確認した。macOS 15 / arm64、Xcode 16.0 / Swift 6.0。
- 公開用書き出し、検証スクリプト、build、pasteboard-probe自己検査、通常テスト1,145件が成功（175.180秒）。性能は27件中22件成功・5件基準超過（163.470秒）。continue-on-errorによりジョブはsuccessだが、性能を含む全件成功とは扱わない。しきい値は変更せず、成功するまでの再実行は行わない。原因と変更前との同条件比較は未確定。

| 基準を超過した性能テスト | 実測 | 基準 |
|---|---|---|
| 24 MP JPEGのデコード | 0.962962667秒 | 0.5秒未満 |
| 10,000件の列挙・ソート | 1.220698375秒 | 1秒未満 |
| 10,000件のフォルダに戻った時の最初の表示 | 1.0585635秒 | 1秒未満 |
| 50,000件に対する256件のバッチ処理 | 0.116112875秒 | 0.1秒未満 |
| zip 200,000件からのスライドショー候補抽出 | 0.215178625秒 | 0.2秒未満 |

- 保守者が20秒遅延する確認用ドラッグ元からcat.pngをTAK88-concurrent-A、logo.svgをTAK88-concurrent-Bへ続けてドロップし、2行の表示後にFolzioで⌘.を実行。「Aはcat.jpgとして保存され、Bは空」「Bだけ取り消せた」の両方を確認した。こちらでもAにcat.jpg（719 bytes、image/jpeg、quarantineあり）、Bは空と確認。取消・完了した受信の一時記録は残らず、待機用2組のみだった。拡張子が中身に合わせて補正されたこと、最後の操作だけの取消と他方の保存を実機で確認済み。
- 次に同じcat.pngをAへドロップして既存cat.jpgの名前を編集中に⌘.を実行。**名前の編集は取り消されなかった**。受信は継続し、Escで編集を終了した後に「両方残す」で2件保存できたと回答。Aのcat.jpgとcat 2.jpgはいずれも719 bytesのimage/jpegと実体を確認した。同名保存の成功と、編集取消の失敗を区別する。FR-363・quickstartの編集取消に対して要調査。受信を誤って取り消す問題は今回発生しなかった。
- T030の今回のコミット・push・CI結果確認は完了。T031は上記の編集取消、宛先ごとの操作、宛先失敗、確認の直列化、強制終了後の掃除、性能などが残るため未チェック。Phase 4は未着手。

### 編集中の⌘.の修正とローカル検証（rename-cancel-shortcut、2026-11-10）

- 保守者がIDと「編集中の⌘.を既存の編集取消へ渡し、受信は続ける」修正を承認。診断は `.specify/bugs/rename-cancel-shortcut/assessment.md` に記録した。承認済みFR-363への実装不一致であり、仕様の本文は変更しない。
- MainMenuのルートを小さなNSMenuの型にし、Commandのみのピリオド・テキスト編集中・シートとモーダルなしの場合、実フィールドエディタへcancelOperationを渡す。受信の判断と名前の確定処理には変更を加えず、ほかのキーと非編集中の処理はAppKitへ渡す。
- 修正前に受信なし・ありの2ケースで編集取消の失敗を自動再現。修正後は関連33件、swift build、全通常1,151件（Core 1,082件・App 69件）、規約チェック（Python 179件）、make-app、git diff --checkが成功。ログは `/tmp/folzio-tak88-rename-fix/`。
- 今回のGUIは再確認待ちでpartial。保守者へ最新アプリでの3ペイン表示、受信なし・ありの編集中の⌘.、非編集中の受信取消を依頼した。今回の追加修正のコミット・CIは未実施のためT030を未チェックに戻す。T031とPhase 4以降は未完了。

### 編集中の⌘.のGUI再確認（2026-11-10）

- 最新の `.build/Folzio.app` へ起動し直した保守者から、次の3項目すべて成功の回答を得た。
  - 3ペインが表示され、受信なしのcat.jpgの名前編集中に⌘.で編集が取り消され、元の名前のまま。
  - 20秒遅延するcat.pngをAへ受信中、既存cat.jpgの編集だけが⌘.で取り消され、受信は継続し、「両方残す」で保存できる。
  - logo.svgをBへ受信し、編集中でないFolzioで⌘.を押すと受信が取り消され、20秒以上後もBは空。
- こちらの読み取り確認でもAのcat.jpg・cat 2.jpg・新しいcat 3.jpgは各719 bytesのimage/jpegでquarantineあり。Bは空。一時フォルダの記録は未使用の待機用2組だけで、それぞれ空のreceived・checkedのみだった。
- rename-cancel-shortcutの元症状はローカルの自動・GUI確認で解消。今回の修正のコミット・push・CIをT030で確認する。T031の他の宛先、宛先失敗、確認の直列化、強制終了後の掃除、性能などは未完了。Phase 4へは進まない。

### 編集取消のSwift 6.0互換修正と宛先の確認（2026-11-10）

- 799e09eをpushし、[CI 42701811275](https://github.com/yoshidax/folzio-dev/actions/runs/42701811275)、job 129448170376のログを確認。このSHA・Swift 6.0 / Xcode 16.0で公開用書き出し等は成功したが、NSMenuの非隔離overrideからMainActorのプロパティ・メソッドへのアクセスでbuild失敗。通常・性能テストは未実行。
- メニューのキー処理をnonisolatedにし、UIでの編集取消だけを実行時にMainActorを検証しつつ同期実行する互換修正を追加。NSEventを隔離の境界へ渡さず、メニューの局所aliasだけをnonisolated(unsafe)とする。
- build成功後の通常テスト初回はzip内PNG/MP4のキャッシュ同一性2件で失敗（Core 1,082件中2件、App 69件成功）。未変更の箇所で原因未確定。単独2件は同じコードで成功し、全通常再実行も1,151件すべて成功（Core 101.617秒・App 1.710秒）。規約チェック（Python 179件）・make-app・diff --check成功。初回失敗も含むログは `/tmp/folzio-tak88-rename-fix/compat-*.log` に保存。互換修正版のGUIとCIは未確認。
- Safari・Chromeそれぞれについて、ツリー・お気に入り・リストの行・サムネイルのフォルダ・検索結果のフォルダ・一覧の背景へのドロップ操作は問題なしと保守者が回答した。保存先は `/Users/igachan/Desktop/pics/TAK88-routes/` 内のTAK88-tree、TAK88-favorite、TAK88-list、TAK88-thumbnail、TAK88-search、TAK88-background。
- 読み取り確認では上の6フォルダに各1件のsample.png（188 bytes、image/png）が存在した。一方、保守者は「同名ドロップの置換・両方残す・中止の確認が表示されなくなった」と報告。「表示される」は「表示されない」への訂正を受領した。2回目の同名保存の成否や、各ファイルと各ブラウザの対応は未確定であり、両ブラウザから別々に2件保存できたとは扱わない。衝突確認の不具合を追加調査する。
- コードに、確認の親ウインドウが取得できない場合にConflictPromptが黙ってabortを返す経路がある。ブラウザからのドロップの非同期処理時に起きる可能性を調べる。上書きを確認したわけではない。T030・T031は未チェック、Phase 4は未着手。

### Swift 6.0互換修正版の起動確認（2026-11-10）

- 保守者が互換修正版の `.build/Folzio.app` へ起動し直し、「3ペインが表示され、編集も取り消された」と回答した。受信を始めずに既存cat.jpgの名前の編集中に⌘.を押し、元の名前のままと確認済み。
- 互換修正のソースとrename-cancel-shortcutの記録を追加コミット・pushし、Swift 6.0 CIを確認する。通常テストの初回キャッシュ失敗の記録は維持する。
- 同名時の確認が表示されない件は、保守者が診断ID `drop-conflict-parent` と「受信開始時のドロップ先ウインドウを確認・衝突ダイアログへ渡す」方針を承認。別のバグ記録として回帰テストと修正を進める。T031・Phase 4以降は未完了。

### 編集取消のSwift 6.0互換修正後のCI（2026-11-10）

- 互換修正を `31064b7795551a295b02755d1c9004d35aa5f82e` として指定ブランチへpush。[macOS Swift CI 42760052352](https://github.com/yoshidax/folzio-dev/actions/runs/42760052352)、job 129643369358の全ログと末尾を確認し、このSHA・Swift 6.0を確認した。
- 公開用書き出し、build、pasteboard-probe自己検査、通常1,151件（155.884秒）が成功。799e09eの非隔離overrideのbuild失敗は解消した。
- 性能は27件中24件成功・3件基準超過（150.815秒）。continue-on-errorによりジョブ全体はsuccessだが、性能も全件成功とは扱わない。しきい値は変更せず、成功するまでの再実行は行わない。原因と変更前との同条件比較は引き続き未確定。

| 基準を超過した性能テスト | 実測 | 基準 |
|---|---|---|
| 24 MP JPEGのデコード | 0.544126042秒 | 0.5秒未満 |
| 50,000件に対する256件のバッチ処理 | 0.1009245秒 | 0.1秒未満 |
| zip 200,000件からのスライドショー候補抽出 | 0.208695458秒 | 0.2秒未満 |

- 編集取消の元症状とSwift 6.0互換性は確認済み。後続のdrop-conflict-parentの実装・実機・CIとT031の残る確認を継続する。Phase 4へは進まない。

### 同名ドロップの確認の親の修正（drop-conflict-parent、2026-11-10）

- 保守者がIDと方針を承認した。診断は `.specify/bugs/drop-conflict-parent/assessment.md`。FR-025・FR-347・US77-AS4に対する実装の不一致として、仕様本文を変えずに修正した。
- 実機で今回の修正を試して直らなければ、同じ方針の修正を重ねず、⌘.廃止を含む方針を見直すという保守者の条件を記録した。
- 受信開始時の宛先ウインドウを弱く保持し、保存時に確認と衝突へ明示する。親の既存シートも待つ。シートを出す時点で親を前面へ出し、受信パネルや⌘.の処理は変更しない。
- 修正前はキー・メインウインドウが取得できない条件で4テスト・17 issuesを再現。修正後は関連31件、build、全通常1,155件（Core 1,082・App 73）、規約チェック（Python 179件）、make-appが成功した。文面生成の不要引数の整理後もbuild・全App 73件・規約チェック・make-app・diff --check成功。Coreソースは変えていない。
- 保守者へ最新アプリでSafari・Chromeの各3つの衝突選択を一度再確認するよう依頼。ドロップ後にFolzioをクリックし直さず、確認が出なければそこで止める。専用宛先は `/Users/igachan/Desktop/pics/TAK88-collision-parent/` のブラウザ別replace/keep/abortの6フォルダ。
- 既存は内容の異なるPNG（161 bytes）、新しいPNGは確認ページの188 bytes。実保存で置換・元ファイルの保持・連番・中止を区別する。GUIと今回のCIは未確認のためpartial。T030・T031は未チェック、Phase 4には進まない。ログは `/tmp/folzio-tak88-conflict-fix/`。

### 同名確認の手順整理後の実機結果（2026-11-10）

- 最初の6フォルダでの結果は、保守者が手順を間違え整理できないと回答したため判定保留。ソースを変えず、新しい `/Users/igachan/Desktop/pics/TAK88-recheck-01` 〜 `TAK88-recheck-06` で1件ずつ再確認した。
- 01〜03はSafariの置換・両方残す・中止、04〜06はChromeの同じ3選択。全6件で保守者が確認表示と選択の成功を回答した。新しい同じ修正案を重ねたわけではなく、同じビルドで手順を整理した確認。
- 読み取りでも、01/04のsample.pngは新188 bytesとSHA-256一致、02/05は元161 bytesのsample.pngと新188 bytesのsample 2.pngがそれぞれ一致、03/06は元161 bytesだけで内容不変だった。保存した新画像のquarantineは01/02がSafari、04/05がChrome。全6フォルダの名前と内容の組を照合して一致した。
- 終了後のpendingImportFoldersは待機用2組だけで、空のreceived・checkedのみ。元の同名確認の症状は実機でも解消した。今回の修正をコミット・pushしてCIを確認する。T030・T031はCIと残る手動確認まで未チェック、Phase 4は未着手。

### 同名確認の修正後CIと修飾キーの測定（2026-11-10）

- 同名確認の修正を `bcdd40a7e27afaf171ae997ff1b8515648e8da67` としてpush。[macOS Swift CI 42771331921](https://github.com/yoshidax/folzio-dev/actions/runs/42771331921)、job 129679579601の全ログと末尾を確認。このSHA・Swift 6.0で公開用書き出し、build、probe自己検査、通常1,155件（174.263秒）が成功した。
- 性能は27件中23件成功・4件基準超過（155.737秒）。continue-on-errorでジョブはsuccessだが、性能を含む全成功とは扱わない。しきい値を変えず、成功するまでの再実行はしない。原因と変更前との同条件比較は未確定。

| 基準を超過した性能テスト | 実測 | 基準 |
|---|---|---|
| 24 MP JPEGのデコード | 0.573492542秒 | 0.5秒未満 |
| フォルダ名変更後の検索結果10,000件の反映 | 中央値0.106355708秒 | 0.1秒未満 |
| 50,000件に対する256件のバッチ処理 | 0.113193625秒 | 0.1秒未満 |
| zip 200,000件からのスライドショー候補抽出 | 0.212706875秒 | 0.2秒未満 |

- T030のコミット・push・CI結果確認は完了。T031は未完了、Phase 4は未着手。
- 続く修飾キー確認では、保守者が07（Safari Option）・09（Chrome Option）で＋表示と保存を確認。どちらもsample.pngは188 bytesで確認ページのPNGとSHA-256一致し、quarantineも各ブラウザと一致した。
- 08（Safari Command）・10（Chrome Command）は＋表示なし・保存なしと回答。08は空と確認。Commandを押して確認スクリプトへ入れたログでは、SafariがsourceOperationMask=0（07:04:11 UTC / 16:04:11 JST）、Chromeが4 generic（07:06:11 UTC / 16:06:11 JST）。いずれもcopyを含まない。ログは `/tmp/folzio-tak88-command-mask/evidence.log` に固定した。
- これはUS77-AS6の無条件の「修飾キーに関わらずコピー」と、FR-356の「コピー許可がなければ拒否」の対応を明確にする必要がある測定結果。アプリのコードは変更していない。仕様の変更案を保守者に示し、承認までは期待値を変更しない。⌘.による受信取消を変更するものではない。

### 修飾キーとコピー許可の仕様の明確化（command-drag-mask、2026-11-10）

- 保守者が診断IDと「Option・⌘でも、ドラッグ元がその状態でコピーを許可する場合だけコピーする。コピー許可がない場合は受け付けない」への変更を「このIDと仕様変更で進める」と承認した。
- specのSession 2026-11-10・US77-AS6・FR-356、契約、quickstart、researchの測定条件へ反映した。従来の無条件の期待値を改めたことを明示し、アプリのコードは変更していない。T007時点のマスクの記録は修飾キーなしの条件と明記した。
- Safari・ChromeのOptionはコピー表示と保存に成功、Commandはcopy許可がなく拒否という実測が、明確化後の条件に適合する。08と10はいずれも空。07と09の保存データ・quarantineも検査済み。既存のfile URLと⌘.の規則は変更しない。
- Spec Quality Checklistは16/16→16/16で変更なし。これは仕様品質の評価であり、T031や性能検証の完了を意味しない。新しい実装・依存・IDは追加しない。
- 前提スクリプトはSPECIFY_FEATURE_DIRECTORY=specs/TAK-88-browser-image-importを明示してpaths-onlyで確認。既存のfeature.jsonへ保存せず、別のfeatureは変更していない。before/after_clarifyは無効、before/after_bug_assessの登録hookはなし。

| 明確化の観点 | 状態 |
|---|---|
| Functional Scope & Behavior | Resolved: コピー許可を受け入れ条件へ明示 |
| Domain & Data Model | Clear: 変更なし |
| Interaction & UX Flow | Resolved: 修飾キー時の受け付け・拒否を明示 |
| Non-Functional Quality Attributes | Clear: 既存の基準は明確。実測の未完は別途残る |
| Integration & External Dependencies | Resolved: 現在のソースの許可を尊重 |
| Edge Cases & Failure Handling | Resolved: 許可なしでは保存しない |
| Constraints & Tradeoffs | Resolved: コピー必須を維持 |
| Terminology & Consistency | Clear: コピー許可の用語を統一 |
| Completion Signals | Resolved: 許可の有無ごとの期待値を明示 |
| Misc / Placeholders | Clear: 新たな未解決の仕様項目なし |

T030はCI確認済み、T031は残る安全性・宛先の失敗・同時確認・再起動後の掃除・体感性能等まで未チェック。Phase 4へ進まない。

### 手動確認の範囲の見直し（2026-11-10）

- 保守者から「このテストはどこまで続きますか？ユーザーがおこないそうにない操作に対して深くテストする必要はない」と指摘を受けた。主要な利用操作と実際の不具合は確認できており、追加の手動確認をここで終了する。
- 今後の手動は通常の主な操作と実際に発生した不具合の再現に限定し、稀な操作を網羅するための依頼を増やさない。tasksとquickstartへ方針を反映した。Chromeの普通の文字列ドラッグの追加質問は回答不要とした。
- この直前には、再作成したTAK-88アプリでSafari・ChromeのURL文字列、Safariの普通の文字列は宛先が強調されず保存されないと保守者が回答。読み取りでも11番フォルダは空。Chromeの普通の文字列は「ドラッグできません」との回答だけで、開始できないのか受け付けられないのか未確定のまま。これを合格とは扱わない。
- Mail PDFの実機、意図的な宛先消失・書込不可、強制終了などの稀な異常系の追加手動確認は行わない。関連する既存のCore/Appの自動テストはCIの通常1,155件成功に含まれるが、未実施の実機確認を実施済みに置き換えない。
- ブラウザ・写真アプリの保存、同名時の3つの選択、進捗・取消と実際に発生した取消後エラーの解消など、主要な確認は上記の実測記録を根拠とする。
- SC-189の入力から表示までの数値や変更前後のドラッグ反応は未計測。CI性能4件の基準超過も原因未確定で残る。手動依頼を終了したことと全品質項目の合格を混同せず、T031とT040は未完了のまま。Phase 4は未着手。


## Phase 4 の実装とローカル検証（2026-11-10）

- 保守者の「Phase4を進めていきましょう」により、`claude/clever-knuth-udimb8`（開始時HEAD `b9f5161`）でT032〜T035を実装した。LinearのTAK-88をIn Progressへ更新した。Phase 3で残した数値計測と性能基準超過を解消済みとは扱わない。
- `PasteboardImport.availability` は項目の型だけを調べ、Coreへ`promiseDeclaredTypes=[]`を渡す。一般クリップボードではfile URL → 画像データの優先順位で、書き出し約束は要求しない。画像データだけなら通常のペーストのみ有効で、移動ペーストは無効とする。
- 編集メニュー、ファイルリストの右クリック、ツリーの「ここにペースト」の有効条件を共通化し、画像のペーストを既存のImportSession・saveReceivedへ接続した。画像の同期読み出しはドラッグと同じ読み出し関数を再利用し、検査・PNG書き込み・保存は既存の背景処理を使う。ペースト開始時の宛先ウインドウを非同期の保存確認・同名確認へ渡す。
- 名前付きNSPasteboardのテストを先に追加し、新しい判定型がない状態で失敗することを確認した。その後、Appの新規8テストが成功。PNG/JPEG/TIFFの有効条件、file URLの優先、約束だけと約束＋画像、URL・文字列の拒否、判定時に遅延データを要求しないことを確認した。PNG/TIFFの実保存・同名時の連番・宛先ウインドウの保持・実行後のクリップボード変更・quarantine、写真アプリの縮小画像を読まず既存ファイルをコピー/移動すること、画像の移動ペーストが無操作であることも自動確認した。
- 環境は既存のローカル検証と同じmacOS 26.6.2（25G83）/ arm64、Swift 6.4.2。`swift build`は成功。
- 初回の`swift test`ではApp 81件と性能27件が成功し、Core 1,082件のうち既存のzipサムネイルのキャッシュ同一性テスト2件（PNG・MP4の`again === thumbnail`）が失敗した。これは以前の検証でも記録した2件と同じ箇所。対象2件の単独実行は成功し、続くCIと同じ`swift test --no-parallel --skip FolzioPerformanceTests`ではCore 1,082件（90.371秒）とApp 81件（1.345秒）、計1,163件が成功した。原因は未確定で、初回失敗を消さず記録する。
- `scripts/dev/check-all.sh`は全検査成功。`git diff --check`成功。`scripts/make-app.sh`で`.build/Folzio.app`を生成した。新しい依存は追加せず、`specs/product/`は変更していない。
- T032〜T035をチェック済み。起動スモークと実アプリのペーストはまだ保守者の確認前。AGENTS.mdのローカル検証ゲートに従い、起動の報告後にPhase単位のコミット・push・CI確認（T036）を行う。T036・T037は未チェックのまま。
- 手動確認はSafari・Chromeの画像コピー→⌘V、ツリーの「ここにペースト」、写真アプリのコピー→⌘Vの通常操作4件を中心とし、問題が出た場合に該当操作を切り分ける。未実施の実機確認やPhase 5の作業を完了扱いにしない。

### Phase 4 の実機確認（2026-11-10）

- 保守者へ最新の`.build/Folzio.app`の再起動・3ペイン表示と、`/Users/igachan/Desktop/pics/TAK88-paste`での通常操作4件を依頼し、「4件とも保存できた」と報告を受けた。Safariの画像コピー→一覧の⌘V、Chromeの画像コピー→一覧の⌘V、ツリーの「ここにペースト」、写真アプリの写真コピー→一覧の⌘Vを実施した報告として記録する。
- Agentの読み取りでは保存先にPNG 2件（1024×768・32×32）とJPEG 1件（1024×768）を確認した。個々の操作とファイルの対応は未特定で、4操作に対応する4つの別ファイルを確認したとは扱わない。写真アプリのコピーがJPEGになることはfile URLを優先する承認済みの仕様に従う。
- T037は通常操作を中心とする保守者の確認方針に沿ってチェックした。移動ペーストの抑止とfile URL優先は今回の自動テストの根拠を用いる。zip・検索結果・名前編集中のペーストなど、今回追加の実機操作を依頼していない条件は実測済みとしない。
- 起動と主要操作の報告を得たため、Phase 4をコミット・pushしてCIを確認する。T036はCI確認まで未チェック。Phase 5には進んでいない。

### master統合とPhase 4のCI確認（2026-11-10）

- Phase 4の実装と実機結果を`fa2f61a2c4085a3fa8b4a69e8753b443ecd49551`でコミット・pushした。その後、保守者の指摘によりmasterを確認し、`97fcb0c8c847387e7e451a8e1f1d1919cb2a9b0a`（TAK-89・PR #70のスライドショー開始/停止切替）を`62fb2fdeec54e74ebee15a3b31ecf55c1a3cd06e`で取り込んだ。
- 共有する翻訳ファイル3件は競合なく自動統合された。Phase 4のPasteboardImport・FileOperationCoordinator・FileContextMenu・ファイルリスト/ツリーのペースト処理には、統合による追加差分がない。master取り込み後も画像取り込み用・スライドショー停止用の翻訳キーを保持している。
- 統合後のローカル検証: `swift build`成功。`swift test --no-parallel --skip FolzioPerformanceTests`はCore 1,086件（97.685秒）・App 81件（1.641秒）、計1,167件が成功した。`scripts/dev/check-all.sh`は全件成功し、仕様IDの重複なし。`git diff --check`と`scripts/make-app.sh`も成功した。統合後のアプリを再生成済みだが、GUI起動は追加で実測していない。先に報告を得た4操作の実機確認は統合前のPhase 4構成のものとして区別する。
- PR #69のタイトルと本文をドラッグ・ペーストの実装範囲へ更新し、Draftを維持した。TAK-88のproduct仕様への反映やPhase 5は未着手。
- `62fb2fd`に対する[macOS Swift CI 42792316857](https://github.com/yoshidax/folzio-dev/actions/runs/42792316857)（job 129748567313）が完了し、ジョブ全体はsuccess。ログのcheckoutは`fb6fc71`（`62fb2fd`を`97fcb0c`へ統合したGitHubのPR用コミット）。Swift 6.0で公開用書き出し・build・probe自己検査と、通常テストの成功表示1,167件（153.833秒）を確認した。大文字小文字を区別する一時ボリュームが必要な1ケースは条件付きスキップであり、実行成功とは数えない。
- 性能テストは27件中24件成功・3件の基準超過（146.144秒）。`continue-on-error`によりステップやジョブ全体はsuccessだが、性能全件成功とは扱わない。同条件の変更前後比較は行っておらず、原因を共有ランナーのばらつき・性能劣化のどちらとも断定しない。

| 基準を超過した性能テスト（master統合後CI） | 実測 | 基準 |
|---|---|---|
| 24 MP JPEGのデコード | 0.546998333秒 | 0.5秒未満 |
| フォルダ名変更後の検索結果10,000件の反映 | 中央値0.116444459秒 | 0.1秒未満 |
| 50,000件に対する256件のバッチ処理 | 0.102507791秒 | 0.1秒未満 |

- 保存先の読み取りで確認したPNG 2件・JPEG 1件は、いずれも`com.apple.quarantine`属性がある。
- T036をチェックし、Phase 4のT032〜T037を完了として記録した。T031・T040の数値計測と性能課題、Phase 5の作業は残す。この後の追記コミットはtasksと検証記録だけで、上記CIの対象は実装・master統合の`62fb2fd`。ソース・テスト・CI定義は変えない。
