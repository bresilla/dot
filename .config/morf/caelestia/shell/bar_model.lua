-- Cached bar readings and actions. No widget construction or layout policy.
local morf = require("morf")
local M = {}
function M.new(ctx)
  local services, apps = require("services"), require("apps")
  local model = { on=ctx.on, side=ctx.side, vertical=ctx.vertical, screen=ctx.screen, insets=ctx.insets,
    rows=morf.list_model({}), has_modem=services.modem~=nil,
    stamp=morf.signal("caelestia.bar.clock",{"","",""}),
    reading=morf.signal("caelestia.bar.reading",{network_icon="wifi",mobile_icon="signal_cellular_nodata",
      battery_icon="power",battery=false,percentage="",tor=false,ring=false,ring_icon="notifications",technology=""}) }
  function model.titles() return require("config").get("edgebar.titles")~="off" and not model.vertical() end
  -- The network, as an icon: Wi-Fi by its signal, the wire, or none.
  local function network_icon()
    local n = services.net
    if n and n.state.available then
      local model = n.state.access_points
      for i = 1, model:len() do
        local ap = model:get(i)
        if ap.in_use then
          local s = ap.strength or 0
          if s > 75 then return "network_wifi" end
          if s > 50 then return "network_wifi_3_bar" end
          if s > 25 then return "network_wifi_2_bar" end
          return "network_wifi_1_bar"
        end
      end
      if n.state.wired then return "lan" end
      return n.state.wifi_enabled and "wifi_find" or "wifi_off"
    end
    return "wifi"
  end
  -- A phone's mobile network: bars by its signal, or off.
  local function mobile_icon()
    local m = services.modem
    -- No modem: the bars crossed out, so the place is always there.
    if not (m and m.state.available) then return "signal_cellular_nodata" end
    local s = m.state
    if s.locked then return "signal_cellular_connected_no_internet_0_bar" end
    if not s.registered then return "signal_cellular_off" end
    local q = s.signal or 0
    if q > 80 then return "signal_cellular_4_bar" end
    if q > 55 then return "signal_cellular_3_bar" end
    if q > 30 then return "signal_cellular_2_bar" end
    if q > 10 then return "signal_cellular_1_bar" end
    return "signal_cellular_0_bar"
  end
  local function battery()
    local u = services.upower
    local d = u and u.state.available and u.state.display or {}
    return d.present and d or nil
  end
  local function battery_icon()
    local b = battery()
    if not b then return "power" end
    if b.charging then return "battery_charging_full" end
    local pct = b.percentage or 0
    if pct > 90 then return "battery_full" end
    if pct > 60 then return "battery_5_bar" end
    if pct > 30 then return "battery_3_bar" end
    if pct > 10 then return "battery_1_bar" end
    return "battery_alert"
  end


  morf.effect("caelestia.bar.readings",function()
    if not model.on() then return end
    local b=battery()
    local r,t,m=services.ringer,services.tor,services.modem
    local mode=r and r.state.mode or "sound"
    model.reading:set {network_icon=network_icon(),mobile_icon=mobile_icon(),battery_icon=battery_icon(),
      battery=b~=nil,percentage=b and ("%d%%"):format(math.floor((b.percentage or 0)+.5)) or "",
      tor=t~=nil and t.on(),ring=mode~="sound",ring_icon=require("lib.util.ringer").icon(mode),
      technology=m and m.state.available and m.state.technology or ""}
  end)
  morf.effect("caelestia.bar.windows",function()
    if not model.on() then return end
    local rows={}
    local h=services.hyprland
    if h then
      local workspace=services.workspace.active()
      local focused=(h.state.active_window or {}).address
      local clients=h.state.clients
      for i=1,clients:len() do
        local client=clients:get(i)
        if client.workspace==workspace and not client.hidden then
          local class=client.class or ""
          local icon=apps.icon(class:lower()) or apps.icon(class) or apps.icon((client.initial_class or ""):lower())
          rows[#rows+1]={address=tostring(client.address),title=client.title and client.title~="" and client.title or class,
            class=class,focused=focused==client.address,icon=icon or {}}
        end
      end
    end
    model.rows:replace(rows,"address")
  end)
  morf.effect("caelestia.bar.time",function()
    if not model.on() then return end
    morf.minute_clock:get()
    local t=morf.time.now()
    model.stamp:set {morf.time.format("%H:%M",t),morf.time.format("%a %-d %b",t),morf.time.format("%d",t)}
  end)
  function model.focus(address)
    if not model.on() then return false end
    local dry=morf.env("CAELESTIA_DRY_RUN")
    if dry and dry~="" and dry~="0" then return false end
    local h=services.hyprland
    if not h then return false end
    local workspace=services.workspace.active()
    for i=1,h.state.clients:len() do
      local client=h.state.clients:get(i)
      if tostring(client.address)==address and client.workspace==workspace and not client.hidden then
        return pcall(h.dispatch,"focuswindow","address:"..address)
      end
    end
    return false
  end
  function model.toggle_launcher()
    if not model.on() then return end
    local d=require("launcher").drawer d.set(not d.open:get())
  end
  function model.open_settings()
    if not model.on() then return end
    local sidebar=require("sidebar")
    sidebar.select("settings")
    require("utilities").detail:set("")
    sidebar.drawer.set(true)
  end
  function model.toggle_dashboard()
    if not model.on() then return end
    local d=require("dashboard").drawer d.set(not d.open:get())
  end
  function model.settings_open()
    local s=package.loaded.sidebar
    return s and s.drawer and s.drawer.open:get() or false
  end
  function model.dashboard_open()
    local d=package.loaded.dashboard
    return d and d.drawer and d.drawer.open:get() or false
  end
  return model
end
return M
