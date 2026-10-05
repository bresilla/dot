-- What the launcher finds besides apps, after Raycast and Alfred: answers
-- inline as one types, a prefix for each kind of thing, and fallbacks at the
-- bottom of every search.
--
--   (nothing)  apps, and inline: math "2^10", units "10ft in m", percent
--              "20% off 80", bases "255 in hex", currency "100 usd in eur",
--              an address; then "search the web / files for ..."
--   =          the calculator alone
--   $          run a command (Tab: in a terminal, copy it)
--   / or ~     files and folders (fd), from home (Tab: reveal, copy path,
--              open a terminal there)
--   ?          search the web; a bang picks the engine: ?gh ?yt ?aur ?w ...
--   @          the open windows (Tab: close, bring here)
--   !          the system (lock, suspend, reboot...) and the shell's own
--              drawers and toggles
--   :          emoji, copied
--   ;          the clipboard's history (clipse), copied back
--   #          a colour, in every notation, copied
--
-- Every row is `{ kind = "menu", id, name, description, material | icon |
-- swatch, run, actions }`: Return runs `run`; Tab (or Ctrl+K) lists
-- `actions`, each `{ name, material, run }`. A run returns "close", "keep",
-- or a new query for the field.

local morf = require("morf")
local config = require("config")
local calc = require("calc")
local units = require("lib.util.units")
local web = require("web")

local M = {}

-- Asynchronous answers (files, currency rates) land here and re-run the
-- search.
M.revision = morf.signal("caelestia.providers.revision", 0)
local function bump() M.revision:set(M.revision:get() + 1) end

local home = morf.fs.home()

local function dry_run()
  local v = morf.env and morf.env("CAELESTIA_DRY_RUN")
  return v ~= nil and v ~= "" and v ~= "0"
end

