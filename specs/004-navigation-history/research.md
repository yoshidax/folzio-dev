# Research: 操作の履歴を戻る・進む

番号は 003 の research.md（R57〜R67）から続ける。コードのコメントで `R68` のように参照する。
Technical Context に NEEDS CLARIFICATION は残っていない。以下は設計上の判断の記録。

## R68. 履歴の持ち方（FR-107・FR-110・FR-111、主なエンティティ）

- **Decision**: 履歴の列は Core の値型 `NavigationHistory`（`struct`）で持つ。戻る側（古い順）・現在（optional）・進む側（近い順）の
  3つに分けて持ち、記録・移動・取り除き・置き換え・まとめ・上限の規則をすべてこの型のメソッドにする。ディスクも `BrowserModel` も
  見ない純粋なロジックで、テストはファイルを作らずに書ける。現在が nil の状態（「現在の履歴がない」）を許し、表示が空・見つからない
  場所になったとき（EC-62・EC-65）に使う。この状態で「戻る」は戻る側の最も新しい履歴へ、「進む」は進む側の最も古い履歴へ移り、
  新しい履歴を記録すると現在になって進む側を取り除く
- **Rationale**: 「インデックス付きの配列」より、現在がない状態を自然に表せる。値型のため、記録の前の状態を丸ごと控えて戻せる（R75 の
  EC-62）。100 件の配列の操作は UI スレッドで行っても無視できる費用である
- **Alternatives considered**:
  - 配列と現在のインデックス: 現在がない状態を「インデックスの間」で表す必要があり、境界の扱いを誤りやすい
  - `BrowserModel` に履歴を持たせる: 表示の状態のうち表示形式・サムネイルサイズ・ペインの表示状態は App が持っており（R70）、
    1,130 行の `BrowserModel` をさらに大きくする
- **確認すること（テスト）**: 記録・戻る・進む・分岐（進む側の取り除き）・100 件の上限（150 回で 99 回戻れる。SC-031）・現在がない状態

## R69. 場所と表示の状態の同一の判定（FR-107・EC-59）

- **Decision**: 履歴の場所 `HistoryLocation` は、表示しているフォルダ（`FolderListing.folder`）と zip の中の位置（`ArchiveLocation?`）の組とする。
  場所の比較は、URL の `.`・`..` を取り除いたパスの文字列で行う（`RenamedFolder` と同じ正規化。`standardizedFileURL` は場所の有無で
  `/private` の扱いが変わるため使わない）。zip の中の階層のパスは文字列のまま比べる。表示の状態 `HistoryViewState` は表示形式・
  サムネイルサイズ・種類フィルタ・zip ファイルの表示・ペインの表示状態の5つで、すべて一致したら同じとする（サムネイルサイズは
  `ViewSettings.clampThumbnailSize` 済みの値どうしで比べる）。フォーカスしていた行は比較に含めない
- **Rationale**: FR-107 の「同じ場所・同じ表示の状態」と EC-59 のまとめで、同じ判定を使う。消えた場所（比べる時点で存在しない）を
  含めても表記がずれない比較が要る
- **Alternatives considered**:
  - `URL` の `==`: 末尾の `/` の有無（`hasDirectoryPath`）で別物になる

## R70. 記録の経路（FR-107）

- **Decision**: 経路を2つに分ける。
  - **場所の変化**（フォルダの選択・フォルダの移動）: `BrowserModel` が場所を変えるたびに、同期のコールバック
    `onLocationEvent: ((LocationEvent) -> Void)?` で理由つきの通知を出す。理由は `.navigated(leavingFocus:)`（ユーザーの操作）・
    `.relocated(vanished:)`（表示中の場所が消えたことによる自動の移動。EC-60）・`.notFound(location)`（読み込みが「見つからない」で
    終わった。EC-62・EC-65）の3つ。`leavingFocus` は一覧を空にする前（`resetForNavigation` の前）のフォーカス行で、
    離れる履歴に記録する（FR-108）。理由は `selectFolder`・`navigateToFolder`・`returnToFolder` に内部の引数を足して呼び出し元で決める
    （ツリー・ファイルリストからは `.navigated`、`handleFileSystemEvent` と `leaveTrashedFolders` からは `.relocated`）。
    `startSearch` は `listing.folder` を変えないため通知しない（FR-113）。履歴の復元（R74）でも通知しない
  - **表示の変更**: 表示形式・サムネイルサイズ・ペインの表示状態の持ち主は App（`FileListViewController`・`MainSplitViewController`）の
    ため、ユーザーの操作の入口（「表示」メニュー・ショートカット・ツールバー・下部のサイズバー）から
    `HistoryNavigator.recordViewChange(_:)` を呼ぶ。種類フィルタと zip ファイルの表示も、入口は `FileListViewController` の
    `applyMediaTypeFilter`・`applyShowsZipFiles`・メニューのアクションなので同じく入口で呼ぶ。復元はこの入口を通らないため記録されない
  - `HistoryNavigator` は、どちらの経路でも記録の時点の場所（`BrowserModel.historyLocation`）と表示の状態（R74 の
    `HistoryPresentationHost` と `BrowserModel` から作る）を読んで `NavigationHistory.record` に渡す。同じ場所・同じ表示の状態なら記録しない
