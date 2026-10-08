-- A transient touch scroll indicator, shared by the phone themes.
local morf=require("morf")
local ui=require("morf.ui")

return function(t,spec,theme)
  local flick=spec.flick
  local function extent() return math.max(0,t.viewport_height-8) end
  local function length() return math.min(extent(),math.max(24,math.min(72,t.size_y*extent()))) end
  local thumb=ui.Rect {
    id=spec.id and (spec.id.."-indicator"),
    anchors={right=true,right_margin=3},width=3,height=length,radius=1.5,z=20,
    color=function() return theme.color.onSurface end,
    visible=function() return t.bar_y end,opacity=0,
    y=function()
      local room=math.max(1,t.content_height-t.viewport_height)
      local position=math.max(0,math.min(1,(flick.content_y or 0)/room))
      return 4+position*(extent()-length())
    end,
  }
  local last=flick.content_y or 0
  local timeout,fade
  morf.effect("phone.scroll.indicator."..tostring(flick),function()
    local offset=flick.content_y or 0
    if offset==last then return end
    last=offset
    if timeout then timeout:cancel() end
    if fade then fade:stop() fade=nil end
    thumb.opacity=.6
    timeout=morf.timer(450,function()
      timeout=nil
      fade=morf.animation.play {{node=thumb,property="opacity",to=0,duration=220,easing="out_cubic"}}
    end,false)
  end,{owner=thumb})
  return {scroll_bar_y=thumb}
end
