# Bug Assessment: ドロップを返した後に約束を要求する確認スクリプト

- **Slug**: tak-88-probe-request-timing（測定の文脈から採用）
- **Created**: 2026-11-09
- **Issue**: TAK-88
- **Source**: 保守者によるT006の操作と保存したログ、macOS 27.2 SDKのNSFilePromiseReceiver.h
- **Verdict**: valid
- **Severity**: medium（確認スクリプトの実測を妨げる）

## Symptom

Safari等の約束でfileNamesが空のままキャンセルする場合がある。確認スクリプトはreceivePromisedFilesをTaskと一時フォルダ作成の後へ遅らせ、ドロップを先に返していた。

## 仕様との照合

製品のSourcesはまだ未実装で、T004の開発用確認スクリプトとT006の測定の不具合として扱う。製品仕様IDへの違反を修正する作業ではない。
製品設計のR3とFR-350にも関係するが、そちらはT007の変更案として保守者に示し、確定前にPhase 2へ進まない。

## Reproduction

1. 旧版でSafari PNG、写真MP4をドロップすると、いずれもキャンセルを記録した。
2. 診断版では受け取り先をSwift起動前に作り、performDragOperation内で全要求を呼んでから返した。
3. Safari PNG（19:04）、写真MP4（19:10）、追加3件（19:19〜19:21）で書き出しに成功。全要求がdrop-returnより前であることもログで確認。

## Suspected Code Paths

- scripts/dev/pasteboard-probe.swift: DropView.performDragOperation / ProbeController.receivePromises。
- receivePromises内のTaskと、Task.detachedのフォルダ作成を待つ箇所。

## Root Cause Hypothesis

確度: 要求がドロップ後へ遅れるコード経路は高、個々のキャンセルの原因がその時機だけであるとの断定はしない。
診断版は宛先の場所・事前作成も異なる。SIGBUSとの因果関係は未確定で、この修正の対象ではない。

## Proposed Remediation

起動時にバックグラウンドで受け取り先を2個準備し、操作が消費したら補充する。準備済みのフォルダを同期的に取得し、同じドラッグの全receiverへ共通の宛先で要求してから返す。
未準備ならドロップをfalseで拒否する。readerは明示的なSendableの非隔離コールバックを維持する。GUI起動は保守者が行う。

**Files likely to change**: scripts/dev/pasteboard-probe.swift、quickstart.md、checklists/validation.md、同じbugディレクトリの記録。

**Tests to add or update**: 実際に使うフォルダ準備の自己検査。未準備でnil、作成はバックグラウンド、消費後に別の実在フォルダで補充されること。

## Risks & Considerations

- 準備が終わる前のドロップは受け付けない。起動時ログとquickstartで説明する。
- 検査用スクリプトのフォルダは従来どおり終了後も残す。製品の掃除の実装ではない。
- 診断版のGUI成功と、修正後の通常スクリプトそのもののGUI確認は区別する。
- 変更内容の説明後、保守者が「続けてください」と報告した範囲で確認スクリプトの修正を進める。T007の仕様案の承認とは扱わない。
