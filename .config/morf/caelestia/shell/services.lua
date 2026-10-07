-- What the bar and the dashboard read, each as a function a binding can
-- call: the compositor's workspaces and window (lib/hyprland.lua, Hyprland
-- only; elsewhere one workspace and "Desktop"), the network, Bluetooth and
-- power (NetworkManager, BlueZ, UPower over D-Bus; absent services read as
-- off, never started).

local morf = require("morf")
local hyprland = require("lib.integrations.hyprland")

local M = {}

local function quiet_connect(name)
  local ok, lib = pcall(require, "lib." .. name)
  if not ok then return nil end
  local ok2, service = pcall(lib.connect)
  if ok2 then return service end
  morf.log("warn", "caelestia: " .. name .. " unavailable: " .. tostring(service))
end

-- ------------------------------------------------------------ workspaces --

M.workspace = {}

-- Off Hyprland there are no workspaces to switch; the bar still moves its
-- indicator where it is clicked (and `workspace N` over IPC), so the
-- control answers.
local local_workspace = morf.signal("caelestia.workspace", 1)

-- The output this runtime draws on (every screen runs the shell once).
local function screen_name()
  return (morf.screens and morf.screens[1] and morf.screens[1].name) or ""
end
M.output = screen_name

-- Capture a destination once per authentication request. Later PAM updates
-- must not open a second dialog just because monitor focus has changed.
function M.active_output()
  if hyprland.available() then
    local focused=hyprland.state.focused_monitor
    if focused and focused~="" then return focused end
  end
  return screen_name()
end

-- This screen's row in the compositor's monitors, if it has one.
local function this_monitor()
  local model = hyprland.state.monitors
  local name = screen_name()
  if not model or name == "" then return nil end
  for i = 1, model:len() do
    local row = model:get(i)
    if row.name == name then return row end
  end
  return nil
end

--- The workspace on show on this screen: each monitor's bar shows its
--- own, as the reference's do; the focused one's when this screen is not
--- among the compositor's monitors.
function M.workspace.active()
  if not hyprland.available() then return local_workspace:get() end
  local monitor = this_monitor()
  local id = monitor and monitor.active_workspace or hyprland.state.active_workspace.id
  if type(id) ~= "number" or id < 1 then return 1 end
  return id
end

--- Whether this screen is the one things opened by a key or a verb appear
--- on: the focused monitor on Hyprland, the primary screen elsewhere.
--- Every screen runs the shell and hears every verb; only this one acts.
function M.here()
  if hyprland.available() then
    local focused = hyprland.state.focused_monitor
    if focused and focused ~= "" then return focused == screen_name() end
  end
  if morf.primary then return morf.primary() end
  return true
end

function M.workspace.occupied(id)
  local model = hyprland.state.workspaces
  for i = 1, model:len() do
    local row = model:get(i)
    if row.id == id then return (row.windows or 0) > 0 end
  end
  return false
end

function M.workspace.go(id)
  if hyprland.available() then hyprland.dispatch("workspace", tostring(id))
  else local_workspace:set(math.max(1, math.floor(tonumber(id) or 1))) end
end

function M.workspace.step(delta)
  if hyprland.available() then hyprland.dispatch("workspace", (delta > 0 and "r+1" or "r-1"))
  else local_workspace:set(math.max(1, local_workspace:get() + (delta > 0 and 1 or -1))) end
end

-- ---------------------------------------------------------------- window --

M.window = {}

function M.window.title()
  local w = hyprland.state.active_window
  local title = w.title or ""
  if title == "" then title = w.class or "" end
  if title == "" then return "Desktop" end
  return title
end

-- --------------------------------------------------------------- network --

local net = quiet_connect("networkmanager")
local bt = quiet_connect("bluez")
local power = quiet_connect("upower")

-- The services themselves, for the popouts (nil when absent).
M.net, M.bt, M.upower = net, bt, power

