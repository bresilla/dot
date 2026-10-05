-- Wired/VPN/Tor state and commands. Themes receive cached rows and callbacks.
local morf=require("morf")
local services=require("services")
local M={}
local NAMES={netbird="NetBird",tailscale="Tailscale",zerotier="ZeroTier",mullvad="Mullvad",protonvpn="Proton VPN"}
local TOOLS={mesh={"netbird","tailscale","zerotier"},tunnel={"mullvad","protonvpn"}}
local WIRED={activated="Connected",disconnected="Disconnected",unavailable="No cable",prepare="Connecting",
  config="Connecting",ip_config="Getting an address",need_auth="Needs a password",deactivating="Disconnecting",failed="Failed"}
local TOR={off="Off",starting="Starting",on="Running",stopping="Stopping",failed="Could not start"}
local NOTES={
  wired="Every wired port NetworkManager looks after: a laptop's own, a dock's, a Thunderbolt link.",
  mesh="ZeroTier's own command needs root to list its networks: it is shown by its link, and switched with zerotier-cli.",
  tunnel="Proton VPN's app keeps its connections in NetworkManager, above; its command-line client, when installed, is here.",
  tor="Starting it runs the system's tor service until it is stopped or the machine restarts; it is never enabled, so every boot is without it. Point a browser or an app at the SOCKS proxy to go through it.",
}
function M.is_mesh_link(name) return require("lib.services.vpns").is_mesh_link(name) end
local function dry_run()
  local v=morf.env("CAELESTIA_DRY_RUN") return v~=nil and v~="" and v~="0"
