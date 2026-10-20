# Research: 3ペイン型メディアビューア

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-19

Technical Context の未確定事項と主要な技術選択について、決定・理由・検討した代替案を記録する。

## R1. 実装言語と UI フレームワーク

- **Decision**: Swift 6（strict concurrency）+ AppKit。外部ライブラリは使わず Apple 標準フレームワークのみ
- **Rationale**:
  - Finder 相当の部品（NSOutlineView / NSTableView / NSCollectionView / NSSplitView）、ゴミ箱、
    ドラッグ&ドロップ、ペーストボード、アクセシビリティ API が OS 標準で揃う（原則 III・V）
  - mp4 / mov 再生（AVKit）、JPEG / PNG / GIF / WebP デコード（ImageIO）も標準で賄え、外部依存ゼロ（原則 V）
  - ネイティブのため起動が速くメモリも小さい（原則 II）。ネットワークを使う依存がない（原則 I）
  - ユーザー選択（2026-10-19）
- **Alternatives considered**:
  - Tauri: 他 OS 展開に有利だが Rust 未導入、Finder 風の振る舞いと a11y を自前実装する量が多い
  - Electron: 起動時間・メモリが憲章の性能基準に不利
  - SwiftUI 主体: `Table` のインライン名前変更、遅延展開ツリー、ツリーへのドロップ先制御、
    `HSplitView` の最小幅と幅の永続化が AppKit より弱い。2つの UI フレームワーク併用は避け、AppKit に統一

## R2. プロジェクト形態とビルド

- **Decision**: Swift Package（`Package.swift`）で構成する。ロジックをライブラリ `MediaViewerCore`、
  UI を実行ターゲット `MediaViewerApp` に分ける。配布用 `.app` は `scripts/make-app.sh` で
  バンドルを組み立て、ad-hoc 署名する
- **Rationale**: `swift build` / `swift test` だけで CLI から完結し、`.xcodeproj` の手管理が不要。
  Core を AppKit 非依存にすることで、UI を起動せずに単体テストできる（原則 IV）
- **Alternatives considered**: Xcode プロジェクト（差分レビューしにくい）、XcodeGen（外部依存が増える）

## R3. 対象 OS バージョン

- **Decision**: macOS 15 以降（開発機は macOS 26.6）
- **Rationale**: Swift 6 の並行処理モデル、ImageIO の WebP デコード（macOS 11+）、
  `QLThumbnailGenerator`（10.15+）がすべて利用でき、個人利用で古い OS を支える理由がない
- **Alternatives considered**: macOS 26 のみ（新 API の必要がなく、絞る利点がない）

## R4. テスト

- **Decision**: Swift Testing（`import Testing`）。`MediaViewerCoreTests`（単体・異常系）と
  `MediaViewerPerformanceTests`（性能基準の計測）の2ターゲット。テスト用の画像・動画・破損ファイル・
  10,000 ファイルのフォルダは、テスト実行時に一時ディレクトリへ生成する
- **Rationale**: 憲章 原則 IV は UI の見た目テストを求めないため、コアロジックを UI から分離して網羅する。
  フィクスチャを生成方式にすることで、大きなバイナリをリポジトリに置かない
- **Alternatives considered**: XCTest（Swift 6 では Swift Testing が標準）、XCUITest（SwiftPM 単体では
  使えず、UI は quickstart の手動検証で担保）

## R5. 画像デコードとプレビュー表示

- **Decision**: ImageIO の `CGImageSourceCreateThumbnailAtIndex` で、表示先スクリーンのピクセルサイズを
  上限にダウンサンプリングしてデコードする。アニメーション GIF / WebP は `CGAnimateImageAtURLWithBlock`
  で再生する。表示位置・大きさは Core の `FitCalculator` が計算し、縦横比を保ったままコンテナ内で
  最も大きくなる矩形を中央に置く。縮小だけでなく拡大も行い、拡大率の上限は設けない（FR-028）
- **Rationale**:
  - 1億画素級の画像でもフル解像度を展開せずに済み、メモリと時間を抑えられる（SC-001・エッジケース）
  - スクリーンサイズでデコードしておけば、ペインのリサイズやフルスクリーン切替で再デコードが不要
  - デコードはバックグラウンドで行い、UI スレッドを塞がない（原則 II）
- **Alternatives considered**: `NSImage(contentsOf:)`（遅延デコードで、表示時に UI スレッドで全解像度を
  展開しうる）、`NSImageView.animates`（WebP アニメーションの扱いが不確実）
- **アニメーション WebP**: `CGAnimateImageAtURLWithBlock` で再生できればアニメーションとして表示し、
  できなければ（エラーが返る、または1フレームしか届かない場合）先頭フレームの静止画として表示する。
  フレームを自前のタイマーで送る独自の再生処理は作らない（ユーザー判断 2026-10-19、FR-030、原則 V）
- **小さい画像の拡大**: デコード時の `maxPixelSize` は上限指定なので、小さい画像は原寸のまま保持される。
  表示時は `ImagePreviewView` が `contentLayer` のフレームを `FitCalculator` の結果に合わせて変えるだけで、
  拡大はレイヤー（GPU）の補間で行う。デコード済み画像の再生成・再描画はしない（原則 II）。
  フルスクリーンも同じビュー・同じ計算を通るため、分岐を増やさずに同じ規則になる（US5）。
  動画（`AVPlayerView`）は対象外とし、従来の表示サイズのままとする（ユーザー判断 2026-10-20）
- **拡大の代替案**: 拡大率の上限（2倍・4倍など）を設ける案は、同じ大きさの画像でも条件によって
  見え方が変わり、設定と分岐が増えるため却下。ニアレストネイバーで拡大する案は、写真で画質が
  落ちるため却下（補間は `ImagePreviewView` が設定する `CALayer.magnificationFilter` の `.trilinear` を使う）

