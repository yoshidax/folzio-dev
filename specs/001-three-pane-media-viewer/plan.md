# Implementation Plan: 3ペイン型メディアビューア

**Branch**: `001-three-pane-media-viewer` | **Date**: 2026-10-21 (folders in the file list, `..` row and tree sync; zip archives; 2026-10-20: favorites, image/video type filter, tree double-click toggle and disclosure, toolbar, fullscreen arrow navigation, small-image upscale, tree/list icons, thumbnail scroll follow; original 2026-10-19) | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-three-pane-media-viewer/spec.md`

## Summary

左にフォルダツリー、中央にファイルリスト（リスト形式 / サムネイル形式）、右にプレビューを並べた
macOS 用のメディアビューアを作る。画像（JPEG / PNG / GIF / WebP）と動画（mp4 / mov）を閲覧でき、
Finder 準拠の操作でファイルのコピー・名前の変更・ゴミ箱への移動・移動ができる。

実装は Swift 6 + AppKit のネイティブアプリとし、外部依存は持たない。選択・プレビュー・並べ替え・
ファイル操作の判断はすべて AppKit 非依存のライブラリ `MediaViewerCore` に置き、Swift Testing で検証する。
UI の `MediaViewerApp` は、`NSSplitViewController` の上に NSOutlineView / NSTableView / NSCollectionView /
AVPlayerView を配置して Core の状態を描画するだけにする。デコードは ImageIO でスクリーンサイズに
ダウンサンプリングし、前後1件を先読みして、上限付きのキャッシュに置く（詳細は [research.md](./research.md)）。
プレビューの画像は、縦横比を保ってペイン内の最大サイズにフィットさせる。ペインより小さい画像も
拡大率の上限なしで拡大し、フルスクリーンでも同じ規則を使う（FR-028、R5）。動画の表示サイズは
この規則の対象外とする。アプリバンドルには、3ペインをモチーフにした自前生成のアイコンを同梱する
（FR-043〜045、R14）。サムネイル形式では、矢印キーでフォーカスをビューポート外へ移したときに、
フォーカス項目全体が見える位置まで必要最小限のスクロールで追従する（FR-017、R15）。
フルスクリーン中も矢印キーでファイルリストの選択を移動し、プレビューを追従させる（FR-046、R16）。
移動規則は通常表示と共通の純粋計算に置き、リスト形式は上下、サムネイル形式は上下左右とする。
動画のフルスクリーンでは矢印キーをファイル移動に使い、シークは `<` / `>` キーに割り当てる。
ツリーのフォルダ名とリスト形式のファイル名の先頭にはアイコンを表示する（FR-047・048）。
ツリーはホーム・マウント中のボリューム・通常フォルダを SF Symbols で区別し、リスト形式は
`ThumbnailProviding` を小さなサイズで再利用して内容の縮小画像を出し、生成中・失敗時は
形式別の SF Symbol にフォールバックする。
メインウィンドウには表示・非表示を切り替えられる `NSToolbar` を持たせる（FR-049〜052、R18）。
既定は非表示で、「表示」メニューと ⇧⌘T で切り替え、表示状態は `SettingsStore` に保存する。
ツールバーには表示形式の2択ボタン（SF Symbols）とサムネイルサイズのスライダーを置き、
既存の表示形式・サイズの状態をメニューや下部バーと共有する。下部バーの表示とスライダーの有効・無効は
Core の純粋計算 `FileListChrome` で決める。
ツリーではフォルダの行のダブルクリックで開閉をトグルし（FR-053）、開閉の三角はサブフォルダがあると
確認できたフォルダにだけ出す（FR-054・055、R19）。確認は表示されているフォルダの直下1階層だけを、
最初の1件で打ち切る列挙で行い、並列数を 4 に制限してバックグラウンドで実行する。
開閉の判断と状態遷移は Core の `FolderDisclosure` と `FolderNode` に置いてテストする。
ファイルリストには画像・動画の種類フィルタを加える（FR-056〜060、R20）。「画像のみ表示」（⇧⌘I）と
「動画のみ表示」（⇧⌘M）の独立した2つのオン・オフで、片方だけがオンのときに絞り込む。ツールバーでは
表示形式ボタンの左に `selectAny` の2択ボタンとして置き、「表示」メニューにも同じ項目を置く。
状態は `BrowserModel.mediaTypeFilter` に1つだけ持ち、保存しない。`BrowserModel` が全件を保持して
`listing.files` に絞り込み後の配列を入れるため、一覧・選択・先読み・フルスクリーン移動・ファイル操作は
既存のまま表示中の一覧だけを対象にする。非表示になった選択の整理と0件のメッセージは Core で決める。
ツリーの最上部には、仮想的な「お気に入り」の見出し（スターのアイコン、開閉の三角付き、起動時は折りたたみ）を置き、
その下に登録したフォルダを三角なしの項目として登録順に並べる（FR-061〜067、R21）。登録は右クリックメニューと ⌃⌘T、
削除はお気に入りの項目の右クリックメニューと ⌘⌫ で、どちらも確認モーダル（ファイル操作と同じ省略設定）を通す。
見出しへの移動は ⇧⌘F。項目を選ぶとそのフォルダの内容を出し、見出しを選んでも一覧は変えない。登録はパスの配列として
`SettingsStore` に保存し、見つからなくなった項目は淡色で残して、フォルダが戻れば自動で通常の表示に戻す。
登録内容・行の役割ごとの操作の可否・存在の確認は Core の `FavoriteFolders`・`FavoriteCommands`・`FavoriteProbe` に置く。
ファイルリストには zip ファイルも出し、ダブルクリックか ⌘↓ で zip の中を、ツリーを使わずにファイルリストの中だけで辿れるようにする
（FR-068〜075、R22〜R28）。zip の中の一覧は、先頭行の `..`・ディレクトリ・対応メディアからなり、⌘↑ か `..` で戻る。
表示形式・並べ替え・プレビュー・フルスクリーン・種類フィルタは通常のフォルダと同じに使え、zip の中は読み取り専用にする。
zip は Core の自前の読み取り器 `ZipArchiveReader` で、中央ディレクトリを `pread` で1回読んで索引にし、一時ファイルを作らない。
zip の中の項目は独自スキームの URL（`mvzip:`）で表し、既存の選択・キャッシュ・形式判定をそのまま使う。画像は項目を `Data` に
読み込んで ImageIO でデコードする。動画は `AVAssetResourceLoaderDelegate` で AVPlayer の範囲要求に応え、無圧縮の項目は直接、
deflate の項目は Compression フレームワークで順に展開して返す。1 本の動画が使うメモリは、32MB のチャンクキャッシュと
展開カーソル 2 本で上限が決まり、動画のサイズに依存しない。名前の文字コードは UTF-8 → CP932 → CP437 の順に、CoreFoundation の
変換で判定する。
ファイルリストにはサブフォルダも出し（FR-076〜078、R29〜R32）、ダブルクリックか ⌘↓ で中へ、先頭行の `..` か ⌘↑ で親へ移る。
戻る行の表記は zip の中も含めて `..` に統一する。サブフォルダの判定はツリーの `subfolders(of:)` と共有し、`DirectoryLister.mediaFiles(in:)` の
1回の列挙から `ListItemKind.folder` の行を作る。ツリーのルート（ホーム・ボリューム）は App から `BrowserModel` に渡し、純粋関数
`FolderNavigation.enclosingFolder(of:roots:)` で `..` を出すか・戻る先を決める（ルートでは出さない）。一覧の中で移動したときは
`BrowserModel.treeSyncRequest` を出し、ツリーがそれを見て実際の階層でそのフォルダを選択・展開する（フォーカスはファイルリストのまま）。
フォルダは通常のファイルと同じ全操作の対象にし、`..` の行は操作の対象から除く。操作の完了はツリーへ直接知らせ、FSEvents を待たずに反映する。

## Technical Context

**Language/Version**: Swift 6（strict concurrency、開発機のツールチェーンは 6.3.3）

**Primary Dependencies**: Apple 標準フレームワークのみ（AppKit, AVKit/AVFoundation, ImageIO,
QuickLookThumbnailing, UniformTypeIdentifiers, CoreServices[FSEvents], CoreGraphics[アイコン生成],
Compression[zip の deflate の展開], CoreFoundation[zip の名前の CP932・CP437 の変換]）。
サードパーティ依存なし。zip の読み取りは自前で実装する（R22）

**Storage**: `UserDefaults`（表示設定・動作オプション・お気に入りのパスの配列）と、`NSSplitView` の自動保存（ペイン幅）。
サムネイルとデコード済み画像はメモリ上のみに置く

**Packaging**: `scripts/make-app.sh` が `scripts/make-icon.sh` を呼び、実行ターゲット `make-icon` が
1024px の設計座標から各解像度を描画して `.build/AppIcon.iconset` を作る。`iconutil` で
`.build/AppIcon.icns` にまとめ、`Contents/Resources/AppIcon.icns` として同梱する。
`Info.plist` の `CFBundleIconFile` は `AppIcon`。アイコンはコードから生成し、外部素材を置かない

**Testing**: Swift Testing（`swift test`）。単体・異常系の `MediaViewerCoreTests` と、性能計測の
`MediaViewerPerformanceTests`。フィクスチャはテスト実行時に生成する

**Target Platform**: macOS 15 以降（Apple Silicon / Intel）。非サンドボックス、ad-hoc 署名

**Project Type**: desktop-app（Swift Package: ライブラリ + 実行ターゲット）

**Performance Goals**: 画像の選択から表示まで 0.5 秒以内（24MP JPEG）、先読み済みの隣接ファイルへの
切替 0.1 秒以内、起動からリスト表示まで 2 秒以内、10,000 ファイルのフォルダの最初の表示 1 秒以内、
動画の再生開始まで 1 秒以内。サムネイルサイズやペイン幅の変更にはドラッグ中も途切れずに追従する。
10,000 項目の zip の最初の表示 1 秒以内（索引の作成は 0.5 秒以内）、zip の中の 1GB 以上の動画の再生・シークで追加メモリ 128MB 以下、
無圧縮で格納した 1080p 動画の再生開始 1 秒以内（SC-014・015）。
小さい画像の拡大はレイヤー（GPU）のフレーム変更だけで行い、追加のデコード・再描画を伴わない

**Constraints**: オフラインで完結し外部通信をしない。UI スレッドでデコード・列挙・ファイル操作をしない。
デコード済みプレビューのキャッシュは 256MB、サムネイルは 128MB を上限とする。ファイルリストに横スクロールを出さない。
デコードはスクリーンの長辺ピクセルを上限にするため、表示先はそれを超えず、ペインのリサイズやフルスクリーン切替で
再デコードは不要。小さい画像はデコード済みの原寸を保ち、表示時にレイヤーで拡大する（R5）。
サムネイル形式のキーボード移動では、フォーカス項目全体が見える最小限の縦スクロールだけを行い、
横スクロールは発生させない（FR-015・017）。サムネイルサイズやペイン幅の変更時は追従しない。
フルスクリーン中の矢印移動では、折りたたみ前のサムネイル列数をスナップショットして使い、解除後に
必要なら同じスクロール追従でフォーカス項目を表示する（FR-046）。新しい永続化状態は増やさない。
ツリーとリストの行頭アイコンは表示時にだけ生成し、永続化しない。リストの縮小画像は可視行だけを
対象に非同期で取得し、セル再利用時は同じ URL・同じ要求サイズの取得だけを取り消す
（サムネイル形式の 128px 以上の要求を巻き込まない）。アイコン取得の完了を待たずにファイル名・
選択・スクロールを操作できる（FR-048、SC-012）。
ツールバーの表示状態は `view.showsToolbar` として `SettingsStore` だけに保存し、`NSToolbar` の
自動保存（`autosavesConfiguration`）は使わない。ツールバーが非表示のときのウィンドウは追加前と同じに保つ。
フルスクリーン中はツールバーをメニューバーと一緒に自動で隠し、保存した表示状態は変えない（FR-049、R18）。
ツリーのサブフォルダの有無の確認は、表示中のフォルダの直下1階層だけを対象にし、孫以下を先読みしない。
確認は UI スレッドで行わず、同時に 4 件までに制限する。確認結果は永続化しない（FR-055、R19）。
種類フィルタは保存せず（`SettingsStore` に書かない）、起動のたびに両方オフで始める。切り替えでは
ディスクを読み直さず、保持済みの全件を `MediaKind` で絞るだけにする（10,000 件で 0.05 秒以内）（FR-056、R20）。
お気に入りは絶対パスの配列 `favorites.paths` だけを保存し、ブックマークデータ・見つかるかどうか・見出しの開閉状態は
保存しない。存在の確認は UI スレッドで行わず、同時 4 件までに制限する。⌘⌫ には新しいメニュー項目を作らず、
既存の「ゴミ箱に入れる」をレスポンダーチェーンでツリーに振り分ける（FR-064・066・067、R21）。
zip の中身はユーザーのフォルダにも一時ディレクトリにも書き出さず、zip ファイルへの `pread` 以外のディスク入出力をしない（FR-072）。
zip の読み出し（索引・画像・サムネイル・動画）は UI スレッドで行わない。zip の中の画像の読み込みは1項目 512MB まで、
動画は 1 asset あたりチャンクキャッシュ 32MB と展開カーソル 2 本まで。zip の中の位置は保存せず、`lastFolder` は zip を含むフォルダの
まま（FR-003）。zip の中の項目は `mvzip:` の URL で、`FileManager`・`NSWorkspace`・ペーストボードに渡さない（FR-073）。
ファイルリストのフォルダの行は、ファイルと同じ1回の `contentsOfDirectory` の結果から作り、ディレクトリを2回読まない。パッケージの判定は
ディレクトリだけに問い合わせる（R29）。通常のフォルダの `..` の行は `mvparent:` の URL で、`FileManager`・`NSWorkspace`・ペーストボードに
渡さない（R30）。ツリーの同期は一覧の表示を待たせず、ツリーの選択の変更から `selectFolder` を呼び返さない。新しい永続化状態は増やさない
（一覧の中で移ったフォルダは既存の `lastFolder` に保存する。FR-003・078、R31）。

**Scale/Scope**: 1ウィンドウ（3ペイン）+ 設定ウィンドウ + 確認・衝突ダイアログ。フォルダあたり最大で
数万ファイルを想定。単一ユーザー

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

憲章 v1.1.0 に対する評価。

| 原則 | 判定 | 根拠 |
|------|------|------|
| I. ローカル完結・プライバシー | ✅ 適合 | ネットワークを使う API も依存もない。サムネイルはメモリにのみ置き、ユーザーのフォルダにもディスクキャッシュにも書かない（R7）。アプリアイコンも外部素材を取得せず、コードから生成する（R14）。ファイル操作はすべてユーザーの明示的な操作が起点になる。確認を省略できるのは、削除が常にゴミ箱経由で取り消せるため（v1.1.0 の「確認または取り消し可能性」、FR-021・024）。取り消せない上書きは常に衝突ダイアログで確認する（FR-025）種類フィルタは表示の絞り込みだけで、ファイルを変更せず通信もしない（R20）。お気に入りの登録・削除は登録内容を変えるだけで、実際のフォルダを変更せずゴミ箱にも入れない。保存先はローカルの `UserDefaults` だけ（R21）。zip の中身は一時ファイルにもユーザーのフォルダにも書き出さず、zip ファイルを `pread` で読むだけにする。動画も AVFoundation の独自スキームの読み込み器でメモリから渡し、ネットワークを使わない（R22・R25）。zip の中は読み取り専用で、zip を書き換える経路を持たない。zip ファイルそのものの操作は既存の確認・ゴミ箱の規則のまま（FR-073）。フォルダのファイル操作は既存の確認・ゴミ箱経由の規則のまま（FR-018・021・022）。フォルダの削除はファイルリストからだけで、ツリーには削除の経路を足さない（R32）。 |
| II. 体感パフォーマンス | ✅ 適合 | デコード・列挙・サムネイル生成・ファイル操作はすべてバックグラウンドで行う（R5・R7・R9・R10）。キャッシュの上限を明示した（R8）。基準値は `MediaViewerPerformanceTests` で計測する（quickstart）。小さい画像の拡大はレイヤーのフレーム変更だけで行い、デコードや再描画を増やさない（R5）。リスト形式の行頭アイコンもサムネイル生成を可視行だけ遅延実行し、セル再利用時は同じ URL・サイズの要求だけを取り消すため、10,000 ファイルでも一覧表示を待たせない（R17）。注: 憲章の基準「起動からファイル指定で開いた最初の画像の表示 1 秒以内」は、ファイルを指定して起動する経路を前提にしている。この経路は本機能の範囲外なので、代わりに SC-002（前回フォルダの一覧表示まで 2 秒）を計測する。ファイル指定起動を追加する機能で 1 秒基準を適用する。アイコン生成はビルド時のみで、起動時間に影響しない。ツールバーは表示状態の読み込みとビュー生成だけで、デコードや列挙を追加しない（R18）種類フィルタは保持済みの一覧を `MediaKind` で絞るだけで、列挙・デコードを追加しない。10,000 件での適用時間を性能テストで計測する（R20）。お気に入りの存在の確認は列挙を伴わない `stat` だけで、バックグラウンドで同時 4 件までに制限し、応答のないボリュームがツリーの操作を止めない（R21）。zip の索引作成・画像の読み込み・サムネイル・動画の範囲読み出しはすべてバックグラウンドで行い、zip の中の画像では同期の `isAnimated(url)` を使わない（R24）。画像の読み込みは1項目 512MB、動画は 1 asset あたり 32MB のチャンクキャッシュと展開カーソル 2 本を上限にし、動画のサイズに比例してメモリを使わない（SC-014）。10,000 項目の zip の索引作成と、展開後 1GB の項目の読み出しのメモリを性能テストで計測する（SC-014・015）。zip の中のサムネイルは同時 4 件（動画 2 件）までに制限する。ファイルリストのフォルダの行は既存の1回の列挙から作り、パッケージの判定はディレクトリだけに行う。10,000 ファイルと 1,000 サブフォルダの列挙を性能テストで計測する（R29）。ツリーの同期は一覧の読み込みと独立に進め、一覧の表示を待たせない（R31）。 |
| III. キーボードファースト & a11y | ✅ 適合 | 提供する全操作のキー割り当てを [contracts/keyboard-and-menus.md](./contracts/keyboard-and-menus.md) で網羅した。手動の拡大/縮小（ズーム）とパンは提供せず、フィットは画像選択時に自動で行うため、これらへのキー割り当ては存在しない（spec Assumptions）。AppKit 標準部品の a11y を使い、プレビューとサムネイルのセルにはファイル名のラベルを付ける。行頭アイコンは装飾として a11y 要素から外し、フォルダ名・ファイル名と選択状態は従来どおり読み上げられる（FR-047・048）。ダークモードは AppKit 標準の配色で追従し、「視差効果を減らす」設定が有効な間は、アニメーション画像を自動で再生しない。サムネイル形式でもキーボードだけで一覧を辿れるよう、フォーカス項目のスクロール追従を必須にする（FR-017）。フルスクリーン中も矢印キーで選択を移動でき（FR-046）、動画のシークは `<` / `>` に残すため、フルスクリーンでも主要操作をキーボードだけで完結できる。ツールバーの表示切替には ⇧⌘T を割り当て、ツールバー上の操作（表示形式・サイズ）は既存の ⌘1 / ⌘2 / ⌘+ / ⌘- でも行えるため、ツールバーを使わなくてもキーボードだけで完結する。ボタンとスライダーにはアクセシビリティラベルを付ける（FR-050・051）。ツリーのダブルクリック開閉は既存の → / ← キーによる開閉のマウス版で、キーボード手段は既にある。開閉できないフォルダは三角を持たず、支援技術にも開閉できる項目として伝わらない（FR-053・054）種類フィルタは ⇧⌘I / ⇧⌘M と「表示」メニューで操作でき、ツールバーが非表示でもキーボードだけで切り替えられる。ツールバーのボタンにはアクセシビリティラベル（「画像のみ表示」「動画のみ表示」）を付け、メニューのチェックマークで状態を伝える（FR-057・058）。お気に入りは、登録 ⌃⌘T・削除 ⌘⌫・見出しへの移動 ⇧⌘F のキーボード手段を持ち、見出しは → / ← と ↑↓ で開閉・移動できる通常の行なので、マウスなしで登録・選択・削除を完結できる（FR-062・064・065）。見出しはラベル「お気に入り」で読み上げられ、見つからない項目はツールチップ「見つかりません」を持つ。zip の中を表示・上の階層へ戻る操作は ⌘↓ / ⌘↑ と「ファイル」メニューの項目で行え、`..` の行も矢印キーで選べるため、ダブルクリックなしで zip の中を辿れる（FR-069・070）。戻った先では出てきた行を選択し、続けてキーボードで隣へ移れる。zip ファイル・ディレクトリ・`..` の行には SF Symbol と名前の a11y ラベル（`..` は「上の階層へ」）を付ける。フォルダへ入る・戻る操作は ⌘↓ / ⌘↑ と「ファイル」メニュー、`..` の行で行え、ツリーの同期でもキーボードフォーカスをファイルリストに残すため、続けて矢印キーで操作できる（FR-076〜078）。フォルダの行には SF Symbol `folder` と名前の a11y ラベルを付ける。 |
| IV. テスト必須 | ✅ 適合 | 判断ロジックをすべて `MediaViewerCore` に置き、UI から分離した（[contracts/core-api.md](./contracts/core-api.md)）。破損・非対応・巨大・権限なしのフィクスチャを自動生成してテストする。フィット計算は拡大（縦横比・中央寄せ・1×1 などの極小サイズ）を含めて `FitCalculatorTests` で検証する。スクロール追従の最小移動量は純粋計算として Core に置き、`ThumbnailScrollTests` で「画面外の項目へ移動したときの計算」という不具合条件を検証する。キー入力からクリップビュー更新までの UI 配線は自動テストの対象外とし、T093 の手動再現で担保する。フルスクリーンの移動規則は `FocusNavigator` として Core に置き、リスト形式・サムネイル形式・フルスクリーンの全経路で同じ関数を使う。境界（先頭・末尾・行頭・行末）と空リストのケースを `FocusNavigatorTests` で検証する。行頭アイコンは小さな要求サイズの丸め（64px 段階）を `ThumbnailProviderTests` で検証し、表示とフォールバックは quickstart の手動確認で担保する。憲章 原則 IV は UI の見た目そのものの自動テストを必須としないため、この分担でテスト要件を満たす。アイコンはビルド生成物のため、解像度セットを `scripts/make-icon.sh` が検証し、表示は quickstart の手動確認で担保する。ツールバーの保存状態は `SettingsStoreTests`、下部バーの表示とスライダーの有効・無効の判断は `FileListChromeTests` で検証し、ツールバーの見た目と配線は quickstart の手動確認で担保する。ツリーの開閉は、サブフォルダの有無の状態遷移とダブルクリックの判断を `FolderDisclosureTests`、`hasSubfolders(in:)` の判定（隠しフォルダ・パッケージ・権限なし・存在しない）と `subfolders(of:)` との一致を `DirectoryListerTests`、並列数の上限と取り消しを `SubfolderProbeTests` で検証する。ダブルクリックと三角の配線は quickstart の手動確認で担保する種類フィルタの4通りの組み合わせ・並び順の保持・0件のメッセージを `MediaTypeFilterTests`、選択の整理（FR-059）を同ファイルの `SelectionState.restricted(toVisible:)` のテスト、フォルダ移動後の保持・`.noMatches`・並べ替えと読み直し・動画の停止通知を `BrowserModelTests` / `BrowserModelVideoTests` で検証する。ボタン・メニューの配線は quickstart の手動確認で担保する。お気に入りは、登録順・重複の判定・削除を `FavoriteFoldersTests`、保存と不正値の扱いを `SettingsStoreTests`、行の役割ごとの操作の可否と右クリックメニューを `FavoriteCommandsTests`、存在の判定・並列数の上限・取り消しを `FavoriteProbeTests` で検証する。ツリーへの表示・メニュー・確認モーダルの配線は quickstart の手動確認で担保する。zip は、URL の生成と解析を `ArchiveURLTests`、文字コードの判定を `ArchiveNameDecoderTests`、終端レコード・ZIP64・壊れた zip・分割 zip の解析を `ZipStructureTests`、階層の補完・隠し項目・`__MACOSX`・`..`・重複・暗号化と非対応方式の扱いを `ArchiveIndexTests`、無圧縮・deflate・データ記述子の読み出しと上限を `ZipArchiveReaderTests`、任意範囲の読み出しが全体と一致することと後ろ向きの読み出しを `ArchiveEntryStreamTests`、`AVURLAsset` の読み込み（無圧縮・deflate・非 faststart）を `ArchiveAssetLoaderTests`、操作の可否を `ListItemCommandsTests`、フルスクリーンの読み飛ばしを `FocusNavigatorTests`、入る・戻る・選択・プレビューの空・FSEvents を `BrowserModelArchiveTests` で検証する。フィクスチャは `ZipFixtureWriter` で生成し、外部のコマンドに依存しない（R28）。メニュー・ダブルクリック・ドラッグの無効化の配線は quickstart の手動確認で担保する。ファイルリストのフォルダは、フォルダの行の列挙（隠しフォルダ・パッケージ・.zip のディレクトリ・`subfolders(of:)` との一致）を `DirectoryListerTests`、戻る先の判定（ルート・最も深いルート・ルート外・パスの要素の比較）を `FolderNavigationTests`、`mvparent` の URL を `ParentLinkTests`、`.folder` と `.parent` の操作の可否と `hasEnclosingLevel` を `ListItemCommandsTests`、フォルダの拡張子の確認を `NameValidationTests`、入る・戻る・選択・`lastFolder`・`treeSyncRequest` の出る経路と出ない経路・`operableSelection`・`..` の有無と FR-060 の判定を `BrowserModelFolderTests`（新規）で検証する。ツリーの選択・展開・スクロールとフォーカスの配線は quickstart の手動確認で担保する。 |
| V. シンプルさ（YAGNI） | ✅ 適合 | 外部依存ゼロ。UI フレームワークは AppKit に統一し、SwiftUI と混在させない。ディスクキャッシュ・Undo・プラグインは作らない。ターゲットは Core / App / テスト2つ / フィクスチャ生成 / アイコン生成の最小構成。アイコン生成はビルド時専用で、実行時の抽象化や設定項目を増やさない。ツリーとリストの行頭アイコンは SF Symbols と既存のサムネイル経路を使い、新しい設定・永続化・外部素材を追加しない（R17）。フルスクリーン移動（FR-046）は既存の選択モデルとレイアウト計算を再利用し、新しい設定・永続化状態・依存を追加しない。ツールバーは AppKit 標準の `NSToolbar` と SF Symbols だけで作り、ユーザーによるカスタマイズは提供しない。永続化はツールバーの表示状態を表す Bool 1 つだけを追加する（R18）。ツリーの開閉は `NSOutlineView` 標準の `doubleAction` と `isItemExpandable` だけで作り、設定・永続化・依存を増やさない。並列数の制限は、遅いボリュームで列挙が積み上がるのを防ぐための最小限の仕組みとする（R19）種類フィルタは Bool 2 つの値型と既存の `NSToolbarItemGroup`・メニュー項目だけで作り、保存キー・設定項目・依存を増やさない。絞り込みを `listing.files` に集約し、UI の各部品に同じ判断を重複させない（R20）。お気に入りは保存キー1つ（パスの配列）と既存の `NSOutlineView`・メニュー・確認モーダルだけで作り、並べ替え・名前の変更・ドロップ先・ブックマークによる追従は作らない。⌘⌫ は既存のメニュー項目をレスポンダーチェーンで振り分け、同じキーの項目を増やさない（R21）。zip は外部依存を足さず、読み取り専用・単一ファイル・無圧縮と deflate だけに対応する（暗号化の解除・他の方式・入れ子・zip の作成は作らない）。zip の中の項目は既存の `MediaFile` と URL のまま表し、選択・キャッシュ・UI の型を作り直さない（R23）。保存キーは増やさない。シークを速くするチェックポイント索引は作らず、必要になったら `InflateCursor` の内部だけを置き換える（R25）。自前の zip 読み取りは Complexity Tracking に記録した。ファイルリストのフォルダは、既存の `ListItemKind`・`MediaFile`・`FileOperationService`・ツリーの `reveal` を使い、行の種類を1つ（`.folder`）、URL の種類を1つ（`mvparent`）、観測値を1つ（`treeSyncRequest`）足すだけにする。保存キー・設定・依存は増やさない（R29〜R32）。 |

**Phase 1 設計後の再評価**: data-model・contracts・quickstart を確認したが、新たな違反はない。
FSEvents による監視（R9）は外部依存ではなく、OS 標準 API の利用にあたる。アイコン生成（R14）は
ビルド時のコード生成で、外部素材・追加依存・起動時コストを増やさない。
FR-028 の拡大フィット（2026-10-20）は `FitCalculator` の上限撤廃とテストの追加だけで成立し、
新しい依存・設定項目・永続化状態を増やさない（原則 V）。拡大はレイヤーのフレーム変更で行うため、
UI スレッドのデコードや再描画を追加しない（原則 II）。
FR-017 のスクロール追従（2026-10-20）は、既存の選択・レイアウト結果から縦オフセットを求める純粋計算と、
クリップビューの原点更新だけで成立する。計算は Core のテストで不具合条件を再現し、UI 配線は
quickstart の手動再現で確認する（原則 IV）。新しい依存・設定項目・永続化状態を増やさず（原則 V）、
キーボードだけで一覧を辿れる操作性を回復する（原則 III）。
FR-046 のフルスクリーン移動（2026-10-20）は、折りたたみ前に取得した表示形式とサムネイル列数、
および現在の選択インデックスだけから移動先を求める。新しい状態を永続化せず、依存も増やさない（原則 V）。
移動規則は Core の純粋計算に集約し、UI はキーイベントの振り分けと `BrowserModel.select` の呼び出しだけを
担う（原則 IV）。動画のシークは `<` / `>` に残すため、フルスクリーンでもキーボードだけで操作できる（原則 III）。
FR-047・048 の行頭アイコン（2026-10-20）は、ツリーの `FolderNode.Kind` と `MediaKind` から
SF Symbols を選ぶだけの UI 表現で、Core の判断ロジックを増やさない（原則 V）。リストの縮小画像は
既存の `ThumbnailProviding` を 64px 段階で再利用し、可視行だけを非同期に取得する（原則 II）。
キャンセルは URL と要求サイズの組で行い、リストの 64px 要求がサムネイル形式の 128px 以上の要求を
取り消さない（FR-013 の回帰防止）。新しい永続化・設定・外部素材は増やさず、アイコンは装飾として
a11y ツリーから外すため、ファイル名の読み上げを妨げない（原則 III）。
FR-049〜052 のツールバー（2026-10-20）は、AppKit 標準の `NSToolbar` と既存の表示形式・サイズの経路を
再利用し、新しい依存を増やさない。永続化はツールバーの表示状態を表す Bool 1 つだけで、カスタマイズや
ラベル表示の切り替えは作らない（原則 V）。下部バーとスライダーの状態判断は Core の純粋計算に置いて
テストする（原則 IV）。ツールバー上の操作はすべて既存のキー割り当てでも行え、表示切替にも ⇧⌘T を
割り当てる（原則 III）。外部通信やデコードは追加しない（原則 I・II）。
FR-053〜055 のツリーの開閉（2026-10-20）は、`NSOutlineView` 標準の `doubleAction` と `isItemExpandable` に
Core の判断を渡すだけで成立し、新しい依存・設定・永続化を増やさない（原則 V）。サブフォルダの有無の確認は
表示中のフォルダの直下1階層に限り、最初の1件で打ち切り、同時 4 件までをバックグラウンドで行う。
10,000 ファイルのフォルダでの確認時間を性能テストで計測する（原則 II）。状態遷移と判断は Core で
テストする（原則 IV）。外部通信は追加しない（原則 I）。
FR-056〜060 の種類フィルタ（2026-10-20）は、Bool 2 つの値型 `MediaTypeFilter` と選択の整理の純粋計算を Core に置き、
`BrowserModel` の一覧の作り直しを1つの経路にまとめるだけで成立する。保存キー・設定・依存を増やさない（原則 V）。
切り替えはディスクを読まず、10,000 件での適用時間を計測する（原則 II）。キー割り当ては既存と衝突しない ⇧⌘I / ⇧⌘M とし、
ツールバーなしでも操作できる（原則 III）。外部通信は追加しない（原則 I）。
FR-061〜067 のお気に入り（2026-10-20）は、登録内容の値型・行の役割ごとの操作の可否・存在の確認を Core に置いてテストし（原則 IV）、
UI はツリーの行の追加とメニュー・確認モーダルの配線だけを担う。永続化はパスの配列1つで、実際のフォルダには触れない（原則 I・V）。
存在の確認はバックグラウンドで並列数を制限して行う（原則 II）。キーは既存と衝突しない ⌃⌘T / ⇧⌘F と、既存の ⌘⌫ の振り分けで、
マウスなしで全操作を行える（原則 III）。憲章の改定は不要。
FR-068〜075 の zip（2026-10-21）は、zip の読み取り・名前の判定・索引・範囲読み出し・AVFoundation の読み込み器・操作の可否をすべて Core に置いて
テストし（原則 IV）、UI は行の種類に応じたアイコン・メニューの有効無効・ダブルクリックと ⌘↓ / ⌘↑ の配線だけを担う。zip の中身はどこにも
書き出さず、ネットワークも使わない（原則 I）。読み出しはすべてバックグラウンドで、メモリの上限を項目のサイズに依存しない形で決めた（原則 II）。
⌘↓ / ⌘↑ は既存の割り当て（⌘O・⌥⌘1〜3・⇧⌘F など）と衝突しない（原則 III）。外部依存を足さない代わりに zip の読み取りを自前で持つため、
Complexity Tracking に理由を記録した（原則 V）。憲章の改定は不要。
FR-076〜078 のファイルリストのフォルダ（2026-10-21）は、フォルダの行の列挙・戻る先の判定・`..` の URL・操作の可否・同期の依頼をすべて Core に置いて
テストし（原則 IV）、ツリーは依頼の値を見て既存の `reveal` を走らせるだけにする。フォルダの操作は既存の確認・ゴミ箱の規則を通り、外部通信もない（原則 I）。
列挙は1回のまま、同期は一覧の表示を待たせない（原則 II）。⌘↓ / ⌘↑ と `..` の行でキーボードだけで辿れ、同期でフォーカスを奪わない（原則 III）。
新しい依存・保存キー・設定は増やさない（原則 V）。憲章の改定は不要。

## Project Structure

### Documentation (this feature)

```text
specs/001-three-pane-media-viewer/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── app-bundle.md
│   ├── core-api.md
│   ├── keyboard-and-menus.md
│   └── settings.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
Package.swift
Sources/
├── MediaViewerCore/                 # AppKit 非依存。すべての判断ロジック
│   ├── Model/                       # MediaKind, MediaFile, FolderNode（サブフォルダの有無を含む）,
│   │                                #   FolderDisclosure（ダブルクリックの開閉）, SortOrder, SelectionState,
│   │                                #   PreviewContent, ViewSettings, PlaybackOptions, FileOperation,
│   │                                #   FileListChrome（下部バーとツールバーのスライダーの状態）,
│   │                                #   MediaTypeFilter（画像・動画の種類フィルタ）,
│   │                                #   FavoriteFolders・FavoriteCommands（お気に入りの登録内容と操作の可否）,
│   │                                #   ListItemKind（一覧の行の種類）, ListItemCommands（行の操作の可否）,
│   │                                #   FolderNavigation（通常のフォルダの戻る先）, ParentLink（`..` の行の URL）
│   ├── Archive/                     # ZipArchiveReader, ZipStructure, ArchiveIndex, ArchiveURL, ArchiveLocation,
│   │                                #   ArchiveNameDecoder, InflateCursor, ArchiveEntryStream, ArchiveAssetLoader（zip の読み取り）
│   ├── Browser/                     # BrowserModel（選択・プレビュー・先読みの調停）
│   ├── FileSystem/                  # DirectoryLister, VolumeProvider, FileSystemWatcher (FSEvents),
│   │                                #   SubfolderProbe（サブフォルダの有無の並列数制限付き確認）,
│   │                                #   FavoriteProbe（お気に入りの存在の並列数制限付き確認）
│   ├── Imaging/                     # ImageDecoder, DecodedImageCache, ThumbnailProvider
│   ├── Layout/                      # FitCalculator, ThumbnailGridLayout, ThumbnailScroll, FocusNavigator
│   ├── Operations/                  # FileOperationService, NameValidation, uniqueName
│   └── Settings/                    # SettingsStore
├── MediaViewerApp/                  # AppKit UI。Core の状態を描画するだけ
│   ├── App/                         # main.swift, AppDelegate, MainMenu, MainWindowController,
│   │                                #   MainSplitViewController（フルスクリーン切替を含む）,
│   │                                #   MainToolbarController（NSToolbar の項目と表示状態）
│   ├── Shared/                      # IconCatalog（ツリー・リストの行頭アイコンの SF Symbol と寸法）
│   ├── Tree/                        # DirectoryTreeViewController (NSOutlineView、ドロップ先、お気に入りの見出しと項目)
│   ├── FileList/                    # FileListViewController, ListModeView (NSTableView),
│   │                                #   ThumbnailModeView (NSCollectionView), FileContextMenu
│   ├── Preview/                     # PreviewViewController, ImagePreviewView, VideoPreviewView
│   ├── Operations/                  # ConfirmationPresenter, ConflictPrompt
│   └── Settings/                    # SettingsWindowController
├── FixtureKit/                      # テスト・手動検証用のフィクスチャ生成（画像・動画・破損ファイル・zip）
├── make-fixtures/                   # 実行ターゲット（scripts/make-fixtures.sh から呼ぶ）
└── make-icon/                       # ビルド時のみ。CoreGraphics でアプリアイコンの各解像度を描画する

