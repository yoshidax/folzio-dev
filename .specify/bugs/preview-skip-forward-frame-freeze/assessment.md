# Bug Assessment: 短い動画で 15 秒スキップすると映像フレームが止まる

- **Slug**: preview-skip-forward-frame-freeze
- **Created**: 2026-10-24
- **Source**: pasted text（＋ assess 中のユーザーへの聞き取り）
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

> プレビュービューで動作再生時にメディアプレイヤー内の15秒先送り、後戻りそれぞれのボタンを押すとシークバーは反応するが
> 動画の再生フレームがその時点で止まったまま復旧できない。

assess 中の聞き取りで分かったこと:

- 通常のフォルダの動画でも zip の中の動画でも起きる
- 5 秒の動画などで起きやすい。15 秒未満の動画で起きているように見える
- 5 秒の動画で 15 秒進めると、シークバーは 0 秒へ移動する。映像は止まったように見えるが、シークバーと再生時刻は進み続ける。
  終端まで進んで先頭から再生し直すと、映像は正常に動き出す
- 設定の「ループ再生」は既定（オン）のまま
- 音声は無音の動画しかないため不明
- `<` / `>` のショートカットキーは、そもそも効かない（下の「仕様との照合」と「Open Questions」を参照）
- ループ再生をオフにすると、15 秒スキップで映像は止まらない（終端で再生が止まる。US2-AS3 どおり）
- フルスクリーン表示中に `>` / `<`（±5 秒）で終端・先頭を越えても、映像は止まらない

## Symptom

ループ再生（既定）で動画の長さより短い区間しか残っていない状態で、AVPlayerView のインラインコントロールにある
15 秒スキップ（進む・戻る）を押すと、シークバーと再生時刻は動き続けるのに、映像のフレームがその時点で止まる。
次のループ（先頭からの再生）に入るまで映像が戻らない。期待する動作は、スキップ先から映像も続けて再生されること。

## 仕様との照合

- **FR-033** / **US2-AS5**: 動画プレビューは画面上のコントロールでシークできなければならない。シーク後に映像が止まるのは
  この要件を満たしていない
- **FR-031** / **US2-AS1**: 既定でループ再生する。不具合はループ再生（`AVPlayerLooper`）の経路で起きている
- `<` / `>` キーについて: FR-033 は `<` / `>` によるシークを「フルスクリーン表示中」の操作として定めている。実装も
  フルスクリーン中（`navigatesHiddenFileList`）だけでキーを処理している（`MainSplitViewController.swift:530-533`）。
  3ペイン表示で `<` / `>` が効かないのは仕様どおりで、本バグの対象外とする。3ペイン表示でも効かせたい場合は、
  仕様の変更として sdd-increment で扱う

**判定**: 実装が仕様（FR-033）に反している → fix へ進む

## Reproduction

1. 5 秒程度の動画（mp4 / mov）を含むフォルダを開く（設定は既定: 自動再生オン・ループ再生オン）
2. ファイルリストでその動画を選び、プレビューで再生させる
3. プレビュー下部のコントロールで「15 秒進む」を押す
4. シークバーは 0 秒付近へ移り、その後も進むが、映像は押した時点のフレームのまま止まる
5. 再生が終端に達して次のループに入ると、映像が動き出す
6. 「15 秒戻る」でも同様に映像が止まる（ユーザー報告）

- 15 秒以上の長い動画で残りが 15 秒以上ある位置からのスキップでは起きにくい（ユーザー報告からの推定）
- ループ再生をオフにすると起きない（ユーザー確認済み）
- フルスクリーン中の `>` / `<`（アプリ独自の `seek(by:)`）で終端・先頭を越えても起きない（ユーザー確認済み）

## Suspected Code Paths