--- Starts `argv` detached from the shell.
local function start(argv)
  if dry_run() then
    morf.log("info", "caelestia: launcher (dry run): " .. table.concat(argv, " "))
    return
  end
  local detached = { "setsid", "-f" }
  for _, word in ipairs(argv) do detached[#detached + 1] = word end
  morf.run(detached, {}, function() end)
end

local function copy(text)
  pcall(morf.clipboard.set, tostring(text))
  return "close"
end

local function open(target) start { "xdg-open", target } return "close" end
local function browse(url) start { web.browser(), url } return "close" end
local function terminal(argv)
  local cmd = { (morf.env and morf.env("TERMINAL")) or "kitty" }
  for _, w in ipairs(argv or {}) do cmd[#cmd + 1] = w end
  start(cmd)
  return "close"
end

local function row(t)
  t.kind = "menu"
  return t
end

local function fuzzy(list, term, key)
  if term == "" then return list end
  local out = {}
  for _, hit in ipairs(morf.text.fuzzy(term, list, { key = key or "name" })) do out[#out + 1] = hit.item end
  return out
end

local function tilde(path)
  if path:sub(1, #home) == home then return "~" .. path:sub(#home + 1) end
  return path
end

-- ------------------------------------------------------------- inline math --

local function answer_row(question, value_text, material)
  return row {
    id = "answer", name = value_text, question = question,
    description = question .. "  ·  Return copies", material = material or "calculate",
    run = function() return copy(value_text:gsub(",", "")) end,
    actions = {
      { name = "Copy the answer", material = "content_copy", run = function() return copy(value_text:gsub(",", "")) end },
      { name = "Copy question and answer", material = "content_copy",
        run = function() return copy(question .. " = " .. value_text) end },
    },
  }
end

local function percent(q)
  local p, x = q:match("^%s*([%d%.]+)%s*%%%s+of%s+([%d%.]+)%s*$")
  if p then return tonumber(p) / 100 * tonumber(x) end
  p, x = q:match("^%s*([%d%.]+)%s*%%%s+off%s+([%d%.]+)%s*$")
  if p then return tonumber(x) * (1 - tonumber(p) / 100) end
  x, p = q:match("^%s*([%d%.]+)%s*%+%s*([%d%.]+)%s*%%%s*$")
  if x then return tonumber(x) * (1 + tonumber(p) / 100) end
  x, p = q:match("^%s*([%d%.]+)%s*%-%s*([%d%.]+)%s*%%%s*$")
  if x then return tonumber(x) * (1 - tonumber(p) / 100) end
  return nil
end

local BASES = { hex = 16, bin = 2, oct = 8, dec = 10, binary = 2, octal = 8, decimal = 10, hexadecimal = 16 }
local function in_base(q)
  local number, base = q:match("^%s*(%S+)%s+[it][no]%s+(%a+)%s*$")
  local to = base and BASES[base:lower()]
  if not to then return nil end
  local value = tonumber(number) or (number:match("^0b[01]+$") and tonumber(number:sub(3), 2))
    or (number:match("^0o[0-7]+$") and tonumber(number:sub(3), 8))
  if not value or value ~= math.floor(value) then return nil end
  value = math.floor(value)
  if to == 10 then return tostring(value) end
  if to == 16 then return ("0x%x"):format(value) end
  if to == 8 then return ("0o%o"):format(value) end
  local bits, v = {}, value
  if v == 0 then return "0b0" end
  while v > 0 do bits[#bits + 1] = tostring(v % 2) v = v // 2 end
  return "0b" .. table.concat(bits):reverse()
end

-- Currency: the European Central Bank's rates (frankfurter.dev, keyless),
-- fetched once a day and kept in the cache folder.
local rates, rates_asked
local function currency(q)
  local amount, from, to = q:upper():match("^%s*([%d%.]+)%s*(%a%a%a)%s+[IT][NO]%s+(%a%a%a)%s*$")
  if not amount then return nil end
  if not rates then
    if not rates_asked then
      rates_asked = true
      local ok, core = pcall(require, "morf.core")
      local file = (ok and core.cache_path and core.cache_path("rates.json")) or nil
      local cached = file and select(2, pcall(morf.fs.read, file))
      local today = morf.time.format("%Y-%m-%d")
      local fine, data = pcall(morf.json.decode, type(cached) == "string" and cached or "")
      if fine and type(data) == "table" and data.fetched == today then
        rates = data.rates
      else
        morf.http.get("https://api.frankfurter.dev/v1/latest?base=EUR", { timeout_ms = 10000 }, function(r)
          local good, body = pcall(function() return r.ok and r.json() end)
          if good and type(body) == "table" and type(body.rates) == "table" then
            body.rates.EUR = 1
            rates = body.rates
            if file then pcall(morf.fs.write, file, morf.json.encode { fetched = today, rates = rates }) end
            bump()
          end
        end)
      end
    end
    if not rates then return "…", from, to end
  end
  local a, b = rates[from], rates[to]
  if not (a and b) then return nil end
  return tonumber(amount) / a * b, from, to
end

--- An answer for `q` if it is a sum, a conversion, a percentage, a base, a
--- currency or an address; nil otherwise.
function M.inline(q)
  if q:match("^%s*$") then return nil end
  local p = percent(q)
  if p then return answer_row(q, units.format(p)) end
  local based = in_base(q)
  if based then return answer_row(q, based, "tag") end
  local money, from, to = currency(q)
  if money == "…" then
    return row { id = "answer", name = "Fetching today's rates…", description = q, material = "currency_exchange",
      run = function() return "keep" end }
  elseif money then
    return answer_row(q, units.format(money, 8) .. " " .. to, "currency_exchange")
  end
  local converted, unit = units.convert(q)
  if converted then return answer_row(q, units.format(converted) .. " " .. unit, "straighten") end
  -- A sum: something with an operator or a function in it, not a bare
  -- number or a word.
  if q:match("[%+%-%*/%^%%%(]") or q:match("%a+%s*%(") then
    local ok, value, shown, result = pcall(calc.evaluate, q)
    if ok and value then return answer_row(q, result or units.format(value)) end
  end
  if web.is_address(q) then
    return row { id = "address", name = q, description = "Open in the browser", material = "open_in_new",
      run = function() return browse(web.address(q)) end,
      actions = { { name = "Copy the address", material = "content_copy", run = function() return copy(web.address(q)) end } } }
  end
  return nil
end

--- The rows at the foot of every search: the web, and files.
function M.fallbacks(q)
  if q:match("^%s*$") then return {} end
  local e = web.ENGINES[1]
  return {
    row { id = "fallback:web", name = "Search " .. e.name .. " for “" .. q .. "”", description = "?" .. e.bang .. " " .. q,
      material = "travel_explore", run = function() return browse(web.search_url(e, q)) end },
    row { id = "fallback:files", name = "Search files for “" .. q .. "”", description = "/" .. q, material = "folder_open",
      run = function() return "/" .. q end },
  }
end

-- ------------------------------------------------------------------- files --

local found_files = { term = nil, rows = {} }
local function files(term)
  if term == "" then
    return { row { id = "files", name = "Type to find files and folders", description = "Searched from " .. tilde(home),
      material = "folder_open", run = function() return "keep" end } }
  end
  if found_files.term ~= term then
    found_files.term = term
    local asked = term
    morf.run({ "fd", "--ignore-case", "--max-results", "60", "--exclude", ".git", "--exclude", "node_modules",
      "--exclude", ".cache", "--", term, home }, { timeout_ms = 4000 }, function(r)
      if found_files.term ~= asked then return end
      local out = {}
      for path in tostring(r and r.stdout or ""):gmatch("[^\n]+") do
        local folder = path:sub(-1) == "/"
        path = path:gsub("/$", "")
        out[#out + 1] = { path = path, folder = folder, name = path:match("([^/]+)$") or path }
      end
      found_files.rows = out
      bump()
    end)
  end
  local out = {}
  for _, f in ipairs(found_files.rows) do
    local parent = f.path:match("^(.*)/[^/]*$") or home
    out[#out + 1] = row {
      id = "file:" .. f.path, name = f.name, description = tilde(f.path),
      material = f.folder and "folder" or "draft",
      run = function() return open(f.path) end,
      actions = {
        { name = "Open", material = "open_in_new", run = function() return open(f.path) end },
        { name = "Show in its folder", material = "folder_open", run = function() return open(parent) end },
        { name = "Copy the path", material = "content_copy", run = function() return copy(f.path) end },
        { name = "Open a terminal there", material = "terminal",
          run = function() return terminal { "--directory", f.folder and f.path or parent } end },
      },
    }
  end
  return out
end

-- --------------------------------------------------------------------- web --

local function websearch(rest)
  local bang, words = rest:match("^(%S+)%s+(.+)$")
  local engine = bang and web.engine(bang)
  if engine then
    return { row { id = "web:" .. engine.id, name = words, description = "Search " .. engine.name, material = "travel_explore",
      run = function() return browse(web.search_url(engine, words)) end,
      actions = { { name = "Copy the link", material = "content_copy", run = function() return copy(web.search_url(engine, words)) end } } } }
  end
  local out = {}
  if rest ~= "" then
    local e = web.ENGINES[1]
    out[1] = row { id = "web", name = rest, description = "Search " .. e.name, material = "travel_explore",
      run = function() return browse(web.search_url(e, rest)) end }
  end
  for _, e in ipairs(web.ENGINES) do
    out[#out + 1] = row { id = "engine:" .. e.id, name = e.name, description = "?" .. e.bang .. " …", material = "language",
      run = function() return "?" .. e.bang .. " " end }
  end
  return out
end

-- ----------------------------------------------------------------- windows --

local function windows(term)
  local ok, hyprland = pcall(require, "lib.integrations.hyprland")
  if not ok or not hyprland.available() then
    return { row { id = "windows", name = "No window list here", description = "It comes from Hyprland", material = "desktop_windows",
      run = function() return "keep" end } }
  end
  local list = {}
  local model = hyprland.state.clients
  for i = 1, model:len() do
    local c = model:get(i)
    if c.mapped ~= false and not c.hidden then
      list[#list + 1] = { client = c, name = c.title ~= "" and c.title or c.class,
        class = c.class, workspace = c.workspace }
    end
  end
  local out = {}
  for _, w in ipairs(fuzzy(list, term, { "name", { "class", 0.6 } })) do
    local c = w.client
    out[#out + 1] = row {
      id = "window:" .. c.address, name = w.name, description = c.class .. "  ·  workspace " .. tostring(c.workspace),
      icon = c.class:lower(), material = nil,
      run = function() hyprland.dispatch("focuswindow", "address:" .. c.address) return "close" end,
      actions = {
        { name = "Switch to it", material = "open_in_browser",
          run = function() hyprland.dispatch("focuswindow", "address:" .. c.address) return "close" end },
        { name = "Bring it here", material = "move_down",
          run = function()
            hyprland.dispatch("movetoworkspace", "+0,address:" .. c.address)
            return "close"
          end },
        { name = "Close it", material = "close",
          run = function() hyprland.dispatch("closewindow", "address:" .. c.address) return "close" end },
      },
    }
  end
  return out
end

-- ------------------------------------------------------------------ system --

-- A second Return confirms what cannot be taken back.
local armed = nil
local function confirmed(id, run)
  return function()
    if armed == id then armed = nil return run() end
    armed = id
    bump()
    return "keep"
  end
end

local function session(name)
  return function()
    local words = config.get("session.commands." .. name)
    if type(words) == "table" and #words > 0 then
      local user = (morf.env and morf.env("USER")) or ""
      local argv = {}
      for i, w in ipairs(words) do argv[i] = tostring(w):gsub("%$USER", user) end
      start(argv)
    end
    return "close"
  end
end

local function drawer(name, tab)
  return function()
    local d = require("drawer")[name]
    if tab and name == "sidebar" then require("sidebar").select(tab) end
    if tab and (name == "leftbar" or name == "bottom") then require(name).panel.select(tab) end
    if d then d.set(true) end
    return "close"
  end
end

local function system(term)
  local SYSTEM = {
    { id = "lock", name = "Lock the screen", material = "lock", run = function() start { "morf", "lock" } return "close" end },
    { id = "suspend", name = "Suspend", material = "bedtime", run = function() start { "systemctl", "suspend" } return "close" end },
    { id = "hibernate", name = "Hibernate", material = "downloading", run = confirmed("hibernate", session("hibernate")) },
    { id = "logout", name = "Log out", material = "logout", run = confirmed("logout", session("logout")) },
    { id = "reboot", name = "Restart", material = "restart_alt", run = confirmed("reboot", session("reboot")) },
    { id = "shutdown", name = "Power off", material = "power_settings_new", run = confirmed("shutdown", session("shutdown")) },
    { id = "dashboard", name = "Dashboard", material = "dashboard", run = drawer("dashboard") },
    { id = "settings", name = "Settings", material = "tune", run = drawer("sidebar", "settings") },
    { id = "notifications", name = "Notifications", material = "notifications", run = drawer("sidebar", "notifications") },
    { id = "capture", name = "Screenshot or record", material = "screenshot_monitor", run = drawer("capture") },
    { id = "assistant", name = "Assistant", material = "auto_awesome", run = drawer("bottom", "assistant") },
    { id = "tasks", name = "Tasks", material = "checklist", run = drawer("leftbar", "tasks") },
    { id = "calendar", name = "Calendar", material = "calendar_month", run = drawer("leftbar", "calendar") },
    { id = "screenshot", name = "Screenshot a region", material = "screenshot_region",
      run = function() require("capture").shoot("region") return "close" end },
    { id = "dnd", name = "Do not disturb", material = "notifications_off",
      run = function() local n = require("notifs") n.dnd:set(not n.dnd:get()) return "close" end },
    { id = "session", name = "Session menu", material = "power", run = drawer("session") },
  }
  local out = {}
  for _, s in ipairs(fuzzy(SYSTEM, term)) do
    out[#out + 1] = row {
      id = "system:" .. s.id, name = s.name, material = s.material, run = s.run,
      description = armed == s.id and "Press Return again to confirm" or ("!" .. s.id),
    }
  end
  return out
end

-- ------------------------------------------------------------------- emoji --

local function emoji(term)
  local out = {}
  for _, e in ipairs(require("lib.util.emoji").search(term, 60)) do
    out[#out + 1] = row {
      id = "emoji:" .. e.char, name = e.char .. "   " .. e.name, description = "Return copies it", material = nil,
      glyph = e.char,
      run = function() return copy(e.char) end,
      actions = { { name = "Copy its name", material = "content_copy", run = function() return copy(e.name) end } },
    }
  end
  return out
end

-- --------------------------------------------------------------- clipboard --

local function clipboard(term)
  local items = require("lib.integrations.clipse").history()
  local list = {}
  for i, item in ipairs(items) do
    local text = item.image ~= "" and ("Picture  " .. tilde(item.image)) or item.value:gsub("%s+", " ")
    list[#list + 1] = { item = item, name = text:sub(1, 200), order = i }
  end
  local out = {}
  for _, c in ipairs(fuzzy(list, term)) do
    local item = c.item
    out[#out + 1] = row {
      id = "clip:" .. c.order, name = c.name,
      description = (item.pinned and "Pinned  ·  " or "") .. item.recorded,
      material = item.image ~= "" and "image" or (item.pinned and "push_pin" or "content_paste"),
      run = function() require("lib.integrations.clipse").copy(item) return "close" end,
      actions = {
        { name = "Copy it back", material = "content_copy", run = function() require("lib.integrations.clipse").copy(item) return "close" end },
        { name = "Open the picture", material = "image", run = function()
          if item.image ~= "" then return open(item.image) end
          return "keep"
        end },
      },
    }
  end
  if #out == 0 then
    out[1] = row { id = "clip", name = "Nothing in the clipboard's history", description = "It comes from clipse",
      material = "content_paste_off", run = function() return "keep" end }
  end
  return out
end

-- ------------------------------------------------------------------ colour --

local function colour(text)
  local ok, c = pcall(morf.color, text:match("^#") and text or ("#" .. text))
  if not ok or not c then ok, c = pcall(morf.color, text) end
  if not ok or not c then
    return { row { id = "colour", name = "Type a colour", description = "#7c3aed, rgb(1, 2, 3), hsl(...), a name",
      material = "palette", run = function() return "keep" end } }
  end
  local r, g, b, a = c.r, c.g, c.b, c.a or 1
  local R, G, B = math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
  local max, min = math.max(r, g, b), math.min(r, g, b)
  local l = (max + min) / 2
  local s, h = 0, 0
  if max ~= min then
    local d = max - min
    s = l > 0.5 and d / (2 - max - min) or d / (max + min)
    if max == r then h = (g - b) / d + (g < b and 6 or 0)
    elseif max == g then h = (b - r) / d + 2
    else h = (r - g) / d + 4 end
    h = h * 60
  end
  local hex = c:hex()
  local forms = {
    { "HEX", hex },
    { "RGB", ("rgb(%d, %d, %d)"):format(R, G, B) },
    { "HSL", ("hsl(%d, %d%%, %d%%)"):format(math.floor(h + 0.5), math.floor(s * 100 + 0.5), math.floor(l * 100 + 0.5)) },
    { "RGBA", ("rgba(%d, %d, %d, %.2f)"):format(R, G, B, a) },
    { "Float", ("%.3f, %.3f, %.3f"):format(r, g, b) },
  }
  local out = {}
  for _, f in ipairs(forms) do
    out[#out + 1] = row { id = "colour:" .. f[1], name = f[2], description = f[1] .. "  ·  Return copies", swatch = hex,
      run = function() return copy(f[2]) end }
  end
  return out
end

-- ------------------------------------------------------------------ search --

M.PREFIXES = {
  ["="] = "calculator", ["$"] = "run", ["/"] = "files", ["~"] = "files", ["?"] = "web",
  ["@"] = "windows", ["!"] = "system", [":"] = "emoji", [";"] = "clipboard", ["#"] = "colour",
}

--- Rows for a query with a prefix, and the mode to draw them in; nil for a
--- query that has none (the launcher's own search goes on).
local SECTIONS = {
  calculator = "Calculator", run = "Run", files = "Files", web = "Web", windows = "Windows",
  system = "System", emoji = "Emoji", clipboard = "Clipboard", colour = "Colour",
}

local search_prefixed -- below

function M.search(query)
  local rows, mode = search_prefixed(query)
  if not rows then return nil end
  local what = M.PREFIXES[query:sub(1, 1)]
  for _, r in ipairs(rows) do r.section = r.section or SECTIONS[what] end
  return rows, mode
end

search_prefixed = function(query)
  M.revision:get()
  local first = query:sub(1, 1)
  local what = M.PREFIXES[first]
  if not what then return nil end
  local rest = query:sub(2):gsub("^%s+", "")
  if what == "calculator" then
    if rest == "" then
      return { row { id = "calc", name = "Type a sum, a conversion or a percentage", description = "2^10  ·  10ft in m  ·  20% off 80  ·  100 usd in eur",
        material = "calculate", run = function() return "keep" end } }, "apps"
    end
    local answer = M.inline(rest)
    if answer then return { answer }, "apps" end
    return { row { id = "calc", name = rest, description = "Not a sum I can read", material = "calculate",
      run = function() return "keep" end } }, "apps"
  elseif what == "run" then
    if rest == "" then
      return { row { id = "run", name = "Type a command", description = "Return runs it; Tab: in a terminal", material = "terminal",
        run = function() return "keep" end } }, "apps"
    end
    return { row {
      id = "run", name = rest, description = "Run it  ·  Tab for more", material = "terminal",
      run = function() start { "sh", "-c", rest } return "close" end,
      actions = {
        { name = "Run it", material = "play_arrow", run = function() start { "sh", "-c", rest } return "close" end },
        { name = "Run it in a terminal", material = "terminal",
          run = function() return terminal { "sh", "-c", rest .. '; printf "\\n[done] "; read _' } end },
        { name = "Copy the command", material = "content_copy", run = function() return copy(rest) end },
      },
    } }, "apps"
  elseif what == "files" then
    return files(first == "~" and rest or rest), "apps"
  elseif what == "web" then
    return websearch(rest), "apps"
  elseif what == "windows" then
    return windows(rest), "apps"
  elseif what == "system" then
    return system(rest), "apps"
  elseif what == "emoji" then
    return emoji(rest), "apps"
  elseif what == "clipboard" then
    return clipboard(rest), "apps"
  elseif what == "colour" then
    return colour(query), "apps"
  end
  return nil
end

--- The hint under the field: every prefix.
M.HINT = "apps  ·  = calc  ·  / files  ·  ? web  ·  @ windows  ·  ! system  ·  : emoji  ·  ; clipboard  ·  # colour  ·  $ run  ·  > shell"

return M
