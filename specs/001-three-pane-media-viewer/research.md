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
  で再生する。表示位置・大きさは Core の `FitCalculator` が計算する（ペインより小さい画像は原寸を超えて
  拡大しない: FR-028）
- **Rationale**:
  - 1億画素級の画像でもフル解像度を展開せずに済み、メモリと時間を抑えられる（SC-001・エッジケース）
  - スクリーンサイズでデコードしておけば、ペインのリサイズやフルスクリーン切替で再デコードが不要
  - デコードはバックグラウンドで行い、UI スレッドを塞がない（原則 II）
- **Alternatives considered**: `NSImage(contentsOf:)`（遅延デコードで、表示時に UI スレッドで全解像度を
  展開しうる）、`NSImageView.animates`（WebP アニメーションの扱いが不確実）
- **アニメーション WebP**: `CGAnimateImageAtURLWithBlock` で再生できればアニメーションとして表示し、
  できなければ（エラーが返る、または1フレームしか届かない場合）先頭フレームの静止画として表示する。
  フレームを自前のタイマーで送る独自の再生処理は作らない（ユーザー判断 2026-10-19、FR-030、原則 V）

## R6. 動画再生

- **Decision**: AVKit の `AVPlayerView`（標準コントロール）+ `AVQueuePlayer` + `AVPlayerLooper`。
  自動再生とループの ON/OFF は動作オプションから決める
- **Rationale**: 再生/一時停止・シーク・音量・キーボード操作（Space 等）・a11y が標準で備わる（FR-033）。
  ループは `AVPlayerLooper` で継ぎ目なく実現できる
- **Alternatives considered**: `AVPlayerLayer` と自前のコントロール（実装量が増え、a11y も自前になる）

## R7. サムネイル生成とキャッシュ

- **Decision**: `QLThumbnailGenerator`（QuickLookThumbnailing）で画像・動画のサムネイルを共通に生成する。
  サイズは 128 / 256 / 512 px（×スクリーン倍率）の段階に丸めて要求し、スライダー操作のたびに作り直さない。
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
