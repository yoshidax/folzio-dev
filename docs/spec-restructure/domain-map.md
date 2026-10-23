# spec.md 分割の対応表（レビュー用ドラフト）

- 対象: `specs/001-three-pane-media-viewer/spec.md`（1,140行）
- 移行先: `specs/product/` 配下の 8 ファイル（Living spec）
- 状態: ドラフト。境界をレビューしてもらうための表で、まだ仕様は動かしていない

## 方針

- FR・SC の ID は振り直さない。移動先のファイルが変わるだけにする
- 1つの ID は 1つのファイルだけで定義する。ほかのドメインからは `FR-xxx（file-list.md）` の形で参照する
- 受け入れシナリオ・Edge Cases・Assumptions は番号を持たないため、移行時に元の位置を示すラベルを付ける
  - 受け入れシナリオ: `US1-AS15`（User Story 1 の 15 番目）
  - Edge Cases: `EC-01`〜`EC-39`（spec.md での記載順）
  - Assumptions: `A-01`〜`A-28`（同上）
- Clarifications（Q&A のセッションログ）は移さない。決定事項は FR に反映済みのため、`001` に履歴として残す

## ファイル別の概要

| ファイル | 元の見出し（spec.md の太字） | FR | SC | 受け入れシナリオ | EC | A |
|---|---|---|---|---|---|---|
| overview.md | 対応形式・横断要件・アプリアイコン + FR-003・FR-009 | 9 | 3 | 0 | 3 | 7 |
| window-layout.md | 画面構成・ツールバー・ペインの表示切り替え | 13 | 0 | 14 | 3 | 0 |
| directory-tree.md | ディレクトリツリー・お気に入り | 15 | 1 | 9 | 5 | 6 |
| file-list.md | ファイルリスト・種類フィルタ・ファイルリストのフォルダ | 18 | 4 | 18 | 5 | 4 |
| zip.md | zip ファイル・zip ファイルの表示制御 | 12 | 3 | 11 | 10 | 4 |
| file-operations.md | ファイル操作 | 11 | 2 | 10 | 5 | 2 |
| search.md | 検索 | 8 | 1 | 4 | 5 | 1 |
| preview.md | プレビュー（フルスクリーンを含む） | 12 | 3 | 14 | 3 | 4 |
| **合計（spec.md と一致）** | | **98** | **17** | **80** | **39** | **28** |

## 1. Functional Requirements

| ファイル | FR |
|---|---|
| overview.md | FR-003（保存と復元）、FR-009（拡張子による判定）、FR-039（対応形式）、FR-040〜042（横断要件）、FR-043〜045（アイコン） |
| window-layout.md | FR-001・002（3ペインと仕切り）、FR-049〜052（ツールバー）、FR-088〜094（ペインの表示切り替え） |
| directory-tree.md | FR-004〜007・047・053〜055（ツリー）、FR-061〜067（お気に入り） |
| file-list.md | FR-008・010〜017・048（一覧と表示形式）、FR-056〜060（種類フィルタ）、FR-076〜078（フォルダと `..`） |
| zip.md | FR-068〜075（zip の中の閲覧）、FR-095〜098（zip ファイルの表示制御） |
| file-operations.md | FR-018〜027（ファイル操作）、FR-079（ツリーのフォルダをゴミ箱に入れる） |
| search.md | FR-080〜087 |
| preview.md | FR-028〜034・038（表示と動画）、FR-035〜037・046（フルスクリーン） |

## 2. Success Criteria

| ファイル | SC |
|---|---|
| overview.md | SC-002（起動時間）、SC-009（キーボードだけの一連の操作）、SC-011（アプリアイコン） |
| directory-tree.md | SC-013（ツリーのアイコンの判別） |
| file-list.md | SC-003（10,000 ファイル）、SC-004（ドラッグの追従）、SC-005（横スクロールなし）、SC-012（行頭アイコン） |
| zip.md | SC-014（zip の中の動画）、SC-015（10,000 項目の zip）、SC-017（zip の表示切り替え） |
| file-operations.md | SC-006（キャンセル時の変更なし）、SC-008（Finder ユーザーの初回操作） |
| search.md | SC-016 |
| preview.md | SC-001（画像表示時間）、SC-007（破損ファイルで落ちない）、SC-010（動画の再生開始） |

