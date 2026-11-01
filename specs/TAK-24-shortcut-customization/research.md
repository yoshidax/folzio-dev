# Research: 設定画面でのショートカットキー割り当ての変更

## R1 割り当ての元を 1 つにする

- **Decision**: Core の `ShortcutAssignments`（コマンド ID → `KeyCombination`）を唯一の元にする。既定値はコード内の表、上書きは `UserDefaults`。
- **Rationale**: メニュー項目のキーは `MainMenu.swift`、`FileListViewController`（表示形式・サイズ・フィルタ・zip）、`MainSplitViewController`（ペインの表示・フォーカス）、
  `DirectoryTreeViewController` とコンテキストメニュー（`FileContextMenu`）に直書きされている。表示（ツールバーのツールチップ、ショートカット一覧）にも直書きの文字列がある。
  元が複数だと FR-238（表示の不一致 0）を保てない。
- **Alternatives**: 各所で `UserDefaults` を直接読む → 検証と重複判定を 1 か所にできない。却下。

## R2 メニュー項目へのキーの適用

- **Decision**: 各 `NSMenuItem` に、文言の更新で使っている `MainMenu.bind` と同じ方式で識別子 `shortcut.<コマンドID>` を付ける。`MenuShortcutApplier` が
  メインメニューと、表示中のコンテキストメニューの全項目を走査し、識別子から割り当てを引いて `keyEquivalent` と `keyEquivalentModifierMask` を設定する。
  メニューの組み立て時（4 か所 + コンテキストメニュー）は、直書きをやめて同じ関数 `MenuShortcutApplier.apply(to:)` を呼ぶ。割り当ての変更通知でも呼ぶ。
- **Rationale**: 言語切り替え（`refreshTitles`）と同じ経路で、追加の仕組みが要らない。ビューコントローラーは後からメニューに項目を足すため
  （`installViewMenuItems` など）、組み立て時にも適用しないと初回が既定値のままになる。
- **Alternatives**: メニューを全部作り直す → 状態（チェック・有効/無効の検証）を失う。却下。

## R3 記録（キーの横取り）

- **Decision**: 記録中の行にフォーカスを持つ `NSView`（`ShortcutRecorderField`）が、`performKeyEquivalent(with:)` と `keyDown(with:)` の両方でイベントを受けて `true` を返し、
  メインメニューのキー等価を実行させない。Esc（`keyCode 53`）、修飾キーだけの入力は候補にしない。記録開始時に `window.makeFirstResponder` でこのビューへフォーカスし、
  フォーカスを失う（`resignFirstResponder`）・ウインドウが閉じる・タブ切り替え・言語変更で記録をやめる。
- **Rationale**: `NSWindow.performKeyEquivalent` はキービューの階層を先に試し、その後にメインメニューを試す。階層側で `true` を返せば、メニューのキーは実行されない（EC-164）。
  設定ウインドウが key のとき、メインウインドウの操作は元々実行されない。
- **Alternatives**: `NSEvent.addLocalMonitorForEvents` → メニューに先に渡る場合があり、解除漏れのリスクもある。却下。
- **API の存在の確認（実装の最初に Apple の文書で確かめる）**: `NSView.performKeyEquivalent(with:)`、`NSEvent.charactersIgnoringModifiers`、`NSEvent.modifierFlags`、`NSMenuItem.keyEquivalentModifierMask`。

## R4 キーの組み合わせの表現

- **Decision**: `KeyCombination { key: String, modifiers: KeyModifiers }`。`key` は `NSMenuItem.keyEquivalent` と同じ文字（小文字化した文字、または矢印・Delete の特殊キーの文字）。
  `KeyModifiers` は Core 独自の `OptionSet`（command / control / option / shift）。大文字（例: `"N"`）で ⇧ を暗黙に表す既存の書き方は、解釈時に `shift` を明示する形に正規化する。
  保存は `"<修飾キーの文字順>+<key>"` の安定した文字列（例 `cmd+opt+j`）。`⌘+` は `shift` + `=` の押下だが、`NSMenuItem` では `"+"` で動くため既存どおり `"+"` として保持する（A-148）。
