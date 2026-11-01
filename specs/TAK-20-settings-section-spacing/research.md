# Research: 設定ウインドウのセクション間隔の統一と確認オプションの補足説明の分離

調査の基準: `origin/master`（bc97861）の `Sources/FolzioApp/Settings/SettingsWindowController.swift`、
`Sources/FolzioLocalization/Resources/{ja,en}.lproj/Localizable.strings`、`specs/product/contracts/settings.md`・`localization.md`。
GUI は Cloud で実行できないため、空白の原因は静的な読み取りに基づく推定で、実装後に保守者の GUI 確認で確かめる。

## R1 区分の間隔

- **Decision**: 縦の `NSStackView` の `spacing` は 8pt のまま残し、区分の前にだけ `setCustomSpacing(20, after:)` を付ける。
  対象は「言語」の行の後（「動画」の前）、「動画をループ再生する」の後（「ファイル操作」の前）、確認の補足説明の後（「スライドショー」の前）。
  見出しと最初の項目の間隔、区分の中の項目どうしの間隔は 8pt で揃う
- **Rationale**: 現在は全項目が 8pt の等間隔で、見出しの前後が同じ間隔のため区分の切れ目が弱い。20pt はウインドウの余白（stack の上下左右 20pt）と同じで、
  値の種類を増やさない。`NSStackView.setCustomSpacing(_:after:)` は macOS 10.13 以降の公開 API（AppKit `NSStackView.h`）
- **Alternatives considered**: 区分ごとに入れ子の stack を作る（構造が深くなり、Tab の移動順の手書きの設定はそのままなので利点が小さい）。
  見出しの前に空の view を挟む（読み上げや Tab に影響しうる）。区切り線（`NSBox`）を加える（A-119 で範囲外）

## R2 「ファイル操作」の大きな空白の原因

- **Decision**: 確認のチェックボックスの `heightAnchor.constraint(greaterThanOrEqualToConstant: 60)` を削除する
- **Rationale**: 長い1文を折り返して表示するために最小の高さ 60pt を付けていた。チェックボックスは文言を縦方向の中央に描くため、
  実際の行数（日本語の画面例では2行）より高い分が上下の空白になる（Issue の添付画像の症状と一致する）。主文を短くすると両言語とも1行に収まり、
  最小の高さは不要になる。さらに、ウインドウの高さの下限 `max(320, fittingSize.height)` も、内容が低いときに最後の項目の下へ空白を作る（R6）
- **Alternatives considered**: 60pt を小さい値へ変える（言語・フォントの大きさに依存し、同じ問題が再発する）

## R3 長い文の折り返し（EC-141）

- **Decision**: 確認のチェックボックスを `KeyViewCheckbox` を継承した `WrappingCheckbox` にする。`intrinsicContentSize` を、現在の幅
  （0 のときは stack の幅の制約による幅）で `cell.cellSize(forBounds:)` を求めた高さにし、`layout()` で幅が変わったら `invalidateIntrinsicContentSize()` する。
  `cell.wraps = true`、`isScrollable = false`、幅は stack の幅に等しい制約を残す。補足説明は `NSTextField(wrappingLabelWithString:)` で、
  幅の制約（stack の幅 − 字下げ）から高さが決まる
- **Rationale**: 標準の `NSButton` の `intrinsicContentSize` は1行の幅で計算され、折り返した行数を高さに反映しない。これが従来 60pt の固定の下限を
  必要とした理由と考えられる。幅から高さを計算すれば、余分な空白なしに必要な行数だけ高くなる。現在の主文は、日本語（30字前後・13pt）でも
  英語（約70字）でも幅 580pt（620 − 余白 40）に1行で収まる見込みで、折り返しは将来の訳に対する保険（GUI で1行であることを確認する）
- **2026-11-01 の修正**: GUI で四角が縮み文言がはみ出したため、高さを「1行のチェックボックスの高さ（`cell.cellSize.height`）」以上にし、
  `cellSize(forBounds:)` に渡す高さを有限の値（10,000pt）にした（quickstart.md の結果の記録）
