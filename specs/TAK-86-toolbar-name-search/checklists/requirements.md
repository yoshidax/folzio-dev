# Specification Quality Checklist: ツールバーの検索欄による名前の絞り込み

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-11-12
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- 2026-11-12 に保守者が要件を改めた（起点からの検索 → 表示中の一覧の絞り込み）。先に作った設計文書は、この内容で書き直した
- 反映の時点・移動時の扱い・虫眼鏡・照合の規則と対象・保存済みの並びの扱いは、2026-11-12 に保守者が決めた（spec.md の Clarifications）
- 次の点は、仕様の作成時に置いた既定で、設計のレビューで確認する
  - 検索欄へ移るコマンド「名前で絞り込む」（⌥⌘F）の追加（FR-391・A-227。憲章 原則 III のため）
  - 検索欄が見えないときに絞り込みを解除する扱い（FR-393・A-226）
  - 検索結果を絞り込んでも検索バーの件数を変えない扱い（FR-382・A-225）
  - セットのラベル「絞り込み」と文言（FR-392）
- FR-393 の識別子 `nameFilter` は保存する設定値の契約（contracts/settings.md）で、実装の詳細ではない
- 「標準の検索フィールド」は FR-081（search.md）と同じ用語で、見た目と操作の要件として使う。実装の方式は plan.md で決める
