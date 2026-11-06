# スクリプトと公開書き出しの契約

- 公開用スクリプトの既存の `scripts/<name>` パス、引数、動作を維持する。
- 開発専用スクリプトは `scripts/dev/<name>` で実行し、従来の引数を維持する。
  - 子ディレクトリを含む関連ファイルも同じ境界に置く。
- `git archive` は `scripts/dev/` を除く。公開スクリプトは開発専用ファイルを必要としない。
- 公開処理は混入を検出すると公開先の初期化・同期・ステージの前に非ゼロ終了する。
- 公開候補の CI は build・Core / App の通常テスト・性能テスト・通信 API 検査を順に行う（FR-311）。
  - 性能テストは他のテストと同時に実行しない。
  - 性能の失敗・タイムアウトは結果とログを候補に記録し、後続の必須検査を行う。
  - 他の必須検査は失敗時に非ゼロ終了し、後続検査・成果物確定・同期・ステージングを行わない。
  - 同期では公開 tree が一致する候補の成功結果を使い、macOS の build とテストを繰り返さない。
- 移動先から実行した場合も各スクリプト・テストはリポジトリルートを正しく求める。
- `git archive` は開発用の workflow（`.github/workflows/` 全体）を除く。
  - 書き出しに含まれていれば、混入として同期の前に非ゼロ終了する（FR-289・FR-293）。
- 公開用の workflow は、固定した対象コミットの `scripts/dev/oss-workflows/` の直下にある通常ファイルのうち、
  名前が `.yml` または `.yaml` で終わるものだけを、同じ名前・内容で書き出しの `.github/workflows/` に置く。
  - サブディレクトリの中、シンボリックリンク、ほかのファイルは置かない。
  - 定義がなければ `.github/workflows/` を作らない（FR-291）。
- 置いた workflow の名前の集合と内容が管理元と一致しなければ、同期の前に非ゼロ終了する（FR-293）。
  - 置いた workflow の名前（なければそのこと）を表示する。
- `$HOME`・ユーザー名の検査は、公開用の workflow を置いた後に行う。
  - 公開先の `.github/workflows/` は同期で保護せず、書き出しを繰り返すと管理元と一致する（FR-292）。
- `git archive` の展開の後、書き出しの `README.md` と `README.ja.md` から、開発用リポジトリの注記を除く（FR-314）。
  - 範囲は、行の全体が `<!-- dev-repo-note:start -->` の行から `<!-- dev-repo-note:end -->` の行まで（両方を含む）と、
    終了の印の直後の空行 1 行とする。
  - 処理は `scripts/dev/strip-readme-dev-note.sh` で行い、開発用リポジトリの作業ツリーの README は変えない。
  - 末尾の改行の有無は変えない。
  - 印の対応が崩れているか、印の文字列が残れば、公開先の初期化・同期・ステージの前に非ゼロ終了する（FR-315・EC-215）。
  - 印の行の改行が CRLF の場合と、README がない場合も、同じく非ゼロ終了する。
  - 印がなければ、README を変えない（EC-216）。

## リリース要求と候補

- 開発用 workflow は `.github/workflows/release-candidate.yml` と `.github/workflows/sync-public.yml` とする。
  - 前者は PR と手動の候補生成、後者は master push の判定と手動同期を担う。
- 公開用は `scripts/dev/oss-workflows/release.yml` を書き出し、公開用 main の push と手動実行に使う。
- 候補・最終配布の macOS job は arm64 / Xcode 16.0（Swift 6.0）を使い、全体を30分に制限する。
  - 通常テストと候補の性能テストは各10分に制限する。

- 通常の公開は開発用の `release.json` 変更 PR から始め、通常の master 更新では同期しない（FR-332）。
- 要求は文字列の version・build_number・notes_file の3キーだけとし、未知・重複キーを拒否する（FR-324）。
  - version は先頭0のない X.Y.Z、build は先頭0のない数字とし、0単独は許可する。
  - ノートは `release-notes/` 以下の非空白 UTF-8 Markdown とする。
  - 絶対パス・空要素・`.`・`..`・symlink を拒否し、コミット済みの通常ファイルを使う。
- `export-public.sh SOURCE_SHA OUTPUT_DIR` は固定 SHA の公開ファイルを生成し、既存出力を変更しない（FR-334）。
  - 除外・README 注記除去・公開 workflow 配置・混入検査を共通化し、検査の成功後だけ出力を確定する。
  - Tests の仮想ホームは `/test-homes/` を使い、ホーム検査に fixture のユーザー名の例外を設けない。
  - README の構造は対象コミットの `check-readme-sync.sh --structure-only EN_FILE JA_FILE` で共通検査する。
  - 標準 CI アカウント runner / runneradmin は通常の文章から検出せず、ホーム・個人パスは引き続き拒否する。
