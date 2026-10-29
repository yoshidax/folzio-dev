# Research: Folzioへの改名

## R1: アプリの同一性

- Decision: 表示名と `.app` / 実行ファイルを Folzio、Bundle IDを `local.folzio.Folzio` とする。
- Rationale: 製品名と成果物を統一する。従来の識別子から変わる設定ドメインを明示する。
- Alternatives: 旧Bundle IDの維持はブランド変更を不完全にする。所有者未確定のインターネットドメインは使わない。

## R2: 設定移行

- Decision: `.app` と `swift run` の保存先を別々にユーザーの明示操作で移す。移行先の永続ドメインが存在すれば停止し、旧ドメインを残す。移行前にローカルバックアップを作る。
- Rationale: アプリ内に旧ドメインへの恒久依存を持たず、既存の新設定の損失を避ける。
- Alternatives: 自動上書きやアプリ起動時の自動移行は採用しない。

## R3: ソースと生成リソース

- Decision: Package・ターゲット・ソースディレクトリ・テストとリソース参照を一体で改名し、`make-app.sh` のSwiftPM生成リソースバンドルを新しい実際の生成名に合わせる。
- Rationale: 翻訳バンドル名はPackage名とターゲット名に依存する。変更後の実物で確認が必要。
- Alternatives: 表示名だけの変更は採用しない。

## R4: 公開ディレクトリとパス

- Decision: `publish.sh` で公開先の `.vscode/` を同期・削除から保護し、既定先を `../folzio-oss` にする。移動先が存在する場合は移動を止める。
- Rationale: 実際の公開先には未追跡の `.vscode/` があり、既存の `rsync --delete` はそのままだと消去する。
- Alternatives: 無条件の書き出しやIDE設定の破棄は採用しない。

## R5: 検証と移動の順序

- Decision: 実装・自動検証・GUI確認・product spec反映の後、ユーザーが実際のフォルダを移動して再確認する。feature内では一時領域で移動をリハーサルし、移動後の実確認は運用引き継ぎとして記録する。
- Rationale: ユーザーが了承した作業順序と、現在の書き込み権限・IDEセッションを保つ。
- Alternatives: 作業中の現在のワークスペースを自動移動する方法は採用しない。
