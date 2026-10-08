-- Material's looks for the Range widgets beyond the plain slider
-- (skins.lua draws it, the media rail and the scroll bar), in M3's
-- manner: balanced rounded tracks split by a gap round a stable handle,
-- stop indicators and a value bubble while held;
-- knobs are an expressive cookie that turns inside a thick arc of travel
-- (a static shape turned by `rotation`, the arc a static path trimmed).
-- The behaviour is the archetype's (crates/morf-kit/src/range.rs).
local morf = require("morf")
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local arc = morf.geometry.arc
  local function get(v) if type(v) == "function" then return v() end return v end
  local function clamp01(v) v = tonumber(v) or 0 return v < 0 and 0 or (v > 1 and 1 or v) end
  local function num(v, d) v = get(v) return type(v) == "number" and v or d end
  local function motion() return { duration = theme.duration.small, easing = theme.ease.standard } end
  -- Things under a hand move on a spring with a little give (M3 expressive).
  local function travel() return M.spring(380, 26) end
  local function squish() return ui.spring { stiffness = 520, damping = 18 } end

  local SLOTS = { "background", "track", "fill", "ticks", "handle", "second_handle", "value_label", "increase",
    "decrease", "content" }
  local function full(slots)
    for _, name in ipairs(SLOTS) do if slots[name] == nil then slots[name] = ui.Item {} end end
    return slots
  end
  local function ring(t, radius, box)
    return function()
      local props = { z = 50, color = "transparent", radius = radius, border_width = 2,
        border_color = function() return C().secondary end, visible = function() return t.visual_focus end }
      if box then props.x, props.y, props.width, props.height = box[1], box[2], box[3], box[4]
      else props.anchors = { fill = true, margins = 1 } end
      return ui.Rect(props)
    end
  end
  local function path(w, h, props)
    props.width, props.height, props.view_box = w, h, { 0, 0, w, h }
    if props.fill_color == nil then props.fill_color = "transparent" end
    return ui.Path(props)
  end
  local function vis(t, p) return t.mirrored and 1 - p or p end
  local function readout(props)
    props.font_size = props.font_size or theme.size.small
    props.color = props.color or function() return C().onSurfaceVariant end
    props.height = props.height or 20
    props.vertical_alignment = props.vertical_alignment or "center"
    return M.text(props)
  end
  local function trim(v) local s = ("%.2f"):format(v) s = s:gsub("0+$", ""):gsub("%.$", "") return s end
  local function hz(v)
    if v >= 1000 then return trim(v / 1000) .. " kHz" end
    return ("%d Hz"):format(math.floor(v + 0.5))
  end

  -- ------------------------------------------------------------ tracks --

  local TH, GAP, HW, HH = 16, 6, 4, 44
  -- All moving pieces use the same timing, and follow input immediately
  -- while held. That keeps the handle, its gap and the fill together.
  local function moving(t,props,values,build)
    for name,binding in pairs(values) do props[name]=binding() end
    local node=(build or ui.Rect)(props)
    require("themes.kit_common").follow_range(t,node,{{node=node,values=values}},motion)
    return node
  end
  --- A short segment shrinks toward a circle instead of becoming a tall
  --- sliver. Its ends and centre line match the main volume slider.
  local function piece(t,a,b,cy,th,color,id)
    local function width() return math.max(0,b()-a()) end
    local function height() return math.min(th,width()) end
    return moving(t,{id=id,color=color,radius=th/2,visible=function() return width()>.5 end},
      {x=a,width=width,height=height,y=function() return cy-height()/2 end})
  end
  --- The tall thin handle at `hx` (a binding).
  local function bar(t, hx, cy, id, h)
    h = h or HH
    return moving(t,{id=id,y=cy-h/2,height=h,radius=2,width=HW,
      color=function() return C().primary end},{x=function() return hx()-HW/2 end})
  end
  --- M3's value bubble over the handle while it is held.
  local function bubble(t, hx, cy, text)
    return ui.Rect { width = 48, height = 36, radius = 18, y = cy - HH / 2 - 42,
      x = function() return hx() - 24 end, color = function() return C().inverseSurface end,
      visible = function() return t.down or t.dragging end,
      readout { anchors = { fill = true }, height = 36, horizontal_alignment = "center",
        font_size = theme.size.normal, color = function() return C().inverseOnSurface end, text = text } }
  end
  --- A horizontal track from `left` to `right` at `cy` with the handle at
  --- the position: active up to the gap, inactive after it, a stop dot
  --- at the end.
  local function track(t, o)
    local left, right, cy = o.left, o.right, o.cy
    local x0, span = left + HW / 2, right - left - HW
    local function hx() return x0 + span * clamp01(t.visual_position) end
    local function lo() return math.min(left, right) end
    local slots = {
      track = ui.Item { x = x0, y = cy - HH / 2, width = span, height = HH },
      background = ui.Item { width = o.W, height = o.H,
        piece(t,function() return t.mirrored and lo() or hx() + HW / 2 + GAP end,
          function() return t.mirrored and hx() - HW / 2 - GAP or right end, cy, o.th or TH,
          function() return C().secondaryContainer end),
        ui.Rect { y = cy - 2, width = 4, height = 4, radius = 2, x = function() return t.mirrored and left + 6 or right - 10 end,
          color = function() return C().primary end,
          visible = function() return math.abs(hx() - (t.mirrored and left or right)) > 18 end } },
      fill = piece(t,function() return t.mirrored and hx() + HW / 2 + GAP or left end,
        function() return t.mirrored and right or hx() - HW / 2 - GAP end, cy, o.th or TH,
        function() return C().primary end),
      handle = bar(t, hx, cy, nil, o.hh),
    }
    return slots, hx
  end

  -- ------------------------------------------------------------ scales --

  --- Stops at every step: a dot on the track for each, the value bubble
  --- while held, the value at the end.
  function S.discrete_slider(t, spec)
    local W, H = num(spec.width, 240), num(spec.height, 48)
    local from, to, step = num(spec.from, 0), num(spec.to, 10), num(spec.step, 1)
    local n = math.max(1, math.floor(math.abs(to - from) / math.max(step, 1e-9) + 0.5))
    local cy, left, right = math.floor(H / 2), 0, W - 40
    local slots, hx = track(t, { W = W, H = H, left = left, right = right, cy = cy })
    local x0, span = left + HW / 2, right - left - HW
    local dots = ui.Item {}
    for i = 0, n do
      local f = i / n
      ui.reparent(ui.Rect { width = 4, height = 4, radius = 2, y = cy - 2,
        x = function() return x0 + span * vis(t, f) - 2 end,
        visible = function() return math.abs(x0 + span * vis(t, f) - hx()) > GAP + 4 end,
        color = function()
          return clamp01(t.position) >= f - 1e-6 and C().onPrimary:alpha(0.8) or C().primary:alpha(0.8)
        end }, dots)
    end
    slots.ticks = dots
    slots.second_handle = bubble(t, hx, cy, function() return trim(t.value or 0) end)
    slots.value_label = readout { x = W - 32, width = 32, y = cy - 10, horizontal_alignment = "right",
      text = function() return trim(t.value or 0) end }
    slots.increase = ring(t, 12)
    return full(slots)
  end

  --- A logarithmic slider: decades named under the track, the value (Hz
  --- unless `spec.format`) at the end.
  function S.log_slider(t, spec)
    local W, H = num(spec.width, 260), num(spec.height, 52)
    local from, to = num(spec.from, 20), num(spec.to, 20000)
    local cy, left, right = 16, 0, W - 64
    local slots = track(t, { W = W, H = H, left = left, right = right, cy = cy, hh = 32 })
    local x0, span = left + HW / 2, right - left - HW
    local format = spec.format or hz
    local names = ui.Item {}
    local decade = 10 ^ math.ceil(math.log(from, 10) - 1e-9)
    while decade <= to * 1.0001 do
      local p = math.log(decade / from) / math.log(to / from)
      if p > 0.02 and p < 0.98 then
        local label = decade >= 1000 and (trim(decade / 1000) .. "k") or tostring(math.floor(decade))
        ui.reparent(readout { width = 40, horizontal_alignment = "center", y = cy + 12, text = label,
          x = function() return x0 + span * vis(t, p) - 20 end }, names)
        ui.reparent(ui.Rect { width = 2, height = 6, radius = 1, y = cy + 10,
          x = function() return x0 + span * vis(t, p) - 1 end,
          color = function() return C().outlineVariant end }, names)
      end
      decade = decade * 10
    end
    slots.ticks = names
    slots.value_label = readout { x = W - 60, width = 60, y = cy - 10, horizontal_alignment = "right",
      text = function() return format(t.value or from) end }
    slots.second_handle = ring(t, 12)
    return full(slots)
  end

  --- Two handles on one track: inactive, active between them, inactive;
  --- the pair read above.
  function S.range_slider(t, spec)
    local W, H = num(spec.width, 240), num(spec.height, 56)
    local cy = H - 22
    local x0, span = HW / 2, W - HW
    local function ax() return x0 + span * clamp01(t.first_visual_position) end
    local function bx() return x0 + span * clamp01(t.second_visual_position) end
    local function lo() return math.min(ax(), bx()) end
    local function hi() return math.max(ax(), bx()) end
    local format = spec.format or function(v) return ("%d"):format(math.floor(v * 100 + 0.5)) end
    local inactive = function() return C().secondaryContainer end
    return full {
      track = ui.Item { x = x0, y = cy - HH / 2, width = span, height = HH },
      background = ui.Item { width = W, height = H,
        piece(t,function() return 0 end, function() return lo() - HW / 2 - GAP end, cy, TH, inactive),
        piece(t,function() return hi() + HW / 2 + GAP end, function() return W end, cy, TH, inactive) },
      fill = piece(t,function() return lo() + HW / 2 + GAP end, function() return hi() - HW / 2 - GAP end, cy, TH,
        function() return C().primary end),
      handle = bar(t, ax, cy, nil, 40),
      second_handle = bar(t, bx, cy, nil, 40),
      value_label = readout { x = 0, width = W, y = 0, horizontal_alignment = "right",
        text = function() return format(t.first or 0) .. " – " .. format(t.second or 0) end },
      ticks = ring(t, 12),
    }
  end

  --- A vertical track with a gap round a wide flat handle, active below.
  local function vtrack(t, W, top, bottom, cx, hw)
    local y0, span = top + HW / 2, bottom - top - HW
    local function hy() return y0 + span * clamp01(t.visual_position) end
    local function vpiece(a,b,color)
      local function height() return math.max(0,b()-a()) end
      local function width() return math.min(TH,height()) end
      return moving(t,{color=color,radius=TH/2,visible=function() return height()>.5 end},
        {y=a,height=height,width=width,x=function() return cx-width()/2 end})
    end
    return {
      track = ui.Item { x = 0, y = y0, width = W, height = span },
      background = ui.Item {
        vpiece(function() return top end, function() return hy() - HW / 2 - GAP end,
          function() return C().secondaryContainer end),
        ui.Rect { x = cx - 2, y = top + 6, width = 4, height = 4, radius = 2, color = function() return C().primary end,
          visible = function() return hy() - top > 18 end } },
      fill = vpiece(function() return hy() + HW / 2 + GAP end, function() return bottom end,
        function() return C().primary end),
      handle=moving(t,{x=cx-hw/2,width=hw,radius=2,height=HW,color=function() return C().primary end},
        {y=function() return hy()-HW/2 end}),
    }, hy
  end

  function S.vertical_slider(t, spec)
    local W, H = num(spec.width, 48), num(spec.height, 200)
    local slots = vtrack(t, W, 0, H - 26, W / 2, 40)
    slots.background.width, slots.background.height = W, H
    slots.value_label = readout { x = 0, width = W, y = H - 20, horizontal_alignment = "center",
      text = function() return ("%d"):format(math.floor(clamp01(t.position) * 100 + 0.5)) end }
    slots.second_handle = ring(t, 12)
    return full(slots)
  end

  --- A console fader: a vertical track with a gap round a wide cap, stop
  --- dots either side named in dB, the level read under it.
  local FADER = { { 1, "+6" }, { 0.75, "0" }, { 0.5, "-10" }, { 0.25, "-30" }, { 0, "-∞" } }
  local function db(p)
    if p <= 0.001 then return "-∞ dB" end
    for i = 1, #FADER - 1 do
      local a, b = FADER[i], FADER[i + 1]
      if p <= a[1] and p >= b[1] then
        local va, vb = tonumber(a[2]) or 0, tonumber(b[2]) or -60
        return ("%+.1f dB"):format(vb + (va - vb) * (p - b[1]) / (a[1] - b[1]))
      end
    end
    return "+6.0 dB"
  end
  function S.fader(t, spec)
    local W, H = num(spec.width, 76), num(spec.height, 200)
    local cx, top, bottom = 48, 0, H - 26
    local slots, hy = vtrack(t, W, top, bottom, cx, 40)
    slots.background.width, slots.background.height = W, H
    local y0, span = top + HW / 2, bottom - top - HW
    local marks = ui.Item {}
    for i = 0, 8 do
      local y = y0 + span * i / 8
      for _, side in ipairs { -1, 1 } do
        ui.reparent(ui.Rect { x = cx + side * 18 - 2, y = y - 2, width = 4, height = 4, radius = 2,
          color = function() return C().outlineVariant end }, marks)
      end
    end
    for _, mark in ipairs(FADER) do
      ui.reparent(readout { x = 0, width = 24, horizontal_alignment = "right", y = y0 + span * (1 - mark[1]) - 10,
        text = mark[2] }, marks)
    end
    slots.ticks = marks
    -- The cap: the handle grows a pill either side of its line.
    ui.destroy(slots.handle, true)
    slots.handle = moving(t,{ x = cx - 22, width = 44, height = 20,
      ui.Rect { anchors = { fill = true }, radius = 10, color = function() return C().primary end,
        scale = function() return t.down and 0.92 or 1 end, behavior = { scale = squish() },
        ui.Rect { x = 10, y = 9, width = 24, height = 2, radius = 1, color = function() return C().onPrimary end } } },
      {y=function() return hy()-10 end},ui.Item)
    slots.value_label = readout { x = 0, width = W, y = H - 20, horizontal_alignment = "center",
      text = function() return db(clamp01(t.position)) end }
    slots.second_handle = ring(t, 12)
    return full(slots)
  end

  --- A system level: M3's medium track with its icon inside the active
  --- part (outside while it is too short), the percentage at the end.
  local function level(t, spec, icons, spin)
    local W, H = num(spec.width, 260), num(spec.height, 48)
    local th = 40
    local cy, left, right = math.floor(H / 2), 0, W - 46
    local slots, hx = track(t, { W = W, H = H, left = left, right = right, cy = cy, th = th, hh = 48 })
    local size = 22
    local function inside() return hx() - GAP > size + 22 end
    slots.ticks = M.icon(function() return icons(clamp01(t.position), get(spec.muted)) end, size,
      function() return inside() and C().onPrimary or C().onSurfaceVariant end,
      { y = cy - size / 2 - 1, width = size + 2, height = size + 2, horizontal_alignment = "center",
        vertical_alignment = "center", fill = true,
        x = function() return inside() and 10 or hx() + HW / 2 + GAP + 8 end,
        rotation = spin and function() return clamp01(t.position) * 90 end or nil,
        behavior = spin and { x = travel(), rotation = travel() } or { x = travel() } })
    slots.value_label = readout { x = W - 42, width = 42, y = cy - 10, horizontal_alignment = "right",
      text = function() return ("%d%%"):format(math.floor(clamp01(t.position) * 100 + 0.5)) end }
    slots.second_handle = ring(t, 12)
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

  --- A tonal round icon button that sends `event`.
  local function stepper(send, icon, event, x, y, size)
    return require("lib.kit.widgets").icon { x = x, y = y, width = size, height = size, size = 20,
      icon = icon, icon_off = icon, on_clicked = function() send(event) end }
  end

  --- Zoom out and in either side of a logarithmic track with a stop at
  --- 100 %, the zoom read at the end.
  function S.zoom(t, spec, _, send)
    local W, H = num(spec.width, 270), num(spec.height, 48)
    local from, to = num(spec.from, 0.25), num(spec.to, 4)
    local B = 36
    local cy = math.floor(H / 2)
    local left, right = B + 8, W - B - 8 - 52
    local slots, hx = track(t, { W = W, H = H, left = left, right = right, cy = cy, hh = 36 })
    local one = (from < 1 and to > 1) and math.log(1 / from) / math.log(to / from) or nil
    if one then
      local x0, span = left + HW / 2, right - left - HW
      slots.ticks = ui.Rect { width = 4, height = 4, radius = 2, y = cy - 2,
        x = function() return x0 + span * vis(t, one) - 2 end,
        visible = function() return math.abs(x0 + span * vis(t, one) - hx()) > GAP + 4 end,
        color = function() return clamp01(t.position) >= one and C().onPrimary or C().primary end }
    end
    slots.decrease = stepper(send, "zoom_out", "decrease", 0, cy - B / 2, B)
    slots.increase = stepper(send, "zoom_in", "increase", right + 8, cy - B / 2, B)
    slots.value_label = readout { x = W - 50, width = 50, y = cy - 10, horizontal_alignment = "right",
      text = function() return ("%d%%"):format(math.floor((t.value or 1) * 100 + 0.5)) end }
    slots.second_handle = ring(t, 12)
    return full(slots)
  end

  -- ------------------------------------------------------------- knobs --

  local shapes = morf.geometry
  --- A knob: a thick arc of travel (`angle_from` across `angle_sweep`),
  --- the primary along it to the value -- from the middle for a bipolar
  --- one, stop dots for a stepped one -- round a tonal cookie that turns
  --- with the value, its pointer a dot by its rim, squeezed while held.
  local function dial_knob(t, spec, kind)
    local Sz = num(spec.size, nil) or math.min(num(spec.width, 96), num(spec.height, 118) - 22)
    local W, H = Sz, Sz + 22
    local c = Sz / 2
    local from_a, sweep = num(spec.angle_from, -135), num(spec.angle_sweep, 270)
    local th = 8
    local ra = c - th / 2 - 1
    local rb = c - th - 7
    local function p() return clamp01(t.position) end
    local slots = { track = ui.Item { width = Sz, height = Sz } }
    local back = ui.Item { width = W, height = H }
    slots.background = back
    if kind == "stepped" then
      local lo, hi, step = num(spec.from, 0), num(spec.to, 10), num(spec.step, 1)
      local n = math.max(1, math.floor(math.abs(hi - lo) / math.max(step, 1e-9) + 0.5))
      local dots = ui.Item { width = Sz, height = Sz }
      for i = 0, n do
        local a = math.rad(from_a + sweep * i / n)
        ui.reparent(ui.Rect { width = 6, height = 6, radius = 3,
          x = c + ra * math.sin(a) - 3, y = c - ra * math.cos(a) - 3,
          scale = function() return p() >= i / n - 1e-6 and 1.25 or 1 end,
          color = function() return p() >= i / n - 1e-6 and C().primary or C().outlineVariant end,
          behavior = { color = motion(), scale = squish() } }, dots)
      end
      slots.ticks = dots
    else
      ui.reparent(path(Sz, Sz, { d = arc(c, c, ra, from_a, sweep), stroke_width = th, stroke_cap = "round",
        stroke_color = function() return C().secondaryContainer end }), back)
      local mid = kind == "bipolar" and 0.5 or 0
      local up = path(Sz, Sz, { d = arc(c, c, ra, from_a + sweep * mid, sweep * (1 - mid)), stroke_width = th,
        stroke_cap = "round", stroke_color = function() return C().primary end,
        trim_end = function() return math.max(0.001, (p() - mid) / (1 - mid)) end,
        visible = function() return p() > mid + 0.002 end, behavior = { trim_end = travel() } })
      if kind == "bipolar" then
        local down = path(Sz, Sz, { d = arc(c, c, ra, from_a, sweep * mid), stroke_width = th, stroke_cap = "round",
          stroke_color = function() return C().primary end,
          trim_start = function() return math.min(0.999, p() / mid) end,
          visible = function() return p() < mid - 0.002 end, behavior = { trim_start = travel() } })
        slots.fill = ui.Item { width = Sz, height = Sz, up, down,
          ui.Rect { x = c - 2, y = c - ra - 2, width = 4, height = 4, radius = 2,
            color = function() return C().onSurfaceVariant end,
            visible = function() return math.abs(p() - 0.5) > 0.03 end } }
      else
        slots.fill = up
      end
    end
    -- The cookie and its pointer turn together; a press squeezes it.
    local shape = kind == "stepped" and "cookie7" or "cookie9"
    slots.handle = ui.Item { x = c - rb, y = c - rb, width = 2 * rb, height = 2 * rb,
      rotation = function() return t.angle or 0 end, behavior = { rotation = travel(), scale = squish() },
      scale = function() return t.down and 0.93 or 1 end,
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, 100, 100 }, d = shapes.shape_path(shape),
        fill_color = function() return t.hovered and C().surfaceContainerHighest:mix(C().onSurface, 0.06)
          or C().surfaceContainerHighest end },
      ui.Rect { x = rb - 4, y = 7, width = 8, height = 8, radius = 4, color = function() return C().primary end } }
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

  --- An angle: a tonal dial with a stop dot every 30 degrees, a hand out
  --- from the reading in the middle to a handle on the rim.
  function S.angle_slider(t, spec)
    local Sz = num(spec.size, nil) or math.min(num(spec.width, 120), num(spec.height, 120))
    local c = Sz / 2
    local r = c - 10
    local dots = ui.Item { width = Sz, height = Sz }
    for k = 0, 11 do
      local a = math.rad(k * 30)
      ui.reparent(ui.Rect { width = 4, height = 4, radius = 2, x = c + (r - 10) * math.sin(a) - 2,
        y = c - (r - 10) * math.cos(a) - 2, color = function() return C().onSurfaceVariant:alpha(0.6) end }, dots)
    end
    local K = 20
    return full {
      track = ui.Item { width = Sz, height = Sz },
      background = ui.Item { width = Sz, height = Sz,
        ui.Rect { x = c - r, y = c - r, width = 2 * r, height = 2 * r, radius = r,
          color = function() return C().surfaceContainerHighest end }, dots },
      fill = ui.Item { width = Sz, height = Sz, rotation = function() return t.angle or 0 end,
        ui.Rect { x = c - 2, y = c - r, width = 4, height = r * 0.55, radius = 2, color = function() return C().primary end } },
      handle = ui.Item { width = Sz, height = Sz, rotation = function() return t.angle or 0 end,
        ui.Rect { x = c - K / 2, y = c - r - K / 2, width = K, height = K, radius = K / 2,
          color = function() return C().primary end, border_width = 3, border_color = function() return C().surface end,
          scale = function() return t.down and 1.2 or 1 end, behavior = { scale = squish() } } },
      value_label = readout { x = 0, y = c - 13, width = Sz, height = 26, horizontal_alignment = "center",
        font_size = theme.size.large, color = function() return C().onSurface end,
        text = function() return ("%d°"):format(math.floor((t.value or 0) + 0.5) % 360) end },
      second_handle = ring(t, c, { 0, 0, Sz, Sz }),
    }
  end

  -- ----------------------------------------------------------- numbers --

  --- A spin button: a tonal pill with the value, minus and plus as round
  --- tonal buttons inside its end. A drag up or down scrubs it.
  function S.spin_button(t, spec, _, send)
    local W, H = num(spec.width, 150), num(spec.height, 40)
    local B = H - 8
    local step = num(spec.step, 1)
    local format = spec.format or function(v)
      if step >= 1 then return ("%d"):format(math.floor(v + 0.5)) end
      return trim(v)
    end
    return full {
      track = ui.Item { width = W - 2 * B - 8, height = H },
      background = ui.Rect { width = W, height = H, radius = H / 2,
        color = function() return C().surfaceContainerHigh end,
        border_width = function() return t.focused and 2 or 0 end, border_color = function() return C().primary end },
      value_label = M.text { x = 18, y = 0, width = W - 2 * B - 26, height = H, vertical_alignment = "center",
        font_size = theme.size.normal, color = function() return C().onSurface end,
        text = function() return format(t.value or 0) end },
      decrease = stepper(send, "remove", "decrease", W - 2 * B - 8, 4, B),
      increase = stepper(send, "add", "increase", W - B - 4, 4, B),
      second_handle = ring(t, H / 2),
    }
  end

  --- A timeline scrubber: stop dots for the seconds, the played part as an
  --- active track, the playhead a tall handle with its time on a bubble.
  function S.scrubber(t, spec)
    local W, H = num(spec.width, 260), num(spec.height, 64)
    local total = num(spec.duration, 90)
    local function clock(s) s = math.floor(s + 0.5) return ("%d:%02d"):format(s // 60, s % 60) end
    local FW, FH = 52, 24
    local cy = 44
    local x0, span = HW / 2, W - HW
    local function hx() return x0 + span * clamp01(t.visual_position) end
    local ruler = {}
    for i = 0, 26 do
      local x = math.floor(x0 + span * i / 26) + 0.5
      ruler[#ruler + 1] = ("M%g %d V%d"):format(x, 26 + (i % 5 == 0 and 0 or 3), 32)
    end
    return full {
      track = ui.Item { width = W, height = H },
      background = ui.Item { width = W, height = H,
        path(W, H, { d = table.concat(ruler, " "), stroke_width = 1, stroke_color = function() return C().outlineVariant end }),
        piece(t,function() return t.mirrored and 0 or hx() + HW / 2 + GAP end,
          function() return t.mirrored and hx() - HW / 2 - GAP or W end, cy, TH,
          function() return C().secondaryContainer end) },
      fill = piece(t,function() return t.mirrored and hx() + HW / 2 + GAP or 0 end,
        function() return t.mirrored and W or hx() - HW / 2 - GAP end, cy, TH,
        function() return C().primary end),
      handle=moving(t,{y=FH+2,height=H-FH-2,radius=2,width=HW,color=function() return C().primary end},
        {x=function() return hx()-HW/2 end}),
      value_label = moving(t,{ y = 0, width = FW, height = FH, radius = FH / 2,
        color = function() return C().inverseSurface end,
        readout { anchors = { fill = true }, height = FH, horizontal_alignment = "center",
          color = function() return C().inverseOnSurface end,
          text = function() return clock(clamp01(t.position) * total) end } },
        {x=function() return math.max(0,math.min(W-FW,hx()-FW/2)) end}),
      second_handle = ring(t, 12),
    }
  end

  --- Stars: filled in the primary up to the value, each springing up as
  --- it fills.
  function S.rating(t, spec)
    local count = math.max(1, math.floor(num(spec.to, 5) - num(spec.from, 0) + 0.5))
    local Z, gap = 28, 6
    local W, H = count * (Z + gap) - gap, Z + 4
    local stars = ui.Item { width = W, height = H }
    for i = 1, count do
      local function on() return (t.value or 0) >= num(spec.from, 0) + i - 1e-6 end
      ui.reparent(M.icon("star", Z, function() return on() and C().primary or C().outlineVariant end,
        { x = function() return t.mirrored and (count - i) * (Z + gap) or (i - 1) * (Z + gap) end, y = 2,
          width = Z, height = Z, horizontal_alignment = "center", vertical_alignment = "center", fill = on,
          scale = function() return on() and 1 or 0.84 end, behavior = { scale = squish() } }), stars)
    end
    return full {
      track = ui.Item { width = W, height = H },
      background = ui.Item { width = W, height = H },
      fill = stars,
      second_handle = ring(t, 12),
    }
  end

  --- An adjustable level: a row of rounded cells, the lit ones primary
  --- and the last lit one taller, the percentage at the end.
  function S.level_control(t, spec)
    local W, H = num(spec.width, 250), num(spec.height, 32)
    local n = math.floor(num(spec.segments, 12))
    local gap, span = 4, W - 48
    local bw = (span - gap * (n - 1)) / n
    local cells = ui.Item { width = span, height = H }
    for i = 1, n do
      local function lit() return clamp01(t.position) >= (i - 0.5) / n end
      local function head() return lit() and clamp01(t.position) < (i + 0.5) / n end
      ui.reparent(ui.Rect { width = bw, radius = 4,
        height = function() return head() and 24 or 16 end, y = function() return head() and (H - 24) / 2 or (H - 16) / 2 end,
        x = function() return t.mirrored and span - i * (bw + gap) + gap or (i - 1) * (bw + gap) end,
        color = function() return lit() and C().primary or C().secondaryContainer end,
        behavior = { color = motion(), height = squish(), y = squish() } }, cells)
    end
    return full {
      track = ui.Item { width = span, height = H },
      background = ui.Item { width = W, height = H },
      fill = cells,
      value_label = readout { x = W - 44, width = 44, y = (H - 20) / 2, horizontal_alignment = "right",
        text = function() return ("%d%%"):format(math.floor(clamp01(t.position) * 100 + 0.5)) end },
      second_handle = ring(t, 12),
    }
  end

  --- An on-screen display's level: a pill on the container colour, the
  --- icon in a primary disc, a thick bar.
  function S.osd_level(t, spec)
    local W, H = num(spec.width, 260), num(spec.height, 52)
    local D = H - 12
    local x0, x1 = D + 18, W - 20
    local th = 12
    return full {
      track = ui.Item { width = W, height = H },
      background = ui.Item { width = W, height = H,
        ui.Rect { anchors = { fill = true }, radius = H / 2, color = function() return C().surfaceContainer end,
          shadow_color = function() return morf.color("#000000"):alpha(0.25) end, shadow_blur = 8, shadow_offset_y = 2 },
        ui.Rect { x = x0, y = H / 2 - th / 2, width = x1 - x0, height = th, radius = th / 2,
          color = function() return C().secondaryContainer end } },
      fill = ui.Rect { x = x0, y = H / 2 - th / 2, height = th, radius = th / 2,
        width = function() return math.max(th, (x1 - x0) * clamp01(t.position)) end,
        color = function() return C().primary end, behavior = { width = travel() } },
      ticks = ui.Rect { x = 6, y = 6, width = D, height = D, radius = D / 2, color = function() return C().primaryContainer end,
        M.icon(function()
          local i = get(spec.icon)
          if i then return i end
          return volume_icon(clamp01(t.position), get(spec.muted))
        end, 22, function() return C().onPrimaryContainer end,
          { anchors = { center_in = true }, fill = true }) },
    }
  end
end