Tests/
├── MediaViewerCoreTests/            # 単体・異常系
└── MediaViewerPerformanceTests/     # 性能基準の計測

scripts/
├── make-app.sh                      # .app バンドルの組み立てと ad-hoc 署名
├── make-icon.sh                     # iconset の生成・解像度検証・icns 化
└── make-fixtures.sh                 # 手動検証用フォルダの生成
```

**Structure Decision**: 単一の Swift Package に、ライブラリ `MediaViewerCore`・実行ターゲット
`MediaViewerApp`・フィクスチャ生成用の `FixtureKit`・アイコン生成用の `make-icon` とテストターゲット2つを置く。
Core を AppKit から切り離すことで、憲章 原則 IV の「コアロジックを UI から分離し、単体でテスト可能に保つ」を
構造で担保する。`make-icon` はビルド時専用のツールで、実行時コードには含めない。
Xcode プロジェクトは持たず、CLI（`swift build` / `swift test` / `scripts/`）だけで完結させる（R2）。

## 変更点（2026-10-20: 小さい画像の拡大）

- `Sources/MediaViewerCore/Layout/FitCalculator.swift`: スケールの上限 `1` を外し、コンテナより
  小さい画像も拡大する。中央寄せ・縦横比維持・0 以下で `.zero` の扱いは変えない
- `Tests/MediaViewerCoreTests/FitCalculatorTests.swift`: 拡大の期待値に更新し、横長・縦長の拡大、
  極小（1×1）画像、中央寄せ、不正サイズのケースを追加する
- `Sources/MediaViewerApp/Preview/ImagePreviewView.swift`: コード変更は不要（`FitCalculator` の結果に
  レイヤーのフレームを合わせる既存の経路がそのまま拡大になる）。フルスクリーンも同じビューを通る
- 動画（`VideoPreviewView` / `AVPlayerView`）とデコード（`ImageDecoder`）は変更しない
- `README.md` の「小さい画像は原寸を超えて拡大しない」という記述を新しい挙動に合わせて直す

## 変更点（2026-10-20: サムネイル形式のキーボード追従スクロール）

- `Sources/MediaViewerCore/Layout/ThumbnailScroll.swift`（新規）: アイテム矩形と可視矩形から、
  アイテム全体が見える最小の縦スクロール位置を返す純粋計算を置く。既に見えていれば現在位置を返し、
  コンテンツ範囲 `0...(contentHeight - visibleHeight)` にクランプする。ビューポートより高いアイテムは
  上端を合わせる。横方向の値は扱わない（FR-015）
- `Tests/MediaViewerCoreTests/ThumbnailScrollTests.swift`（新規）: 下方向・上方向・一部見えている場合・
  既に見えている場合・先頭/末尾でのクランプ・ビューポートより高いアイテム・不正な寸法を検証する。
  画面外の項目へ移動したときの計算という不具合条件を再現するケースを含める（UI 配線は T093 で手動確認する）
- `Sources/MediaViewerApp/FileList/ThumbnailModeView.swift`: 矢印キーと Shift+矢印の移動後、
  および `scrollToFocused()` から共通の「フォーカス項目を表示」処理を呼ぶ。レイアウト済みの
  `layoutAttributesForItem(at:)` のフレームと `scrollView.contentView.bounds` から Core の計算で
  目標原点を求め、クリップビューを即時にスクロールする（アニメーションなし）。
  `layoutAttributesForItem(at:)` が nil の場合は、`ThumbnailGridLayout` とコンテンツ高から対象行の
  Y 範囲を推定する。推定も不能な場合のみ `NSCollectionView.scrollToItems(at:scrollPosition:)` を
  最終フォールバックにし、FR-017 が無言で満たされない状態を残さない。
  名前変更開始時のスクロールも同じ処理に統一する。リスト形式（`ListModeView`）は変更しない
- `specs/001-three-pane-media-viewer/contracts/keyboard-and-menus.md`: ファイルリストの矢印キーの行に、
  サムネイル形式の最小スクロール追従を追記する
- `specs/001-three-pane-media-viewer/contracts/core-api.md`: `ThumbnailScroll` の境界を追記する
- `specs/001-three-pane-media-viewer/quickstart.md`: 多数ファイルのサムネイル形式で、上下左右・
  Shift+矢印の移動にスクロールが追従する手動確認を追加する
- `Sources/MediaViewerApp/FileList/ListModeView.swift` と表示設定・永続化は変更しない

## 変更点（2026-10-20: フルスクリーン中の矢印キーによるファイル移動）

- `Sources/MediaViewerCore/Layout/FocusNavigator.swift`（新規）: 現在インデックス・件数・移動方向・
  レイアウト（リスト / サムネイルの列数）から移動先インデックスを返す純粋計算。リストは上/下を ∓1、
  左/右は移動なし。サムネイルは左/右を ±1、上/下を ∓列数。`0...(count-1)` にクランプし、端では
  `nil` を返す。空リスト、現在位置なし（先頭を選ぶ）、列数 0（1 として扱う）も定義する
- `Tests/MediaViewerCoreTests/FocusNavigatorTests.swift`（新規）: リスト・グリッドの4方向、先頭/末尾、
  行頭/行末、最終行の短い行、空リスト、列数不正を検証する
- `Sources/MediaViewerApp/FileList/ThumbnailModeView.swift`: `handleArrowKey` のインデックス計算を
  `FocusNavigator` に置き換える（既存の Shift+矢印の範囲選択とスクロール追従は維持）。移動先が `nil`
  のときは選択を変えずにキーを消費し、OS の既定動作へ渡さない。折りたたみ前の列数を取得できるよう、
  現在の列数を公開する
- `Sources/MediaViewerApp/FileList/FileListViewController.swift`: フルスクリーン開始時に表示形式と
  列数をスナップショットする `beginFullScreenNavigation()`、矢印移動をモデルへ反映する
  `moveFocusInFullScreen(_:)`、解除後に `scrollToFocused()` を呼ぶ `endFullScreenNavigation()` を追加する。
  フルスクリーン中の移動は単一選択にし、`BrowserModel.select([url], focused: url)` を使う
- `Sources/MediaViewerApp/App/MainSplitViewController.swift`: ペイン折りたたみ前にスナップショットを取得する。
  フルスクリーン中だけローカルの keyDown モニタを登録し、修飾キーなしの矢印を
  `moveFocusInFullScreen` へ、`<` / `>` を動画シークへ振り分ける。Cmd/Option/Control 付きのキー、
  Esc、Space は横取りしない。解除時（`windowDidExitFullScreen`）にモニタを外し、ペイン復元後に
  フォーカス項目が見える位置へそろえる
- `Sources/MediaViewerApp/Preview/PreviewViewController.swift` と `VideoPreviewView.swift`: `<` / `>`
  用に、現在位置から一定秒（5 秒）戻す / 送るシークを追加する。再生状態は変えない。
  動画以外では何もしない
- 通常表示のリスト形式・サムネイル形式のキー操作、選択状態、スクロール追従は変更しない。
  Shift+矢印による範囲選択はフルスクリーンでは対象外（spec の Outstanding）とし、イベントを横取りしない
- `specs/001-three-pane-media-viewer/contracts/keyboard-and-menus.md`、
  `contracts/core-api.md`、`data-model.md`、`quickstart.md`、`research.md` を更新する

## 変更点（2026-10-20: ツリーとリスト形式の行頭アイコン）

- `Sources/MediaViewerApp/Shared/IconCatalog.swift`（新規）: SF Symbols の選択と構成を一箇所に置く。
  - ツリー: `.home` → `house`、`.volume` → `externaldrive`、`.folder` → `folder`。展開状態では変えない
  - リストのフォールバック: `.jpeg` → `photo`、`.png` → `photo.on.rectangle`、`.gif` → `photo.stack`、
    `.webp` → `photo.circle`、`.mp4` → `film`、`.mov` → `video`。生成中・取得失敗時に使う
  - アイコンは template 画像として `NSImage.SymbolConfiguration` で 13〜16pt に構成し、
    選択・ダークモードの配色に追従させる。装飾なので a11y 要素にはしない
- `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift`: フォルダ列のセルを
  `imageView` + `textField` の `NSTableCellView` にし、`FolderNode.Kind` に応じたアイコンを設定する。
  テキストはアイコンの右に置き、既存のアクセス不可表示・選択・展開操作は変えない
- `Sources/MediaViewerApp/FileList/ListModeView.swift`: コンストラクタに `ThumbnailProviding` を追加。
  名前列のセルだけ `imageView` を持たせ、`representedObject` に URL を保持する。行の表示時に
  まず形式別フォールバックを設定し、`thumbnail(for:pointSize: 16, scale:)` を非同期に要求して
  取得後に同じ URL のセルへだけ差し替える。セル再利用時は
  `cancel(for:pointSize:scale:)` で同じ 64px 要求だけを取り消し、128px 以上のサムネイル形式の
  要求を巻き込まない。名前のインライン編集時もアイコンは残し、テキストの制約だけをアイコンの右側へ移す。
  行の高さはアイコンが収まる 20pt にする
- `Sources/MediaViewerCore/Imaging/ThumbnailProvider.swift`: 要求サイズの段階に 64px を追加し、
  `cancel(for:pointSize:scale:)` を URL + ピクセルサイズ単位のキャンセルに変更する
  （16pt × 2x = 32px を 64px に丸める）。既存の 128 / 256 / 512 の選択は変えない
- `Sources/MediaViewerApp/FileList/ThumbnailModeView.swift`: 進行中要求に `scale` を保持し、
  `cancel(for:pointSize:scale:)` へ移行する。要求サイズを変えたとき・セルを破棄したときに、
  同じ URL でも古いサイズの要求だけを取り消す
- `Tests/MediaViewerCoreTests/ThumbnailProviderTests.swift`: 50pt × 1x が 128 ではなく 64 になる
  期待値へ更新し、16pt × 1x / 2x、境界値、上限 512 のケースを追加する。URL + サイズ単位の
  キャンセルが他のサイズを巻き込まないことを、可能な範囲で再現する
- `Sources/MediaViewerApp/FileList/FileListViewController.swift`: 既存の `thumbnailProvider` を
  `ListModeView` へ渡す。表示形式の切替・フルスクリーン・ファイル操作の経路は変えない
- サムネイル形式（`ThumbnailModeView`）の表示、設定・永続化、Core の選択モデルは変更しない
- `specs/001-three-pane-media-viewer/contracts/core-api.md`、`data-model.md`、`research.md`、
  `quickstart.md` を更新する

## 変更点（2026-10-20: 表示を切り替えられるツールバー）

- `Sources/MediaViewerCore/Model/Settings.swift`: `ViewSettings` に `showsToolbar: Bool`（既定 `false`）を追加する。
  イニシャライザの既定引数にも加え、既存の呼び出しを壊さない
- `Sources/MediaViewerCore/Settings/SettingsStore.swift`: キー `view.showsToolbar` を追加し、
  `viewSettings` の読み書きに含める。値がない・Bool でない場合は `false`
- `Sources/MediaViewerCore/Model/FileListChrome.swift`（新規）: 表示形式とツールバーの表示状態から、
  下部のサイズバーを出すか（サムネイル形式かつツールバー非表示）と、ツールバーのスライダーを有効にするか
  （サムネイル形式）を返す純粋計算
- `Tests/MediaViewerCoreTests/SettingsStoreTests.swift`: 未保存時に `false`、保存と読み戻し、不正な型で
  `false`、他のキーを壊さないことを追加する
- `Tests/MediaViewerCoreTests/FileListChromeTests.swift`（新規）: 表示形式 2 種 × ツールバー表示 2 種の
  4 通りを検証する
- `Sources/MediaViewerApp/App/MainToolbarController.swift`（新規）: `NSToolbarDelegate`。識別子
  `MainToolbar`。項目は「表示形式」（`NSToolbarItemGroup`、`selectOne`、`square.grid.2x2` と
  `list.bullet`、ラベル「サムネイル」「リスト」）・「サイズ」（`NSSlider` を持つ `NSToolbarItem`）・
  可変スペースの順。`allowsUserCustomization = false`・`allowsDisplayModeCustomization = false`・
  `autosavesConfiguration = false`・`displayMode = .iconOnly`。操作は `FileListViewController` の
  公開メソッドへ渡し、状態の変化は `FileListViewController` からの通知で反映する。
  `isVisible` を KVO で監視し、どの経路で変わっても `SettingsStore` と `FileListViewController` へ伝える
- `Sources/MediaViewerApp/App/MainWindowController.swift`: ウィンドウ生成時に `MainToolbarController` を作り、
  保存された表示状態を `isVisible` に設定してから `window.toolbar` に入れる（表示前に決めてちらつかせない）。
  `toolbarStyle = .unified`。メニューのアクション `toggleMainToolbar(_:)` と `validateMenuItem` を実装し、
  項目名を「ツールバーを表示」「ツールバーを隠す」に切り替える。`NSWindow.toggleToolbarShown(_:)` は
  使わない（項目名が英語になるため、R18）
- `Sources/MediaViewerApp/App/AppDelegate.swift`: 起動時に `NSWindow.allowsAutomaticWindowTabbing = false` にし、
  AppKit が「表示」メニューへ自動で追加する「タブバーを表示」（⇧⌘T）と衝突させない（R18）
- `Sources/MediaViewerApp/App/MainMenu.swift`: 「表示」メニューの先頭に「ツールバーを表示」（⇧⌘T）と
  区切り線を追加する
- `Sources/MediaViewerApp/FileList/FileListViewController.swift`: `isToolbarShown` を追加し、
  `updateModeVisibility()` で `FileListChrome` を使って下部バーの表示を決める。ツールバーから呼ぶ
  `selectDisplayMode(_:)` と `applyThumbnailSize(_:)`（既存の `setDisplayMode` / `setThumbnailSize(_:persist: true)`
  を通す）と、表示形式・サイズが変わるたびに呼ぶ `onViewStateChange` を公開する。メニュー・下部バー・
  ツールバーのどこから変えても同じ経路を通る
- `Sources/MediaViewerApp/App/MainSplitViewController.swift`: `fileListViewController` をツールバーから
  参照できるようにする。`window(_:willUseFullScreenPresentationOptions:)` で `.autoHideToolbar` を
  加え、フルスクリーン中はツールバーをメニューバーと一緒に自動で隠す（保存した表示状態は変えない）
- 表示形式の切替・サムネイルサイズの規則、ファイル操作、プレビュー、フルスクリーン中の矢印移動は変更しない
- `specs/001-three-pane-media-viewer/contracts/keyboard-and-menus.md`、`contracts/settings.md`、
  `contracts/core-api.md`、`data-model.md`、`research.md`、`quickstart.md` を更新する

## 変更点（2026-10-20: ツリーのダブルクリック開閉と開閉の三角の表示条件）

- `Sources/MediaViewerCore/Model/FolderNode.swift`: `AccessState` に `.unavailable` を追加する。`SubfolderState`（`.unknown` / `.present` / `.absent` /
  `.failed`）と `subfolderState`（既定 `.unknown`）、計算プロパティ `isExpandable`、
  `applySubfolderProbe(_:)` と `applySubfolderListing(_:)` を追加する。イニシャライザの既定引数に加え、
  既存の呼び出しを壊さない。等価性と `hash` は `url` のままにする
- `Sources/MediaViewerCore/Model/FolderDisclosure.swift`（新規）: `doubleClickToggle(isExpandable:isExpanded:)`
- `Sources/MediaViewerCore/FileSystem/DirectoryLister.swift`: プロトコルに `hasSubfolders(in:)` を追加し、
  既定実装をプロトコル拡張に置く。`DirectoryLister` は `FileManager.enumerator` で最初の1件で打ち切る実装にする。
  判定条件・事前チェック（存在・ディレクトリか）・エラー変換は `subfolders(of:)` と共有する
- `Sources/MediaViewerCore/FileSystem/SubfolderProbe.swift`（新規）: `SubfolderProbeResult` と
  `SubfolderProbe.results(for:lister:maxConcurrent:)`。`withTaskGroup` で同時実行数を `maxConcurrent` 以下に保ち、
  `AsyncStream` の終了で残りを取り消す
- `Tests/MediaViewerCoreTests/FolderDisclosureTests.swift`（新規）: data-model の状態遷移表の全行、
  `isExpandable` の組み合わせ、`doubleClickToggle` の 4 通りを検証する
- `Tests/MediaViewerCoreTests/DirectoryListerTests.swift`: `hasSubfolders(in:)` を、空・ファイルだけ・隠しフォルダだけ・
  パッケージだけ・サブフォルダあり・権限なし（`0o000`）・存在しないパスで検証し、各ケースで
  `!subfolders(of:).isEmpty` と一致することを確かめる
- `Tests/MediaViewerCoreTests/SubfolderProbeTests.swift`（新規）: 遅延するフェイクの lister で、全 URL が1回ずつ
  流れること、同時実行数が上限を超えないこと、URL ごとのエラーが他に波及しないこと、空入力ですぐ終わること、
  取り消し後に新しい確認を始めないことを検証する
- `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift`: サブフォルダのない 10,000 ファイルの
  フォルダで `hasSubfolders(in:)` が 0.2 秒以内に `false` を返すことを計測する
- `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift`:
  - `isItemExpandable` は `node.folder.isExpandable` を返す
  - `outlineView.target = self`、`doubleAction = #selector(toggleClickedFolder(_:))` を設定する。
    `clickedRow` のノードについて `FolderDisclosure.doubleClickToggle` の結果で `expandItem` / `collapseItem` を呼ぶ
  - ルート（`viewDidLoad`・`applyRoots`）と、子を読み込んだ・読み直したときの新しい子に対して
    `SubfolderProbe` を開始する。親ごとに進行中の確認を `Task` で1つ持ち、作り直すときに取り消す。
    結果はノードに反映し、表示中の行だけ `reloadItem(_:reloadChildren: false)` する
  - `loadChildrenIfNeeded` / `reloadChildren(of:)` は、読み込み結果を `applySubfolderListing` に渡す。
    `.absent` になったら折りたたみ、開閉できるときだけ `expandItem` する。読み直しでは同じ URL の
    既存ノードの状態を引き継ぐ。権限以外の失敗（`.unavailable`）では三角を残して折りたたみ、次の展開で読み直す
  - セルの「アクセスできません」表示（グレーの文字とツールチップ）の条件を `.denied` または `.unavailable` にする。
    ドロップ先の判定は変えない
  - `applyRoots` でも既存ルートの `subfolderState` と `accessState` を引き継ぐ
  - `updateWatchSet()` は、表示中のフォルダ（ルートと展開中のフォルダの子）も監視対象に入れる。
    イベントが来た折りたたみ中のノードは再確認し、読み込み済みの子を捨てて次の展開で読み直す
    （折りたたみ中に起きた変更が、展開したときに古い子のまま表示される既存の問題も解消する）
  - `reveal(_:)` は各段で子を読み込んでから `expandItem` を呼ぶ
