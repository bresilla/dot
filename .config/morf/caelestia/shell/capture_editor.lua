-- Shell lifecycle and preferences around the shared capture/document library.
local morf=require("morf")
local annotation=require("lib.util.annotation")
local backend=require("lib.util.capture")
local config=require("config")
local M={phase=morf.signal("caelestia.capture.stage","selecting"),
  tools_open=morf.signal("caelestia.capture.tools.open",false),more_open=morf.signal("caelestia.capture.more.open",false),
  hovered=morf.signal("caelestia.capture.hovered",false),pending=morf.signal("caelestia.capture.pending",false),active=morf.signal("caelestia.capture.editor",false),revision=morf.signal("caelestia.capture.revision",0),
  preview=morf.signal("caelestia.capture.preview",""),busy=morf.signal("caelestia.capture.export",false),
  settings=morf.signal("caelestia.capture.settings",false),status=morf.signal("caelestia.capture.editor.status",""),
  hint=morf.signal("caelestia.capture.editor.hint",""),
  toolbar=morf.signal("caelestia.capture.toolbar",{x=0,y=0}),upload_confirm=morf.signal("caelestia.capture.upload.confirm",false),
  picker=morf.signal("caelestia.capture.picker",false),
  text_value=morf.signal("caelestia.capture.text",""),
  rebinding=morf.signal("caelestia.capture.rebinding",false)}
local session,source,preview_source,output,finished,watchdog,render_timer,viewport
local last_hover_window,selection_confirmed,render_dirty,resize_base,render_waiter,draft_cache,mark_cache
local generation,rendering=0,false
local picker_done
function M.running() return M.active:get() or M.pending:get() end
M.tools=annotation.tools
-- The marker inks a mark may take: document content, not theme chrome, so
-- they are the same in every theme (the first is the configured default).
M.COLOURS={"#ef5350","#ff9800","#ffeb3b","#66bb6a","#26c6da","#5c6bc0","#ffffff","#202020"}
function M.doc() M.revision:get() return M.document end
function M.tool_info()
  local d=M.doc() local id=d and d.tool or "select"
  if d and id=="select" and d.selected and d.items[d.selected] then id=d.items[d.selected].type end
  for _,tool in ipairs(M.tools) do if tool[1]==id then return tool end end
  return M.tools[1]
end
function M.current_style()
  local d=M.doc() if not d then return {width=4,color=M.COLOURS[1],filled=false} end
  return d.tool=="select" and d.items[d.selected] or d.styles[d.tool]
end
function M.dismiss_tools()
  local open=M.tools_open:get() or M.more_open:get()
  M.tools_open:set(false) M.more_open:set(false) M.hint:set("")
  return open
end
function M.toolbar_size(w)
  return {width=math.min(392,w-24),height=88}
end
function M.geometry()
  local screen=(morf.screens or {})[1] or {width=1920,height=1080,x=0,y=0}
  local d=M.doc() local s=output or screen
  local scale=d and (s.width or screen.width)/d.width or 1
  return {w=screen.width,h=screen.height,scale=scale,
    x=((s.x or 0)-(screen.x or 0)),y=((s.y or 0)-(screen.y or 0)),
    iw=d and d.width*scale or 0,ih=d and d.height*scale or 0}
end
-- Display only this output's pixels. The document keeps desktop coordinates
-- so window selection and export remain accurate on monitors with offsets.
local function viewport_for(width,height,desktop)
  local screen=(morf.screens or {})[1] or desktop
  local factor=width/(desktop.width or width)
  local x=math.max(0,math.floor(((screen.x or 0)-(desktop.x or 0))*factor))
  local y=math.max(0,math.floor(((screen.y or 0)-(desktop.y or 0))*factor))
  return {x=x,y=y,w=math.min(width-x,math.ceil(screen.width*factor)),
    h=math.min(height-y,math.ceil(screen.height*factor))}
end
function M.preview_geometry()
  local g=M.geometry() local v=viewport or {x=0,y=0,w=0,h=0}
  return {x=v.x*g.scale,y=v.y*g.scale,w=v.w*g.scale,h=v.h*g.scale}
