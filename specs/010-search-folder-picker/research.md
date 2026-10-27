# Research: 検索起点フォルダの GUI 選択

**Date**: 2026-10-27 | **Branch**: `010-search-folder-picker`

入力は [spec.md](spec.md)、plan.md の product 参照領域、憲章 v1.2.0、既存コード。型名は実装予定である。調査事項は以下で解決した。

## 既存コードの調査

| 接続点 | 現状と設計への影響 |
|---|---|
| `Sources/MediaViewerApp/Search/SearchPanelController.swift` | 編集可能な起点欄、常に parse → 非同期 validate、Tab はキーワード・起点・取消・検索。`viewDidAppear` は毎回キーワードへフォーカスするため子からの復帰を分ける |
| `Sources/MediaViewerApp/App/MainSplitViewController.swift` の `showSearch` | 検索シートを提示し、`onSearch` だけで `model.startSearch` を呼ぶ。この境界を維持する |
| `Sources/MediaViewerCore/Search/SearchRoot.swift` | parse は純粋な trim・ホーム展開・末尾 `/` の解釈。validate は detached task でリンク解決・存在・種類・パッケージ拒否・opendir。直接入力の意味を維持する |
| `Sources/MediaViewerCore/FileSystem/DirectoryLister.swift` | subfolders は detached task で隠し・パッケージを除く。祖先・リンク先の GUI 到達可否は別途必要 |
| `Sources/MediaViewerCore/FileSystem/VolumeProvider.swift` | ホームと表示可能なボリュームを取得。同期 API の呼出しはバックグラウンドへ置く |
| `009-folder-search` | 現 HEAD へ統合済み。product 未反映の検索対象・結果の差分も維持する |

## R1 — 選択 GUI の部品

**Decision**: 標準 AppKit 部品による小さな `SearchFolderPickerController` を作る。フォルダだけの単一選択テーブル、場所・親・選択・取消を持つ。

**Rationale**: ローカル SDK の `NSSavePanel.h` は `showsHiddenFiles` をユーザーが ⌘⇧. で切替可能と記載する。false は切替禁止にならない。公開 shouldEnable は有効・無効の判定であり非表示ではない。`treatsFilePackagesAsDirectories = false` もパッケージの非表示を約束しない。directory 変更 delegate は移動後の通知。確定の validate は MainActor 上の同期 API である。FR-141 の禁止と非同期検証には専用 GUI が直接対応でき、A-83 でも許容される。

**Alternatives considered**: NSOpenPanel の設定だけ（禁止を満たさない）。キー横取り・KVO 巻戻し・内部ビュー変更（一度表示・移動する可能性、OS 依存が増える）。汎用ファイラ（範囲外）。

