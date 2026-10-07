-- Tsugumori's looks for each Selection widget: square, framed, technical --
-- hairline frames, mono capitals, numbered slots, hatched runs, block
-- fills, corner brackets. Each keeps the archetype's layout and moves one
-- thing between the entries: a block, a bar, a bracket frame or the list
-- instrument (hud.selection), riding a track whose leading edge snaps
-- across first and whose trailing edge follows -- a shutter, not a spring.
-- A configuration's own `delegate` keeps its entries; only the ground is
-- drawn round them.
local morf = require("morf")
local ui = require("morf.ui")
local stripes = require("themes.tsugumori.stripes")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local function get(v) if type(v) == "function" then return v() end return v end
  local quick = { duration = 140, easing = "out_cubic" }
  local function label_of(v)
    if type(v) == "table" then return tostring(v.label or v.name or v.text or v.caption or v.title or "") end
    return tostring(v)
  end
  local function icon_of(v) return type(v) == "table" and v.icon or nil end
  local function nothing() return ui.Item {} end
  local seq = 0
  local function key(name) seq = seq + 1 return "tsugumori.selection." .. name .. "." .. seq end

  -- --------------------------------------------------------- travel --

  local N = 14
  local function expo(u) return u >= 1 and 1 or 1 - 2 ^ (-10 * u) end
  local function cubic(u) return 1 - (1 - u) ^ 3 end
  --- Moves `node` from box `a` to box `b` ({x, y, w, h}): the leading edge
  --- of each axis on an exponential snap in the first 45 %, the trailing
  --- one on a cubic from a quarter of the way.
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
            local k = leading and expo(math.min(1, u / 0.45)) or cubic(math.max(0, (u - 0.25) / 0.75))
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

  --- A track (any node: it may draw) following the current entry's box
  --- through `fit(x, y, w, h)`.
  local function glide(t, fit, track)
    track = track or ui.Item {}
    track.visible = function() return t.current > 0 end
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
        running = travel(track, { track.x or last[1], track.y or last[2], track.width or last[3],
          track.height or last[4] }, box, math.floor(math.min(380, 220 + far * 0.4)))
      end
      last = box
    end, { owner = track })
    return track
  end

  local function inset(d) return function(x, y, w, h) return x + d, y + d, math.max(0, w - 2 * d), math.max(0, h - 2 * d) end end

  --- A square block on `track`: `fill` (a colour binding), `edge` (a
  --- frame colour), `hatch` (a hatched run inside, its colour), `corners`.
  local function block(track, o)
    o = o or {}
    local parts = {}
    if o.fill then
      parts[#parts + 1] = ui.Sdf { anchors = { fill = true },
        ui.SdfShape { shape = "box", radius = 0, track = track, fill_color = o.fill } }
    end
    if o.hatch then
      ui.reparent(ui.Item { anchors = { fill = true }, clip = true,
        stripes.box { width = 480, height = 120, gap = 7, weight = 2, color = o.hatch } }, track)
    end
    if o.edge then
      ui.reparent(ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
        border_color = o.edge }, track)
    end
    if o.corners then
      ui.reparent(hud().corners { length = o.corners, weight = 2, color = function() return C.primary end }, track)
    end
    parts[#parts + 1] = track
    return ui.Item { anchors = { fill = true }, table.unpack(parts) }
  end

  --- An entry's frame: a hairline brighter under the pointer, a faint
  --- wash pressed or hovered, the keyboard's brackets on the current one.
  local function frame(t, s, props)
    props = props or {}
    return ui.Item { anchors = props.anchors or { fill = true },
      ui.Rect { anchors = { fill = true }, color = function()
          return C.primary:alpha(s.down() and .18 or (s.hovered() and .055 or 0)) end,
        behavior = { color = quick } },
      props.bare and nil or ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
        border_color = function() return s.hovered() and stroke(C, "hover") or stroke(C, "quiet") end,
        behavior = { border_color = { duration = 180 } } },
      hud().corners { length = 5, weight = 2, color = function() return C.primary end,
        visible = function() return t.visual_focus and s.current() end } }
  end

  local function caps(text, props)
    props = props or {}
    props.text = tostring(text):upper()
    return M.menu_label(props)
  end

  local function delegated(spec, slots)
    if spec.delegate then slots.indicator = nothing() end
    return slots
  end

  -- --------------------------------------------------- linked choices --

  --- A framed row of capitals split by hairlines; the chosen one a primary
  --- block that shutters across to it.
  function S.segmented(t, spec)
    local track = glide(t, inset(2))
    return delegated(spec, {
      background = ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
        border_color = function() return stroke(C, "idle") end },
      indicator = block(track, { fill = function() return C.primary end }),
      item = function(index, value, s)
        local glyph = icon_of(value)
        local text = label_of(value)
        local function ink() return s.current() and C.onPrimary or C.onSurface end
        local vertical = spec.orientation == "vertical"
        local look = ui.Item { anchors = { fill = true }, frame(t, s, { bare = true }),
          ui.Rect { visible = index > 1, color = function() return stroke(C, "idle") end,
            width = vertical and nil or 1, height = vertical and 1 or nil,
            anchors = vertical and { left = true, right = true, top = true, left_margin = 6, right_margin = 6 }
              or { left = true, top = true, bottom = true, top_margin = 6, bottom_margin = 6 } } }
        if glyph and text == "" then
          ui.reparent(M.icon(glyph, 18, ink, { anchors = { center_in = true } }), look)
        else
          ui.reparent(caps(text, { anchors = { center_in = true }, color = ink }), look)
        end
        return look
      end,
    })
  end

  --- Framed view slots, an icon over a capital name; the chosen slot's
  --- top edge a primary bar over a hatched run, both travelling.
  function S.view_switcher(t, spec)
    local track = glide(t, inset(0))
    ui.reparent(ui.Rect { anchors = { left = true, right = true, top = true }, height = 2,
      color = function() return C.primary end }, track)
    return delegated(spec, {
      background = nothing(),
      indicator = block(track, { hatch = function() return C.primary:alpha(.22) end }),
      item = function(_, value, s)
        local function ink() return s.current() and C.primary or C.onSurface end
        return ui.Item { anchors = { fill = true },
          frame(t, s),
          ui.Column { anchors = { center_in = true }, gap = 4, align = "center",
            M.icon(icon_of(value) or "circle", 18, ink, { fill = s.current }),
            caps(label_of(value), { color = ink }) } }
      end,
    })
  end

  --- A framed strip, the icon beside the capital name; the chosen one
  --- inside travelling corner brackets over a faint primary wash.
  function S.inline_view_switcher(t, spec)
    local track = glide(t, inset(3))
    return delegated(spec, {
      background = ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
        border_color = function() return stroke(C, "idle") end },
      indicator = block(track, { fill = function() return C.primary:alpha(.14) end, corners = 6 }),
      item = function(_, value, s)
        local glyph = icon_of(value)
        local function ink() return s.current() and C.primary or C.onSurface end
        return ui.Item { anchors = { fill = true },
          frame(t, s, { bare = true }),
          ui.Row { anchors = { center_in = true }, gap = 6, align = "center",
            glyph and M.icon(glyph, 16, ink) or nil,
            caps(label_of(value), { color = ink }) } }
      end,
    })
  end

  --- Numbered choices, each with a square socket; one primary pip drops
  --- from socket to socket.
  function S.radio_group(t, spec)
    local track = glide(t, function(x, y, w, h) return x + 17, y + h / 2 - 4, 8, 8 end)
    return delegated(spec, {
      background = nothing(),
      indicator = block(track, { fill = function() return C.primary end }),
      item = function(index, value, s)
        return ui.Item { anchors = { fill = true },
          frame(t, s, { bare = true }),
          ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
            color = function() return stroke(C, "quiet") end },
          ui.Rect { x = 14, anchors = { vertical_center = true }, width = 14, height = 14, color = "transparent",
            border_width = 1, border_color = function() return s.current() and C.primary or stroke(C, "hover") end },
          caps(("%02d"):format(index), { x = 40, anchors = { vertical_center = true },
            color = function() return C.onSurfaceVariant end }),
          caps(label_of(value), { x = 70, anchors = { vertical_center = true },
            color = function() return s.current() and C.primary or C.onSurface end }) }
      end,
    })
  end

  --- Framed toggles: each one on hatched inside a primary frame; the
  --- keyboard's brackets travel between them.
  function S.toggle_group(t, spec)
    local track = glide(t, inset(-2))
    return delegated(spec, {
      background = nothing(),
      indicator = block(track, { corners = 6 }),
      item = function(_, value, s)
        local glyph = icon_of(value)
        local text = label_of(value)
        local function on() return s.selected() end
        local function ink() return on() and C.primary or C.onSurface end
        local look = ui.Item { anchors = { fill = true, margins = 2 },
          ui.Item { anchors = { fill = true }, clip = true, opacity = function() return on() and 1 or 0 end,
            behavior = { opacity = quick },
            stripes.box { width = 120, height = 120, gap = 6, weight = 2, color = function() return C.primary:alpha(.28) end } },
          frame(t, s),
          ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
            border_color = function() return C.primary end, opacity = function() return on() and 1 or 0 end,
            behavior = { opacity = quick } } }
        if glyph and text == "" then
          ui.reparent(M.icon(glyph, 18, ink, { anchors = { center_in = true } }), look)
        else
          ui.reparent(caps(text, { anchors = { center_in = true }, color = ink }), look)
        end
        return look
      end,
    })
  end

  -- ------------------------------------------------------------ lists --

  --- A list: hairlines between rows, and the list instrument -- a plate
  --- with a primary edge, brackets, a hatched strip and a scanline pass
  --- where it lands -- travelling row to row.
  function S.list_selection(t, spec)
    local track = glide(t, inset(0))
    local indicator = ui.Item { anchors = { fill = true }, track }
    if not spec.delegate then ui.reparent(hud().selection { track = track }, indicator) end
    return delegated(spec, {
      background = nothing(),
      indicator = indicator,
      item = function(index, value, s)
        return ui.Item { anchors = { fill = true },
          frame(t, s, { bare = true }),
          ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
            color = function() return stroke(C, "quiet") end },
          caps(("%02d"):format(index), { x = 14, anchors = { vertical_center = true },
            color = function() return C.onSurfaceVariant end }),
          caps(label_of(value), { x = 44, anchors = { vertical_center = true },
            color = function() return s.current() and C.primary or C.onSurface end }) }
      end,
    })
  end

  --- A sidebar: an icon and a capital name per row; a faint plate with a
  --- primary edge travels to the chosen row.
  function S.sidebar_list(t, spec)
    local track = glide(t, inset(0))
    ui.reparent(ui.Rect { anchors = { left = true, top = true, bottom = true }, width = 3,
      color = function() return C.primary end }, track)
    return delegated(spec, {
      background = nothing(),
      indicator = block(track, { fill = function() return C.primary:alpha(.12) end }),
      item = function(_, value, s)
        local glyph = icon_of(value)
        local function ink() return s.current() and C.primary or C.onSurface end
        return ui.Item { anchors = { fill = true },
          frame(t, s, { bare = true }),
          glyph and M.icon(glyph, 18, ink, { x = 14, anchors = { vertical_center = true }, fill = s.current }) or nil,
          caps(label_of(value), { x = glyph and 44 or 14, anchors = { vertical_center = true }, color = ink }) }
      end,
    })
  end

  --- A transfer list's side: numbered rows with square marks (filled for
  --- the marked ones), the keyboard's row under a travelling edge.
  function S.transfer_side(t, spec)
    local track = glide(t, inset(0))
    ui.reparent(ui.Rect { anchors = { left = true, top = true, bottom = true }, width = 2,
      color = function() return C.primary end }, track)
    return delegated(spec, {
      background = nothing(),
      indicator = block(track, { fill = function() return C.primary:alpha(.08) end }),
      item = function(index, value, s)
        local function on() return s.selected() end
        return ui.Item { anchors = { fill = true },
          frame(t, s, { bare = true }),
          ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
            color = function() return stroke(C, "quiet") end },
          ui.Rect { x = 14, anchors = { vertical_center = true }, width = 14, height = 14,
            color = "transparent", border_width = 1, border_color = function() return on() and C.primary or stroke(C, "hover") end,
            ui.Rect { anchors = { fill = true, margins = 3 }, color = function() return C.primary end,
              opacity = function() return on() and 1 or 0 end, behavior = { opacity = quick } } },
          caps(("%02d"):format(index), { x = 40, anchors = { vertical_center = true },
            color = function() return C.onSurfaceVariant end }),
          caps(label_of(value), { x = 70, anchors = { vertical_center = true },
            color = function() return on() and C.primary or C.onSurface end }) }
      end,
    })
  end

  -- ------------------------------------------------------------ grids --

  --- Framed cells, each numbered in its corner; the chosen one inside a
  --- primary frame with brackets over a faint wash, travelling.
  function S.grid_selection(t, spec)
    local track = glide(t, inset(0))
    return delegated(spec, {
      background = nothing(),
      indicator = block(track, { fill = function() return C.primary:alpha(.14) end,
        edge = function() return C.primary end, corners = 7 }),
      item = function(index, value, s)
        return ui.Item { anchors = { fill = true, margins = 0 },
          frame(t, s),
          caps(("%02d"):format(index), { x = 5, y = 3, color = function() return C.onSurfaceVariant end }),
          M.text { anchors = { center_in = true }, text = label_of(value), font_size = theme.size.large,
            color = function() return s.current() and C.primary or C.onSurface end } }
      end,
    })
  end

  --- A month on a hairline lattice; the blanks hatched; the chosen day a
  --- primary block that shutters across the weeks.
  function S.day_grid(t, spec)
    local track = glide(t, inset(1))
    return delegated(spec, {
      background = nothing(),
      indicator = block(track, { fill = function() return C.primary end }),
      item = function(_, value, s)
        local text = label_of(value)
        if text == "" or (type(value) == "table" and value.blank) then
          return ui.Item { anchors = { fill = true },
            ui.Item { anchors = { fill = true, margins = 1 }, clip = true,
              stripes.box { width = 80, height = 80, gap = 6, weight = 1, color = function() return stroke(C, "quiet") end } },
            ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
              border_color = function() return stroke(C, "quiet") end } }
        end
        local n = tonumber(text)
        return ui.Item { anchors = { fill = true },
          frame(t, s),
          caps(n and ("%02d"):format(n) or text, { anchors = { center_in = true },
            color = function() return s.current() and C.onPrimary or C.onSurface end }) }
      end,
    })
  end

  --- Square swatches; a primary frame with brackets travels round the
  --- chosen one.
  function S.swatch_grid(t, spec)
    local track = glide(t, inset(0))
    return delegated(spec, {
      background = nothing(),
      indicator = block(track, { edge = function() return C.primary end, corners = 6 }),
      item = function(_, value, s)
        local color = type(value) == "table" and value.color or nil
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true, margins = 4 }, color = function() return get(color) or C.primary end },
          ui.Rect { anchors = { fill = true, margins = 4 }, color = "transparent", border_width = 1,
            border_color = function() return s.hovered() and C.onSurface or stroke(C, "quiet") end } }
      end,
    })
  end

  --- Emoji in framed cells; travelling brackets on the chosen one.
  function S.emoji_grid(t, spec)
    local track = glide(t, inset(0))
    return delegated(spec, {
      background = nothing(),
      indicator = block(track, { fill = function() return C.primary:alpha(.16) end, corners = 6 }),
      item = function(_, value, s)
        return ui.Item { anchors = { fill = true },
          frame(t, s),
          M.text { anchors = { center_in = true }, text = type(value) == "table" and (value.emoji or value.label) or tostring(value),
            font_size = math.floor((spec.item_height or 40) * 0.5) } }
      end,
    })
  end

  --- Symbols in framed cells; the chosen one a primary block with the
  --- symbol cut out of it.
  function S.icon_chooser(t, spec)
    local track = glide(t, inset(1))
    return delegated(spec, {
      background = nothing(),
      indicator = block(track, { fill = function() return C.primary end }),
      item = function(_, value, s)
        return ui.Item { anchors = { fill = true },
          frame(t, s),
          M.icon(icon_of(value) or label_of(value), 22, function() return s.current() and C.onPrimary or C.onSurface end,
            { anchors = { center_in = true }, fill = s.current }) }
      end,
    })
  end

  -- ------------------------------------------------------ indicators --

  --- Slide marks: square sockets, the current one a primary bar that
  --- shutters along them.
  function S.carousel_dots(t, spec)
    local track = glide(t, function(x, y, w, h) return x + w / 2 - 8, y + h / 2 - 3, 16, 6 end)
    return delegated(spec, {
      background = nothing(),
      indicator = block(track, { fill = function() return C.primary end }),
      item = function(_, _, s)
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { center_in = true }, width = 6, height = 6, color = "transparent", border_width = 1,
            border_color = function() return s.hovered() and C.primary or stroke(C, "hover") end } }
      end,
    })
  end

  --- Numbered page slots; the current one a primary block.
  function S.pagination(t, spec)
    local track = glide(t, inset(1))
    return delegated(spec, {
      background = nothing(),
      indicator = block(track, { fill = function() return C.primary end }),
      item = function(_, value, s)
        local n = tonumber(label_of(value))
        return ui.Item { anchors = { fill = true },
          frame(t, s),
          caps(n and ("%02d"):format(n) or label_of(value), { anchors = { center_in = true },
            color = function() return s.current() and C.onPrimary or C.onSurface end }) }
      end,
    })
  end

  --- A stepper: framed numbered segments -- passed ones hatched, the
  --- current one solid primary, the rest bare -- over a tick ruler, with a
  --- primary bar under the current segment.
  function S.stepper_header(t, spec)
    local function n() return math.max(1, get(spec.count) or #(type(spec.items) == "function" and spec.items() or spec.items or {})) end
    local track = glide(t, function(x, y, w, h) return x + 2, y + h - 6, math.max(0, w - 4), 2 end)
    return delegated(spec, {
      background = ui.Item { y = function() return (t.current_height or 0) - 4 end, height = 4, clip = true,
        width = function() return (t.current_width or 0) * n() end,
        ui.Path { x = 0, y = 0, width = 800, height = 4,
          view_box = { 0, 0, 800, 4 }, d = morf.geometry.ruler(800, 4, { pitch = 8, major = 5, min_count = 4 }),
          fill_color = "transparent", stroke_color = function() return stroke(C, "idle") end, stroke_width = 1 } },
      indicator = block(track, { fill = function() return C.primary end }),
      item = function(index, value, s)
        local function done() return index < t.current end
        local function lit() return index == t.current end
        local function ink() return lit() and C.onPrimary or (done() and C.primary or C.onSurfaceVariant) end
        return ui.Item { anchors = { fill = true, left_margin = 2, right_margin = 2, bottom_margin = 10 },
          ui.Item { anchors = { fill = true }, clip = true, opacity = function() return done() and 1 or 0 end,
            behavior = { opacity = quick },
            stripes.box { width = 160, height = 80, gap = 7, weight = 2, color = function() return C.primary:alpha(.24) end } },
          ui.Rect { anchors = { fill = true }, color = function() return C.primary end,
            opacity = function() return lit() and 1 or 0 end, behavior = { opacity = quick } },
          frame(t, s),
          caps(("%02d"):format(index), { x = 8, y = 6, color = ink }),
          caps(label_of(value), { x = 8, anchors = { bottom = true, bottom_margin = 6 }, color = ink,
            width = function() return math.max(0, (s.area and s.area.width or 80) - 20) end, elide = "right" }) }
      end,
    })
  end

  --- A path of capitals split by slashes; a primary bar under the chosen
  --- place shutters along it.
  function S.breadcrumbs(t, spec)
    local track = glide(t, function(x, y, w, h)
      local lead = x > 0 and 20 or 0
      return x + lead + 6, y + h - 5, math.max(0, w - lead - 12), 2
    end)
    return delegated(spec, {
      background = nothing(),
      indicator = block(track, { fill = function() return C.primary end }),
      item = function(index, value, s)
        local lead = index > 1 and 20 or 0
        local text = caps(label_of(value), { x = lead + 8, anchors = { vertical_center = true },
          color = function() return s.current() and C.primary or C.onSurface end })
        if s.area and not spec.item_width then
          s.area.width = function() return lead + 16 + (text.layout_width or 0) end
        end
        return ui.Item { anchors = { fill = true },
          index > 1 and caps("/", { x = 6, anchors = { vertical_center = true },
            color = function() return stroke(C, "focus") end }) or nil,
          frame(t, s, { bare = true, anchors = { fill = true, left_margin = lead } }),
          text }
      end,
    })
  end

  --- A rating as diamonds: framed, solid primary up to the chosen one.
  function S.rating_items(t, spec)
    return delegated(spec, {
      background = nothing(),
      indicator = nothing(),
      item = function(index, _, s)
        local function on() return t.current >= index end
        return ui.Item { anchors = { fill = true },
          frame(t, s, { bare = true }),
          ui.Rect { anchors = { center_in = true }, width = 14, height = 14, rotation = 45,
            color = function() return on() and C.primary or C.primary:alpha(0) end,
            border_width = 1, border_color = function() return on() and C.primary or stroke(C, "hover") end,
            scale = function() return on() and 1 or 0.8 end,
            behavior = { color = quick, scale = { duration = 220, easing = "out_back" } } } }
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
      return v and label_of(v):upper() or ""
    end
  end
  -- The shutter the highlight turns on.
  local turn = { duration = 260, easing = "out_expo" }

  --- Ticks on the boundaries between `n` sectors of a disc `D` across:
  --- rotated hairlines, `from` px in from the rim, `len` long; rebuilt only
  --- when the count changes.
  local function ticks(t, D, from, len, color, weight)
    local holder = ui.Item { anchors = { fill = true } }
    local seen, made = nil, {}
    morf.effect(key("ticks"), function()
      local n = math.max(1, t.count or 1)
      if n == seen then return end
      seen = n
      for _, node in ipairs(made) do ui.destroy(node, true) end
      made = {}
      for k = 1, n do
        made[k] = ui.Item { anchors = { fill = true }, rotation = (k - 0.5) * 360 / n,
          ui.Rect { x = D / 2 - (weight or 1) / 2, y = from, width = weight or 1, height = len, color = color } }
        ui.reparent(made[k], holder)
      end
    end, { owner = holder })
    return holder
  end

  --- A radial menu: an instrument dial -- a hairline rim with ticks on the
  --- sector boundaries, a primary-outlined wedge (one distance field) that
  --- shutters round to the entry pointed at, the icons round the rim, and a
  --- plate in brackets at the hub naming the entry in caps.
  function S.radial_menu(t, spec)
    local D = 2 * (t.outer or 110)
    local inner = t.inner or 36
    -- The hub's plate: as wide as the hub's circle lets a caption be.
    local hub_w, hub_h = 2 * inner - 6, 30
    return delegated(spec, {
      background = ui.Item { anchors = { fill = true },
        ui.Sdf { anchors = { fill = true }, fill_color = function() return C.surfaceContainer end,
          stroke_color = function() return stroke(C, "idle") end, stroke_width = 1,
          ui.SdfShape { shape = "circle", anchors = { fill = true, margins = 1 } } },
        ui.Sdf { anchors = { fill = true, margins = 6 }, fill_color = function() return stroke(C, "quiet") end,
          ui.SdfShape { shape = "ring", anchors = { fill = true }, thickness = 1 } },
        ticks(t, D, 1, 9, function() return stroke(C, "corner") end, 2) },
      indicator = ui.Item { anchors = { fill = true },
        ui.Item { anchors = { fill = true }, rotation = heading(t), behavior = { rotation = turn },
          opacity = function() return (t.current or 0) > 0 and 1 or 0 end,
          ui.Sdf { anchors = { fill = true, margins = 6 }, fill_color = function() return C.primary:alpha(.14) end,
            stroke_color = function() return C.primary end, stroke_width = 1.5,
            ui.SdfShape { shape = "pie", anchors = { fill = true },
              angle = function() return 360 / math.max(1, t.count or 1) end },
            ui.SdfShape { shape = "circle", anchors = { center_in = true }, operation = "subtract",
              width = 2 * inner + 6, height = 2 * inner + 6 } } },
        ui.Item { anchors = { center_in = true }, width = hub_w, height = hub_h,
          ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerHigh end,
            border_width = 1, border_color = function() return stroke(C, "hover") end },
          hud().corners { length = 6, weight = 2, color = function() return C.primary end },
          M.text { anchors = { center_in = true }, width = hub_w - 6, horizontal_alignment = "center", elide = "right",
            text = current_label(t, spec), font_size = theme.typography.menu, font_weight = 500,
            color = function() return C.primary end } },
        hud().corners { length = 10, weight = 2, color = function() return C.primary end,
          visible = function() return t.visual_focus end } },
      item = function(_, value, s)
        local glyph = icon_of(value)
        local function ink() return s.current() and C.primary or C.onSurface end
        local look = ui.Item { anchors = { fill = true } }
        if glyph then
          ui.reparent(M.icon(glyph, 22, ink, { anchors = { center_in = true }, fill = s.current }), look)
        else
          ui.reparent(caps(label_of(value), { anchors = { center_in = true }, color = ink }), look)
        end
        return look
      end,
    })
  end

  --- A pie menu: a disc of the container tone in a hairline, ruled into
  --- sectors, inside registration brackets; the sector pointed at a
  --- primary block (one wedge, shuttered round to it) with its entry in
  --- the primary's ink; a square hub to let go in. It opens on a shutter.
  function S.pie_menu(t, spec)
    local D = 2 * (t.outer or 120)
    local inner = t.inner or 40
    local hub = math.floor(inner * 1.2)
    local grow = ui.Item { anchors = { fill = true },
      ui.Sdf { anchors = { fill = true, margins = 6 }, fill_color = function() return C.surfaceContainer end,
        stroke_color = function() return stroke(C, "hover") end, stroke_width = 1,
        ui.SdfShape { shape = "circle", anchors = { fill = true } } },
      ui.Item { anchors = { fill = true }, rotation = heading(t), behavior = { rotation = turn },
        opacity = function() return (t.current or 0) > 0 and 1 or 0 end,
        ui.Sdf { anchors = { fill = true, margins = 7 }, fill_color = function() return C.primary end,
          ui.SdfShape { shape = "pie", anchors = { fill = true },
            angle = function() return 360 / math.max(1, t.count or 1) end },
          ui.SdfShape { shape = "circle", anchors = { center_in = true }, operation = "subtract",
            width = 2 * inner, height = 2 * inner } } },
      ticks(t, D, 7, D / 2 - inner - 7, function() return stroke(C, "idle") end, 1),
      ui.Item { anchors = { center_in = true }, width = hub, height = hub,
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerHigh end,
          border_width = 1, border_color = function() return stroke(C, "hover") end },
        M.icon("close", 18, function() return C.onSurfaceVariant end, { anchors = { center_in = true } }) },
      hud().corners { length = 12, weight = 2, color = function() return t.visual_focus and C.primary or stroke(C, "corner") end } }
    morf.effect(key("pie.open"), function()
      if t.open then
        morf.animation.play { { parallel = {
          { node = grow, property = "scale", from = 0.8, to = 1, duration = 220, easing = "out_expo" },
          { node = grow, property = "opacity", from = 0, to = 1, duration = 120 } } } }
      end
    end, { owner = grow })
    return delegated(spec, {
      background = grow,
      indicator = nothing(),
      item = function(_, value, s)
        local glyph = icon_of(value)
        local function ink() return s.current() and C.onPrimary or C.onSurface end
        local column = { anchors = { center_in = true }, gap = 3, align = "center" }
        if glyph then column[#column + 1] = M.icon(glyph, 20, ink) end
        column[#column + 1] = caps(label_of(value), { color = ink })
        return ui.Item { anchors = { fill = true }, ui.Column(column) }
      end,
    })
  end

  -- ----------------------------------------------------------- tumbler --

  --- A tumbler: the entries fold over a drum (the glue's); the centre row
  --- ruled above and below, in brackets over a faint wash, the entry there
  --- in the primary, the rest dim.
  function S.tumbler(t, spec)
    local row = t.row or 36
    return delegated(spec, {
      background = ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
        border_color = function() return stroke(C, "quiet") end },
      indicator = ui.Item { anchors = { left = true, right = true, vertical_center = true }, height = row,
        ui.Rect { anchors = { fill = true }, color = function() return C.primary:alpha(.08) end },
        ui.Rect { anchors = { left = true, right = true, top = true }, height = 1,
          color = function() return stroke(C, "hover") end },
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
          color = function() return stroke(C, "hover") end },
        hud().corners { length = 6, weight = 2, color = function() return C.primary end,
          opacity = function() return t.visual_focus and 1 or 0.6 end } },
      item = function(_, value, s)
        return M.text { anchors = { fill = true }, text = label_of(value):upper(), horizontal_alignment = "center",
          vertical_alignment = "center", font_size = theme.size.larger, font_weight = 500,
          color = function() return s.current() and C.primary or C.onSurfaceVariant end }
      end,
    })
  end
end
