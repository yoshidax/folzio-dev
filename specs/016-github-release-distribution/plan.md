# Implementation Plan: GitHub Releases での配布

**Branch**: `016-github-release-distribution` | **Date**: 2026-10-29 | **Spec**: [spec.md](spec.md)

## Summary

既存の書き出しに続き、公開用の固定コミットから arm64 アプリを隔離してビルド・ZIP 化し、成果物と公開済みタグを検証して GitHub Release のドラフトを作成する。公開用コミット・push と GUI 確認は担当者が行う。

## Technical Context

**Language/Version**: Bash、Swift 6、macOS 15 以降
**Dependencies**: Swift Package、macOS 標準ツール、Git、配布時の GitHub CLI。アプリへの外部依存追加なし。
**Storage**: 一時作業ディレクトリと `.build` 配下の配布成果物
**Testing**: Swift Testing、シェル手順の一時 Git リポジトリとスタブによる検証、ユーザーによる GUI 確認
**Constraints**: 開発専用成果物は export-ignore、アプリは通信しない。`git push` 禁止。公開用リポジトリのコミット・push はユーザー担当。

## Constitution Check

I: 配布者が CLI で明示的に通信するのみでアプリはオフライン。II・III: アプリの性能・入力は変更しない。IV: ビルドと既存テスト、配布手順の異常系と GUI を検証。V: 既存ツールを再利用し CI や自動更新を追加しない。仕様管理: feature に変更を記録し、完了後に Living spec へ反映する。

## Project Structure

- `scripts/publish.sh`: 既存の公開用書き出しを維持。
- `scripts/` の開発専用配布スクリプト: 公開済みコミットとタグを確認、隔離ビルド、検証、ドラフト作成。`.gitattributes` と書き出し検査に除外を追加。
- `scripts/make-app.sh`: 開発用途を維持しつつ配布時のバージョンと arm64 指定を支援。
- `scripts/tests/`: 一時リポジトリとスタブを使う安全な失敗系の検証。
- `README.md`、`README.ja.md`: 対応環境とインストール案内を同期。
- `docs_private/repository-and-release.md`: 担当分担と操作手順。
- `specs/016-github-release-distribution/quickstart.md`: 自動検証・GUI の受け入れ手順。

**Structure Decision**: 開発用ツールは公開版へ出さず、公開版からアプリをビルドする機能は公開版にも存在する `make-app.sh` に置く。

## Design

1. 公開先の Git 作業ツリー、GitHub リポジトリ、公開コミットの一致を検証し、公開コミットから一時ディレクトリにソースを展開する。追跡外ファイルや過去の `.build` は混ぜない。既存の公開元検査と破壊防止を維持する。
2. 配布バージョンとビルド番号を明示的に指定し、公開用ソースから arm64 release ビルド、バンドル構築、ad hoc 署名を行う。既定の開発ビルドは既存動作を維持する。
3. `ditto` で ZIP を作り、展開後の plist、`lipo`、`codesign` と SHA-256 を検査する。成果物にコミット ID とバージョンを対応付け、ドラフト作成直前に検証し直す。
4. ユーザーが公開用コミットとタグを push。ツールは明示したリポジトリとリモートタグが同じコミットを指すことを検証し、`gh release create --verify-tag --draft` で ZIP、チェックサム、ノートを登録する。自動上書きや公開は行わない。
5. GUI はユーザーによる `.app` の起動と配布 ZIP の展開後の起動を個別に記録。実ネットワークの Release ドラフト作成は副作用を伴うため本番で自動実施しない。

詳細なコマンドと失敗時復旧は実装時に quickstart と運用文書に整える。既存 `app-bundle.md` の固定バージョン契約は、開発用の既定値を維持し配布用の指定値を追記する形で完了後に反映する。

## Complexity Tracking

憲章への違反なし。隔離ビルドと成果物の再検証はソースと配布物の対応を維持するために必要。

## Contract impact

`specs/product/contracts/app-bundle.md` のバージョンの固定値は開発ビルドの既定値として維持し、配布時の指定値・タグとの一致を実装検証後に追記する。タグ照合は annotated tag の参照先コミットも解決して行う。
