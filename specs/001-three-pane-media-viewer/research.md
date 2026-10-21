# Research: 3ペイン型メディアビューア

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-19（ファイルリストのフォルダ: 2026-10-21）

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

## R21. お気に入り

- **Decision**:
  - 登録内容は Core の値型 `FavoriteFolders`（登録順の `[URL]`）に置く。同一性は `standardizedFileURL.path` で判定し、
    末尾の `/` や `..` の違いで重複させない。`add(_:)` は末尾に追加し、登録済みなら何もせず `false` を返す（FR-062）。
    `remove(_:)` は登録だけを取り除く（FR-064）。並べ替え・名前の変更は持たない（spec Assumptions）
  - 保存は `SettingsStore.favorites` として `UserDefaults` のキー `favorites.paths`（絶対パスの文字列配列、登録順）に置く
    （FR-066）。ブックマークデータ（`URL.bookmarkData`）は使わず、移動・名前変更に追従しない（FR-067）。
    読み込み時に配列でない値は空に、文字列でない要素・空文字・相対パスは捨て、重複は先勝ちで除く
  - 「お気に入り」の見出しと各項目は `NSOutlineView` の通常の行として、既存のルート（ホーム・ボリューム）より上に置く。
    データソースのトップレベルは `[見出し] + roots` とし、見出しの子が登録順の項目になる。見出しは `isGroupItem` にしない
    （ソースリストのグループ行は開閉の三角ではなく「表示/隠す」になるため、FR-061 の「フォルダと同様の開閉の三角」に反する）。
    見出しは登録が0件でも開閉できる。項目は `isItemExpandable == false` で三角を出さず、`SubfolderProbe` の対象にしない（FR-063）
  - 見出しの開閉状態は保存しない。起動時は折りたたんだ状態で始める（spec Assumptions）。`applyRoots` の `reloadData()` の後は、
    見出しが展開中だったら展開し直す
  - 行の種類は Core の `TreeItemRole`（`.favoritesHeader` / `.favorite(URL)` / `.folder(URL)`。ホーム・ボリュームのルートも `.folder`）
    で表し、どの操作が使えるかを純粋計算 `FavoriteCommands` で決める。UI は行から役割を作って渡すだけにする
    - 追加（⌃⌘T・「お気に入りに追加」）: `.folder` かつ未登録のときだけ有効。見出しと項目では無効（FR-062）
    - 削除（⌘⌫・「お気に入りから削除」）: `.favorite` のときだけ有効。見つからない項目も削除できる（FR-064・067）
    - 右クリックメニュー: `.folder` は既存の「ここにペースト」「ここに移動ペースト」に「お気に入りに追加」と「Finder に表示」を加える。
      `.favorite` は「お気に入りから削除」だけ、`.favoritesHeader` は項目なし（メニューを出さない）
  - 右クリックメニューの対象は、右クリックした行（`clickedRow`）とする（spec Assumptions。既存の「ここにペースト」「ここに移動ペースト」
    「Finder に表示」も同じ規則にそろえる。お気に入りの項目を右クリックしたまま別の行が選択されていると、選択中の行を対象にする
    既存の方式では「お気に入りから削除」が別の行に効いてしまうため、メニューの項目ごとに対象が食い違わないようにする）。キーボードで開いたときなど `clickedRow` が
    ない場合だけ選択中の行を使う。メニューは `NSMenuDelegate.menuNeedsUpdate(_:)` で、対象の役割に合わせて作り直す
  - ⌘⌫ は既存のメニュー項目「ゴミ箱に入れる」（ファイル・編集の両メニュー、アクション `moveToTrash(_:)`、宛先なし）を
    そのまま使う。ツリーにフォーカスがあるときは、レスポンダーチェーン上で `FileListViewController` より先に
    `DirectoryTreeViewController` が同じアクションを受ける（ファイルリストはツリーのレスポンダーチェーンに入らない）。
    ツリーは、お気に入りの項目を選択中のときだけ項目を有効にし、項目名を「お気に入りから削除」に変える。
    それ以外の行では無効にして項目名を「ゴミ箱に入れる」に戻す（FR-064 の「何もしない」）。
    プレビューにフォーカスがあるときはどちらも検証しないため、「ファイル」「編集」メニューの `NSMenuDelegate.menuNeedsUpdate(_:)` で、
    開くたびに `moveToTrash(_:)` の項目名を「ゴミ箱に入れる」に戻してから検証させる（項目名が残らないようにする）
  - ⌃⌘T（「ファイル」メニューの「お気に入りに追加」）と ⇧⌘F（「表示」メニューの「お気に入りへ移動」）は、どのペインに
    フォーカスがあっても効くように、`MainSplitViewController` のアクションにして `DirectoryTreeViewController` へ渡す。
    ⇧⌘F は既存の ⌥⌘1〜3（ペインへのフォーカス）と同じ場所に、同じ方法（`installFocusMenuItems`）で追加する。
    ⇧⌘F はフルスクリーン中（`panesCollapsedForFullScreen`）とファイル名の変更中は無効にする。
    ⌃⌘T は名前の変更中だけ無効にする（対象はツリーの選択なので、フルスクリーン中でも登録できる）
  - ⇧⌘F は、見出しの行を選択して `scrollRowToVisible` し、ツリーをファーストレスポンダーにし、折りたたまれていれば展開する（FR-065）
  - 見出しを選択したときは `BrowserModel.selectFolder(_:)` を呼ばない。そのためファイルリスト・プレビュー・再生中の動画・
    `lastFolder` は変わらない（FR-065）。項目を選択したときは、通常のフォルダと同じく `selectFolder(entry.url)` を呼ぶ
    （`lastFolder` も更新する）。ツリー下側の実際の階層は展開も選択もしない（FR-063）
  - 削除後の選択: 選択中の項目を削除したら、見出しの行を選択する（`selectFolder` は呼ばれないため、ファイルリストは
    削除したフォルダの表示のまま残る）。削除で消えた行の位置に、別の項目が自動で選ばれてファイルリストが切り替わることを防ぐ
  - 追加しても見出しの開閉状態は変えない（選択やスクロール位置が動かないようにする）
  - 存在の確認は Core の `FavoriteProbe` で行う。`fileExists(atPath:isDirectory:)` がディレクトリを返せば `.available`、
    そうでなければ `.missing` とする（権限のないフォルダは存在するので `.available`。選んだときに既存の
    「アクセスできません」を出す）。確認は UI スレッドで行わず、`SubfolderProbe` と同じく同時 4 件までに制限する。
    確認の契機は、起動時・ボリュームのマウント/取り外し（`VolumeProviding.changes`）・アプリがアクティブになったとき
    （`NSApplication.didBecomeActiveNotification`）・登録したフォルダの親フォルダの FSEvents・登録直後・項目を選択したとき。
    ツリーの監視対象（`updateWatchSet`）に、登録したフォルダの親フォルダを加える（FR-067 の「FR-042 と同様に自動で戻す」）
  - 見つからない項目は、既存のアクセス不可と同じ淡色の文字（`disabledControlTextColor`）とツールチップ「見つかりません」で
    表示する。選択したときのファイルリストは、既存の経路（`DirectoryLister.mediaFiles` の `.notFound` →
    `FolderListing.State.failed("フォルダが見つかりません")`）の表示をそのまま使い、新しい文言を作らない（FR-067）
  - 項目の表示名は、ルート（ホーム・ボリューム）と同じ URL ならそのルートの `name`、それ以外は `lastPathComponent`。
    アイコンは同じ規則で `FolderNode.Kind` を決めて `IconCatalog.treeIcon(for:)` を使う。見出しのアイコンは
    SF Symbol `star.fill`（template）で、ラベルは「お気に入り」（FR-061）
  - ドロップ: 見出しと項目へのドロップは受け付けない（`validateDrop` で `[]`）。spec はお気に入りへのドロップを
    定めていないため、移動・コピーの経路を増やさない（原則 V）。ペーストも同じく、お気に入りの行では無効にする
  - 確認モーダル: `ConfirmationPresenter` に `confirmRemovingFavorite(named:)` を追加する。既存の `confirm(_:)` と同じ
    シート・ボタン（「削除」/「キャンセル」、Esc でキャンセル）・「今後この確認を表示しない」を使い、
    `confirmBeforeFileOperations` を共有する（FR-024）。文言は「お気に入りから削除しますか？」と、
    「対象: <フォルダ名>」「実際のフォルダは変更されません」。`FileOperation.Kind` には加えない
    （ファイルシステムを変更しない操作で、`FileOperationService` を通さないため）
  - 設定ウインドウのチェックボックスの文言を「コピー・移動・名前の変更・ゴミ箱に入れる・お気に入りから削除する前に確認する」にする
