#!/usr/bin/env bash

set -euo pipefail

ENVY="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.config"

for item in "$ENVY"/.config/*; do
    rm -rf "$HOME/.config/$(basename "$item")"
    ln -sf "$item" "$HOME/.config/"
done

echo 'export ZDOTDIR="$HOME/.config/zsh"' > ~/.zshenv

for item in "$ENVY"/.{profile,xinitrc,winitrc}; do
    rm -rf "$HOME/$(basename "$item")"
    ln -sf "$item" "$HOME/"
done

BINDIR="$HOME/.local/bin"

echo "export PATH=$BINDIR:\$PATH" | sudo tee /etc/profile.d/envy.sh
echo 'for f in /etc/profile.d/*.sh; do [[ -r $f ]] && source "$f"; done' | sudo tee -a /etc/zsh/zshrc
echo 'for f in /etc/profile.d/*.sh; do [[ -r $f ]] && source "$f"; done' | sudo tee -a /etc/bash.bashrc
echo "set -gx PATH $BINDIR \$PATH" | sudo tee /etc/fish/conf.d/envy.fish

# wget -q https://github.com/marcosnils/bin/releases/download/v0.24.0/bin_0.24.0_linux_amd64 -O bin
# chmod +x bin

mkdir -p "$BINDIR" && ./bin ensure