## R6. 動画再生

- **Decision**: AVKit の `AVPlayerView`（標準コントロール）+ `AVQueuePlayer` + `AVPlayerLooper`。
  自動再生とループの ON/OFF は動作オプションから決める
- **Rationale**: 再生/一時停止・シーク・音量・キーボード操作（Space 等）・a11y が標準で備わる（FR-033）。
  ループは `AVPlayerLooper` で継ぎ目なく実現できる
- **Alternatives considered**: `AVPlayerLayer` と自前のコントロール（実装量が増え、a11y も自前になる）

## R7. サムネイル生成とキャッシュ

- **Decision**: `QLThumbnailGenerator`（QuickLookThumbnailing）で画像・動画のサムネイルを共通に生成する。
  サイズは 64 / 128 / 256 / 512 px（×スクリーン倍率）の段階に丸めて要求し、スライダー操作のたびに作り直さない。
  64px はリスト形式の行頭アイコン用（R17）、128px 以上はサムネイル形式用とする。
  結果はメモリ上の `NSCache` に保持し（上限 128MB）、ディスクには書かない
- **Rationale**: 画像と動画を同じ API で扱え、生成は OS がバックグラウンドで行う。ユーザーのフォルダにも
  アプリ独自のディスクキャッシュにも書き込まない（原則 I）
- **Alternatives considered**: ImageIO + `AVAssetImageGenerator` の使い分け（コード量が倍になる）、
  ディスクキャッシュ（初版では不要。YAGNI）

## R8. メモリ上限（原則 II）

- **Decision**: デコード済みプレビューのキャッシュは 256MB 上限の LRU。対象は選択中のファイルと、その前後
  1件ずつの先読み分。サムネイルは 128MB 上限
- **Rationale**: 5K スクリーンの1画面分（約 59MB）を3枚保持しても上限内に収まる。上限は定数で一元管理する

## R9. ディレクトリ列挙・ボリューム・変更監視

- **Decision**:
  - 列挙: `FileManager.contentsOfDirectory(at:includingPropertiesForKeys:options:)` に
    `.creationDateKey` / `.isDirectoryKey` / `.contentTypeKey` を事前取得キーとして渡し、
    `.skipsHiddenFiles` を指定してバックグラウンドで実行する
  - ボリューム: `FileManager.mountedVolumeURLs(... options: .skipHiddenVolumes)`、および
    `NSWorkspace.didMountNotification` / `didUnmountNotification`
  - 変更監視: FSEvents（`FSEventStreamCreate`、`kFSEventStreamCreateFlagFileEvents`）。表示中の
    フォルダとツリーで展開中のフォルダを監視対象とし、対象が変わったらストリームを作り直す（0.3 秒デバウンス）
- **Rationale**: 1回のシステムコールで属性までまとめて取得でき、10,000 件でも 1 秒以内に収まる見込み（SC-003）。
  FSEvents は1本のストリームで複数パスを監視でき、ディレクトリごとにファイル記述子を開かずに済む
- **Alternatives considered**: `DispatchSource` のファイルシステム監視（ディレクトリごとに記述子が必要で、
  展開ノードが増えると破綻する）、ポーリング（遅延と無駄が大きい）

## R10. ファイル操作

- **Decision**: `FileManager.copyItem` / `moveItem` / `trashItem(at:resultingItemURL:)` をバックグラウンドで
  実行する。コピー・移動の受け渡しは `NSPasteboard` のファイル URL を使い、Finder との相互コピーも可能にする。
  同名衝突の「両方残す」は Finder と同じく `名前 2.拡張子` 形式で採番する
- **Rationale**: 削除は常にゴミ箱経由で元に戻せる。これは確認モーダル省略の前提条件（憲章 v1.1.0 原則 I、
  spec FR-024）。元に戻せない上書きは、設定に関わらず衝突ダイアログで確認する（FR-025）
- **名前の検証規則**: 空文字、`/` または `:` を含む名前、先頭が `.` の名前（隠しファイルになる）、
  同じフォルダ内の既存の名前（大文字小文字の違いのみも含む: APFS の既定は大文字小文字非区別）は拒否する。
  拡張子の変更は確認する

## R11. フルスクリーン

- **Decision**: ツリーとリストの `NSSplitViewItem` を折りたたみ、ウィンドウを `toggleFullScreen` する。
  解除時は逆の順序で戻す。トリガーは画像プレビューのダブルクリック（`NSClickGestureRecognizer`、2クリック）、
  ⌃⌘F と表示メニュー、Esc（解除のみ）、ウインドウの緑ボタン
- **Rationale**: プレビューのビューを付け替えないため、動画の再生位置と状態がそのまま保たれる（FR-037）。
  折りたたみは分割位置を保持するので、ペイン幅も元に戻る
- **Alternatives considered**: 専用のフルスクリーンウィンドウへビューを移す（再生状態の引き継ぎが必要で複雑）
- **動画上のダブルクリック**: 対応しない。動画表示中の切替・解除は ⌃⌘F・表示メニュー・Esc・緑ボタンという
  macOS 標準の手段に任せ、`AVPlayerView` のマウス操作に重ね合わせビューなどで割り込まない
  （ユーザー判断 2026-10-19、FR-035）。`AVPlayerView` 自身の全画面ボタンは、仕組みが二重になるため非表示にする

## R12. 設定の保存

- **Decision**: `UserDefaults` にキーを定義して保存する（[contracts/settings.md](./contracts/settings.md)）。
  分割位置は `NSSplitView.autosaveName` で自動保存する
- **Rationale**: ローカルの plist 保存で外部送信がなく（原則 I）、追加コードも最小で済む（原則 V）

