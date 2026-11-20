# Specification Quality Checklist: コピー元を移動した後もペーストできるようにする

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-11-20
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

- 範囲（Folzio の操作だけ、削除・ゴミ箱は失敗のまま、別のアプリのコピーも対象）は、2026-11-20 に保守者が選んだ。
- FR-414 の「Folzio が中身を把握しているクリップボードだけ」は、FR-354（file-operations.md）の
  「中身はペーストの実行時だけ読む」を保つための制約。設計レビューで保守者の確認を受ける。
- SC-237（Finder でのペースト）は macOS での手動確認が要る。
