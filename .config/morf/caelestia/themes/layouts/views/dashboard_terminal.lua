-- The dashboard's Terminal tab: a real terminal (`ui.Terminal`, a shell on a
-- pseudo-terminal) with tabs of its own. The strip on top lists them -- each
-- named after what runs in it -- with one to close it and one to open
-- another; under it the chosen one fills the page. The first shell starts
-- when the tab is first shown, not with the shell; a shell that exits takes
-- its tab with it. At most eight.
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local C = theme.color
local M = {}

local P = require("themes.layouts.page")
-- The dashboard's page (the same for every tab), filled by one tile.
M.WIDTH, M.HEIGHT = require("responsive").dashboard("terminal")

local MAX = 8
local STRIP = 40

-- The user's login shell: their account's own (/etc/passwd), not whatever
-- $SHELL the shell was started with; $SHELL, then sh, without one.
local function login_shell()
  local user = morf.env("USER") or morf.env("LOGNAME")
  local ok, passwd = pcall(morf.fs.read, "/etc/passwd")
  if user and ok and type(passwd) == "string" then
    for line in passwd:gmatch("[^\n]+") do
      local name, shell = line:match("^([^:]*):[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:([^:]*)$")
      if name == user and shell and shell ~= "" and morf.fs.exists(shell) then return shell end
    end
  end
  local shell = morf.env("SHELL")
  return (shell and shell ~= "") and shell or "sh"
end
local function command() return { login_shell(), "-l" } end

-- Its colours: its tile's card, the theme's ink,
-- and the usual sixteen. Read as a binding, so a change of scheme or of
-- dark and light reaches a terminal already open.
local function colours()
  local function hex(c) return type(c) == "function" and c():hex() or c:hex() end
  return {
    foreground = hex(C.onSurface), background = hex(C.surfaceContainer), cursor = hex(C.primary),
    palette = {
      "#1d202f", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff", "#a9b1d6",
      "#414868", "#ff899d", "#9fe044", "#faba4a", "#8db0ff", "#c7a9ff", "#a4daff", "#c0caf5",
    },
  }
end

function M.build(ctx)
  -- The strip and the terminal fill the tile's inner box.
  local function height() local _,h=require("responsive").dashboard("terminal") return math.max(1,h) end
  local W = P.tile_inner(M.WIDTH, M.HEIGHT)
  local area = ui.Item { x = 0, y = STRIP + 8, width = W,
    height = function() local _,h=P.tile_inner(M.WIDTH,height()) return math.max(1,h-STRIP-8) end,clip = true }
  -- Eight places; a place is a tab while it holds a terminal.
  local sessions = {}
  local titles, live = {}, {}
  for i = 1, MAX do
    titles[i] = morf.signal("caelestia.terminal.title." .. i, "")
    live[i] = morf.signal("caelestia.terminal.live." .. i, false)
  end
  local current = morf.signal("caelestia.terminal.current", 0)
  local serial = 0

  local function close(i)
    local s = sessions[i]
    if not s then return end
    sessions[i] = nil
    live[i]:set(false)
    ui.destroy(s, true)
    if current:get() == i then
      local next_one = 0
      for k = 1, MAX do if sessions[k] then next_one = k end end
      current:set(next_one)
    end
  end

  local function open()
    local i
    for k = 1, MAX do if not sessions[k] then i = k break end end
    if not i then return end
    serial = serial + 1
    titles[i]:set("shell " .. serial)
    local term = ui.Terminal {
      id = "terminal-" .. i,
      command = command(), cwd = morf.fs.home(),
      font_family = theme.mono or "monospace", font_size = 13, padding = 8,
      anchors = { fill = true },
      visible = function() return current:get() == i end,
      focus = true,
      colors = colours,
      on_title = function(title) if title and title ~= "" then titles[i]:set(title) end end,
      on_exit = function() close(i) end,
    }
    ui.reparent(term, area)
    sessions[i] = term
    live[i]:set(true)
    current:set(i)
  end

  -- The first shell, when the tab is first on show.
  morf.effect("caelestia.terminal.first", function()
    if ctx.opened() and current:get() == 0 then morf.timer(1, open, false) end
  end)

  -- ----------------------------------------------------------- the strip --
  local tabs = {}
  for i = 1, MAX do
    local function chosen() return current:get() == i end
    tabs[i] = kit.action {
      id = "terminal-tab-" .. i, height = STRIP - 6, cursor = "pointer",
      width = 168, visible = function() return live[i]:get() end,
      on_clicked = function() current:set(i) end,
      kit.surface { anchors = { fill = true }, radius = kit.round(10),
        color = function() return chosen() and C.primaryContainer or C.surfaceContainerHigh end },
      kit.icon("terminal", 16, function() return chosen() and C.onPrimaryContainer or C.onSurfaceVariant end,
        { x = 10, anchors = { vertical_center = true } }),
      kit.text { x = 32, width = 168 - 32 - 30, elide = "right", anchors = { vertical_center = true },
        text = function() return titles[i]:get() end, font_size = theme.size.smaller,
        color = function() return chosen() and C.onPrimaryContainer or C.onSurface end },
      kit.action { id = "terminal-close-" .. i, width = 24, height = 24, cursor = "pointer",
        anchors = { right = true, right_margin = 4, vertical_center = true },
        accessible_name = "Close terminal",
        on_clicked = function() close(i) end,
        kit.icon("close", 14, function() return chosen() and C.onPrimaryContainer or C.onSurfaceVariant end,
          { anchors = { center_in = true } }) },
    }
  end
  local add = kit.action {
    id = "terminal-new", width = STRIP - 6, height = STRIP - 6, cursor = "pointer",
    accessible_name = "New terminal",
    on_clicked = open,
    kit.surface { anchors = { fill = true }, radius = kit.round(10), color = function() return C.surfaceContainerHigh end },
    kit.icon("add", 18, function() return C.onSurface end, { anchors = { center_in = true } }),
  }
  -- (The places then the new one: an unpacked list keeps all its values
  -- only as the last of a constructor's.)
  local row = { y = 3, gap = 6, align = "center" }
  for i = 1, MAX do row[#row + 1] = tabs[i] end
  row[#row + 1] = add
  local strip = kit.scroll({ id = "terminal-strip", x = 0, y = 0, width = W, height = STRIP, clip = true,
    ui.Row(row) })

  local empty = ui.Column {
    id = "terminal-empty", anchors = { center_in = true }, gap = 8, align = "center",
    visible = function() return current:get() == 0 end,
    kit.icon("terminal", 36, function() return C.onSurfaceVariant end),
    kit.text { text = "No terminal open", color = function() return C.onSurfaceVariant end },
  }

  return { page = P.tile { id = "dashboard-terminal", width = M.WIDTH, height = height, title = "Terminal",
    note = function()
      local n = 0
      for i = 1, MAX do if live[i]:get() then n = n + 1 end end
      return n == 1 and "1 shell" or n .. " shells"
    end,
    area, (strip), empty } }
end

return M