- **Rationale**: 場所の変化の理由は `BrowserModel` の中でしか分からない（外部の変更・ゴミ箱で親へ移ったのか、ユーザーが移ったのか）。
  通知を同期にするのは、Observation の `onChange` は次の変化までに再登録が間に合わず、続けて起きた移動を取りこぼすことがあるため。
  表示の変更を setter ではなく入口で記録するのは、復元で同じ setter を呼んでも記録しないようにするため。同じ値の再設定は
  同一の判定で記録されないため、入口では無条件に呼んでよい
- **Alternatives considered**:
  - App のツリー・ファイルリストのアクションで場所を記録する: `selectFolder` は読み込みの完了まで戻らず、記録の時点で場所が決まらない。
    `openItem` の行の種類ごとの行き先を App で重ねて判断することになる
  - `BrowserModel.listing` を Observation で監視する: 理由（ユーザーの操作か自動の移動か）が分からない
- **確認すること（テスト）**: ツリーの選択・行を開く・`..`・⌘↑・zip の中の移動のそれぞれで1件ずつ記録されること、`leavingFocus` に
  移動前のフォーカス行が入ること、検索の開始・外部の変更・ゴミ箱による移動では新しい履歴にならないこと

## R71. サムネイルサイズの変更のまとめ方（FR-107・US8-AS2・US8-AS7）

- **Decision**: `NavigationHistory` が直前の記録の種類（`lastRecordKind`）を持つ。サムネイルサイズの変更（`.thumbnailSize`）を記録するとき、
  直前の記録も `.thumbnailSize` で、その後に戻る・進む・ほかの記録がなければ、新しい履歴を足さずに現在の履歴の表示の状態を
  書き換える。戻る・進む・ほかの種類の記録・現在の取り除き（R75）で `lastRecordKind` を nil にする。まとめた結果、現在の履歴が
  1つ前の履歴と同じ状態になったら（ドラッグで元の大きさに戻した）、EC-59 のとおり1つにまとめ、`lastRecordKind` を nil にする
  （続くサイズの変更が古い履歴を書き換えないように）
- **Rationale**: スライダーは連続して値を送る（`isContinuous = true`）ため、ドラッグの終わりを App で検出するより、Core で
  「続けて行ったサイズの変更」をまとめる方が単純で、⌘+ / ⌘- の連打も同じ規則で扱える。FR-107 の規則（ほかの記録する操作と
  戻る・進むを挟まない限り1件）そのものである
- **Alternatives considered**:
  - マウスアップでの確定（`NSEvent` の監視）: ツールバーのスライダーと下部のサイズバーの両方に必要で、⌘+ / ⌘- には使えない
  - 時間でまとめる（0.5 秒以内）: FR-107 の規則と食い違う
- **確認すること（テスト）**: 連続した5回のサイズの変更が1件になること、戻る・進むの直後のサイズの変更が新しい履歴になること（US8-AS7）、
  元の大きさに戻したときに前の履歴とまとまること

## R72. 戻る・進むの実行と連打（FR-108・FR-109・EC-61）

