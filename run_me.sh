#! /usr/bin/env bash


[[ -d "/env" ]] && ENVY="/env" || echo "/$HOME not set"
[[ ! -d "$HOME/.config" ]] && mkdir -p $HOME/.config

ln -sf $ENVY/dot/.config/* $HOME/.config
ln -sf $ENVY/dot/.{aliases,bashrc,func,profile,startup,xinitrc,winitrc,zshrc} $HOME

# [[ ! -d $HOME/.vnc ]] && mkdir $HOME/.vnc
# cp $ENVY/dot/.vnc/* $HOME/.vnc
#

echo 'export PATH=/env/bin:$PATH' | sudo tee /etc/profile.d/envy.sh
echo 'for f in /etc/profile.d/*.sh; do [[ -r $f ]] && source "$f"; done' | sudo tee -a /etc/zsh/zshrc
echo 'for f in /etc/profile.d/*.sh; do [[ -r $f ]] && source "$f"; done' | sudo tee -a /etc/bash.bashrc
echo 'set -gx PATH /env/bin $PATH' | sudo tee /etc/fish/conf.d/envy.fish


wget https://github.com/marcosnils/bin/releases/download/v0.24.0/bin_0.24.0_linux_amd64 -O bin
chmod +x bin

[[ ! -d /env/bin ]] && mkdir -p /env/bin && ./bin ensure
