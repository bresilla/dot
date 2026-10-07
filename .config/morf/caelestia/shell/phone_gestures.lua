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
    if drawer ~= keep then drawer.set(false) end
  end
end

function M.swipe(edge)
  if not phone() or blocked() then return end
  if edge == "top" then
    local sidebar = require("sidebar")
    -- The first pull shows notifications; another pull opens quick settings.
    local settings = sidebar.drawer.open:get() and sidebar.showing("notifications")
    close_other_panels(sidebar.drawer)
    sidebar.select(settings and "settings" or "notifications")
    sidebar.drawer.set(true)
  elseif edge == "bottom" then
    local dashboard = require("dashboard").drawer
    close_other_panels(dashboard)
    dashboard.set(true)
  elseif edge == "left" or edge == "right" then
    close_other_panels()
    require("services").workspace.step(edge == "left" and -1 or 1)
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
function M.edge_pan(edge,phase,dx,dy,vx,vy)
  if phase == "begin" then
    if not phone() or blocked() then return false end
    local inward = ({top=dy,bottom=-dy,left=dx,right=-dx})[edge]
    if not inward or inward <= 0 then return false end
    if edge == "left" or edge == "right" then return true end
    if edge == "top" then
      local sidebar=require("sidebar")
      local settings=sidebar.drawer.open:get() and sidebar.showing("notifications")
      sidebar.select(settings and "settings" or "notifications")
      edge_drawer=sidebar.drawer
    else edge_drawer=require("dashboard").drawer end
    close_other_panels(edge_drawer)
    return edge_drawer.begin_drag()
  elseif edge == "left" or edge == "right" then
    if phase == "end" and (edge=="left" and dx or -dx) >= 80 then M.swipe(edge) end
  elseif edge_drawer then
    if phase == "update" then edge_drawer.drag_by(dy)
    else edge_drawer.end_drag(vy,phase=="cancel") edge_drawer=nil end
  end
end

function M.attach(root)
  if attached[root] or not phone() then return end
  attached[root] = true
  if M.continuous then root.on_edge_panned = M.edge_pan
  else root.on_edge_swiped = M.swipe end
  -- Under the existing controls: tapping the bar/rail still reaches them.
  -- An Item, rather than a fullscreen MouseArea, leaves apps interactive.
  ui.reparent(ui.Item {
    id = "phone-gesture-edges", anchors = { fill = true }, z = -1,
    ui.MouseArea { id = "phone-gesture-top", height = EDGE,
      anchors = { top = true, left = true, right = true } },
    ui.MouseArea { id = "phone-gesture-bottom", height = EDGE,
      anchors = { bottom = true, left = true, right = true } },
    ui.MouseArea { id = "phone-gesture-left", width = EDGE,
      anchors = { left = true, top = true, bottom = true, top_margin = EDGE, bottom_margin = EDGE } },
    ui.MouseArea { id = "phone-gesture-right", width = EDGE,
      anchors = { right = true, top = true, bottom = true, top_margin = EDGE, bottom_margin = EDGE } },
  }, root)
end

return M
