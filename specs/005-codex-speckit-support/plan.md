# Implementation Plan: Codex での Spec Kit 開発環境

## 方針

1. 公式 CLI で Codex integration と標準・拡張スキルを生成し、既定を Claude に戻す。
2. `.codex/config.toml` とコマンドルールで sandbox／承認方針と既存の禁止操作を設定する。
3. Claude 版 increment の手順を引き継いだ Codex 用 YAML を追加する。
4. Python 標準ライブラリのランナーで公式 integration の実行ファイル差し替え機能を使い、
   Codex の JSONL を進捗ログと最終回答に分離する。CLI の終了コードと失敗イベントを維持する。
5. run／resume は Spec Kit の状態管理と対話ゲートを使う。ランナーは実行前後の run ID を照合する。
6. 外部サービスへ副作用を起こさない一時リポジトリと偽 CLI で失敗・再開を検証し、
   実 CLI のスモーク、既存アプリの検証ゲートを行う。

## Constitution Check

- 原則 I〜III: アプリコード・画像・UI を変更しない。外部通信は開発ツールの既存認証に限る。
- 原則 IV: ランナーの失敗伝播、最終回答抽出、ゲートと再開を検証する。
- 原則 V: 新しいパッケージ依存を加えず、既存 Spec Kit と Python 標準ライブラリを使う。
- 仕様管理: 本 feature に記録し、完了済み feature と Living spec は変更しない。

## Complexity Tracking

Codex は captured step では通常の最終回答、streaming step では JSONL を返す。
進捗通知を両方で利用するため実行ブリッジを置く。個人設定へのフック追加や trust の迂回を避け、
ワークフローの実行時だけ有効にする。
