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

    -- Color definitions
    local grey0 = hsl("#323437")
    local grey1 = hsl("#373c4d")
    local grey89 = hsl("#e4e4e4")
    local grey70 = hsl("#b2b2b2")
    local grey62 = hsl("#9e9e9e")
    local grey58 = hsl("#949494")
    local grey50 = hsl("#808080")
    local grey39 = hsl("#626262")
    local grey30 = hsl("#4e4e4e")
    local grey27 = hsl("#444444")
    local grey23 = hsl("#3a3a3a")
    local grey18 = hsl("#2e2e2e")
    local grey15 = hsl("#262626")
    local grey11 = hsl("#1c1c1c")
    local grey7 = hsl("#121212")

    local khaki = hsl("#c6c684")
    local yellow = hsl("#e3c78a")
    local orange = hsl("#de935f")
    local coral = hsl("#f09479")
    local orchid = hsl("#e196a2")
    local lime = hsl("#85dc85")
    local green = hsl("#8cc85f")
    local emerald = hsl("#36c692")
    local turquoise = hsl("#79dac8")
    local blue = hsl("#80a0ff")
    local sky = hsl("#74b2ff")
    local lavender = hsl("#adadf3")
    local purple = hsl("#ae81ff")
    local violet = hsl("#cf87e8")
    local cranberry = hsl("#e65e72")
    local crimson = hsl("#ff5189")
    local red = hsl("#ff5454")


    local highlights = lush(function()
        return {
            Normal { bg = c.r0 },
            NonText { fg = c.r240 },
            Cursor { bg = c.r1, fg = c.r15 , gui = "bold" },
            iCursor { bg = c.r1, fg = c.r15 , gui = "bold" },
            rCursor { bg = c.r1, fg = c.r15 , gui = "bold" },
            CursorLine { bg = c.r236 },
            CursorColumn { bg = c.r236 },
            Visual { bg = c.r237 },
            Conceal { fg = c.r240 },
            LineNr { fg = c.r237 },
            Comment  { fg = c.r238, gui = "italic" },
            CursorLineNR { fg = c.r246, gui = "bold" },
            NormalFloat { bg = c.r237 },
            Whitespace { fg = c.r240 },

            -- General highlights
            MoonflyVisual { bg = grey0 },
            MoonflyWhite { fg = grey89 },
            MoonflyGrey0 { fg = grey0 },
            MoonflyGrey89 { fg = grey89 },
            MoonflyGrey70 { fg = grey70 },
            MoonflyGrey62 { fg = grey62 },
            MoonflyGrey58 { fg = grey58 },
            MoonflyGrey39 { fg = grey39 },
            MoonflyGrey30 { fg = grey30 },
            MoonflyGrey27 { fg = grey27 },
            MoonflyGrey23 { fg = grey23 },
            MoonflyGrey18 { fg = grey18 },
            MoonflyGrey15 { fg = grey15 },

            -- Core theme colors
            MoonflyKhaki { fg = khaki },
            MoonflyYellow { fg = yellow },
            MoonflyOrange { fg = orange },
            MoonflyCoral { fg = coral },
            MoonflyOrchid { fg = orchid },
            MoonflyLime { fg = lime },
            MoonflyGreen { fg = green },
            MoonflyEmerald { fg = emerald },
            MoonflyTurquoise { fg = turquoise },
            MoonflyBlue { fg = blue },
            MoonflySky { fg = sky },
            MoonflyLavender { fg = lavender },
            MoonflyPurple { fg = purple },
            MoonflyViolet { fg = violet },
            MoonflyCranberry { fg = cranberry },
            MoonflyCrimson { fg = crimson },
            MoonflyRed { fg = red },

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
            Character      { MoonflyPurple },

            Constant       { MoonflyOrange },
            Number         { fg = hsl("#8eafff") }, -- a number constant: 234, 0xff
            Boolean        { MoonflyCranberry },
            Float          { fg = hsl("#8eafff") }, -- a floating point constant: 2.3e10

            Identifier     { MoonflyTurquoise },
            Function       { MoonflySky },
            Title          { fg = orange },

            Statement      { fg = hsl("#cdacfc") }, -- (preferred) any statement
            Conditional    { fg = hsl("#ffcbfb") }, -- if, then, else, endif, switch, etc.
            Repeat         { MoonflyViolet },
            Label          { MoonflyTurquoise },
            Operator       { MoonflyCranberry },
            Keyword        { fg = hsl("#ffcbfb") }, -- any other keyword
            Exception      { MoonflyCrimson },

            PreProc        { MoonflyCranberry },
            Include        { fg = hsl("#ffcbfb") }, -- preprocessor #include
            Define         { fg = hsl("#ffcbfb") }, -- preprocessor #define
            Macro          { fg = hsl("#ffcbfb") }, -- same as Define
            PreCondit      { fg = hsl("#ffcbfb") }, -- preprocessor #if, #else, #endif, etc.

            Type           { fg = emerald },
            StorageClass   { MoonflyViolet },
            Structure      { fg = hsl("#f4af6f") }, -- struct, union, enum, etc.
            Typedef        { fg = hsl("#f4af6f") }, -- A typedef

            Special        { fg = hsl("#eeef9f") }, -- (preferred) any special symbol
            SpecialComment { fg = hsl("#eeef9f") }, -- special things inside a comment
            Tag            { fg = hsl("#eeef9f") }, -- you can use CTRL-] on this
            Delimiter      { fg = hsl("#eeef9f") }, -- character that needs attention
            Debug          { fg = hsl("#eeef9f") }, -- debugging statements




            -- Neovim Tree-sitter
            sym"@attribute" { MoonflySky },
            sym"@comment.error" { MoonflyRed },
            sym"@comment.note" { MoonflyGrey58 },
            sym"@comment.ok" { MoonflyGreen },
            sym"@comment.todo" { Todo },
            sym"@comment.warning" { MoonflyYellow },
            sym"@constant" { MoonflyTurquoise },
            sym"@constant.builtin" { MoonflyGreen },
            sym"@constant.macro" { MoonflyViolet },
            sym"@constructor" { MoonflyEmerald },
            sym"@diff.delta" { DiffChange },
            sym"@diff.minus" { DiffDelete },
            sym"@diff.plus" { DiffAdd },
            sym"@function.builtin" { Function },
            sym"@function.call" { Function },
            sym"@function.macro" { MoonflyTurquoise },
            sym"@function.method" { Function },
            sym"@function.method.call" { Function },
            sym"@keyword.conditional" { Conditional },
            sym"@keyword.directive" { PreProc },
            sym"@keyword.directive.define" { Define },
            sym"@keyword.exception" { MoonflyViolet },
            sym"@keyword.import" { Include },
            sym"@keyword.operator" { MoonflyViolet },
            sym"@keyword.repeat" { Repeat },
            sym"@keyword.storage" { StorageClass },
            sym"@markup.environment" { MoonflyViolet },
            sym"@markup.environment.name" { MoonflyEmerald },
            sym"@markup.heading" { MoonflyViolet },
            sym"@markup.italic" { fg = orchid, italic = true },
            sym"@markup.link" { MoonflyGreen },
            sym"@markup.link.label" { MoonflyGreen },
            sym"@markup.link.url" { fg = purple, underline = true, sp = grey50 },
            sym"@markup.list" { MoonflyCranberry },
            sym"@markup.list.checked" { MoonflyTurquoise },
            sym"@markup.list.unchecked" { MoonflyBlue },
            sym"@markup.math" { MoonflySky },
            sym"@markup.quote" { MoonflyGrey58 },
            sym"@markup.raw" { String },
            sym"@markup.strikethrough" { strikethrough = true },
            sym"@markup.strong" { MoonflyOrchid },
            sym"@markup.underline" { underline = true },
            sym"@module" { MoonflyTurquoise },
            sym"@module.builtin" { MoonflyGreen },
            sym"@none" {},
            sym"@parameter.builtin" { MoonflyOrchid },
            sym"@property" { MoonflyLavender },
            sym"@string.documentation" { MoonflyTurquoise },
            sym"@string.regexp" { MoonflyTurquoise },
            sym"@string.special.path" { MoonflyOrchid },
            sym"@string.special.symbol" { MoonflyPurple },
            sym"@string.special.url" { MoonflyPurple },
            sym"@tag" { MoonflyBlue },
            sym"@tag.attribute" { MoonflyTurquoise },
            sym"@tag.builtin" { MoonflyBlue },
            sym"@tag.delimiter" { MoonflyGreen },
            sym"@type.builtin" { MoonflyEmerald },
            sym"@type.qualifier" { MoonflyViolet },
            sym"@variable" { MoonflyWhite },
            sym"@variable.builtin" { MoonflyGreen },
            sym"@variable.member" { MoonflyLavender },
            sym"@variable.parameter" { MoonflyOrchid },
        
            -- Neovim LSP semantic highlights
            sym"@lsp.type.boolean" { sym"@boolean" },
            sym"@lsp.type.builtinConstant" { sym"@constant.builtin" },
            sym"@lsp.type.builtinType" { sym"@type.builtin" },
            sym"@lsp.type.class" { sym"@type" },
            sym"@lsp.type.enum" { sym"@type" },
            sym"@lsp.type.enumMember" { sym"@constant" },
            sym"@lsp.type.escapeSequence" { sym"@string.escape" },
            sym"@lsp.type.formatSpecifier" { sym"@punctuation.special" },
            sym"@lsp.type.generic" { sym"@variable" },
            sym"@lsp.type.interface" { sym"@type" },
            sym"@lsp.type.keyword" { sym"@keyword" },
            sym"@lsp.type.lifetime" { sym"@storageclass" },
            sym"@lsp.type.namespace" { sym"@module" },
            sym"@lsp.type.number" { sym"@number" },
            sym"@lsp.type.parameter" { sym"@parameter" },
            sym"@lsp.type.property" { sym"@property" },
            sym"@lsp.type.selfKeyword" { sym"@variable.builtin" },
            sym"@lsp.type.selfParameter" { sym"@variable.builtin" },
            sym"@lsp.type.string" { sym"@string" },
            sym"@lsp.type.struct" { sym"@type" },
            sym"@lsp.type.typeAlias" { sym"@type.definition" },
            sym"@lsp.type.unresolvedReference" { underline = true, sp = red },
            sym"@lsp.type.variable" { sym"@variable" },
        
            -- Additional LSP modifications
            sym"@lsp.typemod.class.defaultLibrary" { sym"@type" },
            sym"@lsp.typemod.enum.defaultLibrary" { sym"@type" },
            sym"@lsp.typemod.function.defaultLibrary" { sym"@function" },
            sym"@lsp.typemod.keyword.async" { sym"@keyword" },
            sym"@lsp.typemod.keyword.injected" { sym"@keyword" },
            sym"@lsp.typemod.variable.static" { sym"@constant" },
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
