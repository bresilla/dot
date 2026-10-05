-- Appearance adapter for the shared lock/greeter composition. Hooks replace
-- surfaces and motion; geometry, controls and authentication stay shared.
local ui = require("morf.ui")
local stroke = require("themes.tsugumori.strokes")
return function(context)
  local ctx = setmetatable({}, {__index=context})
  local C = ctx.C
  local feedback = require("themes.tsugumori.interaction")({color=C})
  local function straight(props)
    for _,key in ipairs {"radius","top_left_radius","top_right_radius","bottom_left_radius","bottom_right_radius"} do
      if props[key] then props[key]=0 end
    end
    return props
  end
  ctx.heading = function(props)
    props.color=props.color or function() return C.primary end
    props.reveal_delay,props.decode_lead,props.decode_stagger=300,260,45
    props.effect_scope=ctx.output_name
    return require("themes.tsugumori.heading")({color=C},{text=context.text},props)
  end
  ctx.ui = setmetatable({
    Rect = function(props)
      straight(props)
      local id=props.id or ""
      if id:find("%-field%-surface$") then
        props.color=function() return C.surfaceContainerLow end
        props.border_width=1
        props.border_color=function()
          return ctx.bad:get() and C.error or stroke(C,ctx.typed:get()>0 and "focus" or "idle")
        end
        props.behavior={color={duration=140},border_color={duration=140}}
      elseif id=="greet-session-surface" then
        props.color=function() return C.primary:alpha(.08) end
        props.border_width=1 props.border_color=function() return stroke(C,"idle") end
      elseif id:match("%-method%-surface$") or id=="greet-suspend-surface"
        or id=="greet-reboot-surface" or id=="greet-poweroff-surface" then
        props.color=function() return C.primary:alpha(.07) end
        props.border_width=1 props.border_color=function() return stroke(C,"quiet") end
      end
      -- Preserve semantic error colours on other controls.
      return ui.Rect(props)
    end,
    SdfShape = function(props) return ui.SdfShape(straight(props)) end,
    MouseArea = function(props)
      -- The shared layout's areas (lock.lua, greet.lua: their handlers are
      -- the layout's) pass through, drawn with this theme's feedback; the
      -- theme adds a look, not input of its own.
      if (props.id or ""):match("%-open$") then return ui.MouseArea(props) end
      props.scale=nil
      if props.behavior then props.behavior.scale=nil end
      return feedback(ui.MouseArea(props),props.id)
    end,
  }, {__index=ui})
  ctx.auth_skin=require("themes.tsugumori.auth_art")(ctx)
  ctx.auth_skin.action=ctx.ui.MouseArea
  return ctx
end
