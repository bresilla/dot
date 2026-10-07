-- One soft reload for all outputs, after every output has covered its panels.
-- The handoff contains UI state only; passwords and running jobs never cross it.
local morf = require("morf")
local ui = require("morf.ui")
local session = require("themes.session")
local themes = require("themes")
local M = {
  busy = morf.signal("caelestia.appearance.busy", session.restoring),
  message = morf.signal("caelestia.appearance.message", ""),
}
local own = (morf.screens[1] or {}).name or "headless"
local transaction, timeout, guard, chrome = nil, nil, nil, {}
local covers, animations = {}, {}
local geometry = {}
local mode = session.transition and session.transition.mode or "wipe"
local FEATHER, COVER, REVEAL = 80, 220, 380
local requested = false
local function resolve(target)
  if target == "material" or target == "tsugumori" then return target, themes.font or "" end
  if type(target) == "string" and target:sub(1,5) == "font:" then
    local family = target:sub(6)
    if #family <= 200 and not family:find("[%c]") then return themes.current.id, family end
  end
end
local function unchanged(target)
  local style, font = resolve(target)
  return not style or (style == themes.current.id and font == (themes.font or ""))
end
local function primary() return not morf.primary or morf.primary() end
local function stop()
  for _, animation in ipairs(animations) do animation:stop() end
  animations = {}
end
local function play(node, property, to, duration, delay, easing)
  animations[#animations + 1] = morf.animation.play {{node=node,property=property,to=to,
    duration=duration,delay=delay or 0,easing=easing or "out_cubic"}}
end
local function transfer(entry,duration,covering)
  local ribbon=entry.ribbon
  ribbon.opacity=0
  if mode~="wipe" then return end
  local width=entry.drawer.panel.layout_width
  ribbon.translate_x=covering and -FEATHER or 0
  play(ribbon,"translate_x",width+FEATHER,duration,0,"in_out_cubic")
  animations[#animations+1]=morf.animation.play {{node=ribbon,property="opacity",duration=duration,
    keyframes={{at=0,value=0},{at=.18,value=.5},{at=.62,value=.35},{at=1,value=0}}}}
end
local function reveal(cancelled)
  stop()
  local duration=cancelled and 180 or REVEAL
  for _, node in ipairs(chrome) do play(node,"opacity",1,duration) end
  for _, entry in ipairs(geometry) do play(entry.node,entry.property,entry.target,duration) end
  for _, entry in ipairs(covers) do
    entry.ribbon.opacity=0
    if entry.drawer.open:get() then
      if not cancelled then transfer(entry,duration,false) end
      if mode=="dissolve" then play(entry.paint,"opacity",0,duration)
      else play(entry.paint,"translate_x",(cancelled and -1 or 1)*(entry.drawer.panel.layout_width+FEATHER),duration) end
    end
  end
  morf.timer(duration+20,function() M.busy:set(false) end,false)
end
local function send(phase, id, value)
  if not morf.broadcast("appearance-sync",phase,id,value) then M.receive(phase,id,value) end
end
local function clear_timer()
  if timeout then timeout:cancel() timeout=nil end
end
local function abort(reason)
  clear_timer()
  transaction=nil
  session.abort()
  M.message:set(reason or "The theme could not be changed.")
  reveal(true)