- `README.md`: ツリーの操作説明に、行のダブルクリックでの開閉と、三角はサブフォルダがあるときだけ出ることを追記する
- ファイルリスト・プレビュー・ファイル操作・設定・永続化は変更しない。ツリーのキー操作（FR-005）とドロップ（FR-020）、
  行頭アイコン（FR-047）も変えない
- `specs/001-three-pane-media-viewer/contracts/core-api.md`、`contracts/keyboard-and-menus.md`、`data-model.md`、
  `research.md`、`quickstart.md` を更新する

## 変更点（2026-10-20: 画像・動画の種類フィルタ）

- `Sources/MediaViewerCore/Model/MediaTypeFilter.swift`（新規）: `MediaTypeFilter`（`imagesOnly`・`videosOnly`、
  `isFiltering`・`includes(_:)`・`apply(to:)`・`noMatchesMessage`）
- `Sources/MediaViewerCore/Model/BrowserState.swift`: `FolderListing.State` に `.noMatches` を追加する。
  `SelectionState.restricted(toVisible:)` を追加する（data-model の表のとおり）
- `Sources/MediaViewerCore/Browser/BrowserModel.swift`:
  - 並べ替え済みの全件 `allFiles`（非公開）と `public private(set) var mediaTypeFilter`（既定は両方オフ）を持つ
  - `listing.files` と `listing.state` を作る処理を1つの非公開メソッドにまとめ、`loadFolder`・`reloadCurrentFolder`・
    `sortOrder` の `didSet` から呼ぶ。全件が空なら `.empty`、絞り込み後だけが空なら `.noMatches`、それ以外は `.loaded`。
    `sortOrder` の `didSet` の対象状態に `.noMatches` を加える
  - `setMediaTypeFilter(_:)` を追加する。同じ値なら何もしない。一覧を作り直し、`restricted(toVisible:)` で選択を整理する。
    フォーカスが変わらなければ `selection` だけを差し替えて先読みを組み直し、変わる場合は `select(_:focused:)` を呼ぶ
  - `selectFolder(_:)` は `mediaTypeFilter` を変えない。`reloadCurrentFolder()` の選択の扱いは変えず、絞り込み後の一覧に対して行う
