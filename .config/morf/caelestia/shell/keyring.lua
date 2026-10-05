-- Keyring UI and lifecycle. Passwords stay in local buffers and the private
-- bridge pipe/private answer socket, never signals, broadcast IPC, logs or settings.
local morf = require("morf")
local ui = require("morf.ui")
local M = {
  request=morf.signal("caelestia.keyring.request",false),
  opened=morf.signal("caelestia.keyring.opened",false),
  registered=morf.signal("caelestia.keyring.registered",false),
  busy=morf.signal("caelestia.keyring.busy",false),
  focused=morf.signal("caelestia.keyring.focused",1),
  error=morf.signal("caelestia.keyring.error",""),
  choice=morf.signal("caelestia.keyring.choice",false),
  lengths={morf.signal("caelestia.keyring.length",0),morf.signal("caelestia.keyring.confirm-length",0)},
}
local keys, key_nodes, passwords, active, agent = {}, {}, {"",""}, nil, nil
local responding = false
local services = require("services")
local here = services.here
local function destination(output)
  if output and output~="" and services.output then return output==services.output() end
  return here()
end
local function clear()
  for i=1,2 do passwords[i]="" M.lengths[i]:set(0) if keys[i] then keys[i].text="" end end
end
function M.focus(index)
  M.focused:set(index)
  for i=1,2 do keys[i].focus=M.opened:get() and i==index end
end
function M.cancel()
  if not active then return end
  local request = active
  active = nil
  responding = false
  M.busy:set(false)
  clear()
  for i=1,2 do keys[i].focus=false end
  M.request:set(false)
  M.drawer.set(false)
  -- The bridge may be gone, or already processing a submitted answer.
  -- Neither case should keep the dialog or its input grab alive.
  local ok = pcall(request.cancel)
  if not ok then morf.log("warn", "caelestia: keyring cancellation transport failed") end
end
function M.submit()
  if not active or responding then return end
  if active.kind=="password" and active.properties["password-new"] and passwords[1]~=passwords[2] then
    M.error:set("Passwords do not match") M.focus(2) return
  end
  responding=true M.busy:set(true)
  local password=passwords[1]
  clear()
  active.answer(password,M.choice:get())
  password=nil