- **Rationale**:
  - 登録内容をパスの配列として保存すると、既存の `view.lastFolderPath` と同じ扱いで読み書きでき、
    移動に追従しない規則（FR-067）とも一致する。不正値の扱いも既存の `SettingsStore` の方針（既定値に戻す）にそろう
  - 見出しを通常の行にすると、→ / ← での開閉・↑↓での移動・ダブルクリックの開閉といった既存のツリー操作が
    そのまま使え、キーボードだけで項目へ届く（原則 III）
  - 操作の可否を `TreeItemRole` と `FavoriteCommands` に集めると、メニュー・ショートカット・右クリックで同じ判断を使え、
    Core のテストで網羅できる（原則 IV）
  - ⌘⌫ を既存のメニュー項目とレスポンダーチェーンで振り分けると、同じキーを2つのメニュー項目に割り当てる衝突を避けられる。
    項目名を対象に合わせて変えるため、メニューから見ても何が起きるかが分かる
  - 存在の確認は数件〜数十件の `stat` だけで、列挙を伴わない。並列数を制限すれば、応答のないネットワークボリュームが
    ほかの項目の確認を止めない（原則 II）
- **Alternatives considered**:
  - ブックマークデータで保存して移動・名前変更に追従する案: ユーザー判断（追従しない、2026-10-20）と異なるため却下
  - 見出しをソースリストのグループ行（`isGroupItem`）にする案: 開閉の三角が出ず FR-061 に反するため却下
  - 見出しの選択でファイルリストを空にする案: ユーザー判断（直前の表示を保つ、2026-10-20）と異なるため却下
  - お気に入りの項目を選んだときに実際の階層まで展開して選択を移す案: ユーザー判断（実際の階層は動かさない、2026-10-20）と
    異なるため却下
  - 「お気に入りから削除」に ⌘⌫ の別のメニュー項目を作る案: 同じキーの項目が2つになり、どちらが効くかがメニューの
    検証順に依存するため却下
  - `FileOperation.Kind` に `.removeFavorite` を加えて既存の確認経路を通す案: ファイル操作のサービス・衝突確認・結果表示の
    分岐を増やすため却下
  - FSEvents を使わず、アクティブ化とボリューム変更のときだけ確認する案: アプリを前面にしたままターミナルなどで
    削除したときに反映されず、FR-067 の「FR-042 と同様」を満たさないため却下
  - 見つからない項目専用のメッセージをファイルリストに出す案: spec が既存の表示（「フォルダが見つかりません」）を求めているため却下
  - 既存の右クリックメニューの項目だけ選択中の行を対象のまま残す案: お気に入りの項目と対象の決め方が食い違い、同じメニューの中で
    別の行に効く項目が混ざるため却下
  - お気に入りの項目へのドロップ・ペーストを受け付ける案: spec の対象外で、経路を増やすため今回は却下（必要になれば追加する）

## R22. zip の読み取り方式

