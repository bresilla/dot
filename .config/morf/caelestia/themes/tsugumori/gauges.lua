-- The instrument gauges: a segmented outer ring, a tick ruler, a thick
-- value arc glowing over its track, a needle at its head
-- and end stops; the centre is left to whatever it sits on. Small gauges keep a plain arc over a dashed track. Taken
-- whole from the Futuristic theme's instruments.
local morf = require("morf")
local ui = require("morf.ui")

return function(theme, kit)
  local C = theme.color
  local common = require("themes.kit_common")
  local get, clamp01 = common.get, common.clamp01
  local G = {}

  local function settle() return { duration = theme.duration.large, easing = theme.ease.emphasized_decel or "out_cubic" } end
  -- Line strengths these gauges are drawn at.
  local STRENGTH = { faint = .13, quiet = .24, idle = .4, mark = .72, hot = 1 }
  local function line(strength, color)
    local a = STRENGTH[strength]
    return function() return (color and get(color) or C.primary):alpha(a) end
  end
  local function accent() return kit.signal("accent") end

  -- (0 degrees at twelve o'clock, clockwise; a full turn too.)
  local arc = morf.geometry.arc
  G.arc = arc

  --- The ring gauge: `size`, `value` (0..1), `color`, `sweep` (300),
  --- `text` (fn -> string; the percentage when nil), `label`, `thickness`,
  --- `ticks` (60), `text_size`; children laid over it.
  function G.ring(spec)
    local s = spec.size
    local sweep = spec.sweep or 300
    local from = -sweep / 2
    local thick = spec.thickness or math.max(5, s / 9)
    local color = spec.color or accent()
    local c = s / 2
    local r0 = c - 1                           -- segmented outer ring
    local r1 = r0 - 6                          -- tick ring
    local r2 = r1 - 6 - thick / 2              -- value arc
    local r3 = r2 - thick / 2 - 5              -- inner hairline
    -- The tick ruler: every fifth tick long.
    local ticks = { morf.geometry.ticks(c, c, r1 - 2, r1,
      { from = from, sweep = sweep, count = spec.ticks or 60, major = 5, major_r0 = r1 - 5 }) }
    local function v() return clamp01(get(spec.value)) end
    local value_arc = arc(c, c, r2, from, sweep)
    local function path(props)
      props.anchors, props.view_box, props.fill_color = { fill = true }, { 0, 0, s, s }, props.fill_color or "transparent"
      return ui.Path(props)
    end
    local lit = function() return v() > .002 and 1 or 0 end
    local trim = function() return math.max(.001, v()) end
    local node = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s,
      -- Outer ring in segments, the ruler inside it.
      path { d = arc(c, c, r0, 0, 360), stroke_color = line("quiet", color), stroke_width = 2,
        dash = { math.max(0.5, math.pi * 2 * r0 / 48 - 3), 3 } },
      path { d = table.concat(ticks), stroke_color = line("mark", color), stroke_width = 1 },
      -- Track, then the value: a wide faint stroke under the arc makes its
      -- glow, the arc itself on top.
      path { d = value_arc, stroke_color = function() return get(color):alpha(.12) end, stroke_width = thick },
      path { d = value_arc, stroke_color = function() return get(color):alpha(.16) end, stroke_width = thick * 1.7,
        opacity = lit, trim_end = trim, behavior = { trim_end = settle() } },
      path { d = value_arc, stroke_color = color, stroke_width = thick,
        opacity = lit, trim_end = trim, behavior = { trim_end = settle() } },
      path { d = arc(c, c, r3, 0, 360), stroke_color = line("idle", color), stroke_width = 1, dash = { 3, 3 } },
    }
    -- The needle: a bright bar across the arc at its head.
    node[#node + 1] = ui.Item { anchors = { fill = true },
      rotation = function() return from + sweep * v() end, behavior = { rotation = settle() },
      ui.Rect { x = c - 1.5, y = c - r1, width = 3, height = r1 - (r2 - thick / 2) + 1,
        color = function() return C.onSurface end },
    }
    -- End stops of the sweep.
    for _, at in ipairs { from, from + sweep } do
      node[#node + 1] = ui.Item { anchors = { fill = true }, rotation = at,
        ui.Rect { x = c - 1, y = c - r0, width = 2, height = r0 - r3, color = line("mark", color) } }
    end
    local text = spec.text or function() return ("%d%%"):format(math.floor(v() * 100 + .5)) end
    -- The reading fits inside the inner hairline whatever size is asked for:
    -- about four characters across, with room for the label under it.
    local fit = math.max(8, math.floor(math.min(spec.text_size or s * .15, r3 * (spec.label and .5 or .6))))
    node[#node + 1] = ui.Column { anchors = { center_in = true }, width = math.floor(2 * r3), gap = 0, align = "center",
      ui.Text { text = text, font_family = theme.font, font_size = fit,
        font_weight = 300, color = color, horizontal_alignment = "center" },
      spec.label and kit.label { text = spec.label, horizontal_alignment = "center", color = kit.ink("lo") } or nil,
    }
    for _, child in ipairs(spec) do node[#node + 1] = child end
    return ui.Item(node)
  end

  --- The kit's gauge: the ring from 72 px up; a plain arc over a dashed
  --- track, with end ticks, below that.
  function G.gauge(spec)
    local size = spec.size
    if size >= 72 then
      local ring = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, size = size,
        value = spec.value, color = spec.color, thickness = spec.stroke,
        sweep = spec.sweep and math.min(spec.sweep, 320) or 300, text = function() return "" end }
      for _, child in ipairs(spec) do ring[#ring + 1] = child end
      return G.ring(ring)
    end
    local stroke = spec.stroke or 4
    local from, sweep = spec.from or 0, spec.sweep or 360
    local r = size / 2 - stroke / 2 - 1
    local d = arc(size / 2, size / 2, r, from, math.min(sweep, 359.9))
    local color = spec.color or accent()
    local function v() return clamp01(spec.value()) end
    local node = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = size, height = size,
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, size, size }, d = d, fill_color = "transparent",
        stroke_width = stroke, stroke_cap = "butt", dash = { 2, 2 },
        stroke_color = spec.track or line("quiet", color) },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, size, size }, d = d, fill_color = "transparent",
        stroke_width = stroke, stroke_cap = "butt", stroke_color = color,
        opacity = function() return v() > .002 and 1 or 0 end,
        trim_end = function() return math.max(.001, v()) end, behavior = { trim_end = settle() } },
    }
    if sweep < 360 then
      -- A tick across each end.
      local ends = morf.geometry.ticks(size / 2, size / 2, r - stroke, r + stroke / 2 + 1, { angles = { from, from + sweep } })
      node[#node + 1] = ui.Path { anchors = { fill = true }, view_box = { 0, 0, size, size }, d = ends,
        fill_color = "transparent", stroke_width = 1, stroke_color = line("mark", color) }
    end
    for _, child in ipairs(spec) do node[#node + 1] = child end
    return ui.Item(node)
  end

  --- A small ring with its caption under it: `size`, `value`, `text`,
  --- `label`, `color`, `text_size`.
  function G.mini_ring(spec)
    local s = spec.size
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, width = s, height = s + 14,
      G.ring { size = s, value = spec.value, color = spec.color, text = spec.text,
        text_size = spec.text_size or math.floor(s * .14), ticks = 40, sweep = 280 },
      kit.label { anchors = { horizontal_center = true }, y = s, text = spec.label, font_size = 10,
        horizontal_alignment = "center" },
    }
  end

  return G
end
