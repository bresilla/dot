#!/usr/bin/env bash

set -euo pipefail

readonly config_root="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
readonly target="quickshell.target"
readonly components=(border board osd main)

config_path() {
    case "$1" in
        border|board|osd)
            printf '%s/%s\n' "$config_root" "$1"
            ;;
        main)
            printf '%s\n' "$config_root"
            ;;
        *)
            printf 'Unknown QuickShell component: %s\n' "$1" >&2
            return 2
            ;;
    esac
}

import_session_environment() {
    local -a names=()
    local name

    for name in DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE; do
        if [[ -v "$name" ]]; then
            names+=("$name")
        fi
    done

    if ((${#names[@]})); then
        systemctl --user import-environment "${names[@]}"
    fi
}

run_component() {
    local path
    path="$(config_path "$1")"
    exec /usr/bin/qs --path "$path"
}

restart_component() {
    local component="$1"
    local path unit
    path="$(config_path "$component")"
    unit="quickshell@${component}.service"

    systemctl --user stop "$unit"
    /usr/bin/qs kill --path "$path" --any-display >/dev/null 2>&1 || true
    systemctl --user start "$unit"
}

restart_all() {
    local component path
    local -a units=()

    for component in "${components[@]}"; do
        units+=("quickshell@${component}.service")
    done

    systemctl --user stop "$target" "${units[@]}"

    # Remove any instances left behind by the old daemonized launcher.
    for component in "${components[@]}"; do
        path="$(config_path "$component")"
        /usr/bin/qs kill --path "$path" --any-display >/dev/null 2>&1 || true
    done

    systemctl --user start "$target"
}

action="${1:-restart}"
case "$action" in
    run)
        [[ $# -eq 2 ]] || {
            printf 'Usage: %s run {border|board|osd|main}\n' "$0" >&2
            exit 2
        }
        run_component "$2"
        ;;
    restart)
        component="${2:-}"
        ;;
    border|board|osd|main)
        component="$action"
        ;;
    *)
        printf 'Usage: %s [restart [border|board|osd|main]]\n' "$0" >&2
        exit 2
        ;;
esac

import_session_environment
systemctl --user daemon-reload

if [[ -n "${component:-}" ]]; then
    restart_component "$component"
else
    restart_all
fi