- **Alternatives considered**: `wraps = false` で1行に固定する（訳が長くなると欠ける。FR-153 に反する）。チェックボックスの文言を空にして
  隣にラベルを置く（文言のクリックで切り替わる標準の動作と読み上げの名前を失う）

## R4 補足説明の見た目と位置

- **Decision**: `NSTextField(wrappingLabelWithString:)`、フォントは `NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)`（11pt）、文字色は
  `NSColor.secondaryLabelColor`。`isSelectable = false`、`isEditable = false`、`refusesFirstResponder = true`。
  チェックボックスとの間隔は `setCustomSpacing(4, after: confirmFileOperationsCheckbox)`。
  字下げは、チェックボックスのセルの `titleRect(forBounds:)` の `minX`（文言の先頭の x 座標）とする。補足説明はコンテナの view に入れ、
  `leading = container.leading + 字下げ`、`trailing = container.trailing` で配置する。求めた値が 14〜28pt の範囲にない場合は 20pt を使う
- **Rationale**: macOS の標準の設定画面は、チェックボックスの説明を小さい二次的な文字でチェックボックスの文言の下に揃えて置く（Issue の dl/dd の参考に相当）。
  `secondaryLabelColor` はライト／ダーク・「コントラストを上げる」に OS が合わせる（EC-142）。字下げをセルから求めると、OS の版でチェックボックスの
  四角の大きさが変わっても揃う。範囲外の値の保険は、セルの値が想定外の場合に補足説明が大きくずれることを防ぐ
- **Alternatives considered**: 固定の 18 / 20pt（OS の版による差に追従しない）。`NSFont.labelFontSize`（10pt。読みにくい）。
  独自の灰色（ダーク表示とコントラストの設定に追従しない）

## R5 アクセシビリティ

- **Decision**: 確認のチェックボックスに `setAccessibilityHelp(補足説明)` を設定し、補足説明のラベルは `setAccessibilityElement(false)` にする。
  `updateLocalizedLabels()` で両方を新しい言語の文言に更新する。Tab の移動順（`nextKeyView` の手書きの鎖）は変えない
- **Rationale**: VoiceOver はチェックボックスの名前・状態の後にヘルプを読むため、補足説明が主文に従属して読まれる（FR-209（4））。ラベルも
  要素として残すと同じ文を二重に読む。ラベルは `refusesFirstResponder` で Tab の対象にならない
- **Alternatives considered**: ラベルを残して `setAccessibilityTitleUIElement` などで結び付ける（チェックボックスの名前が補足説明に置き換わるおそれ）

## R6 ウインドウの高さ

- **Decision**: 高さの下限 320pt を外し、`contentView.fittingSize.height` に合わせる。初期化時と `updateLocalizedLabels()` の最後に
  `resizeToFitContent()` を呼び、ウインドウの上端（`frame.maxY`）を保って高さだけを変える。幅は 620pt のまま
- **Rationale**: stack の下端の制約は `lessThanOrEqualTo(bottom − 20)` のため、ウインドウが内容より高いと最後の項目の下に空白が残る（FR-208（4））。
  表示言語の切り替えで行数が変わった場合も合わせ直す（EC-143）。上端を保つと、開いているウインドウの見出しの位置が動かない
- **Alternatives considered**: 下端の制約を `equalTo` にして高さを内容で固定する（初期化の順序で制約の衝突が起きやすい。`fittingSize` を使う既存の方法を保つ）

## API の存在の確認（CI の前に）

使う API は、いずれも AppKit の公開 API で、macOS 15 SDK に含まれる: `NSStackView.setCustomSpacing(_:after:)`（10.13）、
`NSTextField(wrappingLabelWithString:)`（10.12）、`NSFont.smallSystemFontSize`、`NSColor.secondaryLabelColor`（10.10）、
`NSCell.titleRect(forBounds:)`、`NSCell.cellSize(forBounds:)`、`NSAccessibilityProtocol.setAccessibilityHelp(_:)`・`setAccessibilityElement(_:)`。
実装の前に、Swift での名前（`NSFont.smallSystemFontSize` はクラスプロパティ）を Apple の文書で再確認する（`docs_private/cloud-agent-workflow.md` 4 章）。
