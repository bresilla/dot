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
# autoload -U colors && colors
autoload compinit && compinit -d ~/.cache/zsh/zcompdump-$ZSH_VERSION

# TMOUT=1
TRAPALRM() { [[ "$WIDGET" != "complete-word" ]] && zle reset-prompt }

[ -d ~/.config/zsh/autosuggestions ] && source ~/.config/zsh/autosuggestions/zsh-autosuggestions.zsh
[ -d ~/.config/zsh/syntax ] && source ~/.config/zsh/syntax/zsh-syntax-highlighting.zsh

fpath+="/home/bresilla/.config/zsh/completions/src"

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
[[ -f ~/.aliases ]] && source ~/.aliases
alias \$=''

###PROFILE
[[ -e ~/.profile ]] && emulate sh -c 'source ~/.profile'

##NAME
# [[ -x "$(command -v tmux)" ]] && tmux setenv -g TMUX_FANCY_$(tmux display -p "#D" | tr -d %) $FANCY
# [[ -x "$(command -v tmux)" ]] && tmux setenv FANCY $FANCY

###DIRENV
[[ -x "$(command -v direnv)" ]] && eval "$(direnv hook zsh)"

##DEVBOX
# [[ -x "$(command -v devbox)" ]] && eval "$(devbox global shellenv --init-hook)"

###AUTIN
[[ -x "$(command -v atuin)" ]] && eval "$(atuin init zsh)"


###CARAPACE
# export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
# zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
# [[ -x "$(command -v carapace)" ]] && source <(carapace _carapace)
# zstyle ':completion:*:git:*' group-order 'main commands' 'alias commands' 'external commands'

###NOSTROMO
[[ -x "$(command -v nostromo)" ]] && source <(nostromo completion zsh)

###STARSHIP
#source ~/.config/promptline
[[ -x "$(command -v starship)" ]] && eval "$(starship init zsh)" || source ~/.config/promptline

###MICROMAMBA
[[ -x "$(command -v micromamba)" ]] && eval "$(micromamba shell hook --shell=zsh)"

###SSH&GPG
export GPG_TTY=$(tty)
[[ -x "$(command -v gpgconf)" ]] && export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

#--------------------------------------------------------------------------------------------------------------------
# NNN
# [[ -e ~/.config/nnn/config.sh ]] && emulate sh -c 'source ~/.config/nnn/config.sh'
# n(){
#   export NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"
#   if [ -n $NNNLVL ] && [ "${NNNLVL:-0}" -ge 1 ]; then echo "already running"; return; fi
#   nnn -deuUHQ "$@"
#   if [ -f "$NNN_TMPFILE" ]; then
#     . "$NNN_TMPFILE"; rm -f "$NNN_TMPFILE" > /dev/null
#   fi
# }
# #YAZI
# yazicd() {
#     local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
#     local cwd
#     yazi "$@" --cwd-file="$tmp"
#     if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
#         builtin cd -- "$cwd"
#         for precmd in $precmd_functions; do
#           $precmd
#         done
#         zle reset-prompt
#         printf '\e[4 q'
#     fi
#     rm -f -- "$tmp"
# }
# zle -N yazicd
# bindkey '^W' yazicd


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
[[ -n $TAB ]] && export DISPLAY=:0
[[ ! -n $TAB ]] && bresilla

#---------------------------            EXTERNAL       --------------------------
[[ -s "$HOME/.external" ]] && source "$HOME/.external"

#-------------------------------------------------------------------------------------------------------------------- 
#--------------------------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------------------------

if [ -e /home/bresilla/.nix-profile/etc/profile.d/nix.sh ]; then . /home/bresilla/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer
