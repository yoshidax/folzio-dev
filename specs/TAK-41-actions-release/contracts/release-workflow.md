# Contract: リリース PR、同期と配布

## リリース PR と候補の検証

- release.json とノートを変更する PR をレビューし、CI の確認用 ZIP を保守者がローカルで試してからマージする。
- PR の検証と候補ビルドには公開先の Secret を渡さない。
  `.github/workflows/release-candidate.yml` は release.json の差分がある PR の公開用ツリーを検証する。
- source は PR のテスト用 merge SHA に固定する。PR の head と base も記録する。
  `docs_private/repository-and-release.md` の master 追従不要の規則は変更しない。
- 候補 CI は静的な公開検査 → swift build → Core / App 通常テスト → 性能テスト → check-no-network → package の順。
  通常・性能テストは順に実行し、それぞれ10分、job 全体は30分を上限とする。
- 性能テストは既存 CI と同じ continue-on-error。成功・失敗・タイムアウトとログを metadata / summary に残す。
  性能テストの失敗後も通信 API 検査へ進む。性能以外の必須検査が失敗したら直ちに非ゼロ終了し、
  後続の検査・package・artifact 確定を行わない。
- 必須検証に成功した場合に ZIP / SHA256SUMS / candidate.json を30日保持する。
  検証結果は source と公開 tree に結び付け、単に workflow 全体が success であることだけで代用しない。

## 開発用の同期判定

管理元 `.github/workflows/sync-public.yml`。master push と workflow_dispatch に対応するが、
通常の master push は Ubuntu の判定だけで終了する。PR の未マージコードから公開先へ書き込まない。

1. push の before / after で release.json の差分を検出する。比較元が不明なら失敗、all-zero before は空とする。
2. マージ済みリリース PR とその merge commit を API で照合し、その完全な SHA を対象 M とする。
   PR の base が master、merged が true、要求の変更を含むことを検証する。
   後で master が進んでも M に固定し、通常 PR のマージ結果を同じ要求の公開対象として扱わない。
3. PR の最新 head の成功した候補 run を API で特定し、M からの公開 tree と比較する。
   候補の必須検査の成功、version / build / toolchain・artifact の digest も照合する。
4. 一致した場合は候補 CI の検証を再利用する。同期では Ubuntu 上の exporter と静的検査のみ行い、
   build・通常テスト・性能テストをもう一度 macOS で実行しない。
5. 不一致・候補欠落・期限切れの場合は、この run の条件付き macOS job で M の候補を生成する。
   必須検査と package は候補 workflow と同じ共通処理を使う。
   新 artifact と M を summary に表示して「ローカル確認待ち」とし、writer は起動しない。
   これは通常起こり得る分岐であり、候補の生成成功を同期成功とは表示しない。
6. 保守者が新候補を確認後、M とその candidate_run_id を指定して同期を手動再開する。
   この入力を候補確認後の進行操作とし、再開では同じ M と公開 tree を再照合する。

必須読み取り権限は自リポジトリの contents read / actions read / pull-requests read。
PR preview、同期内の候補再生成、手動の候補生成で共通の検証・パッケージ処理を使う。
通常経路の macOS 実行は候補 CI と公開用の最終ビルドの2段階。
マージ結果が異なるときの追加ビルドは、別のコードを再確認するためにだけ行う。

## 同期の書き込みと競合

- exporter は `scripts/dev/export-public.sh SOURCE_SHA OUTPUT_DIR`。既存の OUTPUT_DIR は拒否する。
  除外・README 調整・workflow 配置・混入・公開されない文書へのリンクを検査する。
  HOME / 実行ユーザーとホームパス表現の静的検査を維持する。
- 同期判定の開始時に公開用 main を取得し expected_public_base として固定する。
  検証済みの公開ツリーと照合情報を同じ run の artifact で writer へ渡す。
- Ubuntu writer だけに App Secret を渡す。archive の digest・M・tree を検証し、受け取ったソースを実行しない。
  公開用 main を唯一の親にした1コミットを作り、Development-Commit trailer に M を記録する。
- 同期に repo 共通の workflow / job concurrency group を設定しない。
  cancel-in-progress: false だけでは pending が後続 run に置換されるため、待機列として使わない。
  通常 push と別リリースが、待機中のリリースをその仕組みで取り消さないようにする。
- 書き込み直前に public main と source trailer を再取得し、expected_public_base と祖先関係を照合する。
  tree が同じなら重複コミットなしで終了。公開済み source より古い対象は拒否する。
  base の変更は競合として停止する。更新自体も通常の非 force push とし、並行更新が先に成功すれば非 fast-forward で拒否する。
- 競合した run は理由を表示して再実行できる状態を残す。自動的な取り消し・reset・競合統合・force はしない。
  writer helper は `scripts/dev/sync-public.py` とし、一時 Git と API adapter で状態遷移を検証する。

## 手動実行の入力

workflow を起動する ref は default branch に限るが、処理対象は次の入力で決定する。
checkout するコードの SHA と、起動時の GITHUB_SHA が同じだとは仮定しない。

