# Bug Assessment: フォルダの監視がファイルディスクリプタを使い切り、描画中に落ちる

- **Slug**: fsevents-watchroot-fd-exhaustion
- **Created**: 2026-10-25
- **Source**: pasted text（クラッシュレポート `MediaViewer-2026-10-25-031405.ips`）と、assess 中の調査（システムログ・計測）
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> テスト中にウィンドウサイズを変更した際に落ちました。

クラッシュレポートの要点:

- `Exception Type: EXC_CRASH (SIGABRT)`、`Triggered by Thread: 5, Dispatch Queue: CA::CG::Queue`
- Thread 5: `MTLReportFailure` ← `-[_MTLFunctionInternal initializePublicMetadata]` ← `CA::OGL::MetalContext::load_shader_function` ←
  `CA::CG::fill_path`（Core Animation が CG の描画を Metal で行う途中で、シェーダーの読み込みに失敗して assert）
- Thread 0（メイン）: `-[NSSplitView mouseDown:]` の中で `CA::Transaction::commit()` を待っている（ペインの仕切りのドラッグ中）
- アプリのコードはクラッシュしたスレッドに出てこない
- macOS 26.6.2（25G83）、Mac15,12、`.app`（release ビルド）

## Symptom

`.app` を使っている途中でペインの仕切り（ウインドウの大きさ）を変えると、アプリが SIGABRT で終了する。期待する動作は、
仕切りやウインドウの大きさを変えても終了しないこと。

## 仕様との照合

- **憲章 原則 IV**: 「アプリは異常系でクラッシュしてはならない（MUST NOT）」。監視するフォルダが増えるという通常の使い方で
  異常終了しており、これに反する
- **FR-042**（overview.md）: 外部で行われたファイル・フォルダの追加・削除・名前変更をツリーとリストに反映しなければならない。
  ディスクリプタが尽きると `FSEventStreamCreate` が失敗し（ログの `watch_path() failed ... Too many open files`）、反映も止まる
- **FR-087・EC-36**（search.md）: 検索起点そのものの削除・移動を受け取るために `kFSEventStreamCreateFlagWatchRoot` を使う（001 の
  research.md R38）。この要件は起点（`subtrees`）にだけ必要で、通常のフォルダ（`folders`）には必要ない。`FileSystemWatcherTests` の
  「起点自身・親フォルダの削除と移動は、起点の URL として流す。folders だけなら自身は流さない」も、`folders` に起点の移動の通知を
  求めていない

判定: **実装が仕様に反している**。fix へ進む（`specs/product/` は変更しない）。

## Reproduction

1. `scripts/make-app.sh` の後、`open .build/MediaViewer.app` で起動する（GUI アプリのディスクリプタの上限は 256。
   `launchctl limit maxfiles` → `256 unlimited`）
2. ツリーで、サブフォルダの多いフォルダを展開していく（展開していない行も、見えていれば監視の対象になる）。
   お気に入りを登録し、検索結果を表示すると、監視の対象がさらに増える
3. フォルダの選択・展開を続ける（そのたびに監視を作り直す）と、ある時点からシステムログに
   `FSEventStreamCreate: ... watch_path() failed ... (24):(Too many open files)` が出る
4. その状態でペインの仕切りをドラッグする（または、新しい描画のシェーダーが要る操作をする）と、Metal がシェーダーの
   ライブラリを開けずに assert し、アプリが終了する

ユーザーの環境では、1〜3 個のフォルダを展開した状態で、フォルダの削除と名前の変更を繰り返して起きた（Open Questions を参照）

### 調査で確かめたこと

- システムログ（PID 32273）:
  - 03:13:23.136 と 03:13:38.155 に `[com.apple.fsevents:client] FSEventStreamCreate: _FSEventStreamCreate: ERROR: watch_path() failed for
    srcPath='<private>' ... (24):(Too many open files)`
  - 03:13:57.542 に `(Metal) readFunctionPublicOrPrivateMetadata, line 6599: error '<private>'`（クラッシュの直前）
- 計測（Swift Testing のテストプロセスで `/dev/fd` の数を数えた。調査用のテストはコミットしていない）:
  - `kFSEventStreamCreateFlagWatchRoot` を付けたストリームで 100 フォルダを監視すると +1,101、付けないと +0
  - `FileSystemWatcher` で 10〜11 フォルダの監視を作り直し続けると +232 で頭打ち。古いストリームのディスクリプタは止めてから
    約2秒後に閉じられるため、作り直しの直後は新旧の分が重なる（監視をやめて2秒待つと +0。リークではない）
  - 1パスあたりの数（約11）は、パスの要素の数（祖先の数）とほぼ同じ

## Suspected Code Paths

- `Sources/MediaViewerCore/FileSystem/FileSystemWatcher.swift:128-169`（`rebuildStream`）— `folders` と `subtrees` のすべてのパスを
  1つのストリームにまとめ、`kFSEventStreamCreateFlagWatchRoot` を付けている（146〜149 行）。WatchRoot はパスごとに祖先を開いて
  見張るため、監視の数 × パスの深さのディスクリプタを使う