- **Decision**:
  - zip の読み取りは Core の自前実装 `ZipArchive` で行う。外部依存は増やさない。対応範囲は、単一ファイルの zip（ZIP64 を含む）と、
    格納方式の無圧縮（0）・deflate（8）。暗号化された項目（汎用フラグのビット 0）と、それ以外の格納方式（deflate64・bzip2・LZMA など）は
    一覧には出し、プレビューで表示できない旨を示す（spec Edge Cases）。分割 zip（ディスク番号が 0 以外）は開けない
  - 開くときは、末尾の終端レコード（EOCD）を末尾 64KB + 22 バイトの範囲から後ろ向きに探し、ZIP64 ならロケータから ZIP64 の終端レコードを読む。
    続けて中央ディレクトリを1回で読み、索引 `ArchiveIndex` を作る。読み出しはファイル記述子への `pread` で行い、zip 全体を読み込まない・
    メモリマップしない。中央ディレクトリの読み込みと解析は UI スレッドで行わない
  - 項目のデータの開始位置は、ローカルヘッダ（30 バイト + 名前 + 拡張フィールド）を読んで決める。中央ディレクトリとローカルヘッダで
    拡張フィールドの長さが異なることがあるため。初めて読むときに1回だけ求め、項目ごとに覚える
  - サイズは中央ディレクトリの値を使う（データ記述子を使う zip、ビット 3 でも正しい）。ZIP64 拡張フィールド（0x0001）があればその値を使う
  - 階層は、名前を `/` で区切って木にする。ディレクトリの項目を持たない zip でも、途中のディレクトリを補う。名前の先頭の `/`・空の要素・`.` は
    取り除き、`..` を含む名前の項目は捨てる（展開しないので書き出しの危険はないが、表示上の階層を崩さないため）。区切りは `/` だけとし、
    `\` は名前の一部として扱う（ZIP の仕様 APPNOTE 4.4.17。CP932 の2バイト目には 0x5C が現れるため、`\` で区切ると日本語名が壊れる）
  - 隠し項目: 名前の要素が `.` で始まる項目と `__MACOSX/` 以下（macOS が作るリソースフォーク）は出さない。FR-008 の隠しファイルと
    同じ扱いにする。`__MACOSX/._a.jpg` は拡張子が jpg でも中身は画像ではなく、出すと壊れたファイルとして並ぶため
  - 同じパスが重複した場合は、中央ディレクトリで先に出た項目を使う。同じ名前がファイルとディレクトリの両方にある場合はディレクトリとして扱う
  - 「作成日」の列には更新日時を出す（spec Assumptions）。拡張タイムスタンプ（0x5455）の更新時刻（UTC）があれば使い、なければ DOS の日時を
    現地時刻として解釈する
  - CRC は検証しない。範囲を指定した読み出し（R25）では検証できないため。壊れたデータは、デコードや再生の失敗として FR-038 の表示になる
  - 開いたときに zip ファイルの同一性 `ArchiveIdentity`（パス・サイズ・更新日時・inode）を記録する。FSEvents の後に比べて違っていれば、
    zip が変わったものとして閉じる（R26）
- **Rationale**:
  - Apple 標準のフレームワークには、zip の中を一覧して項目の一部だけを読み出す公開 API がない。AppleArchive は独自形式で zip を読めない。
    `NSFileCoordinator` の `.forUploading` は zip を作る側。libarchive は OS に含まれるが SDK に公開ヘッダがない
  - zip の構造（終端レコード・中央ディレクトリ・ローカルヘッダ）は固定長のフィールドが中心で、読み取り専用なら数百行で書ける。
    判断をすべて Core に置けるため、壊れた zip・ZIP64・データ記述子・重複などの異常系を自動テストで網羅できる（原則 IV）
  - 中央ディレクトリは 10,000 項目でも 1MB 前後で、1回の読み込みと解析で SC-015（最初の項目を 1 秒以内）を満たせる
  - `pread` はオフセットを指定する読み出しなので、同じファイル記述子を複数の読み出し（一覧・サムネイル・再生）で共有しても互いに干渉しない
- **Alternatives considered**:
  - `/usr/bin/unzip` や `ditto` を子プロセスで呼ぶ案: 項目の一部だけを読み出せず、再生には一時ファイルへの展開が要る（FR-072 に反する）ため却下
  - libarchive を使う案: SDK に公開ヘッダがなく、自前でヘッダを持ち込むと外部依存と同じ扱いになる（原則 V）ため却下
  - ZIPFoundation などのパッケージを使う案: 外部依存を増やさない方針（原則 V、AGENTS.md）に反するため却下
  - `Data(contentsOf:options: .alwaysMapped)` で zip 全体をメモリマップする案: 実装は簡単だが、読み出しのエラーがページフォールト（SIGBUS）として
    起き、取り外されたボリュームや壊れたファイルをエラーとして扱えない。常駐メモリにも数えられ、SC-014 の計測を難しくするため却下

## R23. zip の中の項目の識別と一覧のモデル

- **Decision**:
  - zip の中の項目は、独自スキーム `mvzip` の URL で表す。形は `mvzip:///<項目のパス>?archive=<zip の絶対パス>` とし、どちらも
    パーセントエンコードする。ディレクトリはパスの末尾を `/` にする。zip の最上位は空のパス（`mvzip:///?archive=…`）。
    先頭行の `..` は、表示中の階層の URL にフラグメント `parent` を付けたものにする。生成と解析は `ArchiveURL` に集め、ほかの場所で
    文字列を組み立てない
  - 一覧の行の型は既存の `MediaFile` を使い続け、`kind` の型を `MediaKind` から行の種類 `ListItemKind`
    （`.media(MediaKind)` / `.archive` / `.directory` / `.parent`）に変える。`ListItemKind` には `isVideo`（メディアの動画だけ true）・
    `mediaKind`・`isMedia`・`opensAsContainer`（`.archive` / `.directory` / `.parent`）を持たせ、既存の `file.kind.isVideo` などの呼び出しは
    そのまま通るようにする
  - 通常のフォルダの zip ファイルの行は、`url` を zip のファイル URL、`kind` を `.archive` にする。zip ファイルそのもののファイル操作
    （FR-073 の最後の文）は、既存の経路がそのまま使える
  - `DirectoryListing.mediaFiles(in:)` は、対応メディアに加えて `.zip` のファイル（拡張子の大文字小文字を区別しない）も返す（FR-068）。
    ツリー用の `subfolders(of:)` と `hasSubfolders(in:)` は変えない（zip はディレクトリとして扱わない）
  - `FolderListing` に `archive: ArchiveLocation?`（開いている zip と、その中の階層のパス）を加える。`folder` は zip の中を表示中も、zip を含む
    フォルダのまま変えない。ペーストの宛先・FSEvents の対象・`lastFolder`（FR-003）がそのまま「zip を含むフォルダ」になる
  - `BrowserModel` は、開いている zip の `ArchiveIndex` を1つだけ持つ（10,000 項目で数 MB）。zip の中の階層を移るときは zip を読み直さず、
    索引から一覧を作る。zip から出たとき（最上位の `..`・⌘↑・ツリーで別のフォルダを選んだとき・FSEvents で zip が変わったとき）に捨てる
  - 並べ替え: `..` は並べ替えの前に取り除き、結果の先頭に戻す（FR-070）。ディレクトリとメディアファイルは区別せず、同じ規則で並べる
    （spec Assumptions）。「種類」列の値は、zip の中のメディアは拡張子の `UTType` の説明、ディレクトリは「フォルダ」、zip ファイルは既存の
    リソース値（`localizedTypeDescription`）とする
  - 種類フィルタ: `MediaTypeFilter.apply(to:)` は `.media` 以外の行を常に残す（FR-056）
  - 空の判定（FR-060）: `.noMatches` は「フィルタ前にメディアが1件以上あり、フィルタ後に0件」。`.empty` は「メディアが0件で、`..` 以外の行も
    ない」。メディアが0件でも zip ファイルかディレクトリがあれば `.loaded` にする
  - 1つ上の階層へ戻ったら、直前まで中を表示していた zip ファイルまたはディレクトリの行だけを選択し、フォーカスにする（FR-070）。
    プレビューは FR-075 により空になる。UI は選択の変化で既存のスクロール追従（`scrollToFocused()`）を呼ぶ
