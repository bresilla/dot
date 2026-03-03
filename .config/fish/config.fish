function fish_mode_prompt
end
function fish_greeting
end

fish_vi_key_bindings

replay "source ~/.profile"
replay "source ~/.config/profile/aliases.sh"
# ─────────────────────────────────────────────────────────────────────────────
if test -f ~/.cache/wal/colors.sh
    replay 'source ~/.cache/wal/colors.sh'
end

set -x SHELL /bin/fish

# ─────────────────────────────────────────────────────────────────────────────
if type -q direnv
    direnv hook fish | source
end
if type -q atuin
    atuin init fish | source
end
if type -q zoxide
    zoxide init fish | source
end
if type -q starship
    starship init fish | source
end
if type -q carapace
    carapace fish | source
end

# ─────────────────────────────────────────────────────────────────────────────
## BINDINGS
bind -M insert ctrl-x tab repaint
bind -M insert ctrl-a scrr repaint

# ─────────────────────────────────────────────────────────────────────────────
# advanced cd
function cd --description 'cd with pro-file, git-root, zoxide & default behavior'
    # first argument
    set -l dest $argv[1]
    # 1) no args + pro‐marker file exists → jump home then back
    if test (count $argv) -eq 0 -a -f /env/dot/.func/code/pro
        builtin cd ~
        builtin cd -
        return
    end
    # 2) dest is a directory, or looks like an option “-x” or “--foo”
    if test -d $dest
        builtin cd $dest
        return
    else if string match -r '^-{1,2}[a-z]*$' $dest
        builtin cd $dest
        return
    end
    # 3) “cd root” → git top-level if in a repo
    if test "$dest" = root
        set -l gitroot (git rev-parse --show-toplevel 2>/dev/null)
        if test -d $gitroot
            builtin cd $gitroot
            return
        end
    end
    # 4) zoxide fallback if installed
    if type -q zoxide
        z $dest
        return
    end
    # 5) default
    builtin cd $dest
end

# ─────────────────────────────────────────────────────────────────────────────

bind \r clear-screen repaint

bresilla
