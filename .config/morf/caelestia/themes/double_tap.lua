-- Two deliberate, nearby taps. Kept independent of rendering and input APIs.
local M={}
function M.new(spec)
  local contacts,first={},nil
  local movement=spec.movement or 16
  local separation=spec.separation or 40
  local blocked_until=0
  local function count() local n=0 for _ in pairs(contacts) do n=n+1 end return n end
  local function distance(x,y,a,b) return (x-a)^2+(y-b)^2 end
  local g={}
  function g.reset()
    first=nil
    for _,c in pairs(contacts) do c.invalid=true end
    blocked_until=spec.now()+350
  end
  function g.down(id,x,y)
    if contacts[id] then return end
    local now=spec.now()
    local valid=spec.allowed() and now>=blocked_until
    if count()>0 then
      valid=false first=nil
      for _,c in pairs(contacts) do c.invalid=true end
    end
    contacts[id]={x=x,y=y,time=now,invalid=not valid}
    if not valid then first=nil end
    if first and (now-first.time<40 or now-first.time>350
      or distance(x,y,first.x,first.y)>separation^2) then first=nil end
  end
  function g.move(id,x,y)
    local c=contacts[id]
    if c and distance(x,y,c.x,c.y)>movement^2 then c.invalid=true first=nil end
  end
  function g.up(id,x,y)
    local c=contacts[id]
    if not c then return end
    if x and y then g.move(id,x,y) end
    contacts[id]=nil
    local now=spec.now()
    if c.invalid or not spec.allowed() or count()>0 or now-c.time<20 or now-c.time>250 then
      first=nil return
    end
    if first then
      first=nil
      blocked_until=now+500
      spec.wake()
    else first={x=c.x,y=c.y,time=now} end
  end
  function g.cancel(id)
    contacts[id]=nil
    first=nil
    for _,c in pairs(contacts) do c.invalid=true end
  end
  return g
end
return M
