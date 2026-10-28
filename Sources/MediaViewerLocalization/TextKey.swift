import Foundation
import MediaViewerCore

/// 翻訳単位の引数の種類（data-model.md）。位置指定の書式で入れる
public enum TextArgument: Sendable, Equatable {
    /// ファイル名・パス・キーワード・OS の理由など。文字どおりに入れる（EC-109）
    case text
    /// 件数。複数形の判定に使う整数と、地域の書式で整形した件数の2つを渡す（R6）
    case count
    /// 語形が変わらないラベルの値としての件数（整形済みの文字列だけを渡す）
    case number
}

/// 画面に表示する1つの文言（翻訳単位）。管理元は `Resources/{en,ja}.lproj/Localizable.strings(dict)`
public enum TextKey: String, CaseIterable, Sendable {
    // MARK: - Core の値

    case errorSearchRootEmpty = "error.searchRoot.empty"
    case errorSearchRootNotAbsolute = "error.searchRoot.notAbsolute"
    case errorSearchRootNotFound = "error.searchRoot.notFound"
    case errorSearchRootNotAFolder = "error.searchRoot.notAFolder"
    case errorSearchRootAccessDenied = "error.searchRoot.accessDenied"
    case errorSearchRootNoUsableFolder = "error.searchRoot.noUsableFolder"

    case errorZipCannotOpen = "error.zip.cannotOpen"
    case errorZipNotFound = "error.zip.notFound"
    case errorZipAccessDenied = "error.zip.accessDenied"
    case errorZipNotAZip = "error.zip.notAZip"
    case errorZipMultiDisk = "error.zip.multiDisk"
    case errorZipEntryEncrypted = "error.zip.entryEncrypted"
    case errorZipUnsupportedMethod = "error.zip.unsupportedMethod"
    case errorZipTooLarge = "error.zip.tooLarge"

    case errorZipCorruptedCannotStartInflate = "error.zip.corrupted.cannotStartInflate"
    case errorZipCorruptedCompressedDataDamaged = "error.zip.corrupted.compressedDataDamaged"
    case errorZipCorruptedDataTruncated = "error.zip.corrupted.dataTruncated"
    case errorZipCorruptedCompressedDataTruncated = "error.zip.corrupted.compressedDataTruncated"
    case errorZipCorruptedHeaderDamaged = "error.zip.corrupted.headerDamaged"
    case errorZipCorruptedInvalidOffset = "error.zip.corrupted.invalidOffset"
    case errorZipCorruptedCentralDirectoryTooLarge = "error.zip.corrupted.centralDirectoryTooLarge"
    case errorZipCorruptedInvalidLocation = "error.zip.corrupted.invalidLocation"
    case errorZipCorruptedEntryNotFound = "error.zip.corrupted.entryNotFound"
    case errorZipCorruptedSizeMismatch = "error.zip.corrupted.sizeMismatch"
    case errorZipCorruptedDataOutsideFile = "error.zip.corrupted.dataOutsideFile"
    case errorZipCorruptedReadCancelled = "error.zip.corrupted.readCancelled"
    case errorZipCorruptedReadFailed = "error.zip.corrupted.readFailed"
    case errorZipCorruptedUnreadable = "error.zip.corrupted.unreadable"

    case errorNameEmpty = "error.name.empty"
    case errorNameForbiddenCharacter = "error.name.forbiddenCharacter"
    case errorNameLeadingDot = "error.name.leadingDot"
    case errorNameDuplicate = "error.name.duplicate"
    case errorNameBecomesPackage = "error.name.becomesPackage"

    case errorOperationNoDestination = "error.operation.noDestination"
    case errorOperationDestinationNotFound = "error.operation.destinationNotFound"
    case errorOperationSourceNotFound = "error.operation.sourceNotFound"
    case errorOperationIntoItself = "error.operation.intoItself"
    case errorOperationSameNameExists = "error.operation.sameNameExists"
    case errorOperationSameNameAtDestination = "error.operation.sameNameAtDestination"
    case errorOperationTrashExistingFailed = "error.operation.trashExistingFailed"
    case errorOperationSystemFailure = "error.operation.systemFailure"

    case emptyFilterImages = "empty.filter.images"
    case emptyFilterVideos = "empty.filter.videos"
    case emptyFolderNotFound = "empty.folderNotFound"
    case emptyLoading = "empty.loading"
    case emptySearching = "empty.searching"
    case emptyNoMedia = "empty.noMedia"
    case emptyNoMatches = "empty.noMatches"
    case emptyAccessDenied = "empty.accessDenied"

