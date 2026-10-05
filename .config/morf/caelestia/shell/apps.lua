-- The launcher's lists: installed applications, ranked by `morf.text.fuzzy`
-- and lifted by how often and how lately each was launched from here
-- (lib/frecency.lua); and, after the action prefix (">"), the shell's own
-- actions, and the pickers some of them open: "> scheme " (source
-- colours), "> variant " (Material 3 scheme variants), "> wallpaper " (the
-- pictures in ~/Pictures/Wallpapers) and "> calc " (calc.lua).

local morf = require("morf")
local frecency = require("lib.util.frecency")
local config = require("config")
local calc = require("calc")

local M = {}

local index
local rows = {}

--- Reads the desktop entries again; true when they changed.
function M.refresh()
  if not index then
    local ok, made = pcall(morf.desktop_entries)
    if not ok then
      morf.log("warn", "caelestia: cannot read the applications: " .. tostring(made))
      return false
    end
    index = made
  else
    local ok, changed = pcall(index.refresh, index)
    if not ok or not changed then return false end
  end
  local list, seen = {}, {}
  local ok, all = pcall(index.applications, index)
  if not ok or type(all) ~= "table" then return false end
  for _, entry in ipairs(all) do
    local name = (entry.name or ""):match("^%s*(.-)%s*$")
    if not entry.no_display and name ~= "" and not seen[entry.id] then
      seen[entry.id] = true
      local comment = (entry.comment or ""):match("^%s*(.-)%s*$")
      if comment == "" then comment = entry.generic_name or "" end
      list[#list + 1] = {
        kind = "app",
        id = entry.id,
        name = name,
        description = comment,
        icon = entry.icon or "",
        keywords = table.concat(entry.keywords or {}, " "),
      }
    end
  end
  table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
  rows = list
  return true
end

M.refresh()

local used = frecency.open { path = morf.state_path("caelestia-launches.json") }

-- ---------------------------------------------------------------- actions --

-- The shell's own actions, as the reference lists them after ">".
-- `run(query)` returns what the launcher does next: "close", or a new query.
M.ACTIONS = {
  { id = "calc", name = "Calculator", description = "Do simple maths equations", icon = "calculate",
    run = function() return "> calc " end },
  { id = "scheme", name = "Scheme", description = "Change the current colour scheme", icon = "palette",
    run = function() return "> scheme " end },
  { id = "wallpaper", name = "Wallpaper", description = "Change the current wallpaper", icon = "image",
    run = function() return "> wallpaper " end },
  { id = "variant", name = "Variant", description = "Change the current scheme variant", icon = "format_paint",
    run = function() return "> variant " end },
  { id = "random", name = "Random", description = "Switch to a random wallpaper", icon = "casino",
    run = function()
      local pics = M.wallpapers()
      if #pics > 0 then require("wallpaper").set(pics[math.random(#pics)].path) end
      return "close"
    end },
  { id = "light", name = "Light", description = "Change the scheme to light mode", icon = "light_mode",
    run = function() config.set("theme.mode", "light") return "close" end },
  { id = "dark", name = "Dark", description = "Change the scheme to dark mode", icon = "dark_mode",
    run = function() config.set("theme.mode", "dark") return "close" end },
}
for _, a in ipairs(M.ACTIONS) do a.kind = "action" end

-- ---------------------------------------------------------------- pickers --

--- The source colours "> scheme " offers: the wallpaper's, then named
--- ones. Each builds a Material 3 scheme through lib/material.lua.
M.SCHEMES = {
  { id = "wallpaper", name = "Dynamic", description = "Colours from the wallpaper", color = nil },
  { id = "#ffb0ca", name = "Rosé", description = "A soft pink" },
  { id = "#f4a261", name = "Apricot", description = "A warm orange" },
  { id = "#e9c46a", name = "Saffron", description = "A mellow yellow" },
  { id = "#8fbf7f", name = "Sage", description = "A quiet green" },
  { id = "#4fb3bf", name = "Lagoon", description = "A clear teal" },
  { id = "#7aa2f7", name = "Cornflower", description = "A calm blue" },
  { id = "#b39ddb", name = "Lavender", description = "A light violet" },
  { id = "#e57373", name = "Coral", description = "A bright red" },
  { id = "#9e9e9e", name = "Graphite", description = "Hardly any colour" },
}

