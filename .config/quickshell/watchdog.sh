#!/usr/bin/env bash

# Restart QuickShell components that lost their Hyprland event socket.
#
# quickshell 0.3.0 has no reconnect path for Hyprland's .socket2.sock (only the
# i3/sway backend retries). After a "Hyprland event socket error:
# QLocalSocket::PeerClosedError" the process stays alive and systemd keeps
# reporting the unit active, so Restart=always never fires -- but no further
# Hyprland events arrive and the bar freezes until it is restarted by hand.
#
# Detect components that no longer hold an established connection to socket2
# and restart just those units.

set -euo pipefail

readonly components=(main board osd)
readonly runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

instance_signature() {
    if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        printf '%s\n' "$HYPRLAND_INSTANCE_SIGNATURE"
        return
    fi

    systemctl --user show-environment | sed -n 's/^HYPRLAND_INSTANCE_SIGNATURE=//p'
}

signature="$(instance_signature)"
[[ -n $signature ]] || exit 0

socket="$runtime_dir/hypr/$signature/.socket2.sock"

# Hyprland is not up (or the signature is stale) -- nothing to police.
[[ -S $socket ]] || exit 0

# Socket inodes of the client end of every established connection to socket2.
# ss omits the State column when a state filter is given, so match the address
# field by value rather than by position.
readarray -t peer_inodes < <(
    ss --unix --all --no-header state established 2>/dev/null \
        | awk -v sock="$socket" '{
            for (i = 1; i <= NF; i++)
                if ($i == sock) { print $NF; break }
          }'
)

holds_connection() {
    local pid="$1" fd target inode candidate

    for fd in /proc/"$pid"/fd/*; do
        target="$(readlink "$fd" 2>/dev/null)" || continue
        [[ $target =~ ^socket:\[([0-9]+)\]$ ]] || continue
        inode="${BASH_REMATCH[1]}"

        for candidate in "${peer_inodes[@]}"; do
            [[ $inode == "$candidate" ]] && return 0
        done
    done

    return 1
}

stale=()
for component in "${components[@]}"; do
    unit="quickshell@${component}.service"

    [[ "$(systemctl --user is-active "$unit")" == active ]] || continue

    pid="$(systemctl --user show -p MainPID --value "$unit")"
    [[ -n $pid && $pid != 0 && -d /proc/$pid ]] || continue

    if ! holds_connection "$pid"; then
        stale+=("$unit")
    fi
done

((${#stale[@]})) || exit 0

printf 'Hyprland event socket lost, restarting: %s\n' "${stale[*]}"
systemctl --user restart "${stale[@]}"
