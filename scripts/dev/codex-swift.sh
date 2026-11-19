#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^(build|test|test-system|app)$ ]]; then
    echo "使い方: scripts/dev/codex-swift.sh {build|test|test-system|app}" >&2
    exit 2
fi

cd "$(dirname "$0")/../.."
swift_path=$(type -P swift)

# test と test-system で同じ識別子を使い、システム依存のテストを分割する。
system_tests=(
    # 時間・メモリの計測は、通常の macOS セッションで行う。
    'FolzioPerformanceTests[.]'
    # AVFoundation の動画エンコード・再生、動画を含むフィクスチャ。
    'FolzioCoreTests[.](ArchiveAssetLoaderTests|FileNameSearcherTests|FolderSearchFixtureTests|VideoPlaybackTests)/'
    'FolzioCoreTests[.]ThumbnailProviderTests/(generatesThumbnailsForMixedFixtures|generatesThumbnailForVideoInsideZip)'
    # Launch Services に依存する種別の取得と、実ファイルの列挙・監視。
    'FolzioCoreTests[.](BrowserModelContentRefreshTests|BrowserModelFolderTests|BrowserModelHistoryTests|BrowserModelNameFilterTests|DirectoryListerTests|FileSystemWatcherTests|ImportInspectorTests|ImportPayloadPolicyTests|PackageNameTests)/'
    'FolzioCoreTests[.]BrowserModelSearchTests/(selectingFolderLeavesSearch|openingFolderRowSendsOpenedSearchResultFolder)'
    'FolzioCoreTests[.](ImportedFileNameTests/correctedExtensions|NameValidationTests/folderRejectsPackageName)'
    'FolzioAppTests[.](FolderContextMenuTests|ImportSessionTests)/'
    # ゴミ箱・置き換え時のファイル操作と、AppKit のペーストボード・ダイアログ。
    'FolzioCoreTests[.](FileOperationServiceTests|ImageDataWriterTests)/'
    'FolzioAppTests[.](ExternalImageDragTests|ImportPromptParentTests|PasteboardFileURLsTests|PasteboardImportTests)/'
)
system_filter=$(IFS='|'; echo "${system_tests[*]}")

if [[ "$1" == test-system ]]; then
    # サンドボックス外で個別に承認して実行する。SwiftPM 本来の保護を使う。
    exec "$swift_path" test --no-parallel --filter "$system_filter"
fi

# Codex のサンドボックス内で書き込める、作業ツリーごとのキャッシュを使う。
cache_dir="$PWD/.build/codex-swift/module-cache"
mkdir -p "$cache_dir"
export CLANG_MODULE_CACHE_PATH="$cache_dir"
export SWIFTPM_MODULECACHE_OVERRIDE="$cache_dir"

# 外側の Codex の保護を維持し、入れ子で起動できない SwiftPM の保護だけを無効にする。
case "$1" in
    build)
        exec "$swift_path" build --disable-sandbox
        ;;
    test)
        exec "$swift_path" test --disable-sandbox --no-parallel --skip "$system_filter"
        ;;
    app)
        # 公開用スクリプトはそのまま使い、その実行中の Swift build にだけフラグを渡す。
        shim_dir="$PWD/.build/codex-swift/app"
        if ! mkdir "$shim_dir"; then
            echo "アプリ作成用の作業ディレクトリを確保できません: $shim_dir" >&2
            exit 1
        fi
        app_path="$PWD/.build/Folzio.app"
        backup="$shim_dir/Folzio.app"
        cleanup_app() {
            local status=$?
            # パッケージングに失敗したら、それまで使っていたアプリを戻す。
            if (( status != 0 )) && [[ -e "$backup" || -L "$backup" ]]; then
                rm -rf "$app_path"
                mv "$backup" "$app_path"
            fi
            rm -rf "$shim_dir"
        }
        trap cleanup_app EXIT
        cat > "$shim_dir/swift" <<'SHIM'
#!/bin/bash
set -euo pipefail
if [[ "${1:-}" != build ]]; then
    echo "アプリ作成では swift build のみを扱います。" >&2
    exit 2
fi
shift
exec "$FOLZIO_CODEX_SWIFT" build --disable-sandbox "$@"
SHIM
        chmod +x "$shim_dir/swift"
        if [[ -e "$app_path" || -L "$app_path" ]]; then
            mv "$app_path" "$backup"
        fi
        PATH="$shim_dir:$PATH" FOLZIO_CODEX_SWIFT="$swift_path" scripts/make-app.sh
        ;;
esac
