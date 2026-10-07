-- What a lock or greet screen does with input under its controls, shared by
-- every theme's look of it: a press or a swipe up opens the sheet, and the
-- keys go to the authentication flow. A theme draws the screen; this is
-- the one place its input is handled.
--
--     auth_input.sheet { id = "lock-open", active = main, open = open_sheet, key = key,
--       pull = function(dy) ... end, release = function() ... end }
--
-- `active()` says whether this output is the one that takes input; `pull`
-- and `release` follow a drag (a sheet drawn as it is pulled), else a
-- swipe of `swipe` px (60) up opens the sheet when it ends.
local ui = require("morf.ui")

local M = {}

function M.sheet(spec)
  local function on() return spec.active == nil or spec.active() end
  return ui.MouseArea {
    id = spec.id, anchors = { fill = true }, z = spec.z or -1,
    on_clicked = function() if spec.on_press then spec.on_press() end if on() then spec.open() end end,
    on_dragged = spec.pull and function(_, _, _, dy) if spec.on_press then spec.on_press() end spec.pull(dy) end or nil,
    on_drag_finished = function(_, _, _, dy)
      if spec.release then spec.release() return end
      if on() and dy and dy < -(spec.swipe or 60) then spec.open() end
    end,
    on_key_pressed = function(...) if on() then return spec.key(...) end return false end,
  }
end

return M
