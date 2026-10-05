-- Material's looks for each Disclosure widget (Material 3 Expressive): an
-- expander's state layer, a list item's tonal card, an accordion's
-- dividers with a primary title, a drawer's section label, a bold section
-- with its chevron in a tonal circle that morphs into a squircle, a tree
-- with filled folders, a "show more" text button, an elevated card, a
-- tertiary fold-out. Indicators turn on a spring that overshoots; while
-- the content grows or shrinks it fades through a mask the control wears
-- only for that moment.
local morf = require("morf")
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local function quick() return { duration = theme.duration.small, easing = theme.ease.standard } end
  local turn = M.spring(420, 22)
  local seq = 0
  local function key(name) seq = seq + 1 return "caelestia.material.disclosure." .. name .. "." .. seq end

  --- The content fading in (or out) while it is revealed: a mask on the
  --- control for the moment -- the header whole, the content part fading
  --- on the emphasized curve -- gone once it settles.
  local function reveal(t, node, H)
    local owner = ui.Item {}
    local was = t.expanded
    morf.effect(key("reveal"), function()
      local now = t.expanded
      if now == was then return end
      was = now
      if not node then return end
      local part = ui.Rect { anchors = { fill = true, top_margin = H }, color = "#ffffff", opacity = now and 0 or 1 }
      local mask = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { left = true, right = true, top = true }, height = H, color = "#ffffff" }, part }
      node.mask = mask
      morf.animation.play { { node = part, property = "opacity", to = now and 1 or 0,
        duration = now and 420 or 150, easing = now and theme.ease.emphasized_decel or theme.ease.emphasized_accel,
        delay = now and 60 or 0 },
        on_finished = function() if node.mask == mask then node.mask = nil end end }
    end, { owner = owner })
    return owner
  end

  local function on() return C().onSurface end
  local function variant() return C().onSurfaceVariant end
  local function layer(t, base)
    return function()
      local c = base and base() or C().onSurface:alpha(0)
      if t.down then return c:mix(C().onSurface, 0.1) end
      return t.hovered and c:mix(C().onSurface, 0.08) or c
    end
  end
  local function veil(t)
    return function()
      if t.down then return C().onSurface:alpha(0.1) end
      return t.hovered and C().onSurface:alpha(0.08) or C().onSurface:alpha(0)
    end
  end
  local function ring(t, radius, H)
    return ui.Rect { width = function() return t.width end, height = H, radius = radius, color = "transparent", z = 5,
      border_width = function() return t.visual_focus and 2 or 0 end, border_color = function() return C().secondary end }
  end
  local function chevron(t, H, size, props)
    props = props or {}
    return ui.Item { x = props.x or function() return (t.width or 0) - size - 14 end, y = (H - size) / 2,
      width = size, height = size,
      rotation = function() return t.expanded and (props.open or 180) or (props.closed or 0) end,
      behavior = { rotation = turn },
      M.icon(props.icon or "expand_more", size, props.color or variant) }
  end
  local function title(spec, x, H, props)
    props = props or {}
    props.x, props.text = x, spec.title or ""
    props.font_size = props.font_size or theme.size.normal
    props.y = props.y or (H - props.font_size * 1.4) / 2
    props.color = props.color or on
    if props.width then props.elide = "right" end
    if props.weight then
      local size, w = props.font_size, props.weight
      props.axes = { opsz = size * 3 / 4, ROND = 25, wght = w }
      props.weight = nil
    end
    return M.text(props)
  end
  local function room(t, used) return function() return math.max(0, (t.width or 0) - used) end end

  --- An expander: a state layer across a rounded row, the title turning
  --- primary while open, the chevron springing over.
  function S.expander(t, spec, node)
    local H = spec.header_height or 44
    return {
      background = ui.Rect { width = function() return t.width end, height = H, radius = 16, color = veil(t),
        behavior = { color = quick() } },
      header = ui.Item { width = function() return t.width end, height = H,
        title(spec, 16, H, { width = room(t, 60), color = function() return t.expanded and C().primary or C().onSurface end,
          behavior = { color = quick() } }),
        ring(t, 16, H) },
      indicator = ui.Item { chevron(t, H, 22), reveal(t, node, H) },
    }
  end

  --- An expander row: a list item on a low container card with large
  --- corners that grows round the content, a supporting line under the
  --- title, and the chevron in a tonal circle.
  function S.expander_row(t, spec, node)
    local H = spec.header_height or 52
    local sub = spec.subtitle
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, radius = 20, color = function() return C().surfaceContainerLow end },
        ui.Rect { width = function() return t.width end, height = H, radius = 20, color = veil(t),
          behavior = { color = quick() } } },
      header = ui.Item { width = function() return t.width end, height = H,
        title(spec, 16, H, { y = sub and (H / 2 - theme.size.normal * 1.3) or nil, width = room(t, 64) }),
        sub and M.text { x = 16, y = H / 2 + 1, text = sub, font_size = theme.size.small, color = variant,
          width = room(t, 64), elide = "right" } or nil,
        ring(t, 20, H) },
      indicator = ui.Item {
        ui.Rect { x = function() return (t.width or 0) - 46 end, y = (H - 32) / 2, width = 32, height = 32, radius = 16,
          color = function() return t.expanded and C().secondaryContainer or C().surfaceContainerHighest end,
          behavior = { color = quick() } },
        chevron(t, H, 20, { x = function() return (t.width or 0) - 40 end,
          color = function() return t.expanded and C().onSecondaryContainer or C().onSurfaceVariant end }),
        reveal(t, node, H) },
    }
  end

  --- An accordion's row: an outline divider below, the title primary and
  --- bold while open with a primary pill rising at its start, and a plus
  --- that springs round into a cross.
  function S.accordion(t, spec, node)
    local H = spec.header_height or 40
    local function bar() return t.expanded and H - 14 or 0 end
    return {
      background = ui.Item { width = function() return t.width end, height = H,
        ui.Rect { anchors = { fill = true }, radius = 12, color = veil(t), behavior = { color = quick() } },
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1, color = function() return C().outlineVariant end },
        ui.Rect { x = 2, width = 4, radius = 2, height = bar, y = function() return (H - bar()) / 2 end,
          color = function() return C().primary end, behavior = { height = turn, y = turn } } },
      header = ui.Item { width = function() return t.width end, height = H,
        title(spec, 16, H, { width = room(t, 60), color = function() return t.expanded and C().primary or C().onSurface end,
          behavior = { color = quick() } }),
        ring(t, 12, H) },
      indicator = ui.Item { chevron(t, H, 22, { icon = "add", open = 135,
        color = function() return t.expanded and C().primary or C().onSurfaceVariant end }), reveal(t, node, H) },
    }
  end

  --- A collapsible header: a drawer's section label in the variant tone
  --- with a small chevron right after it.
  function S.collapsible_header(t, spec, node)
    local H = spec.header_height or 32
    local text = title(spec, 12, H, { font_size = theme.size.small, weight = 600, color = variant })
    return {
      background = ui.Rect { width = function() return t.width end, height = H, radius = H / 2, color = veil(t),
        behavior = { color = quick() } },
      header = ui.Item { width = function() return t.width end, height = H, text, ring(t, H / 2, H) },
      indicator = ui.Item {
        chevron(t, H, 18, { closed = -90, open = 0, x = function() return 18 + (text.layout_width or 0) end }),
        reveal(t, node, H) },
    }
  end

  --- A collapsible section: a large title, a primary underline that
  --- springs out under it while open, and the chevron in a tonal circle
  --- that morphs into a squircle as it opens.
  function S.collapsible_section(t, spec, node)
    local H = spec.header_height or 44
    local text = title(spec, 4, H, { font_size = theme.size.larger, weight = 600 })
    return {
      background = ui.Item { width = function() return t.width end, height = H,
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1, color = function() return C().outlineVariant end },
        ui.Rect { x = 4, anchors = { bottom = true }, height = 3, radius = 1.5,
          width = function() return t.expanded and (text.layout_width or 0) or 0 end,
          color = function() return C().primary end, behavior = { width = turn } } },
      header = ui.Item { width = function() return t.width end, height = H, text, ring(t, 12, H) },
      indicator = ui.Item {
        M.shape { x = function() return (t.width or 0) - 38 end, y = (H - 34) / 2, width = 34, height = 34,
          shape = function() return t.expanded and "cookie4" or "circle" end,
          color = function() return t.expanded and C().secondaryContainer or C().surfaceContainerHigh end },
        chevron(t, H, 20, { x = function() return (t.width or 0) - 31 end,
          color = function() return t.expanded and C().onSecondaryContainer or C().onSurfaceVariant end }),
        reveal(t, node, H) },
    }
  end

  --- Details: a filled triangle before the title that springs down, a
  --- primary rule down the side of what it shows.
  function S.details(t, spec, node)
    local H = spec.header_height or 36
    return {
      background = ui.Rect { width = function() return t.width end, height = H, radius = H / 2, color = veil(t),
        behavior = { color = quick() } },
      header = ui.Item { width = function() return t.width end, height = H,
        title(spec, 32, H, { width = room(t, 44) }), ring(t, H / 2, H) },
      indicator = ui.Item { chevron(t, H, 22, { x = 6, icon = "arrow_right", open = 90,
        color = function() return C().primary end }), reveal(t, node, H) },
      content = ui.Rect { anchors = { left = true, top = true, bottom = true, left_margin = 15, top_margin = H + 2,
        bottom_margin = 4 }, width = 3, radius = 1.5, color = function() return C().primary:alpha(0.5) end },
    }
  end

  --- A tree's node: a chevron, a folder that fills and opens in the
  --- primary, the name, and an outline guide down its children.
  function S.tree_node(t, spec, node)
    local H = spec.header_height or 32
    return {
      background = ui.Rect { width = function() return t.width end, height = H, radius = H / 2, color = veil(t),
        behavior = { color = quick() } },
      header = ui.Item { width = function() return t.width end, height = H,
        M.icon(function() return t.expanded and "folder_open" or "folder" end, 20,
          function() return t.expanded and C().primary or C().onSurfaceVariant end,
          { x = 28, anchors = { vertical_center = true }, fill = function() return t.expanded end }),
        title(spec, 56, H, { width = room(t, 60) }), ring(t, H / 2, H) },
      indicator = ui.Item { chevron(t, H, 20, { x = 4, icon = "chevron_right", open = 90 }), reveal(t, node, H) },
      content = ui.Rect { anchors = { left = true, top = true, bottom = true, left_margin = 13, top_margin = H,
        bottom_margin = 2 }, width = 2, radius = 1, color = function() return C().outlineVariant end },
    }
  end

  --- "Show more": an M3 text button in the primary, centred, its words
  --- and chevron turning as it opens, a state layer pill round it.
  function S.show_more(t, spec, node)
    local H = spec.header_height or 36
    local more, less = spec.title or "Show more", spec.title_expanded or "Show less"
    local text = M.text { text = function() return t.expanded and less or more end, font_size = theme.size.normal,
      axes = { opsz = theme.size.normal * 3 / 4, ROND = 25, wght = 600 }, color = function() return C().primary end }
    return {
      background = ui.Rect { x = function() return ((t.width or 0) - (text.layout_width or 0)) / 2 - 20 end, y = 0,
        width = function() return (text.layout_width or 0) + 56 end, height = H, radius = H / 2,
        color = veil(t), behavior = { color = quick() } },
      header = ui.Item { width = function() return t.width end, height = H,
        ui.Item { x = function() return ((t.width or 0) - (text.layout_width or 0)) / 2 - 10 end,
          y = (H - theme.size.normal * 1.4) / 2, text },
        ring(t, H / 2, H) },
      indicator = ui.Item {
        chevron(t, H, 20, { color = function() return C().primary end,
          x = function() return ((t.width or 0) + (text.layout_width or 0)) / 2 - 4 end }),
        reveal(t, node, H) },
    }
  end

  --- A collapsible card: an elevated card (the high container) whose
  --- corners round further while open, a title, and the chevron in a
  --- tonal circle.
  function S.collapsible_card(t, spec, node)
    local H = spec.header_height or 48
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, radius = function() return t.expanded and 28 or 16 end,
          color = layer(t, function() return C().surfaceContainerHigh end),
          behavior = { radius = turn, color = quick() } } },
      header = ui.Item { width = function() return t.width end, height = H,
        title(spec, 20, H, { weight = 600, width = room(t, 70) }), ring(t, 16, H) },
      indicator = ui.Item {
        ui.Rect { x = function() return (t.width or 0) - 48 end, y = (H - 32) / 2, width = 32, height = 32, radius = 16,
          color = function() return C().secondaryContainer end },
        chevron(t, H, 20, { x = function() return (t.width or 0) - 42 end, color = function() return C().onSecondaryContainer end }),
        reveal(t, node, H) },
    }
  end

  --- A fold-out: a tertiary-container band with a double chevron, the
  --- panel it folds out in the low container under it.
  function S.fold_out(t, spec, node)
    local H = spec.header_height or 40
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, radius = 20, color = function() return C().surfaceContainerLow end },
        ui.Rect { width = function() return t.width end, height = H, radius = 20,
          color = layer(t, function() return C().tertiaryContainer end), behavior = { color = quick() } } },
      header = ui.Item { width = function() return t.width end, height = H,
        M.icon("tune", 20, function() return C().onTertiaryContainer end, { x = 14, anchors = { vertical_center = true } }),
        title(spec, 42, H, { weight = 600, width = room(t, 84), color = function() return C().onTertiaryContainer end }),
        ring(t, 20, H) },
      indicator = ui.Item {
        chevron(t, H, 22, { icon = "keyboard_double_arrow_down", color = function() return C().onTertiaryContainer end }),
        reveal(t, node, H) },
    }
  end
end