-- Keep the modem observer even before ModemManager or its hardware appears.
-- The ring mode (lib/ringer.lua): feedbackd's profile on a phone, the shell's own
-- setting elsewhere.
do
  local ok, modem = pcall(require, "lib.services.modem")
  local mobile = ok and select(2, pcall(modem.connect)) or nil
  if type(mobile) == "table" and mobile.state then M.modem = mobile end
  -- CAELESTIA_FAKE_MODEM=1: a stand-in, to see a phone's parts on a laptop.
  local fake = morf.env and morf.env("CAELESTIA_FAKE_MODEM")
  if fake and fake ~= "" and fake ~= "0" and not (M.modem and M.modem.state.available) then
    local state = morf.state { available = true, signal = 72, technology = "5G", operator = "Vodafone NL",
      registered = true, connected = true, enabled = true, locked = false, data = true,
      sim_present = true, roaming = false, path = "/fake" }
    M.modem = { state = state, set_data = function(on) state.data = on == true end }
  end
end
do
  local config = require("config")
  local ok, ringer = pcall(require, "lib.util.ringer")
  local ring = ok and select(2, pcall(ringer.connect, { mode = config.get("ringer.mode") })) or nil
  if type(ring) == "table" and ring.state then
    M.ringer = ring
    morf.effect("caelestia.ringer.remember", function()
      local mode = ring.state.mode
      if config.get("ringer.mode") ~= mode then config.set("ringer.mode", mode) end
    end)
  end
end

-- Tor (lib/tor.lua), where it is installed: the system's tor service,
-- started and stopped from the quick settings and never enabled, so every
-- boot starts without it. Up is told by its SOCKS port listening -- a look
-- at /proc every few seconds, no command.
do
  local installed = morf.fs.exists("/usr/bin/tor") or morf.fs.exists("/usr/local/bin/tor")
  local ok, tor = pcall(require, "lib.integrations.tor")
  if ok and installed then
    local t = tor.new { unit = "tor.service", socks = 9050 }
    -- "off", "starting", "on", "stopping" or "failed"
    local phase = morf.signal("caelestia.tor.phase", t.up() and "on" or "off")
    local progress = morf.signal("caelestia.tor.progress", "")
    local function look()
      local up = t.up()
      local p = phase:get()
      if up then
        if p ~= "stopping" and p ~= "on" then phase:set("on") end
        if p == "starting" or p == "on" then
          t.bootstrap(function(pct, what)
            progress:set(pct and (pct < 100 and ("%d%% · %s"):format(pct, what or "") or "Connected") or "")
          end)
        end
      elseif p ~= "starting" and p ~= "failed" and p ~= "off" then
        phase:set("off")
      end
    end
    morf.timer(4000, look, true)
    M.tor = { phase = phase, progress = progress, socks = t.socks }
    function M.tor.on() local p = phase:get() return p == "on" or p == "starting" end
    function M.tor.set(on)
      local dry = morf.env and morf.env("CAELESTIA_DRY_RUN")
      if dry and dry ~= "" and dry ~= "0" then
        morf.log("info", "caelestia: tor " .. (on and "start" or "stop") .. " (dry run)")
        phase:set(on and "on" or "off")
        return
      end
      phase:set(on and "starting" or "stopping")
      progress:set("")
      local verb = on and t.start or t.stop
      verb(function(done, why)
        if not done then
          morf.log("warn", "caelestia: tor " .. (on and "start" or "stop") .. " failed: " .. tostring(why or ""))
          phase:set(on and "failed" or (t.up() and "on" or "off"))
          return
        end
        phase:set(on and (t.up() and "on" or "starting") or "off")
        look()
      end)
    end
  end
end

M.network = {}

