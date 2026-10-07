-- Lock and greet share one form. The controller owns secrets and submission;
-- this module only arranges the account, entry and status above the keyboard.
local morf=require("morf")
local base_ui=require("morf.ui")
local M={}

function M.password(ctx)
  local ui,s,C=ctx.ui or base_ui,ctx.s,ctx.C
  local W,H=ctx.width,ctx.height
  local dot=math.min(s(10),math.max(1,math.floor((W-s(120))/ctx.max_dots*.65)))
  local dots={}
  for i=1,ctx.max_dots do
    dots[i]=ui.Rect {width=dot,height=dot,radius=dot/2,
      color=function() return C.primary end,visible=function() return ctx.typed:get()>=i end}
  end
  return ui.Item {id=ctx.prefix.."-field",width=W,height=H,
    translate_x=function() return ctx.shake:get()==1 and s(8) or 0 end,
    behavior={translate_x=ui.spring {stiffness=900,damping=9}},
    ui.Rect {id=ctx.prefix.."-field-surface",anchors={fill=true},radius=s(16),
      color=function() return C.surfaceContainerHighest end,
      border_width=function() return ctx.bad:get() and s(2) or 0 end,
      border_color=function() return C.error end},
    ui.MouseArea {id=ctx.prefix.."-keyboard-focus",anchors={fill=true},on_clicked=ctx.focus},
    ctx.icon(function() return ctx.busy:get() and "hourglass" or "lock" end,s(22),C.onSurfaceVariant,
      {x=s(18),anchors={vertical_center=true}}),
    ctx.text {x=s(52),anchors={vertical_center=true},text="Password",font_size=s(16),
      color=C.onSurfaceVariant,visible=function() return ctx.typed:get()==0 end},
    ui.Row {x=s(52),anchors={vertical_center=true},gap=dot*.45,table.unpack(dots)},
    ui.MouseArea {id=ctx.prefix.."-submit",cursor="pointer",
      anchors={right=true,right_margin=s(7),vertical_center=true},width=H-s(14),height=H-s(14),
      on_clicked=ctx.submit,
      ui.Rect {id=ctx.prefix.."-submit-surface",anchors={fill=true},radius=s(12),
        color=function() return ctx.typed:get()>0 and C.primary or C.surfaceContainerHigh end},
      ctx.icon("arrow_forward",s(22),function() return ctx.typed:get()>0 and C.onPrimary or C.onSurfaceVariant end,
        {anchors={center_in=true}})},
  }
end

function M.sheet(ctx)
  local ui,s,C=ctx.ui or base_ui,ctx.s,ctx.C
  local W,PAD=ctx.width,s(24)
  local inner,AV=W-2*PAD,s(52)
  local function spacer(h) return ui.Item {width=1,height=h} end
  local header=ui.Item {id=ctx.prefix.."-identity",width=inner,height=AV,
    ctx.avatar,
    ctx.text {x=AV+s(16),y=0,width=math.max(1,inner-AV-s(16)),height=s(20),
      text=ctx.prefix=="lock" and "Unlock" or "Sign in",font_size=s(13),color=C.onSurfaceVariant},
    (ctx.heading or ctx.text) {id=ctx.prefix.."-name",x=AV+s(16),y=s(22),
      width=math.max(1,inner-AV-s(16)),height=s(28),elide="right",
      text=ctx.name,font_size=s(20),font_weight=600,active=ctx.active},
  }
  local entry_top=PAD+AV+s(20)
  local function entry_bottom() return entry_top+ctx.entry_height()+s(8)+s(24) end
  local function content_height()
    return entry_bottom()+(ctx.session and s(52) or 0)+ctx.method_height()+PAD+ctx.keyboard.inline_height()
  end
  local bottom=ctx.border+s(12)+(ctx.footer or 0)
  local function height()
    return math.min(content_height(),math.max(1,ctx.keyboard.content_height()-ctx.top-bottom))
  end
  local nodes={x=PAD,y=PAD,width=inner,align="center",gap=0,
    header,spacer(s(20)),ctx.entry,spacer(s(8)),ctx.message,
  }
  if ctx.session then nodes[#nodes+1]=spacer(s(12)) nodes[#nodes+1]=ctx.session end
  nodes[#nodes+1]=ctx.method
  nodes[#nodes+1]=spacer(PAD)
  if ctx.keyboard.embedded then
    nodes[#nodes+1]=ui.Item {width=inner,height=ctx.keyboard.inline_height,
      visible=ctx.keyboard.active,ctx.keyboard.node}
  end
  local scroll,viewport=require("lib.kit.scroll").make("scroll_view",{
    id=ctx.prefix.."-sheet-scroll",width=W,height=height,clip=true,ui.Column(nodes)})
  morf.effect(ctx.prefix..".sheet-scroll."..ctx.output,function()
    if not ctx.active() then viewport.content_y=0 return end
    -- Keep the input and its error visible when the available height is small.
    viewport.content_y=math.min(entry_top,math.max(0,entry_bottom()-height()+s(12)))
  end,{owner=viewport})
  local sheet=ui.Item {id=ctx.prefix.."-sheet",width=W,height=height,
    x=math.floor((ctx.screen_width-W)/2),
    y=function() return ctx.keyboard.content_height()-bottom-height() end,
    visible=ctx.visible,opacity=function() return ctx.active() and 1 or 0 end,
    -- The keyboard changes the usable viewport immediately. No spring or
    -- delayed translation may carry a control through the dock while resizing.
    behavior={opacity={duration=160}},
    ui.Rect {id=ctx.prefix.."-card",anchors={fill=true},radius=s(24),
      color=function() return ctx.skin.sheet_color and ctx.skin.sheet_color() or C.surfaceContainer end},
    scroll,
    ctx.keyboard.surface {id=ctx.prefix.."-sheet-handle",x=0,y=0,width=W,height=s(18),z=10},
  }
  if ctx.skin.sheet then ctx.skin.sheet(sheet,{role=ctx.prefix,width=W,scale=s,active=ctx.active}) end
  return {node=sheet,height=height}
end
return M
