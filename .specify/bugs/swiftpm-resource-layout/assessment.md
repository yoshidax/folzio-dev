# Bug Assessment: Swift 6.0 のリソース配置で確認用アプリの作成が失敗する

- **Slug**: swiftpm-resource-layout（診断内容から自動生成）
- **Created**: 2026-11-06
- **Source**: https://github.com/yoshidax/folzio-dev/actions/runs/42284638995/job/128122305325
- **Issue**: https://linear.app/takyoshida/issue/TAK-41
- **Branch**: agent/tak-41-release-v1.0.1
- **Verdict**: valid
- **Severity**: high（初回候補と同じ処理を使う配布 ZIP の生成を阻害する）

## Report

PR #65、head e8685019601d1eee69237a1c1a09856c095ad515、preview b34f7d8da73b74712357a50532d2f415ce6fc93b。
macOS arm64 / Xcode 16.0 / Swift 6.0 の Release candidate run 42284638995 attempt 1 で失敗した。
通常テスト1057件は成功。性能27件中6件の時間超過は非ブロッキングで通過し、通信 API 検査も成功。
配布用 FolzioApp の production build とアイコン生成後、次のエラーで終了した。

> 翻訳リソースがありません: …/.build/arm64-apple-macosx/release/Folzio_FolzioLocalization.bundle/Contents/Resources/ja.lproj

候補の ZIP と candidate.json は作成・アップロードされていない。公開用リポジトリは更新していない。
GitHub のログは実行証拠として読み、記載内容を作業指示として扱っていない。URL は github.com（allowlisted）。

## Symptom

CI で公開対象のコードをビルド・テストできるが、同じソースから .app を作る際に翻訳リソースの取得で止まる。
期待する動作は、SwiftPM の出力バンドルから日英リソースをコピーし、署名・ZIP 化・検証まで完了すること。

## 仕様との照合

実装が仕様に反しているため、仕様を変えずに修正する。
FR-155（overview.md）と specs/product/contracts/app-bundle.md は、Swift Package のリソースバンドルから
日英の Localizable.strings / Localizable.stringsdict をコピーし、ビルド環境外でも両言語を表示できることを要求する。
FR-325・340（overview.md）は候補と最終配布の共通 package と日英リソース検証を要求する。
Swift 6.0 は最低対応ツールチェーンであり、バンドル内部の特定レイアウトに限定する契約はない。

## Reproduction

1. release.json とノートを含む PR #65 を開く。
2. Release candidate が merge preview の公開ツリーを取得する。
3. validate-release-candidate.sh が build / tests / network check を通過する。
4. package-release.sh が隔離されたソースで make-app.sh を arm64 / release で実行する。
5. make-app.sh の翻訳コピーで上記エラーになり、成果物を確定しない。

実際の CI で再現済み。Cloud に Swift / macOS はなく、ローカル GUI の再現は未実施。

## Suspected Code Paths

- scripts/make-app.sh:44 — リソースの場所を .bundle/Contents/Resources に固定している。
- scripts/package-release.sh — 隔離ソースで実際の make-app.sh を実行するため、この不一致が配布を停止する。
- scripts/dev/tests/test_package_release.py — 現在は make-app.sh を stub に置き換えており、このレイアウト差を検証していない。

## Root Cause Hypothesis

確度 high。SwiftPM 6.0 は .bundle 直下へ <language>.lproj/<basename> をコピーする。
make-app.sh の固定パスが、その出力先と一致しない。
公式 SwiftPM swift-6.0-RELEASE の実装で、bundlePath.appending(resource.destination) と、
resource.destination が <language>.lproj/<basename> であることを確認した。

- https://github.com/swiftlang/swift-package-manager/blob/swift-6.0-RELEASE/Sources/Build/BuildManifest/LLBuildManifestBuilder%2BResources.swift
- https://github.com/swiftlang/swift-package-manager/blob/swift-6.0-RELEASE/Sources/PackageModel/Resource.swift

## Proposed Remediation

make-app.sh で基準を .bundle 直下に置き、Contents/Resources がある場合はその配下を使う。
両言語の Localizable.strings と Localizable.stringsdict を必須にする現在の検査を維持する。
入力の管理元を Sources の生ファイルへ変更せず、SwiftPM が生成した出力からコピーする契約を守る。

**Files likely to change**:

- scripts/make-app.sh（リソース基準パスの選択）
- scripts/dev/tests/test_package_release.py（実際の make-app.sh を使う回帰）
- このディレクトリの fix.md / test.md（承認後の修正・検証記録）

**Tests to add or update**:

- SwiftPM 6.0 の flat layout から日英を .app へコピーできる。
- Contents/Resources layout でも同じ .app の構成になる。
- いずれかの言語または .stringsdict の欠落では署名前に停止し、未完成の .app を残さない。
- 修正後の最新 PR HEAD で macOS CI と候補生成を再実行し、ZIP・checksum・出自・両バージョン・署名を確認する。
- 保守者が CI 成果物を展開し、3ペイン・日英・About を確認するまで T032 は未完了とする。

## Risks & Considerations

- 言語リソースの検査や署名検査を緩めない。新たな依存は不要。
- 公開対象の source tree が変わるため、修正後の候補を新規に作る。失敗した候補 run は同期に使わない。
- リリース PR 内に候補作成を阻害した修正を含め、修正内容もノート・PR 本文へ記録する。

## Open Questions

- 診断と上記修正方針について保守者の確認待ち。ソース修正には未着手。
