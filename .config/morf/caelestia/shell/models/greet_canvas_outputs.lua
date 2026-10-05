-- A single greeter owns its keyboard and authentication conversation.
-- Cage selects the only enabled login output; pointer movement is irrelevant.
local morf=require("morf")
return function(options)
  local active=morf.signal("greet.output","main")
  local owner=morf.signal("greet.submission","")
  local M={active=active,owner=owner}
  function M.main() return true end
  function M.claim() end
  function M.submit()
    if owner:get()~="" then return end
    owner:set("main") options.busy(true) options.submit()
  end
  function M.release() owner:set("") options.busy(false) end
  function M.publish() end
  morf.ipc["greet-output"]=function() end
  morf.surface.keyboard_focus="exclusive"
  return M
end
