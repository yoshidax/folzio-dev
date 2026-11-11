# Implementation Plan: プレビュー操作モード

**Branch**: `020-preview-wheel-pan` | **Date**: 2026-11-12 | **Spec**: [spec.md](spec.md)

## Summary

保存する2択を設定に加え、既存の画像ビューにホイールズームとドラッグパンを追加する。倍率の正本は既存の PreviewViewController、位置とバーは ImagePreviewView に置く。設定変更を既存の通知経路で即時伝える。

## Technical Context

**Language/Version**: Swift 6 / Swift Package Manager  
**Primary Dependencies**: AppKit、既存の FolzioCore・FolzioLocalization  
**Storage**: UserDefaults  
**Testing**: Swift Testing / XCTest、手動 GUI  
**Target Platform**: macOS（Package.swift の対応バージョン）  
**Project Type**: オフライン macOS アプリ  
**Performance Goals**: 入力中にデコードを再実行せず既存のアニメーションを維持  
**Constraints**: 倍率25%〜800%、画像範囲外に動かさない、既存の全画面入力と共存  
**Scale/Scope**: 単一プレビュー、静止画・対応アニメーション画像

## Constitution Check

変更は画像ビューと設定に限定し、判断は FolzioCore、AppKit の入力・描画は FolzioApp、翻訳は日英両方に置く。オフラインを維持し、キーボード代替・VoiceOver・既存の履歴と全画面動作を維持する。既存設定は未設定時の既定値で読み取り、他の設定を消さない。テストとユーザーによる GUI 検証を実施する。設計後も違反なし。

## Project Structure

- `Sources/FolzioCore/Settings/`・`Model/`・`Layout/`: 設定と入力量・位置の純粋な判断。
- `Sources/FolzioApp/Preview/`・`Settings/`・`App/`: イベント、画面、設定変更の配線。
- `Sources/FolzioLocalization/`: 日英の設定文言。
- `Tests/FolzioCoreTests/`・`Tests/FolzioAppTests/`: 設定、入力・位置、統合と回帰。
- `specs/020-preview-wheel-pan/`: この設計と手動検証。

## Design

既存の `PreviewScrollLayout` の位置制限を再利用する。`PreviewZoom` を有限な連続値に変更し、25%〜800%に収める。ボタン操作は現在値に25ポイント加減して端に制限し、通常ホイールはOSの非高精度のスクロール量に対し1目盛りあたり1.1倍、その逆は1/1.1倍とする。ピンチはジェスチャ開始時の倍率を基準に累積変化を反映する。倍率の正本、アクセシビリティ通知、ボタン有効状態は controller 側の既存経路を共有する。連続値の表示は既存の地域別割合書式を使い、内部値と読み上げ用の丸めを分ける。

ホイール・ピンチではポインタのビュー座標を基準とし、倍率変更前後の画像座標から中心を計算して端に制限する。その他の操作とリサイズは従来のビューポート中心を維持する。ピンチ開始時のカーソル座標をその操作の基準として固定する。計算と境界は Core で検証する。

新モードでは高精度スクロールを位置移動として扱い、慣性も位置に反映する。通常の非高精度ホイールはズームとして扱う。`hasPreciseScrollingDeltas` は入力装置の種類を識別しないため、高精度ホイールを出すマウスも移動になる。OS のページ間スワイプ設定には連動しない。従来モードではすべて現行のスクロール動作を維持する。入力分類と実機での機器ごとの動作は検証で確かめる。

ドラッグ開始閾値は4 point とし、その後は初期位置からの差を適用する。ビュー消失、画像・モード変更、非アクティブ化と mouseUp で中断・カーソル復元する。クリックは既存の全画面判定へ渡し、ドラッグ後はクリックと見なさない。実際のイベント伝播とカーソルは GUI で確認する。

## Phase and validation

一体の変更として設定と入力を実装し、自動検証の後に独立した手動タスクを実施する。`swift build` → `swift test` → `scripts/dev/check-all.sh` → `scripts/make-app.sh` の順に実行し、ユーザーが起動・動作を確認する。確認後に Phase をコミットし、最終検証と converge を経て製品仕様への反映を別途レビューする。
