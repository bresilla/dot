-- Launcher state and actions. Theme views own its geometry and presentation.
local morf = require("morf")
local config = require("config")
local apps = require("apps")
local drawer = require("drawer")
local M = {}
local view

M.query = morf.signal("caelestia.launcher.query", "")
M.selected = morf.signal("caelestia.launcher.selected", 1)
M.results = morf.list_model({})
-- How tall each kind of row is, with the gap under it: the results view
-- lists them virtualised by these, and its build sets its own.
M.row_heights = { header = 32, hero = 118, row = 52 }
-- Bumped once the view has set its own heights, so the rows found before
-- it was built are found again at those.
local heights_set = morf.signal("caelestia.launcher.heights", 0)
M.count = morf.signal("caelestia.launcher.count", 0)
M.mode = morf.signal("caelestia.launcher.mode", "apps")
-- The row whose actions are listed instead of the results (Tab, Ctrl+K),
-- by key; "" for none.
M.acting = morf.signal("caelestia.launcher.acting", "")
-- The carousel's pictures: `{ path, name }` each, and how many.
M.walls = {}
M.wall_count = morf.signal("caelestia.launcher.walls", 0)

local function max_shown() return config.get("launcher.max_shown") end

local by_key = {}

--- The full row behind a model entry.
local function row_of(entry) return entry and by_key[entry.key] end