- **Rationale**: Core が AppKit を import しないため独自型が必要。保存は人が読めて、`NSEvent` のフラグの値に依存しない。
- **Alternatives**: `NSEvent.ModifierFlags` の rawValue を保存 → OS の将来の変更に弱く、Core が AppKit に依存する。却下。

## R5 検証の順序と対象

- **Decision**: 候補 → (1) 修飾（⌘/⌃/⌥ を含む）→ (2) 予約キー・固定キー → (3) 他コマンドとの重複。重複は「現在の割り当て」（他コマンドの上書き後の値）に対して判定する。
  ⇧だけが付く組み合わせは修飾なしと同じに扱う。
- **Rationale**: spec の FR-236・237。メッセージの優先は、利用者が直せるものを後に示す。
- **Alternatives**: 重複を相手に譲らせる（入れ替え） → 利用者が意図せず他の操作を失う。却下（保守者の方針と Issue の「入力・設定できないようにする」に沿う）。

## R6 固定キーと予約キーの一覧

- **Decision**: contracts §2・§3 に一覧を置き、Core に定数として持つ。`ShortcutCommandConsistencyTests` が、既定値どうし・既定値と一覧の重複がないことを検査する（FR-244）。
- **Rationale**: 現行の `keyboard-and-menus.md` の ⌥矢印（画像スクロール・ツリーの全展開）、⇧矢印、⌘A、Tab、Space、Return、Esc、`<` `>` を網羅する。

## R7 チートシート（TAK-22）とツールチップの表示

- **Decision**: `ShortcutEntry` に、対応するコマンド ID の配列と区切り（` / ` など）を持たせ、`keys` を割り当てから生成する。コマンドに対応しない項目（Tab、矢印、Space など）は静的な文字列のまま。
  ツールバーのツールチップは、翻訳の文言を「名前」と「キー」に分け、キーを引数として挿入する（現状は `toolbarStartSlideshowHelp` などにキーが直接入っている）。
  VoiceOver 用のラベルも同じ値を使う。
- **Rationale**: FR-238。TAK-22 の「実際の割り当てとの一致」の考慮事項を満たす。
- **Alternatives**: 一覧は既定値のまま、注記で補う → 不一致が生じる。却下。

## R8 設定ウインドウのタブ構成

- **Decision**: `NSTabView`（`tabViewType = .topTabsBezelBorder`）で 2 タブ。「一般」は現行の `makeContentView()` の内容をそのまま入れる（間隔・Tab 順・補足説明を変えない）。
  タブの切り替えで、ウインドウの高さを各タブの内容に合わせる。「ショートカット」は固定の高さ（約 480pt）で、行を `NSScrollView` に入れる。幅は 620pt のまま。
  タブの切り替えは ⌃Tab / ⇧⌃Tab（`NSTabView` の標準）に加え、タブ見出しへ Tab で移れるようにする（`canBecomeKeyView`）。
- **Rationale**: Issue の提案（独立したタブペイン）と、既存の画面を壊さないことの両立。
- **Alternatives**: `NSTabViewController`（ツールバースタイル）→ 設定ウインドウ全体の作りの変更が大きい。却下。

## R9 読み込み時の不正な値

- **Decision**: 辞書でなければ無視。未知のコマンド ID・解釈できない値・検証（修飾/予約/固定）に反する値は、その項目だけ捨てる。重複は、コマンドの宣言順で先のものを残し、後のものを捨てる。
- **Rationale**: 起動を妨げず、他の割り当てを保つ（SC-119、EC-165）。宣言順で決定的にする。

## 範囲外として決めたこと

- 修飾なしの既定値を持つ Return（名前の変更）は対象外（FR-233）。
- コンテキストメニューの項目は、メインメニューと同じコマンドとして同じ割り当てを表示する。独立した割り当てを持たない。
