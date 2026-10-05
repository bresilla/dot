-- The shared battery model stays alive independently of its selected view.
local state=require("dashboard_state")
local view=require("themes").view("dashboard_battery")
local model=require("battery_model").new(state.context(4))
local visual=view.build(model)
local M={INDEX=4,WIDTH=view.WIDTH,HEIGHT=view.HEIGHT,page=visual.page,
  width=visual.width or view.WIDTH,height=visual.height or view.HEIGHT,resize=visual.resize}
function M.show()
  state.tab:set(M.INDEX)
  require("dashboard").drawer.set(true)
end
return M
