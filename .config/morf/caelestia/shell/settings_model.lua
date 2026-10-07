-- Shared Settings readings, state and actions. No scene nodes or geometry.
local morf = require("morf")
local config = require("config")
local services = require("services")
local notifs = require("notifs")
local M = {}
local function dry_run()
  local v = morf.env and morf.env("CAELESTIA_DRY_RUN")
  return v ~= nil and v ~= "" and v ~= "0"
end
M.dry_run = dry_run

local function expand(words)
  local home = morf.fs.home()
  local stamp = morf.time.format("%Y%m%d_%H-%M-%S")
  local out = {}
  for i, w in ipairs(words) do
    out[i] = tostring(w):gsub("^~/", home .. "/"):gsub("%$HOME", home):gsub("%$DATE", stamp)
  end
  return out
end

--- Runs the command the settings keep under `utilities.commands.<name>`
--- (a list of words; `~/`, `$HOME` and `$DATE` expanded). Dry, it logs.
function M.run(name)
  local words = config.get("utilities.commands." .. name)
  if type(words) ~= "table" or #words == 0 then
    morf.log("info", "caelestia: utilities " .. name .. ": nothing to run")
    return false
  end
  local argv = expand(words)
  if dry_run() then
    morf.log("info", "caelestia: utilities " .. name .. " (dry run): " .. table.concat(argv, " "))
    return true
  end
  morf.run(argv, {}, function(result)
    if result and not result.ok then
      morf.log("warn", "caelestia: utilities " .. name .. " failed: " .. tostring(result.stderr or result.code))
    end
  end)
  return true
end

-- ------------------------------------------------------------ keep awake --

M.awake = require("themes.session").keep("caelestia.utilities.awake", false)
local awake_since = require("themes.session").keep("caelestia.utilities.awake_since", "")

morf.effect("caelestia.utilities.inhibit", function()
  local on = M.awake:get()
  if dry_run() then
    morf.log("info", "caelestia: keep awake " .. (on and "on" or "off") .. " (dry run)")
  elseif morf.idle and morf.idle.inhibit then
    morf.idle.inhibit(on)
  end
end)

local function clock(at)
  if config.get("bar.clock.twelve_hour") then
    return (morf.time.format("%-I:%M %p", at):lower())
  end
  return (morf.time.format("%H:%M", at))
end

function M.set_awake(on)
  if on and not M.awake:get() then awake_since:set(clock(morf.time.now())) end
  M.awake:set(on and true or false)
end

local local_state = {
  wifi = morf.signal("caelestia.utilities.wifi", false),
  bluetooth = morf.signal("caelestia.utilities.bluetooth", false),
  mic = morf.signal("caelestia.utilities.mic", true),
  gamemode = morf.signal("caelestia.utilities.gamemode", false),
}

