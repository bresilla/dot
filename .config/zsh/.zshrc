#!/usr/bin/env zsh
#--------------------------------------------------------------------------------------------------------------------
###WAL COLORS
[ -f ~/.cache/wal/sequences ] && (cat ~/.cache/wal/sequences &)
[ -f ~/.cache/wal/colors.sh ] && source ~/.cache/wal/colors.sh

export SHELL=/bin/zsh

#--------------------------------------------------------------------------------------------------------------------
# treat `#', `~' and `^' characters as part of patterns for filename generation
setopt extended_glob
setopt local_options
# case insensitive matching when performing filename expansion
setopt no_case_glob
# if command not found, but directory found, cd into this directory
setopt auto_cd
# turn off automatic matching of ~/ directories (speeds things up)
setopt no_cdable_vars
# prevents you from accidentally overwriting an existing file
setopt clobber
# perform implicit tees or cats when multiple redirections are attempted
setopt multios
# do not send the HUP signal to backround jobs on shell exit
setopt no_hup
# parameter expansion, command substitution and arithmetic expansion are performed in prompts
setopt prompt_subst
# do not prompt when rm *
setopt rmstarsilent
#ignore commands that start with space
setopt histignorespace

unsetopt no_match

#--------------------------------------------------------------------------------------------------------------------
###VI MODE
bindkey -v
DEFAULT_VI_MODE=viins
KEYTIMEOUT=1
set_vi_mode_cursor() {
    case $KEYMAP in
        vicmd)
          printf "\033[2 q"
          ;;
        main|viins)
          printf "\033[3 q"
          ;;
    esac
}
zle-keymap-select(){ set_vi_mode_cursor; zle reset-prompt; }
zle-line-init(){ zle -K $DEFAULT_VI_MODE; }
zle -N zle-line-init
zle -N zle-keymap-select
vi-append-x-selection(){ RBUFFER=$(xsel -o -p </dev/null)$RBUFFER; }
zle -N vi-append-x-selection
bindkey -M vicmd '^P' vi-append-x-selection
vi-yank-x-selection(){ print -rn -- $CUTBUFFER | xsel -i -p; }
zle -N vi-yank-x-selection
bindkey -M vicmd '^Y' vi-yank-x-selection

#--------------------------------------------------------------------------------------------------------------------
###MODULES
# Load completion modules
zmodload zsh/complist

# Add completion paths BEFORE compinit
fpath=(~/.config/zsh/completions/src $fpath)

[[ -d ~/.cache/zsh ]] || mkdir -p ~/.cache/zsh
autoload -Uz compinit
compinit -d ~/.cache/zsh/zcompdump-$ZSH_VERSION

# Enable completion display
setopt autolist automenu

# Use git completions for hub (git is aliased to hub)
compdef hub=git

# Completion styles
zstyle ':completion:*' completer _extensions _complete _approximate
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.cache/zsh/zcompcache

# TMOUT=1
# Disable TRAPALRM during completion to prevent interference
TRAPALRM() {
  if [[ "$WIDGET" != "complete-word" ]] && [[ "$WIDGET" != "expand-or-complete" ]] && [[ -z "$_comp_setup" ]]; then
    zle reset-prompt
  fi
}

[ -d ~/.config/zsh/autosuggestions ] && source ~/.config/zsh/autosuggestions/zsh-autosuggestions.zsh
[ -d ~/.config/zsh/syntax ] && source ~/.config/zsh/syntax/zsh-syntax-highlighting.zsh

#--------------------------------------------------------------------------------------------------------------------
###KILLER
function run_killer(){ killer; zle reset-prompt; zle redisplay; }
zle -N run_killer
bindkey -M vicmd '^k' run_killer
bindkey -M viins '^k' run_killer
# bindkey '^o' run_killer
bindkey -s '^o' ' pik\n'

###SYSZ
function run_sysz(){ sysz; zle reset-prompt; zle redisplay; }
zle -N run_sysz
bindkey -M vicmd '^p' run_sysz
bindkey -M viins '^p' run_sysz
bindkey '^p' run_sysz

