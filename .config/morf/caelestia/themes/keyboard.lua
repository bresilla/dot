-- One keyboard for desktop, lock and greet. Hosts supply colours and a
-- private key sink; sizing, layouts and touch ownership are shared here.
local morf=require("morf")
local ui=require("morf.ui")
local M={PAD=12,MAX_WIDTH=1060}

function M.contacts(region,model,single)
  return require("themes.touch_contacts").new {
    allowed=model.allowed,single=single,cancel_keys=model.cancel,
    pair=function(a,b)
      local dx1,dy1,dx2,dy2=a.x-a.sx,a.y-a.sy,b.x-b.sx,b.y-b.sy
      if math.abs(dy1)<48 or math.abs(dy2)<48 or dy1*dy2<=0
        or math.abs(dy1)<math.abs(dx1)*1.2 or math.abs(dy2)<math.abs(dx2)*1.2 then return end
      if model.allowed and not model.allowed() then return end
      if region=="bottom" then
        if a.sy<model.height()-20 or b.sy<model.height()-20 then return end
        if dy1<0 and not model.active() then
          if model.before_show then model.before_show() end
          model.show("full")
        end
      elseif model.active() then
        if dy1>0 then model.hide()
        else model.show(model.mode()=="dev" and "full" or "dev") end
      end
    end,
  }
end

function M.area(contacts,props)
  props=props or {}
  props.on_touch_pressed=contacts.down
  props.on_touch_moved=contacts.move
  props.on_touch_released=contacts.up
  props.on_touch_canceled=contacts.cancel
  props.on_dragged=function() end
  return ui.MouseArea(props)
end

function M.panel(options)
  local width=math.min(M.MAX_WIDTH,options.width)
  local keys=require("lib.util.osk").new {
    prefix=options.prefix,width=width-2*M.PAD,mode="full",numbers=false,
    look=options.look,key_face=options.look.key_face,action=options.action,
    send=options.send,active=options.active,touch=options.touch,
  }
  local function height() return keys.height()+2*M.PAD end
  local content=ui.Item {width=width,height=height,
    M.area(options.touch,{anchors={fill=true},z=-1}),
    ui.Item {x=M.PAD,y=M.PAD,width=width-2*M.PAD,height=keys.height,keys.node},
  }
  if options.decoration then ui.reparent(options.decoration,content) end
  return {width=width,height=height,keys=keys,content=content}
end
return M
