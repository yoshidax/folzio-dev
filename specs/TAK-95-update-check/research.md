# Research: アップデートの確認（TAK-95）

## R1 更新の範囲: 確認と通知だけにする

- **Decision**: 新しい公開版の有無を確かめて知らせ、Release ページを既定の Web ブラウザで開くまでとする。
  ダウンロード・展開・置き換え・再起動は行わない（spec の Clarifications、A-257）。
- **Rationale**:
  - 配布は ad hoc 署名・未公証（FR-172（overview.md））で、ビルドごとに署名の識別子が変わる。アプリが取得した更新を
    OS のコード署名で「同じ発行者のものか」確かめる手段がなく、アプリ内の置き換えは安全性を保証しにくい。
  - Sparkle 2 は Developer ID のないアプリでは EdDSA 署名で更新を検証するが、外部依存（バイナリの framework）の同梱、
    `scripts/make-app.sh` での埋め込みと署名、EdDSA の秘密鍵の管理と Actions への登録、appcast の生成・公開が要る。
    A-89（overview.md）の「外部パッケージを追加しない」方針とも合わない。保守者は確認と通知だけを選んだ。
- **Alternatives considered**: Sparkle 2 で適用まで（上記の理由で不採用）。自前で適用まで（ダウンロード・検証・置き換えの
  実装と安全性の検証の負担が最も大きく不採用）。

## R2 版の情報源: GitHub REST API の最新 Release

- **Decision**: `GET https://api.github.com/repos/yoshidax/folzio/releases/latest` を1回呼び、応答の `tag_name` を使う。
- **Rationale**:
  - このエンドポイントは、公開済みの最新の Release を返し、ドラフトとプレリリースを含まない（GitHub REST API の文書
    「Get the latest release」: "The latest release is the most recent non-prerelease, non-draft release"）。FR-423 の条件に一致する。
  - 公開リポジトリなので認証は要らない。appcast などの配信用ファイルを新しく作らずに済み、配布の手順を変えない（A-259）。
  - タグは `v<版>` の形（`scripts/dev/release-distribution.sh` の `tag="v$version"`）で、`release.json` の `version` と
    `CFBundleShortVersionString` が一致する（FR-171（overview.md））。
- **Alternatives considered**:
  - `https://github.com/yoshidax/folzio/releases/latest` のリダイレクト先からタグを読む: HTML のページの挙動に依存し、
    応答の形が保証されないため不採用。
  - 公開リポジトリに版のファイルを置いて raw で読む: 配布の手順に1工程増えるため不採用。

## R3 失敗の扱い

- **Decision**: 次をすべて「確認できなかった」とする（US97-AS2・EC-292・EC-294）。
  - 接続できない・15 秒で応答がない（`timeoutIntervalForRequest` と `timeoutIntervalForResource` を 15 秒にする）
  - HTTP の状態が 200 でない（Release がないときの 404、回数の制限の 403・429、障害の 5xx）
  - 応答が JSON として読めない、`tag_name` がない、`v<数>.<数>.<数>` の形でない
  - 応答の大きさが 1 MiB を超える（通常の応答は数 KB。異常な応答を処理しない）
- **Rationale**: 利用者にとっての対処はどれも同じ（あとで試す・Release ページを自分で開く）で、理由を分けても
  操作の選択肢が増えない。理由はテストで区別できるよう、Core の結果の値には持たせる。
- 未認証の API は IP アドレスごとに 1 時間 60 回の制限がある。利用者の操作でだけ呼ぶため、通常は届かない。

## R4 送る情報を最小にする（FR-424）

- **Decision**: `URLSessionConfiguration.ephemeral` を使い、次の要求ヘッダーを明示する。
  - `User-Agent: Folzio`（GitHub の API は User-Agent を必須とする。版や OS は含めない）
  - `Accept: application/vnd.github+json`、`X-GitHub-Api-Version: 2022-11-28`（GitHub の推奨）
  - `Accept-Language: en`（既定では OS の優先言語が送られるため、固定値で上書きする）
  - Cookie を送らず保存しない（`httpShouldSetCookies = false`、`httpCookieStorage = nil`）、ディスクのキャッシュを使わない
    （`urlCache = nil`、`requestCachePolicy = .reloadIgnoringLocalCacheData`）
- **Rationale**: 憲章 原則 I（画像・メタデータ・パスを送らない）と A-260。ephemeral のセッションは永続の Cookie・
  キャッシュ・資格情報を持たない。
- **Alternatives considered**: `URLSession.shared`（既定の Cookie とキャッシュを共有するため不採用）。

## R5 コードの置き場所とネットワーク API の検査

- **Decision**:
  - 判断のロジック（版の解析と比較、要求の組み立て、応答の評価、Release ページの URL の組み立て）は
    `Sources/FolzioCore/Update/`に置く。Core は `URLSession` を使わず、通信は注入された関数（`UpdateTransport`）で行う。
  - `URLSession` を使うのは `Sources/FolzioApp/Update/URLSessionUpdateTransport.swift` の1ファイルだけにする。
  - API の URL のリテラル `"https://api.github.com/repos/yoshidax/folzio/releases/latest"` は
    `Sources/FolzioCore/Update/UpdateSource.swift` の1か所だけに置く。Release ページの URL は
    `AboutInfo.repositoryURL` から組み立て、新しいリテラルを増やさない。
  - `scripts/check-no-network.sh` の許可を、ファイルと許す行の組の一覧に改める。上の2ファイルの決まった行だけを許し、
    ほかのファイルへの追加と、許したファイルでの別の URL・別のネットワーク API を失敗にする（SC-246）。
    `NWConnection`・`import Network` はどこでも許さない。
