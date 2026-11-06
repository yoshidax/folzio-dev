# Research: リリース PR から公開と配布へ

## R1 開始操作と master の追従

- Decision: release.json 変更 PR のマージをリリース開始にする。通常の master 更新では公開しない。
  既存の「マージ前に最新 master へ追従させない」規則は変えない。
- Rationale: 保守者が2リポジトリと任意のリリース時期・PR 起点を指定した。
  preview と実際のマージ結果の差は通常起こり得るため、差があれば M の新候補を作ってローカル再確認を待つ。
  不一致だけで復旧不能にする案や、全 PR に strict な最新化を要求する案は採用しない。

## R2 対象の固定と再開

- Decision: 同期の対象はリリース PR の merge commit M。手動候補と同期も source_sha=M を必須にする。
  候補の run と M を指定する操作を、ローカルで再確認後に進める操作にする。
- Rationale: dispatch する workflow の ref と、処理対象の SHA は別物。
  master が M+3 になっていても M を再現し、候補生成と同期の間に HEAD が進んでも内容を変えない。
  artifact 名は PR イベントに依存しない source / run / attempt で定義する。

## R3 検証と macOS の実行回数

- Decision: PR preview または固定 M の候補 CI で build → 通常テスト → 性能テスト → 通信 API → package。
  性能テストは既存 macOS CI と同じ非ブロッキングとし、結果・ログを残す。
  他の必須検査は失敗した時点で中断し、その先の検査・確定・同期を行わない。
- Rationale: `.github/workflows/macos-swift-ci.yml` は共有ランナーの測定のぶれを理由に性能を continue-on-error にしている。
  前案は FR-311（overview.md）の厳格なローカル検証をそのまま同期へ移し、CI の実情と整合していなかった。
  新しい FR-311 では性能失敗の例外と、その他の fail-fast を明文化する。
- Decision: source と公開 tree が一致した候補の必須検証を同期で再利用し、同期は Ubuntu の静的検査だけにする。
  最終配布は公開済みコミットで通常テストと package を行う。通常は macOS 2段階。
  preview と M が違う場合だけ、別のコード M を確認するために追加の候補を作る。

## R4 同期の競合と初期化

- Decision: repo 共通の concurrency group を同期に置かない。
  書き込み直前に public main と source を再取得し、固定 base・祖先関係を検証して非 force で更新する。
- Rationale: cancel-in-progress: false でも既定の pending は置換される。
  最新の GitHub には queue オプションもあるが、ここでは待機列の機能・順序・上限を安全性の前提にしない。
  通常 push によるリリースの取り消しを避け、競合は可視化して再実行できるようにする。
- Decision: trailer のない初回は自動同期せず、bootstrap_public_base を指定した手動実行だけを許可する。
  入力の欠落・不一致・初期化済みでの指定を拒否し、候補や対象の検査を省略しない。
- Rationale: 移行前の履歴に source の対応がないことを、通常の祖先保護の抜け道にしない。

## R5 認証・公開境界・配布

- Decision: exporter と package を共通化し、writer だけが公開用に限定した GitHub App の短期トークンを使う。
  PR・候補・静的検査には公開用の Secret を渡さない。Contents write / Workflows write を必要最小限とする。
- 新規依存: 公式 create-github-app-token Action は独自 JWT 署名・トークン更新を避けるため必要。
  公開用の push から先は公開用自身の GITHUB_TOKEN でタグとドラフトを作る。
- Decision: 同一 SHA のタグだけ再利用し、既存 Release は自動上書きしない。
  公開済みソースから最終ビルドするため、ローカル確認用 ZIP のバイト列の同一性は要求しない。
  公開 tree・version / build・toolchain を照合し、GUI 確認と最終公開は保守者が行う。

## R6 表記と記録

- Decision: version の各数値と build_number は、0 単独を除く先頭の0を拒否する。
  自動正規化しない。01.2.0 / 1.02.0 / 007 を受理して別タグを作ることを防ぐ。
- Decision: 文書の Feature Branch は agent/tak-41-release-design、Cloud のローカル checkout は work と区別する。
  既存要件への参照には領域ファイルを付け、FR-311（overview.md）の契約変更を反映先へ明記する。

## 根拠と確認範囲

基準は origin/master の03c80bc。リポジトリの保護規則・既存 CI・FR-311 の実文を照合した。
[GitHub の concurrency の公式資料](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency)で
pending の既定の置換動作を確認した。認証の一次資料は [背景メモ](github-publishing-proposal.md) に記載。
今回は設計文書の修正のみ。実装・workflow 起動・Secret 設定・本番の同期は行っていない。
