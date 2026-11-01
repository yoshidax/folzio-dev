# Data Model: Shortcut Cheat Sheet

## ShortcutSection

- `id`: 安定した列挙値。`panes`, `navigation`, `files`, `search`, `images`, `playback`, `application` の7つ。
- `entries`: 固定順の ShortcutEntry。空区分は禁止。
- 見出しの翻訳は Localization が section ID から TextKey へ対応させる。

## ShortcutEntry

- `id`: 空でない安定した列挙値。カタログ全体で一意。同じキーでも対象や条件が違う操作は別ID。
- `keys`: 空でない記号表記。表示言語で変形しない。代替キーは同一項目で表示できる。
- `section`: 7区分のいずれか。各 entry は1区分だけに所属。
- 説明と条件: Localization の `ShortcutText` が entry ID から説明の TextKey と必要なら条件の TextKey へ網羅的に対応する。Core に翻訳文・AppKit・TextKey 依存を入れない。
- 項目範囲と表記は `contracts/shortcut-cheatsheet.md`。各項目の実際の操作は既存の keyboard-and-menus 契約が正本。
- 動作実行 closure、Selector、可変ショートカット設定、現在有効かどうかの判定は持たない。

## CheatSheetPresentation（App 内の所有・表示状態）

- 親 MainWindowController: 一覧 controller の任意の強参照、親終了済みフラグ。
- 一覧 controller: 通常の NSWindow、スクロールビュー、IDと対応する行、言語 observer。
- 位置・サイズ・スクロール: ウィンドウとビューに起動中だけ保持。言語更新中は先頭可視 entry ID と行内 offset を一時保持し、再レイアウト後に復元・clamp。

| 現在 | 操作 | 次の状態 |
|---|---|---|
| 未作成・親生存 | 有効な表示要求 | 作成し表示、初回配置 |
| 表示中 | 有効な表示要求 | 同じ一覧を前面化、位置とスクロール維持 |
| 非表示・親生存 | 有効な表示要求 | 同じ一覧を再表示、位置とスクロール維持 |
| 表示中 | 一覧の閉じる / ⌘W | 非表示、親は維持 |
| 任意・親生存 | 親終了 | 一覧を閉じる、親終了済み。以後の表示を拒否 |
| 任意 | 無効な表示要求 | 変化なし |
| 表示中 | 言語変更 | 文言と高さだけ更新、参照位置を復元 |

## 永続化

追加なし。起動時に一覧を自動復元しない。既存の表示言語保存を再利用する。