- **Rationale**: AGENTS.md の「判断ロジックは FolzioCore」。通信の部分を薄くし、Core のテストでは通信せずに全分岐を確かめる。
  検査は公開用スクリプトなので、許す範囲を明示し、既存のテスト（`scripts/dev/tests/test_check_no_network.py`）に足す。

## R6 ダイアログの出し方

- **Decision**: `NSAlert` を `runModal()` でアプリ全体のダイアログとして出す。出す前に `NSApp.activate()` を呼ぶ。
  - 新しい版があるとき: 1つ目のボタン「ダウンロードページを開く」（Return）、2つ目「閉じる」（Esc）。
  - 最新・確認できなかったとき: 「OK」だけ（既存の `dialog.ok`）。
- **Rationale**:
  - メインウィンドウのシートにすると、スライドショー・全画面・ほかのシートの表示中に出せない、または状態を変える。
    FR-238（window-layout.md）と同じく状態に関わらず選べる項目なので、アプリ全体のダイアログにする。
  - スライドショーの切り替えは `.modalPanel` のモードでも進む（`SlideshowCoordinator.swift` の `RunLoop.main.perform(inModes:
    [.default, .eventTracking, .modalPanel])`）ため、ダイアログの表示中もスライドショーは止まらない（EC-295）。
  - `NSAlert` のボタンは Return・Esc・Tab で操作でき、標準のアクセシビリティのラベルを持つ（FR-428）。
- **Alternatives considered**: About と同じ独立した非モーダルのウインドウ（部品が増え、結果ごとに再利用の扱いが要るため不採用）。

## R7 確認中の表示

- **Decision**: 確認中は「アップデートを確認…」を無効にするだけとし、進捗のウインドウは出さない。自動の確認の途中も同じ（EC-291）。
- **Rationale**: 応答は通常 1 秒未満で、最長でも 15 秒で結果のダイアログが出る（FR-427）。ほかの操作は待たされない。
  起動直後に利用者がメニューを開いても、項目が淡色の時間は最長 15 秒で、自動の確認で新しい版があればダイアログが出る。

## R9 起動時の自動の確認（設計レビューでの方針の変更）

- **Decision**:
  - 初回に同意を尋ねる（FR-430）。保存は `updates.automaticCheck`（Bool）。キーがない・Bool でないときは「未回答」とし、
    尋ねる。答える前は通信しない。
  - 起動時、メインウィンドウを表示した後（`applicationDidFinishLaunching` の `showWindow` の後）に、未回答なら尋ね、有効なら
    24 時間の判定をして確認する。起動中のタイマーは持たない（A-257）。
  - 前回の自動の確認の時刻（`updates.lastAutomaticCheck`、Date）は、結果が新しい版か最新のときだけ保存する。確認できなかった
    ときは保存せず、次の起動で確かめ直す（EC-298）。時刻が未来なら期限切れとみなす（EC-297）。
  - 知らせた版（`updates.lastNotifiedVersion`、String）より新しい版だけを自動で知らせる。メニューの確認で新しい版を知らせた
    ときも保存する（FR-432）。
  - 自動の結果を知らせる時点、または同意を尋ねる時点で、メインウィンドウがショートカット一覧を開けない状態
    （`MainSplitViewController.canShowShortcuts` が false。文字の編集中・シート・モーダル・全画面・スライドショー）なら、
    その回は知らせず・尋ねず、時刻と知らせた版を保存しない（EC-296）。
- **Rationale**:
  - 保守者の判断: メニューだけでは新しい版に気付きにくい。同意を初回に尋ねることで、憲章 原則 I の「明示的な操作」を
    「自動の確認を有効にする利用者の答え」で満たし、改定を最小にする（Sparkle も2回目の起動で同じ問いを出す）。
  - 24 時間に1回なので、未認証の API の制限（1 時間に 60 回）に届かず、通信の回数も増えない（SC-248）。
  - 状態を後で見張って知らせ直す仕組み（作業が終わるのを待つ）は、通知とタイマーが要り、原則 V に反する。起動時の結果は
    通常 1 秒以内に出るので、作業の途中に当たることはまれで、当たっても次の起動で知らせられる。
- **Alternatives considered**:
  - 既定でオン（保守者が初回に尋ねる方式を選んだ）。
  - 「このバージョンをスキップ」「あとで知らせる」のボタン（各版1回の通知で足りるため不採用。A-261）。
  - 確認できなかったときにも時刻を保存する（オフラインの間は無駄な問い合わせが減るが、再接続後の気付きが最長 24 時間遅れる。
    オフラインでは通信が成立しないので不採用）。

## R8 憲章の改定

- **Decision**: 憲章 原則 I の「ユーザーの明示的な操作でのみ通信を開始」を、「ユーザーの明示的な操作、またはユーザーが明示的に
  有効にした自動の処理でのみ通信を開始」に改める。あわせて、いま許す通信は公開用リポジトリの最新の公開版の確認だけであること、
  送らない情報、自動の確認の上限（起動時・24 時間に1回）、更新の適用をしないことを書き足す。
  「開発ワークフローと品質ゲート」のマージ前のゲート「外部通信が追加されていないこと」を、原則 I で許した範囲を超える
  外部通信がないことに改める。版は 1.5.0 → 1.6.0（MINOR: ガイダンスの実質的な拡張）。Sync Impact Report を更新する。
- **Rationale**: 原則 I は「ネットワークを必要とする機能を追加する場合は、spec で明示し、ユーザーの明示的な操作でのみ通信を
  開始し、本憲章の改定を経なければならない」と定める。保守者はこの feature の中での改定を選んだ。
