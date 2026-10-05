-- Compatibility constructor for callers that supply their own tab builders.
-- Visual composition lives in the selected theme; side panels use shared
-- side_panel_model navigation with their theme's side_panel view instead.
local M = { TABS_H = 64, PAD = 11 }
function M.new(spec)
  local kit = require("kit")
  if kit.tabbed then return kit.tabbed(spec) end
  return require("themes.layouts.tabbed").new(spec)
end
return M