- `Tests/MediaViewerCoreTests/MediaTypeFilterTests.swift`（新規）: 4 通りの `includes` と `isFiltering`、`apply(to:)` が
  並び順を保つこと、空入力、`noMatchesMessage` の文言と nil を検証する。`restricted(toVisible:)` は data-model の表の
  3 行に加え、フォーカスなし・複数選択の並び順（`Set` の順に依存しない）・空の表示一覧を検証する
- `Tests/MediaViewerCoreTests/BrowserModelTests.swift`: 既定が両方オフで全件が出ること、片方オンで絞られること、
  `.noMatches` と `.empty` の区別、フォルダを移っても絞り込みが残ること、並べ替え・FSEvents の読み直し後も絞り込みが
  効くこと、フォーカスが表示中なら選択とプレビューを変えないこと、新しい `BrowserModel` は保存値に関わらず両方オフで
  始まることを追加する
- `Tests/MediaViewerCoreTests/BrowserModelVideoTests.swift`: 再生中の動画が絞り込みで非表示になったとき、停止通知が
  増えてプレビューが空になることを追加する
- `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift`: 10,000 件への `MediaTypeFilter.apply(to:)` が
  0.05 秒以内であることを計測する
- `Sources/MediaViewerApp/FileList/FileListViewController.swift`:
  - `refresh()` に `.noMatches` を加え、`model.mediaTypeFilter.noMatchesMessage` を表示する。`updateModeVisibility()` では
    `.noMatches` を一覧を隠す状態として扱う
  - 「表示」メニューの「サムネイルを縮小」の後ろに区切り線と「画像のみ表示」（`keyEquivalent: "I"`）・
    「動画のみ表示」（`"M"`）を追加し、`model.mediaTypeFilter` の監視でチェックマークを更新する。
    `validateMenuItem` ではテキスト編集中に無効にする
  - `applyMediaTypeFilter(_:)`（メニュー・ツールバーの共通経路）と `onMediaTypeFilterChange` を公開する
