local morf=require("morf")
return function(theme)
  local registration=require("themes.tsugumori.registration")(theme)
  return function(host,cards,model,shown)
    local cues,slots,known,pending={},{},{},{}
    local was_open=false
    for i,card in ipairs(cards) do cues[i]=registration(card,"notification-"..i) end
    for _,notification in ipairs(model.list:get()) do known[notification.id]=true end
    morf.effect("caelestia.notifications.acquire",function()
      local present={}
      for _,notification in ipairs(model.list:get()) do
        present[notification.id]=true
        if not known[notification.id] then pending[notification.id]=true end
      end
      known=present
      for id in pairs(pending) do if not present[id] then pending[id]=nil end end
      local suppressed=model.dnd:get() or model.covered:get() or not require("services").here()
      local opened=model.opened:get()
      if suppressed then pending={} end
      for i,notification in ipairs(shown()) do
        local id=notification.id
        if slots[i]~=id or not opened or suppressed then cues[i](nil) end
        slots[i]=id
        if opened and not suppressed and pending[id] then
          pending[id]=nil cues[i]("arrival",was_open and 0 or 500)
        end
      end
      local count=#shown()
      for i=count+1,#cards do slots[i]=nil cues[i](nil) end
      if opened then pending={} end
      was_open=opened
    end,{owner=host})
  end
end
