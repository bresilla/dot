return function(ctx)
    hl.on("hyprland.start", function()
        hl.exec_cmd("eval $(gnome-keyring-daemon --start)")
        hl.exec_cmd("export SSH_AUTH_SOCK")

        hl.exec_cmd("hyprpaper")
        hl.exec_cmd("sleep 1 && " .. ctx.home .. "/.local/bin/lule create --theme=dark -- set")
        hl.exec_cmd(ctx.home .. "/.local/bin/clipse -listen")
        hl.exec_cmd(ctx.home .. "/.local/bin/evsieve --input /dev/input/event2 grab --map key:capslock key:f12 --output")
        ctx.reload_plugins_and_apply_settings()
        hl.exec_cmd([[hyprctl setcursor "BreezeX-Black" 60]])
        hl.exec_cmd("systemctl --user start hyprpolkitagent")

        -- Imports WAYLAND_DISPLAY/HYPRLAND_INSTANCE_SIGNATURE into the user
        -- manager before starting quickshell.target. The target is no longer
        -- WantedBy=default.target, so this is what brings the shell up.
        hl.exec_cmd(ctx.home .. "/.config/quickshell/launch.sh")
    end)
end