--- The VPNs of `kind` that are up, by name: the mesh ones and the tunnel
--- apps by their links (no command run), and for tunnels NetworkManager's
--- own VPN and WireGuard profiles.
function M.vpn_names(kind)
  local names = {}
  local n = services.net
  local ok, vpns = pcall(require, "lib.services.vpns")
  if kind == "tunnel" and n and n.state.available then
    local model = n.state.vpn_connections
    for i = 1, model:len() do
      local v = model:get(i)
      if v.active and not (ok and vpns.is_mesh_link(v.id)) then names[#names + 1] = v.id end
    end
  end
  if ok then
    -- A link is read, not watched: re-read as the network changes.
    if n and n.state.available then n.state.devices:len() end
    for _, name in ipairs(vpns.links(kind)) do names[#names + 1] = name end
  end
  return names
end

--- Airplane mode on: what was on is remembered, then every radio is shut;
--- off, what was on comes back.
function M.set_airplane(on)
  local net, bt, modem = services.net, services.bt, services.modem
  if dry_run() then
    morf.log("info", "caelestia: airplane mode " .. (on and "on" or "off") .. " (dry run)")
    config.set("airplane.on", on == true)
    return
  end
  if on then
    config.set("airplane.was", {
      wifi = net ~= nil and net.state.available and net.state.wifi_enabled == true,
      bluetooth = bt ~= nil and bt.state.available and bt.state.powered == true,
      mobile = modem ~= nil and modem.state.data == true,
    })
    if net and net.state.available then pcall(net.set_wifi, false) pcall(net.set_wwan, false) end
    if bt and bt.state.available then pcall(bt.set_powered, false) end
  else
    local was = config.get("airplane.was") or {}
    if net and net.state.available then
      if was.wifi then pcall(net.set_wifi, true) end
      if was.mobile then pcall(net.set_wwan, true) end
    end
    if bt and bt.state.available and was.bluetooth then pcall(bt.set_powered, true) end
  end
  config.set("airplane.on", on == true)
end

M.TOGGLES = {
  {
    id = "wifi", icon = "wifi", name = "Wi-Fi", detail = "network",
    status = function()
      local n = services.net
      if n and n.state.available then
        local model = n.state.access_points
        for i = 1, model:len() do
          local ap = model:get(i)
          if ap.in_use then return ap.ssid or "Connected" end
        end
      end
      return nil
    end,
    on = function()
      local n = services.net
      if n and n.state.available then return n.state.wifi_enabled == true end
      return local_state.wifi:get()
    end,
    set = function(now)
      local n = services.net
      if n and n.state.available and not dry_run() then pcall(n.set_wifi, now) return end
      if dry_run() then morf.log("info", "caelestia: wifi " .. (now and "on" or "off") .. " (dry run)") end
      local_state.wifi:set(now)
    end,
  },
  {
    id = "bluetooth", icon = "bluetooth", name = "Bluetooth", detail = "bluetooth",
    status = function()
      local b = services.bt
      if b and b.state.available then
        local model = b.state.devices
        for i = 1, model:len() do
          local d = model:get(i)
          if d.connected then return d.alias or d.name or "Connected" end
        end
      end
      return nil
    end,
    on = function()
      local b = services.bt
      if b and b.state.available then return b.state.powered == true end
      return local_state.bluetooth:get()
    end,
    set = function(now)
      local b = services.bt
      if b and b.state.available and not dry_run() then pcall(b.set_powered, now) return end
      if dry_run() then morf.log("info", "caelestia: bluetooth " .. (now and "on" or "off") .. " (dry run)") end
      local_state.bluetooth:set(now)
    end,
  },
  {
    -- Wired: the first wired port's state, a click connects or disconnects
    -- it; ">" lists every port.
    id = "wired", name = "Wired", detail = "wired",
    icon = function()
      local n = services.net
      return (n and n.state.available and n.state.wired.carrier == false) and "settings_ethernet" or "lan"
    end,
    on = function()
      local n = services.net
      return n ~= nil and n.state.available and n.state.wired.connected == true
    end,
    set = function(now)
      local n = services.net
      if not (n and n.state.available) then return end
      local port = n.state.wired.device
      if port == "" then return end
      if dry_run() then morf.log("info", "caelestia: wired " .. tostring(now) .. " (dry run)") return end
      if now then pcall(n.connect_device, port) else pcall(n.disconnect, port) end
    end,
    status = function()
      local n = services.net
      if not (n and n.state.available) then return nil end
      local w = n.state.wired
      if w.device == "" then return "No port" end
      if w.connected then return w.ip4 ~= "" and w.ip4 or "Connected" end
      return w.carrier and "Disconnected" or "No cable"
    end,
  },
  {
    -- A phone's mobile data. Without a modem it says so, crossed out.
    id = "mobile", name = "Mobile data", detail = "mobile",
    icon = function()
      local m = services.modem
      if not (m and m.state.available) then return "signal_cellular_nodata" end
      return m.state.data and "signal_cellular_alt" or "signal_cellular_off"
    end,
    on = function() local m = services.modem return m ~= nil and m.state.available and m.state.data end,
    set = function(now)
      local m = services.modem
      if not (m and m.state.available) then return end
      if dry_run() then morf.log("info", "caelestia: mobile data " .. tostring(now) .. " (dry run)") return end
      pcall(m.set_data, now)
    end,
    status = function()
      local m = services.modem
      if not (m and m.state.available) then return "No modem" end
      local s = m.state
      if s.locked then return "SIM locked" end
      if not s.data then return "Off" end
      return (s.technology ~= "" and (s.technology .. " · ") or "") .. (s.operator ~= "" and s.operator or "On")
    end,
  },
  {
    -- Mesh VPNs: one's own machines (NetBird, Tailscale, ZeroTier).
    id = "mesh", icon = "hub", name = "Mesh", detail = "mesh",
    on = function() return #M.vpn_names("mesh") > 0 end,
    set = function() M.detail:set("mesh") end,
    status = function()
      local names = M.vpn_names("mesh")
      return #names == 0 and "Off" or table.concat(names, ", ")
    end,
  },
  {
    -- Tunnel VPNs: out to the internet through elsewhere (Mullvad, Proton).
    id = "tunnel", icon = "vpn_lock", name = "Tunnel", detail = "tunnel",
    on = function() return #M.vpn_names("tunnel") > 0 or services.tor ~= nil and services.tor.on() end,
    set = function() M.detail:set("tunnel") end,
    status = function()
      local names = M.vpn_names("tunnel")
      if services.tor and services.tor.on() then names[#names+1]="Tor" end
      return #names == 0 and "Off" or table.concat(names, ", ")
    end,
  },
  {
    -- Tor: the system's tor service, started and stopped -- never enabled,
    -- so it is off again after every boot.
    id = "tor", icon = "travel_explore", name = "Tor", detail = "tor",
    present = function() return services.tor ~= nil end,
    on = function() return services.tor ~= nil and services.tor.on() end,
    set = function(now)
      if dry_run() then morf.log("info", "caelestia: tor " .. tostring(now) .. " (dry run)") return end
      if services.tor then services.tor.set(now) end
    end,
    status = function()
      local t = services.tor
      if not t then return "Not installed" end
      local p = t.phase:get()
      if p == "starting" then return "Starting…" end
      if p == "stopping" then return "Stopping…" end
      if p == "failed" then return "Could not start" end
      if p == "on" then return ("SOCKS %d"):format(t.socks) end
      return "Off"
    end,
  },
  {
    -- Airplane mode: every radio off at once -- Wi-Fi, Bluetooth, mobile
    -- data -- and back as they were.
    id = "airplane", icon = "flight", name = "Airplane mode",
    on = function() return config.get("airplane.on") == true end,
    set = function(now) M.set_airplane(now) end,
    status = function() return config.get("airplane.on") == true and "On" or "Off" end,
  },
  {
    id = "sound", name = "Sound", detail = "sound",
    icon = function()
      local ok, sink = pcall(function() return morf.audio.available() and morf.audio.default_sink() end)
      return (ok and sink and sink.muted) and "volume_off" or "volume_up"
    end,
    on = function()
      local ok, sink = pcall(function() return morf.audio.available() and morf.audio.default_sink() end)
      if ok and sink then return not sink.muted end
      return true
    end,
    set = function(now)
      local ok, sink = pcall(function() return morf.audio.available() and morf.audio.default_sink() end)
      if not (ok and sink) then return end
      if dry_run() then morf.log("info", "caelestia: sound " .. (now and "on" or "off") .. " (dry run)") return end
      morf.audio.set_mute(sink.id, not now)
    end,
    status = function()
      local ok, sink = pcall(function() return morf.audio.available() and morf.audio.default_sink() end)
      if ok and sink then return ("%d%%"):format(math.floor(sink.volume * 100 + 0.5)) end
      return nil
    end,
  },
  {
    id = "mic", icon = function() return "mic" end, name = "Microphone", detail = "microphone",
    on = function() return local_state.mic:get() end,
    set = function(now)
      M.run(now and "mic_on" or "mic_off")
      local_state.mic:set(now)
    end,
  },
  {
    -- The battery: its charge, and a ">" to the Power page (profiles,
    -- health, how it charges). A tap opens the page too.
    id = "battery", name = "Battery", detail = "power",
    icon = function()
      local u = services.upower
      local d = u and u.state.available and u.state.display or {}
      if not d.present then return "power" end
      if d.charging then return "battery_charging_full" end
      local pct = d.percentage or 0
      if pct > 90 then return "battery_full" end
      if pct > 50 then return "battery_5_bar" end
      if pct > 20 then return "battery_3_bar" end
      return "battery_alert"
    end,
    on = function()
      local u = services.upower
      local d = u and u.state.available and u.state.display or {}
      return d.charging == true
    end,
    set = function() M.detail:set("power") end,
    status = function()
      local u = services.upower
      local d = u and u.state.available and u.state.display or {}
      if not d.present then return "On mains power" end
      return ("%d%%%s"):format(math.floor((d.percentage or 0) + 0.5), d.charging and ", charging" or "")
    end,
  },
  {
    id = "awake", icon = "coffee", name = "Keep awake",
    on = function() return M.awake:get() end,
    set = function(now) M.set_awake(now) end,
    status = function()
      if not M.awake:get() then return "Off" end
      return "Since " .. awake_since:get()
    end,
  },
  {
    -- How it calls for attention: sound, vibrate (on a phone) or silent.
    id = "ringer", name = "Ring mode",
    icon = function()
      local r = services.ringer
      return require("lib.util.ringer").icon(r and r.state.mode or "sound")
    end,
    on = function() local r = services.ringer return r ~= nil and r.state.mode ~= "sound" end,
    set = function()
      if dry_run() then morf.log("info", "caelestia: ring mode (dry run)") return end
      local r = services.ringer if r then r.next() end
    end,
    status = function()
      local r = services.ringer
      local mode = r and r.state.mode or "sound"
      return mode:sub(1, 1):upper() .. mode:sub(2)
    end,
  },
  {
    -- The bar: up or down, and a ">" to where it goes.
    id = "bar", icon = "toolbar", name = "Bar", detail = "bar",
    on = function() return require("bar").on() end,
    set = function(now) require("bar").set_on(now) end,
    status = function()
      local b = require("bar")
      if not b.on() then return "Off" end
      local side = b.side()
      return side:sub(1, 1):upper() .. side:sub(2)
    end,
  },
  {
    id = "dnd", icon = "notifications_off", name = "Do not disturb",
    on = function() return notifs.dnd:get() end,
    set = function(now) notifs.dnd:set(now) end,
  },
}

--- The detail page on show over the settings ("" for none): a tile's
--- ">" opens one, the back arrow shuts it.
M.detail = require("themes.session").keep("caelestia.settings.detail", "")
if M.detail:get()=="tor" then M.detail:set("tunnel") end

-- Focus is one entry point; each setting remains independent inside it.
-- Retain the raw controls for the detail page, before overview read caching.
M.CONTROLS={}
do
  local kept = {}
  for _, t in ipairs(M.TOGGLES) do
    M.CONTROLS[t.id]=t
    if t.id=="awake" then
      kept[#kept+1]={id="focus",name="Focus",detail="focus",
        icon=function()
          if notifs.dnd:get() then return "notifications_off" end
          if M.awake:get() then return "coffee" end
          return "tune"
        end,
        on=function() return M.awake:get() or notifs.dnd:get() or M.CONTROLS.ringer.on() end,
        set=function() M.detail:set("focus") end,
        status=function()
          local names={}
          if M.awake:get() then names[#names+1]="Awake" end
          if M.CONTROLS.ringer.on() then names[#names+1]=M.CONTROLS.ringer.status() end
          if notifs.dnd:get() then names[#names+1]="DND" end
          return #names>0 and table.concat(names," · ") or "Sound · Normal sleep"
        end}
    elseif t.id~="ringer" and t.id~="dnd" and t.id~="tor" and (not t.present or t.present()) then
      kept[#kept + 1] = t
    end
  end
  -- The theme: the tile switches dark and light; its page has that, and
  -- Lule (wallpaper, colours, the shell's theme and font) one page in.
  local function dark() return config.get("theme.mode") ~= "light" end
  kept[#kept + 1] = { id = "theme", name = "Theme", detail = "theme",
    icon = function() return dark() and "dark_mode" or "light_mode" end,
    on = dark,
    set = function() config.set("theme.mode", dark() and "light" or "dark") end,
    status = function() return dark() and "Dark" or "Light" end }
  M.TOGGLES = kept
end

M.opened = morf.signal("caelestia.settings.opened", false)
M.displayed = require("themes.session").keep("caelestia.settings.displayed", "")

M.DETAILS = {
  {key="network",name="Network"}, {key="bluetooth",name="Bluetooth"},
  {key="mobile",name="Mobile networks"},
  {key="sound",name="Sound"}, {key="microphone",name="Microphone"},
  {key="power",name="Power"}, {key="bar",name="Bar"}, {key="wired",name="Wired"},
  {key="mesh",name="Mesh"}, {key="tunnel",name="Tunnel"}, {key="focus",name="Focus"},
  {key="theme",name="Theme"}, {key="theme/lule",name="Lule",parent="theme"},
  {key="sound/equalizer",name="Equalizer",parent="sound"},
  {key="sound/equalizer/audiogram",name="Audiogram",parent="sound/equalizer"},
}
M.navigation=require("lib.util.settings_pages").new(M.DETAILS,M.detail,{tor="tunnel"})
M.back=M.navigation.back
M.breadcrumb=M.navigation.breadcrumb
function M.overview() return M.opened:get() and M.displayed:get()=="" end
function M.present(key) if key==M.detail:get() then M.displayed:set(key) end end
function M.request(key)
  return M.navigation.request(key)
end
function M.capture()
  require("sidebar").drawer.set(false)
  require("capture").drawer.set(true)
end
-- Retain the last displayed values while hidden, without refreshing sources.
local function reading(fn, initial, active)
  local cached=initial
  return function()
    if (active or M.overview)() then cached=fn() end
    return cached
  end
end
for _, toggle in ipairs(M.TOGGLES) do
  toggle.on=reading(toggle.on,false)
  if toggle.status then toggle.status=reading(toggle.status,nil) end
  if type(toggle.icon)=="function" then toggle.icon=reading(toggle.icon,"") end
end
M.focus={}
local function focus_active() return M.opened:get() and M.displayed:get()=="focus" end
for _,id in ipairs {"awake","ringer","dnd"} do
  local control=M.CONTROLS[id]
  M.focus[#M.focus+1]={id=id,name=control.name,set=control.set,
    icon=type(control.icon)=="function" and reading(control.icon,"",focus_active) or control.icon,
    on=reading(control.on,false,focus_active),
    status=control.status and reading(control.status,id=="ringer" and "Sound" or "Off",focus_active) or nil}
end
M.levels={}
for _, kind in ipairs {"volume","brightness"} do
  M.levels[kind]=reading(function() return (require("osd")[kind]()) end,0)
  M.levels[kind.."_icon"]=reading(function() return require("osd")[kind.."_icon"]() end,
    kind=="volume" and "volume_mute" or "brightness_low")
  M.levels["set_"..kind]=function(value)
    if dry_run() then
      morf.log("info","caelestia: "..kind.." "..tostring(value).." (dry run)")
      return
    end
    require("osd")["set_"..kind](value)
  end
end
morf.effect("caelestia.settings.presentation",function()
  local open,key=M.opened:get(),M.displayed:get()
  local presentation=require("presentation")
  presentation.set("settings.overview",open and key=="")
  presentation.set("settings.detail",open and key~="")
  for _, detail in ipairs(M.DETAILS) do presentation.set("settings."..detail.key,open and key==detail.key) end
end)
return M
