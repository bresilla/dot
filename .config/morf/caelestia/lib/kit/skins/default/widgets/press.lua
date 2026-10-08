-- The default kit's looks for the Press widgets, each the libadwaita style
-- class its name promises: a suggested or destructive action filled with
-- its tone at 6 px corners, a raised button with its shade under it, an
-- elevated one on the card tone with a soft shadow, a tonal one tinted with
-- the accent, a close button's grey disc, GNOME quick-settings tiles,
-- boxed-list rows with the go-next chevron, linked segments, a toggle
-- group's plate on its trough. Nothing overshoots: every motion is the
-- critically damped spring or the short ease-out libadwaita moves on.
-- Widgets not named here (push, flat, outlined, pill, circular, icon,
-- link, toggle, switch, checkbox, radio, menu items, keycap, rating star)
-- keep the archetype's look (skins.lua). The behaviour is the archetype's.
local morf = require("morf")
local ui = require("morf.ui")

return function(S, theme, M)
  local P = theme.P
  local R = theme.radius
  local function get(v) if type(v) == "function" then return v() end return v end
  local function quick() return { duration = theme.duration.small, easing = theme.ease.standard } end
  local function slide() return M.spring(420, 40) end
  -- A slot left empty without the archetype's skin filling it.
  local function none() return nil end
  local SLOTS = { "background", "content", "indicator", "icon", "label", "badge" }
  local function full(slots)
    for _, name in ipairs(SLOTS) do if slots[name] == nil then slots[name] = none end end
    return slots
  end
  local function H(t) return (t.height and t.height > 0) and t.height or theme.control_height end
  local function W(t) return (t.width and t.width > 0) and t.width or theme.control_height end
  local function dim(t) return function() return t.enabled == false and 0.5 or 1 end end
  -- A node of `kind` with `props` and the children given, nils skipped.
  local function with(kind, props, ...)
    for i = 1, select("#", ...) do
      local child = select(i, ...)
      if child then props[#props + 1] = child end
    end
    return kind(props)
  end

  -- The keyboard's ring: 2 px of the focus tone just inside the edge.
  local function ring(t, radius)
    return function()
      return ui.Rect { anchors = { fill = true }, z = 50, color = "transparent", radius = radius,
        border_width = 2, border_color = function() local p = P() return p.strong and p.focus or p.focus:alpha(0.6) end,
        visible = function() return t.visual_focus end }
    end
  end

  -- A state layer over a ground: the ink at the palette's wash for the state.
  local function layered(base, t, ink)
    return function()
      local p = P()
      local c = get(base)
      local over = get(ink) or p.ink
      if t.down then return c:mix(over, p.wash.active) end
      if t.hovered then return c:mix(over, p.wash.hover) end
      return c
    end
  end

  --- The content of a button: a leading icon, the label, a trailing icon,
  --- centred (or from the start with `start`).
  local function content(t,spec, ink, o)
    o = o or {}
    local size = o.size or theme.size.normal
    local weight = o.weight or 700
    local lead=o.lead
    if lead==nil then lead=spec.icon end
    local label = o.label ~= nil and o.label or spec.label
    local before,after={},{}
    if o.pre then before[#before+1]=o.pre end
    if lead then before[#before+1]=M.icon(lead,o.glyph or 18,o.lead_ink or ink,{fill=o.lead_fill}) end
    if o.trail then after[#after+1]=M.icon(o.trail,o.trail_size or 16,o.trail_ink or ink) end
    if o.post then after[#after+1]=o.post end
    return require("lib.kit.caption").make {width=spec.width,height=function() return H(t) end,
      gap=o.gap or 6,left=o.start,align=o.start and "start" or nil,
      before=before,after=after,measure=M.text {text=label or "",font_size=size,font_weight=weight,opacity=0},
      label_visible=function() local s=get(label) return s~=nil and s~="" end,
      label=label and label~="" and function(w)
        return M.text {text=label,width=w,elide="right",font_size=size,font_weight=weight,color=ink}
      end or nil}
  end

  --- A button: `ground` (fn of the palette), `ink`, `radius`, `border`
  --- (width fn), `edge` (its colour), `shadow` ({ blur, y, alpha }), and
  --- what `content` takes.
  local function button(t, spec, o)
    local radius = o.radius or R.small
    local function ink() return get(o.ink) end
    return full {
      background = ui.Rect { anchors = { fill = true }, color = o.ground,
        radius = not o.corners and radius or nil,
        top_left_radius = o.corners and o.corners[1] or nil, bottom_left_radius = o.corners and o.corners[1] or nil,
        top_right_radius = o.corners and o.corners[2] or nil, bottom_right_radius = o.corners and o.corners[2] or nil,
        opacity = dim(t),
        border_width = o.border or function() return P().strong and 1 or 0 end,
        border_color = o.edge or function() return P().border end,
        shadow_color = o.shadow and function()
          local p = P()
          local a = o.shadow.alpha or 0.35
          return p.shade:alpha((t.hovered and not t.down) and math.min(1, a * 1.4) or a)
        end or nil,
        shadow_blur = o.shadow and function() return (t.hovered and not t.down) and o.shadow.blur * 1.5 or o.shadow.blur end or nil,
        shadow_offset_y = o.shadow and function() return t.down and 0 or o.shadow.y end or nil,
        behavior = { color = quick(), shadow_blur = quick(), shadow_offset_y = quick() } },
      content = (o.content == false) and none or (o.content or content(t,spec, ink, o)),
      indicator = ring(t, radius),
    }
  end

  -- Washes over nothing: a flat thing's ground.
  local function flat_ground(t)
    return function()
      local p = P()
      if t.down then return p.ink:alpha(p.wash.active) end
      if t.checked then return p.ink:alpha(p.wash.checked) end
      if t.hovered then return p.ink:alpha(p.wash.hover) end
      return p.ink:alpha(0)
    end
  end

  -- -------------------------------------------------------- actions --

  --- .suggested-action: the accent at 6 px corners, white ink.
  function S.suggested(t, spec)
    return button(t, spec, {
      ground = layered(function() return get(spec.color) or P().accent end, t, function() return P().on_accent end),
      ink = function() return get(spec.ink) or P().on_accent end,
    })
  end

  --- .destructive-action: the destructive red, white ink.
  function S.destructive(t, spec)
    return button(t, spec, {
      ground = layered(function() return P().destructive end, t, function() return P().on_accent end),
      ink = function() return P().on_accent end,
    })
  end

  --- .raised: the grey button standing on its shade -- a hairline under it
  --- that it sinks onto when pressed.
  function S.raised(t, spec)
    return button(t, spec, {
      ground = function()
        local p = P()
        if t.down then return p.ink:alpha(p.wash.checked + 0.06) end
        if t.checked then return p.ink:alpha(p.wash.checked) end
        return p.ink:alpha(t.hovered and p.wash.raised_hover or p.wash.button)
      end,
      ink = function() return P().ink end,
      border = function() return 1 end,
      edge = function() local p = P() return p.strong and p.border or p.shade:alpha(p.dark and 0.9 or 0.7) end,
      shadow = { blur = 2, y = 1, alpha = 0.45 },
    })
  end

  --- A text button: no ground until the pointer, the accent's ink.
  function S.text(t, spec)
    return button(t, spec, { ground = flat_ground(t), ink = function() return P().accent_ink end,
      border = function() local p = P() return (p.strong and t.hovered) and 1 or 0 end })
  end

  --- A tonal button: the accent as a tint, its ink in the accent.
  function S.tonal(t, spec)
    return button(t, spec, {
      ground = function()
        local p = P()
        local a = p.dark and 0.22 or 0.14
        if t.down then a = a + 0.12 elseif t.hovered then a = a + 0.06 end
        return p.accent:alpha(a)
      end,
      ink = function() return P().accent_ink end,
    })
  end

  --- An elevated button: the card tone lifted on a soft shadow that grows
  --- under the pointer and settles when pressed.
  function S.elevated(t, spec)
    return button(t, spec, {
      radius = R.medium,
      ground = layered(function() return P().card end, t),
      ink = function() return P().ink end,
      border = function() local p = P() return (p.strong or not p.dark) and 1 or 0 end,
      edge = function() local p = P() return p.strong and p.border or p.shade:alpha(0.5) end,
      shadow = { blur = 8, y = 2, alpha = 0.4 },
    })
  end

  -- ------------------------------------------------------ icon actions --

  --- The window's close button: a grey disc with the cross, darker under
  --- the pointer.
  function S.close(t, spec)
    local function d() return math.max(22, math.min(W(t), H(t)) - 14) end
    return full {
      background = ui.Rect { anchors = { center_in = true }, width = d, height = d,
        radius = function() return d() / 2 end, opacity = dim(t),
        color = function()
          local p = P()
          if t.down then return p.ink:alpha(p.wash.checked + 0.06) end
          return p.ink:alpha(t.hovered and p.wash.raised_hover or p.wash.button)
        end,
        border_width = function() return P().strong and 1 or 0 end, border_color = function() return P().border end,
        behavior = { color = quick() } },
      icon = M.icon(spec.icon or "close", 16, function() return P().ink end,
        { anchors = { center_in = true }, font_weight = 700 }),
      indicator = ring(t, function() return math.min(W(t), H(t)) / 2 end),
    }
  end

  -- A flat image button: `glyph` (a name or fn), its ring and wash.
  local function image_button(t, spec, glyph, o)
    o = o or {}
    local radius = o.round and function() return math.min(W(t), H(t)) / 2 end or R.small
    return full {
      background = ui.Rect { anchors = { fill = true }, radius = radius, color = o.ground or flat_ground(t),
        opacity = dim(t),
        border_width = o.border or function() local p = P() return (p.strong and t.hovered) and 1 or 0 end,
        border_color = o.edge or function() return P().border end,
        behavior = { color = quick() } },
      icon = ui.Item { anchors = { center_in = true }, width = 24, height = 24,
        translate_x = o.nudge and function() return t.hovered and o.nudge() or 0 end or nil,
        rotation = o.turn, behavior = { translate_x = quick(), rotation = slide() },
        M.icon(glyph, o.size or 18, o.ink or function() return P().ink end,
          { anchors = { center_in = true }, font_weight = o.weight }) },
      indicator = ring(t, radius),
    }
  end

  --- Back and forward: go-previous and go-next, flat, the arrow leaning
  --- the way it goes under the pointer (mirrored right to left).
  local function arrow(way)
    return function(t, spec)
      local function sign() return ((way == "back") ~= (t.mirrored == true)) and -1 or 1 end
      return image_button(t, spec, function() return sign() < 0 and "chevron_left" or "chevron_right" end,
        { size = 24, nudge = function() return sign() * 2 end })
    end
  end
  S.back = arrow("back")
  S.forward = arrow("forward")

  --- Help: a flat round button with the question mark in a hairline ring.
  function S.help(t, spec)
    return image_button(t, spec, "question_mark", { round = true, size = 18, weight = 700,
      border = function() return 1 end,
      edge = function() local p = P() return p.strong and p.border or p.ink:alpha(t.hovered and 0.3 or 0.18) end })
  end

  --- A repeat button: grey like a push button; held, it takes the accent
  --- tint, for as long as it keeps repeating.
  function S.repeat_button(t, spec)
    local glyph = spec.icon
    local o = {
      ground = function()
        local p = P()
        if t.down then return p.accent:alpha(p.dark and 0.35 or 0.22) end
        return p.ink:alpha(t.hovered and p.wash.raised_hover or p.wash.button)
      end,
      ink = function() return t.down and P().accent_ink or P().ink end,
      glyph = 18,
    }
    if glyph and not spec.label then o.content = false end
    local slots = button(t, spec, o)
    if glyph and not spec.label then
      slots.content = M.icon(glyph, 18, function() return t.down and P().accent_ink or P().ink end,
        { anchors = { center_in = true }, font_weight = 700 })
    end
    return slots
  end

  --- A disclosure button: flat, its label and a chevron that turns over
  --- while open.
  function S.disclosure_button(t, spec)
    local function ink() return P().ink end
    local row=content(t,spec,ink,{lead=false,post=ui.Item { width = 18, height = 18, rotation = function() return t.checked and 180 or 0 end,
      behavior = { rotation = slide() },
      M.icon("expand_more", 18, function() return P().ink_dim end, { anchors = { center_in = true } }) }})
    return button(t, spec, { ground = function()
      local p = P()
      if t.down then return p.ink:alpha(p.wash.active) end
      return p.ink:alpha(t.hovered and p.wash.hover or 0)
    end, ink = ink, content = row })
  end

  --- Copy: a flat button whose icon and label turn to a tick and "Copied"
  --- for a moment after the press.
  function S.copy(t, spec)
    local copied = morf.signal("kit.default.copy." .. tostring({}), false)
    local function ink() return copied:get() and P().success_ink or P().ink end
    local row=content(t,spec,ink,{glyph=16,
      lead=function() return copied:get() and "check" or (get(spec.icon) or "content_copy") end,
      label=spec.label and function() return copied:get() and "Copied" or get(spec.label) end})
    local was, timer = false, nil
    morf.effect("kit.default.copy.watch." .. tostring(row), function()
      local down = t.down
      if was and not down and t.hovered then
        copied:set(true)
        if timer then timer:cancel() end
        timer = morf.timer(1400, function() timer = nil copied:set(false) end, false)
      end
      was = down
    end, { owner = row })
    return button(t, spec, { ground = flat_ground(t), ink = ink, content = row,
      border = function() local p = P() return (p.strong and t.hovered) and 1 or 0 end })
  end

  --- A busy button: grey, the spinner before its label.
  function S.loading(t, spec)
    local function ink() return P().ink end
    local row=content(t,spec,ink,{lead=false,gap=8,pre=M.loading(16,function() return P().ink_dim end)})
    return button(t, spec, { ground = function() local p = P() return p.ink:alpha(p.wash.button) end, ink = ink,
      content = row })
  end

  -- ------------------------------------------------------------- chips --

  -- A chip: a pill in the small type; `o` as `button`'s.
  local function chip(t, spec, o)
    o.radius = function() return H(t) / 2 end
    o.size = theme.size.small
    o.weight = o.weight or 400
    return button(t, spec, o)
  end

  --- An assist chip: grey, its icon in the accent.
  function S.chip_assist(t, spec)
    return chip(t, spec, {
      ground = function() local p = P() return p.ink:alpha(t.down and p.wash.active + 0.04 or (t.hovered and p.wash.raised_hover or p.wash.button)) end,
      ink = function() return P().ink end, lead_ink = function() return P().accent_ink end })
  end

  --- A filter chip: grey; chosen, the accent tint with a tick before it.
  function S.chip_filter(t, spec)
    local slots = chip(t, spec, {
      ground = function()
        local p = P()
        if t.checked then return p.accent:alpha((p.dark and 0.3 or 0.18) + (t.hovered and 0.06 or 0)) end
        return p.ink:alpha(t.down and p.wash.active + 0.04 or (t.hovered and p.wash.raised_hover or p.wash.button))
      end,
      ink = function() return t.checked and P().accent_ink or P().ink end,
      border = function() local p = P() return (p.strong or t.checked) and 1 or 0 end,
      edge = function() local p = P() return t.checked and p.accent:alpha(p.strong and 1 or 0.4) or p.border end,
      content = false,
    })
    local function ink() return t.checked and P().accent_ink or P().ink end
    slots.content=content(t,spec,ink,{lead=false,gap=0,size=theme.size.small,
      pre=ui.Item { height = 16, width = function() return t.checked and 22 or 0.001 end, clip = true,
        opacity = function() return t.checked and 1 or 0 end,
        behavior = { width = slide(), opacity = quick() },
        M.icon("check", 16, ink, { font_weight = 700 }) }})
    return slots
  end

  --- An input chip: its icon, its label and a small round remove cross.
  function S.chip_input(t, spec)
    local slots = chip(t, spec, {
      ground = function() local p = P() return p.ink:alpha(t.hovered and p.wash.raised_hover or p.wash.button) end,
      ink = function() return P().ink end, content = false })
    slots.content=content(t,spec,function() return P().ink end,{glyph=16,size=theme.size.small,
      lead_ink=function() return P().ink_dim end,post=ui.Rect { width = 18, height = 18, radius = 9,
        color = function() local p = P() return p.ink:alpha(t.down and 0.3 or (t.hovered and 0.2 or 0.12)) end,
        behavior = { color = quick() },
        M.icon("close", 14, function() return P().ink end, { anchors = { center_in = true }, font_weight = 700 }) }})
    return slots
  end

  --- A suggestion chip: an outline only, the ground showing under the
  --- pointer.
  function S.chip_suggestion(t, spec)
    return chip(t, spec, { ground = flat_ground(t), ink = function() return P().ink end,
      border = function() return P().strong and 2 or 1 end,
      edge = function() local p = P() return p.strong and p.border or p.ink:alpha(0.22) end })
  end

  --- A tag: a small bold label on the accent tint at 6 px corners.
  function S.tag(t, spec)
    return button(t, spec, {
      ground = function() local p = P() return p.accent:alpha((p.dark and 0.25 or 0.15) + (t.hovered and 0.05 or 0)) end,
      ink = function() return P().accent_ink end, size = theme.size.small, glyph = 14,
    })
  end

  -- ------------------------------------------------------ tiles, rows --

  --- A GNOME quick-settings tile: a pill with its icon, title and state
  --- line; the accent while on.
  function S.tile(t, spec)
    local function on() return t.checked end
    local function ink() local p = P() return on() and p.on_accent or p.ink end
    local function sub() local p = P() return on() and p.on_accent:alpha(0.8) or p.ink_dim end
    local function radius() return math.min(H(t) / 2, R.large * 2) end
    local text = ui.Column { gap = 0,
      M.text { text = spec.label or "", font_weight = 700, color = ink, elide = "right",
        width = function() return math.max(0, W(t) - 70) end },
      spec.subtitle and M.text { text = spec.subtitle, font_size = theme.size.small, color = sub, elide = "right",
        width = function() return math.max(0, W(t) - 70) end } or nil }
    return full {
      background = ui.Rect { anchors = { fill = true }, radius = radius, opacity = dim(t),
        color = function()
          local p = P()
          local c = on() and p.accent or p.ink:alpha(p.wash.button)
          if t.down then return on() and c:mix(p.shade, 0.25) or p.ink:alpha(p.wash.checked) end
          if t.hovered then return on() and c:mix(p.on_accent, 0.1) or p.ink:alpha(p.wash.raised_hover) end
          return c
        end,
        border_width = function() return P().strong and 1 or 0 end, border_color = function() return P().border end,
        behavior = { color = quick() } },
      content = ui.Row { anchors = { left = true, left_margin = 18, vertical_center = true }, gap = 14, align = "center",
        M.icon(spec.icon or "toggle_on", 22, ink), text },
      indicator = ring(t, radius),
    }
  end

  --- An activatable card (AdwActionRow in a boxed list of one): the card
  --- tone, its icon on an accent-tinted disc, a title and a dim line, and
  --- the go-next chevron that leans in under the pointer.
  function S.card_action(t, spec)
    local function ink() return P().ink end
    local function words() return math.max(0, W(t) - 112) end
    return full {
      background = ui.Rect { anchors = { fill = true }, radius = R.large, opacity = dim(t),
        color = layered(function() return P().card end, t),
        border_width = function() local p = P() return (p.strong and 2) or (p.dark and 0) or 1 end,
        border_color = function() return P().border end,
        shadow_color = function() local p = P() return p.dark and p.shade:alpha(0) or p.shade:alpha(0.35) end,
        shadow_blur = 4, shadow_offset_y = 1,
        behavior = { color = quick() } },
      content = with(ui.Row, { anchors = { left = true, left_margin = 16, vertical_center = true }, gap = 14, align = "center" },
        spec.icon and ui.Rect { width = 40, height = 40, radius = 20,
          color = function() local p = P() return p.accent:alpha(p.dark and 0.25 or 0.14) end,
          M.icon(spec.icon, 20, function() return P().accent_ink end, { anchors = { center_in = true } }) } or nil,
        ui.Column { gap = 1,
          M.text { text = spec.label or "", font_weight = 700, color = ink, elide = "right", width = words },
          spec.subtitle and M.text { text = spec.subtitle, font_size = theme.size.small,
            color = function() return P().ink_dim end, elide = "right", width = words } or nil }),
      icon = ui.Item { anchors = { right = true, right_margin = 14, vertical_center = true }, width = 20, height = 20,
        translate_x = function() return t.hovered and 3 or 0 end, behavior = { translate_x = quick() },
        M.icon("chevron_right", 20, function() return P().ink_dim end, { anchors = { center_in = true } }) },
      indicator = ring(t, R.large),
    }
  end

  --- An activatable row of a boxed list: no ground until the pointer, its
  --- icon, title and subtitle from the start, the go-next chevron at the
  --- end and the list's hairline under it.
  function S.row_activation(t, spec)
    local function ink() return P().ink end
    local left = spec.icon and 48 or 14
    local function words() return math.max(0, W(t) - left - 40) end
    return full {
      background = ui.Item { anchors = { fill = true }, opacity = dim(t),
        ui.Rect { anchors = { fill = true }, radius = R.small, color = flat_ground(t), behavior = { color = quick() } },
        ui.Rect { anchors = { left = true, right = true, bottom = true, left_margin = left }, height = 1,
          color = function() local p = P() return p.strong and p.border or p.border:alpha(0.8) end } },
      icon = spec.icon and M.icon(spec.icon, 20, function() return P().ink end,
        { x = 14, anchors = { vertical_center = true } }) or none,
      content = ui.Column { x = left, anchors = { vertical_center = true }, gap = 1,
        M.text { text = spec.label or "", color = ink, elide = "right", width = words },
        spec.subtitle and M.text { text = spec.subtitle, font_size = theme.size.small,
          color = function() return P().ink_dim end, elide = "right", width = words } or nil },
      badge = M.icon("chevron_right", 18, function() return P().ink_dim end,
        { anchors = { right = true, right_margin = 10, vertical_center = true } }),
      indicator = ring(t, R.small),
    }
  end

  -- ------------------------------------------------------------ groups --

  -- Corners for a member of a linked row: `position` "first", "middle",
  -- "last" or nil (alone).
  local function corners(spec, r)
    local pos = spec.position
    local left = (pos == nil or pos == "first") and r or 0
    local right = (pos == nil or pos == "last") and r or 0
    return left, right
  end

  --- A segment of a linked row (`position`): grey buttons joined edge to
  --- edge with a hairline between, the chosen one darker. A layout's own
  --- segment (no label, no icon) gets only the ring.
  function S.segment(t, spec)
    if not spec.label and not spec.icon then
      return { indicator = ring(t, function() return math.min(R.small, H(t) / 2) end) }
    end
    local l, r = corners(spec, R.small)
    local slots = button(t, spec, {
      ground = function()
        local p = P()
        if t.checked then return p.ink:alpha(p.wash.checked + (t.down and 0.06 or 0)) end
        if t.down then return p.ink:alpha(p.wash.active + 0.04) end
        return p.ink:alpha(t.hovered and p.wash.raised_hover or p.wash.button)
      end,
      ink = function() return P().ink end, size = theme.size.normal, corners = { l, r },
    })
    if spec.position == "middle" or spec.position == "last" then
      slots.badge = ui.Rect { width = 1, anchors = { left = true, top = true, bottom = true, top_margin = 6, bottom_margin = 6 },
        color = function() local p = P() return p.strong and p.border or p.ink:alpha(0.12) end }
    end
    return slots
  end

  --- A toggle group's member (AdwToggleGroup): the group's trough, and in
  --- it a raised plate under the chosen member that fades and settles in.
  function S.toggle_group_member(t, spec)
    local l, r = corners(spec, R.medium)
    local function ink() local p = P() return t.checked and p.ink or p.ink_dim end
    local glyph = spec.icon
    local inner = (glyph and not spec.label) and M.icon(glyph, 18, ink, { anchors = { center_in = true } })
      or content(t,spec, ink, { size = theme.size.normal })
    return full {
      background = ui.Item { anchors = { fill = true }, opacity = dim(t),
        ui.Rect { anchors = { fill = true },
          top_left_radius = l, bottom_left_radius = l, top_right_radius = r, bottom_right_radius = r,
          color = function() local p = P() return p.ink:alpha(p.dark and 0.08 or 0.06) end,
          border_width = function() return P().strong and 1 or 0 end, border_color = function() return P().border end },
        ui.Rect { anchors = { fill = true, margins = 3 }, radius = R.small,
          color = function() local p = P() return (t.hovered and not t.checked) and p.ink:alpha(p.wash.hover) or p.ink:alpha(0) end,
          behavior = { color = quick() } },
        ui.Rect { anchors = { fill = true, margins = 3 }, radius = R.small,
          opacity = function() return t.checked and 1 or 0 end,
          scale = function() return t.checked and 1 or 0.92 end,
          color = function() local p = P() return p.dark and p.ink:alpha(0.16) or p.view end,
          border_width = 1,
          border_color = function() local p = P() return p.strong and p.ink or p.shade:alpha(p.dark and 0 or 0.8) end,
          shadow_color = function() local p = P() return p.shade:alpha(p.dark and 0.6 or 0.5) end,
          shadow_blur = 3, shadow_offset_y = 1,
          behavior = { opacity = quick(), scale = slide() } } },
      content = inner,
      indicator = ring(t, R.small),
    }
  end

  -- ------------------------------------------------- floating actions --

  --- A floating action button: an accent disc on a soft shadow (an OSD
  --- round button), its icon in white.
  function S.fab(t, spec)
    local function r() return math.min(W(t), H(t)) / 2 end
    local slots = button(t, spec, {
      radius = r,
      ground = layered(function() return get(spec.color) or P().accent end, t, function() return P().on_accent end),
      ink = function() return P().on_accent end,
      shadow = { blur = 10, y = 3, alpha = 0.5 }, content = false,
    })
    slots.content = M.icon(spec.icon or "add", 24, function() return P().on_accent end, { anchors = { center_in = true } })
    return slots
  end

  --- An extended floating action button: the accent pill with its icon
  --- and label, on the same shadow.
  function S.extended_fab(t, spec)
    return button(t, spec, {
      radius = function() return H(t) / 2 end,
      ground = layered(function() return get(spec.color) or P().accent end, t, function() return P().on_accent end),
      ink = function() return P().on_accent end, glyph = 20, gap = 10,
      shadow = { blur = 10, y = 3, alpha = 0.5 },
    })
  end

  --- A speed dial's action: its label on a card-toned pill at the start,
  --- its icon on a raised round button at the end.
  function S.speed_dial_item(t, spec)
    local function d() return math.min(H(t), 48) - 4 end
    return full {
      background = ui.Rect { anchors = { right = true, vertical_center = true }, width = d, height = d,
        radius = function() return d() / 2 end, opacity = dim(t),
        color = layered(function() return P().raised end, t),
        border_width = function() local p = P() return (p.strong or not p.dark) and 1 or 0 end,
        border_color = function() local p = P() return p.strong and p.border or p.shade:alpha(0.5) end,
        shadow_color = function() return P().shade:alpha(0.45) end, shadow_blur = 6, shadow_offset_y = 2,
        behavior = { color = quick() } },
      icon = ui.Item { anchors = { right = true, vertical_center = true }, width = d, height = d,
        M.icon(spec.icon or "add", 20, function() return P().ink end, { anchors = { center_in = true } }) },
      label = spec.label and ui.Rect { x = 0, anchors = { vertical_center = true }, height = 28, radius = 14,
        width = function() return math.max(0, W(t) - d() - 10) end,
        color = function() local p = P() return p.dark and p.raised or p.ink:alpha(0.82) end,
        M.text { anchors = { center_in = true }, text = spec.label, font_size = theme.size.small, font_weight = 700,
          color = function() local p = P() return p.dark and p.ink or p.view end } } or none,
      indicator = ring(t, function() return H(t) / 2 end),
    }
  end

  -- ------------------------------------------------------------ holding --

  --- A hold button (a press that counts only once held for `t.hold` ms):
  --- the grey button, a ring round its icon that fills clockwise while it
  --- is held -- one distance-field wedge whose angle runs over the hold --
  --- and the destructive tint (`tone = "accent"`: the accent's) sweeping
  --- across the ground with it, one drawing slid along. Let go early, both
  --- drain back; held to the end, the icon turns to a tick until it is let
  --- go. From the keyboard it acts at once, as the archetype says.
  function S.hold_button(t, spec)
    local function tone() local p = P() return spec.tone == "accent" and p.accent or p.destructive end
    local function tone_ink() local p = P() return spec.tone == "accent" and p.accent_ink or p.error_ink end
    local done = morf.signal("kit.default.hold." .. tostring({}), false)
    local sweep = ui.Rect { anchors = { fill = true }, radius = R.small,
      translate_x = function() return -W(t) end,
      color = function() local p = P() return tone():alpha(p.strong and 0.4 or (p.dark and 0.32 or 0.2)) end }
    local fill = ui.SdfShape { shape = "pie", anchors = { fill = true }, operation = "intersect", angle = 0, rotation = 0 }
    local D = 26
    local dial = ui.Item { width = D, height = D,
      ui.Sdf { anchors = { fill = true }, fill_color = function() local p = P() return p.ink:alpha(p.strong and 0.5 or 0.16) end,
        ui.SdfShape { shape = "ring", anchors = { fill = true }, thickness = 3 } },
      ui.Sdf { anchors = { fill = true }, fill_color = tone,
        ui.SdfShape { shape = "ring", anchors = { fill = true }, thickness = 3 }, fill },
      ui.Item { anchors = { center_in = true }, width = 18, height = 18,
        scale = function() return done:get() and 1.15 or 1 end, behavior = { scale = M.spring(520, 18) },
        M.icon(function() return done:get() and "check" or (spec.icon or "delete") end, 16,
          function() return done:get() and tone_ink() or P().ink end, { anchors = { center_in = true }, font_weight = 700 }) } }
    local running, was, counted, settle_timer = nil, false, false, nil
    local function play(to, duration, easing)
      if running then running:stop() end
      running = morf.animation.play { { parallel = {
        { node = fill, property = "angle", to = 360 * to, duration = duration, easing = easing },
        { node = fill, property = "rotation", to = 180 * to, duration = duration, easing = easing },
        { node = sweep, property = "translate_x", to = (to - 1) * W(t), duration = duration, easing = easing } } },
        on_finished = function() running = nil end }
    end
    morf.effect("kit.default.hold.watch." .. tostring(dial), function()
      local holding, down = t.holding, t.down
      if holding and not was then
        if settle_timer then settle_timer:cancel() settle_timer = nil end
        done:set(false)
        play(1, math.max(1, t.hold or 800), "linear")
      elseif was and not holding then
        if down then counted = true done:set(true) else play(0, 260, "out_cubic") end
      elseif counted and not down then
        counted = false
        -- Let go after it counted: the tick stays a moment, then all drains.
        settle_timer = morf.timer(500, function()
          settle_timer = nil
          done:set(false)
          play(0, 320, "out_cubic")
        end, false)
      end
      was = holding
    end, { owner = dial })
    local function ink() return P().ink end
    return full {
      background = ui.Rect { anchors = { fill = true }, radius = R.small, opacity = dim(t),
        color = function()
          local p = P()
          if t.down then return p.ink:alpha(p.wash.checked) end
          return p.ink:alpha(t.hovered and p.wash.raised_hover or p.wash.button)
        end,
        border_width = function() return P().strong and 1 or 0 end, border_color = function() return P().border end,
        behavior = { color = quick() },
        ui.ClipRect { anchors = { fill = true }, radius = R.small, color = "transparent", sweep } },
      content=content(t,spec,ink,{lead=false,gap=8,pre=dial}),
      indicator = ring(t, R.small),
    }
  end
end
