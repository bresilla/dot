-- Material's looks for each Selection widget (Material 3 Expressive):
-- outlined segmented buttons with a tonal fill and a check, navigation-bar
-- pills behind icons, radio rings whose dot rolls, connected button groups
-- that round off when chosen, tonal list plates, a date picker's primary
-- disc. Each keeps the archetype's layout and moves one thing between the
-- entries -- a distance-field layer on an invisible track whose leading
-- edge leaves first on the emphasized curve and whose trailing edge
-- follows, then squashes and settles on a spring. A configuration's own
-- `delegate` keeps its entries; only the ground is drawn round them.
local morf = require("morf")
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local function get(v) if type(v) == "function" then return v() end return v end
  local function quick() return { duration = theme.duration.small, easing = theme.ease.standard } end
  local function label_of(v)
    if type(v) == "table" then return tostring(v.label or v.name or v.text or v.caption or v.title or "") end
    return tostring(v)
  end
  local function icon_of(v) return type(v) == "table" and v.icon or nil end
  local function nothing() return ui.Item {} end
  local seq = 0
  local function key(name) seq = seq + 1 return "caelestia.material.selection." .. name .. "." .. seq end
  local pop = M.spring(520, 20)

  -- --------------------------------------------------------- travel --

  local N = 18
  local function eased(curve, u) return morf.easing.value(curve, math.max(0, math.min(1, u))) end
  --- Moves `node` from box `a` to box `b` ({x, y, w, h}): on each axis the
  --- leading edge on the emphasized-decelerate curve in the first 55 %,
  --- the trailing one on the standard curve from a fifth of the way.
  local function travel(node, a, b, duration)
    local tracks = {}
    for _, axis in ipairs { { "x", "width", 1, 3 }, { "y", "height", 2, 4 } } do
      local l0, r0 = a[axis[3]], a[axis[3]] + a[axis[4]]
      local l1, r1 = b[axis[3]], b[axis[3]] + b[axis[4]]
      if l0 == l1 and r0 == r1 then
        node[axis[1]], node[axis[2]] = l1, r1 - l1
      else
        local forward = l1 >= l0
        local pos, len = {}, {}
        for i = 0, N do
          local u = i / N
          local function edge(from, to, leading)
            local k = leading and eased(theme.ease.emphasized_decel, u / 0.55)
              or eased(theme.ease.standard, (u - 0.2) / 0.8)
            return from + (to - from) * k
          end
          local l = edge(l0, l1, not forward)
          local r = edge(r0, r1, forward)
          pos[#pos + 1] = { at = u, value = l }
          len[#len + 1] = { at = u, value = math.max(0, r - l) }
        end
        tracks[#tracks + 1] = { node = node, property = axis[1], duration = duration, keyframes = pos }
        tracks[#tracks + 1] = { node = node, property = axis[2], duration = duration, keyframes = len }
      end
    end
    if #tracks == 0 then return nil end
    return morf.animation.play { { parallel = tracks } }
  end

  --- An invisible track following the current entry's box through
  --- `fit(x, y, w, h)`; it squashes as it lands (M.STRETCH).
  local function glide(t, fit, on_move)
    local track = ui.Item { visible = function() return t.current > 0 end, stretch = M.STRETCH }
    local last, running
    morf.effect(key("glide"), function()
      local x, y, w, h = t.current_x, t.current_y, t.current_width, t.current_height
      if t.current < 1 or w <= 0 or h <= 0 then return end
      local box = { fit(x, y, w, h) }
      if not last then
        track.x, track.y, track.width, track.height = box[1], box[2], box[3], box[4]
      elseif box[1] ~= last[1] or box[2] ~= last[2] or box[3] ~= last[3] or box[4] ~= last[4] then
        if running then running:stop() end
        local far = math.abs(box[1] - last[1]) + math.abs(box[2] - last[2])
        local duration = math.floor(math.min(560, 340 + far * 0.6))
        running = travel(track, { track.x or last[1], track.y or last[2], track.width or last[3],
          track.height or last[4] }, box, duration)
        if on_move then on_move(duration) end
      end
      last = box
    end, { owner = track })
    return track
  end

  local function inset(d) return function(x, y, w, h) return x + d, y + d, math.max(0, w - 2 * d), math.max(0, h - 2 * d) end end
  local function disc(size, dx)
    return function(x, y, w, h)
      local cx = dx and (x + dx) or (x + w / 2)
      return cx - size / 2, y + h / 2 - size / 2, size, size
    end
  end
  local function round(h) return h / 2 end

  --- The moving layer: a field box of `radius` (a number or a function of
  --- the track's height) in `color` on `track`, `extra` nodes inside it.
  local function plate(track, radius, color, extra)
    for _, node in ipairs(extra or {}) do ui.reparent(node, track) end
    return ui.Item { anchors = { fill = true },
      ui.Sdf { anchors = { fill = true },
        ui.SdfShape { shape = "box", track = track, fill_color = color,
          radius = type(radius) == "function" and function() return radius(track.height or 0) end or radius } },
      track }
  end

  --- The state layer (onSurface at 8 % hovered, 10 % pressed) and the
  --- keyboard's secondary ring on one entry.
  local function state_layer(t, s, radius, props)
    props = props or {}
    props.anchors = props.anchors or { fill = true, margins = props.margins or 0 }
    props.margins = nil
    props.radius = radius
    props.color = function()
      if s.down() then return C().onSurface:alpha(0.1) end
      return s.hovered() and C().onSurface:alpha(0.08) or C().onSurface:alpha(0)
    end
    props.border_width = function() return t.visual_focus and s.current() and 2 or 0 end
    props.border_color = function() return C().secondary end
    props.behavior = { color = quick() }
    return ui.Rect(props)
  end

  --- Text whose weight follows `strong()` (700 then, 500 otherwise).
  local function weighted(props, strong)
    local size = props.font_size or theme.size.normal
    props.font_size = size
    props.axes = function() return { opsz = size * 3 / 4, ROND = 25, wght = strong() and 700 or 500 } end
    return props
  end
  local function label(text, props)
    props.text = text
    props.font_size = props.font_size or theme.size.small
    local w = props.font_weight or 500
    props.font_weight = nil
    if type(w) == "function" then
      local f = w
      weighted(props, function() return f() >= 600 end)
    else
      props.axes = { opsz = props.font_size * 3 / 4, ROND = 25, wght = w }
    end
    props.behavior = props.behavior or {}
    props.behavior.color = quick()
    return M.text(props)
  end

  local function delegated(spec, slots)
    if spec.delegate then slots.indicator = nothing() end
    return slots
  end

  -- --------------------------------------------------- linked choices --

  --- The M3 segmented button: an outlined pill split by outlines; the
  --- chosen segment's secondary-container fill runs to it and a check
  --- springs in before its label.
  function S.segmented(t, spec)
    local track = glide(t, inset(1))
    local vertical = spec.orientation == "vertical"
    -- A check only where there is room for it beside the label.
    local roomy = (spec.item_width or 80) >= 72
    local function half(w, h) return math.min(w or 0, h or 0) / 2 end
    return delegated(spec, {
      background = ui.Rect { anchors = { fill = true }, color = "transparent",
        radius = function() return half(t.width, t.height) end,
        border_width = 1, border_color = function() return C().outline end },
      indicator = plate(track, function() return half(track.width, track.height) end,
        function() return C().secondaryContainer end),
      item = function(index, value, s)
        local glyph = icon_of(value)
        local text = label_of(value)
        local function ink() return s.current() and C().onSecondaryContainer or C().onSurface end
        local look = ui.Item { anchors = { fill = true },
          state_layer(t, s, function() return half(s.area and s.area.width, s.area and s.area.height) end, { margins = 1 }),
          ui.Rect { visible = index > 1, color = function() return C().outline end,
            width = vertical and nil or 1, height = vertical and 1 or nil,
            anchors = vertical and { left = true, right = true, top = true } or { left = true, top = true, bottom = true } } }
        if glyph and text == "" then
          ui.reparent(M.icon(glyph, 18, ink, { anchors = { center_in = true }, fill = s.current }), look)
        else
          local shift = function() return (roomy and s.current()) and 12 or 0 end
          local words = label(text, { anchors = { center_in = true }, color = ink, translate_x = shift,
            behavior = { translate_x = pop } })
          ui.reparent(words, look)
          if roomy then
            ui.reparent(M.icon("check", 18, ink, { anchors = { vertical_center = true },
              x = function() return ((s.area and s.area.width or 0) - (words.layout_width or 0)) / 2 - 12 end,
              opacity = function() return s.current() and 1 or 0 end, scale = function() return s.current() and 1 or 0.3 end,
              behavior = { opacity = quick(), scale = pop } }), look)
          end
        end
        return look
      end,
    })
  end

  --- The navigation bar: each destination an icon over its label, the
  --- chosen icon inside a pill (the active indicator) that runs between
  --- them and squashes as it lands.
  function S.view_switcher(t, spec)
    local track = glide(t, function(x, y, w) return x + w / 2 - 30, y + 4, 60, 30 end)
    return delegated(spec, {
      background = nothing(),
      indicator = plate(track, round, function() return C().secondaryContainer end),
      item = function(_, value, s)
        local function ink() return s.current() and C().onSecondaryContainer or C().onSurfaceVariant end
        return ui.Item { anchors = { fill = true },
          state_layer(t, s, 15, { anchors = { horizontal_center = true }, y = 4, width = 60, height = 30 }),
          M.icon(icon_of(value) or "circle", 22, ink, { anchors = { horizontal_center = true }, y = 7, fill = s.current }),
          label(label_of(value), { anchors = { horizontal_center = true }, y = 38,
            font_weight = function() return s.current() and 700 or 500 end,
            color = function() return s.current() and C().onSurface or C().onSurfaceVariant end }) }
      end,
    })
  end

  --- A connected button group in a tonal trough: the chosen one a primary
  --- pill that runs to it, its icon and label beside each other.
  function S.inline_view_switcher(t, spec)
    local track = glide(t, inset(4))
    return delegated(spec, {
      background = ui.Rect { anchors = { fill = true }, radius = function() return (t.height or 0) / 2 end,
        color = function() return C().surfaceContainerHigh end },
      indicator = plate(track, round, function() return C().primary end),
      item = function(_, value, s)
        local glyph = icon_of(value)
        local function ink() return s.current() and C().onPrimary or C().onSurfaceVariant end
        return ui.Item { anchors = { fill = true },
          state_layer(t, s, function() return ((s.area and s.area.height or 8) - 8) / 2 end, { margins = 4 }),
          ui.Row { anchors = { center_in = true }, gap = 6, align = "center",
            glyph and M.icon(glyph, 18, ink, { fill = s.current }) or nil,
            label(label_of(value), { color = ink }) } }
      end,
    })
  end

  --- M3 radio buttons in a column: an outlined ring per choice, primary
  --- round the chosen one, whose dot rolls ring to ring.
  function S.radio_group(t, spec)
    local D, X = 20, 22
    local track = glide(t, disc(10, X))
    return delegated(spec, {
      background = nothing(),
      indicator = plate(track, 5, function() return C().primary end),
      item = function(_, value, s)
        return ui.Item { anchors = { fill = true },
          ui.Rect { x = X - 20, anchors = { vertical_center = true }, width = 40, height = 40, radius = 20,
            color = function()
              if s.down() then return C().onSurface:alpha(0.1) end
              return s.hovered() and C().onSurface:alpha(0.08) or C().onSurface:alpha(0)
            end,
            border_width = function() return t.visual_focus and s.current() and 2 or 0 end,
            border_color = function() return C().secondary end, behavior = { color = quick() } },
          ui.Rect { x = X - D / 2, anchors = { vertical_center = true }, width = D, height = D, radius = D / 2,
            color = "transparent", border_width = 2,
            border_color = function() return s.current() and C().primary or C().onSurfaceVariant end,
            behavior = { border_color = quick() } },
          M.text { x = 48, anchors = { vertical_center = true }, text = label_of(value),
            color = function() return C().onSurface end } }
      end,
    })
  end

  --- A toggle button group: rounded squares in the highest container;
  --- each one on fills with the primary and rounds into a pill on a
  --- spring. A short primary bar under the keyboard's entry slides along.
  function S.toggle_group(t, spec)
    local track = glide(t, function(x, y, w, h) return x + w / 2 - 8, y + h - 3, 16, 3 end)
    return delegated(spec, {
      background = nothing(),
      indicator = plate(track, 1.5, function() return C().primary end),
      item = function(_, value, s)
        local glyph = icon_of(value)
        local text = label_of(value)
        local function on() return s.selected() end
        local function ink() return on() and C().onPrimary or C().onSurfaceVariant end
        local function h() return (s.area and s.area.height or 40) - 10 end
        local look = ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true, left_margin = 2, right_margin = 2, top_margin = 2, bottom_margin = 8 },
            radius = function() return on() and h() / 2 or 10 end,
            color = function()
              local c = on() and C().primary or C().surfaceContainerHighest
              if s.down() then return c:mix(C().onSurface, 0.1) end
              return s.hovered() and c:mix(C().onSurface, 0.08) or c
            end,
            border_width = function() return t.visual_focus and s.current() and 2 or 0 end,
            border_color = function() return C().secondary end,
            behavior = { color = quick(), radius = pop } } }
        local box = ui.Item { anchors = { fill = true, bottom_margin = 6 } }
        if glyph and text == "" then
          ui.reparent(M.icon(glyph, 20, ink, { anchors = { center_in = true }, fill = on }), box)
        else
          ui.reparent(label(text, { anchors = { center_in = true }, color = ink }), box)
        end
        ui.reparent(box, look)
        return look
      end,
    })
  end

  -- ------------------------------------------------------------ lists --

  --- A list: the chosen row on a secondary-container plate with round
  --- ends that runs row to row, a primary check at its end.
  function S.list_selection(t, spec)
    local track = glide(t, inset(1))
    return delegated(spec, {
      background = nothing(),
      indicator = plate(track, 16, function() return C().secondaryContainer end),
      item = function(_, value, s)
        local glyph = icon_of(value)
        local function ink() return s.current() and C().onSecondaryContainer or C().onSurface end
        return ui.Item { anchors = { fill = true },
          state_layer(t, s, 16, { margins = 1 }),
          glyph and M.icon(glyph, 20, ink, { x = 14, anchors = { vertical_center = true } }) or nil,
          M.text { anchors = { fill = true, left_margin = glyph and 44 or 16, right_margin = 40 }, text = label_of(value),
            elide = "right", vertical_alignment = "center", color = ink, behavior = { color = quick() } },
          M.icon("check", 20, function() return C().primary end,
            { anchors = { right = true, right_margin = 12, vertical_center = true },
              opacity = function() return s.current() and 1 or 0 end, scale = function() return s.current() and 1 or 0.4 end,
              behavior = { opacity = quick(), scale = pop } }) }
      end,
    })
  end

  --- The navigation drawer: a full pill (the active indicator) runs to
  --- the chosen destination, its icon filling in.
  function S.sidebar_list(t, spec)
    local track = glide(t, inset(0))
    return delegated(spec, {
      background = nothing(),
      indicator = plate(track, round, function() return C().secondaryContainer end),
      item = function(_, value, s)
        local glyph = icon_of(value)
        local function ink() return s.current() and C().onSecondaryContainer or C().onSurfaceVariant end
        return ui.Item { anchors = { fill = true },
          state_layer(t, s, function() return (s.area and s.area.height or 0) / 2 end),
          glyph and M.icon(glyph, 22, ink, { x = 16, anchors = { vertical_center = true }, fill = s.current }) or nil,
          M.text(weighted({ anchors = { fill = true, left_margin = glyph and 50 or 18, right_margin = 12 }, text = label_of(value),
            elide = "right", vertical_alignment = "center", color = ink, behavior = { color = quick() } }, s.current)) }
      end,
    })
  end

  --- A transfer list's side: M3 check boxes for the marked rows (primary,
  --- the check popping in), the keyboard's row on a tonal plate.
  function S.transfer_side(t, spec)
    local track = glide(t, inset(1))
    return delegated(spec, {
      background = nothing(),
      indicator = plate(track, 12, function() return C().surfaceContainerHighest end),
      item = function(_, value, s)
        local function on() return s.selected() end
        return ui.Item { anchors = { fill = true },
          state_layer(t, s, 12, { margins = 1 }),
          ui.Rect { x = 12, anchors = { vertical_center = true }, width = 18, height = 18, radius = 2,
            color = function() return on() and C().primary or C().primary:alpha(0) end,
            border_width = function() return on() and 0 or 2 end,
            border_color = function() return C().onSurfaceVariant end, behavior = { color = quick() },
            M.icon("check", 16, function() return C().onPrimary end, { anchors = { center_in = true },
              scale = function() return on() and 1 or 0 end, behavior = { scale = pop } }) },
          M.text { anchors = { fill = true, left_margin = 44, right_margin = 8 }, text = label_of(value),
            elide = "right", vertical_alignment = "center", color = function() return C().onSurface end } }
      end,
    })
  end

  -- ------------------------------------------------------------ grids --

  --- Tiles in a container tone; the chosen one under a primary-container
  --- plate, rounder than the tiles, that travels tile to tile.
  function S.grid_selection(t, spec)
    local track = glide(t, inset(0))
    return delegated(spec, {
      background = nothing(),
      indicator = plate(track, function(h) return h * 0.36 end, function() return C().primaryContainer end),
      item = function(_, value, s)
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true, margins = 2 }, radius = 14,
            color = function()
              if s.current() then return C().surfaceContainerHigh:alpha(0) end
              local c = C().surfaceContainerHigh
              return s.hovered() and c:mix(C().onSurface, 0.08) or c
            end,
            border_width = function() return t.visual_focus and s.current() and 2 or 0 end,
            border_color = function() return C().secondary end, behavior = { color = quick() } },
          M.text { anchors = { center_in = true }, text = label_of(value), font_size = theme.size.large,
            color = function() return s.current() and C().onPrimaryContainer or C().onSurface end,
            behavior = { color = quick() } } }
      end,
    })
  end

  --- The date picker's days: the chosen one a primary disc that runs
  --- across the weeks and squashes where it lands.
  function S.day_grid(t, spec)
    local function size() return math.max(0, math.min(t.current_width, t.current_height) - 2) end
    local track = glide(t, function(x, y, w, h) local d = math.max(0, math.min(w, h) - 2) return x + (w - d) / 2, y + (h - d) / 2, d, d end)
    return delegated(spec, {
      background = nothing(),
      indicator = plate(track, round, function() return C().primary end),
      item = function(_, value, s)
        if label_of(value) == "" or (type(value) == "table" and value.blank) then return ui.Item {} end
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { center_in = true }, width = size, height = size, radius = 999,
            color = function() return (s.hovered() and not s.current()) and C().onSurface:alpha(0.08) or C().onSurface:alpha(0) end,
            border_width = function() return t.visual_focus and s.current() and 2 or 0 end,
            border_color = function() return C().secondary end },
          M.text { anchors = { center_in = true }, text = label_of(value), font_size = theme.size.small,
            color = function() return s.current() and C().onPrimary or C().onSurface end, behavior = { color = quick() } } }
      end,
    })
  end

  --- Colour swatches as discs; the chosen one turns into a scalloped
  --- cookie with a check while an outline ring runs round to it.
  function S.swatch_grid(t, spec)
    local track = glide(t, inset(0))
    return delegated(spec, {
      background = nothing(),
      indicator = plate(track, round, function() return C().onSurface:alpha(0) end, {
        ui.Rect { anchors = { fill = true }, color = "transparent", radius = function() return (track.height or 0) / 2 end,
          border_width = 2, border_color = function() return C().onSurface end } }),
      item = function(_, value, s)
        local color = type(value) == "table" and value.color or nil
        return ui.Item { anchors = { fill = true },
          M.shape { anchors = { fill = true, margins = 4 },
            shape = function() return s.current() and "cookie9" or "circle" end,
            color = function() return get(color) or C().primary end },
          M.icon("check", 18, function() return C().surface end, { anchors = { center_in = true },
            scale = function() return s.current() and 1 or 0 end, behavior = { scale = pop } }) }
      end,
    })
  end

  --- Emoji: each glyph large; the chosen one on a secondary-container disc.
  function S.emoji_grid(t, spec)
    local track = glide(t, inset(2))
    return delegated(spec, {
      background = nothing(),
      indicator = plate(track, round, function() return C().secondaryContainer end),
      item = function(_, value, s)
        return ui.Item { anchors = { fill = true },
          state_layer(t, s, 999, { margins = 2 }),
          M.text { anchors = { center_in = true }, text = type(value) == "table" and (value.emoji or value.label) or tostring(value),
            font_size = math.floor((spec.item_height or 40) * 0.55),
            scale = function() return s.current() and 1.1 or 1 end, behavior = { scale = pop } } }
      end,
    })
  end

  --- Icons to choose from: the chosen one filled, on a primary-container
  --- squircle that travels.
  function S.icon_chooser(t, spec)
    local track = glide(t, inset(2))
    return delegated(spec, {
      background = nothing(),
      indicator = plate(track, 16, function() return C().primaryContainer end),
      item = function(_, value, s)
        return ui.Item { anchors = { fill = true },
          state_layer(t, s, 16, { margins = 2 }),
          M.icon(icon_of(value) or label_of(value), 24,
            function() return s.current() and C().onPrimaryContainer or C().onSurfaceVariant end,
            { anchors = { center_in = true }, fill = s.current }) }
      end,
    })
  end

  -- ------------------------------------------------------ indicators --

  --- Page dots: the current one a primary pill that runs to its slide;
  --- the dots it passes melt into it while it moves, crisp at rest.
  function S.carousel_dots(t, spec)
    local field
    local track = glide(t, function(x, y, w, h) return x + w / 2 - 12, y + h / 2 - 4, 24, 8 end, function(duration)
      if not field then return end
      field.blend = 8
      morf.timer(duration, function() if field then field.blend = 0 end end, false)
    end)
    field = ui.Sdf { anchors = { fill = true }, blend = 0, behavior = { blend = { duration = 200 } },
      ui.SdfShape { shape = "box", radius = 4, track = track, operation = "smooth_union",
        fill_color = function() return C().primary end } }
    local dots = {}
    return delegated(spec, {
      background = nothing(),
      indicator = ui.Item { anchors = { fill = true }, field, track },
      item = function(index, _, s)
        if index == 1 then
          for _, shape in ipairs(dots) do ui.destroy(shape, true) end
          dots = {}
        end
        local dot = ui.Item { anchors = { center_in = true }, width = 8, height = 8 }
        dots[#dots + 1] = ui.SdfShape { shape = "circle", track = dot, operation = "smooth_union",
          fill_color = function() return C().onSurfaceVariant:alpha(s.hovered() and 0.7 or 0.38) end }
        ui.reparent(dots[#dots], field)
        return ui.Item { anchors = { fill = true }, dot }
      end,
    })
  end

  --- Page numbers: the current one a primary disc that runs along the
  --- row; the others in the variant tone with a state layer.
  function S.pagination(t, spec)
    local track = glide(t, function(x, y, w, h) local d = math.min(w, h) - 2 return x + (w - d) / 2, y + (h - d) / 2, d, d end)
    return delegated(spec, {
      background = nothing(),
      indicator = plate(track, round, function() return C().primary end),
      item = function(_, value, s)
        return ui.Item { anchors = { fill = true },
          state_layer(t, s, 999, { margins = 1 }),
          label(label_of(value), { anchors = { center_in = true },
            color = function() return s.current() and C().onPrimary or C().onSurfaceVariant end }) }
      end,
    })
  end

  --- A stepper: a numbered disc per step on an outline rail, primary up
  --- to the current one (a check on the passed ones), the rail's primary
  --- run growing to it, and a tonal halo that moves there.
  function S.stepper_header(t, spec)
    local D, TOP = 28, 8
    local track = glide(t, function(x, y, w) return x + w / 2 - D / 2 - 6, y + TOP - 6, D + 12, D + 12 end)
    local function n() return math.max(1, get(spec.count) or #(type(spec.items) == "function" and spec.items() or spec.items or {})) end
    local function first() return (t.current_width or 0) / 2 end
    local function last_x() return (t.current_width or 0) * (n() - 0.5) end
    return delegated(spec, {
      background = spec.delegate and nothing() or ui.Item { anchors = { fill = true },
        ui.Rect { y = TOP + D / 2 - 1, height = 2, radius = 1, x = first,
          width = function() return math.max(0, last_x() - first()) end, color = function() return C().outlineVariant end },
        ui.Rect { y = TOP + D / 2 - 1, height = 2, radius = 1, x = first,
          width = function() return math.max(0, (t.current_x or 0) + (t.current_width or 0) / 2 - first()) end,
          color = function() return C().primary end, behavior = { width = M.spring(300, 22) } } },
      indicator = plate(track, round, function() return C().primary:alpha(0.16) end),
      item = function(index, value, s)
        local function done() return index < t.current end
        local function lit() return index <= t.current end
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { horizontal_center = true }, y = TOP, width = D, height = D, radius = D / 2,
            color = function() return lit() and C().primary or C().surface end,
            border_width = function() return lit() and 0 or 2 end,
            border_color = function() return C().outline end, behavior = { color = quick() },
            label(tostring(index), { anchors = { center_in = true }, font_weight = 700,
              opacity = function() return done() and 0 or 1 end,
              color = function() return lit() and C().onPrimary or C().onSurfaceVariant end }),
            M.icon("check", 18, function() return C().onPrimary end, { anchors = { center_in = true },
              scale = function() return done() and 1 or 0 end, behavior = { scale = pop } }) },
          label(label_of(value), { anchors = { horizontal_center = true }, y = TOP + D + 6,
            font_weight = function() return s.current() and 700 or 500 end,
            color = function() return lit() and C().onSurface or C().onSurfaceVariant end }),
          ui.Rect { anchors = { fill = true }, radius = 12, color = "transparent",
            border_width = function() return t.visual_focus and s.current() and 2 or 0 end,
            border_color = function() return C().secondary end } }
      end,
    })
  end

  --- A path: the places with chevrons between, the chosen one on a tonal
  --- pill that runs to it.
  function S.breadcrumbs(t, spec)
    local track = glide(t, function(x, y, w, h)
      local lead = x > 0 and 18 or 0
      return x + lead + 2, y + 4, math.max(0, w - lead - 4), math.max(0, h - 8)
    end)
    return delegated(spec, {
      background = nothing(),
      indicator = plate(track, round, function() return C().secondaryContainer end),
      item = function(index, value, s)
        local lead = index > 1 and 18 or 0
        local text = M.text(weighted({ x = lead + 12, anchors = { vertical_center = true }, text = label_of(value),
          color = function() return s.current() and C().onSecondaryContainer or C().onSurfaceVariant end,
          behavior = { color = quick() } }, s.current))
        if s.area and not spec.item_width then
          s.area.width = function() return lead + 24 + (text.layout_width or 0) end
        end
        return ui.Item { anchors = { fill = true },
          index > 1 and M.icon("chevron_right", 18, function() return C().onSurfaceVariant end,
            { x = 0, anchors = { vertical_center = true } }) or nil,
          state_layer(t, s, function() return ((s.area and s.area.height or 8) - 8) / 2 end,
            { anchors = { fill = true, left_margin = lead + 2, right_margin = 2, top_margin = 4, bottom_margin = 4 } }),
          text }
      end,
    })
  end

  --- Rating stars in the primary, filled up to the chosen one, each
  --- popping past its size as it fills.
  function S.rating_items(t, spec)
    return delegated(spec, {
      background = nothing(),
      indicator = nothing(),
      item = function(index, _, s)
        local function on() return t.current >= index end
        return ui.Item { anchors = { fill = true },
          state_layer(t, s, 999, { margins = 2 }),
          M.icon("star", 28, function() return on() and C().primary or C().onSurfaceVariant end,
            { anchors = { center_in = true }, fill = on,
              scale = function() return on() and 1 or 0.82 end, behavior = { scale = pop } }) }
      end,
    })
  end

  -- ------------------------------------------------------- on a circle --

  --- The angle the current entry's sector points at, turning the shorter
  --- way round: a binding for a highlight's rotation.
  local function heading(t)
    local at = 0
    return function()
      local n = math.max(1, t.count or 1)
      if (t.current or 0) < 1 then return at end
      local target = (t.current - 1) * 360 / n
      at = at + ((target - at) + 180) % 360 - 180
      return at
    end
  end
  local function current_label(t, spec)
    return function()
      local items = spec.items
      if type(items) == "function" then items = items() end
      local v = (items or {})[t.current or 0]
      return v and label_of(v) or ""
    end
  end
  -- The hub's shapes, one per entry, so a new pick morphs it.
  local HUB = { "cookie9", "sunny", "clover4", "pentagon", "flower", "soft_burst", "cookie6", "gem" }

  --- The sectors of a pie of `n`, parted by `gap` degrees and cut round a
  --- hub of `inner` (+ `gap` px): one wedge per sector, each turned to its
  --- place about the disc's centre, unioned in one field.
  local function sectors(n, inner, gap)
    local out = {}
    for k = 1, n do
      out[#out + 1] = ui.SdfShape { shape = "pie", anchors = { fill = true }, angle = 360 / n - gap,
        rotation = (k - 1) * 360 / n }
    end
    out[#out + 1] = ui.SdfShape { shape = "circle", anchors = { center_in = true }, operation = "subtract",
      width = 2 * (inner + 3), height = 2 * (inner + 3) }
    return out
  end

  --- A radial menu: a surfaceContainerLow disc on an outlineVariant
  --- hairline, a secondaryContainer sector (one distance-field wedge) that
  --- swings on the spatial spring to the entry pointed at, the icons round
  --- the rim, and a primary hub whose M3 shape morphs with each pick and
  --- names it.
  function S.radial_menu(t, spec)
    local inner = t.inner or 36
    return {
      background = ui.Sdf { anchors = { fill = true }, fill_color = function() return C().surfaceContainerLow end,
        stroke_color = function() return C().outlineVariant end, stroke_width = 1,
        shadow_color = function() return C().shadow:alpha(0.18) end, shadow_blur = 6, shadow_offset_y = 2,
        ui.SdfShape { shape = "circle", anchors = { fill = true, margins = 1 } } },
      indicator = ui.Item { anchors = { fill = true },
        ui.Item { anchors = { fill = true }, rotation = heading(t), behavior = { rotation = M.spring(300, 20) },
          opacity = function() return (t.current or 0) > 0 and 1 or 0 end,
          ui.Sdf { anchors = { fill = true, margins = 5 }, fill_color = function() return C().secondaryContainer end,
            ui.SdfShape { shape = "pie", anchors = { fill = true },
              angle = function() return 360 / math.max(1, t.count or 1) - 4 end },
            ui.SdfShape { shape = "circle", anchors = { center_in = true }, operation = "subtract",
              width = 2 * inner + 8, height = 2 * inner + 8 } } },
        ui.Item { anchors = { center_in = true }, width = 2 * inner - 4, height = 2 * inner - 4,
          ui.Sdf { anchors = { fill = true }, fill_color = function() return C().primary end,
            M.sdf_shape { anchors = { fill = true },
              shape = function() return HUB[((t.current or 1) - 1) % #HUB + 1] end, duration = 450 } },
          M.text { anchors = { center_in = true }, width = 2 * inner - 18, horizontal_alignment = "center",
            elide = "right", text = current_label(t, spec), font_size = theme.size.small, font_weight = 500,
            color = function() return C().onPrimary end } },
        ui.Rect { anchors = { center_in = true }, width = 2 * inner + 4, height = 2 * inner + 4, radius = inner + 2,
          color = "transparent", border_width = 2, border_color = function() return C().secondary end,
          visible = function() return t.visual_focus end } },
      item = function(_, value, s)
        local glyph = icon_of(value)
        local function ink() local c = C() return s.current() and c.onSecondaryContainer or c.onSurfaceVariant end
        local look = ui.Item { anchors = { fill = true },
          scale = function() return s.current() and 1.14 or 1 end, behavior = { scale = pop } }
        if glyph then
          ui.reparent(M.icon(glyph, 24, ink, { anchors = { center_in = true }, fill = s.current }), look)
        else
          ui.reparent(M.text { anchors = { center_in = true }, text = label_of(value), font_size = theme.size.small,
            font_weight = 500, color = ink }, look)
        end
        return look
      end,
    }
  end

  --- A pie menu: surfaceContainerHigh sectors on a shadow, parted by
  --- gaps (one field of wedges), the one pointed at in the
  --- primary (one wedge, swung to it), each entry's icon over its label,
  --- and a hub to let go in. It blooms out from the pointer as it opens.
  function S.pie_menu(t, spec)
    local D = 2 * (t.outer or 120)
    local inner = t.inner or 40
    local disc = ui.Item { anchors = { fill = true } }
    local seen, made = nil, nil
    morf.effect(key("pie.disc"), function()
      local n = math.max(1, t.count or 1)
      if n == seen then return end
      seen = n
      if made then ui.destroy(made, true) end
      local props = { anchors = { fill = true, margins = 6 }, fill_color = function() return C().surfaceContainerHigh end,
        shadow_color = function() return C().shadow:alpha(0.3) end, shadow_blur = 6, shadow_offset_y = 2 }
      for _, shape in ipairs(sectors(n, inner, 3)) do props[#props + 1] = shape end
      made = ui.Sdf(props)
      ui.reparent(made, disc)
    end, { owner = disc })
    local grow = ui.Item { anchors = { fill = true }, disc,
      ui.Item { anchors = { fill = true }, rotation = heading(t), behavior = { rotation = M.spring(300, 20) },
        opacity = function() return (t.current or 0) > 0 and 1 or 0 end,
        ui.Sdf { anchors = { fill = true, margins = 6 }, fill_color = function() return C().primary end,
          ui.SdfShape { shape = "pie", anchors = { fill = true },
            angle = function() return 360 / math.max(1, t.count or 1) - 1.5 end },
          ui.SdfShape { shape = "circle", anchors = { center_in = true }, operation = "subtract",
            width = 2 * inner + 6, height = 2 * inner + 6 } } },
      ui.Item { anchors = { center_in = true }, width = 2 * inner - 6, height = 2 * inner - 6,
        ui.Sdf { anchors = { fill = true }, fill_color = function() return C().secondaryContainer end,
          M.sdf_shape { anchors = { fill = true }, shape = function() return t.visual_focus and "cookie9" or "circle" end } },
        M.icon("close", 20, function() return C().onSecondaryContainer end, { anchors = { center_in = true } }) } }
    morf.effect(key("pie.open"), function()
      if t.open then
        morf.animation.play { { parallel = {
          { node = grow, property = "scale", from = 0.5, to = 1, duration = 380, easing = theme.ease.emphasized_decel },
          { node = grow, property = "rotation", from = -30, to = 0, duration = 380, easing = theme.ease.emphasized_decel },
          { node = grow, property = "opacity", from = 0, to = 1, duration = 160 } } } }
      end
    end, { owner = grow })
    return {
      background = grow,
      indicator = nothing(),
      item = function(_, value, s)
        local glyph = icon_of(value)
        local function ink() local c = C() return s.current() and c.onPrimary or c.onSurface end
        local column = { anchors = { center_in = true }, gap = 2, align = "center" }
        if glyph then column[#column + 1] = M.icon(glyph, 22, ink, { fill = s.current }) end
        column[#column + 1] = M.text { text = label_of(value), font_size = theme.size.small, font_weight = 500, color = ink }
        return ui.Item { anchors = { fill = true }, ui.Column(column) }
      end,
    }
  end

  -- ----------------------------------------------------------- tumbler --

  --- A tumbler: the entries fold over a drum (the glue's), the centre row
  --- on a secondaryContainer pill; the entry there in its ink and medium
  --- weight, the rest onSurfaceVariant.
  function S.tumbler(t, spec)
    local row = t.row or 36
    return {
      background = nothing(),
      indicator = ui.Rect { anchors = { left = true, right = true, vertical_center = true }, height = row,
        radius = row / 2, color = function() return C().secondaryContainer end,
        border_width = function() return t.visual_focus and 2 or 0 end,
        border_color = function() return C().secondary end },
      item = function(_, value, s)
        return M.text { anchors = { fill = true }, text = label_of(value), horizontal_alignment = "center",
          vertical_alignment = "center", font_size = theme.size.larger,
          axes = function() return { opsz = theme.size.larger * 3 / 4, ROND = 25, wght = s.current() and 500 or 400 } end,
          color = function() local c = C() return s.current() and c.onSecondaryContainer or c.onSurfaceVariant end }
      end,
    }
  end
end
