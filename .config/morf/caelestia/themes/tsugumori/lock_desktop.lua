local stroke = require("themes.tsugumori.strokes")
-- Resting-screen instruments. Readers and playback commands are injected.
local morf=require("morf")
local ui=require("morf.ui")
local tokens=require("themes.tsugumori.tokens")
return function(ctx,W,H,main,output,s)
  local C=ctx.C
  local desktop=ctx.desktop.for_output(output)
  local compact=W<1000 or W<H
  local width=math.min(s(370),W-2*s(40))
  local function active() return main() and ctx.stage:get()=="rest" end
  local function weather() return active() and desktop.weather() or {} end
  local function player() return active() and desktop.player() or {} end
  local function text(props)
    props.font_family=tokens.font
    props.font_size=props.font_size or s(tokens.typography.subtitle)
    props.color=props.color or function() return C.onSurfaceVariant end
    return ui.Text(props)
  end
  local function heading(id,value,x,y,w,level)
    return require("themes.tsugumori.heading")({color=C},{text=text},{id=id,text=value,x=x,y=y,width=w,
      font_size=s(tokens.typography[level or "caption"]),active=active,reveal_delay=560})
  end
  local feedback=require("themes.tsugumori.interaction")({color=C})
  local function button(id,icon,action,x)
    local area
    area=require("lib.kit.widgets").area {id=id,x=x,y=s(154),width=(width-2*s(16)-2*s(8))/3,height=s(34),cursor="pointer",
      on_clicked=function() if active() then desktop.control(action) end end,
      ui.Rect {anchors={fill=true},border_width=1,border_color=function() return stroke(C,"idle") end,
        color=function() return area and area.hovered and C.primaryContainer or C.surfaceContainerHigh end},
      ui.Text {anchors={center_in=true},font_family=tokens.icon_font,font_size=s(20),text=icon,
        color=function() return C.primary end,axes={FILL=1}}}
    return feedback(area,id)
  end
  local step=(width-2*s(16)+s(8))/3
  local node=ui.Item {id="lock-desktop",width=width,height=s(202),
    x=compact and (W-width)/2 or W-width-s(60),
    y=compact and H-s(250) or H*.34,visible=active,
    ui.Rect {anchors={fill=true},border_width=1,border_color=function() return stroke(C,"quiet") end,
      color=function() return C.surfaceContainer end},
    heading("lock-weather-title","Weather",s(16),s(12),width-s(32)),
    text {id="lock-weather-temperature",x=s(16),y=s(34),font_size=s(28),color=function() return C.primary end,
      text=function() local w=weather() return w.temperature and ("%d°"):format(math.floor(w.temperature+.5)) or "—" end},
    text {id="lock-weather-condition",x=s(104),y=s(42),width=width-s(120),elide="right",
      text=function() return weather().condition or "Weather unavailable" end},
    ui.Rect {x=s(16),y=s(78),width=width-s(32),height=1,color=function() return stroke(C,"quiet") end},
    heading("lock-media-title",function() return player().title or "Nothing playing" end,s(16),s(91),width-s(32),"section"),
    text {id="lock-media-artist",x=s(32),y=s(123),width=width-s(48),elide="right",
      text=function() return player().artist or "Playback controls" end},
    button("lock-media-previous","skip_previous","previous",s(16)),
    button("lock-media-play",function() return player().playing and "pause" or "play_arrow" end,"play_pause",s(16)+step),
    button("lock-media-next","skip_next","next",s(16)+2*step),
  }
  local running, was
  morf.effect("tsugumori.lock-desktop."..tostring(output),function()
    local on=active()
    if was==on then return end
    was=on
    if running then running:stop() running=nil end
    if on then
      running=morf.animation.play {{parallel={
        {node=node,property="opacity",from=0,to=1,delay=280,duration=420,easing="out_cubic"},
        {node=node,property="translate_y",from=s(12),to=0,delay=280,duration=420,easing="out_cubic"},
      }}}
    else node.opacity,node.translate_y=0,0 end
  end,{owner=node})
  return node
end
