# Research: 検索起点フォルダの GUI 選択

**Date**: 2026-10-27 | **Branch**: `010-search-folder-picker`

入力は [spec.md](spec.md)、plan.md の product 参照領域、憲章 v1.2.0、既存コード。型名は実装予定である。調査事項は以下で解決した。

## 既存コードの調査

| 接続点 | 現状と設計への影響 |
|---|---|
| `Sources/MediaViewerApp/Search/SearchPanelController.swift` | 編集可能な起点欄、常に parse → 非同期 validate、Tab はキーワード・起点・取消・検索。検索欄を標準の検索フィールドへ、起点の近くに「選択…」を追加し、子シートは標準パネルにする |
| `Sources/MediaViewerApp/App/MainSplitViewController.swift` の `showSearch` | 検索シートを提示し、`onSearch` だけで `model.startSearch` を呼ぶ。この境界を維持する |
| `Sources/MediaViewerCore/Search/SearchRoot.swift` | parse は純粋な trim・ホーム展開・末尾 `/` の解釈。validate は detached task でリンク解決・存在・種類・パッケージ拒否・opendir。直接入力と GUI 選択の検証に再利用する |
| `009-folder-search` | 現 HEAD へ統合済み。product 未反映の検索対象・結果の差分も維持する |

## R1 — 選択 GUI の部品

**Decision**: macOS 標準の `NSOpenPanel` を検索シートの子シートとして使う。独自のフォルダ一覧・場所一覧・親移動・表示切替は作らない。

**Rationale**: Apple の File System Programming Guide は、既存のファイルやフォルダを選ばせる場合は標準の Open パネルを使い、既存ウインドウから選ぶ場合はシートとして表示するよう案内している。標準パネルはサイドバー・アイコン・検索・キーボード・VoiceOver・ダークモードを OS が提供する。`canChooseFiles = false`・`canChooseDirectories = true`・`allowsMultipleSelection = false` で単一フォルダ選択にでき、`treatsFilePackagesAsDirectories = false` でパッケージをフォルダとして辿らせない。`showsHiddenFiles = false` は既定で隠し項目を隠すが、ユーザーは ⌘⇧. で切り替えられる。この切替は許容し、隠しフォルダの選択も許可する（spec の Clarifications）。確定後の非同期検証は、パネルが返した URL に対して `SearchRoot.validate` を UI スレッド外で実行する。

**Alternatives considered**: 独自の `NSViewController` シート（標準パネルらしい操作感・アクセシビリティを再現しにくく、隠し・パッケージ・非同期検証の制約が増える）。`NSOpenPanel` の delegate で隠し項目・パッケージを完全に隠す（公開 API では保証できない）。汎用ファイラ（範囲外）。