--- The variants "> variant " offers, in lib/material.lua's names.
M.VARIANTS = {
  { id = "vibrant", name = "Vibrant", icon = "sentiment_very_dissatisfied",
    description = "Colours at their fullest, the accents pushed to the edge of the gamut." },
  { id = "tonal_spot", name = "Tonal Spot", icon = "android",
    description = "The default: calm, pastel accents with a little colour in the greys." },
  { id = "expressive", name = "Expressive", icon = "compare_arrows",
    description = "The accents turned away from the source's hue for a livelier mix." },
  { id = "fidelity", name = "Fidelity", icon = "compare",
    description = "Keeps the source colour as it is, however bright or dark." },
  { id = "content", name = "Content", icon = "sentiment_satisfied",
    description = "Much like fidelity: follows the source closely." },
  { id = "fruit_salad", name = "Fruit Salad", icon = "nutrition",
    description = "Playful: the accents wander well away from the source's hue." },
  { id = "rainbow", name = "Rainbow", icon = "looks",
    description = "Playful: bright accents over plain grey surfaces." },
  { id = "neutral", name = "Neutral", icon = "contrast",
    description = "Almost grey: only a hint of the source colour." },
  { id = "monochrome", name = "Monochrome", icon = "filter_b_and_w",
    description = "Greys only, with no colour at all." },
}

local PICTURE = { jpg = true, jpeg = true, png = true, webp = true, gif = true }