end
function M.menu_geometry()
  local g=M.geometry() local b=M.crop() local size=M.toolbar_size(g.w) local pos=M.toolbar:get()
  local left,top=g.x+b.x*g.scale,g.y+b.y*g.scale
  local bottom=top+b.h*g.scale
  local y=bottom+12
  if y+size.height>g.h-44 then y=top-size.height-12 end
  if y<12 then y=g.h-size.height-44 end
  return {w=size.width,h=size.height,
    x=math.max(12,math.min(g.w-size.width-12,left+b.w*g.scale/2-size.width/2+pos.x)),
    y=math.max(12,math.min(g.h-size.height-44,y+pos.y))}
end
local function changed() M.revision:set(M.revision:get()+1) end
function M.cancel()
  generation=generation+1
  M.phase:set("selecting") M.tools_open:set(false) M.more_open:set(false) M.hovered:set(false)
  M.pending:set(false) M.active:set(false) M.busy:set(false) M.settings:set(false) M.upload_confirm:set(false)
  M.rebinding:set(false) M.picker:set(false) picker_done=nil
  M.hint:set("")
  M.preview:set("") M.document=nil source=nil preview_source=nil viewport=nil rendering=false
  last_hover_window=nil selection_confirmed=false render_dirty=false resize_base=nil render_waiter=nil draft_cache=nil mark_cache=nil
  if watchdog then watchdog:cancel() watchdog=nil end
  if render_timer then render_timer:cancel() render_timer=nil end
  if session then session.close() session=nil end
  if finished then local cb=finished finished=nil cb(true) end
end
local function failure(message)
  M.status:set(tostring(message))
  if not M.active:get() then
    local cb=finished finished=nil M.cancel()
    if cb then cb(false,tostring(message)) end
  end
