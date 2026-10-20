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
