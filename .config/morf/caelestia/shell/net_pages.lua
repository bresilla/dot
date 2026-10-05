local models=require("net_pages_model")
local view=require("themes").view("net_pages")
local M={is_mesh_link=models.is_mesh_link}
local function page(kind,w,h)
  return view.build(models.new(kind,require("presentation").active("settings."..kind)),w,h)
end
function M.wired_page(w,h) return page("wired",w,h) end
function M.vpn_page(kind,w,h) return page(kind,w,h) end
function M.tor_page(w,h) return page("tor",w,h) end
return M
