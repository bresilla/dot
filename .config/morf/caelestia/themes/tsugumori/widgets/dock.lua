-- Tsugumori's looks for the Dock archetype and each of its widgets. The
-- layouts are the kit's (the default look's canvas_dock.lua and
-- widgets/dock.lua), drawn square in the wallpaper's roles: stacks framed
-- by the primary's quiet stroke, tabs as mono capitals whose chosen one
-- wears a primary bar along its top and brackets while its stack has
-- focus, dividers as three studs that part under the pointer, and where
-- a dragged tab would land a hatched, framed, bracketed plate that slides
-- to each zone.
local ui = require("morf.ui")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local look, K = M.canvas_look, M.canvas_kit
  require("lib.kit.skins.default.widgets.dock")(S, look, K)
  local quick = { duration = 140, easing = "out_cubic" }
  local slide = { duration = 200, easing = "out_cubic" }

  local function restyle(name, change) require("lib.kit.canvas").restyle(S, name, change) end

  --- A tab: its title in mono capitals, the chosen one on the container
  --- tone with a primary bar along its top that runs out from the left,
  --- brackets on it while its stack has focus; a hatch-free square close.
  local function tab(s, opts)
    opts = opts or {}
    local close_area
    local node = ui.Rect { anchors = { fill = true, right_margin = 1 },
      color = function()
        if s.current() then return C.surfaceContainer end
        return s.hovered() and C.primary:mix(C.surfaceContainerLow, 0.94) or C.surfaceContainerLow
      end, behavior = { color = quick } }
    local row = ui.Row { anchors = { fill = true, left_margin = 10, right_margin = 6 }, gap = 6, align = "center" }
    if s.icon then
      ui.reparent(M.icon(s.icon, 15, function() return s.current() and C.primary or C.onSurfaceVariant end), row)
    end
    ui.reparent(M.text { text = tostring(s.title):upper(), font_size = theme.typography.label + 1,
      letter_spacing = 0.6, elide = "right",
      color = function() return s.current() and C.onSurface or C.onSurfaceVariant end,
      width = function() return math.max(20, (node.layout_width or 100) - (s.icon and 62 or 40)) end,
      visible = function() return not s.icon or (node.layout_width or 0) >= 104 end }, row)
    ui.reparent(row, node)
    if s.closable then
      close_area = ui.MouseArea { anchors = { right = true, vertical_center = true, right_margin = 4 },
        width = 20, height = 20, cursor = "pointer", accessible_role = "button", accessible_name = "Close " .. s.title,
        visible = function() return (s.current() or s.hovered()) and (node.layout_width or 0) >= 76 end,
        on_clicked = function() s.close() end,
        ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
          border_color = function() return close_area and close_area.hovered and stroke(C, "focus") or stroke(C, "quiet") end },
        M.icon("close", 13, function() return C.onSurfaceVariant end, { anchors = { center_in = true } }) }
      ui.reparent(close_area, node)
    end
    ui.reparent(ui.Rect { anchors = { left = true, top = true }, height = 2, color = function() return C.primary end,
      width = function() return node.layout_width or 0 end, enter = { width = 0 }, behavior = { width = slide },
      visible = function() return s.current() end }, node)
    ui.reparent(hud().corners { length = 5, weight = 1, color = function() return C.primary end,
      visible = function() return s.current() and s.focused() end }, node)
    return node
  end

  restyle("Dock", function(slots, t, spec)
    local TAB = spec.tab_height or 34
    slots.background = ui.Rect { anchors = { fill = true }, color = function() return C.surface end }
    slots.tab = function(s) return tab(s) end
    slots.stack = function(s)
      return ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { left = true, right = true, top = true }, height = TAB, color = function() return C.surfaceContainerLow end },
        ui.Rect { anchors = { fill = true, top_margin = TAB }, color = function() return C.surface end },
        ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
          border_color = function() return s.focused() and stroke(C, "hover") or stroke(C, "idle") end,
          behavior = { border_color = quick } },
        ui.Rect { y = TAB - 1, height = 1, anchors = { left = true, right = true }, color = function() return stroke(C, "idle") end } }
    end
    -- Three studs across a divider, parting under the pointer.
    slots.divider = function(s)
      local vertical = s.orientation == "vertical"
      local function on() return s.hovered() or s.dragging() end
      local holder = ui.Item { anchors = { fill = true } }
      for i = -1, 1 do
        local function at() return i * (on() and 10 or 6) end
        ui.reparent(ui.Rect { width = 4, height = 4, anchors = { center_in = true },
          translate_x = function() return vertical and at() or 0 end,
          translate_y = function() return vertical and 0 or at() end,
          color = function() return s.dragging() and C.primary or (on() and C.onSurface or C.outline) end,
          behavior = { translate_x = quick, translate_y = quick } }, holder)
      end
      return holder
    end
    slots.floating = function(s)
      return ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerHigh end, border_width = 1,
          border_color = function() return stroke(C, "focus") end },
        ui.Rect { anchors = { left = true, right = true }, height = TAB, color = function() return C.surfaceContainer end },
        M.text { x = 12, height = TAB, text = tostring(s.title):upper(), font_size = theme.typography.label + 1,
          color = function() return C.onSurface end, vertical_alignment = "center" },
        hud().corners { length = 8, color = function() return C.primary end } }
    end
    -- Where a dragged tab would land: a hatched plate, framed and
    -- bracketed, that slides to each zone.
    local plate = ui.Item {
      x = function() local x = spec.drop_box() return x + 4 end,
      y = function() local _, y = spec.drop_box() return y + 4 end,
      width = function() local _, _, w = spec.drop_box() return math.max(0, w - 8) end,
      height = function() local _, _, _, h = spec.drop_box() return math.max(0, h - 8) end,
      behavior = { x = slide, y = slide, width = slide, height = slide } }
    local W = function() return t.width or 0 end
    local H = function() return t.height or 0 end
    local hatch = ui.Item { anchors = { fill = true }, clip = true,
      ui.Rect { anchors = { fill = true }, color = function() return C.primary:alpha(0.06) end },
      ui.Path { x = function() local x = spec.drop_box() return -(x + 4) end,
        y = function() local _, y = spec.drop_box() return -(y + 4) end,
        width = W, height = H, fill_color = "transparent", stroke_width = 1.5, stroke_cap = "butt",
        d = function() return require("themes.tsugumori.stripes").hatch_d(math.max(1, W()), math.max(1, H()), 10) end,
        stroke_color = function() return C.primary:alpha(0.3) end } }
    ui.reparent(hatch, plate)
    ui.reparent(ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
      border_color = function() return stroke(C, "focus") end }, plate)
    ui.reparent(hud().corners { length = 10, weight = 2, color = function() return C.primary end }, plate)
    slots.drop_indicator = ui.Item { anchors = { fill = true }, plate }
  end)

  -- The widgets share the dock's look; shelves stand apart, each framed
  -- and bracketed, and tool windows keep their bar on in every stack.
  for _, name in ipairs { "document_tabs", "tabbed_container", "tool_windows" } do
    restyle(name, function(slots)
      slots.tab, slots.stack, slots.background, slots.divider, slots.drop_indicator = nil, nil, nil, nil, nil
    end)
  end
  restyle("shelf_dock", function(slots, t, spec)
    local TAB = spec.tab_height or 34
    slots.tab, slots.background, slots.divider, slots.drop_indicator = nil, nil, nil, nil
    slots.stack = function(s)
      return ui.Item { anchors = { fill = true, margins = 3 },
        ui.Rect { anchors = { left = true, right = true, top = true }, height = TAB, color = function() return C.surfaceContainerLow end },
        ui.Rect { anchors = { fill = true, top_margin = TAB }, color = function() return C.surfaceContainerLowest end },
        ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
          border_color = function() return s.focused() and stroke(C, "hover") or stroke(C, "idle") end },
        hud().corners { length = 8, weight = 2, color = function() return s.focused() and C.primary or stroke(C, "corner") end } }
    end
  end)
end