- **Rationale**:
  - URL のまま識別すると、選択（`Set<URL>`）・プレビューのキャッシュ（URL がキー）・サムネイルのキャッシュ（`absoluteString` がキー）・
    `lastPathComponent` と `pathExtension` による形式判定を変えずに使える。AVFoundation の独自スキームの読み込み（R25）にもそのまま渡せる
  - `isFileURL` が false になるため、`FileManager`・`NSWorkspace`・ペーストボードに zip の中の URL が渡る経路を、1つの条件で止められる（R26）
  - 一覧の行の型を1つにすると、リスト形式・サムネイル形式・選択・矢印キーの移動・並べ替えに「ディレクトリとメディアが同じ並びに混ざる」
    規則をそのまま通せる。`MediaFile` の名前は残し、型の名前の変更による差分を避ける
- **Alternatives considered**:
  - 項目の場所を `enum MediaLocation { case file(URL), archiveEntry(...) }` にして選択やキャッシュのキーを置き換える案: 型としては明確だが、
    UI とキャッシュの全経路の型が変わり、差分とテストの書き換えが大きいため却下
  - `MediaFile` とは別に「ディレクトリと zip の行」の配列を持つ案: 並べ替えと矢印キーの移動でディレクトリとメディアが混ざる規則を
    2つの配列で再現する必要があり、ずれやすいため却下
  - `MediaKind` に `.zip` や `.directory` を加える案: `MediaKind(fileExtension:)` が「対応メディアか」の判定（FR-009）を兼ねており、
    種類フィルタやプレビューの判定が壊れるため却下
  - `MediaFile` の型名を `FileListItem` に変える案: 意味は正確になるが、今回の機能と関係のない差分が広がるため今回は見送る

## R24. zip の中の画像とサムネイル

- **Decision**:
  - zip の中の画像は、項目全体を `Data` に読み込んでから ImageIO でデコードする。無圧縮の項目は `pread`、deflate の項目は Compression
    フレームワークの `compression_stream`（`COMPRESSION_ZLIB`、ヘッダのない生の DEFLATE）で展開する。読み込む前に中央ディレクトリの
    展開後のサイズを確かめ、1項目 512MB を超える画像は読まずに「zip の中の画像が大きすぎるため表示できません」とする（FR-038）。
    `Data` はデコードが終わったら捨て、キャッシュにはデコード結果だけを置く（既存の 256MB の上限、R8）
  - `ImageDecoding` に `decode(data:maxPixelSize:)` と `isAnimated(data:)` を加える。`BrowserModel` は、zip の中の画像では同期の
    `isAnimated(url)` を呼ばない（読み出しが UI スレッドで起きるため）。`.loading` にしてから、バックグラウンドで `Data` を読み、
    アニメーションかどうかを決める。アニメーションなら新しい `PreviewContent.animatedImageData(URL, Data)` にし、`ImagePreviewView` は
    `CGAnimateImageDataWithBlock` で再生する。静止画なら `decode(data:)` の結果を `.image` にする
  - 前後1件の先読みも、zip の中の画像は同じ経路（`Data` を読んでデコード）を通す。動画とアニメーションは先読みしない（既存どおり）
  - サムネイル: `ThumbnailProvider` は、`mvzip` の URL では QuickLook を使わない（QuickLook はファイル URL を必要とするため）。画像は `Data` から
    `CGImageSourceCreateThumbnailAtIndex` で作り、動画は R25 の `AVURLAsset` から `AVAssetImageGenerator` で代表フレームを作る。
    zip の中の取得は同時 4 件（動画は 2 件）までに制限し、先頭からの展開が積み上がらないようにする。キャッシュと、URL と要求サイズの組での
    取り消しは既存のものを使う
  - 暗号化・非対応の格納方式・上限超えの項目では、サムネイルは nil を返す。UI は形式別の汎用アイコンにフォールバックする（spec Edge Cases）
- **Rationale**:
  - ImageIO はデータ全体を参照してデコードするため、`Data` で渡すのが最も単純で確実。画像は通常数 MB で、上限で巨大な項目を止められる
  - 画像のデコードとアニメーション判定を1回の読み出しで済ませられ、UI スレッドで zip を読まない（原則 II）
- **Alternatives considered**:
  - `CGDataProvider` の順次コールバックで展開しながら ImageIO に渡す案: ImageIO が内部で全体を複製することがあり、メモリの効果が不確か。
    巻き戻しのたびに展開をやり直す複雑さもあるため却下
  - QuickLook に渡すため一時ファイルへ書き出す案: FR-072 に反するため却下
  - 画像の上限を設けない案: 1項目の展開でメモリを使い切るおそれがあり、原則 II のメモリ上限の考え方に反するため却下

## R25. zip の中の動画のストリーミング再生

- **Decision**:
  - `AVURLAsset(url: <mvzip の URL>)` に、Core の `ArchiveAssetLoader`（`AVAssetResourceLoaderDelegate`）を設定する。
    `ArchiveAssetFactory.makeAsset(for:)` が asset とデリゲートを組で作り、asset が生きている間はデリゲートを保持する
    （`AVAssetResourceLoader` はデリゲートを弱参照するため）。`VideoPreviewView` は、ファイル URL では従来どおり `AVPlayerItem(url:)`、
    `mvzip` の URL では factory の asset から `AVPlayerItem(asset:)` を作る。`AVPlayerLooper` が作る項目の複製は同じ asset を共有するため、
    ループ再生でも読み込み器は1つ
  - 内容の情報: `contentType` は拡張子の `UTType`（`.mpeg4Movie` / `.quickTimeMovie`）、`contentLength` は展開後のサイズ、
    `isByteRangeAccessSupported = true` を返す
  - データの要求: 要求された範囲（`requestedOffset` から `requestedLength` まで、または `requestsAllDataToEndOfResource` なら末尾まで）を、
    512KB ずつ `respond(with:)` で返す。1つの要求をまとめて読み込まない。各チャンクの間で取り消し（`resourceLoader(_:didCancel:)`）を確かめる。
    デリゲートのコールバックは専用の直列キューで受け、読み出しは要求ごとのタスクで行う。ある要求の展開が、ほかの要求を待たせないようにする
  - 無圧縮の項目: `pread` で要求範囲を直接読む。使うメモリは応答中のチャンクだけ
  - deflate の項目: `InflateCursor`（`compression_stream` を包み、展開後の位置を覚える順方向のカーソル）で展開する
    - 要求位置がカーソルより前なら先頭から展開し直し、後ろなら読み捨てながら進む
    - カーソルは1つの asset につき最大 2 本を LRU で使い回す（再生位置用と、末尾の moov など離れた位置の読み出し用）。離れた位置への
      交互の要求で、先頭からの展開が繰り返されないようにする
    - 展開済みのデータは 1MB 単位のチャンクで LRU キャッシュ（1 asset あたり 32MB）に置き、AVPlayer の小さな後戻りや重複した要求に、
      展開し直さずに応える
    - 1 asset のメモリは、キャッシュ 32MB + カーソル 2 本（各 `compression_stream` の状態と 64KB の入出力バッファ）+ 応答中のチャンクで
      上限が決まり、動画のサイズに依存しない（FR-072、SC-014）
    - 後ろへのシークでは先頭から目的の位置まで展開し直すため、大きな動画では数秒かかることがある（spec Assumptions）。非 faststart の
      mp4 / mov は、再生の開始前に1回末尾まで展開する
  - 展開の途中経過を保存して任意の位置から展開を再開する方式（zlib の `zran` の考え方）は、今回は採らない。Compression フレームワークは
    展開器の内部状態（32KB の窓とビット位置）を外に出せず、自前の inflate の実装（数百行）が必要になるため。シークの遅さが問題に
    なったら、`InflateCursor` の内部だけを置き換える（インターフェースは変えない）
  - SC-014 の計測: 性能テストで、展開後 1GB の deflate 項目（ゼロ埋めのため zip 自体は数 MB）を `ArchiveEntryStream` で先頭から末尾まで
    読み、途中で後ろ向きのシークを挟む。読み出しの前後でプロセスの物理フットプリント（`task_info` の `phys_footprint`）を比べ、
    増加が 128MB 以下であることを確かめる。無圧縮の 1080p 動画の再生開始は、既存の os_signpost `VideoPlaybackStart` で 1 秒以内を確かめる
