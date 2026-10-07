local stroke = require("themes.tsugumori.strokes")
-- Tsugumori's complete style kit (see the kit contract and THEMING.md). Framed, mechanical
-- controls: square frames, chamfered outlines cut on the top-left and
-- bottom-right, corner registration marks on the same diagonal, mono type,
-- rolling labels and quiet instrument rails. All fills and ink come from the
-- wallpaper palette and `theme.lule`; the reference's fixed red is not part
-- of this theme. Nothing here animates at rest.
local morf = require("morf")
local ui = require("morf.ui")
local channel = require("lib.util.channel")
local common = require("themes.kit_common")
local get, clamp01 = common.get, common.clamp01
return function(theme)
  local M = {}
  local C = theme.color
  local feedback = require("themes.tsugumori.interaction")(theme)
  local stripes = require("themes.tsugumori.stripes")
  local hud_parts
  local function hud() hud_parts = hud_parts or require("themes.tsugumori.hud")(theme, M) return hud_parts end
  local CH, MARK = theme.CHAMFER or 8, theme.MARK or 10
  local function settle() return { duration = theme.duration.large, easing = "out_cubic" } end

  -- ------------------------------------------------------------ colour --

  -- Status signals follow the desk's terminal palette (green, yellow, red,
  -- cyan, magenta); the accent is the wallpaper's primary.
  local SIGNAL = { ok = "color2", warn = "color3", alert = "color1", info = "color6", extra = "color5" }
  function M.signal(kind)
    return function()
      local k = get(kind)
      if k == "accent" or not SIGNAL[k] then return C.primary end
      local lule = theme.lule
      return lule and lule[SIGNAL[k]] or C.primary
    end
  end
  function M.ink(kind)
    if kind == "lo" then return function() return C.onSurfaceVariant end end
    if kind == "accent" then return function() return C.primary end end
    return function() return C.onSurface end
  end
  -- Line strengths, on the same accent ramp as strokes.lua.
  local STRENGTH = { faint = .06, quiet = .10, idle = .18, mark = .42, hot = .65 }
  function M.stroke(strength, color)
    local a = assert(STRENGTH[strength or "idle"], "unknown stroke strength")
    return function() return (color and get(color) or C.primary):alpha(a) end
  end
  function M.level(value, warn, alert)
    warn, alert = warn or 70, alert or 90
    local accent, w, a = M.signal("accent"), M.signal("warn"), M.signal("alert")
    return function()
      local v = tonumber(get(value)) or 0
      if v >= alert then return a() elseif v >= warn then return w() end
      return accent()
    end
  end

  -- ---------------------------------------------------------- geometry --

  --- The Tsugumori frame: a square box `w` x `h`, inset by `i` (half a
  --- hairline). (`c`, the old corner cut, is accepted and ignored: every
  --- edge is square.)
  local function frame_d(w, h, _, i)
    i = i or 0
    return ("M%g %g H%g V%g H%g Z"):format(i, i, w - i, h - i, i)
  end
  M.frame_path = frame_d
  --- Registration marks: filled Ls on the top-left and bottom-right corners.
  local function marks_d(w, h, l, t)
    t = t or 1
    local pts = { { 0, 0 }, { l, 0 }, { l, t }, { t, t }, { t, t }, { t, l }, { 0, l }, { 0, 0 } }
    local a, b = {}, {}
    for i, p in ipairs(pts) do
      local cmd = i == 1 and "M" or "L"
      a[#a + 1] = ("%s%.2f %.2f"):format(cmd, p[1], p[2])
      b[#b + 1] = ("%s%.2f %.2f"):format(cmd, w - p[1], h - p[2])
    end
    return table.concat(a, " ") .. " Z " .. table.concat(b, " ") .. " Z"
  end
  local function marks(w, h, l, color, props)
    props = props or {}
    props.width, props.height, props.view_box = w, h, { 0, 0, w, h }
    props.d = marks_d(w, h, l or MARK)
    props.fill_color = color or function() return stroke(C, "corner") end
    return ui.Path(props)
  end
  --- A registration mark in an `l` box: a square L.
  local function mark_d(l, t)
    t = t or 1
    return ("M0 0 H%g V%g H%g V%g H0 Z"):format(l, t, t, l)
  end
  M.mark_path = mark_d
  --- Anchored registration marks for a box of unknown size, on the
  --- top-left / bottom-right diagonal only.
  local function anchored_marks(l, color, inset, opacity)
    l, inset = l or MARK, inset or 0
    local d = mark_d(l)
    local function corner(anchors, rotation)
      anchors.left_margin, anchors.right_margin, anchors.top_margin, anchors.bottom_margin = inset, inset, inset, inset
      return ui.Path { anchors = anchors, width = l, height = l, view_box = { 0, 0, l, l }, d = d,
        rotation = rotation, fill_color = color or function() return stroke(C, "corner") end }
    end
    return ui.Item { anchors = { fill = true }, opacity = opacity,
      corner({ left = true, top = true }, 0), corner({ right = true, bottom = true }, 180) }
  end

  --- SVG path data for an arc of `sweep` degrees, clockwise from `from`
  --- degrees (0 at twelve o'clock), radius `r` about `(cx, cy)`, in pieces
  --- of at most 90 degrees.
  M.arc_path = morf.geometry.arc
  --- Short radial strokes at `angles`, from radius `r0` to `r1`.
  local function radials(cx, cy, r0, r1, angles)
    return morf.geometry.ticks(cx, cy, r0, r1, { angles = angles })
  end

  -- -------------------------------------------------------------- text --

  --- Text in the theme's mono face; `props` as a `ui.Text`'s.
  function M.text(props)
    props.font_family = props.font_family or theme.font
    if (theme.font_file or "") ~= "" and props.font_source == nil then props.font_source = theme.font_file end
    props.font_size = props.font_size or theme.size.normal
    if props.font_weight and props.axes == nil then props.axes = { wght = props.font_weight } end
    if props.color == nil then props.color = function() return C.onSurface end end
    return ui.Text(props)
  end

  --- A Material Symbols icon by its ligature name; `props.fill` (a boolean
  --- or a binding) fills it in.
  function M.icon(name, size, color, props)
    props = props or {}
    props.text = name
    -- A glyph's ligature ("arrow_back") is no word for a screen reader:
    -- the control around it is named instead, unless the icon is named.
    if props.accessible_name == nil and props.accessible_hidden == nil then props.accessible_hidden = true end
    props.font_family = theme.icon_font
    props.font_size = size or 18
    props.color = color or function() return C.onSurface end
    if props.fill ~= nil then
      local fill = props.fill
      props.fill = nil
      props.axes = function()
        local on = fill
        if type(fill) == "function" then on = fill() end
        return { FILL = on and 1 or 0 }
      end
      props.behavior = props.behavior or {}
      props.behavior.axes = { duration = theme.duration.small, easing = theme.ease.standard }
    end
    return ui.Text(props)
  end

  local heading_serial = 0
  local heading_viewports = {}
  -- Capture the surrounding scroll surfaces while constructing a page, even
  -- when those surfaces are created after their children. Nested page-local
  -- viewports add to this chain instead of replacing the outer clipping area.
  function M.with_viewport(viewport, build)
    local previous = heading_viewports
    heading_viewports = {table.unpack(previous)}
    heading_viewports[#heading_viewports + 1] = viewport
    local result = table.pack(pcall(build))
    heading_viewports = previous
    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
  end
  function M.heading(props)
    heading_serial = heading_serial + 1
    props.id = props.id or "tsugumori-heading-" .. heading_serial
    props.font_size = theme.typography[props.level or "title"] or theme.typography.title
    props.font_weight = 500
    props.color = props.ink or function() return C.primary end
    if not props.active and props.scope then props.active = require("presentation").active(props.scope) end
    props.viewports = {table.unpack(heading_viewports)}
    if props.viewport then props.viewports[#props.viewports + 1] = props.viewport end
    local node = require("themes.tsugumori.heading")(theme, M, props)
    -- A heading to a screen reader, by its words as they settle, not the
    -- letters that roll through on the way.
    node.accessible_role = "heading"
    node.accessible_name = type(props.text) == "function" and function() return tostring(props.text() or "") end
      or tostring(props.text or "")
    node.accessible = { level = props.level == "section" and 2 or 1 }
    return node
  end
  function M.subtitle(props)
    props.font_size, props.font_weight = theme.typography.subtitle, 400
    props.color = props.color or function() return C.onSurfaceVariant end
    return M.text(props)
  end
  function M.menu_label(props)
    props.font_size, props.font_weight = props.font_size or theme.typography.menu, 500
    return M.text(props)
  end
  function M.section_label(props)
    props.font_size, props.font_weight = theme.typography.label, 500
    props.color = props.color or function() return C.onSurfaceVariant end
    return M.text(props)
  end

  --- Micro label: caps, spaced mono. Text props + `size`.
  function M.label(props)
    local text = props.text
    local function caption() return tostring(get(text) or ""):upper() end
    props.text = caption
    props.font_size = props.font_size or props.size or theme.typography.label
    props.size = nil
    props.letter_spacing = props.letter_spacing or .6
    -- In a fixed box the mono run shrinks (to a floor) rather than spill
    -- past the box's edge: its advance is known, so no measuring node.
    if props.height == nil and type(props.font_size) == "number" then
      props.height = math.ceil(props.font_size * 1.4)
    end
    local w = props.width
    if type(w) == "number" and props.elide == nil then
      local size, spacing = props.font_size, props.letter_spacing
      if type(size) == "number" then
        props.font_size = function()
          local n = utf8.len(caption()) or 0
          if n == 0 then return size end
          local fit = (w / n - spacing) / .6
          return math.max(math.min(size, 8), math.min(size, math.floor(fit * 2) / 2))
        end
      end
    end
    props.color = props.color or M.ink("lo")
    return M.text(props)
  end

  --- A large reading: mono digits with the unit raised beside them.
  function M.readout(spec)
    local size = spec.size or theme.typography.hero
    local row = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, gap = 4, align = "start",
      M.text { text = spec.value, font_size = size, font_weight = 400,
        color = spec.color or M.ink("accent"), height = math.ceil(size * 1.2) },
    }
    if spec.unit then
      row[#row + 1] = M.label { text = spec.unit, font_size = math.max(9, math.floor(size * .38)),
        color = spec.unit_color or M.ink("lo") }
    end
    return ui.Row(row)
  end

  -- No codes inside menus and panels; the frame prints its own.
  function M.code() return "" end

  --- A caption row across `width`: a registration pip, the caps text, a
  --- hairline under the row and the note at its right.
  function M.caption(spec)
    local w = spec.width
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = 16,
      ui.Rect { y = 5, width = 5, height = 5, color = spec.color or M.ink("accent") },
      M.label { text = spec.text, x = 11, y = 0, height = 14, color = spec.color or M.ink("accent"),
        width = function() return math.max(0, get(w) - 90) end, elide = "right" },
      spec.note and M.label { text = spec.note, anchors = { right = true }, y = 0, height = 14,
        horizontal_alignment = "right" } or nil,
      ui.Rect { y = 15, width = w, height = 1, color = M.stroke("quiet") },
    }
  end

  --- Label / value lines, each over a faint hairline.
  function M.facts(rows, width, row_h, label_w)
    row_h = row_h or 22
    label_w = label_w or math.floor((get(width) or 300) * .4)
    local column = { gap = 0, width = width }
    for _, row in ipairs(rows) do
      column[#column + 1] = ui.Item { width = width, height = row_h,
        M.label { text = row[1], width = label_w - 6, height = row_h - 1, vertical_alignment = "center",
          elide = "right" },
        M.text { text = row[2], x = label_w, width = function() return math.max(0, get(width) - label_w) end,
          height = row_h - 1, vertical_alignment = "center", elide = "right", font_size = theme.size.small },
        ui.Rect { y = row_h - 1, width = width, height = 1, color = M.stroke("faint") },
      }
    end
    return ui.Column(column)
  end

  -- ------------------------------------------------------- containers --

  function M.surface(props)
    if props.border_width then props.border_color=function() return stroke(C,"idle") end end
    for _, key in ipairs { "radius", "top_left_radius", "top_right_radius", "bottom_left_radius", "bottom_right_radius" } do
      if props[key] ~= nil then props[key] = 0 end
      if props.behavior then props.behavior[key] = nil end
    end
    return ui.Rect(props)
  end

  --- While a collector is set (`M.collect(list)`), a card is an item whose
  --- background is a square layer of a distance field someone else builds:
  --- `list` gets `{ node, radius, color, shape }` for each.
  local collector
  function M.collect(list) collector = list end
  function M.card(props)
    props.radius = 0
    if props.color == nil then props.color = function() return C.surfaceContainer end end
    props[#props + 1] = ui.Rect {
      anchors = { fill = true }, color = "transparent", border_width = 1,
      border_color = function() return hud().line("faint")() end,
    }
    props[#props + 1] = hud().corners { length = 12, color = hud().line("hot") }
    if not collector then return ui.Rect(props) end
    local color = props.color
    props.radius, props.color = nil, nil
    local node = ui.Item(props)
    local entry = { node = node, radius = 0, color = color }
    entry.shape = ui.SdfShape {
      shape = "box", radius = 0, track = node,
      operation = #collector == 0 and "union" or "smooth_union",
      fill_color = color,
    }
    collector[#collector + 1] = entry
    return node
  end

  --- An item centred in a box of `w` x `h`.
  function M.centred(w, h, child, props)
    props = props or {}
    props.width, props.height = w, h
    child.anchors = { center_in = true }
    props[#props + 1] = child
    return ui.Item(props)
  end

  --- A framed region: a chamfered hairline outline with registration marks,
  --- an optional header strip or a caps title, and children.
  function M.panel(spec)
    local w, h = spec.width, spec.height
    local wn, hn = get(w), get(h)
    local sized = type(wn) == "number" and type(hn) == "number" and type(w) ~= "function" and type(h) ~= "function"
    local fill = function() return C.surfaceContainer:alpha(spec.fill or .6) end
    local node = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h, clip = spec.clip }
    if sized then
      node[#node + 1] = ui.Path { width = w, height = h, view_box = { 0, 0, w, h }, d = frame_d(w, h, CH, .5),
        fill_color = fill, stroke_color = spec.mark or M.stroke("idle", spec.color), stroke_width = 1,
        stroke_join = "miter" }
      node[#node + 1] = marks(w, h, MARK, M.stroke("mark", spec.color), { x = 0, y = 0 })
    else
      node[#node + 1] = ui.Rect { anchors = { fill = true }, color = fill, border_width = 1,
        border_color = spec.mark or M.stroke("idle", spec.color) }
      node[#node + 1] = anchored_marks(MARK, M.stroke("mark", spec.color))
    end
    if spec.header and type(wn) == "number" then
      node[#node + 1] = M.header { x = 12, y = 8, width = wn - 24, key = spec.id or spec.title,
        title = spec.title, status = spec.status, color = spec.color }
    elseif spec.title then
      node[#node + 1] = M.label { text = spec.title, x = 14, y = 10, font_size = theme.typography.caption,
        color = spec.color or M.ink("accent") }
    end
    for _, child in ipairs(spec) do node[#node + 1] = child end
    return ui.Item(node)
  end

  --- A panel's chrome strip: a registration pip, the caps title, the status
  --- (or the call-sign) at the right, and a hairline with an accent lead.
  function M.header(spec)
    local w = spec.width
    local color = spec.color or M.signal("accent")
    local title = spec.title or spec.key or ""
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = 22,
      ui.Rect { y = 6, width = 5, height = 5, color = color },
      M.label { text = title, x = 11, y = 0, height = 16, font_size = theme.typography.caption,
        color = M.ink("hi"), width = function() return math.max(0, get(w) - 100) end, elide = "right" },
      M.label { text = spec.status or M.code(spec.key or title), anchors = { right = true }, y = 1, height = 15,
        font_size = 9, horizontal_alignment = "right", color = spec.status and color or M.ink("lo") },
      ui.Rect { y = 21, width = w, height = 1, color = M.stroke("quiet", spec.color) },
      ui.Rect { y = 20, width = 24, height = 2, color = color },
    }
  end

  --- A small chamfered tag, outlined or filled.
  function M.chip(spec)
    local color = spec.color or M.signal("accent")
    local text = spec.text
    local w = spec.width or math.ceil(12 + 5.6 * utf8.len(tostring(get(text) or "")))
    local filled = spec.filled
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = 13,
      ui.Path { width = w, height = 13, view_box = { 0, 0, w, 13 }, d = frame_d(w, 13, 3, .5),
        fill_color = function() return filled and get(color) or get(color):alpha(0) end,
        stroke_color = color, stroke_width = 1, stroke_join = "miter" },
      M.label { text = text, x = 5, y = 0, height = 13, font_size = 8, vertical_alignment = "center",
        width = w - 9, elide = "right", letter_spacing = .5,
        color = filled and function() return C.surface end or color },
    }
  end

  --- Tsugumori decorations: registration `corners` (any box) and
  --- `brackets` (a sized box), and a hairline `grid`. Ticks, scales and
  --- hatching are not part of this style.
  function M.decor(name, spec)
    spec = spec or {}
    if name == "corners" or name == "brackets" then
      -- Four bright L-brackets on the box's corners.
      local node = hud().corners { length = spec.length or 10, color = spec.color or hud().line("hot"),
        inset = spec.inset, opacity = spec.opacity, id = spec.id }
      if type(spec.width) == "number" and type(spec.height) == "number" then
        return ui.Item { x = spec.x, y = spec.y, width = spec.width, height = spec.height, node }
      end
      return node
    elseif name == "grid" and type(spec.width) == "number" and type(spec.height) == "number" then
      local w, h = spec.width, spec.height
      local cols, rows = spec.columns or 8, spec.rows or 4
      local d = {}
      for k = 1, cols - 1 do d[#d + 1] = ("M%.1f 0 V%g "):format(w * k / cols, h) end
      for k = 1, rows - 1 do d[#d + 1] = ("M0 %.1f H%g "):format(h * k / rows, w) end
      return ui.Path { id = spec.id, x = spec.x, y = spec.y, width = w, height = h, view_box = { 0, 0, w, h },
        d = table.concat(d), fill_color = "transparent", stroke_color = spec.color or M.stroke("faint"),
        stroke_width = 1 }
    end
    return nil
  end

  -- ---------------------------------------------------------- controls --

  --- Lets Tab reach `area` and marks it, while a keyboard put focus there,
  --- with Tsugumori's four bright corner brackets. A click does not take
  --- focus, so a search field keeps typing. Returns `area`.
  function M.focusable(area)
    area.focus_policy = "tab"
    ui.reparent(hud().corners { length = 6, weight = 2, color = function() return C.primary end,
      visible = function() return area.visual_focus end }, area)
    return area
  end

  -- Skins for the kit's archetypes (lib.kit.skin).
  M.skins = {}

  --- A bare Control: a square plate, its corners lit under the pointer and
  --- bright with keyboard focus.
  function M.skins.Control(t)
    local plate = ui.Item { anchors = { fill = true },
      ui.Rect { anchors = { fill = true },
        color = function() return C.primary:alpha(t.down and .16 or t.hovered and .1 or .05) end,
        border_width = 1, border_color = function() return C.primary:alpha(.35) end },
      hud().corners { length = 8, color = function() return C.primary:alpha(t.hovered and 1 or .5) end },
      hud().corners { length = 10, weight = 2, color = function() return C.primary end,
        visible = function() return t.visual_focus end },
    }
    return { background = plate }
  end

  function M.action(props)
    props.scale, props.stretch = nil, nil
    if props.behavior then props.behavior.scale = nil end
    for _,key in ipairs {"enter","exit"} do
      if type(props[key])=="table" then props[key].scale=nil end
    end
    return feedback(require("lib.kit.widgets").area(props), props.id)
  end
  function M.tabbed(spec) return require("themes.tsugumori.tabbed")(theme, M, spec) end
  -- Tsugumori outlines: straight-edged, eight vertices each (repeated
  -- where a shape has fewer), so any one morphs into any other point to
  -- point. Every outline stays inside its 100 x 100 box.
  local function ring(r1, r2, phase)
    local out = {}
    for k = 0, 7 do
      local a = math.rad(phase + k * 45)
      local r = k % 2 == 0 and r1 or r2
      out[#out + 1] = ("%s%.2f %.2f"):format(k == 0 and "M" or "L", 50 + r * math.sin(a), 50 - r * math.cos(a))
    end
    return table.concat(out, " ") .. " Z"
  end
  local outlines = {
    circle = "M0 0 L50 0 L100 0 L100 50 L100 100 L50 100 L0 100 L0 50 Z",
    pill = "M0 0 L50 0 L100 0 L100 50 L100 100 L50 100 L0 100 L0 50 Z",
    diamond = "M50 0 L50 0 L100 50 L100 50 L50 100 L50 100 L0 50 L0 50 Z",
    frame = "M0 0 L50 0 L100 0 L100 50 L100 100 L50 100 L0 100 L0 50 Z",
    square = "M0 0 L100 0 L100 0 L100 100 L100 100 L0 100 L0 100 L0 0 Z",
    cookie9 = "M0 0 L50 0 L100 0 L100 50 L100 100 L50 100 L0 100 L0 50 Z",
    soft_burst = ring(50, 34, 0),
    sunny = ring(50, 26, 0),
  }
  local function outline(name)
    return outlines[name] or outlines.frame
  end
  function M.shape_path(name) return outline(name) end
  --- A straight-edged outline that morphs vertex to vertex when `shape`
  --- (a name or a binding) changes. Rotation is not part of this style: a
  --- `loop` asking for it keeps only its other properties, so the outline
  --- never sweeps outside its box.
  function M.shape(props)
    local shape = props.shape
    local ms = props.duration or theme.duration.normal
    props.shape, props.duration, props.easing = nil, nil, nil
    props.rotation = nil
    local loop = props.loop
    if type(loop) == "function" then
      props.loop = function()
        local l = loop()
        if type(l) ~= "table" then return l end
        local out, any = {}, false
        for k, v in pairs(l) do if k ~= "rotation" then out[k], any = v, true end end
        return any and out or nil
      end
    elseif type(loop) == "table" then
      loop.rotation = nil
      if next(loop) == nil then props.loop = nil end
    end
    local function build() return outline(type(shape) == "function" and shape() or shape) end
    local current = build()
    props.d, props.morph_to, props.morph_progress = current, current, 0
    props.behavior = props.behavior or {}
    props.behavior.morph_progress = { duration = ms, easing = "out_cubic" }
    props.view_box = { 0, 0, 100, 100 }
    props.fill_color, props.color = props.color, nil
    local node = ui.Path(props)
    if type(shape) == "function" then
      local at_end = false
      morf.effect("tsugumori.shape", function()
        local d = build()
        if d == current then return end
        current = d
        if at_end then node.d, node.morph_progress = d, 0
        else node.morph_to, node.morph_progress = d, 1 end
        at_end = not at_end
      end, { owner = node })
    end
    return node
  end
  function M.svg(name)
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><path d="' .. outline(name) .. '"/></svg>'
  end
  function M.sdf_shape(props)
    props.shape, props.duration, props.easing = "box", nil, nil
    props.radius, props.loop = 0, nil
    return ui.SdfShape(props)
  end
  function M.loading(size, color, props)
    props=props or {}
    local active=props.active or function() return true end
    props.active=nil
    props.width,props.height=size,size
    for i=1,4 do
      props[#props+1]=ui.Rect {x=(i-1)*size/4,width=size/4-3,height=3,y=size/2,
        color=color,opacity=0.25,
        loop=function()
          if not active() then return nil end
          return {opacity={from=0.15,to=1,duration=440,delay=(i-1)*90,alternate=true}}
        end }
    end
    return ui.Item(props)
  end

  --- A number whose digits roll: a changed digit rolls up out of its slot as
  --- the new one rolls in from below, once. `spec`: `id`, `value` (fn: a
  --- number or a string of digits), `size`, `color`, `digits` (3),
  --- `duration` (220), `font`, `weight`.
  function M.morph_number(spec)
    local size = spec.size
    local n = spec.digits or 3
    local dw = math.floor(size * 0.62 + 0.5)
    local duration = spec.duration or 220
    local node = ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = n * dw, height = size }
    local slots, state = {}, {}
    for i = 1, n do
      local function digit(id, opacity)
        return M.text { id = id, width = dw, height = size, font_size = size, opacity = opacity,
          font_family = spec.font or theme.mono, font_weight = spec.weight or 500,
          horizontal_alignment = "center", vertical_alignment = "center", text = "", color = spec.color }
      end
      local current = digit(spec.id and (spec.id .. "-digit-" .. i) or nil, 1)
      local old = digit(nil, 0)
      slots[i] = { item = ui.Item { x = (i - 1) * dw, width = dw, height = size, clip = true, old, current },
        current = current, old = old }
      state[i] = { shown = "" }
      ui.reparent(slots[i].item, node)
    end
    morf.effect("tsugumori.morph_number" .. (spec.id and ("." .. spec.id) or ""), function()
      local text = tostring(spec.value() or "")
      if #text > n then text = text:sub(-n) end
      local lead = n - #text
      for i = 1, n do
        local c = i > lead and text:sub(i - lead, i - lead) or ""
        local slot, st = slots[i], state[i]
        slot.item.x = (i - 1) * dw - lead * dw / 2
        if c ~= st.shown then
          if st.running then st.running:stop() st.running = nil end
          slot.current.text = c
          if st.shown == "" or c == "" then
            slot.current.y, slot.old.opacity = 0, 0
          else
            slot.old.text = st.shown
            st.running = morf.animation.play {{ parallel = {
              { node = slot.current, property = "y", from = size, to = 0, duration = duration, easing = "out_cubic" },
              { node = slot.old, property = "y", from = 0, to = -size, duration = duration, easing = "out_cubic" },
              { node = slot.old, property = "opacity", from = 1, to = 0, duration = duration },
            } }}
          end
          st.shown = c
        end
      end
    end, { owner = node })
    return node
  end

  function M.hover(area, color)
    ui.reparent(ui.Rect {
      anchors = { fill = true }, z = -1, radius = 0, border_width = 1,
      color = function() return color(area.hovered) end,
      border_color = function() return area.hovered and stroke(C,"focus") or stroke(C,"idle") end,
      behavior = { color = { duration = 140 }, border_color = { duration = 140 } },
    }, area)
    feedback(area)
    return area
  end
  local meters = require("themes.tsugumori.meters")(theme, M)
  M.bar = meters.bar

  -- ------------------------------------------------- stateful controls --

  --- A layout's radius `r` (Material's measure) in Tsugumori's: square,
  --- with at most the theme's hairline softening.
  function M.round(r)
    r = tonumber(get(r)) or 0
    return math.max(0, math.min(theme.ROUNDING or 2, r))
  end

  --- The highlight under a list's chosen row: a square plate in a distance
  --- field tracking `track` (it slides with the item's springs, no path
  --- rebuilt per frame), with an accent lead edge and the chamfered
  --- registration marks riding the item itself.
  function M.selection(spec)
    local track = spec.track
    local color = spec.color or function() return C.primary:alpha(.12) end
    local ride = ui.Item { anchors = { fill = true }, z = -1,
      ui.Rect { width = 2, anchors = { top = true, bottom = true, left = true }, color = M.ink("accent") },
      anchored_marks(7, function() return stroke(C, "focus") end, -2),
    }
    ui.reparent(ride, track)
    return ui.Sdf { id = spec.id, anchors = { fill = true }, z = spec.z or -1,
      ui.SdfShape { shape = "box", radius = 0, track = track, fill_color = color } }
  end

  --- The ground of a stateful control (a quick-settings tile, a profile
  --- choice). Square plate; hover lifts its hairline, a press sinks the
  --- plate a step inside its frame, and `on` fills it with the tone and
  --- marks it with an accent edge and the registration marks.
  function M.state_surface(spec)
    local area = spec.area
    local function on() return spec.on and spec.on() == true end
    local tone = spec.tone and (type(spec.tone) == "function" and spec.tone or M.signal(spec.tone))
      or function() return C.primary end
    local function over() return area and area.hovered end
    local function down() return area and area.pressed end
    local node = { id = spec.id, z = spec.z or -1, x = spec.x, y = spec.y }
    if spec.height or spec.width then
      node.width, node.height = spec.width, spec.height
      if not spec.width then node.anchors = { left = true, right = true } end
    else node.anchors = { fill = true } end
    node[1] = ui.Rect { anchors = { fill = true },
      color = function() return on() and tone():alpha(.16) or C.surfaceContainerHigh end,
      border_width = 1,
      border_color = function()
        if on() then return tone():alpha(.6) end
        return over() and stroke(C, "hover") or stroke(C, "idle")
      end,
      behavior = { color = { duration = 160 }, border_color = { duration = 140 } } }
    -- The press: an inner plate a step in from the frame.
    node[2] = ui.Rect { anchors = { fill = true, margins = 3 },
      color = function() return tone():alpha(.14) end,
      opacity = function() return down() and 1 or 0 end, behavior = { opacity = { duration = 90 } } }
    node[3] = ui.Rect { width = 3, anchors = { top = true, bottom = true, left = true }, color = tone,
      opacity = function() return on() and 1 or 0 end, behavior = { opacity = { duration = 160 } } }
    node[4] = anchored_marks(8, tone, 0, function() return on() and 1 or 0 end)
    return ui.Item(node)
  end

  --- The ink on a state surface: its ground is only a wash of the tone,
  --- so a control that is on reads in the tone itself. `on` (fn), `tone`,
  --- `idle` (the ink while off).
  function M.state_ink(spec)
    local tone = spec.tone and spec.tone ~= "secondary" and M.signal(spec.tone) or function() return C.primary end
    return function()
      if spec.on and spec.on() == true then return tone() end
      return spec.idle or C.onSurface
    end
  end

  --- A key hint cap: a chamfered mono key with the caps legend.
  function M.keycap(spec)
    local text = tostring(get(spec.text) or "")
    local h = spec.height or 22
    local w = spec.width or math.max(26, math.ceil(utf8.len(text) * 7.6 + 14))
    local c = math.max(3, math.floor(h * .22))
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
      ui.Path { width = w, height = h, view_box = { 0, 0, w, h }, d = frame_d(w, h, c, .5),
        fill_color = function() return C.surfaceContainerHighest end,
        stroke_color = function() return stroke(C, "hover") end, stroke_width = 1, stroke_join = "miter" },
      ui.Rect { x = c + 2, y = h - 3, width = math.max(0, w - 2 * c - 4), height = 1, color = M.stroke("mark") },
      M.text { anchors = { center_in = true }, text = text:upper(), font_size = theme.size.small - 2,
        font_weight = 500, letter_spacing = .5, color = M.ink("hi") },
    }
  end

  --- The well a text input sits in: a hairline chamfered frame that lights
  --- on focus, with an accent lead line along its foot that runs out while
  --- focused; `error` turns the frame and the lead to the error role.
  function M.field(spec)
    local w, h = spec.width, spec.height
    local function focused() return spec.focused and spec.focused() and true or false end
    local function bad() return spec.error and spec.error() and true or false end
    local function edge()
      if bad() then return C.error end
      return focused() and stroke(C, "focus") or stroke(C, "idle")
    end
    local function lead_color() return bad() and C.error or C.primary end
    local sized = type(w) == "number" and type(h) == "number"
    local node = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h }
    if sized then
      node[#node + 1] = ui.Path { width = w, height = h, view_box = { 0, 0, w, h },
        d = frame_d(w, h, math.min(CH, math.floor(h / 3)), .5),
        fill_color = function() return C.surfaceContainerLow end,
        stroke_color = edge, stroke_width = 1, stroke_join = "miter",
        behavior = { stroke_color = { duration = 140 } } }
    else
      node[#node + 1] = ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerLow end,
        border_width = 1, border_color = edge, behavior = { border_color = { duration = 140 } } }
    end
    node[#node + 1] = ui.Rect { anchors = { left = true, bottom = true }, height = 2,
      width = function()
        local full = (get(w) or 0) - (sized and math.min(CH, math.floor(h / 3)) or 0)
        return (focused() or bad()) and math.max(0, full) or math.min(18, math.max(0, full))
      end,
      color = lead_color,
      opacity = function() return (focused() or bad()) and 1 or .45 end,
      behavior = { width = { duration = 260, easing = "out_cubic" }, opacity = { duration = 140 },
        color = { duration = 140 } } }
    for _, child in ipairs(spec) do node[#node + 1] = child end
    return ui.Item(node)
  end

  --- A small chamfered square toggle with an icon; the alert tone while
  --- `on` (a mute): a filled plate, the alert hairline and a slash mark.
  --- The on-screen keyboard's keys in Tsugumori's look: tonal caps with
  --- their top-left and bottom-right corners chamfered (one path per key),
  --- a press that takes the accent container and mono legends. Returns
  --- `look` with its `key_face` (lib.osk draws every key with it).
  function M.keyboard_look(look)
    look = look or {}
    look.radius = 0
    look.panel = function() return C.surface:alpha(0) end
    look.key = function() return C.surfaceContainerHigh end
    look.key_dim = function() return C.surfaceContainer end
    look.press = function() return C.primaryContainer end
    look.accent = look.accent or M.signal("accent")
    look.on_accent = look.on_accent or function() return C.onPrimary end
    look.text = look.text or M.ink("hi")
    look.dim = look.dim or M.ink("lo")
    look.font = theme.mono or theme.font
    look.icons = look.icons or theme.icon_font
    local function get_c(v) if type(v) == "function" then return v() end return v end
    function look.key_face(key)
      local w, h = key.width, key.height
      local function strong() return key.accent or (key.lit and key.lit()) end
      local function down() return key.down and key.down() end
      local function ink() return get_c(strong() and look.on_accent or look.text) end
      local c = math.max(4, math.floor(math.min(w, h) * .16))
      local label_size = math.floor(h * .42)
      local face = { anchors = { fill = true },
        ui.Path { width = w, height = h, view_box = { 0, 0, w, h }, d = frame_d(w, h, c),
          fill_color = function()
            if down() then return get_c(look.press) end
            if strong() then return get_c(look.accent) end
            return get_c(key.dim and look.key_dim or look.key)
          end,
          behavior = { fill_color = { duration = 90 } } },
      }
      if key.icon and look.icons then
        face[#face + 1] = ui.Text { anchors = { center_in = true }, font_family = look.icons,
          font_size = math.floor(label_size * 1.15), axes = { FILL = 1 }, scale_x = key.mirror and -1 or 1,
          text = key.icon, color = ink }
      else
        local label = tostring(key.label and key.label() or "")
        face[#face + 1] = ui.Text { anchors = { center_in = true }, text = key.label, font_family = look.font,
          font_size = (key.kind == "char" or #label <= 2) and label_size or math.floor(label_size * .72),
          color = ink }
      end
      -- The long press's first offer, small in the corner.
      if key.hint then
        local small = math.floor(h * .26)
        face[#face + 1] = ui.Text { x = w - small - 4, y = 3, text = key.hint, font_family = look.font,
          font_size = small, color = function() return get_c(look.dim) end }
      end
      return ui.Item(face)
    end
    return look
  end

  -- ---------------------------------------------------------- readings --

  --- A square-capped arc gauge: a hairline track, the value's arc with butt
  --- ends, registration ticks across both ends of the sweep and a short
  --- head mark riding the value. `spec`: `value()` (0..1), `size`,
  --- `stroke`, `from`/`sweep` (degrees from twelve o'clock), `color`,
  --- `track`, `id`, children laid over it.
  function M.gauge(spec)
    local size, thick = spec.size, spec.stroke or 6
    local r = size / 2 - thick / 2 - 1
    local from, sweep = spec.from or 0, spec.sweep or 360
    local color = spec.color or M.signal("accent")
    local d = M.arc_path(size / 2, size / 2, r, from, sweep)
    local function v() return clamp01(spec.value()) end
    -- The track in segments; the value a solid arc over it.
    local stripe = size >= 40 and { 5, 2.5 } or { 3, 2 }
    local ends = sweep < 360 and { from, from + sweep } or { 0, 90, 180, 270 }
    local node = {
      id = spec.id, width = size, height = size, x = spec.x, y = spec.y, anchors = spec.anchors,
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, size, size }, d = d,
        fill_color = "transparent", stroke_width = thick, stroke_cap = "butt", dash = stripe,
        stroke_color = spec.track or M.stroke("quiet", color) },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, size, size },
        d = radials(size / 2, size / 2, r - thick / 2 - 2, r + thick / 2 + 1, ends),
        fill_color = "transparent", stroke_width = 1, stroke_color = M.stroke("mark", color) },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, size, size }, d = d,
        fill_color = "transparent", stroke_width = thick, stroke_cap = "butt",
        stroke_color = color,
        opacity = function() return v() > 0.002 and 1 or 0 end,
        trim_end = function() return math.max(0.001, v()) end,
        behavior = { trim_end = settle() } },
    }
    if size >= 40 then
      node[#node + 1] = ui.Item { anchors = { fill = true },
        rotation = function() return from + sweep * v() end, behavior = { rotation = settle() },
        opacity = function() return v() > 0.002 and 1 or 0 end,
        ui.Rect { x = size / 2 - 1, y = size / 2 - r - thick / 2 - 2, width = 2, height = thick + 4,
          color = M.ink("hi") } }
    end
    for _, child in ipairs(spec) do node[#node + 1] = child end
    return ui.Item(node)
  end

  --- The large gauge: the square-capped arc, ticks at the four quadrants
  --- outside it, registration marks on its box and the reading in mono.
  function M.ring(spec)
    local s = spec.size
    local sweep = spec.sweep or 270
    local from = -sweep / 2
    local thick = spec.thickness or math.max(4, math.floor(s / 16))
    local color = spec.color or M.signal("accent")
    local function v() return clamp01(get(spec.value)) end
    local inner = s - 16
    local arc = M.gauge { x = 8, y = 8, size = inner, stroke = thick, from = from, sweep = sweep,
      value = v, color = color }
    local r_out = s / 2 - 1
    local text = spec.text or function() return ("%d%%"):format(math.floor(v() * 100 + .5)) end
    local node = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s,
      marks(s, s, math.max(8, math.floor(s / 12)), M.stroke("mark", color)),
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s },
        d = radials(s / 2, s / 2, r_out - 5, r_out, { 0, 90, 180, 270 }),
        fill_color = "transparent", stroke_width = 1, stroke_color = M.stroke("idle", color) },
      arc,
      ui.Column { anchors = { center_in = true }, gap = 0, align = "center",
        M.text { text = text, font_size = spec.text_size or math.floor(s * .18), font_weight = 500,
          color = color, horizontal_alignment = "center" },
        spec.label and M.label { text = spec.label, horizontal_alignment = "center" } or nil,
      },
    }
    for _, child in ipairs(spec) do node[#node + 1] = child end
    return ui.Item(node)
  end

  --- A small gauge with its caption under it.
  function M.mini_ring(spec)
    local s = spec.size
    local color = spec.color or M.signal("accent")
    local function v() return clamp01(get(spec.value)) end
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s + 14,
      M.gauge { size = s, stroke = math.max(3, math.floor(s / 10)), value = v, color = color,
        M.text { anchors = { center_in = true }, font_size = math.max(9, math.floor(s * .24)), font_weight = 500,
          text = spec.text or function() return ("%d"):format(math.floor(v() * 100 + .5)) end,
          color = M.ink("hi"), horizontal_alignment = "center" } },
      spec.label and M.label { text = spec.label, y = s + 1, width = s, height = 13, font_size = 9,
        horizontal_alignment = "center", elide = "right" } or nil,
    }
  end

  --- A segmented meter: square blocks along the length, faint, lit up to
  --- the level in whole blocks.
  function M.meter(spec)
    local w, h = spec.width, spec.height or 8
    local n = spec.count or math.max(6, math.floor(w / 8))
    local gap = 2
    local seg = (w - gap * (n - 1)) / n
    local color = spec.color or M.signal("accent")
    local d = ("M0 %g H%g"):format(h / 2, w)
    local function lit()
      local v = clamp01(get(spec.value))
      return math.floor(v * n + .5) / n
    end
    local function line(props)
      props.width, props.height, props.view_box, props.d = w, h, { 0, 0, w, h }, d
      props.fill_color, props.stroke_width, props.dash, props.stroke_cap = "transparent", h, { seg, gap }, "butt"
      return ui.Path(props)
    end
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
      line { stroke_color = spec.track and function() return get(spec.track) end or M.stroke("quiet", color) },
      line { stroke_color = color, opacity = function() return lit() > 0 and 1 or 0 end,
        trim_end = function() return math.max(.0001, lit()) end, behavior = { trim_end = settle() } },
    }
  end

  --- An emphasised fill: a hatched run up to the level over a faint tint,
  --- a solid head at the level and a base line where full would be.
  function M.fill(spec)
    local w, h = spec.width, spec.height or 14
    local color = spec.color or M.signal("accent")
    local function v() return clamp01(get(spec.value)) end
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
      ui.Rect { y = h - 1, width = w, height = 1, color = M.stroke("idle", color) },
      ui.Item { height = h, clip = true, width = function() return w * v() end, behavior = { width = settle() },
        visible = function() return v() > .002 end,
        ui.Rect { width = w, height = h, color = function() return get(color):alpha(.18) end },
        stripes.box { width = w, height = h, gap = 7, weight = 2.5, color = color } },
      ui.Rect { x = function() return math.max(0, w * v() - 2) end, width = 2, height = h, color = color,
        opacity = function() return v() > 0.002 and 1 or 0 end, behavior = { x = settle() } },
    }
  end

  --- A vertical channel: a column of square segments, faint, lit from the
  --- floor in whole segments.
  function M.vmeter(spec)
    local w, h = spec.width, spec.height
    local n = spec.count or math.max(4, math.floor(h / 6))
    local gap = 2
    local seg = (h - gap * (n - 1)) / n
    local color = spec.color or M.signal("accent")
    local d = ("M%g %g V0"):format(w / 2, h)
    local function lit()
      local v = clamp01(get(spec.value))
      return math.floor(v * n + .5) / n
    end
    local function line(props)
      props.width, props.height, props.view_box, props.d = w, h, { 0, 0, w, h }, d
      props.fill_color, props.stroke_width, props.dash, props.stroke_cap = "transparent", w, { seg, gap }, "butt"
      return ui.Path(props)
    end
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
      line { stroke_color = M.stroke("quiet", color) },
      line { stroke_color = color, opacity = function() return lit() > 0 and 1 or 0 end,
        trim_end = function() return math.max(.0001, lit()) end, behavior = { trim_end = settle() } },
    }
  end

  --- A history chart: a framed hairline grid with stepped series, the first
  --- filled under its line, the second a quieter line, the newest sample on
  --- the right edge. Returns the node and its `top` function.
  local history_size
  local function samples_default()
    if not history_size then
      local ok, sysinfo = pcall(require, "lib.services.sysinfo")
      history_size = ok and type(sysinfo) == "table" and sysinfo.history_size or 60
    end
    return history_size
  end
  function M.chart(spec)
    local w, h = spec.width, spec.height
    local color = spec.color or M.signal("accent")
    -- The series as data channels the paths draw: steps and the hatching
    -- under them made where they are painted, no Lua building them.
    local first, feed_first = channel.from(spec.first or {})
    local second, feed_second
    if spec.second then second, feed_second = channel.from(spec.second) end
    local function bottom() return tonumber(get(spec.bottom)) or 0 end
    local function top()
      if type(spec.top) == "function" then return math.max(bottom() + 1e-9, spec.top()) end
      if spec.top then return spec.top end
      local peak = math.max(bottom(), first:peak() or 0, second and second:peak() or 0)
      return math.max(peak * 1.15, bottom() + (spec.floor or 1))
    end
    local function plot(kind)
      return function()
        return { kind = kind, width = get(w), height = get(h), samples = spec.samples or samples_default(),
          bottom = bottom(), top = top(), pad_top = 2, pad_bottom = 0, hatch = 6 }
      end
    end
    local function grid()
      local W, H = get(w), get(h)
      local cols, rows = spec.columns or 8, spec.rows or 4
      local d = {}
      for k = 1, cols - 1 do d[#d + 1] = ("M%.1f 0 V%g "):format(W * k / cols, H) end
      for k = 1, rows - 1 do d[#d + 1] = ("M0 %.1f H%g "):format(H * k / rows, W) end
      return table.concat(d)
    end
    local function box() return { 0, 0, get(w), get(h) } end
    local strong = spec.emphasis or spec.hatch
    local plot_box = { width = w, height = h, clip = true,
      ui.Rect { anchors = { fill = true }, color = function() return get(color):alpha(.035) end,
        border_width = 1, border_color = M.stroke("idle", color) },
      ui.Path { anchors = { fill = true }, view_box = box, d = grid, fill_color = "transparent",
        stroke_color = M.stroke("faint", color), stroke_width = 1 },
      ui.Path { anchors = { fill = true }, view_box = box, series = first.id, plot = plot("steps_area"),
        fill_color = function() return get(color):alpha(strong and .14 or .08) end },
      ui.Path { anchors = { fill = true }, view_box = box, series = first.id, plot = plot("hatch_steps"),
        fill_color = "transparent", stroke_color = function() return get(color):alpha(strong and .8 or .55) end,
        stroke_width = 1.5, stroke_cap = "butt" },
      ui.Path { anchors = { fill = true }, view_box = box, series = first.id, plot = plot("steps"),
        fill_color = "transparent", stroke_color = color, stroke_width = 1.5, stroke_join = "miter" },
    }
    if second then
      plot_box[#plot_box + 1] = ui.Path { anchors = { fill = true }, view_box = box,
        series = second.id, plot = plot("steps"), fill_color = "transparent",
        stroke_color = function() return get(color):alpha(.55) end, stroke_width = 1, stroke_join = "miter" }
    end
    if spec.caption then
      plot_box[#plot_box + 1] = M.label { text = spec.caption, x = 7, y = 4, font_size = 9 }
    end
    if spec.scale then
      plot_box[#plot_box + 1] = M.label { text = function() return spec.scale(top()) end, anchors = { right = true,
        right_margin = 7 }, y = 4, font_size = 9, horizontal_alignment = "right" }
    end
    local node = ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
      ui.Item(plot_box), anchored_marks(8, M.stroke("mark", color), -3) }
    feed_first(node)
    if feed_second then feed_second(node) end
    return node, top
  end

  --- Bars per value, one path: solid square bars, mirrored bars grown from
  --- the middle.
  function M.spectrum(spec)
    local w, h = spec.width, spec.height
    local color = spec.color or M.signal("accent")
    -- The bars are a data channel's (an audio monitor writes one with no
    -- Lua per frame), drawn where they are painted: solid and square.
    local bars, feed = channel.from(spec.channel or spec.values, { size = 512 })
    local node = ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
      ui.Rect { y = spec.mirror and math.floor(h / 2) or h - 1, width = w, height = 1, color = M.stroke("idle", color) },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, w, h }, series = bars.id,
        plot = { kind = "bars", width = w, height = h, gap = spec.gap or 1, radius = 0, min_bar = 1,
          mirror = spec.mirror == true },
        fill_color = color },
    }
    feed(node)
    return node
  end

  --- A polygon over spokes: the axes as hairlines with a registration tick
  --- across each tip, a half and a full rim, and square vertex marks.
  function M.radar(spec)
    local s = spec.size
    local c = s / 2
    local axes = spec.axes or 6
    local color = spec.color or M.signal("accent")
    local R = c - 5
    local function point(k, r)
      local a = math.rad(360 * k / axes)
      return c + r * math.sin(a), c - r * math.cos(a)
    end
    local web = {}
    for _, f in ipairs { .5, 1 } do
      for k = 0, axes do
        local x, y = point(k, R * f)
        web[#web + 1] = (k == 0 and "M%.2f %.2f " or "L%.2f %.2f "):format(x, y)
      end
    end
    for k = 0, axes - 1 do
      local x, y = point(k, R)
      web[#web + 1] = ("M%.2f %.2f L%.2f %.2f "):format(c, c, x, y)
      local a = math.rad(360 * k / axes)
      local tx, ty = 3 * math.cos(a), 3 * math.sin(a)
      web[#web + 1] = ("M%.2f %.2f L%.2f %.2f "):format(x - tx, y - ty, x + tx, y + ty)
    end
    local function values() return get(spec.values) or {} end
    local function shape()
      local list, out = values(), {}
      for k = 0, axes - 1 do
        local x, y = point(k, R * clamp01(list[k + 1] or 0))
        out[#out + 1] = (k == 0 and "M%.2f %.2f " or "L%.2f %.2f "):format(x, y)
      end
      return table.concat(out) .. "Z"
    end
    local function vertices()
      local list, out = values(), {}
      for k = 0, axes - 1 do
        local x, y = point(k, R * clamp01(list[k + 1] or 0))
        out[#out + 1] = ("M%.2f %.2f h3 v3 h-3 Z "):format(x - 1.5, y - 1.5)
      end
      return table.concat(out)
    end
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s,
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = table.concat(web),
        fill_color = "transparent", stroke_color = M.stroke("idle", color), stroke_width = 1 },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = shape,
        fill_color = function() return get(color):alpha(.2) end, stroke_color = color, stroke_width = 1.5,
        stroke_join = "miter" },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = vertices, fill_color = color },
    }
  end

  --- A dial on a chamfered plate: a hairline circle, the value's
  --- square-capped arc, quadrant ticks and a pointer from a square hub.
  function M.dial(spec)
    local s = spec.size
    local color = spec.color or M.signal("accent")
    local c = s / 2
    local r = s * .34
    local thick = math.max(3, math.floor(s / 22))
    local function v() return clamp01(get(spec.value)) end
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s,
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = frame_d(s, s, math.max(6, s / 8), .5),
        fill_color = "transparent", stroke_color = M.stroke("idle", color), stroke_width = 1, stroke_join = "miter" },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = M.arc_path(c, c, r, 0, 360),
        fill_color = "transparent", stroke_color = M.stroke("quiet", color), stroke_width = 1 },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s },
        d = radials(c, c, r + thick, r + thick + 5, { 0, 90, 180, 270 }),
        fill_color = "transparent", stroke_color = M.stroke("mark", color), stroke_width = 1 },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = M.arc_path(c, c, r, 0, 360),
        fill_color = "transparent", stroke_color = color, stroke_width = thick, stroke_cap = "butt",
        opacity = function() return v() > .002 and 1 or 0 end,
        trim_end = function() return math.max(.001, v()) end, behavior = { trim_end = settle() } },
      ui.Item { anchors = { fill = true }, rotation = function() return 360 * v() end,
        behavior = { rotation = settle() },
        ui.Rect { x = c - .5, y = c - r + thick, width = 1, height = r - thick, color = M.ink("hi") } },
      ui.Rect { x = c - 3, y = c - 3, width = 6, height = 6, color = color },
    }
  end

  --- A boxed number on a chamfered frame: the caps label, the number in
  --- mono and a level rail up the right edge, coloured by its level.
  function M.cell(spec)
    local w, h = spec.width, spec.height
    local function value() return tonumber(get(spec.value)) or 0 end
    local tone = spec.color or M.level(value)
    local rail_h = h - 16
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
      ui.Path { width = w, height = h, view_box = { 0, 0, w, h }, d = frame_d(w, h, math.min(CH, h / 4), .5),
        fill_color = function() return C.surfaceContainer:alpha(.5) end,
        stroke_color = M.stroke("idle"), stroke_width = 1, stroke_join = "miter" },
      spec.label and M.label { text = spec.label, x = 9, y = 5, width = w - 24, height = 13, font_size = 9,
        elide = "right" } or nil,
      M.text { text = spec.text or function() return ("%d"):format(math.floor(value() + .5)) end,
        x = 9, anchors = { bottom = true, bottom_margin = 4 }, width = w - 24,
        font_size = math.max(11, math.min(theme.typography.hero, math.floor(h * .36))), font_weight = 500,
        color = tone, elide = "right" },
      ui.Rect { x = w - 8, y = 8, width = 3, height = rail_h, color = M.stroke("quiet") },
      ui.Rect { x = w - 8, width = 3, color = tone,
        y = function() return 8 + rail_h * (1 - clamp01(value() / 100)) end,
        height = function() return rail_h * clamp01(value() / 100) end,
        behavior = { y = settle(), height = settle() } },
    }
  end

  --- A readout plate: registration marks, the caps label, the value in
  --- mono and, given a level, a rail along the foot.
  function M.stat(spec)
    local w, h = spec.width, spec.height
    local color = spec.color or M.signal("accent")
    local node = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
      ui.Rect { anchors = { fill = true }, color = function() return get(color):alpha(.05) end },
      marks(w, h, 8, M.stroke("mark", color)),
      M.label { text = spec.label, x = 10, y = 7, width = w - 20, height = 13, font_size = 9, elide = "right" },
      M.text { text = spec.value, x = 10, y = 22, width = w - 20,
        font_size = math.max(11, math.min(theme.typography.hero, math.floor((h - 34) * .9))), font_weight = 500,
        color = M.ink("hi"), elide = "right" },
    }
    if spec.level ~= nil then
      local function level()
        local l = tonumber(get(spec.level)) or 0
        return l > 1 and l / 100 or l
      end
      node[#node + 1] = M.meter { x = 10, y = h - 10, width = w - 20, height = 6, value = level, color = color }
    end
    return ui.Item(node)
  end

  --- NOW / AVG / PEAK in three numbered columns divided by hairlines.
  function M.triplet(spec)
    local w = spec.width
    local color = spec.color or M.signal("accent")
    local function fmt(v)
      if spec.format then return spec.format(v) end
      return ("%d"):format(math.floor(v + .5))
    end
    local function pick(k)
      return function()
        local now, avg, peak = common.summary(get(spec.series) or {})
        return fmt(({ now, avg, peak })[k])
      end
    end
    local cw = w / 3
    local node = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = 34 }
    for k, name in ipairs { "Now", "Avg", "Peak" } do
      local x = (k - 1) * cw
      if k > 1 then node[#node + 1] = ui.Rect { x = x, y = 3, width = 1, height = 28, color = M.stroke("idle", color) } end
      node[#node + 1] = M.label { text = ("%02d %s"):format(k, name), x = x + 8, y = 0, height = 13, font_size = 9 }
      node[#node + 1] = M.text { text = pick(k), x = x + 8, y = 14, width = cw - 12, height = 20,
        font_size = 15, font_weight = 500, elide = "right", color = k == 1 and color or M.ink("hi") }
    end
    return ui.Item(node)
  end

  -- ------------------------------------------------------------ status --

  local GLYPHS = {
    alert = "M44 20 H56 V60 H44 Z M44 68 H56 V80 H44 Z",
    warn = "M50 20 L80 48 L72 56 L50 36 L28 56 L20 48 Z M50 46 L80 74 L72 82 L50 62 L28 82 L20 74 Z",
    ok = "M20 50 L30 40 L43 53 L70 26 L80 36 L43 73 Z",
    info = "M44 20 H56 V32 H44 Z M44 40 H56 V80 H44 Z",
  }
  local PLATE = "M22 2 H98 V78 L78 98 H2 V22 Z"
  --- A status mark: a chamfered plate with the kind's glyph.
  function M.emblem(spec)
    local s = spec.size or 40
    local function kind() local k = get(spec.kind) return GLYPHS[k] and k or "info" end
    local color = spec.color or function() return M.signal(kind())() end
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s,
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, 100, 100 }, d = PLATE,
        fill_color = function() return get(color):alpha(.14) end, stroke_color = color, stroke_width = 3,
        stroke_join = "miter" },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, 100, 100 },
        d = function() return GLYPHS[kind()] end, fill_color = color },
    }
  end

  --- The mark, the big word in caps and a trailing rule: an accent lead and
  --- a chamfered pip at the far end.
  function M.status_line(spec)
    local w = spec.width
    local size = spec.size or 40
    local function kind() return get(spec.kind) end
    local color = spec.color or function() return M.signal(kind())() end
    local title_w = spec.title_width or math.floor(w * .52)
    local rule_x = size + 18 + title_w
    local rule_w = math.max(0, w - rule_x)
    local mid = math.floor(size / 2)
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = size,
      M.emblem { kind = spec.kind, size = size, color = color },
      M.text { x = size + 14, y = 0, height = math.floor(size * .62),
        text = function() return tostring(get(spec.title) or ""):upper() end,
        font_size = math.floor(size * .46), font_weight = 500, color = M.ink("hi"), width = title_w, elide = "right" },
      spec.subtitle and M.label { x = size + 14, y = size - 13, text = spec.subtitle, font_size = 9,
        width = title_w, elide = "right" } or nil,
      rule_w > 24 and ui.Item { x = rule_x, y = mid - 4, width = rule_w, height = 8,
        ui.Rect { y = 4, width = rule_w - 10, height = 1, color = M.stroke("mark", color) },
        ui.Rect { y = 3, width = 18, height = 3, color = color },
        ui.Path { x = rule_w - 8, width = 8, height = 8, view_box = { 0, 0, 8, 8 }, d = frame_d(8, 8, 2),
          fill_color = color },
      } or nil,
    }
  end

  --- A live status strip: an accent edge, the live mark, a title and a
  --- note, over a faint hairline.
  function M.status(spec)
    local w = spec.width
    local h = spec.height or 40
    local color = function() return M.signal(get(spec.kind))() end
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
      ui.Rect { width = 3, height = h, color = color, behavior = { color = { duration = 180 } } },
      M.emblem { x = 12, y = math.floor((h - 22) / 2), size = 22, kind = spec.kind, color = color },
      M.text { x = 44, y = math.floor(h / 2) - 17, height = 18, font_size = theme.typography.section, font_weight = 500,
        text = function() return tostring(get(spec.title) or ""):upper() end, color = M.ink("hi"),
        width = function() return math.max(0, get(w) - 52) end, elide = "right" },
      spec.subtitle and M.text { x = 44, y = math.floor(h / 2) + 2, height = 15, font_size = theme.typography.caption,
        text = function() return tostring(get(spec.subtitle) or "") end, color = M.ink("lo"),
        width = function() return math.max(0, get(w) - 52) end, elide = "right" } or nil,
      ui.Rect { y = h - 1, width = w, height = 1, color = M.stroke("faint") },
    }
  end

  -- ------------------------------------------------------------ motion --

  function M.spring()
    return { duration = theme.duration.small, easing = theme.ease.standard }
  end
  -- Tsugumori moves without squash and stretch.
  M.STRETCH = nil
  local indicators = setmetatable({}, { __mode = "k" })
  function M.elastic(node, axis, _, _, start, finish)
    if indicators[node] then indicators[node]:stop() end
    indicators[node] = morf.animation.play { { parallel = {
      { node = node, property = axis, to = start, duration = 320, easing = "out_cubic" },
      { node = node, property = axis == "x" and "width" or "height", to = finish-start, duration = 320, easing = "out_cubic" },
    } } }
    return indicators[node]
  end
  --- The contents of a drawer coming in or going, in the theme's entry
  --- choreography (motion.entries).
  function M.bud(nodes, coming, opts)
    local entries = {}
    for _, node in ipairs(nodes) do entries[#entries + 1] = { node = node } end
    return theme.motion.entries(entries, coming, opts)
  end
  --- Makes `node` ride out with drawer `d`: tied to the panel's far edge on
  --- every frame (ui.follow), pushed `distance()` px at the end.
  function M.ride(name, node, d, distance)
    morf.effect("caelestia.ride." .. name, function()
      local dist = distance()
      local follow = { node = d.panel, property = "translate_x", offset = dist }
      if dist >= 0 then follow.min = 0 else follow.max = 0 end
      ui.follow(node, "translate_x", follow)
    end)
  end

  M.bytes = common.bytes
  --- A state word in the theme's voice: Tsugumori's labels set their own
  --- casing, so the plain word.
  function M.term(_, plain) return plain end

  -- The gauges: the instrument rings (themes/tsugumori/gauges.lua).
  local gauges = require("themes.tsugumori.gauges")(theme, M)
  M.gauge, M.ring, M.mini_ring = gauges.gauge, gauges.ring, gauges.mini_ring

  -- Lists and keys wear the instrument pieces (themes/tsugumori/hud.lua).
  M.selection, M.keycap = hud().selection, hud().keycap

  for name, skin in pairs(require("themes.tsugumori.skins")(theme, M, hud)) do M.skins[name] = skin end
  -- The display widgets this file does not draw itself, from the shared
  -- composition in this theme's style.
  require("lib.kit.display").install(M, require("themes.tsugumori.display_style")(theme, M, anchored_marks))
  return M
end
