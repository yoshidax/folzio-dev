# Data Model: ショートカット割り当て

永続データは `UserDefaults` の 1 キー `shortcuts.overrides` だけ。Core の型は AppKit に依存しない。

## KeyModifiers（OptionSet）

`command`・`control`・`option`・`shift`。表記の順は `⌃⌥⇧⌘`（macOS のメニューの標準の並び）。

## KeyCombination

| フィールド | 型 | 意味 |
|---|---|---|
| key | String（1 文字、または特殊キーの名前） | 押した結果の文字を小文字化したもの。特殊キー: `up` `down` `left` `right` `delete` `return` `escape` `tab` `space` |
| modifiers | KeyModifiers | 押下時の修飾キー |

- 比較は `key` と `modifiers` の等価。大文字の `key`（例 `"N"`）は読み込み時に小文字と `shift` へ正規化する
- 記録時は、押した結果の文字（`charactersIgnoringModifiers`）をそのまま `key` にし、⇧は `modifiers` に残す。記号キーは、メニューのキー等価と同じく
  **⇧が必要な文字を ⇧なしの表記で扱う**: 既存の `⌘+`（`key = "+"`、`modifiers = [command]`）は、押下 ⇧⌘= を同じ組み合わせとして解釈する。
  正規化は Core の関数 `KeyCombination.normalized(key:modifiers:)` に集め、判定する対象は US 配列の ⇧記号（`+ ? < > : " { } | ~ ! @ # $ % ^ & * ( ) _`）に限る（A-156）。
  文字キー（a〜z）の ⇧は `shift` として残す（⇧⌘N と ⌘N は別）
- 表記: 修飾キーの記号 + キー（例 `⇧⌘N`、`⌘↓`、`⌘Delete`、`⌥⌘J`）。既存のショートカット一覧と同じ記号を使う
- 保存形式: 修飾キーを `ctrl,opt,shift,cmd` の順に `+` でつなぎ、最後に key（例 `ctrl+opt+cmd+j`、`shift+cmd+n`）。解釈できない文字列は不正とする
- 検証用の述語: `hasRequiredModifier`（`command`/`control`/`option` のいずれかを含む）

## ShortcutCommandID

contracts §1 の 32 個の安定した ID（`newFolder`、`openDefault`、…）。保存形式の一部なので、改名しない。廃止した ID は読み込み時に無視する。

## ShortcutCommand

| フィールド | 意味 |
|---|---|
| id | ShortcutCommandID |
| defaultCombination | 既定の KeyCombination |
| section | `ShortcutSection`（既存。ショートカット一覧の区分と同じ） |
| alternates | 主キーが既定値のときだけ有効な別名（`zoomIn` の ⌘= のみ） |

宣言の順序が、設定ウインドウの行の順と、読み込み時の重複解消の優先を決める。

## FixedKeys / ReservedKeys

- `FixedKeys`: 文脈依存の固定キー（contracts §2）の KeyCombination の集合。割り当ての候補にできず、コマンドの既定値にもできない
- `ReservedKeys`: アプリ・OS の基本操作（contracts §3）

## ShortcutAssignments（値型）

| 操作 | 意味 |
|---|---|
| `combination(for:)` | 現在の割り当て（上書き、なければ既定値） |
| `validate(_:for:)` | `Result<Void, ShortcutAssignmentError>`。`.missingModifier`、`.reserved`、`.fixed`、`.conflict(ShortcutCommandID)` |
| `assigning(_:to:)` | 検証に通ったときだけ新しい値を返す。自分自身と同じ組み合わせは変更なし |
| `resetting(_:)` | 1 コマンドを既定値へ。既定値が他の割り当てと重複するなら `.conflict` |
| `resettingAll()` | すべての上書きを消す |
| `isOverridden(_:)` | 既定値と異なるか |
| `overrides` | `[ShortcutCommandID: KeyCombination]`（既定値と異なるものだけ） |
| `init(storedOverrides:)` | 保存値から復元（R9）。不正な項目は捨てる |

不変条件: ① すべてのコマンドが常に 1 つの組み合わせを持つ ② 現在の割り当て全体で重複がない ③ すべての組み合わせが修飾要件を満たし、固定キー・予約キーを含まない。

## 保存形式 `shortcuts.overrides`

`[String: String]`（コマンド ID → 保存形式の組み合わせ）。既定値と異なるものだけ。上書きがなければキー自体を消す。例:

```text
shortcuts.overrides = { "newFolder": "opt+cmd+j", "find": "ctrl+cmd+f" }
```

## 状態遷移（記録の UI）

```text
idle --[記録を押す]--> recording
recording --[Esc / タブ切替 / 閉じる / フォーカス喪失 / 言語変更]--> idle（割り当ては不変）
recording --[修飾キーだけ]--> recording（無視）
recording --[検証エラー]--> recording（エラー表示）
recording --[検証に通る]--> idle（保存・全表示の更新）
```
