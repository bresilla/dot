-- Touch gestures belong to the whole frame, including touches that start
-- on its bar or workspace rail. Only the edge strips claim new input area;
-- the middle of the desktop continues to belong to application windows.
local ui = require("morf.ui")
local M = {}
-- Dotfiles can update before the installed engine. Older Morf releases
-- keep their completed-swipe handling until continuous pans are available.
local probe = ui.Item {}
M.continuous = pcall(function() probe.on_panned = function() end end)
ui.destroy(probe)
local attached = {}
local EDGE = 20 -- Matches the runtime's on_edge_swiped recognition zone.

local function phone() return require("responsive").portrait() end

local function blocked()
  for _, name in ipairs { "polkit", "keyring", "authsteps", "session" } do
    local controller = package.loaded[name]
    if controller and controller.drawer and controller.drawer.open:get() then return true end
  end
  local capture = package.loaded.capture
  return capture and capture.editor and capture.editor.active:get()
end

local function close_other_panels(keep)
  for _, drawer in ipairs(require("drawer").all) do
    if drawer ~= keep and drawer.name~="keyboard" then drawer.set(false) end
  end
end

local function top_page(x)
  local width=(morf.screens[1] or {}).width or morf.surface.width
  return (tonumber(x) or 0)>=width/2 and "settings" or "notifications"
end

local function select_top(sidebar,x)
  local page=top_page(x)
  sidebar.select(page)
  if page=="settings" then require("utilities").request("") end
end

function M.swipe(edge,x)
  if not phone() or blocked() then return end
  if edge == "top" then
    local sidebar = require("sidebar")
    close_other_panels(sidebar.drawer)
    select_top(sidebar,x)
    sidebar.drawer.set(true)
  elseif edge == "bottom" then
    local dashboard = require("dashboard").drawer
    close_other_panels(dashboard)
    dashboard.set(true)
  end
end

-- Horizontal navigation belongs to a panel, not a fullscreen gesture
-- overlay. The runtime bubbles a swipe past passive content, retaining a
-- slider's drag and a notification's own dismissal.
function M.panel(spec)
  return function(direction)
    if not phone() or blocked() then return end
    if direction == "left" or direction == "right" then
      local next_tab = spec.tab:get() + (direction == "left" and 1 or -1)
      spec.tab:set(math.max(1, math.min(spec.count, next_tab)))
    elseif direction == spec.dismiss and spec.close and
        (not spec.can_dismiss or spec.can_dismiss()) then
      spec.close()
    end
  end
end

-- Each recognizer owns one contact; its begin can decline to a parent.
function M.pan(spec)
  if not M.continuous then return nil end
  local drawer, pager
  return function(phase, dx, dy, vx, vy)
    if phase == "begin" then
      if not phone() or blocked() then return false end
      if math.abs(dx) >= math.abs(dy) then
        pager=spec.pager
        return pager and pager.begin() or false
      end
      if not spec.dismiss or (spec.can_dismiss and not spec.can_dismiss()) then return false end
      if (spec.dismiss == "down" and dy < 0) or (spec.dismiss == "up" and dy > 0) then return false end
      drawer = require(spec.drawer).drawer
      return drawer.begin_drag()
    elseif pager then
      if phase=="update" then pager.update(dx)
      else pager.finish(vx,phase=="cancel") pager=nil end
    elseif drawer then
      if phase == "update" then drawer.drag_by(dy)
      else drawer.end_drag(vy,phase=="cancel") drawer=nil end
    end
  end
end

local edge_drawer
function M.edge_pan(edge,phase,dx,dy,vx,vy,start_x)
  if phase == "begin" then
    if not phone() or blocked() then return false end
    local inward = ({top=dy,bottom=-dy,left=dx,right=-dx})[edge]
    if not inward or inward <= 0 then return false end
    if edge == "left" or edge == "right" then return false end
    if edge == "top" then
      local sidebar=require("sidebar")
      -- Choose from where the finger landed, even if it crosses the middle
      -- during the pull. Repeated pulls from the same side keep that page.
      select_top(sidebar,start_x)
      edge_drawer=sidebar.drawer
    else edge_drawer=require("dashboard").drawer end
    close_other_panels(edge_drawer)
    return edge_drawer.begin_drag()
  elseif edge_drawer then
    if phase == "update" then edge_drawer.drag_by(dy)
    else edge_drawer.end_drag(vy,phase=="cancel") edge_drawer=nil end
  end
end

function M.attach(root)
  if attached[root] or not phone() then return end
  attached[root] = true
  if morf.env("CAELESTIA_GESTURE_DRIVER")=="lisgd" then
    require("lisgd_gestures").attach(root,{phone=phone,blocked=blocked,
      swipe=M.swipe,close_panels=close_other_panels})
    return
  end
  local preview=require("workspace_gesture").new(root)
  M.workspace_preview=preview.state
  local mode,last_y,last_time,velocity,drawer
  local function single(phase,dx,dy)
    if phase=="begin" then
      mode,drawer=nil,nil
      last_y,last_time,velocity=0,morf.time.now_ms(),0
      return
    end
    if phase=="cancel" then
      if mode=="workspace" then preview.cancel()
      elseif drawer then drawer.end_drag(0,true) end
      mode,drawer=nil,nil
      return
    end
    if phase=="update" then
      if not mode and math.max(math.abs(dx),math.abs(dy))>=8 then
        if math.abs(dx)>math.abs(dy)*1.2 then
          close_other_panels(nil)
          preview.begin() mode="workspace"
        elseif -dy>math.abs(dx)*1.2 then
          drawer=require("dashboard").drawer
          close_other_panels(drawer)
          drawer.begin_drag() mode="dashboard"
        elseif dy>math.abs(dx)*1.2 then mode="ignored" end
      end
      if mode=="workspace" then preview.update(dx)
      elseif drawer then drawer.drag_by(dy) end
      local now=morf.time.now_ms()
      if now>last_time then velocity=(dy-last_y)*1000/(now-last_time) end
      last_y,last_time=dy,now
    elseif phase=="end" then
      if mode=="workspace" then preview.update(dx) preview.finish(false)
      elseif drawer then
        if morf.time.now_ms()-last_time>100 then velocity=0 end
        drawer.drag_by(dy) drawer.end_drag(velocity,false)
      end
      mode,drawer=nil,nil
    end
  end
  local gestures=require("keyboard_gestures")
  local contacts=gestures.contacts("bottom",function() return not blocked() end,single)
  -- The bottom strip owns its raw contacts so a second finger can cancel
  -- an in-progress panel/workspace pull before choosing the keyboard.
  if M.continuous then root.on_edge_panned=function(edge,...)
    if edge=="top" then return M.edge_pan(edge,...) end
    return false
  end
  else root.on_edge_swiped=function(edge) if edge=="top" then M.swipe(edge) end end end
  -- Under the existing controls: tapping the bar/rail still reaches them.
  -- An Item, rather than a fullscreen MouseArea, leaves apps interactive.
  ui.reparent(ui.Item {
    id = "phone-gesture-edges", anchors = { fill = true }, z = -1,
    ui.MouseArea { id = "phone-gesture-top", height = EDGE,
      anchors = { top = true, left = true, right = true } },
  }, root)
  ui.reparent(gestures.area(contacts,{id="phone-gesture-bottom",height=EDGE,z=200,
    anchors={left=true,right=true},
    y=function() return ((morf.screens[1] or {}).height or morf.surface.height)
      -require("themes.keyboard").inset:get()-EDGE end}),root)
end

return M
