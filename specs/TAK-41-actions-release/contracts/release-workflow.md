# Contract: リリース PR、同期と配布

## リリース PR

- `release.example.json` と公開ガイドを追加し、実際の release.json とノートは保守者が配布時に用意する。
- version を未使用の値へ更新する PR をレビューし、保守者が master にマージする。
- 通常の master push では公開先を変えない。release.json の内容差分を before / after で確認する。
  比較元が不明なら失敗する。初回 all-zero before は空として扱う。
- PR の validation job は要求と公開候補を検査し、公開先の Secret を使用しない。
  `.github/workflows/release-candidate.yml` の read-only CI で、公開ツリーから確認用 ZIP を作る。
  ZIP / SHA256SUMS / candidate.json を Actions artifact として30日保持する。
  通常の PR は要求差分を判定して候補ビルドを省略する。リリース PR は head 更新ごとに再生成する。
- 保守者は最新候補を取得してローカルで確認し、その後で PR をマージする。
  PR の merge 用 SHA と実際のマージ SHA の違いは許容するが、公開ツリーは一致を必須とする。
- 公開作業を開始するのはマージ後の master push または復旧用 workflow_dispatch。
  手動起動も default branch だけを許可し、対象はイベント SHA に固定する。

## 開発用の同期 workflow

管理元 `.github/workflows/sync-public.yml`。公開用へは書き出さない。

1. release.json の変更を判定する Ubuntu job（contents read、5分）。
2. 対象の merged PR と最新 head の成功した候補 run を取得し、公開 tree ID を照合する。
   候補の欠落・期限切れ・別 head・不一致なら同期を停止する。metadata だけでなく API 上の run の関係も確認する。
   読み取り job は自リポジトリの actions read / pull-requests read だけを追加し、App Secret は使わない。
3. macOS job（読み取りのみ、30分）で source SHA と公開先 base を固定し、
   `scripts/dev/export-public.sh SOURCE_SHA OUTPUT_DIR` で候補を作る。
4. 現行の除外・README 注記の調整・workflow の内容照合・混入とリンクの検査を行う。
   ホームの絶対パス検査は `/Users/`・`/home/` とユーザー名要素の組み合わせを対象とし、
   HOME / 実行ユーザーの既存検査も維持する。公開候補の違反パスをログへ示す。
5. 候補で swift build → 通常 Core / App テスト（10分）→ 性能テスト（10分）→ check-no-network。
   今回は同期前の性能テストの失敗を許容しない。
6. 検証した候補と照合情報を、同じ run の名前の決まった artifact に渡す。
7. Ubuntu の writer job（5分）で artifact の digest と source SHA を検査する。
   ソースコードを実行せず、公開先の base と公開済み source を照合してコミット・push する。
8. 新しい commit の親は公開用 main だけ。tree が同じならコミットしない。
   expected base と違う場合は停止し、force・reset・自動的な競合統合をしない。

同期 concurrency は対象 repo 単位、cancel-in-progress は false。
古い実行で新しい公開内容を巻き戻さない。公開側のコミットには Development-Commit trailer を付ける。
export-public.sh は destination が既存なら拒否し、一時候補の生成だけを行う。
書き込み helper は `scripts/dev/sync-public.py` とし、一時 Git と差し替え可能な API adapter で検証する。

## 認証・初回設定

- 公開用 folzio だけに GitHub App をインストールし、Contents write / Workflows write を許可する。
- 開発用の変数 `PUBLIC_SYNC_APP_CLIENT_ID` と Secret `PUBLIC_SYNC_APP_PRIVATE_KEY` を設定する。
- Secret は writer job の対象 master 実行だけへ渡す。トークンの owner と repositories を明示する。
- 公式 create-github-app-token Action を利用し、job 終了時の revoke を有効のまま使う。
- 公開用 main の保護が bot の更新を拒否する場合は停止する。保護の迂回設定を自動で追加しない。
  初回設定手順で bot の通常更新を許可する運用と保護規則の整合を保守者が確認する。
- App の push を公開用の push イベントへつなぎ、通常の連鎖に追加 dispatch を使わない。

## 公開用 workflow と公開ツール

管理元 `scripts/dev/oss-workflows/release.yml` → 公開先 `.github/workflows/release.yml`。
main push / workflow_dispatch、実行先が yoshidax/folzio と default branch であることを検査する。
全 checkout は github.sha、fetch-depth 0、persist-credentials false。

- `python3 scripts/release.py plan`: metadata とイベントを検証し、push 前後で要求が同一なら省略する。
  手動実行は有効な要求を必須とする。API は 404 のみを不存在と判断する。
  出力 ready / version / build_number / tag / notes_file は検証済みの1行の値だけとする。
- `scripts/package-release.sh VERSION BUILD_NUMBER SOURCE_DIR OUTPUT_DIR`: arm64 macOS で、
  呼び出し元が確定した公開ソースを SOURCE_DIR から隔離コピーし、
  make-app.sh を arm64 指定で実行する。既存 OUTPUT_DIR は上書きしない。
  PR は exporter の公開ツリー、最終配布とローカル復旧は公開済み SHA の git archive を SOURCE_DIR にする。
  ZIP のトップレベルは Folzio.app のみ。署名・両バージョン・日英リソースを生成直後と再展開後に検査する。
  ZIP と SHA256SUMS の2ファイルだけを成功時に出力確定し、失敗時は一時物を除去する。
- `python3 scripts/release.py draft OUTPUT_DIR`: checksum と metadata、GitHub の状態を再確認する。
  未作成タグは対象 SHA に作り、存在する軽量/注釈タグは commit に解決して一致を確認する。
  既存 Release は拒否し、gh release create の --repo / --verify-tag / --draft / --notes-file を指定する。
  ZIP と SHA256SUMS を添付し、ノートと実行サマリーに出自を記録する。

公開用 preflight は Ubuntu / contents read、配布は macos-15 / contents write。
既存 CI と同じ Xcode 16.0、arm64 を実行時に確認し、なければ停止する。
通常テストは必須（10分）、配布 job 全体は30分。配布ビルドでは性能テストを重複実行しない。
concurrency は公開 repo + SHA、cancel-in-progress false。別 SHA のタグ競合は API の参照再確認で止める。

## 復旧

- 確認用候補の失効・不一致は候補の再生成とローカル再確認へ戻す。
  release-candidate.yml の復旧用 workflow_dispatch で default branch の候補も生成できる。
  この場合は同期の手動実行で candidate_run_id を明示し、同じ公開 tree と成功状態を照合する。
  run ID の指定は確認後に先へ進む操作とする。
- 同期前の失敗は開発用の実行を再実行する。同期済みなら重複コミットは作らない。
- 配布だけの失敗は公開用の元の実行を再実行する。最新 main へ対象を読み替えない。
- 既存 draft の部分失敗は担当者が修復・削除してから再実行する。公開済み Release は新しい version にする。
- Actions 全体の障害時はローカル release-distribution.sh prepare / draft を維持する。
  prepare は公開済み HEAD の確認後に公開用 package-release へ委譲し、既存 CLI と release-info を維持する。
- publish.sh は通常経路から外す。残す場合は復旧専用 wrapper とし、選別処理を重複させない。
