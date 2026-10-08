-- Small pieces every part of the shell uses: a Material Symbols icon, text
-- in the shell's face, a rounded card.

local morf = require("morf")
local ui = require("morf.ui")
local channel = require("lib.util.channel")
return function(theme)

local M = {}
function M.shape_path(...) return require("lib.util.m3shapes").path(...) end
-- Non-interactive surfaces, kept distinct from semantic cards and controls.
M.surface = ui.Rect

local function C() return theme.color end

-- The ring of each focusable area, so a hover that rounds the area's
-- background can round the ring to match.
local rings = setmetatable({}, { __mode = "k" })

--- Lets Tab reach `area` and draws the Material focus ring on it while a
--- keyboard put focus there: a 2 px secondary outline just inside its
--- edge, `radius` (or a pill's) rounded. A click does not take focus, so a
--- search field keeps typing. Returns `area`.
function M.focusable(area, radius)
  area.focus_policy = "tab"
  local ring = ui.Rect {
    anchors = { fill = true, margins = 1 }, z = 50, color = "transparent",
    radius = radius or function() return math.min(16, (tonumber(area.height) or 0) / 2) end,
    border_width = 2, border_color = function() return C().secondary end,
    visible = function() return area.visual_focus end,
  }
  ui.reparent(ring, area)
  rings[area] = ring
  return area
end

-- Skins for the kit's archetypes (lib.kit.skin): functions of a control's
-- live state returning its slots.
M.skins = {}

--- A bare Control: a rounded surface with Material's state layer.
function M.skins.Control(t)
  return {
    background = ui.Rect { anchors = { fill = true }, radius = 12,
      color = function()
        local base = C().surfaceContainer
        if t.down then return base:mix(C().onSurface, 0.12) end
        if t.hovered then return base:mix(C().onSurface, 0.08) end
        return base
      end,
      border_width = function() return t.visual_focus and 2 or 0 end,
      border_color = function() return C().secondary end,
      behavior = { color = { duration = theme.duration.small } } },
  }
end

--- A pointer area that Tab reaches too (`M.focusable`).
-- A pressable area: a kit Press (lib.kit.widgets.area), so the press, Tab
-- and its keys are the archetype's; the theme only draws.
function M.action(props) return require("lib.kit.widgets").area(props) end

--- A Material Symbols Rounded icon by its ligature name (`"wifi_off"`).
--- `name` and `color` may be bindings; `props.fill` (a boolean or a
--- binding) fills it in through the face's FILL axis.
function M.icon(name, size, color, props)
  props = props or {}
  props.text = name
  -- A glyph's ligature ("arrow_back") is no word for a screen reader:
  -- the control around it is named instead, unless the icon is named.
  if props.accessible_name == nil and props.accessible_hidden == nil then props.accessible_hidden = true end
  props.font_family = theme.icon_font
  props.font_size = size or 18
  props.color = color or function() return theme.color.onSurface end
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

--- Text in Rubik; `props` as a `ui.Text`'s.
function M.text(props)
  props.font_family = props.font_family or theme.font
  if theme.font_file ~= "" and props.font_source == nil then props.font_source = theme.font_file end
  props.font_size = props.font_size or theme.size.normal
  -- The reference's font builder sets `opsz` to the size in points (morf's
  -- automatic optical sizing, like CSS's, uses pixels, which reads a size
  -- larger and sets it tighter) and `ROND` 25 on every face. A face without
  -- those axes ignores them.
  if props.axes == nil and type(props.font_size) == "number" then
    props.axes = { opsz = props.font_size * 3 / 4, ROND = 25, wght = props.font_weight }
  elseif props.font_weight and props.axes == nil then
    props.axes = { wght = props.font_weight }
  end
  if props.color == nil then props.color = function() return theme.color.onSurface end end
  return ui.Text(props)
end

--- A semantic section heading; visual themes may add presentation effects.
function M.heading(props)
  -- A heading to a screen reader too: a page's title or a section's.
  local level = props.level == "section" and 2 or 1
  props.active, props.reveal_delay, props.scope, props.level, props.ink = nil, nil, nil, nil, nil
  props.decode_lead, props.decode_stagger, props.viewport = nil, nil, nil
  props.accessible_role, props.accessible = "heading", { level = level }
  return M.text(props)
end
M.subtitle = M.text
M.section_label = M.text
M.menu_label = M.text

--- A card: a surfaceContainer box with the large rounding.
--- While a collector is set (`M.collect(list)`), a card is not a `Rect`
--- but an item whose background is a layer of a distance field someone
--- else builds: `list` gets `{ node, radius, color, shape }` for each, so
--- the cards of a page can merge, bud and melt as one liquid surface.
local collector
function M.collect(list) collector = list end

