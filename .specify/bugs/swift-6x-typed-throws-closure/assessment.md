# Bug Assessment: Swift 6.0〜6.2 のツールチェーンで FolzioCore がビルドできない

- **Slug**: swift-6x-typed-throws-closure
- **Created**: 2026-10-30
- **Source**: GitHub Actions のビルドログ（TAK-25 の PR yoshidax/folzio-dev#1。macos-15 の Xcode 16.4 と Xcode 26.3 の 2 回分）
- **Issue**: [TAK-28](https://linear.app/takyoshida/issue/TAK-28)（関連: TAK-25）
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

macOS 15 のランナーで `swift build` が失敗する。エラーは 2 回とも同じ 2 か所だけ。

| 実行 | ランナーの Swift | 結果 |
|---|---|---|
| 1 回目 | 6.1.2（Xcode 16.4。ランナーの既定） | 失敗 |
| 2 回目 | 6.2.4（Xcode 26.3。`xcode-select` で固定） | 失敗 |
| ローカル | 6.4（macOS 26） | 成功 |

```
Sources/FolzioCore/Archive/ArchiveEntryStream.swift:51:13: error: thrown expression type 'any Error' cannot be converted to error type 'ArchiveError'
 51 |         try result.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) throws(ArchiveError) in
Sources/FolzioCore/Archive/ArchiveEntryStream.swift:97:13: error: (同上)
 97 |         try data.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) throws(ArchiveError) in
```

ビルドは `FolzioCore` のコンパイル中に止まる。ほかのモジュール（`FolzioLocalization`、`FolzioApp` など）のエラーの有無は、まだ分からない。

## 仕様との照合

- `specs/product/` には、必要な Swift・Xcode の最小の版を定めた項目がない（`swift`・`Xcode`・`toolchain` を検索して確認した）。
  近い項目は FR-168（Folzio の名称とディレクトリでビルド、テスト、アプリ生成を行える）と SC-078（新しい名前の一時ディレクトリでビルドと全自動テストが成功する）で、版は指定していない
- 版の宣言は次の 3 か所にある
  - `Package.swift:1` — `// swift-tools-version: 6.0`
  - `docs/development.md:16`・`docs/development.ja.md:16` — 「`swift --version` が 6.0 以上であること」
  - `README.md:42` — 「Xcode with the Swift 6 toolchain is required」
- 判定: **実装が、リポジトリが宣言している要件（Swift 6.0 以上）に反している**。ただし、宣言は `specs/product/` ではなく
  `Package.swift` と公開用ドキュメントにある。AGENTS.md の「仕様が定めていない」に当たるかは、ユーザーの判断が必要（Open Questions を参照）

## Symptom

Swift 6.0〜6.2 のツールチェーンでは、`swift build` が `FolzioCore` のコンパイルで失敗する。Swift 6.4 では成功する。
期待する動作は、宣言している Swift 6.0 以上のどの版でもビルドとテストが通ること。

## Reproduction

1. macOS 15 で、Xcode 16.4（Swift 6.1.2）または Xcode 26.3（Swift 6.2.4）を選ぶ（`xcode-select -s`）
2. `swift build` を実行する
3. `ArchiveEntryStream.swift` の 51 行目と 97 行目で、上のエラーになる

[NEEDS CLARIFICATION: Swift 6.3 で成功するか。ローカルは 6.4 のみで確認している。直った版の特定は修正に必要ない]

## Suspected Code Paths

- `Sources/FolzioCore/Archive/ArchiveEntryStream.swift:51` — `readStored` の `result.withUnsafeMutableBytes { ... throws(ArchiveError) in ... }`
- `Sources/FolzioCore/Archive/ArchiveEntryStream.swift:97` — `chunk(at:)` の `data.withUnsafeMutableBytes { ... throws(ArchiveError) in ... }`
- 同じ形の呼び出しはほかにない。`withUnsafe*` に型付き throws のクロージャを渡している箇所を `Sources/` 全体で検索して確認した
  （`throws(ArchiveError)` を宣言しているクロージャはこの 2 か所だけ）
- クロージャの中で呼んでいる `ArchiveFile.read(into:at:)`（`ArchiveFile.swift:61`）と `InflateCursor.read(into:maxLength:)`
  （`InflateCursor.swift:91`）は、どちらも `throws(ArchiveError)` で、これ自体はコンパイルできている（エラーに出ていない）

## Root Cause Hypothesis

エラーが指すのはクロージャの中ではなく、`try` を付けた `withUnsafeMutableBytes` の呼び出し式（`:51:13`・`:97:13`）で、
「投げる型が `any Error`」と判定されている。つまり、Swift 6.1.2 と 6.2.4 に付属する Foundation の `Data.withUnsafeMutableBytes` は、
クロージャの投げる型を呼び出しの投げる型へ引き継がない（`rethrows` 相当で、`any Error` になる）。そのため、`throws(ArchiveError)` の
関数の中でそのまま使えない。Swift 6.4 の SDK では引き継ぐようになったと考えられる。

確度: **中**。ログのエラー位置と、版による成否の違いからの推定で、Foundation の変更履歴は確認していない。
修正の方針は、この仮説が外れていても有効（版に依存しない書き方にする）。

## Proposed Remediation

**Preferred**: `withUnsafeMutableBytes` に渡すクロージャを、型付き throws にしない。クロージャの中で起きた `ArchiveError` は、
外側の変数に退避し、呼び出しの後に投げ直す。

```swift
/// Calls `body` with the mutable bytes of `data` and rethrows its `ArchiveError`.
/// Foundation's `Data.withUnsafeMutableBytes` does not carry a typed error through on older toolchains.
private func withMutableBytes(of data: inout Data, _ body: (UnsafeMutableRawBufferPointer) throws(ArchiveError) -> Void) throws(ArchiveError) {
    var failure: ArchiveError?
    data.withUnsafeMutableBytes { buffer in
        do throws(ArchiveError) { try body(buffer) } catch { failure = error }
    }
    if let failure { throw failure }
}
```

`readStored` と `chunk(at:)` の呼び出しを、この関数に置き換える。クロージャの本体（読み込みのループ）は変えない。
`do throws(ArchiveError)` は `BrowserModel.swift:1001` と `:1141` で既に使っていて、Swift 6.0 から使える。

**Alternatives**:
- `[UInt8]` や `UnsafeMutableRawBufferPointer.allocate` に読み込んでから `Data` へ移す。型付き throws の問題は避けられるが、
  チャンク（最大 1 MB）ごとにコピーが 1 回増え、メモリの上限の設計（`ArchiveEntryStream.swift` の冒頭のコメント）に影響する
- CI の Xcode を上げる（方針 B）。Xcode 26.3（Swift 6.2.4）でも失敗したため、`macos-15` のランナーでは解決しない。
  `macos-26` に変えても、Swift の版が足りる保証がなく、宣言している「6.0 以上」とも合わない

**Files likely to change**:
- `Sources/FolzioCore/Archive/ArchiveEntryStream.swift`

**Tests to add or update**:
- 既存の `Tests/FolzioCoreTests/ArchiveEntryStreamTests.swift`（stored と deflated の読み込み）が、動作を変えないことの確認になる
- 切り出した関数の「`ArchiveError` が投げ直される」ことを固定するテストを足す。`dataTruncated`・`compressedDataTruncated` の
  経路が、既存のテストで通っているかを fix の最初に確認し、なければ足す
- 今回の不具合は「特定のツールチェーンでコンパイルできない」ことなので、**再現を固定する回帰テストは、CI のビルドそのもの**になる。
  ローカル（Swift 6.4）のテストでは再現しない

## Risks & Considerations

- ビルドは最初のエラーのあるモジュールで止まる。修正後に、`FolzioLocalization`・`FolzioApp`・テストターゲットで、
  別の互換性のエラーが見つかる可能性がある。CI での確認を繰り返す前提にする
- この環境（クラウド）には Swift がなく、ローカルでもビルドの確認ができない。確認できるのは、TAK-25 の CI だけ
- 「6.0 以上」を保証する確認には、Swift 6.0 の Xcode 16.0 でのビルドが要る。`macos-15` のイメージに `Xcode_16.0.app` はある
  （2 回目のログのインストール済み一覧で確認）。ただし、CI の Xcode は 1 つに固定するか、複数の版で回すかは、
  macOS のランナーの使用時間とのトレードオフ
- 補助関数は実行時の挙動を変えない。ただし、`Data` の領域へのアクセスの安全性（クロージャの外へポインタを持ち出さない）は保つ

## Open Questions

- [NEEDS CLARIFICATION: これを `specs/product/` が「定めていない」ケースとして、sdd-increment で「必要なツールチェーンの最小の版」を
  仕様に加えるか。それとも、宣言（`Package.swift`・docs）に反する不具合として、bug フローで直すか。bug フローを推奨する。
  最小の版を `specs/product/` に書くかは、別の小さな変更として扱える]
- [NEEDS CLARIFICATION: CI で確認する Swift の版。最小（Xcode 16.0 = Swift 6.0）と最新のどちらか、または両方]
- [NEEDS CLARIFICATION: 修正のブランチと PR を、TAK-25 の PR（#1）より先に出すか、後に出すか。
  修正の CI を動かすには、ワークフローが master にある必要があるため、PR #1 を先にマージする順序を推奨する]
