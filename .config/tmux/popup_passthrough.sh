#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
shift || true

current_session="$(tmux display -p '#{session_name}')"

if [[ "$current_session" != *"popup"* ]]; then
    case "$mode" in
        newwindow) tmux new-window -c "#{pane_current_path}" ;;
        newwindow-home) tmux new-window ;;
        next) tmux next-window ;;
        previous) tmux previous-window ;;
        key) tmux send-keys "$@" ;;
    esac
    exit 0
fi

parent_session="$(tmux show -t "$current_session" -v @popup_parent_session 2>/dev/null || true)"
parent_window="$(tmux show -t "$current_session" -v @popup_parent_window 2>/dev/null || true)"
parent_pane="$(tmux show -t "$current_session" -v @popup_parent_pane 2>/dev/null || true)"

if [[ -z "$parent_session" || -z "$parent_window" ]]; then
    tmux detach-client
    exit 0
fi

if [[ -z "$parent_pane" ]]; then
    parent_pane="$(tmux display -p -t "${parent_session}:${parent_window}" '#{pane_id}' 2>/dev/null || true)"
fi

printf '%s\n' "$current_session" > "/tmp/tmux_popup_${parent_window}"

case "$mode" in
    newwindow)
        cwd="$(
            if [[ -n "$parent_pane" ]]; then
                tmux display -p -t "$parent_pane" '#{pane_current_path}' 2>/dev/null || true
            fi
        )"
        if [[ -n "$cwd" ]]; then
            tmux new-window -t "${parent_session}:" -c "$cwd"
        else
            tmux new-window -t "${parent_session}:"
        fi
        tmux detach-client
        ;;
    newwindow-home)
        tmux new-window -t "${parent_session}:"
        tmux detach-client
        ;;
    next)
        tmux next-window -t "$parent_session"
        tmux detach-client
        ;;
    previous)
        tmux previous-window -t "$parent_session"
        tmux detach-client
        ;;
    key)
        [[ -n "$parent_pane" ]] && tmux send-keys -t "$parent_pane" "$@"
        ;;
    *)
        printf 'usage: %s {newwindow|newwindow-home|next|previous|key KEY...}\n' "$0" >&2
        exit 2
        ;;
esac
