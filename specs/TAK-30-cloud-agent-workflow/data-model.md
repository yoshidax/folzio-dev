# Data model

## エンティティ

- **Linear Issue**: 作業の単位。番号 `TAK-nn` が feature ディレクトリ名の接頭辞になる。
- **feature ディレクトリ**: `specs/TAK-nn-<slug>/`。`.specify/feature.json`（管理対象外）が現在の feature を指す。ブランチ名とは独立。
- **作業ブランチ**: `claude/` などの許可された接頭辞を持つブランチ。PR がマージされたら再利用しない。
- **PR**: 作業の統合の単位。CI の結果と保守者の確認を経て、保守者がマージする。スカッシュマージされる。

## Issue の状態の遷移

| 状態 | きっかけ | 更新する者 | 根拠 |
|---|---|---|---|
| `In Progress` | feature またはバグ修正に着手する | Agent | FR-188 |
| `In Review` | 保守者の依頼で PR を作った（PR のリンクも追加する） | Agent | FR-198、FR-199 |
| `Done` | 保守者がマージ後に依頼し、マージを確認できた | Agent（保守者の依頼があるときだけ） | FR-197 |

`Done`、`Canceled`、`Duplicate` の Issue は、保守者の明示的な指示なしに再着手しない（FR-197）。Linear に接続できないときは、失敗を報告し、更新できたと扱わない。

## 作業ブランチの流れ

Cloud が指定した作業ブランチ → PR を作る（保守者の依頼で） → スカッシュマージ → そのブランチは再利用しない → 次の作業は、最新の `master` から新しい `claude/` のブランチを作る（Cloud が指定した名前と別のときは、保守者の許可を得る）。

## `AGENTS.md` の規則の分類

変更前の全 14 節の区分。変更後は、見出しに【共通】【ローカル】【Cloud】を付け、先頭の一覧表と一致させる。

| 変更前の節 | 区分 | 変更後の扱い |
|---|---|---|
| プロジェクト概要 | 共通 | 変更なし |
| Issue 管理 | 共通 | 変更なし。PR を作った後の `In Review` とリンクは、Cloud の節に書く |
| コードコメント（英語） | 共通 | 変更なし |
| Phase の検証ゲート | ローカル | 見出しに区分を付ける。Cloud 版の検証ゲートは Cloud の節に書く |
| バグ修正 | 共通 | 手順 1（`bugfix/<slug>` ブランチ）と手順 5（検証ゲート）に、ローカルと Cloud の違いを注記する |
| 起動しないときの初動（AppKit / macOS） | ローカル | 見出しに区分を付ける。Cloud では保守者に依頼する旨を 1 文足す |
| AppKit UI の不変条件 | 共通 | 変更なし |
| 並列実装（worktree 標準） | ローカル | 見出しに区分を付ける。Cloud は Issue 単位で並行する旨を Cloud の節に書く |
| Codex / Spec Kit | 混在 | 下の行の単位で分ける |
| テスト | 共通 | 変更なし。Cloud では CI で実行する旨の注記だけ足す |
| 検証用コマンド | 共通 | Cloud では `swift` を使うコマンドを実行できない旨を注記する |
| 公開用リポジトリ | 共通 | 変更なし |
| README の英語版と日本語版 | 共通 | 変更なし |
| 参照 | 共通 | Cloud の手順書への参照を足す |

### 「Codex / Spec Kit」の行の単位の分類

| 規則 | 区分 | 移す先 |
|---|---|---|
| Codex の Spec Kit スキルは `.agents/skills/`、呼び出し方 | 共通 | 「Codex / Spec Kit」【共通】 |
| 標準・git・bug スキルは Spec Kit が生成する | 共通 | 同上 |
| `sdd-run-codex.sh` による Codex の自動実行 | ローカル | 「Codex の自動実行」【ローカル】 |
| `.codex/config.toml`・`.codex/rules/` は Codex 用 | 共通 | 「Codex / Spec Kit」【共通】 |
| `git push` は作業ブランチだけ。`master` への push、強制 push、削除、PR のマージは行わない | 共通 | 新しい「Git の規則」【共通】 |
| `git reset --hard`、`git clean`、sandbox・承認・ルールの無効化はしない | 共通 | 同上 |
| `merge-to-master.sh` は保守者が実行し、Agent は実行しない | 共通 | 同上 |
| GUI の起動は保守者に依頼する。非対話実行中は GUI タスクを未チェックにする | 共通 | 同上 |
| Codex の初期ワークフローは順次実装する | ローカル | 「Codex の自動実行」【ローカル】 |

### 新しく足す Cloud 専用の節

「Cloud Agent の作業【Cloud】」に、次を書く（詳細は `docs_private/cloud-agent-workflow.md`）。feature の始め方（FR-186、FR-187）、Linear の更新（FR-188、FR-199）、PR（FR-198）、ブランチ（FR-189）、CI（FR-190、FR-191）、検証ゲートの Cloud 版（FR-192）、`specs/product/` の反映（FR-193）、再着手の禁止（FR-197）。