#--------------------------------------------------------------------------------------------------------------------
# CTRL-Z starts previously suspended process.
fancy-ctrl-z () {
  if [[ $#BUFFER -eq 0 ]]; then
    bg
    zle redisplay
    fg &>/dev/null
  else
    zle push-input
  fi
}
zle -N fancy-ctrl-z
bindkey '^Z' fancy-ctrl-z

#--------------------------------------------------------------------------------------------------------------------
###SCRIPTS PATH
export FPATH=~/.config/zsh:$FPATH

###ALIASES
[[ -f ~/.config/profile/aliases.sh ]] && source ~/.config/profile/aliases.sh
alias \$=''


###FUNCTIONS
if [ -d ~/.config/profile/functions ]; then
    for file in ~/.config/profile/functions/*; do
        if [ -d "$file" ]; then
            PATH="$file:$PATH"
        fi
    done
fi

alias sw=$HOME/.config/profile/functions/wm/startw

###PROFILE
[[ -e ~/.profile ]] && emulate sh -c 'source ~/.profile'

###SECRETS
[[ -e "/env/set/variables" ]] && source /env/set/variables

###DIRENV
[[ -x "$(command -v direnv)" ]] && eval "$(direnv hook zsh)"

###AUTIN
[[ -x "$(command -v atuin)" ]] && eval "$(atuin init zsh)"

###STARSHIP
# source ~/.config/promptline
# [[ -x "$(command -v starship)" ]] && eval "$(starship init zsh)" || source ~/.config/promptline
export HEXE_UNRESTRICTED_CONFIG=1
eval "$(hexe shp init zsh)"

bindkey -M viins -s '^E' 'dir=$(hexe mux float --title="explorer" -c '\''yazi --cwd-file="$HEXE_FLOAT_RESULT_FILE"'\'') && cd "$dir"\n'
bindkey -M viins -s '^P' 'file=$(hexe mux float --title="picker" -c '\''tv find > "$HEXE_FLOAT_RESULT_FILE"'\'') && $EDITOR "$file"\n'
bindkey -M viins -s '^F' 'file=$(hexe mux float --title="finder" -c '\''tv text > "$HEXE_FLOAT_RESULT_FILE"'\'') && $EDITOR "$file"\n'
bindkey -M viins -s '^O' 'hexe mux float --title="replace" -c '\''serpl -p .'\'' \n'

###MICROMAMBA
if command -v micromamba >/dev/null 2>&1 && micromamba --version >/dev/null 2>&1; then
    eval "$(micromamba shell hook --shell=zsh)"
fi

###SSH&GPG
export GPG_TTY=$(tty)
[[ -x "$(command -v gpgconf)" ]] && export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

#--------------------------------------------------------------------------------------------------------------------
# ALT-KEY shortcut
for key in {a..z}; do
    bindkey -s "^[${key}" " _${key}\n"
done

#--------------------------------------------------------------------------------------------------------------------
#RUN OR LS (shotrcut: Enter)
runner () {
    # check if the buffer does not contain any words
    if [ ${#${(z)BUFFER}} -eq 0 ]; then
      echo
      ll
    fi
    zle accept-line
}
zle -N runner
bindkey '^M' runner

#--------------------------------------------------------------------------------------------------------------------
###CD && ZOXIDE
[[ -x "$(command -v zoxide)" ]] && eval "$(zoxide init zsh)"
cd() {
    if [[ -z $1 ]] && [[ -f "/env/dot/.func/code/pro" ]]; then
        cd ~ && cd -
    elif [[ -d $1 ]] || [[ $date =~ ^[-]{1,2}+[a-z]* ]] ; then
        builtin cd $1
    elif [[ $1 == root ]] && [[ -d $(git rev-parse --show-toplevel) ]] ; then
        cd $(git rev-parse --show-toplevel)
    elif [[ -x "$(command -v zoxide)" ]] ; then
        z $1
    else
        builtin cd $1;
    fi
}

#--------------------------------------------------------------------------------------------------------------------
###CURRENT_EDITING_FILE
cf() { $EDITOR $(tv dot) }
zle -N cf

#--------------------------------------------------------------------------------------------------------------------
#TAB-RS (shotrcut: Ctrl + x)
bindkey -s '^X' ' tab\n'
bindkey -s '^A' ' scrr\n'
# [[ -n $TMUX ]] && tab $(names)

#--------------------------------------------------------------------------------------------------------------------
# ###CLEAR (preserves scrollback)
# clear() {
#     # Clear screen but preserve scrollback for viewing history
#     # tmux has its own separate scrollback buffer, so we can use normal clear
#     printf '\033[2J\033[H'
#     FIRST_PROMPT=true
# }

#---------------------------            EXTERNAL       --------------------------
[[ -s "$HOME/.external" ]] && source "$HOME/.external"

#-------------------------------------------------------------------------------------------------------------------- 
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi # added by Nix installer

# opencode
export PATH="$HOME/.opencode/bin:$PATH"