- `Sources/MediaViewerApp/Preview/VideoPreviewView.swift:45-61` — ループ再生を `AVQueuePlayer` ＋ `AVPlayerLooper` で
  実装している。`AVPlayerLooper` はテンプレートの複製アイテムをキューに複数入れ、終端に達するたびに次のアイテムへ
  切り替える。終端を越えるシーク（5 秒の動画で +15 秒）は、その場で「終端に到達 → 次の複製アイテムへ切り替え」を
  起こす。ユーザーの観察（シークバーが 0 秒へ移る）はこの切り替えと一致する
- `Sources/MediaViewerApp/Preview/VideoPreviewView.swift:157` — `controlsStyle = .inline`。15 秒スキップのボタンは
  AVPlayerView 標準のもので、アプリ側でシーク量や範囲を制御していない
- `Sources/MediaViewerApp/Preview/VideoPreviewView.swift:116-132` — `seek(by:)`（フルスクリーン中の `<` / `>`）は
  目標を `[0, duration]` に丸めて誤差ゼロでシークする。この経路では映像は止まらない（ユーザー確認済み）。
  終端ちょうどへのシークによるアイテム切り替えだけでは症状は出ないことになり、AVPlayerView 標準のスキップ操作と
  `AVPlayerLooper` のキューの組み合わせが引き金と考えられる
- `Sources/MediaViewerApp/Preview/PreviewViewController.swift:176-197` — 通常ファイルと zip の動画はどちらも
  `VideoPreviewView.configure` に入る。zip の読み込み（`ArchiveAssetLoader`）は両方で起きるという報告から
  原因ではないと判断する

## Root Cause Hypothesis

ループ再生の経路（`AVQueuePlayer` ＋ `AVPlayerLooper`）で、AVPlayerView 標準の 15 秒スキップが動画の長さを越える
（または先頭より前へ戻る）と、AVPlayerView の描画層（`AVPlayerLayer`）が新しい位置のフレームを表示せず、直前の
フレームを出し続ける。時刻とシークバーはプレイヤーに従って進むため「シークバーは動くが映像は止まる」状態になり、
次の自然なループ（複製アイテムへの切り替え）で描画が戻る。

確信度: 原因が `AVPlayerLooper` の経路にあることは **high**、AVPlayerView 内部で何が起きているかは **low**。

- ループ再生をオンにしたときだけ起き、オフ（`AVQueuePlayer` に1つのアイテムだけを入れる経路）では起きない。
  コード上の違いは `AVPlayerLooper` の有無だけである
- 15 秒未満の動画で起きやすく、+15 秒でシークバーが 0 秒へ移り（次の複製アイテムへの切り替え）、次のループで
  回復する
- 通常ファイルと zip の両方で起きるため、`ArchiveAssetLoader` は関係しない
- アプリ独自の `seek(by:)`（`[0, duration]` に丸めて誤差ゼロでシーク）では、終端・先頭を越えても起きない。
  終端でのアイテム切り替えそのものではなく、AVPlayerView のスキップ操作（丸めない目標時刻、または内部の
  シーク手順）と `AVPlayerLooper` のキューの組み合わせが引き金と考えられる
- スクラッチの実験（`AVQueuePlayer` ＋ `AVPlayerLooper`、5 秒・60 秒の動画、`seek(to:)` の既定許容誤差と誤差ゼロ、
  丸めない目標時刻）では、`AVPlayerItemVideoOutput` で取ったフレームは ±15 秒シーク後も時刻に追従して更新された。
  デコードとアイテムの進行は正常で、問題は描画側にある。AVPlayerView のスキップボタンの内部処理は公開されておらず、
  これ以上は特定できない

## Proposed Remediation

**Preferred**: ループ再生を `AVPlayerLooper` から「単一の `AVPlayer` ＋ 終端通知で先頭へ戻す」方式に置き換える。

- `AVQueuePlayer` / `AVPlayerLooper` をやめ、`AVPlayer(playerItem:)` に1つのアイテムだけを持たせる
- ループ時は `actionAtItemEnd = .none` にし、`AVPlayerItem.didPlayToEndTimeNotification` で
  `seek(to: .zero)` → 再生を続ける。ループしないときは今と同じく終端で `pause()` する
