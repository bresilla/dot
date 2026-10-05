-- Optional lock-screen readings. One set of readers per controller, shared by
-- every output and visual theme. No nodes or authentication data live here.
local morf = require("morf")
local M = {}
function M.new(options)
  local weather_lib, weather_source, media
  local weather_checked, media_checked = false, false
  local last_weather, last_player, last_art = {}, {}, ""
  local function weather_available()
    if not weather_checked then
      weather_checked = true
      local ok, lib = pcall(require, "lib.integrations.weather")
      if ok then weather_lib = lib end
    end
    return weather_lib ~= nil
  end
  local function media_available()
    if not media_checked then
      media_checked = true
      local ok, client = pcall(function() return require("lib.services.mpris").connect() end)
      if ok then media = client end
    end
    return media ~= nil
  end
  local function weather()
    if options.active() and weather_available() then
      weather_source = weather_source or weather_lib.new {units="metric"}
      last_weather = weather_source:get() or {}
    end
    return last_weather
  end
  return {for_output=function(output)
    local function visible() return options.active() and options.primary(output) end
    local function player()
      if visible() and media_available() then last_player = media.state.active or {} end
      return last_player
    end
    return {
      weather_available=weather_available, media_available=media_available,
      weather=weather,
      weather_symbol=function()
        local value=weather()
        return weather_available() and weather_lib.material_symbol(value.code,value.is_day) or "cloud"
      end,
      player=player,
      artwork=function()
        if visible() then last_art=require("lib.util.remote").file(player().art_url or "") end
        return last_art
      end,
      control=function(action)
        if not visible() or not ({previous=true,play_pause=true,next=true})[action] then return false end
        local dry=morf.env("CAELESTIA_DRY_RUN")
        if dry and dry~="" and dry~="0" then return false end
        if not media_available() or type(media[action])~="function" then return false end
        return pcall(media[action])
      end,
    }
  end}
end
return M
