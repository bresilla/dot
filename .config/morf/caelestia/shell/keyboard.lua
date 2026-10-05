-- The on-screen keyboard: a drawer of its own along the bottom edge --
-- beside the capture drawer, not in it -- carrying lib.board's keys, which
-- type into whatever has the focus through a virtual keyboard. The drawer
-- never takes the focus itself, so the text goes where it was going.
--
-- It comes up by itself when a program asks for text (a text field is
-- focused: the input-method protocol says so) and no real keyboard is
-- attached (lib.keyboards), and goes when the field does -- unless it was
-- opened by hand. By hand: `keyboard [toggle|open|close]` over IPC, which a
-- key can be bound to. `keyboard.auto = false` in the settings stops the
-- coming up by itself.

local morf = require("morf")
local config = require("config")
local osk = require("lib.util.osk")
local keyboards = require("lib.services.keyboards")
local M = { opened = morf.signal("caelestia.keyboard.shown", false) }

local field = false
local send = osk.sender { ime = function() return field end }
function M.active() return M.opened:get() end
function M.send(event)
  if not M.active() then return end
  local dry = morf.env("CAELESTIA_DRY_RUN")
  if dry and dry ~= "" and dry ~= "0" then return end
  send(event)
end
function M.close() M.drawer.set(false) end
function M.desk_size()
  local _, _, w, h = require("bar").desk()
  return w, h
end

local view = require("themes").view("keyboard").build(M)
M.keys, M.WIDTH = view.keys, view.width
M.drawer = require("drawer").new {
  name = "keyboard", edge = view.edge or "bottom", width = view.width,
  height = view.height, content = view.content, props = view.props,
}

local asked = false
function M.set(on)
  asked = false
  M.drawer.set(on)
end
function M.toggle() M.set(not M.drawer.open:get()) end
function M.show(mode)
  local valid = mode == nil
  for _, name in ipairs(osk.MODES) do if mode == name then valid = true end end
  if not valid then return false end
  asked = false
  if mode then M.keys.mode:set(mode) end
  M.keys.reset()
  M.set(true)
  return true
end

if morf.input_method and morf.input_method.subscribe then
  pcall(morf.input_method.subscribe, function(active)
    field = active == true
    if config.get("keyboard.auto") == false then return end
    if active then
      if not M.drawer.open:get() and not keyboards.attached() then
        asked = true
        M.keys.reset()
        M.drawer.set(true)
      end
    elseif asked then
      asked = false
      M.drawer.set(false)
    end
  end)
end
morf.effect("caelestia.keyboard.hand", function()
  local on = M.drawer.open:get()
  M.opened:set(on)
  if not on then asked = false end
  if view.shown then view.shown(on) end
end)
return M
