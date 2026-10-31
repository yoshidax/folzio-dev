# Implementation Plan: 目的別ショートカットチートシート

**Branch**: `work` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-22-shortcut-cheatsheet/spec.md` / TAK-22

## Summary

目的別の固定カタログを、親が所有する独立した非モーダル NSWindow に表示する。起動はファイルメニューと ⌘/。標準 responder chain の「閉じる」⌘W を追加する。親の delegate を置き換えず、親の終了通知で対応一覧を閉じる。カタログと翻訳を分離し、両言語の即時切り替えとキーボードスクロールを実装する。

本資料は設計レビュー用。`docs_private/cloud-agent-workflow.md` の「承認の前に実装しない」に従い、設計承認後に tasks.md の実装タスクを開始する。

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: Foundation、AppKit、既存 FolzioCore / FolzioLocalization。外部依存なし。

**Storage**: 新しい永続化なし。親の生存中だけ controller と表示状態をメモリ保持。

**Testing**: Swift Testing（Tests/FolzioCoreTests）。既存のローカライズ整合性検査を継続。AppKit 実機検証は quickstart.md。

**Target Platform**: macOS 15 以降。Cloud Linux では Swift コマンド・GUI を実行しない。

**Project Type**: Swift Package のデスクトップアプリ。

**Performance Goals**: 固定数の短いテキストだけを表示。画像デコード・走査・ファイル操作・既存キャッシュに変更を加えない。一覧を開いても親の入力を遮らない。既存の画像切り替え100ms・初回画像1秒の基準を維持する。

**Constraints**: Core に AppKit を import しない。ウィンドウ・ビュー操作は MainActor。ネットワーク API・外部リソース取得なし。Auto Layout は addSubview 後に有効化。

**Scale/Scope**: 1親あたり1一覧、7区分、契約表の固定項目。実行中のメニュー収集やショートカットの設定基盤は導入しない。

## Constitution Check

| 原則 | Phase 0 前 / Phase 1 後の判断 |
|---|---|
| I ローカル完結 | PASS / PASS。固定テキストのみ。通信・ユーザーファイルへの操作なし。 |
| II 体感性能 | PASS / PASS。既存のデコード・列挙・キャッシュ経路に変更なし。表示は固定カタログのみ。CI の既存性能テストと実機で親の応答を確認。 |
| III キーボード・アクセシビリティ | PASS / PASS。⌘/・⌘W、キーボードスクロール、見出しと項目の読み上げ、標準の外観。 |
| IV テスト必須 | PASS / PASS。Core のカタログと翻訳取得を自動検証。GUI は別途記録し、CI と保守者の確認前は完了扱いにしない。 |
| V YAGNI | PASS / PASS。汎用キー再割り当て基盤・検索・外部依存・新設定なし。 |
| 仕様管理 | PASS / PASS。新しい feature のみ作成。product への反映は実装・検証後。ID は最新 product の最大値 FR199 / SC95 / EC135 / A115 / US31 の次から採番。 |

## Project Structure

### Documentation (this feature)

`specs/TAK-22-shortcut-cheatsheet/` に spec.md、plan.md、research.md、data-model.md、contracts/shortcut-cheatsheet.md、quickstart.md、checklists/requirements.md、tasks.md を置く。

### Source Code (repository root)

```text
Sources/FolzioCore/Shortcuts/ShortcutCatalog.swift             # 新規: 順序・ID・キー表記・区分
Sources/FolzioLocalization/ShortcutText.swift                  # 新規: カタログIDからTextKeyへの対応
Sources/FolzioLocalization/TextKey.swift                       # 新しいタイトル・見出し・説明・条件
Sources/FolzioLocalization/Resources/{en,ja}.lproj/Localizable.strings
Sources/FolzioApp/Shortcuts/ShortcutCheatSheetWindowController.swift # 新規: 一覧とスクロール
Sources/FolzioApp/App/MainWindowController.swift               # 所有・再表示・親終了通知
Sources/FolzioApp/App/AppDelegate.swift                        # 起動入口・有効条件
Sources/FolzioApp/App/MainMenu.swift                           # ⌘/・⌘W・翻訳バインド
Sources/FolzioApp/App/MainSplitViewController.swift            # 既存状態を使う表示可否の公開
Tests/FolzioCoreTests/ShortcutCatalogTests.swift                # 新規
Tests/FolzioCoreTests/Localization/ShortcutTextTests.swift      # 新規
README.md / README.ja.md                                      # 同内容の起動・終了案内
```

**Structure Decision**: 参照カタログは UI から分離した Core の純粋な値。翻訳キーは Localization、描画・有効条件・所有は App に置く。既存キー処理の全面リファクタリングは行わない。

## Phase 0: Research

[research.md](research.md) に根拠、採用案、代替案を記録済み。親の delegate 所有と入力監視は読み取り専用の調査担当にも確認した。未解決の技術選択はない。Linear の get_agent_context は呼び出したがサーバーが Tool not found を返したため、共有ノートは取得できず、リポジトリを根拠とした。

## Phase 1: Design

1. Core は [data-model.md](data-model.md) の区分・項目を提供する。操作IDごとにキー表記と説明・条件の翻訳対応を網羅し、識別子と順序を安定させる。
2. `MainMenu` に ⌘/ と Close（⌘W）を追加。起動は AppDelegate を明示 target とし既存親へ送る。親の生存、名前の編集、sheet/modal、全画面、スライドショーの状態で検証。controller の非 nil だけで判定しない。
3. `MainWindowController` が一覧 controller を遅延作成し保持する。既存の MainSplitViewController に設定された window.delegate は変えない。親 object に限定した willCloseNotification の selector observer で閉じ、親終了済みフラグを立てる。通知は寿命に合わせ解除する。
4. 一覧は `.titled/.closable/.resizable` の通常ウィンドウ、`isReleasedWhenClosed = false`、通常レベル。child window・sheet・modal を使わず、初回だけ visibleFrame 内へ配置する。親の生存中は同じ controller を再利用する。
5. `NSScrollView` に7区分の縦並び。説明は折り返すラベル、キー列は一定幅の記号表記。見出しと行を accessibility で識別可能にする。scroll view の標準キー入力で不足する ↑↓・Page Up/Down・Home/End だけを専用ビューで処理し、グローバルイベント監視は追加しない。
6. `LanguageChangeObserver` でラベル・アクセシビリティ・タイトルを更新。更新前の先頭可視項目IDとその行内オフセットを保存し、レイアウト後に復元・範囲へclampする。ウィンドウと親の状態は作り直さない。
7. カタログは操作を実行しない。同期は契約表と全行の照合、自動テストのID・キー・区分・翻訳対応検査、実機のキー動作照合で担保する。メニューだけから生成するとフォーカス条件付き操作が欠けるため採用しない。

## Validation & Delivery

[quickstart.md](quickstart.md) に Cloud、CI、実機の担当と期待結果を分離。設計資料だけの段階では Swift build/test、GUI 検証は未実施。実装後は Cloud の4検査、CI、保守者確認を順に記録する。PR は依頼時のみ作成し、product への反映前に master を取り込みID衝突を解消し、反映差分を提示して承認後コミットする。

現在の `work` は Cloud 指定名として維持する。push 許可プレフィックスに合わないため、この名前では push しない。リモート提出が必要になった時点で `agent/TAK-22-shortcut-cheatsheet` などへの変更を保守者に確認する。ブランチ名変更は設計承認と別の操作。

## Complexity Tracking

憲章違反なし。新しい外部依存なし。汎用のコマンド管理基盤は作らず、固定カタログと1つの補助ウィンドウで実現する。
