-- Radio state, sorted device lists and actions, independent of visual themes.
local morf=require("morf")
local services=require("services")
local config=require("config")
local M={}
local function dry_run()
  local value=morf.env("CAELESTIA_DRY_RUN")
  return value~=nil and value~="" and value~="0"
end
function M.signal_icon(strength)
  strength=strength or 0
  if strength>=80 then return "signal_wifi_4_bar" end
  if strength>=55 then return "network_wifi_3_bar" end
  if strength>=30 then return "network_wifi_2_bar" end
  if strength>=10 then return "network_wifi_1_bar" end
  return "signal_wifi_0_bar"
end
function M.new(kind,active)
  assert(kind=="network" or kind=="bluetooth","unknown radio page")
  local wireless=kind=="network"
  local snapshot=morf.signal("caelestia."..kind..".snapshot",{available=false,enabled=false,discovering=false,rows={}})
  local state=morf.state {rows={}}
  local model={key=kind,active=active,wireless=wireless,rows=state.rows,signal_icon=M.signal_icon,
    message=morf.signal("caelestia."..kind..".message",""),failed=morf.signal("caelestia."..kind..".failed",false)}
  local request=0
  local function service() return wireless and services.net or not wireless and services.bt or nil end
  local function key(row)
    if wireless then return morf.json.encode({row.key or row.ssid or "",row.security or "",row.device or ""}) end
    return morf.json.encode({row.path or "",row.address or ""})
  end
  local function read_rows(source)
    local list=wireless and source.state.access_points or source.state.devices
    local rows={}
    if list then for i=1,list:len() do
      local row=list:get(i)
      if wireless or row.named~=false then
        row.view_key=key(row)
        rows[#rows+1]=row
      end
    end end
    table.sort(rows,function(a,b)
      if wireless then
        if (a.in_use==true)~=(b.in_use==true) then return a.in_use==true end
        if (a.strength or 0)~=(b.strength or 0) then return (a.strength or 0)>(b.strength or 0) end
      else
        if (a.connected==true)~=(b.connected==true) then return a.connected==true end
        if (a.paired==true)~=(b.paired==true) then return a.paired==true end
        local an,bn=a.alias or a.name or "",b.alias or b.name or ""
        if an~=bn then return an<bn end
      end
      return a.view_key<b.view_key
    end)
    return rows
  end
  morf.effect("caelestia."..kind..".read",function()
    if not active() then
      request=request+1 model.message:set("") model.failed:set(false)
      return
    end
    local ok,value=pcall(function()
      local source=service()
      if not source or not source.state or not source.state.available then
        return {available=false,enabled=false,discovering=false,rows={}}
      end
      return {available=true,enabled=(wireless and source.state.wifi_enabled or not wireless and source.state.powered)==true,
        discovering=not wireless and source.state.discovering==true or false,rows=read_rows(source)}
    end)
    if not ok then value={available=false,enabled=false,discovering=false,rows={}} end
    snapshot:set(value) state.rows:replace(value.rows,"view_key")
  end)
  function model.available() return snapshot:get().available end
  function model.enabled() return snapshot:get().enabled end
  function model.discovering() return snapshot:get().discovering end
  function model.list() return snapshot:get().rows end
  function model.row(target)
    local wanted=type(target)=="table" and (target.view_key or key(target)) or target
    for _,row in ipairs(model.list()) do if row.view_key==wanted then return row end end
  end
  local function current(target)
    local ok,row=pcall(function()
      local source=service()
      if not source or not source.state.available then return nil end
      local wanted=target.view_key or key(target)
      for _,row in ipairs(read_rows(source)) do if row.view_key==wanted then return row end end
    end)
    return ok and row or nil
  end
  local function action(label,invoke)
    if not active() or dry_run() then return false end
    request=request+1
    local serial=request
    model.failed:set(false) model.message:set(label)
    local answered=false
    local function done(result,err)
      if serial~=request or not active() then return end
      answered=true
      model.failed:set(result==nil or result==false)
      model.message:set((result~=nil and result~=false) and "Request sent" or tostring(err or "Request failed"))
    end
    local ok,result,err=pcall(invoke,done)
    if not ok then done(nil,result) return false end
    if result==nil or result==false then
      if not answered then done(nil,err) end
      return false
    end
    return true
  end
  local function radio_action(label,invoke)
    return action(label,function(done)
      local source=service()
      if not source or not source.state.available then return nil,"Service unavailable" end
      return invoke(source,done)
    end)
  end
  function model.set_enabled(on)
    return radio_action(wireless and "Changing Wi-Fi…" or "Changing Bluetooth…",function(source,done)
      if wireless then return source.set_wifi(on==true,done) end
      return source.set_powered(on==true,nil,done)
    end)
  end
  function model.scan(on)
    return radio_action(wireless and "Scanning for networks…" or "Changing discovery…",function(source,done)
      if wireless then return source.request_scan(nil,done) end
      return (on and source.start_discovery or source.stop_discovery)(nil,done)
    end)
  end
  function model.choose(target)
    if not active() or dry_run() or type(target)~="table" then return false end
    local row=current(target)
    if not row or (wireless and (not row.ssid or row.in_use)) then return false end
    if not wireless and not row.path then return false end
    return radio_action(wireless and ("Connecting to "..row.ssid.."…") or
      ((row.connected and "Disconnecting " or "Connecting ")..(row.alias or row.name or row.address or "device").."…"),function(source,done)
      if wireless then return source.connect(row,nil,nil,done) end
      return (row.connected and source.disconnect or source.connect)(row,done)
    end)
  end
  function model.open_settings()
    if wireless then return false end
    local argv=config.get("bar.bluetooth_settings")
    if type(argv)~="table" or #argv==0 then return false end
    return action("Opening settings…",function(done)
      local child,err=morf.spawn {command=argv}
      done(child~=nil and child~=false,err)
      return child,err
    end)
  end
  return model
end
return M
