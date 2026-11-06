# Validation: 候補のローカル確認から公開へ

実装後の確認手順。今回の設計修正で workflow 起動や本番設定は行わない。

## Cloud と macOS CI

```bash
scripts/dev/check-all.sh
```

一時 Git と API / gh stub で source / PR / run / tree、初期化、無差分、古い対象、公開先競合を検証する。
version の01.2.0 / 1.02.0 / 1.2.00、build の007を拒否し、0 単独の有効性も確認する。
候補で build → 通常 → 性能 → 通信 API → package が順に動き、
性能失敗時だけは結果を記録して続行し、それ以外の必須失敗後は後続・成果物確定・同期がないことを確認する。
通常の同期に macOS job がなく、候補の必須検証を再利用することも確認する。
実装 PR のマージ前の make-app → 起動スモークは保守者が行う。

## 通常のリリース PR

1. 未使用の version・先頭0のない build_number・ノートのパスを release.json に書き、ノートも同じ PR へ含める。
2. PR preview の CI が成功したら Summary → Artifacts から候補を取得する。
   名前は release-candidate-<source_sha>-<run_id>-<run_attempt>。外側の ZIP を展開して、
   アプリ ZIP・SHA256SUMS・candidate.json を取り出す。
3. metadata の PR / head / source / version / build / toolchain・必須検証と性能結果を確認する。
4. 下のローカル確認を行ってから PR をマージする。同期の summary にある実際の merge commit M を記録する。
   既存の master 追従不要の運用は維持するため、preview と M が異なる場合は次の再確認経路を使う。

## ローカル PC での確認

Apple silicon / macOS 15 以降の PC で、artifact を取り出したディレクトリから実行する。

```bash
shasum -a 256 -c SHA256SUMS
ditto -x -k Folzio-vX.Y.Z-macos-arm64.zip extracted
codesign --verify --deep --strict extracted/Folzio.app
open extracted/Folzio.app
```

3ペイン、日英切り替え、内部キーの混在がないこと、About の version、未公証アプリの開き方を確認する。
PR を更新したら最新候補を取得し直す。M の再候補でも metadata と source / run を照合して再確認する。

## preview とマージ結果が異なる場合

1. preview の確認後に別 PR が master へ入る場合を再現し、実際の merge commit M と tree が異なることを確認する。
2. 同期は M の候補を作り直し、「ローカル確認待ち」と表示する。公開用 main はまだ変わらないことを確認する。
3. 新しい artifact を取得してローカルで再確認する。candidate.json の source_kind は merged-source、source_sha は M。
4. sync-public の Run workflow で ref は master、入力 source_sha は M、candidate_run_id は確認した run ID を指定する。
   workflow の起動時の HEAD を source_sha の代わりにしない。
5. 同じ M の tree・必須検証を照合して同期が再開できることを確認する。

## 初回の同期

App / Secret と公開用 main の保護規則を整える。公開用の最新 SHA を保守者が確認する。

```bash
gh api repos/yoshidax/folzio/git/ref/heads/main --jq .object.sha
```

source trailer がない初回は自動経路を初期化待ちにし、source_sha=M / candidate_run_id に加え、
この完全な公開用 SHA を bootstrap_public_base に指定して sync-public を手動起動する。
入力なし・不一致・不正なら更新されず、一致時だけ初期化されることを確認する。
初期化済みの bootstrap 指定、不正 trailer を初回と解釈する入力も拒否する。
初回だけは tree が同じでも source の対応付けコミットを1つ作り、次回から通常の無差分判定を使う。

## その後の公開と復旧

- 同期が公開用 main を更新すると、公開用の通常テストと最終 package、タグ・ドラフト作成へ進む。
  最終 ZIP / checksum / ノート・出自を確認し、GUI / Gatekeeper の最終確認後に公開する。
- 候補失効・生成失敗: release-candidate を ref=master、source_sha=M で手動起動する。
  名前は PR の場合と同じ規則。再確認後、同期にも同じ M とその run ID を渡す。
- M の後に通常 PR を3件入れ、master=M+3 から上の手順で M を復旧する。
  候補と同期の手動起動の間にも master を進め、両方とも M のままであることを確認する。
- 通常 push を同期の待機中に複数流しても共通 concurrency で取り消されない構成を確認する。
  同時の writer 更新は base / source 検査と非 force push の競合として表示されることを確認する。
- 競合・古い M: force しない。公開済み対象を確認し、候補を変える場合は取得・再確認からやり直す。
- 同期済みの再実行: 重複コミットを作らない。配布だけの再試行は公開用の元の run を使う。
- タグのみ残る場合は同じ public SHA の元の run を再実行する。同名 Release は自動上書きしない。
- Actions 全体の障害時は日本語の運用文書のローカル prepare / draft を復旧用に使う。

実確認の結果は tasks.md に追記し、未確認の項目は未チェックにする。