## R13. アプリサンドボックスとファイルアクセス権限

- **Decision**: アプリサンドボックスは使わない（非サンドボックス、ad-hoc 署名）
- **Rationale**: ホーム全体とボリュームを自由に辿る要件（FR-004）は、サンドボックスでは毎回ユーザーの
  フォルダ選択が必要になり、ツリー UI と両立しない。個人利用で App Store 配布の予定もない
- **影響**: デスクトップ・書類・ダウンロード等にアクセスすると macOS のプライバシー確認（TCC）が表示される。
  拒否されたフォルダは「アクセスできない」と表示する（spec エッジケース）。`swift run` で起動した場合、
  許可はターミナルに紐づく

## R14. アプリアイコンの生成

- **Decision**: ビルド時専用の実行ターゲット `make-icon` を追加し、CoreGraphics で 1024×1024 の設計座標から
  16 / 32 / 64 / 128 / 256 / 512 / 1024 px を個別に描画する。`scripts/make-icon.sh` が `.build/AppIcon.iconset`
  を作り、重複する @2x スロットを埋めて `iconutil -c icns` で `.build/AppIcon.icns` に変換する。
  `scripts/make-app.sh` がこれを呼び、`Contents/Resources/AppIcon.icns` と
  `Info.plist` の `CFBundleIconFile=AppIcon` を設定する
- **Rationale**:
  - 各サイズをベクター的に描き直すため、16px でも線が潰れず判別できる（FR-044、SC-011）
  - 外部素材・外部ライセンス・追加依存がなく、原画をコードとしてレビューできる（原則 I・V）
  - アイコンはビルド時のみ生成し、アプリの起動時間や実行時メモリに影響しない（原則 II）。
    `.icns` は `.build/` 配下の生成物とし、バイナリをコミットしない
  - `iconutil` は OS 標準ツールで、ネットワークを使わない（原則 I）
- **Alternatives considered**:
  - 1024px PNG を `sips` で縮小する: 小サイズで輪郭が甘くなるため不採用
  - 生成済み `.icns` をコミットする: 差分がバイナリでレビューできず、原画の再現性がない
  - SVG を `qlmanage` でラスタライズする: 変換結果が OS バージョンに依存し不安定
  - 外部のアイコン生成ツール: 依存追加になり原則 V に反する
- **デザイン**: macOS のアイコン余白に合わせた角丸スクエアに、左からフォルダ・サムネイル・プレビューを
  表す3つの縦ペインを描く。文字は使わない。外観バリエーション（ライト/ダーク/ティント）は持たない
  （spec の前提、macOS 15 対象）

## R15. サムネイル形式のキーボード追従スクロール

- **Decision**: `NSCollectionViewFlowLayout` のレイアウト結果からフォーカス項目のフレームを取得し、
  可視矩形との差分を `MediaViewerCore` の純粋計算（`ThumbnailScroll`）で求めて、クリップビューの
  縦原点を直接更新する。計算規則は「項目全体が見える最小移動」とし、既に見えていれば動かさない。
  移動はアニメーションなしで即時に行う。レイアウト属性が取得できない場合は、グリッド計算と
  コンテンツ高から対象行の Y 範囲を推定し、推定も不能な場合のみ `scrollToItems` を最終フォールバックにする
- **Rationale**:
  - 現行の `NSCollectionView.scrollToItems(at:scrollPosition: .nearestVerticalEdge)` は、選択変更の直後に
    呼ぶとビューポートが動かない場合があり、キーボード操作でフォーカスが画面外に残る（FR-017 の不具合）。
    レイアウト済みのフレームと可視矩形を明示的に比較する方が結果が決定的で、キーリピートにも追従しやすい
  - 最小移動にすることで、連続した矢印操作で閲覧位置が不必要に飛ばず、Finder の感覚に合う
    （ユーザー判断 2026-10-20）
  - 横方向は計算せず、既存の「横スクロールを出さない」制約（FR-015）を維持する
  - 計算を Core に置くことで、UI を起動せずに「画面外の項目へ移動したとき」の計算を検証できる。
    UI 配線は自動テストの対象外とし、quickstart の手動再現で確認する（原則 IV）
  - フォールバックを残すことで、レイアウト属性が未生成の状態でも FR-017 を無言で落とさない
  - 新しい依存・設定・永続化状態は増えない（原則 V）。UI スレッドではレイアウト済みの値を読むだけで、
    デコードや再描画を追加しない（原則 II）
- **Alternatives considered**:
  - `scrollToItems` の呼び出し位置やタイミングの調整を主手段にする案: レイアウト完了を待つ必要があり、
    キーリピート時に取りこぼす可能性が残るため却下（最終フォールバックとしてのみ残す）
  - フォーカス項目を常に中央へ寄せる案: 連続操作で画面が細かく動き、閲覧位置が定まらないため却下
  - ページ単位のスクロール: 1項目移動のたびに大きく飛び、小さなサムネイルでは過剰なため却下
   - リスト形式にも共通処理を適用する案: リスト形式は OS 標準の追従で既に動作しており、変更範囲を
     広げる利点がないため対象外（ユーザー判断 2026-10-20）

## R16. フルスクリーン中の矢印キーによるファイル移動

