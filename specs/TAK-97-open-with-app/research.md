# Research: 関連アプリケーションで開く

## R1 候補の取得

**Decision**: `NSWorkspace.urlsForApplications(toOpen: URL)` に選択ファイルの URL を渡す。返るアプリ URL を候補の識別子として扱い、OS の適合順を保つ。URL が重複する場合だけ除去する。

**Reason**: [Apple の API 文書](https://developer.apple.com/documentation/appkit/nsworkspace/urlsforapplications%28toopen%3A%29-ualk) は、URL を開ける利用可能なアプリの一覧を返し、適合度順に並べると説明している。拡張子だけから独自に候補を推測する必要がない。

**Alternative**: 拡張子から UTType を求めて候補を列挙する方法は、実ファイル URL の情報を失うため採用しない。

## R2 指定アプリで開く

**Decision**: `NSWorkspace.open(_:withApplicationAt:configuration:completionHandler:)` を使い、結果のエラーを UI に戻す。選択時のファイル URL とアプリ URL をメニュー項目に固定し、実行時にも対象が有効か確認する。

**Reason**: [Apple の API 文書](https://developer.apple.com/documentation/appkit/nsworkspace/open%28_%3Awithapplicationat%3Aconfiguration%3Acompletionhandler%3A%29) は指定アプリへの非同期オープンとエラー通知を提供する。既定の関連付けを変更する操作は呼ばない。

**Alternative**: `openFile(_:withApplication:)` は非推奨で結果を十分に扱えない。

## R3 メニュー更新と応答性

**Decision**: メニューを開く契機に現在の1件の対象を判定し、そのファイルの候補を取得する。選択変更後の結果は使わず、同じ候補を右クリックと「ファイル」メニューに表示する。候補列挙がメニュー表示を遅らせる場合は、対象 URL をキーに結果をキャッシュし、アプリのインストール状況が変わったら破棄する方法を検討する。

**Reason**: 候補は選択ごとに異なる。アプリ検索で重いファイル列挙を追加しない。メニュー更新時の OS 呼び出しが同期かどうか、実機で遅延を確認する。

## R4 対象と表示

**Decision**: FolzioCore の `ListItemCommands` に1件の通常ファイルを判定する条件を追加する。メディアと zip ファイルは対象、フォルダ・`..`・zip 内・複数選択は対象外とする。候補ゼロなら親項目を淡色にする。メニューのアプリ名が同じ場合は表示名に識別に必要な情報を付ける。

**Reason**: 既存の `allowsFileOperations` だけではフォルダを除外できず、選択数も考慮しない。
