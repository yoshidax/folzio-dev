# Quickstart: スライドショーのオプション設定の検証

**Date**: 2026-10-26 | **Branch**: `007-slideshow-options`

本書は実装後の検証ガイド。操作の正本は [contracts/slideshow-options.md](contracts/slideshow-options.md)、状態と遷移は [data-model.md](data-model.md)、受け入れ条件は [spec.md](spec.md) を参照する。006 のシナリオ（[006 の quickstart.md](../006-add-slideshow/quickstart.md)）は、既定値（間隔3秒・繰り返しオン・効果「なし」）で回帰確認として使う（A-54）。

## 前提

- macOS 15 以降、Swift 6 の開発環境、Instruments（OS Signposts／Points of Interest）。
- ネットワーク接続・外部パッケージは不要。
- GUI の起動と操作はユーザーが行う。エージェントは build・test・bundle の作成までを行い、起動コマンドと確認点を渡す。
- 設定は `.app` のドメイン `local.my-img-viewer.MediaViewer` に保存される。初回起動の状態から確かめる場合は、ユーザーの了承を得てから次で3キーだけを消す。

  ```bash
  defaults delete local.my-img-viewer.MediaViewer slideshow.intervalSeconds
  defaults delete local.my-img-viewer.MediaViewer slideshow.repeats
  defaults delete local.my-img-viewer.MediaViewer slideshow.transition
  ```

## 検証データ

既存の `slideshow/` セット（006）に加え、実装工程で `FixtureSets.slideshow(in:)` に次の1フォルダを追加する予定。

| 生成先以下 | 内容／用途 |
|---|---|
| `slideshow/transitions/` | 表示順が分かる5件: `01-image.jpg`・`02-video-1s.mp4`・`03-broken.jpg`（破損）・`04-image.png`・`05-video-10s.mov`。US12-AS5（5件の3件目から開始）、効果の画像・動画・エラー表示の組み合わせ |
| 既存 `slideshow/mixed/`・`slideshow/single/`・`slideshow/slides.zip`・`slideshow/search/` | 間隔・繰り返しの通常フォルダ・zip・検索結果での確認（SC-040）、対象1件（EC-66） |

```bash
cd /Users/igachan/projects/my_img_viewer
scripts/make-fixtures.sh ~/MediaViewerFixtures
```

## 自動検証と起動ゲート

実装 Phase の終わりに次の順で行う。build/test の失敗を3回直しても解決しない場合は止めて報告する。

```bash
cd /Users/igachan/projects/my_img_viewer
swift build
swift test --filter MediaViewerCoreTests
swift test --filter MediaViewerPerformanceTests
scripts/check-no-network.sh
scripts/make-app.sh
```

成功後、ユーザーに次を実行してもらい、3ペインが表示されることを最初に確かめる。起動しない場合は推測で直さず、AGENTS.md の lldb による Objective-C 例外の停止手順をユーザーへ依頼する。

```bash
open .build/MediaViewer.app
```

自動テストで確かめる内容:

| テスト領域 | 確認する条件 | 対応 |
|---|---|---|
| SlideshowIntervalInput | `10`・`１５`・` 15 `・`007`・`1`・`3600` を受け付け、空・`0`・`-1`・`+5`・`2.5`・`abc`・`1,000`・`3601`・桁あふれを拒否 | US12-AS3・AS4、EC-74、SC-039 |
| SettingsStore.slideshow | 未保存で 3／オン／なし。往復で同じ値（1・3600 を含む）。不正な型・範囲（`0`・`3601`・`3.5`・`true`・文字列・未知の効果名・Bool でない繰り返し）は該当項目だけ既定値 | US12-AS1・AS8、EC-75、SC-039 |
| SlideshowSession | 間隔 1／3／10 秒で期限前0回・期限で1回。予定済みの期限は新しい間隔で変わらず、その次から新しい間隔。矢印による待機中に変えても期限は不変 | US12-AS2・AS9、FR-132、SC-038 |
| SlideshowSequence.advance | 繰り返しオン／オフ × 末尾・途中・1件・フォーカスなし・0件。一覧の更新で末尾になる／でなくなる。実行中に繰り返しを切り替える。通常フォルダ・zip・検索結果相当の一覧 | US12-AS5〜AS7、EC-66・EC-76・EC-77、SC-040 |
| SlideshowTransitionEffect | 視差効果を減らす がオンで slide・zoom → crossfade、none・crossfade は不変 | US13-AS7 |
| SlideshowTransitionState | idle → holding → animating → idle の遷移。対象が現在の表示と同じ URL、または効果が none の arm では holding にならない。準備中の表示では待ち、holding で対象の再表示が届いたら準備完了を判定し直す。対象以外の表示（holding・animating のどちらでも）・cancel・コンテナの大きさの変更で打ち切る。animating での対象の再表示・準備完了は無視する。古い世代の completion・準備完了を無視する。`PreviewContent` ごとの準備完了の判定 | FR-130・FR-131、EC-66・EC-80、US13-AS5・AS6・AS8 |
| フィクスチャ | `slideshow/transitions/` の5件と表示順 | 検証データ |

## 手動シナリオ

### 設定ウインドウ（US12-AS1・AS3・AS4・AS8、EC-73、SC-039・SC-042）

1. 初回状態で ⌘, を開く。「動画」「ファイル操作」の下に「スライドショー」があり、間隔 `3`・「秒」、繰り返しオン、効果「なし」と表示される。
2. システム設定の「キーボードナビゲーション」をオフにした状態で、Tab を押し続ける。動画の2項目 → 確認 → 間隔 → 繰り返し → 効果 → 先頭の順にフォーカスが移る。⇧Tab で逆順になる。オンにして同じ確認を行う。
3. 繰り返しで Space を押してオン／オフが切り替わる。効果で Space を押してメニューが開き、矢印キーと Return で選べる。
4. 間隔を `5` にして Return。続けて `0`・`-1`・`2.5`・`abc`・`3601`・空欄・`+5`・`1,000` をそれぞれ入力して Return・Tab で確定する。毎回 `5` に戻り、警告のダイアログや警告音は出ない。
5. `１５`・` 15 `・`007` を確定すると、それぞれ `15`・`15`・`7` と表示される。
6. 間隔に `20` と入力して Esc。`7`（直前の有効値）に戻り、ウインドウは閉じない。`20` と入力したまま閉じるボタンで閉じ、開き直すと `20` になっている。`abc` のまま閉じた場合は `20` のまま。
7. 3項目を既定値から変えてアプリを終了し、起動し直す。設定ウインドウとスライドショーの振る舞いに変えた値が使われる。
8. VoiceOver をオンにし、3項目が「切り替え間隔（秒）」「最後まで表示したら先頭から繰り返す」「切り替え効果」と読み上げられる。

### 間隔と繰り返し（US12-AS2・AS5〜AS7・AS9、EC-66・EC-76・EC-77、SC-040）

1. 間隔 `10` で `slideshow/mixed` を開始する。10秒ごとに次へ進み、矢印で割り込むと最後の押下から10秒後に次へ進む。
2. 間隔 `5` で実行中に設定ウインドウを開き、`2` に変えて確定する。次の切り替えは元の時刻で行われ、その次から2秒ごとに進む。スライドショーは終了しない。設定ウインドウでの Esc でもスライドショーは終了しない。
3. 繰り返しをオフにして `slideshow/transitions` の3件目を選び、開始する。3・4・5件目を表示し、5件目から設定した間隔の後に終了する。表示は Esc の終了と同じ（開始前のペイン表示へ戻り、5件目の選択を保つ）。全画面から開始した場合は全画面も解除される。
4. 繰り返しオフで末尾を表示中に ↑ で1件戻って待つ。末尾へ進み、そこから間隔の後に終了する。末尾で ↓ を押した場合は、最後の押下から間隔の後に終了する。
5. 繰り返しオンで同じ一覧を2周確認し、末尾から先頭へ戻って続く。
6. 実行中に繰り返しをオフへ変える。末尾を表示中に変えた場合は、次の予定時刻に先頭へ戻らず終了する。
7. 繰り返しオフで、`slideshow/slides.zip` のルートと、`search` の検索結果でも途中から開始して末尾で終了する。先頭へ戻らない。
8. `slideshow/single` で、繰り返しオンなら同じ動画を再生し直さずに続き、繰り返しオフなら開始から間隔の後に終了する。
9. 繰り返しオフで実行中に、Finder で現在のメディアより後ろのファイルを削除して、現在のメディアを末尾にする。次の予定時刻に終了する。

