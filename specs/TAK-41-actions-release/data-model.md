# Data Model

## ReleaseRequest

ルートの release.json。3キーすべて必須、未知・重複キーを拒否する。

| キー | 制約 |
|---|---|
| version | 文字列。`[0-9]+\.[0-9]+\.[0-9]+` に全体一致 |
| build_number | 文字列。`[0-9]+` に全体一致 |
| notes_file | `release-notes/` 配下の `.md` への相対パス |

値の型変換・空白の補正をしない。notes_file の各要素は英数字・`_`・`-`・`.` のみとし、
空の要素・`.`・`..`・絶対パス・改行を拒否する。
要求とノートは対象コミットの通常ファイルとし、途中のディレクトリを含め symlink を拒否する。
ノートは UTF-8 の空白以外の本文を持つ。tag は `v` + version。

## PublicCandidate

| 値 | 制約 |
|---|---|
| source_sha | イベントの完全な SHA。checkout HEAD と一致し、開発用 master に含まれる |
| expected_public_base | 検証開始時の公開用 main の完全な SHA |
| archive_digest | 公開候補 artifact の SHA-256。後続 job で照合 |
| public_tree | 生成・検証された公開ファイルの内容とモード |
| run_url | 開発用 Actions の実行 URL |

GitHub Secret やトークンを artifact に含めない。書き込み job は candidate のスクリプトを実行しない。
公開用コミットの trailer に `Development-Commit: <source_sha>` を記録する。
Git の親は公開用 main だけとし、開発用の commit オブジェクトを親にしない。

## CandidateArtifact

`release-candidate-pr-<PR>-<HEAD_SHA>` の artifact。保持30日。ZIP、SHA256SUMS、candidate.json を含む。
metadata は PR 番号、PR head SHA、実ビルド SHA、公開 tree ID、version / build、run URL を持つ。
公開 tree ID は除外・README 調整・workflow 配置後のファイル内容と Git モードから算出する。
ローカルの build 出力は tree の対象外。同期後の Git 親・コミットメッセージも比較しない。
run のリポジトリ・workflow・成功状態・PR と head の関係を GitHub API でも照合する。

## 状態

| 状態 | 結果 |
|---|---|
| 通常の開発 push | 同期を省略 |
| リリース PR の検証 | 公開候補を検査。公開先への書き込みなし |
| 確認用候補なし・別 head・公開 tree 不一致 | 同期前に停止。再生成とローカル再確認 |
| 検証失敗・artifact 不一致 | 公開用 main を保持して失敗 |
| 公開ツリーが同一 | 重複コミットなしで省略 |
| 候補より新しい source が公開済み | 巻き戻さず停止 |
| 公開先が expected_public_base から進んだ | 非 fast-forward を許可せず停止 |
| 公開成功・配布失敗 | 公開用の元の実行で配布だけを再実行 |
| 同一 SHA のタグだけ存在 | タグを維持して配布を再試行 |
| 別 SHA の同名タグ・既存 Release | 変更せず停止 |
| API 404 以外の障害 | 不存在と解釈せず失敗 |

初回移行で trailer がない公開コミットは、実行開始時の明示的な base を基準に初回同期する。
以後は source SHA の祖先関係を検証する。実行中に master が進んでも、選択した候補自体は変更しない。

## 配布物

ZIP は `Folzio-v{version}-macos-arm64.zip`、チェックサムは ZIP 1件を指す SHA256SUMS。
ノート末尾に公開用 SHA・両バージョン・run URL を付ける。
source SHA は公開用コミットの trailer と実行サマリーから追跡できる。
ローカルの release-info.txt は既存の commit / repo / version / build の4行を維持する。
