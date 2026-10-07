-- Direct manipulation uses surface displacement, never coordinates relative
-- to the moving drawer. Animation runs only after the finger lets go.
local morf = require("morf")
local M = {}

function M.attach(d, ctx, stop_theme)
  local panel, content, axis = d.panel, ctx.content, ctx.axis
  local drag, settling
  local function stop()
    if settling then settling:stop() settling = nil end
    if stop_theme then stop_theme() end
  end
  function d.interrupt_drag()
    stop()
    drag = nil
    d.manual = false
  end
  function d.begin_drag()
    if ctx.floating then return false end
    local was_open = d.open:get()
    stop()
    local origin = panel.visible and panel[axis] or ctx.tucked()
    d.manual = true
    drag = { origin = origin, was_open = was_open, delta = 0 }
    panel.visible, panel.opacity, content.opacity, d.shape.opacity = true, 1, 1, 1
    panel[axis] = origin
    d.open:set(true)
    return true
  end
  function d.drag_by(delta)
    if not drag then return end
    drag.delta = delta
    local tucked = ctx.tucked()
    panel[axis] = math.max(math.min(0,tucked), math.min(math.max(0,tucked), drag.origin + delta))
  end
  function d.end_drag(velocity, canceled)
    if not drag then return end
    local tucked = ctx.tucked()
    local size = math.max(1, math.abs(tucked))
    local progress = 1 - math.abs(panel[axis]) / size
    local opening_velocity = velocity * (tucked > 0 and -1 or 1)
    local opening = progress >= 0.5
    if canceled then opening = drag.was_open
    elseif math.abs(drag.delta) >= 24 and math.abs(opening_velocity) >= 650 then
      opening = opening_velocity > 0
    end
    drag = nil
    d.open:set(opening)
    local target = opening and 0 or tucked
    local distance = math.abs(target-panel[axis])
    local duration = math.max(100,math.min(320,320*distance/size))
    settling = morf.animation.play {
      { node=panel, property=axis, to=target, duration=duration, easing="out_cubic" },
      on_finished=function(reason)
        if reason ~= "completed" then return end
        settling = nil
        panel.visible = d.open:get()
        d.manual = false
      end,
    }
  end
end
return M
