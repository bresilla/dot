-- Morf draws snapshots while a bottom-edge drag is held. The compositor
-- receives a normal workspace command only after a completed swipe.
local morf=require("morf")
local ui=require("morf.ui")
local services=require("services")
local hypr=require("lib.integrations.hyprland")
local M={}
function M.new(root)
  local state=morf.state {active=false,offset=0,from=1,target=1}
  local pages,shots={},{}
  local generation=0
  local animation
  -- Keep the real shell frame, rail and its decorations above the preview.
  local viewport=ui.Item {id="phone-workspace-preview",z=-1,clip=true,
    x=function() return select(1,require("bar").desk()) end,
    y=function() return select(2,require("bar").desk()) end,
    width=function() return select(3,require("bar").desk()) end,
    height=function() return select(4,require("bar").desk()) end,
    visible=function() return state.active end}
  ui.reparent(viewport,root)
  local style=morf.state {border=0,rounding=0,active="#ffffff",inactive="#808080"}
  local function refresh_style()
    if not hypr.options then return end
    hypr.options({"general:border_size","decoration:rounding","general:col.active_border",
      "general:col.inactive_border"},function(options)
      if not options then return end
      style.border=math.max(0,tonumber((options["general:border_size"] or {}).int) or 0)
      style.rounding=math.max(0,tonumber((options["decoration:rounding"] or {}).int) or 0)
      for _,kind in ipairs {"active","inactive"} do
        local gradient=(options["general:col."..kind.."_border"] or {}).gradient or ""
        local argb=gradient:match("^%s*(%x%x%x%x%x%x%x%x)")
        if argb then style[kind]="#"..argb:sub(3)..argb:sub(1,2) end
      end
    end)
  end
  refresh_style()
  local function width() return math.max(1,(select(3,require("bar").desk()))) end
  local function release(source)
    if source and source~="" and morf.screencopy then pcall(morf.screencopy.release,source) end
  end
  local function clear()
    generation=generation+1
    if animation then animation:stop() animation=nil end
    state.active=false
    for _,node in ipairs(pages) do ui.destroy(node) end
    for source in pairs(shots) do release(source) end
    pages,shots={},{}
  end
  local function neighbor(id,delta)
    local other={}
    local model=hypr.state.workspaces
    for i=1,model:len() do
      local row=model:get(i)
      if row.monitor~="" and row.monitor~=services.output() then other[row.id]=true end
    end
    local target=id+delta
    while target>0 and other[target] do target=target+delta end
    return math.floor(math.max(1,target))
  end
  local function toplevel(client)
    local found
    for _,window in ipairs(morf.windows or {}) do
      if window.app_id==client.class and window.title==client.title then
        if found then return nil end -- identical titles must not show the wrong window
        found=window.identifier
      end
    end
    return found
  end
  local function page(id,position,queue)
    local C=require("theme").color
    local w,h=width(),select(4,require("bar").desk())
    local node=ui.Item {id="phone-workspace-page-"..position,width=w,height=h,clip=true,
      x=function() return position*w+state.offset end,
      ui.Rect {anchors={fill=true},z=-2,color=function() return C.surface end},
      ui.Image {anchors={fill=true},z=-1,fill_mode="preserve_aspect_crop",
        source=function() return require("wallpaper").current:get() end},
    }
    ui.reparent(node,viewport) pages[#pages+1]=node
    local dx,dy=select(1,require("bar").desk()),select(2,require("bar").desk())
    local mx,my,ratio=0,0,1
    local monitors=hypr.state.monitors
    for i=1,monitors:len() do
      local row=monitors:get(i)
      if row.name==services.output() then
        mx,my=row.x,row.y
        -- Fullscreen surfaces request width=0 (automatic). The screen
        -- reports the actual size, including Morf's current density.
        local screen=(morf.screens or {})[1]
        ratio=((screen and screen.width) or row.width/row.scale)/math.max(1,row.width/row.scale)
      end
    end
    local clients=hypr.state.clients
    local count=0
    for i=1,clients:len() do
      local c=clients:get(i)
      if c.workspace==id and c.mapped~=false and not c.hidden and count<12
        and (position==0 or id~=state.from) then
        count=count+1
        local source=morf.signal("phone.workspace.shot."..generation.."."..position.."."..i,"")
        local decorated=not c.fullscreen or c.fullscreen==0
        local function border() return decorated and style.border*ratio or 0 end
        local function rounding() return decorated and style.rounding*ratio or 0 end
        local cw,ch=math.max(1,c.width*ratio),math.max(1,c.height*ratio)
        local card=ui.Item {id="phone-workspace-window-"..position.."-"..i,z=1,
          width=cw,height=ch,x=(c.x-mx)*ratio-dx,y=(c.y-my)*ratio-dy,
          ui.Rect {id="phone-workspace-border-"..position.."-"..i,
            x=function() return -border() end,y=function() return -border() end,
            width=function() return cw+2*border() end,height=function() return ch+2*border() end,
            radius=function() return rounding()+border() end,
            color=function() return c.active and style.active or style.inactive end},
          ui.ClipRect {anchors={fill=true},radius=rounding,color=function() return C.surfaceContainer end,
            ui.Text {anchors={center_in=true},width=math.max(1,cw-24),
              text=c.title~="" and c.title or c.class,elide="right",horizontal_alignment="center",
              font_family=require("theme").font,color=function() return C.onSurface end},
            ui.Image {anchors={fill=true},fill_mode="stretch",source=function() return source:get() end},
          },
        }
        ui.reparent(card,node)
        local identifier=toplevel(c)
        if identifier then queue[#queue+1]={identifier=identifier,source=source} end
      end
    end
    ui.reparent(ui.Text {id="phone-workspace-label-"..position,x=16,y=16,z=2,
      text=("Workspace %d"):format(id),font_family=require("theme").font,font_size=18,
      color=function() return C.onSurface end},node)
  end
  local next_id,previous_id
  local g={state=state}
  function g.begin()
    clear()
    refresh_style()
    state.from=services.workspace.active()
    state.target=state.from state.offset=0
    previous_id,next_id=neighbor(state.from,-1),neighbor(state.from,1)
    local queue={}
    page(state.from,0,queue) page(previous_id,-1,queue) page(next_id,1,queue)
    state.active=true
    local token=generation
    local index=0
    local function capture_next()
      if token~=generation then return end
      index=index+1
      local item=queue[index]
      if not item or not morf.screencopy or not morf.screencopy.capture_window then return end
      local ok=pcall(morf.screencopy.capture_window,item.identifier,function(frame)
        if frame and frame.source then
          if token~=generation then release(frame.source) return end
          shots[frame.source]=true item.source:set(frame.source)
        end
        capture_next()
      end,{gpu=true})
      if not ok then capture_next() end
    end
    capture_next()
    return true
  end
  function g.update(dx)
    if not state.active then return end
    local w=width()
    state.offset=math.max(-w,math.min(w,dx))
    state.target=dx<0 and next_id or previous_id
    if state.target==state.from then state.offset=state.offset*.2 end
    for i,node in ipairs(pages) do node.x=(i==1 and 0 or i==2 and -w or w)+state.offset end
  end
  function g.finish(canceled)
    if not state.active then return end
    local commit=not canceled and math.abs(state.offset)>=width()*.35 and state.target~=state.from
    local target=state.target
    local final=commit and (state.offset<0 and -width() or width()) or 0
    local steps={}
    for i,node in ipairs(pages) do
      steps[#steps+1]={node=node,property="x",to=(i==1 and 0 or i==2 and -width() or width())+final,
        duration=160,easing="out_cubic"}
    end
    animation=morf.animation.play {{parallel=steps},on_finished=function(reason)
      if reason~="completed" then return end
      if commit then services.workspace.go(math.floor(target)) end
      clear()
    end}
  end
  function g.cancel() clear() end
  return g
end
return M
