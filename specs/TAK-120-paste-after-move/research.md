# Research: コピー元を移動した後もペーストできるようにする

## R0 方式の見直し（クリップボードの書き換えをやめた理由）

- 当初の設計（コミット 7474d21）は、Folzio の移動・名前の変更の後に、クリップボードのパスを移動後のパスへ書き換えた。
- 保守者の指摘: 後から書き換えるのはコピーした内容の改変になる。Finder はクリップボードを書き換えずに、移動後もペーストできる。
- 当初の設計で Finder の仕組みを採らなかった理由は、仕組みを確かめていなかったこと（当時の A-248）と、最初の質問で参照の方式を
  難しく示し、範囲を「Folzio の操作だけ」に寄せたことにある。根拠の弱い判断だったため、確かめてから改めた（R1）。

## R1 Finder の仕組み

- **Decision**: Folzio のコピーも、Finder と同じくファイルの参照とファイル名の文字列を置く。
- **Rationale**: 保守者が 2026-11-20 に、Finder でファイルを ⌘C した直後のクリップボードを次のコマンドで書き出した。
  1項目に `public.file-url = file:///.file/id=6571367.196396778`、`public.utf8-plain-text = <ファイル名>`、
  `public.utf16-external-plain-text`、`com.apple.icns` があった（A-248）。

  ```bash
  osascript -l JavaScript -e 'ObjC.import("AppKit"); const pb = $.NSPasteboard.generalPasteboard; const items = ObjC.unwrap(pb.pasteboardItems) || []; const out = ["changeCount=" + pb.changeCount, "items=" + items.length]; items.forEach((item, i) => { ObjC.unwrap(item.types).forEach(t => { const type = ObjC.unwrap(t); const s = item.stringForType(type); out.push(i + " " + type + " = " + (s.isNil() ? "(no string)" : ObjC.unwrap(s))); }); }); out.join("\n")'
  ```

  `file:///.file/id=…` はファイルの参照の URL で、Apple の `NSURL` の文書では、パスでなくファイルの ID で項目を指し、
  同じボリュームの中で移動・名前の変更をしても同じ項目を指し続ける（A-250）。ゴミ箱に入れるのも同じボリュームの中の移動のため、
  Finder がゴミ箱に入れた項目をペーストできた（A-249）ことと合う。
- **Alternatives considered**: 移動の後にクリップボードを書き換える（R0）: 保守者が退けた。

## R2 参照の作り方と、Swift の `URL` への変換の注意

- **Decision**: CoreFoundation の `CFURLCreateFileReferenceURL` で参照を作り、`CFURLGetString` の文字列として持つ。
  解決は、その文字列から `CFURLCreateWithString` で作った URL に `CFURLCreateFilePathURL` を使う。
  どちらも `CFURL` のまま扱い、Swift の `URL` を経由しない。
- **Rationale**: Swift の `URL` に変換すると、参照の URL がパスの URL に変わる場合があると知られている（未確認）。今の Folzio の
  ペーストが Finder の参照を扱えたのは（A-251）、読み取りの `$0 as URL`（`PasteboardFileURLs.fileURLs`）でパスに解決された
  ためと考えられるが、確かめていない。参照の文字列を確実にクリップボードへ書くため、作成から書き込みまで文字列で扱う。
  CoreFoundation は Foundation と同じく AppKit を要らないため、`FolzioCore` に置ける。
- **確かめ方**: CI（macOS）の単体テストで、作った文字列が `file:///.file/id=` で始まること、移動・名前の変更の後に新しいパスへ
  解決されることを確かめる。
- **Alternatives considered**: `NSURL.fileReferenceURL()`: Swift では `URL?` を返し、上の変換の問題を避けにくい。

## R3 UI スレッドの外で用意してから書く

- **Decision**: ⌘C で、まず対象の URL とクリップボードの版（`changeCount`）を取り、`Task.detached` で参照とファイル名を用意し、
  UI スレッドに戻ってから、版が同じときだけ書く（EC-281）。ペーストでは、UI スレッドで項目の文字列を読み（FR-354 の
  ペーストの実行時）、`Task.detached` で解決してから、既存の `copy`・`move` に渡す。
- **Rationale**: 参照の作成と解決はファイルシステムへの問い合わせであり、UI スレッドで行わない（AGENTS.md の設計の制約、憲章 II）。
  用意している間に利用者が別のものをコピーした場合、後から Folzio が上書きすると、利用者の新しいコピーが失われる。
- **影響**: ⌘C の直後、書き込みの前に ⌘V を押すと、前のクリップボードの内容がペーストされうる。項目ごとに1回の問い合わせで
  あり、通常は人の操作より速く終わる。これは保守者の確認の対象にする（quickstart.md）。
- **Alternatives considered**: クリップボードの約束（データを要求されたときに作る）: 約束のデータは UI スレッドで作ることになり、
  制約に反する。

## R4 解決できない参照の示し方

- **Decision**: 解決できない参照（別のボリュームへ移動した、削除した）は、同じ項目のファイル名の文字列（なければ参照の文字列）を
  名前として、`sourceNotFound` の失敗にする。コピー・移動の失敗とまとめて、既存の失敗の表示（`presentFailures`）で1回示す（EC-283）。
- **Rationale**: 失敗の表示は `failure.url.lastPathComponent` を名前にするため、参照の URL のままでは `id=…` が表示される。
  Finder と Folzio のコピーは、ファイル名の文字列を置いている（A-248・FR-413）。
- **Alternatives considered**: 解決できない項目を黙って除く: 何がペーストされなかったかが分からない。

## R5 変えないところ

- **ドラッグ**: ドラッグのクリップボードの読み取り（`InternalDrag`・`ExternalDrag` の `PasteboardFileURLs.fileURLs`）は変えない。
  ドラッグ中は項目が移動しないため、参照を解決し直す必要がない。
- **メニューの有効・無効**: `PasteboardImport.availability` は型（`public.file-url`）だけを見るため、参照でもパスでも同じく有効になる。
- **パス名をコピー**: パスの文字列を置く（FR-181）。変えない。
- **パスの file URL**: 以前の版のコピーなど、パスで置かれた file URL は、`CFURLCreateFilePathURL` がそのパスを返すので、従来どおり（EC-285）。
