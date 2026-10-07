local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local C = theme.color
local V = {}
function V.build(model)
  local W = require("responsive").fit(require("themes.keyboard").MAX_WIDTH, 0)
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
  return require("themes.keyboard").panel {
    prefix="caelestia.osk",width=W,action=kit.action,look=look,
    send=model.send,active=model.active,touch=contacts,
    decoration=kit.decor("corners", {anchors={fill=true},length=8,inset=3,color=kit.stroke("mark")}),
  }
end
return V
