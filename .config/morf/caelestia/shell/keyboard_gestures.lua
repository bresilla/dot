-- Two fingers form one action. Both must travel vertically in the same
-- direction; a pinch, short movement or cancelled sequence does nothing.
local M = {}
function M.contacts(region, allowed, single)
  return require("touch_contacts").new {
    allowed = function()
      return require("responsive").portrait() and (not allowed or allowed())
    end,
    single = single,
    cancel_keys = function()
      local keyboard=package.loaded.keyboard
      if keyboard and keyboard.keys then keyboard.keys.cancel() end
    end,
    pair = function(a,b)
      local keyboard = require("keyboard")
      local dx1,dy1,dx2,dy2=a.x-a.sx,a.y-a.sy,b.x-b.sx,b.y-b.sy
      if math.abs(dy1) < 48 or math.abs(dy2) < 48 or dy1 * dy2 <= 0
        or math.abs(dy1) < math.abs(dx1) * 1.2 or math.abs(dy2) < math.abs(dx2) * 1.2 then return end
      if allowed and not allowed() then return end
      if region == "bottom" then
        local screen=(morf.screens or {})[1]
        local height=screen and screen.height or morf.surface.height
        if a.sy < height-20 or b.sy < height-20 then return end
        if dy1 < 0 and not keyboard.active() then
          for _,drawer in ipairs(require("drawer").all) do drawer.set(false) end
          keyboard.show("full")
        end
      elseif keyboard.active() then
        if dy1 > 0 then keyboard.set(false)
        else keyboard.show(keyboard.keys.mode:get() == "dev" and "full" or "dev") end
      end
    end,
  }
end
function M.area(contacts, props)
  props=props or {}
  props.on_touch_pressed=contacts.down
  props.on_touch_moved=contacts.move
  props.on_touch_released=contacts.up
  props.on_touch_canceled=contacts.cancel
  -- Keep raw motion here; an ancestor's one-finger pan must not swallow
  -- the first contact while another finger joins it.
  props.on_dragged=function() end
  return require("morf.ui").MouseArea(props)
end
return M