### 切り替え効果（US13-AS1〜AS8、EC-66・EC-67・EC-78〜EC-80、SC-041）

`slideshow/transitions` を、効果ごとに間隔 `3` で2周以上見る。

1. 「なし」: 006 と同じく即座に切り替わる。
2. 「クロスフェード」: 前が薄れながら次が現れ、約0.5秒で次だけになる。
3. 「スライド」: 次が右から入り、前が左へ押し出される。末尾 → 先頭でも同じ向き。
4. 「ズーム」: 前が薄れる間に、次が中央から拡大して等倍で止まる。
5. 各効果で、動画（`05-video-10s.mov`）の再生中に次へ送られるとき、前の映像が止まり音声も止まった状態で効果が行われる。次が動画なら、効果の途中から自動再生・ループの設定どおりに再生され、効果の途中に黒い（空の）表示が見えない。
6. 各効果で、破損ファイル（`03-broken.jpg`）のエラー表示への切り替えと、エラー表示からの切り替えにも効果が付く。
7. 効果の途中で ↓・Esc・⌃⌘F を押す。どれも効果の完了を待たずに反映される（矢印は選び直したメディアを即座に表示、Esc は終了と復帰、全画面は次のメディアをそのまま表示して実行を続ける）。効果の途中に画像をダブルクリックした場合も全画面が切り替わる（クリックが下のプレビューへ届く）。VoiceOver がオンでも、効果の表示が読み上げの要素として現れない。
8. 「なし」以外の効果で、矢印による選び直しと開始時の最初の表示・終了時の復帰には効果が付かない。スライドショーを使わずにファイルリストで選択を変えても効果は付かない。
9. システム設定 → アクセシビリティ → ディスプレイ → 「視差効果を減らす」をオンにする。「スライド」「ズーム」はクロスフェードで表示され、設定ウインドウの表示は「スライド」「ズーム」のまま。
10. 効果の途中でウインドウの大きさを変える。効果は打ち切られ、次の切り替えの時刻は遅れない。
11. 間隔 `1` の「ズーム」で1周見て、効果が次の切り替えに重ならない。
12. `slideshow/single` で繰り返しオン・「クロスフェード」（ほかの効果でも同じ）にして開始し、間隔を3回以上待つ。動画は止まらず先頭からも再生し直されず、切り替え間隔ごとに前の表示の写しが一瞬重なる（ちらつく）こともない（EC-66、FR-119）。
13. 「なし」以外の効果で、前の表示が保たれている準備待ちの間（例: `04-image.png` から `05-video-10s.mov` への切り替えで、動画の最初のフレームが出る前）、または効果の途中に操作する。↓ では、表示中の前のメディアではなく、ファイルリストで選択中のメディア（次の対象）の次が即座に表示される。Esc では終了し、選択中のメディア（次の対象）の選択が保たれる（EC-80）。準備待ちが短すぎて手で押せない場合は、効果の途中での確認と、準備待ちを目視できなかったことを記録する。

## 実時間の計測（SC-038・SC-041）

既存の `OSSignposter`（`local.my-img-viewer.MediaViewer` / `Performance`）に、実装工程で `SlideshowTransitionBegin`・`SlideshowTransitionStart`・`SlideshowTransitionEnd`・`SlideshowTransitionCancel` を加える。パス・名前は含めない。

