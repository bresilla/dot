#!/usr/bin/env bash

set -euo pipefail

ENVY="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.config"

for item in "$ENVY"/.config/*; do
    rm -rf "$HOME/.config/$(basename "$item")"
    ln -sf "$item" "$HOME/.config/"
done

echo 'export ZDOTDIR="$HOME/.config/zsh"' > ~/.zshenv

for item in "$ENVY"/.{profile,winitrc}; do
    rm -rf "$HOME/$(basename "$item")"
    ln -sf "$item" "$HOME/"
done

# Install bin
BINDIR="$HOME/.local/bin"
echo "export PATH=$BINDIR:\$PATH" | sudo tee /etc/profile.d/envy.sh
echo 'for f in /etc/profile.d/*.sh; do [[ -r $f ]] && source "$f"; done' | sudo tee -a /etc/zsh/zshrc
echo 'for f in /etc/profile.d/*.sh; do [[ -r $f ]] && source "$f"; done' | sudo tee -a /etc/bash.bashrc
echo "set -gx PATH $BINDIR \$PATH" | sudo tee /etc/fish/conf.d/envy.fish
if [ ! command -v bin &> /dev/null ]; then
    curl -sL https://github.com/marcosnils/bin/releases/download/v0.24.0/bin_0.24.0_linux_amd64 -o bin
    chmod +x bin
    ./bin ensure
else
    bin ensure
fi

# Install Nix
if [ ! command -v nix-env &> /dev/null ]; then
    if [ ! -d "/nix" ]; then
        sudo mkdir /nix
        chown -R $USER /nix
    fi
    sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --no-daemon
fi
