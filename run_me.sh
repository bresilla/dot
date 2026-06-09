#!/usr/bin/env bash

set -euo pipefail

ENVY="$(cd "$(dirname "$0")" && pwd)"

log() {
    printf '==> %s\n' "$*"
}

have() {
    command -v "$1" >/dev/null 2>&1
}

sudo_install_dir() {
    sudo install -d "$1"
}

sudo_write_file() {
    local file="$1"
    local content="$2"

    sudo_install_dir "$(dirname "$file")"
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
    ln -sfn "$install_dir/bin/nvim" "$BINDIR/nvim"
    rm -rf "$tmp_dir"
}

mkdir -p "$HOME/.config"

shopt -s nullglob
for item in "$ENVY"/.config/*; do
    rm -rf "$HOME/.config/$(basename "$item")"
    ln -sf "$item" "$HOME/.config/"
done
shopt -u nullglob

echo 'export ZDOTDIR="$HOME/.config/zsh"' > ~/.zshenv

for item in "$ENVY"/.{profile,winitrc}; do
    [[ -e "$item" ]] || continue
    rm -rf "$HOME/$(basename "$item")"
    ln -sf "$item" "$HOME/"
done

# Install bin
BINDIR="$HOME/.local/bin"
mkdir -p "$BINDIR"

log "Installing shell PATH hooks"
sudo_write_file /etc/profile.d/envy.sh "export PATH=$BINDIR:\$PATH"
sudo_append_line_once /etc/zsh/zshrc 'for f in /etc/profile.d/*.sh; do [[ -r $f ]] && source "$f"; done'
sudo_append_line_once /etc/bash.bashrc 'for f in /etc/profile.d/*.sh; do [[ -r $f ]] && source "$f"; done'
sudo_write_file /etc/fish/conf.d/envy.fish "set -gx PATH $BINDIR \$PATH"

load_github_auth_token

if ! have bin; then
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
    TMP_BIN="$(mktemp)"
    trap 'rm -f "$TMP_BIN"' EXIT
    curl -fsSL "https://github.com/marcosnils/bin/releases/download/v0.24.0/bin_0.24.0_linux_${BIN_ARCH}" -o "$TMP_BIN"
    chmod +x "$TMP_BIN"
    "$TMP_BIN" ensure
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
