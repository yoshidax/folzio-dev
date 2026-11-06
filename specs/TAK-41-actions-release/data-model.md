# Data Model

## ReleaseRequest

release.json の3キーをすべて必須とし、未知・重複キーを拒否する。

| キー | 制約 |
|---|---|
| version | 文字列。`(0\|[1-9][0-9]*)\.(0\|[1-9][0-9]*)\.(0\|[1-9][0-9]*)` に全体一致 |
| build_number | 文字列。`(0\|[1-9][0-9]*)` に全体一致 |
| notes_file | `release-notes/` 配下の `.md` への相対パス |

0 単独は許可するが、01.2.0、1.02.0、1.2.00、007 は拒否する。値を型変換・補正・正規化しない。
notes_file の要素は英数字・`_`・`-`・`.` のみ。空・`.`・`..`・絶対パス・改行を拒否する。
要求・ノートと途中のディレクトリに symlink を許さず、対象コミットの UTF-8 の非空白本文を持つ通常ファイルを使う。
tag は v + version。未使用 version の検査前に形式を確定させ、表記違いの別タグを許さない。

## ReleaseTarget と手動入力

| 値 | 制約 |
|---|---|
| source_sha | 固定したマージ済みリリース PR の merge commit M。完全な40桁 SHA |
| release_pr | master への merged PR。merge commit が M と一致し、release.json の変更を含む |
| expected_public_base | 同期判定開始時に取得した公開用 main の SHA |
| candidate_run_id | 保守者が確認した候補の run。PR 候補の自動選択時は照合した値を記録 |
| bootstrap_public_base | 初回の手動同期だけで明示する公開用 main の SHA。既定は空 |

手動の候補生成・同期では source_sha が必須。workflow の実行 ref は default branch だが、
対象には入力 M を checkout する。M が origin/master の祖先で、release_pr のマージ結果であることを検証する。
実行時の GITHUB_SHA、後続の master HEAD、任意の通常 PR のマージコミットを代用しない。

## CandidateArtifact

名前はイベント共通で `release-candidate-<source_sha>-<run_id>-<run_attempt>`。保持30日。
ZIP、SHA256SUMS、candidate.json を含み、run / attempt と artifact の識別情報は summary にも出す。

| metadata | 意味 |
|---|---|
| source_kind | pr-preview または merged-source |
| source_sha | 実ビルドの完全な SHA。preview はテスト用 merge、merged-source は M |
| release_pr / pr_head_sha / pr_base_sha | PR と preview の履歴。手動で PR イベントがなくても API で対象 PR を解決 |
| public_tree | 除外・README 調整・workflow 配置後の内容と Git モードによる tree ID |
| version / build_number / toolchain | 要求とビルド条件。最終配布との照合に使う |
| required_checks | build・通常テスト・通信 API・静的検査・package の結果。全成功が必須 |
| performance | 実行結果・失敗/タイムアウトの記録とログ参照。失敗だけでは候補を拒否しない |
| run_url / run_attempt | 実行元と試行。別 attempt の成果物を混ぜない |

候補の出所は release-candidate workflow、または同期の rebuild-candidate job。
API で repo・workflow・run・attempt・必須 job の結果を照合し、metadata の自己申告だけを信用しない。
pr-preview を使う場合は現在の merged PR の head と対応し、M の公開 tree に一致すること。
merged-source を使う場合は source_sha が M と完全一致すること。
複数の曖昧な候補や異なる attempt の混在は拒否する。

## 同期 payload

同期の exporter が M から作った source archive の digest・public_tree・source_sha・expected_public_base を固定する。
App Secret とトークンは含めない。writer は archive の照合と Git 操作だけを行い、ソースを実行しない。
公開用の親は main のコミットだけとし、Development-Commit trailer に M を記録する。

## 状態と遷移

| 状態 | 結果 |
|---|---|
| 通常 master push | 判定のみで省略。待機中の同期を取り消さない |
| PR preview の必須検査成功 | 確認用 artifact を作成。公開先への書き込みなし |
| preview と M の tree が一致 | 候補の検証結果を再利用して Ubuntu で静的検査・同期へ進む |
| 候補欠落・preview と M が不一致 | M の候補を生成してローカル確認待ち。公開先を変更しない |
| 手動で M と確認した新候補 run を指定 | M の一致・必須検証を再照合して同期を再開 |
| 必須検証失敗 | 以降の検査・成果物確定・公開用の更新を行わず非ゼロ終了 |
| 性能テストのみ失敗 | 結果を残し、後続の必須検査を実行する |
| source trailer がなく初期 base の入力もない | 初期化待ち。書き込みなし |
| 初期 base の明示入力が実際の public main と一致 | 候補等の全検査後、初期 base の子に最初の source trailer を作る |
| 初期 base 不一致・不正、既存 trailer に対する bootstrap 指定 | 書き込みなしで失敗 |
| 初期化済みで公開ツリーが同一 | 重複コミットなしで終了 |
| 公開済み source より古い M | 巻き戻さず停止 |
| expected_public_base が変化 | 競合として停止。更新時も非 force push で保護 |
| 公開成功・配布失敗 | 公開用の元の run で配布だけを再実行 |
| 同一 SHA のタグのみ存在 | タグを保持してドラフトを再試行 |
| 別 SHA のタグ・既存 Release、API 404 以外の障害 | 自動更新せず停止 |

初期化は bootstrap_public_base の明示を必要とする1回限りの遷移。
初回の source 対応付けに限り tree が同じでも1コミットを作り、次回から無差分で省略する。
trailer の不正・重複・source の解決不能を初回と解釈しない。source / candidate の検査も省略しない。
同時実行は共通 concurrency の待機列で直列化せず、公開先 base と source の再照合・非 force 更新で制御する。

## 配布物

ZIP は Folzio-v{version}-macos-arm64.zip、SHA256SUMS は ZIP 1件の SHA-256。
ノートと summary に public SHA・両バージョン・実行元を記録し、公開コミットから source M へ追跡できるようにする。
ローカル復旧の release-info.txt は commit / repo / version / build の4行を維持する。
