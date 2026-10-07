local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local osk = require("lib.util.osk")
local C = theme.color
local V = {}
function V.build(model)
  local W, PAD = require("responsive").fit(1060, 0), 12
  -- The theme styles the keys: its colours, and its own key face where it
  -- has one (lib.osk's default face otherwise).
  local look = kit.keyboard_look {
    panel = function() return C.surfaceContainer:alpha(0) end,
    key = function() return C.surfaceContainerHighest end,
    key_dim = function() return C.surfaceContainerHigh end,
    accent = kit.signal("accent"), on_accent = function() return C.onPrimary end,
    text = kit.ink("hi"), dim = kit.ink("lo"),
    press = function() return C.secondaryContainer end,
    font = theme.font, radius = theme.key_radius, icons = theme.icon_font,
  }
  local gestures=require("keyboard_gestures")
  local contacts=gestures.contacts("keyboard")
  local kb = osk.new {
    prefix = "caelestia.osk", action = kit.action, width = W - 2 * PAD,
    mode = "full", numbers = false, send = model.send, active = model.active,
    look = look, key_face = look.key_face, touch = contacts,
  }
  -- The theme's own marks round the keys (none in a theme without them).
  local marks = kit.decor("corners", { anchors = { fill = true }, length = 8, inset = 3, color = kit.stroke("mark") })
  local function height() return kb.height() + 2 * PAD end
  local content = ui.Item {width = W, height = height,
    gestures.area(contacts,{anchors={fill=true},z=-1}),
    ui.Item {x = PAD, y = PAD, width = W - 2 * PAD, height = kb.height, kb.node}, marks}
  return {width = W, height = height, keys = kb, content = content}
end
return V
