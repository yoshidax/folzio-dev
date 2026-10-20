# Quickstart: 3ペイン型メディアビューアの検証手順

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

機能が端から端まで動くことを確かめるための、実行と検証の手順。操作の割り当ては
[contracts/keyboard-and-menus.md](./contracts/keyboard-and-menus.md)、設定キーは
[contracts/settings.md](./contracts/settings.md)、バンドルとアイコンは
[contracts/app-bundle.md](./contracts/app-bundle.md) を参照。

## 前提条件

- macOS 15 以降、Apple Silicon または Intel の Mac
- Xcode（Swift 6 ツールチェーン付き）。`swift --version` で 6.0 以上であること
- ネットワーク接続は不要（原則 I）

## ビルドと自動テスト

```bash
swift build                                      # Core と App をビルド
swift test --filter MediaViewerCoreTests         # 単体・異常系テスト（原則 IV）
swift test --filter MediaViewerPerformanceTests  # 性能基準の計測（原則 II）。結果は PR に記載する
```

**期待結果**: すべてのテストが通る。性能テストは基準値（下の「性能の検証」）を超えると失敗する。

## 起動

```bash
swift run MediaViewerApp            # 開発中の起動（TCC の許可はターミナルに紐づく）
scripts/make-app.sh                 # .build/MediaViewer.app を組み立てて ad-hoc 署名する
open .build/MediaViewer.app
```

## アプリアイコンの検証（FR-043〜045、SC-011）

`swift run` はバンドルを持たないため標準アイコンになる。アイコンの確認は必ず `.app` で行う。

```bash
scripts/make-app.sh
test -f .build/MediaViewer.app/Contents/Resources/AppIcon.icns
plutil -extract CFBundleIconFile raw .build/MediaViewer.app/Contents/Info.plist
iconutil -c iconset .build/MediaViewer.app/Contents/Resources/AppIcon.icns -o /tmp/MediaViewer.iconset
sips -g pixelWidth -g pixelHeight /tmp/MediaViewer.iconset/icon_16x16.png
open .build/MediaViewer.app
```

**期待結果**:

- `plutil` が `AppIcon` を返し、`iconutil` が全スロットを展開できる（[contracts/app-bundle.md](./contracts/app-bundle.md)）
- `icon_16x16.png` が 16×16、`icon_512x512@2x.png` が 1024×1024 である
- Finder・Dock・⌘Tab・About に、汎用アイコンではなく3ペインをモチーフにした同じアイコンが出る
- 16px と 32px でも3ペインの図案が判別でき、ライト・ダークの両方の外観で同じアイコンが表示される
- アイコン生成に失敗した場合、`scripts/make-app.sh` は `.app` を残さず非ゼロで終了する

## 検証用フォルダの準備

```bash
scripts/make-fixtures.sh ~/MediaViewerFixtures
```

次のフォルダを生成する（自動テストのフィクスチャ生成と同じ処理を使う）。

| フォルダ | 内容 |
|----------|------|
| `mixed/` | JPEG・PNG・GIF（アニメーション）・WebP（静止とアニメーション）・mp4・mov・.txt・.pdf・サブフォルダ・隠しファイル |
| `broken/` | 破損 JPEG、中身が PNG の .jpg、0 バイトの .mp4 |
| `huge/` | 10,000 個の小さな JPEG |
| `bigimage/` | 1億画素級の PNG |
| `ops/` | ファイル操作の検証用。毎回作り直してよい |

## 手動の検証シナリオ

各シナリオは spec のユーザーストーリーに対応する。

### US1: フォルダを辿って画像をプレビューする
1. ツリーでホーム → `MediaViewerFixtures` → `mixed` を展開して選択する
2. **期待結果**: リストには画像4種と動画2種だけが並び、.txt・.pdf・サブフォルダ・隠しファイルは出ない
3. ↓ キーで順に選択を移す。**期待結果**: プレビューが追従し、画像は縦横比を保ってペインに収まる。
   小さな画像は拡大されない。アニメーション GIF は動く。アニメーション WebP は動くか、先頭フレームの
   静止画で表示される（どちらでも合格。エラー表示や空白になれば不合格）

### US2: 動画をプレビューで再生する
1. `mixed` の mp4 を選択する。**期待結果**: 自動で再生が始まり、終端で先頭に戻る
2. 設定（⌘,）で自動再生をオフにして mov を選択する。**期待結果**: 先頭フレームで止まっている
3. ループをオフにして再生する。**期待結果**: 終端で止まる
4. 再生中に画像を選択する。**期待結果**: 音声も含めて止まる

### US3: リスト形式とサムネイル形式を切り替える
1. ⌘1 / ⌘2 で切り替える。**期待結果**: 選択状態が維持される
2. リスト形式で「作成日」の見出しを2回クリックする。**期待結果**: 昇順 → 降順になる
3. サムネイル形式でサイズのスライダーを左右に動かし、ペイン幅も狭める。**期待結果**: 折り返しが追従し、
   横スクロールバーは一度も出ない
