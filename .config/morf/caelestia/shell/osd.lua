-- The on-screen display's workings: the output's volume and the screen's
-- brightness, read and set, their icons, and the watch that shows a
-- change -- from anywhere: keys, another program -- as the right edge's
-- level pills swelling out (levels.lua). Over IPC: `osd`.
--
-- The volume is `morf.audio`'s default output; the brightness is the
-- backlight lib/sysinfo.lua reads (and writes when it may). Without either
-- the level rests at zero.

local morf = require("morf")

local M = {}

local audio = morf.audio
local sysinfo = require("lib.services.sysinfo")

function M.volume()
  local ok, sink = pcall(function() return audio and audio.available() and audio.default_sink() end)
  if not ok or not sink then return 0, true, false end
  return sink.volume or 0, sink.muted, true
end

function M.brightness()
  local ok, b = pcall(sysinfo.backlight)
  if not ok or not b or not b.percent then return 0, false end
  return b.percent / 100, true
end

function M.set_volume(v)
  local ok, sink = pcall(function() return audio.default_sink() end)
  if ok and sink then pcall(audio.set_volume, sink.id, math.max(0, math.min(1, v))) end
end

function M.set_brightness(v)
  pcall(sysinfo.set_brightness, math.max(1, math.min(100, v * 100)))
end

local volume, brightness = M.volume, M.brightness

--- The icon for a volume, and for a brightness.
function M.volume_icon()
  local v, muted = volume()
  if muted or v <= 0 then return "volume_mute" end
  if v < 0.5 then return "volume_down" end
  return "volume_up"
end
function M.brightness_icon()
  local b = brightness()
  if b < 0.34 then return "brightness_low" end
  if b < 0.67 then return "brightness_medium" end
  return "brightness_high"
end

--- Shows `kind` ("volume", the default, or "brightness") for a moment.
function M.flash(kind)
  require("levels").pop(kind or "volume")
end

-- A change is a reading that moved from one known value to another: the
-- first reading of either, when its service answers, is not one.
local seen_volume, seen_brightness
morf.effect("caelestia.osd.follow", function()
  local v, muted, known_v = volume()
  local b, known_b = brightness()
  local changed
  if known_v then
    local now = ("%.3f/%s"):format(v, tostring(muted))
    if seen_volume and now ~= seen_volume then changed = "volume" end
    seen_volume = now
  end
  if known_b then
    local now = ("%.3f"):format(b)
    if seen_brightness and now ~= seen_brightness then changed = "brightness" end
    seen_brightness = now
  end
  -- On the focused screen only: every screen hears the change. Not while
  -- the settings, whose own sliders show it, are open.
  local sidebar = package.loaded["sidebar"]
  local shown_there = type(sidebar) == "table" and sidebar.drawer and sidebar.drawer.open:get()
    and sidebar.showing("settings")
  if changed and not shown_there and require("services").here() then M.flash(changed) end
end)

return M
