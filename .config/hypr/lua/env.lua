return function(ctx)
    ctx.colors = ctx.util.read_wal_lua_colors(ctx.home .. "/.cache/wal/colors.lua")

    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")

    hl.env("LULE_S", ctx.home .. "/.config/profile/functions/wm/lule_colors")
    hl.env("LULE_C", ctx.home .. "/.cache/lule")
    hl.env("LULE_W", "/env/set/.wallpaper")

    local plugin_keywords = {
        "plugin:borders-plus-plus:add_borders 1",
        "plugin:borders-plus-plus:border_size_1 1",
        "plugin:borders-plus-plus:border_size_2 -1",
        "plugin:borders-plus-plus:natural_rounding yes",
    }

    function ctx.reload_plugins_and_apply_settings()
        local commands = { "hyprpm reload -n" }

        for _, keyword in ipairs(plugin_keywords) do
            table.insert(commands, "hyprctl keyword " .. keyword)
        end

        hl.exec_cmd(table.concat(commands, " && "))
    end
end
