-- Bottom workspace lifecycle and navigation; each theme owns its composition.
local morf = require("morf")
local model = require("bottom_model").new()
local view = require("themes").view("bottom").build(model)
local M = { TABS = model.tabs, panel = model }
M.width = type(view.width) == "function" and view.width or function() return view.width end
M.height = type(view.height) == "function" and view.height or function() return view.height end
M.WIDTH = M.width()
M.drawer = require("drawer").new {
  name = "bottom", edge = view.edge or "bottom", width = view.width, height = view.height,
  content = view.content, props = view.props, close_policy = "escape+outside",
}
morf.effect("caelestia.bottom.shown", function() model.opened:set(M.drawer.open:get()) end)
return M
