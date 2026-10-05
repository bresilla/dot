-- The side panels: shared geometry; the tab row and pages come from the kit.
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local V = {}
function V.build(model)
  local function height()
    local _, h = model.desk_size()
    return h - 2 * theme.BORDER
  end
  local tabs = {}
  for i, tab in ipairs(model.tabs) do
    tabs[i] = { key = tab.key, name = tab.name, icon = tab.icon,
      build = function(w, h) return model.page(tab.key, w, h) end }
  end
  local panel = require("kit").tabbed {
    id = model.id, width = theme.SIDE_W, height = height, tabs = tabs,
    tab = model.tab, publish = false, on_present = model.present,
  }
  morf.effect("material." .. model.id .. ".shown", function() panel.shown(model.opened:get()) end)
  local content = panel.content
  if model.edge == "right" then
    content = ui.Item { anchors = { fill = true, left_margin = theme.STRIP }, content }
  end
  return { width = theme.SIDE_W + theme.STRIP, height = height, edge = model.edge,
    content = content, props = { anchors = { top = true, [model.edge] = true } } }
end
return V
