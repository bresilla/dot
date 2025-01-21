-- File: ~/.config/nvim/lua/themes/lule_theme.lua

local lush = require('lush')
local hsl = lush.hsl

-- Helper function to check if a file exists
local function file_exists(file)
    local f = io.open(file, "rb")
    if f then f:close() end
    return f ~= nil
end

-- Helper function to read file into list
local function fileToList(file)
    local lines = {}
    if file_exists(file) then
        for line in io.lines(file) do
            lines[#lines + 1] = line
        end
    end
    return lines
end

-- Read theme preference
local themecolor = fileToList('/home/bresilla/.cache/lule/theme')[1] or "dark"

-- Read rainbow colors
local rainbow = fileToList('/home/bresilla/.cache/lule/colors')

-- Read additional rainbow colors
local rainbow_colors = {}
for i, color in ipairs(rainbow) do
    rainbow_colors["r" .. (i - 1)] = hsl(color)
end

-- Define the theme using lush
local theme = lush(function()
    return {
        -- Basic Groups
        Normal { fg = palette.fg, bg = palette.bg },
        NormalNC { fg = palette.fg_alt, bg = palette.bg_alt },
        Cursor { fg = rainbow_colors.r15, bg = rainbow_colors.r1 },
        Error { Undercurl = true, sp = palette.red }, -- Assuming 'sp' is the special color for undercurl

        -- -- Define more highlight groups based on your original `define_groups` function
        Folded { fg = palette.fg_special_mild, bg = palette.bg_special_mild, gui = "italic" },
        ErrorMsg { fg = palette.fg, bg = palette.red_intense_bg },
        Comment { fg = rainbow_colors.r8, gui = "italic" },
        Conceal { fg = palette.fg_special_warm, bg = palette.bg_dim, gui = "bold" },
        CursorLine { bg = rainbow_colors.r236, gui = "bold" },
        CursorColumn { bg = rainbow_colors.r236, gui = "bold" },
        Visual { bg = rainbow_colors.ac_d, gui = "bold" },

        -- -- Special Characters
        EndOfBuffer { fg = rainbow_colors.r0, bg = rainbow_colors.r0 },
        NonText { fg = rainbow_colors.r240 },
        Whitespace { fg = palette.fg, gui = "bold" },
        Define { fg = palette.fg },
        Delimiter { fg = palette.fg },
        Float { fg = palette.fg },
        Special { fg = palette.fg },
        SpecialComment { fg = palette.fg_alt },
        Title { fg = palette.fg_special_cold, gui = "bold" },

        -- -- Splits and Numbers
        VertSplit { fg = rainbow_colors.ac_d, bg = rainbow_colors.r0 },
        FoldColumn { bg = rainbow_colors.r0 },
        LineNr { fg = rainbow_colors.r1, bg = rainbow_colors.r0 },
        SignColumn { bg = rainbow_colors.r0 },
        CursorLineNr { fg = rainbow_colors.r1, bg = rainbow_colors.r0, gui = "bold" },

        -- -- Completion Menu
        Pmenu { fg = rainbow_colors.r15, bg = rainbow_colors.ac_d },
        PmenuSel { fg = rainbow_colors.r1, bg = rainbow_colors.r236, gui = "bold" },
        PmenuSbar { bg = rainbow_colors.r0 },
        PmenuThumb { bg = rainbow_colors.r0 },
        NormalFloat { fg = rainbow_colors.r15, bg = rainbow_colors.ac_d, gui = "bold" },

        -- -- Parentheses Matching
        MatchParen { fg = rainbow_colors.r0, bg = rainbow_colors.r1, gui = "bold" },
        Number { fg = palette.fg },
        Operator { fg = palette.fg },

        -- -- Nvim Tree
        NvimTreeNormal { bg = rainbow_colors.ac_d },
        NvimTreeEndOfBuffer { fg = rainbow_colors.ac_d, bg = rainbow_colors.ac_d },
        NvimTreeVertSplit { fg = rainbow_colors.ac_d, bg = rainbow_colors.ac_d },
        NvimTreeStatusLine { fg = rainbow_colors.ac_d, bg = rainbow_colors.ac_d },
        NvimTreeCursorLine { bg = rainbow_colors.r0, gui = "bold" },

        -- -- Indentations
        IndentLine { fg = rainbow_colors.ac_d },
        IndentOdd { fg = rainbow_colors.ac_d, bg = rainbow_colors.r0 },
        IndentEven { fg = rainbow_colors.ac_d, bg = rainbow_colors.r236 },

        -- -- Tabs
        TabLine { fg = palette.fg_dim, bg = palette.fg_inactive },
        TabLineSel { fg = palette.fg, bg = palette.bg_alt },
        TabLineFill { fg = rainbow_colors.r1, bg = rainbow_colors.ac_d },
        BufferCurrent { fg = rainbow_colors.r1, bg = rainbow_colors.r0, gui = "bold" },
        BufferCurrentMod { fg = rainbow_colors.r1, bg = rainbow_colors.r0 },
        BufferCurrentSign { fg = rainbow_colors.r0, bg = rainbow_colors.r0 },
        BufferCurrentTarget { fg = rainbow_colors.r15, bg = rainbow_colors.r0 },
        BufferVisible { fg = rainbow_colors.r15, bg = rainbow_colors.r236, gui = "bold" },
        BufferVisibleMod { fg = rainbow_colors.r0, bg = rainbow_colors.r236 },
        BufferVisibleSign { fg = rainbow_colors.r0, bg = rainbow_colors.r236 },
        BufferVisibleTarget { fg = rainbow_colors.r0, bg = rainbow_colors.r236 },
        BufferInactive { fg = rainbow_colors.r15, bg = rainbow_colors.ac_d },
        BufferInactiveMod { fg = rainbow_colors.r0, bg = rainbow_colors.ac_d },
        BufferInactiveSign { fg = rainbow_colors.r0, bg = rainbow_colors.ac_d },
        BufferInactiveTarget { fg = rainbow_colors.r0, bg = rainbow_colors.ac_d },
        BufferTabpages { fg = rainbow_colors.r15, bg = rainbow_colors.ac_d },
        BufferTabpageFill { fg = rainbow_colors.r0, bg = rainbow_colors.ac_d },

        -- -- Status Line
        StatusLine { fg = rainbow_colors.ac_l, bg = rainbow_colors.ac_d },
        StatusLineNC { fg = rainbow_colors.r0, bg = rainbow_colors.ac_d },
        ElNormal { fg = rainbow_colors.r1, bg = rainbow_colors.r0, gui = "bold" },
        ElInsert { fg = rainbow_colors.r0, bg = rainbow_colors.r1, gui = "bold" },
        ElFileType { fg = rainbow_colors.r1, bg = rainbow_colors.ac_d, gui = "bold" },

        -- -- Diagnostics
        LspDiagnosticsVirtualTextSpace { fg = rainbow_colors.r232, bg = rainbow_colors.r0, gui = "italic" },
        LspDiagnosticsVirtualTextError { fg = rainbow_colors.Redish, bg = rainbow_colors.r232, gui = "italic" },
        LspDiagnosticsSignError { fg = rainbow_colors.Redish, bg = rainbow_colors.r0, gui = "bold" },
        LspDiagnosticsFloatingError { fg = rainbow_colors.Redish },
        -- -- Continue defining all diagnostic groups...

        -- -- Search
        Search { fg = rainbow_colors.r0, bg = rainbow_colors.r1 },
        HlSearchCur { fg = rainbow_colors.r0, bg = rainbow_colors.r1 },
        HlSearchLensCur { fg = rainbow_colors.r0, bg = rainbow_colors.ac_d },
        HlSearchLens { fg = rainbow_colors.r0, bg = rainbow_colors.ac_d },
        CursorWord { fg = rainbow_colors.ac_l, bg = rainbow_colors.ac_d },
        CursorJump { fg = rainbow_colors.ac_d, bg = rainbow_colors.ac_l },

        -- -- Git & GitSigns
        DiffAdd { fg = palette.green, bg = rainbow_colors.r0 },
        DiffChange { fg = palette.yellow, bg = rainbow_colors.r0 },
        DiffDelete { fg = palette.red, bg = rainbow_colors.r0 },
        DiffText { fg = palette.blue, bg = rainbow_colors.r0 },
        GitSignsAdd { fg = palette.green, bg = rainbow_colors.r0 },
        GitSignsChange { fg = palette.yellow, bg = rainbow_colors.r0 },
        GitSignsDelete { fg = palette.red, bg = rainbow_colors.r0 },
        GitSignsChangeDelete { fg = palette.blue, bg = rainbow_colors.r0 },
        GitBlameVirt { fg = rainbow_colors.r0, bg = rainbow_colors.ac_d, gui = "italic,bold" },

        -- -- Multiple Cursors
        VM_Mono { fg = rainbow_colors.r0, bg = rainbow_colors.r1, gui = "reverse" },
        VM_Extend { fg = rainbow_colors.r0, bg = rainbow_colors.r1, gui = "reverse" },
        VM_Cursor { fg = rainbow_colors.r0, bg = rainbow_colors.r1, gui = "reverse" },
        VM_Insert { fg = rainbow_colors.r0, bg = rainbow_colors.r1, gui = "reverse" },

        -- -- Floating Term
        FloatermBorder { fg = rainbow_colors.r1, bg = rainbow_colors.r0 },
        Floaterm { bg = rainbow_colors.r0 },

        -- -- Telescope
        TelescopeBorder { fg = rainbow_colors.r1 },

        -- -- Nvim Lua Tree
        Directory { fg = rainbow_colors.r1 },
        FolderIcon { fg = rainbow_colors.r1 },

        -- -- Dashboard
        DashboardHeader { fg = rainbow_colors.r1 },
        DashboardCenter { fg = rainbow_colors.ac_l },
        DashboardFooter { fg = rainbow_colors.r1 },

        -- -- Completion
        CmpItemKindText { fg = rainbow_colors.r0, bg = palette.yellow },
        CmpItemKindMethod { fg = rainbow_colors.r0, bg = palette.blue },
        -- -- Continue defining all completion item kinds...

        -- -- Syntax
        -- Function { fg = palette.magenta_faint },
        -- Warning { fg = palette.yellow_alt_faint },
        -- Boolean { fg = palette.blue_faint, gui = "bold" },
        -- Character { fg = palette.blue_alt_faint },
        -- Conditional { fg = palette.magenta_alt_other_faint },
        -- Constant { fg = palette.blue_alt_other_faint },
        -- Directory { fg = palette.blue_faint },
        -- Exception { fg = palette.magenta_alt_other_faint },
        -- Identifier { fg = palette.blue_alt_other_faint },
        -- Include { fg = palette.red_alt_other_faint },
        -- Keyword { fg = palette.magenta_alt_other_faint },
        -- Label { fg = palette.cyan_faint },
        -- PreProc { fg = palette.red_alt_other_faint },
        -- Repeat { fg = palette.magenta_alt_other_faint },
        -- SpecialChar { fg = palette.blue_alt_other_faint },
        -- Statement { fg = palette.magenta_alt_other_faint },
        -- StorageClass { fg = palette.magenta_alt_other_faint },
        -- String { fg = palette.blue_alt_faint },
        -- Structure { fg = palette.magenta_alt_other_faint },
        -- Tag { fg = palette.magenta_active },
        -- Todo { fg = palette.magenta_faint, gui = "bold" },
        -- Type { fg = palette.magenta_alt_faint },
        -- Typedef { fg = palette.magenta_alt_faint },
        -- Underlined { gui = "underline", fg = palette.none, bg = palette.blue_nuanced_bg },

        -- -- Treesitter
        -- TSError { fg = palette.Error, gui = "bold" },
        -- TSPunctDelimiter { fg = palette.fg, bg = palette.bg },
        -- TSPunctBracket { fg = palette.fg, bg = palette.bg },
        -- TSConstant { fg = palette.Constant },
        -- TSConstBuiltin { fg = palette.Constant },
        -- TSConstMacro { fg = palette.Constant },
        -- TSString { fg = palette.String },
        -- TSStringRegex { fg = palette.red_refine_fg },
        -- TSStringEscape { fg = palette.yellow_active },
        -- TSCharacter { fg = palette.Character },
        -- TSNumber { fg = palette.Number },
        -- TSBoolean { fg = rainbow_colors.r1 },
        -- TSFloat { fg = palette.Number },
        -- TSFunction { fg = palette.Function },
        -- TSFuncBuiltin { fg = palette.Function },
        -- TSFuncMacro { fg = palette.Function },
        -- TSParameter { fg = palette.cyan_faint },
        -- TSConstructor { fg = palette.magenta_alt_faint },
        -- TSKeywordFunction { fg = palette.magenta_alt_faint },
        -- TSLiteral { fg = palette.blue_alt_faint, gui = "bold" },
        -- TSVariable { fg = palette.cyan_faint },
        -- TSVariableBuiltin { fg = palette.magenta_alt_other_faint },
        -- TSParameterReference { fg = palette.TSParameter },
        -- TSMethod { fg = palette.Function },
        -- TSConditional { fg = palette.Conditional },
        -- TSRepeat { fg = palette.Repeat },
        -- TSLabel { fg = palette.Label },
        -- TSOperator { fg = palette.Operator },
        -- TSKeyword { fg = palette.Keyword },
        -- TSException { fg = palette.Exception },
        -- TSType { fg = palette.Type },
        -- TSTypeBuiltin { fg = palette.Type },
        -- TSStructure { fg = palette.Structure },
        -- TSInclude { fg = palette.Include },
        -- TSAnnotation { fg = palette.blue_nuanced_bg },
        -- TSTitle { fg = palette.cyan_nuanced },

        -- -- Spelling
        -- SpellBad { fg = palette.Red },
        -- SpellCap { fg = palette.Red },
    }
end)

return theme

