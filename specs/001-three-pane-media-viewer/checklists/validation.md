# Validation: 3ペイン型メディアビューア

**Feature**: [spec.md](../spec.md) | **Plan**: [plan.md](../plan.md) | **Date**: 2026-10-20

## アプリアイコン（FR-043〜045、SC-011）

`scripts/make-app.sh` で `.build/MediaViewer.app` を生成して確認した。

| 確認項目 | 結果 | 根拠 |
|----------|------|------|
| `Contents/Resources/AppIcon.icns` が存在する | PASS | `test -f` |
| `CFBundleIconFile` が `AppIcon` | PASS | `plutil -extract CFBundleIconFile raw` |
| iconset の10スロットが揃う | PASS | `iconutil -c iconset` で全10ファイルを展開 |
| 16 / 32 / 64 / 128 / 256 / 512 / 1024 px が生成される | PASS | `sips -g pixelWidth -g pixelHeight` |
| 16px と 32px で3ペインの図案が判別できる | PASS | 生成 PNG を 256px に拡大して目視確認 |
| Finder・Dock・⌘Tab・About で同じアイコンが表示される | 未確認 | GUI での確認が必要 |
| ライト・ダークの両方で同じアイコンが表示される | 未確認 | GUI での確認が必要 |
| `swift run` では標準アイコンになる | 未確認 | バンドルがないため想定どおり |

### 再確認コマンド

```bash
scripts/make-app.sh
open .build/MediaViewer.app
```

確認ポイント:

1. Finder で `.build/MediaViewer.app` を表示し、3ペインのアイコンになっている
2. Dock と ⌘Tab に同じアイコンが出る
3. メニューの「MediaViewer について」に同じアイコンが出る
4. システム設定で外観をライト／ダークに切り替え、どちらでも同じアイコンが出る
5. 16px 相当（Finder のリスト表示や小さい Dock）でも3ペインの図案が判別できる

## 未実施の検証

- T079: Accessibility Inspector によるラベル確認
- T080: US1〜US6、キーボードのみの操作、異常系の手動シナリオ
