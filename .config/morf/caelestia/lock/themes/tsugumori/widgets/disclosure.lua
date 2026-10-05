-- Tsugumori's looks for each Disclosure widget: framed headers in mono
-- capitals, square plus marks whose upright folds flat into a minus,
-- numbered rows, a hatched band while open, bracketed cards, a ruled tree.
-- The glue grows the control to its content; while it moves the content
-- is wiped in from the left (or out) behind a mask the control wears only
-- for that moment -- a shutter, like the theme's page cuts.
local morf = require("morf")
local ui = require("morf.ui")
local stripes = require("themes.tsugumori.stripes")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local quick = { duration = 140, easing = "out_cubic" }
  local fold = { duration = 200, easing = "out_cubic" }
  local seq = 0
  local function key(name) seq = seq + 1 return "tsugumori.disclosure." .. name .. "." .. seq end

  --- The content wiped in from the left while it is revealed (and out to
  --- the right while it is hidden): a mask on the control for that
  --- moment, its content part a band whose width runs, gone once done.
  local function reveal(t, node, H)
    local owner = ui.Item {}
    local was = t.expanded
    morf.effect(key("reveal"), function()
      local now = t.expanded
      if now == was then return end
      was = now
      if not node then return end
      local W = t.width or 0
      local part = ui.Rect { x = 0, y = H, width = now and 0 or W, height = 4000, color = "#ffffff" }
      local mask = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { left = true, right = true, top = true }, height = H, color = "#ffffff" }, part }
      node.mask = mask
      local steps = now and { { node = part, property = "width", to = W, duration = 300, easing = "out_expo" } }
        or { { node = part, property = "x", to = W, duration = 160, easing = "in_cubic" } }
      morf.animation.play { { parallel = steps },
        on_finished = function() if node.mask == mask then node.mask = nil end end }
    end, { owner = owner })
    return owner
  end

  local function on() return C.onSurface end
  local function wash(t) return function() return C.primary:alpha(t.down and .18 or (t.hovered and .06 or 0)) end end
  local function caps(text, props)
    props = props or {}
    props.text = tostring(text or ""):upper()
    return M.menu_label(props)
  end
  local function room(t, used) return function() return math.max(0, (t.width or 0) - used) end end
  local function brackets(t)
    return hud().corners { length = 6, weight = 2, color = function() return C.primary end,
      visible = function() return t.visual_focus end }
  end

  --- A square plus of `size` whose upright folds flat into a minus as it
  --- opens; `x` a number or binding.
  local function plus(t, H, size, x, color)
    color = color or function() return C.primary end
    local bar = math.max(2, math.floor(size / 7))
    return ui.Item { x = x, y = (H - size) / 2, width = size, height = size,
      ui.Rect { x = 0, y = (size - bar) / 2, width = size, height = bar, color = color },
      ui.Rect { x = (size - bar) / 2, width = bar, color = color,
        y = function() return t.expanded and (size - bar) / 2 or 0 end,
        height = function() return t.expanded and bar or size end,
        behavior = { y = fold, height = fold } } }
  end
  --- A square chevron mark: a filled triangle that turns.
  local function arrow(t, H, size, x, open)
    return ui.Item { x = x, y = (H - size) / 2, width = size, height = size,
      rotation = function() return t.expanded and (open or 90) or 0 end, behavior = { rotation = fold },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, 10, 10 }, d = "M3 1 L8 5 L3 9 Z",
        fill_color = function() return C.primary end } }
  end

  --- An expander: a framed header in capitals, the frame primary and a
  --- hatched band filling it while open, the plus folding.
  function S.expander(t, spec, node)
    local H = spec.header_height or 44
    return {
      background = ui.Item { width = function() return t.width end, height = H,
        ui.Item { anchors = { fill = true, margins = 1 }, clip = true, opacity = function() return t.expanded and 1 or 0 end,
          behavior = { opacity = quick },
          stripes.box { width = 640, height = 80, gap = 8, weight = 2, color = function() return C.primary:alpha(.12) end } },
        ui.Rect { anchors = { fill = true }, color = wash(t), border_width = 1,
          border_color = function() return t.expanded and C.primary or stroke(C, "idle") end, behavior = { color = quick } } },
      header = ui.Item { width = function() return t.width end, height = H,
        caps(spec.title, { x = 14, anchors = { vertical_center = true }, width = room(t, 50), elide = "right",
          color = function() return t.expanded and C.primary or C.onSurface end }),
        brackets(t) },
      indicator = ui.Item { plus(t, H, 14, function() return (t.width or 0) - 28 end), reveal(t, node, H) },
    }
  end

  --- An expander row: a framed card the whole height, registration
  --- brackets on it, the title in capitals over a dim line, the plus.
  function S.expander_row(t, spec, node)
    local H = spec.header_height or 52
    local sub = spec.subtitle
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainer end, border_width = 1,
          border_color = function() return stroke(C, "idle") end },
        ui.Rect { width = function() return t.width end, height = H, color = wash(t), behavior = { color = quick } },
        hud().corners { length = 8, color = hud().line("hot") } },
      header = ui.Item { width = function() return t.width end, height = H,
        caps(spec.title, { x = 14, y = sub and (H / 2 - 19) or (H - 18) / 2, height = 18, width = room(t, 50), elide = "right",
          color = function() return t.expanded and C.primary or C.onSurface end }),
        sub and M.text { x = 14, y = H / 2 + 1, text = sub, font_size = theme.typography.menu, width = room(t, 50),
          elide = "right", color = function() return C.onSurfaceVariant end } or nil,
        brackets(t) },
      indicator = ui.Item { plus(t, H, 14, function() return (t.width or 0) - 28 end), reveal(t, node, H) },
      content = ui.Rect { x = 1, y = H, width = function() return math.max(0, (t.width or 0) - 2) end, height = 1,
        color = function() return stroke(C, "idle") end, opacity = function() return t.expanded and 1 or 0 end },
    }
  end

  --- An accordion's row: a hairline under it, a primary block at its
  --- start while open, a minus or plus.
  function S.accordion(t, spec, node)
    local H = spec.header_height or 40
    return {
      background = ui.Item { width = function() return t.width end, height = H,
        ui.Rect { anchors = { fill = true }, color = wash(t), behavior = { color = quick } },
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1, color = function() return stroke(C, "idle") end },
        ui.Rect { x = 0, y = 0, height = H, color = function() return C.primary end,
          width = function() return t.expanded and 4 or 0 end, behavior = { width = fold } } },
      header = ui.Item { width = function() return t.width end, height = H,
        caps(spec.title, { x = 16, anchors = { vertical_center = true }, width = room(t, 50), elide = "right",
          color = function() return t.expanded and C.primary or C.onSurface end }),
        brackets(t) },
      indicator = ui.Item { plus(t, H, 12, function() return (t.width or 0) - 26 end), reveal(t, node, H) },
    }
  end

  --- A collapsible heading: a dim capital label with a short rule after
  --- it and a small triangle.
  function S.collapsible_header(t, spec, node)
    local H = spec.header_height or 32
    local text = caps(spec.title, { x = 26, anchors = { vertical_center = true },
      color = function() return C.onSurfaceVariant end })
    return {
      background = ui.Rect { width = function() return t.width end, height = H, color = wash(t), behavior = { color = quick } },
      header = ui.Item { width = function() return t.width end, height = H, text,
        ui.Rect { x = function() return 34 + (text.layout_width or 0) end, y = H / 2, height = 1,
          width = function() return math.max(0, (t.width or 0) - 42 - (text.layout_width or 0)) end,
          color = function() return stroke(C, "idle") end },
        brackets(t) },
      indicator = ui.Item { arrow(t, H, 12, 8), reveal(t, node, H) },
    }
  end

  --- A collapsible section: a framed numbered tab with the title, a
  --- primary rule along the bottom that runs out while open, the plus.
  function S.collapsible_section(t, spec, node)
    local H = spec.header_height or 44
    return {
      background = ui.Item { width = function() return t.width end, height = H,
        ui.Rect { anchors = { fill = true }, color = wash(t), behavior = { color = quick } },
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1, color = function() return stroke(C, "idle") end },
        ui.Rect { anchors = { bottom = true }, height = 2, color = function() return C.primary end,
          width = function() return t.expanded and (t.width or 0) or 0 end, behavior = { width = { duration = 320, easing = "out_expo" } } } },
      header = ui.Item { width = function() return t.width end, height = H,
        M.text { x = 4, anchors = { vertical_center = true }, text = tostring(spec.title or ""):upper(),
          font_size = theme.typography.title, color = function() return t.expanded and C.primary or C.onSurface end },
        brackets(t) },
      indicator = ui.Item {
        ui.Rect { x = function() return (t.width or 0) - 32 end, y = (H - 24) / 2, width = 24, height = 24,
          color = "transparent", border_width = 1, border_color = function() return stroke(C, "hover") end },
        plus(t, H, 12, function() return (t.width or 0) - 26 end), reveal(t, node, H) },
    }
  end

  --- Details: a triangle that turns down, and a bracket rule down the
  --- side of what it shows.
  function S.details(t, spec, node)
    local H = spec.header_height or 36
    return {
      background = ui.Rect { width = function() return t.width end, height = H, color = wash(t), behavior = { color = quick } },
      header = ui.Item { width = function() return t.width end, height = H,
        caps(spec.title, { x = 28, anchors = { vertical_center = true }, width = room(t, 36), elide = "right",
          color = function() return t.expanded and C.primary or C.onSurface end }),
        brackets(t) },
      indicator = ui.Item { arrow(t, H, 14, 6), reveal(t, node, H) },
      content = ui.Item { anchors = { left = true, top = true, bottom = true, left_margin = 12, top_margin = H + 2,
          bottom_margin = 4 }, width = 5,
        ui.Rect { x = 0, anchors = { top = true, bottom = true }, width = 1, color = function() return C.primary end },
        ui.Rect { x = 0, y = 0, width = 5, height = 1, color = function() return C.primary end },
        ui.Rect { x = 0, anchors = { bottom = true }, width = 5, height = 1, color = function() return C.primary end } },
    }
  end

  --- A tree's node: a square marker (filled while open), the name in
  --- capitals, and a hairline guide with ticks down its children.
  function S.tree_node(t, spec, node)
    local H = spec.header_height or 32
    return {
      background = ui.Rect { width = function() return t.width end, height = H, color = wash(t), behavior = { color = quick } },
      header = ui.Item { width = function() return t.width end, height = H,
        ui.Rect { x = 28, anchors = { vertical_center = true }, width = 9, height = 9,
          color = function() return t.expanded and C.primary or C.primary:alpha(0) end, border_width = 1,
          border_color = function() return C.primary end, behavior = { color = quick } },
        caps(spec.title, { x = 46, anchors = { vertical_center = true }, width = room(t, 52), elide = "right",
          color = function() return t.expanded and C.primary or C.onSurface end }),
        brackets(t) },
      indicator = ui.Item { arrow(t, H, 12, 6), reveal(t, node, H) },
      content = ui.Rect { anchors = { left = true, top = true, bottom = true, left_margin = 11, top_margin = H,
        bottom_margin = 2 }, width = 1, color = function() return stroke(C, "focus") end },
    }
  end

  --- "Show more": a bracketed capital link, its words turning and its
  --- plus folding as it opens.
  function S.show_more(t, spec, node)
    local H = spec.header_height or 36
    local more, less = spec.title or "Show more", spec.title_expanded or "Show less"
    local text = caps("", { color = function() return C.primary end })
    text.text = function() return (t.expanded and less or more):upper() end
    local function left() return ((t.width or 0) - (text.layout_width or 0)) / 2 - 12 end
    return {
      background = ui.Rect { x = function() return left() - 12 end, y = 2, height = H - 4,
        width = function() return (text.layout_width or 0) + 48 end, color = wash(t), border_width = 1,
        border_color = function() return t.hovered and stroke(C, "hover") or stroke(C, "quiet") end,
        behavior = { color = quick } },
      header = ui.Item { width = function() return t.width end, height = H,
        ui.Item { x = left, y = (H - 18) / 2, height = 18, text }, brackets(t) },
      indicator = ui.Item {
        plus(t, H, 10, function() return left() + (text.layout_width or 0) + 10 end), reveal(t, node, H) },
    }
  end

  --- A collapsible card: a framed card the whole height with brackets and
  --- a hatched strip in its header, the title in capitals, the plus.
  function S.collapsible_card(t, spec, node)
    local H = spec.header_height or 48
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainer end, border_width = 1,
          border_color = function() return t.expanded and stroke(C, "focus") or stroke(C, "idle") end },
        ui.Rect { width = function() return t.width end, height = H, color = wash(t), behavior = { color = quick } },
        ui.Item { x = function() return (t.width or 0) - 120 end, y = 12, width = 72, height = H - 24, clip = true,
          stripes.box { width = 72, height = 40, gap = 7, weight = 2, color = function() return C.primary:alpha(.4) end } },
        hud().corners { length = 10, color = hud().line("hot") } },
      header = ui.Item { width = function() return t.width end, height = H,
        caps(spec.title, { x = 16, anchors = { vertical_center = true }, width = room(t, 140), elide = "right",
          color = function() return C.onSurface end }),
        brackets(t) },
      indicator = ui.Item { plus(t, H, 14, function() return (t.width or 0) - 32 end), reveal(t, node, H) },
    }
  end

  --- A fold-out: a solid primary band with dark capitals, the panel it
  --- folds out hatched faintly behind its content, framed in the primary.
  function S.fold_out(t, spec, node)
    local H = spec.header_height or 40
    local function ink() return C.onPrimary end
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Item { anchors = { fill = true, top_margin = H }, clip = true,
          stripes.box { width = 640, height = 480, gap = 10, weight = 1, color = function() return C.primary:alpha(.08) end } },
        ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1, border_color = function() return C.primary end },
        ui.Rect { width = function() return t.width end, height = H,
          color = function() return t.down and C.primary:mix(C.onPrimary, .2) or (t.hovered and C.primary:mix(C.onPrimary, .1) or C.primary) end,
          behavior = { color = quick } } },
      header = ui.Item { width = function() return t.width end, height = H,
        caps(spec.title, { x = 14, anchors = { vertical_center = true }, width = room(t, 50), elide = "right", color = ink }),
        brackets(t) },
      indicator = ui.Item { plus(t, H, 14, function() return (t.width or 0) - 28 end, ink), reveal(t, node, H) },
    }
  end
end
