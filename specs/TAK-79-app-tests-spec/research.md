# 調査: Swift Package のターゲット

`Package.swift` はテストターゲット `FolzioCoreTests`、`FolzioAppTests`、`FolzioPerformanceTests` を定義する。日英の開発ガイドも同じ 3 つを案内する。一方 `specs/product/contracts/app-bundle.md` は App のテストターゲットを欠いている。

契約の既存一覧に `FolzioAppTests` を加えれば差分を解消できる。ターゲットの依存関係やテストコマンドを別の場所に複製する必要はない。`FR-166`・`FR-168` の本文は個別ターゲットを列挙しておらず変更不要。
