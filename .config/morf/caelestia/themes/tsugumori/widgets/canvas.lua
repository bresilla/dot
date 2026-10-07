-- Tsugumori's looks for the Canvas archetype and each of its widgets. The
-- layouts are the kit's (the default look's canvas_dock.lua and
-- widgets/canvas.lua), drawn square in the wallpaper's roles with the
-- primary's quiet strokes; what Tsugumori draws its own way is given
-- after: a grid of fine lines with registration crosses at every fourth
-- crossing, bracket corners that close in on what is chosen, a hatched
-- band, edge ticks that follow the pointer, wires that run in right
-- angles, square ports, framed buttons and a bracketed readout.
local morf = require("morf")
local ui = require("morf.ui")
local stripes = require("themes.tsugumori.stripes")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local canvas = require("lib.kit.canvas")
  local shadow = morf.color("#000000")
  local quick = { duration = 140, easing = "out_cubic" }

  --- The kit's palette names in the wallpaper's roles: grounds from the
  --- surface tones, lines from the primary's strokes.
  local function P()
    local dark = not C.surface:is_light()
    return {
      view = C.surface, window = C.surface, card = C.surfaceContainer, raised = C.surfaceContainerHigh,
      sidebar = C.surfaceContainerLow, header = C.surfaceContainerLow, ink = C.onSurface, ink_dim = C.onSurfaceVariant,
      border = C.primary:mix(C.surface, 0.8), shade = shadow, accent = C.primary, accent_ink = C.primary,
      on_accent = C.onPrimary, track = C.surfaceContainerHighest, paper = dark and C.onSurface or C.surfaceContainerLowest,
      info = C.secondary, extra = C.tertiary, error = C.error, destructive = C.error,
      success = C.tertiary:mix(C.secondary, 0.5), warning = C.tertiary:mix(C.error, 0.45),
      wash = { hover = 0.05, selected = 0.1, active = 0.14, button = 0.06, checked = 0.18, raised_hover = 0.08 },
      strong = false, dark = dark,
      -- (The run under a chart's series: barely tinted.)
      area = 0.95,
      -- A tone's fill: its colour barely in the ground; its ink the tone.
      fills = { accent = C.primary:mix(C.surface, 0.86), info = C.secondary:mix(C.surface, 0.86),
        extra = C.tertiary:mix(C.surface, 0.86), error = C.error:mix(C.surface, 0.84),
        success = C.secondary:mix(C.tertiary, 0.5):mix(C.surface, 0.86),
        warning = C.tertiary:mix(C.error, 0.45):mix(C.surface, 0.86) },
      on_fills = { accent = C.primary, info = C.secondary, extra = C.tertiary, error = C.error,
        success = C.secondary:mix(C.tertiary, 0.5), warning = C.tertiary:mix(C.error, 0.45) },
    }
  end
  M.canvas_palette = P
  local look = {
    P = P, radius = { small = 0, medium = 0, large = 0, window = 0 },
    size = theme.size, duration = theme.duration, ease = theme.ease, reduced = theme.reduced,
  }
  local K = setmetatable({}, { __index = M })

  -- Over a map or an image: a square framed button, its frame lit and
  -- its ground washed under the pointer.
  function K.canvas_osd(icon, name, action, props)
    props = props or {}
    local area
    props.width, props.height = props.width or 36, props.height or 36
    props.cursor, props.accessible_role, props.accessible_name = "pointer", "button", name
    props.on_clicked = action
    area = ui.MouseArea(props)
    ui.reparent(ui.Rect { anchors = { fill = true }, border_width = 1,
      color = function() return area.pressed and C.primary:mix(C.surfaceContainer, 0.75) or C.surfaceContainer end,
      border_color = function() return area.hovered and stroke(C, "focus") or stroke(C, "idle") end,
      behavior = { border_color = quick } }, area)
    ui.reparent(M.icon(icon, 20, function() return area.hovered and C.primary or C.onSurface end,
      { anchors = { center_in = true } }), area)
    return area
  end
  function K.canvas_osd_label(text)
    return ui.Rect { width = 76, height = 36, color = function() return C.surfaceContainer end, border_width = 1,
      border_color = function() return stroke(C, "idle") end,
      M.text { anchors = { fill = true }, text = text, font_size = theme.size.small,
        color = function() return C.primary end, horizontal_alignment = "center", vertical_alignment = "center" } }
  end
  -- A port lit by the pointer stays square: it only grows.
  function K.canvas_port_round() return 0 end

  require("lib.kit.skins.default.canvas_dock")(S, look, K)
  require("lib.kit.skins.default.widgets.canvas")(S, look, K)
  M.canvas_look, M.canvas_kit = look, K

  -- ------------------------------------------------------------ Tsugumori --

  -- What is chosen: four brackets a few pixels out that close in from
  -- further out as it is picked.
  local function chosen(margin)
    return function(s)
      local m = (s.item().shape == "point") and -12 or (margin or -6)
      return ui.Item { anchors = { fill = true, margins = m }, scale = 1, opacity = 1,
        enter = { scale = 1.18, opacity = 0, duration = 220, easing = "out_cubic" },
        hud().corners { length = 8, weight = 2, color = function() return C.primary end },
        ui.Rect { anchors = { fill = true, margins = 3 }, color = "transparent", border_width = 1,
          border_color = function() return stroke(C, "hover") end } }
    end
  end

  -- A hatch the size of the canvas, made once (again only if the canvas
  -- is resized), seen through a box that moves: the stripes stay put as
  -- the box slides and grows over them.
  local function hatched(t, box, color)
    return ui.Item { clip = true,
      x = function() return (box()) end, y = function() return (select(2, box())) end,
      width = function() return math.max(0, select(3, box())) end,
      height = function() return math.max(0, select(4, box())) end,
      ui.Path { x = function() return -(box()) end, y = function() return -(select(2, box())) end,
        width = function() return t.width or 0 end, height = function() return t.height or 0 end,
        d = function() return stripes.hatch_d(math.max(1, t.width or 0), math.max(1, t.height or 0), 9) end,
        fill_color = "transparent", stroke_color = color, stroke_width = 1.5, stroke_cap = "butt" } }
  end
  M.canvas_hatched = hatched

  local function restyle(name, change) require("lib.kit.canvas").restyle(S, name, change) end

  restyle("Canvas", function(slots, t, spec)
    -- A square grip block in the primary, filled while held.
    slots.grip = function(s)
      return ui.Rect { x = -4, y = -4, width = 8, height = 8, radius = 0,
        color = function() return (s.held() or s.hovered()) and C.primary or C.surface end,
        border_width = 1, border_color = function() return C.primary end }
    end
    slots.selection = chosen()
    -- Fine lines and a registration cross at every fourth crossing.
    if slots.grid and spec.widget ~= "chart_inspector" and spec.widget ~= "timeline_track"
      and spec.widget ~= "drawing_board" and spec.widget ~= "image_viewer" then
      slots.grid = ui.Item { anchors = { fill = true },
        canvas.grid(t, { stroke_width = 1, stroke_color = function() return C.primary:mix(C.surface, 0.94) end }),
        canvas.grid(t, { kind = "crosses", every = 4, arm = 5, stroke_width = 1,
          stroke_color = function() return C.primary:mix(C.surface, 0.55) end }) }
    end
    -- The band: hatched, framed, bracketed.
    local function band() return canvas.band_box(t) end
    local plate = hatched(t, band, function() return C.primary:alpha(0.35) end)
    slots.band = ui.Item { anchors = { fill = true },
      visible = function() return t.band ~= nil and t.band ~= "" and t.gesture ~= "none" end,
      plate,
      ui.Item { x = function() return (band()) end, y = function() return (select(2, band())) end,
        width = function() return select(3, band()) end, height = function() return select(4, band()) end,
        ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
          border_color = function() return stroke(C, "focus") end },
        hud().corners { length = 6, weight = 2, color = function() return C.primary end } } }
    -- Ticks on the edges where the pointer is, and its place in world
    -- units in the corner.
    if not slots.crosshair then
      slots.crosshair = ui.Item { anchors = { fill = true }, visible = function() return t.pointer_inside end,
        ui.Rect { y = 0, width = 1, height = 10, color = function() return C.primary end,
          x = function() return (t.pointer_x - t.view_x) * t.zoom_x end },
        ui.Rect { width = 1, height = 10, anchors = { bottom = true }, color = function() return C.primary end,
          x = function() return (t.pointer_x - t.view_x) * t.zoom_x end },
        ui.Rect { x = 0, height = 1, width = 10, color = function() return C.primary end,
          y = function() return (t.pointer_y - t.view_y) * t.zoom_y end },
        ui.Rect { height = 1, width = 10, anchors = { right = true }, color = function() return C.primary end,
          y = function() return (t.pointer_y - t.view_y) * t.zoom_y end } }
    end
    -- The canvas's frame: a quiet line with brackets on its corners.
    local frame = ui.Item { anchors = { fill = true },
      ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
        border_color = function() return stroke(C, "idle") end },
      hud().corners { length = 10, weight = 2, color = function() return stroke(C, "corner") end } }
    if slots.overlay then
      -- The zoom: a framed readout in the primary.
      local reading = ui.Rect { anchors = { right = true, bottom = true, margins = 12 }, width = 78, height = 26,
        color = function() return C.surfaceContainer end, border_width = 1,
        border_color = function() return stroke(C, "idle") end,
        M.text { anchors = { fill = true }, font_size = theme.size.small, color = function() return C.primary end,
          text = function() return ("%d%%"):format(math.floor((t.zoom or 1) * 100 + 0.5)) end,
          horizontal_alignment = "center", vertical_alignment = "center" } }
      local old = slots.overlay
      if spec.widget == "zoomable_canvas" or spec.widget == "node_graph" or spec.widget == "drawing_board" then
        old = reading
      end
      slots.overlay = ui.Item { anchors = { fill = true }, frame, old }
      return { old }
    else
      slots.overlay = frame
    end
  end)

  -- Wires in right angles: out level, across at the middle, in level.
  local function elbow(x0, y0, x1, y1)
    local mid = x0 + math.max(24, (x1 - x0) / 2)
    if x1 < x0 + 48 then mid = x0 + 24 end
    if x1 >= mid + 24 or x1 >= x0 + 48 then
      return ("M%.1f %.1f H%.1f V%.1f H%.1f"):format(x0, y0, mid, y1, x1)
    end
    local back = x1 - 24
    local half = (y0 + y1) / 2
    return ("M%.1f %.1f H%.1f V%.1f H%.1f V%.1f H%.1f"):format(x0, y0, mid, half, back, y1, x1)
  end

  restyle("node_graph", function(slots, t, spec)
    slots.selection = chosen(-6)
    -- The wire being pulled runs in right angles too, dashed.
    slots.draft = ui.Item { anchors = { fill = true },
      ui.Path { anchors = { fill = true }, d = function() return canvas.draft_path(t) end,
        fill_color = "transparent", stroke_width = 1.5, stroke_color = function() return C.primary end,
        visible = function() return t.gesture == "draw" or t.gesture == "draft" end },
      ui.Path { anchors = { fill = true }, d = function() return canvas.pull_path(t, spec, elbow) end,
        fill_color = "transparent", stroke_width = 1.5, dash = { 5, 4 },
        stroke_color = function() return t.connect_to ~= "" and C.primary or stroke(C, "focus") end,
        visible = function() return t.gesture == "connect" end } }
    local control = require("lib.kit.control")
    slots.wires = function(points, s)
      local function lit()
        local w = s.wire()
        local a = spec.port and (spec.port(w.from) or {}).item
        local b = spec.port and (spec.port(w.to) or {}).item
        return control.has(t.selection, a) or control.has(t.selection, b)
      end
      return ui.Path {
        width = function() local x0, _, x1 = points() return x0 and math.max(x0, x1) + 80 or 1 end,
        height = function() local _, y0, _, y1 = points() return y0 and math.max(y0, y1) + 80 or 1 end,
        fill_color = "transparent", stroke_join = "miter",
        d = function()
          local x0, y0, x1, y1 = points()
          if not x0 then return "M0 0" end
          return elbow(x0, y0, x1, y1)
        end,
        stroke_color = function() return lit() and C.primary or stroke(C, "hover") end,
        stroke_width = function() return (lit() and 2 or 1.5) / math.max(0.0001, s.zoom()) end }
    end
  end)
  for _, name in ipairs { "diagram", "timeline_track", "drawing_board" } do
    restyle(name, function(slots) slots.selection = chosen(name == "drawing_board" and -3 or -5) end)
  end
  restyle("chart_inspector", function(slots, t, spec)
    -- The brushed span: hatched, between two upright rules.
    local function band()
      local x, _, w = canvas.band_box(t)
      return x, 0, w, t.height or 0
    end
    slots.band = ui.Item { anchors = { fill = true },
      visible = function() return t.band ~= nil and t.band ~= "" and t.gesture ~= "none" end,
      hatched(t, band, function() return C.primary:alpha(0.3) end),
      ui.Rect { width = 1, height = function() return t.height or 0 end, x = function() return (band()) end,
        color = function() return C.primary end },
      ui.Rect { width = 1, height = function() return t.height or 0 end,
        x = function() local x, _, w = band() return x + w end, color = function() return C.primary end } }
  end)
end