- **Decision**:
  - 移動先インデックスの計算を `MediaViewerCore` の `FocusNavigator` に集約する。入力は現在インデックス、
    ファイル件数、移動方向、レイアウト（リスト / サムネイルの列数）。リスト形式は ↑↓ を ±1、
    ←→ は移動なし。サムネイル形式は ←→ を ±1、↑↓ を ∓列数とし、`0...(count-1)` にクランプする。
    端では `nil` を返し、選択を動かさない（キー自体は消費し、OS の既定動作には渡さない）
  - フルスクリーン開始時（ペインを折りたたむ前）に、現在の表示形式とサムネイルの列数を
    `FileListViewController` にスナップショットする。折りたたみ後はビューの幅が 0 になり列数を
    再計算できないため、表示中のファイルリストと同じ規則を保つには開始時の値が必要になる
  - フルスクリーン中だけ `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` を登録し、
    修飾キーなしの矢印キーを `BrowserModel.select([url], focused: url)` に振り分ける。
    これにより、フォーカスが画像ビューにあっても `AVPlayerView` の内部ビューにあっても同じ動作になる。
    動画の `<` / `>` は `AVPlayerView` に渡さず、`AVPlayer` の現在位置から 5 秒戻す / 送るシークとして扱う
  - 解除時はモニタを外し、ペインを戻した後に既存の `ThumbnailScroll` 経由でフォーカス項目を表示する。
    リスト形式は既存の `scrollRowToVisible` に任せる
- **Rationale**:
  - 移動規則を Core の純粋関数に置くことで、リスト形式・サムネイル形式・フルスクリーンが同じ計算を
    共有し、「ファイルリストと同等」という FR-046 をテスト可能な形で保証できる（原則 IV）
  - ローカルモニタはレスポンダチェーンに依存しないため、画像・動画・標準コントロールのどれが
    フォーカスを持っていても矢印の意味が変わらない。フルスクリーン中だけ有効にするので、
    通常表示のリスト操作やテキスト編集中の入力には影響しない
  - 折りたたみ前の列数を使うことで、全画面中にグリッド幅が 0 になっても ↑↓ の移動幅が変わらない
  - シークを `<` / `>` に移すことで、矢印キーをファイル移動に固定しつつ、FR-033 のキーボードシークを
    維持できる（ユーザー判断 2026-10-20、FR-046）
  - 新しい依存・設定・永続化状態は増えない（原則 V）。移動後のプレビュー更新は既存の
    `BrowserModel.select` と Observation に任せ、UI スレッドでデコードしない（原則 II）
- **Alternatives considered**:
  - `ImagePreviewView` と `AVPlayerView` のサブクラスで個別に `keyDown` を処理する案:
    `AVPlayerView` の内部レスポンダや標準シークと競合し、同じキーでもフォーカス位置で結果が変わるため却下
  - フルスクリーン中にファイルリストへフォーカスを移して標準のキー操作に任せる案:
    リストが折りたたまれて非表示になり、ビューポートも 0 幅になるため、列数とスクロール位置を
    正しく維持できない
  - 解除後に選択をフルスクリーン前へ戻す案: 表示していたメディアとリスト選択が食い違い、
    利用者の期待に反するため却下（ユーザー判断 2026-10-20）
  - 端で反対端へ循環する案: Finder の矢印移動と異なり、意図しない先頭・末尾への移動が起きるため却下
    （ユーザー判断 2026-10-20）

## R17. ツリーとリスト形式の行頭アイコン

- **Decision**:
  - ツリーは `FolderNode.Kind` に応じて SF Symbols を使い分ける（`.home` → `house`、
    `.volume` → `externaldrive`、`.folder` → `folder`）。展開・折りたたみでアイコンは変えない
  - リスト形式は、形式別の SF Symbol を即座に表示したうえで、既存の `ThumbnailProviding` に
    16pt（バッキング倍率を掛けて 64px 段階）を要求し、取得できた画像へ差し替える。
    取得中・失敗時は形式別の SF Symbol を残す（`.jpeg` → `photo`、`.png` → `photo.on.rectangle`、
    `.gif` → `photo.stack`、`.webp` → `photo.circle`、`.mp4` → `film`、`.mov` → `video`）
  - アイコンは template 画像として構成し、ダークモード・選択ハイライト・アクセシビリティの
    コントラスト設定に追従させる。装飾として a11y 要素から外し、ファイル名の読み上げだけを残す
  - リストの名前列だけがアイコンを持ち、他の列は従来のテキストのみとする。行の高さは 20pt
  - 取得のキャンセルは URL と要求サイズ（丸め後のピクセルサイズ）の組で行う。セル再利用時に
    64px の要求だけを取り消し、同じ URL に対するサムネイル形式の 128 / 256 / 512px 要求は残す
- **Rationale**:
  - Finder のリスト表示に近い「内容が分かる小さな画像」を、サムネイル形式と共通の OS 標準 API で
    生成できる。ユーザー判断（2026-10-20）に一致する（FR-048）
  - ツリーはフォルダ種別を色や独自素材に頼らず形状で区別でき、SF Symbols は macOS 標準で
    ダークモード・高コントラストに追従する（FR-047、SC-013、原則 III）
  - 既存の `ThumbnailProviding` に 64px 段階を足すだけで、画像・動画・破損ファイルの扱いを
    二重実装しない。可視行だけを遅延取得し、セル再利用時は URL + サイズ単位で取り消すため、
    10,000 ファイルでも一覧表示を待たせない（SC-003・SC-012、原則 II）
  - キャンセルを URL だけで行うと、リストの 64px 要求が同じ URL のサムネイル形式 128px 要求を
    巻き込んで取り消し、表示形式の切替時に既存のサムネイルが欠ける。要求サイズを含むキーに
    することで、FR-013 を回帰させずに済む
  - SF Symbols と既存のサムネイル経路だけを使い、外部素材・新しい設定・永続化・依存を増やさない
    （原則 I・V）
  - フォールバックを先に表示することで、サムネイル生成が遅い・失敗する場合でも行の高さと
    テキスト位置が動かず、選択やスクロールが安定する