end
local function list(source)
  local out={}
  if source then for i=1,source:len() do out[#out+1]=source:get(i) end end
  return out
end
function M.new(kind,active)
  assert(NOTES[kind],"unknown network settings page")
  local vpn=kind=="mesh" or kind=="tunnel"
  local vpns=vpn and require("lib.services.vpns") or nil
  local rows=morf.state {network={},apps={},tor={}}
  local snapshot=morf.signal("caelestia.net-page."..kind,{available=false,network=false,network_available=false,loaded=false,network_rows={},app_rows={},tor_rows={}})
  local model={key="net-"..kind,kind=kind,active=active,network=rows.network,apps=rows.apps,tor=rows.tor,
    tools=TOOLS[kind] or {},names=NAMES,note=NOTES[kind],
    message=morf.signal("caelestia.net-page."..kind..".message",""),
    failed=morf.signal("caelestia.net-page."..kind..".failed",false)}
  local function network_rows(net)
    local out={}
    if not net or not net.state or net.state.available==false then return out end
    if kind=="wired" then
      for _,d in ipairs(list(net.state.devices)) do if d.type=="ethernet" then
        local on=d.state=="activated"
        local words={WIRED[d.state] or d.state or "Unknown"}
        if on and d.connection and d.connection~="" then words[#words+1]=d.connection end
        if d.ip4 and d.ip4~="" then words[#words+1]=d.ip4 end
        if (d.speed or 0)>0 then words[#words+1]=("%d Mb/s"):format(d.speed) end
        if d.hw_address and d.hw_address~="" then words[#words+1]=d.hw_address end
        out[#out+1]={key=morf.json.encode({d.path or "",d.interface or ""}),source="wired",target=d.interface,
          id="wired-"..(d.interface or ""),name=d.interface or "",icon=d.carrier==false and "settings_ethernet" or "lan",
          on=on,can=d.state~="unavailable",detail=table.concat(words," · "),address=d.ip4 or ""}
      end end
    elseif kind=="tunnel" then
      for _,d in ipairs(list(net.state.vpn_connections)) do if not M.is_mesh_link(d.id) then
        out[#out+1]={key="nm:"..d.uuid,source="nm",target=d.uuid,id="vpn-nm-"..d.uuid,name=d.id,
          icon=d.type=="wireguard" and "vpn_lock" or "vpn_key",on=d.active==true,can=true,
          detail=(d.type=="wireguard" and "WireGuard" or "VPN").." · "..(d.active and "Connected" or "Off")}
      end end
    end
    return out
  end
  local function read()
    local net=services.net
    local value={available=false,network=net~=nil and net.state~=nil,network_available=false,loaded=false,network_rows={},app_rows={},tor_rows={}}
    if kind=="wired" or kind=="tunnel" then value.network_available=value.network and net.state.available~=false end
    if kind=="wired" or kind=="tunnel" then value.network_rows=network_rows(net) end
    if kind=="wired" then value.available=value.network and net.state.available~=false end
    if vpn then
      value.available=true
      local data=vpns.rows[kind]:get()
      value.loaded=vpns.loaded and vpns.loaded[kind]:get() or #data>0
      for _,id in ipairs(TOOLS[kind]) do for _,r in ipairs(data) do if r.id==id then
        value.app_rows[#value.app_rows+1]={key="app:"..id,source="app",target=id,id="vpn-"..id,name=NAMES[id],
          icon=kind=="mesh" and "hub" or "shield",on=r.up==true,can=r.can_toggle==true,
          detail=(r.detail or "")..(r.address and r.address~="" and (" · "..r.address) or ""),
          on_word=kind=="mesh" and "Up" or "Connect",off_word=kind=="mesh" and "Down" or "Disconnect"}
      end end end
    end
    if kind=="tor" or kind=="tunnel" then
      local t=services.tor
      if t then
        value.available=true
        local phase,progress=t.phase:get(),t.progress:get()
        local on=phase=="on" or phase=="starting"
        value.tor_rows={
          {key="tor",source="tor",id="tor-service",name="Tor",icon="travel_explore",on=on,
            can=phase~="starting" and phase~="stopping",on_word="Start",off_word="Stop",
            detail=(TOR[phase] or phase)..((phase=="on" or phase=="starting") and progress~="" and (" · "..progress) or "")},
          {key="proxy",source="readout",id="tor-socks",name="SOCKS proxy",icon="lan",on=phase=="on",can=false,
            detail=("127.0.0.1:%d"):format(t.socks)},
        }
      end
    end
    return value
  end
  local serial=0
  morf.effect("caelestia.net-page."..kind..".read",function()
    if not active() then serial=serial+1 model.message:set("") model.failed:set(false) return end
    local value=read()
    snapshot:set(value)
    rows.network:replace(value.network_rows,"key") rows.apps:replace(value.app_rows,"key") rows.tor:replace(value.tor_rows,"key")
  end)
  if vpn then
    local holding=false
    morf.effect("caelestia.vpn.watch."..kind,function()
      active()
      -- Construct the library's polling timer outside the effect's lifetime.
      morf.timer(1,function()
        local on=active()
        if on and not holding then holding=true vpns.watch(kind,8000)
        elseif not on and holding then holding=false vpns.release(kind) end
      end,false)
    end)
  end
  function model.available() return snapshot:get().available end
  function model.has_network() return snapshot:get().network end
  function model.network_available() return snapshot:get().network_available end
  function model.loaded() return snapshot:get().loaded end
  local function find(value,key)
    for _,name in ipairs {"network_rows","app_rows","tor_rows"} do
      for _,row in ipairs(value[name]) do if row.key==key then return row end end
    end
  end
  function model.row(target) return find(snapshot:get(),type(target)=="table" and target.key or target) end
  function model.toggle(target,on)
    if not active() or dry_run() then return false end
    local key=type(target)=="table" and target.key or target
    local row=find(read(),key)
    if not row or not row.can or row.source=="readout" then return false end
    if on==nil then on=not row.on end
    if type(on)~="boolean" or on==row.on then return false end
    serial=serial+1
    local request=serial
    model.failed:set(false) model.message:set(on and "Connecting…" or "Disconnecting…")
    local function done(ok,why)
      if request~=serial or not active() then return end
      local success=ok~=nil and ok~=false
      model.failed:set(not success)
      model.message:set(success and "Request sent" or tostring(why or "Request failed"))
    end
    local ok,result,err=pcall(function()
      local net=services.net
      if row.source=="wired" then return (on and net.connect_device or net.disconnect)(row.target,done)
      elseif row.source=="nm" then return (on and net.activate_vpn or net.deactivate_vpn)(row.target,done)
      elseif row.source=="app" then return vpns.set(row.target,on,done)
      elseif row.source=="tor" then services.tor.set(on) done(true) return true end
    end)
    if not ok then done(nil,result) return false end
    -- VPN commands return asynchronously without a value; nil alone is not failure.
    if result==false or (result==nil and err~=nil) then done(nil,err) return false end
    return true
  end
  return model
end
return M
