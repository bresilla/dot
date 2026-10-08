-- Material 3's looks for the Press widgets, each the M3 component its name
-- promises: filled, tonal, outlined, text and elevated buttons with stable
-- corners and bounded captions, toggle buttons that square off
-- when selected, connected button groups whose chosen member swells to a
-- pill, 8 px chips, a FAB that morphs (an SDF field) under the finger,
-- Android quick-settings tiles, filled cards and list items with the state
-- layer over every container. Elevation is the tonal surface plus a soft
-- shadow in the scheme's shadow role. Widgets not named here (push, pill,
-- icon, switch, checkbox, radio, menu items) keep the archetype's look
-- (skins.lua). The behaviour is the archetype's.
local morf = require("morf")
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local function get(v) if type(v) == "function" then return v() end return v end
  local function fade() return { duration = theme.duration.small, easing = theme.ease.standard } end
  -- The shape spring: quick, with a touch of overshoot.
  local function bounce() return M.spring(520, 22) end
  local function none() return nil end
  local SLOTS = { "background", "content", "indicator", "icon", "label", "badge" }
  local function full(slots)
    for _, name in ipairs(SLOTS) do if slots[name] == nil then slots[name] = none end end
    return slots
  end
  local function H(t) return (t.height and t.height > 0) and t.height or 40 end
  local function W(t) return (t.width and t.width > 0) and t.width or 40 end
  local function with(kind, props, ...)
    for i = 1, select("#", ...) do
      local child = select(i, ...)
      if child then props[#props + 1] = child end
    end
    return kind(props)
  end

  -- The keyboard's ring: a 2 px secondary outline inside the edge.
  local function ring(t, radius)
    return function()
      return ui.Rect { anchors = { fill = true, margins = 1 }, z = 50, color = "transparent", radius = radius,
        border_width = 2, border_color = function() return C().secondary end,
        visible = function() return t.visual_focus end }
    end
  end

  -- The state layer: the content colour over the container at 8 % under
  -- the pointer and 10 % pressed (M3's hover and pressed opacities).
  local function layer(t, container, ink)
    return function()
      local c, over = get(container), get(ink)
      if c == nil then return over:alpha(t.down and 0.10 or (t.hovered and 0.08 or 0)) end
      if t.down then return c:mix(over, 0.10) end
      if t.hovered then return c:mix(over, 0.08) end
      return c
    end
  end

  -- Elevation levels as a shadow in the scheme's shadow role.
  local LEVEL = { [0] = { 0, 0, 0 }, { 3, 1, 0.22 }, { 6, 2, 0.24 }, { 10, 4, 0.26 } }
  local function shadow(t, rest, hover)
    local function level() return LEVEL[(t.hovered and not t.down) and (hover or rest) or rest] end
    return function() return C().shadow:alpha(level()[3]) end,
      function() return level()[1] end, function() return level()[2] end
  end

  --- The content of a button: a leading icon, the label (Label Large), a
  --- trailing icon; centred.
  local function content(t, spec, ink, o)
    o = o or {}
    local lead=o.lead
    if lead==nil then lead=spec.icon end
    local label = o.label ~= nil and o.label or spec.label
    local gap, glyph = o.gap or 8, o.glyph or 18
    local has_label = label and label ~= ""
    local measure=M.text {text=label or "",font_size=o.size or theme.size.normal,
      font_weight=o.weight or 500,opacity=0}
    local before,after={},{}
    if o.pre then before[#before+1]=o.pre end
    if lead then before[#before+1]=M.icon(lead,glyph,o.lead_ink or ink,{fill=o.lead_fill}) end
    if o.trail then after[#after+1]=M.icon(o.trail,o.trail_size or 18,o.trail_ink or ink) end
    if o.post then after[#after+1]=o.post end
    return require("lib.kit.caption").make {width=spec.width,height=function() return H(t) end,
      gap=gap,measure=measure,before=before,after=after,
      label_visible=function() local s=get(label) return s~=nil and s~="" end,
      label=has_label and function(w)
        return M.text {text=label,width=w,elide="right",font_size=o.size or theme.size.normal,
          font_weight=o.weight or 500,color=ink}
      end or nil}
  end

  --- A button: `container` (fn, nil for none), `ink`, `outline` (fn),
  --- `rest`, `pressed`, `selected` (radius fns of the height), `level`
  --- and `hover_level` (elevation), and what `content` takes.
  local function button(t, spec, o)
    local function ink() return get(o.ink) end
    local rest = o.rest or function(h) return h / 2 end
    local pressed = o.pressed or rest
    local function radius()
      local h = math.min(H(t), W(t))
      if t.down then return pressed(h) end
      if t.checked and o.selected then return o.selected(h) end
      return rest(h)
    end
    local sc, sb, sy
    if o.level then sc, sb, sy = shadow(t, o.level, o.hover_level) end
    return full {
      background = ui.Rect { anchors = { fill = true }, radius = radius,
        color = layer(t, o.container, ink),
        border_width = o.outline and (o.outline_width or 1) or 0,
        border_color = o.outline,
        shadow_color = sc, shadow_blur = sb, shadow_offset_y = sy,
        behavior = { radius = bounce(), color = fade(), shadow_blur = fade(), shadow_offset_y = fade() } },
      content = (o.content == false) and none or (o.content or content(t, spec, ink, o)),
      indicator = ring(t, radius),
    }
  end

  -- ----------------------------------------------------- common buttons --

  --- A push button: the primary container in M3 expressive's square
  --- shape family (the pill is the round one).
  function S.push(t, spec)
    return button(t, spec, { container = function() return get(spec.color) or C().primaryContainer end,
      ink = function() return get(spec.ink) or C().onPrimaryContainer end,
      rest = function(h) return h * 0.3 end,
      selected = function(h) return h * 0.3 end, level = 0, hover_level = 1 })
  end

  --- The filled button (the suggested action): primary, its ink on it.
  function S.suggested(t, spec)
    return button(t, spec, { container = function() return get(spec.color) or C().primary end,
      ink = function() return get(spec.ink) or C().onPrimary end, level = 0, hover_level = 1 })
  end

  --- The destructive action: a filled button in the error role.
  function S.destructive(t, spec)
    return button(t, spec, { container = function() return C().error end,
      ink = function() return C().onError end, level = 0, hover_level = 1 })
  end

  --- A flat button: no container, the surface's ink, the state layer only.
  function S.flat(t, spec)
    return button(t, spec, { ink = function() return get(spec.ink) or C().onSurfaceVariant end })
  end

  --- The text button: no container, the primary as its ink.
  function S.text(t, spec)
    return button(t, spec, { ink = function() return get(spec.ink) or C().primary end })
  end

  --- The tonal button: the secondary container.
  function S.tonal(t, spec)
    return button(t, spec, { container = function() return get(spec.color) or C().secondaryContainer end,
      ink = function() return get(spec.ink) or C().onSecondaryContainer end, level = 0, hover_level = 1 })
  end

  --- The outlined button: an outline, the primary as its ink.
  function S.outlined(t, spec)
    return button(t, spec, { ink = function() return C().primary end,
      outline = function() return t.down and C().primary or C().outline end })
  end

  --- The elevated button: the low container lifted a level, two under
  --- the pointer.
  function S.elevated(t, spec)
    return button(t, spec, { container = function() return C().surfaceContainerLow end,
      ink = function() return C().primary end, level = 1, hover_level = 2 })
  end

  --- A raised button: the highest container on a level of shadow, the
  --- surface's ink -- a filled neutral that stands off the page.
  function S.raised(t, spec)
    return button(t, spec, { container = function() return C().surfaceContainerHighest end,
      ink = function() return C().onSurface end, lead_ink = function() return C().primary end,
      level = 1, hover_level = 3 })
  end

  --- A link: the primary, underlined under the pointer, no container.
  function S.link(t, spec)
    return full {
      background = ui.Rect { anchors = { fill = true }, radius = 8,
        color = function() return C().primary:alpha(t.down and 0.10 or 0) end, behavior = { color = fade() } },
      content = M.text { anchors = { fill = true, left_margin = 4, right_margin = 4 }, text = spec.label or "",
        font_size = theme.size.normal, font_weight = 500, color = function() return C().primary end,
        elide = "right", horizontal_alignment = "center", vertical_alignment = "center",
        decoration = function() return (t.hovered or t.visual_focus) and { line = "under" } or {} end },
      indicator = ring(t, 8),
    }
  end

  -- -------------------------------------------------------- icon buttons --

  -- An icon button: `glyph` (a name or fn), `container`, `ink`, `outline`,
  -- `nudge` (fn: a lean under the pointer), `size`.
  local function icon_button(t, spec, glyph, o)
    local function ink() return get(o.ink) end
    local slots = button(t, spec, { container = o.container, ink = o.ink, outline = o.outline,
      selected = o.selected, pressed = o.pressed, content = false })
    slots.icon = ui.Item { anchors = { center_in = true }, width = 24, height = 24,
      translate_x = o.nudge and function() return t.hovered and o.nudge() or 0 end or nil,
      rotation = o.turn, scale = o.scale,
      behavior = { translate_x = bounce(), rotation = M.spring(420, 18), scale = M.spring(520, 14) },
      M.icon(glyph, o.size or 24, ink, { anchors = { center_in = true }, fill = o.fill }) }
    return slots
  end

  --- The circular icon button: the tonal container, round, squaring off
  --- while pressed.
  function S.circular(t, spec)
    return icon_button(t, spec, spec.icon or "add", { container = function() return C().secondaryContainer end,
      ink = function() return C().onSecondaryContainer end, pressed = function(h) return h * 0.3 end })
  end

  --- A close button: a standard icon button with the cross.
  function S.close(t, spec)
    return icon_button(t, spec, spec.icon or "close", { ink = function() return C().onSurfaceVariant end })
  end

  --- Help: an outlined icon button with the question mark.
  function S.help(t, spec)
    return icon_button(t, spec, "help", { ink = function() return C().onSurfaceVariant end,
      outline = function() return C().outlineVariant end })
  end

  --- Back and forward: standard icon buttons whose arrow leans the way it
  --- goes under the pointer (mirrored right to left).
  local function arrow(way)
    return function(t, spec)
      local function sign() return ((way == "back") ~= (t.mirrored == true)) and -1 or 1 end
      return icon_button(t, spec, function() return sign() < 0 and "arrow_back" or "arrow_forward" end,
        { ink = function() return C().onSurfaceVariant end, nudge = function() return sign() * 3 end })
    end
  end
  S.back = arrow("back")
  S.forward = arrow("forward")

  --- A repeat button: a tonal icon button that, held, fills with the
  --- primary and squares off for as long as it repeats.
  function S.repeat_button(t, spec)
    return icon_button(t, spec, spec.icon or "add", {
      container = function() return t.down and C().primary or C().secondaryContainer end,
      ink = function() return t.down and C().onPrimary or C().onSecondaryContainer end,
      pressed = function(h) return h * 0.22 end })
  end

  --- A disclosure button: a tonal pill with its label and a chevron that
  --- turns over on a spring; open, it is the secondary container, squared.
  function S.disclosure_button(t, spec)
    local function ink() return t.checked and C().onSecondaryContainer or C().onSurfaceVariant end
    local row=content(t,spec,ink,{lead=false,gap=6,post=
      ui.Item { width = 20, height = 20, rotation = function() return t.checked and 180 or 0 end,
        behavior = { rotation = M.spring(420, 18) },
        M.icon("expand_more", 20, ink, { anchors = { center_in = true } }) }})
    return button(t, spec, {
      container = function() return t.checked and C().secondaryContainer or C().surfaceContainerHigh end,
      ink = ink, selected = function(h) return h * 0.3 end, content = row })
  end

  -- -------------------------------------------------- feedback buttons --

  --- Copy: a tonal button whose icon and label turn to a tick and
  --- "Copied" on the primary container for a moment after the press.
  function S.copy(t, spec)
    local copied = morf.signal("caelestia.copy." .. tostring({}), false)
    local function ink() return copied:get() and C().onPrimaryContainer or C().onSecondaryContainer end
    local row=content(t,spec,ink,{lead=false,label=spec.label and function() return copied:get() and "Copied" or get(spec.label) end,
      pre=ui.Item { width = 18, height = 18, scale = function() return copied:get() and 1.15 or 1 end,
        behavior = { scale = M.spring(520, 12) },
        M.icon(function() return copied:get() and "check" or (get(spec.icon) or "content_copy") end, 18, ink,
          { anchors = { center_in = true } }) }})
    local was, timer = false, nil
    morf.effect("caelestia.copy.watch." .. tostring(row), function()
      local down = t.down
      if was and not down and t.hovered then
        copied:set(true)
        if timer then timer:cancel() end
        timer = morf.timer(1400, function() timer = nil copied:set(false) end, false)
      end
      was = down
    end, { owner = row })
    return button(t, spec, {
      container = function() return copied:get() and C().primaryContainer or C().secondaryContainer end,
      ink = ink, content = row })
  end

  --- A busy button: the primary container with M3's loading indicator (a
  --- shape morphing as it turns) before its label.
  function S.loading(t, spec)
    local function ink() return C().onPrimaryContainer end
    local row=content(t,spec,ink,{lead=false,gap=10,pre=M.loading(22,ink)})
    return button(t, spec, { container = function() return C().primaryContainer end, ink = ink, content = row })
  end

  -- ----------------------------------------------------------- toggles --

  --- A toggle button: the surface container, round; selected, the primary
  --- -- and the shape squares off.
  function S.toggle(t, spec)
    return button(t, spec, {
      container = function() return t.checked and C().primary or C().surfaceContainerHigh end,
      ink = function() return t.checked and C().onPrimary or C().onSurfaceVariant end,
      selected = function(h) return h * 0.3 end, pressed = function(h) return h * 0.18 end,
      lead_fill = function() return t.checked end })
  end

  --- A connected button group's member (`position`): outer corners round,
  --- inner ones 8 px and 2 px apart; the chosen one swells to a pill.
  function S.toggle_group_member(t, spec)
    local pos = spec.position
    local outer_l = pos == nil or pos == "first"
    local outer_r = pos == nil or pos == "last"
    local function corner(outer)
      return function()
        local h = H(t)
        if t.down then return h * 0.18 end
        if t.checked or outer then return h / 2 end
        return 8
      end
    end
    local function ink() return t.checked and C().onSecondaryContainer or C().onSurfaceVariant end
    local glyph = spec.icon
    local inner = (glyph and not spec.label)
      and M.icon(glyph, 22, ink, { anchors = { center_in = true }, fill = function() return t.checked end })
      or content(t, spec, ink)
    return full {
      background = ui.Rect { anchors = { fill = true, left_margin = outer_l and 0 or 1, right_margin = outer_r and 0 or 1 },
        top_left_radius = corner(outer_l), bottom_left_radius = corner(outer_l),
        top_right_radius = corner(outer_r), bottom_right_radius = corner(outer_r),
        color = layer(t, function() return t.checked and C().secondaryContainer or C().surfaceContainerHigh end, ink),
        behavior = { top_left_radius = bounce(), bottom_left_radius = bounce(), top_right_radius = bounce(),
          bottom_right_radius = bounce(), color = fade() } },
      content = inner,
      indicator = ring(t, function() return H(t) / 2 end),
    }
  end

  --- A segmented button's segment (`position`): an outline shared with
  --- its neighbours, round at the row's ends; chosen, the secondary
  --- container with a tick that slides in before the label. A layout's own
  --- segment (no label, no icon) gets only the ring.
  function S.segment(t, spec)
    if not spec.label and not spec.icon then
      return { indicator = ring(t, function() return math.min(16, H(t) / 2) end) }
    end
    local pos = spec.position
    local l = (pos == nil or pos == "first") and function() return H(t) / 2 end or 0
    local r = (pos == nil or pos == "last") and function() return H(t) / 2 end or 0
    local function ink() return t.checked and C().onSecondaryContainer or C().onSurface end
    return full {
      background = ui.Rect { anchors = { fill = true, left_margin = (pos == "middle" or pos == "last") and -1 or 0 },
        top_left_radius = l, bottom_left_radius = l, top_right_radius = r, bottom_right_radius = r,
        color = layer(t, function() return t.checked and C().secondaryContainer or C().surface end, ink),
        border_width = 1, border_color = function() return C().outline end,
        behavior = { color = fade() } },
      content=content(t,spec,ink,{lead=false,gap=0,size=theme.size.small,
        pre=ui.Item { height = 18, width = function() return t.checked and 24 or 0.001 end, clip = true,
          opacity = function() return t.checked and 1 or 0 end,
          behavior = { width = bounce(), opacity = fade() },
          M.icon("check", 18, ink) }}),
      indicator = ring(t, function() return H(t) / 2 end),
    }
  end

  --- A rating star: the primary, filled, popping in on a spring when
  --- chosen; an outline in the variant ink otherwise.
  function S.rating_star(t, spec)
    return full {
      background = ui.Rect { anchors = { fill = true, margins = 2 }, radius = function() return H(t) / 2 end,
        color = function() return C().primary:alpha(t.down and 0.12 or (t.hovered and 0.08 or 0)) end,
        behavior = { color = fade() } },
      icon = ui.Item { anchors = { center_in = true }, width = 28, height = 28,
        scale = function() return t.down and 0.8 or (t.checked and 1 or 0.88) end,
        behavior = { scale = M.spring(560, 12) },
        M.icon("star", 26, function() return t.checked and C().primary or C().onSurfaceVariant end,
          { anchors = { center_in = true }, fill = function() return t.checked end }) },
      indicator = ring(t, function() return H(t) / 2 end),
    }
  end

  -- ------------------------------------------------------------- chips --

  -- A chip: 8 px corners (tighter pressed), Label Large.
  local function chip(t, spec, o)
    o.rest = function() return 8 end
    o.pressed = function() return 6 end
    o.size = theme.size.small
    return button(t, spec, o)
  end

  --- An assist chip: an outline, its icon in the primary.
  function S.chip_assist(t, spec)
    return chip(t, spec, { ink = function() return C().onSurface end, lead_ink = function() return C().primary end,
      outline = function() return C().outlineVariant end })
  end

  --- A filter chip: an outline; chosen, the secondary container with a
  --- tick that springs in before the label.
  function S.chip_filter(t, spec)
    local function ink() return t.checked and C().onSecondaryContainer or C().onSurfaceVariant end
    local row=content(t,spec,ink,{lead=false,gap=0,size=theme.size.small,
      pre=ui.Item { height = 18, width = function() return t.checked and 26 or 0.001 end, clip = true,
        opacity = function() return t.checked and 1 or 0 end,
        behavior = { width = bounce(), opacity = fade() },
        M.icon("check", 18, ink) }})
    return chip(t, spec, {
      container = function() return t.checked and C().secondaryContainer or C().surface:alpha(0) end,
      ink = ink, outline = function() return t.checked and C().secondaryContainer or C().outlineVariant end,
      content = row })
  end

  --- An input chip: an avatar disc with its icon, the label and a remove
  --- cross.
  function S.chip_input(t, spec)
    local function ink() return C().onSurfaceVariant end
    local row=content(t,spec,ink,{lead=false,size=theme.size.small,
      pre=spec.icon and ui.Rect { width = 24, height = 24, radius = 12, color = function() return C().primaryContainer end,
        M.icon(spec.icon, 16, function() return C().onPrimaryContainer end, { anchors = { center_in = true } }) } or nil,
      post=M.icon("close",18,ink)})
    return chip(t, spec, { ink = ink, outline = function() return C().outlineVariant end, content = row })
  end

  --- A suggestion chip: an outline and its label in the variant ink.
  function S.chip_suggestion(t, spec)
    return chip(t, spec, { ink = function() return C().onSurfaceVariant end,
      outline = function() return C().outlineVariant end })
  end

  --- A tag: a small label on the tertiary container, a full pill.
  function S.tag(t, spec)
    return button(t, spec, { container = function() return C().tertiaryContainer end,
      ink = function() return C().onTertiaryContainer end, size = theme.size.small, weight = 600, glyph = 16,
      pressed = function(h) return h / 2 end })
  end

  -- --------------------------------------------------- tiles, cards, rows --

  --- A quick-settings tile: a pill of the high container with its icon,
  --- title and state line; on, the primary. Pressed, it squares off.
  function S.tile(t, spec)
    local function ink() return t.checked and C().onPrimary or C().onSurface end
    local function sub() return t.checked and C().onPrimary:alpha(0.8) or C().onSurfaceVariant end
    local function words() return math.max(0, W(t) - 74) end
    return button(t, spec, {
      container = function() return t.checked and C().primary or C().surfaceContainerHigh end,
      ink = ink, rest = function(h) return math.min(h / 2, 32) end, pressed = function() return 16 end,
      content = ui.Row { anchors = { left = true, left_margin = 20, vertical_center = true }, gap = 14, align = "center",
        M.icon(spec.icon or "toggle_on", 24, ink, { fill = function() return t.checked end }),
        with(ui.Column, { gap = 0 },
          M.text { text = spec.label or "", font_size = theme.size.normal, font_weight = 600, color = ink,
            elide = "right", width = words },
          spec.subtitle and M.text { text = spec.subtitle, font_size = theme.size.small, color = sub,
            elide = "right", width = words } or nil) } })
  end

  --- A filled card that acts: the highest container at 12 px, its icon on
  --- a tonal disc, a title and a supporting line, and an arrow that leans
  --- in; lifted a level under the pointer.
  function S.card_action(t, spec)
    local function words() return math.max(0, W(t) - 120) end
    local slots = button(t, spec, {
      container = function() return C().surfaceContainerHighest end, ink = function() return C().onSurface end,
      rest = function() return 12 end, pressed = function() return 20 end, level = 0, hover_level = 1,
      content = with(ui.Row, { anchors = { left = true, left_margin = 16, vertical_center = true }, gap = 14,
          align = "center" },
        spec.icon and ui.Rect { width = 44, height = 44, radius = 22, color = function() return C().secondaryContainer end,
          M.icon(spec.icon, 22, function() return C().onSecondaryContainer end, { anchors = { center_in = true } }) } or nil,
        with(ui.Column, { gap = 2 },
          M.text { text = spec.label or "", font_size = theme.size.normal, font_weight = 600,
            color = function() return C().onSurface end, elide = "right", width = words },
          spec.subtitle and M.text { text = spec.subtitle, font_size = theme.size.small,
            color = function() return C().onSurfaceVariant end, elide = "right", width = words } or nil)) })
    slots.icon = ui.Item { anchors = { right = true, right_margin = 16, vertical_center = true }, width = 24, height = 24,
      translate_x = function() return t.hovered and 4 or 0 end, behavior = { translate_x = bounce() },
      M.icon("arrow_forward", 22, function() return C().primary end, { anchors = { center_in = true } }) }
    return slots
  end

  --- A list item (an expressive segmented list's): the container at
  --- 16 px that rounds right out while pressed, a leading icon, headline
  --- and supporting text, a trailing chevron.
  function S.row_activation(t, spec)
    local left = spec.icon and 52 or 16
    local function words() return math.max(0, W(t) - left - 44) end
    local slots = button(t, spec, {
      container = function() return C().surfaceContainer end, ink = function() return C().onSurface end,
      rest = function() return 16 end, pressed = function(h) return h / 2 end,
      content = with(ui.Column, { x = left, anchors = { vertical_center = true }, gap = 1 },
        M.text { text = spec.label or "", font_size = theme.size.normal, color = function() return C().onSurface end,
          elide = "right", width = words },
        spec.subtitle and M.text { text = spec.subtitle, font_size = theme.size.small,
          color = function() return C().onSurfaceVariant end, elide = "right", width = words } or nil) })
    slots.icon = spec.icon and M.icon(spec.icon, 22, function() return C().onSurfaceVariant end,
      { x = 16, anchors = { vertical_center = true } }) or none
    slots.badge = M.icon("chevron_right", 22, function() return C().onSurfaceVariant end,
      { anchors = { right = true, right_margin = 12, vertical_center = true } })
    return slots
  end

  --- A key: the highest container at 8 px standing on a lip of the
  --- outline variant that it presses down onto, its legend in the mono
  --- face.
  function S.keycap(t, spec)
    local function lip() return t.down and 1 or 3 end
    return full {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, radius = 8, color = function() return C().outlineVariant end },
        ui.Rect { anchors = { left = true, right = true, top = true }, radius = 8,
          height = function() return math.max(0, H(t) - lip()) end,
          translate_y = function() return t.down and 2 or 0 end,
          color = layer(t, function() return C().surfaceContainerHighest end, function() return C().onSurface end),
          behavior = { height = fade(), translate_y = fade(), color = fade() } } },
      label = M.text { anchors = { horizontal_center = true }, y = function() return (H(t) - lip()) / 2 - 10 + (t.down and 2 or 0) end,
        height = 20, vertical_alignment = "center", text = spec.label or spec.text or "",
        font_family = theme.mono, font_size = theme.size.small, font_weight = 600,
        color = function() return C().onSurfaceVariant end, behavior = { y = fade() } },
      indicator = ring(t, 8),
    }
  end

  -- -------------------------------------------------- floating actions --

  --- The FAB: the primary container in M3's rounded square (an SDF field)
  --- that morphs into the nine-lobed cookie under the finger, on three
  --- levels of shadow, four under the pointer.
  function S.fab(t, spec)
    local function ink() return C().onPrimaryContainer end
    local sc, sb, sy = shadow(t, 2, 3)
    return full {
      background = ui.Sdf { anchors = { fill = true },
        shadow_color = sc, shadow_blur = sb, shadow_offset_y = sy,
        behavior = { shadow_blur = fade(), shadow_offset_y = fade() },
        M.sdf_shape { anchors = { fill = true }, shape = function() return t.down and "cookie9" or "square" end,
          duration = 380,
          fill_color = layer(t, function() return C().primaryContainer end, ink) } },
      icon = ui.Item { anchors = { center_in = true }, width = 24, height = 24,
        rotation = function() return t.down and 12 or 0 end, behavior = { rotation = M.spring(420, 14) },
        M.icon(spec.icon or "add", 24, ink, { anchors = { center_in = true } }) },
      indicator = ring(t, 16),
    }
  end

  --- The extended FAB: the primary container at 16 px with its icon and
  --- label, tightening while pressed.
  function S.extended_fab(t, spec)
    return button(t, spec, { container = function() return C().primaryContainer end,
      ink = function() return C().onPrimaryContainer end, glyph = 24, gap = 12,
      rest = function() return 16 end, pressed = function() return 10 end, level = 2, hover_level = 3 })
  end

  --- A FAB menu's item: a secondary-container pill with its icon and
  --- label, squaring off while pressed.
  function S.speed_dial_item(t, spec)
    return button(t, spec, { container = function() return C().secondaryContainer end,
      ink = function() return C().onSecondaryContainer end, glyph = 22, gap = 10,
      pressed = function() return 14 end, level = 1, hover_level = 2 })
  end

  -- ------------------------------------------------------------ holding --

  --- A hold button (a press that counts only once held for `t.hold` ms):
  --- a tonal pill whose corners tighten on the shape spring while it is
  --- held, the error container (`tone = "accent"`: the primary's) sweeping
  --- across it -- one drawing slid along -- and M3's circular indicator
  --- round its icon, a distance-field wedge whose angle runs over the hold.
  --- Let go early, both drain back; held to the end, the icon's disc
  --- morphs into a cookie with a tick on it until it is let go.
  function S.hold_button(t, spec)
    local accent = spec.tone == "accent"
    local function tone() local c = C() return accent and c.primary or c.error end
    local function on_tone() local c = C() return accent and c.onPrimary or c.onError end
    local function container() local c = C() return accent and c.primaryContainer or c.errorContainer end
    local function on_container() local c = C() return accent and c.onPrimaryContainer or c.onErrorContainer end
    local done = morf.signal("caelestia.material.hold." .. tostring({}), false)
    local function radius() local h = H(t) return t.holding and h * 0.3 or h / 2 end
    local sweep = ui.Rect { anchors = { fill = true }, radius = radius, color = container,
      translate_x = function() return -W(t) end, behavior = { radius = bounce() } }
    local fill = ui.SdfShape { shape = "pie", anchors = { fill = true }, operation = "intersect", angle = 0, rotation = 0 }
    local D = 28
    local dial = ui.Item { width = D, height = D,
      ui.Sdf { anchors = { fill = true }, fill_color = function() return C().onSurfaceVariant:alpha(0.22) end,
        ui.SdfShape { shape = "ring", anchors = { fill = true }, thickness = 3 } },
      ui.Sdf { anchors = { fill = true }, fill_color = tone,
        ui.SdfShape { shape = "ring", anchors = { fill = true }, thickness = 3 }, fill },
      ui.Sdf { anchors = { fill = true, margins = 1 }, fill_color = tone,
        opacity = function() return done:get() and 1 or 0 end, behavior = { opacity = fade() },
        M.sdf_shape { anchors = { fill = true }, shape = function() return done:get() and "cookie9" or "circle" end,
          duration = 420 } },
      M.icon(function() return done:get() and "check" or (spec.icon or "delete") end, 18,
        function() return done:get() and on_tone() or C().onSurfaceVariant end,
        { anchors = { center_in = true } }) }
    local running, was, counted, settle_timer = nil, false, false, nil
    local function play(to, duration, easing)
      if running then running:stop() end
      running = morf.animation.play { { parallel = {
        { node = fill, property = "angle", to = 360 * to, duration = duration, easing = easing },
        { node = fill, property = "rotation", to = 180 * to, duration = duration, easing = easing },
        { node = sweep, property = "translate_x", to = (to - 1) * W(t), duration = duration, easing = easing } } },
        on_finished = function() running = nil end }
    end
    morf.effect("caelestia.material.hold.watch." .. tostring(dial), function()
      local holding, down = t.holding, t.down
      if holding and not was then
        if settle_timer then settle_timer:cancel() settle_timer = nil end
        done:set(false)
        play(1, math.max(1, t.hold or 800), "linear")
      elseif was and not holding then
        if down then counted = true done:set(true) else play(0, 300, theme.ease.standard) end
      elseif counted and not down then
        counted = false
        settle_timer = morf.timer(600, function()
          settle_timer = nil
          done:set(false)
          play(0, 360, theme.ease.standard)
        end, false)
      end
      was = holding
    end, { owner = dial })
    local function ink() return done:get() and on_container() or C().onSurface end
    return full {
      background = ui.Rect { anchors = { fill = true }, radius = radius,
        color = layer(t, function() return C().surfaceContainerHighest end, function() return C().onSurface end),
        behavior = { radius = bounce(), color = fade() },
        ui.ClipRect { anchors = { fill = true }, radius = radius, color = "transparent",
          behavior = { radius = bounce() }, sweep } },
      content=content(t,spec,ink,{lead=false,gap=10,pre=dial}),
      indicator = ring(t, function() return radius() end),
    }
  end
end