- `Sources/MediaViewerApp/App/MainToolbarController.swift`: 識別子 `mediaTypeFilter` の `NSToolbarItemGroup`
  （`selectAny`、`photo` と `film`、ラベル「画像のみ表示」「動画のみ表示」、ツールチップとアクセシビリティラベルも同じ）を
  追加し、既定と許可の並びを「種類フィルタ」「表示形式」「サイズ」「可変スペース」にする。クリック時は
  `isSelected(at:)` から `MediaTypeFilter` を作って `applyMediaTypeFilter(_:)` へ渡し、`onMediaTypeFilterChange` で
  `setSelected(_:at:)` を合わせる。テキスト編集中のクリックは無視して表示を元に戻す
- `Sources/MediaViewerApp/App/MainSplitViewController.swift`: `deliverInitialListingIfReady()` の網羅的な `switch` に
  `.noMatches` を加える（表示済みとして扱う）。フルスクリーンのキー処理は変更しない
- `ListModeView`・`ThumbnailModeView`・`PreviewViewController`・ファイル操作・ツリー・設定と永続化は変更しない
  （`listing.files` と `selection` の既存の監視で絞り込みが反映される）
- `README.md`: ファイルリストの操作説明に、種類フィルタのボタン・メニュー・⇧⌘I / ⇧⌘M を追記する
- `specs/001-three-pane-media-viewer/contracts/core-api.md`、`contracts/keyboard-and-menus.md`、`contracts/settings.md`、
  `data-model.md`、`research.md`、`quickstart.md` を更新する

