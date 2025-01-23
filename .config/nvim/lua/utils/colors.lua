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

    ac_d = c.r237
    ac_l = c.r251

    local highlights = lush(function()
        return {
            -- Normal { bg = dark and c.r0.lighten(10) or c.r0.darken(10), fg = c.r15 },
            Normal { },

            ------- BARBAR -------
            BufferDefaultCurrent { bg = c.r0, fg = c.r1, gui = "bold" },
            BufferDefaultCurrentSign { bg = c.r0, fg = c.r1.saturate(10) },
            BufferDefaultCurrentSignRight { bg = c.r0, fg = c.r1.saturate(10) },
            BufferDefaultInactive {  bg = c.r237 },
            BufferDefaultInactiveSign { bg = c.r237, fg = c.r0 },
            BufferDefaultInactiveSignRight { bg = c.r237, fg = c.r0 },
            BufferDefaultVisible { bg = c.r237 },
            BufferDefaultVisibleSign { bg = c.r237 , fg = c.r0 },
            BufferDefaultVisibleSignRight { bg = c.r237, fg = c.r0 },
            BufferTabpageFill { bg = c.r237 },
            BufferTabpagesSep { bg = c.r237 },


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
            NvimTreeNormal { bg = c.r237 },
            NvimTreeCursorLine { bg = c.r0 },
            WinSeparator { fg = c.r0 },


            ------- STATUS-LINE -------
            StatusLine { bg = c.r237, fg = c.r1 },
            StatusLineNC { bg = c.r0, fg = c.r1 },
            ElNormal { bg = c.r1, fg = c.r0, gui = "bold" },
            ElNormal2 { bg = c.r0, fg = c.r1, gui = "bold" },
            ElInsert { bg = c.r0, fg = c.r1, gui = "bold" },
            ElFileType { bg = c.r1, fg = c.r0, gui = "bold" },

            ------- INDENTATIONS -------
            IndentLine { bg = c.r237 },
            IndentOdd { bg = c.r237, fg = c.r0 },
            IndentEven { bg = c.r237, fg = c.r236 },

            ------- SEARCH -------
            Search { bg = c.r1, fg = c.r0 },
            HlSearchCur { bg = c.r1, fg = c.r0 },
            HlSearchLensCur { bg = c.r0, fg = c.r1 },
            HlSearchLens { bg = c.r0, fg = c.r1 },
            CursorWord { bg = c.r1, fg = c.r0 },
            CursorJump { bg = c.r0, fg = c.r1 },


            ------- TELESCOPE -------
            TelescopeBorder { fg = c.r1 },

            -------- COMPLETION MENU -------
            Pmenu { bg = c.r0, fg = c.r15 },
            PmenuSel { bg = c.r237, fg = c.r1, gui = "bold" },
            PmenuSbar { bg = c.r237 },
            PmenuThumb { bg = c.r237 },
            NormalFloat { bg = c.r0, fg = c.r15, gui = "bold" },



            ------- SYNTAX -------
            Constant       { fg = hsl("#de8ff6") }, -- (preferred) any constant
            String         { fg = c.r1 }, --   a string constant: "this is a string"
            Character      { String }, --  a character constant: 'c', '\n'
            Number         { fg = hsl("#8eafff") }, --   a number constant: 234, 0xff
            Boolean        { Constant }, --  a boolean constant: TRUE, false
            Float          { Number }, --    a floating point constant: 2.3e10

            Identifier     { fg = hsl("#eefeee") }, -- (preferred) any variable name
            Function       { fg = hsl("#a7aeff") }, -- function name (also: methods for classes)

            Statement      { fg = hsl("#cdacfc") }, -- (preferred) any statement
            -- Conditional    { }, --  if, then, else, endif, switch, etc.
            -- Repeat         { }, --   for, do, while, etc.
            -- Label          { }, --    case, default, etc.
            -- Operator       { }, -- "sizeof", "+", "*", etc.
            -- Keyword        { }, --  any other keyword
            -- Exception      { }, --  try, catch, throw

            PreProc        { fg = hsl("#ffcbfb") }, -- (preferred) generic Preprocessor
            -- Include        { }, --  preprocessor #include
            -- Define         { }, --   preprocessor #define
            -- Macro          { }, --    same as Define
            -- PreCondit      { }, --  preprocessor #if, #else, #endif, etc.

            Type           { fg = hsl("#f4af6f") }, -- (preferred) int, long, char, etc.
            -- StorageClass   { }, -- static, register, volatile, etc.
            -- Structure      { }, --  struct, union, enum, etc.
            -- Typedef        { }, --  A typedef

            Special        { fg = hsl("#eeef9f") }, -- (preferred) any special symbol
            -- SpecialChar    { }, --  special character in a constant
            -- Tag            { }, --    you can use CTRL-] on this
            -- Delimiter      { }, --  character that needs attention
            -- SpecialComment { }, -- special things inside a comment
            -- Debug          { }, --    debugging statements


        }
    end)
    lush.apply(highlights)
end

themecolor = fileToList('/home/bresilla/.cache/wal/theme')[1] or "dark"
mycolors(themecolor)
