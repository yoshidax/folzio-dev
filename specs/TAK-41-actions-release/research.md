# Research: リリース PR から公開と配布へ

## R1 開始操作

- Decision: release.json 変更 PR の master へのマージを開始点とする。
  開発用 master の全 push を同期する案と、通常手順を手動 dispatch だけにする案は採用しない。
- Rationale: 保守者は2リポジトリを維持し、任意のリリース時期を選びたいと回答した。
  さらに release.json 変更 PR を起点にしたいと指定した。PR のレビューとマージが時期の決定になる。
- Alternatives: 全変更の同期、1リポジトリへの統合、ローカル publish の維持。

## R2 イベントと公開境界

- Decision: 開発用の PR 検証は読み取りと公開候補の検査のみ。
  master push の before / after で release.json の変更を検出し、マージ後の SHA を固定して同期する。
  復旧用 workflow_dispatch では default branch のコミットを固定し、要求が有効なら同期を試みる。
- Rationale: タグや公開コミットを PR の未マージ内容から作らない。
  on.push.paths だけに依存せず、イベントの比較元を Git で確認する。
- Alternatives: PR 作成時の公開、最新 HEAD の再取得による対象変更。採用しない。

## R3 同期と認証

- Decision: 検証 job と書き込み job を分ける。書き込み job だけが GitHub App の短期トークンを使う。
  App は公開用のみへインストールし、Contents write / Workflows write に限定する。
- Rationale: GITHUB_TOKEN の権限は実行元リポジトリに限られる。
  App の push は公開用の push workflow につながり、追加 dispatch を通常経路に要しない。
  公開 workflow の同期にも権限が必要となる。
- Alternatives: 長期 PAT、SSH deploy key と追加 dispatch、公開用に開発用全履歴をコピーする方式。
  対象限定・短期認証と運用の単純さから App を選ぶ。
- 新規外部依存: 公式 actions/create-github-app-token（調査時の公式例は v3）。
  独自 JWT 署名・トークン管理を実装しないために必要。実装時に使うリビジョンと入力仕様を確認する。

## R4 既存 publish の分解

- Decision: export-public.sh に選別・README 調整・workflow 配置・静的検査を分け、公開候補を作る。
  macOS job で候補の build → 通常テスト → 性能テスト → 通信 API 検査を行ってから公開先を更新する。
- Rationale: 現行 FR-311 の性能テストを必須から外さない。
  ローカルパス検査はランナーの HOME / ユーザー名だけでは保守者の環境を検出できないため、
  既存の検査にホームパス表現の検査を追加する案を契約で定義する。
- Alternatives: publish.sh をそのままランナーで呼ぶ。初期化・同期・ステージまで行い、
  検証前に書き出し先を変更する現行動作を GitHub 公開へ直結させないため分離する。

## R5 再実行と配布

- Decision: 無差分はコミットを作らず、公開済み source より古い候補は拒否する。
  配布は公開用 SHA に固定し、同一 SHA のタグのみ再利用、既存 Release は自動更新しない。
  package-release.sh を公開ツールとして共通化し、ローカル配布の復旧 CLI からも使う。
- Rationale: 同期の再実行と配布の再実行を区別し、確認済み ZIP とタグを保護する。
- Alternatives: 強制同期、既存ドラフトの自動修復、最終公開の自動化。不要な状態管理を増やすため採用しない。

## R6 リリース前のローカル確認

- Decision: release-candidate workflow で PR の公開用ツリーから確認用 ZIP を作り、
  SHA256SUMS と候補 metadata を同じ Actions artifact として30日間保持する。
  保守者は取得した ZIP をローカルで試し、最新の候補を確認してからマージする。
- Rationale: 保守者は CI ビルド成果物をローカル PC で確認できる仕組みを明示的に求めた。
  マージを確認後の進行操作とし、独自の承認システムは追加しない。
- 同等性: PR のテスト用 merge コミットと、実際の master の公開用ツリーの Git tree ID を照合する。
  元の commit SHA 自体は squash merge で変わり得るため一致条件にはしない。
  CI run と PR head の関連も検証し、別 run の自己申告 metadata だけを信用しない。
- Alternatives: ローカルで再ビルド、マージ後に初めて確認、自動テストだけで公開。要望を満たさない。
  確認用 ZIP のそのままの昇格も検討したが、FR-170 に沿って公開済みコミットから最終ビルドする。
  公開ツリー・ツールチェーン・ビルド条件を一致させ、ZIP のバイト列の同一性までは要求しない。

## 根拠

現行ソースと仕様は 03c80bc。リポジトリ情報で公開先 yoshidax/folzio / main を確認した。
一次資料のリンクと背景は [設計変更メモ](github-publishing-proposal.md) を参照。
実 Actions、認証設定、同期 push、タグ・Release の作成は未実施。
