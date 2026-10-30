# Implementation Plan: Cloud Agent 向けの開発 workflow

**Branch**: `claude/tak-30-cloud-agent-workflow` | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)

## Summary

`AGENTS.md` の各規則に【共通】【ローカル】【Cloud】の区分を付け、両方が混ざった節を分けて、ローカルと Cloud の規則が矛盾しない形にする。Cloud Agent の手順（feature の始め方、Linear の更新、PR、CI の確認、検証ゲート、完了の報告）は、非公開の運用手順 `docs_private/cloud-agent-workflow.md` にまとめ、`AGENTS.md` から参照する。権限（TAK-27）、CI（TAK-25）、Swift 6.0 でのビルド（TAK-28）はすでに実装されているので、この feature はそれらを手順に取り込み、未確認の 2 点（Agent による `workflow_dispatch` の起動、Linear へのリンクと状態の更新）をこの feature 自身の PR で実機確認する。アプリのコードとワークフロー・権限の設定は変えない。

## Technical Context

**Language/Version**: Markdown（文書）。確認用に既存の Bash・Python のスクリプトを使う
**Primary Dependencies**: Linear MCP、GitHub MCP、既存の CI（`.github/workflows/macos-swift-ci.yml`）、既存の push 検査（`scripts/dev/check-git-push.py`）。新しい依存は追加しない
**Storage**: リポジトリ内の文書
**Testing**: `AGENTS.md` の全規則の分類表との突き合わせ、既存の検査スクリプト、Cloud のセッションでの実機確認（[MANUAL]）
**Target Platform**: Cloud Agent（Linux のコンテナ）と、保守者のローカル（macOS）
**Project Type**: 開発 workflow（文書と運用）
**Performance Goals**: なし（アプリの性能に影響しない）
**Constraints**: アプリのコード（`Sources/`）を変えない。Agent は `.claude/settings.json` を編集できない。Agent は `master` への push、強制 push、PR のマージを行わない。ネットワーク API を追加しない
**Scale/Scope**: `AGENTS.md` の 14 節、新規の手順書 1 つ、`specs/product/overview.md` への反映

## Constitution Check

- I: アプリに通信を追加しない。アプリのコードは変更しない。
- II: アプリの実行経路は変更しない。
- III: UI とキーボード操作は変更しない。
- IV: 文書の変更で、コアロジックは変えない。既存の自動検証が変わらず通ることを確認し、分類表と突き合わせて規則の抜けと矛盾を検査する。
- V: 新しいスキル、スクリプト、設定項目を追加しない（R1、R2）。ほかの案を採らない理由は research.md に記録する。
- 開発ワークフローと品質ゲート: マージ前のゲート（自動テストの通過）は、Cloud では CI の成功と保守者のローカルでの確認で満たすと解釈する（A-113）。憲章は改定しない（R8）。
- 仕様の管理: feature を先に作成し、検証後に `specs/product/` へ反映して凍結する。この feature の PR に反映を含める（FR-193）。

設計後も上記を満たす。違反なし。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-30-cloud-agent-workflow/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md              # /speckit-tasks で作る
└── checklists/requirements.md
```

### Source Code (repository root)

```text
AGENTS.md                              # 区分の一覧表、見出しの区分、混在節の分割、Cloud 専用の節
docs_private/cloud-agent-workflow.md   # 新規。Cloud Agent の作業手順
docs_private/folzio-sdd-increment.md   # ローカル専用である旨と、Cloud の手順書への案内を 1 文足す
specs/product/overview.md              # 検証後に反映する（ID は spec.md の「反映先」）
```

`.claude/settings.json`、`.github/workflows/`、`Sources/`、`Tests/`、`.specify/` は変更しない。権限の設定を変える必要が見つかった場合は、Agent が編集できないため、保守者に依頼する（[MANUAL]）。

**Structure Decision**: 手順書は、既存の運用手順（`docs_private/folzio-sdd-increment.md`、`docs_private/codex-speckit.md`）と同じ `docs_private/` に置く。公開版には含まれない（`AGENTS.md` と `docs_private/` は書き出しから除外されている）。

## Verification and impact

- 分類表（data-model.md）に、変更前の `AGENTS.md` の全 14 節と、混在節の行の単位の分類を載せ、変更後の見出しと 1 対 1 で突き合わせる。
- 同じ状況に対する規則（`git push`、検証ゲート、ブランチの切り方、完了の報告）を読み比べ、矛盾する指示が 0 件であることを確かめる（SC-094）。
- ローカルの手順（`merge-to-master.sh`、ローカルの検証ゲート、worktree）の記述が、意味を変えずに残ることを差分で確かめる（SC-093）。
- Cloud の実機確認は、この feature の PR で行う。PR の作成後に、Linear へのリンクと `In Review` の更新（FR-199）、CI の自動実行（US28-AS1）、手動実行の起動（US28-AS2）を確かめる。結果は quickstart.md に記録する。
- 既存の `check-*.sh`、`scripts/dev/tests` の Python テストを実行する。公開版の README・ガイド・ソースのコメントは変更しない。

## Complexity Tracking

違反なし。
