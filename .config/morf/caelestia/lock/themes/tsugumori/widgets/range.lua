-- Tsugumori's looks for the Range widgets beyond the plain slider
-- (skins.lua draws it, the media rail and the scroll bar): square and
-- technical -- faint framed bands, hatched runs whose clip moves while the
-- stripes stay put, tick rulers, block handles, readouts in the mono face
-- padded with zeros. Knobs are instrument dials: a segmented outer ring,
-- a ruler, a dashed value arc trimmed to the position and a needle turned
-- by `rotation`. The behaviour is the archetype's
-- (crates/morf-kit/src/range.rs).
local morf = require("morf")
local ui = require("morf.ui")
local stripes = require("themes.tsugumori.stripes")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local arc = morf.geometry.arc
  local function get(v) if type(v) == "function" then return v() end return v end
  local function clamp01(v) v = tonumber(v) or 0 return v < 0 and 0 or (v > 1 and 1 or v) end
  local function num(v, d) v = get(v) return type(v) == "number" and v or d end
  local quick = { duration = 140, easing = "out_cubic" }
  local follow = { duration = 90, easing = "out_cubic" }

  local SLOTS = { "background", "track", "fill", "ticks", "handle", "second_handle", "value_label", "increase",
    "decrease", "content" }
  local function full(slots)
    for _, name in ipairs(SLOTS) do if slots[name] == nil then slots[name] = ui.Item {} end end
    return slots
  end
  --- The keyboard's four brackets over `box` (the whole control when nil).
  local function brackets(t, box)
    return function()
      local holder = ui.Item { z = 50, visible = function() return t.visual_focus end }
      if box then holder.x, holder.y, holder.width, holder.height = box[1], box[2], box[3], box[4]
      else holder.anchors = { fill = true } end
      ui.reparent(hud().corners { length = 6, weight = 2, color = function() return C.primary end }, holder)
      return holder
    end
  end
  local function path(w, h, props)
    props.width, props.height, props.view_box = w, h, { 0, 0, w, h }
    if props.fill_color == nil then props.fill_color = "transparent" end
    return ui.Path(props)
  end
  local function engaged(t) return function() return t.hovered or t.down end end
  local function ink(t) return function() return (t.hovered or t.down) and C.primary or C.onSurfaceVariant end end
  local function readout(props)
    props.font_size = props.font_size or 12
    props.height = props.height or 18
    props.vertical_alignment = props.vertical_alignment or "center"
    props.color = props.color or function() return C.onSurfaceVariant end
    return M.text(props)
  end
  -- A level's reading: its percent, or what `spec.reading(position)` says.
  local function pct(t, spec)
    return function()
      if spec and spec.reading then return spec.reading(clamp01(t.position)) end
      return ("%03d"):format(math.floor(clamp01(t.position) * 100 + 0.5))
    end
  end
  local function trim(v) local s = ("%.2f"):format(v) s = s:gsub("0+$", ""):gsub("%.$", "") return s end
  local function hz(v)
    if v >= 1000 then return trim(v / 1000) .. "K HZ" end
    return ("%d HZ"):format(math.floor(v + 0.5))
  end
  local function vis(t, p) return t.mirrored and 1 - p or p end
  local function ruler(x, y, len, size, color, vertical)
    local w, h = vertical and size or len, vertical and len or size
    return path(w, h, { x = x, y = y, stroke_width = 1, stroke_color = color,
      d = morf.geometry.ruler(len, size, { pitch = 8, major = 5, min_count = 4, vertical = vertical }) })
  end
  local function faint() return C.primary:alpha(.32) end

  --- A faint framed band `w` x `h` at (`x`, `y`).
  local function band(t, x, y, w, h)
    return ui.Rect { x = x, y = y, width = w, height = h,
      color = function() return C.primary:alpha((t.hovered or t.down) and .1 or .06) end,
      border_width = 1, border_color = function() return C.primary:alpha(.18) end, behavior = { color = quick } }
  end
  --- A hatched run across a band at (`x`, `y`), `w` x `h`, shown from `a`
  --- to `b` (bindings, px from the band's start; `vertical`: down it).
  --- Only the clip moves; the stripes stay put.
  local function run(x, y, w, h, a, b, vertical, id)
    local inner = ui.Item { width = w, height = h,
      x = vertical and 0 or function() return -a() end, y = vertical and function() return -a() end or 0,
      ui.Rect { width = w, height = h, color = function() return C.primary:alpha(.2) end },
      stripes.box { width = w, height = h, gap = 6, weight = 2, color = function() return C.primary end } }
    local clip = { id = id, clip = true, inner, behavior = vertical and { y = follow, height = follow } or { x = follow, width = follow },
      visible = function() return b() - a() > 0.5 end }
    if vertical then
      clip.x, clip.width = x, w
      clip.y = function() return y + a() end
      clip.height = function() return math.max(1e-3, b() - a()) end
    else
      clip.y, clip.height = y, h
      clip.x = function() return x + a() end
      clip.width = function() return math.max(1e-3, b() - a()) end
    end
    return ui.Item(clip)
  end
  --- A block handle: a solid bar `w` x `h` centred on `at` along x (or y).
  local function block(at, cross, w, h, vertical, id)
    if vertical then
      return ui.Rect { id = id, x = cross - w / 2, width = w, height = h, y = function() return at() - h / 2 end,
        behavior = { y = follow }, color = function() return C.primary end }
    end
    return ui.Rect { id = id, y = cross - h / 2, width = w, height = h, x = function() return at() - w / 2 end,
      behavior = { x = follow }, color = function() return C.primary end }
  end

  --- The house scale: a band from `left` across `span` at `by` (`bh`
  --- deep), hatched to the value, a block handle. Returns slots and `hx`.
  local function scale(t, o)
    local left, span, by, bh = o.left, o.span, o.by, o.bh
    local function hx() return left + span * clamp01(t.visual_position) end
    local function a() return t.mirrored and hx() - left or 0 end
    local function b() return t.mirrored and span or hx() - left end
    return {
      track = ui.Item { x = left, y = by - 6, width = span, height = bh + 12 },
      background = ui.Item { width = o.W, height = o.H, band(t, left, by, span, bh) },
      fill = run(left, by, span, bh, a, b, false),
      handle = block(hx, by + bh / 2, 6, bh + 8),
    }, hx
  end

  -- ------------------------------------------------------------ scales --

  --- Stops at every step: a tick for each under the band, the lit ones
  --- in the accent, the value in two digits.
  function S.discrete_slider(t, spec)
    local W, H = num(spec.width, 240), num(spec.height, 48)
    local from, to, step = num(spec.from, 0), num(spec.to, 10), num(spec.step, 1)
    local n = math.max(1, math.floor(math.abs(to - from) / math.max(step, 1e-9) + 0.5))
    local left, span, by, bh = 0, W - 46, 12, 16
    local slots = scale(t, { W = W, H = H, left = left, span = span, by = by, bh = bh })
    local ticks = ui.Item {}
    for i = 0, n do
      local f = i / n
      ui.reparent(ui.Rect { width = 2, height = (i == 0 or i == n) and 8 or 5, y = by + bh + 4,
        x = function() return left + span * vis(t, f) - 1 end,
        color = function() return clamp01(t.position) >= f - 1e-6 and C.primary or faint() end }, ticks)
    end
    slots.ticks = ticks
    slots.value_label = readout { x = W - 40, width = 40, y = by + bh / 2 - 9, horizontal_alignment = "right",
      color = ink(t), text = function() return ("%02d"):format(math.floor((t.value or 0) + 0.5)) end }
    slots.second_handle = brackets(t)
    return full(slots)
  end

  --- A logarithmic slider: decades ticked and named under the band, the
  --- value at the end.
  function S.log_slider(t, spec)
    local W, H = num(spec.width, 260), num(spec.height, 52)
    local from, to = num(spec.from, 20), num(spec.to, 20000)
    local left, span, by, bh = 0, W - 70, 6, 16
    local slots = scale(t, { W = W, H = H, left = left, span = span, by = by, bh = bh })
    local format = spec.format or hz
    local names = ui.Item {}
    local decade = 10 ^ math.ceil(math.log(from, 10) - 1e-9)
    while decade <= to * 1.0001 do
      local p = math.log(decade / from) / math.log(to / from)
      if p > 0.02 and p < 0.98 then
        local label = decade >= 1000 and (trim(decade / 1000) .. "K") or tostring(math.floor(decade))
        ui.reparent(ui.Rect { width = 1, height = 7, y = by + bh + 2, x = function() return left + span * vis(t, p) end,
          color = function() return C.primary:alpha(.6) end }, names)
        ui.reparent(readout { width = 40, horizontal_alignment = "center", y = by + bh + 10, text = label,
          x = function() return left + span * vis(t, p) - 20 end }, names)
      end
      decade = decade * 10
    end
    -- The minor ruler under the band.
    ui.reparent(ruler(left, by + bh + 2, span, 4, function() return C.primary:alpha(.22) end), slots.background)
    slots.ticks = names
    slots.value_label = readout { x = W - 66, width = 66, y = by + bh / 2 - 9, horizontal_alignment = "right",
      color = ink(t), text = function() return format(t.value or from) end }
    slots.second_handle = brackets(t)
    return full(slots)
  end

  --- Two block handles on one band, hatched between them, the pair read
  --- above in three digits each.
  function S.range_slider(t, spec)
    local W, H = num(spec.width, 240), num(spec.height, 56)
    local left, span, by, bh = 3, W - 6, 28, 16
    local function ax() return left + span * clamp01(t.first_visual_position) end
    local function bx() return left + span * clamp01(t.second_visual_position) end
    local format = spec.format or function(v) return ("%03d"):format(math.floor(v * 100 + 0.5)) end
    return full {
      track = ui.Item { x = left, y = by - 6, width = span, height = bh + 12 },
      background = ui.Item { width = W, height = H, band(t, left, by, span, bh),
        ruler(left, by + bh + 3, span, 5, function() return C.primary:alpha(.28) end) },
      fill = run(left, by, span, bh, function() return math.min(ax(), bx()) - left end,
        function() return math.max(ax(), bx()) - left end, false),
      handle = block(ax, by + bh / 2, 6, bh + 8),
      second_handle = block(bx, by + bh / 2, 6, bh + 8),
      value_label = readout { x = 0, width = W, y = 0, horizontal_alignment = "right", color = ink(t),
        text = function() return format(t.first or 0) .. " — " .. format(t.second or 0) end },
      ticks = brackets(t),
    }
  end

  --- An upright band hatched up from its foot, a ruler beside it, a flat
  --- block handle, the reading under it.
  local function vscale(t, W, top, bottom, cx, bw)
    local span = bottom - top
    local function hy() return top + span * clamp01(t.visual_position) end
    return {
      track = ui.Item { x = 0, y = top, width = W, height = span },
      background = ui.Item { band(t, cx - bw / 2, top, bw, span) },
      fill = run(cx - bw / 2, top, bw, span, function() return hy() - top end, function() return span end, true),
      handle = block(hy, cx, bw + 12, 6, true),
    }, hy
  end

  function S.vertical_slider(t, spec)
    local W, H = num(spec.width, 48), num(spec.height, 200)
    local top, bottom, cx, bw = 4, H - 28, W / 2 - 4, 14
    local slots = vscale(t, W, top, bottom, cx, bw)
    slots.background.width, slots.background.height = W, H
    ui.reparent(ruler(cx + bw / 2 + 4, top, bottom - top, 6, function() return C.primary:alpha(.32) end, true),
      slots.background)
    slots.value_label = readout { x = 0, width = W, y = H - 20, horizontal_alignment = "center", color = ink(t),
      text = pct(t, spec) }
    slots.second_handle = brackets(t)
    return full(slots)
  end

  --- A console fader: a framed slot hatched up to a ribbed block cap, a
  --- ruler either side named in dB, the level under it.
  local FADER = { { 1, "+6" }, { 0.75, "0" }, { 0.5, "-10" }, { 0.25, "-30" }, { 0, "-∞" } }
  local function db(p)
    if p <= 0.001 then return "-∞ DB" end
    for i = 1, #FADER - 1 do
      local a, b = FADER[i], FADER[i + 1]
      if p <= a[1] and p >= b[1] then
        local va, vb = tonumber(a[2]) or 0, tonumber(b[2]) or -60
        return ("%+.1f DB"):format(vb + (va - vb) * (p - b[1]) / (a[1] - b[1]))
      end
    end
    return "+6.0 DB"
  end
  function S.fader(t, spec)
    local W, H = num(spec.width, 76), num(spec.height, 200)
    local top, bottom, cx, bw = 8, H - 30, 48, 8
    local span = bottom - top
    local slots, hy = vscale(t, W, top, bottom, cx, bw)
    slots.background.width, slots.background.height = W, H
    ui.reparent(ruler(cx - bw / 2 - 12, top, span, 8, function() return C.primary:alpha(.32) end, true), slots.background)
    ui.reparent(ruler(cx + bw / 2 + 4, top, span, 8, function() return C.primary:alpha(.32) end, true), slots.background)
    local names = ui.Item {}
    for _, mark in ipairs(FADER) do
      ui.reparent(readout { x = 0, width = 24, horizontal_alignment = "right", y = top + span * (1 - mark[1]) - 9,
        text = mark[2] }, names)
    end
    slots.ticks = names
    ui.destroy(slots.handle, true)
    local CW, CH = 32, 16
    slots.handle = ui.Rect { x = cx - CW / 2, width = CW, height = CH, y = function() return hy() - CH / 2 end,
      behavior = { y = follow }, color = function() return C.surfaceContainerHigh end,
      border_width = 1, border_color = function() return C.primary end,
      ui.Rect { x = 0, y = CH / 2 - 1, width = CW, height = 2, color = function() return C.primary end },
      ui.Rect { x = 4, y = 3, width = CW - 8, height = 1, color = function() return C.primary:alpha(.4) end },
      ui.Rect { x = 4, y = CH - 4, width = CW - 8, height = 1, color = function() return C.primary:alpha(.4) end } }
    slots.value_label = readout { x = 0, width = W, y = H - 20, horizontal_alignment = "center", color = ink(t),
      text = function() return db(clamp01(t.position)) end }
    slots.second_handle = brackets(t)
    return full(slots)
  end

  --- A system level: its icon, the band hatched to the value, the
  --- reading in three digits.
  local function level(t, spec, icons, spin)
    local W, H = num(spec.width, 260), num(spec.height, 48)
    local left, by, bh = 34, math.floor(H / 2) - 8, 16
    local span = W - left - 48
    local slots = scale(t, { W = W, H = H, left = left, span = span, by = by, bh = bh })
    ui.reparent(ruler(left, by + bh + 3, span, 5, function() return C.primary:alpha(.28) end), slots.background)
    slots.decrease = M.icon(function() return icons(clamp01(t.position), get(spec.muted)) end, 20, ink(t),
      { x = 2, y = by + bh / 2 - 11, width = 22, height = 22, horizontal_alignment = "center",
        vertical_alignment = "center", rotation = spin and function() return clamp01(t.position) * 90 end or nil,
        behavior = spin and { rotation = quick } or nil })
    -- `reading(position)`: what the level says instead of its percent.
    local said = pct(t, spec)
    slots.value_label = readout { x = W - 52, width = 52, y = by + bh / 2 - 9, horizontal_alignment = "right",
      color = ink(t), text = said }
    slots.second_handle = brackets(t)
    return full(slots)
  end
  local function volume_icon(p, muted)
    if muted or p <= 0 then return "volume_off" end
    if p < 0.34 then return "volume_mute" end
    if p < 0.67 then return "volume_down" end
    return "volume_up"
  end
  local function brightness_icon(p)
    if p < 0.34 then return "brightness_low" end
    if p < 0.67 then return "brightness_medium" end
    return "brightness_high"
  end
  function S.volume(t, spec) return level(t, spec, volume_icon, false) end
  function S.brightness(t, spec) return level(t, spec, brightness_icon, true) end

  --- A framed icon key that sends `event`.
  local function key(send, icon, event, x, y, size)
    return require("lib.kit.widgets").icon { x = x, y = y, width = size, height = size, size = 18,
      icon = icon, icon_off = icon, on_clicked = function() send(event) end }
  end

  --- Zoom out and in keys either side of the band, a tall tick at 1:1,
  --- the zoom read at the end.
  function S.zoom(t, spec, _, send)
    local W, H = num(spec.width, 270), num(spec.height, 48)
    local from, to = num(spec.from, 0.25), num(spec.to, 4)
    local B = 30
    local by, bh = math.floor(H / 2) - 8, 16
    local left = B + 8
    local span = W - left - 8 - B - 52
    local slots = scale(t, { W = W, H = H, left = left, span = span, by = by, bh = bh })
    local one = (from < 1 and to > 1) and math.log(1 / from) / math.log(to / from) or nil
    if one then
      slots.ticks = ui.Rect { width = 1, height = bh + 12, y = by - 6,
        x = function() return left + span * vis(t, one) end, color = function() return C.onSurface:alpha(.6) end }
    end
    slots.decrease = key(send, "zoom_out", "decrease", 0, math.floor(H / 2) - B / 2, B)
    slots.increase = key(send, "zoom_in", "increase", left + span + 8, math.floor(H / 2) - B / 2, B)
    slots.value_label = readout { x = W - 48, width = 48, y = by + bh / 2 - 9, horizontal_alignment = "right",
      color = ink(t), text = function() return ("%03d%%"):format(math.floor((t.value or 1) * 100 + 0.5)) end }
    slots.second_handle = brackets(t)
    return full(slots)
  end

  -- ------------------------------------------------------------- knobs --

  --- A knob as an instrument dial: a segmented outer ring, a ruler round
  --- the sweep (`angle_from` across `angle_sweep`), a dashed value arc
  --- trimmed to the position -- from the middle for a bipolar one, square
  --- detents for a stepped one -- and a needle to the rim at `t.angle`.
  local function dial_knob(t, spec, kind)
    local Sz = num(spec.size, nil) or math.min(num(spec.width, 96), num(spec.height, 118) - 22)
    local W, H = Sz, Sz + 22
    local c = Sz / 2
    local from_a, sweep = num(spec.angle_from, -135), num(spec.angle_sweep, 270)
    local r0 = c - 1
    local r1 = r0 - 5
    local th = 6
    local r2 = r1 - 4 - th / 2
    local r3 = r2 - th / 2 - 5
    local function p() return clamp01(t.position) end
    local back = ui.Item { width = W, height = H,
      path(Sz, Sz, { d = arc(c, c, r0, 0, 360), stroke_width = 1, stroke_color = function() return C.primary:alpha(.24) end,
        dash = { math.max(0.5, math.pi * 2 * r0 / 40 - 3), 3 } }),
      path(Sz, Sz, { d = morf.geometry.ticks(c, c, r1 - 2, r1, { from = from_a, sweep = sweep, count = 28, major = 3,
        major_r0 = r1 - 5 }), stroke_width = 1, stroke_color = function() return C.primary:alpha(.6) end }),
      ui.Rect { x = c - r3, y = c - r3, width = 2 * r3, height = 2 * r3, radius = r3,
        color = function() return C.surfaceContainer end,
        border_width = 1, border_color = function() return C.primary:alpha((t.hovered or t.down) and .6 or .3) end,
        behavior = { border_color = quick } },
    }
    local slots = { track = ui.Item { width = Sz, height = Sz }, background = back }
    local seg = { 3, 2 }
    if kind == "stepped" then
      local lo, hi, step = num(spec.from, 0), num(spec.to, 10), num(spec.step, 1)
      local n = math.max(1, math.floor(math.abs(hi - lo) / math.max(step, 1e-9) + 0.5))
      local marks = ui.Item { width = Sz, height = Sz }
      for i = 0, n do
        local a = from_a + sweep * i / n
        ui.reparent(ui.Item { width = Sz, height = Sz, rotation = a,
          ui.Rect { x = c - 3, y = c - r2 - th / 2, width = 6, height = th,
            color = function() return p() >= i / n - 1e-6 and C.primary or C.primary:alpha(.16) end,
            behavior = { color = quick } } }, marks)
      end
      slots.ticks = marks
    else
      ui.reparent(path(Sz, Sz, { d = arc(c, c, r2, from_a, sweep), stroke_width = th, dash = seg,
        stroke_color = function() return C.primary:alpha(.14) end }), back)
      local mid = kind == "bipolar" and 0.5 or 0
      local up = path(Sz, Sz, { d = arc(c, c, r2, from_a + sweep * mid, sweep * (1 - mid)), stroke_width = th, dash = seg,
        stroke_color = function() return C.primary end,
        trim_end = function() return math.max(0.001, (p() - mid) / (1 - mid)) end,
        visible = function() return p() > mid + 0.002 end, behavior = { trim_end = follow } })
      if kind == "bipolar" then
        local down = path(Sz, Sz, { d = arc(c, c, r2, from_a, sweep * mid), stroke_width = th, dash = seg,
          stroke_color = function() return C.primary end,
          trim_start = function() return math.min(0.999, p() / mid) end,
          visible = function() return p() < mid - 0.002 end, behavior = { trim_start = follow } })
        slots.fill = ui.Item { width = Sz, height = Sz, up, down,
          ui.Rect { x = c - 1, y = 0, width = 2, height = r0 - r2 + th / 2, color = function() return C.onSurface end } }
      else
        slots.fill = up
      end
    end
    -- The needle: a bright bar from inside the dial out across the arc.
    slots.handle = ui.Item { width = Sz, height = Sz, rotation = function() return t.angle or 0 end,
      behavior = { rotation = follow },
      ui.Rect { x = c - 1, y = c - r1, width = 2, height = r1 - r3 + 10, color = function() return C.onSurface end },
      ui.Rect { x = c - 3, y = c - r3 + 3, width = 6, height = 6, color = function() return C.primary end } }
    local format = spec.format or function(v)
      if kind == "bipolar" then
        if math.abs(v) < 0.005 then return "C000" end
        return ("%s%03d"):format(v < 0 and "L" or "R", math.floor(math.abs(v) * 100 + 0.5))
      elseif kind == "stepped" then return ("%02d"):format(math.floor(v + 0.5)) end
      return ("%03d"):format(math.floor(clamp01(t.position) * 100 + 0.5))
    end
    slots.value_label = readout { x = 0, width = W, y = Sz + 3, horizontal_alignment = "center", color = ink(t),
      text = function() return format(t.value or 0) end }
    slots.second_handle = brackets(t, { 0, 0, Sz, Sz })
    return full(slots)
  end
  function S.knob(t, spec) return dial_knob(t, spec, "plain") end
  function S.bipolar_knob(t, spec) return dial_knob(t, spec, "bipolar") end
  function S.stepped_knob(t, spec) return dial_knob(t, spec, "stepped") end

  --- An angle: a compass ring with a ruler every five degrees (long every
  --- thirty), faint cross hairs, a needle from the reading to the rim
  --- with a block at its end.
  function S.angle_slider(t, spec)
    local Sz = num(spec.size, nil) or math.min(num(spec.width, 120), num(spec.height, 120))
    local c = Sz / 2
    local r = c - 6
    return full {
      track = ui.Item { width = Sz, height = Sz },
      background = ui.Item { width = Sz, height = Sz,
        path(Sz, Sz, { d = arc(c, c, r, 0, 360), stroke_width = 1, stroke_color = function() return C.primary:alpha(.4) end }),
        path(Sz, Sz, { d = morf.geometry.ticks(c, c, r - 3, r, { from = 0, sweep = 360, count = 72, major = 6, major_r0 = r - 8 }),
          stroke_width = 1, stroke_color = function() return C.primary:alpha(.5) end }),
        path(Sz, Sz, { d = ("M%g %g H%g M%g %g V%g"):format(c - r + 10, c, c + r - 10, c, c - r + 10, c + r - 10),
          stroke_width = 1, stroke_color = function() return stroke(C, "quiet") end }) },
      fill = ui.Item { width = Sz, height = Sz, rotation = function() return t.angle or 0 end,
        ui.Rect { x = c - 1, y = c - r + 2, width = 2, height = r * 0.55, color = function() return C.primary end } },
      handle = ui.Item { width = Sz, height = Sz, rotation = function() return t.angle or 0 end,
        ui.Rect { x = c - 5, y = c - r - 3, width = 10, height = 10, color = function() return C.primary end } },
      value_label = ui.Rect { x = c - 28, y = c - 11, width = 56, height = 22, color = function() return C.surfaceContainer end,
        border_width = 1, border_color = function() return C.primary:alpha(.3) end,
        readout { anchors = { fill = true }, height = 22, horizontal_alignment = "center", font_size = 13,
          color = function() return C.onSurface end,
          text = function() return ("%03d°"):format(math.floor((t.value or 0) + 0.5) % 360) end } },
      second_handle = brackets(t, { 0, 0, Sz, Sz }),
    }
  end

  -- ----------------------------------------------------------- numbers --

  --- A spin button: a framed register with the value in zero-padded
  --- digits, minus and plus as framed keys at its end. A drag up or down
  --- scrubs it.
  function S.spin_button(t, spec, _, send)
    local W, H = num(spec.width, 150), num(spec.height, 40)
    local B = H - 8
    local step = num(spec.step, 1)
    local format = spec.format or function(v)
      if step >= 1 then return ("%03d"):format(math.floor(v + 0.5)) end
      return trim(v)
    end
    return full {
      track = ui.Item { width = W - 2 * B - 8, height = H },
      background = ui.Item { width = W, height = H,
        path(W, H, { d = M.frame_path(W, H, 6, .5), fill_color = function() return C.surfaceContainer end,
          stroke_color = function() return (t.focused or t.hovered) and stroke(C, "hover") or stroke(C, "idle") end,
          stroke_width = 1, behavior = { stroke_color = quick } }),
        ui.Rect { x = 2, y = 6, width = 2, height = H - 12, color = function() return C.primary:alpha(.8) end } },
      value_label = M.text { x = 14, y = 0, width = W - 2 * B - 22, height = H, vertical_alignment = "center",
        font_size = theme.size.normal, color = function() return C.onSurface end,
        text = function() return format(t.value or 0) end },
      decrease = key(send, "remove", "decrease", W - 2 * B - 8, 4, B),
      increase = key(send, "add", "increase", W - B - 4, 4, B),
      second_handle = brackets(t),
    }
  end

  --- A timeline scrubber: a ruler over a band hatched up to the playhead,
  --- a hairline head with its time on a square flag.
  function S.scrubber(t, spec)
    local W, H = num(spec.width, 260), num(spec.height, 64)
    local total = num(spec.duration, 90)
    local function clock(s) s = math.floor(s + 0.5) return ("%02d:%02d"):format(s // 60, s % 60) end
    local FW, FH = 50, 20
    local by, bh = 38, 16
    local function hx() return clamp01(t.visual_position) * W end
    return full {
      track = ui.Item { width = W, height = H },
      background = ui.Item { width = W, height = H, ruler(0, by - 9, W, 7, faint), band(t, 0, by, W, bh) },
      fill = run(0, by, W, bh, function() return t.mirrored and hx() or 0 end,
        function() return t.mirrored and W or hx() end, false),
      handle = ui.Item { x = hx, width = 1, height = H, behavior = { x = follow },
        ui.Rect { x = -1, y = FH, width = 2, height = H - FH, color = function() return C.onSurface end },
        ui.Rect { y = 0, width = FW, height = FH, color = function() return C.primary end,
          x = function() return math.max(-hx(), math.min(W - hx() - FW, -FW / 2)) end,
          readout { anchors = { fill = true }, height = FH, horizontal_alignment = "center",
            color = function() return C.onPrimary end, text = function() return clock(clamp01(t.position) * total) end } } },
      second_handle = brackets(t),
    }
  end

  --- Stars to rate with: hollow in a faint stroke, filled in the accent
  --- up to the value, a hatched plate under each filled one.
  function S.rating(t, spec)
    local count = math.max(1, math.floor(num(spec.to, 5) - num(spec.from, 0) + 0.5))
    local Z, gap = 28, 6
    local W, H = count * (Z + gap) - gap, Z + 4
    local stars = ui.Item { width = W, height = H }
    for i = 1, count do
      local function on() return (t.value or 0) >= num(spec.from, 0) + i - 1e-6 end
      local function at() return t.mirrored and (count - i) * (Z + gap) or (i - 1) * (Z + gap) end
      ui.reparent(ui.Item { x = at, y = 2, width = Z, height = Z,
        stripes.box { width = Z, height = Z, gap = 5, weight = 1, color = function() return C.primary:alpha(.22) end,
          opacity = function() return on() and 1 or 0 end },
        M.icon("star", Z - 4, function() return on() and C.primary or C.primary:alpha(.35) end,
          { x = 2, y = 2, width = Z - 4, height = Z - 4, horizontal_alignment = "center", vertical_alignment = "center",
            fill = on }) }, stars)
    end
    return full {
      track = ui.Item { width = W, height = H },
      background = ui.Item { width = W, height = H },
      fill = stars,
      second_handle = brackets(t),
    }
  end

  --- An adjustable level: square cells, lit solid up to the value and
  --- framed past it, the reading in three digits.
  function S.level_control(t, spec)
    local W, H = num(spec.width, 250), num(spec.height, 32)
    local n = math.floor(num(spec.segments, 12))
    local gap, span = 3, W - 48
    local bw = (span - gap * (n - 1)) / n
    local cells = ui.Item { width = span, height = H }
    for i = 1, n do
      local function lit() return clamp01(t.position) >= (i - 0.5) / n end
      ui.reparent(ui.Rect { y = (H - 16) / 2, width = bw, height = 16,
        x = function() return t.mirrored and span - i * (bw + gap) + gap or (i - 1) * (bw + gap) end,
        color = function() return lit() and C.primary or C.primary:alpha(.06) end,
        border_width = 1, border_color = function() return lit() and C.primary or C.primary:alpha(.24) end,
        behavior = { color = quick } }, cells)
    end
    return full {
      track = ui.Item { width = span, height = H },
      background = ui.Item { width = W, height = H },
      fill = cells,
      value_label = readout { x = W - 42, width = 42, y = (H - 18) / 2, horizontal_alignment = "right", color = ink(t),
        text = pct(t, spec) },
      second_handle = brackets(t),
    }
  end

  --- An on-screen display's level: a framed plate with corner brackets,
  --- the icon, a hatched bar and the reading.
  function S.osd_level(t, spec)
    local W, H = num(spec.width, 260), num(spec.height, 52)
    local left, span, by, bh = 44, W - 44 - 52, H / 2 - 6, 12
    return full {
      track = ui.Item { width = W, height = H },
      background = ui.Item { width = W, height = H,
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainer end,
          border_width = 1, border_color = function() return stroke(C, "idle") end },
        ui.Item { anchors = { fill = true }, hud().corners { length = 8, weight = 2, color = function() return C.primary end } },
        ui.Rect { x = left, y = by, width = span, height = bh, color = function() return C.primary:alpha(.06) end,
          border_width = 1, border_color = function() return C.primary:alpha(.18) end } },
      fill = run(left, by, span, bh, function() return 0 end, function() return span * clamp01(t.position) end, false),
      ticks = M.icon(function()
        local i = get(spec.icon)
        if i then return i end
        return volume_icon(clamp01(t.position), get(spec.muted))
      end, 22, function() return C.primary end, { x = 12, y = H / 2 - 12, width = 24, height = 24,
        horizontal_alignment = "center", vertical_alignment = "center" }),
      value_label = readout { x = W - 46, width = 34, y = H / 2 - 9, horizontal_alignment = "right",
        color = function() return C.onSurface end, text = pct(t, spec) },
    }
  end
end