- **Alternatives considered**:
  - `NSWorkspace.icon(forFile:)` のフルカラー書類アイコン: 形式ごとの差が小さく、選択時の配色や
    高コントラストへの追従が OS 任せになるため、行頭の小さなアイコンには SF Symbols を優先
  - 独自の PNG アイコンセットを同梱する案: 外部素材か描画コードの追加が必要になり、
    解像度・ダークモード・a11y の検証対象が増えるため却下（原則 V）
  - アイコンを別列にする案: Finder のリスト表示と異なり、名前列の幅を圧迫するため却下
  - 全行のサムネイルを一括生成する案: 10,000 ファイルで不要な生成が走り、SC-003 に反するため却下
  - 128px の既存最小段階をそのまま使う案: 64px で足りる表示に 4 倍の画素を確保し、
    スクロール時のキャッシュ圧迫と生成時間が増えるため、64px 段階を追加する
  - URL だけでキャンセルする案: 同じ URL の別サイズ要求を巻き込み、リストとサムネイル形式の
    切替時に既存のサムネイル表示を壊すため却下。URL + ピクセルサイズをキーにする

## R18. 表示を切り替えられるツールバー

- **Decision**:
  - `MainWindowController` のウィンドウに `NSToolbar`（識別子 `MainToolbar`、`toolbarStyle = .unified`、
    `displayMode = .iconOnly`）を常に設定し、表示・非表示は `isVisible` で切り替える。既定は非表示
  - 表示状態は `SettingsStore` のキー `view.showsToolbar`（Bool、既定 `false`）だけに保存する。
    `autosavesConfiguration = false` にして、AppKit 独自の保存（`NSToolbar Configuration MainToolbar`）と
    二重管理しない。起動時は保存値を `isVisible` に設定してからウィンドウを表示する
  - `isVisible` を KVO で監視し、メニュー・ショートカット・ツールバーの右クリックメニューなど、どの経路で
    変わっても保存と下部バーの表示更新を行う
  - メニューは「表示」メニューの先頭に独自アクション `toggleMainToolbar(_:)` で置き、⇧⌘T を割り当てる。
    ⇧⌘T は AppKit の自動ウィンドウタブ（「タブバーを表示」）と同じキーのため、起動時に
    `NSWindow.allowsAutomaticWindowTabbing = false` にして自動タブの項目を出さない
    `validateMenuItem` で項目名を「ツールバーを表示」「ツールバーを隠す」に切り替える
  - 表示形式は `NSToolbarItemGroup(itemIdentifier:images:selectionMode: .selectOne, labels:target:action:)` で
    2 つのセグメントにする。左が「サムネイル」（`square.grid.2x2`）、右が「リスト」（`list.bullet`）で、
    ⌘1 / ⌘2 の番号順と Finder の並びに合わせる。選択中のセグメントが強調表示される
  - サイズは `NSSlider`（`controlSize = .small`、幅 120pt、連続更新）を持つ `NSToolbarItem` にする。
    範囲は `ViewSettings` の最小・最大値と同じ。リスト形式のときは項目を残したまま無効にする
  - 項目の並びは「表示形式」「サイズ」「可変スペース」で固定する。`allowsUserCustomization = false`、
    `allowsDisplayModeCustomization = false` にしてカスタマイズとラベル表示の切り替えは提供しない
  - 表示形式・サイズの状態は `FileListViewController` が持つ既存の値を唯一の正とする。ツールバーは
    `FileListViewController` の公開メソッドを呼び、`onViewStateChange` の通知で表示を合わせる
  - 下部バーの表示とツールバーのスライダーの有効・無効は Core の純粋計算 `FileListChrome` で決める
  - フルスクリーン中は `window(_:willUseFullScreenPresentationOptions:)` で `.autoHideToolbar` を加え、
    ポインタを画面上端へ移したときだけメニューバーと一緒に表示する。保存した表示状態は変えない
  - ボタンとスライダーにはツールチップとアクセシビリティラベル（「サムネイル」「リスト」
    「サムネイルのサイズ」）を付ける
- **Rationale**:
  - `NSToolbar` は macOS 標準のツールバーで、表示切替・アニメーション・ダークモード・アクセシビリティを
    AppKit がそのまま提供する（原則 III・V）。「表示」メニューは Finder・Safari と同じ配置
    （2026-10-20 のユーザー判断、FR-050）。キーは当初 macOS 標準の ⌥⌘T としたが、常駐アプリの
    全体ショートカットに先取りされて届かなかったため、ユーザー判断で ⇧⌘T に変更した
  - 保存先を `SettingsStore` に一本化すると、既定の非表示（FR-049）と復元（FR-003）を Core のテストで
    検証でき、AppKit の自動保存と値が食い違うことがない
  - `NSWindow.toggleToolbarShown(_:)` の項目名は AppKit が設定する。アプリが日本語のローカライズを
    持たないと英語の「Show Toolbar」になり、他の日本語メニューと揃わないため、独自アクションにする
  - 状態の正を `FileListViewController` に残すことで、メニュー・下部バー・ツールバーの 3 経路が同じ
    `setDisplayMode` / `setThumbnailSize` を通り、表示がずれない（FR-051）
  - 下部バーとスライダーの判断は小さいが、FR-051・052 の受け入れ条件そのものなので、Core に置いて
    4 通りの組み合わせを自動テストする（原則 IV）
  - フルスクリーンは「画面全体」に表示する機能（FR-035）なので、ツールバーが画像に重ならないよう
    自動で隠す。保存値を変えないため、解除後は元の表示状態に戻る
