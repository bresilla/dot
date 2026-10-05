-- Workspace model and preferences. Themes own the rail's layout and motion.
local config=require("config")
local workspace=require("services").workspace
local V=require("themes").view("rail")
-- Nine workspaces per output, retaining Hyprland's decade-based IDs.
local M={COUNT=9,STRIDE=10}
local model={count=M.COUNT,active=workspace.active,occupied=workspace.occupied,
  enabled=function() return config.get("rail.enabled")~=false end,
  hold=function() return config.get("rail.hold") or 800 end,
  desk_size=function() local _,_,w,h=require("bar").desk() return w,h end,
  base=function(id) return id-((id-1)%M.STRIDE) end}
function M.geometry()
  local g=V.geometry(model)
  g.count,g.enabled=M.COUNT,model.enabled()
  return g
end
function M.build()
  model.leftbar=require("leftbar")
  local view=V.build(model)
  M.shape=view.shape
  return view.node
end
return M