1. Instruments で `.build/MediaViewer.app` を記録する（ユーザーが操作する）。
2. 間隔 1／3／10 秒それぞれで、事前に表示可能な静止画（`slideshow/mixed` の 01〜03 を種類フィルタ「画像のみ」で）を連続10回送る。`SlideshowAdvance` の間隔がすべて設定値〜設定値＋0.2秒に入る。4種類の効果で繰り返す。
3. 矢印を受理させ、最後の `SlideshowArrow` から次の `SlideshowAdvance` までが同じ時間枠に入る。
4. 「なし」以外の各効果で20回、`SlideshowTransitionStart` から `SlideshowTransitionEnd` までがすべて0.7秒以内。
5. 既存の性能基準（先読み済みの切り替え100ms、動画の開始1秒など）が、video output の追加後も満たされる（[research.md の R7](research.md#r7--前の表示の-snapshot) の Risks）。

記録には環境（macOS、機種、build 種別）、間隔ごとの最小・最大・範囲外の件数、効果の所要時間の最大を含める。未実施の項目を PASS としない。結果欄は、tasks で明示した本書への追記タスクで加える。

## 完了の扱い

build・全自動テスト・no-network・bundle の作成・ユーザーによる3ペインの起動スモークと該当する GUI シナリオ・実時間の計測が揃って完了とする。GUI 未確認のタスクは未チェックのまま残す。問題のない実装 Phase をコミットし、最後に spec の「反映先」の表に従って `specs/product/` へ反映する（006 の反映より先には反映しない）。

## Phase 検証記録

実装は worktree（`agent/<task-id>-<slug>`）で行い、`007-slideshow-options` へ `git merge --no-ff` で統合した。各マージ後に `swift build` と `swift test` を実行した。

### Phase 1・2（T004・T010、2026-10-26）

| 項目 | 結果 |
|---|---|
| 統合 | `agent/T001-transitions-fixture`（452941d）、`agent/T007-slideshow-settings`（b86f7f2） |
| `swift build` | 成功 |
| `swift test --filter MediaViewerCoreTests` | 654 件成功 |
| `swift test --filter MediaViewerPerformanceTests` | 23 件成功 |
| `swift test`（2 target 同時） | 1 回目: `PerformanceBaseline` の「50,000 件への 256 件のバッチ」と `FileNameSearcher` の「ストリームを集める Task を取り消すと、列挙が止まる」が失敗。2 回目: 後者だけ失敗。どちらも本 feature の変更と無関係なファイルで、target ごとの実行では成功する。2 target の同時実行による負荷で時間に依存するテストが揺れていると判断 |
| `scripts/check-no-network.sh` | 成功（No network API references in Sources） |
| `scripts/make-app.sh` | 成功（`.build/MediaViewer.app` を作成） |
| T003 `scripts/make-fixtures.sh .build/SlideshowFixtures` | 未実施（エージェント環境でスクリプトの実行が承認されなかった）。生成内容は `SlideshowFixtureTests` の「transitions は表示順が分かる5件…」で確認済み |
| GUI（T005・T011） | 未実施。GUI を起動しない指示のため |

### Phase 1・2 引き継ぎ後の再検証（T003・T004・T010、2026-10-26）

Claude Code の利用上限による中断後、Codex の対話セッションで再開した。
Phase 1・2 のソースは統合済み。`agent/T016-interval-input` の worktree にある間隔入力の未コミットのソース・テストは保持し、まだ統合していない。

Phase 2 の `SlideshowOptions.intervalSeconds` が初期化後の代入で範囲外の値を持てたため、代入時も範囲外なら既定値3にするよう補完した。
回帰テストが修正前に失敗することを確認し、修正後は全テストが成功した。
繰り返し設定の不正値の検証にも `"yes"` と整数 `1` を追加した。

| 項目 | 結果 |
|---|---|
| T003 `scripts/make-fixtures.sh .build/SlideshowFixtures` | 成功。`ls -lh .build/SlideshowFixtures/slideshow/transitions` で指定の5件を確認。外部ツールの追加導入なし |
| `swift build` | 成功 |
| `swift test` | 成功。Core 655件・性能23件（計678件）。前回の記録で失敗したテストも今回は成功 |
| `scripts/check-no-network.sh` | 成功（no network API references in Sources） |
| `scripts/make-app.sh` | 成功。最新の `.build/MediaViewer.app` を作成 |
| 実行環境 | 通常の sandbox 内では Swift の module cache への書き込みと manifest の sandbox 起動が拒否されたため、承認付き実行で検証した |
| GUI（T005・T011） | ユーザー確認待ち。3ペイン、既存の3秒循環・Esc、既存の設定3項目の表示と保存を確認する |
| Phase 完了・コミット（T006・T012） | GUI 未確認のため未完了。Phase 3 は未着手のまま保持 |

### Phase 1 GUI 確認（T005・T006、2026-10-26）

ユーザーから「確認し問題はありませんでした」と報告を受けた。最新の `.build/MediaViewer.app` で3ペインの表示、`slideshow/mixed` の ⇧⌘S による3秒ごとの循環、Esc による終了を確認済み。T003・T004 と合わせて Phase 1 のゲート合格とし、引き継ぎ後のフィクスチャ生成と確認記録をコミットする。

### Phase 2 GUI 確認（T011・T012、2026-10-26）

同じユーザー報告で、3ペインの表示と既存の設定ウインドウ（⌘,）の3項目の表示・変更の保存に問題がないことを確認した。範囲外の間隔の代入を補完した実装と回帰テスト、T010 の再検証結果に対して GUI ゲートも合格とし、Phase 2 の変更をコミットして Phase 3 へ進む。上の引き継ぎ時点の「確認待ち」「未完了」の記録は本確認で解消した。

### Phase 3 自動検証（T013〜T022、2026-10-26）

中断した `agent/T016-interval-input` の worktree の間隔解析とテストを読み、テストから順に現在のブランチへ取り込んだ。元の worktree のファイルは保持している。可変間隔の Session、最新一覧での繰り返し／末尾終了判定、設定の都度読み取り、間隔と繰り返しの設定 UI を実装した。設定画面では Tab 順を明示し、Return・フォーカス移動・ウインドウを閉じる操作で確定、編集中の Esc で取り消す。切り替え効果は Phase 4 で追加する。

| 項目 | 結果 |
|---|---|
| テスト先行 | 間隔解析のテストは `SlideshowIntervalInput` 未定義で失敗し、取り込み後は Session の新引数・Sequence の `advance` の未実装で失敗することを確認した |
| `swift test --filter Slideshow` | 成功。関連40テスト。新しいテストの Swift Testing の mutating 呼び出しの記法と Duration の負値の記法を修正した後に成功 |
| `swift build` | 成功。設定 UI と Coordinator の接続を含む |
| `swift test`（初回） | 性能23件成功。Core 663件中、既存の検索キャンセルテスト（`FileNameSearcherTests.cancellationStopsEnumeration`）のみ失敗。`countAtCancel` が10,000となり `< 10_000` の期待を満たさなかった。Phase 1・2 の最初の記録にも同じテストの失敗がある |
| `swift test`（再実行） | ソースを変更せず同じ全テストを再実行し、Core 663件・性能23件（計686件）が成功 |
| `scripts/check-no-network.sh` | 成功（no network API references in Sources） |
| `scripts/make-app.sh` | 成功。最新の `.build/MediaViewer.app` を作成 |
| GUI（T023） | 未実施。3ペイン、設定ウインドウ1・2・4〜7（効果を除く）、間隔と繰り返し1〜9をユーザーに依頼する |
| Phase 3 コミット（T024） | GUI 確認待ちのため未実施。Phase 4 へはまだ進まない |

検証データは引き継ぎ時に生成した `.build/SlideshowFixtures/slideshow/` をそのまま利用できる。GUI 確認では、アプリを一度終了してから `open .build/MediaViewer.app` で最新の bundle を起動する。

### Phase 3 GUI 確認（T023・T024、2026-10-26）

ユーザーから Phase 3 の確認完了・問題なしとの報告を受けた。設定ウインドウ1・2・4〜7（効果を除く）、間隔と繰り返し1〜9のゲートを合格とし、Phase 3 をコミットして Phase 4 へ進む。
