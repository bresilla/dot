return function(ctx)
    ctx.colors = ctx.util.read_wal_lua_colors(ctx.home .. "/.cache/wal/colors.lua")

    hl.env("LULE_C", ctx.home .. "/.config/lule")
    hl.env("LULE_A", ctx.home .. "/.cache/lule")
    hl.env("LULE_W", ctx.home .. "/.local/share/lule/wallpapers")

    local function plugin_keywords()
        local extra_border_size = ctx.hypr_extra_border_size and ctx.hypr_extra_border_size() or 1

        return {
            "plugin:borders-plus-plus:add_borders 1",
            "plugin:borders-plus-plus:border_size_1 " .. extra_border_size,
            "plugin:borders-plus-plus:border_size_2 -1",
            "plugin:borders-plus-plus:natural_rounding yes",
        }
    end

    function ctx.reload_plugins_and_apply_settings()
        local commands = { "hyprpm reload -n" }

        for _, keyword in ipairs(plugin_keywords()) do
            table.insert(commands, "hyprctl keyword " .. keyword)
        end

        hl.exec_cmd(table.concat(commands, " && "))
    end
end
