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
  elseif edge == "left" or edge == "right" then
    local launcher = require("launcher")
    close_other_panels(launcher.drawer)
    require("menus").open(edge == "left" and "apps" or "web")
    launcher.set_query("")
    launcher.drawer.set(true)
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
    elseif (pager or drawer) and blocked() then
      if pager then pager.finish(0,true) pager=nil end
      if drawer then drawer.end_drag(0,true) drawer=nil end
    elseif pager then
      if phase=="update" then pager.update(dx)
      else pager.finish(vx,phase=="cancel") pager=nil end
    elseif drawer then
      if phase == "update" then drawer.drag_by(dy)
      else drawer.end_drag(vy,phase=="cancel") drawer=nil end
    end
  end
end

local edge_drawer, side_edge
function M.edge_pan(edge,phase,dx,dy,vx,vy,start_x,start_y)
  if phase == "begin" then
    edge_drawer,side_edge=nil,nil
    if not phone() or blocked() then return false end
    local inward = ({top=dy,bottom=-dy,left=dx,right=-dx})[edge]
    if not inward or inward <= 0 then return false end
    if edge == "left" or edge == "right" then
      local height=(morf.screens[1] or {}).height or morf.surface.height
      local bottom=height-require("themes.keyboard").inset:get()-EDGE
      if math.abs(dx)<=math.abs(dy)*1.2 or not start_y or start_y<EDGE or start_y>=bottom then
        return false
      end
      side_edge=edge
      return true
    end
    if edge == "top" then
      local sidebar=require("sidebar")
      -- Choose from where the finger landed, even if it crosses the middle
      -- during the pull. Repeated pulls from the same side keep that page.
      select_top(sidebar,start_x)
      edge_drawer=sidebar.drawer
    else edge_drawer=require("dashboard").drawer end
    close_other_panels(edge_drawer)
    return edge_drawer.begin_drag()
  elseif side_edge then
    if blocked() or phase=="cancel" then side_edge=nil
    elseif phase=="end" then
      local origin=side_edge
      side_edge=nil
      local sign=origin=="left" and 1 or -1
      local distance,velocity=dx*sign,(vx or 0)*sign
      local motion=require("gesture_motion")
      -- Finish on release so a short pull, reversal or second finger can
      -- cancel before the centered launcher takes keyboard focus.
      if distance>math.abs(dy)*1.2 and velocity>-motion.FLING and
        (distance>=80 or (distance>=motion.TRAVEL and velocity>=motion.FLING)) then
        M.swipe(origin)
      end
    end
  elseif edge_drawer and blocked() then
    edge_drawer.end_drag(0,true) edge_drawer=nil
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
  local mode,drawer
  local function single(phase,dx,dy,vx,vy)
    if phase=="begin" then
      mode,drawer=nil,nil
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
    elseif phase=="end" then
      if mode=="workspace" then preview.update(dx) preview.finish(false,vx)
      elseif drawer then
        drawer.drag_by(dy) drawer.end_drag(vy or 0,false)
      end
      mode,drawer=nil,nil
    end
  end
  local gestures=require("keyboard_gestures")
  local contacts=gestures.contacts("bottom",function() return not blocked() end,
    function(phase,dx,dy) single(phase,dx,dy,0,0) end)
  -- The bottom strip owns the gesture so a second finger can cancel
  -- an in-progress panel/workspace pull before choosing the keyboard.
  if M.continuous then root.on_edge_panned=function(edge,...)
    if edge~="bottom" then return M.edge_pan(edge,...) end
    return false
  end
  else root.on_edge_swiped=function(edge) if edge~="bottom" then M.swipe(edge) end end end
  -- Under the existing controls: tapping the bar/rail still reaches them.
  -- An Item, rather than a fullscreen MouseArea, leaves apps interactive.
  ui.reparent(ui.Item {
    id = "phone-gesture-edges", anchors = { fill = true }, z = -1,
    ui.MouseArea { id = "phone-gesture-top", height = EDGE,
      anchors = { top = true, left = true, right = true } },
    ui.MouseArea { id = "phone-gesture-left", width = EDGE, y = EDGE,
      anchors = { left = true }, height = function()
        return math.max(0,((morf.screens[1] or {}).height or morf.surface.height)
          -require("themes.keyboard").inset:get()-2*EDGE)
      end },
    ui.MouseArea { id = "phone-gesture-right", width = EDGE, y = EDGE,
      anchors = { right = true }, height = function()
        return math.max(0,((morf.screens[1] or {}).height or morf.surface.height)
          -require("themes.keyboard").inset:get()-2*EDGE)
      end },
  }, root)
  local bottom={id="phone-gesture-bottom",height=EDGE,z=200,
    anchors={left=true,right=true},
    y=function() return ((morf.screens[1] or {}).height or morf.surface.height)
      -require("themes.keyboard").inset:get()-EDGE end}
  if M.continuous then
    bottom.on_panned=function(phase,dx,dy,vx,vy)
      if phase=="begin" then
        if blocked() then return false end
        single("begin") single("update",dx,dy,vx,vy)
        return mode=="workspace" or mode=="dashboard"
      end
      if blocked() then single("cancel") return end
      single(phase,dx,dy,vx,vy)
    end
    bottom.on_two_finger_panned=function(phase,dx1,dy1,dx2,dy2,x1,y1,x2,y2)
      if phase=="begin" then
        if blocked() or require("keyboard").active() then return false end
        local height=((morf.screens[1] or {}).height or morf.surface.height)
        return y1>=height-EDGE and y2>=height-EDGE
      elseif phase=="end" and not blocked() and dy1<=-48 and dy2<=-48
        and -dy1>math.abs(dx1)*1.2 and -dy2>math.abs(dx2)*1.2 then
        require("keyboard").show("full")
      end
    end
    ui.reparent(ui.MouseArea(bottom),root)
  else ui.reparent(gestures.area(contacts,bottom),root) end
end

return M
