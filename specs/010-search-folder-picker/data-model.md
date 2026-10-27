# Data Model: 検索起点フォルダの GUI 選択

本書の型・メソッドは実装予定の契約を示す。保存形式・外部 API は追加しない。

## 1. SearchRootInput（Core、値型）

| 状態 | 値 | 表示 | 解釈 |
|---|---|---|---|
| typed | 入力文字列 | 文字列そのもの | `SearchRoot.parse(text, home:)` の既存規則 |
| picked | 標準パネルで確定した絶対 file URL | `url.path`、引用符・エスケープなし | 選択 URL をそのまま返す。trim しない |

- 初期状態は typed。picked は標準パネルの検証成功からのみ作る。
- 起点欄のユーザー編集は常に typed にする。同じ文字列へ戻しても picked には戻さない。
- キーワード編集、パネルの取消・失敗・再表示は状態を変えない。
- `displayText` と `resolvedInput(home:)` を設ける。検索と初期表示の両方が同じ解釈を使う。
- 検索シートを閉じたら破棄。次に開くときは既存の既定値で初期化する。
- picked が持つ「選択した URL」と、検索検証が返す「リンク解決後の URL」は区別する。前者を欄へ表示し、後者を検索へ渡す。

## 2. SearchFolderInitialLocation（Core、非同期の候補解決）

| 操作 | 入力 | 出力 |
|---|---|---|
| 初期位置 | SearchRootInput、開始時既定パス、ホーム、検証処理（注入可能） | 優先順で最初の有効 URL、または利用不可の理由 |

- 候補順は（1）現在入力、（2）開始時既定、（3）ホーム。重複は除く。
- 各候補を `SearchRoot.validate` と同じ条件（存在・フォルダ・パッケージ拒否・読取り）で確認する。隠しフォルダは許可する。
- 検証失敗は次候補へ進み、全滅だけを親へ返す。候補を試す途中では欄・エラーを変更しない。
- 初期位置はパネルの `directoryURL` に渡すだけで、起点欄を書き換えない。

理由型は、既存の `SearchRootError` と「利用できるフォルダがない」を区別し、表示・読み上げ用のメッセージを持つ。

## 3. 選択パネル（App、標準 NSOpenPanel）

標準の `NSOpenPanel` を検索シートの親ウインドウに `beginSheetModal(for:)` で表示する。状態機械は持たない。

| 設定 | 値 |
|---|---|
| `canChooseFiles` | false |
| `canChooseDirectories` | true |
| `allowsMultipleSelection` | false |
| `canCreateDirectories` | false |
| `resolvesAliases` | true |
| `treatsFilePackagesAsDirectories` | false |
| `showsHiddenFiles` | false（ユーザーの ⌘⇧. 切替は許容） |
| `directoryURL` | 初期位置の解決結果 |
| `message` / `prompt` | 検索起点を選ぶ説明 / 「選択」 |

- 通常ファイル・zip は選択できず、複数選択・新規作成も提供しない。
- パッケージはフォルダとして辿れず、選択できない。一覧に表示されてもよい。
- 隠し項目は標準パネルに従う。表示して選択できる。
- パネルの Return・Esc・階層移動・VoiceOver は OS 標準に任せる。

確定後は選択 URL を捕捉し、`SearchRoot.validate` を UI スレッド外で実行する。成功なら選択 URL を picked として親へ返し、失敗なら親に理由を返す。パネル自体は検証を待たず閉じる。

## 4. 親の入力と表示の一時状態

`SearchPanelInputState` は SearchRootInput.swift 内に置く小さな Core の値型とする。rootInput、keyword、revision、isActive に加え、pendingOperation と requestGeneration を持つ。

| フィールド / 操作 | 内容 |
|---|---|
| pendingOperation | idle / resolvingInitialLocation / validatingSelection / validatingSearch |
| requestGeneration | 処理開始・失効で進める依頼世代 |
| revision | 入力元・キーワードの変更回数 |
| 初期位置の開始 | 世代を進め resolvingInitialLocation。入力と依頼世代を捕捉 |
| 確定後の検証の開始 | 世代を進め validatingSelection。選択 URL・入力・依頼世代を捕捉 |
| 検索の開始 | 空キーワードは無操作。それ以外は保留中の処理を失効させて validatingSearch へ |
| 完了の採用 | 捕捉した revision・requestGeneration・処理種別と isActive が一致する場合だけ |
| 編集・終了 | 保留中の処理を失効させて idle。終了では isActive も false |
| パネル表示中 | 親の検索・選択を拒否する（AppKit のモーダルに加えた防御） |

### 遷移

| イベント | 状態変更 | 完了時の扱い |
|---|---|---|
| 選択… | 初期位置の解決を開始。重複開始はしない | 成功した候補だけをパネルの `directoryURL` に使う。失敗は親に理由、欄は保持 |
| 初期位置解決中の検索受理 | 解決を失効させ、検索検証を開始 | 失効した解決の成功・失敗はパネル提示・エラーに使わない |
| パネルで選択 | 選択 URL を捕捉して validatingSelection | 成功した URL だけを欄へ反映し、古い起点エラーを消す。失敗は親に理由、欄・キーワード保持 |
| 検証中の検索受理 | 選択の検証を失効させ、検索検証を開始 | 失効した選択結果は欄へ反映しない |
| 検索検証の成功 | 親を終了 | onSearch を一度だけ呼ぶ |
| 検索検証の失敗 | idle | 親に理由を表示し、選択の再試行を可能にする。旧依頼は復活させない |
| パネル取消 | 状態変更なし | パネルだけを閉じ、欄・キーワード・理由を保持 |
| 編集・終了 | 入力/依頼世代を失効 | 古い成功・失敗を表示に使わない |

子の取消は rootInput・キーワード・親の理由を変更しない。確定成功は rootInput を picked にし、欄の全体を置換して古い起点理由だけを消す。確定失敗は選択 URL を反映せず、親の理由だけを新しい失敗内容にする。

## 5. 既存状態との関係

標準パネルは `BrowserModel` を参照しない。親も選択の開閉では startSearch・検索解除・ツリー同期・履歴記録・設定保存を呼ばない。既存検索と外部変更の更新は独立して続く。新しい検索の再検証が成功したときだけ既存 onSearch に渡し、FR-085 の置換を行う。
