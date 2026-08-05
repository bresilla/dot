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

    local function active_monitor()
        return hl.get_active_monitor() or hl.get_monitors()[1]
    end

    local function active_monitor_height()
        local monitor = active_monitor()
        return monitor and monitor.height or 1080
    end

    local function monitor_scale(monitor)
        return tonumber(monitor and monitor.scale) or 1
    end

    local function active_monitor_short_edge()
        local monitor = active_monitor()
        local width = monitor and monitor.width or 1920
        local height = monitor and monitor.height or 1080

        return math.min(width, height)
    end

    local function active_monitor_physical_edges()
        local monitor = active_monitor()
        local scale = monitor_scale(monitor)
        local width = monitor and monitor.width or 1920
        local height = monitor and monitor.height or 1080

        return math.min(width, height) * scale, math.max(width, height) * scale
    end

    local function is_internal_panel(monitor)
        local name = monitor and monitor.name or ""
        return name:match("^eDP") or name:match("^LVDS") or name:match("^DSI")
    end

    local function clamp(value, min, max)
        return math.max(min, math.min(max, value))
    end

    local function sigmoid(value)
        return 1 / (1 + math.exp(-value))
    end

    local function scaled_number(value, baseline)
        return active_monitor_height() * value / baseline
    end

    local function scaled_px(value, baseline)
        return tostring(math.floor(scaled_number(value, baseline) + 0.5))
    end

    -- Scratchpads are read at a glance rather than worked in, so they get a
    -- larger font than the tiled terminals.
    local scratchpad_font_scale = 1.2

    -- Scaling the bounds rather than the result keeps the sigmoid curve's shape
    -- intact, so the multiplier applies evenly at every resolution and the
    -- internal-panel cap moves with it.
    local function terminal_font_size(scale)
        scale = scale or 1

        local monitor = active_monitor()
        local short_edge, long_edge = active_monitor_physical_edges()
        local resolution_score = math.max(short_edge / 1440, long_edge / 2560)
        local min_font_size = 4.73 * scale
        local max_font_size = 12.6 * scale
        local internal_max_font_size = 9.45 * scale
        local font_size = min_font_size
            + sigmoid((resolution_score - 1.2) * 6) * (max_font_size - min_font_size)

        if is_internal_panel(monitor) then
            font_size = math.min(font_size, internal_max_font_size)
        end

        return string.format("%.2f", clamp(font_size, min_font_size, max_font_size))
    end

    local function terminal_padding_x()
        return scaled_px(36, 2160)
    end

    local function terminal_padding_y()
        return scaled_px(24, 2160)
    end

    local function kitty_cmd(args, font_scale)
        local cmd = "kitty"
            .. " -o font_size=" .. terminal_font_size(font_scale)
            .. " -o window_padding_width=" .. terminal_padding_y()

        if args and args ~= "" then
            cmd = cmd .. " " .. args
        end

        return cmd
    end

    local function alacritty_cmd(args, font_scale)
        local cmd = "alacritty"
            .. " -o font.size=" .. terminal_font_size(font_scale)
            .. " -o window.padding.x=" .. terminal_padding_x()
            .. " -o window.padding.y=" .. terminal_padding_y()

        if args and args ~= "" then
            cmd = cmd .. " " .. args
        end

        return cmd
    end

    bind_exec(super .. " + L", "hyprlock")

    bind_exec(super_meta .. " + P", "doas chvt 2")
    scratchpads.bind(super_meta .. " + Backspace", "ask", function()
        return kitty_cmd("--title ask -e aichat", scratchpad_font_scale)
    end, {
        size = { "monitor_h*0.8", "monitor_h*0.8" },
    })
    scratchpads.bind(super_meta .. " + Space", "browsy", function()
        return kitty_cmd("--title browsy -e browsy", scratchpad_font_scale)
    end, {
        size = { "monitor_w*0.6", "monitor_h*0.2" },
    })
    scratchpads.bind(super_meta .. " + Return", "appy", function()
        return kitty_cmd("--title appy -e appy", scratchpad_font_scale)
    end, {
        size = { "monitor_w*0.6", "monitor_h*0.2" },
    })
    bind_exec(super_meta .. " + F9", ctx.home .. "/.config/profile/functions/wm/lule_switch")

    hl.bind(super .. " + Escape", hl.dsp.window.close())
    hl.bind(super .. " + Return", function()
        hl.exec_cmd(alacritty_cmd())
    end)
    hl.bind(meta .. " + Return", function()
        hl.exec_cmd(kitty_cmd())
    end)

    scratchpads.bind(super .. " + Space", "noteing", function()
        return alacritty_cmd("--title noteing", scratchpad_font_scale)
    end, {
        size = { "monitor_w*0.78", "monitor_h*0.54" },
    })
    scratchpads.bind(meta .. " + Space", "main", function()
        return alacritty_cmd("--title main", scratchpad_font_scale)
    end, {
        size = { "monitor_w*0.78", "monitor_h*0.54" },
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
