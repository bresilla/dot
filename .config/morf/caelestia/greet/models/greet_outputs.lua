-- Public presentation and submission ownership only. Password drafts and the
-- greetd conversation remain private to the runtime that receives input.
local morf = require("morf")
return function(options)
  local own = (morf.screens[1] or {}).name or ""
  local function names()
    local result={}
    for _, output in ipairs(morf.screens or {}) do result[#result+1]=output.name end
    table.sort(result)
    return result
  end
  local active=morf.signal("greet.output",names()[1] or own)
  local owner=morf.signal("greet.submission", "")
  local M={active=active, owner=owner}
  function M.main() return active:get()==own end
  local function primary() return not morf.primary or morf.primary() end
  local function valid(name)
    for _, item in ipairs(names()) do if item==name then return true end end
    return false
  end
  local send
  function M.receive(action, name, payload)
    if action=="claim" and valid(name) then
      if active:get()~=name then options.clear() active:set(name) end
    elseif action=="state" then
      local ok, data=pcall(morf.json.decode,payload or "")
      if ok and type(data)=="table" and valid(name) then options.restore(data) end
    elseif action=="request" and primary() and valid(name) and owner:get()=="" then
      -- Reserve before sending the grant: two outputs cannot submit together.
      owner:set(name)
      send("grant",name)
    elseif action=="grant" and valid(name) then
      owner:set(name)
      options.busy(true)
      if name==own then options.submit() end
    elseif action=="release" and owner:get()==name then
      owner:set("") options.busy(false)
    elseif action=="sync" and primary() then
      send("claim",active:get())
      send("state",own,morf.json.encode(options.snapshot()))
      if owner:get()~="" then send("pending",owner:get()) end
    elseif action=="pending" and valid(name) then
      owner:set(name) options.busy(true)
    end
  end
  send=function(action,name,payload)
    if not morf.broadcast("greet-output",action,name,payload or "") then M.receive(action,name,payload) end
  end
  function M.claim()
    -- The supervisor forwards broadcasts asynchronously. Accept input in
    -- this runtime immediately, rather than losing the first key or click
    -- while its ownership claim travels back from the supervisor.
    M.receive("claim",own)
    send("claim",own)
  end
  function M.submit()
    if M.main() and owner:get()=="" then send("request",own) end
  end
  function M.release()
    M.publish()
    send("release",own)
  end
  function M.publish()
    if M.main() or owner:get()==own then send("state",own,morf.json.encode(options.snapshot())) end
  end
  morf.ipc["greet-output"]=M.receive
  morf.surface.on_pointer_changed=function(inside) if inside then M.claim() end end
  morf.on_keyboard_focus(function(focused)
    -- Cage chooses the focused fullscreen toplevel itself; that can differ
    -- from the alphabetically first output and happen without pointer entry.
    -- Layer-shell continues to follow pointer claims, avoiding focus loops.
    if focused and morf.capabilities.layer_shell == false then M.claim() end
  end)
  morf.effect("greet.outputs",function()
    if morf.screens_revision then morf.screens_revision() end
    if not valid(active:get()) then active:set(names()[1] or own) end
    if owner:get()~="" and not valid(owner:get()) then owner:set("") options.busy(false) end
    morf.surface.keyboard_focus=M.main() and "exclusive" or "none"
  end)
  morf.timer(1,function() send("sync",own) end,false)
  return M
end