- **Decision**: Core の `HistoryNavigator`（`@MainActor @Observable`）が、戻る・進むの要求を順に処理する。`goBack()`・`goForward()` は
  要求をキューに積んですぐ戻る（UI を待たせない）。処理は1つずつ、次の順で行う。
  1. 検索結果の表示中の「戻る」は、検索結果の表示を終える（R76）。履歴は移らない
  2. その方向の最も近い履歴（候補）を取り出す。候補がなければ何もしない
  3. 候補の場所が今の表示と同じなら、場所の確認と読み込みをせず、表示の状態だけを復元する（FR-108）
  4. そうでなければ `BrowserModel.resolveHistoryLocation(_:)` で場所を確かめる（R73。UI スレッドの外）。見つからなければ候補を
     取り除いて 2 へ戻る（FR-109）
  5. 確かめている間に履歴（`NavigationHistory` の版）や `BrowserModel` の移動の世代が変わったら（ユーザーがツリーで別のフォルダを
     選んだなど）、この要求を捨てる
  6. 離れる履歴に今のフォーカス行を記録して履歴を移り、`BrowserModel.showHistoryLocation(_:focusing:)` で場所を表示し（読み込みの
     完了を待たない）、表示の状態を復元する（R74）
  連打では、要求ごとに確認と移動を行い、読み込みは `BrowserModel` の移動の世代で古いものが捨てられるため、最後の移動先の一覧が残る
- **Rationale**: 場所の確認は数 ms の stat だが、zip の中の場所は zip を開いて確かめるため時間がかかることがある。要求を直列にすれば
  候補の取り除きと移動の順序が崩れない。読み込みの完了を待たないので、10,000 件のフォルダへ戻る途中でも次の要求を受け付ける
- **Alternatives considered**:
  - 押した時点で履歴を先に移し、確認は後から行う: 見つからなかったときに履歴を巻き戻す処理が要り、EC-54（すべて見つからなければ
    表示を変えない）を満たしにくい
  - 確認を UI スレッドで同期に行う: 取り外し途中のボリュームやネットワークボリュームで stat が長く止まることがある（憲章 II）
- **確認すること（テスト）**: `goBack()` を3回続けて呼んで `waitUntilIdle()` の後に3つ前の履歴にいること、確認中にツリーの選択に
  当たる移動をしたら要求が捨てられること、すべての候補が見つからないときに表示（`listing`）が変わらないこと（EC-54）

## R73. 場所の確認（FR-109・EC-55〜EC-58）

- **Decision**: `BrowserModel.resolveHistoryLocation(_:) async -> HistoryLocationResolution` が、表示を変えずに場所を確かめる。
  - 通常のフォルダ: `Task.detached` で `fileExists(atPath:isDirectory:)` を見る。存在してディレクトリなら見つかる（読めるかは見ない。
    EC-55）。ボリュームの取り外しも stat の失敗として見つからないになる（EC-57）
  - zip の中: zip ファイルが存在して通常のファイルでなければ見つからない。存在すれば索引を作る（`archiveReader.open`）。開けなければ
    （壊れている）見つかるとして扱い、表示のときに EC-24 と同じ失敗を出す（EC-56）。開けたら、階層が最上位でなく、索引にその
    ディレクトリがなければ見つからない。判定に `ArchiveIndex.containsDirectory(_:)` を足す。今表示している zip と同じ zip なら、
    開いている索引を使い、開き直さない
  - 確認の結果（索引や失敗の理由）は `ResolvedHistoryLocation` に入れて返し、表示（R74）で使う。確認を始めた時点の移動の世代を持ち、
    表示のときに世代が変わっていれば何もしない
- **Rationale**: 場所の存在で判定する（A-42）。zip は中のディレクトリまで確かめないと、表示した後で見つからないと分かり、
  表示を変えずに飛ばすこと（EC-54）ができない。開いた索引を表示に渡せば2回開かずに済む
- **Alternatives considered**:
  - zip の中は zip ファイルの存在だけを見る: 中のディレクトリがない zip（作り直された zip など）で空の一覧を出してしまう
- **確認すること（テスト）**: 存在するフォルダ・削除したフォルダ・権限のないフォルダ（見つかる）・zip の最上位・zip の中の存在する／
  しないディレクトリ・削除した zip・壊れた zip（見つかる）

## R74. 復元（FR-108・FR-056 の変更・EC-64）