- アイテムが切り替わらないため、終端を越えるスキップは「終端到達 → 同じアイテムの先頭へ戻る」になり、
  描画層が古いフレームを持ち続ける状況を作らない
- `seek(by:)` は `player.currentItem` が常に同じアイテムになり、今の丸め処理のまま使える
- 再生開始の計測（`VideoPlaybackStart` のサインポスト）、`stop()` の後始末、FR-037（フルスクリーン切替で位置と状態を維持）
  は今の構造のまま保てる

**Alternatives**:

- `AVPlayerLooper` を残し、`player.currentItem` の変化を KVO で監視して `playerView.player` を付け直す
  （描画層を作り直す）。変更は小さいが、OS 内部の不具合を回避する対症療法で、付け直しの瞬間にちらつく恐れがある
- AVPlayerView の標準コントロールのスキップを使わせない（独自コントロール）。macOS の AVPlayerView に
  スキップボタンだけを隠す公開 API がなく、コントロール全体の自作になるため割に合わない

ループの継ぎ目について: `AVPlayerLooper` は継ぎ目のないループ（gapless）を作るが、終端通知で先頭へ戻す方式では
ループの境目に一瞬の間ができることがある。FR-031 / US2-AS1 は「先頭から繰り返し再生される」ことだけを求めており、
継ぎ目のなさは要件にない。

**Files likely to change**:

- `Sources/MediaViewerApp/Preview/VideoPreviewView.swift`
- ループ・シークの判断を Core へ切り出す場合: `Sources/MediaViewerCore/`（例: 動画のシーク先とループ時の
  巻き戻し判定）と `Tests/MediaViewerCoreTests/`

**Tests to add or update**:

- Core に、シーク先の計算（現在位置 ± 秒数を `[0, duration]` に丸める、終端を越えた場合の扱い）を純粋関数として
  切り出し、短い動画（5 秒）で +15 秒・−15 秒・+5 秒（終端ちょうど）の境界値を確かめるテスト
- AVFoundation を使う回帰テスト（Core 側、AppKit なし）: `FixtureKit` で 5 秒の動画を作り、ループ設定の
  プレイヤーで +15 秒シークした後もプレイヤーのアイテムが同じで、時刻が先頭側から進み続けること。
  再生のタイミングに依存するため、待ち時間に余裕を持たせる
- 描画が止まらないことは単体テストで確かめられない。GUI での確認（5 秒の動画で 15 秒進む・戻るを押し、
  映像が動き続けること）を `/speckit-bug-test` で必ず行う

## Risks & Considerations

- ループの継ぎ目に一瞬の間や先頭フレームの表示の遅れが出る可能性がある（短い動画ほど目立つ）
- 終端通知とユーザー操作（一時停止・シーク）が重なったときに、一時停止中の動画を勝手に再生しないよう、
  先頭へ戻したあとの再生は「その時点で再生中だった場合だけ」にする
- `stop()` での通知の解除漏れがあると、別ファイルへ切り替えた後に古い通知で巻き戻しが走る（FR-034）。
  今の `playbackGeneration` と同じ考え方で古い通知を無視する
- zip の中の動画（`ArchiveAssetLoader`）は先頭へのシークで先頭付近のデータを読み直す。圧縮して格納された動画は
  シークが遅くなることがある（A-26）。SC-014 のメモリ基準には影響しない見込み
- AVPlayerView 内部の仕組みは特定できていないため、fix 後に GUI で「15 秒進む・戻る」を確認するまで解決とはしない

## Open Questions

- [NEEDS CLARIFICATION: 3ペイン表示でも `<` / `>` でシークできるようにしたいか。したい場合は本バグとは別に、
  FR-033 の変更として sdd-increment で扱う]
