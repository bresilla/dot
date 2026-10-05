-- Decorative surfaces only. Account selection, input, PAM and greetd stay in
-- the shared layouts/controllers. All animation stops once a reveal settles.
local morf = require("morf")
local ui = require("morf.ui")
local stroke = require("themes.tsugumori.strokes")
local JAPANESE = "M+1 Nerd Font, Noto Sans CJK JP, Noto Sans JP, sans-serif"
local BEVEL = "M14 0 H100 V86 L86 100 H0 V14 Z"
return function(ctx)
  local C = ctx.C
  local function accent() return C.primary end
  local function corners(parent, size, color)
    for i, anchor in ipairs {{left=true,top=true},{right=true,top=true},{left=true,bottom=true},{right=true,bottom=true}} do
      ui.reparent(ui.Path {anchors=anchor,width=size,height=size,view_box={0,0,16,16},
        d="M0 0 H16 V1 H1 V16 H0 Z",rotation=({0,90,270,180})[i],fill_color=color},parent)
    end
  end
  local function label(props)
    props.color = props.color or function() return C.onSurfaceVariant end
    return ctx.text(props)
  end
  local skin = {
    grow={duration=300,easing="out_expo"}, settle={duration=240,easing="out_cubic"},
    sheet_motion={opacity={duration=90,easing="out_cubic"},translate_y={duration=300,easing="out_expo"}},
    blend=0, key_radius=0, static_art=true, avatar_path=BEVEL,
    wallpaper_tint=.78, clock_weight=400,
    sheet_color=function() return C.surface end,
  }
  function skin.keyboard_look(look)
    look.radius=0
    look.panel=function() return C.surface:alpha(0) end
    look.key=function() return C.primary:alpha(.07) end
    look.key_dim=function() return C.primary:alpha(.035) end
    look.press=function() return C.primary:alpha(.14) end
    return look
  end

  skin.clock=require("themes.tsugumori.auth_clock")(ctx)

  function skin.avatar(person, size, selected, id)
    local function fill() return selected() and C.primaryContainer or C.surfaceContainerHigh end
    local image = person.face and person.face ~= "" and person.face
    local node = ui.Item {id=id,width=size,height=size,
      ui.Path {anchors={fill=true},view_box={0,0,100,100},d=BEVEL,fill_color=fill,
        behavior={fill_color={duration=160}}},
      image and ui.Image {x=4,y=4,width=size-8,height=size-8,source=image,fill_mode="preserve_aspect_crop",
        mask=ui.Path {anchors={fill=true},view_box={0,0,100,100},d=BEVEL,fill_color="#ffffff"}}
      or label {anchors={center_in=true},text=person.initial or "?",font_size=math.floor(size*.42),font_weight=400,
        color=function() return selected() and C.onPrimaryContainer or C.onSurfaceVariant end},
      ui.Path {anchors={fill=true},view_box={0,0,100,100},d="M0 28 V14 L14 0 H36 M64 100 H86 L100 86 V72",
        fill_color="#00000000",stroke_color=accent,stroke_width=1.25,
        opacity=function() return selected() and .6 or .15 end,behavior={opacity={duration=180}}},
    }
    return node
  end

  function skin.backdrop(W,H,s,role)
    -- A still architectural grid, with large clear areas behind the controls.
    -- No full-screen rotation, grain shader or perpetual redraw while idle.
    local path={}
    local function line(x,y,xx,yy) path[#path+1]=("M%.1f %.1f L%.1f %.1f"):format(x,y,xx,yy) end
    for _,x in ipairs {W*.18,W*.82} do line(x,s(110),x,H-s(150)) end
    for _,y in ipairs {H*.36,H*.69} do
      line(s(38),y,W*.30,y) line(W*.70,y,W-s(38),y)
    end
    line(s(38),H*.69,W*.18,H*.69-s(76))
    line(W*.82,H*.36+s(76),W-s(38),H*.36)
    return ui.Item {id=(role or "auth").."-auth-backdrop",anchors={fill=true},
      ui.Rect {anchors={fill=true},color=function() return C.surfaceContainerLowest end},
      ui.Path {width=W,height=H,view_box={0,0,W,H},d=table.concat(path," "),
        fill_color="#00000000",stroke_width=1,stroke_color=function() return C.primary:alpha(.045) end},
    }
  end

  function skin.chrome(W,H,s,role)
    local lock=role=="lock"
    local shown=function() return ctx.stage:get()=="rest" or ctx.stage:get()=="sheet" end
    local node=ui.Item {id=role.."-register",anchors={fill=true},
      opacity=function() return shown() and 1 or 0 end,
      behavior={opacity={duration=300,easing="out_cubic"}},
    }
    -- Reuse the shell's phase drawing in two bounded side strips. It assembles
    -- once on entry; there is no time uniform or idle animation afterward.
    if W>=s(1400) then
      local phase=require("themes.tsugumori.phase")
      local progress=ui.Item {opacity=0}
      ui.reparent(progress,node)
      local refresh={}
      for i,x in ipairs {math.floor(W*.16),math.floor(W*.80)} do
        local field,update=phase.field(C,function() return progress.opacity end,
          {id=role.."-phase-"..i,x=x,y=math.floor(H*.33),width=s(84),height=math.floor(H*.35),opacity=.22})
        ui.reparent(field,node) refresh[#refresh+1]=update
      end
      local running,was=nil,false
      morf.effect(role..".phase-entry."..(ctx.output_name or ""),function()
        local on=shown()
        if on==was then return end
        was=on
        if running then running:stop() running=nil end
        if not on then progress.opacity=0 return end
        running=morf.animation.play {{node=progress,property="opacity",from=0,to=1,duration=650,easing="out_cubic"}}
        for _,update in ipairs(refresh) do update(650) end
      end,{owner=node})
    end
    -- Edge register is deliberately sparse. Hide side inscriptions on phones.
    if W>=s(1000) then
      ui.reparent(label {x=s(42),y=math.floor(H*.47),text=lock and "守\n護" or "暁\n光",
        font_family=JAPANESE,font_size=s(28),
        color=function() return C.primary:alpha(.22) end},node)
      ui.reparent(label {anchors={right=true,right_margin=s(42)},y=math.floor(H*.47),
        text=lock and "MORF\n\nLOCK" or "MORF\n\nGREET",font_size=s(10),letter_spacing=s(2),
        horizontal_alignment="right",color=function() return C.primary:alpha(.32) end},node)
      for _,right in ipairs {false,true} do
        ui.reparent(ui.Path {x=right and W-s(112) or s(96),y=math.floor(H*.5),width=s(16),height=s(16),
          view_box={0,0,16,16},d="M0 8 H16 M8 0 V16",fill_color="#00000000",stroke_width=1,
          stroke_color=function() return stroke(C,"quiet") end},node)
      end
    end
    ui.reparent(label {x=s(38),anchors={bottom=true,bottom_margin=s(30)},text=lock and "01 / SESSION LOCK" or "02 / SIGN IN",
      font_size=s(10),letter_spacing=s(1),color=function() return C.primary:alpha(.46) end,
      visible=function() return (lock or H>=s(500)) and (W>=s(1000) or ctx.stage:get()=="rest") end},node)
    ui.reparent(label {anchors={right=true,right_margin=s(38),bottom=true,bottom_margin=s(30)},
      text=lock and "シュゴ / SHUGO" or "アカツキ / AKATSUKI",font_family=JAPANESE,font_size=s(11),
      color=function() return C.primary:alpha(.46) end,
      visible=function() return (lock or H>=s(500)) and (W>=s(1000) or ctx.stage:get()=="rest") end},node)
    return node
  end

  function skin.sheet(host,opts)
    local s,role,W=opts.scale,opts.role,opts.width
    local lock=role=="lock"
    local id=role.."-auth"
    require("themes.tsugumori.auth_result")({color=C})(host,id,{
      scope=ctx.output_name,
      active=function() local stage=ctx.stage:get() return stage=="sheet" or stage=="opening" or stage=="leaving" end,
      read=function()
        local stage=ctx.stage:get()
        return (stage=="opening" or stage=="leaving") and "opening" or ctx.bad:get() and "failed" or "waiting"
      end,
    })
    local trim=ui.Item {id=id.."-trim",anchors={fill=true},z=2}
    ui.reparent(trim,host)
    corners(trim,s(22),function() return stroke(C,"corner") end)
    ui.reparent(label {x=s(18),y=s(11),text=lock and "UNLOCK" or "SIGN IN",font_size=s(9),letter_spacing=s(2),
      color=function() return C.primary:alpha(.55) end},trim)
    ui.reparent(label {anchors={right=true,right_margin=s(18)},y=s(10),
      text=lock and "守護" or "暁",font_family=JAPANESE,font_size=s(12),
      color=function() return C.primary:alpha(.55) end},trim)
    -- A brief, opaque reveal like the shell drawers. It retracts horizontally
    -- after the sheet arrives. It never receives keys or sends auth requests.
    local cover=ui.Rect {id=id.."-cover",z=100,clip=true,x=0,width=0,
      anchors={top=true,bottom=true},color=accent,visible=false,
      require("lib.kit.widgets").shield {anchors={fill=true}},
      ui.Column {anchors={center_in=true},align="center",gap=s(7),
        label {text=lock and "シュゴ" or "アカツキ",font_family=JAPANESE,font_size=s(30),
          letter_spacing=s(3),color=function() return C.onPrimary end},
        label {text=lock and "SHUGO / LOCK" or "AKATSUKI / GREET",font_size=s(10),letter_spacing=s(2),
          color=function() return C.onPrimary:alpha(.7) end},
      },
    }
    corners(cover,s(20),function() return C.onPrimary:alpha(.45) end)
    ui.reparent(cover,host)
    local running,was,generation=nil,false,0
    morf.effect(id..".reveal."..(ctx.output_name or ""),function()
      local on=opts.active()
      if on==was then return end
      was=on generation=generation+1
      local own=generation
      if running then running:stop() running=nil end
      cover.visible=on
      if not on then cover.width=0 return end
      cover.x,cover.width=0,W
      running=morf.animation.play {{parallel={
        {node=cover,property="x",from=0,to=W,delay=180,duration=240,easing="out_expo"},
        {node=cover,property="width",from=W,to=0,delay=180,duration=240,easing="out_expo"},
      }},on_finished=function(reason)
        if own~=generation then return end
        running=nil
        if reason=="completed" then cover.visible=false end
      end}
    end,{owner=host})
  end
  return skin
end
