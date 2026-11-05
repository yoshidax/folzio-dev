# Research: 仕様反映と凍結注記

## TAK-10 の未反映部分

- Decision: FR-018 に末尾の半角十進連番、整数型の上限を設けないこと、生成時の先頭ゼロ除去を追加し、FR-025 に「両方残す」が FR-018 に従うことと既存項目を変更しないことを追加する。
- Rationale: `specs/TAK-10-unbounded-counters/spec.md` とマージ済みの `NameValidation.swift`、`NameValidationTests.swift`、`FileOperationServiceTests.swift` は同じ振る舞いを示す。`specs/product/file-operations.md` はその詳細を未記載。
- Alternatives: 凍結注記だけを付ける案は、未反映の内容を移行済みと誤認させるため採らない。

## 既存 feature の記録

- Decision: 005 は開発環境向けで `specs/product/` への反映対象外と注記する。TAK-46 と TAK-49 は既存の製品仕様への反映を確認し、対応表を保持したまま注記する。TAK-10 は製品仕様の反映後に注記する。
- Evidence: 005 の反映先は開発文書・設定。TAK-46 は `file-list.md` の FR-269〜272 など、TAK-49 は `preview.md` の FR-287 などに反映済み。
- Alternatives: 005 に製品仕様への移行済みとだけ記す案、TAK-10 の反映前に移行済みと記す案はいずれも事実と異なる。