**Sources**: Apple の [showsHiddenFiles](https://developer.apple.com/documentation/appkit/nssavepanel/showshiddenfiles)、[panel(_:shouldEnable:)](https://developer.apple.com/documentation/appkit/nsopensavepaneldelegate/panel(_:shouldenable:))、[panel(_:validate:)](https://developer.apple.com/documentation/appkit/nsopensavepaneldelegate/panel(_:validate:))、[NSOpenSavePanelDelegate](https://developer.apple.com/documentation/appkit/nsopensavepaneldelegate)。専用 GUI の選択はこれらからの設計判断である。

## R2 — 直接入力と GUI 選択

**Decision**: Core の `SearchRootInput` を `.typed(String)` / `.picked(URL)` とする。GUI 確定では選択 URL の絶対パスを表示し、解釈結果はその URL とする。起点欄のユーザー編集通知で `.typed` へ戻す。開始時の既定パスも `.typed` とする。

**Rationale**: `Photos ` を `SearchRoot.parse` へ渡して trim しない。検索と初期表示は共通の解釈を使う。プログラムによる欄の置換はユーザー編集ではない。キーワード編集・子の取消・検証失敗では区別を変えない。選択 URL と validate が返すリンク解決後 URL を区別し、表示には選択 URL を使う。

**Alternatives considered**: 常に trim（AS10 に反する）。末尾空白の有無で自動判別（直接入力を変える）。欄と URL の一致で推定（編集して同じ文字列へ戻す操作を区別できない）。

## R3 — 初期位置と到達可否

**Decision**: 現在入力 → シート開始時の既定パス → ホームを順に解釈・検証し、最初に GUI で到達可能な候補を採る。全滅なら子を開かず親に理由を表示・読み上げる。欄は補正しない。既定パスは R8 の一覧基準で開始時に捕捉し、後からツリーへ問い合わせない。EC-102 の F が GUI 対象外なら現在入力と既定の F を飛ばしてホームへ進み、V は候補に加えない。

GUI の入口は `/`、ホーム、隠しでないマウント済みボリューム。入口自体も存在・読取り・非隠し・非パッケージを確認する。入口までの経路に隠し・パッケージがあれば内部を含め拒否する。ホームを入口にして隠し祖先を迂回しないようホームの経路も確認する。ボリュームは独立した入口とし、マウント先を載せる `/Volumes` の表示属性だけで外部ボリュームを拒否しない。リンクでは表示経路と解決先の経路を両方確認し、隠し・パッケージ内部への迂回を防ぐ。不明なメタデータを可として扱わない。

**Rationale**: FR-143 の順序と非表示規則を両立する。各ボリュームへ直接入る経路が必要であり、物理祖先を一律 `/` まで調べるだけでは SC-058 を誤拒否しうる。

**Alternatives considered**: 欄をホームへ補正（取消で保持できない）。末尾成分だけ検査（禁止内部へ入れる）。GUI 制限を SearchRoot.validate へ追加（直接入力の意味が変わる）。ボリュームを無条件で信用（隠し・読取不能を許す）。

## R4 — 列挙と確定検証

**Decision**: `SearchFolderAccess` がバックグラウンドで入口・候補・経路を検証し、`DirectoryLister.subfolders` の結果にも到達可否を適用する。確定時に再検証し、成功した選択 URL だけを親へ返す。検索でも既存 validate を再実行する。

**Rationale**: 列挙後の削除・権限変更・取り外しを確定時に検出する。事前検査だけでは競合を排除できないため次の操作でも再検証する。読取りは実際にディレクトリを開けるかで確認する。失敗は子のエラーとし、親を変えない。列挙失敗時も別の場所への移動・取消を残す。

**Alternatives considered**: 閉じてから検証（AS12 に反する）。同期 I/O（UI スレッド禁止に反する）。選択後の検索検証省略（EC-104 に反する）。

## R5 — 非同期の順序と寿命

**Decision**: 選択状態に世代を持ち、列挙・確定時に対象と世代を捕捉する。移動・選択変更で進め、取消・終了で失効する。完了は世代・対象・開いている状態が一致する場合だけ反映する。Task.cancel も行うが I/O の即終了には依存しない。

親の検索検証でも入力世代・キーワードを捕捉し、編集・取消後の古い成功で onSearch を呼ばない。親の入力世代と採否は SearchRootInput.swift 内の小さな Core の値型に置く。検索検証中は選択ボタンを無効にする。初期位置の解決中は重複提示を防ぐ。どの処理中も取消できる。

親には処理種別と依頼世代も持たせる。初期位置解決中の検索操作を受理した時点で提示依頼を失効させ、その後に検索条件を検証する。空キーワードなら従来どおり無操作。検索検証中は選択・重複検索を拒否する。失効した初期位置の成功・失敗は親のエラーにも子の提示にも使わず、検索失敗後にも復活させない。失敗後の選択は新しい依頼とする。先に子が提示済みなら親の検索を拒否する。UI への採用とアクションの受理は MainActor 上で直列化する。

**Rationale**: 古い一覧の巻戻し、Esc 後の確定、別候補の結果による確定を防ぐ。入力が同じでも検索検証と初期位置解決は競合するため、入力世代だけでなく依頼の種別・世代を照合する。完了順を入れ替えた状態の遷移は AppKit なしでテストできる。

**Alternatives considered**: 処理中 bool だけ（複数処理を識別できない）。cancel だけ（開始済み同期 I/O は完了しうる）。

## R6 — シートとキー

**Decision**: 検索 controller 自身が子を presentAsSheet する。メインウインドウへ二枚目を直接要求せず、runModal は使わない。子の Return・Esc を消費し、親のアクションも防御する。復帰後は選択ボタンへフォーカスし、親の初期キーワード全選択は初回だけにする。

**Rationale**: すでにシートを持つ同じウインドウへの次のシートはキューに入るため、検索シートを提示元とする。入力を文書モーダルで制限し、既存の検索 Task と外部更新は続ける。onSearch は有効な検索ボタンの検証成功でだけ呼ぶ。

**Alternatives considered**: メインウインドウへ二枚目（背後で待つ可能性）。アプリモーダルループ（更新と入力を複雑化）。既存検索を停止（AS13 に反する）。

**Sources**: Apple の [presentAsSheet(_:)](https://developer.apple.com/documentation/appkit/nsviewcontroller/presentassheet(_:))、[beginSheet(_:completionHandler:)](https://developer.apple.com/documentation/appkit/nswindow/beginsheet(_:completionhandler:))。実際の子シート・キー分離・更新継続は GUI 検証の対象とする。

## R7 — 検証方法

**Decision**: 入力元、候補順、到達可否、世代を決定的な自動テストにする。異常系は FixtureKit の一時フィクスチャで確認し、権限を戻して削除する。候補順・到達可否の組合せには注入したメタデータと検証結果を使い、一時領域の `/private` 等の属性や root 権限へ依存させない。子シート・キー・読み上げは手動で検証する。

**Rationale**: Core ロジックの自動検証と実操作の証明を両立する。SC-058〜060 の回数と検索中の更新は GUI で確認する。大量件数の UI 停止は Instruments で測る。

**Alternatives considered**: GUI のみ（状態と競合を固定できない）。自動テストだけで完了（起動・キー・VoiceOver を確認できない）。

## R8 — 既定起点の記述の統一（I1）

**Decision**: 既定起点は一覧に表示中のフォルダとする。検索結果中は検索前、zip 内は zip を含むフォルダ。EC-102 で一覧に F、ツリーに V がある場合は F を捕捉する。GUI 到達可否は別に判定し、F が禁止対象の内部ならホームへフォールバックし、親の F は保持する。

**差分と反映**: FR-081 に加え、既存 US1-AS25 の変更本文を spec.md に記載し、同じ一覧基準・EC-102 の F で判定する。両 ID を spec.md の「反映先」と T045 に含め、実装・検証後に search.md の要件と受け入れシナリオを揃える。

**Rationale**: 既存キー契約の FR-081 と `MainSplitViewController.showSearch`（`model.listing.folder.path`）が一致し、A-84 の既定値維持と本 feature の入力手段だけを追加する範囲に合う。product/search.md と本 feature に残るツリー基準の記述を、本 feature の差分として改める。実装・検証後の product 反映ではキー契約の既定値を維持し、search.md を揃える。EC-102 のツリー・保存・履歴は変えない。

**Alternatives considered**: ツリーの V を使う（既存キー契約・実装の挙動が変わる）。GUI の初期位置だけ V を使う（FR-143 の候補にない値を追加する）。

## R9 — SC-058 の合格条件（A1）

**Decision**: 5ケースのすべてで選択後の検索開始が成立し、検索バーの起点と配下の既知の一致結果で起点一致を確認すれば合格とする。全走査の完了は要求しない。`/` 等も照合後は解除してよく、照合前の解除は未確認とする。

**Rationale**: 検証対象は起点入力手段であり、ルート全走査の所要時間や読み取り範囲は端末に依存する。既存 quickstart が許容する途中終了を保ちつつ、開始前の選択確定だけを合格にしない観測条件を定める。全走査の性能基準は既存の専用フィクスチャで別途検証する。

**Alternatives considered**: 5ケースすべてで全走査完了を必須にする（入力手段の受け入れに端末全体の走査を課す）。起点ラベルだけで合格にする（結果の起点を照合できない）。