function M.card(props)
  props.radius = props.radius or theme.ROUNDING
  if props.color == nil then props.color = function() return theme.color.surfaceContainer end end
  if not collector then return ui.Rect(props) end
  local radius, color = props.radius, props.color
  props.radius, props.color = nil, nil
  -- Cards grow in place, evenly about their centres (the default
  -- origin): no squash and stretch, which skewed them as they grew.
  local node = ui.Item(props)
  local entry = { node = node, radius = radius, color = color }
  entry.shape = ui.SdfShape {
    shape = "box", radius = radius, track = node,
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

--- Gives a MouseArea a rounded background whose colour follows its hover:
--- `color(hovered)`. (Built after the area, so the binding can read it.)
function M.hover(area, color, radius)
  radius = radius or 0
  local bg = ui.Rect {
    anchors = { fill = true }, z = -1,
    -- M3 expressive: pressed, a round button squares up, and springs back.
    radius = function() return area.pressed and radius * 0.45 or radius end,
    color = function() return color(area.hovered) end,
    behavior = {
      color = { duration = theme.duration.small },
      radius = ui.spring { stiffness = 520, damping = 22 },
    },
  }
  ui.reparent(bg, area)
  if rings[area] then rings[area].radius = math.max(0, radius - 1) end
  return area
end

-- ----------------------------------------------------------------- motion --

--- A spring for a `behavior`: the port's one feel for things that move
--- under a hand (selections, thumbs, indicators).
function M.spring(stiffness, damping)
  return ui.spring { stiffness = stiffness or 320, damping = damping or 24 }
end

--- Makes `node` ride out with drawer `d` as it opens: `node` sits on the
--- frame's edge, and the drawer's far edge sweeps past it and carries it
--- `distance` px out (negative: to the left), exactly as the drawer moves,
--- so the two stay together; closing, it rides back in.
function M.ride(name, node, d, distance)
  -- Tied to the panel itself (ui.follow), not a second animation made to
  -- look like its slide: on every frame the node is where the panel's
  -- far edge says, overshoot and all. Left: pushed once the edge reaches
  -- it, `distance` at the end; right, the same the other way.
  morf.effect("caelestia.ride." .. name, function()
    local dist = distance()
    local spec = { node = d.panel, property = "translate_x", offset = dist }
    if dist >= 0 then spec.min = 0 else spec.max = 0 end
    ui.follow(node, "translate_x", spec)
  end)
end

--- Squash and stretch for something that travels (see UI.md, `stretch`).
M.STRETCH = { stiffness = 260, damping = 14, scale = 0.14, max = 0.3 }

--- Moves a bar from `[l0, r0]` to `[l1, r1]` along `axis` ("x" or "y")
--- the way an M3 indicator does: the edge in front leaves first and fast,
--- the one behind follows, so the bar stretches out towards its target and
--- draws itself in there. `node`'s position and size are driven with dense
--- keyframes of the two edges' curves.
local running = setmetatable({}, { __mode = "k" })
function M.elastic(node, axis, l0, r0, l1, r1, opts)
  opts = opts or {}
  local size = axis == "x" and "width" or "height"
  local duration = opts.duration or 500
  local lead = opts.lead or theme.ease.emphasized_decel
  local trail = opts.trail or theme.ease.standard
  local forward = l1 >= l0
  -- The leading edge covers its way in the first 55 % of the time, the
  -- trailing one starts a little late and takes the rest.
  local function edge(from, to, t, leading)
    local u
    if leading then u = math.min(1, t / 0.55)
    else u = math.max(0, math.min(1, (t - 0.18) / 0.82)) end
    local k = morf.easing.value(leading and lead or trail, u)
    return from + (to - from) * k
  end
  local pos, len = {}, {}
  local N = 16
  for i = 0, N do
    local t = i / N
    local l = edge(l0, l1, t, not forward)
    local r = edge(r0, r1, t, forward)
    pos[#pos + 1] = { at = t, value = l }
    len[#len + 1] = { at = t, value = math.max(0, r - l) }
  end
  if running[node] then running[node]:stop() end
  running[node] = morf.animation.play {
    {
      parallel = {
        { node = node, property = axis, duration = duration, keyframes = pos },
        { node = node, property = size, duration = duration, keyframes = len },
      },
    },
  }
  return running[node]
end

--- The contents of a drawer coming in (`coming`) or going: each of `nodes`
--- grows evenly about its own centre from 0.92 (`opts.from`) as it fades in, one a
--- little after the other (`opts.stagger`, 26 ms; `opts.delay` before the
--- first), or shrinks a touch and fades as they go. No offsets and no
--- squash: at rest every node is exactly where and what it was. Returns the
--- handles, for `stop`.
function M.bud(nodes, coming, opts)
  local entries = {}
  for _, node in ipairs(nodes) do entries[#entries + 1] = { node = node } end
  return theme.motion.entries(entries, coming, opts)
end

-- --------------------------------------------------------------- shapes --

local shapes -- lib/m3shapes, loaded on first use

--- A number whose digits morph into the next ones: each digit is a glyph in
--- a distance field (`shape = "glyph"`), and a new digit in its place walks
--- there from the old, contour onto contour, rather than being swapped.
--- `spec`: `id`, `value` (a function: a number or a string of digits),
--- `size` (the digits' height), `color` (a function), `digits` (the most it
--- shows, 3), `duration` (260), `font` (a family), `weight` (the font
--- weight the digits are cut at, 700). The number is centred in
--- a box `digits` wide; a digit coming or going (9 to 10) takes its place at
--- once, the others morph.
function M.morph_number(spec)
  local size = spec.size
  local n = spec.digits or 3
  local dw = math.floor(size * 0.62 + 0.5)
  local family = spec.font or (theme.font:match("^%s*([^,]+)") or "sans-serif")
  local motion = { duration = spec.duration or 260, easing = theme.ease.standard }
  local slots, state = {}, {}
  local field = { id = spec.id, width = n * dw, height = size, fill_color = spec.color }
  for i = 1, n do
    slots[i] = ui.SdfShape {
      id = spec.id and (spec.id .. "-digit-" .. i) or nil,
      shape = "glyph", morph_to = "glyph",
      glyph = "", glyph_morph_to = "",
      font_family = family, font_family_morph_to = family,
      -- Bold: cut from the face's own bold (a variable face's wght 700).
      font_weight = spec.weight or 700,
      x = (i - 1) * dw, y = 0, width = dw, height = size,
      morph_progress = 0,
      behavior = { morph_progress = motion, x = motion },
    }
    state[i] = { shown = "", at_end = false }
    field[#field + 1] = slots[i]
  end
  local node = ui.Sdf(field)
  morf.effect("caelestia.morph_number" .. (spec.id and ("." .. spec.id) or ""), function()
    local text = tostring(spec.value() or "")
    if #text > n then text = text:sub(-n) end
    local lead = n - #text
    for i = 1, n do
      local c = i > lead and text:sub(i - lead, i - lead) or ""
      local slot, st = slots[i], state[i]
      -- Centred: the digits there are, in the middle of the box.
      slot.x = (i - 1) * dw - lead * dw / 2
      if c ~= st.shown then
        if st.shown == "" or c == "" then
          -- Coming or going: no outline to walk from, so it is simply there.
          slot.glyph, slot.glyph_morph_to = c, c
          st.at_end = false
          slot.morph_progress = 0
        elseif st.at_end then
          slot.glyph = c
          slot.morph_progress = 0
          st.at_end = false
        else
          slot.glyph_morph_to = c
          slot.morph_progress = 1
          st.at_end = true
        end
        st.shown = c
      end
    end
  end, { owner = node })
  return node
end

--- An M3 expressive shape that morphs whenever `shape()` changes (see
--- lib/m3shapes: `shapes.Shape`). `props` as a `ui.Path`'s; `color` a
--- binding; `duration`, `easing`.
function M.shape(props)
  shapes = shapes or require("lib.util.m3shapes")
  props.easing = props.easing or theme.ease.spatial
  props.duration = props.duration or 450
  return shapes.Shape(props)
end

--- An M3 expressive shape as an inline SVG document, for an `SdfShape`'s
--- `source`: a drawing is an outline to a field, so the shape unions, melts
--- and morphs with the other layers.
local svgs = {}
function M.svg(name)
  shapes = shapes or require("lib.util.m3shapes")
  if not svgs[name] then
    svgs[name] = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><path d="%s"/></svg>')
      :format(shapes.path(name))
  end
  return svgs[name]
end

--- A field layer in an M3 expressive shape that morphs, outline to outline,
--- whenever `shape()` changes. `props` as an `SdfShape`'s, and `duration`,
--- `easing`.
function M.sdf_shape(props)
  local source = props.shape
  local current = type(source) == "function" and source() or source
  local motion = { duration = props.duration or 450, easing = props.easing or theme.ease.spatial }
  props.shape, props.duration, props.easing = nil, nil, nil
  props.source = M.svg(current)
  props.source_morph_to = M.svg(current)
  props.morph_progress = 0
  props.behavior = props.behavior or {}
  props.behavior.morph_progress = motion
  local node = ui.SdfShape(props)
  if type(source) == "function" then
    -- As lib/m3shapes' Shape: the two ends take turns, so a change never
    -- jumps back to a start.
    local at_end = false
    morf.effect("caelestia.sdf_shape", function()
      local name = source()
      if name == current then return end
      current = name
      if at_end then
        node.source = M.svg(name)
        node.morph_progress = 0
      else
        node.source_morph_to = M.svg(name)
        node.morph_progress = 1
      end
      at_end = not at_end
    end, { owner = node })
  end
  return node
end

-- The loading indicator's shapes, in the order M3 expressive cycles them.
local LOADING = { "soft_burst", "cookie9", "pentagon", "pill", "sunny", "cookie4", "oval", "flower" }

--- M3 expressive's loading indicator: a shape that morphs from one to the
--- next every 650 ms while turning, in `color`, `size` across. `active()`
--- (a binding, default always) runs it; stopped, it rests.
function M.loading(size, color, props)
  props = props or {}
  local step = morf.signal("caelestia.loading." .. tostring(props.id or math.random(1e9)), 1)
  local active = props.active or function() return true end
  props.active = nil
  local timer
  props.width, props.height = size, size
  props.shape = function() return LOADING[step:get()] end
  props.color = color
  props.duration = 500
  props.loop = function()
    if not active() then return nil end
    return { rotation = { to = 360, duration = 2600, hold = true } }
  end
  local given = props.on_destroyed
  props.on_destroyed = function(...)
    if timer then timer:cancel() timer = nil end
    if given then return given(...) end
  end
  local node = M.shape(props)
  -- Its clock runs while it is active and ends with it: a spinner let go
  -- must not go on waking the shell.
  morf.effect("caelestia.loading.run." .. tostring(step), function()
    if active() then
      if not timer then
        timer = morf.timer(650, function() step:set(step:get() % #LOADING + 1) end, true)
      end
    elseif timer then
      timer:cancel()
      timer = nil
    end
  end, { owner = node })
  return node
end

-- ---------------------------------------------------------------- controls --

-- ----------------------------------------------------------------- gauges --

--- SVG path data for an arc of `sweep` degrees, clockwise from `from`
--- degrees (0 at twelve o'clock), radius `r` about `(cx, cy)`, in pieces of
--- at most 90 degrees.
function M.arc_path(cx, cy, r, from, sweep)
  local function at(deg)
    local a = math.rad(deg)
    return cx + r * math.sin(a), cy - r * math.cos(a)
  end
  local x, y = at(from)
  local d = { ("M%.3f %.3f"):format(x, y) }
  local pieces = math.max(1, math.ceil(sweep / 90))
  for i = 1, pieces do
    local ex, ey = at(from + sweep * i / pieces)
    d[#d + 1] = ("A%.3f %.3f 0 0 1 %.3f %.3f"):format(r, r, ex, ey)
  end
  return table.concat(d, " ")
end

local function clamp01(x)
  x = tonumber(x) or 0
  if x ~= x then return 0 end
  return math.max(0, math.min(1, x))
end

--- A Material 3 expressive progress arc: the value's part in `color`, a
--- gap, then the rest of the track, and a small stop dot at the track's
--- end. `spec`: `value()` (0..1), `size` (the square it sits in), `stroke`,
--- `from` and `sweep` (degrees, clockwise from twelve o'clock), `color`,
--- `track` (bindings), `gap` (px between the two), `dot` (false for none),
--- `id`, and children to lay over it.
function M.gauge(spec)
  local size, stroke = spec.size, spec.stroke or 6
  local r = size / 2 - stroke / 2
  local sweep = spec.sweep or 360
  local d = M.arc_path(size / 2, size / 2, r, spec.from or 0, sweep)
  local length = 2 * math.pi * r * sweep / 360
  -- Round caps reach half a stroke past each end: the gap is between them.
  local gap = ((spec.gap or 4) + stroke) / length
  local function v() return clamp01(spec.value()) end
  local motion = { duration = theme.duration.large, easing = theme.ease.emphasized_decel }
  local node = {
    id = spec.id, width = size, height = size, x = spec.x, y = spec.y, anchors = spec.anchors,
    ui.Path {
      anchors = { fill = true }, view_box = { 0, 0, size, size }, d = d,
      fill_color = "transparent", stroke_width = stroke, stroke_cap = "round",
      stroke_color = spec.track,
      trim_start = function()
        local x = v()
        return x <= 0 and 0 or math.min(1, x + gap)
      end,
      behavior = { trim_start = motion },
    },
    ui.Path {
      anchors = { fill = true }, view_box = { 0, 0, size, size }, d = d,
      fill_color = "transparent", stroke_width = stroke, stroke_cap = "round",
      stroke_color = spec.color,
      opacity = function() return v() > 0.002 and 1 or 0 end,
      trim_end = function() return math.max(0.001, v()) end,
      behavior = { trim_end = motion },
    },
  }
  if spec.dot ~= false and sweep < 360 then
    local a = math.rad((spec.from or 0) + sweep)
    local ex, ey = size / 2 + r * math.sin(a), size / 2 - r * math.cos(a)
    local dot = math.max(2, stroke * 0.55)
    node[#node + 1] = ui.Rect {
      x = ex - dot / 2, y = ey - dot / 2, width = dot, height = dot, radius = dot / 2,
      color = spec.color,
    }
  end
  for _, child in ipairs(spec) do node[#node + 1] = child end
  return ui.Item(node)
end

--- A straight M3 expressive progress bar: the value in `color`, a gap, the
--- track, a stop dot at the end. `spec`: `width`, `stroke`, `value()`
--- (0..1), `color`, `track`, `id`.
function M.bar(spec)
  local w, h = spec.width, spec.stroke or 6
  local GAP = 4
  local function v() return clamp01(spec.value()) end
  local motion = { duration = theme.duration.large, easing = theme.ease.emphasized_decel }
  local function split() return math.min(w, v() * w + GAP + h) end
  return ui.Item {
    id = spec.id, width = w, height = h, x = spec.x, y = spec.y, anchors = spec.anchors,
    ui.Rect {
      height = h, radius = h / 2, color = spec.track,
      x = split,
      width = function() return math.max(0, w - split()) end,
      behavior = { x = motion, width = motion },
    },
    ui.Rect {
      height = h, radius = h / 2, color = spec.color,
      width = function() return math.max(h, v() * w) end,
      opacity = function() return v() > 0 and 1 or 0 end,
      behavior = { width = motion },
    },
    ui.Rect {
      x = w - h * 0.7, y = h * 0.15, width = h * 0.7, height = h * 0.7, radius = h * 0.35,
      color = spec.color,
    },
  }
end

-- ============================================================ the kit ==
-- Material's reading of the shared kit (the kit contract, library/lib/kit/contract.lua): rounded tonal
-- containers in the surfaceContainer roles, pill-shaped progress with
-- round caps and a stop dot, M3 expressive shapes that morph when a kind
-- or a value changes, springy overshoot where something travels. No codes,
-- no tick marks, no hairline frames. Nothing here moves at rest.

local common = require("themes.kit_common")
local get = common.get

--- Bytes in binary units (themes/kit_common.lua).
M.bytes = common.bytes

local function settle() return { duration = theme.duration.large, easing = theme.ease.emphasized_decel } end
local function spatial(ms) return { duration = ms or 500, easing = theme.ease.spatial } end
local function sentence(s)
  s = tostring(s or "")
  return s:sub(1, 1):upper() .. s:sub(2):lower()
end

-- ------------------------------------------------------- colour and ink --

-- Status colours: the error role for alerts, tertiary for the extra one;
-- the desk's terminal greens, yellows and cyans for the rest, harmonized
-- toward the primary as M3 harmonizes custom colours.
local LULE = { ok = "color2", warn = "color3", info = "color6" }
function M.signal(kind)
  return function()
    local c = theme.color
    if kind == "alert" then return c.error end
    if kind == "extra" then return c.tertiary end
    local slot, lule = LULE[kind], theme.lule
    if slot and lule and lule[slot] then return lule[slot]:mix(c.primary, 0.18) end
    return c.primary
  end
end

function M.ink(kind)
  if kind == "lo" then return function() return theme.color.onSurfaceVariant end end
  if kind == "accent" then return function() return theme.color.primary end end
  return function() return theme.color.onSurface end
end

-- Lines are rare in Material; where one is asked for it is an outline role.
local STROKE = { faint = 0.35, quiet = 0.7, idle = 1, mark = 1, hot = 1 }
function M.stroke(strength, color)
  local a = assert(STROKE[strength or "idle"], "unknown stroke strength")
  return function()
    local c = theme.color
    if color then return get(color):alpha(a * (strength == "hot" and 1 or 0.6)) end
    if strength == "hot" then return c.primary end
    if strength == "mark" then return c.outline end
    return c.outlineVariant:alpha(a)
  end
end

local level_alert, level_warn = M.signal("alert"), M.signal("warn")
function M.level(value, warn, alert)
  warn, alert = warn or 70, alert or 90
  return function()
    local v = tonumber(get(value)) or 0
    if v >= alert then return level_alert() end
    if v >= warn then return level_warn() end
    return theme.color.primary
  end
end

-- ------------------------------------------------------------------ text --

--- A small label (units, captions): sentence case, medium weight, the
--- variant ink. Text props + `size`.
function M.label(props)
  props.font_size = props.font_size or props.size or (theme.size.small - 2)
  props.size = nil
  props.font_weight = props.font_weight or 500
  props.color = props.color or M.ink("lo")
  props.height = props.height or math.ceil(props.font_size * 1.4)
  return M.text(props)
end

--- A big reading: `value` (fn -> string), `size`, `unit`, `color`.
function M.readout(spec)
  local size = spec.size or theme.size.extra
  local row = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, gap = 4, align = "end",
    M.text { text = spec.value, font_size = size, font_weight = 400, color = spec.color or M.ink("hi"),
      height = math.ceil(size * 1.15) },
  }
  if spec.unit then
    row[#row + 1] = M.label { text = spec.unit, size = math.max(10, math.floor(size * 0.4)),
      color = spec.unit_color or M.ink("lo") }
  end
  return ui.Row(row)
end

--- Material prints no decorative codes.
function M.code() return "" end

--- No decorations either: the call is accepted and the box it asked for
--- is kept, empty.
function M.decor(_, spec)
  if type(spec) ~= "table" then return nil end
  local w = spec.width or spec.length
  local h = spec.height or (spec.vertical and spec.length) or spec.size
  if w == nil and h == nil and spec.anchors == nil then return nil end
  return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h }
end

--- A caption row: a primary dot, the caption, a note at the right.
--- `width`, `text`, `note`, `color`. 14 high.
function M.caption(spec)
  local w = spec.width
  return ui.Item { id = spec.id, x = spec.x, y = spec.y, width = w, height = 14,
    ui.Rect { y = 3, width = 8, height = 8, radius = 4, color = spec.color or M.signal("accent") },
    M.label { x = 14, y = -2, height = 18, text = spec.text, size = theme.size.small - 1,
      color = M.ink("hi"), width = w - 140, elide = "right" },
    spec.note and M.label { anchors = { right = true }, y = -2, height = 18, text = spec.note,
      width = 124, horizontal_alignment = "right" } or nil,
  }
end

--- Label / value lines on alternating tonal pills. `rows` ({ label,
--- value }), `width`, `row_h` (17), `label_w` (half).
function M.facts(rows, width, row_h, label_w)
  row_h = row_h or 17
  label_w = label_w or math.floor(width * 0.5)
  local fs = math.min(theme.size.small - 1, math.floor(row_h * 0.72))
  local ty = math.floor((row_h - fs * 1.3) / 2)
  local node = { width = width, height = #rows * row_h }
  for k, r in ipairs(rows) do
    local y = (k - 1) * row_h
    if k % 2 == 1 then
      node[#node + 1] = ui.Rect { y = y, width = width, height = row_h, radius = row_h / 2,
        color = function() return theme.color.surfaceContainerHighest:alpha(0.55) end }
    end
    node[#node + 1] = M.text { x = 8, y = y + ty, text = (tostring(get(r[1]) or ""):gsub(":$", "")),
      font_size = fs, color = M.ink("lo"), width = label_w - 8, elide = "right" }
    node[#node + 1] = M.text { x = label_w, y = y + ty, text = r[2], font_size = fs, font_weight = 500,
      color = M.ink("hi"), width = width - label_w - 8, elide = "left", horizontal_alignment = "right" }
  end
  return ui.Item(node)
end

-- ------------------------------------------------------------ containers --

--- The strip a panel wears, read as Material: the card's title in title
--- medium, and -- only when a status is given -- a small dot in the
--- status colour with the word beside it in the variant ink, flush right.
--- No pill, no strip. `width`, `title`, `status`, `color`. 22 high.
function M.header(spec)
  local w = spec.width
  local color = spec.color or M.signal("accent")
  local has_status = spec.status ~= nil and spec.status ~= false
  local node = { id = spec.id, x = spec.x, y = spec.y, width = w, height = 22,
    M.text { x = 2, y = 0, height = 22, vertical_alignment = "center", text = spec.title or "",
      font_size = theme.size.normal, font_weight = 500, color = M.ink("hi"),
      width = has_status and w - 92 or w - 4, elide = "right" },
  }
  if has_status then
    local fs = theme.size.small - 2
    node[#node + 1] = ui.Row { anchors = { right = true, vertical_center = true, right_margin = 2 },
      gap = 6, align = "center",
      ui.Rect { width = 6, height = 6, radius = 3, color = color,
        behavior = { color = { duration = theme.duration.small } } },
      M.text { text = function() return sentence(get(spec.status)) end, font_size = fs, font_weight = 500,
        color = M.ink("lo") },
    }
  end
  return ui.Item(node)
end

--- A region: a rounded surfaceContainer box, with the header strip or a
--- title. `width`, `height`, `title`, `header`, `status`, `color`,
--- `radius` (20), children.
function M.panel(spec)
  local w, h = spec.width, spec.height
  local node = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
    clip = spec.clip, visible = spec.visible,
    ui.Rect { anchors = { fill = true }, radius = spec.radius or 20,
      color = function() return theme.color.surfaceContainer end },
  }
  local wn = get(w)
  if spec.header and type(wn) == "number" then
    node[#node + 1] = M.header { x = 14, y = 10, width = wn - 28, title = spec.title, status = spec.status,
      color = spec.color }
  elseif spec.title then
    node[#node + 1] = M.text { x = 16, y = 12, text = spec.title, font_size = theme.size.normal,
      font_weight = 500, color = spec.color or M.ink("hi") }
  end
  for _, child in ipairs(spec) do node[#node + 1] = child end
  return ui.Item(node)
end

--- A small tag: an M3 assist chip, rounded, tonal or `filled`. `text`,
--- `color`, `width` (fits the text). 13 high.
function M.chip(spec)
  local color = spec.color or M.signal("accent")
  local function word() return sentence(get(spec.text)) end
  local w = spec.width
  if w == nil then
    if type(spec.text) == "function" then w = function() return 12 + math.ceil(#word() * 5.2) end
    else w = 12 + math.ceil(#word() * 5.2) end
  end
  return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = 13,
    ui.Rect { anchors = { fill = true }, radius = 6.5,
      color = function() return spec.filled and get(color) or get(color):alpha(0.18) end },
    M.text { anchors = { center_in = true }, text = word, font_size = 9, font_weight = 600,
      color = spec.filled and function() return theme.color.surface end or color },
  }
end

-- -------------------------------------------------------------- controls --

--- No scroll-tracked effects to scope: the build runs as is.
function M.with_viewport(_, build) return build() end

--- The side panels' tabbed body (themes/layouts/tabbed.lua).
function M.tabbed(spec) return require("themes.layouts.tabbed").new(spec) end

-- -------------------------------------------------------------- readings --

--- A path whose outline morphs to the next one whenever `build()` gives
--- another (the same commands, other numbers): the two ends take turns, as
--- lib/m3shapes' Shape does, on the expressive spatial curve.
local function morphing(props, build, ms)
  local current = build()
  props.d, props.morph_to, props.morph_progress = current, current, 0
  props.behavior = props.behavior or {}
  props.behavior.morph_progress = spatial(ms or 520)
  local node = ui.Path(props)
  local at_end = false
  morf.effect("caelestia.material.morph", function()
    local d = build()
    if d == current then return end
    current = d
    if at_end then node.d, node.morph_progress = d, 0
    else node.morph_to, node.morph_progress = d, 1 end
    at_end = not at_end
  end, { owner = node })
  return node
end

--- An arc whose radius swings in `waves` even waves of `amp`: M3
--- expressive's wavy progress. The waves are uniform, so a trim of it
--- lands where a trim of the plain arc would.
local function wavy_arc(cx, cy, r, from, sweep, amp, waves)
  local n = math.max(48, math.ceil(sweep / 1.5))
  local d = {}
  for i = 0, n do
    local a = math.rad(from + sweep * i / n)
    local rr = r + amp * math.sin(2 * math.pi * waves * i / n)
    d[#d + 1] = ("%s%.2f %.2f"):format(i == 0 and "M" or "L", cx + rr * math.sin(a), cy - rr * math.cos(a))
  end
  return table.concat(d, " ")
end

--- A large gauge: a thick round-capped arc (wavy unless `wavy = false`),
--- a gap, the tonal track and its stop dot, round a tonal disc with the
--- reading. `size`, `value` (0..1), `color`, `text` (the percentage when
--- nil), `label`, `sweep` (300), `thickness`, `track`, `disc` (false for
--- none), `text_size`.
function M.ring(spec)
  local s = spec.size
  local sweep = spec.sweep or 300
  local from = sweep >= 360 and 0 or -sweep / 2
  local wavy = spec.wavy ~= false and s >= 64
  local thick = spec.thickness or (wavy and math.max(6, math.floor(s / 17)) or math.max(6, math.floor(s / 11)))
  local amp = wavy and thick * 0.42 or 0
  local r = s / 2 - thick / 2 - amp - 1
  local color = spec.color or M.signal("accent")
  local track = spec.track or function() return get(color):alpha(0.22) end
  local function v() return common.clamp01(get(spec.value)) end
  local length = 2 * math.pi * r * sweep / 360
  local gap = (thick + 5) / length
  local flat = M.arc_path(s / 2, s / 2, r, from, sweep)
  local active = flat
  if wavy then active = wavy_arc(s / 2, s / 2, r, from, sweep, amp, math.max(6, math.floor(length / (thick * 3.4)))) end
  local node = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s }
  if spec.disc ~= false then
    local ri = r - thick / 2 - math.max(5, s * 0.06)
    node[#node + 1] = ui.Rect { x = s / 2 - ri, y = s / 2 - ri, width = 2 * ri, height = 2 * ri, radius = ri,
      color = function() return theme.color.surfaceContainerHigh end }
  end
  node[#node + 1] = ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = flat,
    fill_color = "transparent", stroke_width = thick, stroke_cap = "round", stroke_color = track,
    trim_start = function() local x = v() return x <= 0 and 0 or math.min(1, x + gap) end,
    trim_end = function() return (sweep >= 360 and v() > 0) and math.max(0, 1 - gap) or 1 end,
    behavior = { trim_start = settle(), trim_end = settle() } }
  node[#node + 1] = ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = active,
    fill_color = "transparent", stroke_width = thick, stroke_cap = "round", stroke_join = "round",
    stroke_color = color, opacity = function() return v() > 0.002 and 1 or 0 end,
    trim_end = function() return math.max(0.001, v()) end, behavior = { trim_end = settle() } }
  if sweep < 360 then
    local a = math.rad(from + sweep)
    local dot = math.max(3, thick * 0.45)
    node[#node + 1] = ui.Rect { x = s / 2 + r * math.sin(a) - dot / 2, y = s / 2 - r * math.cos(a) - dot / 2,
      width = dot, height = dot, radius = dot / 2, color = color }
  end
  local text = spec.text or function() return ("%d%%"):format(math.floor(v() * 100 + 0.5)) end
  node[#node + 1] = ui.Column { anchors = { center_in = true }, gap = 0, align = "center",
    M.text { text = text, font_size = spec.text_size or math.floor(s * 0.2), font_weight = 500,
      color = M.ink("hi"), horizontal_alignment = "center" },
    spec.label and M.label { text = spec.label, horizontal_alignment = "center" } or nil,
  }
  for _, child in ipairs(spec) do node[#node + 1] = child end
  return ui.Item(node)
end

--- A small circular gauge with its caption under it. `size`, `value`,
--- `text`, `label`, `color`. `size` wide, `size` + 14 high.
function M.mini_ring(spec)
  local s = spec.size
  return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s + 14,
    M.ring { size = s, value = spec.value, color = spec.color, text = spec.text, sweep = 360, wavy = false,
      disc = false, thickness = math.max(4, math.floor(s / 12)), text_size = spec.text_size or math.floor(s * 0.22) },
    M.label { anchors = { horizontal_center = true }, y = s, height = 14, text = spec.label,
      horizontal_alignment = "center" },
  }
end

--- A level: a rounded pill track, the value in `color`, a gap, the tonal
--- rest and its stop dot. `width`, `height` (8), `value`, `color`,
--- `track`. (`count` is accepted; Material does not segment.)
function M.meter(spec)
  local color = spec.color or M.signal("accent")
  return M.bar { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = spec.width,
    stroke = spec.height or 8, color = color,
    value = function() return get(spec.value) end,
    track = spec.track or function() return get(color):alpha(0.22) end }
end

--- An emphasised fill: a tonal pill as tall as the box, filled with a
--- rounded bar. `width`, `height` (14), `value`, `color`.
function M.fill(spec)
  local w, h = spec.width, spec.height or 14
  local color = spec.color or M.signal("accent")
  local function v() return common.clamp01(get(spec.value)) end
  return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
    ui.Rect { anchors = { fill = true }, radius = h / 2, color = function() return get(color):alpha(0.18) end },
    ui.Rect { height = h, radius = h / 2, color = color,
      width = function() return v() <= 0 and 0 or math.max(h, v() * w) end, behavior = { width = settle() } },
  }
end

--- A vertical channel: a rounded column filled from the foot, a gap, the
--- tonal rest above. `width` (10), `height`, `value`, `color`.
function M.vmeter(spec)
  local w, h = spec.width or 10, spec.height
  local color = spec.color or M.signal("accent")
  local GAP = 3
  local function lit()
    local v = common.clamp01(get(spec.value))
    return v <= 0 and 0 or math.max(w, v * h)
  end
  return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
    ui.Rect { width = w, radius = w / 2, color = function() return get(color):alpha(0.22) end,
      height = function() local l = lit() return math.max(0, h - l - (l > 0 and GAP or 0)) end,
      behavior = { height = settle() } },
    ui.Rect { width = w, radius = w / 2, color = color,
      y = function() return h - lit() end, height = lit, behavior = { y = settle(), height = settle() } },
  }
end

-- A smooth curve through `pts` (Catmull-Rom as cubic Béziers), its
-- controls kept inside [lo, hi] vertically so it never swings past the box.
local function smooth(pts, lo, hi, closed)
  local n = #pts
  if n == 0 then return "" end
  local function at(i)
    if closed then return pts[(i - 1) % n + 1] end
    return pts[math.max(1, math.min(n, i))]
  end
  local function cy(y) return math.max(lo, math.min(hi, y)) end
  local d = { ("M%.2f %.2f"):format(pts[1][1], pts[1][2]) }
  local last = closed and n or n - 1
  for i = 1, last do
    local p0, p1, p2, p3 = at(i - 1), at(i), at(i + 1), at(i + 2)
    d[#d + 1] = ("C%.2f %.2f %.2f %.2f %.2f %.2f"):format(
      p1[1] + (p2[1] - p0[1]) / 6, cy(p1[2] + (p2[2] - p0[2]) / 6),
      p2[1] - (p3[1] - p1[1]) / 6, cy(p2[2] - (p3[2] - p1[2]) / 6), p2[1], p2[2])
  end
  if closed then d[#d + 1] = "Z" end
  return table.concat(d, " ")
end

--- A history chart: a soft-cornered tonal plot, the first series as a
--- smooth line over a fill that fades to nothing, the second a thinner
--- tertiary line, and a dot riding the newest value. `width`, `height`,
--- `samples`, `first` (fn -> list), `second`, `top` (n | fn; the peak when
--- nil), `bottom`, `floor`, `color`, `emphasis`/`hatch` (a stronger fill),
--- `caption`, `scale` (fn(top) -> string), `id`. Returns the node and
--- `top`. (`columns` is accepted; Material draws no grid columns.)
function M.chart(spec)
  local w, h = spec.width, spec.height
  local color = spec.color or M.signal("accent")
  local PAD = 4
  -- The series as data channels the paths draw: smooth curves made where
  -- they are painted, no Lua building them.
  local first, feed_first = channel.from(spec.first)
  local second, feed_second
  if spec.second then second, feed_second = channel.from(spec.second) end
  local function bottom() return get(spec.bottom) or 0 end
  local function top()
    if type(spec.top) == "function" then return math.max(bottom() + 1e-9, spec.top()) end
    if spec.top then return spec.top end
    local peak = math.max(bottom(), first:peak() or 0, second and second:peak() or 0)
    return math.max(peak * 1.15, bottom() + (spec.floor or 1))
  end
  local function ys(v, b, t) return h - PAD - (h - 2 * PAD) * common.clamp01((v - b) / math.max(1e-9, t - b)) end
  local function plot(kind)
    return function()
      return { kind = kind, smooth = true, width = w, height = h, samples = spec.samples, bottom = bottom(),
        top = top(), pad_top = PAD, pad_bottom = PAD }
    end
  end
  local strong = spec.emphasis or spec.hatch
  local grid = {}
  for k = 1, 3 do grid[#grid + 1] = ("M0 %g H%g "):format(math.floor(h * k / 4) + 0.5, w) end
  local box = { id = spec.id, width = w, height = h,
    ui.Rect { anchors = { fill = true }, radius = 14, color = function() return theme.color.surfaceContainerHigh end },
    ui.Path { anchors = { fill = true }, view_box = { 0, 0, w, h }, d = table.concat(grid),
      fill_color = "transparent", stroke_color = function() return theme.color.outlineVariant:alpha(0.35) end,
      stroke_width = 1 },
    ui.Rect { anchors = { fill = true },
      gradient = function()
        local c = get(color)
        return { angle = 180, stops = { { c:alpha(strong and 0.5 or 0.34), 0 }, { c:alpha(0), 1 } } }
      end,
      mask = ui.Path { width = w, height = h, view_box = { 0, 0, w, h },
        series = first.id, plot = plot("area"), fill_color = "#ffffff" } },
  }
  if spec.second then
    box[#box + 1] = ui.Path { anchors = { fill = true }, view_box = { 0, 0, w, h },
      series = second.id, plot = plot("line"), fill_color = "transparent",
      stroke_color = M.signal("extra"), stroke_width = 2, stroke_cap = "round", stroke_join = "round" }
  end
  box[#box + 1] = ui.Path { anchors = { fill = true }, view_box = { 0, 0, w, h },
    series = first.id, plot = plot("line"), fill_color = "transparent",
    stroke_color = color, stroke_width = 2.5, stroke_cap = "round", stroke_join = "round" }
  -- The newest value: a dot on a halo of the plot's tone, springing to it.
  local function head()
    return ys(first:last() or bottom(), bottom(), top())
  end
  box[#box + 1] = ui.Rect { x = w - 11, width = 10, height = 10, radius = 5, color = color,
    border_width = 2, border_color = function() return theme.color.surfaceContainerHigh end,
    y = function() return head() - 5 end, behavior = { y = M.spring(300, 30) } }
  if not spec.caption then
    box.x, box.y, box.anchors = spec.x, spec.y, spec.anchors
    local node = ui.Item(box)
    feed_first(node)
    if feed_second then feed_second(node) end
    return node, top
  end
  local node = ui.Item(box)
  feed_first(node)
  if feed_second then feed_second(node) end
  return ui.Column { x = spec.x, y = spec.y, anchors = spec.anchors, gap = 6,
    M.caption { width = w, text = spec.caption, color = color,
      note = spec.scale and function() return spec.scale(top()) end or nil },
    node,
  }, top
end

--- Bars, one per value, with rounded tops (capsules when `mirror`), all in
--- one path. `width`, `height`, `values` (fn -> list of 0..1), `color`,
--- `gap` (2).
function M.spectrum(spec)
  local w, h = spec.width, spec.height
  -- The bars are a data channel's (an audio monitor writes one with no Lua
  -- per frame), drawn where they are painted: rounded tops, capsules when
  -- mirrored, never shorter than their width or 4 px.
  local bars, feed = channel.from(spec.channel or spec.values, { size = 512 })
  local node = ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
    ui.Path { anchors = { fill = true }, view_box = { 0, 0, w, h }, series = bars.id,
      plot = { kind = "bars", width = w, height = h, gap = spec.gap or 2, radius = 8, min_bar = 4,
        mirror = spec.mirror == true },
      fill_color = spec.color or M.signal("accent") },
  }
  feed(node)
  return node
end

--- A soft blob over a round tonal web: the values as a smooth closed
--- curve that morphs to the next values. `size`, `values` (fn -> list of
--- 0..1), `axes` (6), `color`.
function M.radar(spec)
  local s = spec.size
  local c = s / 2
  local axes = spec.axes or 6
  local color = spec.color or M.signal("accent")
  local R = c - 4
  local function point(k, r)
    local a = math.rad(360 * k / axes)
    return { c + r * math.sin(a), c - r * math.cos(a) }
  end
  local function blob()
    local values = get(spec.values) or {}
    local pts = {}
    for k = 0, axes - 1 do pts[#pts + 1] = point(k, R * math.max(0.08, common.clamp01(values[k + 1] or 0))) end
    return smooth(pts, 0, s, true)
  end
  local function ring(r) return M.arc_path(c, c, r, 0, 360) end
  local node = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s,
    ui.Rect { x = c - R, y = c - R, width = 2 * R, height = 2 * R, radius = R,
      color = function() return theme.color.surfaceContainerHigh end },
    ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = ring(R * 2 / 3) .. " " .. ring(R / 3),
      fill_color = "transparent", stroke_color = function() return theme.color.outlineVariant:alpha(0.6) end,
      stroke_width = 1 },
  }
  for k = 0, axes - 1 do
    local p = point(k, R)
    node[#node + 1] = ui.Rect { x = p[1] - 2, y = p[2] - 2, width = 4, height = 4, radius = 2,
      color = function() return theme.color.outline end }
  end
  node[#node + 1] = morphing({ anchors = { fill = true }, view_box = { 0, 0, s, s },
    fill_color = function() return get(color):alpha(0.32) end, stroke_color = color, stroke_width = 2,
    stroke_join = "round" }, blob)
  return ui.Item(node)
end

--- Concentric rounded rings: an outline ring, the value as a thick round
--- arc on its tonal track with a dot springing round to its head, a tonal
--- disc and a small cookie at the centre. `size`, `value` (0..1), `color`.
function M.dial(spec)
  local s = spec.size
  local c = s / 2
  local color = spec.color or M.signal("accent")
  local thick = math.max(4, math.floor(s / 16))
  local r1 = c - thick / 2 - 6
  local r2 = r1 - thick / 2 - 6
  local function v() return common.clamp01(get(spec.value)) end
  local full = M.arc_path(c, c, r1, 0, 360)
  local dot = thick * 1.9
  local core = math.floor(s * 0.24)
  return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s,
    ui.Rect { x = 1, y = 1, width = s - 2, height = s - 2, radius = c - 1, color = "transparent",
      border_width = 1.5, border_color = function() return theme.color.outlineVariant end },
    ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = full, fill_color = "transparent",
      stroke_width = thick, stroke_color = function() return get(color):alpha(0.2) end },
    ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = full, fill_color = "transparent",
      stroke_width = thick, stroke_cap = "round", stroke_color = color,
      opacity = function() return v() > 0.002 and 1 or 0 end,
      trim_end = function() return math.max(0.001, v()) end, behavior = { trim_end = settle() } },
    ui.Rect { x = c - r2, y = c - r2, width = 2 * r2, height = 2 * r2, radius = r2,
      color = function() return theme.color.surfaceContainerHigh end },
    M.shape { x = c - core / 2, y = c - core / 2, width = core, height = core, shape = "cookie9",
      color = function() return get(color):alpha(0.45) end },
    ui.Item { anchors = { fill = true }, rotation = function() return 360 * v() end,
      behavior = { rotation = M.spring(200, 15) },
      ui.Rect { x = c - dot / 2, y = c - r1 - dot / 2, width = dot, height = dot, radius = dot / 2, color = color,
        border_width = 2, border_color = function() return theme.color.surfaceContainer end },
    },
  }
end

--- A rounded tonal tile with its number, tinted toward its level, and a
--- pill level along its foot. `width`, `height`, `value` (0..100), `text`
--- (fn; the value when nil), `label`.
function M.cell(spec)
  local w, h = spec.width, spec.height
  local function v() return tonumber(get(spec.value)) or 0 end
  local color = M.level(v)
  local text = spec.text or function() return ("%d"):format(math.floor(v() + 0.5)) end
  local fs = math.floor(math.min(h * 0.4, w * 0.3))
  return ui.Item { id = spec.id, x = spec.x, y = spec.y, width = w, height = h,
    ui.Rect { anchors = { fill = true }, radius = math.min(14, h / 3),
      color = function() return theme.color.surfaceContainerHigh:mix(get(color), 0.1) end,
      behavior = { color = { duration = theme.duration.normal } } },
    spec.label and M.label { x = 8, y = 4, text = spec.label, size = 9 } or nil,
    M.text { anchors = { horizontal_center = true }, y = math.floor((h - 8) / 2 - fs * 0.62), text = text,
      font_size = fs, font_weight = 500, color = M.ink("hi") },
    M.meter { x = 8, y = h - 9, width = w - 16, height = 4, color = color,
      value = function() return v() / 100 end },
  }
end

--- A readout card: a rounded tonal tile with a label, the value large and
--- a pill level at its foot. `width`, `height` (58), `label`, `value` (fn
--- -> string), `level` (fn -> 0..1; none when nil), `color`, `mark` ("solid"
--- | "dashed": a dot in the colour the chart draws it in).
function M.stat(spec)
  local w, h = spec.width, spec.height or 58
  local color = spec.color or M.signal("accent")
  local node = { id = spec.id, x = spec.x, y = spec.y, width = w, height = h,
    ui.Rect { anchors = { fill = true }, radius = 16, color = function() return theme.color.surfaceContainerHigh end },
    M.label { x = 12, y = 7, text = spec.label, width = w - 40, elide = "right" },
    M.text { x = 12, y = 22, text = spec.value, font_size = theme.size.large - 2, font_weight = 500,
      color = M.ink("hi"), width = w - 24, elide = "right" },
  }
  if spec.mark then
    node[#node + 1] = ui.Rect { x = w - 20, y = 11, width = 8, height = 8, radius = 4,
      color = spec.mark == "dashed" and M.signal("extra") or color }
  end
  if spec.level then
    node[#node + 1] = M.meter { x = 12, y = h - 11, width = w - 24, height = 4, value = spec.level, color = color }
  end
  return ui.Item(node)
end

--- Now / Avg / Peak of a series as three tonal tiles. `width`, `series`
--- (fn -> list), `top` (fn -> the full-scale value), `format` (fn(value)
--- -> string), `color`, `font_size`. 74 high.
function M.triplet(spec)
  local w = spec.width
  local cw = math.floor((w - 16) / 3)
  local function pick(i) return function() return (select(i, common.summary(get(spec.series)))) end end
  local items = { { "Now", pick(1) }, { "Average", pick(2) }, { "Peak", pick(3) } }
  local node = { id = spec.id, x = spec.x, y = spec.y, width = w, height = 74 }
  for i, item in ipairs(items) do
    local value = item[2]
    local function frac() return common.clamp01(value() / math.max(1e-9, get(spec.top) or 1)) end
    node[#node + 1] = ui.Item { x = (i - 1) * (cw + 8), width = cw, height = 74,
      ui.Rect { anchors = { fill = true }, radius = 16, color = function() return theme.color.surfaceContainerHigh end },
      M.label { x = 12, y = 8, text = item[1] },
      M.text { x = 12, y = 24, text = function() return spec.format(value()) end,
        font_size = spec.font_size or 19, font_weight = 500, color = M.ink("hi"), width = cw - 24, elide = "right" },
      M.meter { x = 12, y = 60, width = cw - 24, height = 4, value = frac,
        color = spec.color or M.level(function() return frac() * 100 end) },
    }
  end
  return ui.Item(node)
end

-- ---------------------------------------------------------------- status --

-- Each kind an M3 expressive shape and a glyph; a change morphs the shape
-- into the next one while it turns once on the spatial curve.
local EMBLEM = {
  ok = { shape = "cookie9", icon = "check" },
  warn = { shape = "triangle", icon = "priority_high", lift = 0.07 },
  alert = { shape = "soft_burst", icon = "priority_high" },
  info = { shape = "cookie4", icon = "info_i" },
}

--- A status mark: `kind` (alert, warn, ok, info; may be a binding),
--- `size` (48), `color` (the kind's signal).
function M.emblem(spec)
  local s = spec.size or 48
  local function kind() local k = get(spec.kind) return EMBLEM[k] and k or "info" end
  local color = spec.color or function() return M.signal(kind())() end
  local turns, last = 0, kind()
  local function turn()
    local k = kind()
    if k ~= last then last, turns = k, turns + 1 end
    return turns * 360
  end
  return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s,
    ui.Item { anchors = { fill = true }, rotation = turn, behavior = { rotation = spatial(650) },
      M.shape { anchors = { fill = true }, shape = function() return EMBLEM[kind()].shape end, color = color,
        behavior = { morph_progress = spatial(450), fill_color = { duration = theme.duration.small } } },
    },
    M.icon(function() return EMBLEM[kind()].icon end, math.floor(s * 0.5), function() return theme.color.surface end,
      { anchors = { horizontal_center = true, vertical_center = true },
        y = function() return s * (EMBLEM[kind()].lift or 0) end, fill = true }),
  }
end

-- The status banner both status_line and status draw: a tonal pill the
-- kind's colour, the emblem at its start, the word and its subtitle, and a
-- solid pill of the colour trailing at its end.
local function banner(spec, default)
  local w, s = spec.width, spec.size or default
  local function kind() return get(spec.kind) or "info" end
  local color = spec.color or function() return M.signal(kind())() end
  local trail = math.min(64, math.floor(w * 0.14))
  local tw = w - s - trail - 28
  local fs = math.floor(s * 0.38)
  local block = fs * 1.3 + (spec.subtitle and 14 or 0)
  local ty = math.floor((s - block) / 2)
  local ph = math.max(6, math.floor(s * 0.26))
  return ui.Item { id = spec.id, x = spec.x, y = spec.y, width = w, height = s,
    ui.Rect { anchors = { fill = true }, radius = s / 2,
      color = function() return get(color):alpha(0.14) end, behavior = { color = { duration = theme.duration.normal } } },
    M.emblem { x = 4, y = 4, size = s - 8, kind = kind, color = color },
    M.text { x = s + 6, y = ty, text = spec.title, font_size = fs, font_weight = 500, color = M.ink("hi"),
      width = tw, elide = "right" },
    spec.subtitle and M.label { x = s + 6, y = ty + fs * 1.3 - 1, height = 14, text = spec.subtitle,
      color = color, width = tw, elide = "right" } or nil,
    ui.Rect { x = w - trail - s * 0.3, y = (s - ph) / 2, width = trail, height = ph, radius = ph / 2, color = color },
  }
end

--- Mark + word + trailing emphasis: `kind`, `title`, `subtitle`, `width`,
--- `size` (46).
function M.status_line(spec) return banner(spec, 46) end

--- The live status strip: `width`, `kind` (fn), `title` (fn), `subtitle`
--- (fn), `size` (40).
function M.status(spec) return banner(spec, 40) end

-- ------------------------------------------------- requested additions --
-- (the kit contract)

--- A radius in Material's own measure: Material is the measure.
function M.round(r) return r end

--- The highlight under a list's chosen row: one rounded box in a distance
--- field, riding `track` (an item the layout springs from row to row), so
--- it stretches towards the next row and settles round there. `track`,
--- `color` (a tonal wash of the ink), `radius` (12), `stretch` (false to
--- leave the track's own motion alone), `id`, `anchors`, `z`.
local SELECT_STRETCH = { stiffness = 300, damping = 15, scale = 0.1, max = 0.22 }
function M.selection(spec)
  local track = spec.track
  if track and spec.stretch ~= false then
    local ok, current = pcall(function() return track.stretch end)
    if ok and not current then track.stretch = spec.stretch or SELECT_STRETCH end
  end
  return ui.Sdf { id = spec.id, x = spec.x, y = spec.y, width = spec.width, height = spec.height,
    anchors = spec.anchors or (spec.width == nil and { fill = true } or nil), z = spec.z or -1,
    ui.SdfShape { shape = "box", radius = spec.radius or 12, track = track,
      fill_color = spec.color or function() return theme.color.onSurface:alpha(0.12) end },
  }
end

-- The container and its ink for a state surface's tone.
local TONES = {
  primary = { "primary", "onPrimary" },
  secondary = { "secondaryContainer", "onSecondaryContainer" },
  tertiary = { "tertiaryContainer", "onTertiaryContainer" },
  error = { "errorContainer", "onErrorContainer" },
}

--- The background of a stateful control: one rounded shape in every state,
--- the tone's container while on, the highest surface while off, each with its state
--- layer (hover 8 %, press 12 %). `area` (the MouseArea it backs: given as
--- a node it is put behind its children; or a function returning it),
--- `on` (fn), `height` (for the radii; the area's), `tone` ("primary",
--- "secondary", "tertiary", "error"), `pressed` (fn, more presses that
--- count, e.g. a nested button), `radius_on` (h * 0.28, used in all states), `id`.
function M.state_surface(spec)
  local on = spec.on or function() return false end
  local tone = TONES[spec.tone or "primary"] or TONES.primary
  local function area() return get(spec.area) end
  local is_node = spec.area ~= nil and type(spec.area) ~= "function"
  local h = spec.height or (is_node and tonumber(spec.area.height)) or 56
  local radius = math.min(h/2, spec.radius_on or math.max(8, math.floor(h * 0.28)))
  local function pressed()
    local a = area()
    return (a and a.pressed) or (spec.pressed and spec.pressed()) or false
  end
  local node = ui.Rect {
    id = spec.id, z = -1, anchors = spec.anchors or { fill = true },
    radius = radius,
    color = function()
      local c = theme.color
      local base, ink = c.surfaceContainerHighest, c.onSurface
      if on() then base, ink = c[tone[1]], c[tone[2]] end
      local a = area()
      if pressed() then return base:mix(ink, 0.12) end
      if a and a.hovered then return base:mix(ink, 0.08) end
      return base
    end,
    behavior = {
      color = { duration = theme.duration.small, easing = theme.ease.standard },
    },
  }
  if is_node then ui.reparent(node, spec.area) end
  return node
end

local function glyphs(s)
  local ok, n = pcall(utf8.len, s)
  return ok and n or #s
end

--- A key hint cap: a tonal rounded key with its legend. `text`, `height`
--- (22), `width` (fits the legend), `id`, `x`, `y`, `anchors`.
function M.keycap(spec)
  local h = spec.height or 22
  local function legend() return tostring(get(spec.text) or "") end
  local function fit() return math.max(h + 4, glyphs(legend()) * 8 + 14) end
  local w = spec.width or (type(spec.text) == "function" and fit or fit())
  return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
    ui.Rect { anchors = { fill = true }, radius = math.floor(h * 0.36),
      color = function() return theme.color.surfaceContainerHighest end },
    M.text { anchors = { center_in = true }, text = legend, font_size = theme.size.small - 1, font_weight = 600,
      color = M.ink("lo") },
  }
end

--- The well a text input sits in: an M3 filled text field -- a tonal fill
--- with rounded top corners and an active indicator along the foot, which
--- thickens from the middle out and takes the primary colour on focus, or
--- the error colour while `error()`. `width`, `height` (48), `focused` (fn),
--- `error` (fn), `id`, `x`, `y`, `anchors`, `visible`, children (laid over
--- the fill, under the indicator).
function M.field(spec)
  local w, h = spec.width, spec.height or 48
  local focused = spec.focused or function() return false end
  local err = spec.error or function() return false end
  local r = math.min(12, math.floor(h / 4))
  local grow = M.spring(460, 30)
  local node = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
    visible = spec.visible,
    ui.Rect { anchors = { fill = true }, top_left_radius = r, top_right_radius = r,
      color = function()
        local c = theme.color
        if err() then return c.surfaceContainerHighest:mix(c.error, 0.06) end
        return c.surfaceContainerHighest
      end,
      behavior = { color = { duration = theme.duration.small } } },
  }
  for _, child in ipairs(spec) do node[#node + 1] = child end
  node[#node + 1] = ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
    color = function()
      local c = theme.color
      return err() and c.error or c.onSurfaceVariant:alpha(0.75)
    end,
    behavior = { color = { duration = theme.duration.small } } }
  node[#node + 1] = ui.Rect { anchors = { bottom = true }, height = 2,
    x = function() return focused() and 0 or get(w) / 2 end,
    width = function() return focused() and get(w) or 0 end,
    color = function() return err() and theme.color.error or theme.color.primary end,
    behavior = { x = grow, width = grow, color = { duration = theme.duration.small } } }
  return ui.Item(node)
end


--- The shell's on-screen keyboard in Material's colours: keys on the
--- highest surface, the function keys (shift, backspace, ?123) in the
--- secondary container, the accent key primary, a press in the primary
--- container; the keys keep lib.osk's rounding (about a quarter of their
--- height) unless the look names one.
function M.keyboard_look(look)
  look = look or {}
  look.panel = function() return theme.color.surfaceContainer:alpha(0) end
  look.key = function() return theme.color.surfaceContainerHighest end
  look.key_dim = function() return theme.color.secondaryContainer end
  look.accent = function() return theme.color.primary end
  look.on_accent = function() return theme.color.onPrimary end
  look.text = function() return theme.color.onSurface end
  look.dim = function() return theme.color.onSurfaceVariant end
  look.press = function() return theme.color.primaryContainer end
  if look.radius == 0 then look.radius = nil end
  return look
end


--- The ink on a `state_surface` ground: Material fills the tone, so the
--- tone's on-colour while on.
function M.state_ink(spec)
  return function()
    local C = theme.color
    if spec.on and spec.on() == true then
      return spec.tone == "secondary" and C.onSecondaryContainer or C.onPrimary
    end
    return spec.idle or C.onSurface
  end
end

--- A state word in the theme's voice: Material says it plainly.
function M.term(_, plain) return plain end

for name, skin in pairs(require("themes.material.skins")(theme, M)) do M.skins[name] = skin end

-- The display widgets this file does not draw itself, from the shared
-- composition in this theme's style.
require("lib.kit.display").install(M, require("themes.material.display_style")(theme, M))

return M
end
