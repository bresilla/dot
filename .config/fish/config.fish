function fish_mode_prompt
end
function fish_greeting
end

source /home/bresilla/.aliases

#--------------------------------------------------------------------------------------------------------------------
if test -f ~/.cache/wal/colors.sh
    replay 'source ~/.cache/wal/colors.sh'
end

set -x SHELL /bin/fish

#--------------------------------------------------------------------------------------------------------------------
## FUNCTIONS
function n --wraps nnn --description 'support nnn quit and change directory'
    if test -n "$NNNLVL"
        if [ (expr $NNNLVL + 0) -ge 1 ]
            echo "nnn is already running"
            return
        end
    end
    if test -n "$XDG_CONFIG_HOME"
        set -x NNN_TMPFILE "$XDG_CONFIG_HOME/nnn/.lastd"
    else
        set -x NNN_TMPFILE "$HOME/.config/nnn/.lastd"
    end
    nnn $argv
    if test -e $NNN_TMPFILE
        source $NNN_TMPFILE
        rm $NNN_TMPFILE
    end
end

function cd
    if test -z "$argv[1]" && test -f "/env/dot/.func/code/pro"
        /env/dot/.func/code/pro
    else if test -d "$argv[1]" || string match -qr '^--?[a-z]*' "$argv[1]"
        builtin cd "$argv[1]"
    else if test "$argv[1]" = root && git rev-parse --show-toplevel >/dev/null 2>&1
        cd (git rev-parse --show-toplevel)
    else if command -v zoxide >/dev/null 2>&1
        z $argv[1]
    else
        builtin cd "$argv[1]"
    end
end

#--------------------------------------------------------------------------------------------------------------------
## BINDINGS
bind \cx 'tab; commandline -f execute'
bind \cw 'n; commandline -f execute'
bind \ca 'scrr; commandline -f execute'
bind \cb 'build; commandline -f execute'
bind \cr 'run; commandline -f execute'
bind \cg 'git go; commandline -f execute'

#--------------------------------------------------------------------------------------------------------------------
starship init fish | source
direnv hook fish | source
atuin init fish | source
zoxide init fish | source

# bresilla
# echo "Fish shell is ready!"