- **Rationale**:
  - 独自スキームの読み込みは AVFoundation 標準の拡張点で、ネットワークを使わずに、AVPlayer の範囲要求に合わせて必要な部分だけを読める
  - 無圧縮で格納された動画は、通常のファイルとほぼ同じ速さで読めるため、SC-014 の再生開始 1 秒を満たせる
  - 読み込み器を Core に置くと、AppKit なしで `AVURLAsset` の `duration` の読み込みなどを自動テストできる（原則 IV）
- **Alternatives considered**:
  - 一時ファイルに展開して再生する案: ユーザー判断（ストリーミング方式、2026-10-21）と FR-072 に反するため却下
  - 動画全体をメモリに展開して渡す案: メモリが動画のサイズに比例し、SC-014 に反するため却下
  - 自前の inflate でチェックポイントの索引を作る案: シークは速くなるが実装量が増える。上記のとおり、必要になったときの置き換え先として残す
  - `AVSampleBufferDisplayLayer` に自前でデマックスして渡す案: 実装量が大きく、`AVPlayerView` の標準コントロール（FR-033）を失うため却下

## R26. zip の中の操作（開く・戻る・読み取り専用・プレビュー・フルスクリーン）

- **Decision**:
  - 開く: ダブルクリック（`NSTableView.doubleAction`、`NSCollectionView` のクリック数 2 の `mouseDown`）と ⌘↓ を、
    `FileListViewController.openFocusedItem(_:)` に集める。対象はフォーカス行。zip ファイル・ディレクトリなら中へ入り、`..` なら1つ上へ戻る。
    メディアの行では何もしない（FR-069）
  - 戻る: ⌘↑ を `FileListViewController.goToEnclosingLevel(_:)` に割り当てる。zip の中でなければ何もしない
  - メニュー: 「ファイル」メニューの「開く」の後ろに「中を表示」（⌘↓）と「上の階層へ」（⌘↑）を置く（Finder の「開く」と「移動 > 内包しているフォルダ」に
    相当。「移動」メニューは新しく作らない）。アクションは宛先なしで、ファイルリストがレスポンダーチェーンにあるときだけ有効にする。
    名前の変更中は無効。ツリーやプレビューにフォーカスがあるときは無効になり、⌘↓ / ⌘↑ はほかのペインに影響しない
  - メニュー項目が無効なとき（メディアの行での ⌘↓、zip の外での ⌘↑）でも、キーは `NSTableView` / `NSCollectionView` の既定の動作
    （⌘↓ = 末尾へ移動など）に渡さない。`ListModeView` / `ThumbnailModeView` の `keyDown` で ⌘↓ / ⌘↑ を消費し、何もしない（FR-069 の「何もしない」）
  - 読み取り専用（FR-073）: 判断は Core の `ListItemCommands`（行の種類と「zip の中を表示中か」から、操作ごとの可否を返す純粋計算）に置く。
    `FileListViewController.validateMenuItem` は、zip の中を表示中なら「開く」「ゴミ箱に入れる」「名前を変更」「複製」「コピー」「ペースト」
    「移動ペースト」「Finder に表示」を無効にする。「Finder に表示」も、zip の中の項目を Finder で指せないため無効にする。各アクションの先頭でも同じ
    条件で何もせずに戻る（メニューを通らないキー操作への備え）。`ListModeView` / `ThumbnailModeView` の Return による名前の変更も止める。
    ドラッグは、`pasteboardWriterForRow` / `pasteboardWriterForItemAt` が `mvzip` の URL と `.parent` の行に nil を返して始めない
  - 通常のフォルダの zip ファイルの行は、既存のファイルと同じく全操作を有効にする。「開く」（⌘O）は既定のアプリで開く既存の動作のまま
    （ユーザーが明示的に選ぶ操作で、FR-072 の「ユーザーのフォルダへの書き出し」はアプリ自身による展開を禁じるもの）
  - プレビュー（FR-075）: `BrowserModel.loadPreview` は、フォーカス行がメディアでなければ `.empty` にする。`select` の既存の停止通知で
    動画は止まる。これまで `MediaKind(fileExtension:)` で判定していた部分は、一覧の行の `kind` で判定する（拡張子が .zip の行が
    「対応していない形式」と表示されないようにする）
  - フルスクリーン（FR-046）: `FocusNavigator.targetIndex` に `isNavigable: (Int) -> Bool` を受けるオーバーロードを加え、移動先がメディアの行に
    当たるまで同じ方向への移動を繰り返す。見つからなければ nil（端で停止）。通常表示の矢印キーは従来の関数のまま（メディア以外の行にも止まる）
  - 行頭アイコンとサムネイル: zip ファイルは SF Symbol `doc.zipper`、ディレクトリは `folder`、`..` は `arrowshape.turn.up.left` を使い、
    縮小画像は取得しない。a11y のラベルは名前（`..` は「上の階層へ」）にする
  - 読み込み中: zip を開く間は既存の `.loading` の表示（プログレス）を使う（SC-015）
  - 失敗の表示: zip を開けない（壊れている・zip ではない・分割 zip）ときは `FolderListing.State.failed("zip を開けません: <理由>")` にし、
    行は `..` だけを出す。⌘↑ とダブルクリックで戻れる
  - メッセージと行の両立: `.empty` / `.noMatches` / `.denied` / `.failed` で行が残る場合（`..` やディレクトリ）は、一覧を表示したまま、一覧の下端に
    1行のメッセージの帯を出す。行が1つもないときは、従来どおり一覧の中央に出す
  - FSEvents: zip の中を表示中に、zip を含むフォルダの変更が通知されたら `ArchiveIdentity` を比べる。変わった・消えたときは zip を閉じて
    フォルダの一覧を読み直し、プレビューを空にする（spec Edge Cases）。変わっていなければ何もしない（戻るときにフォルダを読み直す）
  - ツリーで別のフォルダを選んだとき（FR-069）は、既存の `selectFolder(_:)` が zip の状態を捨てる
- **Rationale**:
  - 開く・戻るをメニュー項目にすると、キー割り当てがメニューに表示され、a11y からも操作を見つけられる（原則 III）。レスポンダーチェーンで
    有効範囲がファイルリストに限られ、ツリーの ⌘↓ などとぶつからない
  - 読み取り専用の判断を純粋計算にまとめると、メニュー・キー・ドラッグで同じ規則を使え、Core のテストで網羅できる（原則 IV）
  - フルスクリーンの読み飛ばしを `FocusNavigator` に置くと、既存の端の規則（FR-046）と同じ関数で検証できる
- **Alternatives considered**:
  - Return で開く案: ユーザー判断（⌘↓ / ⌘↑、2026-10-21）と異なるため却下
  - ツリーに zip を出す案: ユーザー要件（ツリーで zip をディレクトリとして扱わない）に反するため却下
  - zip の中の項目のドラッグやコピーで取り出す案: ユーザー判断（読み取り専用、2026-10-21）と異なるため却下
  - `..` を一覧の行ではなく一覧の上のボタンにする案: ユーザー要件（先頭の行の項目）と異なり、矢印キーで届かないため却下
  - zip の中を表示中も FSEvents のたびにフォルダを読み直す案: zip の中の一覧には関係のない読み込みが増えるため却下

## R27. zip の中の名前の文字コードの判定

- **Decision**:
  - Core の純粋関数 `ArchiveNameDecoder.decode(_ bytes: Data, utf8Flag: Bool) -> String` にする（FR-074）
    1. 汎用フラグのビット 11 があれば UTF-8 として読む（不正なバイトは置換文字にする）
    2. ビット 11 がなく、厳密な UTF-8 として読めれば UTF-8
    3. 読めなければ CP932（CoreFoundation の `CFStringEncodings.dosJapanese`）
    4. それでも読めなければ CP437（`CFStringEncodings.dosLatinUS`。256 バイトすべてが定義されているため必ず読める）
  - 変換は CoreFoundation 標準の文字コード変換を使い、自前の変換表を持たない
  - 判定は名前ごとに行う。区切りの `/` は判定後の文字列で分ける（CP932 の2バイト目に 0x2F は現れないため、バイト列で分けても結果は同じ）
  - Info-ZIP の Unicode Path 拡張フィールド（0x7075）は使わない。FR-074 の規則に含まれないため
- **Rationale**:
  - 日本語環境の古い zip（Windows の標準機能や古いアーカイバで作ったもの）の名前は CP932 で記録されている。ASCII だけの名前は、どの規則でも
    同じ結果になる
  - CP932 の日本語のバイト列が、偶然に厳密な UTF-8 として正しくなることはまれなので、2 の判定で誤ることはほとんどない
  - CoreFoundation の変換は OS 標準で、表を同梱・保守する必要がない（原則 V）
- **Alternatives considered**:
  - `String.Encoding.shiftJIS` を使う案: JIS X 0208 だけを対象にした変換で、①② や NEC・IBM の拡張文字を読めないため却下
  - zip 全体で1つの文字コードを決める案: spec は名前ごとの判定（FR-074）を求めているため却下
  - 自前の変換表を持つ案: CoreFoundation で足りるため却下
  - 0x7075 を優先して使う案: spec の規則の外で、名前の表示が規則と食い違うことがあるため今回は見送る

## R28. zip のフィクスチャと検証

- **Decision**:
  - `FixtureKit` に、テスト用の zip を書き出す `ZipFixtureWriter` を置く。無圧縮・deflate（Compression フレームワークで圧縮）・データ記述子
    （ビット 3）・UTF-8 フラグの有無（CP932 の名前）・暗号化フラグ・非対応の格納方式（12 = bzip2、中身はダミー）・ZIP64・ディレクトリの
    項目の有無・`__MACOSX/`・入れ子の zip・同じパスの重複を指定して作れるようにする。CRC32 は `FixtureKit` の中の小さな実装で計算する
  - 壊れた zip（途中で切れたもの・終端レコードのないもの・中身がテキストの `.zip`）と、10,000 項目の zip（SC-015）、展開後 1GB の
    ゼロ埋めの deflate 項目を持つ zip（SC-014。zip 自体は数 MB）を生成できるようにする
  - 外部の `zip` コマンドには頼らない。テストの結果を環境に依存させず、異常系を正確に作るため
  - `scripts/make-fixtures.sh` は、手動検証用に `zip/` フォルダを作る（[quickstart.md](./quickstart.md)）。SC-014 のメモリの確認用の約 1.1GB の動画の zip
    （`zip-big/`）は、時間とディスクを使うため `--big` を付けたときだけ作る。動画の素材は `VideoFixtures` に faststart とビットレートの指定を足して作る
  - 一時ファイルを作らないこと（FR-072）は、実行時に共有の一時ディレクトリの増減では判定できない（並列のテストもフィクスチャを作る）。
    `scripts/check-no-archive-writes.sh` で zip の読み取りのコードに書き込み系の API がないことを確かめ、実行時は `fs_usage` で確認する
- **Rationale**: 異常系（暗号化・非対応方式・壊れた zip・文字コード）を、自動テストで確実に再現できる（原則 IV）
- **Alternatives considered**:
  - `/usr/bin/zip` でフィクスチャを作る案: 暗号化フラグだけを立てる、方式を偽る、CP932 の名前を書くといった異常系を作れないため却下
  - フィクスチャの zip をリポジトリにコミットする案: 1GB 相当の項目や 10,000 項目の zip は大きく、生成で済むため却下

## R29. ファイルリストのフォルダの行（FR-008・076）

