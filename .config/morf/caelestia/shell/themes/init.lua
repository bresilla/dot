-- Theme packages own appearance, never wallpaper colors or application state.
local morf = require("morf")
local settings = require("lib.util.settings")
local root = morf.env("XDG_CONFIG_HOME") or (morf.fs.home() .. "/.config")
-- make apply supplies a readable default beside each installed config. The
-- greeter has no personal settings; a user's explicit preference still wins.
local defaults = { theme = "material", font = "" }
do
  local ok, value = pcall(function()
    return morf.json.decode(morf.fs.read(morf.config_path("appearance-default.json")))
  end)
  if ok and type(value) == "table" then
    if type(value.theme) == "string" then defaults.theme = value.theme end
    if type(value.font) == "string" then defaults.font = value.font end
  end
end
local preferences = settings.open {
  path = morf.env("CAELESTIA_APPEARANCE") or (root .. "/morf/caelestia/appearance.json"),
  name = "caelestia.appearance", defaults = defaults,
}
local M = { preferences = preferences }
function M.load(name)
  assert(type(name) == "string" and name:match("^[a-z][a-z0-9_]*$"), "Invalid visual theme name")
  local package = require("themes." .. name .. ".manifest")
  assert(package.api == 1 and package.id == name, "Incompatible visual theme: " .. name)
  assert(type(package.tokens) == "table" and type(package.components) == "string", "Incomplete visual theme: " .. name)
  return package
end
local session = require("themes.session")
M.font = session.font
if M.font == nil then M.font = preferences.get("font") end
local requested = session.target or morf.env("CAELESTIA_STYLE") or preferences.get("theme")
-- Futuristic was folded into Tsugumori: a saved choice of it lands there.
if requested == "futuristic" then requested = "tsugumori" end
local ok, package = pcall(M.load, requested)
if not ok then
  morf.log("warn", "caelestia: " .. tostring(package) .. "; using Material")
  package = M.load("material")
end
M.current = package
-- A theme may reuse another theme's individual views while replacing others.
-- This is explicit inheritance, not an implicit fallback for misspelled files.
function M.view(name)
  local selected, seen = M.current, {}
  while selected do
    assert(not seen[selected.id], "Visual theme inheritance cycle")
    seen[selected.id] = true
    local module = (selected.views or {})[name]
    if module then return require(module) end
    selected = selected.inherits and M.load(selected.inherits) or nil
  end
  error("Visual theme " .. M.current.id .. " has no view: " .. name)
end
return M