**Sources**: Apple の [Using the Open and Save Panels](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/UsingtheOpenandSavePanels/UsingtheOpenandSavePanels.html)、[NSOpenPanel](https://developer.apple.com/documentation/appkit/nsopenpanel)、[NSSavePanel.treatsFilePackagesAsDirectories](https://developer.apple.com/documentation/appkit/nssavepanel/treatsfilepackagesasdirectories)、[NSSavePanel.showsHiddenFiles](https://developer.apple.com/documentation/appkit/nssavepanel/showshiddenfiles)。

## R2 — 直接入力と GUI 選択

**Decision**: Core の `SearchRootInput` を `.typed(String)` / `.picked(URL)` とする。GUI 確定では選択 URL の絶対パスを表示し、解釈結果はその URL とする。起点欄のユーザー編集通知で `.typed` へ戻す。開始時の既定パスも `.typed` とする。

**Rationale**: `Photos ` を `SearchRoot.parse` へ渡して trim しない。検索と初期表示は共通の解釈を使う。プログラムによる欄の置換はユーザー編集ではない。キーワード編集・パネルの取消・検証失敗では区別を変えない。選択 URL と validate が返すリンク解決後 URL を区別し、表示には選択 URL を使う。

**Alternatives considered**: 常に trim（AS10 に反する）。末尾空白の有無で自動判別（直接入力を変える）。欄と URL の一致で推定（編集して同じ文字列へ戻す操作を区別できない）。

## R3 — 初期位置

**Decision**: 現在入力 → シート開始時の既定パス → ホームを順に解釈・検証し、最初に有効な候補を `NSOpenPanel.directoryURL` にする。全滅ならパネルを開かず親に理由を表示・読み上げる。欄は補正しない。既定パスは R8 の一覧基準で開始時に捕捉し、後からツリーへ問い合わせない。EC-102 の F が無効なら現在入力と既定の F を飛ばしてホームへ進み、V は候補に加えない。

各候補には `SearchRoot.validate`（存在・フォルダ・パッケージ拒否・読取り）を適用する。隠しフォルダは許可する。独自の隠し祖先・リンク経路・ボリューム入口の判定は行わない。標準パネルは OS が表示と移動を扱う。

**Rationale**: FR-143 の順序を保ちつつ、標準パネルに開始位置だけを渡す。無効な URL を `directoryURL` にしてパネルが失敗することを避ける。

**Alternatives considered**: パネル自身に初期位置を決めさせる（現在入力・既定の優先順を保てない）。欄をホームへ補正（取消で保持できない）。隠し祖先を拒否（標準パネルの表示と一致せず、不要な制約になる）。

## R4 — 確定後の再検証

**Decision**: 標準パネルで「選択」を押すとパネルを閉じ、選択 URL を捕捉して `SearchRoot.validate` を非同期で実行する。成功した場合だけ選択 URL を親へ返し、欄を置換して古い起点エラーを消す。失敗した場合は欄・キーワードを保持し、親シートに理由を表示・読み上げて再試行できる。検索時にも必ず再検証する。

**Rationale**: パネルが閉じる前に非同期検証を完了させることはできない。閉じた後に検証し、失敗時は親で説明する方が、標準パネルの動作を変えずに EC-104 を満たせる。選択後の削除・権限変更・取り外しは確定時と検索時の両方で検出する。

**Alternatives considered**: パネルの delegate で同期検証（UI スレッドの I/O と FR-141 の非同期要件に反する）。検証を省略（EC-104 に反する）。検証の間パネルを開いたままにする（標準パネルの確定動作を変える）。

## R5 — 非同期の順序と寿命

**Decision**: 親の入力状態に `revision`・`requestGeneration`・`pendingOperation` を持つ。初期位置の解決と確定後の検証は、開始時の入力・依頼世代・選択 URL を捕捉する。編集・シート終了・検索受理・取消で世代を進め、完了は捕捉値と現在値が一致する場合だけ採用する。初期位置の解決中も検索でき、検索を受理したら解決を失効させる。パネル表示中は親の検索・選択を拒否する。確定後の検証中に検索を受理した場合も、選択の完了を採用しない。

**Rationale**: 古い初期位置でパネルを開く、編集後の遅い検証で欄を上書きする、検索と選択の完了順で状態が混ざる、といった競合を防ぐ。標準パネルはモーダルなので、表示中の親操作は主に防御的チェックになる。

**Alternatives considered**: 処理中 bool だけ（複数処理を識別できない）。cancel だけ（開始済みの検証は完了しうる）。パネル表示中に親を操作可能にする（標準シートのモーダル性に反する）。

## R6 — シートとキー

**Decision**: 検索 controller 自身が `NSOpenPanel` を `beginSheetModal(for:)` で開く。`runModal` は使わない。パネル表示中は親を操作できない。パネルの Return・Esc は標準パネルが処理し、親へ伝播しない。パネル終了後は親の「選択…」へフォーカスを戻す。親の初期キーワード全選択は初回だけにする。

**Rationale**: すでにシートを持つ同じウインドウへの次のシートはキューに入るため、検索シートを提示元とする。標準パネルのキーボード・アクセシビリティをそのまま使える。`onSearch` は有効な検索ボタンの検証成功でだけ呼ぶ。

**Alternatives considered**: 標準パネルをアプリモーダルで開く（他のウインドウと更新を複雑化）。既存検索を停止（AS13 に反する）。独自の子シート（R1 の代替案）。

## R7 — 検証方法

**Decision**: 入力元、初期候補の順序、入力世代、確定後の検証を決定的な自動テストにする。初期候補のテストは検証処理を注入し、実 I/O に依存させない。標準パネルの外観・標準キー・VoiceOver、既存検索の継続は手動で検証する。`SearchRoot.validate` の実 I/O 回帰（削除・権限・リンク）は既存テストを維持する。

**Rationale**: 非同期の採否と候補順は Core で固定できる。標準パネルそのものの見た目・操作は OS の実装であり、自動テスト target を増やさず手動で確認するのが適切である。

**Alternatives considered**: 標準パネルを UI テストで自動化（新しい target と OS 依存が増える）。GUI のみ（状態と競合を固定できない）。

## R8 — 既定起点の記述の統一（I1）

**Decision**: 既定起点は一覧に表示中のフォルダとする。検索結果中は検索前、zip 内は zip を含むフォルダ。EC-102 で一覧に F、ツリーに V がある場合は F を捕捉する。GUI の初期位置は F を `SearchRoot.validate` で確認し、無効ならホームへフォールバックし、親の F は保持する。

**差分と反映**: FR-081 に加え、既存 US1-AS25 の変更本文を spec.md に記載し、同じ一覧基準・EC-102 の F で判定する。両 ID を spec.md の「反映先」に含め、実装・検証後に search.md の要件と受け入れシナリオを揃える。

**Rationale**: 既存キー契約の FR-081 と `MainSplitViewController.showSearch`（`model.listing.folder.path`）が一致し、A-84 の既定値維持と入力手段だけを追加する範囲に合う。EC-102 のツリー・保存・履歴は変えない。

**Alternatives considered**: ツリーの V を使う（既存キー契約・実装の挙動が変わる）。GUI の初期位置だけ V を使う（FR-143 の候補にない値を追加する）。

## R9 — SC-058 の合格条件（A1）

**Decision**: 5ケースのすべてで選択後の検索開始が成立し、検索バーの起点と配下の既知の一致結果で起点一致を確認すれば合格とする。全走査の完了は要求しない。`/` 等も照合後は解除してよく、照合前の解除は未確認とする。

**Rationale**: 検証対象は起点入力手段であり、ルート全走査の所要時間や読み取り範囲は端末に依存する。既存 quickstart が許容する途中終了を保ちつつ、開始前の選択確定だけを合格にしない観測条件を定める。全走査の性能基準は既存の専用フィクスチャで別途検証する。

**Alternatives considered**: 5ケースすべてで全走査完了を必須にする（入力手段の受け入れに端末全体の走査を課す）。起点ラベルだけで合格にする（結果の起点を照合できない）。
