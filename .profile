export HOSTNAME=$(uname -n)

export DOTS=$HOME/dots
export SETS=$HOME/sets
export DATA=$HOME/data
export DOWN=$HOME/down
export SYNC=$HOME/sync
export TEMP=/tmp

export PATH=/usr/local/cuda-12.9/bin:$PATH
export PATH="/home/bresilla/.deno/bin:/home/bresilla/.bun/bin:/.npm-global/bin:$PATH"
export PATH="/opt/TurboVNC/bin/:$PATH"
export LD_LIBRARY_PATH=/usr/local/cuda-12.9/lib64:$LD_LIBRARY_PATH


#USER BINARIES AND SCRIPTS
export LD_LIBRARY_PATH=/env/lib:$LD_LIBRARY_PATH
[[ -d "/env/bin" ]] && PATH="$PATH:/env/bin"
[[ -d "$HOME/.local/bin" ]] && PATH="$HOME/.local/bin:$PATH"
[[ -d "$HOME/.local/sbin" ]] && PATH="$HOME/.local/sbin:$PATH"
[[ -d /env/dot/.func ]] && for file in /env/dot/.func/*; do [[ -d "$file" ]] && PATH="$file:$PATH"; done

#SECRETS
[[ -e "/env/set/variables" ]] && source /env/set/variables

#ALT
export PATH="$HOME/.local/alt/shims:$PATH"

#PKGCONFIGS
export PKG_CONFIG_PATH=/usr/lib/pkgconfig

#---------------------------         LOC & TERM          --------------------------
export COLORTERM=truecolor
export BROWSER=app.zen_browser.zen
export EDITOR=hx
export TERMINAL=kitty
export CONSOLE=kitty
export TERM=xterm-256color
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
export LULE_W="/env/set/.animegen"
export LULE_S="/env/dot/.func/wm/lule_colors"
export LULE_C="/home/bresilla/.config/lule/configs.json"
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
export XDG_CONFIG_HOME=/home/$USER/.config
export XDG_CONFIG_PATH=/home/$USER/.config
export XDG_DATA_HOME=/home/$USER/.local/share
export XDG_DATA_PATH=/home/$USER/.local/share
export XDG_CACHE_HOME=/home/$USER/.cache
export XDG_CACHE_PATH=/home/$USER/.cache
export GNUPGHOME="$XDG_DATA_HOME"/gnupg
export PASSWORD_STORE_DIR="$XDG_DATA_HOME"/pass
export GRAVEYARD=/tmp/graveyard-$USER

#---------------------------     HOME_CLEANUP          --------------------------
export LESSHISTFILE="$XDG_CACHE_HOME"/less/history
export CCACHE_DIR="$XDG_CACHE_HOME"/ccache
export CUDA_CACHE_PATH="$XDG_CACHE_HOME"/nv


#---------------------------            ROS             --------------------------
#export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
#export CYCLONEDDS_URI='<CycloneDDS><Domain><General><NetworkInterfaceAddress>stargate</></></></>'
#export CYCLONEDDS_URI='<CycloneDDS><Domain><General><Interfaces><NetworkInterface name="stargate"/></></></></>'
export ROS_DOMAIN_ID=226
export WEBOTS_HOME=/usr/local/webots
export LD_LIBRARY_PATH=/usr/local/webots/lib/controller:$LD_LIBRARY_PATH
export PYTHONPATH=/usr/local/webots/lib/controller/python:$PYTHONPATH

#---------------------------         PLATFORMIO         --------------------------
export PLATFORMIO_CORE_DIR=/pkg/pio/core


#----------------------------        HIVE-SERVER        ---------------------------
export OLLAMA_HOST=borg.skynet:11434
#export DOCKER_HOST=tcp://borg.zerotier:2375


#----------------------------            OTHER          ---------------------------
export LOCAL_NOTEBOOK_DEV=1

#---------------------------            CORE            --------------------------
if [ "$HOSTNAME" = core ]; then
    # eval $(gnome-keyring-daemon --start)
    export SSH_AUTH_SOCK
    # export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
    export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/yubikey-agent/yubikey-agent.sock"
    export GPG_TTY=$(tty)
fi
[[ -f "$HOME/.external" ]] && source /home/bresilla/.external
