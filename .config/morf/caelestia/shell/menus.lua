-- The launcher's two other menus, as the author's own scripts had them
-- (~/.local/sbin/appy and browsy, both fzy lists in a terminal):
--
--   appy     the Flatpak apps and the AppImages in /env/app; Return starts
--            one, detached (`flatpak run ID`, or the AppImage itself)
--   browsy   history, bookmarks, proxmox, search, playlist, app-list and
--            packages; anything else typed opens as an address, or is
--            searched on DuckDuckGo, in $BROWSER
--
-- Opened over IPC -- `launcher apps`, `launcher web` -- so a key can bring
-- either straight up. Everything they read is the author's own: the
-- bookmark tool's JSON files, Zen's history, `play` for a playlist. Escape
-- on a page goes back to the menu, then shuts the launcher.
-- CAELESTIA_DRY_RUN=1 logs what would be started instead.

local morf = require("morf")
local config = require("config")

local M = {}

--- Which menu the launcher shows ("" for its own), and the page of it.
M.source = morf.signal("caelestia.menus.source", "")
M.page = morf.signal("caelestia.menus.page", "")

local home = morf.fs.home()
local BOOKMARKS = home .. "/.local/share/bookmark/"
local APPIMAGES = "/env/app"

local function dry_run()
  local v = morf.env and morf.env("CAELESTIA_DRY_RUN")
  return v ~= nil and v ~= "" and v ~= "0"
end

