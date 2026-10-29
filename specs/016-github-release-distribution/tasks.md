# Tasks: GitHub Releases での配布

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [quickstart.md](quickstart.md)

## Phase 1: 配布準備とドラフト

- [X] T001 [US1] `scripts/make-app.sh` に既存の開発用既定値を維持する配布バージョン・ビルド番号と arm64 の指定を追加する。
- [X] T002 [US1] `scripts/` に公開用リポジトリのクリーン状態・公開コミットを確認し、固定コミットから隔離ビルド、ZIP、SHA-256 と対応記録を生成する開発専用スクリプトを作る。
- [X] T003 [US2] T002 の成果物・メタデータ・リモートタグ・GitHub リポジトリを再検証し、上書きせず `gh release create --verify-tag --draft` を実行する操作を実装する。
- [X] T004 [US1] 開発専用スクリプトを `.gitattributes` と `scripts/publish.sh` の公開除外検査に追加する。
- [X] T005 [US2] `scripts/tests/` に一時 Git リポジトリとスタブで正常系および不一致・改変・重複・外部コマンド失敗を検証するテストを追加する。
- [X] T006 [US3] `README.md` と `README.ja.md` に対応環境、ZIP の入手・インストール、未公証時の開き方を同内容で追加する。
- [X] T007 [US2] `docs_private/repository-and-release.md` に開発用からの操作、ユーザーによるコミット・push・タグ・公開、検証と失敗時の復旧を記述する。
- [X] T008 [US1] `specs/016-github-release-distribution/quickstart.md` に実際の検証コマンドと期待結果を追記する。
- [X] T009 自動検証を実行する: T005 のテスト、`swift build`、`swift test`、`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/check-english-comments.sh`、`scripts/make-app.sh`。
- [X] T010 [MANUAL] ユーザーが `open .build/Folzio.app` で起動し3ペインを確認する。結果を `specs/016-github-release-distribution/checklists/validation.md` に記録する。
- [X] T011 [MANUAL] ユーザーが配布 ZIP を展開して Apple silicon 上で起動し、3ペイン・日英表示を確認する。ダウンロード時の Gatekeeper の確認が可能ならその結果も記録する。未実施の項目を明記する。
- [X] T012 検証後に Phase の変更をコミットする。

## Dependencies & Execution Order

T001 → T002 → T003 → T005。T004、T006、T007 は T003 までの設計に合わせて実施。T008 は T001〜T007 後。T009 → T010 → T011 → T012。実装は順次実行し、GUI の起動はユーザーが行う。
