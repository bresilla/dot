-- The default kit's skins for every archetype (lib.kit.skin), in the
-- Adwaita manner: grey push buttons that darken under the pointer, a blue
-- pill for the suggested action, flat buttons that show only a wash,
-- switches with a white knob, accent-filled checks and radios, thin
-- slider troughs with a round knob, view switchers with a sliding plate,
-- lists whose chosen row wears the selected wash. The behaviour --
-- pressing, dragging, keys, focus -- is the archetype's.
local morf = require("morf")
local ui = require("morf.ui")

return function(theme, M)
  local S = {}
  local P = theme.P
  local function get(v) if type(v) == "function" then return v() end return v end
  local function clamp01(v) v = tonumber(v) or 0 return v < 0 and 0 or (v > 1 and 1 or v) end
  local function quick() return { duration = theme.duration.small, easing = theme.ease.standard } end
  local function slide() return M.spring(420, 40) end
  local R = theme.radius
  local function wash(kind) return function() local p = P() return p.ink:alpha(p.wash[kind]) end end
  local function label_of(v)
    if type(v) == "table" then return tostring(v.label or v.name or v.text or v.caption or v.title or "") end
    return tostring(v)
  end

  -- The keyboard's ring: 2 px of the accent at 60 %, just inside the edge,
  -- made the first time the control is reached (most never are).
  local function ring(t, radius)
    return function()
      return ui.Rect { anchors = { fill = true }, z = 50, color = "transparent", radius = radius,
        border_width = 2, border_color = function() local p = P() return p.strong and p.focus or p.focus:alpha(0.6) end,
        visible = function() return t.visual_focus end }
    end
  end

  -- ------------------------------------------------------------ presses --

  -- Each press widget's look.
  local LOOK = {
    suggested = "suggested", pill = "pill", fab = "suggested", extended_fab = "suggested",
    destructive = "destructive",
    flat = "flat", text = "flat", close = "flat", copy = "flat", help = "flat", back = "flat", forward = "flat",
    disclosure_button = "flat", row_activation = "flat",
    link = "link", outlined = "outlined", circular = "circular",
    chip_assist = "chip", chip_filter = "chip", chip_input = "chip", chip_suggestion = "chip", tag = "chip",
    tile = "tile", card_action = "tile",
  }

  --- A button: `label`, `icon`, `color`/`ink` (a filled look's), by look.
  local function button(t, spec, look)
    local function h() return (t.height and t.height > 0) and t.height or theme.control_height end
    local rounded = look == "suggested" or look == "pill" or look == "circular" or look == "chip"
    -- A pill given its own colour is filled with it; otherwise it is grey.
    if look == "pill" and spec.color then look = "suggested" end
    local function radius()
      if rounded then return h() / 2 end
      return look == "tile" and R.large or R.small
    end
    local filled = look == "suggested" or look == "destructive"
    local function base()
      local p = P()
      if look == "destructive" then return p.destructive end
      return get(spec.color) or p.accent
    end
    local function ink()
      local p = P()
      if filled then return get(spec.ink) or p.on_accent end
      if look == "link" then return p.accent_ink end
      if look == "chip" and t.checked then return p.accent_ink end
      return get(spec.ink) or p.ink
    end
    local function ground()
      local p = P()
      if filled then
        local c = base()
        if t.down then return c:mix(p.shade, 0.3) end
        if t.hovered then return c:mix(p.on_accent, 0.1) end
        return c
      end
      if look == "link" then return p.ink:alpha(0) end
      if look == "chip" and t.checked then return p.accent:alpha(p.dark and 0.3 or 0.18) end
      local w = p.wash
      if look == "flat" or look == "outlined" or look == "tile" then
        if t.down then return p.ink:alpha(w.active) end
        if t.checked then return p.ink:alpha(w.checked) end
        if t.hovered then return p.ink:alpha(w.hover) end
        if look == "tile" then return p.card end
        return p.ink:alpha(0)
      end
      if t.down then return p.ink:alpha(w.checked + 0.06) end
      if t.checked then return p.ink:alpha(w.checked) end
      if t.hovered then return p.ink:alpha(w.raised_hover) end
      return p.ink:alpha(w.button)
    end
    local function edge()
      local p = P()
      if look == "outlined" then return p.strong and 2 or 1 end
      if look == "tile" then return (p.strong and 2) or (p.dark and 0) or 1 end
      if p.strong and look ~= "link" and look ~= "flat" then return 1 end
      if p.strong and look == "flat" and t.hovered then return 1 end
      return 0
    end
    local fs = look == "chip" and theme.size.small or theme.size.normal
    local weight = (look == "link" or look == "chip" or look == "tile") and 400 or 700
    local glyph = math.max(16, math.min(24, math.floor((tonumber(spec.height) or 34) * 0.45)))
    local content
    if spec.icon and not spec.label then
      content = M.icon(spec.icon, glyph, ink, { anchors = { center_in = true } })
    else
      content=require("lib.kit.caption").make {width=spec.width,height=h,gap=6,left=10,right=10,
        before=spec.icon and {M.icon(spec.icon,16,ink)} or {},
        measure=M.text {text=spec.label or "",font_size=fs,font_weight=weight,opacity=0},
        label_visible=function() local s=get(spec.label) return s~=nil and s~="" end,
        label=function(w)
          return M.text {text=spec.label or "",width=w,font_size=fs,font_weight=weight,color=ink,elide="right",
            decoration=look=="link" and function() return t.hovered and {line="under"} or {} end or nil}
        end}
    end
    return {
      background = ui.Rect { anchors = { fill = true }, radius = radius, color = ground,
        border_width = edge, border_color = function() return P().border end,
        behavior = { color = quick() } },
      content = content,
      indicator = ring(t, radius),
    }
  end

  --- The libadwaita switch: a pill trough, grey off and the accent on, and
  --- a white knob that slides across.
  local function switch(t)
    local TW, TH, K = 46, 26, 22
    local function oy() return math.floor(((t.height and t.height > 0 and t.height or 32) - TH) / 2) end
    local function ox() return math.floor(((t.width and t.width > 0 and t.width or 52) - TW) / 2) end
    return {
      background = ui.Rect { x = ox, y = oy, width = TW, height = TH, radius = TH / 2,
        color = function()
          local p = P()
          if t.checked then return t.hovered and p.accent:mix(p.on_accent, 0.1) or p.accent end
          return p.ink:alpha(t.hovered and p.wash.raised_hover + 0.05 or p.wash.raised_hover)
        end,
        border_width = function() return P().strong and 1 or 0 end,
        border_color = function() return P().border end,
        behavior = { color = quick() } },
      indicator = ui.Rect { width = K, height = K, radius = K / 2,
        y = function() return oy() + (TH - K) / 2 end,
        x = function() return ox() + ((t.checked ~= (t.mirrored == true)) and (TW - K - 2) or 2) end,
        color = function() return P().knob end,
        border_width = 1, border_color = function() local p = P() return p.strong and p.ink or p.shade:alpha(p.dark and 0.5 or 0.35) end,
        behavior = { x = slide() } },
      badge = ring(t, TH / 2),
    }
  end

  --- A check box: a rounded square outlined while off, the accent with a
  --- white tick when checked, a dash when partial.
  local function checkbox(t)
    local function on() return t.checked or t.partial end
    return {
      background = ui.Rect { anchors = { fill = true, margins = 3 }, radius = 5,
        color = function()
          local p = P()
          if on() then return t.hovered and p.accent:mix(p.on_accent, 0.1) or p.accent end
          return t.hovered and p.ink:alpha(p.wash.hover) or p.ink:alpha(0)
        end,
        border_width = function() return on() and 0 or 2 end,
        border_color = function() local p = P() return p.strong and p.ink or p.ink:alpha(0.3) end,
        behavior = { color = quick() } },
      indicator = M.icon(function() return t.partial and "remove" or "check" end, 16,
        function() return P().on_accent end,
        { anchors = { center_in = true }, visible = function() return on() end,
          font_weight = 700 }),
      badge = ring(t, 6),
    }
  end

  --- A radio button: a ring while off, an accent disc with a white dot on.
  local function radio(t)
    return {
      background = ui.Rect { anchors = { fill = true, margins = 3 }, radius = 9,
        color = function()
          local p = P()
          if t.checked then return p.accent end
          return t.hovered and p.ink:alpha(p.wash.hover) or p.ink:alpha(0)
        end,
        border_width = function() return t.checked and 0 or 2 end,
        border_color = function() local p = P() return p.strong and p.ink or p.ink:alpha(0.3) end,
        behavior = { color = quick() } },
      indicator = ui.Rect { anchors = { center_in = true }, width = 8, height = 8, radius = 4,
        color = function() return P().on_accent end, visible = function() return t.checked end },
      badge = ring(t, 12),
    }
  end

  --- A flat round icon button: `icon_on`, `icon_off`, `on` (fn; the error
  --- tone while on), `size` (18).
  local function icon(t, spec)
    local W, H = spec.width or 34, spec.height or 34
    local function on() return spec.on and spec.on() == true end
    local function ink()
      local p = P()
      return on() and p.error_ink or p.ink
    end
    local r = math.min(W, H) / 2
    return {
      background = ui.Rect { width = W, height = H, radius = r,
        color = function()
          local p = P()
          if on() then return p.error:alpha(t.down and 0.3 or (t.hovered and 0.22 or 0.15)) end
          if t.down then return p.ink:alpha(p.wash.active) end
          if t.hovered then return p.ink:alpha(p.wash.hover) end
          return p.ink:alpha(0)
        end,
        border_width = function() local p = P() return (p.strong and (t.hovered or on())) and 1 or 0 end,
        border_color = function() return P().border end,
        behavior = { color = quick() } },
      icon = M.icon(function() return on() and (spec.icon_on or spec.icon_off) or (spec.icon_off or spec.icon) end,
        spec.size or 18, ink, { anchors = { center_in = true }, fill = on }),
      indicator = ring(t, r),
    }
  end

  --- A menu row: its icon and label on a hover wash, a check or a radio
  --- mark at the right.
  local function menu_item(t, spec)
    local left=spec.icon and 38 or 12
    local right=spec.widget=="menu_item" and 12 or 36
    return {
      background = ui.Rect { anchors = { fill = true }, radius = R.small,
        color = function()
          local p = P()
          if t.down then return p.ink:alpha(p.wash.active) end
          return (t.hovered or t.visual_focus) and p.ink:alpha(p.wash.hover) or p.ink:alpha(0)
        end, behavior = { color = quick() } },
      icon = spec.icon and M.icon(spec.icon, 16, function() return P().ink end,
        { x = 12, anchors = { vertical_center = true } }) or nil,
      label = M.text { x = left, anchors = { vertical_center = true }, text = spec.label,
        width=function() return math.max(1e-3,t.width-left-right) end,elide="right",
        font_size = theme.size.normal, color = function() return P().ink end },
      indicator = (spec.widget ~= "menu_item") and M.icon(function()
        if spec.widget == "radio_menu_item" then return t.checked and "radio_button_checked" or "radio_button_unchecked" end
        return "check"
      end, 16, function() return P().ink end, { anchors = { right = true, right_margin = 12, vertical_center = true },
        visible = function() return spec.widget == "radio_menu_item" or t.checked end }) or nil,
    }
  end

  --- A key hint press: a light key on a hairline.
  local function keycap(t, spec)
    return {
      background = ui.Rect { anchors = { fill = true }, radius = R.small,
        color = function() local p = P() return p.ink:alpha(t.down and p.wash.active or (t.hovered and p.wash.raised_hover or p.wash.button)) end,
        border_width = 1, border_color = function() local p = P() return p.strong and p.border or p.ink:alpha(0.12) end },
      label = M.text { anchors = { center_in = true }, text = spec.label or spec.text or "", font_weight = 700,
        font_size = theme.size.small, color = function() return P().ink_dim end },
      indicator = ring(t, R.small),
    }
  end

  --- A rating star: the accent filled when checked.
  local function star(t)
    return {
      icon = M.icon("star", 20, function() local p = P() return t.checked and p.warning or p.ink:alpha(t.hovered and 0.5 or 0.3) end,
        { anchors = { center_in = true }, fill = function() return t.checked end }),
      indicator = ring(t, R.small),
    }
  end

  --- A busy button: grey, with a spinner where its label would be.
  local function loading(t, spec)
    local slots = button(t, spec, "push")
    slots.content = M.loading(16, function() return P().ink end, { anchors = { center_in = true } })
    return slots
  end

  function S.Press(t, spec)
    local widget = spec.widget
    if widget == "menu_item" or widget == "check_menu_item" or widget == "radio_menu_item" then
      return menu_item(t, spec)
    end
    -- A layout's own area draws itself: only the keyboard's ring here.
    if widget == "area" or widget == "segment" then
      return { indicator = ring(t, function() return math.min(R.small, (t.height or 0) / 2) end) }
    end
    if widget == "switch" then return switch(t)
    elseif widget == "icon" then return icon(t, spec)
    elseif widget == "checkbox" then return checkbox(t)
    elseif widget == "radio" then return radio(t)
    elseif widget == "keycap" then return keycap(t, spec)
    elseif widget == "rating_star" then return star(t)
    elseif widget == "loading" then return loading(t, spec)
    end
    return button(t, spec, LOOK[widget] or "push")
  end

  -- -------------------------------------------------------- disclosures --

  --- An expander row: the title, a wash under the pointer and a chevron
  --- that turns as it opens. A layout's own header gets only the ring.
  function S.Disclosure(t, spec)
    if spec.widget == "area" then
      return { indicator = ring(t, function() return math.min(R.small, (t.height or 0) / 2) end) }
    end
    local H = spec.header_height or 44
    return {
      background = ui.Rect { width = function() return t.width end, height = H, radius = R.large,
        color = function()
          local p = P()
          if t.down then return p.ink:alpha(p.wash.active) end
          return t.hovered and p.ink:alpha(p.wash.hover) or p.ink:alpha(0)
        end,
        behavior = { color = quick() } },
      header = M.text { x = 12, y = (H - theme.size.normal * 1.4) / 2, text = spec.title or "",
        font_size = theme.size.normal, color = function() return P().ink end },
      indicator = ui.Item { x = function() return (t.width or 0) - 34 end, y = (H - 20) / 2, width = 20, height = 20,
        rotation = function() return t.expanded and 180 or 0 end,
        behavior = { rotation = M.spring(320, 40) },
        M.icon("expand_more", 20, function() return P().ink_dim end) },
    }
  end

  -- -------------------------------------------------------------- drags --

  --- A pane's separator: a hairline, with a small grip that shows under
  --- the pointer and takes the accent while held.
  function S.Drag(t, spec)
    local across = (spec.axis or "x") == "x"
    local function grip() return t.active or t.hovered end
    return {
      background = ring(t, 3),
      handle = ui.Item { anchors = { fill = true },
        ui.Rect {
          x = function() return across and math.floor((t.width or 0) / 2) or 0 end,
          y = function() return across and 0 or math.floor((t.height or 0) / 2) end,
          width = function() return across and 1 or (t.width or 0) end,
          height = function() return across and (t.height or 0) or 1 end,
          color = function() return P().border end },
        ui.Rect {
          x = function() return ((t.width or 0) - (across and 4 or 28)) / 2 end,
          y = function() return ((t.height or 0) - (across and 28 or 4)) / 2 end,
          width = across and 4 or 28, height = across and 28 or 4, radius = 2,
          opacity = function() return grip() and 1 or 0 end,
          color = function() local p = P() return t.active and p.accent or p.ink:alpha(0.4) end,
          behavior = { opacity = quick(), color = quick() } },
      },
    }
  end

  -- -------------------------------------------------------- navigations --

  --- A page change: the new page slides a little in from its side as it
  --- fades up over the old one, which fades away. Instant with motion off.
  function S.Navigation()
    local latest
    return {
      transition = function(from, to, direction)
        latest = to
        if theme.reduced then
          to.translate_x, to.opacity = 0, 1
          if from and from ~= to then from.visible = false end
          return
        end
        local shift = 24 * (direction or 1)
        to.translate_x, to.opacity = shift, 0
        local steps = { { node = to, property = "translate_x", to = 0, duration = theme.duration.page, easing = "out_cubic" },
          { node = to, property = "opacity", to = 1, duration = 200, easing = "linear" } }
        if from then
          steps[#steps + 1] = { node = from, property = "translate_x", to = -shift, duration = theme.duration.page,
            easing = "out_cubic" }
          steps[#steps + 1] = { node = from, property = "opacity", to = 0, duration = 120, easing = "linear" }
        end
        morf.animation.play { { parallel = steps }, on_finished = function()
          if from and from ~= latest then from.visible, from.translate_x, from.opacity = false, 0, 1 end
        end }
      end,
    }
  end

  -- ------------------------------------------------------------- ranges --

  --- The libadwaita scale: a thin pill trough, the accent up to a white
  --- round knob, an optional icon before it and the reading after it.
  --- `spec`: `width`, `bar_height`, `icon`, `label` (false hides it),
  --- `orientation`.
  local function slider(t, spec)
    local function W() return get(spec.width) or 200 end
    local function H() return get(spec.height) or ((get(spec.bar_height) or 24) + 8) end
    local TR, K = 4, 20
    local vertical = spec.orientation == "vertical" or spec.widget == "vertical_slider" or spec.widget == "fader"
    if vertical then
      local function VW() return get(spec.width) or 30 end
      local function VH() return get(spec.height) or 160 end
      local function travel() return math.max(0,VH()-K) end
      local function hy() return K / 2 + travel() * clamp01(t.visual_position) end
      local function cx() return VW()/2 end
      return {
        track = ui.Item { x = 0, y = K / 2, width = VW, height = travel },
        background = ui.Rect { x = function() return cx()-TR/2 end, y = K / 2, width = TR, height = travel, radius = TR / 2,
          color = function() return P().track end },
        fill = ui.Rect { x = function() return cx()-TR/2 end, width = TR, radius = TR / 2, color = function() return P().accent end,
          y = hy, height = function() return math.max(0, VH() - K / 2 - hy()) end },
        handle = ui.Rect { x = function() return cx()-K/2 end, width = K, height = K, radius = K / 2,
          y = function() return hy() - K / 2 end, color = function() return P().knob end,
          border_width = 1, border_color = function() local p = P() return p.strong and p.ink or p.shade:alpha(0.45) end },
        second_handle = ring(t, R.small),
      }
    end
    local left = spec.icon and 28 or 0
    local right = spec.label ~= false and 44 or 0
    local x0 = left + K / 2
    local function travel() return math.max(1,W()-left-right-K) end
    local function cy() return math.floor(H()/2) end
    local function hx() return x0 + travel() * clamp01(t.visual_position) end
    local slots = {
      track = ui.Item { x = x0, y = 0, width = travel, height = H },
      background = ui.Rect { x = x0 - TR / 2, y = function() return cy()-TR/2 end, width = function() return travel()+TR end, height = TR, radius = TR / 2,
        color = function() return P().track end },
      fill = ui.Rect { id = spec.id and spec.id .. "-level", x = x0 - TR / 2, y = function() return cy()-TR/2 end, height = TR, radius = TR / 2,
        width = function() return math.max(0, hx() - x0 + TR) end,
        color = function() return P().accent end },
      handle = ui.Rect { id = spec.id and spec.id .. "-handle", y = function() return cy()-K/2 end, width = K, height = K, radius = K / 2,
        x = function() return hx() - K / 2 end,
        color = function() local p = P() return t.down and p.knob:mix(p.ink, 0.08) or p.knob end,
        border_width = 1, border_color = function() local p = P() return p.strong and p.ink or p.shade:alpha(p.dark and 0.6 or 0.45) end },
      second_handle = ring(t, R.small),
    }
    if spec.icon then
      slots.ticks = M.icon(spec.icon, 18, function() return P().ink end, { x = 2, y = function() return cy()-11 end })
    end
    if spec.label ~= false then
      slots.value_label = M.text { id = spec.id and spec.id .. "-value", x = function() return W()-40 end, width = 40,
        horizontal_alignment = "right", y = function() return cy()-10 end, height = 20,
        text = function() return ("%d"):format(math.floor(clamp01(t.position) * 100 + 0.5)) end,
        font_size = theme.size.small, color = function() return P().ink_dim end }
    end
    return slots
  end

  --- The media position: a thin trough, the accent played part and a
  --- knob; a drag follows at once, the player's ticks ease over a second.
  local function seek_bar(t, spec)
    local H, TR, K = 34, 4, 14
    local function W() return get(spec.width) or 200 end
    local function at() return clamp01(t.visual_position) end
    local function travel() return math.max(0,W()-K) end
    local function fill_width() return at()*travel()+TR end
    local function handle_x() return at()*travel() end
    local slots = {
      track = ui.Item { x = K / 2, width = travel, height = H },
      background = ui.Rect { x = K / 2 - TR / 2, y = H / 2 - TR / 2, width = function() return travel()+TR end, height = TR, radius = TR / 2,
        color = function() return P().track end },
      fill = ui.Rect { x = K / 2 - TR / 2, y = H / 2 - TR / 2, height = TR, radius = TR / 2,
        width = fill_width(),
        color = function() local p = P() return (get(spec.active) == false) and p.ink_dim or p.accent end },
      handle = ui.Rect { id = "media-progress-handle", y = H / 2 - K / 2, width = K, height = K, radius = K / 2,
        x = handle_x(),
        color = function() return P().knob end,
        border_width = 1, border_color = function() local p = P() return p.strong and p.ink or p.shade:alpha(0.45) end },
      second_handle = ring(t, R.small),
    }
    local running,initial,previous=nil,true,at()
    morf.effect("default.seek."..tostring(slots.handle),function()
      local position=at()
      local direct=initial or theme.reduced or t.down or t.dragging
      local flowing=get(spec.playing)==true and position>previous and position-previous<.03
      local x,width=handle_x(),fill_width()
      if running then running:stop() running=nil end
      if direct then slots.handle.x,slots.fill.width=x,width
      else
        local duration=flowing and 1000 or theme.duration.small
        local easing=flowing and "linear" or theme.ease.standard
        running=morf.animation.play {{parallel={
          {node=slots.handle,property="x",to=x,duration=duration,easing=easing},
          {node=slots.fill,property="width",to=width,duration=duration,easing=easing},
        }}}
      end
      initial,previous=false,position
    end,{owner=slots.handle})
    return slots
  end

  --- An overlay scroll bar: a slim pill the length of the view's share,
  --- wider under the pointer.
  local function scroll_bar(t, spec)
    local vertical=spec.orientation=="vertical"
    local function extent() return math.max(0,vertical and t.height or t.width) end
    local function length() return math.min(extent(),math.max(24,clamp01(get(spec.size) or 1)*extent())) end
    local function thickness() return math.min(vertical and t.width or t.height,(t.hovered or t.down) and 8 or 4) end
    local function offset() return t.visual_position*(extent()-length()) end
    return {
      track = ui.Item { anchors = { fill = true } },
      handle = ui.Rect { anchors = vertical and {right=true} or {bottom=true}, radius = 4,
        width=vertical and thickness or length,height=vertical and length or thickness,
        x=not vertical and offset or nil,y=vertical and offset or nil,
        color = function() local p = P() return p.ink:alpha((t.hovered or t.down) and 0.5 or (p.strong and 0.7 or 0.3)) end,
        behavior = {[vertical and "width" or "height"]=quick()} },
    }
  end

  function S.Range(t, spec)
    if spec.widget == "area" then return { indicator = ring(t, function() return math.min(R.small, (t.height or 0) / 2) end) } end
    if spec.widget == "seek_bar" then return seek_bar(t, spec) end
    if spec.widget == "scroll_bar" then return scroll_bar(t, spec) end
    return slider(t, spec)
  end

  -- -------------------------------------------------------- text fields --

  --- An entry: the grey well when `well` is asked, a 2 px accent ring on
  --- focus (the error tone while what is typed would not be accepted), a
  --- clear or reveal button, and a counter.
  function S.TextField(t, spec, _, send)
    local function bad() return not t.acceptable and not t.empty end
    local slots = {
      error = ui.Rect { anchors = { fill = true }, radius = R.small, color = "transparent", border_width = 2,
        border_color = function()
          local p = P()
          if bad() then return p.error end
          return p.strong and p.accent or p.focus:alpha(0.6)
        end,
        opacity = function() return (t.focused or bad()) and 1 or 0 end,
        behavior = { opacity = quick() } },
    }
    if spec.well then
      slots.background = ui.Rect { anchors = { fill = true }, radius = R.small,
        color = function()
          local p = P()
          return bad() and p.error:alpha(0.12) or p.ink:alpha(p.dark and 0.08 or 0.07)
        end,
        border_width = function() return P().strong and 1 or 0 end,
        border_color = function() return P().border end }
    end
    if spec.clear or spec.reveal then
      local reveal = spec.reveal and spec.echo == "password"
      slots.trailing = require("lib.kit.widgets").icon { width = 26, height = 26, size = 16,
        anchors = { right = true, right_margin = 5, vertical_center = true },
        icon_off = reveal and "visibility" or "close", icon_on = "visibility_off",
        on = function() return reveal and t.revealed end,
        visible = function() return reveal or not t.empty end,
        on_clicked = function() send(reveal and "reveal" or "clear") end }
    end
    if spec.max_length then
      slots.counter = M.text { anchors = { right = true, bottom = true, right_margin = 6, bottom_margin = 3 },
        font_size = theme.size.small - 2,
        color = function() local p = P() return bad() and p.error_ink or p.ink_dim end,
        text = function() return ("%d/%d"):format(t.length, spec.max_length) end }
    end
    return slots
  end

  -- ------------------------------------------------------------ scrolls --

  --- A scrolled view: an overlay scroll bar along its right edge while
  --- there is somewhere to scroll.
  function S.Scroll(t, spec)
    local flick = spec.flick
    local function room() return math.max(0, t.content_height - t.viewport_height) end
    return {
      scroll_bar_y = require("lib.kit.widgets").scroll_bar { width = 10, orientation = "vertical", inverted = true,
        accessible_name = "Scroll position",
        anchors = { right = true, top = true, bottom = true, right_margin = 2, top_margin = 4, bottom_margin = 4 },
        visible = function() return t.bar_y end,
        value = function() return t.position_y end,
        size = function() return t.size_y end,
        handle_size = function() return math.max(24, t.size_y * t.viewport_height) end,
        on_moved = function(v) if flick then flick.content_y = v * room() end end },
    }
  end

  -- --------------------------------------------------------- selections --

  --- The view switcher a tab row is drawn as: each slot an icon over its
  --- label, a wash under the pointer, and a plate of the selected wash
  --- sliding to the chosen tab. `spec` as `kit.tabs` makes it.
  local function tabs(t, spec)
    local id, row_width = spec.tab_id or spec.id, spec.width_of or spec.width
    local list = type(spec.items) == "function" and spec.items() or spec.items
    local PAD, H = spec.pad or 11, spec.height or 64
    local growing = spec.growing == true
    local function width() return get(row_width) or 0 end
    local function slot() return (width() - 2 * PAD) / math.max(1, #list) end
    return {
      indicator = ui.Rect { id = id and id .. "-tab-indicator", radius = R.medium,
        x = function() return t.current_x + 3 end, y = function() return t.current_y + 3 end,
        width = function() return math.max(0, t.current_width - 6) end,
        height = function() return math.max(0, t.current_height - 6) end,
        visible = function() return t.current > 0 end,
        color = wash("selected"),
        border_width = function() return P().strong and 1 or 0 end, border_color = function() return P().border end,
        behavior = { x = slide(), width = slide() } },
      background = ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
        color = function() local p = P() return p.strong and p.border or p.border:alpha(0.6) end },
      container = function()
        if growing then
          return ui.Flex { anchors = { fill = true, bottom_margin = 2 }, direction = "row", padding = 0 }
        end
        return ui.Item { anchors = { fill = true } }
      end,
      place = function(i)
        if growing then return { width = 10, height = H - 4, layout = { grow = 1 } } end
        return { y = 2, height = H - 4, width = slot, x = function() return PAD + (i - 1) * slot() end }
      end,
      item = function(i, entry, s)
        local name = spec.item_id and spec.item_id(i, entry) or ("tab-" .. i)
        local function ink() local p = P() return s.current() and p.ink or p.ink_dim end
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true, margins = 3 }, radius = R.medium,
            color = function()
              local p = P()
              return (s.hovered() and not s.current()) and p.ink:alpha(p.wash.hover) or p.ink:alpha(0)
            end,
            border_width = function() return t.visual_focus and s.current() and 2 or 0 end,
            border_color = function() local p = P() return p.strong and p.focus or p.focus:alpha(0.6) end,
            behavior = { color = quick() } },
          ui.Column { anchors = { horizontal_center = true, vertical_center = true }, gap = 2, align = "center",
            M.centred(26, 24, entry.icon_build and entry.icon_build(s.current, name .. "-icon")
              or M.icon(entry.icon, 20, ink, { id = name .. "-icon" })),
            M.text { text = entry.name, font_size = theme.size.small,
              font_weight = 700, color = ink, behavior = { color = quick() } } },
        }
      end,
    }
  end

  -- Selection widgets drawn as a linked row of buttons on a trough with a
  -- raised plate under the chosen one.
  local LINKED = { segmented = true, inline_view_switcher = true, view_switcher = true, toggle_group = true,
    radio_group = true, pagination = true, rating_items = true }
  -- Those drawn as a list of rows, left-aligned, the chosen one washed.
  local ROWS = { sidebar_list = true, list_selection = true, transfer_side = true }

  local function linked(t, spec)
    local slots = {
      background = ui.Rect { anchors = { fill = true }, radius = R.medium + 2,
        color = function() local p = P() return p.ink:alpha(p.dark and 0.08 or 0.06) end,
        border_width = function() return P().strong and 1 or 0 end, border_color = function() return P().border end },
      item = function(_, value, s)
        local label = label_of(value)
        local glyph = type(value) == "table" and value.icon or nil
        local function ink() local p = P() return s.current() and p.ink or p.ink_dim end
        local node = { anchors = { fill = true },
          ui.Rect { anchors = { fill = true, margins = 3 }, radius = R.small,
            color = function()
              local p = P()
              return (s.hovered() and not s.current()) and p.ink:alpha(p.wash.hover) or p.ink:alpha(0)
            end,
            border_width = function() return t.visual_focus and s.current() and 2 or 0 end,
            border_color = function() local p = P() return p.strong and p.focus or p.focus:alpha(0.6) end },
        }
        if glyph and label == "" then
          node[#node + 1] = M.icon(glyph, 16, ink, { anchors = { center_in = true } })
        else
          node[#node + 1] = M.text { anchors = { fill = true, left_margin = 6, right_margin = 6 }, text = label,
            font_size = theme.size.small, font_weight = 700, color = ink, elide = "right",
            horizontal_alignment = "center", vertical_alignment = "center" }
        end
        return ui.Item(node)
      end,
    }
    if not spec.delegate then
      slots.indicator = ui.Rect { radius = R.small,
        x = function() return t.current_x + 3 end, y = function() return t.current_y + 3 end,
        width = function() return math.max(0, t.current_width - 6) end,
        height = function() return math.max(0, t.current_height - 6) end,
        visible = function() return t.current > 0 end,
        color = function() local p = P() return p.dark and p.ink:alpha(0.16) or p.view end,
        border_width = 1,
        border_color = function() local p = P() return p.strong and p.ink or p.shade:alpha(p.dark and 0 or 0.8) end,
        behavior = { x = slide(), y = slide(), width = slide(), height = slide() } }
    end
    return slots
  end

  local function rows(t, spec)
    local slots = {
      item = function(_, value, s)
        local label = label_of(value)
        local glyph = type(value) == "table" and value.icon or nil
        local function ink() return P().ink end
        local node = { anchors = { fill = true },
          ui.Rect { anchors = { fill = true }, radius = R.small,
            color = function()
              local p = P()
              if spec.delegate == nil and s.current() then return p.ink:alpha(0) end
              return s.hovered() and p.ink:alpha(p.wash.hover) or p.ink:alpha(0)
            end,
            border_width = function() return t.visual_focus and s.current() and 2 or 0 end,
            border_color = function() local p = P() return p.strong and p.focus or p.focus:alpha(0.6) end,
            behavior = { color = quick() } },
        }
        if glyph then
          node[#node + 1] = M.icon(glyph, 16, ink, { x = 10, anchors = { vertical_center = true } })
        end
        node[#node + 1] = M.text { anchors = { fill = true, left_margin = glyph and 36 or 12, right_margin = 8 },
          text = label, font_size = theme.size.normal, color = ink, elide = "right",
          vertical_alignment = "center",
          font_weight = function() return s.current() and 700 or 400 end }
        return ui.Item(node)
      end,
    }
    if not spec.delegate then
      slots.indicator = ui.Rect { radius = R.small,
        x = function() return t.current_x end, y = function() return t.current_y end,
        width = function() return t.current_width end, height = function() return t.current_height end,
        visible = function() return t.current > 0 end,
        color = wash("selected"),
        border_width = function() return P().strong and 1 or 0 end, border_color = function() return P().border end,
        behavior = { x = slide(), y = slide(), width = slide(), height = slide() } }
    end
    return slots
  end

  --- Any other selection (a day grid, swatches, dots): each entry its
  --- label centred, the chosen one an accent disc with white ink.
  local function cells(t, spec)
    return {
      item = function(_, value, s)
        local label = label_of(value)
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { center_in = true },
            width = function() local a = s.area return math.max(0, math.min(a and a.width or 0, a and a.height or 0) - 4) end,
            height = function() local a = s.area return math.max(0, math.min(a and a.width or 0, a and a.height or 0) - 4) end,
            radius = 999,
            color = function()
              local p = P()
              if s.current() then return p.accent end
              return s.hovered() and p.ink:alpha(p.wash.hover) or p.ink:alpha(0)
            end,
            border_width = function() return t.visual_focus and s.current() and 2 or 0 end,
            border_color = function() local p = P() return p.strong and p.ink or p.focus end,
            behavior = { color = quick() } },
          M.text { anchors = { center_in = true }, text = label, font_size = theme.size.small,
            font_weight = function() return s.current() and 700 or 400 end,
            color = function() local p = P() return s.current() and p.on_accent or p.ink end } }
      end,
    }
  end

  function S.Selection(t, spec)
    local widget = spec.widget
    if widget == "tabs" then return tabs(t, spec) end
    if LINKED[widget] then return linked(t, spec) end
    if ROWS[widget] then return rows(t, spec) end
    return cells(t, spec)
  end

  -- -------------------------------------------------------- collections --

  --- A list, table or tree row: a wash under the pointer, the selected
  --- wash on the current row, the label indented by depth with a chevron
  --- for a tree node; a table's header bold and dim.
  S.Collection = {
    row = function(t)
      return function(row, s)
        local function now() return s.row() or row end
        local node = ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true, margins = 1 }, radius = R.small,
            color = function()
              local p = P()
              if s.current() then return p.ink:alpha(p.wash.selected) end
              return s.hovered() and p.ink:alpha(p.wash.hover) or p.ink:alpha(0)
            end,
            border_width = function() return t.visual_focus and s.current() and 2 or 0 end,
            border_color = function() local p = P() return p.strong and p.focus or p.focus:alpha(0.6) end },
          M.icon(function() return s.expanded() and "expand_more" or "chevron_right" end, 16,
            function() return P().ink_dim end,
            { anchors = { vertical_center = true }, x = function() return 8 + s.depth() * 18 end,
              visible = function() return s.expandable() end }),
          M.text { anchors = { vertical_center = true },
            x = function() return 12 + s.depth() * 18 + (s.expandable() and 18 or 0) end,
            width = function() return math.max(0, (s.area and s.area.width or 200) - 20 - s.depth() * 18 - (s.expandable() and 18 or 0)) end,
            elide = "right",
            text = function() local r = now() return tostring(r.label or r.name or r.title or r.key or "") end,
            font_size = theme.size.normal, color = function() return P().ink end },
        }
        return node, function() end
      end
    end,
    cell = function()
      return function(row, column, s)
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true }, color = function()
            local p = P()
            return s.current() and p.ink:alpha(p.wash.selected) or (s.hovered() and p.ink:alpha(p.wash.hover) or p.ink:alpha(0))
          end },
          M.text { anchors = { fill = true, left_margin = 10, right_margin = 6 }, vertical_alignment = "center",
            font_size = theme.size.small, elide = "right",
            text = function() local r = s.row() or row return tostring(r[column.key] or "") end,
            color = function() return P().ink end } }, function() end
      end
    end,
    header = function(t)
      return function(column)
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1, color = function() return P().border end },
          M.text { anchors = { fill = true, left_margin = 10, right_margin = 22 }, vertical_alignment = "center",
            text = column.title or column.key, elide = "right",
            font_size = theme.size.small, font_weight = 700, color = function() return P().ink_dim end },
          M.icon(function() return t.sort_ascending and "arrow_upward" or "arrow_downward" end, 14,
            function() return P().accent_ink end,
            { anchors = { right = true, right_margin = 6, vertical_center = true },
              visible = function() return t.sort_column == column.key end }) }
      end
    end,
  }

  -- ------------------------------------------------------------- popups --

  --- A popup's ground: the raised tone with 12 px corners and a hairline
  --- (a dialog 15 px); a tooltip a dark translucent pill in either scheme.
  function S.Popup(t, spec)
    local widget = spec.widget
    if widget == "tooltip" then
      return { background = ui.Rect { anchors = { fill = true }, radius = R.small,
        color = function() local p = P() return p.strong and p.ink or morf.color("#000000"):alpha(0.82) end } }
    end
    local dialog = widget == "dialog" or widget == "alert_dialog" or widget == "message_dialog"
      or widget == "preferences_dialog" or widget == "about_dialog" or widget == "shortcuts_dialog"
    return {
      dim = ui.Rect { anchors = { fill = true }, color = function() return morf.color("#000000"):alpha(0.3) end },
      background = ui.Rect { anchors = { fill = true }, radius = dialog and R.window or R.large,
        color = function() return P().raised end,
        border_width = function() return P().strong and 2 or 1 end,
        border_color = function() local p = P() return p.strong and p.border or p.shade:alpha(p.dark and 0.9 or 0.6) end },
    }
  end

  -- ------------------------------------------------------------- planes --

  --- A colour plane: saturation across, value down, of `spec.hue()`, with
  --- 6 px corners and a white ring for the handle. Any other plane: a grey
  --- field with the ring.
  function S.Plane(t, spec)
    if spec.widget == "area" then return { indicator = ring(t, function() return math.min(R.small, (t.height or 0) / 2) end) } end
    local W, H = spec.width or 160, spec.height or 160
    local field
    if spec.widget == "colour_plane" then
      local function hue() return morf.color(("hsl(%d, 100%%, 50%%)"):format(math.floor(get(spec.hue) or 0))) end
      field = ui.Item { width = W, height = H,
        ui.Rect { anchors = { fill = true }, radius = R.small,
          gradient = function() return { angle = 90, stops = { "#ffffff", hue() } } end },
        ui.Rect { anchors = { fill = true }, radius = R.small,
          gradient = { angle = 180, stops = { "#00000000", "#000000" } } } }
    else
      field = ui.Rect { width = W, height = H, radius = R.small, color = wash("button"),
        border_width = function() return P().strong and 1 or 0 end, border_color = function() return P().border end }
    end
    return {
      track = ui.Item { width = W, height = H },
      field = field,
      handle = ui.Rect { width = 18, height = 18, radius = 9, color = "transparent", border_width = 3,
        border_color = "#ffffff",
        x = function() return t.visual_x * W - 9 end, y = function() return t.visual_y * H - 9 end },
      crosshair = ring(t, R.small),
    }
  end

  -- ----------------------------------------------------- control, shell --

  --- A bare Control: a card that washes under the pointer.
  function S.Control(t)
    return {
      background = ui.Rect { anchors = { fill = true }, radius = R.large,
        color = function()
          local p = P()
          if t.down then return p.card:mix(p.ink, p.wash.active) end
          if t.hovered then return p.card:mix(p.ink, p.wash.hover) end
          return p.card
        end,
        border_width = function() local p = P() return (p.strong and 2) or (p.dark and 0) or 1 end,
        border_color = function() return P().border end,
        behavior = { color = quick() } },
      content = ring(t, R.large),
    }
  end

  --- An application window: the window's ground; the regions are the
  --- configuration's own.
  function S.Shell()
    return {
      background = ui.Rect { anchors = { fill = true }, color = function() return P().window end },
    }
  end

  -- Canvas and Dock (canvas_dock.lua).
  require("lib.kit.skins.default.canvas_dock")(S, theme, M)

  -- Each archetype's widgets may have looks of their own, in
  -- widgets/<archetype>.lua: a function of (S, theme, M) that adds
  -- S.<widget>. The kit asks a widget's skin before its archetype's, slot
  -- by slot, so a widget's look fills what it draws and the archetype's
  -- skin the rest.
  for _, name in ipairs { "press", "range", "plane", "selection", "popup", "text_field", "scroll", "collection",
    "disclosure", "drag", "navigation", "shell", "canvas", "dock", "transform", "sheet", "roving", "form",
    "overflow" } do
    local ok, looks = pcall(require, "lib.kit.skins.default.widgets." .. name)
    if ok then
      if type(looks) == "function" then looks(S, theme, M) end
    -- (Only its own absence is quiet: an error inside it, or in what it
    -- requires, is raised.)
    elseif not tostring(looks):find("`lib.kit.skins.default.widgets." .. name .. "` is not available", 1, true) then
      error(looks, 0)
    end
  end

  return S
end
