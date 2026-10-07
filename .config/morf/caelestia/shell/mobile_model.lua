-- Mobile broadband: ModemManager supplies the radio, NetworkManager owns
-- connections. Keep action state separate from the modem's observed state.
local morf=require("morf")
local services=require("services")
local M={}
local function each(list,fn)
  if list then for i=1,list:len() do fn(list:get(i)) end end
end
local function mobile(row) return row.type=="gsm" or row.type=="cdma" end
local function dry_run()
  local v=morf.env("CAELESTIA_DRY_RUN")
  return v~=nil and v~="" and v~="0"
end
function M.new(active)
  local snapshot=morf.signal("caelestia.mobile.snapshot",{available=false,rows={}})
  local model={key="mobile",active=active,
    message=morf.signal("caelestia.mobile.message",""),
    failed=morf.signal("caelestia.mobile.failed",false),
    pending=morf.signal("caelestia.mobile.pending",false)}
  local serial=0
  local function read()
    local modem,net=services.modem,services.net
    if not modem or not modem.state.available then return {available=false,rows={}} end
    local s=modem.state
    local value={available=true,data=s.data,locked=s.locked,sim=s.sim_present,
      registered=s.registered,connected=s.connected,roaming=s.roaming,
      operator=s.operator,technology=s.technology,signal=s.signal,rows={},
      managed=net~=nil and net.state.available==true}
    if value.managed then
      local connections={}
      each(net.state.active_connections,function(row)
        if mobile(row) then connections[row.connection]=row end
      end)
      each(net.state.known_connections,function(row)
        if not mobile(row) then return end
        local live=connections[row.path]
        value.rows[#value.rows+1]={path=row.path,name=row.id,uuid=row.uuid,
          apn=row.apn or "",auto_apn=row.auto_apn==true,
          active=live and live.path or "",state=live and live.state or "disconnected"}
      end)
      table.sort(value.rows,function(a,b)
        if (a.active~="")~=(b.active~="") then return a.active~="" end
        if a.name~=b.name then return a.name<b.name end
        return a.path<b.path
      end)
    end
    return value
  end
  morf.effect("caelestia.mobile.read",function()
    if not active() then
      serial=serial+1
      model.message:set("") model.failed:set(false) model.pending:set(false)
      return
    end
    snapshot:set(read())
  end)
  function model.available() return snapshot:get().available==true end
  function model.enabled() return snapshot:get().data==true end
  function model.list() return snapshot:get().rows end
  function model.carrier()
    local s=snapshot:get()
    return s.operator and s.operator~="" and s.operator or "Mobile network"
  end
  function model.status()
    local s=snapshot:get()
    if not s.available then return "No modem" end
    if s.locked then return "SIM locked" end
    if not s.sim then return "No SIM detected" end
    if not s.data then return "Mobile data is off" end
    if s.connected then return s.roaming and "Connected · Roaming" or "Connected" end
    if s.registered then return s.roaming and "Registered · Roaming" or "Registered · Not connected" end
    return "Searching for a network"
  end
  function model.signal()
    local s=snapshot:get()
    if not s.registered then return "No network signal" end
    return (s.technology~="" and (s.technology.." · ") or "")..tostring(s.signal or 0).."% signal"
  end
  function model.can_connect()
    local s=snapshot:get()
    return s.available and s.managed and s.data and s.sim and not s.locked and not model.pending:get()
  end
  function model.can_toggle()
    local s=snapshot:get()
    return s.available and s.managed and not model.pending:get()
  end
  local function action(label,invoke)
    if not active() or dry_run() or model.pending:get() then return false end
    local s=read()
    if not s.available or not s.managed then return false end
    serial=serial+1
    local request=serial
    model.message:set(label) model.failed:set(false) model.pending:set(true)
    local function done(result,err)
      if request~=serial or not active() then return end
      model.pending:set(false)
      model.failed:set(result==nil or result==false)
      model.message:set(result~=nil and result~=false and "Request sent" or tostring(err or "Request failed"))
    end
    local ok,result,err=pcall(invoke,services.net,s,done)
    if not ok then done(nil,result) return false end
    if result==nil or result==false then done(nil,err) return false end
    return true
  end
  function model.set_enabled(on)
    return action("Changing mobile data…",function(net,_,done) return net.set_wwan(on==true,done) end)
  end
  function model.choose(target)
    return action("Changing connection…",function(net,s,done)
      for _,row in ipairs(s.rows) do
        if row.path==target.path then
          if row.active~="" then return net.deactivate(row.active,done) end
          if not s.data or not s.sim or s.locked then return nil,"Enable mobile data and unlock the SIM first" end
          return net.activate(row.path,done)
        end
      end
      return nil,"Connection no longer exists"
    end)
  end
  function model.setup()
    return action("Setting up mobile data…",function(net,s,done)
      if #s.rows>0 then return nil,"A mobile connection already exists" end
      if not s.data or not s.sim or s.locked then return nil,"Enable mobile data and unlock the SIM first" end
      return net.connect_mobile(done)
    end)
  end
  function model.note()
    local s=snapshot:get()
    if s.available and not s.managed then return "NetworkManager is not running." end
    return "APN settings come from your saved connections. Automatic setup uses your provider’s settings."
  end
  return model
end
return M