end
function M.attach(drawer)
  local palette=require("theme").color
  local color=palette.surfaceContainer
  local paint=ui.Item {id="theme-cover-"..drawer.name,anchors={fill=true},
    ui.Rect {anchors={fill=true},color=color},
    ui.Rect {x=-FEATHER,anchors={top=true,bottom=true},width=FEATHER,
      gradient={angle=90,stops={color:alpha(0),color}}},
    ui.Rect {x=function() return drawer.panel.layout_width or drawer.panel.width or 0 end,anchors={top=true,bottom=true},width=FEATHER,
      gradient={angle=90,stops={color,color:alpha(0)}}}}
  paint.translate_x=session.restoring and 0 or -10000
  local ribbon=ui.Rect {id="theme-transfer-"..drawer.name,z=1,x=-24,width=48,
    anchors={top=true,bottom=true},opacity=0,
    gradient={angle=90,stops={palette.primary:alpha(0),palette.primary,
      palette.secondary,palette.secondary:alpha(0)}}}
  local mask=ui.ClipRect {anchors={fill=true},z=10000,color="transparent",
    top_left_radius=drawer.shape.top_left_radius,top_right_radius=drawer.shape.top_right_radius,
    bottom_left_radius=drawer.shape.bottom_left_radius,bottom_right_radius=drawer.shape.bottom_right_radius,
    visible=function() return M.busy:get() end,paint,ribbon}
  for _,corner in ipairs {
    {"top_left_radius","top","left"},{"top_right_radius","top","right"},
    {"bottom_left_radius","bottom","left"},{"bottom_right_radius","bottom","right"},
  } do
    local target=(drawer.edge==corner[2] or drawer.edge==corner[3]) and 0 or require("theme").ROUNDING
    M.morph(mask,corner[1],target,drawer.shape[corner[1]])
  end
  ui.reparent(mask,drawer.panel)
  covers[#covers+1]={drawer=drawer,paint=paint,ribbon=ribbon}
end
-- Carry the existing frame/drawer silhouette through the reload, then morph
-- its corners and seams as the new controls become visible.
function M.morph(node, property, target, previous)
  if not session.restoring or previous==nil or previous==target then return end
  node[property]=previous
  geometry[#geometry+1]={node=node,property=property,target=target}
end
function M.fade(node)
  if not node then return end
  if session.restoring then node.opacity=0 end
  chrome[#chrome+1]=node
end
function M.blocker()
  return ui.MouseArea {id="theme-switch-blocker",anchors={fill=true},z=20000,
    visible=function() return M.busy:get() end,on_clicked=function() end}
end
function M.request(target)
  if M.busy:get() or unchanged(target) then return false end
  local reason=guard and guard()
  if reason then M.message:set(reason) return false end
  send("request",target,own)
  return true
end
function M.request_font(family)
  if type(family) ~= "string" then return false end
  return M.request("font:" .. family)
end
function M.receive(phase,id,value)
  if phase=="request" then
    if not primary() or requested or M.busy:get() or unchanged(id) then return end
    requested=true
    local token=own..":"..tostring(morf.time.now_ms())
    send("prepare",token,id)
  elseif phase=="prepare" then
    requested=false
    local style, font = resolve(value)
    if not style then return end
    if transaction or M.busy:get() then send("reject",id,"A theme change is already in progress.") return end
    local reason=guard and guard()
    if reason then send("reject",id,reason) return end
    local expected={}
    for _,screen in ipairs(morf.screens) do expected[screen.name]=true end
    if next(expected)==nil then expected[own]=true end
    transaction={id=id,target=value,expected=expected,ready={}}
    mode=style==themes.current.id and "dissolve" or "wipe"
    M.busy:set(true) M.message:set("")
    stop()
    for _,entry in ipairs(covers) do
      if entry.drawer.open:get() then
        transfer(entry,COVER,true)
        entry.paint.opacity=mode=="dissolve" and 0 or 1
        entry.paint.translate_x=mode=="dissolve" and 0 or -entry.drawer.panel.layout_width-FEATHER
        play(entry.paint,mode=="dissolve" and "opacity" or "translate_x",mode=="dissolve" and 1 or 0,COVER,0,"in_out_cubic")
      end
    end
    for _,node in ipairs(chrome) do play(node,"opacity",0,200) end
    timeout=morf.timer(6000,function()
      if transaction and transaction.id==id then send("reject",id,"Theme change timed out. Please try again.") end
    end,false)
    morf.timer(COVER+20,function()
      if not transaction or transaction.id~=id then return end
      local why=guard and guard()
      if why then send("reject",id,why) return end
      local tokens=themes.current.tokens or {}
      session.capture(style,font,{mode=mode,rounding=tokens.ROUNDING,seam=tokens.SEAM,
        frame_rounding=themes.current.id~="material" and 0 or tokens.ROUNDING})
      send("ready",id,own)
    end,false)
  elseif phase=="ready" then
    if not primary() or not transaction or transaction.id~=id then return end
    transaction.ready[value]=true
    for name in pairs(transaction.expected) do if not transaction.ready[name] then return end end
    if transaction.reloading then return end
    transaction.reloading=true
    morf.reload()
  elseif phase=="reject" then
    if not transaction then M.message:set(value) return end
    if transaction.id~=id then return end
    abort(value)
  end
end
function M.start(check)
  guard=check
  morf.ipc["appearance-sync"]=M.receive
  morf.ipc.appearance=function(target,output)
    if output and output~=own then return end
    if target=="state" then target=nil end
    if target and (not require("services").here()) then return end
    if target then return M.request(target) end
    return {theme=themes.current.id,font=themes.font or "",busy=M.busy:get(),message=M.message:get(),output=own}
  end
  -- An authentication request arriving during the covering animation cancels it.
  morf.effect("caelestia.appearance.guard",function()
    local reason=guard()
    if reason and transaction then send("reject",transaction.id,reason) end
  end)
  morf.on_reload_failed(function()
    if transaction then send("reject",transaction.id,"Could not load that theme. Your previous theme is still active.") end
  end)
  morf.on_reload_completed(function()
    if not session.restoring then return end
    if primary() then
      themes.preferences.set("theme",themes.current.id)
      themes.preferences.set("font",themes.font or "")
      themes.preferences.flush()
    end
    session.finish()
    -- Let layout and initial effects settle behind the fully closed cover.
    morf.timer(16,function() reveal() end,false)
  end)
end
return M