    case previewScrollHorizontal = "preview.scroll.horizontal"
    case previewScrollVertical = "preview.scroll.vertical"
    case previewNoMedia = "preview.noMedia"
    case previewUnavailable = "preview.unavailable"
    case previewAnimationUnavailable = "preview.animationUnavailable"
    case previewFailureUnreadable = "preview.failure.unreadable"
    case previewFailureUnsupportedFormat = "preview.failure.unsupportedFormat"
    case previewFailureCorrupted = "preview.failure.corrupted"

    case kindFolder = "kind.folder"
    case kindZipArchive = "kind.zipArchive"

    // MARK: - メニューバー

    case menuAppSettings = "menu.app.settings"
    case menuAppQuit = "menu.app.quit"
    case menuFile = "menu.file"
    case menuFileOpen = "menu.file.open"
    case menuFileShowContents = "menu.file.showContents"
    case menuFileEnclosingFolder = "menu.file.enclosingFolder"
    case menuFileRevealInFinder = "menu.file.revealInFinder"
    case menuFileAddToFavorites = "menu.file.addToFavorites"
    case menuFileFind = "menu.file.find"
    case menuFileTrash = "menu.file.trash"
    case menuFileRemoveFromFavorites = "menu.file.removeFromFavorites"
    case menuEdit = "menu.edit"
    case menuEditUndo = "menu.edit.undo"
    case menuEditRedo = "menu.edit.redo"
    case menuEditCut = "menu.edit.cut"
    case menuEditCopy = "menu.edit.copy"
    case menuEditPaste = "menu.edit.paste"
    case menuEditMovePaste = "menu.edit.movePaste"
    case menuEditDuplicate = "menu.edit.duplicate"
    case menuEditRename = "menu.edit.rename"
    case menuEditSelectAll = "menu.edit.selectAll"
    case menuView = "menu.view"
    case menuViewShowToolbar = "menu.view.showToolbar"
    case menuViewHideToolbar = "menu.view.hideToolbar"
    case menuViewFullScreen = "menu.view.fullScreen"
    case menuViewZoomIn = "menu.view.zoomIn"
    case menuViewZoomOut = "menu.view.zoomOut"
    case menuViewZoomToFit = "menu.view.zoomToFit"
    case menuViewStartSlideshow = "menu.view.startSlideshow"
    case menuViewShowFileListOnly = "menu.view.showFileListOnly"
    case menuViewShowPreviewOnly = "menu.view.showPreviewOnly"
    case menuViewFocusTree = "menu.view.focusTree"
    case menuViewFocusFileList = "menu.view.focusFileList"
    case menuViewFocusPreview = "menu.view.focusPreview"
    case menuViewGoToFavorites = "menu.view.goToFavorites"
    case menuViewAsThumbnails = "menu.view.asThumbnails"
    case menuViewAsList = "menu.view.asList"
    case menuViewLargerThumbnails = "menu.view.largerThumbnails"
    case menuViewSmallerThumbnails = "menu.view.smallerThumbnails"
    case menuViewShowImagesOnly = "menu.view.showImagesOnly"
    case menuViewShowVideosOnly = "menu.view.showVideosOnly"
    case menuViewShowZipFiles = "menu.view.showZipFiles"
    case menuViewSortBy = "menu.view.sortBy"
    case menuGo = "menu.go"
    case menuGoBack = "menu.go.back"
    case menuGoForward = "menu.go.forward"

    // MARK: - 右クリックメニュー

    case contextCopySingle = "context.copy.single"
    case contextCopyMultiple = "context.copy.multiple"
    case contextPasteHere = "context.pasteHere"
    case contextMovePasteHere = "context.movePasteHere"

    // MARK: - ツールバー

    case toolbarHistory = "toolbar.history"
    case toolbarPanes = "toolbar.panes"
    case toolbarZoomGroup = "toolbar.zoomGroup"
    case toolbarMediaType = "toolbar.mediaType"
    case toolbarViewMode = "toolbar.viewMode"
    case toolbarSize = "toolbar.size"
    case toolbarThumbnailSize = "toolbar.thumbnailSize"
    case toolbarStartSlideshowHelp = "toolbar.startSlideshowHelp"
    case toolbarZoomInHelp = "toolbar.zoomInHelp"
    case toolbarZoomToFitHelp = "toolbar.zoomToFitHelp"
    case toolbarZoomOutHelp = "toolbar.zoomOutHelp"
    case toolbarThumbnails = "toolbar.thumbnails"
    case toolbarList = "toolbar.list"

