return function(ctx)
    local bind_exec = ctx.util.bind_exec
    local scratchpads = dofile(ctx.config_dir .. "/lua/scratchpads.lua")(ctx)

    local super = "SUPER"
    local meta = "ALT"
    local meta_mod = "ALT"
    local hyper = "Hyper_L"
    local menu = "CTRL"

    local super_meta = super .. " + " .. meta
    local super_meta_shift = super .. " + " .. meta_mod .. " + SHIFT"

    bind_exec(super .. " + L", "hyprlock")

    bind_exec(super_meta .. " + P", "doas chvt 2")
    scratchpads.bind(super_meta .. " + Backspace", "ask", "kitty --title ask -e aichat", {
        size = { "monitor_h*0.8", "monitor_h*0.8" },
    })
    scratchpads.bind(super_meta .. " + Space", "browsy", "kitty --title browsy -e browsy", {
        size = { "monitor_w*0.6", "monitor_h*0.2" },
    })
    scratchpads.bind(super_meta .. " + Return", "appy", "kitty --title appy -e appy", {
        size = { "monitor_w*0.6", "monitor_h*0.2" },
    })
    bind_exec(super_meta .. " + F9", ctx.home .. "/.config/profile/functions/wm/lule_switch")

    hl.bind(super .. " + Escape", hl.dsp.window.close())
    bind_exec(super .. " + Return", "alacritty")
    bind_exec(meta .. " + Return", "kitty")

    scratchpads.bind(super .. " + Space", "noteing", "alacritty --title noteing", {
        size = { "monitor_w*0.9", "monitor_h*0.6" },
    })
    scratchpads.bind(meta .. " + Space", "main", "alacritty --title main", {
        size = { "monitor_w*0.9", "monitor_h*0.6" },
    })

    scratchpads.bind(super .. " + M", "spotify", "flatpak run com.spotify.Client", {
        size = { "90%", "60%" },
    })
    scratchpads.bind(meta .. " + M", "spotify-premium", "flatpak run com.spotify.Client", {
        size = { "90%", "60%" },
    })

    hl.gesture({ fingers = 4, direction = "vertical", action = "workspace" })

    hl.bind(super .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind(meta_mod .. " + mouse:272", hl.dsp.window.resize(), { mouse = true })

    hl.bind(super_meta .. " + Up", function()
        ctx.focus_workspace_delta(-1)
    end)
    hl.bind(super_meta .. " + Down", function()
        ctx.focus_workspace_delta(1)
    end)

    hl.bind(super_meta_shift .. " + Up", function()
        ctx.move_window_to_workspace_delta(-1)
    end)
    hl.bind(super_meta_shift .. " + Down", function()
        ctx.move_window_to_workspace_delta(1)
    end)

    hl.bind(super .. " + left", hl.dsp.focus({ direction = "left" }))
    hl.bind(super .. " + right", hl.dsp.focus({ direction = "right" }))
    hl.bind(super .. " + up", hl.dsp.focus({ direction = "up" }))
    hl.bind(super .. " + down", hl.dsp.focus({ direction = "down" }))

    hl.bind(super .. " + f", hl.dsp.window.float({ action = "toggle" }))
    hl.bind(super .. " + s", hl.dsp.window.fullscreen())

    bind_exec("XF86AudioMute", "pamixer -t", { repeating = true })
    bind_exec("XF86AudioRaiseVolume", "pamixer -i 2", { repeating = true })
    bind_exec("XF86AudioLowerVolume", "pamixer -d 2", { repeating = true })
    bind_exec("XF86AudioPlay", "playerctl next", { repeating = true })

    bind_exec("XF86MonBrightnessDown", ctx.home .. "/.config/profile/functions/system/bright -2")
    bind_exec("XF86MonBrightnessUp", ctx.home .. "/.config/profile/functions/system/bright +2")

    bind_exec("Print", ctx.home .. "/.config/profile/functions/wm/capture i")

    bind_exec(menu .. " + Return", "play")
    bind_exec(menu .. " + Space", "mpv_control cycle")
    bind_exec(menu .. " + comma", "mpv_control backwards 10")
    bind_exec(menu .. " + period", "mpv_control forewards 10")

    bind_exec(super .. " + F9", ctx.home .. "/.config/profile/functions/wm/lule_create")

    _ = hyper
end
