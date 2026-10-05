-- Settings/history navigation and notification coverage. Themes own the
-- drawer geometry and the timing at which a selected page is presented.
local morf = require("morf")
local ui = require("morf.ui")
local notifs = require("notifs")
local history = require("notification_history")
local model = require("side_panel_model").new {
  id = "sidebar", edge = "right", tabs = {
    { key = "settings", name = "Settings", icon = "tune", build = require("utilities").page },
    { key = "notifications", name = "Notifications", icon = "notifications", build = history.build },
  },
}
local view = require("themes").view("side_panel").build(model)
local M = { groups = history.groups, clear = history.clear, TABS = model.tabs, panel = model,
  tab = model.tab, select = model.select, showing = model.showing, height = view.height }
M.drawer = require("drawer").new {
  name = "sidebar", edge = view.edge, width = view.width, height = view.height,
  content = view.content, props = view.props, close_policy = "escape+outside",
}
morf.effect("caelestia.sidebar.covered", function()
  notifs.covered:set(M.drawer.open:get() and model.showing("notifications"))
end)
morf.effect("caelestia.sidebar.shown", function() model.opened:set(M.drawer.open:get()) end)
return M