- 使用済み version は PR 検証・同期判定と、公開先の更新前に拒否する（FR-324）。
  - read-only の検証は公開用のタグと参照できる Release を照合する。
  - writer は公開先 App の権限でドラフトも含む一覧を再照合し、公開用 main の更新前に拒否する。
- 候補は公開ファイルから共有の package を実行し、ZIP・SHA256SUMS・candidate.json・性能ログを保存する（FR-340・341）。
  - artifact 名は `release-candidate-<source_sha>-<run_id>-<run_attempt>`、保持は30日とする。
  - metadata に PR・head・base・source_kind・source SHA・public tree・両バージョン・toolchain を記録する。
  - 必須検査と性能の結果、run / attempt / URL も記録する。

## 固定対象の同期

- 同期対象 M は master に含まれるリリース PR のマージコミットとし、後続の変更を混ぜない（FR-333）。
  - 手動の候補生成は source_sha、手動同期は source_sha と candidate_run_id を必須にする。
  - workflow のコードは default branch を使い、入力 M を起動時点の HEAD に置き換えない。
  - exporter と package 自体も M に含まれる版を使い、後続の規則変更で M の公開 tree を変えない。
- 候補は API の repo・workflow・run・attempt・必須 job / step・artifact digest と照合する（FR-338・342）。
  - PR preview は merged PR の最新 head に対応し、M の公開 tree と一致する場合だけ再利用する。
  - 固定 M の候補は source_sha が完全一致し、要求・tree・toolchain・必須検証も一致しなければならない。
  - 不一致・欠落・失効時は M の候補を再生成し、ローカル再確認後の M/run 指定を待つ。
  - 候補の attempt は、最後に実際の build を行った job に結び付ける。
  - API が未再実行の job を複製した場合、ランナー・実行時刻・全 steps の一致から元の生成 attempt を確認する。
  - 新しい実 build が失敗した場合は、古い成功候補へ戻らない。
  - 確認待ちは専用 job の failure / Not published で示し、同期の成功と区別する。
  - その run の候補を使う場合も必須 job の成功を確認し、待機以外の失敗があれば拒否する。
- job 間の入力 artifact は、生成 job の出力 ID で引き継ぐ。
  - 部分再実行では元の出力を利用し、受取側の現在の attempt 番号から名前を組み立てない。
  - 読み取り専用トークンと run ID による REST 取得を使い、展開先を固定する。
- writer は App の公開先限定トークンだけを受け取り、照合済み archive と plan を検証する（FR-337）。
  - PR・候補・判定には App Secret を渡さず、writer は payload のスクリプトを実行しない。
  - App は Contents write と Workflows write を持ち、その push から公開用の配布を起動する。
- 公開用 main だけを親として1コミット追加し、Development-Commit trailer に M を記録する（FR-335・336）。
  - 書き込み直前の base/source 再照合と非 force push で競合・古い対象を拒否し、無差分は省略する。
  - 共通 concurrency による pending 置換を使わず、通常 push で待機中のリリースを取り消さない。
  - 初回の source trailer がない場合だけ、現在の公開用 main と一致する bootstrap_public_base を必須にする。
  - 初回の source 対応付けは同一 tree でも作り、初期化済みの指定・不正/重複/消失した trailer は拒否する。
  - 判定は main の blob なしの履歴を取得し、writer は main の先端1コミットだけを取得する。
  - base の一致を再確認した場合だけ、plan に固定した初期化履歴の判定を再利用する。

## 公開用の配布と復旧

- 公開用の main push は要求の追加・更新時だけ配布し、手動実行もイベント SHA に固定する（FR-322・323）。
- `scripts/release.py plan` は読み取り専用で metadata・イベント・タグと Release を確認する（FR-325・328）。
- 通常テストと隔離 package の成功後、`scripts/release.py draft OUTPUT_DIR` が状態を再照合してドラフトを作る。
  - 同一 SHA の軽量・注釈タグだけを再利用し、別 SHA のタグ・既存 Release を変更しない。
  - API は明示的404だけを欠落とし、認証・権限・通信障害では停止する。
  - タグ作成競合を再照合し、部分ドラフトを自動削除・上書きしない。
  - 既存 Release は認証済み一覧をページングして確認し、公開済みだけを返す tag 指定 API に依存しない。
  - ドラフトを確認する書き込み直前の処理には、公開先への push 権限がある資格情報を使う。
- 保守者は CI 候補をローカルで確認してマージし、最終ドラフトの ZIP・ノートを確認して公開する（FR-343）。
- 同期済みで配布だけが失敗した場合は公開用の元の run から再実行し、同期コミットを増やさない（EC-231）。
- `publish.sh` と `release-distribution.sh` は Actions 全体の障害時の復旧用とし、通常手順では使わない（FR-339）。
  - ローカル prepare は公開済み SHA の archive と共有 package を使い、release-info の4行を維持する。