- **Decision**:
  - `ListItemKind` に `.folder` を加える。通常のフォルダの一覧に出るサブフォルダの行で、zip の中のディレクトリ（`.directory`）とは
    別の値にする。`.folder` はファイル URL を持ち、ファイル操作の対象になる。`.directory` は `mvzip` の URL で読み取り専用のまま
  - `DirectoryLister.mediaFiles(in:)` は、メディアと zip ファイルに加えて、サブフォルダを `kind: .folder` で返す。どのフォルダを出すかは
    ツリーの `subfolders(of:)` と同じ判定（`isVisibleSubfolder`: ディレクトリで、パッケージではない。隠しフォルダは `.skipsHiddenFiles` で除く）に
    そろえ、ツリーとファイルリストで出るフォルダを一致させる。パッケージ（`.app` など）はツリーと同じく出さない。拡張子が .zip の
    ディレクトリはパッケージでなければ `.folder` として出す（zip としては扱わない）
  - `.folder` の行の `typeDescription` は「フォルダ」、`creationDate` はファイルシステムの作成日時、`fileSize` は 0（中身を数えない）
  - メソッド名 `mediaFiles(in:)` は変えない（呼び出し側・テストのフェイクを広く書き換えないため）。ドキュメントコメントで返す行を明記する
  - 並べ替え: `sorted(_:by:)` は `.folder` も区別せずに混ぜる（2026-10-21 のユーザー判断）。「種類」列の第2キー `sortKey` に `"folder"` を加える
  - `.folder` の行は、プレビュー（`.empty`）・先読み（しない）・縮小画像（取得しない。SF Symbol `folder`）・種類フィルタ（常に残す）・
    FR-060 の件数（数えない）・フルスクリーンの矢印移動（読み飛ばす）で、`.directory` と同じ経路を通す。既存の判定は `kind.isMedia` で
    書かれているため、`ListItemKind` に値を足すだけで成り立つ
- **Rationale**:
  - ツリーとリストで出るフォルダの判定を共有すると、ツリーにないフォルダへリストから入る（その結果ツリーの同期ができない）ことが起きない
  - `.directory` と分けると、操作の可否（`ListItemCommands`）を「行の種類」だけで決められ、zip の中の読み取り専用の規則を崩さない
- **Alternatives considered**:
  - `.directory` を通常のフォルダにも使う案: 操作の可否が URL のスキームに依存し、判定が散らばるため却下
  - フォルダ用に別の列挙メソッド（`folderItems(in:)`）を足して `BrowserModel` で合成する案: ディレクトリを2回読むことになり、10,000 件規模の
    フォルダで SC-003 に響くため却下（`contentsOfDirectory` の1回の結果からフォルダとファイルを分ける）
  - パッケージもフォルダとして出す案: ツリーに出ないため FR-078 の同期ができず、Finder もパッケージを1つのファイルとして扱うため却下

## R30. 上の階層へ戻る行 `..` と ⌘↑（FR-070・077）

- **Decision**:
  - 戻る行の表記を、zip の中も含めて `..` に統一する（2026-10-21 のユーザー判断。zip の行の旧表記 `...` を置き換える）。行の種類は
    zip の中と同じ `.parent`。zip の中で名前が `..` の項目は既存の `ArchiveIndex` が捨てるため、実在の項目と見分けがつかなくなることはない
  - ツリーのルートの一覧を Core に渡す: `BrowserModel.setNavigationRoots(_ urls: [URL])` を追加し、`MainSplitViewController` が最初の
    `selectFolder` の前に `VolumeProvider.rootNodes()` の URL を渡す。ツリーの `applyRoots`（ボリュームの増減）でも渡し直す。既定は空で、
    空のときは通常のフォルダに `..` を出さない（既存のテストの一覧を変えない）
  - 親の決め方は純粋関数 `FolderNavigation.enclosingFolder(of folder: URL, roots: [URL]) -> URL?` に置く:
    - `folder` がいずれかのルートと同じなら nil（ツリーのルートでは `..` を出さず、⌘↑ も何もしない）
    - `folder` を含むルートのうち最も深いもの（ホーム `/Users/me` と起動ボリューム `/` の両方に含まれるときはホーム）を選び、
      その中での親を返す。どのルートにも含まれないときは nil（ツリーの外へ出ない）
    - 比較は `standardizedFileURL` のパスの要素で行う（`/Users/me2` を `/Users/me` の配下と誤らない）
  - `rebuildListing()` は、zip の中では従来どおり `ArchiveURL.parentLink(of:)` の行を、通常のフォルダでは `enclosingFolder` が nil でない
    ときに `ParentLink.url(for: folder)`（独自スキーム `mvparent:` とフォルダのパス）の行を先頭に1回だけ加える。名前は `..`、
    `typeDescription` は空、`creationDate` は nil
  - `mvparent:` の URL は `FileManager`・`NSWorkspace`・ペーストボードに渡さない。`.parent` の行は `ListItemCommands` でファイル操作を
    不可にし、操作の対象の URL（`BrowserModel.operableSelection`）からも除く（⌘A で `..` が選択に入っても、コピー・ゴミ箱などの対象にならない）
  - `BrowserModel.goToEnclosingLevel()`: zip の中は従来どおり。zip の外では `enclosingFolder` があればその一覧へ移り（R31 の
    `navigateToFolder`）、読み込み後に直前まで表示していたフォルダの行だけを選択する。なければ何もしない
  - `ListItemCommands.canGoUp` は「zip の中」ではなく「戻る先があるか」（`hasEnclosingLevel`）で決める。`BrowserModel.hasEnclosingLevel` は
    `listing.archive != nil || enclosingFolder(of: listing.folder) != nil`
  - お気に入りの項目のフォルダを表示中も同じ規則で、そのフォルダがルートでなければ `..` を出す（FR-077）
  - 読めないフォルダ（`.denied` / `.failed`。一覧から権限のないフォルダへ入った場合など）でも、ルートでなければ `files` を `..` だけにし、メッセージは
    一覧の下端の帯に出す（zip を開けないときと同じ。R26）。ダブルクリックだけでも戻れるようにし、行き止まりを作らない
  - 中へ入った直後の一覧は、zip の中と同じく何も選択しない（Finder と同じ。spec の Outstanding をこの規則で閉じる）
- **Rationale**:
  - ツリーのルートの集合はツリー（ボリュームの増減を受け取る側）が持っているため、Core に値で渡すと判定を純粋関数にでき、テストで
    ホーム・起動ボリューム・外付けボリュームの組み合わせを網羅できる（原則 IV）
  - 親の判定を「最も深いルート」にそろえると、ツリーの `reveal` と同じ階層で親を選べ、ホームから `/Users` へ抜けることがない
  - 戻る行を zip の中と同じ `.parent` にすると、並べ替え（常に先頭）・種類フィルタ・FR-060・プレビュー・フルスクリーンの既存の扱いをそのまま使える
- **Alternatives considered**:
  - `BrowserModel` が `VolumeProvider` を直接持つ案: Core の中でボリュームの監視が二重になり、テストでルートを差し替えにくいため却下
  - `..` の行の URL に親フォルダのファイル URL を使う案: 一覧の中の同名の行や、ペーストボード・ドラッグへ誤って渡る経路ができるため却下
  - ルートでも `..` を淡色で出す案: ユーザー判断（ルートでは出さない、2026-10-21）と異なるため却下

## R31. ファイルリストの移動とツリーの選択の同期（FR-078）

