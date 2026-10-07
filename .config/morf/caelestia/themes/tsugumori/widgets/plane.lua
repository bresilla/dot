-- Tsugumori's looks for the Plane widgets beyond the colour plane
-- (skins.lua): square fields ruled with hairline grids, cross hairs
-- through square handles, corner brackets, readouts in the mono face. A
-- hue wheel is a ring of hues inside a degree ruler; a joystick a ringed
-- well whose stalk runs from the middle to a square cap that springs home
-- when let go (the archetype's `spring`; the cap's behaviour carries it).
-- The behaviour is the archetype's (crates/morf-kit/src/plane.rs).
local morf = require("morf")
local ui = require("morf.ui")
local stripes = require("themes.tsugumori.stripes")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local function get(v) if type(v) == "function" then return v() end return v end
  local function clamp01(v) v = tonumber(v) or 0 return v < 0 and 0 or (v > 1 and 1 or v) end
  local function num(v, d) v = get(v) return type(v) == "number" and v or d end
  local quick = { duration = 140, easing = "out_cubic" }

  local function full(slots)
    for _, name in ipairs { "background", "field", "crosshair", "handle", "content" } do
      if slots[name] == nil then slots[name] = ui.Item {} end
    end
    return slots
  end
  local function brackets(t, box, always)
    local holder = ui.Item { visible = always and true or function() return t.visual_focus end }
    if box then holder.x, holder.y, holder.width, holder.height = box[1], box[2], box[3], box[4]
    else holder.anchors = { fill = true } end
    ui.reparent(hud().corners { length = always and 10 or 6, weight = 2, color = function() return C.primary end }, holder)
    return holder
  end
  local function path(w, h, props)
    props.width, props.height, props.view_box = w, h, { 0, 0, w, h }
    if props.fill_color == nil then props.fill_color = "transparent" end
    return ui.Path(props)
  end
  local function readout(props)
    props.font_size = props.font_size or 12
    props.height = props.height or 18
    props.vertical_alignment = props.vertical_alignment or "center"
    props.color = props.color or function() return C.primary:alpha(.8) end
    return M.text(props)
  end
  --- A framed field: a hairline frame on the container ground with an
  --- 8 x 8 grid (`cols` x `rows`).
  local function grid_field(W, H, cols, rows)
    return ui.Item { width = W, height = H,
      ui.Rect { width = W, height = H, color = function() return C.surfaceContainer end,
        border_width = 1, border_color = function() return stroke(C, "idle") end },
      M.decor("grid", { width = W, height = H, columns = cols or 8, rows = rows or 8 }) }
  end
  local function segment(ax, ay, bx, by, width, color)
    return ui.Rect { height = width, color = color, transform_origin_x = 0, transform_origin_y = 0.5,
      x = function() return ax() end, y = function() return ay() - width / 2 end,
      width = function() local dx, dy = bx() - ax(), by() - ay() return math.sqrt(dx * dx + dy * dy) end,
      rotation = function() return math.deg(math.atan(by() - ay(), bx() - ax())) end }
  end
  --- Cross hairs across `W` x `H` through (`x`, `y`).
  local function hairs(W, H, x, y, alpha)
    return ui.Item { width = W, height = H,
      ui.Rect { width = W, height = 1, y = y, color = function() return C.primary:alpha(alpha or .6) end },
      ui.Rect { width = 1, height = H, x = x, color = function() return C.primary:alpha(alpha or .6) end } }
  end
  --- A square handle `K` across at (`x`, `y`): a frame, filled while held.
  local function square(t, K, x, y, props)
    props = props or {}
    props.width, props.height = K, K
    props.x = function() return x() - K / 2 end
    props.y = function() return y() - K / 2 end
    props.color = props.color or function() return t.down and C.primary or C.surfaceContainer end
    props.border_width = props.border_width or 2
    props.border_color = props.border_color or function() return (t.down or t.visual_focus) and C.primary or C.onSurface end
    props.behavior = props.behavior or { color = quick }
    return ui.Rect(props)
  end

  local function hue_at(f) return morf.color(("hsl(%d, 100%%, 50%%)"):format(math.floor(clamp01(f) * 360 + 0.5) % 360)) end
  local function hues()
    local stops = {}
    for k = 0, 12 do stops[#stops + 1] = ("hsl(%d, 100%%, 50%%)"):format(k * 30 % 360) end
    return stops
  end
  --- A hue wheel: a degree ruler round a ring of hues, a square handle on
  --- the ring filled with its hue, the chosen hue as a bracketed square
  --- in the middle with its angle.
  function S.hue_wheel(t, spec)
    local Sz = math.min(num(spec.width, 180), num(spec.height, 180))
    local c = Sz / 2
    local ro = c - 8
    local T = Sz * 0.11
    local rm = ro - T / 2
    local function angle() return clamp01(t.position_x) * 2 * math.pi end
    local function hx() return c + rm * math.sin(angle()) end
    local function hy() return c - rm * math.cos(angle()) end
    local sq = math.floor((ro - T) * 1.0)
    return full {
      background = ui.Item { width = Sz, height = Sz },
      field = ui.Item { width = Sz, height = Sz,
        path(Sz, Sz, { d = morf.geometry.ticks(c, c, ro + 2, ro + 6, { from = 0, sweep = 360, count = 72, major = 6,
          major_r0 = ro + 1 }), stroke_width = 1, stroke_color = function() return C.primary:alpha(.45) end }),
        ui.Sdf { x = c - ro, y = c - ro, width = 2 * ro, height = 2 * ro, gradient = { kind = "conic", stops = hues() },
          ui.SdfShape { shape = "circle", anchors = { fill = true } },
          ui.SdfShape { shape = "circle", anchors = { fill = true, margins = T }, operation = "subtract" } },
        ui.Rect { x = c - sq / 2, y = c - sq / 2, width = sq, height = sq, color = function() return hue_at(t.position_x) end,
          border_width = 1, border_color = function() return C.surfaceContainer end },
        ui.Item { x = c - sq / 2 - 4, y = c - sq / 2 - 4, width = sq + 8, height = sq + 8,
          hud().corners { length = 8, weight = 2, color = function() return C.primary end } },
        readout { x = c - sq / 2, y = c + sq / 2 - 20, width = sq, horizontal_alignment = "center",
          color = function() return C.surfaceContainer end,
          text = function() return ("%03d°"):format(math.floor(clamp01(t.position_x) * 360 + 0.5) % 360) end } },
      handle = square(t, T + 4, hx, hy, { color = function() return hue_at(t.position_x) end,
        border_color = function() return C.onSurface end }),
      crosshair = brackets(t, { 0, 0, Sz, Sz }),
    }
  end

  --- An XY pad: a ruled grid, cross hairs edge to edge through a square
  --- handle, the coordinates in the corner.
  function S.xy_pad(t, spec)
    local W, H = num(spec.width, 180), num(spec.height, 180)
    local function hx() return clamp01(t.visual_x) * W end
    local function hy() return clamp01(t.visual_y) * H end
    return full {
      background = ui.Item { width = W, height = H },
      field = ui.Item { width = W, height = H, grid_field(W, H),
        path(W, H, { d = ("M%g 0 V%g M0 %g H%g"):format(W / 2, H, H / 2, W), stroke_width = 1,
          stroke_color = function() return stroke(C, "idle") end }) },
      crosshair = ui.Item { width = W, height = H, hairs(W, H, hx, hy),
        readout { x = 6, y = 4, width = W - 12, text = function()
          return ("X%.2f Y%.2f"):format(t.x or 0, t.y or 0) end },
        brackets(t) },
      handle = square(t, 12, hx, hy),
    }
  end

  --- A panner: a square room ruled with rings at a third and two thirds,
  --- the listener a bracketed square in the middle, a line to the source.
  function S.pan_pad(t, spec)
    local Sz = math.min(num(spec.width, 180), num(spec.height, 180))
    local c = Sz / 2
    local function hx() return clamp01(t.visual_x) * Sz end
    local function hy() return clamp01(t.visual_y) * Sz end
    local function circle(r) return ("M%g %g A%g %g 0 1 1 %g %g A%g %g 0 1 1 %g %g"):format(c, c - r, r, r, c, c + r, r, r, c, c - r) end
    return full {
      background = ui.Item { width = Sz, height = Sz },
      field = ui.Item { width = Sz, height = Sz,
        ui.Rect { width = Sz, height = Sz, color = function() return C.surfaceContainer end,
          border_width = 1, border_color = function() return stroke(C, "idle") end },
        path(Sz, Sz, { d = circle(c - 2) .. " " .. circle(c * 2 / 3) .. " " .. circle(c / 3)
          .. (" M%g 0 V%g M0 %g H%g"):format(c, Sz, c, Sz), stroke_width = 1,
          stroke_color = function() return stroke(C, "idle") end }),
        ui.Item { x = c - 9, y = c - 9, width = 18, height = 18,
          hud().corners { length = 5, weight = 1, color = function() return C.onSurface end } },
        ui.Rect { x = c - 3, y = c - 3, width = 6, height = 6, color = function() return C.onSurface end } },
      crosshair = ui.Item { width = Sz, height = Sz,
        segment(function() return c end, function() return c end, hx, hy, 1, function() return C.primary end),
        readout { x = 6, y = Sz - 22, width = Sz - 12, text = function()
          local x, y = t.x or 0, t.y or 0
          return ("%s%03d %s%03d"):format(x < 0 and "L" or "R", math.floor(math.abs(x) * 100 + 0.5),
            y < 0 and "B" or "F", math.floor(math.abs(y) * 100 + 0.5))
        end },
        brackets(t) },
      handle = square(t, 12, hx, hy),
    }
  end

  --- An envelope's breakpoint: the rise and the fall as hairlines over a
  --- ruled grid, a drop line to the floor, the point a square block.
  function S.envelope_point(t, spec)
    local W, H = num(spec.width, 220), num(spec.height, 150)
    local pad = 8
    local fw, fh = W - 2 * pad, H - 2 * pad
    local function hx() return pad + clamp01(t.visual_x) * fw end
    local function hy() return pad + clamp01(t.visual_y) * fh end
    local function x0() return pad end
    local function x1() return W - pad end
    local function floor() return H - pad end
    local primary = function() return C.primary end
    return full {
      background = ui.Item { width = W, height = H },
      field = grid_field(W, H, 8, 4),
      crosshair = ui.Item { width = W, height = H,
        ui.Rect { width = 1, x = hx, y = hy, height = function() return floor() - hy() end,
          color = function() return C.primary:alpha(.5) end },
        ui.Rect { height = 1, x = x0, y = hy, width = function() return hx() - x0() end,
          color = function() return C.primary:alpha(.25) end },
        segment(x0, floor, hx, hy, 2, primary),
        segment(hx, hy, x1, floor, 2, primary),
        readout { x = 6, y = 4, width = W - 12, horizontal_alignment = "right", text = function()
          return ("T%.2f L%.2f"):format(t.x or 0, t.y or 0) end },
        brackets(t) },
      handle = square(t, 10, hx, hy, { color = primary, border_width = 0 }),
    }
  end

  --- A joystick: a ringed well in a square frame with brackets, cross
  --- hairs, a stalk from the middle to a square cap that springs home.
  function S.joystick(t, spec)
    local Sz = math.min(num(spec.width, 160), num(spec.height, 160))
    local c, K = Sz / 2, math.floor(Sz * 0.22)
    local reach = c - K / 2 - 8
    local function hx() return c + (clamp01(t.visual_x) - 0.5) * 2 * reach end
    local function hy() return c + (clamp01(t.visual_y) - 0.5) * 2 * reach end
    local home = ui.spring { stiffness = 520, damping = 24 }
    local cap = ui.Rect { width = K, height = K, x = function() return hx() - K / 2 end, y = function() return hy() - K / 2 end,
      behavior = { x = home, y = home }, color = function() return C.surfaceContainerHigh end,
      border_width = 2, border_color = function() return t.down and C.primary or C.onSurface end,
      ui.Item { x = 4, y = 4, width = K - 8, height = K - 8, clip = true,
        stripes.box { width = K - 8, height = K - 8, gap = 4, weight = 1.5, color = function() return C.primary end } } }
    -- The stalk: a bar from the middle, its length and turn on the cap's
    -- spring so it rides home with it; at rest it keeps its last turn.
    local last = 0
    local stalk = ui.Rect { x = c, y = c - 1, height = 2, transform_origin_x = 0, transform_origin_y = 0.5,
      color = function() return C.primary:alpha(.7) end, behavior = { width = home, rotation = home },
      width = function() local dx, dy = hx() - c, hy() - c return math.sqrt(dx * dx + dy * dy) end,
      rotation = function()
        local dx, dy = hx() - c, hy() - c
        if dx * dx + dy * dy > 1 then last = math.deg(math.atan(dy, dx)) end
        return last
      end }
    local function circle(r) return ("M%g %g A%g %g 0 1 1 %g %g A%g %g 0 1 1 %g %g"):format(c, c - r, r, r, c, c + r, r, r, c, c - r) end
    return full {
      background = ui.Item { width = Sz, height = Sz },
      field = ui.Item { width = Sz, height = Sz,
        ui.Rect { width = Sz, height = Sz, color = function() return C.surfaceContainer end,
          border_width = 1, border_color = function() return stroke(C, "quiet") end },
        brackets(t, { 0, 0, Sz, Sz }, true),
        path(Sz, Sz, { d = circle(c - 6) .. " " .. circle((c - 6) / 2) .. (" M%g 10 V%g M10 %g H%g"):format(c, Sz - 10, c, Sz - 10),
          stroke_width = 1, stroke_color = function() return stroke(C, "idle") end }),
        ui.Rect { x = c - 4, y = c - 4, width = 8, height = 8, color = function() return C.primary end } },
      crosshair = stalk,
      handle = cap,
    }
  end

  --- A minimap: the page in miniature, the view a bracketed frame over it
  --- with a faint hatch inside.
  function S.minimap_viewport(t, spec)
    local W, H = num(spec.width, 150), num(spec.height, 190)
    local view = get(spec.view) or { 0.5, 0.32 }
    local fw, fh = math.floor(W * view[1]), math.floor(H * view[2])
    local lines, y = {}, 14
    local widths = { 0.8, 0.95, 0.6, 0, 0.9, 0.85, 0.7, 0, 0.92, 0.5, 0.88, 0.76, 0, 0.9, 0.64, 0.8, 0.94, 0.4 }
    for i, f in ipairs(widths) do
      if f > 0 then lines[#lines + 1] = ("M12 %d H%d"):format(y, 12 + math.floor((W - 24) * f)) end
      y = y + (f > 0 and 9 or 7)
      if y > H - 12 then break end
      if i == 4 then y = y + 34 end
    end
    local function fx() return clamp01(t.visual_x) * (W - fw) end
    local function fy() return clamp01(t.visual_y) * (H - fh) end
    return full {
      background = ui.Item { width = W, height = H },
      field = ui.Item { width = W, height = H,
        ui.Rect { width = W, height = H, color = function() return C.surfaceContainer end,
          border_width = 1, border_color = function() return stroke(C, "idle") end },
        path(W, H, { d = table.concat(lines, " "), stroke_width = 2,
          stroke_color = function() return C.onSurfaceVariant:alpha(.45) end }),
        ui.Rect { x = 12, y = 56, width = W - 24, height = 26, color = function() return C.primary:alpha(.12) end,
          border_width = 1, border_color = function() return C.primary:alpha(.3) end } },
      crosshair = ui.Item { x = fx, y = fy, width = fw, height = fh, clip = true,
        stripes.box { width = fw, height = fh, gap = 7, weight = 1, color = function() return C.primary:alpha(.25) end } },
      handle = ui.Item { x = fx, y = fy, width = fw, height = fh,
        ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
          border_color = function() return C.primary:alpha(.7) end },
        hud().corners { length = 8, weight = 2, color = function() return C.primary end } },
    }
  end

  --- A crop: a picture dimmed outside the crop, thirds inside, square
  --- brackets on every corner, the dragged one with a block on its point.
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
    local scrim = function() return morf.color("#000000"):alpha(.55) end
    local hill = ("M0 %g L%g %g L%g %g L%g %g L%g %g L%g %g Z"):format(H, W * 0.28, H * 0.5, W * 0.46, H * 0.72,
      W * 0.68, H * 0.38, W, H * 0.66, W, H)
    local shade = ui.Item { width = W, height = H,
      ui.Rect { x = 0, y = 0, width = W, height = y0, color = scrim },
      ui.Rect { x = 0, y = y1, width = W, height = function() return H - y1() end, color = scrim },
      ui.Rect { x = 0, y = y0, width = x0, height = function() return y1() - y0() end, color = scrim },
      ui.Rect { x = x1, y = y0, width = function() return W - x1() end, height = function() return y1() - y0() end, color = scrim },
      ui.Rect { x = x0, y = y0, width = function() return x1() - x0() end, height = function() return y1() - y0() end,
        color = "transparent", border_width = 1, border_color = function() return C.primary:alpha(.7) end } }
    for k = 1, 2 do
      ui.reparent(ui.Rect { width = 1, y = y0, height = function() return y1() - y0() end,
        x = function() return x0() + (x1() - x0()) * k / 3 end, color = function() return C.primary:alpha(.35) end }, shade)
      ui.reparent(ui.Rect { height = 1, x = x0, width = function() return x1() - x0() end,
        y = function() return y0() + (y1() - y0()) * k / 3 end, color = function() return C.primary:alpha(.35) end }, shade)
    end
    local L, T = 14, 2
    local corners = ui.Item { width = W, height = H }
    for _, corner in ipairs { { true, true }, { false, true }, { true, false }, { false, false } } do
      local cxf = corner[1] and x0 or x1
      local cyf = corner[2] and y0 or y1
      local left, top = corner[1], corner[2]
      local color = function() return C.primary end
      ui.reparent(ui.Rect { width = L, height = T, color = color,
        x = function() return left and cxf() - T or cxf() - L + T end,
        y = function() return top and cyf() - T or cyf() end }, corners)
      ui.reparent(ui.Rect { width = T, height = L, color = color,
        x = function() return left and cxf() - T or cxf() end,
        y = function() return top and cyf() - T or cyf() - L + T end }, corners)
    end
    -- The dragged corner's block.
    ui.reparent(ui.Rect { width = 8, height = 8, x = function() return hx() - 4 end, y = function() return hy() - 4 end,
      color = function() return t.down and C.onSurface or C.primary end }, corners)
    return full {
      background = ui.Item { width = W, height = H },
      field = ui.Item { width = W, height = H, clip = true,
        ui.Rect { anchors = { fill = true }, gradient = function()
          return { angle = 180, stops = { C.surfaceContainerHighest, C.primaryContainer } } end },
        ui.Rect { x = W * 0.7, y = H * 0.14, width = H * 0.2, height = H * 0.2, color = function() return C.primary end },
        path(W, H, { d = hill, fill_color = function() return C.surfaceContainerLow end }),
        stripes.box { x = 0, y = 0, width = W, height = H, gap = 9, weight = 1, color = function() return C.primary:alpha(.12) end } },
      crosshair = ui.Item { width = W, height = H, shade, brackets(t) },
      handle = corners,
    }
  end
end