4. 終了して再起動する。**期待結果**: 表示形式・サムネイルサイズ・ペイン幅・最後のフォルダが戻る

### US4: Finder と同じ感覚でファイルを整理する（`ops/` で行う）
1. 確認 ON（既定）で ⌘C → 別フォルダ → ⌘V。**期待結果**: 確認が出て、OK で複製される。キャンセルでは何も変わらない
2. Return で名前を変更する。空・`a/b`・`.hidden`・既存の名前は拒否される。拡張子を変えると確認が出る
3. ⌘Delete。**期待結果**: Finder のゴミ箱に入り、「戻す」で復元できる
4. ファイルをツリーのフォルダにドロップすると移動、⌥ を押しながらだとコピーになる
5. 同名ファイルがある場所へコピーする。**期待結果**: 確認設定に関係なく「置き換える / 両方残す / 中止」が出る。
   「両方残す」で `名前 2.拡張子` ができる
6. 設定で確認をオフにして 1〜4 を繰り返す。**期待結果**: モーダルなしで実行される（衝突ダイアログだけは出る）

### US5: フルスクリーン
1. 画像を表示してプレビューをダブルクリックし、もう一度ダブルクリックする。**期待結果**: 全画面になり、
   元に戻る。ペイン幅と選択は元のまま
2. 動画の再生中に ⌃⌘F で全画面にし、Esc（または ⌃⌘F、表示メニュー）で戻る。**期待結果**: 再生位置は
   途切れない。動画上のダブルクリックは検証対象外

### US6: ペイン幅を調整する
1. 2本の仕切りをそれぞれ端までドラッグする。**期待結果**: 最小幅で止まり、どのペインも消えない

### キーボードだけで操作する（SC-009）
マウスに触れずに「Tab でツリー → フォルダを選択 → Tab でリスト → ファイルを選択 → ⌃⌘F → Esc」を完了できること。

### 異常系（SC-007）
`broken/` の全ファイルを順に選択する。**期待結果**: アプリは落ちず、プレビューにファイル名と
「表示できません」が出る。システム設定で「書類」フォルダへのアクセスを拒否した状態でツリーから開くと、
「アクセスできません」が出る。

## 性能の検証

`MediaViewerPerformanceTests` で自動計測する。手動では `huge/` と `bigimage/` で体感を確認する。

| 項目 | 基準値 | 根拠 |
|------|--------|------|
| 24MP JPEG を選択してから表示されるまで | 0.5 秒以内 | SC-001 |
| 先読み済みの隣接ファイルへの切替 | 0.1 秒以内 | SC-001、憲章 原則 II |
| 起動からリスト表示まで | 2 秒以内 | SC-002 |
| 10,000 ファイルのフォルダの最初の表示 | 1 秒以内。読み込み中もスクロールできる | SC-003 |
| 1080p 動画の選択から再生開始まで | 1 秒以内 | SC-010 |
| ペイン幅・サムネイルサイズのドラッグ中の表示停止 | 100ms 以上の停止が 0 回 | SC-004 |
| デコード済みプレビューのキャッシュ | 256MB を超えない | 憲章 原則 II、research.md R8 |

SC-004 は実際のドラッグ操作を伴うため自動テストには含めず、T080 の手動確認（画面収録または Instruments）で測る。

### os_signpost による起動・動画再生の計測（SC-002・SC-010）

起動から一覧表示までの時間と、動画の再生要求から再生開始までの時間を os_signpost の
インターバルとして記録する。Instruments の「Points of Interest」で確認できる。

- subsystem: `local.my-img-viewer.MediaViewer`
- category: `Performance`
- インターバル名:
  - `LaunchToList`: `applicationDidFinishLaunching` の開始から、最初のフォルダ一覧が
    `.loaded` / `.empty` / `.denied` / `.failed` のいずれかになって表示されるまで（SC-002）
  - `VideoPlaybackStart`: 動画の再生要求から、プレイヤーが最初に `.playing` になるまで（SC-010）

Instruments（Points of Interest）で計測する手順:

1. Instruments を開き、「Points of Interest」テンプレートを選ぶ
2. 対象に `.build/MediaViewer.app` を指定して記録を開始し、アプリを起動する
3. タイムラインを subsystem `local.my-img-viewer.MediaViewer` / category `Performance` で絞り込み、
   `LaunchToList` の長さを読む。目標は 2 秒以内
4. `mixed/` の mp4 を選び、`VideoPlaybackStart` の長さを読む。自動再生がオフの場合は Space で
   再生を開始してから読む。目標は 1 秒以内

コマンドラインで記録する場合:

```bash
xcrun xctrace record \
  --template 'Points of Interest' \
  --output launch.trace \
  --launch -- .build/MediaViewer.app

open launch.trace
```

`launch.trace` を Instruments で開き、同じ subsystem / category とインターバル名で絞り込む。
手動操作が必要な `VideoPlaybackStart` は、記録中に動画を選んで再生を開始する。