--- A Material Symbols name for the connection.
function M.network.icon()
  if not net or not net.state.available then return "wifi_off" end
  local primary = net.state.primary or {}
  if primary.type == "802-3-ethernet" or (net.state.wired and net.state.wired.connected) then
    return "lan"
  end
  local wifi = net.state.wifi or {}
  if not net.state.wifi_enabled then return "wifi_off" end
  if not wifi.connected then return "signal_wifi_statusbar_not_connected" end
  local s = wifi.strength or 0
  if s >= 80 then return "signal_wifi_4_bar" end
  if s >= 55 then return "network_wifi_3_bar" end
  if s >= 30 then return "network_wifi_2_bar" end
  if s >= 10 then return "network_wifi_1_bar" end
  return "signal_wifi_0_bar"
end

function M.network.name()
  if not net or not net.state.available then return nil end
  local wifi = net.state.wifi or {}
  return wifi.connected and wifi.ssid or nil
end

M.bluetooth = {}

function M.bluetooth.icon()
  if not bt or not bt.state.available or not bt.state.powered then return "bluetooth_disabled" end
  if (bt.state.connected_count or 0) > 0 then return "bluetooth_connected" end
  return "bluetooth"
end

M.power = {}

local PROFILE_ICON = {
  ["power-saver"] = "energy_savings_leaf",
  balanced = "balance",
  performance = "rocket_launch",
}

--- The battery when the machine has one, else the power profile.
function M.power.icon()
  if power and power.state.available then
    local d = power.state.display or {}
    if d.present then
      local p = d.percentage or 0
      if d.charging then return "battery_charging_full" end
      if p >= 95 then return "battery_full" end
      return ("battery_%d_bar"):format(math.max(0, math.min(6, math.floor(p / 100 * 7))))
    end
    local profiles = power.state.profiles or {}
    if profiles.available then return PROFILE_ICON[profiles.active] or "balance" end
  end
  return "balance"
end

-- ----------------------------------------------------------------- media --

-- MPRIS players on the session bus (lib/mpris.lua), or nil without one.
do
  local ok, mpris = pcall(require, "lib.services.mpris")
  if ok then
    local ok2, media = pcall(mpris.connect)
    if ok2 then M.media = media end
  end
end

--- The active player's state (`{}` when there is none).
function M.player()
  local media = M.media
  if not media or not media.state.available then return {} end
  return media.state.active or {}
end

--- Whether something is loaded in a player.
function M.playing_something()
  local a = M.player()
  return (a.title or "") ~= "" or (a.name or "") ~= ""
end

--- `m:ss` for seconds.
function M.duration(seconds)
  seconds = math.max(0, math.floor(tonumber(seconds) or 0))
  local h, m, s = seconds // 3600, (seconds % 3600) // 60, seconds % 60
  if h > 0 then return ("%d:%02d:%02d"):format(h, m, s) end
  return ("%d:%02d"):format(m, s)
end

-- --------------------------------------------------------------- weather --

local weather

--- The weather where the settings say (or where the address says), read
--- through lib/weather.lua: `{ available, ... }`.
function M.weather()
  if not weather then
    local config = require("config")
    local location = config.get("services.weather_location")
    weather = require("lib.integrations.weather").new {
      location = location ~= "" and location or nil,
      units = config.get("services.imperial") and "imperial" or "metric",
    }
  end
  return weather:get()
end

--- A Material Symbols name for a WMO weather code.
function M.weather_symbol(code, is_day)
  code = tonumber(code) or -1
  if code == 0 then return is_day == false and "clear_night" or "clear_day" end
  if code == 1 or code == 2 then return is_day == false and "partly_cloudy_night" or "partly_cloudy_day" end
  if code == 3 then return "cloud" end
  if code == 45 or code == 48 then return "foggy" end
  if (code >= 51 and code <= 57) then return "rainy" end
  if (code >= 61 and code <= 67) or (code >= 80 and code <= 82) then return "rainy" end
  if (code >= 71 and code <= 77) or code == 85 or code == 86 then return "weather_snowy" end
  if code >= 95 then return "thunderstorm" end
  return "cloud"
end

-- ---------------------------------------------------------------- system --

M.hyprland = hyprland

return M
