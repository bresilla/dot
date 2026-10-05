-- View selected by the visual theme; services and models stay shared.
local M={}
function M.page(w,h)
  local model=require("power_model").new(require("presentation").active("settings.power"),
    function() require("dashboard_battery").show() end)
  return require("themes").view("power_page").build(model,w,h)
end
return M