## 3. User Story と受け入れシナリオ

User Story は複数のドメインにまたがるため、ストーリー単位では分けない。

- overview.md に User Story 1〜6 の索引（タイトル・優先度・Why・シナリオの置き場所）を置く
- 受け入れシナリオは関係するドメインのファイルへ振り分け、`US1-AS15` のラベルで出典を残す

| User Story | シナリオ | 移動先 |
|---|---|---|
| US1 フォルダを辿って画像をプレビュー | AS1・7・8・9 | directory-tree.md |
| | AS10〜14 | directory-tree.md（お気に入り） |
| | AS2・4・21・22 | file-list.md |
| | AS3・5・6 | preview.md |
| | AS15〜20・29 | zip.md |
| | AS23・24 | file-operations.md |
| | AS25〜28 | search.md |
| US2 動画をプレビューで再生 | AS1〜5 | preview.md |
| US3 リスト形式とサムネイル形式 | AS1〜6・11〜18 | file-list.md |
| | AS7〜10 | window-layout.md（ツールバー） |
| | AS19〜22 | zip.md |
| US4 Finder と同じ感覚で整理 | AS1〜8 | file-operations.md |
| US5 フルスクリーン | AS1〜6 | preview.md |
| US6 ペインの幅を調整 | AS1〜10 | window-layout.md |

## 4. Edge Cases

| ファイル | EC（記載順の番号と要旨） |
|---|---|
| overview.md | EC-13 アプリ外での変更の反映、EC-19 隠しファイル・パッケージを表示しない、EC-31 アイコン生成の失敗でビルドを止める |
| window-layout.md | EC-37 プレビューのみ表示でメディアがない、EC-38 プレビューのみ表示で非メディア行を飛ばす、EC-39 プレビューのみ表示で選択がない |
| directory-tree.md | EC-05 読み取り権限のないフォルダ、EC-06 サブフォルダがないと三角を出さない、EC-07 サブフォルダの確認に失敗、EC-18 ボリュームの取り外し、EC-20 お気に入りのフォルダが見つからない |
| file-list.md | EC-01 空のフォルダ、EC-02 種類フィルタで0件、EC-04 代表フレームを取れない、EC-09 10,000 ファイル、EC-21 種類フィルタで選択中のファイルが消える |
| zip.md | EC-10 10,000 項目の zip、EC-22 読み取り専用、EC-23 文字コード、EC-24 壊れた zip、EC-25 暗号化・非対応の圧縮方式、EC-26 アプリ外での zip の変更、EC-27 種類フィルタと zip の行、EC-28〜30 zip ファイルの表示設定 |
| file-operations.md | EC-08 書き込み権限なし、EC-14 リネームの不正な名前、EC-15 拡張子の変更、EC-16 自分自身の配下への移動、EC-17 フォルダの操作の反映 |
| search.md | EC-32 0件、EC-33 読めないフォルダを飛ばす、EC-34 不正な起点、EC-35 結果のファイルが消える、EC-36 起点が消える |
| preview.md | EC-03 破損ファイル、EC-11 非常に大きな画像、EC-12 極端に小さい画像 |

## 5. Key Entities

| ファイル | エンティティ |
|---|---|
| overview.md | 表示設定、動作オプション、アプリアイコン |
| window-layout.md | ペインの表示状態 |
| directory-tree.md | フォルダ（ディレクトリ）、ボリューム、お気に入り |
| file-list.md | 上の階層へ戻る行（`..`）、メディアファイル、種類フィルタ |
| zip.md | zip ファイル、zip の中の項目、zip の中の現在位置 |
| file-operations.md | ファイル操作 |
| search.md | 検索条件、検索結果 |
| preview.md | なし |

## 6. Assumptions

