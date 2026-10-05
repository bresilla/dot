-- OSD visibility/hold policy. Theme builders own edge geometry and motion.
local morf=require("morf")
local M={}
M.shown=morf.signal("caelestia.levels.shown","")
M.active=morf.signal("caelestia.levels.active",false)
local visual,hide,generation=nil,nil,0
local function hold()
  generation=generation+1
  local own=generation
  if hide then hide:cancel() end
  hide=morf.timer(visual.hold or 1500,function()
    hide=nil
    M.active:set(false)
    visual.hide(function() if own==generation then M.shown:set("") end end)
  end,false)
end
function M.pop(kind)
  if kind~="volume" and kind~="brightness" then return end
  local was=M.shown:get()
  M.shown:set(kind)
  M.active:set(true)
  if visual then visual.show(was) hold() end
end
function M.build()
  local osd=require("osd")
  visual=require("themes").view("levels").build {
    shown=M.shown,active=M.active,
    value={volume=function() return math.max(0,math.min(1,(osd.volume()))) end,
      brightness=function() return math.max(0,math.min(1,(osd.brightness()))) end},
    icon={volume=osd.volume_icon,brightness=osd.brightness_icon},
    muted=function() local _,muted=osd.volume() return muted end,
    rail_geometry=require("rail").geometry,desk=require("bar").desk,sidebar=require("sidebar"),
  }
  M.shape=visual.shape
  if M.shown:get()~="" then visual.show("") hold() end
  return visual.node
end
function M.geometry() return visual and visual.geometry() end
return M
