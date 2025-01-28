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

    local dv = 80
    local lv = 80

    c["error"] = c.r172
    c["error_light"] = c.r176
    c["error_dark"] = c.r161

    c["ok"] = c.r196
    c["ok_light"] = c.r200
    c["ok_dark"] = c.r185

    c["warn"] = c.r220
    c["warn_light"] = c.r224
    c["warn_dark"] = c.r209

    c["info"] = c.r244
    c["info_light"] = c.r248
    c["info_dark"] = c.r233

    c["hint"] = c.r117
    c["hint_light"] = c.r119
    c["hint_dark"] = c.r113


    local highlights = lush(function()
        return {
            Normal { bg = c.r0 },
            NonText { fg = c.r240 },
            Cursor { bg = c.r1, fg = c.r15 , gui = "bold" },
            CursorLine { bg = c.r236 },
            CursorColumn { bg = c.r236 },
            Visual { bg = c.r237 },
            Conceal { fg = c.r240 },
            LineNr { fg = c.r237 },
            Comment  { fg = c.r238, gui = "italic" },
            CursorLineNR { fg = c.r246, gui = "bold" },
            NormalFloat { bg = c.r237 },
            Whitespace { fg = c.r240 },

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

            ------- INDENTATION -------
            IndentLine { bg = c.r0, fg = c.r237 },
            IndentLineCurrent { bg = c.r0, fg = c.r240 },
            MiniIndentscopeSymbol { IndentLine },
            MiniIndentscopeSymbolOff { IndentLineCurrent },

            ------- SEARCH -------
            IlluminatedWordText { bg = c.r237, gui = "bold" },
            Search { bg = c.r238 },
            CurSearch { bg = c.r1, fg = c.r0 },
            IncSearch { bg = c.r0, fg = c.r1 },
            CursorWord { bg = c.r1, fg = c.r0 },
            CursorJump { bg = c.r0, fg = c.r1 },
            MatchParen { bg = c.r1, fg = c.r0 },

            ------- TELESCOPE -------
            TelescopeBorder { fg = c.r1 },
            NoiceCmdlinePopupBorder { fg = c.r1 },

            ------- TERMINAL --------
            ToggleTermNormal { bg = c.r236 },
            ToggleTermNormalFloat { bg = c.r236 },
            ToggleTermFloatBorder { bg = c.r236, fg = c.r236 },

            ------- DIAGNOSTICS -------
            DiagnosticError { fg = c.error_light,   bg = c.error_dark  },
            DiagnosticWarn  { fg =  c.warn_light,   bg =  c.warn_dark  },
            DiagnosticInfo  { fg =  c.info_light,   bg =  c.info_dark  },
            DiagnosticHint  { fg =  c.hint_light,   bg =  c.hint_dark  },
            DiagnosticOk    { fg =    c.ok_light,   bg =    c.ok_dark  },
            DiagnosticFloatingError { DiagnosticError },
            DiagnosticFloatingWarn  { DiagnosticWarn  },
            DiagnosticFloatingInfo  { DiagnosticInfo  },
            DiagnosticFloatingHint  { DiagnosticHint  },
            DiagnosticFloatingOk    { DiagnosticOk    },
            DiagnosticUnderlineError { bg = c.error_dark },
            DiagnosticUnderlineWarn  { bg =  c.warn_dark },
            DiagnosticUnderlineInfo  { bg =  c.info_dark },
            DiagnosticUnderlineHint  { bg =  c.hint_dark },
            DiagnosticUnderlineOk    { bg =    c.ok_dark },
            DiagnosticVirtualTextError  { DiagnosticError },
            DiagnosticVirtualTextWarn   { DiagnosticWarn  },
            DiagnosticVirtualTextInfo   { DiagnosticInfo  },
            DiagnosticVirtualTextHint   { DiagnosticHint  },
            DiagnosticVirtualTextOk     { DiagnosticOk    },
            DiagnosticSignError { DiagnosticError },
            DiagnosticSignWarn  { DiagnosticWarn  },
            DiagnosticSignInfo  { DiagnosticInfo  },
            DiagnosticSignHint  { DiagnosticHint  },
            DiagnosticSignOk    { DiagnosticOk    },
            DiagnosticUnnecessary { fg = c.r3 },

            -------- COMPLETION MENU -------
            Pmenu { bg = c.r237, fg = c.r15 },
            PmenuSel { bg = c.r1, fg = c.r0, gui = "bold" },
            PmenuSbar { bg = c.r237 },
            PmenuThumb { bg = c.r237 },
            BlinkCmpMenu { Pmenu },
            BlinkCmpMenuSelection { PmenuSel },
            BlinkCmpGhostText { fg = c.r240 },
            BlinkCmpDoc { bg = c.r236 },
            BlinkCmpDocSeparator { bg = c.r236, fg = c.r0, gui = "bold" },
            BlinkCmpLabelMatch { bg = c.r240, fg = c.r15, gui = "italic" },

            BlinkCmpKindSnippet         { gui = "bold", fg = c.r0, bg = c.r22  },
            BlinkCmpKindKeyword         { gui = "bold", fg = c.r0, bg = c.r34  },
            BlinkCmpKindText            { gui = "bold", fg = c.r0, bg = c.r46  },
            BlinkCmpKindMethod          { gui = "bold", fg = c.r0, bg = c.r58  },
            BlinkCmpKindConstructor     { gui = "bold", fg = c.r0, bg = c.r70  },
            BlinkCmpKindFunction        { gui = "bold", fg = c.r0, bg = c.r82  },
            BlinkCmpKindFolder          { gui = "bold", fg = c.r0, bg = c.r94  },
            BlinkCmpKindModule          { gui = "bold", fg = c.r0, bg = c.r106 },
            BlinkCmpKindConstant        { gui = "bold", fg = c.r0, bg = c.r118 },
            BlinkCmpKindField           { gui = "bold", fg = c.r0, bg = c.r130 },
            BlinkCmpKindProperty        { gui = "bold", fg = c.r0, bg = c.r142 },
            BlinkCmpKindEnum            { gui = "bold", fg = c.r0, bg = c.r154 },
            BlinkCmpKindUnit            { gui = "bold", fg = c.r0, bg = c.r166 },
            BlinkCmpKindClass           { gui = "bold", fg = c.r0, bg = c.r22  },
            BlinkCmpKindVariable        { gui = "bold", fg = c.r0, bg = c.r34  },
            BlinkCmpKindFile            { gui = "bold", fg = c.r0, bg = c.r46  },
            BlinkCmpKindInterface       { gui = "bold", fg = c.r0, bg = c.r58  },
            BlinkCmpKindColor           { gui = "bold", fg = c.r0, bg = c.r64  },
            BlinkCmpKindReference       { gui = "bold", fg = c.r0, bg = c.r82  },
            BlinkCmpKindEnumMember      { gui = "bold", fg = c.r0, bg = c.r94  },
            BlinkCmpKindStruct          { gui = "bold", fg = c.r0, bg = c.r106 },
            BlinkCmpKindValue           { gui = "bold", fg = c.r0, bg = c.r118 },
            BlinkCmpKindEvent           { gui = "bold", fg = c.r0, bg = c.r124 },
            BlinkCmpKindOperator        { gui = "bold", fg = c.r0, bg = c.r142 },
            BlinkCmpKindTypeParameter   { gui = "bold", fg = c.r0, bg = c.r154 },
            BlinkCmpKindCopilot         { gui = "bold", fg = c.r0, bg = c.r166 },


            ------- SYNTAX -------
            String         { fg = c.r1 }, -- a string constant: "this is a string"
            Character      { fg = c.r1 }, -- a character constant: 'c', '\n'

            Constant       { fg = hsl("#de8ff6") }, -- (preferred) any constant
            Number         { fg = hsl("#8eafff") }, -- a number constant: 234, 0xff
            Boolean        { fg = hsl("#8eafff") }, -- a boolean constant: TRUE, false
            Float          { fg = hsl("#8eafff") }, -- a floating point constant: 2.3e10

            Identifier     { fg = hsl("#eefeee") }, -- (preferred) any variable name
            Function       { fg = hsl("#a7aeff") }, -- function name (also: methods for classes)

            Statement      { fg = hsl("#cdacfc") }, -- (preferred) any statement
            Conditional    { fg = hsl("#ffcbfb") }, -- if, then, else, endif, switch, etc.
            Repeat         { fg = hsl("#ffcbfb") }, -- for, do, while, etc.
            Label          { fg = hsl("#ffcbfb") }, -- case, default, etc.
            Operator       { fg = hsl("#ffcbfb") }, -- "sizeof", "+", "*", etc.
            Keyword        { fg = hsl("#ffcbfb") }, -- any other keyword
            Exception      { fg = hsl("#ffcbfb") }, -- try, catch, throw

            PreProc        { fg = hsl("#ffcbfb") }, -- (preferred) generic Preprocessor
            Include        { fg = hsl("#ffcbfb") }, -- preprocessor #include
            Define         { fg = hsl("#ffcbfb") }, -- preprocessor #define
            Macro          { fg = hsl("#ffcbfb") }, -- same as Define
            PreCondit      { fg = hsl("#ffcbfb") }, -- preprocessor #if, #else, #endif, etc.

            Type           { fg = hsl("#f4af6f") }, -- (preferred) int, long, char, etc.
            StorageClass   { fg = hsl("#f4af6f") }, -- static, register, volatile, etc.
            Structure      { fg = hsl("#f4af6f") }, -- struct, union, enum, etc.
            Typedef        { fg = hsl("#f4af6f") }, -- A typedef

            Special        { fg = hsl("#eeef9f") }, -- (preferred) any special symbol
            SpecialComment { fg = hsl("#eeef9f") }, -- special things inside a comment
            Tag            { fg = hsl("#eeef9f") }, -- you can use CTRL-] on this
            Delimiter      { fg = hsl("#eeef9f") }, -- character that needs attention
            Debug          { fg = hsl("#eeef9f") }, -- debugging statements
        }
    end)
    lush.apply(highlights)
end

themecolor = fileToList('/home/bresilla/.cache/wal/theme')[1] or "dark"
mycolors(themecolor)

vim.keymap.set('n', '<leader>d', function() mycolors() end)

filepathtowatch = '/home/bresilla/.cache/lule/colors'

local watcher = require("utils.watcher")
local handle = watcher.watch_file(filepathtowatch, function(fname, status)
    themecolor = fileToList('/home/bresilla/.cache/wal/theme')[1] or "dark"
    mycolors(themecolor)
end)

--local timerr = require("utils.timerr")
--local thandle = timerr.run_every_2s(function()
--    themecolor = fileToList('/home/bresilla/.cache/wal/theme')[1] or "dark"
--    mycolors(themecolor)
--end)