- **Decision**:
  - **場所**: `BrowserModel.showHistoryLocation(_ resolved:, focusing:)` が、通常のフォルダなら `selectFolder` と同じく一覧を読み込み、
    zip の中なら確認で得た索引でその階層を表示する（失敗なら EC-24 の表示）。どちらもツリーへの同期の依頼（`treeSyncRequest`、
    フォルダは zip を含むフォルダ）を出し（FR-078 の規則でツリーを選択・展開・スクロールする。ツリーのフォーカスは移さず、
    選択の変化から `selectFolder` を呼び返さない）、`lastFolder` を保存する。読み込みの後に `focusing` の行が一覧にあればその行だけを
    選択してプレビューし、なければ何も選択しない（EC-64）。一覧の作り直しでフォーカス行へ必要最小限スクロールするのは、既存の
    `ListModeView`・`ThumbnailModeView` の振る舞い（選択の反映で `scrollRowToVisible`）のまま。再生中の動画は `resetForNavigation` で
    止まる（FR-034）
  - **表示の状態**: 種類フィルタと zip ファイルの表示は `HistoryNavigator` が `BrowserModel.setMediaTypeFilter`・`setShowsZipFiles` で戻す
    （FR-059・FR-097 の選択の整理、FR-095 の保存は既存の setter のまま）。表示形式・サムネイルサイズ・ペインの表示状態は、
    App が実装する `HistoryPresentationHost.applyHistoryPresentation(_:)` で戻す。`MainSplitViewController` が実装し、
    `FileListViewController` の表示形式・サイズの setter（保存を含む。FR-003）と、自身の `setPaneLayout`（FR-091 のフォーカスの移動を含む）を
    記録せずに呼ぶ。場所を変える場合は、先に場所の表示を始めてから表示の状態を戻す（古い一覧に種類フィルタを当て直す無駄を省く）
  - 種類フィルタは、戻る・進むで移ったときだけ移った先の履歴の状態に戻る（FR-056 の変更）。ツリーでの選択など、ほかの移動では
    従来どおり保つ（記録の経路に影響しない）
- **Rationale**: 場所の表示と選択の復元は `BrowserModel` の世代管理の中で行い、古い読み込みの結果で選択を上書きしない。
  App が持つ状態は App の setter を通すことで、ツールバー・メニューの表示（`onViewStateChange`・`onPaneLayoutChange`）が自動で揃う
- **Alternatives considered**:
  - 表示形式・サイズ・ペインの表示状態を Core へ移す: 既存の持ち主（001 の R40 など）を変える大きな変更になる
- **確認すること（テスト）**: 戻ったフォルダでフォーカス行だけが選択されること、行が消えた・種類フィルタで隠れたときに何も選択されず
  プレビューが空であること、zip の中の場所でツリーへの依頼が zip を含むフォルダになること、`lastFolder` が保存されること、
  種類フィルタが戻ること、スタブの `HistoryPresentationHost` に表示形式・サイズ・ペインの表示状態が渡ること

## R75. 履歴の取り除き・置き換え・まとめ（FR-109・EC-54〜EC-60・EC-62・EC-65）

- **Decision**: `HistoryNavigator` が次の契機で `NavigationHistory` を直す。どの操作の後も、隣り合う同じ状態の履歴を1つにまとめる
  （現在の履歴は残す。それ以外は新しい方を残す。EC-59）
  - **アプリの中のフォルダの名前の変更**（ツリー・ファイルリスト）: `FileOperationCoordinator` が `onFolderRenamed` と同じ時点で
    `didRenameFolder(from:to:)` を呼ぶ。現在の履歴は `RenamedFolder.rebase` で新しい場所に置き換え（FR-104 の追従に合わせる）、
    ほかの履歴のうち元の場所とその配下（zip の中を含む）を指すものを取り除く
  - **zip ファイルの名前の変更**（ファイルリスト）: 同じく `didRenameItem(from:to:)` で、その zip の中を指す履歴を取り除く
  - **ゴミ箱・移動**（ツリー・ファイルリスト・ドロップ・移動ペースト）: 成功した元の場所を `didRemoveItems(_:)` に渡し、その場所と配下を
    指す履歴を取り除く。現在の履歴は取り除かない（表示が移るなら次の `.relocated` で置き換わる）
  - **外部の変更**: FSEvents のバッチ（ツリーの `eventTask`）で `handleFileSystemEvent(_:)` を呼び、変更のあったフォルダの配下を指す履歴だけ
    UI スレッドの外で存在を確かめ、見つからないものを取り除く。ボリュームの増減（`volumes.changes`）ではすべての履歴を確かめる。
    zip の中の履歴は zip ファイルの存在だけを見る（中のディレクトリは戻る・進むのときに確かめる）。現在の履歴が見つからなければ
    現在を取り除く（EC-65）。ただし表示中のボリュームが取り外されたときは、先に `BrowserModel.handleFileSystemEvent` が表示を親へ移す
    （`deletingLastPathComponent`）ため、実際の経路は「`.relocated` で現在を親に置き換える → 親の読み込みが「見つからない」で終わる →
    `.notFound` で現在を取り除く」になる。ボリュームのルートを表示していた場合は親（`/Volumes`）が存在するため、EC-60 の置き換えになりうる
    （/speckit-analyze の指摘 U2。テストは tasks.md の T016、GUI は quickstart.md の 26）
  - **`.relocated(vanished:)`**（EC-60）: 現在の履歴の場所を移った先に置き換え（表示の状態は変えない）、`vanished` とその配下を指すほかの
    履歴を取り除く。進む側は残す
  - **`.notFound(location)`**（EC-62・EC-65）: 直前の `.navigated` で記録した履歴がその場所で、その後に履歴が変わっていなければ、記録の前に
    控えた `NavigationHistory` に戻してから現在を戻る側へ移す（記録しなかったことにし、進む側も残す。表示中の「見つからない」場所は
    どの履歴でもない状態にする）。そうでなく現在の履歴の場所なら現在を取り除く
  - 一度取り除いた履歴は戻さない（EC-58）。記録・取り除きはどれも 100 件の配列の操作で、UI スレッドで行う
