-- Dashboard navigation and visibility. Visual packages own layout and motion.
local morf = require("morf")
local ui = require("morf.ui")
local state = require("dashboard_state")
local model = require("dashboard_model")
local M = { LULE_TAB=6, tab=state.tab, month=model.month, month_offset=model.month_offset }
local visual = require("themes").view("dashboard").build(model)
M.size, M.bud = visual.size, visual.bud
M.drawer = require("drawer").new {
  name="dashboard",edge=visual.edge or "top",width=visual.width,height=visual.height,
  content=visual.content,props=visual.props,close_policy="escape+outside",
}
morf.effect("caelestia.dashboard.shown",function() state.opened:set(M.drawer.open:get()) end)
morf.effect("caelestia.dashboard.presentation",function()
  for index,tab in ipairs(model.tabs) do
    require("presentation").set("dashboard."..tab.key,state.opened:get() and state.displayed:get()==index)
  end
end)
morf.effect("caelestia.dashboard.lule",function()
  require("lule_studio").active:set(state.opened:get() and state.displayed:get()==M.LULE_TAB)
end)
function M.edge_trigger()
  return require("hover").edge {name="dashboard",drawer=M.drawer,edge="top",length=visual.width,
    setting="dashboard.hover",grace_ms=50}
end
return M
