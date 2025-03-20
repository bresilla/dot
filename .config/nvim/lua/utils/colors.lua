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

local function apply_highlights(highlights)
  for group, opts in pairs(highlights) do
    if opts.link then
      vim.cmd("highlight! link " .. group .. " " .. opts.link)
    else
      local final_opts = {}
      for key, value in pairs(opts) do
        if not vim.o.termguicolors then
          if key == "bg" then
            final_opts.ctermbg = value
          elseif key == "fg" then
            final_opts.ctermfg = value
          else
            final_opts[key] = value
          end
        else
          final_opts[key] = value
        end
      end
      vim.api.nvim_set_hl(0, group, final_opts)
    end
  end
end


function mycolors()
  -- Read rainbow colors from file
  local rainbow = fileToList('/home/bresilla/.cache/lule/colors')
  local c = {}
  for i, color in ipairs(rainbow) do
      if not vim.o.termguicolors then
          c["r" .. (i - 1)] = (i - 1)
      else
          c["r" .. (i - 1)] = color
      end
  end

  -- Define additional color aliases as local variables
  local error_color = c.r172
  local error_light = c.r176
  local error_dark  = c.r161
  local ok_color    = c.r196
  local ok_light    = c.r200
  local ok_dark     = c.r185
  local warn_color  = c.r220
  local warn_light  = c.r224
  local warn_dark   = c.r209
  local info_color  = c.r244
  local info_light  = c.r248
  local info_dark   = c.r233
  local hint_color  = c.r117
  local hint_light  = c.r119
  local hint_dark   = c.r113

  local grey89     = c.r16
  local grey58     = c.r17
  local khaki      = c.r18
  local yellow     = c.r19
  local cream      = c.r20
  local orange     = c.r21
  local coral      = c.r22
  local orchid     = c.r23
  local rose       = c.r24
  local lime       = c.r25
  local green      = c.r26
  local emerald    = c.r27
  local turquoise  = c.r28
  local blue       = c.r29
  local ocean      = c.r30
  local sky        = c.r31
  local lavender   = c.r32
  local purple     = c.r33
  local violet     = c.r34
  local cranberry  = c.r35
  local crimson    = c.r36
  local red        = c.r37
  local dirt       = c.r38
  local marble     = c.r39

  local accent = c.r1
  local black = c.r0
  local white = c.r15
  local ac0 = c.r236
  local ac1 = c.r237
  local ac2 = c.r238
  local ac3 = c.r239
  local ac4 = c.r240
  local cur_nr = c.r246

  -- Define highlight groups as a table.
  local highlights = {
    Normal = { bg = black },
    NonText = { fg = ac4 },
    Cursor = { bg = accent, fg = white, bold = true },
    iCursor = { bg = accent, fg = white, bold = true },
    rCursor = { bg = accent, fg = white, bold = true },
    CursorLine = { bg = ac0 },
    CursorColumn = { bg = ac0 },
    Visual = { bg = ac1 },
    Conceal = { fg = ac4 },
    LineNr = { fg = ac1 },
    Comment  = { fg = ac2, italic = true },
    CursorLineNR = { fg = cur_nr, bold = true },
    NormalFloat = { bg = ac1 },
    Whitespace = { fg = ac4 },

    -- BARBAR
    BufferDefaultCurrent = { bg = black, fg = accent, bold = true },
    BufferDefaultCurrentSign = { bg = black, fg = accent },
    BufferDefaultCurrentSignRight = { bg = black, fg = accent },
    BufferDefaultInactive = { bg = ac1 },
    BufferDefaultInactiveSign = { bg = ac1, fg = black },
    BufferDefaultInactiveSignRight = { bg = ac1, fg = black },
    BufferDefaultVisible = { bg = ac1 },
    BufferDefaultVisibleSign = { bg = ac1, fg = black },
    BufferDefaultVisibleSignRight = { bg = ac1, fg = black },
    BufferTabpageFill = { bg = ac1 },
    BufferTabpagesSep = { bg = ac1 },

    -- Scrollbar
    ScrollbarHandle = { bg = ac0 },
    ScrollbarSearch = { fg = accent },
    ScrollbarSearchHandle = { bg = ac0, fg = accent },

    -- ChatGPT
    ChatGPTSelectedMessage = { bg = ac0 },

    -- DASHBOARD
    DashboardHeader = { bg = black, fg = accent },
    DashboardCenter = { bg = black, fg = accent },
    DashboardFooter = { bg = black, fg = accent },

    -- NvimTree
    NvimTreeNormal = { bg = ac1 },
    NvimTreeCursorLine = { bg = black },
    WinSeparator = { fg = ac0 },

    -- STATUS-LINE
    StatusLine = { bg = ac1, fg = accent },
    StatusLineNC = { bg = black, fg = accent },
    ElNormal = { bg = accent, fg = black, bold = true },
    ElNormal2 = { bg = black, fg = accent, bold = true },
    ElInsert = { bg = black, fg = accent, bold = true },
    ElFileType = { bg = accent, fg = black, bold = true },

    -- INDENTATION
    IndentLine = { bg = black, fg = ac1 },
    IndentLineCurrent = { bg = black, fg = ac4 },
    MiniIndentscopeSymbol = { fg = black, bg = ac1 },
    MiniIndentscopeSymbolOff = { fg = black, bg = ac4 },

    -- SEARCH
    IlluminatedWordText = { bg = ac1, bold = true },
    Search = { bg = ac2 },
    CurSearch = { bg = accent, fg = black },
    IncSearch = { bg = black, fg = accent },
    CursorWord = { bg = accent, fg = black },
    CursorJump = { bg = black, fg = accent },
    MatchParen = { bg = accent, fg = black },

    -- TELESCOPE
    TelescopeBorder = { fg = accent },
    NoiceCmdlinePopupBorder = { fg = accent },

    -- TERMINAL
    FloatBorder = { bg = black, fg = accent },
    ToggleTermNormal = { bg = ac0 },
    ToggleTermNormalFloat = { bg = ac0 },
    ToggleTermFloatBorder = { bg = ac0, fg = ac0 },

    --- GITSIGNS
    GitGutterAdd = { fg = ok_light },
    GitGutterChange = { fg = warn_light },
    GitGutterDelete = { fg = error_light },

    -- DIAGNOSTICS
    DiagnosticError = { fg = error_light, bg = error_dark },
    DiagnosticWarn  = { fg = warn_light,  bg = warn_dark },
    DiagnosticInfo  = { fg = info_light,  bg = info_dark },
    DiagnosticHint  = { fg = hint_light,  bg = hint_dark },
    DiagnosticOk    = { fg = ok_light,    bg = ok_dark },
    DiagnosticFloatingError = { fg = error_light, bg = error_dark },
    DiagnosticFloatingWarn  = { fg = warn_light,  bg = warn_dark },
    DiagnosticFloatingInfo  = { fg = info_light,  bg = info_dark },
    DiagnosticFloatingHint  = { fg = hint_light,  bg = hint_dark },
    DiagnosticFloatingOk    = { fg = ok_light,    bg = ok_dark },
    DiagnosticUnderlineError = { bg = error_dark },
    DiagnosticUnderlineWarn  = { bg = warn_dark },
    DiagnosticUnderlineInfo  = { bg = info_dark },
    DiagnosticUnderlineHint  = { bg = hint_dark },
    DiagnosticUnderlineOk    = { bg = ok_dark },
    DiagnosticVirtualTextError = { fg = error_light, bg = error_dark },
    DiagnosticVirtualTextWarn  = { fg = warn_light,  bg = warn_dark },
    DiagnosticVirtualTextInfo  = { fg = info_light,  bg = info_dark },
    DiagnosticVirtualTextHint  = { fg = hint_light,  bg = hint_dark },
    DiagnosticVirtualTextOk    = { fg = ok_light,    bg = ok_dark },
    DiagnosticSignError = { fg = error_light, bg = error_dark },
    DiagnosticSignWarn  = { fg = warn_light,  bg = warn_dark },
    DiagnosticSignInfo  = { fg = info_light,  bg = info_dark },
    DiagnosticSignHint  = { fg = hint_light,  bg = hint_dark },
    DiagnosticSignOk    = { fg = ok_light,    bg = ok_dark },
    DiagnosticUnnecessary = { fg = c.r3 },

    -- COMPLETION MENU
    Pmenu = { bg = ac1, fg = white },
    PmenuSel = { bg = accent, fg = black, bold = true },
    PmenuSbar = { bg = ac1 },
    PmenuThumb = { bg = ac1 },
    BlinkCmpMenu = { fg = white, bg = ac1 },
    BlinkCmpMenuSelection = { fg = black, bg = accent, bold = true },
    BlinkCmpGhostText = { fg = ac4 },
    BlinkCmpDoc = { bg = ac0 },
    BlinkCmpDocSeparator = { bg = ac0, fg = black, bold = true },
    BlinkCmpLabelMatch = { fg = white, bg = ac4, italic = true },

    BlinkCmpKindSnippet = { bold = true, fg = black, bg = coral },
    BlinkCmpKindKeyword = { bold = true, fg = black, bg = violet },
    BlinkCmpKindText = { bold = true, fg = black, bg = c.r46 },
    BlinkCmpKindMethod = { bold = true, fg = black, bg = c.r58 },
    BlinkCmpKindConstructor = { bold = true, fg = black, bg = c.r70 },
    BlinkCmpKindFunction = { bold = true, fg = black, bg = c.r82 },
    BlinkCmpKindFolder = { bold = true, fg = black, bg = c.r94 },
    BlinkCmpKindModule = { bold = true, fg = black, bg = c.r106 },
    BlinkCmpKindConstant = { bold = true, fg = black, bg = c.r118 },
    BlinkCmpKindField = { bold = true, fg = black, bg = c.r130 },
    BlinkCmpKindProperty = { bold = true, fg = black, bg = c.r142 },
    BlinkCmpKindEnum = { bold = true, fg = black, bg = c.r154 },
    BlinkCmpKindUnit = { bold = true, fg = black, bg = c.r166 },
    BlinkCmpKindClass = { bold = true, fg = black, bg = coral },
    BlinkCmpKindVariable = { bold = true, fg = black, bg = violet },
    BlinkCmpKindFile = { bold = true, fg = black, bg = c.r46 },
    BlinkCmpKindInterface = { bold = true, fg = black, bg = c.r58 },
    BlinkCmpKindColor = { bold = true, fg = black, bg = c.r64 },
    BlinkCmpKindReference = { bold = true, fg = black, bg = c.r82 },
    BlinkCmpKindEnumMember = { bold = true, fg = black, bg = c.r94 },
    BlinkCmpKindStruct = { bold = true, fg = black, bg = c.r106 },
    BlinkCmpKindValue = { bold = true, fg = black, bg = c.r118 },
    BlinkCmpKindEvent = { bold = true, fg = black, bg = c.r124 },
    BlinkCmpKindOperator = { bold = true, fg = black, bg = c.r142 },
    BlinkCmpKindTypeParameter = { bold = true, fg = black, bg = c.r154 },
    BlinkCmpKindCopilot = { bold = true, fg = black, bg = c.r166 },

    -- SYNTAX
    String = { fg = accent },
    Character = { fg = purple },
    Constant = { fg = orange },
    Number = { fg = ocean },
    Boolean = { fg = cranberry },
    Float = { fg = ocean },

    Identifier = { fg = turquoise },
    Function = { fg = sky },
    Title = { fg = orange },

    Statement = { fg = marble },
    Conditional = { fg = rose },
    Repeat = { fg = violet },
    Label = { fg = turquoise },
    Operator = { fg = cranberry },
    Keyword = { fg = rose },
    Exception = { fg = crimson },

    PreProc = { fg = cranberry },
    Include = { fg = rose },
    Define = { fg = rose },
    Macro = { fg = rose },
    PreCondit = { fg = rose },

    Type = { fg = emerald },
    StorageClass = { fg = violet },
    Structure = { fg = dirt },
    Typedef = { fg = dirt },

    Special = { fg = cream },
    SpecialComment = { fg = cream },
    Tag = { fg = cream },
    Delimiter = { fg = cream },
    Debug = { fg = cream },

    -- Neovim Tree-sitter
    ["@attribute"] = { fg = sky },
    ["@comment.error"] = { fg = red },
    ["@comment.note"] = { fg = grey58 },
    ["@comment.ok"] = { fg = green },
    ["@comment.todo"] = { link = "Todo" },
    ["@comment.warning"] = { fg = yellow },
    ["@constant"] = { fg = turquoise },
    ["@constant.builtin"] = { fg = green },
    ["@constant.macro"] = { fg = violet },
    ["@constructor"] = { fg = emerald },
    ["@diff.delta"] = { link = "DiffChange" },
    ["@diff.minus"] = { link = "DiffDelete" },
    ["@diff.plus"] = { link = "DiffAdd" },
    ["@function.builtin"] = { fg = sky },
    ["@function.call"] = { fg = sky },
    ["@function.macro"] = { fg = turquoise },
    ["@function.method"] = { fg = sky },
    ["@function.method.call"] = { fg = sky },
    ["@keyword.conditional"] = { fg = rose },
    ["@keyword.directive"] = { fg = cranberry },
    ["@keyword.directive.define"] = { fg = rose },
    ["@keyword.exception"] = { fg = violet },
    ["@keyword.import"] = { fg = rose },
    ["@keyword.operator"] = { fg = violet },
    ["@keyword.repeat"] = { fg = violet },
    ["@keyword.storage"] = { fg = violet },
    ["@markup.environment"] = { fg = violet },
    ["@markup.environment.name"] = { fg = emerald },
    ["@markup.heading"] = { fg = violet },
    ["@markup.italic"] = { fg = orchid, italic = true },
    ["@markup.link"] = { fg = green },
    ["@markup.link.label"] = { fg = green },
    ["@markup.link.url"] = { fg = purple, underline = true, sp = marble },
    ["@markup.list"] = { fg = cranberry },
    ["@markup.list.checked"] = { fg = turquoise },
    ["@markup.list.unchecked"] = { fg = blue },
    ["@markup.math"] = { fg = sky },
    ["@markup.quote"] = { fg = grey58 },
    ["@markup.raw"] = { fg = accent },
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
    ["@lsp.type.boolean"] = { link = "@boolean" },
    ["@lsp.type.builtinConstant"] = { fg = green },
    ["@lsp.type.builtinType"] = { fg = emerald },
    ["@lsp.type.class"] = { fg = emerald },
    ["@lsp.type.enum"] = { fg = emerald },
    ["@lsp.type.enumMember"] = { fg = turquoise },
    ["@lsp.type.escapeSequence"] = { link = "@string.escape" },
    ["@lsp.type.formatSpecifier"] = { link = "@punctuation.special" },
    ["@lsp.type.generic"] = { fg = grey89 },
    ["@lsp.type.interface"] = { fg = emerald },
    ["@lsp.type.keyword"] = { fg = rose },
    ["@lsp.type.lifetime"] = { fg = violet },
    ["@lsp.type.namespace"] = { fg = turquoise },
    ["@lsp.type.number"] = { fg = ocean },
    ["@lsp.type.parameter"] = { link = "@parameter" },
    ["@lsp.type.property"] = { fg = lavender },
    ["@lsp.type.selfKeyword"] = { fg = green },
    ["@lsp.type.selfParameter"] = { fg = green },
    ["@lsp.type.string"] = { fg = accent },
    ["@lsp.type.struct"] = { fg = emerald },
    ["@lsp.type.typeAlias"] = { link = "@type.definition" },
    ["@lsp.type.unresolvedReference"] = { underline = true, sp = red },
    ["@lsp.type.variable"] = { fg = grey89 },

    -- Additional LSP modifications
    ["@lsp.typemod.class.defaultLibrary"] = { fg = emerald },
    ["@lsp.typemod.enum.defaultLibrary"] = { fg = emerald },
    ["@lsp.typemod.function.defaultLibrary"] = { fg = sky },
    ["@lsp.typemod.keyword.async"] = { fg = rose },
    ["@lsp.typemod.keyword.injected"] = { fg = rose },
    ["@lsp.typemod.variable.static"] = { fg = turquoise },
  }

  apply_highlights(highlights)
end

-- Set initial theme based on file value (or default to "dark")
-- local themecolor = fileToList('/home/bresilla/.cache/wal/theme')[1] or "dark"
mycolors()

vim.keymap.set('n', '<leader>d', function() mycolors() end)

-- Watch the colors file for changes and reapply the theme.
local filepathtowatch = '/home/bresilla/.cache/lule/colors'
local watcher = require("utils.watcher")
local handle = watcher.watch_file(filepathtowatch, function(fname, status)
  mycolors()
end)