- **Alternatives considered**:
  - 非表示のときに `window.toolbar = nil` にする案: 追加前と同じ見た目は確実だが、表示切替のアニメーションと
    AppKit の表示状態の管理を自前で持つことになるため、`isVisible` を採用する。起動スモークで非表示時の
    タイトルバーが追加前と異なると分かった場合のみ、この案に切り替える
  - `autosavesConfiguration = true` で AppKit に保存させる案: 初回の既定値の扱いと Core での検証が難しく、
    `SettingsStore` と二重管理になるため却下
  - 表示形式を 1 つのトグルボタンにする案: 現在の形式が分かりにくく、2026-10-20 のユーザー判断（Finder 型の
    2 択）と異なるため却下
  - リスト形式でスライダーを隠す案: 項目の位置が変わるため、ユーザー判断（無効化して残す）に従い却下
  - ⌥⌘T（macOS 標準）: 当初の決定。利用者の環境で常駐アプリの全体ショートカットと衝突し、アプリに
    キーが届かなかったため ⇧⌘T に変更した
  - 自動ウィンドウタブを残したまま ⇧⌘T を割り当てる案: AppKit が「タブバーを表示」（⇧⌘T）を追加し
    キーが衝突する。このアプリはウィンドウ 1 枚でタブを使わないため、自動タブを無効にする
  - フルスクリーン中もツールバーを出し続ける案: 画像の上端が隠れ、FR-035 の「画面全体」と食い違うため却下

## R19. ツリーのダブルクリック開閉と開閉の三角の表示条件

- **Decision**:
  - ダブルクリックは `NSOutlineView.doubleAction`（`target` は `DirectoryTreeViewController`）で受ける。
    対象行は `clickedRow` で取り、`-1`（行のない余白）は無視する。反応範囲は行全体（アイコンとフォルダ名）で、
    クリック位置のヒットテストはしない（FR-053）
  - ダブルクリックの1回目のクリックは `NSOutlineView` の標準動作で選択になり、既存の
    `outlineViewSelectionDidChange` からファイルリストが切り替わる。ダブルクリック用に選択処理は追加しない
  - 開閉の判断は Core の純粋計算 `FolderDisclosure.doubleClickToggle(isExpandable:isExpanded:)` で行う。
    展開中なら `.collapse`、折りたたみ中で開閉できれば `.expand`、それ以外は `.none`。
    UI は結果に応じて `expandItem(_:)` / `collapseItem(_:)` を呼ぶだけで、展開時の読み込みは三角と同じ
    `outlineViewItemWillExpand` の経路を通る。⌥ 付きのダブルクリックに特別な意味は持たせない
  - 開閉の三角は `outlineView(_:isItemExpandable:)` が `FolderNode.isExpandable` を返すことで制御する。
    `isExpandable` は「読み取り可能（`accessState != .denied`）かつ `subfolderState` が `.present` または `.failed`」。
    `.unknown`（確認中）と `.absent` では三角を出さず、→ キーや三角のクリックでも展開できない（FR-054・055）
  - サブフォルダの有無は `DirectoryListing.hasSubfolders(in:)` で確認する。`DirectoryLister` は
    `opendir` / `readdir` で列挙し、`d_type` が `DT_DIR` / `DT_UNKNOWN` 以外のエントリと `.` で始まる名前を
    読み飛ばす。残ったディレクトリにだけ `subfolders(of:)` と同じ条件（`isDirectory == true` かつ
    `isPackage != true`、非表示属性なし）を問い合わせ、最初の1件で打ち切る。`errno` は `EACCES` / `EPERM` →
    `.accessDenied`、`ENOENT` / `ENOTDIR` → `.notFound`、それ以外 → `.other` に変換する。
    実装時（T125・T127）に当初の `FileManager.enumerator`（`.skipsHiddenFiles` ほか）で計測したところ、
    10,000 ファイルで 0.05〜0.21 秒とばらつき 0.2 秒の基準を超えることがあったため変更した（`readdir` 版は 5〜9ms）。プロトコル拡張に
    `!subfolders(of:).isEmpty` の既定実装を置き、既存のテスト用フェイクを壊さない
  - 確認は表示されているフォルダの直下1階層だけに行う（FR-055）
    - 起動時と `applyRoots`（ボリュームのマウント・取り外し）: 各ルート
    - 子の読み込み（三角・→ キー・ダブルクリックでの展開、起動時の前回フォルダの表示）: 新たに表示された各子
    - 外部の変更で子を読み直したとき: 同じ URL の既存ノードの結果を引き継ぎ、新しく現れた子だけ
    - 表示されていないフォルダ（折りたたまれた親の孫など）は確認しない
  - 確認の並列数は Core の `SubfolderProbe.results(for:lister:maxConcurrent:)` で 4 に制限する。結果は
    URL ごとに1回ずつ `AsyncStream` で流し、表示順に要求する。親ノードごとに進行中の確認を1つだけ持ち、
    同じ親で新しい確認を始めるとき・ルートを差し替えるときに古い確認を取り消す
  - 結果は MainActor でノードへ反映し、`row(forItem:) >= 0`（まだツリーに表示されている）のときだけ
    `reloadItem(_:reloadChildren: false)` で三角の有無を更新する
  - 状態の変換は `FolderNode` のメソッドに集約する（data-model.md の状態遷移を参照）
    - 確認: `true` → `.present`、`false` → `.absent`、`.accessDenied` → `accessState = .denied`、
      それ以外の失敗（`.notFound` / `.other`）→ `.failed`（三角を出す）
    - 展開時の読み込み: 1件以上 → `.present`、0件 → `.absent`（折りたたんで三角を消す）、
      `.accessDenied` → `accessState = .denied`（三角を消す）、`.notFound` / `.other` → `accessState = .unavailable`・
      `.failed`・`children = nil`（折りたたみ、三角は残して次の展開で読み直す）。`.denied` と `.unavailable` は
      どちらも既存の「アクセスできません」表示にする。ドロップ先の判定は `.denied` だけを拒否する既存のまま
  - 外部の変更（FR-042）に三角を追従させるため、監視対象に「表示されているフォルダ」（ルートと、展開中の
    フォルダの子）を加える。折りたたまれたフォルダへのイベントでは再確認し、展開中のフォルダでは既存の
    子の読み直しのあとに状態を更新する。`BrowserModel.handleFileSystemEvent` は表示中のフォルダ以外の
    URL を無視するため、影響しない
  - 起動時の前回フォルダの表示（`reveal`）は、各段で子を読み込んで状態を確定させてから `expandItem` を
    呼ぶ。確認前（`.unknown`）のノードへの `expandItem` は `isItemExpandable` が `false` のため無視される
