
# Fish completions for roc

# Helper function to check if we're in a subcommand
function __roc_using_subcommand
    set -l cmd (commandline -opc)
    if [ (count $cmd) -eq 1 ]
        return 1
    end
    
    # Check if the second argument is one of our main commands
    contains $cmd[2] action topic service param node interface frame run launch work bag daemon middleware completion
end

function __roc_using_subsubcommand
    set -l cmd (commandline -opc)
    if [ (count $cmd) -lt 3 ]
        return 1
    end
    return 0
end

# Main commands
complete -c roc -f -n "not __roc_using_subcommand" -a "action" -d "Various action subcommands"
complete -c roc -f -n "not __roc_using_subcommand" -a "topic" -d "Various topic subcommands"
complete -c roc -f -n "not __roc_using_subcommand" -a "service" -d "Various service subcommands"
complete -c roc -f -n "not __roc_using_subcommand" -a "param" -d "Various param subcommands"
complete -c roc -f -n "not __roc_using_subcommand" -a "node" -d "Various node subcommands"
complete -c roc -f -n "not __roc_using_subcommand" -a "interface" -d "Various interface subcommands"
complete -c roc -f -n "not __roc_using_subcommand" -a "frame" -d "Various transform subcommands"
complete -c roc -f -n "not __roc_using_subcommand" -a "run" -d "Run an executable"
complete -c roc -f -n "not __roc_using_subcommand" -a "launch" -d "Launch a launch file"
complete -c roc -f -n "not __roc_using_subcommand" -a "work" -d "Packages and workspace"
complete -c roc -f -n "not __roc_using_subcommand" -a "bag" -d "ROS bag tools"
complete -c roc -f -n "not __roc_using_subcommand" -a "daemon" -d "Daemon and bridge"
complete -c roc -f -n "not __roc_using_subcommand" -a "middleware" -d "Middleware settings"
complete -c roc -f -n "not __roc_using_subcommand" -a "completion" -d "Generate shell completions"

# Launch command completions
complete -c roc -f -n "__fish_seen_subcommand_from launch; and not __roc_using_subsubcommand" -a "(roc _complete launch '' '' 1 (commandline -opc)[3..] 2>/dev/null)" -d "Package"
complete -c roc -f -n "__fish_seen_subcommand_from launch; and __roc_using_subsubcommand" -a "(roc _complete launch '' '' 2 (commandline -opc)[3..] 2>/dev/null)" -d "Launch file"

# Run command completions  
complete -c roc -f -n "__fish_seen_subcommand_from run; and not __roc_using_subsubcommand" -a "(roc _complete run '' '' 1 (commandline -opc)[3..] 2>/dev/null)" -d "Package"
complete -c roc -f -n "__fish_seen_subcommand_from run; and __roc_using_subsubcommand" -a "(roc _complete run '' '' 2 (commandline -opc)[3..] 2>/dev/null)" -d "Executable"

# Topic command completions
complete -c roc -f -n "__fish_seen_subcommand_from topic; and not __roc_using_subsubcommand" -a "(roc _complete topic '' '' 1 (commandline -opc)[3..] 2>/dev/null)" -d "Topic subcommands"
complete -c roc -f -n "__fish_seen_subcommand_from topic; and __roc_using_subsubcommand" -a "(roc _complete topic (commandline -opc)[3] '' 1 (commandline -opc)[4..] 2>/dev/null)" -d "Topic names"

# Service command completions
complete -c roc -f -n "__fish_seen_subcommand_from service; and not __roc_using_subsubcommand" -a "(roc _complete service '' '' 1 (commandline -opc)[3..] 2>/dev/null)" -d "Service subcommands"
complete -c roc -f -n "__fish_seen_subcommand_from service; and __roc_using_subsubcommand" -a "(roc _complete service (commandline -opc)[3] '' 1 (commandline -opc)[4..] 2>/dev/null)" -d "Service names"

