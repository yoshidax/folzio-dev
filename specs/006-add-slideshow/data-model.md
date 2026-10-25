# Data Model: スライドショー

**Date**: 2026-10-25 | **Spec**: [spec.md](spec.md)

以下は設計上の型と責務。実装時の名前は対応関係を保った上で調整可能。Core の型は AppKit 非依存とする。

## 1. 対象列 — SlideshowSequence（Core）

| 入力・値 | 型の方針 | 規則 |
|---|---|---|
| visibleFiles | `[MediaFile]` | `BrowserModel.listing.files` 全体。順序を保つ |
| candidates | メディア URL の列 | `kind.isMedia` の項目だけ。都度導出し、開始時の固定列を正本にしない |
| selected | `Set<URL>` | 既存 `SelectionState.selected` |
| focused | `URL?` | 既存 `SelectionState.focused`。現在位置の正本 |

識別は `MediaFile.id == url`。通常ファイルは完全な場所、zip は既存 `ArchiveURL` の archive と内部 path の組。名前・行番号・デコード結果を識別に使わない。メディア本体のデータを対象列へ保持しない。

**Operations**:

- `startTarget`: 選択集合に含まれ対象列にもある focused → selected と candidates の共通部分の表示順先頭 → candidates.first。空なら nil。
- `nextTarget`: 最新 focused が候補にあればその次（末尾なら先頭）、なければ先頭。空なら nil。
- 返った URL が現在の有効な単一選択と同じなら再ロードせず表示を維持する。現在位置を独立した古い index に保存しない。

**Validation**: フォルダ・zip 自体・zip 内ディレクトリ・親リンクを含めない。表示不可エンコード等も kind がメディアなら候補に残す。通常の並べ替え／種類フィルタを作り直さない。

## 2. 実行状態 — SlideshowSession（Core）

| フィールド | 型の方針 | 制約 |
|---|---|---|
| phase | `idle / running / waitingAfterArrow` | waiting は最後の矢印からの3秒待ち。専用一時停止機能ではない |
| interval | `Duration` | 常に3秒。変更・永続化しない |
| deadline | 単調時刻の Instant、または nil | active のとき1つ。idle は nil |
| generation | 単調増加 token | 開始・再設定・終了で古い待機と pending due を無効化 |
| pendingDue | generation と deadline の組、または nil | timeout 到来後、選択確定前の保留。最大1つ |

時刻は呼び出し側から入力する。Core 自身は sleep せず、App は `ContinuousClock` と同じ時刻軸を使う。テストでは任意の now を与える。現在メディアは BrowserModel の選択から導出し、二重に所有しない。

### 状態遷移

| 状態 | 入力 | 出力／次の状態 |
|---|---|---|
| idle | 開始条件を満たす start(now) | 開始対象を1件に整理し running。deadline = now + 3秒、新世代 |
| idle | 無効な start / 古い timeout / stop | 状態・選択・表示を変えない |
| active | 再度 start | 何もしない。選択と deadline 不変 |
| active | 修飾キーなし矢印(now) | 古い待機と pending を無効化後、既存規則で手動移動。deadline = now + 3秒、waitingAfterArrow |
| active | 現世代の timeout、now < deadline | 送らない。既存 deadline を維持 |
| active | 現世代の timeout、now >= deadline | pendingDue に置く。まだ選択は変えない |
| active | pending の commit、世代有効 | 最新候補と選択から最大1回送る。running、deadline = commit 時刻 + 3秒 |
| active | 候補1件かつ同一対象の commit | select/load を呼ばず維持。running、次の3秒へ |
| active | 一覧・設定更新、候補あり | 既存の選択整理に従う。phase・deadline を変えない |
| active | 候補0件 | stop と表示復帰。空選択を補完しない |
| active | 全画面 enter / exit | 実行・pending・deadline を変えない |
| active | シート／アプリモーダルの開閉、編集開始／終了 | phase・pending・deadline 不変。自動送りを継続 |
| active | FR-123 の条件外の Esc／矢印 | App が既存入力先へ渡し、Core の stop／arrow 入力にしない。選択・phase・deadline 不変（自動送りや既存編集の結果は別） |
| active | FR-123 の条件で受理した Esc / 閲覧先置換 / 消失 / close / quit | deadline と pending を破棄し世代更新、idle。必要な表示復帰のみ |

**同時入力**: 同じ調停単位では stop > arrow > due。Esc／矢印は FR-123 の条件で受理した入力だけを対象とする。timeout を保留してから入力を受理した場合も無効化する。due→arrow→commit／arrow→due→commit と、Esc の両順序で同じ結果にする。モーダル／編集のキーは pending due を無効化せず、モーダルを閉じた同じキーを再適用しない。実装で選択を確定済みの過去の送りを巻き戻す方式は採らない。