    // MARK: - 設定ウインドウ

    case settingsWindow = "settings.window"
    case settingsLanguage = "settings.language"
    case settingsLanguageEnglish = "settings.language.english"
    case settingsLanguageJapanese = "settings.language.japanese"
    case settingsVideo = "settings.video"
    case settingsAutoplay = "settings.autoplay"
    case settingsLoop = "settings.loop"
    case settingsFileOperations = "settings.fileOperations"
    case settingsConfirm = "settings.confirm"
    case settingsSlideshow = "settings.slideshow"
    case settingsInterval = "settings.interval"
    case settingsSeconds = "settings.seconds"
    case settingsIntervalA11y = "settings.intervalA11y"
    case settingsRepeat = "settings.repeat"
    case settingsTransition = "settings.transition"
    case settingsTransitionNone = "settings.transition.none"
    case settingsTransitionCrossfade = "settings.transition.crossfade"
    case settingsTransitionSlide = "settings.transition.slide"
    case settingsTransitionZoom = "settings.transition.zoom"

    // MARK: - ファイルリスト・ツリー

    case listColumnName = "list.column.name"
    case listColumnCreationDate = "list.column.creationDate"
    case listColumnKind = "list.column.kind"
    case listColumnLocation = "list.column.location"
    case listSortAscending = "list.sort.ascending"
    case listSortDescending = "list.sort.descending"
    case listParentRow = "list.parentRow"

    case treeColumn = "tree.column"
    case treeFavorites = "tree.favorites"
    case treeTooltipNotAccessible = "tree.tooltip.notAccessible"
    case treeTooltipNotFound = "tree.tooltip.notFound"
    case treeA11yFavoriteName = "tree.a11y.favoriteName"
    case treeA11yFolderName = "tree.a11y.folderName"

    // MARK: - 検索

    case searchKeyword = "search.keyword"
    case searchRoot = "search.root"
    case searchChoose = "search.choose"
    case searchChooseHelp = "search.choose.help"
    case searchSearch = "search.search"
    case searchError = "search.error"
    case searchPanelTitle = "search.panel.title"
    case searchPanelMessage = "search.panel.message"
    case searchPanelPrompt = "search.panel.prompt"
    case searchPanelFailed = "search.panel.failed"
    case searchBarResults = "search.bar.results"
    case searchBarSearching = "search.bar.searching"
    case searchBarCount = "search.bar.count"
    case searchBarCountLimited = "search.bar.countLimited"

    // MARK: - 確認モーダル・ダイアログ

    case dialogConfirmCopy = "dialog.confirm.copy"
    case dialogConfirmMove = "dialog.confirm.move"
    case dialogConfirmRename = "dialog.confirm.rename"
    case dialogConfirmTrash = "dialog.confirm.trash"
    case dialogConfirmItems = "dialog.confirm.items"
    case dialogConfirmBullet = "dialog.confirm.bullet"
    case dialogConfirmMore = "dialog.confirm.more"
    case dialogConfirmFolderTrash = "dialog.confirm.folderTrash"
    case dialogConfirmFolderProcess = "dialog.confirm.folderProcess"
    case dialogConfirmDestination = "dialog.confirm.destination"
    case dialogConfirmLocation = "dialog.confirm.location"
    case dialogConfirmContinue = "dialog.confirm.continue"
    case dialogConfirmDontAsk = "dialog.confirm.dontAsk"
    case dialogFavoriteRemoveTitle = "dialog.favoriteRemove.title"
    case dialogFavoriteRemoveItems = "dialog.favoriteRemove.items"
    case dialogFavoriteRemoveNote = "dialog.favoriteRemove.note"
    case dialogFavoriteRemoveConfirm = "dialog.favoriteRemove.confirm"
    case dialogConflictTitle = "dialog.conflict.title"
    case dialogConflictItems = "dialog.conflict.items"
    case dialogConflictReplace = "dialog.conflict.replace"
    case dialogConflictKeepBoth = "dialog.conflict.keepBoth"
    case dialogConflictStop = "dialog.conflict.stop"
    case dialogConflictApplyAll = "dialog.conflict.applyAll"
    case dialogExtensionTitle = "dialog.extension.title"
    case dialogExtensionMessage = "dialog.extension.message"
    case dialogExtensionConfirm = "dialog.extension.confirm"
    case dialogRenameFailed = "dialog.rename.failed"
    case dialogOperationFailed = "dialog.operation.failed"
    case dialogOperationSummary = "dialog.operation.summary"
    case dialogOperationFailureLine = "dialog.operation.failureLine"
    case dialogOperationMore = "dialog.operation.more"
    case dialogCancel = "dialog.cancel"
    case dialogOK = "dialog.ok"

