-- Shared keyring layout. Theme components supply geometry, color and motion.
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local C = theme.color
local M = {}
function M.build(model)
  local W, PAD = 480, 24
  local inner = W - PAD * 2
  local surface = kit.surface or ui.Rect
  local function heading(props)
    if kit.heading then return kit.heading(props) end
    props.active=nil
    return kit.text(props)
  end
  local action = kit.action or ui.MouseArea
  local function text(value, props)
    props = props or {} props.text = value
    props.font_size = props.font_size or 14
    props.color = props.color or function() return C.onSurface end
    return kit.text(props)
  end
  local function prop(key, fallback)
    local value = model.request:get()
    value = value and value.properties[key] or nil
    return value ~= nil and value ~= "" and value or fallback
  end
  local function password() local r=model.request:get() return r and r.kind=="password" end
  local function field(index, label)
    local dots = {}
    for i=1,24 do
      dots[i] = surface { width=8,height=8,radius=4,color=function() return C.primary end,
        visible=function() return model.lengths[index]:get()>=i end }
    end
    return action { id="keyring-field-"..index,width=inner,height=50,
      visible=function() return password() and (index==1 or prop("password-new",false)) end,
      on_clicked=function() model.focus(index) end,
      surface { anchors={fill=true},radius=18,color=function() return C.surfaceContainerHighest end,
        border_width=1,border_color=function() return model.focused:get()==index and C.primary:alpha(.5) or C.outlineVariant:alpha(.2) end },
      kit.icon(index==1 and "key" or "lock",20,function() return C.primary end,{x=16,y=15}),
      text(label,{x=48,y=16,font_size=13,visible=function() return model.lengths[index]:get()==0 end,
        color=function() return C.onSurfaceVariant end}),
      ui.Row {x=48,y=21,gap=5,table.unpack(dots)},
    }
  end
  local column = ui.Column {x=PAD,y=PAD,width=inner,gap=12,
    ui.Item {width=inner,height=40,
      surface {width=40,height=40,radius=14,color=function() return C.primaryContainer end,
        kit.icon("lock",22,function() return C.onPrimaryContainer end,{anchors={center_in=true}})},
      heading {id="keyring-title",x=54,y=8,width=inner-54,height=26,elide="right",
        text=function() return prop("title","Keyring") end,font_size=21,font_weight=600,
        active=function() return model.opened:get() end},
    },
    text(function() return prop("message","Unlock your keyring") end,{id="keyring-message",width=inner,wrap=true,max_lines=3,font_size=16}),
    text(function() return prop("description","") end,{id="keyring-description",width=inner,wrap=true,max_lines=4,font_size=13,
      visible=function() return prop("description","")~="" end,color=function() return C.onSurfaceVariant end}),
    field(1,"Password"),field(2,"Confirm password"),
    text(function() return model.error:get()~="" and model.error:get() or prop("warning","") end,
      {id="keyring-warning",width=inner,wrap=true,max_lines=3,font_size=13,color=function() return C.error end,
       visible=function() return model.error:get()~="" or prop("warning","")~="" end}),
    action {id="keyring-choice",width=inner,height=36,cursor="pointer",
      visible=function() return prop("choice-label","")~="" end,
      on_clicked=function() model.choice:set(not model.choice:get()) end,
      kit.icon(function() return model.choice:get() and "check_box" or "check_box_outline_blank" end,22,function() return C.primary end,{y=7}),
      text(function() return prop("choice-label","") end,{x=32,y=7,width=inner-32,height=22,elide="right",font_size=13}),
    },
    ui.Item {width=inner,height=40,
      kit.pill {id="keyring-cancel",width=128,height=40,label=function() return prop("cancel-label","Cancel"):gsub("_","") end,
        color=function() return C.surfaceContainerHigh end,ink=function() return C.onSurface end,on_clicked=model.cancel},
      kit.pill {id="keyring-continue",x=inner-180,width=180,height=40,
        label=function() return prop("continue-label",password() and "Unlock" or "Continue"):gsub("_","") end,
        color=function() return C.primary end,ink=function() return C.onPrimary end,on_clicked=model.submit},
    },
  }
  local content=ui.Item {anchors={fill=true},ui.MouseArea {anchors={fill=true}},column}
  if theme.motion and theme.motion.auth_result then
    -- Closing a GCR prompt confirms a reply, not successful authentication.
    -- Only actual validation errors and server warnings produce a result cue.
    theme.motion.auth_result(content,"keyring",{active=function() return model.opened:get() end,
      read=function()
        local warning=model.error:get()~="" and model.error:get() or prop("warning","")
        return warning~="" and "failed" or "waiting",warning
      end})
  end
  return {width=W,height=function() return (column.layout_height or 280)+2*PAD end,content=content}
end
return M
