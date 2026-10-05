-- The bottom workspace: shared dimensions; the tabbed body comes from the kit.
local morf = require("morf")
local theme = require("theme")
local V = {}
function V.build(model)
  local sw, sh = model.screen_size()
  local w = math.floor(math.min(2120, sw - theme.LEFT - theme.BORDER - 20) * .8)
  local h = math.floor(math.min(1252, sh - 2 * theme.BORDER - 40) * .6)
  local tabs = {}
  for i, tab in ipairs(model.tabs) do
    tabs[i] = { key = tab.key, name = tab.name, icon = tab.icon,
      build = function(width, height) return model.page(tab.key, width, height) end }
  end
  local panel = require("kit").tabbed { id = "bottom", width = w, height = function() return h end,
    tabs = tabs, tab = model.tab, on_present = model.present }
  morf.effect("material.bottom.shown", function() panel.shown(model.opened:get()) end)
  return { width = w, height = function() return h end, content = panel.content }
end
return V