App の commit adapter は現在イベント後に1件だけ予約し、直前の非 dequeue のキー照会で FR-123 の条件を満たす未処理の Esc／矢印があれば延期する。条件外のキーで pending due を無効化したり期限を変えたりしない。callback の取消も generation で判定する。具体的な標準 API と mode は [research.md の R3](research.md#r3--単発-deadline-と手動入力の優先) を参照する。

**遅延**: deadline を大幅に過ぎても1回だけ処理し、過ぎた周期の数をループで消化しない。画像デコード・動画終端・Space・シーク・音量・形式変更・追加結果は deadline を更新しない。

## 3. UI 復帰値 — SlideshowRestoreState（App 所有）

| フィールド | 型の方針 | 規則 |
|---|---|---|
| normalPaneLayout | 既存 `PaneLayout` | 開始前の通常ウィンドウの表示。全画面からなら全画面化前 |
| normalFocusedPane | 既存 `Pane?` | 復帰後に表示される開始前ペインへフォーカスを戻す |
| threePaneWidths | `[Double]`、3要素 | tree / list / preview。既存 saved widths を継承し、有限・正値を検証 |
| presentationGeneration | token | 遅れて届く復帰 callback が新しい表示を上書きしないための照合 |

window frame、開始前の選択、閲覧先、ソート／フィルタ／形式のコピーは復帰値に含めない。ユーザーの現在状態を戻さないためである。Focus が取得できない場合は復帰先で表示する既存の有効な focus view を使う。

UI lifecycle は `idle → active → restoring → idle`。Core session は restoring に入る前に停止する。restoring はネイティブ全画面解除等を待つだけで、送りは0件。終了は冪等にし、復帰完了まで再入を防ぐ。close／quit では復帰アニメーションを待たず資源を破棄する。

### 復帰の規則

1. deadline・pending・待機 Task を取り消す。
2. 通常 layout の復帰を確定する。全画面なら解除を要求し、その通知後に幅・focus を最終適用する。途中通知が実行を再開したりスナップショットを上書きしたりしない。
3. 現在の有効な選択だけを保つ。通常 preview-only 進入の選択補完と開始前選択の復元は行わない。
4. 3ペインは既存 `PaneWidths.dividerPositions` と minimumThickness 160/240/320pt で収める。window frame は保持する。
5. 見えるリストでは必要最小限スクロールする。file-list-only への復帰は既存どおり動画を停止・消音する。その他の復帰では終了のみを理由に動画を止めない。

## 4. 手動移動基準 — 既存 HiddenListNavigation

App の `FileListViewController.HiddenListNavigation.width` をそのまま使う。リストを隠す直前に採取し、すでに preview-only／全画面なら既存値を引き継ぐ。列数はこの幅と**現在の**表示形式・サムネイルサイズから求める。preview 幅・全画面幅から取り直さない。

矢印の移動は候補だけに圧縮した列ではなく、既存の**全表示行**に `FocusNavigator` の規則を適用して非メディアを飛ばす。自動送りは候補列で循環し、手動送りは端で止まる。リスト形式の左右も timer は再設定するが選択は動かさない。

## 5. 開始可否とコマンド

開始可能 = 候補1件以上 AND session/復帰処理なし AND 名前の編集中でない AND モーダル表示中でない。読み込み中・検索中・全画面・toolbar 非表示は、それだけでは開始不可にしない。

`PaneCommands` に実行中の条件を加え、`canChangeLayout` と `canNavigateHistory` を false にする。新規開始の可否をメニュー検証・toolbar 更新・action 内の guard で共有する。既存の隠れたペインへの focus／検索制限は維持する。

**実行中の入力受理（U1）**: active AND 対象ウィンドウがキー入力先 AND 対象のシートなし AND アプリモーダルなし AND 編集欄・メニュー等がキーを処理していないこと。App が状態を取得し、Core の可否判断へは真偽値として渡す。monitor・hidden-list 入力・cancelOperation fallback が同じ判断を使う。復帰中や別ウィンドウへのキーは受理しない。モーダル中の時計は通常どおり進め、modalPanel mode でも due を commit する。モーダルの開閉は session のイベントや新しい停止状態に変換しない。

## 6. BrowserModel／履歴との関係

- `onWillReplaceLocation`（仮称）を `resetForNavigation` の変更前に同期通知する。App は送り取消と復帰状態の確定を済ませて返す。`onLocationEvent` は既存履歴用のまま。
- 一覧更新完了後の既存 selection restriction を先に行い、候補0件を観測して終了する。更新途中の一時値で選択補完や誤終了を起こさない。
- `navigationGeneration`／`previewGeneration` は既存非同期処理の採用判定。session generation と役割を分ける。古い reload も navigation 世代を照合する。
- rename で既存一覧が URL を付け替える場合は新しい selection を基準に継続し、旧 URL をスライドショー側で復活させない。
- `HistoryPresentation.paneLayout` は active／restoring 中に復帰先を返す。他の表示値は現在値。`HistoryEntry`・Settings に session を含めない。
- 検索結果中の履歴非記録と、検索解除時の現在履歴への反映は FR-113 を維持する。

## Persistence

全ての新規状態はメモリだけに保持し、window close／quit で破棄する。起動時は session idle・3ペイン表示。保存済みの通常設定だけを既存どおり復元し、スライドショーを自動再開しない。