| ファイル | A（記載順の番号と要旨） |
|---|---|
| overview.md | A-01 macOS、A-02 単一ユーザー、A-09 隠しファイルを表示しない、A-14 範囲外の一覧、A-16 アイコン原画の管理、A-17 単一のアイコン、A-18 メニューバー等のアイコンは範囲外 |
| directory-tree.md | A-04 ツリーのルート、A-19 お気に入りの名前と並び、A-20 お気に入りはドロップ先にしない、A-21 右クリックの対象行、A-27 お気に入りの見出しの開閉、A-28 ツリーのアイコンの種類 |
| file-list.md | A-03 「扱えるファイルのみ」の解釈、A-08 作成日の意味、A-15 縮小画像はアプリ内で生成、A-25 並べ替えで種類を混ぜる |
| zip.md | A-22 入れ子の zip などは範囲外、A-23 zip ファイルの表示設定の意味、A-24 zip の中の日付、A-26 圧縮された動画の遅さ |
| file-operations.md | A-05 削除はゴミ箱、A-07 コピー・移動の操作方法 |
| search.md | A-06 「場所」列の並び順は保存しない |
| preview.md | A-10 音声は既定で再生、A-11 拡大でぼやける、A-12 憲章 原則 III の解釈、A-13 拡大規則は画像のみ |

## 7. spec.md 以外の文書

| 文書 | 移行先 | 理由 |
|---|---|---|
| spec.md の Input（元のユーザー記述） | overview.md の冒頭 | プロダクトの出発点として残す |
| spec.md の Clarifications | `001` に残す | 決定の履歴であり、現在の契約ではない |
| contracts/keyboard-and-menus.md | `specs/product/keyboard-and-menus.md` | ショートカットの衝突を1か所で確認できるよう、分割せず横断の契約にする |
| contracts/settings.md | `specs/product/settings.md` | 保存する設定の一覧も横断の契約 |
| contracts/app-bundle.md | `specs/product/app-bundle.md` | アプリアイコン（overview.md）の契約 |
| contracts/core-api.md | `001` に残す | 実装の API で、プロダクトの仕様ではない |
| plan.md・research.md・data-model.md・quickstart.md・tasks.md・checklists/ | `001` に残す | 実装の経緯。分割も再生成もしない |

## 8. レビューしてほしい境界の判断

| # | 判断 | 代わりの案 |
|---|---|---|
| J1 | FR-003（保存と復元）を「画面構成」から overview.md へ移す。保存対象が全ドメインにまたがるため | window-layout.md に残す |
| J2 | FR-009（拡張子による判定）を「ファイルリスト」から overview.md の対応形式（FR-039）の隣へ移す | file-list.md に残す |
| J3 | ツールバーのボタンは機能のドメインに置く（FR-057 種類フィルタ → file-list、FR-089 → window-layout、FR-096 → zip）。window-layout.md には並び順の索引だけを置く | ツールバーの FR を全部 window-layout.md に集める |
| J4 | フルスクリーン（FR-035〜037・046）は preview.md。ペインの表示状態からの切り替え（FR-094）は window-layout.md | フルスクリーンを window-layout.md に置く |
| J5 | FR-079（ツリーのフォルダをゴミ箱に入れる）は file-operations.md | directory-tree.md に置く |
| J6 | zip ファイルの表示制御（FR-095〜098）は file-list.md ではなく zip.md | file-list.md の種類フィルタの隣に置く |
| J7 | SC-004（サムネイルサイズとペイン幅のドラッグ追従）は file-list.md に定義し、window-layout.md から参照する | 2つに分割する（ID が増えるため非推奨） |
| J8 | 隠しファイル・パッケージを表示しない規則（EC-19・A-09）は overview.md。ツリーと一覧の両方に効くため | directory-tree.md と file-list.md の両方に書く（重複するため非推奨） |
| J9 | User Story はストーリー単位で分けず、overview.md の索引 + シナリオの振り分けにする | 各ドメインのファイルに新しく User Story を書き起こす（内容の書き換えになるため今回は避ける） |

## 9. 移行後の検証（次の手順で使う）

1. FR-001〜098 と SC-001〜017 が、`specs/product/` 内でちょうど1回ずつ定義されていることをスクリプトで確認する
2. `US*-AS*`・`EC-*`・`A-*` のラベルが 80・39・28 件そろっていることを確認する
3. 元の spec.md と移行後の本文を、ラベル単位で文字列比較し、移動以外の変更がないことを確認する
