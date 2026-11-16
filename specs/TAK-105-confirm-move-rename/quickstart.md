# Quickstart: 操作ごとの実行前の確認の設定

## 自動の検証

```bash
swift build
swift test
scripts/dev/check-all.sh
scripts/make-app.sh
```

- `ConfirmationPolicyTests`: 操作4種 × ペイン2種の `target` と、親ウインドウなしの扱い（data-model.md の表）
- `SettingsStoreTests`: 既定値、5つの独立した保存、旧キーからの引き継ぎ（オン・オフ・不正な型・未設定）、
  旧キーを書き換えないこと、変更の通知
- `SettingsTextTests`: 5つの文言と補足説明の日英
- `ConfirmationPresenterTests`: SC-216 の25の組み合わせ、「今後この確認を表示しない」がその操作だけを止めること、
  ツリーのゴミ箱にはそれを出さないこと、親ウインドウなしの移動・名前の変更は確認を経ること

## GUI の確認（保守者）

古い Folzio を終了してから `open .build/Folzio.app` で起動する。

1. **設定ウインドウ**（US85-AS1・US40-AS1〜AS4）: ⌘, の「一般」の「ファイル操作」に5つのチェックボックスがこの順に並び、
   最後のチェックボックスの下に補足説明が小さく淡い文字で、文言の先頭に揃って出る。英語表示でも同じ構造。
   区分の間隔と項目の間隔が他の区分とそろい、ウインドウの下の余白が上の余白と同じ。Tab で
   ループ → コピー → 移動 → 名前の変更 → お気に入りから削除 → ゴミ箱に入れる → 切り替え間隔 と移る。
2. **移動だけオフ**（US85-AS2・AS3）: 「移動する前に確認する」だけをオフにし、ファイルをツリーのフォルダへドロップすると
   確認なしで移動する。コピー（Option ドロップ）・名前の変更・ファイルリストのゴミ箱では確認モーダルが出る。
3. **名前の変更だけオフ**（US85-AS4）: ファイルリストのファイルとツリーのフォルダの名前を変えると確認なしで変わる。
   拡張子を変えると拡張子の確認は出る。
4. **ツリーのゴミ箱**（US85-AS5）: 「ゴミ箱に入れる前に確認する」をオフにしても、ツリーのフォルダのゴミ箱では
   確認モーダルが出て、「今後この確認を表示しない」は出ない。
5. **今後この確認を表示しない**（US85-AS6・AS7）: すべてオンに戻し、設定ウインドウを開いたまま移動の確認モーダルで
   「今後この確認を表示しない」をオンにして実行すると、設定ウインドウの「移動する前に確認する」だけがその場でオフになる。
6. **移行**（US85-AS8・AS9）: Folzio を終了し、次のコマンドで以前の版の状態（確認をオフ）を作ってから起動し、
   設定ウインドウを開く。コピー・お気に入りから削除・ゴミ箱に入れるはオフ、移動・名前の変更はオンで表示される。
   このコマンドは `.app` で起動したときの実際の設定（ドメイン `local.folzio.Folzio`）を書き換える。
   確認の後、設定ウインドウで好みの状態に戻す。

   ```bash
   for k in copy move rename removeFavorite trash; do defaults delete local.folzio.Folzio fileOps.confirm.$k 2>/dev/null; done; defaults write local.folzio.Folzio fileOps.confirmBeforeExecuting -bool false
   ```

## 検証の記録

- 2026-11-16（macOS 26.7.3、ローカル）: `swift build` 成功。`swift test` は 1138 件（124 スイート）と性能 28 件が成功。
  - 2回目の全体実行で `ThumbnailProvider` の zip 内サムネイルのキャッシュの2件が失敗した（`again === thumbnail`）。
    単独では2回とも成功し、3回目の全体実行でも成功した。この feature は該当のコードを変えていないため、負荷による不安定さと
    判断した。
  - `scripts/dev/check-all.sh` 成功（終了コード 0）。`scripts/make-app.sh` で `.build/Folzio.app` を作成した。