- **Rationale**: 取り除きの契機は既存の通知（`onFolderRenamed`・ゴミ箱の結果・FSEvents・ボリュームの変化）に乗せられる。外部の変更を
  契機のたびに確かめることで、US7-AS7 のように戻る先がなくなったときにボタンがすぐ淡色になる。値型の控えで記録を取り消すため、
  「見つからない場所は記録しない」（EC-62）を、記録を読み込みの結果まで遅らせずに満たせる
- **Alternatives considered**:
  - 取り除きを戻る・進むのときだけにする: FR-109 の「その時点で取り除く」と US7-AS7 を満たせない
  - 名前を変えた場所の履歴を新しい名前に追従させる: FR-109 で採らないと決めている
  - EC-62 で記録を読み込みの完了まで遅らせる: 読み込み中に続けて移動したときの順序の扱いが複雑になる
- **確認すること（テスト）**: 名前の変更（現在は置き換え・ほかは取り除き・配下と zip の中を含む・兄弟の前方一致は残す）、ゴミ箱、
  外部の削除（FSEvents）、ボリュームの取り外し、`.relocated` で進む側が残ること、`.notFound` で進む側が残り現在がなくなること、
  取り除いた後の隣り合う同じ履歴のまとめ

## R76. 検索結果の表示との関係（FR-113・US7-AS11〜US7-AS13）

- **Decision**: 検索の開始は `listing.folder` を変えないため記録されない。検索結果の表示中の「戻る」は、ファイルリストの Esc と同じく
  `selectFolder(listing.folder)` で検索結果の表示を終える（検索中なら止まる）。この移動は `.navigated` として通知され、場所が現在の
  履歴と同じなので新しい履歴にならず、現在の履歴の表示の状態を今の表示の状態で書き換える（検索結果の表示中に変えた表示を反映する）。
  ツリーで選択中のフォルダの行をクリックして終えた場合と Esc も同じ規則になる。ツリーで別のフォルダを選んだ場合は、場所が違うため
  FR-107 の（1）として記録される。検索結果の表示中は `recordViewChange` を何もしない。`HistoryNavigator.canGoBack` は検索結果の表示中なら
  戻る側の履歴に関わらず true、`canGoForward` は false