## 変更点（2026-10-20: お気に入り）

- `Sources/MediaViewerCore/Model/FavoriteFolders.swift`（新規）: `FavoriteFolders`（`urls`・`contains`・`add`・`remove`、
  `standardizedFileURL.path` による同一性）と `FavoriteAvailability`
- `Sources/MediaViewerCore/Model/FavoriteCommands.swift`（新規）: `TreeItemRole`・`TreeContextMenuItem`・`FavoriteCommands`
  （`canAdd`・`removalTarget`・`contextMenu(for:)`・`folderToShow(for:)`・`acceptsFiles`）。data-model の表のとおり
- `Sources/MediaViewerCore/FileSystem/FavoriteProbe.swift`（新規）: `FavoriteProbeResult` と `FavoriteProbe`
  （`folderExists(_:)`・`results(for:maxConcurrent:exists:)`）。`SubfolderProbe` と同じく `withTaskGroup` で同時実行数を制限し、
  `AsyncStream` の終了で残りを取り消す
- `Sources/MediaViewerCore/Settings/SettingsStore.swift`: キー `favorites.paths` と `favorites` プロパティを追加する。
  読み込みの不正値の扱いは contracts/settings.md のとおり。ほかのキーの読み書きは変えない
- `Tests/MediaViewerCoreTests/FavoriteFoldersTests.swift`（新規）: 登録順、末尾の `/`・`..` を含む重複の判定、
  `add` / `remove` の戻り値、`init(urls:)` の重複除去と順序を検証する
- `Tests/MediaViewerCoreTests/FavoriteCommandsTests.swift`（新規）: data-model の「TreeItemRole と FavoriteCommands」の表の全行
  （役割 3 種 × 登録済みかどうか、選択なし）を検証する
- `Tests/MediaViewerCoreTests/FavoriteProbeTests.swift`（新規）: 一時ディレクトリで、存在するフォルダ・存在しないパス・ファイル・
  権限のないフォルダ（`0o000`、存在するので `true`）を検証する。遅延するフェイクの `exists` で、全 URL が1回ずつ流れること、
  同時実行数が上限を超えないこと、空入力ですぐ終わること、取り消し後に新しい確認を始めないことを検証する
- `Tests/MediaViewerCoreTests/SettingsStoreTests.swift`: 未保存で空、保存と読み戻しで順序が保たれること、配列でない値・
  文字列でない要素・空文字・相対パスを捨てること、重複の除去、ほかのキーを壊さないことを追加する
- `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift`:
  - コンストラクタに `SettingsStore` と `ConfirmationPresenter` を追加する。`viewDidLoad` で `settings.favorites` を読み込む
  - 行の型に `FavoritesHeader`（1つだけ）と `FavoriteEntry`（`url`・`name`・`kind`・`availability`）を加える。
    データソースのトップレベルは `[header] + roots`、見出しの子は登録順の項目。見出しは常に開閉でき、項目は開閉できない。
    行から `TreeItemRole` を作る `role(for:)` を置き、操作の可否はすべて `FavoriteCommands` に問い合わせる
  - セル: 見出しは `IconCatalog.favoritesIcon` と「お気に入り」、項目はルートと同じ規則で決めた `kind` のアイコンと名前。
    `.missing` の項目は `disabledControlTextColor` とツールチップ「見つかりません」
  - `outlineViewSelectionDidChange`: `FavoriteCommands.folderToShow(for:)` が nil（見出し）なら `selectFolder` を呼ばない。
    項目なら `selectFolder(entry.url)` を呼び、その項目の存在を確認する
  - 右クリックメニューを `NSMenuDelegate.menuNeedsUpdate(_:)` で `clickedRow`（なければ選択中の行）の役割から作り直す。
    既存の「ここにペースト」「ここに移動ペースト」「Finder に表示」の対象も右クリックした行にそろえる
  - `addToFavorites(_:)`（右クリックメニュー）と、`MainSplitViewController` から呼ぶ `addSelectedFolderToFavorites()`・
    `canAddSelectedFolderToFavorites`・`focusFavoritesHeader()` を追加する。登録したら保存し、見出しの子を読み直し、
    存在を確認する。見出しの開閉状態は変えない
  - `@objc func moveToTrash(_:)`: お気に入りの項目を選択中のときだけ、`confirmRemovingFavorite(named:)` → 削除 → 保存 →
    見出しを選択する。`validateMenuItem` で、項目の選択中だけ有効にして項目名を「お気に入りから削除」にし、
    それ以外は無効にして「ゴミ箱に入れる」に戻す。右クリックメニューの「お気に入りから削除」も同じ削除処理を通す
  - `paste(_:)`・`movePaste(_:)`・`validateDrop`・`acceptDrop` は `FavoriteCommands.acceptsFiles` が false の行
    （見出し・項目）では無効にする
  - 存在の確認（`FavoriteProbe`）を、起動時・`volumes.changes`・`NSApplication.didBecomeActiveNotification`・FSEvents のバッチ・
    登録直後・項目の選択時に始める。進行中の確認は1つだけ持ち、作り直すときに取り消す。結果は項目に反映し、変わった行だけ
    `reloadItem` する
  - `updateWatchSet()` に、登録したフォルダの親フォルダを加える
  - `applyRoots` の `reloadData()` の後に、見出しが展開中だったら展開し直す。`reveal(_:)`・`rowForURL`・`reloadChildren(of:)` は
    実際の階層（`roots`）だけを見るため、お気に入りの項目を選択中でも実際の階層の選択に戻さない
