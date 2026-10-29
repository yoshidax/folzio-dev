#!/bin/bash
# One-time local migration for the pre-release development application.
set -euo pipefail

domain_exists() {
    local domain="$1" domains
    if ! domains="$(defaults domains)"; then
        echo "設定ドメインの一覧を取得できません。移行を中止します。" >&2
        return 2
    fi
    printf '%s\n' "$domains" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -Fx "$domain" >/dev/null
}

migrate_settings() {
    local source="$1" destination="$2" backup_root="$3" status backup_dir backup_file exported
    if domain_exists "$source"; then
        :
    else
        status=$?
        if [[ $status -eq 1 ]]; then
            echo "移行元の設定がありません: $source"
            return 0
        fi
        return "$status"
    fi
    if domain_exists "$destination"; then
        echo "移行先の設定がすでにあります。上書きせず中止します: $destination" >&2
        return 1
    else
        status=$?
        [[ $status -eq 1 ]] || return "$status"
    fi

    umask 077
    mkdir -p "$backup_root"
    backup_dir="$(mktemp -d "$backup_root/folzio-settings.XXXXXXXX")"
    backup_file="$backup_dir/source.plist"
    exported="$backup_dir/destination.plist"
    if ! defaults export "$source" "$backup_file"; then
        echo "バックアップに失敗したため、移行先を変更していません: $backup_dir" >&2
        return 1
    fi

    # Recheck immediately before writing in case the new app was started during backup.
    if domain_exists "$destination"; then
        echo "移行先が作成されたため中止しました。バックアップ: $backup_file" >&2
        return 1
    else
        status=$?
        [[ $status -eq 1 ]] || return "$status"
    fi
    if ! defaults import "$destination" "$backup_file"; then
        echo "復元に失敗しました。移行先に一部の値が残る可能性があります。バックアップ: $backup_file" >&2
        return 1
    fi
    if ! defaults export "$destination" "$exported" || ! python3 - "$backup_file" "$exported" <<'PY'
import plistlib
import sys
with open(sys.argv[1], 'rb') as source, open(sys.argv[2], 'rb') as destination:
    if plistlib.load(source) != plistlib.load(destination):
        raise SystemExit(1)
PY
    then
        echo "復元内容を確認できません。移行先を確認してください。バックアップ: $backup_file" >&2
        return 1
    fi
    echo "設定を移行しました: $source → $destination"
    echo "旧設定のバックアップ: $backup_file"
}

main() {
    if [[ $# -ne 1 ]]; then
        echo "使用方法: $0 app|swift-run" >&2
        return 2
    fi
    case "$1" in
        app) migrate_settings 'local.my-img-viewer.MediaViewer' 'local.folzio.Folzio' "$HOME/Library/Application Support/Folzio/SettingsBackups" ;;
        swift-run) migrate_settings 'MediaViewerApp' 'FolzioApp' "$HOME/Library/Application Support/Folzio/SettingsBackups" ;;
        *) echo "指定できる起動方法は app または swift-run です。" >&2; return 2 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
