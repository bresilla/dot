-- Settings lifecycle and detail builders; the selected theme owns all layout.
local morf=require("morf")
local M=require("settings_model")
local view=require("themes").view("utilities")
M.WIDTH,M.RADIUS=view.WIDTH,view.RADIUS
local builders={
  network=function(w,h) return require("connectivity").network_page(w,h) end,
  mobile=function(w,h) return require("connectivity").mobile_page(w,h) end,
  bluetooth=function(w,h) return require("connectivity").bluetooth_page(w,h) end,
  sound=function(w,h) return require("sound_page").output_page(w,h) end,
  ["sound/equalizer"]=function(w,h) return require("equalizer_page").page(w,h) end,
  ["sound/equalizer/audiogram"]=function(w,h) return require("equalizer_page").audiogram(w,h) end,
  microphone=function(w,h) return require("sound_page").input_page(w,h) end,
  power=function(w,h) return require("power_page").page(w,h) end,
  bar=function(w,h) return require("bar_page").page(w,h) end,
  wired=function(w,h) return require("net_pages").wired_page(w,h) end,
  mesh=function(w,h) return require("net_pages").vpn_page("mesh",w,h,M.displayed) end,
  tunnel=function(w,h) return require("net_pages").vpn_page("tunnel",w,h,M.displayed) end,
  focus=function(w,h) return view.focus_page(M,w,h) end,
  theme=function(w,h) return view.theme_page(M,w,h) end,
  ["theme/lule"]=function(w,h) return require("lule_page").build(w,h) end,
}
function M.page_content(key,w,h) return assert(builders[key],"Unknown Settings page: "..key)(w,h) end
local visual
function M.page(w,h)
  visual=view.build(M,w,h)
  return visual.node,visual.head
end
function M.height() return visual and visual.height and visual.height() or 0 end
function M.shown(open)
  M.opened:set(open)
  if not open then M.detail:set("") end
end
morf.effect("caelestia.settings.lifecycle",function()
  M.shown(require("presentation").active("sidebar.settings")())
end)
return M