-- The results follow the query.
morf.effect("caelestia.launcher.search", function()
  heights_set:get()
  local q = M.query:get()
  local menus = require("menus")
  local found, mode
  local acting = M.acting:get()
  local owner = acting ~= "" and by_key[acting] or nil
  if owner and owner.actions then
    -- The action panel: the chosen row's actions, filtered by the field.
    found, mode = {}, "apps"
    for i, a in ipairs(owner.actions) do
      if q == "" or a.name:lower():find(q:lower(), 1, true) then
        found[#found + 1] = { kind = "menu", id = acting .. ":action:" .. i, name = a.name,
          description = owner.name, material = a.material, run = a.run }
      end
    end
  elseif menus.source:get() ~= "" then
    found, mode = menus.search(q, max_shown())
  else
    found, mode = apps.search(q, max_shown())
  end
  if mode == "wallpapers" then
    M.walls = found
    local current = require("wallpaper").current:get()
    local at = 1
    for i, w in ipairs(found) do
      by_key["wallpaper:" .. w.id] = w
      if w.path == current then at = i end
    end
    M.results:replace({}, "key")
    M.count:set(0)
    M.wall_count:set(#found)
    M.mode:set(mode)
    M.selected:set(at)
    return
  end
  local out = {}
  local shown = 0
  for i = 1, #found do
    local row = found[i]
    local hero = row.id == "answer" or row.kind == "calc"
    if not hero and shown >= max_shown() then break end
    local key = row.kind .. ":" .. row.id
    -- A model row is plain data; the row itself (an action's function
    -- among it) stays in Lua, by key.
    by_key[key] = row
    local entry = {
      key = key .. (row.kind == "calc" and (":" .. row.name) or ""),
      kind = hero and "hero" or row.kind, id = row.id, name = row.name,
      description = row.description, icon = row.icon, material = row.material,
      swatch = row.swatch, glyph = row.glyph, question = row.question,
      height = hero and M.row_heights.hero or M.row_heights.row,
    }
    out[#out + 1] = entry
    by_key[entry.key] = row
    if not hero then shown = shown + 1 end
  end
  M.results:replace(out, "key")
  M.count:set(#out)
  M.wall_count:set(0)
  M.mode:set(mode)
  local first = 1
  while out[first] and out[first].kind == "header" do first = first + 1 end
  M.selected:set(out[first] and first or 1)
end)

M.row_of = row_of
M.icon = apps.icon
local function wide() return M.mode:get() == "wallpapers" end
function M.set_query(text)
  M.query:set(text)
  if view then view.set_query(text) end
end

function M.activate(row)
  M.acting:set("")
  local next_step = apps.activate(row)
  if next_step == "close" then
    M.drawer.set(false)
  elseif type(next_step) == "string" and next_step ~= "keep" then
    M.set_query(next_step)
  end
end

-- The list's choosing is a kit Collection (crates/morf-kit): it skips the
-- section headings, walks the wallpapers sideways, and answers the Page
-- keys; the view draws the rows.
local headers = function()
  local out = {}
  for i = 1, M.results:len() do
    if M.results:get(i).kind == "header" then out[#out + 1] = i end
  end
  return out
end
local choice = require("lib.kit.control").headless("Collection", {
  layout = "list",
  orientation = function() return wide() and "horizontal" or "vertical" end,
  count = function() return wide() and M.wall_count:get() or M.count:get() end,
  disabled = function() return wide() and {} or headers() end,
  current = function() return M.selected:get() end,
  page = 5,
  on_current_changed = function(i) M.selected:set(i) end,
})
M.choice = choice
local function move(delta)
  -- The carousel steps by itself: the Collection can keep the list's
  -- orientation across an empty search, and a wallpaper has no headings
  -- to skip anyway.
  if wide() then
    local count = M.wall_count:get()
    if count > 0 then M.selected:set(math.max(1, math.min(count, M.selected:get() + delta))) end
    return
  end
  local back, forth = "Up", "Down"
  for _ = 1, math.abs(delta) do
    if not choice.key(delta > 0 and forth or back) then break end
  end
end
M.move = move

local function chosen()
  if wide() then return M.walls[M.selected:get()] end
  return row_of(M.results:get(M.selected:get()))
end
M.chosen = chosen

function M.escape()

    if M.acting:get() ~= "" then
      M.acting:set("")
    elseif require("menus").back() then
      M.set_query("")
    else
      M.drawer.set(false)
    end
end
function M.key(_, _, modifiers, _, key)

    if key == "Up" then move(-1) return true end
    if key == "Down" then move(1) return true end
    if key == "Page_Up" or key == "Page_Down" then return choice.key(wide() and "" or key) end
    -- Tab or Ctrl+K: the chosen row's actions, and back.
    if key == "Tab" or (key == "k" and tostring(modifiers):find("ctrl")) then
      if M.acting:get() ~= "" then
        M.acting:set("")
      else
        local entry = M.results:get(M.selected:get())
        local r = entry and by_key[entry.key]
        if r and r.actions and #r.actions > 0 then
          M.acting:set(entry.key)
          M.set_query("")
        end
      end
      return true
    end
end
-- TextInput consumes horizontal arrow presses for its caret. Releases reach
-- the controller, so the wallpaper chooser can use them without an engine hook.
function M.release(_, _, modifiers, _, key)
  if not wide() or (modifiers and modifiers ~= "") then return end
  if key == "Left" then move(-1) elseif key == "Right" then move(1) else return end
  view.set_query(M.query:get())
end

local MODE_NAMES = {
  calculator = { "Calculator", "calculate" }, run = { "Run", "terminal" }, files = { "Files", "folder_open" },
  web = { "Web", "travel_explore" }, windows = { "Windows", "desktop_windows" }, system = { "System", "settings_power" },
  emoji = { "Emoji", "mood" }, clipboard = { "Clipboard", "content_paste" }, colour = { "Colour", "palette" },
}
local function mode_name()
  if M.acting:get() ~= "" then return "Actions", "bolt" end
  local menus = require("menus")
  if menus.source:get() == "apps" then return "Apps", "apps" end
  if menus.source:get() == "web" then return "Web", "language" end
  local q = M.query:get()
  local what = require("providers").PREFIXES[q:sub(1, 1)]
  if what then return MODE_NAMES[what][1], MODE_NAMES[what][2] end
  if q:sub(1, 1) == config.get("launcher.action_prefix") then return "Commands", "bolt" end
  return "Search", "search"
end
M.mode_name = mode_name
M.opened = morf.signal("caelestia.launcher.opened", false)
view = require("themes").view("launcher").build(M)
heights_set:set(1)
M.width = view.width
M.drawer = drawer.new {
  name = "launcher", edge = "center", width = view.width, height = view.height,
  content = view.content, props = view.props,
  -- Escape is the launcher's own: it backs out of a menu first.
  close_policy = "outside",
}
morf.effect("caelestia.launcher.open", function()
  local open = M.drawer.open:get()
  M.opened:set(open)
  if open then
    apps.refresh()
    M.set_query("")
    view.focus(true)
  else
    view.focus(false)
    require("menus").open("")
    M.acting:set("")
  end
end)
return M
