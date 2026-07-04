#!/usr/bin/env bash

set -euo pipefail

ENVY="$(cd "$(dirname "$0")" && pwd)"
SKIP_BIN=false

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --skip-bin)
            SKIP_BIN=true
            shift
            ;;
        -h | --help)
            printf 'usage: %s [--skip-bin]\n' "$(basename "$0")"
            exit 0
            ;;
        *)
            printf 'unknown argument: %s\n' "$1" >&2
            exit 1
            ;;
    esac
done

log() {
    printf '==> %s\n' "$*"
}

have() {
    command -v "$1" >/dev/null 2>&1
}

replace_path() {
    local target="$1"

    rm -rf -- "$target"
}

write_file_replace() {
    local file="$1"
    local content="$2"

    mkdir -p "$(dirname "$file")"
    replace_path "$file"
    printf '%s\n' "$content" > "$file"
}

link_replace() {
    local source="$1"
    local target="$2"

    mkdir -p "$(dirname "$target")"
    replace_path "$target"
    ln -s "$source" "$target"
}

install_config_links() {
    local config_dir="$HOME/.config"
    local item
    local target

    mkdir -p "$config_dir"

    shopt -s nullglob dotglob
    for target in "$config_dir"/*; do
        [[ -L "$target" ]] || continue
        rm -f -- "$target"
    done

    for item in "$ENVY"/.config/*; do
        link_replace "$item" "$config_dir/$(basename "$item")"
    done
    shopt -u nullglob dotglob
}

sudo_install_dir() {
    sudo install -d "$1"
}

sudo_write_file() {
    local file="$1"
    local content="$2"

    sudo_install_dir "$(dirname "$file")"
    sudo rm -rf -- "$file"
    printf '%s\n' "$content" | sudo tee "$file" >/dev/null
}

sudo_append_line_once() {
    local file="$1"
    local line="$2"

    sudo_install_dir "$(dirname "$file")"
    sudo touch "$file"
    if ! sudo grep -qxF "$line" "$file"; then
        printf '%s\n' "$line" | sudo tee -a "$file" >/dev/null
    fi
}

sudo_append_line_once_existing() {
    local file="$1"
    local line="$2"

    [[ -e "$file" ]] || return 0
    sudo_append_line_once "$file" "$line"
}

sudo_write_file_in_existing_dir() {
    local file="$1"
    local content="$2"
    local dir

    dir="$(dirname "$file")"
    [[ -d "$dir" ]] || return 0
    sudo_write_file "$file" "$content"
}

sudo_remove_line() {
    local file="$1"
    local line="$2"
    local tmp_file

    [[ -e "$file" ]] || return 0

    tmp_file="$(mktemp)"
    sudo grep -vxF "$line" "$file" > "$tmp_file" || true
    sudo tee "$file" < "$tmp_file" >/dev/null
    rm -f "$tmp_file"
}

load_github_auth_token() {
    if [[ -n "${GITHUB_AUTH_TOKEN:-}" ]]; then
        export GITHUB_AUTH_TOKEN
    fi
}

bin_asset_arch() {
    case "$(uname -m)" in
        x86_64 | amd64) printf 'amd64' ;;
        aarch64 | arm64) printf 'arm64' ;;
        armv7l | armv7*) printf 'armv7' ;;
        armv6l | armv6*) printf 'armv6' ;;
        *)
            printf 'unsupported'
            ;;
    esac
}

nvim_asset_arch() {
    case "$(uname -m)" in
        x86_64 | amd64) printf 'x86_64' ;;
        aarch64 | arm64) printf 'arm64' ;;
        *)
            printf 'unsupported'
            ;;
    esac
}

install_neovim() {
    if have nvim; then
        log "Neovim already installed"
        return
    fi

    if ! have curl; then
        printf 'curl is required to install Neovim. Install curl first and rerun this script.\n' >&2
        exit 1
    fi

    if ! have tar; then
        printf 'tar is required to install Neovim. Install tar first and rerun this script.\n' >&2
        exit 1
    fi

    local nvim_arch
    nvim_arch="$(nvim_asset_arch)"
    if [[ "$nvim_arch" == "unsupported" ]]; then
        log "Skipping Neovim binary install: unsupported architecture $(uname -m)"
        return
    fi

    local version="${NVIM_VERSION:-latest}"
    local archive_name="nvim-linux-${nvim_arch}.tar.gz"
    local url="https://github.com/neovim/neovim/releases/${version}/download/${archive_name}"
    local opt_dir="$HOME/.local/opt"
    local install_dir="$opt_dir/nvim"
    local tmp_dir

    tmp_dir="$(mktemp -d)"

    log "Installing Neovim ${version} for $(uname -m)"
    curl -fsSL "$url" -o "$tmp_dir/$archive_name"
    tar -xzf "$tmp_dir/$archive_name" -C "$tmp_dir"

    mkdir -p "$opt_dir" "$BINDIR"
    rm -rf "$install_dir"
    mv "$tmp_dir/nvim-linux-${nvim_arch}" "$install_dir"
    link_replace "$install_dir/bin/nvim" "$BINDIR/nvim"
    rm -rf "$tmp_dir"
}

install_config_links

write_file_replace "$HOME/.zshenv" 'export ZDOTDIR="$HOME/.config/zsh"
export NVIM_LOG_FILE=/dev/null'

for item in "$ENVY"/.{profile,winitrc}; do
    [[ -e "$item" ]] || continue
    link_replace "$item" "$HOME/$(basename "$item")"
done

# Install bin
BINDIR="$HOME/.local/bin"
mkdir -p "$BINDIR"

log "Installing shell PATH hooks"
BAD_PROFILE_D_SOURCE='for f in /etc/profile.d/*.sh; do [[ -r $f ]] && source "$f"; done'
PATH_HOOK="case \":\$PATH:\" in *\":$BINDIR:\"*) ;; *) export PATH=\"$BINDIR:\$PATH\" ;; esac"

sudo_remove_line /etc/zsh/zshrc "$BAD_PROFILE_D_SOURCE"
sudo_remove_line /etc/bash.bashrc "$BAD_PROFILE_D_SOURCE"
sudo_write_file_in_existing_dir /etc/profile.d/envy.sh "$PATH_HOOK"
sudo_append_line_once_existing /etc/zsh/zshrc "$PATH_HOOK"
sudo_append_line_once_existing /etc/bash.bashrc "$PATH_HOOK"
sudo_write_file_in_existing_dir /etc/fish/conf.d/envy.fish "set -gx PATH $BINDIR \$PATH"

load_github_auth_token

if [[ "$SKIP_BIN" == true ]]; then
    log "Skipping bin install"
elif ! have bin; then
    if ! have curl; then
        printf 'curl is required to install bin. Install curl first and rerun this script.\n' >&2
        exit 1
    fi

    BIN_ARCH="$(bin_asset_arch)"
    if [[ "$BIN_ARCH" == "unsupported" ]]; then
        printf 'Unsupported architecture for bin installer: %s\n' "$(uname -m)" >&2
        exit 1
    fi

    log "Installing bin for $(uname -m)"
    TMP_BIN_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_BIN_DIR"' EXIT
    curl -fsSL "https://github.com/bresilla/bin/releases/latest/download/bin_linux_${BIN_ARCH}.tar.gz" \
        | tar -xzf - -C "$TMP_BIN_DIR"
    chmod +x "$TMP_BIN_DIR/bin"
    "$TMP_BIN_DIR/bin" ensure
else
    log "Running bin ensure"
    bin ensure
fi

install_neovim

# Install Nix
if ! have nix-env; then
    if ! have curl; then
        printf 'curl is required to install Nix. Install curl first and rerun this script.\n' >&2
        exit 1
    fi

    if [ ! -d "/nix" ]; then
        sudo mkdir /nix
        sudo chown -R "$USER" /nix
    fi
    sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --no-daemon
fi
