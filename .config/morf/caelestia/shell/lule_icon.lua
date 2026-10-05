-- Original Lule SVG geometry, painted like the shell's other tab symbols.
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local svg = assert(morf.fs.read(morf.config_path("assets/lule.svg")))
local paths = {}
for attributes in svg:gmatch("<path%s+(.-)/>") do
  local d = attributes:match('%sd="([^"]+)"')
  if d then paths[#paths + 1] = d end
end
local M = {}
function M.build(selected, id, selected_ink)
  local nodes = { id = id, width = 22, height = 22 }
  for _, d in ipairs(paths) do
    nodes[#nodes + 1] = ui.Path {
      anchors = { fill = true }, view_box = { -5, -5, 210, 210 }, d = d,
      fill_color = function() return (selected_ink and selected_ink() or theme.color.primary):alpha(selected() and 1 or 0) end,
      stroke_color = function() return theme.color.onSurface:alpha(selected() and 0 or 1) end,
      stroke_width = 9, stroke_join = "round", stroke_cap = "round",
      behavior = { fill_color = { duration = theme.duration.small }, stroke_color = { duration = theme.duration.small } },
    }
  end
  return ui.Item(nodes)
end
return M
