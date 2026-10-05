-- Material's looks for each Navigation widget (Material 3 motion): a
-- navigation view's shared-axis X, a settings subpage's shared-axis Z (the
-- new page grows in as the old swells and fades), a view stack's fade
-- through, tab pages that slide side by side, a carousel whose old slide
-- shrinks back on the spatial curve, an onboarding page on the Y axis, a
-- wizard's longer X steps, a detail pane's container grow. With `chrome =
-- true` in its spec the widget also draws its furniture over its pages:
-- a small top app bar with a back icon button, primary tabs, page dots
-- with a running pill, linear progress segments, a step count. A
-- composite that draws its own leaves `chrome` out. The page's name is
-- `spec.titles[name]`, or the name itself.
local morf = require("morf")
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local function quick() return { duration = theme.duration.small, easing = theme.ease.standard } end
  local spring = M.spring(380, 26)
  local function names_of(spec)
    local out = {}
    for _, name in ipairs(type(spec.pages) == "table" and spec.pages or {}) do
      if type(name) == "string" then out[#out + 1] = name end
    end
    return out
  end
  local function index_of(t, spec)
    for i, name in ipairs(names_of(spec)) do if name == t.current then return i end end
    return 0
  end
  local function title_of(spec, name)
    local text = (spec.titles or {})[name] or tostring(name or "")
    return (text:gsub("^%l", string.upper))
  end
  local function weight(w, size)
    size = size or theme.size.normal
    return { opsz = size * 3 / 4, ROND = 25, wght = w }
  end

  -- -------------------------------------------------------- transitions --

  --- A transition: `to` comes in from `in_x` widths along the direction
  --- (or `in_px`), `in_y` px, `in_scale`, fading in after `delay`; `from`
  --- leaves to the `out_*` values, fading out first (Material's fade
  --- through puts the outgoing fade before the incoming one).
  local function mover(t, spec, o)
    local latest
    return function(from, to, direction)
      latest = to
      direction = direction or 1
      local W = spec.width or to.layout_width or t.width or 400
      local function reset(node) node.translate_x, node.translate_y, node.opacity, node.scale = 0, 0, 1, 1 end
      if not from then reset(to) return end
      local d, ease = o.duration or 400, o.easing or theme.ease.emphasized_decel
      local in_x = (o.in_px or (W * (o.in_x or 0))) * direction
      local out_x = (o.out_px or (W * (o.out_x or 0))) * direction
      to.translate_x, to.translate_y, to.scale, to.opacity = in_x, o.in_y or 0, o.in_scale or 1, o.in_opacity or 0
      local steps = {
        { node = to, property = "translate_x", to = 0, duration = d, easing = ease },
        { node = to, property = "translate_y", to = 0, duration = d, easing = ease },
        { node = to, property = "scale", to = 1, duration = d, easing = ease },
        { node = to, property = "opacity", to = 1, duration = o.fade_in or 210, easing = "linear", delay = o.delay or 90 },
        { node = from, property = "translate_x", to = -out_x, duration = d, easing = ease },
        { node = from, property = "translate_y", to = o.out_y or 0, duration = d, easing = ease },
        { node = from, property = "scale", to = o.out_scale or 1, duration = d, easing = ease },
        { node = from, property = "opacity", to = o.out_opacity or 0, duration = o.fade_out or 90, easing = "linear" },
      }
      morf.animation.play { { parallel = steps }, on_finished = function()
        if from ~= latest then from.visible = false reset(from) end
      end }
    end
  end

  -- ------------------------------------------------------------ chrome --

  local function ground()
    return ui.Rect { anchors = { fill = true }, radius = 24, color = function() return C().surfaceContainerLow end }
  end

  --- An M3 icon button (40 px state layer round a 24 px icon).
  local function icon_button(icon, x, y, on_clicked, show, name)
    local area
    area = ui.MouseArea { x = x, y = y, width = 40, height = 40, cursor = "pointer",
      accessible_role = "button", accessible_name = name, on_clicked = on_clicked,
      visible = show, opacity = function() return (not show or show()) and 1 or 0 end, behavior = { opacity = quick() },
      ui.Rect { anchors = { fill = true }, radius = 20,
        color = function() return C().onSurface:alpha(area and area.hovered and 0.08 or 0) end },
      M.icon(icon, 22, function() return C().onSurface end, { anchors = { center_in = true } }) }
    return area
  end

  --- A small top app bar: the back icon button while there is somewhere
  --- to go back, the title beside it (sliding over as the button comes).
  local function app_bar(t, spec, send, opts)
    opts = opts or {}
    local H = opts.height or 48
    local size = opts.size or theme.size.larger
    return ui.Item { width = function() return t.width end, height = H,
      ui.Rect { anchors = { fill = true }, top_left_radius = 24, top_right_radius = 24,
        color = function() return C().surfaceContainer end },
      icon_button("arrow_back", 4, (H - 40) / 2, function() send("pop") end, function() return t.can_go_back end, "Back"),
      ui.Item { y = (H - size * 1.4) / 2, height = H, x = function() return t.can_go_back and 52 or 18 end,
        behavior = { x = spring },
        M.text { text = function() return title_of(spec, t.current) end, font_size = size, axes = weight(500, size),
          color = function() return C().onSurface end } } }
  end

  -- ------------------------------------------------------------ widgets --

  function S.navigation_view(t, spec, _, send)
    return {
      transition = mover(t, spec, { in_px = 30, out_px = 30, duration = 450 }),
      background = spec.chrome and ground() or nil,
      page = spec.chrome and app_bar(t, spec, send) or nil,
    }
  end

  function S.settings_subpages(t, spec, _, send)
    return {
      transition = mover(t, spec, { in_scale = 0.8, out_scale = 1.1, duration = 400, fade_in = 210, fade_out = 90 }),
      background = spec.chrome and ground() or nil,
      page = spec.chrome and app_bar(t, spec, send, { size = theme.size.large }) or nil,
    }
  end

  function S.view_stack(t, spec)
    return {
      transition = mover(t, spec, { in_scale = 0.92, duration = 300, fade_in = 210, fade_out = 90 }),
      background = spec.chrome and ground() or nil,
    }
  end

  --- Primary tabs: the names across, a rounded primary indicator that
  --- stretches over to the chosen one; the pages slide side by side.
  function S.tab_pages(t, spec, _, send)
    local slots = { transition = mover(t, spec, { in_x = 1, out_x = 1, out_opacity = 1, in_opacity = 1, duration = 450,
      delay = 0, fade_in = 1 }) }
    if not spec.chrome then return slots end
    local names = names_of(spec)
    local function slot() return (t.width or 0) / math.max(1, #names) end
    local bar = ui.Item { width = function() return t.width end, height = 48,
      ui.Rect { anchors = { fill = true }, top_left_radius = 24, top_right_radius = 24,
        color = function() return C().surfaceContainer end },
      ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1, color = function() return C().outlineVariant end } }
    for i, name in ipairs(names) do
      ui.reparent(ui.MouseArea { x = function() return (i - 1) * slot() end, width = slot, height = 46, cursor = "pointer",
        accessible_role = "tab", accessible_name = title_of(spec, name), on_clicked = function() send("go", name) end,
        M.text { anchors = { center_in = true }, text = title_of(spec, name), axes = weight(500),
          color = function() return t.current == name and C().primary or C().onSurfaceVariant end,
          behavior = { color = quick() } } }, bar)
    end
    local W = 64
    local indicator = ui.Item { y = 45, height = 3, width = W,
      x = function() return (math.max(1, index_of(t, spec)) - 0.5) * slot() - W / 2 end,
      behavior = { x = spring }, stretch = M.STRETCH }
    ui.reparent(indicator, bar)
    ui.reparent(ui.Sdf { anchors = { fill = true },
      ui.SdfShape { shape = "box", top_left_radius = 3, top_right_radius = 3, track = indicator,
        fill_color = function() return C().primary end } }, bar)
    slots.background = ground()
    slots.indicator = bar
    return slots
  end

  --- A carousel: the new slide comes on the spatial curve while the old
  --- one shrinks back; page dots, a primary pill running to the current
  --- one; icon buttons beside them.
  function S.carousel(t, spec, _, send)
    local slots = { transition = mover(t, spec, { in_x = 1, out_x = 0.4, out_scale = 0.86, in_opacity = 1, delay = 0,
      fade_in = 1, fade_out = 300, duration = 500, easing = theme.ease.spatial }) }
    if not spec.chrome then return slots end
    local names = names_of(spec)
    local DOT, GAP = 8, 10
    local function row_x() return ((t.width or 0) - (#names * DOT + (#names - 1) * GAP)) / 2 end
    local dots = ui.Item { anchors = { left = true, right = true, bottom = true }, height = 40 }
    for i, name in ipairs(names) do
      ui.reparent(ui.MouseArea { x = function() return row_x() + (i - 1) * (DOT + GAP) - 4 end, y = 12, width = DOT + 8,
        height = 16, cursor = "pointer", accessible_name = title_of(spec, name), on_clicked = function() send("go", name) end,
        ui.Rect { x = 4, y = 4, width = DOT, height = DOT, radius = DOT / 2,
          color = function() return C().onSurfaceVariant:alpha(0.38) end } }, dots)
    end
    local pill = ui.Item { y = 16, height = DOT, width = 22,
      x = function() return row_x() + (math.max(1, index_of(t, spec)) - 1) * (DOT + GAP) - 7 end,
      behavior = { x = spring }, stretch = M.STRETCH }
    ui.reparent(pill, dots)
    ui.reparent(ui.Sdf { anchors = { fill = true },
      ui.SdfShape { shape = "box", radius = DOT / 2, track = pill, fill_color = function() return C().primary end } }, dots)
    ui.reparent(icon_button("chevron_left", 4, 0, function() send("previous") end,
      function() return index_of(t, spec) > 1 end, "Previous"), dots)
    local right = icon_button("chevron_right", 0, 0, function() send("next") end,
      function() return index_of(t, spec) < #names end, "Next")
    right.x = function() return (t.width or 0) - 44 end
    ui.reparent(right, dots)
    slots.background = ground()
    slots.indicator = dots
    return slots
  end

  --- Onboarding: pages on the Y axis; rounded progress segments along
  --- the top, each filling with the primary up to the current page.
  function S.onboarding(t, spec)
    local slots = { transition = mover(t, spec, { in_y = 30, out_y = -30, duration = 450 }) }
    if not spec.chrome then return slots end
    local names = names_of(spec)
    local GAP = 6
    local function seg() return ((t.width or 0) - 40 - GAP * (#names - 1)) / math.max(1, #names) end
    local bars = ui.Item { x = 20, y = 10, width = function() return (t.width or 0) - 40 end, height = 4 }
    for i in ipairs(names) do
      ui.reparent(ui.Item { x = function() return (i - 1) * (seg() + GAP) end, width = seg, height = 4,
        ui.Rect { anchors = { fill = true }, radius = 2, color = function() return C().secondaryContainer end },
        ui.Rect { height = 4, radius = 2, color = function() return C().primary end,
          width = function() return i <= index_of(t, spec) and seg() or 0 end, behavior = { width = spring } } }, bars)
    end
    slots.background = ground()
    slots.indicator = bars
    return slots
  end

  --- A wizard: steps on the X axis; a bar with the step's name, a tonal
  --- "2 / 4" chip, and a linear progress indicator under it.
  function S.wizard(t, spec)
    local slots = { transition = mover(t, spec, { in_px = 60, out_px = 60, duration = 450 }) }
    if not spec.chrome then return slots end
    local names = names_of(spec)
    local H = 48
    local chip = M.text { text = function() return ("%d / %d"):format(index_of(t, spec), #names) end,
      font_size = theme.size.small, axes = weight(600, theme.size.small), color = function() return C().onSecondaryContainer end }
    slots.background = ground()
    slots.page = ui.Item { width = function() return t.width end, height = H,
      ui.Rect { anchors = { fill = true }, top_left_radius = 24, top_right_radius = 24,
        color = function() return C().surfaceContainer end },
      ui.Rect { x = 0, y = H - 4, width = function() return t.width end, height = 4, radius = 2,
        color = function() return C().secondaryContainer end },
      ui.Rect { x = 0, y = H - 4, height = 4, radius = 2, color = function() return C().primary end,
        width = function() return (t.width or 0) * index_of(t, spec) / math.max(1, #names) end, behavior = { width = spring } },
      M.text { x = 20, anchors = { vertical_center = true }, text = function() return title_of(spec, t.current) end,
        axes = weight(500), color = function() return C().onSurface end },
      ui.Rect { anchors = { right = true, right_margin = 14, vertical_center = true }, height = 26, radius = 13,
        width = function() return (chip.layout_width or 0) + 20 end, color = function() return C().secondaryContainer end,
        ui.Item { x = 10, y = (26 - theme.size.small * 1.4) / 2, chip } } }
    return slots
  end

  --- Master and detail: the detail grows in from smaller (a container
  --- transform's settle) as the old one fades.
  function S.master_detail(t, spec)
    return {
      transition = mover(t, spec, { in_scale = 0.9, duration = 450, fade_in = 250, fade_out = 100, delay = 60 }),
      background = spec.chrome and ground() or nil,
    }
  end
end
