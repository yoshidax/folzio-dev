# Validation: 候補のローカル確認から公開へ

このガイドは実装後の確認手順。設計段階で本番設定・push・タグ・Release 作成は行わない。

## Cloud と macOS CI

```bash
scripts/dev/check-all.sh
```

一時 Git と API / gh stub で通常 push の省略、リリース要求、候補の run / head / tree の照合、
無差分、古い source、public base の競合、API 障害、タグと Release の保護を検証する。
実 build / test と package の macOS 回帰は開発用 CI で確認する。
実装 PR のマージ前には既存どおり make-app → 起動スモークを保守者が確認する。

## リリース PR の作成

1. 実装の導入後、保守者が未使用 version / 数字の build_number / ノートのパスを release.json に記載する。
   ノートも同じ PR にコミットする。通常の開発 PR では公開用が変わらないことを確認する。
2. リリース PR の Actions にある確認用ビルドが成功するまで待つ。
3. Actions の該当 run の Summary → Artifacts から、PR と head SHA に対応する artifact を取得する。
   artifact の外側の ZIP を展開し、内部のアプリ ZIP、SHA256SUMS、candidate.json を取り出す。

## ローカル PC での確認

Apple silicon / macOS 15 以降の PC で、取り出したファイルのディレクトリから実行する。

```bash
shasum -a 256 -c SHA256SUMS
ditto -x -k Folzio-vX.Y.Z-macos-arm64.zip extracted
codesign --verify --deep --strict extracted/Folzio.app
open extracted/Folzio.app
```

- candidate.json の PR・head SHA・version / build が今のリリース PR と一致することを確認する。
- 3ペイン、アプリ設定による日英の切り替え、内部キーの混在がないこと、About の version を確認する。
- Gatekeeper で止まる場合は README の未公証アプリの開き方を使い、確認結果を記録する。
- PR に変更が入ったら新しい run の候補を取得し直して確認する。
- 確認した最新候補の PR を保守者がマージする。候補の取得・起動をスキップして完了にしない。

## マージ後の公開

1. 開発用の同期 workflow で、候補との tree 一致、検証成功、source SHA → public SHA の対応を確認する。
2. 公開用 main の push が配布 workflow を起動し、対象 public SHA のタグとドラフトを作ることを確認する。
3. ドラフトの ZIP / SHA256SUMS / ノート・両バージョンと出自を確認する。
   最終 ZIP もダウンロードし、必要な GUI と Gatekeeper の最終確認を記録して公開する。

## 復旧

- 候補なし・失効・tree 不一致: 元の PR を更新して候補を再生成し、ローカルで再確認する。
  すでにマージ済みなら release-candidate の手動実行で default branch の候補を作り、
  取得・ローカル確認後、その run ID を指定して sync-public を手動実行する。
- 同期前のテスト失敗: 公開用 main が変わらないことを確認して原因を修正する。
- 無差分: 重複コミットを作らない。配布の再試行が必要なら公開用の元の run を再実行する。
- 公開先競合・古い source: force は使わず、対象と公開済み内容を確認して再度候補を用意する。
- タグのみ残った失敗: 同じ public SHA の元の run を再実行する。
- 同名 Release: 自動上書きしない。担当者が不完全な draft を修復または削除してから再試行する。
- Actions 全体の障害: 日本語の運用文書のローカル prepare / draft を復旧用に使う。

初回 App・Secret と公開用 main の保護規則は、運用文書の設定手順で保守者が整える。
実確認の結果は tasks.md に追記し、未確認の項目は未チェックにする。
