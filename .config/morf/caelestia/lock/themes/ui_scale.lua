-- One small preference shared by the shell, lock and greeter. NixOS supplies
-- a public, user-owned path so greetd can read the scale without home access.
local morf = require("morf")
local M = {}
M.compositor = morf.env("CAELESTIA_SCALE_MODE") == "compositor"
M.path = morf.env("CAELESTIA_SCALE_FILE")
  or ((morf.env("XDG_STATE_HOME") or (morf.fs.home() .. "/.local/state")) .. "/caelestia/scale.json")
local base = tonumber(morf.env("CAELESTIA_SCALE_DEFAULT")) or 1
base = math.max(.5, math.min(2, base))
local default = math.log(base) / math.log(2)
local function valid(value)
  return type(value) == "number" and value == value and value >= -1 and value <= 1
end
local function read(path)
  local ok, value = pcall(function() return morf.json.decode(morf.fs.read(path)) end)
  return ok and type(value) == "table" and value or nil
end
local stored = read(M.path)
local saved = stored and valid(stored.zoom)
local zoom = morf.signal("caelestia.shared-scale", saved and stored.zoom or default)
function M.get() return zoom:get() end
function M.factor() return M.compositor and 1 or 2 ^ M.get() end
-- Hyprland accepts fractional scales in 1/120 steps that leave whole
-- logical pixels. Offer those values, rather than a zoom value it silently
-- replaces with another scale (for example 1.7 becomes 1.8 on the FP6).
function M.display_scale(value)
  local requested = 2 ^ value
  local screen = (morf.screens or {})[1] or {}
  local w, h = screen.pixel_width, screen.pixel_height
  if not M.compositor or not w or not h or w <= 0 or h <= 0 then return requested end
  local best, distance = 1, math.huge
  for units = 60, 240 do
    if (w * 120) % units == 0 and (h * 120) % units == 0 then
      local scale = units / 120
      local delta = math.abs(scale - requested)
      if delta <= distance then best, distance = scale, delta end
    end
  end
  return best
end
function M.set(value)
  value = tonumber(value)
  if not valid(value) then return false, "Scale must be between -1 and 1" end
  local preference = { zoom = value }
  if M.compositor then
    preference.scale = M.display_scale(value)
    value = math.log(preference.scale) / math.log(2)
    preference.zoom = value
    preference.output = ((morf.screens or {})[1] or {}).name or ""
  end
  local ok, err = morf.fs.write(M.path, morf.json.encode(preference), { mode = 420, atomic = true, parents = true })
  if not ok then return false, err end
  saved = true
  zoom:set(value)
  if M.compositor then
    local hypr = require("lib.integrations.hyprland")
    if hypr.available() then
      hypr.eval(("hl.monitor({output=%q, scale=%.8f})"):format(preference.output, preference.scale), function(_, err)
        if err then morf.log("warn", "Could not change Hyprland display scale: " .. tostring(err)) end
      end)
    end
  end
  return true
end
M.watch = morf.fs.watch(M.path, function()
  local value = read(M.path)
  if value and valid(value.zoom) then saved = true zoom:set(value.zoom) end
end)

-- Keep the existing slider/config API, migrating its old per-shell value once.
-- Authentication processes only read this module; they never migrate or save.
function M.link(config)
  if not saved then
    local legacy = config.path and read(config.path)
    legacy = legacy and legacy.appearance and legacy.appearance.zoom
    local value = valid(legacy) and legacy or default
    if morf.env("CAELESTIA_DRY_RUN") == "1" then
      -- The launcher's validation uses a synthetic HEADLESS-1 output.
      -- It must not save that name as the real display's preference.
      zoom:set(value)
    else
      local ok, err = M.set(value)
      if not ok then morf.log("warn", "Could not save shared UI scale: " .. tostring(err)) end
    end
  end
  local get, set, reset = config.get, config.set, config.reset
  config.get = function(key) if key == "appearance.zoom" then return M.get() end return get(key) end
  config.set = function(key, value) if key == "appearance.zoom" then return M.set(value) end return set(key, value) end
  config.reset = function(key) if key == "appearance.zoom" then return M.set(default) end return reset(key) end
  return config
end
function M.apply()
  if morf.density then morf.density(M.compositor and "compositor" or { zoom = M.factor() }) end
end
return M