- `Sources/MediaViewerApp/App/MainMenu.swift`: 「ファイル」メニューの「Finder に表示」の後ろに「お気に入りに追加」
  （`keyEquivalent: "t"`、`[.command, .control]`、アクション `MainSplitViewController.addSelectedFolderToFavorites(_:)`、宛先なし）を追加する。
  「ファイル」「編集」メニューに `NSMenuDelegate` を設定し、`menuNeedsUpdate(_:)` で `moveToTrash(_:)` の項目名を「ゴミ箱に入れる」に戻す
- `Sources/MediaViewerApp/App/MainSplitViewController.swift`: ツリーに `SettingsStore` と `ConfirmationPresenter` を渡す。
  `addSelectedFolderToFavorites(_:)` をツリーへ渡す。`installFocusMenuItems()` で ⌥⌘3 の後ろに「お気に入りへ移動」
  （`keyEquivalent: "F"`、⇧⌘）を追加し、`focusFavoritesHeader()` を呼ぶ。`NSMenuItemValidation` を実装し、
  「お気に入りへ移動」はフルスクリーン中（`panesCollapsedForFullScreen`）とファイル名の変更中は無効、
  「お気に入りに追加」はファイル名の変更中と `canAddSelectedFolderToFavorites == false` のとき無効にする
- `Sources/MediaViewerApp/FileList/FileListViewController.swift`: `isEditingText` を内部公開にする（`MainSplitViewController` の
  メニュー検証で使う）。ゴミ箱の処理と検証は変えない
- `Sources/MediaViewerApp/Operations/ConfirmationPresenter.swift`: `confirmRemovingFavorite(named:)` を追加する。
  既存の `confirm(_:)` とシートの表示・「今後この確認を表示しない」の処理を共有する
- `Sources/MediaViewerApp/Shared/IconCatalog.swift`: `favoritesIcon`（`star.fill`、13pt、template）を追加する
- `Sources/MediaViewerApp/Settings/SettingsWindowController.swift`: 確認のチェックボックスの文言を
  「コピー・移動・名前の変更・ゴミ箱に入れる・お気に入りから削除する前に確認する」にする
- `README.md`: ツリーの操作説明に、お気に入りの登録（右クリック・⌃⌘T）・削除（右クリック・⌘⌫）・移動（⇧⌘F）と、
  見つからない項目の表示を追記する
- ファイルリスト・プレビュー・ファイル操作・`BrowserModel` の選択の規則は変更しない。ツリーの既存のキー操作（FR-005）・
  ダブルクリックの開閉（FR-053）・三角の表示条件（FR-054・055）・ドロップ（FR-020）は、実際の階層では変えない
- `specs/001-three-pane-media-viewer/contracts/core-api.md`、`contracts/keyboard-and-menus.md`、`contracts/settings.md`、
  `data-model.md`、`research.md`、`quickstart.md` を更新する

## 変更点（2026-10-21: zip ファイル）

Core（`Sources/MediaViewerCore/`）:

- `Model/MediaKind.swift`: `ListItemKind`（`.media(MediaKind)` / `.archive` / `.directory` / `.parent`）と `isMedia`・`mediaKind`・`isVideo`・
  `opensAsContainer` を追加する。`MediaKind` は変えない
- `Model/MediaFile.swift`: `kind` の型を `ListItemKind` にする。既存の呼び出し（`kind.isVideo`、`IconCatalog.fallbackIcon(for:)`、並べ替え）は
  `ListItemKind` の同名のプロパティか `mediaKind` へ移す
- `Model/BrowserState.swift`: `FolderListing.archive: ArchiveLocation?`（既定 nil）と `PreviewContent.animatedImageData(URL, Data)` を追加する
- `Model/MediaTypeFilter.swift`: `apply(to:)` で `.media` 以外の行を残す
- `Model/Sorting.swift`: `.parent` を取り除いてから並べ、先頭に戻す。「種類」列の第2キーを `ListItemKind` の順序にする
- `Model/ListItemCommands.swift`（新規）: data-model の表のとおり
- `Archive/`（新規）:
  - `ArchiveURL.swift`・`ArchiveLocation.swift`: URL の生成と解析、階層の親
  - `ZipStructure.swift`: 終端レコードの探索・ZIP64・中央ディレクトリ・ローカルヘッダの解析。`Data` を受ける純粋関数にする
  - `ArchiveNameDecoder.swift`: FR-074 の判定（R27）
  - `ArchiveIndex.swift`: 項目の木、隠し項目・`__MACOSX`・`..`・重複の扱い、`readability`、`items(in:)`
  - `ZipArchiveReader.swift`: `ArchiveReading` の実装。ファイル記述子を参照カウントで共有し、`pread` だけで読む。`ArchiveIdentity` を返す
  - `InflateCursor.swift`・`ArchiveEntryStream.swift`: 順方向の展開カーソルと、チャンクキャッシュ付きの範囲読み出し（R25）
  - `ArchiveAssetLoader.swift`: `AVAssetResourceLoaderDelegate` と `ArchiveAssetFactory`
  - `ArchiveError.swift`: 失敗の種類と UI に出す文言
- `FileSystem/DirectoryLister.swift`: `.zip` のファイルを `kind: .archive` で返す（ディレクトリの `x.zip` はこれまでどおり返さない）
- `Imaging/ImageDecoder.swift`: `decode(data:maxPixelSize:)` と `isAnimated(data:)` を追加する。ファイル URL の経路と判定・エラーを共有する
- `Imaging/ThumbnailProvider.swift`: イニシャライザに `ArchiveReading` を追加し、`mvzip` の URL で R24 の経路を使う。同時実行数の制限を足す
- `Browser/BrowserModel.swift`:
  - イニシャライザに `archiveReader: any ArchiveReading` を追加する（既定引数で既存のテストを壊さない）
  - `openItem(_:)`・`goToEnclosingLevel()`・`isBrowsingArchive` を追加する。開いている `ArchiveIndex` と、戻ったときに選ぶ行を持つ
  - `rebuildListing()` で `..` を先頭に加え、FR-060 の空の判定（`.empty` / `.noMatches` / `.loaded`）を行の種類で行う
  - `loadPreview` はフォーカス行の `kind` で分岐する。メディア以外は `.empty`（FR-075）。zip の中の画像は `.loading` にしてから
    バックグラウンドで `Data` を読み、`animatedImageData` か `.image` にする（R24）。動画は `.video(url)` のまま
  - 先読みは zip の中の画像でも同じ規則で行う（動画・アニメーションは対象外）
  - `selectFolder(_:)` で zip の状態を捨てる。`handleFileSystemEvent` は zip の中なら `ArchiveIdentity` を比べる
- `Layout/FocusNavigator.swift`: `isNavigable` を受けるオーバーロードを追加する（既存の関数の結果は変えない）

テスト（`Tests/`）:

- `MediaViewerCoreTests` に新規: `ArchiveURLTests`・`ArchiveNameDecoderTests`・`ZipStructureTests`・`ArchiveIndexTests`・`ZipArchiveReaderTests`・
  `ArchiveEntryStreamTests`・`ArchiveAssetLoaderTests`・`ListItemCommandsTests`・`BrowserModelArchiveTests`（内容は Constitution Check IV の行のとおり）
- 既存に追加: `FocusNavigatorTests`（読み飛ばし・端・全部が移動できない行）、`MediaTypeFilterTests`（メディア以外の行を残す）、
  `SortingTests`（`..` が先頭・ディレクトリとメディアの混在）、`DirectoryListerTests`（`.zip`・`.ZIP` を返す、`x.zip` のディレクトリは返さない）、
  `ImageDecoderTests`（`Data` からのデコードとアニメーション判定）、`ThumbnailProviderTests`（zip の中の画像、暗号化で nil）、
  `BrowserModelTests`（zip の行を選ぶとプレビューが空、zip だけのフォルダは `.loaded`）。既存のテストは `kind: .media(...)` への置き換えだけで通す
- `MediaViewerPerformanceTests/PerformanceBaselineTests.swift`: 10,000 項目の zip の索引作成 0.5 秒以内、展開後 1GB の deflate 項目の読み出しで
  物理フットプリントの増加 128MB 以下（R25）

フィクスチャ（`Sources/FixtureKit/`）:

- `ZipFixtureWriter.swift`・`CRC32.swift`（新規）: R28 のとおり
- `FixtureSets.swift`: `zip(in:)` を追加し、`makeAll` に加える（quickstart の `zip/`）。SC-014 のメモリの確認用の `bigVideoZips(in:)`（`zip-big/`）は
  `makeAll` に含めない
- `VideoFixtures.swift`: `fastStart`（`shouldOptimizeForNetworkUse`）と `averageBitRate` の引数を追加する（既定値では従来と同じファイル）
- `Sources/make-fixtures/main.swift` と `scripts/make-fixtures.sh`: `--big` を受けて `zip-big/` を作る
- `scripts/check-no-archive-writes.sh`（新規）: `Sources/MediaViewerCore/Archive/` に書き込み系の API がないことを確かめる（FR-072、R28）

App（`Sources/MediaViewerApp/`）:

- `App/MainSplitViewController.swift`: `ZipArchiveReader` を1つ作り、`BrowserModel`・`ThumbnailProvider`・`PreviewViewController` に渡す
- `App/MainMenu.swift`: 「ファイル」メニューの「開く」の後ろに「中を表示」（⌘↓、`NSDownArrowFunctionKey`）と「上の階層へ」（⌘↑）を追加する。宛先なし
- `FileList/FileListViewController.swift`: `openFocusedItem(_:)`・`goToEnclosingLevel(_:)` を追加し、`ListItemCommands` で `validateMenuItem` と各アクションの
  先頭の判定を行う。戻った後に `scrollToFocused()` を呼ぶ。`.empty` / `.noMatches` / `.failed` で行が残る場合は、一覧を出したまま下端に
  メッセージの帯を出す。`moveFocusInFullScreen` は `isNavigable` 付きの `FocusNavigator` を使う
- `FileList/ListModeView.swift`: `doubleAction` で `openFocusedItem` を呼ぶ。メニュー項目が無効なときの ⌘↓ / ⌘↑ を `keyDown` で消費する（R26）。Return の名前の変更とドラッグ（`pasteboardWriterForRow`）を
  `ListItemCommands` で止める。メディア以外の行は SF Symbol だけを出し、縮小画像を要求しない
