local lush = require('lush')
local hsl = lush.hsl

-- Helper function to check if a file exists
function file_exists(file)
    local f = io.open(file, "rb")
    if f then f:close() end
    return f ~= nil
end

-- Helper function to read file into list
function fileToList(file)
    local lines = {}
    if file_exists(file) then
        for line in io.lines(file) do
            lines[#lines + 1] = line
        end
    end
    return lines
end

function darken_or_lighten(hls_color, theme)
    if theme == "dark" then
        return hls_color.lighten(10)
    else
        return hls_color.darken(10)
    end
end

function mycolors(theme)
    -- Read rainbow colors
    local rainbow = fileToList('/home/bresilla/.cache/lule/colors')
    local dark = theme == "dark"

    -- Read additional rainbow colors
    local c = {}
    for i, color in ipairs(rainbow) do
        c["r" .. (i - 1)] = hsl(color)
    end

    local highlights = lush(function()
        return {
            Normal { 
                bg = dark and c.r0.lighten(10) or c.r0.darken(10),
                fg = c.r15 
            },
        }
    end)

    lush.apply(highlights)

end

themecolor = fileToList('/home/bresilla/.cache/wal/theme')[1] or "dark"
mycolors(themecolor)
