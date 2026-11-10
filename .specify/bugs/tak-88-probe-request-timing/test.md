# Bug Verification: 約束の要求時機

- **Slug**: tak-88-probe-request-timing
- **Tested**: 2026-11-09
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: partial

## Checks Performed

| 確認 | 結果 |
|---|---|
| 通常モードのswiftc -typecheck -warnings-as-errors | pass |
| Swift 6のswiftc -typecheck -warnings-as-errors | pass |
| Swift 6の全--self-test | pass（画像2種・非圧縮TIFF・reader・provider・フォルダ準備） |
| フォルダ準備の実際の背景実行と消費後の補充 | pass（checkPreparedFolders） |
| 診断版GUI | 保守者がSafari PNG・写真MP4・追加3件の成功を確認 |
| 変更後の通常スクリプトのGUI | pass（19:47 JST、Safari PNGと写真2枚。両方accepted=true、全要求がdrop-returnより前。各readerCount=1で成功） |
| 規約検査 | pass（scripts/dev/check-all.sh、176件のPython検査を含む全件） |
| 差分 | pass（git diff --check） |
| Folzio製品のGUI・製品への保存 | Phase 2以降未着手。T031・T037で確認 |

自己検査を制限内で実行するとAppKitがpublic.pngを有効なUTIとして扱えず例外となった。許可を得た制限外の再実行は全件成功。この例外を元のSIGBUSの再現とは扱わない。

## Residual Risks

通常版でSafari PNGと写真2枚の要求時機・書き出し・フォルダ補充を実測した。旧版の全ケースのキャンセル原因が要求時機だけだったとは断定しないため、総合判定はpartialを維持する。通常版のMP4は今回再測定していない（診断版では成功済み）。17:59のSIGBUSは原因未確定の別記録として残す。全体テスト等の前回の結果はtak-88-probe-actor-crash/test.mdを参照し、今回製品テストを再実行して成功したとは記録しない。

## GUI追確認（2026-11-09 19:47 JST）

保守者が指定の2ケースを完了し、ログと実ファイルを確認した。

- Safari PNG: sample.png / 188 bytes / 0.298310秒。PNG / 32×32、元画像とバイト一致。
- 写真2枚: IMG_2450.PNG / 386001 bytes / 0.418679秒、image01.jpg / 872744 bytes / 0.440082秒。中身はそれぞれPNG / 1179×2556、JPEG / 1024×768。
- 全readerCount=1、readerMainThread=false。両操作はaccepted=trueで、全request-beginがdrop-returnより前。消費後の補充で待機数2に戻った。
- ケース名は空で、完了報告とアプリ固有の型から特定した。写真2枚の原本の形式・内容は検査していない。
- ログ: /tmp/folzio-tak88-t006-final/regular-probe-gui-success-20261109-1947.log。

## Recommendation

追加の全形式の測定は求めず、T007の具体的な仕様変更案を保守者に示して確認する。確定前にPhase 2へ進まない。製品への保存はT031・T037で確認する。