end
function M.redraw(immediate)
  if not M.active:get() or M.busy:get() or not M.document or not session then return end
  -- Throttle motion; restarting a debounce timer on every move starves
  -- continuous drags. Never queue more than one preview worker at a time.
  if rendering then render_dirty=true return end
  if render_timer then
    if not immediate then return end
    render_timer:cancel() render_timer=nil
  end
  local current=generation
  render_timer=morf.timer(immediate and 1 or 80,function()
    render_timer=nil
    if current~=generation or M.busy:get() or not M.document then return end
    rendering=true render_dirty=false local owned=session local rev=M.document.revision
    local draft=M.document.draft
    local effect=draft and (draft.type=="blur" or draft.type=="pixelate" or draft.type=="zoom")
    local base,ops=preview_source
    if annotation.viewport_ops then ops=annotation.viewport_ops(M.document,viewport,effect,not effect)
    else
      -- A configuration can reload before its installed shared library is
      -- upgraded. Keep that combination usable until the library is applied.
      base=source ops=annotation.ops(M.document,false,effect,not effect)
      ops[#ops+1]={"crop",viewport.x,viewport.y,viewport.w,viewport.h}
    end
    (owned.preview or owned.render)(base,ops,function(ok,path)
      if current~=generation then return end
      rendering=false
      if M.busy:get() then
        if ok and path:sub(1,7)=="memory:" then
          -- A native session replaces its previous frame on delivery. Keep
          -- displaying the delivered one while export waits for this worker;
          -- discarding it would leave the UI pointing at released pixels.
          M.preview:set(path)
        elseif ok then owned.remove(path) end
        local next_render=render_waiter render_waiter=nil
        if next_render then next_render() end
        return
      end
      if ok then
        local old=M.preview:get() M.preview:set(path)
        if old~="" and old~=source and old~=preview_source then owned.remove(old) end
      else failure(path) end
      if M.document and (render_dirty or M.document.revision~=rev) then M.redraw() end
    end)
  end,false)
end
local function styles()
  local out={}
  for _,t in ipairs(annotation.tools) do out[t[1]]={color=config.get("capture.tools."..t[1]..".color"),
    width=config.get("capture.tools."..t[1]..".width"),filled=config.get("capture.tools."..t[1]..".filled")} end
  return out
end
function M.load(path,width,height,screen,done,preview)
  source=path preview_source=preview or path output=screen finished=done viewport=viewport_for(width,height,screen)
  last_hover_window=nil selection_confirmed=false render_dirty=false
  M.document=annotation.new(width,height,{styles=styles(),blur=config.get("capture.blur"),pixelate=config.get("capture.pixelate"),
    zoom=config.get("capture.zoom"),font=require("theme").font or "sans-serif",changed=changed,
    style_changed=function(tool,style)
      for key,value in pairs(style) do config.set("capture.tools."..tool.."."..key,value) end
    end})
  M.document.choose("select")
  M.phase:set("selecting") M.hovered:set(false) M.tools_open:set(false) M.more_open:set(false)
  M.hint:set("")
  M.preview:set(preview or path) M.status:set("Drag an area · click a window · S screen · Esc cancel")
  M.pending:set(false) M.toolbar:set({x=0,y=0}) M.active:set(true)
end
function M.start(target,done)
  if session then M.cancel() end
  generation=generation+1 local current=generation
  finished=done M.target=target or "region"
  local screen=(morf.screens or {})[1] or {name="",x=0,y=0,width=1920,height=1080}
  session=backend.session {cursor=config.get("capture.cursor")}
  M.pending:set(true)
  watchdog=morf.timer(10000,function() if current==generation then failure("Screenshot capture timed out") end end,false)
  M.windows={}
  backend.windows(function(windows) if current==generation then M.windows=windows end end)
  local function captured(ok,frame)
    if current~=generation then return end
    if not ok then failure(frame) return end
    local desktop=frame.desktop or screen
    local view=viewport_for(frame.width,frame.height,desktop)
    local function ready(path)
      if current~=generation then return end
      if watchdog then watchdog:cancel() watchdog=nil end
      M.load(frame.source,frame.width,frame.height,desktop,done,path)
      M.target=target
      if target=="screen" then M.select_screen() end
    end
    if view.x==0 and view.y==0 and view.w==frame.width and view.h==frame.height then ready(frame.source)
    else session.render(frame.source,{{"crop",view.x,view.y,view.w,view.h}},function(good,path)
      if current~=generation then return end
      if good then ready(path) else failure(path) end
    end) end
  end
  if target~="screen" and #(morf.screens or {})>1 and session.desktop then session.desktop(morf.screens,captured)
  else session.snapshot(screen.name,captured) end
end
function M.confirm_selection()
  if not M.document then return end
  if not selection_confirmed then
    M.document.undo_stack={} M.document.redo_stack={} selection_confirmed=true
  end
  M.phase:set("editing") M.hovered:set(false) M.toolbar:set({x=0,y=0})
  M.status:set("") M.tools_open:set(false) M.more_open:set(false)
  M.hint:set("")
end
function M.select_screen()
  local d=M.document if not d then return end
  local screen=(morf.screens or {})[1] or {} local s=output or screen
  local factor=d.width/(s.width or d.width)
  d.set_crop(((screen.x or 0)-(s.x or 0))*factor,((screen.y or 0)-(s.y or 0))*factor,
    (screen.width or d.width)*factor,(screen.height or d.height)*factor)
  M.confirm_selection()
end
function M.reselect()
  if not M.document or M.busy:get() then return end
  if M.document.draft and M.document.draft.type=="text" then M.text(M.text_value:get()) end
  M.document.choose("select") M.phase:set("selecting") M.hovered:set(false) last_hover_window=nil
  M.tools_open:set(false) M.more_open:set(false) M.settings:set(false)
  M.status:set("Drag an area · click a window · S screen · Esc cancel")
end
function M.hover(x,y)
  if M.phase:get()~="selecting" or not M.document or M.document.origin then return end
  local s=output or {} local factor=M.document.width/(s.width or M.document.width)
  local r=backend.window_at(M.windows,(s.x or 0)+x/factor,(s.y or 0)+y/factor)
  if r==last_hover_window then return end
  last_hover_window=r
  M.hovered:set(r and {x=(r.x-(s.x or 0))*factor,y=(r.y-(s.y or 0))*factor,w=r.w*factor,h=r.h*factor} or false)
end
function M.choose(tool)
  if M.document and not M.busy:get() and M.phase:get()=="editing" then
    local d=M.document
    if d.draft and d.draft.type=="text" then M.text(M.text_value:get()) end
    local restore=d.moving or d.draft and (d.tool=="blur" or d.tool=="pixelate" or d.tool=="zoom")
    d.choose(tool) M.dismiss_tools() M.status:set("")
    if restore then M.redraw() end
  end
end
function M.begin(x,y)
  local d=M.document if not d or M.busy:get() then return false end
  if M.phase:get()=="editing" then
    -- Dismiss a popover without turning that same click into a mark or
    -- cancelling the capture. A second gesture acts on the image.
    if M.dismiss_tools() then return false end
    local b=d.crop
    if x<b.x or y<b.y or x>b.x+b.w or y>b.y+b.h then M.cancel() return false end
    if #d.items>=128 and d.tool~="select" then M.status:set("128 marks reached · undo or delete a mark") return false end
    M.status:set("")
  end
  local count=#d.items
  d.begin(x,y)
  if M.phase:get()=="selecting" then d.selected=nil d.moving=nil end
  if d.draft and d.draft.type=="text" then M.text_value:set("") end
  if d.draft and (d.tool=="blur" or d.tool=="pixelate" or d.tool=="zoom") then d.draft.strength=config.get("capture."..d.tool) end
  if #d.items~=count then M.redraw(true) end
  return true
end
function M.move(x,y)
  if M.document and not M.busy:get() then
    M.document.update(x,y)
    local d=M.document local draft=d.draft
    if d.moving or draft and (draft.type=="blur" or draft.type=="pixelate" or draft.type=="zoom") then M.redraw() end
  end
end
function M.finish(x,y)
  local d=M.document if not d or M.busy:get() then return end
  local selecting=M.phase:get()=="selecting"
  local draft=d.draft local moving=d.moving
  -- The last motion can be coalesced; always include the release position.
  if d.origin and (x~=d.origin.x or y~=d.origin.y) or draft and draft.type~="text" then d.update(x,y) end
  local chosen=d.preview_crop and d.preview_crop.w>=2 and d.preview_crop.h>=2
  if selecting and d.tool=="select" and d.origin and not d.moving and not chosen then
    local s=output or {} local sx=d.width/(s.width or d.width) local sy=sx
    local window=backend.window_at(M.windows,(s.x or 0)+x/sx,(s.y or 0)+y/sy)
    if window then chosen=true d.set_crop((window.x-(s.x or 0))*sx,(window.y-(s.y or 0))*sy,window.w*sx,window.h*sy) end
  end
  d.finish()
  if selecting then if chosen then M.confirm_selection() end
  elseif moving or draft and draft.type~="text" then M.redraw(true) end
end
function M.text(value) if M.document and not M.busy:get() then M.document.finish(value) M.redraw(true) end end
function M.style(key,value)
  if M.document and not M.busy:get() then
    local selected=M.document.tool=="select" and M.document.items[M.document.selected]
    M.document.style(key,value)
    if selected then M.redraw(true)
    elseif M.document.moving or M.document.draft and (M.document.tool=="blur" or M.document.tool=="pixelate" or M.document.tool=="zoom") then M.redraw() end
  end
end
function M.undo() if M.document and not M.busy:get() then if M.document.undo() then M.redraw() end end end
function M.redo() if M.document and not M.busy:get() then if M.document.redo() then M.redraw() end end end
function M.remove()
  local d=M.document
  if d and not M.busy:get() and d.remove() then
    if d.moving or d.draft or d.origin then d.abort() end
    M.redraw()
  end
end
function M.wheel(steps)
  local d=M.document if not d or M.busy:get() or steps==0 then return end
  M.style("width",M.current_style().width+(steps>0 and 1 or -1))
end
function M.resize_begin()
  if not M.document or M.busy:get() then return false end
  M.document.remember() resize_base=M.document.crop return true
end
function M.resize(handle,x,y) if M.document and resize_base and not M.busy:get() then M.document.resize(handle,x,y,resize_base) end end
function M.resize_end() resize_base=nil end
function M.crop()
  local d=M.doc()
  if d and M.phase:get()=="selecting" then return d.preview_crop or M.hovered:get() or {x=0,y=0,w=0,h=0} end
  return d and (d.preview_crop or d.crop) or {x=0,y=0,w=0,h=0}
end
function M.mark_geometry()
  local d=M.doc()
  if not d or d.tool~="select" or not d.selected or not d.items[d.selected] then return {x=0,y=0,w=0,h=0} end
  if mark_cache and mark_cache.doc==d and mark_cache.revision==d.revision then return mark_cache.box end
  local b=annotation.bounds(d.draft or d.items[d.selected])
  local box={x=b.x-3,y=b.y-3,w=b.w+6,h=b.h+6}
  mark_cache={doc=d,revision=d.revision,box=box}
  return box
end
function M.draft_geometry()
  local d=M.doc() local v=viewport
  if not d or not d.draft or not v then return {x=0,y=0,w=0,h=0} end
  if draft_cache and draft_cache.doc==d and draft_cache.revision==d.revision then return draft_cache.box end
  local b=annotation.bounds(d.draft)
  local pad=d.draft.type=="arrow" and math.max(24,d.draft.width*5+2) or d.draft.width+2
  local x,y=math.max(v.x,math.floor(b.x-pad)),math.max(v.y,math.floor(b.y-pad))
  local right,bottom=math.min(v.x+v.w,math.ceil(b.x+b.w+pad)),math.min(v.y+v.h,math.ceil(b.y+b.h+pad))
  local box={x=x,y=y,w=math.max(0,right-x),h=math.max(0,bottom-y)}
  draft_cache={doc=d,revision=d.revision,box=box}
  return box
end
function M.draft_paths()
  local d=M.doc() local b=M.draft_geometry()
  if not d or not d.draft or b.w==0 or b.h==0 or d.draft.type=="blur" or d.draft.type=="pixelate" or d.draft.type=="text" then return {stroke="",fill=""} end
  if not draft_cache.paths then draft_cache.paths=morf.image.annotation_path(d.draft) end
  return draft_cache.paths
end
function M.draft_viewbox()
  local b=M.draft_geometry()
  return {x=b.x,y=b.y,w=math.max(1,b.w),h=math.max(1,b.h)}
end
-- The picker is the kit's file chooser (lib.kit.composites.file_chooser),
-- drawn by the editor's view while `picker` holds what it was opened
-- with: `{ kind = "save" | "folder", path, name, serial }`. It walks the
-- folders itself and answers `pick_close(true, target)`.
local pick_serial=0
function M.pick_open(kind,path,cb)
  picker_done=cb
  local initial=backend.expand(path)
  local directory=kind=="save" and initial:match("^(.*)/[^/]+$") or initial
  local name=kind=="save" and initial:match("([^/]+)$") or ""
  if directory=="" then directory="/" end
  pick_serial=pick_serial+1
  M.picker:set({kind=kind,path=directory,name=name,serial=pick_serial})
end
--- Closes the picker: `accept` with the chooser's `target` (the folder,
--- or the folder and name to save as; the folder it was opened on when
--- none is given), or cancelled.
function M.pick_close(accept,target)
  local picker=M.picker:get() if not picker then return end
  target=target and backend.expand(target) or (picker.kind=="save" and (picker.path.."/"..picker.name) or picker.path)
  if accept and picker.kind=="save" then
    local name=target:match("([^/]+)$") or ""
    if name=="" then M.status:set("Enter an image filename") return end
    if not name:lower():match("%.(png)$") and not name:lower():match("%.jpe?g$") and not name:lower():match("%.webp$") then
      M.status:set("Use .png, .jpg or .webp") return
    end
    if morf.fs.exists(target) and picker.overwrite~=target then
      M.picker:set({kind=picker.kind,path=picker.path,name=name,serial=picker.serial,overwrite=target})
      M.status:set("That file exists · press Save again to replace it") return
    end
  end
  M.picker:set(false)
  local cb=picker_done picker_done=nil if cb then cb(accept and target or nil) end
