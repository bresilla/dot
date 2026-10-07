-- Shared feedback for every actionable target. Decoration moves; the input
-- rectangle stays fixed so pressing never makes a target slide away.
--
-- The decoration (a wash, one glint and the two registration marks on the
-- top-left / bottom-right diagonal) is built the first time the pointer
-- reaches the target, not up front: a shell holds hundreds of hidden
-- controls, and each would otherwise carry its own nodes and colour
-- bindings through every layout pass and palette change.
local ui = require("morf.ui")
local morf = require("morf")
return function(theme)
  local C = theme.color
  local attached = setmetatable({}, {__mode="k"})
  local serial=0
  local MARK="M0 0 H7 V1.5 H1.5 V7 H0 Z"
  return function(area, name)
    if attached[area] then return area end
    attached[area]=true
    serial=serial+1
    local id=name or "tsugumori-action-"..serial
    local wash, glint, marks, running
    local function build()
      wash=ui.Rect { id=id.."-wash",anchors={fill=true},z=40,
        color=function() return C.primary end,opacity=0,
        behavior={opacity={duration=140,easing="out_cubic"}} }
      ui.reparent(wash,area)
      -- A single clipped glint crosses the control on entry or press. It has
      -- no idle animation and never changes the target's input geometry.
      glint = ui.Path { id=id.."-glint",x=-36,width=28,
        height=function() return math.max(1,area.height) end,
        view_box={0,0,28,100},d="M20 0 H28 L8 100 H0 Z",
        fill_color=function() return C.primary end,opacity=0 }
      ui.reparent(ui.Item { id=id.."-glint-clip",anchors={fill=true},clip=true,z=41,glint },area)
      -- Registration marks on the chamfer diagonal only (never four
      -- brackets): they part outward along it while hovered.
      marks={}
      for i,corner in ipairs {{left=true,top=true},{right=true,bottom=true}} do
        marks[i]=ui.Path {id=id.."-mark-"..i,anchors=corner,width=7,height=7,z=42,
          view_box={0,0,7,7},d=MARK,rotation=i==1 and 0 or 180,
          fill_color=function() return C.primary end,opacity=0,
          behavior={translate_x={duration=340,easing="out_cubic"},translate_y={duration=340,easing="out_cubic"},
            opacity={duration=180}}}
        ui.reparent(marks[i],area)
      end
    end
    local hovered,pressed=false,false
    morf.effect(id..".feedback",function()
      local over,down=area.hovered,area.pressed
      if not wash then
        if not over and not down then return end
        build()
      end
      local fire=(over and not hovered) or (down and not pressed)
      hovered,pressed=over,down
      wash.opacity=down and 0.18 or over and 0.055 or 0
      for i,mark in ipairs(marks) do
        local s=(over and not down) and (i==1 and -3 or 3) or 0
        mark.translate_x,mark.translate_y=s,s
        mark.opacity=over and 1 or 0
      end
      if not over and not down then
        if running then running:stop() running=nil end
        glint.opacity=0
      elseif fire then
        if running then running:stop() end
        running=morf.animation.play {{parallel={
          {node=glint,property="x",from=-36,to=area.width+36,duration=330,easing="out_cubic"},
          {node=glint,property="opacity",duration=330,keyframes={
            {at=0,value=0},{at=.13,value=.33},{at=.65,value=.27},{at=1,value=0},
          }},
        }},on_finished=function() running=nil end}
      end
    end,{owner=area})
    return area
  end
end
