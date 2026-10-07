#!/usr/bin/env bash
set -euo pipefail

# Restore the selected image at login; generate a new one on request or on
# the first login. Use PATH so this works with both Nix and local installs.
mode="${1:-generate}"
case "$mode" in generate|restore) ;; *) echo 'Usage: wallpaper.sh [generate|restore]' >&2; exit 2 ;; esac
export LULE_C="${LULE_C:-${XDG_CONFIG_HOME:-$HOME/.config}/lule}"
export LULE_A="${LULE_A:-${XDG_CACHE_HOME:-$HOME/.cache}/lule}"
folder="${XDG_DATA_HOME:-$HOME/.local/share}/lule/wallpapers"
image=''
if [[ "$mode" == restore ]] && command -v morf-wallpaper >/dev/null 2>&1; then
    image="$(morf-wallpaper adopt)" || image=''
fi
if [[ "$mode" == restore && -z "$image" && -f "$LULE_A/wallpaper" ]]; then
    image="$(cat "$LULE_A/wallpaper")"
fi
if [[ ! -f "$image" ]]; then
    logo="${LULE_LOGO:-$HOME/.dot/.bresilla/logo.svg}"
    [[ -f "$logo" ]] || { echo "Logo not found: $logo" >&2; exit 1; }
    dimensions="$(hyprctl monitors -j | jq -er 'map(select(.disabled != true)) | (map(select(.focused == true))[0] // .[0]) | if . == null then error("No active monitor") else [.width, .height] | @tsv end')"
    read -r width height <<< "$dimensions"
    mkdir -p "$folder"
    # A private directory reserves a unique output name; Lule rejects overwrites.
    generated="$(mktemp -d "$folder/generated.XXXXXXXX")"
    image="$generated/wallpaper.png"
    if ! lule wallpaper --logo="$logo" --size="${LULE_LOGO_SIZE:-40}" \
        --width="$width" --height="$height" --output="$image"; then
        rmdir "$generated" 2>/dev/null || true
        exit 1
    fi
fi

# Hyprpaper starts alongside us at login. Wait for its socket before applying.
ready=false
for ((attempt=0; attempt<40; attempt++)); do
    if hyprctl hyprpaper listactive >/dev/null 2>&1; then ready=true; break; fi
    sleep 0.25
done
if [[ "$ready" != true ]]; then echo 'Hyprpaper is not ready; wallpaper was not applied.' >&2; exit 1; fi
theme=dark
if [[ -f "$LULE_A/theme" ]]; then
    saved_theme="$(cat "$LULE_A/theme")"
    case "$saved_theme" in dark|light) theme="$saved_theme" ;; esac
fi
lule create --image="$image" --theme="$theme" -- set
echo "Lule wallpaper: $image"