# Param command completions
complete -c roc -f -n "__fish_seen_subcommand_from param; and not __roc_using_subsubcommand" -a "(roc _complete param '' '' 1 (commandline -opc)[3..] 2>/dev/null)" -d "Param subcommands"
complete -c roc -f -n "__fish_seen_subcommand_from param; and __roc_using_subsubcommand" -a "(roc _complete param (commandline -opc)[3] '' 1 (commandline -opc)[4..] 2>/dev/null)" -d "Parameter names"

# Node command completions
complete -c roc -f -n "__fish_seen_subcommand_from node; and not __roc_using_subsubcommand" -a "(roc _complete node '' '' 1 (commandline -opc)[3..] 2>/dev/null)" -d "Node subcommands"
complete -c roc -f -n "__fish_seen_subcommand_from node; and __roc_using_subsubcommand" -a "(roc _complete node (commandline -opc)[3] '' 1 (commandline -opc)[4..] 2>/dev/null)" -d "Node names"

# Action command completions
complete -c roc -f -n "__fish_seen_subcommand_from action; and not __roc_using_subsubcommand" -a "(roc _complete action '' '' 1 (commandline -opc)[3..] 2>/dev/null)" -d "Action subcommands"
complete -c roc -f -n "__fish_seen_subcommand_from action; and __roc_using_subsubcommand" -a "(roc _complete action (commandline -opc)[3] '' 1 (commandline -opc)[4..] 2>/dev/null)" -d "Action names"

# Interface command completions
complete -c roc -f -n "__fish_seen_subcommand_from interface; and not __roc_using_subsubcommand" -a "(roc _complete interface '' '' 1 (commandline -opc)[3..] 2>/dev/null)" -d "Interface subcommands"
complete -c roc -f -n "__fish_seen_subcommand_from interface; and __roc_using_subsubcommand" -a "(roc _complete interface (commandline -opc)[3] '' 1 (commandline -opc)[4..] 2>/dev/null)" -d "Interfaces"

# Bag command completions
complete -c roc -f -n "__fish_seen_subcommand_from bag; and not __roc_using_subsubcommand" -a "(roc _complete bag '' '' 1 (commandline -opc)[3..] 2>/dev/null)" -d "Bag subcommands"
complete -c roc -f -n "__fish_seen_subcommand_from bag; and __roc_using_subsubcommand" -a "(roc _complete bag (commandline -opc)[3] '' 1 (commandline -opc)[4..] 2>/dev/null)" -d "Bag files"

# Work command completions
complete -c roc -f -n "__fish_seen_subcommand_from work; and not __roc_using_subsubcommand" -a "(roc _complete work '' '' 1 (commandline -opc)[3..] 2>/dev/null)" -d "Work subcommands"
complete -c roc -f -n "__fish_seen_subcommand_from work; and __roc_using_subsubcommand" -a "(roc _complete work (commandline -opc)[3] '' 1 (commandline -opc)[4..] 2>/dev/null)" -d "Packages"

# Frame command completions
complete -c roc -f -n "__fish_seen_subcommand_from frame; and not __roc_using_subsubcommand" -a "(roc _complete frame '' '' 1 (commandline -opc)[3..] 2>/dev/null)" -d "Frame subcommands"
complete -c roc -f -n "__fish_seen_subcommand_from frame; and __roc_using_subsubcommand" -a "(roc _complete frame (commandline -opc)[3] '' 1 (commandline -opc)[4..] 2>/dev/null)" -d "Frame names"

# Daemon command completions
complete -c roc -f -n "__fish_seen_subcommand_from daemon; and not __roc_using_subsubcommand" -a "(roc _complete daemon '' '' 1 (commandline -opc)[3..] 2>/dev/null)" -d "Daemon subcommands"

# Middleware command completions
complete -c roc -f -n "__fish_seen_subcommand_from middleware; and not __roc_using_subsubcommand" -a "(roc _complete middleware '' '' 1 (commandline -opc)[3..] 2>/dev/null)" -d "Middleware subcommands"

# Completion command completions
complete -c roc -f -n "__fish_seen_subcommand_from completion; and not __roc_using_subsubcommand" -a "bash zsh fish" -d "Shell type"
