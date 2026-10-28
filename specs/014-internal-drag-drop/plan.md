# Implementation Plan: アプリ内ドラッグによる整理

**Branch**: `014-internal-drag-drop` | **Date**: 2026-10-28 | **Spec**: [spec.md](spec.md)

## Summary

既存のファイル操作 coordinator と確認・衝突処理を共用し、ツリーと二つのリスト表示にアプリ内ドラッグ元・フォルダ宛先を追加する。対象全体の妥当性判定を Core に分離し、操作完了後の一覧・検索・履歴・プレビューの同期を検証する。

## Technical Context

Swift 6、macOS 15+、AppKit、Swift Package、外部依存なし。Core は AppKit を import しない。ファイル操作・列挙は UI スレッド外。Swift Testing と FixtureKit を使う。既存の `FileOperationCoordinator`、`FileOperationService`、`BrowserModel`、`DirectoryTreeViewController`、`ListModeView`、`ThumbnailModeView` を調査・再利用する。大規模一覧の操作性を維持する。

## Constitution Check

- I: ローカルのみ。確認・衝突・キャンセルの既存方針を維持し、外部通信は追加しない。
- II: ドラッグ中の同期 I/O・走査を避ける。UI 応答と既存の大量項目基準を確認する。
- III: 既存のファイルリスト上のコピー・移動ペーストをキーボード手段として維持。新しいハイライトは選択を妨げない。
- IV: 判定、異常、結果の同期に Swift Testing を付け、実ドラッグと表示はユーザーが確認する。
- V: 新規依存なし。既存 coordinator と表示更新を優先する。

設計後も適合。仕様の対象外であるアプリ外との既存動作は変更しない。

## Project Structure

- `Sources/MediaViewerCore/Operations/`: 対象全体と宛先の検証、ファイル操作。
- `Sources/MediaViewerCore/Browser/`: 表示・検索・選択の更新。
- `Sources/MediaViewerApp/Tree/`, `FileList/`: ドラッグ元、宛先、ハイライト。
- `Sources/MediaViewerApp/Operations/`: 確認・衝突・結果調整。
- `Tests/MediaViewerCoreTests/`: 判定・操作・状態の回帰テスト。

## Design

[research.md](research.md)、[data-model.md](data-model.md)、[contracts/drag-drop.md](contracts/drag-drop.md)、[quickstart.md](quickstart.md) に詳細を記す。ドラッグセッションを識別し内部操作だけに新規規則を適用する。パスの字面だけに依存せず、シンボリックリンクと既存項目の同一性を考慮し、ドロップ時と実行直前に再検証する。重いファイルシステム検証はバックグラウンドで行い、ドラッグ中はキャッシュされた安全な情報で保守的に判断する。検索結果のフォルダ行も両方向で扱い、選択集合にフォルダと配下の項目が同時にある場合は拒否する。既存の外部受け口の挙動を損なわない。製品仕様への反映時に `specs/product/search.md` と実装済みの 009 の差異を照合する。

## Complexity Tracking

新規依存や憲章違反なし。既存の外部ドラッグと内部ドラッグを分離するのは、今回の適用範囲を守るため。
