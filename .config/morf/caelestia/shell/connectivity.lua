-- Settings page controllers. Themes receive cached radio models and actions.
local models=require("connectivity_model")
local presentation=require("presentation")
local view=require("themes").view("connectivity")
local M,instances={},{}
local function page(kind,w,h)
  local model=models.new(kind,presentation.active("settings."..kind))
  instances[kind]=model
  return view.build(model,w,h)
end
function M.network_page(w,h) return page("network",w,h) end
function M.bluetooth_page(w,h) return page("bluetooth",w,h) end
function M.mobile_page(w,h)
  return view.build(require("mobile_model").new(presentation.active("settings.mobile")),w,h)
end
function M.networks() return instances.network and instances.network.list() or {} end
function M.devices() return instances.bluetooth and instances.bluetooth.list() or {} end
return M
