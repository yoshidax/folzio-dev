# Bug Assessment: 最新の Swift（macOS SDK 27.2）で VideoPreviewView がビルドできない

- **Slug**: video-track-sendable-regression
- **Created**: 2026-10-31
- **Source**: pasted text（保守者のローカルの `swift build` の出力）
- **Issue**: [TAK-31](https://linear.app/takyoshida/issue/TAK-31)（回帰の元: TAK-28）
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

保守者のローカル（Xcode の最新版、macOS SDK 27.2、Swift 6 言語モード）で、`master`（TAK-28 のマージ後）の `swift build` が失敗する。

```
Sources/FolzioApp/Preview/VideoPreviewView.swift:71:44: error: sending 'asset' risks causing data races [#RegionIsolation::SendingRisksDataRace]
 71 |             let hasVideoTrack = await Self.loadHasVideoTrack(of: asset)
note: sending main actor-isolated 'asset' to @concurrent static method 'loadHasVideoTrack(of:)' risks causing data races
      between @concurrent and main actor-isolated uses
```

保守者の追加の報告: `swift build` と `swift build --build-tests` のどちらも、エラーはこの 1 件だけだった。

## Symptom

最新の SDK では `swift build` が失敗し、アプリをビルドできない。期待する動作は、最小の版（Swift 6.0）と最新の版の両方でビルドできること。

## 仕様との照合

- `specs/product/` には、必要な Swift・Xcode の版を定めた項目がない（TAK-28 の assessment と同じ）。
- 宣言は `Package.swift`（`swift-tools-version: 6.0`）と `docs/development.md`（「`swift --version` が 6.0 以上」）にある。保守者の通常の開発環境は最新の版であり、そこでビルドできないことは、宣言に反する。
- 判定: **実装が、宣言している要件に反している**（TAK-28 の変更が原因の回帰）。fix へ進む。

## Reproduction

1. 最新の Xcode（macOS SDK 27.2）で、`master`（`74064b2`）をチェックアウトする
2. `swift build` を実行する
3. `VideoPreviewView.swift:71` で上のエラーになる

## Suspected Code Paths

- `Sources/FolzioApp/Preview/VideoPreviewView.swift:49-55` — TAK-28 で足した `private nonisolated static func loadHasVideoTrack(of:)`
- `Sources/FolzioApp/Preview/VideoPreviewView.swift:70-75` — その呼び出し。メインアクターの `asset`（`AVAsset`）を、並行な関数へ渡している

## Root Cause Hypothesis

TAK-28 では、Swift 6.0 の SDK で `[AVAssetTrack]` が `Sendable` でないために出たエラー（`non-sendable type '[AVAssetTrack]' returned by implicitly asynchronous call to nonisolated function cannot cross actor boundary`）を、トラックを `Bool?` に変える `nonisolated` の補助関数で避けた。その補助関数へ `asset` を渡す部分が、最新の SDK では `AVAsset` が `Sendable` として扱われず、メインアクターから並行な関数への受け渡しとして拒否される。Swift 6.0 の SDK では `AVAsset` の受け渡しが通っていたため、CI は成功し、回帰に気づけなかった。

確度: **中**。エラーの位置と、補助関数を入れる前（`72753a3`）にビルドできていたことからの推定。SDK ごとの `AVAsset` の `Sendable` の扱いの違いは確認していない。

## Proposed Remediation

**Preferred**: 補助関数を取り除いて、TAK-28 より前のコード（`Task` の中で `asset.loadTracks(...)` を直接呼ぶ）に戻し、`@preconcurrency import AVFoundation` を足す。Swift 6.0 のコンパイラが、このエラーに対して提案した方法で、`AVFoundation` 由来の `Sendable` のエラーを警告に下げる。元のコードは最新の版でビルドできていたので、警告に下げるだけの追加が、最新の版のビルドを悪化させることはない。

**Alternatives**:
- `AVAsset` を渡さず、完了ハンドラ版の `loadTracks(withMediaType:completionHandler:)` と `withCheckedContinuation` で `Bool` だけを取り出す。どちらの版でも通る可能性があるが、ヘッダーで存在と可否を確認できず、この環境ではコンパイルできないため、今回は採らない。
- `nonisolated(nonsending)` を使う。Swift 6.2 以降の構文で、最小の版（6.0）ではコンパイルできないため採らない。

**Files likely to change**:
- `Sources/FolzioApp/Preview/VideoPreviewView.swift`

**Tests to add or update**:
- 追加するテストはない。今回の不具合は「特定の版でコンパイルできない」ことなので、**再現を固定する回帰テストは、ビルドそのもの**になる。Swift 6.0 は CI、最新の版は保守者のローカルで確認する。

## Risks & Considerations

- この環境（クラウド）には Swift がなく、CI（macos-15、Xcode 16.0）には最新の SDK がない。**最新の版での確認は、保守者のローカルでしかできない。** この種の回帰は CI では見つからない。
- `swift build` は最初のエラーで止まるため、ほかのファイルにも最新の版のエラーがあるかもしれない。保守者の報告では、`swift build` と `swift build --build-tests` ともにエラーはこの 1 件だけだったが、`swift test` の実行までは確認していない。
- `@preconcurrency` は、そのファイルの `AVFoundation` 由来の `Sendable` の診断を警告に下げる。今後そのファイルで本物のデータ競合の指摘が警告に埋もれる可能性があるが、`VideoPreviewView` は `@MainActor` で、`AVFoundation` の呼び出しはメインアクターから行われている。
- 元のコードに戻すため、TAK-28 で足した補助関数による動作の変化はなくなる（動作は TAK-28 より前と同じになる）。

## Open Questions

- なし（診断と方針は、保守者が確認済み）。