- **zip の中で始めた検索**: FR-086 の既存の振る舞いでは、Esc は zip を含むフォルダの一覧に戻る。このとき表示の場所が現在の履歴（zip の中）と
  異なるため、上の規則では新しい履歴として記録される（zip の中の履歴は戻る側に残り、⌘[ でもう一度 zip の中へ戻れる）。spec は FR-113 と
  US7-AS13 でこの振る舞いを定めた（/speckit-analyze の指摘 I1。当初は spec が定めておらず GUI の確認に回していた）。上の規則のまま実装し、
  `HistoryNavigator` のテストと GUI で検証する
- **Rationale**: 既存の Esc の経路（FR-086）をそのまま使い、記録の規則を増やさない
- **確認すること（テスト）**: 検索結果の表示中の `goBack()` で検索が止まり、履歴の数と位置が変わらないこと、戻る側がないときも
  `canGoBack` が true であること、検索結果の表示中の表示の変更が記録されず、終えたときに現在の履歴の表示の状態になること、
  zip の中で始めた検索の `goBack()` で zip を含むフォルダが新しい履歴になり、もう一度の `goBack()` で zip の中へ戻ること（US7-AS13）

## R77. ツールバー・メニュー・ショートカット（FR-112・FR-045 の変更・FR-102 の変更）

- **Decision**:
  - **ツールバー**: `MainToolbarController` に `history` の項目を足し、並びの先頭に置く。既存の `makeSegmentedControl` で、SF Symbols の
    `chevron.left`（戻る）・`chevron.right`（進む）、`trackingMode: .momentary` の2つのセグメントのボタングループを作る。各セグメントに
    「戻る」「進む」のツールチップとアクセシビリティの説明（画像の `accessibilityDescription`）を付ける。セグメントごとの有効・無効は
    `setEnabled(_:forSegment:)` で設定する
  - **メニュー**: `MainMenu.install` で「表示」の右に「移動」メニューを足し、「戻る」（`[`・⌘）と「進む」（`]`・⌘）を置く。
    `target = nil` で、`MainSplitViewController` の `goBack(_:)`・`goForward(_:)` に応答チェーンで届ける（`addSelectedFolderToFavorites` と同じ）
  - **有効・無効**: `PaneCommands` に `canNavigateHistory`（フルスクリーン中・名前の変更中は false）を足し、`HistoryNavigator` の
    `canGoBack`・`canGoForward` と AND を取る。メニューは `validateMenuItem`、ツールバーは `validateToolbarItem` と、`HistoryNavigator` の
    Observation（確認の結果や外部の変更で、イベントなしに変わるため）の両方で更新する。ショートカットはメニューの項目の検証に従い、
    無効なら何もしない。ツールバーが非表示でもメニューとショートカットは使える
- **Rationale**: 既存のツールバーのボタングループと同じ作りにし、見た目と幅を揃える（FR-045）。Finder と同じ位置とキーにする
- **Alternatives considered**:
  - `NSToolbarItemGroup`: 既存の項目が1つの `NSToolbarItem` に `NSSegmentedControl` を載せる作りのため揃えない
- **GUI で確かめること**: ボタンの位置・アイコン・淡色表示・ツールチップ・VoiceOver の読み上げ、JIS キーボードでの ⌘[・⌘]

## R78. 検証の方針（憲章 II・IV、SC-028〜SC-032）

- **Core のテスト**（Swift Testing）:
  - `NavigationHistory`: 記録（同じ状態の無視・分岐・上限 100・現在がない状態）、サイズのまとめ、移動、候補の取り除き、置き換え、
    名前の変更、配下の取り除き、隣り合う同じ履歴のまとめ
  - `HistoryLocation`: 同一の判定（末尾の `/`・`.`・`..`）、配下の判定（兄弟の前方一致を含まない・zip の中・ルート `/`）
  - `BrowserModel`: `onLocationEvent` の理由と `leavingFocus`、`resolveHistoryLocation`（R73 の各場合）、`showHistoryLocation`（R74）、
    `ArchiveIndex.containsDirectory`
  - `HistoryNavigator`: 戻る・進むの一連の流れ、見つからない場所を飛ばす・すべて見つからない、連打、確認中のユーザーの移動、
    検索結果の表示中、取り除きの各契機、`.relocated`・`.notFound`、表示の状態の復元（スタブの `HistoryPresentationHost`）
- **性能**: 10,000 ファイルのフォルダから別のフォルダへ移ってから `goBack()` し、10,000 ファイルのフォルダの最初の項目が 1 秒以内に
  表示されること（SC-029・SC-003 と同じ基準）を `MediaViewerPerformanceTests` で確かめる。履歴の操作そのものは 100 件の配列の操作のため計測しない。
  SC-029 の「操作が 100ms 以上止まらない」は自動テストで測らず、quickstart.md の 22 で Instruments（Hangs のトラックとメインスレッドの
  CPU の使用）を使って確かめ、validation.md に記録する（/speckit-analyze の指摘 G1）
- **GUI**（quickstart.md）: ツールバーのボタン・メニュー・ショートカット、ツリーの同期、表示の状態の復元、外部の削除の飛ばし、
  名前の変更中・フルスクリーン中の無効、検索結果の表示中の ⌘[（zip の中で始めた検索を含む）、ボリュームの取り外し（EC-65）、再起動での消去
