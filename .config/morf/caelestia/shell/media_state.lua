-- Shared media state and actions. Themes own the artwork, layout and motion.
local morf = require("morf")
local services = require("services")
local spectrum = require("lib.util.spectrum")
local M = { BANDS = 56 }

-- ------------------------------------------------------------- visualiser --

-- The bars, 0 to 1: a data channel the audio monitor writes through the
-- spectrum filter in Rust and the spectrum draws -- no Lua per frame. The
-- monitor runs only while the tab is on screen and something plays.
local bars = morf.channel { name = "caelestia.media.bars", size = M.BANDS, mode = "frame" }
-- Beats heard: a count (the cover's shape turns on every fourth) and the
-- last one's strength (the cover swells with it).
local beats = morf.signal("caelestia.media.beats", 0)
local pulse = morf.signal("caelestia.media.pulse", 0)
local settle
local meter

local function listen(on)
  if on and not meter then
    local ok, m = pcall(morf.audio.monitor, {
      -- Held back as long as the output takes to play it (a Bluetooth
      -- headset's quarter of a second), so the ring moves with what is
      -- heard rather than ahead of it.
      rate_hz = 60, bands = 48, delay = "device",
      channel = bars, spectrum = spectrum.options { bars = M.BANDS },
      beat = true,
      on_beat = function(strength)
        beats:set(beats:get() + 1)
        pulse:set(math.max(0.3, math.min(1, strength or 0.5)))
        if settle then settle:cancel() end
        settle = morf.timer(90, function() settle = nil pulse:set(0) end, false)
      end,
    })
    meter = ok and m or false
  elseif not on and meter then
    pcall(function() meter:stop() end)
    meter = nil
    bars:set({})
    pulse:set(0)
  end
end

-- ---------------------------------------------------------------- lyrics --

local follow
local function lyrics()
  if follow == nil then
    follow = false
    if services.media then
      local ok, f = pcall(require("lib.integrations.lyrics").follow, services.media)
      if ok then follow = f end
    end
  end
  return follow or nil
end


M.bars, M.beats, M.pulse = bars, beats, pulse
M.lyrics = lyrics
M.active = services.player
M.something = services.playing_something
M.duration = services.duration
function M.playing() return M.active().playing == true end
function M.control(action, ...)
  local media = services.media
  if media and media[action] then pcall(media[action], ...) end
end
function M.watch(ctx)
  local function visible() return ctx.opened() and ctx.current() end
  morf.effect("caelestia.media.listen", function() listen(visible() and M.playing()) end)
  return visible
end
function M.field(name)
  return function()
    local value = M.active()[name]
    return type(value) == "table" and table.concat(value, ", ") or value or ""
  end
end
function M.fraction(visible)
  local last = 0
  return function()
    if not visible() then return last end
    local player = M.active()
    last = player.length and player.length > 0
      and math.max(0, math.min(1, (player.position or 0) / player.length)) or 0
    return last
  end
end
function M.seek(fraction)
  local length = M.active().length
  if length and length > 0 then M.control("set_position", math.max(0, math.min(1, fraction)) * length) end
end
function M.players()
  local media = services.media
  if not media or not media.state.available then return {} end
  local list, model = {}, media.state.players
  for i = 1, model:len() do list[#list + 1] = model:get(i) end
  return list
end
function M.lyric(offset)
  local follower = lyrics()
  if not follower then return "" end
  local line = follower.lines:get()[follower.index:get() + offset]
  return line and line.text or ""
end
function M.lyrics_status()
  local follower = lyrics()
  return follower and follower.status:get() or "none"
end
return M
