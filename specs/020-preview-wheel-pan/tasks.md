# Tasks: プレビュー操作モード

**Input**: [spec.md](spec.md), [plan.md](plan.md), [contracts/settings.md](contracts/settings.md)

## Phase 1: 共通基盤

- [X] T001 `Sources/FolzioCore/Model/Settings.swift` と `Sources/FolzioCore/Settings/SettingsStore.swift` に2択と `preview.interactionMode` の保存・不正値時既定値を追加する。
- [X] T002 `Sources/FolzioCore/Layout/PreviewZoom.swift` と `Sources/FolzioCore/Layout/PreviewScrollLayout.swift` に連続倍率、1.1倍と逆数、25ポイント加減と端、カーソルを基準とした位置計算を追加する。
- [X] T003 `Tests/FolzioCoreTests/SettingsStoreTests.swift` と `Tests/FolzioCoreTests/PreviewZoomTests.swift`・`PreviewScrollLayoutTests.swift` に保存・不正値・連続倍率・相反操作・上下限・位置の境界を検証するテストを追加する。

## Phase 2: US1 直接操作（P1）

**独立検証**: 新モードでズーム・両端へのパン・カーソルと既存のダブルクリックを試す。

- [X] T004 [US1] `Sources/FolzioApp/Preview/ImagePreviewView.swift` にモード別バー、高精度スクロールのパンと慣性、通常ホイール・ピンチ入力、4 point 閾値のドラッグと中断時のカーソル復元を実装する。
- [X] T005 [US1] `Sources/FolzioApp/Preview/PreviewViewController.swift` にホイール・ピンチから連続ズームへの接続を追加し、カーソル中心、上限・下限・アクセシビリティ通知・ボタン有効状態・画像変更を保つ。
- [X] T006 [US1] `Tests/FolzioCoreTests/PreviewScrollLayoutTests.swift` と `Tests/FolzioAppTests/` で位置の両端、イベントの分岐、画像の変更と既存のダブルクリックを検証する。

## Phase 3: US2 設定切替（P2）

**独立検証**: 設定を変更し即時反映と再起動後の選択の保持、従来操作を試す。

- [X] T007 [US2] `Sources/FolzioApp/Settings/SettingsWindowController.swift` と `Sources/FolzioLocalization/` に日英の設定 UI・Tab 順・アクセシビリティを追加する。
- [X] T008 [US2] `Sources/FolzioApp/` の既存設定通知経路からプレビューへモード変更を即時伝え、切替時の倍率・位置の保持と入力状態破棄を実装する。
- [X] T009 [US2] `Tests/FolzioCoreTests/SettingsStoreTests.swift`・`Tests/FolzioCoreTests/Localization/SettingsTextTests.swift`・`Tests/FolzioAppTests/` で未設定・既存・不正値、切替、日英文言を検証する。

## Phase 4: 検証と Phase 完了

- [X] T016 `Sources/FolzioCore/Layout/` に押下中の矢印の相殺・45度の移動量・リセットを決める型を追加し、`Tests/FolzioCoreTests/` で単独・斜め・逆方向・解除を検証する。
- [X] T017 `Sources/FolzioApp/Preview/ImagePreviewView.swift` に Option と矢印の押下・解放、システムのキーリピート設定を使う繰り返し、フォーカス喪失・画像変更時の停止を実装する。
- [X] T018 `Tests/FolzioAppTests/ImagePreviewInteractionTests.swift` でキー同時押し・解除、画像端とモード、停止および通常キーへの影響を検証する。
- [X] T010 `specs/020-preview-wheel-pan/quickstart.md` に従い `swift build`、`swift test`、`scripts/dev/check-all.sh`、`scripts/make-app.sh` を順に実行し結果を記録する。
  - 2026-11-12: `swift build`・`swift test`（再実行で成功）・`scripts/dev/check-all.sh`・`scripts/make-app.sh` が成功。初回の全テストでは画像読み込み待機の既存テスト3件が時間切れとなった。
  - 動作確認後の修正: `swift build`・`swift test`（再実行で成功）・`scripts/dev/check-all.sh`・`scripts/make-app.sh` が成功。途中の全テストでは既存のファイル監視の時間切れと、別の実行でスライドショー性能テストの基準超過があった。実機の再確認は T011 で行う。
  - 2本指スクロールの再修正後: `swift build`・`swift test`（再実行で成功）・`scripts/dev/check-all.sh`・`scripts/make-app.sh` が成功。初回の全テストでは画像キャッシュと再読み込みの既存テスト2件が時間切れとなった。
  - ピンチ反転の修正後: `swift build`・`swift test`・`scripts/dev/check-all.sh`・`scripts/make-app.sh` が成功。上下限で指を離さず反転する実機確認は T011 で行う。
  - ホイール補間の調整後: `swift build`・`swift test`・`scripts/dev/check-all.sh`・`scripts/make-app.sh` が成功。操作感と他の入力への切替は T011 で実機確認する。
  - 斜めスクロール追加後: `swift build`・`swift test`・`scripts/dev/check-all.sh`・`scripts/make-app.sh` が成功。実機での同時押しとキー解放は T011 で確認する。
- [X] T011 [MANUAL] `specs/020-preview-wheel-pan/quickstart.md` の全シナリオを保守者が実機で実施し、OS・機器・結果を報告する。
  - 2026-11-12: 保守者が全検証の完了と斜めスクロールの正常動作を報告。macOS 26.6.2、MX Ergo S（Bluetooth）とトラックパッドを使用。トラックパッドの機種は未確認。
- [X] T012 T011 の報告を `specs/020-preview-wheel-pan/tasks.md` に記録し、Phase の変更をコミットする。
- [ ] T013 最終自動検証を `specs/020-preview-wheel-pan/quickstart.md` の順に実行する。
- [ ] T014 [MANUAL] 最終ビルドを `open .build/Folzio.app` で保守者が起動し、3ペインを確認して結果を報告する。
- [ ] T015 T014 の報告を `specs/020-preview-wheel-pan/tasks.md` に記録し、converge で残作業を確認する。

## 依存と実行順

T001〜T003 → T004〜T006 → T007〜T009 → T016〜T018 → T010 の再検証 → T011〜T015。T011・T014 は独立した手動確認で、報告後にのみ後続を進める。両ストーリーを1つの検証 Phase として完了する。設計レビューで確定した [MANUAL] 分類は実装中に変更しない。
