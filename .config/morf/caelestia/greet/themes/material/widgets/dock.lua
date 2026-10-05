-- Material's looks for the Dock archetype and each of its widgets. The
-- layouts are the kit's (the default look's canvas_dock.lua and
-- widgets/dock.lua), drawn in Material's roles at its roundings: stacks
-- on surfaceContainerLow under a strip of surfaceContainer, the chosen
-- tab on the secondary container with an indicator that springs out from
-- its middle, dividers that swell into a primary pill under the pointer,
-- and where a dragged tab would land a field of the primary that slides,
-- stretches and changes shape from zone to zone.
local morf = require("morf")
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  -- The palette, the roundings and the view of the components that
  -- widgets/canvas.lua (loaded first) drew the archetype skins through.
  local look, K = M.canvas_look, M.canvas_kit
  require("lib.kit.skins.default.widgets.dock")(S, look, K)

  local function restyle(name, change) require("lib.kit.canvas").restyle(S, name, change) end

  --- A tab as Material's: the chosen one on the secondary container, its
  --- ink the container's, a 3 px primary indicator with round ends that
  --- springs out from the middle (and stretches as it does).
  local function tab(s, opts)
    opts = opts or {}
    local node = K.dock_tab(s, { top = opts.top or 4, radius = opts.radius or 12, underline = false,
      current = opts.current or function() return C().secondaryContainer end })
    if opts.indicator ~= false then
      local function full() return math.max(0, (node.layout_width or 0) - 24) end
      ui.reparent(ui.Rect { anchors = { bottom = true, horizontal_center = true }, height = 3, radius = 1.5,
        width = full, enter = { width = 0 }, behavior = { width = M.spring(300, 18) }, stretch = M.STRETCH,
        color = function() return s.focused() and C().primary or C().outline end,
        visible = function() return s.current() end }, node)
    end
    return node
  end

  -- Where a dragged tab would land: a box of the primary in a distance
  -- field riding a plate that springs (and stretches) to each zone; a
  -- middle drop is a rounder, softer box than an edge.
  local function landing(t, spec, inset)
    inset = inset or 6
    local plate = ui.Item { stretch = M.STRETCH,
      x = function() local x = spec.drop_box() return x + inset end,
      y = function() local _, y = spec.drop_box() return y + inset end,
      width = function() local _, _, w = spec.drop_box() return math.max(0, w - inset * 2) end,
      height = function() local _, _, _, h = spec.drop_box() return math.max(0, h - inset * 2) end,
      behavior = { x = M.spring(300, 22), y = M.spring(300, 22), width = M.spring(300, 22), height = M.spring(300, 22) } }
    local rim = ui.Item { anchors = { fill = true, margins = 3 } }
    ui.reparent(rim, plate)
    local function round() return t.drop_zone == "center" and 28 or 14 end
    local ease = { radius = M.spring(300, 22) }
    return ui.Item { anchors = { fill = true }, plate,
      ui.Sdf { anchors = { fill = true }, fill_color = function() return C().primary:alpha(0.04) end,
        ui.SdfShape { shape = "box", radius = round, track = plate, behavior = ease } },
      ui.Sdf { anchors = { fill = true }, fill_color = function() return C().primary end,
        ui.SdfShape { shape = "box", radius = round, track = plate, behavior = ease },
        ui.SdfShape { shape = "box", radius = function() return round() - 3 end, track = rim, operation = "subtract",
          behavior = { radius = M.spring(300, 22) } } } }
  end

  restyle("Dock", function(slots, t, spec)
    slots.background = ui.Rect { anchors = { fill = true }, color = function() return C().surface end }
    slots.tab = function(s) return tab(s) end
    -- A divider: a hairline that swells into a primary pill under the
    -- pointer.
    slots.divider = function(s)
      local vertical = s.orientation == "vertical"
      local function on() return s.hovered() or s.dragging() end
      return ui.Item { anchors = { fill = true },
        ui.Rect { anchors = vertical and { left = true, right = true, vertical_center = true }
            or { top = true, bottom = true, horizontal_center = true },
          width = 1, height = 1, color = function() return C().outlineVariant end },
        ui.Rect { anchors = { center_in = true }, radius = 3,
          width = function() return vertical and (on() and 56 or 0) or (on() and 6 or 0) end,
          height = function() return vertical and (on() and 6 or 0) or (on() and 56 or 0) end,
          color = function() return s.dragging() and C().primary or C().outline end,
          behavior = { width = M.spring(520, 22), height = M.spring(520, 22) } } }
    end
    slots.drop_indicator = landing(t, spec)
  end)

  restyle("document_tabs", function(slots)
    slots.tab = function(s)
      return tab(s, { radius = 16, indicator = false, current = function() return C().secondaryContainer end })
    end
  end)
  restyle("tool_windows", function(slots)
    slots.tab = function(s)
      return tab(s, { top = 0, radius = 0, current = function() return C().onSurface:alpha(0) end })
    end
  end)
  restyle("tabbed_container", function(slots)
    slots.tab = function(s)
      return tab(s, { top = 0, radius = 0, current = function() return C().onSurface:alpha(0) end })
    end
  end)
  restyle("shelf_dock", function(slots, t, spec)
    slots.tab = function(s)
      return tab(s, { top = 5, radius = 14, indicator = false, current = function() return C().secondaryContainer end })
    end
    slots.drop_indicator = landing(t, spec, 8)
  end)
end
