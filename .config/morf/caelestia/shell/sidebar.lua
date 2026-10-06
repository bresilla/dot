-- Settings/history navigation and notification coverage. Themes own the
-- drawer geometry and the timing at which a selected page is presented.
local morf = require("morf")
local ui = require("morf.ui")
local notifs = require("notifs")
local history = require("notification_history")
-- Its pages are the `panels.right` setting's (shell/pages.lua); on a phone
-- it comes down from the top, as quick settings do, with `panels.top`'s --
-- the side edges are the workspaces' there.
local PHONE = require("responsive").portrait()
local tabs, bind = require("pages").tabs(PHONE and "top" or "right")
local model = require("side_panel_model").new {
  id = "sidebar", edge = PHONE and "top" or "right", tabs = tabs,
}
bind(model)
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
-- The Lule studio works while its page is on show: the panel open, on its
-- settings, at Theme, Lule.
morf.effect("caelestia.sidebar.lule", function()
  local studio = require("lule_studio")
  local settings = require("utilities")
  if not (studio.active and settings.displayed) then return end
  studio.active:set(M.drawer.open:get() and model.showing("settings")
    and settings.displayed:get() == "theme/lule")
end)
return M
