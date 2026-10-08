-- The default kit's looks for the Range widgets beyond the plain scale
-- (skins.lua draws the slider, the seek bar and the scroll bar), in the
-- libadwaita manner: thin pill troughs, the accent up to a white round
-- knob, flat round icon buttons, the dim ink for readings. Knobs are a
-- raised disc inside an arc of travel, its pointer a static drawing turned
-- by `rotation`, the arc a static path trimmed to the position.
-- The behaviour -- drags, the vertical turn of a knob, snapping, keys --
-- is the archetype's (crates/morf-kit/src/range.rs).
local morf = require("morf")
local ui = require("morf.ui")

return function(S, theme, M)
  local P = theme.P
  local R = theme.radius
  local arc = morf.geometry.arc
  local function get(v) if type(v) == "function" then return v() end return v end
  local function clamp01(v) v = tonumber(v) or 0 return v < 0 and 0 or (v > 1 and 1 or v) end
  local function num(v, d) v = get(v) return type(v) == "number" and v or d end
  local function quick() return { duration = theme.duration.small, easing = theme.ease.standard } end
  local function turn() return M.spring(520, 40) end

  -- Every slot the archetype's skin would fill: a widget's look fills them
  -- all, so the plain scale is never built under it.
  local SLOTS = { "background", "track", "fill", "ticks", "handle", "second_handle", "value_label", "increase",
    "decrease", "content" }
  local function full(slots)
    for _, name in ipairs(SLOTS) do if slots[name] == nil then slots[name] = ui.Item {} end end
    return slots
  end

  --- The keyboard's ring over `box` ({ x, y, w, h }; the whole control
  --- when nil), built the first time the control is reached.
  local function ring(t, radius, box)
    return function()
      local props = { z = 50, color = "transparent", radius = radius, border_width = 2,
        border_color = function() local p = P() return p.strong and p.focus or p.focus:alpha(0.6) end,
        visible = function() return t.visual_focus end }
      if box then props.x, props.y, props.width, props.height = box[1], box[2], box[3], box[4]
      else props.anchors = { fill = true } end
      return ui.Rect(props)
    end
  end

  --- A path in its own pixels: `w` x `h`, unfilled unless told.
  local function path(w, h, props)
    props.width, props.height, props.view_box = w, h, { 0, 0, w, h }
    if props.fill_color == nil then props.fill_color = "transparent" end
    return ui.Path(props)
  end

  local function knob_edge() local p = P() return p.strong and p.ink or p.shade:alpha(p.dark and 0.6 or 0.8) end
  --- The soft shade a raised knob casts.
  local function shadow() local p = P() return morf.color("#000000"):alpha(p.dark and 0.5 or 0.22) end
  local function dim() return P().ink_dim end
  --- Where position `p` is drawn: right to left flips it.
  local function vis(t, p) return t.mirrored and 1 - p or p end

  local function readout(props)
    props.font_size = props.font_size or theme.size.small
    props.color = props.color or dim
    props.height = props.height or 20
    props.vertical_alignment = props.vertical_alignment or "center"
    return M.text(props)
  end

  local function trim(v) local s = ("%.2f"):format(v) s = s:gsub("0+$", ""):gsub("%.$", "") return s end
  local function hz(v)
    if v >= 1000 then return trim(v / 1000) .. " kHz" end
    return ("%d Hz"):format(math.floor(v + 0.5))
  end

  --- The round white knob of a scale, `K` across, centred on (`x`, `y`)
  --- (bindings).
  local function knob(t, K, x, y, id, down)
    return ui.Rect { id = id, width = K, height = K, radius = K / 2,
      x = function() return x() - K / 2 end, y = function() return y() - K / 2 end,
      color = function() local p = P() return (down or function() return t.down end)() and p.knob:mix(p.ink, 0.08) or p.knob end,
      border_width = 1, border_color = knob_edge, shadow_color = shadow, shadow_blur = 4, shadow_offset_y = 1 }
  end

  --- A horizontal scale: a 4 px trough from `x0` across `travel` at `cy`,
  --- the accent from `from` (a position) to the knob, and the knob.
  --- Returns the slots and `hx` (the knob's centre).
  local function scale(t, o)
    local TR, K = 4, o.knob or 20
    local x0, travel, cy = o.x0, o.travel, o.cy
    local function hx() return x0 + travel * clamp01(t.visual_position) end
    local function start() return x0 + travel * vis(t, o.from or 0) end
    local slots = {
      track = ui.Item { x = x0, y = cy - 16, width = travel, height = 32 },
      background = ui.Item { width = o.W, height = o.H,
        ui.Rect { x = x0 - TR / 2, y = cy - TR / 2, width = travel + TR, height = TR, radius = TR / 2,
          color = function() return P().track end } },
      fill = ui.Rect { y = cy - TR / 2, height = TR, radius = TR / 2,
        x = function() return math.min(start(), hx()) - TR / 2 end,
        width = function() return math.abs(hx() - start()) + TR end,
        color = function() return P().accent end },
      handle = knob(t, K, hx, function() return cy end),
    }
    return slots, hx
  end

  --- Small marks under a trough at positions `marks` (value order), the
  --- ones the accent has passed in its ink.
  local function marks_under(t, x0, travel, y, marks, lit)
    local node = ui.Item {}
    for _, m in ipairs(marks) do
      ui.reparent(ui.Rect { width = 2, height = 6, radius = 1, y = y,
        x = function() return x0 + travel * vis(t, m) - 1 end,
        color = function()
          local p = P()
          if lit and clamp01(t.position) >= m - 1e-6 then return p.accent end
          return p.strong and p.ink or p.ink:alpha(0.3)
        end }, node)
    end
    return node
  end

  -- ------------------------------------------------------------ scales --

  -- The plain scale and the seek bar are skins.lua's; their white knob
  -- gets the shade a raised knob casts, or it is lost on a white card.
  local function lifted(slots)
    local knob_node = slots and slots.handle
    if knob_node and type(knob_node) ~= "function" then
      knob_node.shadow_color, knob_node.shadow_blur, knob_node.shadow_offset_y = shadow, 4, 1
    end
    return slots
  end
  function S.slider(t, spec) return lifted(S.Range(t, spec)) end
  function S.seek_bar(t, spec) return lifted(S.Range(t, spec)) end

  --- A slider that stops at every step: a mark under the trough for each,
  --- the reading at the end.
  function S.discrete_slider(t, spec)
    local W, H = num(spec.width, 240), num(spec.height, 48)
    local from, to, step = num(spec.from, 0), num(spec.to, 10), num(spec.step, 1)
    local n = math.max(1, math.floor(math.abs(to - from) / math.max(step, 1e-9) + 0.5))
    local x0, travel, cy = 10, W - 20 - 40, math.floor(H / 2) - 4
    local slots = scale(t, { W = W, H = H, x0 = x0, travel = travel, cy = cy })
    local marks = {}
    for i = 0, n do marks[#marks + 1] = i / n end
    slots.ticks = marks_under(t, x0, travel, cy + 10, marks, true)
    slots.value_label = readout { x = W - 36, width = 36, y = cy - 10, horizontal_alignment = "right",
      text = function() return trim(t.value or 0) end }
    slots.second_handle = ring(t, R.small)
    return full(slots)
  end

  --- A frequency-like logarithmic slider: decade marks named under the
  --- trough, the value (in Hz unless `spec.format`) at the end.
  function S.log_slider(t, spec)
    local W, H = num(spec.width, 260), num(spec.height, 52)
    local from, to = num(spec.from, 20), num(spec.to, 20000)
    local x0, travel, cy = 10, W - 20 - 64, 14
    local slots = scale(t, { W = W, H = H, x0 = x0, travel = travel, cy = cy })
    local format = spec.format or hz
    local function at(v) return math.log(v / from) / math.log(to / from) end
    local marks, names = {}, ui.Item {}
    local decade = 10 ^ math.ceil(math.log(from, 10) - 1e-9)
    while decade <= to * 1.0001 do
      local p = at(decade)
      if p >= -1e-6 and p <= 1 + 1e-6 then
        marks[#marks + 1] = p
        local label = decade >= 1000 and (trim(decade / 1000) .. "k") or tostring(math.floor(decade))
        ui.reparent(readout { width = 40, horizontal_alignment = "center", y = cy + 12, text = label,
          x = function() return x0 + travel * vis(t, p) - 20 end }, names)
      end
      decade = decade * 10
    end
    slots.ticks = ui.Item { marks_under(t, x0, travel, cy + 7, marks, false), names }
    slots.value_label = readout { x = W - 60, width = 60, y = cy - 10, horizontal_alignment = "right",
      text = function() return format(t.value or from) end }
    slots.second_handle = ring(t, R.small)
    return full(slots)
  end

  --- Two knobs on one trough, the accent between them, and the pair read
  --- above the trough's right end.
  function S.range_slider(t, spec)
    local W, H = num(spec.width, 240), num(spec.height, 56)
    local K, TR = 20, 4
    local x0, travel, cy = K / 2, W - K, H - 16
    local function ax() return x0 + travel * clamp01(t.first_visual_position) end
    local function bx() return x0 + travel * clamp01(t.second_visual_position) end
    local format = spec.format or function(v) return ("%d"):format(math.floor(v * 100 + 0.5)) end
    return full {
      track = ui.Item { x = x0, y = cy - 16, width = travel, height = 32 },
      background = ui.Item { width = W, height = H,
        ui.Rect { x = x0 - TR / 2, y = cy - TR / 2, width = travel + TR, height = TR, radius = TR / 2,
          color = function() return P().track end } },
      fill = ui.Rect { y = cy - TR / 2, height = TR,
        x = function() return math.min(ax(), bx()) end, width = function() return math.abs(bx() - ax()) end,
        color = function() return P().accent end },
      handle = knob(t, K, ax, function() return cy end),
      second_handle = knob(t, K, bx, function() return cy end),
      value_label = readout { x = 0, width = W, y = 0, horizontal_alignment = "right",
        text = function() return format(t.first or 0) .. " – " .. format(t.second or 0) end },
      ticks = ring(t, R.small),
    }
  end

  --- An upright scale: the trough runs up from the reading at its foot.
  function S.vertical_slider(t, spec)
    local function W() return num(spec.width,48) end
    local function H() return num(spec.height,200) end
    local K, TR = 20, 4
    local y0=K/2
    local function cx() return W()/2 end
    local function travel() return math.max(1,H()-K-24) end
    local function hy() return y0 + travel() * clamp01(t.visual_position) end
    return full {
      track = ui.Item { x = 0, y = y0, width = W, height = travel },
      background = ui.Item { width = W, height = H,
        ui.Rect { x = function() return cx()-TR/2 end, y = y0 - TR / 2, width = TR, height = function() return travel()+TR end, radius = TR / 2,
          color = function() return P().track end } },
      fill = ui.Rect { x = function() return cx()-TR/2 end, width = TR, radius = TR / 2, y = function() return hy() - TR / 2 end,
        height = function() return y0 + travel() - hy() + TR end, color = function() return P().accent end },
      handle = knob(t, K, cx, hy),
      value_label = readout { x = 0, width = W, y = function() return H()-20 end, horizontal_alignment = "center",
        text = function() return ("%d"):format(math.floor(clamp01(t.position) * 100 + 0.5)) end },
      second_handle = ring(t, R.small),
    }
  end

  --- A console fader: a dark slot, a scale either side of it named in dB,
  --- a ribbed cap riding it, the level read under it.
  local FADER = { { 1, "+6" }, { 0.75, "0" }, { 0.5, "-10" }, { 0.25, "-30" }, { 0, "-∞" } }
  local function db(p)
    if p <= 0.001 then return "-∞ dB" end
    for i = 1, #FADER - 1 do
      local a, b = FADER[i], FADER[i + 1]
      if p <= a[1] and p >= b[1] then
        local va = tonumber(a[2]) or 0
        local vb = tonumber(b[2]) or -60
        local d = vb + (va - vb) * (p - b[1]) / (a[1] - b[1])
        return ("%+.1f dB"):format(d)
      end
    end
    return "+6.0 dB"
  end
  function S.fader(t, spec)
    local W, H = num(spec.width, 76), num(spec.height, 200)
    local CW, CH = 30, 16
    local cx, y0, travel = 48, CH / 2 + 2, H - CH - 4 - 24
    local function hy() return y0 + travel * clamp01(t.visual_position) end
    local scale_marks, names = {}, ui.Item {}
    for i = 0, 20 do
      local y = y0 + travel * i / 20
      local long = i % 5 == 0
      scale_marks[#scale_marks + 1] = ("M%g %.1f H%g M%g %.1f H%g"):format(cx - 16 - (long and 6 or 3), y, cx - 16,
        cx + 16, y, cx + 16 + (long and 6 or 3))
    end
    for _, mark in ipairs(FADER) do
      ui.reparent(readout { x = 0, width = 22, horizontal_alignment = "right", y = y0 + travel * (1 - mark[1]) - 10,
        text = mark[2] }, names)
    end
    return full {
      track = ui.Item { x = 0, y = y0, width = W, height = travel },
      background = ui.Item { width = W, height = H,
        ui.Rect { x = cx - 3, y = y0 - 3, width = 6, height = travel + 6, radius = 3,
          color = function() local p = P() return p.dark and p.shade or p.track end },
        path(W, H, { d = table.concat(scale_marks, " "), stroke_width = 1,
          stroke_color = function() local p = P() return p.strong and p.ink or p.ink:alpha(0.35) end }),
        names },
      fill = ui.Rect { x = cx - 1, width = 2, radius = 1, y = hy,
        height = function() return y0 + travel - hy() end, color = function() return P().accent end },
      handle = ui.Rect { id = spec.id and spec.id .. "-cap", x = cx - CW / 2, width = CW, height = CH, radius = 4,
        y = function() return hy() - CH / 2 end,
        color = function() local p = P() return t.down and p.knob:mix(p.ink, 0.08) or p.knob end,
        border_width = 1, border_color = knob_edge, shadow_color = shadow, shadow_blur = 5, shadow_offset_y = 2,
        ui.Rect { x = 4, y = CH / 2 - 1, width = CW - 8, height = 2, radius = 1, color = function() return P().ink end },
        ui.Rect { x = 6, y = 3, width = CW - 12, height = 1, color = function() return P().ink:alpha(0.2) end },
        ui.Rect { x = 6, y = CH - 4, width = CW - 12, height = 1, color = function() return P().ink:alpha(0.2) end } },
      value_label = readout { x = 0, width = W, y = H - 20, horizontal_alignment = "center",
        text = function() return db(clamp01(t.position)) end },
      second_handle = ring(t, R.small),
    }
  end

  --- A system level with its icon: the icon `icons(position)` names at the
  --- start, the percentage at the end. `spin`: the icon turns with it.
  local function level(t, spec, icons, spin)
    local W, H = num(spec.width, 260), num(spec.height, 48)
    local x0, travel, cy = 40, W - 40 - 10 - 44, math.floor(H / 2)
    local slots = scale(t, { W = W, H = H, x0 = x0, travel = travel, cy = cy })
    local muted = spec.muted
    slots.ticks = M.icon(function() return icons(clamp01(t.position), get(muted)) end, 22,
      function() return P().ink end,
      { x = 4, y = cy - 13, width = 26, height = 26, horizontal_alignment = "center", vertical_alignment = "center",
        rotation = spin and function() return clamp01(t.position) * 90 end or nil,
        behavior = spin and { rotation = turn() } or nil })
    slots.value_label = readout { x = W - 44, width = 44, y = cy - 10, horizontal_alignment = "right",
      text = function() return ("%d%%"):format(math.floor(clamp01(t.position) * 100 + 0.5)) end }
    slots.second_handle = ring(t, R.small)
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

  --- A flat round icon button that sends `event`.
  local function stepper(send, icon, event, x, y, size)
    return require("lib.kit.widgets").icon { x = x, y = y, width = size, height = size, size = 18, icon = icon,
      on_clicked = function() send(event) end }
  end

  --- A zoom: out and in buttons either side of a logarithmic trough with
  --- a mark at 100 %, the zoom read at the end.
  function S.zoom(t, spec, _, send)
    local W, H = num(spec.width, 270), num(spec.height, 48)
    local from, to = num(spec.from, 0.25), num(spec.to, 4)
    local B = 32
    local x0, travel, cy = B + 14, W - (B + 14) - 14 - B - 52, math.floor(H / 2)
    local slots = scale(t, { W = W, H = H, x0 = x0, travel = travel, cy = cy })
    local one = (from < 1 and to > 1) and math.log(1 / from) / math.log(to / from) or nil
    if one then
      slots.ticks = ui.Rect { width = 2, height = 12, radius = 1, y = cy - 6,
        x = function() return x0 + travel * vis(t, one) - 1 end,
        color = function() local p = P() return p.strong and p.ink or p.ink:alpha(0.35) end }
    end
    slots.decrease = stepper(send, "zoom_out", "decrease", 0, cy - B / 2, B)
    slots.increase = stepper(send, "zoom_in", "increase", x0 + travel + 14, cy - B / 2, B)
    slots.value_label = readout { x = W - 50, width = 50, y = cy - 10, horizontal_alignment = "right",
      text = function() return ("%d%%"):format(math.floor((t.value or 1) * 100 + 0.5)) end }
    slots.second_handle = ring(t, R.small)
    return full(slots)
  end

  -- ------------------------------------------------------------- knobs --

  --- A knob: a raised disc inside its arc of travel (`angle_from` across
  --- `angle_sweep`), the accent along the arc to the value -- from the
  --- middle for a bipolar one, detent dots for a stepped one -- and a
  --- pointer on the disc at `t.angle`. The value read under it.
  local function dial_knob(t, spec, kind)
    local Sz = num(spec.size, nil) or math.min(num(spec.width, 96), num(spec.height, 96 + 22) - 22)
    local W, H = Sz, Sz + 22
    local c = Sz / 2
    local from_a, sweep = num(spec.angle_from, -135), num(spec.angle_sweep, 270)
    local ra, thick = c - 4, 4
    local rb = c - 14
    local function p() return clamp01(t.position) end
    local slots = {}
    local back = ui.Item { width = W, height = H }
    slots.background = back
    slots.track = ui.Item { width = Sz, height = Sz }
    if kind == "stepped" then
      local lo, hi, step = num(spec.from, 0), num(spec.to, 10), num(spec.step, 1)
      local n = math.max(1, math.floor(math.abs(hi - lo) / math.max(step, 1e-9) + 0.5))
      local dots = ui.Item { width = Sz, height = Sz }
      for i = 0, n do
        local a = math.rad(from_a + sweep * i / n)
        local d = (i == 0 or i == n) and 6 or 4
        ui.reparent(ui.Rect { width = d, height = d, radius = d / 2,
          x = c + ra * math.sin(a) - d / 2, y = c - ra * math.cos(a) - d / 2,
          color = function()
            local pal = P()
            if p() >= i / n - 1e-6 then return pal.accent end
            return pal.strong and pal.ink or pal.ink:alpha(0.25)
          end, behavior = { color = quick() } }, dots)
      end
      slots.ticks = dots
    else
      ui.reparent(path(Sz, Sz, { d = arc(c, c, ra, from_a, sweep), stroke_width = thick, stroke_cap = "round",
        stroke_color = function() return P().track end }), back)
      local mid = kind == "bipolar" and 0.5 or 0
      local function lit(q) return math.abs(q - mid) > 0.002 end
      local up = path(Sz, Sz, { d = arc(c, c, ra, from_a + sweep * mid, sweep * (1 - mid)), stroke_width = thick,
        stroke_cap = "round", stroke_color = function() return P().accent end,
        trim_end = function() return math.max(0.001, (p() - mid) / (1 - mid)) end,
        visible = function() return p() > mid + 0.002 end })
      if kind == "bipolar" then
        local down = path(Sz, Sz, { d = arc(c, c, ra, from_a, sweep * mid), stroke_width = thick,
          stroke_cap = "round", stroke_color = function() return P().accent end,
          trim_start = function() return math.min(0.999, p() / mid) end,
          visible = function() return p() < mid - 0.002 end })
        slots.fill = ui.Item { width = Sz, height = Sz, up, down,
          -- The centre detent.
          ui.Rect { x = c - 1, y = c - ra - 7, width = 2, height = 5, radius = 1,
            color = function() local pal = P() return lit(p()) and pal.ink:alpha(0.35) or pal.accent end } }
      else
        slots.fill = up
      end
    end
    -- The disc, a hairline round it and a soft shade under it.
    ui.reparent(ui.Rect { x = c - rb, y = c - rb, width = 2 * rb, height = 2 * rb, radius = rb,
      color = function() local pal = P() return t.down and pal.knob:mix(pal.ink, 0.06) or (pal.dark and pal.raised or pal.knob) end,
      border_width = 1, border_color = knob_edge, shadow_color = shadow, shadow_blur = 8, shadow_offset_y = 2 }, back)
    -- The pointer: a short accent bar near the disc's rim, turned.
    slots.handle = ui.Item { width = Sz, height = Sz, rotation = function() return t.angle or 0 end,
      behavior = { rotation = turn() },
      ui.Rect { x = c - 2, y = c - rb + 5, width = 4, height = math.max(8, rb * 0.42), radius = 2,
        color = function() return P().accent end } }
    local format = spec.format or function(v)
      if kind == "bipolar" then
        if math.abs(v) < 0.005 then return "C" end
        return (v < 0 and "L " or "R ") .. math.floor(math.abs(v) * 100 + 0.5)
      elseif kind == "stepped" then return trim(v) end
      return ("%d%%"):format(math.floor(clamp01(t.position) * 100 + 0.5))
    end
    slots.value_label = readout { x = 0, width = W, y = Sz + 2, horizontal_alignment = "center",
      text = function() return format(t.value or 0) end }
    slots.second_handle = ring(t, c, { 0, 0, Sz, Sz })
    return full(slots)
  end
  function S.knob(t, spec) return dial_knob(t, spec, "plain") end
  function S.bipolar_knob(t, spec) return dial_knob(t, spec, "bipolar") end
  function S.stepped_knob(t, spec) return dial_knob(t, spec, "stepped") end

  --- An angle: a dial with a tick every 30 degrees, a hand from the
  --- middle to a knob on the rim, the angle read in the middle.
  function S.angle_slider(t, spec)
    local Sz = num(spec.size, nil) or math.min(num(spec.width, 120), num(spec.height, 120))
    local c = Sz / 2
    local r = c - 11
    local ticks = morf.geometry.ticks(c, c, r - 6, r - 2, { from = 0, sweep = 360, count = 12 })
    local K = 20
    return full {
      track = ui.Item { width = Sz, height = Sz },
      background = ui.Item { width = Sz, height = Sz,
        ui.Rect { x = c - r, y = c - r, width = 2 * r, height = 2 * r, radius = r,
          color = function() local p = P() return p.ink:alpha(p.wash.button * 0.6) end,
          border_width = 2, border_color = function() return P().track end },
        path(Sz, Sz, { d = ticks, stroke_width = 2, stroke_cap = "round",
          stroke_color = function() local p = P() return p.strong and p.ink or p.ink:alpha(0.3) end }) },
      fill = ui.Item { width = Sz, height = Sz, rotation = function() return t.angle or 0 end,
        ui.Rect { x = c - 1.5, y = c - r, width = 3, height = r, radius = 1.5, color = function() return P().accent end } },
      handle = ui.Item { width = Sz, height = Sz, rotation = function() return t.angle or 0 end,
        ui.Rect { x = c - K / 2, y = c - r - K / 2, width = K, height = K, radius = K / 2,
          color = function() return P().knob end, border_width = 1, border_color = knob_edge,
          shadow_color = shadow, shadow_blur = 4, shadow_offset_y = 1 } },
      value_label = ui.Rect { x = c - 26, y = c - 13, width = 52, height = 26, radius = 13,
        color = function() local p = P() return p.dark and p.raised or p.view end,
        readout { anchors = { fill = true }, horizontal_alignment = "center", font_size = theme.size.normal,
          color = function() return P().ink end,
          text = function() return ("%d°"):format(math.floor((t.value or 0) + 0.5) % 360) end } },
      second_handle = ring(t, c, { 0, 0, Sz, Sz }),
    }
  end

  -- ----------------------------------------------------------- numbers --

  --- A spin button: the value in an entry's well, minus and plus at its
  --- end. A drag up or down over it scrubs the value.
  function S.spin_button(t, spec, _, send)
    local W, H = num(spec.width, 150), num(spec.height, 40)
    local B = H - 4
    local step = num(spec.step, 1)
    local format = spec.format or function(v)
      if step >= 1 then return ("%d"):format(math.floor(v + 0.5)) end
      return trim(v)
    end
    return full {
      track = ui.Item { width = W - 2 * B, height = H },
      background = ui.Rect { width = W, height = H, radius = R.small,
        color = function() local p = P() return p.ink:alpha(p.dark and 0.08 or 0.07) end,
        border_width = function() return P().strong and 1 or 0 end, border_color = function() return P().border end },
      value_label = M.text { x = 10, y = 0, width = W - 2 * B - 14, height = H, vertical_alignment = "center",
        font_size = theme.size.normal, color = function() return P().ink end,
        text = function() return format(t.value or 0) end },
      decrease = stepper(send, "remove", "decrease", W - 2 * B - 2, 2, B),
      increase = stepper(send, "add", "increase", W - B - 2, 2, B),
      ticks = ui.Rect { x = W - B - 2, y = 8, width = 1, height = H - 16, color = function() return P().border end },
      second_handle = ring(t, R.small),
    }
  end

  --- A timeline scrubber: a ruler, the played part washed in the accent,
  --- a playhead with its time on a flag. `spec.duration`: seconds (90).
  function S.scrubber(t, spec)
    local W, H = num(spec.width, 260), num(spec.height, 64)
    local total = num(spec.duration, 90)
    local function clock(s) s = math.floor(s + 0.5) return ("%d:%02d"):format(s // 60, s % 60) end
    local FW, FH = 46, 22
    local band_y, band_h = 34, 20
    local function hx() return clamp01(t.visual_position) * W end
    return full {
      track = ui.Item { width = W, height = H },
      background = ui.Item { width = W, height = H,
        path(W, 8, { y = band_y - 9, d = morf.geometry.ruler(W, 8, { pitch = 8, major = 5, minor = 4 }),
          stroke_width = 1, stroke_color = function() local p = P() return p.strong and p.ink or p.ink:alpha(0.35) end }),
        ui.Rect { y = band_y, width = W, height = band_h, radius = R.small,
          color = function() local p = P() return p.ink:alpha(p.wash.button) end } },
      fill = ui.Rect { y = band_y, height = band_h, radius = R.small,
        x = function() return t.mirrored and hx() or 0 end,
        width = function() return t.mirrored and W - hx() or hx() end,
        color = function() local p = P() return p.accent:alpha(p.dark and 0.45 or 0.3) end },
      handle = ui.Item { x = function() return hx() end, width = 1, height = H,
        ui.Rect { x = -1, y = FH - 2, width = 2, height = H - FH + 2, color = function() return P().accent end },
        ui.Rect { x = function() return math.max(-hx(), math.min(W - hx() - FW, -FW / 2)) end, y = 0,
          width = FW, height = FH, radius = FH / 2, color = function() return P().accent end,
          readout { anchors = { fill = true }, horizontal_alignment = "center", height = FH,
            color = function() return P().on_accent end,
            text = function() return clock(clamp01(t.position) * total) end } } },
      second_handle = ring(t, R.small),
    }
  end

  --- Stars to rate with: filled up to the value, each popping as it fills.
  function S.rating(t, spec)
    local count = math.max(1, math.floor(num(spec.to, 5) - num(spec.from, 0) + 0.5))
    local Z, gap = 28, 6
    local W, H = count * (Z + gap) - gap, Z + 4
    local stars = ui.Item { width = W, height = H }
    for i = 1, count do
      local function on() return (t.value or 0) >= num(spec.from, 0) + i - 1e-6 end
      local function at() return t.mirrored and (count - i) * (Z + gap) or (i - 1) * (Z + gap) end
      ui.reparent(M.icon("star", Z, function()
        local p = P()
        if on() then return p.warning end
        return p.strong and p.ink or p.ink:alpha(0.25)
      end, { x = at, y = 2, width = Z, height = Z, horizontal_alignment = "center", vertical_alignment = "center",
        fill = on, scale = function() return on() and 1 or 0.86 end,
        behavior = { scale = M.spring(600, 30) } }), stars)
    end
    return full {
      track = ui.Item { width = W, height = H },
      background = ui.Item { width = W, height = H },
      fill = stars,
      second_handle = ring(t, R.small),
    }
  end

  --- An adjustable level: a row of blocks lit up to the value, the
  --- percentage at the end.
  function S.level_control(t, spec)
    local W, H = num(spec.width, 250), num(spec.height, 32)
    local n = math.floor(num(spec.segments, 12))
    local gap = 3
    local span = W - 48
    local bw = (span - gap * (n - 1)) / n
    local blocks = ui.Item { width = span, height = H }
    for i = 1, n do
      local function lit() return clamp01(t.position) >= (i - 0.5) / n end
      ui.reparent(ui.Rect { y = (H - 14) / 2, width = bw, height = 14, radius = 3,
        x = function() return t.mirrored and span - i * (bw + gap) + gap or (i - 1) * (bw + gap) end,
        color = function()
          local p = P()
          if lit() then return p.accent end
          return p.ink:alpha(p.strong and 0.3 or p.wash.button + 0.04)
        end, behavior = { color = quick() } }, blocks)
    end
    return full {
      track = ui.Item { width = span, height = H },
      background = ui.Item { width = W, height = H },
      fill = blocks,
      value_label = readout { x = W - 44, width = 44, y = (H - 20) / 2, horizontal_alignment = "right",
        text = function() return ("%d%%"):format(math.floor(clamp01(t.position) * 100 + 0.5)) end },
      second_handle = ring(t, R.small),
    }
  end

  --- An on-screen display's level: a raised pill with the icon and a
  --- thin bar, shown, not handled.
  function S.osd_level(t, spec)
    local W, H = num(spec.width, 260), num(spec.height, 52)
    local x0, x1 = 50, W - 22
    local TR = 6
    return full {
      track = ui.Item { width = W, height = H },
      background = ui.Item { width = W, height = H,
        ui.Rect { x = 2, y = 4, width = W - 4, height = H - 4, radius = (H - 4) / 2,
          color = function() local p = P() return p.shade:alpha(p.dark and 0.7 or 0.35) end },
        ui.Rect { width = W, height = H - 2, radius = (H - 2) / 2, color = function() return P().raised end,
          border_width = function() return P().strong and 2 or 1 end,
          border_color = function() local p = P() return p.strong and p.border or p.shade:alpha(p.dark and 0.9 or 0.6) end },
        ui.Rect { x = x0, y = (H - 2) / 2 - TR / 2, width = x1 - x0, height = TR, radius = TR / 2,
          color = function() return P().track end } },
      fill = ui.Rect { x = x0, y = (H - 2) / 2 - TR / 2, height = TR, radius = TR / 2,
        width = function() return math.max(TR, (x1 - x0) * clamp01(t.position)) end,
        color = function() return P().ink end, behavior = { width = quick() } },
      ticks = M.icon(function()
        local i = get(spec.icon)
        if i then return i end
        return volume_icon(clamp01(t.position), get(spec.muted))
      end, 22, function() return P().ink end,
        { x = 16, y = (H - 2) / 2 - 13, width = 24, height = 26, vertical_alignment = "center" }),
    }
  end
end
