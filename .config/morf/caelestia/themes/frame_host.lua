-- Shared scene composition, with geometry and painting supplied by a theme.
-- Input policies arrive as controller-built planes; this module adds none.
local ui=require("morf.ui")
return function(model,frame,insets,decorations)
  local panels={id="opening",anchors={fill=true,left_margin=insets.left,top_margin=insets.top,
    right_margin=insets.right,bottom_margin=insets.bottom},clip=true}
  for _,node in ipairs(model.overlays) do panels[#panels+1]=node end
  local docked={id="keyboard-dock",anchors={fill=true,bottom_margin=require("theme").BORDER},clip=true}
  for _,drawer in ipairs(model.drawers) do
    local host=drawer.docked and docked or panels
    host[#host+1]=drawer.panel
  end
  local desk={id="desk",x=function() local x=model.desk() return x end,
    y=function() local _,y=model.desk() return y end,
    width=function() local _,_,w=model.desk() return w end,
    height=function() local _,_,_,h=model.desk() return h end,
    model.rail.node,model.levels.node}
  if decorations then desk[#desk+1]=decorations end
  desk[#desk+1]=ui.Item(panels)
  for _,trigger in ipairs(model.triggers) do desk[#desk+1]=trigger end
  local switcher=require("themes.switcher")
  for _,drawer in ipairs(model.drawers) do switcher.attach(drawer) end
  local transition=require("themes.session").transition
  switcher.morph(frame,"blend",require("theme").SEAM,transition and transition.seam)
  for _,node in ipairs {model.bar,model.rail.node,model.levels.node} do switcher.fade(node) end
  switcher.fade(decorations)
  return ui.Item {anchors={fill=true},frame,model.bar,ui.Item(desk),ui.Item(docked),switcher.blocker()}
end
