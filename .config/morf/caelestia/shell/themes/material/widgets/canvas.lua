-- Material's looks for the Canvas archetype and each of its widgets. The
-- layouts are the kit's (the default look's canvas_dock.lua and
-- widgets/canvas.lua: a node's header and ports, a map's corners, a
-- timeline's ruler), drawn here in Material's roles -- the canvas ground
-- on surfaceContainerLow, the grid in outlineVariant, cards on the
-- surface containers, the primary for what is chosen -- at Material's
-- roundings and on its springs; what Material draws its own way is
-- given after: a selection outline that springs in past its size and
-- settles, port dots that morph from a circle to a rounded square under
-- the pointer, tonal buttons over a map or an image, a tooltip readout.
local morf = require("morf")
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local shadow = morf.color("#000000")
  local canvas = require("lib.kit.canvas")

  --- The kit's palette names in Material's roles.
  local function P()
    local c = C()
    local dark = not c.surface:is_light()
    return {
      view = c.surfaceContainerLow, window = c.surface, card = c.surfaceContainerHigh,
      raised = c.surfaceContainerHighest, sidebar = c.surfaceContainer, header = c.surfaceContainer,
      ink = c.onSurface, ink_dim = c.onSurfaceVariant, border = c.outlineVariant, shade = shadow,
      accent = c.primary, accent_ink = c.primary, on_accent = c.onPrimary, track = c.surfaceContainerHighest,
      paper = dark and c.onSurface or c.surfaceContainerLowest,
      info = c.secondary, extra = c.tertiary, error = c.error, destructive = c.error,
      success = c.tertiary:mix(c.secondary, 0.5), warning = c.tertiary:mix(c.error, 0.45),
      wash = { hover = 0.08, selected = 0.12, active = 0.12, button = 0.08, checked = 0.16, raised_hover = 0.1 },
      strong = false, dark = dark,
      -- A tone's soft fill is its container, with the container's ink.
      fills = { accent = c.primaryContainer, info = c.secondaryContainer, extra = c.tertiaryContainer,
        error = c.errorContainer, success = c.secondaryContainer:mix(c.tertiaryContainer, 0.5),
        warning = c.tertiaryContainer:mix(c.errorContainer, 0.5) },
      on_fills = { accent = c.onPrimaryContainer, info = c.onSecondaryContainer, extra = c.onTertiaryContainer,
        error = c.onErrorContainer, success = c.onSecondaryContainer, warning = c.onTertiaryContainer },
    }
  end
  M.canvas_palette = P
  local look = {
    P = P, radius = { small = 8, medium = 12, large = 16, window = 28 },
    size = theme.size, duration = theme.duration, ease = theme.ease, reduced = theme.reduced,
  }
  -- The kit's layouts draw through a view of this theme's components, so
  -- what they add (the item and wire builders) stays out of it.
  local K = setmetatable({}, { __index = M })

  -- Over a map or an image: a tonal button, a rounded square that rounds
  -- fully under the pointer and tightens pressed.
  function K.canvas_osd(icon, name, action, props)
    props = props or {}
    local area
    props.width, props.height = props.width or 40, props.height or 40
    props.cursor, props.accessible_role, props.accessible_name = "pointer", "button", name
    props.on_clicked = action
    area = ui.MouseArea(props)
    ui.reparent(ui.Rect { anchors = { fill = true },
      radius = function() return area.pressed and 8 or (area.hovered and 20 or 12) end,
      color = function()
        local c = C()
        local base = c.surfaceContainerHigh
        if area.pressed then return base:mix(c.onSurface, 0.12) end
        return area.hovered and base:mix(c.onSurface, 0.08) or base
      end,
      behavior = { radius = M.spring(520, 22), color = { duration = theme.duration.small } } }, area)
    ui.reparent(M.icon(icon, 22, function() return C().onSurfaceVariant end, { anchors = { center_in = true } }), area)
    return area
  end
  function K.canvas_osd_label(text)
    return ui.Rect { width = 72, height = 40, radius = 20, color = function() return C().surfaceContainerHigh end,
      M.text { anchors = { fill = true }, text = text, font_size = theme.size.small, font_weight = 600,
        color = function() return C().onSurfaceVariant end, horizontal_alignment = "center", vertical_alignment = "center" } }
  end

  -- A port under the pointer (or wired from) morphs to a rounded square.
  function K.canvas_port_round(hot, r) return hot and r * 0.45 or r end

  require("lib.kit.skins.default.canvas_dock")(S, look, K)
  require("lib.kit.skins.default.widgets.canvas")(S, look, K)
  -- (For the dock looks, widgets/dock.lua.)
  M.canvas_look, M.canvas_kit = look, K

  -- ------------------------------------------------------------ Material --

  -- The outline round what is chosen: 3 px of the primary that springs in
  -- from past its size and settles, rounder than the card it holds.
  local function chosen(radius, margin)
    return function(s)
      local shape = s.item().shape or "rect"
      local round = shape == "ellipse" or shape == "circle"
      local m = shape == "point" and -13 or (margin or -5)
      return ui.Rect { anchors = { fill = true, margins = m }, color = "transparent",
        radius = function()
          local it = s.item()
          if shape == "point" then return 13 end
          if round then return math.min(it.w or 0, it.h or 0) * s.zoom() / 2 - m end
          return radius - m
        end,
        border_width = 3, border_color = function() return C().primary end,
        scale = 1, opacity = 1, enter = { scale = 1.14, opacity = 0 },
        behavior = { scale = M.spring(420, 16), opacity = { duration = theme.duration.small } } }
    end
  end

  -- Wraps a widget's look: `change(slots, t, spec, send)` restyles what
  -- the layout gave.
  local function restyle(name, change) require("lib.kit.canvas").restyle(S, name, change) end

  restyle("Canvas", function(slots, t)
    -- An M3 handle: a primary dot ringed in the surface, growing while held.
    slots.grip = function(s)
      return ui.Rect { x = -6, y = -6, width = 12, height = 12, radius = 6,
        color = function() return C().primary end, border_width = 2,
        border_color = function() return C().surface end,
        scale = function() return s.held() and 1.5 or (s.hovered() and 1.3 or 1) end,
        behavior = { scale = M.spring(520, 22) } }
    end
    slots.selection = chosen(12)
    -- The band: a rounded tonal plate.
    if slots.band then
      slots.band.radius = 12
      slots.band.border_width = 2
      slots.band.color = function() return C().primary:alpha(0.12) end
    end
    -- The zoom: a tonal pill with the reading in the label tone.
    if slots.overlay then
      slots.overlay.color = function() return C().surfaceContainerHighest end
      slots.overlay.border_width = 0
    end
  end)

  restyle("node_graph", function(slots, t, spec)
    slots.selection = chosen(16)
  end)
  restyle("timeline_track", function(slots)
    slots.selection = chosen(8, -4)
  end)
  restyle("diagram", function(slots)
    slots.selection = chosen(8)
  end)
  restyle("chart_inspector", function(slots, t, spec)
    -- The readout as a plain tooltip: inverse surface, inverse ink.
    local function label()
      local v = canvas.value_at(spec.series or {}, t.pointer_x or 0)
      if not v then return "" end
      if spec.readout then return spec.readout(t.pointer_x, v) end
      return ("%.1f"):format(v)
    end
    local function px() return (t.pointer_x - t.view_x) * t.zoom_x end
    local function H() return t.height or 0 end
    local lo, hi = spec.value_from or 0, spec.value_to or 100
    local function sy(v) return H() - (v - lo) / math.max(1e-9, hi - lo) * H() end
    local function w() return 28 + utf8.len(label()) * 8 end
    slots.crosshair = ui.Item { anchors = { fill = true },
      visible = function() return t.pointer_inside and label() ~= "" end,
      ui.Rect { width = 2, radius = 1, height = H, x = function() return px() - 1 end,
        color = function() return C().outline end },
      ui.Rect { width = 14, height = 14, radius = 7, border_width = 3,
        x = function() return px() - 7 end,
        y = function() return sy(canvas.value_at(spec.series or {}, t.pointer_x or 0) or 0) - 7 end,
        color = function() return C().primary end, border_color = function() return C().surfaceContainerLow end },
      ui.Rect { height = 32, radius = 8, y = 8, width = w,
        x = function()
          local x = px() + 12
          if x + w() > (t.width or 0) - 6 then x = px() - 12 - w() end
          return x
        end,
        color = function() return C().inverseSurface end,
        M.text { anchors = { fill = true }, text = label, font_size = theme.size.small, font_weight = 600,
          horizontal_alignment = "center", vertical_alignment = "center", color = function() return C().inverseOnSurface end } } }
  end)
end