    // MARK: - アクセシビリティ

    case a11yThumbnail = "a11y.thumbnail"

    /// 引数の並び（位置指定の書式の位置と種類を決める）
    public var arguments: [TextArgument] {
        switch self {
        case .errorZipCannotOpen, .errorOperationTrashExistingFailed, .errorOperationSystemFailure,
             .listSortAscending, .listSortDescending,
             .dialogConfirmBullet, .dialogConfirmDestination, .dialogConfirmLocation,
             .dialogFavoriteRemoveItems, .previewUnavailable:
            return [.text]
        case .contextCopySingle:
            return [.text]
        case .dialogExtensionMessage, .dialogOperationFailureLine:
            return [.text, .text]
        case .searchBarResults, .searchBarSearching:
            return [.text, .text, .text]
        case .contextCopyMultiple, .dialogConfirmCopy, .dialogConfirmMove, .searchBarCount:
            return [.count]
        case .searchBarCountLimited:
            return [.count, .text]
        case .dialogConfirmItems, .dialogConfirmMore, .dialogConflictItems, .dialogOperationMore:
            return [.number]
        case .dialogOperationSummary:
            return [.number, .number]
        default:
            return []
        }
    }

    /// 翻訳者向けの説明（使われる場所と各値の意味）
    public var comment: String {
        switch self {
        case .errorSearchRootEmpty, .errorSearchRootNotAbsolute, .errorSearchRootNotFound,
             .errorSearchRootNotAFolder, .errorSearchRootAccessDenied, .errorSearchRootNoUsableFolder:
            return "検索シートの起点の検証で入力欄の下に出す理由"
        case .errorZipCannotOpen:
            return "zip を開けない理由の前置き。値は理由の文"
        case .errorZipNotFound, .errorZipAccessDenied, .errorZipNotAZip, .errorZipMultiDisk:
            return "zip を開けない理由（errorZipCannotOpen の値）"
        case .errorZipEntryEncrypted, .errorZipUnsupportedMethod, .errorZipTooLarge:
            return "zip の中の項目を表示できない理由"
        case .errorZipCorruptedCannotStartInflate, .errorZipCorruptedCompressedDataDamaged,
             .errorZipCorruptedDataTruncated, .errorZipCorruptedCompressedDataTruncated,
             .errorZipCorruptedHeaderDamaged, .errorZipCorruptedInvalidOffset,
             .errorZipCorruptedCentralDirectoryTooLarge, .errorZipCorruptedInvalidLocation,
             .errorZipCorruptedEntryNotFound, .errorZipCorruptedSizeMismatch,
             .errorZipCorruptedDataOutsideFile, .errorZipCorruptedReadCancelled,
             .errorZipCorruptedReadFailed, .errorZipCorruptedUnreadable:
            return "zip の内容が壊れている理由（errorZipCannotOpen の値）"
        case .errorNameEmpty, .errorNameForbiddenCharacter, .errorNameLeadingDot,
             .errorNameDuplicate, .errorNameBecomesPackage:
            return "名前の変更で使えない名前の理由"
        case .errorOperationNoDestination, .errorOperationDestinationNotFound,
             .errorOperationSourceNotFound, .errorOperationIntoItself,
             .errorOperationSameNameExists, .errorOperationSameNameAtDestination:
            return "ファイル操作の失敗の理由"
        case .errorOperationTrashExistingFailed:
            return "既存の項目をゴミ箱へ移動できなかったときの理由。値は OS が返す理由"
        case .errorOperationSystemFailure:
            return "OS がファイル操作を拒否したときの理由。値は OS が返す理由（訳し直さない）"
        case .emptyFilterImages, .emptyFilterVideos:
            return "種類フィルタで一覧が0件のときの空状態"
        case .emptyFolderNotFound:
            return "開こうとしたフォルダが見つからないときの空状態"
        case .emptyLoading:
            return "ファイルリストとプレビューの読み込み中の表示"
        case .emptySearching:
            return "検索中の空状態"
        case .emptyNoMedia:
            return "対応するメディアファイルがないフォルダの空状態"
        case .emptyNoMatches:
            return "検索結果が0件のときの空状態"
        case .emptyAccessDenied:
            return "フォルダを読めないときの空状態"
        case .previewScrollHorizontal, .previewScrollVertical:
            return "プレビュー画像のスクロールバーのアクセシビリティラベル"
        case .previewNoMedia:
            return "表示するメディアファイルがないときのプレビュー"
        case .previewUnavailable:
            return "プレビューを表示できないときの見出し。値は理由"
        case .previewAnimationUnavailable:
            return "アニメーション画像を表示できないときの理由"
        case .previewFailureUnreadable, .previewFailureUnsupportedFormat, .previewFailureCorrupted:
            return "プレビューを表示できない理由"
        case .kindFolder, .kindZipArchive:
            return "種類名のフォールバック（OS が種類名を返さないとき）"
        case .menuAppSettings:
            return "アプリケーションメニューの設定項目（ダイアログを開くので末尾に …）"
        case .menuAppQuit:
            return "アプリケーションメニューの終了項目。アプリ名は訳さない"
        case .menuFile, .menuEdit, .menuView, .menuGo:
            return "メニューバーのメニュー名"
        case .menuFileOpen, .menuFileShowContents, .menuFileEnclosingFolder,
             .menuFileRevealInFinder, .menuFileAddToFavorites, .menuFileFind,
             .menuFileTrash, .menuFileRemoveFromFavorites:
            return "ファイルメニューの項目（状態でゴミ箱とお気に入りから削除が入れ替わる）"
        case .menuEditUndo, .menuEditRedo, .menuEditCut, .menuEditCopy, .menuEditPaste,
             .menuEditMovePaste, .menuEditDuplicate, .menuEditRename, .menuEditSelectAll:
            return "編集メニューの項目"
        case .menuViewShowToolbar, .menuViewHideToolbar:
            return "表示メニューのツールバーの表示切り替え（状態で入れ替わる）"
        case .menuViewFullScreen, .menuViewZoomIn, .menuViewZoomOut, .menuViewZoomToFit,
             .menuViewStartSlideshow, .menuViewShowFileListOnly, .menuViewShowPreviewOnly,
             .menuViewFocusTree, .menuViewFocusFileList, .menuViewFocusPreview,
             .menuViewGoToFavorites, .menuViewAsThumbnails, .menuViewAsList,
             .menuViewLargerThumbnails, .menuViewSmallerThumbnails,
             .menuViewShowImagesOnly, .menuViewShowVideosOnly, .menuViewShowZipFiles,
             .menuViewSortBy:
            return "表示メニューの項目"
        case .menuGoBack, .menuGoForward:
            return "移動メニューの履歴の項目"
        case .contextCopySingle:
            return "右クリックメニューのコピー（1件）。値はファイル名"
        case .contextCopyMultiple:
            return "右クリックメニューのコピー（複数件）。件数で語形が変わる"
        case .contextPasteHere, .contextMovePasteHere:
            return "ツリーの右クリックメニューのペースト"
        case .toolbarHistory, .toolbarPanes, .toolbarZoomGroup, .toolbarMediaType,
             .toolbarViewMode, .toolbarSize:
            return "ツールバーのグループの名前"
        case .toolbarThumbnailSize:
            return "ツールバーとサイズバーのサムネイルのサイズ。ショートカットを含む"
        case .toolbarStartSlideshowHelp:
            return "スライドショーのツールチップ。ショートカットを含む"
        case .toolbarZoomInHelp, .toolbarZoomToFitHelp, .toolbarZoomOutHelp:
            return "拡大・縮小のツールチップ。ショートカットを含む"
        case .toolbarThumbnails, .toolbarList:
            return "ツールバーの表示形式の選択肢"
        case .settingsWindow:
            return "設定ウインドウの名前"
        case .settingsLanguage:
            return "設定ウインドウの表示言語のラベル"
        case .settingsLanguageEnglish, .settingsLanguageJapanese:
            return "表示言語の選択肢。言語名はそれぞれの言語で表示する"
        case .settingsVideo, .settingsFileOperations, .settingsSlideshow:
            return "設定ウインドウの区分の見出し"
        case .settingsAutoplay, .settingsLoop, .settingsConfirm, .settingsRepeat:
            return "設定ウインドウのチェックボックス"
        case .settingsInterval:
            return "設定ウインドウの切り替え間隔のラベル"
        case .settingsSeconds:
            return "切り替え間隔の単位（数値の後ろ）"
        case .settingsIntervalA11y:
            return "切り替え間隔の入力欄のアクセシビリティのラベル"
        case .settingsTransition:
            return "設定ウインドウの切り替え効果のラベルとアクセシビリティのラベル"
        case .settingsTransitionNone, .settingsTransitionCrossfade,
             .settingsTransitionSlide, .settingsTransitionZoom:
            return "切り替え効果の選択肢"
        case .listColumnName, .listColumnCreationDate, .listColumnKind, .listColumnLocation:
            return "リスト形式の列見出し。並べ替えのメニューでも使う"
        case .listSortAscending:
            return "並べ替えメニューの選択中の列（昇順）。値は列名"
        case .listSortDescending:
            return "並べ替えメニューの選択中の列（降順）。値は列名"
        case .listParentRow:
            return "一覧の .. の行のアクセシビリティのラベル"
        case .treeColumn:
            return "ツリーの列見出し"
        case .treeFavorites:
            return "ツリーの固定の行（お気に入り）"
        case .treeTooltipNotAccessible, .treeTooltipNotFound:
            return "ツリーの行のツールチップ"
        case .treeA11yFavoriteName, .treeA11yFolderName:
            return "ツリーの名前の編集欄のアクセシビリティのラベル"
        case .searchKeyword, .searchRoot, .searchChoose, .searchChooseHelp,
             .searchSearch, .searchError:
            return "検索シートのラベル・ボタン・アクセシビリティ"
        case .searchPanelTitle, .searchPanelMessage, .searchPanelPrompt:
            return "検索起点のフォルダ選択パネルの文言"
        case .searchPanelFailed:
            return "フォルダ選択パネルを開けなかったときの理由"
        case .searchBarResults:
            return "検索バーの完了時の文。値はキーワード・起点のフォルダ名・件数の句"
        case .searchBarSearching:
            return "検索バーの検索中の文。値はキーワード・起点のフォルダ名・件数の句"
        case .searchBarCount:
            return "検索バーの件数の句。件数で語形が変わる"
        case .searchBarCountLimited:
            return "検索バーの件数の句（上限で打ち切り）。件数で語形が変わり、表示件数を値で入れる"
        case .dialogConfirmCopy, .dialogConfirmMove:
            return "コピー・移動の確認の見出し。件数で語形が変わるが件数は表示しない"
        case .dialogConfirmRename, .dialogConfirmTrash:
            return "名前の変更・ゴミ箱の確認の見出し"
        case .dialogConfirmItems:
            return "確認モーダルの対象の件数。値は整形済みの件数"
        case .dialogConfirmBullet:
            return "確認モーダルの対象の1行。値はファイル名"
        case .dialogConfirmMore:
            return "確認モーダルの残りの件数。値は整形済みの件数"
        case .dialogConfirmFolderTrash, .dialogConfirmFolderProcess:
            return "フォルダを中身ごと操作する旨の注記"
        case .dialogConfirmDestination, .dialogConfirmLocation:
            return "確認モーダルのフォルダのパス。値はパス"
        case .dialogConfirmContinue, .dialogCancel, .dialogOK:
            return "ダイアログのボタン"
        case .dialogConfirmDontAsk:
            return "確認モーダルの「今後この確認を表示しない」"
        case .dialogFavoriteRemoveTitle, .dialogFavoriteRemoveItems,
             .dialogFavoriteRemoveNote, .dialogFavoriteRemoveConfirm:
            return "お気に入りの削除の確認"
        case .dialogConflictTitle:
            return "衝突ダイアログの見出し"
        case .dialogConflictItems:
            return "衝突ダイアログの衝突する件数。値は整形済みの件数"
        case .dialogConflictReplace, .dialogConflictKeepBoth, .dialogConflictStop:
            return "衝突ダイアログのボタン"
        case .dialogConflictApplyAll:
            return "衝突ダイアログの「残りすべてに適用」"
        case .dialogExtensionTitle, .dialogExtensionMessage, .dialogExtensionConfirm:
            return "拡張子の変更の確認。値はファイル名と新しい拡張子"
        case .dialogRenameFailed:
            return "名前の変更に失敗したときの見出し"
        case .dialogOperationFailed:
            return "ファイル操作に失敗したときの見出し"
        case .dialogOperationSummary:
            return "ファイル操作の成功・失敗の件数。値は整形済みの件数"
        case .dialogOperationFailureLine:
            return "ファイル操作の失敗の1行。値は名前と理由"
        case .dialogOperationMore:
            return "ファイル操作の失敗の残りの件数。値は整形済みの件数"
        case .a11yThumbnail:
            return "サムネイルの画像のアクセシビリティのラベル"
        }
    }
}