--- Starts `argv` detached from the shell, as the scripts do with setsid.
local function start(argv)
  if dry_run() then
    morf.log("info", "caelestia: menus (dry run): " .. table.concat(argv, " "))
    return
  end
  local detached = { "setsid", "-f" }
  for _, word in ipairs(argv) do detached[#detached + 1] = word end
  morf.run(detached, {}, function(result)
    if result and not result.ok then
      morf.log("warn", "caelestia: could not start " .. argv[1] .. ": " .. tostring(result.stderr or result.code))
    end
  end)
end

local function browser() return (morf.env and morf.env("BROWSER")) or "xdg-open" end
local function open(url) start { browser(), url } return "close" end

local function fuzzy(list, term, key)
  if term == "" then return list end
  local hits = morf.text.fuzzy(term, list, { key = key or { "name", { "description", 0.5 } } })
  local out = {}
  for _, hit in ipairs(hits) do out[#out + 1] = hit.item end
  return out
end

-- -------------------------------------------------------------------- appy --

local app_rows = morf.signal("caelestia.menus.apps", {})

--- Reads the Flatpak apps and the AppImages afresh.
function M.refresh_apps()
  local rows = {}
  local ok, entries = pcall(morf.fs.list, APPIMAGES)
  if ok and type(entries) == "table" then
    for _, e in ipairs(entries) do
      local name = e.name or ""
      if e.is_file and name:match("%.AppImage$") then
        rows[#rows + 1] = {
          id = "appimage:" .. name, name = (name:gsub("%.AppImage$", "")),
          description = APPIMAGES .. "/" .. name, material = "deployed_code",
          argv = { APPIMAGES .. "/" .. name },
        }
      end
    end
  end
  app_rows:set(rows)
  morf.run({ "flatpak", "list", "--app", "--columns=application,name" }, {}, function(result)
    if not (result and result.ok) then return end
    local all = {}
    for _, r in ipairs(rows) do all[#all + 1] = r end
    for line in tostring(result.stdout or ""):gmatch("[^\n]+") do
      local id, name = line:match("^(%S+)\t(.*)$")
      if id then
        all[#all + 1] = {
          id = "flatpak:" .. id, name = name ~= "" and name or id, description = id, icon = id,
          argv = { "flatpak", "run", id },
        }
      end
    end
    table.sort(all, function(a, b) return a.name:lower() < b.name:lower() end)
    app_rows:set(all)
  end)
end

-- ------------------------------------------------------------------ browsy --

-- The bookmark tool's files: `{ urls = { items = { {name, url, group} } } }`.
local function marks(file, group)
  local ok, text = pcall(morf.fs.read, BOOKMARKS .. file)
  if not ok or type(text) ~= "string" then return {} end
  local fine, data = pcall(morf.json.decode, text)
  local items = fine and type(data) == "table" and data.urls and data.urls.items or {}
  local out = {}
  for _, item in ipairs(items) do
    if not group or item.group == group then out[#out + 1] = item end
  end
  return out
end

local function mark_rows(file, group, icon, act)
  local out = {}
  for _, item in ipairs(marks(file, group)) do
    out[#out + 1] = {
      kind = "menu", id = file .. ":" .. tostring(item.id), name = tostring(item.name),
      description = tostring(item.url), material = icon,
      run = function() return act(item.url) end,
    }
  end
  return out
end

-- Zen's history, newest first: read from a copy (the browser holds the
-- database open), off the main loop.
local history = morf.signal("caelestia.menus.history", {})
local function refresh_history()
  local query = "SELECT url, title FROM moz_places WHERE url NOT LIKE '%google%search%' "
    .. "ORDER BY last_visit_date DESC, visit_count DESC LIMIT 3000;"
  local script = [[
db=$(ls -t "$HOME"/.var/app/app.zen_browser.zen/.zen/*/places.sqlite \
  "$HOME"/.mozilla/firefox/*/places.sqlite \
  "$HOME"/.var/app/org.mozilla.firefox/.mozilla/firefox/*/places.sqlite 2>/dev/null | head -1)
[ -n "$db" ] || exit 1
copy=$(mktemp) && cp -f "$db" "$copy" && sqlite3 -separator "$(printf '\t')" "$copy" "$0"; rm -f "$copy"]]
  morf.run({ "sh", "-c", script, query }, { max_output = 4 * 1024 * 1024 }, function(result)
    if not (result and result.ok) then return end
    local rows = {}
    for line in tostring(result.stdout or ""):gmatch("[^\n]+") do
      local url, title = line:match("^([^\t]*)\t?(.*)$")
      if url and url ~= "" then
        local shown = url:gsub("^https?://", ""):gsub("/$", "")
        rows[#rows + 1] = {
          id = "history:" .. #rows, name = title ~= "" and title or shown,
          description = shown, material = "history", url = url,
        }
      end
    end
    history:set(rows)
  end)
end

-- What surfraw's list gave; surfraw is not on this machine, so the engines
-- are web.lua's.
local web = require("web")
local ENGINES = web.ENGINES
local search_url = web.search_url

--- What typed text does on the menu itself: an address opens, anything
--- else is searched on DuckDuckGo.
local function typed_row(query)
  local address = query:match("^https?://") or query:match("^[%w-]+%.[%a][%a]+")
  return {
    kind = "menu", id = "typed", name = query,
    description = address and "Open" or "Search DuckDuckGo", material = address and "open_in_new" or "search",
    run = function()
      if address then return open(query:match("^https?://") and query or ("https://" .. query)) end
      return open(search_url(ENGINES[1], query))
    end,
  }
end

local function go(page)
  return function()
    M.page:set(page)
    if page == "history" then refresh_history() end
    return ""
  end
end

local CATEGORIES = {
  { page = "history", name = "history", description = "What Zen visited, newest first", material = "history" },
  { page = "bookmarks", name = "bookmarks", description = "Your bookmarks", material = "bookmark" },
  { page = "proxmox", name = "proxmox", description = "The cluster's pages", material = "dns" },
  { page = "search", name = "search", description = "Search one engine for something", material = "travel_explore" },
  { page = "playlist", name = "playlist", description = "Play a list", material = "playlist_play" },
  { page = "app-list", name = "app-list", description = "Tools worth knowing", material = "terminal" },
  { page = "packages", name = "packages", description = "Search pkgs.org", material = "inventory_2" },
}

local function browsy(query)
  local page = M.page:get()
  if page == "" then
    local out = {}
    for _, c in ipairs(CATEGORIES) do
      out[#out + 1] = {
        kind = "menu", id = "category:" .. c.page, name = c.name, description = c.description,
        material = c.material, run = go(c.page),
      }
    end
    out = fuzzy(out, query)
    -- Typed text that is no category is an address or a search.
    if query ~= "" then
      local exact = out[1] and out[1].name:lower():find(query:lower(), 1, true) == 1
      if exact then out[#out + 1] = typed_row(query) else table.insert(out, 1, typed_row(query)) end
    end
    return out
  elseif page == "history" then
    local out = {}
    for i, h in ipairs(fuzzy(history:get(), query)) do
      if i > 200 then break end
      out[i] = { kind = "menu", id = h.id, name = h.name, description = h.description, material = h.material,
        run = function() return open(h.url) end }
    end
    return out
  elseif page == "bookmarks" then
    return fuzzy(mark_rows("webmarks_v0.1.json", "default", "bookmark", open), query)
  elseif page == "proxmox" then
    return fuzzy(mark_rows("webmarks_v0.1.json", "proxmox", "dns", open), query)
  elseif page == "playlist" then
    return fuzzy(mark_rows("playmarks_v0.1.json", nil, "playlist_play", function(url)
      start { home .. "/.local/sbin/play", url }
      return "close"
    end), query)
  elseif page == "app-list" then
    return fuzzy(mark_rows("climarks_v0.1.json", nil, "terminal", open), query)
  elseif page == "packages" then
    if query == "" then
      return { { kind = "menu", id = "packages", name = "Type a package", description = "pkgs.org", material = "inventory_2",
        run = function() return "keep" end } }
    end
    return { { kind = "menu", id = "packages", name = query, description = "Search pkgs.org", material = "inventory_2",
      run = function() return open("https://pkgs.org/search/?q=" .. morf.http.url_encode(query)) end } }
  elseif page == "search" then
    local out = {}
    for _, e in ipairs(ENGINES) do
      out[#out + 1] = { kind = "menu", id = "engine:" .. e.id, name = e.name, description = e.url:gsub("%%s", "…"),
        material = "travel_explore", run = go("search:" .. e.id) }
    end
    return fuzzy(out, query)
  elseif page:match("^search:") then
    local id = page:sub(8)
    for _, e in ipairs(ENGINES) do
      if e.id == id then
        if query == "" then
          return { { kind = "menu", id = "engine", name = "Search " .. e.name, description = "Type what to look for",
            material = "travel_explore", run = function() return "keep" end } }
        end
        return { { kind = "menu", id = "engine", name = query, description = "Search " .. e.name, material = "travel_explore",
          run = function() return open(search_url(e, query)) end } }
      end
    end
  end
  return {}
end

--- The rows for `query` in the menu on show, best first.
function M.search(query, limit)
  local source = M.source:get()
  if source == "apps" then
    local rows = fuzzy(app_rows:get(), query)
    local out = {}
    for i = 1, math.min(#rows, limit or #rows) do
      local r = rows[i]
      out[i] = { kind = "menu", id = r.id, name = r.name, description = r.description,
        icon = r.icon, material = r.material,
        run = function() start(r.argv) return "close" end }
    end
    return out, "apps"
  end
  local rows = browsy(query)
  local out = {}
  for i = 1, math.min(#rows, limit or #rows) do out[i] = rows[i] end
  return out, "apps"
end

--- Opens `source` ("apps" or "web") from its top.
function M.open(source)
  M.page:set("")
  M.source:set(source == "web" and "web" or source == "apps" and "apps" or "")
  if M.source:get() == "apps" then M.refresh_apps() end
end

--- Escape: back to the menu from a page (true), or nothing to go back to.
function M.back()
  if M.source:get() ~= "" and M.page:get() ~= "" then
    local page = M.page:get()
    M.page:set(page:match("^search:") and "search" or "")
    return true
  end
  return false
end

return M
