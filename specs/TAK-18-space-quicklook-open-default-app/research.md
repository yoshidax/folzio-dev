# Research: TAK-18

Cloud では Swift と GUI を実行できないため、以下は SDK の文書と既存コードの読み取りに基づく。実機で確かめるべき点は「要実機」と記す。

## R1 Quick Look パネルで起点からのズームを実現できるか（FR-238 の技術検証）

- **Decision**: `QLPreviewPanel.shared()` を使い、`QLPreviewPanelDelegate.previewPanel(_:sourceFrameOnScreenFor:)` で項目の画面座標の矩形を返す。
  パネルはこの矩形から拡大して開き、`close()` / Space でこの矩形へ縮む。独自のウインドウやアニメーションは作らない。
- **Rationale**: Finder の Space と同じ部品で、公開 API だけで起点・終点のアニメーションを指定できる（`sourceFrameOnScreenFor` は Apple の文書に「ズームの起点／終点」として説明されている）。
  Issue の採用条件（標準部品で簡単に実現できる）を満たす見込み。
- **要実機**: 矩形が正しい画面座標か（スクロール・複数ディスプレイ・Retina）、Space で閉じたときの縮小、サムネイル形式の起点。
- **Alternatives considered**: `NSViewController.presentAsSheet` や独自の `NSPanel`（Issue が禁止）、`NSWorkspace.open`（「プレビュー」アプリの起動。Issue が禁止）。
- **見送りの条件**: 実機でズームが成り立たない、または標準部品だけで実現できないなら、（B）を見送る。（A）は独立して出す。

## R2 パネルの制御を受けるレスポンダ

- **Decision**: `NSResponder` の `acceptsPreviewPanelControl(_:)` / `beginPreviewPanelControl(_:)` / `endPreviewPanelControl(_:)`
  を、リストの `NSTableView` とサムネイルの `NSCollectionView` のサブクラス（すでにキー入力を処理している）に実装する。
  `beginPreviewPanelControl` で Coordinator を `dataSource` / `delegate` に設定し、`endPreviewPanelControl` で外す。
- **Rationale**: `QLPreviewPanel` は、キーウインドウのレスポンダチェーンで `acceptsPreviewPanelControl` が true の最初のオブジェクトに制御させる。
  フォーカスがファイルリストにあるときだけ制御を受けるため、EC-164（フォーカス条件）が自然に成り立つ。
- **Alternatives**: ウインドウコントローラが制御を持つ案は、ツリーやプレビューにフォーカスがあるときも開けてしまい、条件が崩れる。

## R3 Space の入口と二重処理

- **Decision**: `keyDown` の Space（`charactersIgnoringModifiers == " "`、修飾キーなし）で `QuickLookCoordinator.toggle()`。
  パネルが開いている間はキーウインドウがパネルになり、パネル自身の Space/Esc で閉じる。
  現在の `ListModeView.onSpace`（動画なら `onTogglePlayback`）は削除する。
- **Rationale**: 現行の Space は動画の再生を切り替える（FR-033）。保守者の決定（ファイルリストでは Quick Look に統一）に従う。
- **要実機**: 閉じた後に first responder がファイルリストに戻ること（M3）。

## R4 複数項目

- **Decision**: 選択中のメディアを、`BrowserModel.listing.files` の並び順で Coordinator が保持して `numberOfPreviewItems` を返す。
  先頭は、一覧の並びで最初の選択項目。Quick Look 内の項目の切り替えは標準のまま、Folzio の選択とは同期しない（A-146）。
- **Alternatives**: Quick Look の切り替えに合わせて Folzio の選択を動かす案は、`previewPanel(_:handle:)` でキーを横取りする必要があり、複雑になる。要望にもない。

## R5 既定のアプリで開く

- **Decision**: `NSWorkspace.shared.open(_:)`（⌘O と同じ。戻り値は無視）。対象の判断は Core。`BrowserModel.openItem` は変えない。
- **Rationale**: ⌘O の既存経路と同じ挙動に揃える。zip の中は `ArchiveURL`（仮想 URL）で実ファイルがないため、`isBrowsingArchive` で除く。

## R6 ビルド設定

- **Decision**: `import Quartz`（または `import QuickLookUI`）を `FolzioApp` に追加する。Package.swift は変えない想定。
- **要確認**: Swift 6 の言語モードで `QLPreviewPanel` の API が `@MainActor` として扱えるか、`NSObject` の `acceptsPreviewPanelControl` を override できるか。
  Cloud ではビルドできないため CI で確認する。失敗したらログを読んでまとめて直す（`docs_private/cloud-agent-workflow.md` の 4 章）。

## R7 一時プレビュー中の状態の変化（EC-166・169）

- **Decision**: 開く前に `previewViewController` の動画を一時停止する（既存の再生制御に pause がなければ、`togglePlayback` の状態を見て止める小さな API を足す）。
  一覧の更新通知で、対象 URL が一覧から消えたら閉じる。残りがあれば `reloadData()`。
- **Alternatives**: 何もしない案は、動画の音声がパネルの音声と重なる。
