local morf=require("morf")
local services=require("services")
local M={device=morf.state {name="",kind="headphones"}}
local view=require("themes").view("headphones").build(M)
M.drawer=require("drawer").new {name="headphones",edge=view.edge,width=view.width,height=view.height,
  transient=true,content=view.content,props=view.props}
local dismiss
function M.show(device)
  if not services.here() then return end
  M.device.name=device.name M.device.kind=device.kind
  if dismiss then dismiss:cancel() end
  M.drawer.set(true)
  dismiss=morf.timer(3200,function() dismiss=nil M.drawer.set(false) end,false)
end
local function receive(payload,target)
  if target~=services.output() then return end
  local ok,device=pcall(morf.json.decode,payload or "")
  if ok and type(device)=="table" and type(device.name)=="string"
    and (device.kind=="headphones" or device.kind=="earbuds") then M.show(device) end
end
morf.ipc["headphones-connected"]=receive
morf.ipc["headphones-demo"]=function(kind)
  M.show {name="Connection preview",kind=kind=="earbuds" and "earbuds" or "headphones"}
end
local tracker=require("models.headphones").new(function(device)
  local payload,target=morf.json.encode(device),services.active_output()
  if not morf.broadcast("headphones-connected",payload,target) then receive(payload,target) end
end)
local backend
local function update(rows,source)
  if backend~=source then tracker.stop() backend=source end
  tracker.update(rows)
end
local subscription,debounce,retry,query,epoch=nil,nil,nil,nil,0
local watching=false
local pulse=morf.signal("caelestia.headphones.pulse",false)
local query_id=0
local function native()
  local audio=morf.audio
  if not audio or not audio.available() then return end
  local rows={}
  for i=1,audio.sinks:len() do rows[#rows+1]=audio.sinks:get(i) end
  update(rows,"native")
end
local refresh
refresh=function()
  if debounce then debounce:cancel() end
  debounce=morf.timer(250,function()
    debounce=nil
    if not watching then return end
    if query then query:kill() end
    query_id=query_id+1
    local request=query_id
    local generation=epoch
    query=morf.run({"pactl","--format=json","list","sinks"},{timeout_ms=2000,max_output=512*1024},function(result)
      if not watching or generation~=epoch or request~=query_id then return end
      query=nil
      if result.ok and not result.truncated then
        local ok,rows=pcall(morf.json.decode,result.stdout)
        if ok and type(rows)=="table" then update(rows,"pulse") end
      else native() end
    end)
  end,false)
end
local function stop()
  watching=false epoch=epoch+1
  pulse:set(false)
  for _,timer in pairs {debounce=debounce,retry=retry} do timer:cancel() end
  debounce,retry=nil,nil
  if subscription then subscription:kill() subscription=nil end
  if query then query:kill() query=nil end
  tracker.stop()
end
local function start()
  watching=true
  local generation=epoch
  subscription=morf.spawn {command={"pactl","subscribe"},
    on_stdout=function(line)
      if watching and generation==epoch and (line:find("on sink",1,true) or line:find("on card",1,true)) then refresh() end
    end,
    on_stderr=function() end,
    on_exit=function()
      if not watching or generation~=epoch then return end
      subscription=nil
      pulse:set(false)
      -- No idle polling while the server is healthy. Only retry a lost server.
      retry=morf.timer(10000,function() retry=nil if watching then start() end end,false)
    end,
  }
  pulse:set(subscription~=nil)
  refresh()
end
-- A dry run reaches no audio server (no `pactl` at all): the native
-- device list below stands in.
local function dry()
  local value=morf.env("CAELESTIA_DRY_RUN")
  return value~=nil and value~="" and value~="0"
end
morf.effect("caelestia.headphones.watch",function()
  local primary=(not morf.primary or morf.primary()) and not dry()
  if primary and not watching then start() elseif not primary and watching then stop() end
end)
morf.effect("caelestia.headphones.native",function()
  -- Native metadata is a fallback on machines without PulseAudio compatibility.
  local primary=not morf.primary or morf.primary()
  if primary and not pulse:get() then native() end
end)
return M
