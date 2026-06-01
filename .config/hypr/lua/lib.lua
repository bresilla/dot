local M = {}

function M.read_wal_lua_colors(path)
    local ok, wal = pcall(dofile, path)

    if not ok or type(wal) ~= "table" then
        return {}
    end

    local colors = {}

    if type(wal.special) == "table" then
        colors.background = wal.special.background
        colors.foreground = wal.special.foreground
        colors.cursor = wal.special.cursor
    end

    if type(wal.colors) == "table" then
        for key, value in pairs(wal.colors) do
            colors[key] = value
        end
    end

    return colors
end

function M.hypr_rgb(color)
    if type(color) ~= "string" then
        return nil
    end

    if color:match("^rgba?%(") then
        return color
    end

    local hex = color:match("^#?([%x][%x][%x][%x][%x][%x])$")

    if hex then
        return "rgb(" .. hex .. ")"
    end

    return color
end

function M.shell_quote(value)
    return "'" .. tostring(value):gsub("'", [["'"']]) .. "'"
end

function M.bind_exec(keys, cmd, opts)
    hl.bind(keys, hl.dsp.exec_cmd(cmd), opts)
end

return M
