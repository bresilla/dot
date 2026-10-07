-- lisgd recognizes global swipes. Morf retains their edge origins and UI
-- context, so a completed command chooses the right panel and never types
-- through the keyboard or an authentication prompt.
local ui=require("morf.ui")
local M={}
local EDGE=20

function M.attach(root,policy)
  local contacts,origin,expiry={},nil,nil
  local function keyboard() return require("keyboard") end
  local function allowed() return policy.phone() and not policy.blocked() end
  local function clear()
    contacts,origin={},nil
    if expiry then expiry:cancel() expiry=nil end
  end
  local function down(edge,id,x)
    if not allowed() then clear() return end
    if next(contacts)==nil then
      clear()
      origin={edge=edge,x=x,count=0}
      expiry=morf.timer(2500,function() origin=nil expiry=nil end,false)
    end
    if origin and origin.edge~=edge then clear() return end
    if not contacts[id] then
      contacts[id]=true
      if origin then origin.count=origin.count+1 end
    end
  end
  local function up(id) contacts[id]=nil end
  local function area(edge)
    return ui.MouseArea {
      id="phone-gesture-"..edge,height=EDGE,z=200,
      anchors={left=true,right=true},
      y=function()
        if edge=="top" then return 0 end
        return ((morf.screens[1] or {}).height or morf.surface.height)-EDGE
      end,
      visible=function() return allowed() and (edge=="top" or not keyboard().active()) end,
      on_touch_pressed=function(id,x) down(edge,id,x) end,
      on_touch_released=up,on_touch_canceled=clear,
      -- Keep edge contacts here; lisgd, rather than a panel pan, owns them.
      on_dragged=function() end,
    }
  end
  morf.ipc["phone-gesture"]=function(action)
    local expected=({top={"top",1},dashboard={"bottom",1},keyboard={"bottom",2},
      ["workspace-next"]={"bottom",1},["workspace-previous"]={"bottom",1}})[action]
    if not expected then return false end
    local start=origin
    origin=nil -- A contact sequence can execute at most one command.
    if expiry then expiry:cancel() expiry=nil end
    if not start or not allowed() or start.edge~=expected[1] or start.count~=expected[2] then return false end
    if action=="top" then policy.swipe("top",start.x)
    elseif keyboard().active() then return false
    elseif action=="keyboard" then keyboard().show("full")
    elseif action=="dashboard" then policy.swipe("bottom")
    else
      policy.close_panels(nil)
      require("services").workspace.step(action=="workspace-next" and 1 or -1)
    end
    return true
  end
  -- Explicit strips preserve the starting half of the top edge; lisgd's
  -- built-in corner zones alone would only cover the very corners.
  ui.reparent(area("top"),root)
  ui.reparent(area("bottom"),root)
end

return M
