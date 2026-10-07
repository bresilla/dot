-- A finite, event-driven marker beside a readout. The data callback is not
-- read while its page is hidden; reopening establishes a fresh baseline.
local morf=require("morf")
local ui=require("morf.ui")
return function(theme)
  return function(host,id,spec)
    local mark=ui.Rect {id=id.."-change-flash",x=spec.x,y=spec.y,
      width=3,height=spec.height or 22,color=function() return theme.color.secondary end,
      opacity=0}
    ui.reparent(mark,host)
    local previous,running,cooling=nil,nil,false
    morf.effect(id..".meaningful-change",function()
      if not spec.active() then
        previous=nil
        if running then running:stop() running=nil end
        mark.opacity=0
        return
      end
      local current=spec.read()
      if current==nil then previous=nil return end
      local meaningful=previous~=nil and spec.changed(previous,current)
      previous=current
      if not meaningful or cooling then return end
      cooling=true
      morf.timer(spec.cooldown or 4000,function() cooling=false end,false)
      if running then running:stop() end
      running=morf.animation.play {{node=mark,property="opacity",duration=460,
        keyframes={{at=0,value=0},{at=.14,value=1},{at=.48,value=.62},{at=1,value=0}}}}
    end,{owner=host})
    return mark
  end
end
