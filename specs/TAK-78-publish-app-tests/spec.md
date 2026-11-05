# Feature Specification: 公開書き出しでの App テスト

> **移行済み（2026-11-05）**: 現在の仕様は [specs/product/](../product/README.md) を正とする。
> このファイルは TAK-78 時点の記録として凍結しており、更新しない。

**Feature Branch**: `feature/tak-78-publish-app-tests`
**Created**: 2026-11-05
**Status**: Draft
**Input**: TAK-78 公開書き出しの検査に FolzioAppTests を含める

## User Scenarios & Testing

### User Story 1 - 公開前に App の回帰も検査する (Priority: P1)

保守者は公開書き出し時に Core、App、性能テストを検査し、App の回帰を見逃さずに公開の準備を行える。

**Independent Test**: 一時的な公開元・公開先を使い、検査の実行順と失敗時の停止を確認する。実際のテストの選択は macOS でも確認する。

**Acceptance Scenarios**:

1. **Given** 書き出しが検査に到達する、**When** 全検査が成功する、**Then** Core・App・性能テストが実行され、既存のネットワーク検査とステージングへ進む。
2. **Given** App を含む通常テストが失敗する、**When** 書き出しを行う、**Then** 非ゼロ終了し、性能テスト、ネットワーク検査、ステージングを実行しない。
3. **Given** 性能テストが失敗する、**When** 書き出しを行う、**Then** 非ゼロ終了し、ネットワーク検査とステージングを実行しない。

### User Story 2 - 公開手順を確認する (Priority: P2)

保守者は検査の対象、順序と失敗時の公開先の状態を手順から確認できる。

**Independent Test**: 運用手順と実際の実行順を照合する。

**Acceptance Scenarios**:

1. **Given** 公開を準備する、**When** 公開手順を読む、**Then** Core・App・性能テストが実行され、テスト失敗より前に公開先の同期が済むことが分かる。

### Edge Cases

- 同期後にテストが失敗すると公開先の作業ツリーには同期済みの変更が残る。ロールバックは行わない。
- Core やビルドの失敗時にも既存どおり後続の処理を中止する。
- フィルターの選択漏れを避けるため、実際の macOS 環境で App と Core が通常テストに含まれることを確認する。

## Requirements

### Functional Requirements

- **FR-311**: 公開書き出しは書き出し先で Core と App のテストおよび性能テストを実行し、性能テストを他のテストと同時に実行してはならない。いずれかの検査が失敗した場合は非ゼロ終了し、その後の検査とステージングを行わない。
- **FR-312**: 公開手順は検査の対象と順序、テスト失敗前に公開先への同期が行われることを明記しなければならない。

## Success Criteria

### Measurable Outcomes

- 正常時の検証で 3 つのテスト対象が実行され、性能テストは他のテストと重ならない。
- 通常テストと性能テストの各失敗ケースで後続のステージングが 0 回となり、非ゼロ終了する。
- 手順の検査対象と順序が実際の公開処理に一致する。

## Assumptions

- 公開対象は同期前の検査を通った開発リポジトリの HEAD である。公開先の同期とロールバックの方式は変更しない。
- アプリのテストの実行には macOS と Swift が必要。一時ディレクトリを使う公開スクリプトの回帰テストには rsync が必要。
- ターゲット一覧の製品仕様更新は別の ISSUE で扱う。

## 反映先

| 要件 | 反映先 |
| --- | --- |
| FR-311・FR-312 | `specs/product/overview.md` の「公開用と開発用スクリプト」 |
| 件数 | `specs/product/README.md` |
| 公開処理の契約 | `specs/product/contracts/scripts.md` |
