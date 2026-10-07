return function(ctx)
    hl.on("hyprland.start", function()
        hl.exec_cmd("eval $(gnome-keyring-daemon --start)")
        hl.exec_cmd("export SSH_AUTH_SOCK")

        hl.exec_cmd("hyprpaper")
        -- The shell: morf, running ~/.config/morf/default (`make apply --example NAME`).
        hl.exec_cmd("/usr/bin/morf")
        hl.exec_cmd('bash "$HOME/.config/lule/wallpaper.sh" restore')
        hl.exec_cmd(ctx.home .. "/.local/bin/clipse -listen")
        hl.exec_cmd(ctx.home .. "/.local/bin/evsieve --input /dev/input/event2 grab --map key:capslock key:f12 --output")
        ctx.reload_plugins_and_apply_settings()
        hl.exec_cmd([[hyprctl setcursor "BreezeX-Black" 60]])
        -- hl.exec_cmd("systemctl --user start hyprpolkitagent")  -- morf is the polkit agent

    end)
end
