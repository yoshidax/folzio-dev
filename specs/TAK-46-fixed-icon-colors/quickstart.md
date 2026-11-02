# Quickstart: TAK-46 の検証

## Cloud（Agent）
`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`

## CI
`swift build`、`swift test`（種別→色の役割、固定色の値、青と黄の明度差 ≤ 0.1）

## 保守者の GUI 確認（ローカル）
```bash
scripts/make-app.sh
open .build/Folzio.app
```
フォルダ・zip・`..`・メディアを含むフォルダを開き、次を確認する。

1. リスト形式・サムネイル形式で、フォルダ（zip 内のディレクトリを含む）の行頭アイコンが青、zip が黄、`..` が従来のグレー（US48-AS1・2・5・7）
2. ライト／ダークを切り替えても色が同じ（SC-125）
3. システム設定でアクセントカラーを変えても色が変わらない（US48-AS3）
4. 行を選択して、青・黄が背景上で見える（US48-AS6・EC-178）
5. ツリーのフォルダ（青）と見比べ、違和感があれば値の調整を依頼する（A-155）
6. 検索結果のフォルダ・zip も同じ色（US48-AS4）
