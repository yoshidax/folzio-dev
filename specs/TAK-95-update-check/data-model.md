# Data Model: アップデートの確認（TAK-95）

すべて `FolzioCore`（AppKit を import しない）に置く値の型と判定。永続化するのは自動の確認の3つのキー（下記）だけ。

## AppVersion

- 3つの非負の整数（`major`・`minor`・`patch`）。
- `init?(_ string: String)`: `<数>.<数>.<数>` の形だけを受け付ける。前後の空白・先頭の `v`・4つ目の部分・数字以外は `nil`。
  - 各部分は 10 進の数字だけ（符号・空文字は不可）。`Int` に収まらない値は `nil`。
- `Comparable`: `major`、`minor`、`patch` の順に数として比べる（EC-293）。
- `description`: `"1.10.0"` の形。

## UpdateCheckResult

| ケース | 値 | 出すダイアログ |
|---|---|---|
| `updateAvailable` | `latest: AppVersion`、`current: AppVersion`、`releasePage: URL` | US96-AS1 |
| `upToDate` | `current: AppVersion` | US97-AS1 |
| `failed` | `UpdateCheckFailure` | US97-AS2 |

## UpdateCheckFailure

UI では区別しない（research.md R3）。テストで分岐を確かめるために持つ。

| ケース | いつ |
|---|---|
| `transport` | 接続できない・タイムアウト・取り消し（`UpdateTransport` が投げた） |
| `httpStatus(Int)` | 状態が 200 でない（404・403・429・5xx など） |
| `responseTooLarge` | 本文が 1 MiB を超える |
| `malformedResponse` | JSON でない、`tag_name` が文字列でない |
| `unrecognizedTag(String)` | `tag_name` が `v<数>.<数>.<数>` の形でない（EC-292） |

## UpdateSource

- `latestReleaseRequest: URLRequest`: research.md R4 の URL・ヘッダー・タイムアウト（15 秒）・キャッシュの方針を持つ。
- `releasePageURL(for: AppVersion) -> URL`: `AboutInfo.repositoryURL` に `releases/tag/v<版>` を足した URL（FR-426）。

## UpdateTransport

- `typealias UpdateTransport = @Sendable (URLRequest) async throws -> (Data, URLResponse)`
- 本番は FolzioApp の `URLSessionUpdateTransport` が ephemeral の `URLSession` で実装する。テストは固定の応答・
  エラーを返す関数を渡す。

## UpdateChecker

- `static func check(current: AppVersion, transport: UpdateTransport) async -> UpdateCheckResult`
  1. `UpdateSource.latestReleaseRequest` を `transport` に渡す。投げたら `failed(.transport)`。
  2. 応答が `HTTPURLResponse` で状態が 200 でなければ `failed(.httpStatus)`。
  3. 本文が 1 MiB を超えれば `failed(.responseTooLarge)`。
  4. JSON の `tag_name` を読み、先頭の `v` を1つ除いて `AppVersion` にする。読めなければ `malformedResponse` か
     `unrecognizedTag`。
  5. `latest > current` なら `updateAvailable`（`releasePage` は `latest` から組み立てる）、そうでなければ `upToDate`。
- 状態を持たない。二重の確認の防止（EC-291）は FolzioApp の `UpdateCheckController` が持つ `isChecking` で行う。

## 永続化する設定（SettingsStore）

| キー | 型 | 未設定・不正 | 意味 |
|---|---|---|---|
| `updates.automaticCheck` | Bool | 未回答 | 自動の確認の同意（FR-430・434） |
| `updates.lastAutomaticCheck` | Date | なし（期限切れ） | 自動の確認で結果を得た最後の時刻（FR-431） |
| `updates.lastNotifiedVersion` | String（`<数>.<数>.<数>`） | なし | 新しい版のダイアログで最後に知らせた版（FR-432） |

- `SettingsStore.automaticUpdateCheck: AutomaticUpdateCheckSetting`（`notAsked`・`enabled`・`disabled`）。`notAsked` を
  書くとキーを消す（テスト用。UI からは書かない）。
- `SettingsStore.lastAutomaticUpdateCheck: Date?`、`SettingsStore.lastNotifiedUpdateVersion: AppVersion?`。
- Bool の判定は既存の `storedBool`（CFBoolean だけを有効とする）を使う。

## AutomaticUpdateCheckPolicy

状態を持たない判定の関数群。時刻と「邪魔をしない状態か」は引数で受け取り、テストで固定する。

- `static let interval: TimeInterval = 24 * 60 * 60`
- `launchAction(setting:current:lastCheck:now:canPresent:) -> LaunchAction`
  - `current == nil` → `.none`（EC-299）
  - `setting == .notAsked` → `canPresent ? .askConsent : .none`（EC-296）
  - `setting == .disabled` → `.none`
  - `setting == .enabled` → `isDue(lastCheck:now:) ? .check : .none`
- `isDue(lastCheck:now:)`: `lastCheck == nil`、`lastCheck > now`（EC-297）、`now - lastCheck >= interval` のとき true。
- `automaticOutcome(result:lastNotified:canPresent:now:) -> AutomaticOutcome`
  - `updateAvailable(latest)` かつ `lastNotified` が nil か `latest > lastNotified`:
    - `canPresent` → 知らせる。`lastCheck = now`・`lastNotified = latest` を保存する
    - そうでなければ → 知らせない。何も保存しない（EC-296）
  - `updateAvailable` で既に知らせた版、または `upToDate` → 知らせない。`lastCheck = now` を保存する
  - `failed` → 知らせない。何も保存しない（EC-298）

## 状態の遷移（UpdateCheckController、FolzioApp）

```text
idle ──メニューで選ぶ／起動時に .check──▶ checking（項目は無効）
checking ──メニューの確認の結果──▶ 結果のダイアログ（新しい版なら知らせた版を保存）──閉じる──▶ idle
checking ──自動の確認の結果──▶ AutomaticOutcome に従って保存し、知らせるときだけダイアログ ──▶ idle
idle ──起動時に .askConsent──▶ 同意のダイアログ ──「自動で確認する」──▶ 保存して checking（自動）
                                             └─「確認しない」・Esc──▶ 保存して idle
```

- 版を取得できない、または `AppVersion` にできない場合は、項目を常に無効にし、起動時は何もしない（FR-422・EC-299）。
