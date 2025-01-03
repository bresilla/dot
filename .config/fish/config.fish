function fish_mode_prompt
end
function fish_greeting
end

source /home/bresilla/.aliases

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

###DIRENV
starship init fish | source
direnv hook fish | source
atuin init fish | source