- **Rationale**:
  - `doubleAction` は `NSTableView` 標準の仕組みで、シングルクリックの選択を遅らせず、ドラッグ&ドロップや
    右クリックメニューとも干渉しない。開閉の三角は独立したボタンとしてクリックを処理するため、三角の
    連続クリックで `doubleAction` が重ねて動くことはない（quickstart で確認する）
  - 開閉の判断と状態遷移を Core に置くと、確認中・失敗・権限なしの組み合わせを自動テストできる（原則 IV）
  - 列挙を最初の1件で打ち切ると、10,000 ファイルのフォルダでも全件の属性を読まずに済む。判定条件を
    `subfolders(of:)` と揃えることで、「三角は出たのに展開すると空」「三角がないのに子がある」を防ぐ
  - 並列数の上限は、ネットワークボリュームや多数の子を持つフォルダで、同時に大量の列挙を発行して
    応答を悪くするのを防ぐ（原則 II）。4 はローカル SSD では待ちにならず、遅いボリュームでも要求が
    積み上がらない値として選んだ
  - FSEvents は登録したパスの配下を再帰的に通知するため、表示中のフォルダを監視対象に加えても OS 側の
    負担はほとんど増えず、コールバックでの絞り込み対象が増えるだけになる（R9）
  - `NSOutlineView` は、同じ階層の行のセルを、三角の有無に関わらず同じ位置に置く。そのため三角が後から
    現れても行の位置はずれない（FR-055。quickstart で確認する）
  - 展開できない行はアクセシビリティ上も「開閉できる項目」として読み上げられなくなる（原則 III）
- **Alternatives considered**:
  - `NSOutlineView` のサブクラスで `mouseDown` をフックし、アイコンの上だけを判定する案: 反応範囲は行全体と
    決まった（2026-10-20 のユーザー判断）ため不要
  - `NSClickGestureRecognizer`（2クリック）: シングルクリックの選択とドラッグの開始が遅れるため却下
  - 確認が終わるまで三角を出しておき、なしと分かったら消す案: クリックした三角が消えて何も起きないことが
    あるため、ユーザー判断（確認が終わるまで出さない）に従い却下
  - `contentsOfDirectory` で全件を読んでから判定する案: 実装は短いが、ファイルの多いフォルダで
    不要な属性の読み込みが増えるため却下
  - `FileManager.enumerator` で最初の1件で打ち切る案（当初の決定）: 全エントリの非表示属性とパッケージ判定を
    問い合わせるため、10,000 ファイルで最大 0.21 秒かかり基準（0.2 秒）を安定して満たせなかったため却下
  - 確認を孫以下まで先読みする案: ユーザー判断（表示されている階層だけ）に反し、I/O が増えるため却下
  - 展開時の読み込み失敗を理由を問わず `.denied` にする案（当初の決定）: 一時的な失敗でも三角が消えてドロップ先にも
    ならず、外部の変更通知かボリュームの再マウントまで回復しないため、/speckit-analyze の指摘（F1）を受けて却下した。
    権限以外の失敗は `.unavailable` として「アクセスできません」の表示を出しつつ三角を残し、再展開で読み直す
    （FR-055 の「展開時に読めなければ、既存のアクセスできない旨の表示を出す」を満たす）
  - 確認結果をディスクに保存する案: 永続化を増やし、外部の変更と食い違うため却下（原則 V）

## R20. 画像・動画の種類フィルタ

- **Decision**:
  - 判定は Core の値型 `MediaTypeFilter`（`imagesOnly: Bool`・`videosOnly: Bool`、既定は両方 `false`）に置く。
    片方だけがオンのときだけ絞り込み、両方オン・両方オフはすべてを通す（FR-056）。区分は既存の
    `MediaKind.isVideo` をそのまま使い、拡張子の判定（FR-009）は変えない
  - 状態の正は `BrowserModel.mediaTypeFilter` に1つだけ置く。`BrowserModel` はアプリの起動中ずっと同じ
    インスタンスなので、フォルダを移っても値が残り（FR-056）、`SettingsStore` には書かないため起動のたびに
    既定に戻る。保存キーは追加しない
  - `BrowserModel` は列挙・並べ替え済みの全件（`allFiles`、非公開）を保持し、`listing.files` には種類フィルタを
    適用した結果だけを入れる。リスト形式・サムネイル形式・⌘A・コピーなどの操作・前後の先読み・
    フルスクリーン中の矢印移動（`FocusNavigator`）は、既存どおり `listing.files` だけを見るため、
    表示中の一覧だけが対象になる。並べ替え・フォルダ読み込み・FSEvents による読み直しは
    すべて `allFiles` を更新してから同じ1つの経路で `listing` を作り直す
  - 「対象ファイルはあるが絞り込みで0件」は `FolderListing.State` に新しい `.noMatches` を加えて表す。
    `.empty`（対象ファイルが元々ない）とは別の状態にし、メッセージは `MediaTypeFilter.noMatchesMessage`
    （「画像のみ表示中: 該当するファイルはありません」「動画のみ表示中: 該当するファイルはありません」）で決める（FR-060）
  - 絞り込みを変えたときの選択の整理は、純粋計算 `SelectionState.restricted(toVisible:)` に置く。
    表示中でなくなった URL を選択から外し、フォーカスが nil か表示中ならそのまま、外れたなら残った選択のうち
    一覧の並び順で最後のものをフォーカスにし、何も残らなければ `nil` にする（FR-059）。
    `setMediaTypeFilter(_:)` は、フォーカスが変わらなければ選択だけを差し替えてプレビューを読み直さない。
    変わる場合は既存の `select(_:focused:)` を通し、動画の停止通知（FR-034）・プレビューの更新・先読みを
    既存の経路に任せる。外した選択は記録しないため、絞り込みを戻しても選択は戻らない
  - FSEvents による読み直し（`reloadCurrentFolder`）の選択の扱いは変えない（フォーカスが消えたらプレビューを空にする）。
    FR-059 の「残った選択へフォーカスを移す」は種類フィルタの変更だけに適用する
  - ツールバーは `NSToolbarItemGroup(itemIdentifier:images:selectionMode: .selectAny, labels:target:action:)` の
    2 セグメントにし、左が「画像のみ表示」（`photo`）、右が「動画のみ表示」（`film`）。識別子は `mediaTypeFilter`。
    並びは「種類フィルタ」「表示形式」「サイズ」「可変スペース」で固定する（FR-057）。押された状態の
    見た目は `selectAny` のセグメントの選択表示をそのまま使い、`setSelected(_:at:)` で状態を合わせる。
    SF Symbols はリスト形式のフォールバックアイコン（`IconCatalog`）と同じ系統にそろえる
  - 「表示」メニューには、既存の「サムネイルを縮小」の後ろに区切り線を入れて「画像のみ表示」（⇧⌘I）と
    「動画のみ表示」（⇧⌘M）を追加し、オンの項目にチェックマークを付ける（FR-058）。表示形式の項目と同じく
    `FileListViewController` が追加・検証する。名前の変更中（テキスト編集中）は無効にする
  - メニュー・ショートカット・ツールバーは、どれも `FileListViewController.applyMediaTypeFilter(_:)` から
    `BrowserModel.setMediaTypeFilter(_:)` を呼ぶ。表示の反映は `mediaTypeFilter` の監視で行い、
    `FileListViewController` がメニューのチェックを更新し、`onMediaTypeFilterChange` でツールバーに伝える
  - フルスクリーン中も ⇧⌘I / ⇧⌘M は効く（フルスクリーンの keyDown モニタは Command 付きのキーを横取りしない）。
    フルスクリーンは解除せず、FR-059 の結果でプレビューが空になった場合は空の表示のまま、次の矢印キーで
    表示中の一覧の先頭から移動できる（`FocusNavigator` の「現在位置なし」の規則）
- **Rationale**:
  - 絞り込み後の配列を `listing.files` に置けば、一覧・選択・先読み・フルスクリーン移動・ファイル操作の
    既存コードは変更なしで「表示中の一覧だけ」を対象にできる。判断が Core に集まり、4 通りの組み合わせと
    選択の整理を自動テストできる（原則 IV）。UI に絞り込みの判断を持たせない
  - 0件の状態を `.empty` と分けると、FR-060 の文言の出し分けを UI の条件分岐ではなく状態で表せ、
    既存の「対応メディアがない」表示（`.empty`）を変えずに済む
  - 絞り込みは `MediaKind` の比較だけで、10,000 件でも数 ms で終わる。列挙・デコードを伴わないため、
    MainActor 上で行っても原則 II の「UI スレッドで重い処理をしない」に反しない。性能テストで上限を確認する
  - `NSToolbarItemGroup` の `selectAny` は独立したオン・オフを AppKit 標準の見た目で表せ、既存の表示形式
    （`selectOne`）と同じ部品・同じ高さで並ぶ。アクセシビリティもセグメントごとのラベルで AppKit が提供する
  - ⇧⌘I / ⇧⌘M はアプリ内の既存の割り当て（⇧⌘T・⌥⌘V・⌘1/⌘2・⌥⌘1〜3・⌃⌘F）と衝突しない（2026-10-20 のユーザー判断）
- **Alternatives considered**:
  - UI 側（`ListModeView` / `ThumbnailModeView`）で配列を絞る案: 2つの表示形式・フルスクリーン移動・⌘A・
    先読みに同じ絞り込みを重複して入れることになり、ずれやすいため却下
  - `DirectoryLister.mediaFiles(in:)` に絞り込みを渡して列挙し直す案: 切り替えのたびにディスクを読み直し、
    原則 II に反するうえ、0件の理由（元々ない / 絞り込み）を区別できないため却下
  - 2 つの状態を1つの列挙（すべて / 画像 / 動画）にまとめる案: 「両方オン」と「両方オフ」を区別できず、
    ボタンとメニューの押された状態を正しく表示できないため却下
  - 絞り込みを `SettingsStore` に保存する案: ユーザー判断（再起動で引き継がない、2026-10-20）と異なるため却下
  - ツールバーに `NSButton`（`.pushOnPushOff`）を 2 つ別々の `NSToolbarItem` として置く案: 見た目が表示形式の
    セグメントとそろわず、項目間の余白も広がる。`selectAny` の表示が起動スモークで押された状態として
    判別しにくいと分かった場合のみ、この案に切り替える
  - 選択が残らないときに先頭のファイルを自動で選ぶ案: ユーザー判断（自動で選ばない、2026-10-20）と異なるため却下
  - 0件のメッセージに「フィルタを解除」ボタンを置く案: ユーザー判断（文言のみ）と異なり、⇧⌘I / ⇧⌘M で
    解除できるため却下
