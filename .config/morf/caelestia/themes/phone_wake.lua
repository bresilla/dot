-- Optional phone integration: a sleeping surface consumes all touches.
-- The same shield is used by the lockscreen and the separate greetd user.
local morf=require("morf")
local ui=require("morf.ui")
local M={}
local cfg,runtime,instance
local ok,raw=pcall(morf.fs.read,morf.env("MORF_PHONE_SCREEN_CONFIG") or "/etc/morf/phone-screen.json")
if ok and type(raw)=="string" then
  local valid,value=pcall(morf.json.decode,raw)
  if valid and type(value)=="table" and type(value.command)=="string" then cfg=value end
end
runtime,instance=morf.env("XDG_RUNTIME_DIR"),morf.env("HYPRLAND_INSTANCE_SIGNATURE")
local dry=morf.env("CAELESTIA_DRY_RUN")
if not cfg or not runtime or not instance or (dry and dry~="" and dry~="0") then
  function M.attach() end
  return M
end
local path=runtime.."/phone-screen-"..instance..".status"
local function read()
  local valid,value=pcall(morf.fs.read,path)
  return valid and type(value)=="string" and value:match("^off%s*$")~=nil
end
local sleeping=morf.signal("phone.screen.sleeping",read())
M.watch=morf.fs.watch(path,function() sleeping:set(read()) end)
function M.attach(root,spec)
  local pending=false
  local taps=require("themes.double_tap").new {
    now=morf.time.now_ms,
    movement=math.min(spec.width,spec.height)*.025,
    separation=math.min(spec.width,spec.height)*.06,
    allowed=function() return sleeping:get() and cfg.doubleTap==true and not pending end,
    wake=function()
      pending=true
      morf.log("info","phone screen: double-tap wake")
      morf.run({cfg.command,"wake"},{timeout_ms=5000,max_output=2048},function(result)
        pending=false
        if not result.ok then morf.log("warn","phone wake: "..(result.stderr or "failed")) end
      end)
    end,
  }
  local shield=ui.MouseArea {
    id=spec.prefix.."-wake-shield",anchors={fill=true},z=10000,
    visible=function() return sleeping:get() end,
    on_touch_pressed=taps.down,on_touch_moved=taps.move,
    on_touch_released=taps.up,on_touch_canceled=taps.cancel,
    -- Consume the mouse events synthesized from touches, too.
    on_clicked=function() end,on_dragged=function() end,on_key_pressed=function() end,
  }
  local was_sleeping
  morf.effect(spec.prefix..".phone-sleep."..(spec.output or ""),function()
    local value=sleeping:get()
    if value~=was_sleeping then
      was_sleeping=value taps.reset()
      if value and spec.rest then spec.rest() end
    end
  end,{owner=shield})
  ui.reparent(shield,root)
end
return M