- `Sources/MediaViewerCore/FileSystem/FileSystemWatcher.swift:106-126`（`applyFolders`）— `folders` と `subtrees` のどちらが変わっても
  ストリームを丸ごと作り直す。作り直しのたびに、解放の遅れでディスクリプタが一時的に2倍になる
- `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift`（`updateWatchSet`）— 監視の対象は、表示中のフォルダ・展開した行・
  見えているすべての行（折りたたみ中の行もサブフォルダの有無の更新のため）・お気に入りの親・検索の起点。ツリーの選択・展開・
  読み込みのたびに呼ばれる。対象の決め方自体は FR-054・FR-067・FR-087 のための既存の設計で、今回は変えない

## Root Cause Hypothesis

WatchRoot は検索の起点の移動・削除を受け取るために Phase 25（`9b781b6`、R38）で付けたが、起点だけでなく通常のフォルダの監視にも
付けている。そのため、ツリーで見えている行の数 × パスの深さのディスクリプタを使い、作り直しの直後は2倍になる。GUI アプリの上限 256 に
十数〜二十程度のフォルダで達し、`FSEventStreamCreate` が失敗するうえ、同じプロセスで Metal がシェーダーのライブラリを開けずに
assert して終了する。確度: **high**（ログの EMFILE、WatchRoot の有無による計測の差、上限 256 が揃っている）。

## Proposed Remediation

**Preferred**（ユーザー承認済み）: `FileSystemWatcher` のストリームを2つに分ける。

- `folders` 用のストリーム: `kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes`（WatchRoot なし）
- `subtrees` 用のストリーム: 上に加えて `kFSEventStreamCreateFlagWatchRoot`（起点自身と祖先の移動・削除を受け取る。R38 のまま）
- `applyFolders` は、変わった側のストリームだけを作り直す（ツリーの操作で `folders` が変わるたびに `subtrees` 側を作り直さない）
- 2つのストリームは同じ `queue` とコールバックを使い、`handleEventPaths` は今のまま（`folders` と `subtrees` の両方の判定を行う）。
  どちらのストリームから届いたイベントでも同じ判定でよい
- `stopStream` は2つのストリームを止める。`deinit` も同じ

**Alternatives**:

- 起動時に `setrlimit(RLIMIT_NOFILE)` でソフト上限を引き上げる: すぐ効くが、監視の数に比例して増える構造は残り、上限を超えれば
  同じことが起きる。必要なら、保険として後で別に足す
- 監視の対象を減らす（見えているすべての行ではなく、展開した行だけにする）: FR-054 の「折りたたみ中のフォルダの三角の更新」に関わり、
  仕様の振る舞いが変わる

**Files likely to change**:

- `Sources/MediaViewerCore/FileSystem/FileSystemWatcher.swift`
- `Tests/MediaViewerCoreTests/FileSystemWatcherTests.swift`

**Tests to add or update**:

- 回帰テスト: `folders` だけで多くのフォルダ（例: 100）を監視し、作り直しを繰り返しても、プロセスの開いているディスクリプタ
  （`/dev/fd` の数）がほとんど増えない（例: 監視前から +20 未満）こと。修正前は +1,000 を超えて失敗する
- `subtrees` を1つ足しても、増えるディスクリプタが起点1つ分（WatchRoot の分）にとどまること
- 既存の `FileSystemWatcherTests` がすべて通ること（`folders` の追加・名前変更・削除の通知、`subtrees` の配下の通知、起点自身・親の
  削除と移動の通知、`/private` の扱い、最大の遅延）

## Risks & Considerations

- WatchRoot を外した `folders` は、監視しているフォルダ自身が移動・削除されたことを WatchRoot の通知（`RootChanged`）では受け取らない。
  ただし `handleEventPaths` は通知のパスの親が `folders` にあるかで判断しており、自身の移動は親フォルダの変更として届く（親が監視の
  対象のとき）。既存のテスト「folders だけなら自身は流さない」もこの振る舞いを前提にしている
- 2つのストリームは同じ `queue` で動くため、イベントの処理と debounce（`scheduleEmit`）は今と同じく直列になる
- `subtrees` は検索の起点1つ（実体のパスと渡された形の2パス）で、WatchRoot の分は 20 程度。検索中の作り直しは起点が変わるときだけになる
- 監視の対象の数そのものは変わらないため、FSEvents のイベントの量・遅延は変わらない

## Open Questions

- （解決）落ちたときにツリーで展開していたフォルダ: ユーザーへの聞き取りで「1〜3 個。その状態でフォルダの削除や名前の変更を
  繰り返した」。展開が少なくても、見えている行（例: ホームの直下の 20 前後のフォルダと、テスト用のフォルダ）はすべて監視の対象のため、
  25 パス × 約 11 ≈ 275 で、作り直しの重なりがなくても上限 256 を超えうる。削除・名前の変更のたびに監視を作り直すため、重なりで
  さらに増える。修正後の GUI の確認は、同じく 1〜3 個のフォルダを展開して削除・名前の変更を繰り返して行う
