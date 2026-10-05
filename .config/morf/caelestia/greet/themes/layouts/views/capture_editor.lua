-- Shared editor layout; each theme supplies its existing controls and motion.
local ui=require("morf.ui")
local morf=require("morf")
local kit=require("kit")
local theme=require("theme")
local config=require("config")
local C=theme.color
local V={}
-- The dimming over what is outside the crop, and behind the picker.
local function scrim(a) return function() return C.scrim:alpha(a) end end
function V.build(M)
  local function g() return M.geometry() end
  local function crop() local b=M.crop() local a=g() return {x=b.x*a.scale,y=b.y*a.scale,w=b.w*a.scale,h=b.h*a.scale} end
  local function doc() return M.doc() end
  local function text_draft() local d=doc() return d~=nil and d.draft~=nil and d.draft.type=="text" end
  local function editing() return M.phase:get()=="editing" end
  local function button(id,label,icon,action,x,y,w,selected,enabled)
    local area
    local function on() return selected and selected() or false end
    local function ready() return (not M.busy:get() or id:match("^capture%-picker%-")) and (not enabled or enabled()) end
    area=kit.action {id=id,x=x,y=y,width=w or 36,height=40,
      cursor=function() return ready() and "pointer" or "default" end,
      on_clicked=function() if ready() then action() end end,
      opacity=function() return ready() and 1 or .35 end,
      on_entered=function() M.hint:set(label) end,
      on_exited=function() M.hint:set("") end,
      ui.Item {anchors={fill=true},translate_y=function() return area and area.pressed and 1 or area and area.hovered and -1 or 0 end,
        behavior={translate_y=kit.spring()},
      icon and kit.icon(icon,19,function() return on() and C.onPrimary or C.onSurface end,{anchors={center_in=true}})
        or kit.menu_label {text=label,anchors={center_in=true},font_size=12,color=function() return on() and C.onPrimary or C.onSurface end},
      },
    }
    return kit.hover(area,function(hovered)
      return on() and C.primary or C.primary:alpha(area.pressed and .20 or hovered and .12 or .025)
    end,10)
  end
  local handles={}
  local roles={{"nw",0,0},{"n",.5,0},{"ne",1,0},{"w",0,.5},{"e",1,.5},{"sw",0,1},{"s",.5,1},{"se",1,1}}
  for _,handle in ipairs(roles) do
    local pressed=false
    handles[#handles+1]=ui.MouseArea {id="capture-handle-"..handle[1],width=16,height=16,
      x=function() local b=crop() return b.x+b.w*handle[2]-8 end,
      y=function() local b=crop() return b.y+b.h*handle[3]-8 end,
      visible=editing,cursor="crosshair",on_pressed=function() pressed=M.resize_begin() end,
      on_position_changed=function(sx,sy)
        if pressed then local a=g() M.resize(handle[1],(sx-a.x)/a.scale,(sy-a.y)/a.scale) end
      end,on_released=function() pressed=false M.resize_end() end,
      kit.surface {anchors={center_in=true},width=9,height=9,radius=3,color=function() return C.primary end,
        border_width=1,border_color=function() return C.onPrimary end},
    }
  end
  local canvas,gesture
  canvas=ui.MouseArea {id="capture-editor-canvas",x=function() return g().x end,y=function() return g().y end,
    width=function() return g().iw end,height=function() return g().ih end,cursor="crosshair",
    focus=function() return M.active:get() and not text_draft() and not M.settings:get() and not M.picker:get() and not M.upload_confirm:get() end,
    on_key_pressed=M.key,
    on_pressed=function(_,_,x,y,button)
      gesture=false
      if button=="right" then if not M.dismiss_tools() then M.cancel() end return end
      if button and button~="left" then return end
      gesture=M.begin(x/g().scale,y/g().scale)
    end,
    on_position_changed=function(_,_,_,_,x,y) if gesture then M.move(x/g().scale,y/g().scale) elseif not canvas.pressed then M.hover(x/g().scale,y/g().scale) end end,
    on_released=function(_,_,x,y) if gesture then M.finish(x/g().scale,y/g().scale) end gesture=false end,
    on_wheel=function(_,_,_,_,_,steps) if editing() then M.wheel(steps) end end,
    ui.Image {id="capture-editor-image",x=function() return M.preview_geometry().x end,y=function() return M.preview_geometry().y end,
      width=function() return M.preview_geometry().w end,height=function() return M.preview_geometry().h end,source=function() return M.preview:get() end,fill_mode="stretch"},
    ui.Item {
      ui.Path {id="capture-editor-draft-fill",x=function() return M.draft_geometry().x*g().scale end,y=function() return M.draft_geometry().y*g().scale end,
        width=function() return M.draft_geometry().w*g().scale end,height=function() return M.draft_geometry().h*g().scale end,
        view_box=M.draft_viewbox,d=function() return M.draft_paths().fill end,fill_mode="stretch",
        fill_color=function() local d=doc() return d and d.draft and d.draft.color or "transparent" end,
        opacity=function() local d=doc() return d and d.draft and d.draft.type=="marker" and .32 or 1 end,
        visible=function() local d=doc() return d~=nil and d.draft~=nil and not text_draft() and d.draft.type~="blur" and d.draft.type~="pixelate" end},
      ui.Path {id="capture-editor-draft",x=function() return M.draft_geometry().x*g().scale end,y=function() return M.draft_geometry().y*g().scale end,
        width=function() return M.draft_geometry().w*g().scale end,height=function() return M.draft_geometry().h*g().scale end,
        view_box=M.draft_viewbox,d=function() return M.draft_paths().stroke end,fill_mode="stretch",fill_color="transparent",
        stroke_color=function() local d=doc() return d and d.draft and d.draft.color or "transparent" end,
        stroke_width=function() local d=doc() return d and d.draft and d.draft.width or 0 end,stroke_cap="round",stroke_join="round",
        visible=function() local d=doc() return d~=nil and d.draft~=nil and not text_draft() and d.draft.type~="blur" and d.draft.type~="pixelate" end},
    },
    kit.surface {width=function() return g().iw end,height=function() return crop().y end,color=scrim(.33)},
    kit.surface {y=function() local b=crop() return b.y+b.h end,width=function() return g().iw end,
      height=function() local b=crop() return math.max(0,g().ih-b.y-b.h) end,color=scrim(.33)},
    kit.surface {y=function() return crop().y end,width=function() return crop().x end,height=function() return crop().h end,color=scrim(.33)},
    kit.surface {x=function() local b=crop() return b.x+b.w end,y=function() return crop().y end,
      width=function() local b=crop() return math.max(0,g().iw-b.x-b.w) end,height=function() return crop().h end,color=scrim(.33)},
    kit.surface {id="capture-editor-selection",x=function() return crop().x end,y=function() return crop().y end,
      width=function() return crop().w end,height=function() return crop().h end,
      visible=function() return crop().w>0 and crop().h>0 end,
      color="transparent",border_width=1.5,border_color=kit.stroke("hot"),
      kit.decor("corners",{length=12,weight=2,color=kit.stroke("hot")})},
    kit.surface {id="capture-editor-selected-mark",visible=function() return M.mark_geometry().w>0 end,
      x=function() return M.mark_geometry().x*g().scale end,y=function() return M.mark_geometry().y*g().scale end,
      width=function() return M.mark_geometry().w*g().scale end,height=function() return M.mark_geometry().h*g().scale end,
      color="transparent",border_width=1,border_color=kit.stroke("mark",C.primary)},
    (kit.text_field("entry", {id="capture-editor-text",visible=text_draft,focus=function() return M.active:get() and text_draft() or false end,
      x=function() local d=doc() return text_draft() and d.draft.points[1].x*g().scale or 0 end,
      y=function() local d=doc() return text_draft() and d.draft.points[1].y*g().scale or 0 end,
      width=function() return math.min(420,g().iw) end,height=48,font_family=theme.font,
      font_size=function() local d=doc() return text_draft() and d.draft.width*g().scale or 24 end,
      color=function() local d=doc() return d and d.styles.text.color or M.COLOURS[1] end,placeholder="Type · Enter to place",max_length=4096,
      text=function() return M.text_value:get() end,on_text_changed=function(value) M.text_value:set(value) end,
      on_accepted=function(value) M.text(value) end,
      on_escape=function() local d=doc() if d then d.abort() M.redraw(true) end end,
    })),table.unpack(handles),
  }
  local function menu() return M.menu_geometry() end
  local function palette_width() return math.min(468,g().w-24) end
  local function columns() return math.max(2,math.floor((palette_width()-24)/100)) end
  local function cell_width() return (palette_width()-24)/columns() end
  local function rows() return math.ceil(#M.tools/columns()) end
  local function palette_height() return math.min(132+rows()*62,g().h-24) end
  local function above(height)
    local m=menu() local y=m.y-height-10
    if y<12 then y=m.y+m.h+10 end
    return math.max(12,math.min(g().h-height-12,y))
  end
  local function shell_surface(radius)
    return kit.card {anchors={fill=true},radius=radius or 18,color=function() return C.surfaceContainerHigh end}
  end
  local palette_items={}
  for i,t in ipairs(M.tools) do
    local area
    local function on() local d=doc() return d and d.tool==t[1] end
    local function ink() return on() and C.onPrimaryContainer or C.onSurface end
    area=kit.action {id="capture-tool-"..t[1],
      x=function() return ((i-1)%columns())*cell_width() end,
      y=function() return math.floor((i-1)/columns())*62 end,
      width=function() return cell_width()-6 end,height=56,cursor="pointer",
      on_clicked=function() M.choose(t[1]) end,
      on_entered=function() M.hint:set(t[2].." · "..t[3]:upper()) end,
      on_exited=function() M.hint:set("") end,
      kit.icon(t[4],22,ink,{anchors={horizontal_center=true},y=7,fill=on}),
      kit.text {text=t[2],font_size=12,font_weight=500,color=ink,anchors={horizontal_center=true},y=34},
      kit.label {text=t[3]:upper(),font_size=9,color=function() return C.onSurfaceVariant:alpha(.6) end,
        anchors={right=true,right_margin=7},y=5},
    }
    kit.hover(area,function(hovered) return on() and C.primaryContainer or C.primary:alpha(hovered and .10 or .025) end,12)
    palette_items[#palette_items+1]=area
  end
  local styles_items={}
  for i,color in ipairs(M.COLOURS) do
    styles_items[#styles_items+1]=kit.action {id="capture-colour-"..i,x=12+(i-1)*28,y=0,width=26,height=30,
      cursor="pointer",on_clicked=function() M.style("color",color) end,
      kit.surface {anchors={center_in=true},width=20,height=20,radius=10,color=color,
        border_width=function() return M.current_style().color==color and 2 or .5 end,
        border_color=function() return M.current_style().color==color and kit.ink("hi")() or kit.stroke("faint")() end},
      kit.icon("check",14,function() return morf.color(color):text_color() end,
        {anchors={center_in=true},visible=function() return M.current_style().color==color end}),
    }
  end
  styles_items[#styles_items+1]=button("capture-width-minus","Thinner", "remove",function() M.wheel(-1) end,12,34,32)
  styles_items[#styles_items+1]=kit.text {x=48,y=47,width=48,text=function() return M.current_style().width.."px" end,font_size=12}
  styles_items[#styles_items+1]=button("capture-width-plus","Thicker","add",function() M.wheel(1) end,94,34,32)
  styles_items[#styles_items+1]=ui.Item {visible=function() local t=M.tool_info()[1] return t=="rect" or t=="ellipse" end,
    button("capture-fill","Fill",nil,function() M.style("filled",not M.current_style().filled) end,
      144,34,54,function() return M.current_style().filled end),}
  local tools_popup=ui.Item {id="capture-tools-palette",visible=function() return editing() and M.tools_open:get() end,z=5,
    width=palette_width,height=palette_height,
    x=function() return math.max(12,math.min(g().w-palette_width()-12,menu().x+(menu().w-palette_width())/2)) end,
    y=function() return above(palette_height()) end,

    shell_surface(),ui.MouseArea {anchors={fill=true}},
    kit.heading {x=16,y=10,text="Markup",level="section",scope="capture.editor.tools",active=function() return M.tools_open:get() end,font_size=14},
    kit.label {anchors={right=true,right_margin=16},y=14,text="Choose a tool",font_size=11,color=kit.ink("lo")},
    (kit.scroll({x=12,y=42,width=function() return palette_width()-24 end,
      height=function() return palette_height()-132 end,clip=true,
      ui.Item {width=function() return palette_width()-24 end,height=function() return rows()*62 end,table.unpack(palette_items)},})),
    kit.surface {x=16,y=function() return palette_height()-86 end,width=function() return palette_width()-32 end,height=1,
      color=kit.stroke("faint")},
    ui.Item {x=0,y=function() return palette_height()-82 end,width=palette_width,height=80,table.unpack(styles_items)},
  }
  local toolbar_drag
  local function tx(x) return x*menu().w/392 end
  local toolbar=ui.Item {id="capture-editor-toolbar",visible=editing,width=function() return menu().w end,height=function() return menu().h end,
    x=function() return menu().x end,y=function() return menu().y end,

    shell_surface(20),
    ui.MouseArea {x=12,y=0,width=function() return menu().w-24 end,height=34,cursor="move",
      on_pressed=function(sx,sy) toolbar_drag={x=sx,y=sy,pos=M.toolbar:get()} end,
      on_position_changed=function(sx,sy) if toolbar_drag then M.toolbar:set({x=toolbar_drag.pos.x+sx-toolbar_drag.x,y=toolbar_drag.pos.y+sy-toolbar_drag.y}) end end,
      on_released=function() toolbar_drag=nil end,
      kit.icon(function() return M.tool_info()[4] end,18,function() return C.primary end,{x=2,y=11}),
      kit.heading {id="capture-editor-title",x=28,y=8,width=function() return menu().w-148 end,height=24,
        text=function() local d=doc() return d and d.tool=="select" and not d.selected and "Capture" or M.tool_info()[2] end,
        scope="capture.editor",level="caption",font_size=12,active=editing},
      kit.label {anchors={right=true},y=13,width=90,height=16,font_size=11,horizontal_alignment="right",
        text=function() local d=doc() return M.busy:get() and "Working…" or d and (math.floor(d.crop.w).." × "..math.floor(d.crop.h)) or "" end,
        color=function() return C.onSurfaceVariant end},
    },
    button("capture-editor-draw","Drawing tools","draw",function() M.more_open:set(false) M.tools_open:set(not M.tools_open:get()) end,
      function() return tx(10) end,40,function() return tx(42) end,function() return M.tools_open:get() end),
    button("capture-editor-undo","Undo · Ctrl Z","undo",M.undo,function() return tx(58) end,40,function() return tx(38) end,nil,
      function() local d=doc() return d and #d.undo_stack>0 end),
    button("capture-editor-redo","Redo · Ctrl Shift Z","redo",M.redo,function() return tx(102) end,40,function() return tx(38) end,nil,
      function() local d=doc() return d and #d.redo_stack>0 end),
    button("capture-editor-copy","Copy",nil,function() M.export("copy") end,function() return tx(154) end,40,function() return tx(72) end,function() return true end),
    button("capture-editor-save","Save",nil,function() M.export("save") end,function() return tx(232) end,40,function() return tx(72) end),
    button("capture-editor-more","More","more_horiz",function() M.tools_open:set(false) M.more_open:set(not M.more_open:get()) end,
      function() return tx(340) end,40,function() return tx(42) end,function() return M.more_open:get() end),
  }
  local more_items={}
  for i,a in ipairs {{"reselect","Select again","crop_free",M.reselect},{"upload","Upload","cloud_upload",function() M.more_open:set(false) M.export("upload") end},
    {"delete","Delete mark","delete",M.remove},{"settings","Settings","settings",function() M.more_open:set(false) M.settings:set(true) end},
    {"cancel","Cancel","close",M.cancel}} do
    local area
    local function enabled() return a[1]=="cancel" or not M.busy:get() and (a[1]~="delete" or doc() and doc().selected~=nil) end
    area=kit.action {id="capture-editor-"..a[1],x=8,y=8+(i-1)*42,width=184,height=40,cursor="pointer",
      on_clicked=function() if enabled() then a[4]() end end,opacity=function() return enabled() and 1 or .35 end,
      kit.icon(a[3],18,kit.ink("lo"),{x=10,y=11}),
      kit.menu_label {x=38,y=12,width=140,elide="right",text=a[2],font_size=12},
    }
    kit.hover(area,function(hovered) return C.primary:alpha(hovered and .10 or 0) end,10)
    more_items[#more_items+1]=area
  end
  local more_popup=ui.Item {id="capture-more-menu",visible=function() return editing() and M.more_open:get() end,z=6,width=200,height=226,
    x=function() return math.max(12,menu().x+menu().w-200) end,y=function() return above(226) end,

    shell_surface(),ui.MouseArea {anchors={fill=true}},table.unpack(more_items),
  }
  local function reveal(node,open,offset)
    local was=false local animation
    morf.effect(node.id..".reveal",function()
      local now=open()
      if now==was then return end
      was=now
      if animation then animation:stop() animation=nil end
      if now then animation=morf.animation.play {{parallel={
        {node=node,property="opacity",from=0,to=1,duration=140,easing="out_cubic"},
        {node=node,property="translate_y",from=offset,to=0,duration=180,easing="out_cubic"},
      }}} end
    end,{owner=node})
  end
  reveal(toolbar,editing,10)
  reveal(tools_popup,function() return editing() and M.tools_open:get() end,6)
  reveal(more_popup,function() return editing() and M.more_open:get() end,6)
  local settings_items={}
  local function toggle(key,label,y)
    return kit.action {id="capture-setting-"..key,x=16,y=y,width=280,height=30,on_clicked=function() config.set("capture."..key,not config.get("capture."..key)) end,
      kit.icon(function() return config.get("capture."..key) and "check_box" or "check_box_outline_blank" end,20,function() return C.primary end,{y=4}),
      kit.text {x=30,y=6,text=label,font_size=13},}
  end
  for i,option in ipairs {{"save_dialog","Choose where to save"},{"copy_on_save","Copy when saving"},{"copy_to_disk","Save when copying"},{"cursor","Include pointer"}} do
    settings_items[#settings_items+1]=toggle(option[1],option[2],40+(i-1)*32)
  end
  for i,option in ipairs {{"blur","Blur strength",1,100},{"pixelate","Pixel size",1,256},{"zoom","Zoom factor",1,10}} do
    local y=174+(i-1)*40
    settings_items[#settings_items+1]=kit.text {x=16,y=y+10,text=option[2],font_size=13}
    settings_items[#settings_items+1]=button("capture-setting-"..option[1].."-minus","−",nil,function()
      config.set("capture."..option[1],math.max(option[3],config.get("capture."..option[1])-1)) end,174,y,30)
    settings_items[#settings_items+1]=kit.text {x=211,y=y+10,width=40,text=function() return tostring(config.get("capture."..option[1])) end,font_size=13}
    settings_items[#settings_items+1]=button("capture-setting-"..option[1].."-plus","+",nil,function()
      config.set("capture."..option[1],math.min(option[4],config.get("capture."..option[1])+1)) end,264,y,30)
  end
  local settings=ui.Item {id="capture-editor-preferences",z=8,visible=function() return M.settings:get() end,
    x=function() return math.max(12,g().w-336) end,y=42,width=320,height=function() return math.min(490,g().h-54) end,
    kit.card {anchors={fill=true},radius=20,color=function() return C.surfaceContainerHigh end},
    ui.MouseArea {anchors={fill=true}},
    (kit.scroll({width=320,height=function() return math.min(490,g().h-54) end,clip=true,
    ui.Item {width=320,height=490,
    kit.heading {x=16,y=12,text="Capture settings",scope="capture.settings",font_size=16},
    (kit.text_field("entry", {id="capture-setting-folder",x=16,y=302,width=224,height=32,text=function() return config.get("capture.folder") end,
      font_size=12,color=function() return C.onSurface end,
      on_accepted=function(path) config.set("capture.folder",path) end,on_escape=function() M.settings:set(false) end})),
    button("capture-setting-browse","Browse","folder_open",M.pick_folder,248,302,46),
    (kit.text_field("entry", {id="capture-setting-colour",x=16,y=344,width=125,height=30,text=function() local d=doc() return d and M.current_style().color or "" end,
      font_size=13,color=function() return C.onSurface end,on_accepted=function(value)
        if value:match("^#%x%x%x%x%x%x$") then M.style("color",value) else M.status:set("Use a colour like #ef5350") end end})),
    kit.text {x=16,y=386,text="Capture key",font_size=13},
    (kit.text_field("entry", {id="capture-setting-hotkey",x=16,y=412,width=190,height=34,read_only=true,
      text=function() return M.rebinding:get() and "Press a key…" or config.get("capture.hotkey") end,
      focus=function() return M.settings:get() and M.rebinding:get() end,font_size=13,color=function() return C.primary end,
      on_key_pressed=M.binding_key,on_escape=function() M.rebinding:set(false) end})),
    button("capture-setting-rebind","Change",nil,function() M.rebinding:set(true) end,218,412,76),
    button("capture-setting-close","Done",nil,function() M.settings:set(false) end,220,452,76),
    table.unpack(settings_items),
    }})),
  }
  -- The save and folder picker: the kit's file chooser, made each time the
  -- picker opens (at the size the screen gives it then) and let go when it
  -- shuts. On a narrow screen its places fold into a drawer.
  local function pw() return math.min(600,g().w-24) end
  local function ph() return math.min(470,g().h-24) end
  local chooser_host=ui.Item {x=8,y=48,width=function() return pw()-16 end,height=function() return ph()-56 end}
  local picker=ui.Item {id="capture-file-picker",anchors={fill=true},z=10,visible=function() return M.picker:get()~=false end,
    kit.surface {anchors={fill=true},color=scrim(.56)},
    ui.MouseArea {anchors={fill=true},focus=function() return M.picker:get()~=false end,on_key_pressed=M.key},
    ui.Item {anchors={center_in=true},width=pw,height=ph,
      kit.card {anchors={fill=true},radius=20,color=function() return C.surfaceContainerHigh end},
      ui.MouseArea {anchors={fill=true}},
      kit.heading {x=16,y=14,scope="capture.file",font_size=16,
        text=function() local p=M.picker:get() return p and p.kind=="save" and "Save capture" or "Capture folder" end},
      chooser_host,
    },
  }
  local chooser,shown_serial
  morf.effect("caelestia.capture.picker.chooser",function()
    local p=M.picker:get()
    local serial=p and p.serial or nil
    if serial==shown_serial then return end
    shown_serial=serial
    if chooser then ui.destroy(chooser,true) chooser=nil end
    if not p then return end
    local save=p.kind=="save"
    chooser=require("lib.kit.composites").file_chooser {id="capture-picker",
      width=math.max(280,pw()-16),height=math.max(240,ph()-56),root="/",path=p.path,name=p.name,
      mode=save and "save" or "folder",accept_label=save and "Save" or "Choose",
      filters=save and {{name="Images",patterns={"png","jpg","jpeg","webp"}},{name="All files"}} or nil,
      on_accepted=function(target) M.pick_close(true,target) end,
      on_cancelled=function() M.pick_close(false) end}
    ui.reparent(chooser,chooser_host)
  end,{owner=picker})
  local upload_confirm = ui.Item {id="capture-upload-confirm",z=8,visible=function() return M.upload_confirm:get() end,anchors={center_in=true},width=320,height=144,
      kit.card {anchors={fill=true},radius=20,color=function() return C.surfaceContainerHigh end},
      ui.MouseArea {anchors={fill=true}},
      kit.text {x=18,y=18,width=284,wrap=true,text="Upload this image? The link will be public. The default host deletes it after 72 hours.",font_size=14},
      button("capture-upload-back","Back",nil,function() M.upload_confirm:set(false) end,18,94,76),
      button("capture-upload-confirm-send","Upload",nil,function() M.export("upload") end,220,94,82),
    }
  local editor = ui.Item {id="capture-editor",anchors={fill=true},visible=function() return M.active:get() end,z=100,
    kit.surface {anchors={fill=true},color=scrim(1)},
    ui.MouseArea {anchors={fill=true},on_key_pressed=M.key},
    canvas,
    ui.Item {id="capture-selection-hint",visible=function() return M.phase:get()=="selecting" end,
      width=function() return math.min(400,g().w-24) end,height=38,x=function() return (g().w-math.min(400,g().w-24))/2 end,
      y=function() return g().h-58 end,
      kit.card {anchors={fill=true},radius=16,color=function() return C.surfaceContainer:alpha(.94) end},
      kit.text {anchors={center_in=true},text="Drag area · click window · S screen · Esc",font_size=12},
    },
    toolbar,tools_popup,more_popup,
    ui.Item {id="capture-editor-feedback",visible=editing,
      x=function() return (g().w-math.min(440,g().w-24))/2 end,y=function() return g().h-34 end,
      width=function() return math.min(440,g().w-24) end,height=26,
      kit.card {anchors={fill=true},radius=10,color=function() return C.surfaceContainer:alpha(.96) end},
      kit.text {id="capture-editor-feedback-text",anchors={fill=true,left_margin=12,right_margin=12},font_size=11,
        horizontal_alignment="center",vertical_alignment="center",elide="right",
        text=function()
          if M.status:get()~="" then return M.status:get() end
          if M.hint:get()~="" then return M.hint:get() end
          local d=doc()
          if d and d.tool=="select" and d.selected then return "Drag to move · Delete removes · Ctrl Z undoes" end
          return "Ctrl C copy · Ctrl S save · Esc cancel"
        end,color=function() return C.onSurfaceVariant end},
    },
    ui.MouseArea {id="capture-modal-catcher",anchors={fill=true},z=7,
      visible=function() return M.settings:get() or M.upload_confirm:get() end,
      focus=function() return M.active:get() and (M.settings:get() or M.upload_confirm:get()) and not M.picker:get() and not M.rebinding:get() end,
      on_key_pressed=M.key},
    settings,picker,
    upload_confirm,
  }
  -- The preferences and the upload question are kit Popups where they
  -- stand: a press outside either shuts it (the catcher under them keeps
  -- that press from reaching the picture).
  local popup = require("lib.kit.popup")
  popup.track(settings, { open = function() return M.settings:get() end, close_policy = "outside",
    on_close = function() M.settings:set(false) end })
  popup.track(upload_confirm, { open = function() return M.upload_confirm:get() end, close_policy = "outside",
    on_close = function() M.upload_confirm:set(false) end })
  return editor
end
return V
