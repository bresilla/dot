-- Same badge/title/subtitle language as the authentication status marker.
local ui=require("morf.ui")
local theme=require("theme")
local kit=require("kit")
local C=theme.color
local V={}
function V.build(model)
  local W,H,BADGE=320,76,52
  local content=ui.Item {id="headphones",anchors={fill=true},
    ui.Row {x=14,anchors={vertical_center=true},gap=14,align="center",
      ui.Item {width=BADGE,height=BADGE,
        kit.shape {anchors={fill=true},shape="circle",color=function() return C.primaryContainer end},
        kit.icon(function() return model.device.kind=="earbuds" and "earbuds" or "headphones" end,
          30,function() return C.onPrimaryContainer end,{anchors={center_in=true},fill=true})},
      ui.Column {gap=2,
        kit.heading {id="headphones-title",scope="headphones",level="section",width=W-BADGE-50,
          reveal_delay=80,decode_lead=120,decode_stagger=18,
          elide="right",font_weight=600,
          text=function() return model.device.kind=="earbuds" and "Earbuds connected" or "Headphones connected" end},
        kit.subtitle {id="headphones-name",width=W-BADGE-50,elide="right",font_size=theme.size.small,
          text=function() return model.device.name end},
      },
    },
  }
  return {content=content,width=W,height=H,edge="center"}
end
return V
