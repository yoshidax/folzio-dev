# Research: 仕様反映と凍結注記

## TAK-10 の未反映部分

- Decision: FR-018 に拡張子を除いた名前の末尾の半角十進連番、整数型の上限を設けないこと、ゼロだけの扱い、生成時の先頭ゼロ除去、大文字小文字を区別しない空き名判定を追加し、FR-025 に「両方残す」が FR-018 に従うことと既存項目を変更しないことを追加する。
- Rationale: `specs/TAK-10-unbounded-counters/spec.md` とマージ済みの `NameValidation.swift`、`NameValidationTests.swift`、`FileOperationServiceTests.swift` は同じ振る舞いを示す。`specs/product/file-operations.md` はその詳細を未記載。
- Alternatives: 凍結注記だけを付ける案は、未反映の内容を移行済みと誤認させるため採らない。

## 既存 feature の記録

- Decision: 005 は開発環境向けで `specs/product/` への反映対象外と注記する。TAK-46 と TAK-49 は既存の製品仕様への反映を確認し、対応表を保持したまま注記する。TAK-10 は製品仕様の反映後に注記する。
- Evidence: 005 の反映先は開発文書・設定。TAK-46 は `file-list.md` の FR-269〜272 など、TAK-49 は `preview.md` の FR-287 などに反映済み。
- Alternatives: 005 に製品仕様への移行済みと記す案、TAK-10 の反映前に移行済みと記す案はいずれも事実と異なる。005 は「凍結（製品仕様の反映対象外）」と明示する。

## 過去の検証・進捗記録

- TAK-10: 元の `tasks.md` T005 は、9f37375 の通常テスト成功と性能テスト 27 件中 1 件失敗、レビュー後 4cc183d 未検証のまま。T006 は保守者による起動・複製・両方残すの確認報告がある。T007 の製品仕様への反映は TAK-68 の PR #56 で行い、レビューは進行中。PR #56 の CI は TAK-10 を含む後続コミット f6944fa でビルド・通常 1057 件・性能 27 件が成功したが、4cc183d 自体の検証とは扱わない。
- TAK-46: 元の T010 は未チェックのまま。[PR #38](https://github.com/yoshidax/folzio-dev/pull/38) に保守者のライト／ダークでの GUI 確認報告があり、当時のコミット d32bc8e の [CI](https://github.com/yoshidax/folzio-dev/actions/runs/41462634000) は通常 1006 件・性能 27 件とも成功。アクセントカラー・選択背景の個別確認は PR 本文では不明。
- TAK-49: 元の T006・T007 は未チェックのまま。[PR #39](https://github.com/yoshidax/folzio-dev/pull/39) は ba691d8 のビルド・通常テスト 997 件の成功と、保守者による起動・シークの確認報告を記録する。性能テストは 27 件中 1 件が境界値超過で失敗し、再実行で確認されていない。
- 凍結注記は製品仕様への移行と記録の保全を示し、過去の未チェック項目がすべて完了したことを意味しない。元の tasks.md は履歴として保持し、未確認事項と後続の検証は上記のように区別する。

## FR の変更履歴

- TAK-10 の feature に元の FR-018・FR-025 の変更案がある。TAK-68 は未反映部分を現在の正本に追従し、拡張子・大文字小文字・ゼロだけの扱いも既存実装に照らして明確にする。
- `specs/product/README.md` は変更対象の ID について変更後の全文を現在の feature に記載するよう求めるため、TAK-68 の spec.md にも全文を残す。二つの記録は時点ごとの履歴であり、現在の正本は `specs/product/` とする。
