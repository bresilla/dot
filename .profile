export HOSTNAME=$(uname -n)

export DOTS=$HOME/dots
export SETS=$HOME/sets
export DATA=$HOME/data
export DOWN=$HOME/down
export TEMP=/tmp

#USER BINARIES AND SCRIPTS
export LD_LIBRARY_PATH=/env/lib:$LD_LIBRARY_PATH
[[ -d "/env/bin" ]] && PATH="/env/bin:/opt/TurboVNC/bin:$PATH"
[[ -d "$HOME/.local/bin" ]] && PATH="$HOME/.local/bin:$PATH"
# No existence test on this one: oslo creates it when the first stored script is published, and a
# shell that logged in before that would go without it until the next login — which is exactly how
# `git rel` went missing. A PATH entry that is not there yet costs nothing.
PATH="$HOME/.local/sbin:$PATH"

# The fifteen ~/.config/profile/functions/* directories were added to PATH here. Those scripts are
# in the oslo macro database now, and every change writes them into ~/.local/sbin — already on PATH
# above — so bash, tmux and .desktop files still find them by name. oslo reads the database itself
# and leaves that directory out of its own search.

#PKGCONFIGS
export PKG_CONFIG_PATH=/usr/lib/pkgconfig

#HELIX
export HELIX_RUNTIME=$HOME/.local/share/helix

#---------------------------         LOC & TERM          --------------------------
export COLORTERM=truecolor
export BROWSER=app.zen_browser.zen
export NVIM_LOG_FILE=/dev/null
export EDITOR=hx
# export TERMINAL=kitty
# export CONSOLE=kitty
# export TERM=xterm-256color
export DISTRO=$(cat /etc/os-release | grep -m 1 ID)

#---------------------------         LANGUAGES          --------------------------
#C++
export XMAKE_GLOBALDIR=/pkg/xmake
[[ -s "$HOME/.xmake/profile" ]] && source "$HOME/.xmake/profile"
export VCPKG_ROOT="/pkg/vcpkg"
# RUST
export CARGO_HOME="/pkg/cargo"
export RUSTUP_HOME="$CARGO_HOME/rustup"
[[ -d "$CARGO_HOME/bin" ]] && PATH="$CARGO_HOME/bin:$PATH"
# GO
export GOPATH="/pkg/go"
export GOBIN="$GOPATH/bin"
export GO111MODULE=on
[[ -d "$GOPATH/bin" ]] && PATH="$GOPATH/bin:$PATH"
export PATH=$PATH:/usr/local/go/bin
# NIM
export NIMBLE_DIR="/pkg/nimble"
# ZIG
export ZIGY=zig
# PYTHON
export PIXI_DIR=/pkg/pixi/

#---------------------------             LULE           --------------------------
export BAT_THEME="TwoDark"
export LULE_W="/env/set/.wallpaper"
# LULE_C is the config directory - where init.lua and the named schemes live. The cache is LULE_A.
export LULE_C="$HOME/.config/lule"
export LULE_A="$HOME/.cache/lule"
export DSTASK_GIT_REPO=/doc/self/TASKS
export GUM_CHOOSE_CURSOR_FOREGROUND="1"
export GUM_CHOOSE_SELECTED_FOREGROUND="9"
export GUM_CONFIRM_SELECTED_FOREGROUND="15"
export GUM_CONFIRM_UNSELECTED_FOREGROUND="7"

#---------------------------            LOCALE           --------------------------
export TZ='Europe/Berlin'
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"
#export LC_CTYPE="en_US.UTF-8"
#export LC_NUMERIC="en_US.UTF-8"
#export LC_TIME="en_US.UTF-8"
#export LC_COLLATE="en_US.UTF-8"
#export LC_MONETARY="en_US.UTF-8"
#export LC_MESSAGES="en_US.UTF-8"
#export LC_PAPER="en_US.UTF-8"
#export LC_NAME="en_US.UTF-8"
#export LC_ADDRESS="en_US.UTF-8"
#export LC_TELEPHONE="en_US.UTF-8"
#export LC_MEASUREMENT="en_US.UTF-8"
#export LC_IDENTIFICATION="en_US.UTF-8"
export LOCALE_ARCHIVE=/usr/lib/locale/locale-archive


#---------------------------              XDG           --------------------------
# export XDG_CONFIG_HOME=/home/$USER/.config
# export XDG_CONFIG_PATH=/home/$USER/.config
# export XDG_DATA_HOME=/home/$USER/.local/share
# export XDG_DATA_PATH=/home/$USER/.local/share
export XDG_CACHE_HOME=/home/$USER/.cache
export XDG_CACHE_PATH=/home/$USER/.cache
export GNUPGHOME="$XDG_DATA_HOME"/gnupg
export PASSWORD_STORE_DIR="$XDG_DATA_HOME"/pass
export GRAVEYARD=/tmp/graveyard-$USER

#---------------------------     HOME_CLEANUP          --------------------------
export LESSHISTFILE="$XDG_CACHE_HOME"/less/history
export CCACHE_DIR="$XDG_CACHE_HOME"/ccache
export CUDA_CACHE_PATH="$XDG_CACHE_HOME"/nv


#---------------------------            CORE            --------------------------
if [ "$HOSTNAME" = core ]; then
    # eval $(gnome-keyring-daemon --start)
    export SSH_AUTH_SOCK
    # export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
    export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/yubikey-agent/yubikey-agent.sock"
    export GPG_TTY=$(tty)
fi
export LOGO_PATH="$HOME/.bresilla"
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp

if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi # added by Nix installer
