-- Wallpaper-derived colors, independent of the selected visual theme.
--
-- Colours are a Material 3 scheme (lib/material.lua): every role --
-- primary, onSurfaceVariant, surfaceContainerHigh, ... -- is a token of one
-- `morf.theme`, so a binding that reads `theme.color.primary` follows a new
-- wallpaper with no wiring. The scheme comes from the wallpaper (tonal_spot,
-- dark) unless the settings name a source colour.
--
-- Sizes were measured off the reference at 1920x1080: a 10 px frame, a
-- 60 px bar, 25 px corners, 40 px pills.

local morf = require("morf")
local material = require("lib.util.material")
local config = require("config")

local M = {}

-- ------------------------------------------------------------------ colour --

-- A pink source until the wallpaper's scheme is in: the colours the
-- reference shows before it has a scheme of its own.
M.FALLBACK_SOURCE = "#ffb0ca"

local function initial()
  local source = config.get("theme.source")
  if source == "" or source == "wallpaper" or source == "auto" or source == "lule" then
    source = M.FALLBACK_SOURCE
  end
  return material.scheme(source, { variant = config.get("theme.variant"), mode = config.get("theme.mode") })
end

local roles = {}
for name, value in pairs(initial()) do
  local ok, red = pcall(function() return value.r end)
  if type(value) ~= "string" and ok and type(red) == "number" then roles[name] = value end
end
-- A new scheme, variant or mode eases every colour there, as one.
local session = require("themes.session")
for name,value in pairs(session.restore("palette",{})) do if roles[name] then roles[name]=morf.color(value) end end
M.color = morf.theme(roles, { transition = { duration = 400, easing = "in_out_cubic" } })

session.register("palette",function()
  local saved={}
  for name in pairs(roles) do saved[name]=M.color[name]:hex() end
  return saved
end)

-- The colour tool's own palette (lule, pywal: terminal_colors.lua), beside
-- the Material scheme: `theme.lule.accent`, `.background`, `.foreground`,
-- `.cursor`, `.color0`..`.color15`. A part that wants the desk's terminal
-- colours rather than Material's reads these; they ease to new values as
-- the tool re-themes. Grey until a tool has set anything.
local lule_tokens = { accent = "#888888", background = "#111111", foreground = "#eeeeee", cursor = "#888888" }
for i = 0, 15 do lule_tokens["color" .. i] = "#888888" end
M.lule = morf.theme(lule_tokens, { transition = { duration = 400, easing = "in_out_cubic" } })

--- Puts the colour tool's palette in `theme.lule`.
function M.apply_lule(tool)
  if not tool then return end
  if tool.accent then M.lule.accent = tool.accent end
  for name, value in pairs(tool.palette or {}) do
    if value and lule_tokens[name] then M.lule[name] = value end
  end
end

--- Puts every role of scheme `s` in place.
function M.apply(s)
  for name in pairs(roles) do
    if s[name] ~= nil then M.color[name] = s[name] end
  end
end

--- The scheme for `source` (a colour, or "wallpaper" with `wallpaper` the
--- picture's path), applied when it is made.
function M.follow(source, wallpaper, mode)
  local opts = { variant = config.get("theme.variant"), mode = mode or config.get("theme.mode") }
  if source ~= "wallpaper" and source ~= "" then
    M.apply(material.scheme(source, opts))
    return
  end
  if not wallpaper or wallpaper == "" then return end
  material.from_image(wallpaper, opts, function(ok, s)
    if ok then M.apply(s) else morf.log("warn", "caelestia: no scheme from the wallpaper: " .. tostring(s)) end
  end)
end

return M
