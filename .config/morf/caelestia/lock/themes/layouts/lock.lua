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
local WALLPAPER = ctx.WALLPAPER
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
  local PORTRAIT = H > W
  local SHORT = geometry.short
  -- The on-screen keyboard: on a phone, or wherever no keyboard is attached.
  local ONSCREEN = PORTRAIT or not ctx.keyboard_attached()

  local SW = geometry.sheet_width
  local AV = geometry.avatar
  local FIELD_W, FIELD_H = geometry.field_width, geometry.field_height

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
  local kb
  if ONSCREEN then
    kb = osk.new {
      action = skin.action,
      prefix = "lock.osk." .. NAME, width = SW - s(24), mode = "full", numbers = true,
      metrics = {gap=s(5), key_height=s(54), alternate_cell=s(48)},
      active = function() return main() and stage:get() == "sheet" and method:get() == "password" and not busy:get() end,
      look = (skin.keyboard_look or function(v) return v end) {
        panel = function() return C.surfaceContainer end,
        key = function() return C.surfaceContainerHighest end,
        key_dim = function() return C.surfaceContainerHigh end,
        accent = function() return C.primary end,
        on_accent = function() return C.onPrimary end,
        text = function() return C.onSurface end,
        dim = function() return C.onSurfaceVariant end,
        press = function() return C.secondaryContainer end,
        font = FONT, icons = ICONS, radius = skin.key_radius,
      },
      send = function(event)
        if event.text then type_text(event.text)
        elseif event.key == "backspace" then backspace()
        elseif event.key == "enter" then submit()
        elseif event.key == "escape" then escape() end
      end,
    }
  end
  local function kb_h() return (kb and method:get() == "password") and (kb.height() + s(16)) or 0 end
  -- The sheet: the account, the pill, a line for what PAM says; the keyboard
  -- under them on a phone.
  local function content_h()
    return s(28) + AV + s(12) + s(30) + s(20) + entry_h() + s(10) + s(24) + chip_h() + s(24) + kb_h()
  end
  local function sheet_h() return math.min(content_h(), math.max(1,H-2*BORDER-s(16))) end

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
      shape = "box", x = 0, y = 0, width = W, height = H,
      fill_color = function() return C.surface end,
    },
    -- The opening in the frame: shut while the lock comes in and goes.
    ui.SdfShape {
      shape = "box", operation = "subtract", radius = ROUND,
      x = function() return stage:get() == "closed" and 0 or BORDER end,
      y = function() return stage:get() == "closed" and 0 or BORDER end,
      width = function() return stage:get() == "closed" and W or W - 2 * BORDER end,
      height = function() return stage:get() == "closed" and H or H - 2 * BORDER end,
      behavior = { x = SETTLE, y = SETTLE, width = SETTLE, height = SETTLE },
    },
  }

  -- The swell has a field of its own, in a band along the bottom edge: the
  -- frame above stays still, and a swell growing redraws the band alone,
  -- not the whole screen every frame (a 4K screen of field was the lag).
  local function band_h() return math.min(H, sheet_h() + s(90)) end
  local band = ui.Item {
    x = 0, width = W,
    y = function() return H - band_h() end,
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

  -- The desk under it: the wallpaper, blurred and dimmed.
  local backdrop = skin.backdrop and skin.backdrop(W,H,s,"lock") or ui.Item {
    anchors = { fill = true },
    opacity = function() return (stage:get() == "rest" or stage:get() == "sheet") and 1 or 0 end,
    behavior = { opacity = { duration = 420, easing = "out_cubic" } },
    ui.Rect { anchors = { fill = true }, color = function() return C.surface end },
    WALLPAPER ~= "" and ui.Image {
      anchors = { fill = true }, fill_mode = "preserve_aspect_crop", source = WALLPAPER,
    } or ui.Item {},
    ui.Rect {
      anchors = { fill = true }, backdrop_blur = s(28),
      -- One tint, whatever the stage: a tint that changed with the sheet
      -- repainted every screen, blur and all.
      color = function() return C.surface:alpha(skin.wallpaper_tint or 0.4) end,
    },
  }

  -- ------------------------------------------------------------ at rest --

  local function with(base, extra)
    for k, v in pairs(extra) do base[k] = v end
    return base
  end
  local function resting() return stage:get() == "rest" or stage:get() == "sheet" end

  -- The weather, beside the date, where it can be had.
  local weather = {}
  do
    if desktop.weather_available() then
      local now_w = desktop.weather
      weather = {
        icon(desktop.weather_symbol, s(26),
          function() return C.onSurfaceVariant end,
          { visible = function() return now_w().temperature ~= nil end }),
        text {
          font_size = s(22), color = function() return C.onSurfaceVariant end,
          visible = function() return now_w().temperature ~= nil end,
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
    width = math.max(1,W-s(64)),
    anchors = { horizontal_center = true }, gap = s(6), align = "center",
    y = function()
      if stage:get() == "sheet" and main() then
        return math.max(s(40), math.floor((H - BORDER - sheet_h()) / 2 - geometry.clock_sheet_offset))
      end
      return CLOCK_Y
    end,
    scale = function() return (stage:get() == "sheet" and main()) and 0.72 or 1 end,
    opacity = function()
      return resting() and (not main() or stage:get() ~= "sheet" or H - sheet_h() > s(220)) and 1 or 0
    end,
    behavior = { y = GROW, scale = GROW, opacity = { duration = 320 } },
    (skin.clock or text) {
      id = "lock-clock", text = function() return clock:get() end,
      font_size = geometry.clock_size, font_weight = skin.clock_weight or 600, color = C.primary,
    },
    ui.Row((function()
      local row = { gap = s(10), align = "center",
        text { text = function() return day:get() end, width=math.max(1,W-s(160)),elide="right",horizontal_alignment="center",font_size = s(22), color = C.onSurfaceVariant } }
      for _, node in ipairs(weather) do row[#row + 1] = node end
      return row
    end)()),
    ui.Item { width = 1, height = s(34) },
    media_row or ui.Item { width = 1, height = 1 },
  }

  -- Where the way in is: a chevron bobbing over the bud, and what to do.
  local hint = ui.Column {
    anchors = { horizontal_center = true },
    y = H - BORDER - BUD_H - s(74), gap = s(2), align = "center",
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
        .. (ONSCREEN and (FINGER and "swipe up" or "Swipe up") or (FINGER and "type" or "Type or click"))
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
      anchors = { center_in = true }, text = me.initial or "?", font_size = s(42), font_weight = 600,
      color = C.onPrimaryContainer,
    },
  }

  -- The password: a pill, a dot for each character, each popping in.
  local DOT = math.min(s(12), math.max(1, math.floor((FIELD_W-s(120))/MAX_DOTS*.65)))
  local dots = {}
  for i = 1, MAX_DOTS do
    dots[i] = ui.Rect {
      width = DOT, height = DOT, radius = DOT / 2,
      color = function() return C.primary end,
      visible = function() return typed:get() >= i end,
      scale = function() return typed:get() >= i and 1 or 0 end,
      behavior = { scale = { duration = 260, easing = "out_back" } },
    }
  end
  local field = ui.Item {
    id = "lock-field",
    width = FIELD_W, height = FIELD_H,
    translate_x = function() return shake:get() == 1 and s(12) or 0 end,
    behavior = { translate_x = ui.spring { stiffness = 900, damping = 9 } },
    ui.Rect {
      id = "lock-field-surface", anchors = { fill = true }, radius = FIELD_H / 2,
      color = function() return C.surfaceContainerHighest end,
      border_width = function() return bad:get() and s(2) or 0 end,
      border_color = function() return C.error end,
    },
    icon(function() return busy:get() and "hourglass" or "lock" end, s(22), C.onSurfaceVariant,
      { x = s(20), anchors = { vertical_center = true } }),
    text {
      anchors = { vertical_center = true }, x = s(56),
      text = "Password", color = C.onSurfaceVariant, font_size = s(16),
      visible = function() return typed:get() == 0 end,
    },
    ui.Row { x = s(56), anchors = { vertical_center = true }, gap = DOT*.45, table.unpack(dots) },
    ui.MouseArea {
      id = "lock-submit",
      anchors = { right = true, right_margin = s(7), vertical_center = true },
      width = FIELD_H - s(14), height = FIELD_H - s(14), cursor = "pointer",
      on_clicked = submit,
      ui.Rect {
        id = "lock-submit-surface", anchors = { fill = true }, radius = (FIELD_H - s(14)) / 2,
        color = function() return typed:get() > 0 and C.primary or C.surfaceContainerHigh end,
        behavior = { color = { duration = 200 } },
      },
      icon("arrow_forward", s(22), function() return typed:get() > 0 and C.onPrimary or C.onSurfaceVariant end,
        { anchors = { center_in = true } }),
    },
  }

  local sheet_nodes = {
    x = s(12), y = s(28), width = SW - s(24), gap = 0, align = "center",
    avatar,
    ui.Item { width = 1, height = s(12) },
    (ctx.heading or text) { id="lock-name", width=SW-s(48),elide="right",horizontal_alignment="center",active=function() return main() and stage:get()=="sheet" end, text = me.label ~= "" and me.label or me.name, font_size = s(20), font_weight = 600, height = s(30) },
    ui.Item { width = 1, height = s(20) },
    ui.Item {
      width = SW - s(24), height = entry_h,
      ui.Item { anchors = { horizontal_center = true }, width = FIELD_W, height = FIELD_H,
        visible = function() return method:get() == "password" end, field },
      ui.Item { anchors = { horizontal_center = true }, width = PAD_W, height = pad.height,
        visible = function() return method:get() == "pattern" end, pad.node },
    },
    ui.Item { width = 1, height = s(10) },
    text {
      id = "lock-message", height = s(24), width = SW - s(48), horizontal_alignment = "center", elide = "right",
      text = function() return message:get() end, font_size = s(15),
      color = function() return bad:get() and C.error or C.onSurfaceVariant end,
    },
    ui.Item {
      width = SW - s(24), height = chip_h, visible = has_pattern,
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
    ui.Item { width = 1, height = s(24) },
  }
  if kb then
    sheet_nodes[#sheet_nodes + 1] = ui.Item {
      width = SW - s(24),
      height = function() return method:get() == "password" and kb.height() or 0 end,
      visible = function() return method:get() == "password" end,
      kb.node,
    }
  end
  local viewport_node, viewport, viewport_t, viewport_ctl = require("lib.kit.scroll").make("scroll_view", {id="lock-sheet-scroll",width=SW,height=sheet_h,clip=true,
    ui.Column(sheet_nodes)})
  morf.effect("lock.sheet-scroll."..NAME,function()
    local st=stage:get()
    if st~="sheet" then viewport.content_y=0 return end
    local entry_bottom=s(28)+AV+s(12)+s(30)+s(20)+entry_h()+s(10)+s(24)
    local entry_top=s(28)+AV+s(12)+s(30)+s(20)
    viewport.content_y=math.min(entry_top,math.max(0,entry_bottom-sheet_h()+s(12)))
  end,{owner=viewport})
  local sheet = ui.Item {
    id = "lock-sheet",
    x = math.floor((W - SW) / 2), width = SW,
    y = function() return H - BORDER - sheet_h() end,
    height = sheet_h,
    opacity = function() return stage:get() == "sheet" and 1 or 0 end,
    translate_y = function() return stage:get() == "sheet" and 0 or s(60) end,
    behavior = skin.sheet_motion or { opacity = { duration = 260, delay = 120 },
      translate_y = GROW },
    visible = function() return main() and (stage:get() == "sheet" or stage:get() == "opening") end,
    viewport_node,
  }

  if skin.sheet then skin.sheet(sheet, {role="lock", width=SW, scale=s,
    active=function() return main() and stage:get()=="sheet" end}) end

  -- ------------------------------------------------------------ the screen --

  -- Opaque from the first frame: a lock that let the desk show through for
  -- a moment would not be a lock, and morf will not hold one that could.
  local root = ui.Rect {
    anchors = { fill = true },
    clip=true,
    color = C.surface:alpha(1),
    backdrop,
    skin.chrome and skin.chrome(W, H, s, "lock") or ui.Item {},
    frame,
    band,
    glance,
    hint,
    sheet,
    -- Under everything that can be clicked: a click or a swipe up opens the
    -- sheet, and the keys go where they belong.
    ui.MouseArea {
      id = "lock-open",
      anchors = { fill = true }, z = -1,
      on_clicked = function() main_output:set(NAME) open_sheet() end,
      on_dragged = function(_, _, _, dy)
        main_output:set(NAME)
        if stage:get() ~= "rest" then return end
        pull:set(math.max(0, math.min(1, -dy / s(360))))
      end,
      on_drag_finished = function()
        if stage:get() ~= "rest" then return end
        if pull:get() > 0.3 then open_sheet() else pull:set(0) end
      end,
      on_key_pressed = key,
    },
  }

  -- contains_pointer includes the password field, keyboard and other children;
  -- hovering a child must not be mistaken for leaving this monitor.
  morf.effect("lock.pointer." .. NAME, function()
    if root.contains_pointer then main_output:set(NAME) end
  end, {owner=root})
  return root

end

end
