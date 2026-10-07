-- A contact sequence stays with the Morf surface where it began. This
-- recognizer uses the raw events available in released engines: no input
-- device access, compositor plugin, or global touchscreen grab.
local M = {}
function M.new(spec)
  local contacts, order, multi, invalid, ended = {}, {}, false, false, false
  local function reset()
    contacts, order, multi, invalid, ended = {}, {}, false, false, false
  end
  local function count() local n=0 for _ in pairs(contacts) do n=n+1 end return n end
  local function allowed() return not spec.allowed or spec.allowed() end
  local function cancel_single()
    if spec.single then spec.single("cancel") end
  end
  local g = {}
  function g.blocked() return multi or invalid end
  function g.down(id,x,y)
    if count()==0 then reset() end
    if contacts[id] then return end
    contacts[id]={x=x,y=y,sx=x,sy=y}
    order[#order+1]=id
    if not allowed() then invalid=true end
    if #order==1 and not invalid and spec.single then spec.single("begin",0,0,x,y) end
    if #order==2 then
      multi=true
      cancel_single()
      if spec.cancel_keys then spec.cancel_keys() end
    elseif #order>2 then invalid=true end
  end
  function g.move(id,x,y)
    local c=contacts[id]
    if not c then return end
    c.x,c.y=x,y
    if not allowed() then invalid=true cancel_single() end
    if not invalid and not multi and spec.single then
      spec.single("update",x-c.sx,y-c.sy,c.sx,c.sy)
    end
  end
  function g.up(id,x,y)
    local c=contacts[id]
    if not c then return end
    if x and y then c.x,c.y=x,y end
    if not ended then
      ended=true
      if allowed() and not invalid then
        if multi then
          local a,b=contacts[order[1]],contacts[order[2]]
          if a and b and spec.pair then spec.pair(a,b) end
        elseif spec.single then spec.single("end",c.x-c.sx,c.y-c.sy,c.sx,c.sy) end
      else cancel_single() end
    end
    contacts[id]=nil
    if count()==0 then reset() end
  end
  function g.cancel(id)
    invalid,ended=true,true
    cancel_single()
    if spec.cancel_keys then spec.cancel_keys() end
    contacts[id]=nil
    if count()==0 then reset() end
  end
  return g
end
return M