end
function M.pick_folder()
  M.pick_open("folder",config.get("capture.folder"),function(path) if path then config.set("capture.folder",path) end end)
end
local live_binding="Print"
local function apply_binding(binding)
  if binding==live_binding then return end
  backend.rebind(binding,live_binding,config.get("capture.keybind_file"),function(ok,why)
    if ok then live_binding=binding config.set("capture.hotkey",binding) M.status:set("Capture key: "..binding)
    else M.status:set(tostring(why or "Could not change capture key")) end
  end)
end
function M.binding_key(key,text,mods,_,name)
  if not M.rebinding:get() then return end
  if key==65307 then M.rebinding:set(false) return end
  name=name or text
  if not name or name=="" or name:match("_[LR]$") then return end
  local tokens={}
  for _,entry in ipairs {{"logo","SUPER"},{"ctrl","CTRL"},{"alt","ALT"},{"shift","SHIFT"}} do
    if (mods or ""):find(entry[1],1,true) then tokens[#tokens+1]=entry[2] end
  end
  tokens[#tokens+1]=name
  local binding=table.concat(tokens," + ")
  M.rebinding:set(false) apply_binding(binding)
end
-- Saved shell preferences also restore the binding after a compositor reload.
local hypr=require("lib.integrations.hyprland")
if hypr.on then
  local function restore()
    if not morf.primary or morf.primary() then live_binding="Print" apply_binding(config.get("capture.hotkey")) end
  end
  hypr.on("connected",restore) hypr.on("configreloaded",restore)
end
morf.effect("caelestia.capture.hotkey",function()
  local binding=config.get("capture.hotkey")
  local primary=not morf.primary or morf.primary()
  if primary and hypr.available and hypr.available() then apply_binding(binding)
  elseif not primary then live_binding=binding end
end)
local function output_name()
  return backend.expand(config.get("capture.folder")).."/capture_"..morf.time.format("%Y%m%d_%H-%M-%S").."_"..tostring(morf.time.now_ms())..".png"
end
function M.export(action)
  if M.busy:get() or not M.document or not session or M.phase:get()~="editing" then return end
  if action=="upload" and not M.upload_confirm:get() then M.upload_confirm:set(true) return end
  M.upload_confirm:set(false)
  local current=generation local owned=session
  local rendered
  -- Accept text even if the user clicks Copy instead of pressing Enter.
  if M.document.draft then
    M.document.finish(M.document.draft.type=="text" and M.text_value:get() or nil)
  end
  if render_timer then render_timer:cancel() render_timer=nil end
  render_dirty=false
  M.busy:set(true) M.status:set(action=="upload" and "Uploading…" or "Rendering…")
  local function complete(ok,message)
    if current~=generation then return end
    M.busy:set(false)
    if rendered then owned.remove(rendered) rendered=nil end
    if ok then
      if M.on_export then M.on_export(action,message) end
      M.cancel()
    else M.status:set(tostring(message or "Export failed")) M.redraw() end
  end
  local function render_export()
    owned.render(source,annotation.ops(M.document,true,false),function(ok,path)
      if current~=generation then return end
      if not ok then complete(false,path) return end
      rendered=path
      local function copy_done(good,message) complete(good,message) end
      local function save(target,then_copy)
        if not target then M.busy:set(false) M.status:set("Save cancelled") owned.remove(path) M.redraw() return end
        target=backend.expand(target)
        local folder=target:match("^(.*)/[^/]+$") if folder then morf.fs.mkdir(folder) end
        backend.save(path,target,function(good,message)
          if current~=generation then return end
          if good and then_copy then backend.copy(path,copy_done) else complete(good,message) end
        end)
      end
      if action=="copy" then
        if config.get("capture.copy_to_disk") then save(output_name(),true) else backend.copy(path,copy_done) end
      elseif action=="save" then
        if config.get("capture.save_dialog") then M.pick_open("save",output_name(),function(target) if current==generation then save(target,config.get("capture.copy_on_save")) end end)
        else save(output_name(),config.get("capture.copy_on_save")) end
      elseif action=="upload" then backend.upload(path,config.get("capture.upload_endpoint"),complete)
      else complete(false,"Unknown export action") end
    end)
  end
  -- Wait for an in-flight preview to release its pixels before exporting.
  if rendering then render_waiter=render_export else render_export() end
end
function M.key(key,text,mods)
  if not M.active:get() then return end
  if key==65307 then
    if M.tools_open:get() then M.tools_open:set(false) return end
    if M.more_open:get() then M.more_open:set(false) return end
    if M.picker:get() then M.pick_close(false) return end
    if M.settings:get() then M.settings:set(false) return end
    if M.upload_confirm:get() then M.upload_confirm:set(false) return end
    if M.document and M.document.draft then M.document.abort() M.redraw() else M.cancel() end
    return
  end
  if M.picker:get() or M.settings:get() or M.upload_confirm:get() then return end
  if M.phase:get()=="selecting" then
    if not (mods or ""):find("ctrl",1,true) and not (mods or ""):find("alt",1,true)
      and not (mods or ""):find("logo",1,true) and ((text or ""):lower()=="s" or key==65293) then M.select_screen() end
    return
  end
  local ctrl=(mods or ""):find("ctrl",1,true)
  if ctrl then
    local k=string.char(key<128 and key or 0):lower()
    if k=="z" then if (mods or ""):find("shift",1,true) then M.redo() else M.undo() end
    elseif k=="y" then M.redo() elseif k=="c" then M.export("copy") elseif k=="s" then M.export("save") elseif k=="u" then M.export("upload") end
    return
  end
  if key==65535 or key==65288 then M.remove() return end
  if text=="f" then local d=M.document if d and (d.tool=="rect" or d.tool=="ellipse") then M.style("filled",not d.styles[d.tool].filled) end return end
  for _,tool in ipairs(M.tools) do if text==tool[3] then M.choose(tool[1]) return end end
end
M.node=require("themes").view("capture_editor").build(M)
return M
