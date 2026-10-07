-- Authentication keeps its own key sink and busy state. Everything the
-- person touches is the same keyboard and gesture recognizer as the shell.
local morf=require("morf")
local ui=require("morf.ui")
local shared=require("themes.keyboard")
local M={}
function M.new(ctx)
  local W,H=ctx.width,ctx.height
  local embedded=H<480
  local enabled=H>W or not ctx.keyboard_attached()
  local shown=morf.signal(ctx.prefix..".keyboard.shown",true)
  local kb
  local function ready() return enabled and ctx.main() and not ctx.busy:get() end
  local function active() return enabled and ctx.main() and shown:get() and ctx.stage:get()=="sheet" and ctx.method:get()=="password" end
  local function show(mode)
    if not ready() then return end
    ctx.claim()
    ctx.open_sheet()
    if ctx.method:get()~="password" then ctx.clear() ctx.method:set("password") end
    if mode then kb.keys.mode:set(mode) end
    kb.keys.reset()
    shown:set(true)
  end
  local model={active=active,allowed=ready,height=function() return H end,
    show=show,hide=function() shown:set(false) kb.keys.cancel() end,
    mode=function() return kb.keys.mode:get() end,
    cancel=function() if kb then kb.keys.cancel() end end}
  local contacts=shared.contacts("keyboard",model)
  kb=shared.panel {prefix=ctx.prefix..".osk."..ctx.output,width=embedded and ctx.embedded_width or W,look=ctx.look,
    action=ctx.action,touch=contacts,active=function() return active() and not ctx.busy:get() end,send=ctx.send}
  local panel=ui.Rect {id=ctx.prefix.."-keyboard",z=10,
    width=kb.width,height=kb.height,x=embedded and 0 or math.floor((W-kb.width)/2),
    y=function() return embedded and 0 or H-ctx.border-kb.height() end,
    visible=active,color=ctx.look.panel,radius=16,kb.content}
  local start,travel
  local function single(phase,dx,dy)
    if phase=="begin" then ctx.claim() start=ctx.stage:get() travel=0
    elseif phase=="update" and start=="rest" then
      travel=math.abs(dy)>math.abs(dx)*1.2 and math.max(0,-dy) or 0
      ctx.pull:set(math.min(1,travel/360))
    elseif phase=="end" then
      if math.abs(dy)>48 and math.abs(dy)>math.abs(dx)*1.2 then
        if start=="rest" and dy<0 then ctx.open_sheet() shown:set(true)
        elseif start=="sheet" and dy>0 then ctx.clear() ctx.escape() end
      end
      ctx.pull:set(0)
    elseif phase=="cancel" then ctx.pull:set(0) end
  end
  local surface=require("themes.touch_contacts").new {
    allowed=function() return ctx.main() and not ctx.busy:get() end,single=single}
  local bottom=shared.contacts("bottom",model,single)
  local edge=shared.area(bottom,{id=ctx.prefix.."-keyboard-edge",z=200,
    x=0,y=H-20,width=W,height=20,visible=function() return H>W and ready() end})
  local was_sheet=false
  morf.effect(ctx.prefix..".keyboard.stage."..ctx.output,function()
    local is_sheet=ctx.stage:get()=="sheet"
    if is_sheet and not was_sheet then shown:set(true) end
    if not is_sheet then kb.keys.cancel() end
    was_sheet=is_sheet
  end,{owner=panel})
  local function reserved() return not embedded and active() and kb.height()+ctx.border or 0 end
  local function content_height() return math.max(1,H-reserved()) end
  return {node=panel,edge=edge,keys=kb.keys,active=active,show=show,hide=model.hide,embedded=embedded,
    height=function() return active() and kb.height()+12 or 0 end,
    reserved=reserved,content_height=content_height,
    -- The whole authentication screen shares this reduced viewport: its
    -- frame, wallpaper, clock, account controls and sheet move together.
    -- The opaque lock root and the keyboard retain the full output size.
    content=function(children)
      children.id=ctx.prefix.."-content"
      children.width,children.height,children.clip=W,content_height,true
      return ui.Item(children)
    end,
    inline_height=function() return embedded and active() and kb.height()+12 or 0 end,
    surface=function(props) return shared.area(surface,props) end}
end
return M
