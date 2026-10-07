-- Tsugumori motion, adapted from its MIT-licensed Menu and ControlCenterView.
-- See REFERENCE.md and LICENSE-Tsugumori. Reversals retain the current pose.
local morf = require("morf")
local ui = require("morf.ui")
return function(theme)
  local M = { liquid_cards = false,
    value_flash=require("themes.tsugumori.value_flash")(theme),
    auth_result=require("themes.tsugumori.auth_result")(theme),
    notification_acquire=require("themes.tsugumori.notification_acquire")(theme) }
  -- Keep the cover/swap/reveal order, with a shorter, consistent cadence.
  local PAGE_COVER, REVEAL = 140, 220
  local ENTER, COVER, WITHDRAW = 280, 230, 270
  local ENTRY_DELAY, ENTRY_MOVE, ENTRY_LEAVE, STAGGER = 180, 240, 120, 50
  function M.page_wipe(host, width, id)
    local cover = ui.Rect { id = id .. "-page-curtain", z = 90,
      anchors = { top = true, bottom = true }, x = 0, width = 0, visible = false,clip=true,
      color=function() return theme.color.primary end,
      require("lib.kit.widgets").shield { anchors = { fill = true } },
    }
    -- This stroke is a sibling of the cover: children of a clipped, animated
    -- rectangle are not reliably composited above its fill by the renderer.
    local glow = ui.Rect { id=id.."-page-glow",z=91,x=-12,width=16,
      anchors={top=true,bottom=true},color=function() return theme.color.secondary end,
      opacity=0,visible=false }
    local flash = ui.Rect { id=id.."-page-flash",z=92,x=0,width=4,
      anchors={top=true,bottom=true},color=function() return theme.color.onSurface end,
      opacity=0,visible=false }
    local register = ui.Text {id=id.."-page-register",z=93,x=22,y=18,
      width=function() return math.max(1,width()-44) end,height=22,
      font_family=theme.font,font_size=12,letter_spacing=2,
      color=function() return theme.color.onPrimary end,
      text="",opacity=0,visible=false}
    ui.reparent(cover, host)
    ui.reparent(glow, host)
    ui.reparent(flash, host)
    ui.reparent(register,host)
    local running, generation = nil, 0
    return function(swap, immediate, destination)
      generation = generation + 1
      local own = generation
      if running then running:stop() end
      flash.visible,flash.opacity,glow.visible,glow.opacity=false,0,false,0
      register.visible,register.opacity=false,0
      register.x=22
      if immediate then cover.visible = false cover.width = 0 swap() return end
      if destination then
        register.text=("%02d / %s"):format(destination.index or 0,
          tostring(destination.name or destination.key or id):upper())
      else register.text=("TS / %s"):format(id:upper()) end
      register.visible=true
      cover.visible = true
      running = morf.animation.play { { parallel = {
        { node = cover, property = "x", to = 0, duration = PAGE_COVER, easing = "in_out_quint" },
        { node = cover, property = "width", to = width(), duration = PAGE_COVER, easing = "in_out_quint" },
        { node = register, property = "opacity",from=0,to=.85,duration=PAGE_COVER,easing="out_cubic" },
      } }, on_finished = function(reason)
        if reason ~= "completed" or own ~= generation then return end
        swap()
        flash.x,flash.visible,glow.x,glow.visible=0,true,-12,true
        running = morf.animation.play { { parallel = {
          { node = cover, property = "x", to = width(), duration = REVEAL, easing = "out_expo" },
          { node = cover, property = "width", to = 0, duration = REVEAL, easing = "out_expo" },
          { node = register, property = "opacity",to=0,duration=100,easing="out_cubic" },
          { node = register, property = "x",to=width()+22,duration=REVEAL,easing="out_expo" },
          { node = flash, property = "x", to = width(), duration = REVEAL, easing = "out_expo" },
          { node = glow, property = "x", to = width()-12, duration = REVEAL, easing = "out_expo" },
          { node = glow, property = "opacity",duration=REVEAL,keyframes={
            {at=0,value=0},{at=.12,value=.22},{at=.68,value=.17},{at=1,value=0} } },
          { node = flash, property = "opacity",duration=REVEAL,keyframes={
            {at=0,value=0},{at=.12,value=.9},{at=.68,value=.72},{at=1,value=0} } },
        } }, on_finished = function(why)
          if why == "completed" and own == generation then
            cover.visible,flash.visible,glow.visible,register.visible=false,false,false,false
          end
        end }
      end }
    end
  end
  function M.entries(entries, coming, opts)
    if require("themes.session").restoring then
      for _, entry in ipairs(entries) do
        entry.node.opacity = coming and 1 or 0
        entry.node.scale, entry.node.translate_x, entry.node.translate_y = 1, 0, 0
        if entry.shape then entry.shape.opacity = coming and 1 or 0 end
      end
      return {}, 0
    end
    opts = opts or {}
    local handles = {}
    for k, entry in ipairs(entries) do
      local node = entry.node
      local fresh = not (node.opacity > 0 and node.opacity < 1)
      local delay = coming and ((opts.delay or ENTRY_DELAY) + (k - 1) * (opts.stagger or STAGGER)) or 0
      local steps = {
        { node = node, property = "translate_x", from = coming and fresh and -12 or nil, to = coming and 0 or -12,
          delay = delay, duration = coming and ENTRY_MOVE or ENTRY_LEAVE, easing = "out_cubic" },
        { node = node, property = "translate_y", from = coming and fresh and -8 or nil, to = coming and 0 or -6,
          delay = delay, duration = coming and ENTRY_MOVE or ENTRY_LEAVE, easing = "out_cubic" },
        { node = node, property = "opacity", from = coming and fresh and 0 or nil, to = coming and 1 or 0,
          delay = delay, duration = coming and ENTRY_MOVE or ENTRY_LEAVE, easing = "out_cubic" },
      }
      if entry.shape then
        steps[#steps + 1] = { node = entry.shape, property = "opacity", from = coming and fresh and 0 or nil,
          to = coming and 1 or 0, delay = delay, duration = coming and ENTRY_MOVE or ENTRY_LEAVE }
      end
      handles[#handles + 1] = morf.animation.play { { parallel = steps } }
    end
    return handles, coming and ((opts.delay or ENTRY_DELAY) + ENTRY_MOVE + math.max(0, #entries - 1) * (opts.stagger or STAGGER)) or ENTRY_LEAVE
  end
  -- Menu.qml's covered entrance and uncover at a quicker cadence. Close
  -- covers before withdrawal so the visible content cannot be exposed during
  -- travel. Reversals retain the current pose of each active phase.
  function M.drawer(ctx)
    local panel, content, d = ctx.panel, ctx.spec.content, ctx.drawer
    local id="drawer-" .. (d.name or "auth")
    local curtain = require("themes.tsugumori.curtain")(theme, panel, id)
    local glow=ui.Rect {id=id.."-reveal-glow",z=101,x=-12,width=16,
      anchors={top=true,bottom=true},color=function() return theme.color.secondary end,
      opacity=0,visible=false}
    local flash=ui.Rect {id=id.."-reveal-flash",z=102,x=0,width=4,
      anchors={top=true,bottom=true},color=function() return theme.color.onSurface end,
      opacity=0,visible=false}
    ui.reparent(glow,panel)
    ui.reparent(flash,panel)
    local corner_a=ui.Path {id=id.."-lock-corner-a",z=103,anchors={left=true,top=true},
      width=16,height=16,view_box={0,0,16,16},d="M0 0 H16 V2 H2 V16 H0 Z",
      fill_color=function() return theme.color.secondary end,opacity=0,visible=false}
    local corner_b=ui.Path {id=id.."-lock-corner-b",z=103,anchors={right=true,bottom=true},
      width=16,height=16,rotation=180,view_box={0,0,16,16},d="M0 0 H16 V2 H2 V16 H0 Z",
      fill_color=function() return theme.color.secondary end,opacity=0,visible=false}
    local pip=ui.Rect {id=id.."-lock-pip",z=103,anchors={top=true,horizontal_center=true},
      y=7,width=5,height=5,color=function() return theme.color.primary end,
      opacity=0,visible=false}
    ui.reparent(corner_a,panel)
    ui.reparent(corner_b,panel)
    ui.reparent(pip,panel)
    local axis = ctx.floating and "translate_x" or ctx.axis
    local function tucked()
      return ctx.floating and (panel.width + 2) or ctx.tucked()
    end
    local running, lock_motion, generation = nil, nil, 0
    local function move(opening)
      generation = generation + 1
      local own = generation
      local hidden = not panel.visible
      if running then running:stop() end
      if lock_motion then lock_motion:stop() lock_motion=nil end
      corner_a.visible,corner_b.visible,pip.visible=false,false,false
      corner_a.opacity,corner_b.opacity,pip.opacity=0,0,0
      if hidden then
        panel[axis] = tucked()
        curtain.width, curtain.x = math.max(panel.width, panel.width_target or 0), 0
      end
      panel.visible, curtain.visible, content.opacity, d.shape.opacity = true, true, 1, 1
      flash.x,flash.visible,flash.opacity=curtain.x,true,0
      glow.x,glow.visible,glow.opacity=curtain.x-12,true,0
      local travel = math.min(1, math.abs((opening and 0 or tucked()) - panel[axis]) / math.max(1, math.abs(tucked())))
      local width = panel.width_target or panel.width
      local cover = math.min(1, curtain.width / math.max(1, width))
      local enter_ms = math.max(1, ENTER * travel)
      local easing = { x1 = 0.76, y1 = 0, x2 = 0.24, y2 = 1 }
      local function finish()
        if generation ~= own then return end
        running=nil
        panel.visible=d.open:get()
        curtain.visible,flash.visible,glow.visible=false,false,false
        if not opening then return end
        corner_a.visible,corner_b.visible,pip.visible=true,true,true
        lock_motion=morf.animation.play {{parallel={
          {node=corner_a,property="translate_x",from=-7,to=0,duration=280,easing="out_cubic"},
          {node=corner_a,property="translate_y",from=-7,to=0,duration=280,easing="out_cubic"},
          {node=corner_b,property="translate_x",from=7,to=0,duration=280,easing="out_cubic"},
          {node=corner_b,property="translate_y",from=7,to=0,duration=280,easing="out_cubic"},
          {node=corner_a,property="opacity",duration=360,keyframes={
            {at=0,value=0},{at=.18,value=.86},{at=.55,value=.56},{at=1,value=0}}},
          {node=corner_b,property="opacity",duration=360,keyframes={
            {at=0,value=0},{at=.18,value=.86},{at=.55,value=.56},{at=1,value=0}}},
          {node=pip,property="opacity",duration=360,keyframes={
            {at=0,value=0},{at=.12,value=1},{at=.32,value=0},
            {at=.55,value=1},{at=.75,value=0},{at=1,value=0}}},
        }},on_finished=function(reason)
          if generation~=own then return end
          if reason=="completed" and generation==own then
            corner_a.visible,corner_b.visible,pip.visible=false,false,false
          end
          lock_motion=nil
        end}
      end
      local function sweep(uncover,next_phase)
        local duration=math.max(1,uncover and REVEAL*cover or COVER*(1-cover))
        running=morf.animation.play {{parallel={
          {node=curtain,property="width",to=uncover and 0 or width,duration=duration,
            easing=uncover and "out_expo" or easing},
          {node=curtain,property="x",to=uncover and width or 0,duration=duration,
            easing=uncover and "out_expo" or easing},
          {node=flash,property="x",to=uncover and width or 0,duration=duration,
            easing=uncover and "out_expo" or easing},
          {node=glow,property="x",to=(uncover and width or 0)-12,duration=duration,
            easing=uncover and "out_expo" or easing},
          {node=glow,property="opacity",duration=duration,keyframes={
            {at=0,value=0},{at=.18,value=.22},{at=.48,value=.17},{at=1,value=0}}},
          {node=flash,property="opacity",duration=duration,keyframes={
            {at=0,value=0},{at=.18,value=.82},{at=.48,value=.58},{at=1,value=0}}},
        }},on_finished=function(reason)
          if reason=="completed" and generation==own then next_phase() end
        end}
      end
      if opening then
        running=morf.animation.play {{node=panel,property=axis,to=0,duration=enter_ms,
          easing="out_expo"},on_finished=function(reason)
          if reason=="completed" and generation==own then sweep(true,finish) end
        end}
      else
        sweep(false,function()
          running=morf.animation.play {{node=panel,property=axis,to=tucked(),
            duration=math.max(1,WITHDRAW*travel),easing=easing},on_finished=function(reason)
            if reason=="completed" then finish() end
          end}
        end)
      end
    end
    return move, function()
      generation = generation + 1
      if running then running:stop() running=nil end
      if lock_motion then lock_motion:stop() lock_motion=nil end
      for _, node in ipairs {curtain,glow,flash,corner_a,corner_b,pip} do node.visible=false end
    end
  end
  return M
end
