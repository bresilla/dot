-- Tsugumori's looks for each Navigation widget: hard cuts and wipes, each
-- crossed by the theme's light blade -- a narrow stroke leading a faint
-- trail over the pages while they change, gone once they settle. A
-- navigation view cuts in from its side as the old page drops away; a view
-- stack flickers over; tab pages wipe side by side; a carousel's slide
-- snaps across; an onboarding page cuts up; a wizard steps along; a detail
-- pane flickers in. With `chrome = true` in its spec the widget also draws
-- its furniture over its pages: a framed header with a square back key
-- and the title in capitals, numbered tab slots, square slide marks, a
-- hatched segment rail, a step register. A composite that draws its own
-- leaves `chrome` out. The page's name is `spec.titles[name]`, or the name.
local morf = require("morf")
local ui = require("morf.ui")
local stripes = require("themes.tsugumori.stripes")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local quick = { duration = 140, easing = "out_cubic" }
  local snap = { duration = 260, easing = "out_expo" }
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
  local function title_of(spec, name) return tostring((spec.titles or {})[name] or name or ""):upper() end
  local function caps(text, props)
    props = props or {}
    props.text = text
    return M.menu_label(props)
  end

  -- -------------------------------------------------------- transitions --

  --- The light blade: a stroke and its trail, hidden at rest, swept
  --- across the pages by a change.
  local function blade_layer()
    local trail = ui.Rect { x = 0, width = 56, anchors = { top = true, bottom = true },
      color = function() return C.secondary:alpha(.16) end }
    local edge = ui.Rect { x = 56, width = 2, anchors = { top = true, bottom = true }, color = function() return C.onSurface end }
    local blade = ui.Item { x = -60, width = 58, anchors = { top = true, bottom = true }, opacity = 0, trail, edge }
    return ui.Item { anchors = { fill = true }, clip = true, blade }, blade, trail, edge
  end

  --- A transition: `to` from `in_x` widths along the direction (`in_y`
  --- px), on `easing`, with `flicker` keyframes on its opacity or a plain
  --- cut; `from` fades out over `drop` ms; the blade crosses either way.
  local function mover(t, spec, o, blade, trail, edge)
    local latest
    return function(from, to, direction)
      latest = to
      direction = direction or 1
      local W = spec.width or to.layout_width or t.width or 400
      local function reset(node) node.translate_x, node.translate_y, node.opacity = 0, 0, 1 end
      if not from then reset(to) return end
      local d = o.duration or 240
      to.translate_x, to.translate_y = direction * W * (o.in_x or 0), o.in_y or 0
      local steps = {
        { node = to, property = "translate_x", to = 0, duration = d, easing = o.easing or "out_expo" },
        { node = to, property = "translate_y", to = 0, duration = d, easing = o.easing or "out_expo" },
        { node = from, property = "opacity", to = 0, duration = o.drop or 80, easing = "linear" },
      }
      if o.flicker then
        to.opacity = 0
        steps[#steps + 1] = { node = to, property = "opacity", duration = 220, keyframes = {
          { at = 0, value = 0 }, { at = .2, value = .7 }, { at = .35, value = .15 }, { at = .55, value = .85 },
          { at = .7, value = .4 }, { at = 1, value = 1 } } }
      else
        to.opacity = 1
      end
      if o.out_x then
        steps[#steps + 1] = { node = from, property = "translate_x", to = -direction * W * o.out_x, duration = d,
          easing = o.easing or "out_expo" }
      end
      if blade and not o.no_blade then
        local forward = direction >= 0
        trail.x, edge.x = forward and 0 or 2, forward and 56 or 0
        steps[#steps + 1] = { node = blade, property = "x", from = forward and -60 or W, to = forward and W or -60,
          duration = math.max(260, d + 60), easing = "out_cubic" }
        steps[#steps + 1] = { node = blade, property = "opacity", duration = math.max(260, d + 60), keyframes = {
          { at = 0, value = 0 }, { at = .12, value = 1 }, { at = .7, value = .8 }, { at = 1, value = 0 } } }
      end
      morf.animation.play { { parallel = steps }, on_finished = function()
        if from ~= latest then from.visible = false reset(from) end
        if blade then blade.opacity = 0 end
      end }
    end
  end

  --- The slots every widget shares: its transition and the blade over it.
  local function base(t, spec, o)
    local layer, blade, trail, edge = blade_layer()
    return { transition = mover(t, spec, o, blade, trail, edge), content = layer }
  end

  -- ------------------------------------------------------------ chrome --

  local function ground()
    return ui.Item { anchors = { fill = true },
      ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainer end, border_width = 1,
        border_color = function() return stroke(C, "idle") end },
      hud().corners { length = 10, color = hud().line("hot") } }
  end

  --- A framed header: a square back key while there is somewhere to go
  --- back to, the page's name in capitals, a primary rule under it.
  local function header(t, spec, send, H)
    H = H or 44
    local key
    key = ui.MouseArea { x = 6, y = (H - 32) / 2, width = 32, height = 32, cursor = "pointer",
      accessible_role = "button", accessible_name = "Back", on_clicked = function() send("pop") end,
      visible = function() return t.can_go_back end,
      ui.Rect { anchors = { fill = true }, color = function() return C.primary:alpha(key and key.hovered and .14 or 0) end,
        border_width = 1, border_color = function() return stroke(C, "hover") end },
      M.icon("arrow_back", 18, function() return C.primary end, { anchors = { center_in = true } }) }
    return ui.Item { width = function() return t.width end, height = H,
      ui.Rect { anchors = { fill = true, margins = 1 }, color = function() return C.surfaceContainerHigh end },
      ui.Rect { anchors = { left = true, right = true }, y = H - 1, height = 1, color = function() return C.primary end },
      key,
      ui.Item { y = (H - 18) / 2, height = 18, x = function() return t.can_go_back and 50 or 14 end, behavior = { x = snap },
        caps(function() return title_of(spec, t.current) end, { color = function() return C.onSurface end }) } }
  end

  -- ------------------------------------------------------------ widgets --

  function S.navigation_view(t, spec, _, send)
    local slots = base(t, spec, { in_x = 0.6, duration = 240 })
    if spec.chrome then slots.background, slots.page = ground(), header(t, spec, send) end
    return slots
  end

  function S.settings_subpages(t, spec, _, send)
    local slots = base(t, spec, { in_x = 0.35, duration = 220, flicker = true })
    if spec.chrome then slots.background, slots.page = ground(), header(t, spec, send, 48) end
    return slots
  end

  function S.view_stack(t, spec)
    local slots = base(t, spec, { flicker = true, duration = 220, drop = 60 })
    if spec.chrome then slots.background = ground() end
    return slots
  end

  --- Tab pages: numbered framed slots across the top, the chosen one
  --- solid primary, a block sliding under it; the pages wipe side by side.
  function S.tab_pages(t, spec, _, send)
    local slots = base(t, spec, { in_x = 1, out_x = 1, drop = 260, duration = 280 })
    if not spec.chrome then return slots end
    local names = names_of(spec)
    local GAP = 6
    local function slot() return ((t.width or 0) - 12 - GAP * (#names - 1)) / math.max(1, #names) end
    local strip = ui.Item { width = function() return t.width end, height = 44 }
    for i, name in ipairs(names) do
      local area
      area = ui.MouseArea { x = function() return 6 + (i - 1) * (slot() + GAP) end, y = 6, width = slot, height = 30,
        cursor = "pointer", accessible_role = "tab", accessible_name = title_of(spec, name),
        on_clicked = function() send("go", name) end,
        ui.Rect { anchors = { fill = true }, color = function() return C.primary end,
          opacity = function() return t.current == name and 1 or 0 end, behavior = { opacity = quick } },
        ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
          border_color = function() return (area and area.hovered) and stroke(C, "hover") or stroke(C, "idle") end },
        caps(("%02d"):format(i), { x = 8, anchors = { vertical_center = true },
          color = function() return t.current == name and C.onPrimary or C.onSurfaceVariant end }),
        caps(title_of(spec, name), { x = 34, anchors = { vertical_center = true },
          color = function() return t.current == name and C.onPrimary or C.onSurface end }) }
      ui.reparent(area, strip)
    end
    ui.reparent(ui.Rect { y = 40, height = 2, width = slot, color = function() return C.primary end,
      x = function() return 6 + (math.max(1, index_of(t, spec)) - 1) * (slot() + GAP) end, behavior = { x = snap } }, strip)
    slots.background = ground()
    slots.indicator = strip
    return slots
  end

  --- A carousel: slides snap across; square marks under them, a primary
  --- bar jumping to the current one, square keys at the ends.
  function S.carousel(t, spec, _, send)
    local slots = base(t, spec, { in_x = 1, out_x = 0.5, drop = 200, duration = 300 })
    if not spec.chrome then return slots end
    local names = names_of(spec)
    local MARK, GAP = 6, 12
    local function row_x() return ((t.width or 0) - (#names * MARK + (#names - 1) * GAP)) / 2 end
    local band = ui.Item { anchors = { left = true, right = true, bottom = true }, height = 32,
      ui.Rect { anchors = { left = true, right = true, top = true, left_margin = 1, right_margin = 1 }, height = 1,
        color = function() return stroke(C, "idle") end } }
    for i, name in ipairs(names) do
      ui.reparent(ui.MouseArea { x = function() return row_x() + (i - 1) * (MARK + GAP) - 5 end, y = 8, width = MARK + 10,
        height = 16, cursor = "pointer", accessible_name = title_of(spec, name), on_clicked = function() send("go", name) end,
        ui.Rect { x = 5, y = 5, width = MARK, height = MARK, color = "transparent", border_width = 1,
          border_color = function() return stroke(C, "hover") end } }, band)
    end
    ui.reparent(ui.Rect { y = 13, height = MARK, width = 16, color = function() return C.primary end,
      x = function() return row_x() + (math.max(1, index_of(t, spec)) - 1) * (MARK + GAP) - 5 end, behavior = { x = snap } }, band)
    local function key(icon, event, show)
      local area
      area = ui.MouseArea { y = 4, width = 24, height = 24, cursor = "pointer", accessible_role = "button",
        accessible_name = event, on_clicked = function() send(event) end, visible = show,
        ui.Rect { anchors = { fill = true }, color = function() return C.primary:alpha(area and area.hovered and .14 or 0) end,
          border_width = 1, border_color = function() return stroke(C, "hover") end },
        M.icon(icon, 16, function() return C.primary end, { anchors = { center_in = true } }) }
      return area
    end
    local left = key("chevron_left", "previous", function() return index_of(t, spec) > 1 end)
    left.x = 8
    local right = key("chevron_right", "next", function() return index_of(t, spec) < #names end)
    right.x = function() return (t.width or 0) - 32 end
    ui.reparent(left, band)
    ui.reparent(right, band)
    slots.background = ground()
    slots.indicator = band
    return slots
  end

  --- Onboarding: pages cut up into place; a rail of segments along the
  --- top, the passed ones hatched, the current one solid.
  function S.onboarding(t, spec)
    local slots = base(t, spec, { in_y = 40, duration = 260, drop = 120 })
    if not spec.chrome then return slots end
    local names = names_of(spec)
    local GAP = 4
    local function seg() return ((t.width or 0) - 32 - GAP * (#names - 1)) / math.max(1, #names) end
    local rail = ui.Item { x = 16, y = 8, width = function() return (t.width or 0) - 32 end, height = 8 }
    for i in ipairs(names) do
      ui.reparent(ui.Item { x = function() return (i - 1) * (seg() + GAP) end, width = seg, height = 8,
        ui.Item { anchors = { fill = true }, clip = true, opacity = function() return i < index_of(t, spec) and 1 or 0 end,
          stripes.box { width = 200, height = 8, gap = 5, weight = 1.5, color = function() return C.primary:alpha(.7) end } },
        ui.Rect { anchors = { fill = true }, color = function() return C.primary end,
          opacity = function() return i == index_of(t, spec) and 1 or 0 end, behavior = { opacity = quick } },
        ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
          border_color = function() return stroke(C, "hover") end } }, rail)
    end
    slots.background = ground()
    slots.indicator = rail
    return slots
  end

  --- A wizard: steps along with the blade; a register with the step's
  --- number, its name in capitals and a hatched run filling to it.
  function S.wizard(t, spec)
    local slots = base(t, spec, { in_x = 0.2, duration = 240, drop = 100 })
    if not spec.chrome then return slots end
    local names = names_of(spec)
    local H = 44
    slots.background = ground()
    slots.page = ui.Item { width = function() return t.width end, height = H,
      ui.Rect { anchors = { fill = true, margins = 1 }, color = function() return C.surfaceContainerHigh end },
      ui.Item { x = 1, y = H - 7, height = 6, clip = true,
        width = function() return math.max(0, ((t.width or 0) - 2) * index_of(t, spec) / math.max(1, #names)) end,
        behavior = { width = snap },
        stripes.box { width = 1200, height = 6, gap = 5, weight = 1.5, color = function() return C.primary end } },
      ui.Rect { anchors = { left = true, right = true }, y = H - 1, height = 1, color = function() return C.primary end },
      caps(function() return ("%02d / %02d"):format(index_of(t, spec), #names) end,
        { x = 14, y = (H - 24) / 2, color = function() return C.primary end }),
      ui.Rect { x = 92, y = 10, width = 1, height = H - 24, color = function() return stroke(C, "focus") end },
      caps(function() return title_of(spec, t.current) end, { x = 104, y = (H - 24) / 2,
        color = function() return C.onSurface end }) }
    return slots
  end

  --- Master and detail: the detail flickers in over a framed panel.
  function S.master_detail(t, spec)
    local slots = base(t, spec, { flicker = true, in_x = 0.04, duration = 220, drop = 60 })
    if spec.chrome then slots.background = ground() end
    return slots
  end
end