| workflow | 入力 | 制約 |
|---|---|---|
| release-candidate.yml | source_sha | 必須。40桁の完全な commit SHA。省略して HEAD を使わない |
| sync-public.yml | source_sha | 必須。同上 |
| sync-public.yml | candidate_run_id | 必須。保守者が確認した候補を含む run |
| sync-public.yml | bootstrap_public_base | 初回だけ使用する公開用 main の完全な commit SHA。既定は空 |

- 手動 source_sha は取得済み origin/master の祖先であり、マージ済みリリース PR の merge commit に一致すること。
  M の後の通常 PR のコミット M+3 は、master の祖先でもリリース PR の対象でなければ拒否する。
- 候補の source_kind が pr-preview の場合は、PR の head と対象 M の関係、公開 tree を API と再生成で照合する。
  merged-source の場合は候補の source_sha が入力 M と完全一致すること。
- 有効な候補の出所は release-candidate.yml、または sync-public.yml の rebuild-candidate job に限定する。
  repo / workflow / run / attempt / job の必須検査の結果、metadata と artifact の digest を API と照合する。
  異なる attempt の混在・複数の曖昧な候補は拒否する。
- 手動の候補も `release-candidate-<source_sha>-<run_id>-<run_attempt>` の artifact 名とする。
  PR イベントの有無で名前を切り替えない。具体的な取得・再開用の値を summary に示す。

## 初回移行

- 公開用 main に Development-Commit がない場合、自動経路は初期化待ちとして writer を起動しない。
- 保守者が現在の公開用 main の完全な SHA を取得し、確認した候補と M に加えて
  bootstrap_public_base を指定して sync-public を手動実行する。
- 入力なし・実際の public main と不一致・形式不正なら公開用を変更しない。
  一致した場合だけ、その base を親として初回の source trailer を付ける。
  初回に限り tree が同じでもこの対応付けコミットを1つ作り、以後は無差分で省略する。
- 初期化でも M・候補・run・tree の検査を省略しない。すでに source trailer がある場合は
  bootstrap_public_base の指定を拒否して通常の祖先判定を行う。
  不正・複数・解決不能な trailer を「初回」と見なして保護を回避しない。

## 認証・保護規則

公開用 folzio だけに App をインストールし、Contents write / Workflows write を許可する。
開発用の PUBLIC_SYNC_APP_CLIENT_ID と PUBLIC_SYNC_APP_PRIVATE_KEY を設定し、writer だけが短期トークンを作る。
owner / repositories を明示し、job 終了時の revoke を有効にする。
公開用 main の保護が更新を拒否する場合は停止し、迂回設定を自動追加しない。
App の push を公開用の push workflow につなぐ。

## 公開用 workflow とツール

管理元 `scripts/dev/oss-workflows/release.yml` → 公開先 `.github/workflows/release.yml`。
公開 repo / default branch の push と手動起動。checkout は公開側のイベント SHA、fetch-depth 0、persist-credentials false。
preflight は Ubuntu / contents read、配布は macos-15 / contents write。

- release.py plan は metadata・イベント・既存タグと Release を確認し、push の同一要求は省略する。
  API の404だけを不存在とし、検証済みの1行の値だけを出力する。
- `scripts/package-release.sh VERSION BUILD_NUMBER SOURCE_DIR OUTPUT_DIR` は確定した公開ソースを隔離コピーし、
  arm64 の make-app を実行する。既存 OUTPUT_DIR は拒否し、失敗時は一時物を除く。
  候補では exporter の tree、最終配布・ローカル復旧では公開済み SHA の archive を SOURCE_DIR にする。
  ZIP のトップレベルは Folzio.app のみ。生成直後と再展開後の両バージョン・署名・arm64・日英を確認し、
  ZIP と SHA256SUMS の2ファイルだけを成功時に確定する。
- release.py draft は状態を再確認し、タグがなければ対象 SHA へ作る。同一 SHA の軽量・注釈タグだけ再利用する。
  既存 Release は拒否し、gh release create に --repo / --verify-tag / --draft / --notes-file を指定する。
  ノートと summary に出自を記載する。

公開用 job は Xcode 16.0 / arm64 を確認し、通常テスト（10分）と最終 package を実行する。job 全体は30分。
性能テストは候補 CI で実行済みなので同期・最終配布では繰り返さない。
PR 候補と最終ビルドの公開 tree・バージョン・ツールチェーンを一致させ、ZIP のバイト列自体の一致は要求しない。
公開側の concurrency は公開 repo + 公開 SHA とし、異なるリリースを同じ group に入れない。

## 復旧

対象 M は失敗した run の summary から取得する。現在の master HEAD を代用しない。
候補生成が必要なら release-candidate を source_sha=M で起動し、取得・再確認後に同期へ M とその run ID を渡す。
配布だけの失敗は公開用の元の run を再実行し、同期コミットを増やさない。
不完全な draft は保守者が修復・削除して再試行し、公開済み Release の更新は新しい version を使う。
Actions 全体の障害では既存 release-distribution.sh prepare / draft を復旧用に維持する。
publish.sh は通常経路から外し、残す場合も共通 exporter へ委譲する。