--- The pictures in ~/Pictures/Wallpapers (and the current one), by name:
--- `{ path, name }` each.
function M.wallpapers()
  local dir = morf.fs.home() .. "/Pictures/Wallpapers"
  local ok, entries = pcall(morf.fs.list, dir)
  local out, seen = {}, {}
  if ok and type(entries) == "table" then
    for _, e in ipairs(entries) do
      if e.is_file and PICTURE[(e.extension or ""):lower()] and not seen[e.path] then
        seen[e.path] = true
        out[#out + 1] = { path = e.path, name = e.name or e.path:match("([^/]+)$") }
      end
    end
  end
  local current = require("wallpaper").current:get()
  if current ~= "" and not seen[current] then
    out[#out + 1] = { path = current, name = current:match("([^/]+)$") }
  end
  table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
  return out
end

-- ----------------------------------------------------------------- search --

local function picked(list, term, kind, make)
  local hits = morf.text.fuzzy(term, list, { key = { "name", { "description", 0.3 } } })
  local out = {}
  for _, hit in ipairs(hits) do out[#out + 1] = make(hit.item) end
  return out
end

--- What `query` finds: `rows, mode` -- rows best first (apps, actions,
--- schemes, variants, wallpapers or one calculation) and the mode the
--- launcher draws them in: "apps", "actions", "schemes", "variants",
--- "wallpapers" or "calc".
function M.search(query, limit)
  -- A prefix of providers.lua's: its rows alone.
  local providers = require("providers")
  local routed, routed_mode = providers.search(query)
  if routed then return routed, routed_mode end
  local prefix = config.get("launcher.action_prefix")
  if query:sub(1, #prefix) == prefix then
    local rest = query:sub(#prefix + 1):gsub("^%s+", "")
    local word, after = rest:match("^(%a+)%s(.*)$")
    word = word and word:lower()
    if word == "scheme" then
      local source = config.get("theme.source")
      return picked(M.SCHEMES, after:match("^%s*(.-)%s*$"), "scheme", function(item)
        return {
          kind = "scheme", id = item.id, name = item.name, icon = "palette",
          description = item.id == "wallpaper" and item.description or (item.description .. " · " .. item.id),
          color = item.id ~= "wallpaper" and item.id or nil, current = source == item.id,
          run = function() config.set("theme.source", item.id) return "close" end,
        }
      end), "schemes"
    elseif word == "variant" then
      local variant = config.get("theme.variant")
      return picked(M.VARIANTS, after:match("^%s*(.-)%s*$"), "variant", function(item)
        return {
          kind = "variant", id = item.id, name = item.name, icon = item.icon, description = item.description,
          current = variant == item.id,
          run = function() config.set("theme.variant", item.id) return "close" end,
        }
      end), "variants"
    elseif word == "wallpaper" then
      local term = after:match("^%s*(.-)%s*$")
      local list = M.wallpapers()
      local out = {}
      if term == "" then
        out = list
      else
        for _, hit in ipairs(morf.text.fuzzy(term, list, { key = "name" })) do out[#out + 1] = hit.item end
      end
      local rows = {}
      for _, w in ipairs(out) do
        rows[#rows + 1] = {
          kind = "wallpaper", id = w.path, name = w.name, description = w.path, icon = "image", path = w.path,
          run = function() require("wallpaper").set(w.path) return "close" end,
        }
      end
      return rows, "wallpapers"
    elseif word == "calc" then
      local value, shown, result = calc.evaluate(after)
      if not value then
        return { {
          kind = "calc", id = "calc", name = after:match("^%s*(.-)%s*$") == "" and "Type an expression" or shown,
          description = "", icon = "function", failed = true, run = function() return "keep" end,
        } }, "calc"
      end
      return { {
        kind = "calc", id = "calc", name = shown, description = result, icon = "function", result = result,
        run = function()
          pcall(morf.clipboard.set, result)
          return "close"
        end,
      } }, "calc"
    end
    local term = rest:match("^%s*(.-)%s*$")
    local hits = morf.text.fuzzy(term, M.ACTIONS, { key = { "name", { "description", 0.3 } } })
    local out = {}
    for _, hit in ipairs(hits) do out[#out + 1] = hit.item end
    return out, "actions"
  end
  local hits = used.rank(query, rows, {
    key = { "name", { "keywords", 0.4 }, { "description", 0.2 } },
    id = "id",
  })
  -- An answer first (a sum, a conversion, an address), the apps, then
  -- what else to do with the words: search the web or the files.
  providers.revision:get()
  local answer = providers.inline(query)
  local fallbacks = providers.fallbacks(query)
  local room = limit and math.max(1, limit - #fallbacks - (answer and 1 or 0)) or nil
  local out = {}
  if answer then out[1] = answer end
  local apps_found = 0
  for _, hit in ipairs(M.strict(query, hits)) do
    out[#out + 1] = hit.item
    apps_found = apps_found + 1
    if room and apps_found >= room then break end
  end
  for _, f in ipairs(fallbacks) do out[#out + 1] = f end
  return out, "apps"
end

--- Whether a match's characters are one unbroken run (bytes in order,
--- each character right after the one before).
local function contiguous(text, positions)
  for i = 2, #(positions or {}) do
    local prev = positions[i - 1]
    local step = utf8.offset(text, 2, prev)
    if not step or positions[i] ~= step then return false end
  end
  return true
end

--- Whether every run of matched characters starts a word: "lw" in
--- "LibreOffice Writer", "ki" in "kitty", not "fire" strung through
--- "LibreOffice Impress".
local function at_words(text, positions)
  local prev
  for _, p in ipairs(positions or {}) do
    local continues = prev and utf8.offset(text, 2, prev) == p
    if not continues then
      local before = p > 1 and text:sub(p - 1, p - 1) or ""
      local here = text:sub(p, p)
      local starts = p == 1 or before:match("[%s%-_%./]")
        or (before:match("%l") and here:match("%u"))
      if not starts then return false end
    end
    prev = p
  end
  return true
end

--- The fuzzy hits worth showing, as the reference is strict about them: a
--- match in a name may skip letters only from one word to the start of the
--- next; one found only in the keywords or the description must be the
--- query as written, in one run; and nothing scoring under half the best
--- hit's score is listed. "fire" finds Firefox, not LibreOffice with an f,
--- an i, an r and an e somewhere in it.
function M.strict(query, hits)
  if (query or "") == "" then return hits end
  local best = 0
  for _, hit in ipairs(hits) do best = math.max(best, hit.score or 0) end
  local out = {}
  for _, hit in ipairs(hits) do
    local ok = (hit.score or 0) >= best * 0.5
    if ok and hit.key == "name" then
      ok = at_words(tostring(hit.item.name or ""), hit.positions)
    elseif ok then
      -- Every term of the query in one run somewhere in that field.
      local text = tostring(hit.item[hit.key] or ""):lower()
      for term in query:lower():gmatch("%S+") do
        if not text:find(term, 1, true) then ok = false break end
      end
      if ok and not query:find("%s") then ok = contiguous(tostring(hit.item[hit.key] or ""), hit.positions) end
    end
    if ok then out[#out + 1] = hit end
  end
  return out
end

--- Runs a row: launches an app (and remembers it), or an action. Returns
--- "close" or a new query.
function M.activate(row)
  if not row then return "keep" end
  if row.kind == "app" then
    used.record(row.id)
    local ok, err = pcall(index.launch, index, row.id)
    if not ok then morf.log("warn", "caelestia: could not launch " .. row.id .. ": " .. tostring(err)) end
    return "close"
  end
  return row.run() or "close"
end

-- ------------------------------------------------------------------ icons --

local found = {}

--- `{ name }` for a themed icon, `{ path }` for a file, or nil.
function M.icon(name)
  name = tostring(name or "")
  if name == "" then return nil end
  if found[name] ~= nil then return found[name] or nil end
  local hit
  if name:sub(1, 1) == "/" then
    hit = morf.fs.exists(name) and { path = name } or nil
  else
    local ok, has = pcall(morf.has_icon, name)
    if ok and has then hit = { name = name }
    else
      for _, ext in ipairs { ".svg", ".png" } do
        local path = "/usr/share/pixmaps/" .. name .. ext
        if morf.fs.exists(path) then hit = { path = path } break end
      end
    end
  end
  found[name] = hit or false
  return hit
end

return M
