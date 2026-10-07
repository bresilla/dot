-- Bar preference policy and desktop reservation. The theme supplies its
-- dimensions and layout; bar_model owns shared service readings and actions.
local morf = require("morf")
local config = require("config")
local keyboard_space = require("themes.keyboard").inset

local view = require("themes").view("bar")
local M = {}

M.THICK = view.horizontal
M.WIDE = view.vertical
M.SIDES = { "top", "bottom", "left", "right" }

local function screen()
  morf.screens_revision()
  local s = morf.screens[1]
  return (s and s.width) or 1920, (s and s.height) or 1080
end

--- Whether the bar is up.
function M.on()
  local wanted = config.get("edgebar.enabled")
  if wanted == "on" or wanted == true then return true end
  if wanted == "off" or wanted == false then return false end
  local w, h = screen()
  return w < 1000 or h > w
end

--- Which edge it is on.
function M.side()
  local side = config.get("edgebar.side")
  for _, s in ipairs(M.SIDES) do if s == side then return side end end
  return "top"
end

function M.vertical() return M.side() == "left" or M.side() == "right" end

--- What the bar takes from each side of the screen: `{ left, top, right,
--- bottom }`, all zero while it is down.
local function bar_insets()
  local out = { left = 0, top = 0, right = 0, bottom = 0 }
  if M.on() then out[M.side()] = M.vertical() and M.WIDE or M.THICK end
  return out
end

function M.insets()
  -- One work area for application windows, drawers and workspace markers.
  local out=bar_insets()
  out.bottom=out.bottom+keyboard_space:get()
  return out
end

--- The desk: the screen less the bar and keyboard. `x, y, width, height`.
function M.desk()
  local w, h = screen()
  local i = M.insets()
  return i.left, i.top, w - i.left - i.right, h - i.top - i.bottom
end

--- Sets it up or down.
function M.set_on(on) config.set("edgebar.enabled", on and "on" or "off") end
function M.set_side(side) config.set("edgebar.side", side) end

function M.build()
  local model = require("bar_model").new {
    on=M.on, side=M.side, vertical=M.vertical,
    screen=function() local w,h=screen() return w,h-keyboard_space:get() end,
    insets=bar_insets,
  }
  return view.build(model)
end
return M
