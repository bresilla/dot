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
      table.insert(lines, line)
    end
  end
  return lines
end

-- Function to apply highlights using Neovim's API.
local function apply_highlights(highlights)
  for group, opts in pairs(highlights) do
    if opts.link then
      vim.cmd("highlight! link " .. group .. " " .. opts.link)
    else
      vim.api.nvim_set_hl(0, group, opts)
    end
  end
end

function mycolors(theme)
  -- Read rainbow colors from file
  local rainbow = fileToList('/home/bresilla/.cache/lule/colors')
  local dark = (theme == "dark")
  local c = {}
  for i, color in ipairs(rainbow) do
    c["r" .. (i - 1)] = color
  end

  -- Define additional color aliases
  c.error       = c.r172
  c.error_light = c.r176
  c.error_dark  = c.r161

  c.ok       = c.r196
  c.ok_light = c.r200
  c.ok_dark  = c.r185

  c.warn       = c.r220
  c.warn_light = c.r224
  c.warn_dark  = c.r209

  c.info       = c.r244
  c.info_light = c.r248
  c.info_dark  = c.r233

  c.hint       = c.r117
  c.hint_light = c.r119
  c.hint_dark  = c.r113

  -- Static color definitions (using hex values directly)
  local grey0   = "#323437"
  local grey1   = "#373c4d"
  local grey89  = "#e4e4e4"
  local grey70  = "#b2b2b2"
  local grey62  = "#9e9e9e"
  local grey58  = "#949494"
  local grey50  = "#808080"
  local grey39  = "#626262"
  local grey30  = "#4e4e4e"
  local grey27  = "#444444"
  local grey23  = "#3a3a3a"
  local grey18  = "#2e2e2e"
  local grey15  = "#262626"
  local grey11  = "#1c1c1c"
  local grey7   = "#121212"

  local khaki      = "#c6c684"
  local yellow     = "#e3c78a"
  local orange     = "#de935f"
  local coral      = "#f09479"
  local orchid     = "#e196a2"
  local lime       = "#85dc85"
  local green      = "#8cc85f"
  local emerald    = "#36c692"
  local turquoise  = "#79dac8"
  local blue       = "#80a0ff"
  local sky        = "#74b2ff"
  local lavender   = "#adadf3"
  local purple     = "#ae81ff"
  local violet     = "#cf87e8"
  local cranberry  = "#e65e72"
  local crimson    = "#ff5189"
  local red        = "#ff5454"

  -- Define highlight groups as a table.
  local highlights = {
    Normal = { ctermbg = 0 },
    NonText = { fg = c.r240 },
    Cursor = { bg = c.r1, fg = c.r15, bold = true },
    iCursor = { bg = c.r1, fg = c.r15, bold = true },
    rCursor = { bg = c.r1, fg = c.r15, bold = true },
    CursorLine = { bg = c.r236 },
    CursorColumn = { bg = c.r236 },
    Visual = { bg = c.r237 },
    Conceal = { fg = c.r240 },
    LineNr = { fg = c.r237 },
    Comment  = { fg = c.r238, italic = true },
    CursorLineNR = { fg = c.r246, bold = true },
    NormalFloat = { bg = c.r237 },
    Whitespace = { fg = c.r240 },

    -- BARBAR
    BufferDefaultCurrent = { bg = c.r0, fg = c.r1, bold = true },
    BufferDefaultCurrentSign = { bg = c.r0, fg = c.r1 },
    BufferDefaultCurrentSignRight = { bg = c.r0, fg = c.r1 },
    BufferDefaultInactive = { bg = c.r237 },
    BufferDefaultInactiveSign = { bg = c.r237, fg = c.r0 },
    BufferDefaultInactiveSignRight = { bg = c.r237, fg = c.r0 },
    BufferDefaultVisible = { bg = c.r237 },
    BufferDefaultVisibleSign = { bg = c.r237, fg = c.r0 },
    BufferDefaultVisibleSignRight = { bg = c.r237, fg = c.r0 },
    BufferTabpageFill = { bg = c.r237 },
    BufferTabpagesSep = { bg = c.r237 },

    -- Scrollbar
    ScrollbarHandle = { bg = c.r236 },
    ScrollbarSearch = { fg = c.r1 },
    ScrollbarSearchHandle = { bg = c.r236, fg = c.r1 },

    -- ChatGPT
    ChatGPTSelectedMessage = { bg = c.r236 },

    -- DASHBOARD
    DashboardHeader = { bg = c.r0, fg = c.r1 },
    DashboardCenter = { bg = c.r0, fg = c.r1 },
    DashboardFooter = { bg = c.r0, fg = c.r1 },

    -- NvimTree
    NvimTreeNormal = { bg = c.r237 },
    NvimTreeCursorLine = { bg = c.r0 },
    WinSeparator = { fg = c.r236 },

    -- STATUS-LINE
    StatusLine = { bg = c.r237, fg = c.r1 },
    StatusLineNC = { bg = c.r0, fg = c.r1 },
    ElNormal = { bg = c.r1, fg = c.r0, bold = true },
    ElNormal2 = { bg = c.r0, fg = c.r1, bold = true },
    ElInsert = { bg = c.r0, fg = c.r1, bold = true },
    ElFileType = { bg = c.r1, fg = c.r0, bold = true },

    -- INDENTATION
    IndentLine = { bg = c.r0, fg = c.r237 },
    IndentLineCurrent = { bg = c.r0, fg = c.r240 },
    MiniIndentscopeSymbol = { fg = c.r0, bg = c.r237 },  -- inlined from IndentLine
    MiniIndentscopeSymbolOff = { fg = c.r0, bg = c.r240 },  -- inlined from IndentLineCurrent

    -- SEARCH
    IlluminatedWordText = { bg = c.r237, bold = true },
    Search = { bg = c.r238 },
    CurSearch = { bg = c.r1, fg = c.r0 },
    IncSearch = { bg = c.r0, fg = c.r1 },
    CursorWord = { bg = c.r1, fg = c.r0 },
    CursorJump = { bg = c.r0, fg = c.r1 },
    MatchParen = { bg = c.r1, fg = c.r0 },

    -- TELESCOPE
    TelescopeBorder = { fg = c.r1 },
    NoiceCmdlinePopupBorder = { fg = c.r1 },

    -- TERMINAL
    ToggleTermNormal = { bg = c.r236 },
    ToggleTermNormalFloat = { bg = c.r236 },
    ToggleTermFloatBorder = { bg = c.r236, fg = c.r236 },

    -- DIAGNOSTICS
    DiagnosticError = { fg = c.error_light, bg = c.error_dark },
    DiagnosticWarn = { fg = c.warn_light,  bg = c.warn_dark },
    DiagnosticInfo = { fg = c.info_light,  bg = c.info_dark },
    DiagnosticHint = { fg = c.hint_light,  bg = c.hint_dark },
    DiagnosticOk = { fg = c.ok_light,    bg = c.ok_dark },
    DiagnosticFloatingError = { fg = c.error_light, bg = c.error_dark },
    DiagnosticFloatingWarn = { fg = c.warn_light,  bg = c.warn_dark },
    DiagnosticFloatingInfo = { fg = c.info_light,  bg = c.info_dark },
    DiagnosticFloatingHint = { fg = c.hint_light,  bg = c.hint_dark },
    DiagnosticFloatingOk = { fg = c.ok_light,    bg = c.ok_dark },
    DiagnosticUnderlineError = { bg = c.error_dark },
    DiagnosticUnderlineWarn = { bg = c.warn_dark },
    DiagnosticUnderlineInfo = { bg = c.info_dark },
    DiagnosticUnderlineHint = { bg = c.hint_dark },
    DiagnosticUnderlineOk = { bg = c.ok_dark },
    DiagnosticVirtualTextError = { fg = c.error_light, bg = c.error_dark },
    DiagnosticVirtualTextWarn = { fg = c.warn_light,  bg = c.warn_dark },
    DiagnosticVirtualTextInfo = { fg = c.info_light,  bg = c.info_dark },
    DiagnosticVirtualTextHint = { fg = c.hint_light,  bg = c.hint_dark },
    DiagnosticVirtualTextOk = { fg = c.ok_light,    bg = c.ok_dark },
    DiagnosticSignError = { fg = c.error_light, bg = c.error_dark },
    DiagnosticSignWarn = { fg = c.warn_light,  bg = c.warn_dark },
    DiagnosticSignInfo = { fg = c.info_light,  bg = c.info_dark },
    DiagnosticSignHint = { fg = c.hint_light,  bg = c.hint_dark },
    DiagnosticSignOk = { fg = c.ok_light,    bg = c.ok_dark },
    DiagnosticUnnecessary = { fg = c.r3 },

    -- COMPLETION MENU
    Pmenu = { bg = c.r237, fg = c.r15 },
    PmenuSel = { bg = c.r1, fg = c.r0, bold = true },
    PmenuSbar = { bg = c.r237 },
    PmenuThumb = { bg = c.r237 },
    BlinkCmpMenu = { fg = c.r15, bg = c.r237 },  -- inlined from Pmenu
    BlinkCmpMenuSelection = { fg = c.r0, bg = c.r1, bold = true },  -- inlined from PmenuSel
    BlinkCmpGhostText = { fg = c.r240 },
    BlinkCmpDoc = { bg = c.r236 },
    BlinkCmpDocSeparator = { bg = c.r236, fg = c.r0, bold = true },
    BlinkCmpLabelMatch = { fg = c.r15, bg = c.r240, italic = true },

    BlinkCmpKindSnippet = { bold = true, fg = c.r0, bg = c.r22 },
    BlinkCmpKindKeyword = { bold = true, fg = c.r0, bg = c.r34 },
    BlinkCmpKindText = { bold = true, fg = c.r0, bg = c.r46 },
    BlinkCmpKindMethod = { bold = true, fg = c.r0, bg = c.r58 },
    BlinkCmpKindConstructor = { bold = true, fg = c.r0, bg = c.r70 },
    BlinkCmpKindFunction = { bold = true, fg = c.r0, bg = c.r82 },
    BlinkCmpKindFolder = { bold = true, fg = c.r0, bg = c.r94 },
    BlinkCmpKindModule = { bold = true, fg = c.r0, bg = c.r106 },
    BlinkCmpKindConstant = { bold = true, fg = c.r0, bg = c.r118 },
    BlinkCmpKindField = { bold = true, fg = c.r0, bg = c.r130 },
    BlinkCmpKindProperty = { bold = true, fg = c.r0, bg = c.r142 },
    BlinkCmpKindEnum = { bold = true, fg = c.r0, bg = c.r154 },
    BlinkCmpKindUnit = { bold = true, fg = c.r0, bg = c.r166 },
    BlinkCmpKindClass = { bold = true, fg = c.r0, bg = c.r22 },
    BlinkCmpKindVariable = { bold = true, fg = c.r0, bg = c.r34 },
    BlinkCmpKindFile = { bold = true, fg = c.r0, bg = c.r46 },
    BlinkCmpKindInterface = { bold = true, fg = c.r0, bg = c.r58 },
    BlinkCmpKindColor = { bold = true, fg = c.r0, bg = c.r64 },
    BlinkCmpKindReference = { bold = true, fg = c.r0, bg = c.r82 },
    BlinkCmpKindEnumMember = { bold = true, fg = c.r0, bg = c.r94 },
    BlinkCmpKindStruct = { bold = true, fg = c.r0, bg = c.r106 },
    BlinkCmpKindValue = { bold = true, fg = c.r0, bg = c.r118 },
    BlinkCmpKindEvent = { bold = true, fg = c.r0, bg = c.r124 },
    BlinkCmpKindOperator = { bold = true, fg = c.r0, bg = c.r142 },
    BlinkCmpKindTypeParameter = { bold = true, fg = c.r0, bg = c.r154 },
    BlinkCmpKindCopilot = { bold = true, fg = c.r0, bg = c.r166 },

    -- SYNTAX
    String = { fg = c.r1 },
    Character = { fg = purple },
    Constant = { fg = orange },
    Number = { fg = "#8eafff" },
    Boolean = { fg = cranberry },
    Float = { fg = "#8eafff" },
    FloatBorder = { bg = c.r0, fg = c.r1 },

    Identifier = { fg = turquoise },
    Function = { fg = sky },
    Title = { fg = orange },

    Statement = { fg = "#cdacfc" },
    Conditional = { fg = "#ffcbfb" },
    Repeat = { fg = violet },
    Label = { fg = turquoise },
    Operator = { fg = cranberry },
    Keyword = { fg = "#ffcbfb" },
    Exception = { fg = crimson },

    PreProc = { fg = cranberry },
    Include = { fg = "#ffcbfb" },
    Define = { fg = "#ffcbfb" },
    Macro = { fg = "#ffcbfb" },
    PreCondit = { fg = "#ffcbfb" },

    Type = { fg = emerald },
    StorageClass = { fg = violet },
    Structure = { fg = "#f4af6f" },
    Typedef = { fg = "#f4af6f" },

    Special = { fg = "#eeef9f" },
    SpecialComment = { fg = "#eeef9f" },
    Tag = { fg = "#eeef9f" },
    Delimiter = { fg = "#eeef9f" },
    Debug = { fg = "#eeef9f" },

    -- Neovim Tree-sitter
    ["@attribute"] = { fg = sky },
    ["@comment.error"] = { fg = red },
    ["@comment.note"] = { fg = grey58 },
    ["@comment.ok"] = { fg = green },
    ["@comment.todo"] = { link = "Todo" },  -- no local variable available; left unchanged
    ["@comment.warning"] = { fg = yellow },
    ["@constant"] = { fg = turquoise },
    ["@constant.builtin"] = { fg = green },
    ["@constant.macro"] = { fg = violet },
    ["@constructor"] = { fg = emerald },
    ["@diff.delta"] = { link = "DiffChange" },  -- no local variable available; left unchanged
    ["@diff.minus"] = { link = "DiffDelete" },    -- no local variable available; left unchanged
    ["@diff.plus"] = { link = "DiffAdd" },          -- no local variable available; left unchanged
    ["@function.builtin"] = { fg = sky },
    ["@function.call"] = { fg = sky },
    ["@function.macro"] = { fg = turquoise },
    ["@function.method"] = { fg = sky },
    ["@function.method.call"] = { fg = sky },
    ["@keyword.conditional"] = { fg = "#ffcbfb" },
    ["@keyword.directive"] = { fg = cranberry },
    ["@keyword.directive.define"] = { fg = "#ffcbfb" },
    ["@keyword.exception"] = { fg = violet },
    ["@keyword.import"] = { fg = "#ffcbfb" },
    ["@keyword.operator"] = { fg = violet },
    ["@keyword.repeat"] = { fg = violet },
    ["@keyword.storage"] = { fg = violet },
    ["@markup.environment"] = { fg = violet },
    ["@markup.environment.name"] = { fg = emerald },
    ["@markup.heading"] = { fg = violet },
    ["@markup.italic"] = { fg = orchid, italic = true },
    ["@markup.link"] = { fg = green },
    ["@markup.link.label"] = { fg = green },
    ["@markup.link.url"] = { fg = purple, underline = true, sp = grey50 },
    ["@markup.list"] = { fg = cranberry },
    ["@markup.list.checked"] = { fg = turquoise },
    ["@markup.list.unchecked"] = { fg = blue },
    ["@markup.math"] = { fg = sky },
    ["@markup.quote"] = { fg = grey58 },
    ["@markup.raw"] = { fg = c.r1 },  -- inlined from String
    ["@markup.strikethrough"] = { strikethrough = true },
    ["@markup.strong"] = { fg = orchid },
    ["@markup.underline"] = { underline = true },
    ["@module"] = { fg = turquoise },
    ["@module.builtin"] = { fg = green },
    ["@none"] = {},
    ["@parameter.builtin"] = { fg = orchid },
    ["@property"] = { fg = lavender },
    ["@string.documentation"] = { fg = turquoise },
    ["@string.regexp"] = { fg = turquoise },
    ["@string.special.path"] = { fg = orchid },
    ["@string.special.symbol"] = { fg = purple },
    ["@string.special.url"] = { fg = purple },
    ["@tag"] = { fg = blue },
    ["@tag.attribute"] = { fg = turquoise },
    ["@tag.builtin"] = { fg = blue },
    ["@tag.delimiter"] = { fg = green },
    ["@type.builtin"] = { fg = emerald },
    ["@type.qualifier"] = { fg = violet },
    ["@variable"] = { fg = grey89 },
    ["@variable.builtin"] = { fg = green },
    ["@variable.member"] = { fg = lavender },
    ["@variable.parameter"] = { fg = orchid },

    -- Neovim LSP semantic highlights
    ["@lsp.type.boolean"] = { link = "@boolean" },  -- no substitution available
    ["@lsp.type.builtinConstant"] = { fg = green },
    ["@lsp.type.builtinType"] = { fg = emerald },
    ["@lsp.type.class"] = { fg = emerald },
    ["@lsp.type.enum"] = { fg = emerald },
    ["@lsp.type.enumMember"] = { fg = turquoise },
    ["@lsp.type.escapeSequence"] = { link = "@string.escape" },  -- no substitution available
    ["@lsp.type.formatSpecifier"] = { link = "@punctuation.special" },  -- no substitution available
    ["@lsp.type.generic"] = { fg = grey89 },
    ["@lsp.type.interface"] = { fg = emerald },
    ["@lsp.type.keyword"] = { fg = "#ffcbfb" },
    ["@lsp.type.lifetime"] = { fg = violet },
    ["@lsp.type.namespace"] = { fg = turquoise },
    ["@lsp.type.number"] = { fg = "#8eafff" },
    ["@lsp.type.parameter"] = { link = "@parameter" },  -- no substitution available
    ["@lsp.type.property"] = { fg = lavender },
    ["@lsp.type.selfKeyword"] = { fg = green },
    ["@lsp.type.selfParameter"] = { fg = green },
    ["@lsp.type.string"] = { fg = c.r1 },
    ["@lsp.type.struct"] = { fg = emerald },
    ["@lsp.type.typeAlias"] = { link = "@type.definition" },  -- no substitution available
    ["@lsp.type.unresolvedReference"] = { underline = true, sp = red },
    ["@lsp.type.variable"] = { fg = grey89 },

    -- Additional LSP modifications
    ["@lsp.typemod.class.defaultLibrary"] = { fg = emerald },
    ["@lsp.typemod.enum.defaultLibrary"] = { fg = emerald },
    ["@lsp.typemod.function.defaultLibrary"] = { fg = sky },
    ["@lsp.typemod.keyword.async"] = { fg = "#ffcbfb" },
    ["@lsp.typemod.keyword.injected"] = { fg = "#ffcbfb" },
    ["@lsp.typemod.variable.static"] = { fg = turquoise },
  }

  apply_highlights(highlights)
end

-- Set initial theme based on file value (or default to "dark")
local themecolor = fileToList('/home/bresilla/.cache/wal/theme')[1] or "dark"
mycolors(themecolor)

vim.keymap.set('n', '<leader>d', function() mycolors() end)

-- Watch the colors file for changes and reapply the theme.
local filepathtowatch = '/home/bresilla/.cache/lule/colors'
local watcher = require("utils.watcher")
local handle = watcher.watch_file(filepathtowatch, function(fname, status)
  themecolor = fileToList('/home/bresilla/.cache/wal/theme')[1] or "dark"
  mycolors(themecolor)
end)

