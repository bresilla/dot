return function(ctx)
    local function load_colors()
        ctx.colors = ctx.util.read_wal_lua_colors(ctx.home .. "/.cache/wal/colors.lua")
        return ctx.colors
    end

    local function border_colors()
        local colors = ctx.colors or {}

        return ctx.util.hypr_rgb(colors.color1) or "rgb(efb9dd)",
            ctx.util.hypr_rgb(colors.color8 or colors.color0) or "rgb(595959)"
    end

    local active_border, inactive_border = border_colors()
    ctx.border_color_signature = active_border .. "|" .. inactive_border

    function ctx.apply_border_colors()
        load_colors()

        local active, inactive = border_colors()
        local signature = active .. "|" .. inactive

        if signature == ctx.border_color_signature then
            return
        end

        ctx.border_color_signature = signature

        hl.config({
            general = {
                col = {
                    active_border = active,
                    inactive_border = inactive,
                },
            },
        })
    end

    hl.config({
        debug = {
            disable_logs = true,
        },

        input = {
            kb_layout = "us",
            kb_variant = "",
            kb_model = "",
            kb_options = "caps:hyper",
            kb_rules = "",
            follow_mouse = 1,
            mouse_refocus = true,
            float_switch_override_focus = 1,
            touchpad = {
                natural_scroll = false,
                disable_while_typing = true,
            },
            sensitivity = 0,
        },

        general = {
            gaps_in = 5,
            gaps_out = 10,
            border_size = 3,
            col = {
                active_border = active_border,
                inactive_border = inactive_border,
            },
            layout = "dwindle",
            allow_tearing = false,
        },

        decoration = {
            rounding = 20,
            blur = {
                enabled = false,
            },
            shadow = {
                enabled = false,
            },
        },

        animations = {
            enabled = true,
        },

        misc = {
            force_default_wallpaper = 0,
            focus_on_activate = false,
            disable_scale_notification = true,
        },

        scrolling = {
            column_width = 0.7,
            fullscreen_on_one_column = true,
        },
    })

    hl.animation({ leaf = "windows", enabled = true, speed = 20, bezier = "default", style = "popin" })
    hl.animation({ leaf = "border", enabled = true, speed = 20, bezier = "default" })
    hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
    hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
    hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "default", style = "slidevert" })
    hl.animation({ leaf = "specialWorkspace", enabled = false })
    hl.animation({ leaf = "specialWorkspaceIn", enabled = false })
    hl.animation({ leaf = "specialWorkspaceOut", enabled = false })

    hl.timer(ctx.apply_border_colors, { timeout = 1000, type = "repeat" })
end