- `FileList/ThumbnailModeView.swift`: クリック数 2 で `openFocusedItem` を呼ぶ。⌘↓ / ⌘↑ を同じく消費する。Return とドラッグ（`pasteboardWriterForItemAt`）を同じく止める。
  メディア以外のセルは SF Symbol を出す
- `FileList/FileContextMenu.swift`: 「中を表示」「上の階層へ」を加え、zip の中ではファイル操作の項目を無効にする
- `Preview/PreviewViewController.swift`: `animatedImageData` を表示する。`mvzip` の動画は `ArchiveAssetFactory` の asset で `VideoPreviewView` を構成する
- `Preview/ImagePreviewView.swift`: `CGAnimateImageDataWithBlock` で `Data` のアニメーションを再生する経路を足す
- `Preview/VideoPreviewView.swift`: `configure` に `AVAsset` を受ける形を足す（ファイル URL の経路は変えない）
- `Shared/IconCatalog.swift`: `doc.zipper`・`folder`・`arrowshape.turn.up.left` と `ListItemKind` からのアイコン選択を追加する
- ツリー（`DirectoryTreeViewController`）・設定・永続化・ファイル操作のサービスは変更しない

ドキュメント:

- `README.md`: ファイルリストの操作説明に、zip の中の表示（ダブルクリック・⌘↓ / ⌘↑・`..`）と、読み取り専用であることを追記する
- `specs/001-three-pane-media-viewer/contracts/core-api.md`、`contracts/keyboard-and-menus.md`、`contracts/settings.md`、`data-model.md`、
  `research.md`、`quickstart.md` を更新した

## 変更点（2026-10-21: ファイルリストのフォルダ・`..`・ツリーの同期）

Core（`Sources/MediaViewerCore/`）:

- `Model/MediaKind.swift`: `ListItemKind` に `.folder` を追加する。`opensAsContainer` に含め、`sortKey` は `"folder"`。`.parent` のコメントを
  「zip の中と通常のフォルダの先頭行 `..`」にする
- `Model/FolderNavigation.swift`（新規）: `enclosingFolder(of:roots:)`（data-model の表のとおり）
- `Model/ParentLink.swift`（新規）: `mvparent:` の URL の生成と判定
- `Model/ListItemCommands.swift`: `hasEnclosingLevel`（既定は `isBrowsingArchive`）を受け、`canGoUp` をそれで決める。`allowsFileOperations` は
  `.parent` でも false にする（data-model の表のとおり）
- `Model/BrowserState.swift`: `TreeSyncRequest` を追加する
- `FileSystem/DirectoryLister.swift`: `mediaFiles(in:)` で、`isVisibleSubfolder` を満たすディレクトリを `kind: .folder`（`typeDescription` は「フォルダ」）で返す。
  ドキュメントコメントを更新する
- `Operations/NameValidation.swift`: `validateNewName` に `isDirectory: Bool = false` を足し、true なら拡張子の変更の確認を返さない
- `Browser/BrowserModel.swift`:
  - `navigationRoots`（非公開）と `setNavigationRoots(_:)`。変わったら、読み込み済みの状態なら `rebuildListing()` で `..` を作り直す
  - `hasEnclosingLevel`・`operableSelection`・`treeSyncRequest`（`public private(set)`）を追加する
  - `rebuildListing()`: zip の外では `FolderNavigation.enclosingFolder` が nil でないときだけ `ParentLink` の `..` の行を先頭に加える。名前は `..`
    （zip の中の `parentRow` の名前も `..` に変える）
  - 読めないフォルダ（`.denied` / `.failed`）でも、ルート以外なら `files` を `..` の行だけにする（行き止まりを作らない。FR-077）
  - `openItem(_:)`: `.folder` は `navigateToFolder(url, selecting: nil)`。`.parent` は zip の中か外かに関わらず `goToEnclosingLevel()`
  - `goToEnclosingLevel()`: zip の外では `enclosingFolder` があれば `navigateToFolder(parent, selecting: 直前のフォルダ)`
  - `navigateToFolder(_:selecting:)`（非公開）: `selectFolder` と同じ手順で読み込み、`lastFolder` を保存し、`treeSyncRequest` の `id` を増やして出す。
    読み込み後に `selecting` の行があれば `select([url], focused: url)` する
  - `selectFolder(_:)` は `treeSyncRequest` を出さない（既存のまま）
- `Imaging/ThumbnailProvider.swift`: 変更しない（UI がメディアの行にしか要求しない）

テスト（`Tests/`）:

- 新規: `FolderNavigationTests`（ルートそのもの・ホームと `/` の両方に含まれる・外付けボリューム・ルート外・空のルート・`/Users/me2`）、
  `ParentLinkTests`（生成・判定・スペースや日本語を含むパス）、`BrowserModelFolderTests`（`.folder` を開くと一覧が変わり選択が空・`lastFolder`
  が変わる・`treeSyncRequest` が増える、`..` と `goToEnclosingLevel` で親へ戻り直前のフォルダが選択される、ルートでは `..` がなく
  `goToEnclosingLevel` が何もしない、ルートが空なら `..` を出さない、`setNavigationRoots` で `..` が出入りする、`selectFolder` と zip の中の移動では
  `treeSyncRequest` が変わらない、`operableSelection` が `..` を除く、フォルダだけの階層は `.loaded`・空のフォルダは `.empty` で `..` が残る、
  種類フィルタでフォルダが残る、フォルダの行を選ぶとプレビューが空になり動画の停止通知が増える）
- 既存に追加: `DirectoryListerTests`（サブフォルダを `.folder` で返す、隠しフォルダ・パッケージを返さない、`x.zip` のディレクトリは `.folder`、
  返すフォルダが `subfolders(of:)` と一致する）、`ListItemCommandsTests`（`.folder` と通常のフォルダの `..` の行、`hasEnclosingLevel` の有無）、
  `NameValidationTests`（フォルダで拡張子の確認を出さない）、`SortingTests`（フォルダが混ざって並び `..` が先頭）、`FocusNavigatorTests`
  （`.folder` を読み飛ばす）、`MediaTypeFilterTests`（`.folder` を残す）。既存の `BrowserModelArchiveTests` の `...` の期待値を `..` にする
- `MediaViewerPerformanceTests/PerformanceBaselineTests.swift`: 10,000 ファイルと 1,000 サブフォルダのフォルダで `mediaFiles(in:)` が 1 秒以内（SC-003 の列挙と同じ基準）

フィクスチャ（`Sources/FixtureKit/`）:

- `FixtureSets.swift`: `folders(in:)`（quickstart の `folders/`）を追加して `makeAll` に加える。`ops(in:)` に `album/`（JPEG 2 枚と `inner/`）を加える

App（`Sources/MediaViewerApp/`）:

- `App/MainSplitViewController.swift`: 最初の `selectFolder` の前に `model.setNavigationRoots(volumes.rootNodes().map(\.url))` を呼ぶ。
  `FileOperationCoordinator.onFoldersChanged` をツリーの `refreshFolders(_:)` に結ぶ
- `Tree/DirectoryTreeViewController.swift`:
  - `applyRoots` の最後に `model.setNavigationRoots(roots.map(\.url))` を呼ぶ
  - `treeSyncRequest` を `withObservationTracking` で監視し、`revealTask` を取り消してから `reveal(folder)` を始める。完了時に `id` が最新のときだけ、
    `isRestoringSelection = true` の間に行を選択して `scrollRowToVisible` する。`makeFirstResponder` は呼ばない
  - `reveal(_:)` のルートの選び方を「対象を含むルートのうち最も深いもの」にする（ホームの配下を起動ボリューム側から辿らない）
  - `refreshFolders(_:)` を追加し、FSEvents のバッチと同じ処理（`reloadChildren(of:)`・サブフォルダの再確認・お気に入りの存在の確認）を通す
  - `validateDrop`: ドラッグ中の URL がドロップ先のフォルダ自身か祖先なら `[]` を返す
  - 右クリックメニューと ⌘⌫ は変えない（FR-064）
- `Operations/FileOperationCoordinator.swift`: `onFoldersChanged: ((Set<URL>) -> Void)?` を追加し、コピー・移動・名前の変更・ゴミ箱・複製の完了後に
  対象の親フォルダと操作先を渡す。名前の変更の検証に `isDirectory` を渡す
- `Operations/ConfirmationPresenter.swift`: 対象にフォルダが含まれるときの「フォルダは中身ごと」の文言を足す
- `FileList/ListItemSupport.swift`: `focusedItemCommands` と `itemCommands(forRowAt:)` に `hasEnclosingLevel` を渡す
- `FileList/FileListViewController.swift`: `selectedFileURLs` を `model.operableSelection` にする。`goToEnclosingLevel(_:)` の判定は
  `canGoUp`（`hasEnclosingLevel`）のまま。フォルダを開いた後・戻った後のスクロールは既存の `scrollFocusedItemIntoViewAfterModelUpdate()` を使う
- `FileList/ListModeView.swift`・`FileList/ThumbnailModeView.swift`: `.folder` の行は SF Symbol `folder` を出して縮小画像を要求しない。ダブルクリックは
  既存の `opensAsContainer` の判定で開く。ドラッグは `ListItemCommands` の判定（`.folder` は可、`.parent` は不可）にそろえる。
  `..` の表示名を `..` にする（a11y ラベルは「上の階層へ」のまま）
- `FileList/FileContextMenu.swift`: 「上の階層へ」の表示条件を `isBrowsingArchive` から `focusedItemCommands.canGoUp` にする
- `Shared/IconCatalog.swift`: `.folder` に `folder` を割り当てる（`.directory` と同じ）

ドキュメント:

- `README.md`: ファイルリストの操作説明に、フォルダの表示・ダブルクリックと ⌘↓ / ⌘↑ / `..` での移動・ツリーの同期・フォルダの操作を追記し、
  zip の `...` の記述を `..` に直す
- `specs/001-three-pane-media-viewer/contracts/core-api.md`、`contracts/keyboard-and-menus.md`、`data-model.md`、`research.md`、`quickstart.md` を更新した
  （`contracts/settings.md` は保存キーが増えないため変更なし）

## Complexity Tracking

| 導入する複雑さ | 必要な理由 | 採らなかったより単純な案と、その理由 |
|----------------|------------|--------------------------------------|
| zip の読み取り器を自前で持つ（`ZipStructure`・`ZipArchiveReader`・`InflateCursor`、R22・R25） | FR-072 の「一時ファイルに展開しない」と、動画のストリーミング再生（2026-10-21 のユーザー判断）には、zip の中の項目の任意の範囲を読む手段が要る。Apple 標準のフレームワークには公開 API がない | `unzip` / `ditto` の子プロセス（一時ファイルが必要で FR-072 に反する）、ZIPFoundation などの外部パッケージ（原則 V と AGENTS.md の「外部依存なし」に反する）、libarchive（SDK に公開ヘッダがない） |
| 動画用の `AVAssetResourceLoaderDelegate` とチャンクキャッシュ（R25） | 動画全体をメモリに展開せずに AVPlayer へ渡すため（SC-014） | 動画全体をメモリに展開（メモリが動画のサイズに比例し SC-014 に反する）、一時ファイル（FR-072 に反する） |
