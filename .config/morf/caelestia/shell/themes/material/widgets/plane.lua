-- Material's looks for the Plane widgets beyond the colour plane
-- (skins.lua): tonal fields with generous corners, the primary for what
-- moves, handles that swell under a hand. A hue wheel is a ring of hues
-- with a tonal cookie in the middle; a joystick's stalk is a distance
-- field fusing the middle to its cap, which springs home when let go (the
-- archetype's `spring`; the cap's behaviour carries it). The behaviour is
-- the archetype's (crates/morf-kit/src/plane.rs).
local morf = require("morf")
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local function get(v) if type(v) == "function" then return v() end return v end
  local function clamp01(v) v = tonumber(v) or 0 return v < 0 and 0 or (v > 1 and 1 or v) end
  local function num(v, d) v = get(v) return type(v) == "number" and v or d end
  local function squish() return ui.spring { stiffness = 520, damping = 18 } end

  local function full(slots)
    for _, name in ipairs { "background", "field", "crosshair", "handle", "content" } do
      if slots[name] == nil then slots[name] = ui.Item {} end
    end
    return slots
  end
  local function ring(t, radius, box)
    local props = { z = 50, color = "transparent", radius = radius, border_width = 2,
      border_color = function() return C().secondary end, visible = function() return t.visual_focus end }
    if box then props.x, props.y, props.width, props.height = box[1], box[2], box[3], box[4]
    else props.anchors = { fill = true, margins = 1 } end
    return ui.Rect(props)
  end
  local function path(w, h, props)
    props.width, props.height, props.view_box = w, h, { 0, 0, w, h }
    if props.fill_color == nil then props.fill_color = "transparent" end
    return ui.Path(props)
  end
  local function grid_d(w, h, cols, rows)
    local d = {}
    for k = 1, cols - 1 do d[#d + 1] = ("M%.1f 0 V%g"):format(w * k / cols, h) end
    for k = 1, rows - 1 do d[#d + 1] = ("M0 %.1f H%g"):format(h * k / rows, w) end
    return table.concat(d, " ")
  end
  local function field_box(W, H, radius)
    return ui.Rect { width = W, height = H, radius = radius or 16, color = function() return C().surfaceContainerHigh end }
  end
  local function lines() return C().outlineVariant:alpha(0.6) end
  local function segment(ax, ay, bx, by, width, color)
    return ui.Rect { height = width, radius = width / 2, color = color, transform_origin_x = 0, transform_origin_y = 0.5,
      x = function() return ax() end, y = function() return ay() - width / 2 end,
      width = function() local dx, dy = bx() - ax(), by() - ay() return math.sqrt(dx * dx + dy * dy) end,
      rotation = function() return math.deg(math.atan(by() - ay(), bx() - ax())) end }
  end
  --- A round handle `K` across at (`x`, `y`), swelling while held.
  local function dot(t, K, x, y, props)
    props = props or {}
    props.width, props.height, props.radius = K, K, K / 2
    props.x = function() return x() - K / 2 end
    props.y = function() return y() - K / 2 end
    props.color = props.color or function() return C().primary end
    props.border_width = props.border_width or 3
    props.border_color = props.border_color or function() return C().surface end
    props.scale = function() return t.down and 1.25 or 1 end
    props.behavior = { scale = squish() }
    return ui.Rect(props)
  end

  local function hue_at(f) return morf.color(("hsl(%d, 100%%, 50%%)"):format(math.floor(clamp01(f) * 360 + 0.5) % 360)) end
  local function hues()
    local stops = {}
    for k = 0, 12 do stops[#stops + 1] = ("hsl(%d, 100%%, 50%%)"):format(k * 30 % 360) end
    return stops
  end
  --- A hue wheel: the ring of hues, a handle on it filled with its hue,
  --- and the chosen hue as a cookie in the middle that turns with it.
  function S.hue_wheel(t, spec)
    local Sz = math.min(num(spec.width, 180), num(spec.height, 180))
    local c, T = Sz / 2, Sz * 0.14
    local rm = c - T / 2
    local function angle() return clamp01(t.position_x) * 2 * math.pi end
    local function hx() return c + rm * math.sin(angle()) end
    local function hy() return c - rm * math.cos(angle()) end
    local inner = rm - T / 2 - 10
    return full {
      background = ui.Item { width = Sz, height = Sz },
      field = ui.Item { width = Sz, height = Sz,
        ui.Sdf { anchors = { fill = true }, gradient = { kind = "conic", stops = hues() },
          ui.SdfShape { shape = "circle", anchors = { fill = true } },
          ui.SdfShape { shape = "circle", anchors = { fill = true, margins = T }, operation = "subtract" } },
        ui.Path { x = c - inner, y = c - inner, width = 2 * inner, height = 2 * inner, view_box = { 0, 0, 100, 100 },
          d = morf.geometry.shape_path("cookie9"), fill_color = function() return hue_at(t.position_x) end,
          rotation = function() return clamp01(t.position_x) * 360 end, behavior = { rotation = squish() } } },
      handle = dot(t, T + 6, hx, hy, { color = function() return hue_at(t.position_x) end,
        border_color = function() return C().surface end }),
      crosshair = ring(t, c, { 0, 0, Sz, Sz }),
    }
  end

  --- An XY pad: a tonal field with a grid, rails through the handle.
  function S.xy_pad(t, spec)
    local W, H = num(spec.width, 180), num(spec.height, 180)
    local function hx() return clamp01(t.visual_x) * W end
    local function hy() return clamp01(t.visual_y) * H end
    return full {
      background = ui.Item { width = W, height = H },
      field = ui.Item { width = W, height = H, field_box(W, H),
        path(W, H, { d = grid_d(W, H, 4, 4), stroke_width = 1, stroke_color = lines }) },
      crosshair = ui.Item { width = W, height = H,
        ui.Rect { x = 8, width = W - 16, height = 2, radius = 1, y = function() return hy() - 1 end,
          color = function() return C().primary:alpha(0.35) end },
        ui.Rect { y = 8, width = 2, height = H - 16, radius = 1, x = function() return hx() - 1 end,
          color = function() return C().primary:alpha(0.35) end },
        ring(t, 16) },
      handle = dot(t, 20, hx, hy),
    }
  end

  --- A panner: a round tonal room with rings, the listener in a disc in
  --- the middle, a rail from them to the source.
  function S.pan_pad(t, spec)
    local Sz = math.min(num(spec.width, 180), num(spec.height, 180))
    local c = Sz / 2
    local function hx() return clamp01(t.visual_x) * Sz end
    local function hy() return clamp01(t.visual_y) * Sz end
    local function circle(r) return ("M%g %g A%g %g 0 1 1 %g %g A%g %g 0 1 1 %g %g"):format(c, c - r, r, r, c, c + r, r, r, c, c - r) end
    return full {
      background = ui.Item { width = Sz, height = Sz },
      field = ui.Item { width = Sz, height = Sz, field_box(Sz, Sz, c),
        path(Sz, Sz, { d = circle(c / 3) .. " " .. circle(c * 2 / 3), stroke_width = 1, stroke_color = lines }),
        ui.Rect { x = c - 16, y = c - 16, width = 32, height = 32, radius = 16, color = function() return C().secondaryContainer end,
          M.icon("headphones", 18, function() return C().onSecondaryContainer end, { anchors = { center_in = true } }) } },
      crosshair = ui.Item { width = Sz, height = Sz,
        segment(function() return c end, function() return c end, hx, hy, 4, function() return C().primary:alpha(0.5) end),
        ring(t, c, { 0, 0, Sz, Sz }) },
      handle = dot(t, 22, hx, hy),
    }
  end

  --- An envelope's breakpoint: the rise and the fall as thick rounded
  --- rails, a drop line, the point a tonal squircle.
  function S.envelope_point(t, spec)
    local W, H = num(spec.width, 220), num(spec.height, 150)
    local pad = 10
    local fw, fh = W - 2 * pad, H - 2 * pad
    local function hx() return pad + clamp01(t.visual_x) * fw end
    local function hy() return pad + clamp01(t.visual_y) * fh end
    local function x0() return pad end
    local function x1() return W - pad end
    local function floor() return H - pad end
    local primary = function() return C().primary end
    return full {
      background = ui.Item { width = W, height = H },
      field = ui.Item { width = W, height = H, field_box(W, H),
        path(W, H, { d = grid_d(W, H, 8, 4), stroke_width = 1, stroke_color = lines }) },
      crosshair = ui.Item { width = W, height = H,
        ui.Rect { width = 2, radius = 1, x = function() return hx() - 1 end, y = hy,
          height = function() return floor() - hy() end, color = function() return C().primary:alpha(0.3) end },
        segment(x0, floor, hx, hy, 4, primary),
        segment(hx, hy, x1, floor, 4, primary),
        ring(t, 16) },
      handle = ui.Rect { width = 18, height = 18, x = function() return hx() - 9 end, y = function() return hy() - 9 end,
        radius = function() return t.down and 9 or 6 end, color = function() return C().primaryContainer end,
        border_width = 3, border_color = primary,
        scale = function() return t.down and 1.2 or 1 end, behavior = { scale = squish(), radius = squish() } },
    }
  end

  --- A joystick: a round tonal well, a primary cap on a stalk fused to the
  --- middle, springing home when let go.
  function S.joystick(t, spec)
    local Sz = math.min(num(spec.width, 160), num(spec.height, 160))
    local c, K = Sz / 2, math.floor(Sz * 0.3)
    local reach = c - K / 2 - 4
    local function hx() return c + (clamp01(t.visual_x) - 0.5) * 2 * reach end
    local function hy() return c + (clamp01(t.visual_y) - 0.5) * 2 * reach end
    local home = ui.spring { stiffness = 420, damping = 14 }
    local cap = ui.Rect { width = K, height = K, radius = K / 2,
      x = function() return hx() - K / 2 end, y = function() return hy() - K / 2 end,
      behavior = { x = home, y = home, scale = squish() }, stretch = M.STRETCH,
      scale = function() return t.down and 0.92 or 1 end,
      color = function() return C().primary end,
      shadow_color = function() return morf.color("#000000"):alpha(0.3) end, shadow_blur = 10, shadow_offset_y = 3,
      ui.Rect { x = K / 2 - 7, y = K / 2 - 7, width = 14, height = 14, radius = 7, color = function() return C().onPrimary end } }
    return full {
      background = ui.Item { width = Sz, height = Sz },
      field = ui.Item { width = Sz, height = Sz,
        ui.Rect { width = Sz, height = Sz, radius = c, color = function() return C().surfaceContainerHighest end },
        ui.Rect { x = 14, y = 14, width = Sz - 28, height = Sz - 28, radius = c - 14, color = "transparent",
          border_width = 2, border_color = lines },
        ui.Sdf { anchors = { fill = true }, blend = K * 0.9, fill_color = function() return C().primaryContainer end,
          ui.SdfShape { shape = "circle", x = c - 10, y = c - 10, width = 20, height = 20 },
          ui.SdfShape { shape = "circle", operation = "smooth_union", track = cap } } },
      handle = cap,
      crosshair = ring(t, c, { 0, 0, Sz, Sz }),
    }
  end

  --- A minimap: the page in miniature on a tonal card, the view a
  --- rounded primary frame over it.
  function S.minimap_viewport(t, spec)
    local W, H = num(spec.width, 150), num(spec.height, 190)
    local view = get(spec.view) or { 0.5, 0.32 }
    local fw, fh = W * view[1], H * view[2]
    local lines_d, y = {}, 14
    local widths = { 0.8, 0.95, 0.6, 0, 0.9, 0.85, 0.7, 0, 0.92, 0.5, 0.88, 0.76, 0, 0.9, 0.64, 0.8, 0.94, 0.4 }
    for i, f in ipairs(widths) do
      if f > 0 then lines_d[#lines_d + 1] = ("M12 %d H%d"):format(y, 12 + math.floor((W - 24) * f)) end
      y = y + (f > 0 and 9 or 7)
      if y > H - 12 then break end
      if i == 4 then y = y + 34 end
    end
    local function fx() return clamp01(t.visual_x) * (W - fw) end
    local function fy() return clamp01(t.visual_y) * (H - fh) end
    return full {
      background = ui.Item { width = W, height = H },
      field = ui.Item { width = W, height = H, field_box(W, H, 12),
        path(W, H, { d = table.concat(lines_d, " "), stroke_width = 3, stroke_cap = "round",
          stroke_color = function() return C().onSurfaceVariant:alpha(0.35) end }),
        ui.Rect { x = 12, y = 56, width = W - 24, height = 26, radius = 8, color = function() return C().tertiaryContainer end } },
      crosshair = ui.Item { width = W, height = H,
        ui.Rect { x = fx, y = fy, width = fw, height = fh, radius = 10, color = function() return C().primary:alpha(0.14) end },
        ring(t, 12) },
      handle = ui.Rect { x = fx, y = fy, width = fw, height = fh, radius = 10, color = "transparent",
        border_width = function() return t.down and 4 or 3 end, border_color = function() return C().primary end },
    }
  end

  --- A crop: a picture dimmed outside the crop, thirds inside, thick
  --- rounded corner brackets, the dragged one in the primary.
  function S.crop_handle(t, spec)
    local W, H = num(spec.width, 220), num(spec.height, 160)
    local anchor = get(spec.anchor) or { 0.14, 0.16 }
    local ax, ay = anchor[1] * W, anchor[2] * H
    local function hx() return clamp01(t.visual_x) * W end
    local function hy() return clamp01(t.visual_y) * H end
    local function x0() return math.min(ax, hx()) end
    local function x1() return math.max(ax, hx()) end
    local function y0() return math.min(ay, hy()) end
    local function y1() return math.max(ay, hy()) end
    local scrim = function() return morf.color("#000000"):alpha(0.5) end
    local hill = ("M0 %g L%g %g L%g %g L%g %g L%g %g L%g %g Z"):format(H, W * 0.28, H * 0.5, W * 0.46, H * 0.72,
      W * 0.68, H * 0.38, W, H * 0.66, W, H)
    local shade = ui.Item { width = W, height = H,
      ui.Rect { x = 0, y = 0, width = W, height = y0, color = scrim },
      ui.Rect { x = 0, y = y1, width = W, height = function() return H - y1() end, color = scrim },
      ui.Rect { x = 0, y = y0, width = x0, height = function() return y1() - y0() end, color = scrim },
      ui.Rect { x = x1, y = y0, width = function() return W - x1() end, height = function() return y1() - y0() end, color = scrim } }
    for k = 1, 2 do
      ui.reparent(ui.Rect { width = 1, y = y0, height = function() return y1() - y0() end,
        x = function() return x0() + (x1() - x0()) * k / 3 end, color = function() return C().primaryFixed:alpha(0.5) end }, shade)
      ui.reparent(ui.Rect { height = 1, x = x0, width = function() return x1() - x0() end,
        y = function() return y0() + (y1() - y0()) * k / 3 end, color = function() return C().primaryFixed:alpha(0.5) end }, shade)
    end
    local L, T = 18, 4
    local corners = ui.Item { width = W, height = H }
    for _, corner in ipairs { { true, true }, { false, true }, { true, false }, { false, false } } do
      local cxf = corner[1] and x0 or x1
      local cyf = corner[2] and y0 or y1
      local left, top = corner[1], corner[2]
      local function dragged() return math.abs(cxf() - hx()) < 0.5 and math.abs(cyf() - hy()) < 0.5 end
      -- (The fixed tone: light on the dimmed picture in either scheme.)
      local color = function() return dragged() and C().primaryFixedDim or C().primaryFixed end
      ui.reparent(ui.Rect { width = L, height = T, radius = T / 2, color = color,
        x = function() return left and cxf() - T / 2 or cxf() - L + T / 2 end,
        y = function() return top and cyf() - T / 2 or cyf() - T / 2 end }, corners)
      ui.reparent(ui.Rect { width = T, height = L, radius = T / 2, color = color,
        x = function() return cxf() - T / 2 end,
        y = function() return top and cyf() - T / 2 or cyf() - L + T / 2 end }, corners)
    end
    return full {
      background = ui.Item { width = W, height = H },
      field = ui.ClipRect { width = W, height = H, radius = 16, color = "transparent",
        ui.Rect { anchors = { fill = true }, gradient = function()
          return { angle = 180, stops = { C().primaryContainer, C().tertiaryContainer } } end },
        ui.Rect { x = W * 0.7, y = H * 0.14, width = H * 0.2, height = H * 0.2, radius = H * 0.1,
          color = function() return C().tertiary end },
        path(W, H, { d = hill, fill_color = function() return C().secondary end }) },
      crosshair = ui.ClipRect { width = W, height = H, radius = 16, color = "transparent", shade,
        ui.Rect { x = x0, y = y0, width = function() return x1() - x0() end, height = function() return y1() - y0() end,
          color = "transparent", border_width = 1, border_color = function() return C().primaryFixed:alpha(0.8) end },
        ring(t, 16) },
      handle = corners,
    }
  end
end
