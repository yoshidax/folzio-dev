# Data Model: 連続選択時の画像読み込み数と不要な先読みを制御する

永続化するデータはない。いずれも `FolzioCore` の内部の型。

## ImageLoadPriority

| 値 | 意味 |
|---|---|
| `preview` | 現在のフォーカスのプレビューの読み込み |
| `prefetch` | フォーカスの前後 1 件の先読み |

## ImageLoadScheduler（actor）

| 項目 | 内容 |
|---|---|
| `limit` | 同時に実行できる読み込みの合計。既定 2（FR-233） |
| `prefetchLimit` | そのうち先読みが同時に実行できる数。既定 1（FR-235） |
| `running` / `runningPrefetches` | 現在枠を持つ数 |
| 待機者 | プレビューと先読みの別々の待ち行列（取り消しで外せる） |
| `peakRunning` | 観測した同時実行数の最大値（テスト用に読み取れる） |

規則:

- `acquire(_ priority)`: 取り消されていれば `false`。空きがあり（`running < limit`、先読みでは加えて `runningPrefetches < prefetchLimit`）待機者がいなければ即座に取得する。
  そうでなければ待機し、待機中に取り消されたら待機者から外して `false` を返す。取得後に取り消されていたら、枠を返して `false` を返す
- `release(_ priority)`: 枠を返し、空いた枠を次の待機者に渡す。順序はプレビュー、次に（`runningPrefetches < prefetchLimit` のとき）先読み
- 枠を取得できた呼び出し側だけが `release` を呼ぶ。失敗・取り消し・結果の不使用のいずれでも必ず呼ぶ（EC-166）

## PrefetchEntry（`BrowserModel` の内部）

| 項目 | 内容 |
|---|---|
| `task` | 先読みの `Task<Void, Never>` |
| `isRunning` | 枠を取得して読み込みを始めたか。引き継ぎ（FR-236）の判断に使う |

`prefetchTasks: [URL: PrefetchEntry]`（現行は `[URL: Task<Void, Never>]`）。

## 状態の遷移（先読み 1 件）

```text
待機（枠待ち） ── 取得 ──▶ 実行中 ── 完了 ──▶ 終了（キャッシュ格納、項目を外す）
   │                         │
   └─ 取り消し ─▶ 終了（何もしない）   └─ 取り消し ─▶ 完了まで枠を保持し、結果はキャッシュへ（EC-164）
```