- **Decision**:
  - `BrowserModel` に非公開の `navigateToFolder(_ url: URL, selecting: URL?)` を置き、`.folder` の行を開く・`..`・⌘↑ の3経路で使う。
    中身は `selectFolder(_:)` と同じ（読み込みの取り消し、`lastFolder` の保存、種類フィルタの保持）に加え、読み込み後に `selecting` の行だけを
    選択し、ツリーへの同期の依頼を出す
  - 依頼は観測できる値 `public private(set) var treeSyncRequest: TreeSyncRequest?`（`folder: URL` と、毎回増やす `id: Int`）で出す。
    ツリーから呼ばれる `selectFolder(_:)` は依頼を出さない（ツリー自身の操作を送り返さない）
  - ツリー（`DirectoryTreeViewController`）は `treeSyncRequest` を `withObservationTracking` で監視し、変わったら `reveal(folder)` を実行する:
    - 進行中の `revealTask` を取り消してから始め、完了時に `id` が最新でなければ選択を変えない（⌘↓ を続けて押したときに古い結果で戻らない）
    - ユーザーがツリーで行を選んだとき（`isRestoringSelection` でない `outlineViewSelectionDidChange`）は、進行中の同期の `revealTask` を取り消す。
      ツリーからの選択は `treeSyncRequest` を変えないため、`id` の比較だけでは、遅れて終わった同期がユーザーの選択を上書きしてしまう
    - さらに選択を当てる直前に、`model.listing.folder` と依頼の `folder` が同じ（`standardizedFileURL`）であることを確かめ、違えば選択を変えない
      （取り消しが間に合わなかった場合の保険。ツリーの選択がファイルリストの表示と食い違ったまま残らない）
    - `reveal` はルートのうち最も深いもの（R30 と同じ規則）から辿り、各段で子を読み込んでから展開する（既存の `loadAndExpand`）。
      展開に伴う FR-055 のサブフォルダ確認も既存のまま行う
    - 行の選択は `isRestoringSelection = true` の間に行い、`outlineViewSelectionDidChange` から `selectFolder` を呼び返さない。
      スクロールは `scrollRowToVisible`（必要最小限）。`makeFirstResponder` は呼ばず、キーボードフォーカスはファイルリストに残す
    - お気に入りの項目を選択中でも、実際の階層の行へ選択を移す（FR-078）
    - 子フォルダの展開状態は変えない（戻ったときに折りたたまない）
    - 途中の段が見つからない（読めない・直前に消えた）ときは、辿れた最も深い行を選択して止める。一覧の表示は変えない
  - 一覧の読み込みとツリーの `reveal` は独立に進み、一覧の表示はツリーの完了を待たない
- **Rationale**:
  - 依頼を値として公開すると、Core のテストで「どの操作で依頼が出るか」（フォルダを開く・戻るでは出る、ツリーからの選択・zip の中の移動では
    出ない）を検証できる（原則 IV）。ツリーの UI はその値を描画するだけになる
  - `isRestoringSelection` は、ボリュームの増減でお気に入りの選択を戻すときに使っている既存の仕組みで、選択の送り返しを防げる
- **Alternatives considered**:
  - ツリーが `listing.folder` の変化を直接見て `reveal` する案: ツリーからの選択でも走り、FSEvents で消えたフォルダの親へ戻ったときなど
    同期すべきでない経路でも選択が動くため却下
  - ファイルリストからツリーのメソッドを直接呼ぶ案: ビューコントローラ同士の結合が増え、Core のテストで経路を検証できないため却下
  - 同期のときにツリーへフォーカスを移す案: ユーザー判断（フォーカスはファイルリストに残す、2026-10-21）と異なるため却下

## R32. フォルダのファイル操作（FR-018・076）

- **Decision**:
  - `ListItemCommands` の可否（data-model の表）: `.folder` は通常のファイルと同じく、開く（⌘O）・コピー・複製・名前の変更・ゴミ箱・
    Finder に表示・ドラッグを可にする。⌘O は既存どおり `NSWorkspace` の既定のアプリ（フォルダなら Finder）で開き、一覧の中で開くのは
    ダブルクリックと ⌘↓ だけにする。`.parent` は zip の外でもすべて不可。zip の中は従来どおりすべて不可
  - 操作の対象: `FileListViewController.selectedFileURLs` を `BrowserModel.operableSelection`（一覧の並び順で、`.parent` を除いた選択）に
    置き換える。フォーカスが `..` で、ほかに選択がないときは、メニュー項目を淡色にする
  - 実行は既存の `FileOperationService` のまま（`copyItem` / `moveItem` / `trashItem` はディレクトリを中身ごと扱う。自分自身や配下への移動・
    コピーの拒否も既にある）。同名の衝突（FR-025）の「置き換える」はフォルダごと置き換える
  - 名前の変更: `validateNewName(_:for:existingNames:)` に `isDirectory: Bool = false` を足し、フォルダでは拡張子の変更の確認を出さない
    （フォルダの名前の `.` 以降は拡張子として扱わない）。空・使えない文字・同名の判定は同じ
  - 確認モーダル（FR-022）: 対象にフォルダが含まれるときは、文言に「フォルダは中身ごと」を添える（例: 「「旅行」をゴミ箱に入れますか？
    フォルダは中身ごと移動します」）。省略設定（FR-023）の扱いは変えない
  - ツリーへのドロップ: `validateDrop` で、ドラッグ中の URL にドロップ先のフォルダ自身またはその祖先が含まれるときは `[]` を返す
    （実行時の拒否に加え、ドロップできない見た目にする）
  - ツリーへの即時反映（FR-027）: `FileOperationCoordinator` に `onFoldersChanged: ((Set<URL>) -> Void)?` を足し、操作の完了後に
    影響したフォルダ（対象の親フォルダと操作先）を渡す。ツリーはそれを FSEvents のバッチと同じ処理（`reloadChildren(of:)` と
    サブフォルダの再確認、お気に入りの存在の確認）に流す。FSEvents の通知も従来どおり受け、重複しても結果は同じ
  - フォルダの削除はファイルリストだけで行い、ツリーの右クリックメニューと ⌘⌫ は変えない（FR-064、2026-10-21 のユーザー判断）
- **Rationale**:
  - 既存のファイル操作のサービスは URL の種類を区別しないため、可否の表と対象の絞り込みを変えるだけで成り立つ（原則 V）
  - FSEvents だけに頼るとツリーの反映に通知の遅延（最大で約 1 秒）がかかるため、操作の完了時に直接知らせる
- **Alternatives considered**:
  - フォルダの操作を別のサービスに分ける案: 実行の中身が同じで、重複になるため却下
  - フォルダのゴミ箱に中身の件数を数えて確認モーダルに出す案: 巨大なフォルダで確認の表示が遅れ、件数の取得自体が UI を待たせうるため見送る
