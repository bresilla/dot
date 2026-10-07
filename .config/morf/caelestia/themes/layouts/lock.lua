-- Shared lock composition. Skins supply surfaces and motion only;
-- authentication and password storage belong to the controller.
local morf = require("morf")
local ui = require("morf.ui")
local osk = require("lib.util.osk")
local shapes = require("lib.util.m3shapes")
return function(ctx)
local ui = ctx.ui or ui
local skin = ctx.auth_skin or {}
local message, bad, clear = ctx.message, ctx.bad, ctx.clear
local HELD = ctx.HELD
local main_output = ctx.main_output
local text = ctx.text
local icon = ctx.icon
local C = ctx.C
local stage = ctx.stage
local pull = ctx.pull
local busy = ctx.busy
local say = ctx.say
local submit = ctx.submit
local method = ctx.method
local has_pattern = ctx.has_pattern
local type_text = ctx.type_text
local backspace = ctx.backspace
local escape = ctx.escape
local clock = ctx.clock
local day = ctx.day
local me = ctx.me
local typed = ctx.typed
local shake = ctx.shake
local MAX_DOTS = ctx.MAX_DOTS
local open_sheet = ctx.open_sheet
local FINGER = ctx.FINGER
local FONT = ctx.FONT
local ICONS = ctx.ICONS
local look = ctx.look
local pattern = ctx.pattern
local key = ctx.key
return function(W, H, NAME)
  local desktop = ctx.desktop.for_output(NAME)
  -- In a window there is one screen, and it is the one.
  local function main() return not HELD or main_output:get() == NAME end
  local s = ctx.s or require("themes.auth_metrics")(W, H, ctx.keyboard_attached())
  local base_text = text
  local function text(props)
    props.font_size = props.font_size or s(15)
    return base_text(props)
  end

  -- -------------------------------------------------------------- geometry --

  local geometry=require("themes.auth_layout")(W,H,s)
  local BORDER = geometry.border
  local ROUND = geometry.round
  local SHORT = geometry.short
  -- The on-screen keyboard: on a phone, or wherever no keyboard is attached.

  local SW = geometry.sheet_width
  local AV = s(52)
  local FIELD_W, FIELD_H = SW-s(48), geometry.field_height

  local PAD_W = math.min(s(300), SW - s(48),math.max(s(96),H-2*BORDER-s(80)))
  local pad = osk.new {
    prefix = "lock.pattern." .. NAME, width = PAD_W, mode = "pattern", look = skin.keyboard_look and skin.keyboard_look(look()) or look(),
    active = function() return main() and stage:get() == "sheet" and method:get() == "pattern" and not busy:get() end,
    on_pattern = function(dots)
      pattern(dots)
    end,
  }
  local function entry_h() return method:get() == "pattern" and pad.height() or FIELD_H end
  local function chip_h() return has_pattern() and s(44) or 0 end
  local kb=require("themes.auth_keyboard").new {
    prefix="lock",output=NAME,width=W,height=H,border=BORDER,embedded_width=FIELD_W,
    main=main,keyboard_attached=ctx.keyboard_attached,busy=busy,stage=stage,method=method,pull=pull,
    claim=function() main_output:set(NAME) end,open_sheet=open_sheet,clear=clear,escape=escape,action=skin.action,
    look=(skin.keyboard_look or function(v) return v end) {
      panel=function() return C.surfaceContainer end,
      key=function() return C.surfaceContainerHighest end,key_dim=function() return C.surfaceContainerHigh end,
      accent=function() return C.primary end,on_accent=function() return C.onPrimary end,
      text=function() return C.onSurface end,dim=function() return C.onSurfaceVariant end,
      press=function() return C.secondaryContainer end,font=FONT,icons=ICONS,radius=skin.key_radius,
    },
    send=function(event)
      if event.text then type_text(event.text)
      elseif event.key=="backspace" then backspace()
      elseif event.key=="enter" then submit()
      elseif event.key=="escape" then escape() end
    end,
  }
  local content_height=kb.content_height
  local form
  local function sheet_h() return form and form.height() or 1 end

  -- The swell's height as it stands: a bud at rest, the sheet up, a swipe
  -- in between.
  local BUD_W, BUD_H = s(132), s(16)
  local function up()
    if not main() then return 0 end
    local st = stage:get()
    if st == "sheet" then return 1 end
    if st == "rest" then return pull:get() end
    return 0
  end
  local function swell_h()
    local st = stage:get()
    if st == "closed" or st == "opening" or not main() then return BORDER end
    return BORDER + BUD_H + (sheet_h() - BUD_H) * up()
  end
  local function swell_w()
    local st = stage:get()
    if st == "closed" or st == "opening" then return BUD_W end
    return BUD_W + (SW - BUD_W) * up()
  end
  local GROW = skin.grow or { duration = 420, easing = "out_back" }
  local SETTLE = skin.settle or { duration = 340, easing = "out_cubic" }
  -- Follows a finger at once, and eases the rest of the way.
  local function swell_motion() return pull:get() > 0 and stage:get() == "rest" and { duration = 60 } or GROW end

  -- ------------------------------------------------------------- the frame --

  -- The frame and the swell are one distance field: the swell is a box that
  -- rises out of the frame's bottom edge and melts into it where they meet.
  local frame = ui.Sdf {
    anchors = { fill = true },
    ui.SdfShape {
      shape = "box", x = 0, y = 0, width = W, height = content_height,
      fill_color = function() return C.surface end,
    },
    -- The opening in the frame: shut while the lock comes in and goes.
    ui.SdfShape {
      shape = "box", operation = "subtract", radius = ROUND,
      x = function() return stage:get() == "closed" and 0 or BORDER end,
      y = function() return stage:get() == "closed" and 0 or BORDER end,
      width = function() return stage:get() == "closed" and W or W - 2 * BORDER end,
      height = function() return stage:get() == "closed" and content_height() or content_height() - 2 * BORDER end,
      behavior = { x = SETTLE, y = SETTLE, width = SETTLE, height = SETTLE },
    },
  }

  -- The swell has a field of its own, in a band along the bottom edge: the
  -- frame above stays still, and a swell growing redraws the band alone,
  -- not the whole screen every frame (a 4K screen of field was the lag).
  local function band_h() return math.min(content_height(), sheet_h() + s(90)) end
  local band = ui.Item {
    visible=function() return stage:get()=="rest" end,
    x = 0, width = W,
    y = function() return content_height() - band_h() end,
    height = band_h,
    ui.Sdf {
      anchors = { fill = true },
      -- The frame's bottom edge, for the swell to melt into.
      ui.SdfShape {
        shape = "box", x = 0, width = W,
        y = function() return band_h() - BORDER end,
        height = BORDER + s(40),
        fill_color = function() return C.surface end,
      },
      ui.SdfShape {
        id = "lock-swell",
        shape = "box", operation = "smooth_union", blend = skin.blend or s(26),
        radius = function() return up() > 0.5 and s(38) or s(12) end,
        fill_color = function() return up() > 0.5 and (skin.sheet_color and skin.sheet_color() or C.surfaceContainer) or C.surface end,
        x = function() return math.floor((W - swell_w()) / 2) end,
        y = function() return band_h() - swell_h() end,
        width = swell_w,
        height = function() return swell_h() + s(40) end,
        behavior = { x = GROW, y = GROW, width = GROW, height = GROW, radius = SETTLE,
          fill_color = { duration = 240 } },
      },
    },
  }

  local backdrop=require("themes.auth_backdrop")(ctx,s,"lock")

  -- ------------------------------------------------------------ at rest --

  local function with(base, extra)
    for k, v in pairs(extra) do base[k] = v end
    return base
  end
  local function resting() return stage:get() == "rest" or stage:get() == "sheet" end

  -- A compact row above the clock, centered independently from the date.
  local weather
  do
    if desktop.weather_available() then
      local now_w = desktop.weather
      weather = ui.Row {
        id="lock-weather",gap=s(8),align="center",
        visible=function() return now_w().temperature~=nil end,
        icon(desktop.weather_symbol, s(26),
          function() return C.onSurfaceVariant end),
        text {
          id="lock-weather-temperature",
          font_size = s(22), color = function() return C.onSurfaceVariant end,
          text = function()
            local n = now_w()
            return n.temperature and ("%d°"):format(math.floor(n.temperature + 0.5)) or ""
          end,
        },
      }
    end
  end

  -- What is playing, as a row: art in a turning cookie, the title, controls.
  local media_row
  do
    if desktop.media_available() then
      local active, control = desktop.player, desktop.control
      local function button(id, name, action, strong)
        local area
        area = ui.MouseArea {
          id = id, width = s(44), height = s(44), cursor = "pointer",
          on_clicked = function() control(action) end,
          scale = function() return (area and area.pressed) and 0.9 or 1 end,
          behavior = { scale = ui.spring { stiffness = 700, damping = 18 } },
          ui.Rect {
            anchors = { fill = true }, radius = s(22),
            color = function() return strong and C.primary or C.surfaceContainerHighest end,
          },
          icon(name, s(22), strong and C.onPrimary or C.onSurface, { anchors = { center_in = true } }),
        }
        return area
      end
      local art = desktop.artwork
      local RW, RH = math.min(s(560), W - 2 * s(40)), s(84)
      local cookie12 = skin.avatar_path or shapes.path("cookie12", { segments = false })
      media_row = ui.Rect {
        id = "lock-media", width = RW, height = RH, radius = RH / 2,
        color = function() return C.surfaceContainer:alpha(0.82) end,
        visible = function() return not SHORT and main() and (active().title or "") ~= "" end,
        ui.Item {
          x = s(12), anchors = { vertical_center = true }, width = s(60), height = s(60),
          ui.Path {
            anchors = { fill = true }, view_box = { 0, 0, 100, 100 }, d = cookie12,
            fill_color = function() return C.secondaryContainer end,
          },
          ui.Image {
            anchors = { fill = true }, fill_mode = "preserve_aspect_crop", source = art,
            visible = function() return art() ~= "" end,
            mask = ui.Path { anchors = { fill = true }, view_box = { 0, 0, 100, 100 }, d = cookie12, fill_color = "#ffffff" },
          },
          loop = function()
            if skin.static_art or not active().playing then return nil end
            return { rotation = { to = 360, duration = 30000, loops = 1, hold = true } }
          end,
        },
        ui.Column {
          x = s(86), anchors = { vertical_center = true }, gap = s(2),
          text { width = RW - s(86) - s(170), elide = "right", font_size = s(16), font_weight = 600,
            text = function() return active().title or "" end },
          text { width = RW - s(86) - s(170), elide = "right", font_size = s(14),
            color = function() return C.onSurfaceVariant end,
            text = function() return active().artist or "" end },
        },
        ui.Row {
          anchors = { right = true, right_margin = s(14), vertical_center = true }, gap = s(8),
          button("lock-media-previous", "skip_previous", "previous"),
          button("lock-media-play", function() return active().playing and "pause" or "play_arrow" end, "play_pause", true),
          button("lock-media-next", "skip_next", "next"),
        },
      }
    end
  end

  -- The time at rest sits a third of the way down; with the sheet up it
  -- steps aside above it, smaller.
  local CLOCK_Y = geometry.clock_y
  local glance = ui.Column {
    id = "lock-glance",
    visible=function() return not main() or stage:get()~="sheet" end,
    width = math.max(1,W-s(64)),
    anchors = { horizontal_center = true }, gap = s(6), align = "center",
    y = function()
      if stage:get() == "sheet" and main() then
        return math.max(s(40), math.floor((content_height() - BORDER - sheet_h()) / 2 - geometry.clock_sheet_offset))
      end
      return CLOCK_Y
    end,
    scale = function() return (stage:get() == "sheet" and main()) and 0.72 or 1 end,
    opacity = function()
      return resting() and (not main() or stage:get() ~= "sheet" or content_height() - sheet_h() > s(220)) and 1 or 0
    end,
    behavior = { y = GROW, scale = GROW, opacity = { duration = 320 } },
    weather or ui.Item {visible=false},
    (skin.clock or text) {
      id = "lock-clock", text = function() return clock:get() end,
      font_size = geometry.clock_size, font_weight = skin.clock_weight or 600, color = C.primary,
    },
    text {id="lock-date",text=function() return day:get() end,width=math.max(1,W-s(64)),
      elide="right",horizontal_alignment="center",font_size=s(22),color=C.onSurfaceVariant},
    ui.Item { width = 1, height = s(34) },
    media_row or ui.Item { width = 1, height = 1 },
  }

  -- Where the way in is: a chevron bobbing over the bud, and what to do.
  local hint = ui.Column {
    anchors = { horizontal_center = true },
    y = function() return content_height() - BORDER - BUD_H - s(74) end, gap = s(2), align = "center",
    opacity = function() return (not SHORT and main() and stage:get() == "rest" and pull:get() < 0.1) and 1 or 0 end,
    behavior = { opacity = { duration = 260 } },
    icon("keyboard_arrow_up", s(30), function() return C.onSurfaceVariant end, {
      -- A few bobs when the screen comes to rest, then still.
      loop = function()
        if SHORT or not main() or stage:get() ~= "rest" then return nil end
        return { translate_y = { from = 0, to = -s(6), duration = 900, alternate = true, loops = 6, easing = "in_out_sine" } }
      end,
    }),
    text {
      text = (FINGER and "Touch the sensor, or " or "")
        .. (FINGER and "swipe up" or "Swipe up")
        .. " to unlock",
      font_size = s(14), color = function() return C.onSurfaceVariant end,
    },
  }

  -- -------------------------------------------------------------- the sheet --

  local cookie = skin.avatar_path or shapes.path("cookie9", { segments = false })
  local avatar = skin.avatar and skin.avatar(me, AV, function() return true end, "lock-avatar") or ui.Item {
    width = AV, height = AV,
    -- Only the cookie turns: a face or an initial stays upright on it.
    ui.Path {
      anchors = { fill = true }, view_box = { 0, 0, 100, 100 }, d = cookie,
      fill_color = function() return C.primaryContainer end,
      -- It turns while authenticating; at rest it is still.
      loop = function()
        if not busy:get() then return nil end
        return { rotation = { to = 360, duration = 2400, hold = true } }
      end,
    },
    me.face and ui.Image {
      anchors = { fill = true }, fill_mode = "preserve_aspect_crop", source = me.face,
      mask = ui.Path { anchors = { fill = true }, view_box = { 0, 0, 100, 100 }, d = cookie, fill_color = "#ffffff" },
    } or text {
      anchors = { center_in = true }, text = me.initial or "?", font_size = s(22), font_weight = 600,
      color = C.onPrimaryContainer,
    },
  }

  local field=require("themes.auth_form").password {
    prefix="lock",ui=ui,s=s,C=C,width=FIELD_W,height=FIELD_H,text=text,icon=icon,
    typed=typed,shake=shake,bad=bad,busy=busy,max_dots=MAX_DOTS,
    submit=submit,focus=function() kb.show() end,
  }

  form=require("themes.auth_form").sheet {
    prefix="lock",output=NAME,ui=ui,s=s,C=C,skin=skin,width=SW,screen_width=W,
    border=BORDER,top=BORDER+s(12),footer=0,keyboard=kb,
    text=text,heading=ctx.heading,avatar=avatar,name=me.label ~= "" and me.label or me.name,
    active=function() return main() and stage:get()=="sheet" end,
    visible=function() return main() and (stage:get()=="sheet" or stage:get()=="opening") end,
    entry_height=entry_h,
    entry=ui.Item {width=FIELD_W,height=entry_h,
      ui.Item {anchors={horizontal_center=true},width=FIELD_W,height=FIELD_H,
        visible=function() return method:get()=="password" end,field},
      ui.Item {anchors={horizontal_center=true},width=PAD_W,height=pad.height,
        visible=function() return method:get()=="pattern" end,pad.node}},
    message=text {id="lock-message",width=FIELD_W,height=s(24),elide="right",font_size=s(14),
      text=function()
        local value=message:get()
        return busy:get() and value=="" and "Checking password…" or value
      end,
      color=function() return bad:get() and C.error or C.onSurfaceVariant end},
    method_height=chip_h,
    method=ui.Item {
        width = FIELD_W, height = chip_h, visible = has_pattern,
        (function()
          local area
          area = ui.MouseArea {
            id = "lock-method", anchors = { horizontal_center = true, bottom = true },
            width = s(180), height = s(36), cursor = "pointer",
            on_clicked = function()
              method:set(method:get() == "pattern" and "password" or "pattern")
              clear()
              say("")
            end,
            ui.Rect {
              id = "lock-method-surface", anchors = { fill = true }, radius = s(18),
              color = function() return (area and area.hovered) and C.surfaceContainerHighest or C.surfaceContainerHigh end,
            },
            ui.Row {
              anchors = { center_in = true }, gap = s(6), align = "center",
              icon(function() return method:get() == "pattern" and "password" or "pattern" end, s(18), C.onSurfaceVariant),
              text { font_size = s(14), color = C.onSurfaceVariant,
                text = function() return method:get() == "pattern" and "Use password" or "Use pattern" end },
            },
          }
          return area
        end)(),
      },
  }
  local sheet=form.node

  -- ------------------------------------------------------------ the screen --

  -- Touch uses the shared recognizer. Mouse drags and touchpad scrolling
  -- offer the same deliberate reveal on a laptop without a touchscreen.
  local pointer_from_rest=false
  local scroll_distance,scroll_time=0,0
  local reveal=kb.surface {
    id="lock-open",anchors={fill=true},z=-1,on_key_pressed=key,
    on_pressed=function(_,_,_,_,button)
      pointer_from_rest=button=="left" and stage:get()=="rest" and not busy:get()
      if pointer_from_rest then main_output:set(NAME) end
    end,
    on_drag_finished=function(_,_,dx,dy)
      if pointer_from_rest and not busy:get() and dy < -48 and -dy > math.abs(dx)*1.2 then open_sheet() end
      pointer_from_rest=false
      pull:set(0)
    end,
    on_wheel=function(_,_,px,py,sx,sy)
      if stage:get()~="rest" or busy:get() then scroll_distance=0 return end
      px,py=px or 0,py or 0
      if py==0 then px,py=(sx or 0)*40,(sy or 0)*40 end
      if py>=0 or math.abs(py)<=math.abs(px)*1.2 then scroll_distance=0 return end
      local now=morf.time.now_ms()
      if now-scroll_time>400 then scroll_distance=0 end
      scroll_time=now
      scroll_distance=scroll_distance-py
      if scroll_distance>=48 then
        scroll_distance=0 main_output:set(NAME) open_sheet()
      end
    end,
  }
  reveal.on_dragged=function(_,_,dx,dy)
    if pointer_from_rest and stage:get()=="rest" then
      pull:set(math.abs(dy)>math.abs(dx)*1.2 and math.min(1,math.max(0,-dy)/360) or 0)
    end
  end

  -- Opaque from the first frame: a lock that let the desk show through for
  -- a moment would not be a lock, and morf will not hold one that could.
  local root = ui.Rect {
    anchors = { fill = true },
    clip=true,
    color = C.surface:alpha(1),
    kb.content {
      backdrop,
      skin.chrome and skin.chrome(W, H, s, "lock") or ui.Item {},
      frame,band,glance,hint,sheet,
    },
    not kb.embedded and kb.node or ui.Item {}, kb.edge,
    reveal,
  }

  -- contains_pointer includes the password field, keyboard and other children;
  -- hovering a child must not be mistaken for leaving this monitor.
  morf.effect("lock.pointer." .. NAME, function()
    if root.contains_pointer then main_output:set(NAME) end
  end, {owner=root})
  return root

end

end
