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


function mycolors(theme)
    -- Read rainbow colors
    local rainbow = fileToList('/home/bresilla/.cache/lule/colors')
    local dark = (theme == "dark")

    -- Read additional rainbow colors
    local c = {}
    for i, color in ipairs(rainbow) do
        c["r" .. (i - 1)] = hsl(color)
    end

    local highlights = lush(function()
        return {
            -- Normal { bg = dark and c.r0.lighten(10) or c.r0.darken(10), fg = c.r15 },
            Normal { },

            ------- BARBAR -------
            BufferDefaultCurrent { bg = c.r0, fg = c.r1, gui = "bold" },
            BufferDefaultCurrentSign { bg = c.r0, fg = c.r1.saturate(10) },
            BufferDefaultCurrentSignRight { bg = c.r0, fg = c.r1.saturate(10) },
            BufferDefaultInactive {  bg = dark and c.r0.lighten(10) or c.r0.darken(10) },
            BufferDefaultInactiveSign { bg = BufferDefaultInactive.bg, fg = c.r0 },
            BufferDefaultInactiveSignRight { bg = BufferDefaultInactive.bg, fg = c.r0 },
            BufferDefaultVisible { bg = BufferDefaultInactive.bg },
            BufferDefaultVisibleSign { bg = BufferDefaultInactive.bg , fg = c.r0 },
            BufferDefaultVisibleSignRight { bg = BufferDefaultInactive.bg, fg = c.r0 },
            BufferTabpageFill { bg = BufferDefaultInactive.bg },
            BufferTabpagesSep { bg = BufferDefaultInactive.bg },


            ------- DASHBOARD -------
            DashboardHeader { bg = c.r0, fg = c.r1 },
            DashboardCenter { bg = c.r0, fg = c.r1 },
            DashboardFooter { bg = c.r0, fg = c.r1 },

            ------- LUALINE -------
            lualine_a_normal { bg = c.r1, fg = c.r1 },
            lualine_b_normal { bg = c.r1, fg = c.r1 },
            lualine_c_normal { bg = c.r1, fg = c.r1 },
            lualine_x_normal { bg = c.r1, fg = c.r1 },
            lualine_y_normal { bg = c.r1, fg = c.r1 },
            lualine_z_normal { bg = c.r1, fg = c.r1 },


            ------- NvimTree -------
            NvimTreeNormal { bg = BufferDefaultInactive.bg },
            NvimTreeCursorLine { bg = c.r0 },
            WinSeparator { fg = c.r0 },


            ------- STATUS-LINE -------
            StatusLine { bg = BufferDefaultInactive.bg, fg = c.r1 },
            StatusLineNC { bg = c.r0, fg = c.r1 },
            ElNormal { bg = c.r1, fg = c.r0, gui = "bold" },
            ElNormal2 { bg = c.r0, fg = c.r1, gui = "bold" },
            ElInsert { bg = c.r0, fg = c.r1, gui = "bold" },
            ElFileType { bg = c.r1, fg = c.r0, gui = "bold" },

        }
    end)
    lush.apply(highlights)
end

themecolor = fileToList('/home/bresilla/.cache/wal/theme')[1] or "dark"
mycolors(themecolor)
