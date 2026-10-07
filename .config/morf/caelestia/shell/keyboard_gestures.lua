-- Two fingers form one action. Both must travel vertically in the same
-- direction; a pinch, short movement or cancelled sequence does nothing.
local M = {}
function M.attach(node, region, allowed)
  local accepted = false
  local function pan(phase, dx1, dy1, dx2, dy2, x1, y1, x2, y2)
    local keyboard = require("keyboard")
    if phase == "begin" then
      accepted = false
      if not require("responsive").portrait() or (allowed and not allowed()) then return false end
      if region == "bottom" then
        local h = morf.surface.height
        if keyboard.active() or y1 < h - 20 or y2 < h - 20 then return false end
      elseif not keyboard.active() then return false end
      accepted = true
      keyboard.keys.cancel()
      return true
    end
    if phase == "cancel" then accepted = false return end
    if phase ~= "end" or not accepted then return end
    accepted = false
    if math.abs(dy1) < 48 or math.abs(dy2) < 48 or dy1 * dy2 <= 0
      or math.abs(dy1) < math.abs(dx1) * 1.2 or math.abs(dy2) < math.abs(dx2) * 1.2 then return end
    if allowed and not allowed() then return end
    if region == "bottom" then
      if dy1 < 0 and not keyboard.active() then keyboard.show("full") end
    elseif keyboard.active() then
      if dy1 > 0 then keyboard.set(false)
      else keyboard.show(keyboard.keys.mode:get() == "dev" and "full" or "dev") end
    end
  end
  -- A dotfiles checkout may precede the engine update.
  return pcall(function() node.on_two_finger_panned = pan end)
end
return M
