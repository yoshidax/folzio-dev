# Research: TAK-16

調査基準: `origin/master` bfe63d5（2026-10-31 取得、work に fast-forward）。静的調査のみ。macOS での操作・Swift build/test はまだ実行していない。

## R1: 元項目と別項目の区別

**Decision**: 親の実際のエントリ名から元名の完全一致だけを除き、caseInsensitiveCompare で残りを照合する。元項目の URL は現行 UI と同じく列挙で得た保存名を持つ前提。

**Rationale**: Coordinator.rename は既に siblingNames.subtracting([file.lastPathComponent]) を行う。一方 Service.rename は target が存在すると abort で sameNameExists にするため、case-insensitive volume の自己改名も拒否する。Core 側でも兄弟を確認する必要がある。

**Alternatives considered**: sameItem は実体 ID と symlink の解決を使うため、別エントリのハードリンクまで自己扱いする。大文字小文字を無視して元名を除く方法も別の Photo.png を見落とす。いずれも不採用。

## R2: 改名の方法

**Decision**: 自己の case-only なら target の存在による拒否を外し、既存の FileManager.moveItem を使い入力表記の target を返す。通常の改名と競合エラーは別に扱う。

**Rationale**: 既存の操作経路を維持し、途中の一時パス・復旧失敗という新しい状態を作らない。ファイルとフォルダを同じ経路で扱える。

**Alternatives considered**: 一時名を経由する方式は、二段目と復旧の失敗時の契約が必要になるため初期設計では採らない。POSIX の独自移動処理も導入しない。

**Verification limit**: この環境では macOS の FileManager.moveItem による case-only の成功を確認できない。最初の macOS テストで実際のディレクトリエントリ名を検証し、失敗する場合は方法を再設計する。API の成功を未確認のまま断定しない。

## R3: 競合とエラー

**Decision**: rename の別項目競合は全 resolution で sameNameExists にする。親の列挙失敗は systemFailure。リンク先の有無に依存せず名前の列挙で競合を検出する。

**Rationale**: UI は常に abort を渡すが、Service も公開 API であり、replace が元項目をゴミ箱へ送ることを防ぐ。コピー/移動は既存の三択を維持する。

**Alternatives considered**: UI だけの対応では、確認中の別項目追加や Service の直接呼び出しをカバーしない。

## R4: テスト環境

**Decision**: FixtureKit の一時ディレクトリで host volume の性質を実際の別表記の存在から判定し、保存名は contentsOfDirectory で検証する。case-sensitive 専用の別表記が共存するテストはボリューム条件を明記する。両ボリュームを使ったローカル検証を quickstart に用意する。

**Rationale**: case-insensitive volume では旧パスの fileExists が true のままになるため、旧パス消失の assertion は正しくない。CI が片方しか提供しなければ両方を検証済みとは扱わない。

**Alternatives considered**: Linux 上のファイル操作を macOS の証拠に使うこと、モックだけで OS の改名成功を主張することは不採用。

## R5: 表示の反映

**Decision**: Coordinator の onFolderRenamed、didRenameFolder/Item、履歴更新、reload を使う。大文字小文字だけのパス差分が RenamedFolder と SearchRenameLedger に伝わることをテストする。

**Rationale**: FR-027・FR-104・FR-105 の表示規則を再利用する。新しい通知経路は不要。

## Tool limitations

Linear get_agent_context は呼び出したがサーバーが Tool not found を返した。共有ノートは取得できていない。判断はコード・現行仕様・Issue 本文に基づく。
