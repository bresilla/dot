-- The colours the desk's colour tool set for the terminals: lule, pywal,
-- wallust -- whatever writes the escape sequences every terminal takes.
--
-- The shell holds a terminal of its own (`morf.terminal.listen`), so the
-- tool's loop over /dev/pts/* writes to it too and the shell re-themes the
-- moment the tool runs. Until it does, or when the shell starts, the files
-- the tools keep are read instead: lule's colors.json, then pywal's
-- sequences. `M.current` is `{ accent, mode, wallpaper, palette }` (the
-- palette: `color0`..`color15`, `background`, `foreground`, `cursor` as
-- hex), or nil when no tool has set anything. theme.lua shows it as
-- `theme.lule`, beside the Material scheme in `theme.color`.

local morf = require("morf")
local lule = require("lib.integrations.lule")

local M = {}

-- A background this dark or darker is a dark scheme.
local function mode_of(background)
  if not background then return nil end
  local ok, color = pcall(morf.color, background)
  if not ok then return nil end
  local _, _, tone = color:hct()
  return tone < 50 and "dark" or "light"
end

local function hex(c) return c and (type(c) == "string" and c or c:hex()) or nil end

-- The sixteen, and the three a terminal draws with, as hex.
local function flat(colors, background, foreground, cursor)
  local out = { background = hex(background), foreground = hex(foreground), cursor = hex(cursor) }
  for i = 0, 15 do out["color" .. i] = hex(colors and colors[i + 1]) end
  return out
end

local function from_palette(palette)
  local accent = palette.colors and palette.colors[2] or palette.cursor
  if not accent then return nil end
  return {
    accent = hex(accent),
    mode = mode_of(hex(palette.background)),
    palette = flat(palette.colors, palette.background, palette.foreground, palette.cursor),
  }
end

local function from_files()
  local scheme = lule.read()
  if scheme then
    return {
      accent = scheme.accent, mode = scheme.theme, wallpaper = scheme.wallpaper,
      palette = flat(scheme.colors, scheme.background, scheme.foreground, scheme.cursor),
    }
  end
  local wal = morf.fs.join(morf.fs.home(), ".cache/wal/sequences")
  local ok, text = pcall(morf.fs.read, wal)
  if ok and type(text) == "string" and text ~= "" then
    return from_palette(morf.terminal.parse(text))
  end
  return nil
end

M.current = morf.signal("caelestia.terminal_colors", from_files())

-- The files: lule rewrites its scheme as it sets the terminals.
lule._watch_handle = morf.fs.watch(lule.path(), function()
  local now = from_files()
  if now then M.current:set(now) end
end)

-- The terminal: whatever the tool writes to every terminal, this hears.
if morf.terminal and morf.terminal.listen then
  local ok, tty = pcall(morf.terminal.listen, function(palette)
    local heard = from_palette(palette)
    if not heard then return end
    local was = M.current:get() or {}
    heard.wallpaper = was.wallpaper
    heard.mode = heard.mode or was.mode
    M.current:set(heard)
  end)
  if ok then
    M.tty = tty
    morf.log("info", "caelestia: listening for the colour tool on " .. tostring(tty.path))
  else
    morf.log("warn", "caelestia: no terminal to hear the colour tool on: " .. tostring(tty))
  end
end

return M