end
for i=1,2 do
  -- Kit password fields, hidden: the view draws the dots.
  key_nodes[i],keys[i]=require("kit").text_field("password",{id="keyring-keys-"..i,reveal=false,
    width=1,height=1,opacity=0,password=true,max_length=4096,tab_navigation=false,
    read_only=function() return not M.opened:get() or M.busy:get() end,
    on_text_changed=function(value)
      passwords[i]=value or "" M.lengths[i]:set(math.min(24,#passwords[i])) M.error:set("")
    end,
    on_accepted=function()
      if i==1 and active and active.properties["password-new"] then M.focus(2) else M.submit() end
    end,
    on_escape=M.cancel,
  })
end
local visual=require("keyring_view").build(M)
for i=1,2 do ui.reparent(key_nodes[i],visual.content) end
M.drawer=require("drawer").new {name="keyring",edge="top",width=visual.width,height=visual.height,content=visual.content,
  close_policy="none",modal=true}
visual.content.visible=function() return M.opened:get() end
local function close(request)
  if active~=request then return end
  active=nil responding=false M.busy:set(false) clear()
  M.request:set(false) M.drawer.set(false)
end
local function show(request)
  clear() active=request responding=false M.busy:set(false)
  M.error:set("") M.choice:set(request.properties["choice-chosen"]==true)
  M.request:set({kind=request.kind,properties=request.properties})
  -- Give the authentication prompt the top edge while it is open.
  for _,name in ipairs {"dashboard","launcher","session"} do
    local panel=require("drawer")[name] if panel then panel.set(false) end
  end
  M.drawer.set(true)
  M.focus(1)
end
-- The primary output owns GCR; only metadata is broadcast to the views.
-- Pin each prompt to the monitor focused when it arrives, as polkit does.
-- Answers go straight to the native bridge's user-private socket.
function M.message(kind, payload)
  local ok, data=pcall(morf.json.decode,payload or "")
  if not ok or type(data)~="table" then return end
  if kind=="status" then
    M.registered:set(data.registered==true)
  elseif kind=="close" then
    if active and active.id==data.id and active.endpoint==data.endpoint then close(active) end
  elseif kind=="prompt" and destination(data.output) and type(data.id)=="number" and type(data.endpoint)=="string"
    and (data.kind=="password" or data.kind=="confirm") then
    local request={id=data.id,endpoint=data.endpoint,kind=data.kind,properties=data.properties or {}}
    local answered=false
    local function reply(action,password,choice)
      if answered then return false end
      answered=true
      local sent=pcall(morf.request_socket,request.endpoint,
        morf.json.encode({id=request.id,action=action,password=password,choice=choice==true}).."\n",
        function()
          -- The bridge also broadcasts close. Local completion handles a
          -- bridge disappearing/reloading without leaving an orphan dialog.
          close(request)
        end,{timeout_ms=5000,max_bytes=64})
      if not sent then close(request) end
      return sent
    end
    function request.answer(password,choice) return reply("continue",password,choice) end
    function request.cancel() return reply("cancel") end
    show(request)
  end
end
local function publish(kind,data)
  local payload=morf.json.encode(data)
  if morf.broadcast and morf.broadcast("keyring-event",kind,payload) then return end
  M.message(kind,payload)
end
morf.ipc["keyring-event"]=M.message
morf.effect("caelestia.keyring.visibility",function()
  local open=M.drawer.open:get() M.opened:set(open)
  M.focus(M.focused:get())
  if not open then
    clear()
    if active and not responding then M.cancel() end
  end
end)
local function dry()
  local value=morf.env("CAELESTIA_DRY_RUN")
  return value and value~="" and value~="0"
end
morf.effect("caelestia.keyring.agent",function()
  local primary=not morf.primary or morf.primary()
  if dry() then return end
  if primary and not agent then
    local ok, result, why=pcall(require("lib.services.keyring_agent").serve,{
      helper=morf.env("MORF_KEYRING_HELPER"),
      on_request=function(request)
        if request.endpoint then
          publish("prompt",{id=request.id,endpoint=request.endpoint,kind=request.kind,properties=request.properties,
            output=services.active_output and services.active_output() or nil})
        else show(request) end -- private-pipe fixtures / older bridge
      end,
      on_close=function(request)
        if request.endpoint then publish("close",{id=request.id,endpoint=request.endpoint})
        else close(request) end
      end,
      on_status=function(names)
        local registered=false
        for _,name in ipairs(names) do if name=="org.gnome.keyring.SystemPrompter" then registered=true end end
        M.registered:set(registered)
        publish("status",{registered=registered})
      end,
    })
    if ok and result then agent=result
    else morf.log("info","caelestia: keyring prompter unavailable: "..tostring(ok and why or result)) end
  elseif not primary and agent then
    agent.close() agent=nil M.registered:set(false)
  end
end)
-- A disposable UI preview: no GCR request, keyring write or password check.
-- Real requests take priority and may replace this preview at any time.
function M.demo(kind,new_password)
  if active then return false end
  local switcher=package.loaded["themes.switcher"]
  if switcher and switcher.busy:get() then return false end
  for _,name in ipairs {"polkit","authsteps"} do
    local panel=require("drawer")[name]
    if panel and panel.open:get() then return false end
  end
  kind=kind or "password"
  if kind~="password" and kind~="confirm" then return false end
  local request={kind=kind,properties={title="Keyring demo",
    message=kind=="confirm" and "Confirm a test request" or new_password and "Create a test password" or "Unlock a test keyring",
    description=kind=="confirm" and "This demo does not change a real keyring."
      or "Use a dummy password such as 'test'. No real keyring is unlocked or changed.",
    ["password-new"]=new_password==true,["choice-label"]="Remember for this session",["continue-label"]="Continue"}}
  function request.answer() close(request) end
  function request.cancel() close(request) end
  show(request) return true
end
return M
