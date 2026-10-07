-- Phone pages slide as one track under the finger. Selection changes only
-- on release, leaving actions and keyboard navigation on a committed page.
local morf=require("morf")
local M={}
function M.new(spec)
  local p={}
  local held, running, was=nil,nil,spec.tab:get()
  local function stop() if running then running:stop() running=nil end end
  local function settle(index)
    stop()
    running=morf.animation.play {{node=spec.track,property="translate_x",to=-spec.offset(index),
      duration=240,easing="out_cubic"}}
  end
  morf.effect(spec.id..".phone-page-position",function()
    local index=spec.tab:get()
    if index==was then return end
    was=index
    held=nil
    settle(index)
  end)
  function p.begin()
    stop()
    held={x=spec.track.translate_x or 0,index=spec.tab:get(),dx=0}
    if spec.prepare then spec.prepare() end
    return true
  end
  function p.update(dx)
    if not held then return end
    held.dx=dx
    local x=held.x+dx
    local bound=math.max(-spec.offset(spec.count),math.min(0,x))
    -- Elastic resistance only beyond the first and last page.
    local extra=x-bound
    spec.track.translate_x=bound+extra/(1+math.abs(extra)/90)
  end
  function p.finish(vx,canceled)
    if not held then return end
    local index=held.index
    if not canceled then
      local closest=math.huge
      for i=1,spec.count do
        local distance=math.abs(spec.track.translate_x+spec.offset(i))
        if distance<closest then index,closest=i,distance end
      end
      if math.abs(vx)>=650 and math.abs(held.dx)>=24 then
        index=math.max(1,math.min(spec.count,held.index+(vx<0 and 1 or -1)))
      end
    end
    held=nil
    was=index
    spec.tab:set(index)
    settle(index)
  end
  return p
end
return M
