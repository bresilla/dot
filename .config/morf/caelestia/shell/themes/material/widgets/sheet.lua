-- Material's looks for each Sheet widget: a spreadsheet of outline-variant
-- grid lines under tonal header strips, its range a primary plate with a
-- round fill handle and a primary ring on the current cell; a data grid of
-- tonal stripes under a header whose current column carries a primary
-- line; a step sequencer of rounded pads lit in the primary on tonal
-- containers, the playing column glowing; a seat map of seats free
-- (outlined), taken (the disabled container) and chosen (primary); a plain
-- cell grid. The ring springs between cells and the plate stretches. The
-- layouts are the default kit's and tsugumori's; only the style differs.
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local SZ = theme.size
  local function quick() return { duration = theme.duration.small } end

  -- (Numbers sit to the right, as a spreadsheet's do.)
  local function numeric(v) return type(v) == "number" or (type(v) == "string" and v:match("^%-?[%d%.,]+$") ~= nil) end

  -- -------------------------------------------------------------- parts --

  local function text_cell(o)
    return function(t, spec)
      return function(s)
        return ui.Item { anchors = { fill = true },
          o.zebra and ui.Rect { anchors = { fill = true },
            color = function() return C().onSurface:alpha(s.row() % 2 == 0 and 0.035 or 0) end } or nil,
          o.right ~= false and ui.Rect { anchors = { right = true, top = true, bottom = true }, width = 1,
            color = function() return C().outlineVariant:alpha(0.7) end } or nil,
          ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
            color = function() return C().outlineVariant:alpha(o.zebra and 0.45 or 0.7) end },
          M.text { anchors = { fill = true, left_margin = o.pad or 8, right_margin = o.pad or 8 },
            vertical_alignment = "center", elide = "right", font_size = SZ.normal,
            horizontal_alignment = o.center and "center" or function() return numeric(s.value()) and "right" or "left" end,
            text = function() return s.text() end,
            color = function() local c = C() return s.disabled() and c.onSurfaceVariant or c.onSurface end } }
      end
    end
  end

  local function header(o)
    o = o or {}
    return function(t, spec)
      return function(h)
        local row = h.kind == "row"
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true }, color = function() return C().surfaceContainer end },
          ui.Rect { anchors = { fill = true },
            color = function() return C().secondaryContainer:alpha(h.selected() and 0.9 or 0) end,
            behavior = { color = quick() } },
          ui.Rect { anchors = { right = true, top = true, bottom = true }, width = 1,
            color = function() return C().outlineVariant:alpha(0.7) end },
          ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
            color = function() return C().outlineVariant end },
          h.kind ~= "corner" and ui.Rect {
            anchors = row and { right = true, top = true, bottom = true, top_margin = 6, bottom_margin = 6 }
              or { left = true, right = true, bottom = true, left_margin = 6, right_margin = 6 },
            width = row and 3 or nil, height = row and nil or 3, radius = 1.5,
            color = function() return C().primary end, opacity = function() return h.current() and 1 or 0 end,
            behavior = { opacity = quick() } } or nil,
          M.text { anchors = { fill = true, left_margin = o.left and 10 or 4, right_margin = 4 },
            vertical_alignment = "center", horizontal_alignment = (o.left and not row) and "left" or "center",
            elide = "right", text = function() return h.title() end,
            font_size = SZ.small, font_weight = o.bold and 700 or 600,
            color = function()
              local c = C()
              if h.current() then return c.primary end
              return h.selected() and c.onSecondaryContainer or c.onSurfaceVariant
            end } }
      end
    end
  end

  local function ring(o)
    return function(t, spec)
      local function box(i) return function() return select(i, spec.cursor_box(t)) end end
      local inset = o.inset or 0
      local spring = M.spring(380, 26)
      return ui.Rect { x = function() return box(1)() + inset end, y = function() return box(2)() + inset end,
        width = function() return box(3)() - 2 * inset end, height = function() return box(4)() - 2 * inset end,
        radius = o.radius or 4, color = "transparent", border_width = o.width or 2,
        border_color = function() return C().primary end,
        opacity = function() return (t.focused or t.visual_focus) and 1 or 0.55 end,
        visible = function() return not t.editing end,
        behavior = { x = spring, y = spring, width = spring, height = spring, opacity = quick() } }
    end
  end

  local function plate(o)
    return function(t, spec)
      local function box(i) return function() return select(i, spec.range_box(t)) end end
      local function many() local r0, c0, r1, c1 = tostring(t.range or ""):match("(%d+),(%d+),(%d+),(%d+)")
        return r0 ~= nil and (r0 ~= r1 or c0 ~= c1) end
      local spring = M.spring(340, 26)
      return ui.Item { x = box(1), y = box(2), width = box(3), height = box(4),
        behavior = { x = spring, y = spring, width = spring, height = spring },
        ui.Rect { anchors = { fill = true }, radius = o.radius or 4,
          color = function() return C().primary:alpha(0.12) end,
          border_width = o.border or 1, border_color = function() return C().primary end,
          opacity = function() return many() and 1 or 0 end, behavior = { opacity = quick() } },
        o.handle and ui.Rect { anchors = { right = true, bottom = true, right_margin = -4, bottom_margin = -4 },
          width = 9, height = 9, radius = 4.5, color = function() return C().primary end,
          border_width = 2, border_color = function() return C().surface end,
          visible = function() return not t.editing end } or nil }
    end
  end

  local function editor(o)
    return function(t, spec)
      return function(props)
        props.font_size = SZ.normal
        props.color = function() return C().onSurface end
        props.selection_color = function() return C().primary:alpha(0.3) end
        props.caret_color = function() return C().primary end
        props.vertical_alignment = "center"
        props.anchors = { fill = true, left_margin = 8, right_margin = 6 }
        local input = ui.TextInput(props)
        local node = ui.Rect { anchors = { fill = true, margins = -1 }, radius = o.radius or 4,
          color = function() return C().surfaceContainerHigh end, border_width = 2,
          border_color = function() return C().primary end,
          shadow_color = function() return C().shadow and C().shadow:alpha(0.3) or C().onSurface:alpha(0.2) end,
          shadow_blur = 8, shadow_offset_y = 2, input }
        return node, input
      end
    end
  end

  local function ground(role)
    return function(t, spec)
      return ui.Rect { anchors = { fill = true }, color = function() return C()[role] end, border_width = 1,
        border_color = function() return C().outlineVariant end }
    end
  end

  -- -------------------------------------------------------- the widgets --

  S.Sheet = {
    background = ground("surface"),
    cell = text_cell {},
    header = header {},
    range = plate {},
    cursor = ring {},
    editor = editor {},
  }

  S.spreadsheet = {
    cell = text_cell {},
    header = header {},
    range = plate { handle = true, radius = 2 },
    cursor = ring { width = 3, radius = 3, inset = -1 },
    editor = editor { radius = 3 },
  }

  S.data_grid = {
    background = ground("surfaceContainerLow"),
    cell = text_cell { zebra = true, right = false, pad = 12 },
    header = header { left = true, bold = true },
    range = plate { radius = 8, border = 0 },
    cursor = ring { width = 2, radius = 8, inset = 1 },
    editor = editor { radius = 8 },
  }

  S.cell_grid = {
    background = ground("surfaceContainerLow"),
    cell = text_cell { center = true },
    range = plate { radius = 6 },
    cursor = ring { width = 2, radius = 8, inset = 1 },
    editor = editor { radius = 8 },
  }

  S.step_sequencer = {
    background = function() return ui.Rect { anchors = { fill = true }, radius = 16,
      color = function() return C().surfaceContainerLow end } end,
    cell = function(t, spec)
      return function(s)
        local down_beat = (s.column - 1) % 8 < 4
        local function on() return s.value() and s.value() ~= 0 and s.value() ~= "" end
        return ui.Rect { anchors = { fill = true, margins = 3 }, radius = 8,
          color = function()
            local c = C()
            if on() then return c.primary end
            return down_beat and c.surfaceContainerHighest or c.surfaceContainerHigh
          end,
          behavior = { color = quick() },
          ui.Rect { anchors = { fill = true }, radius = 8, color = function() return C().onPrimary:alpha(0.3) end,
            opacity = function() return (on() and s.playing()) and 1 or 0 end, behavior = { opacity = { duration = 90 } } } }
      end
    end,
    header = function(t, spec)
      return function(h)
        if h.kind == "corner" then return nil end
        if h.kind == "row" then
          return M.text { anchors = { fill = true, left_margin = 12, right_margin = 6 }, vertical_alignment = "center",
            elide = "right", text = function() return h.title() end, font_size = SZ.small, font_weight = 600,
            color = function() local c = C() return h.current() and c.primary or c.onSurfaceVariant end }
        end
        local beat = (h.index() - 1) % 4 == 0
        return ui.Item { anchors = { fill = true },
          beat and M.text { anchors = { fill = true }, horizontal_alignment = "center", vertical_alignment = "center",
            text = function() return h.title() end, font_size = SZ.small, font_weight = 600,
            color = function() local c = C() return (h.playing() or h.current()) and c.primary or c.onSurfaceVariant end } or nil,
          not beat and ui.Rect { anchors = { center_in = true }, width = 4, height = 4, radius = 2,
            color = function() local c = C() return h.playing() and c.primary or c.outline end } or nil }
      end
    end,
    cursor = function(t, spec)
      local spring = M.spring(380, 26)
      local function box(i) return function() return select(i, spec.cursor_box(t)) end end
      local function col(i) return function() return select(i, spec.column_box(spec.playhead_column())) end end
      return ui.Item {
        ui.Rect { x = col(1), y = 0, width = col(3), height = col(4), radius = 11, z = -1,
          color = function() return C().primary:alpha(0.14) end,
          visible = function() return spec.playhead_column() > 0 end,
          behavior = { x = { duration = 90, easing = "out_cubic" } } },
        ui.Rect { x = function() return box(1)() + 1 end, y = function() return box(2)() + 1 end,
          width = function() return box(3)() - 2 end, height = function() return box(4)() - 2 end,
          radius = 10, color = "transparent", border_width = 2,
          border_color = function() return C().primary end,
          opacity = function() return t.focused and 1 or 0 end,
          behavior = { x = spring, y = spring, opacity = quick() } } }
    end,
  }

  S.seat_map = {
    background = function() return ui.Rect { anchors = { fill = true }, radius = 16,
      color = function() return C().surfaceContainerLow end } end,
    cell = function(t, spec)
      return function(s)
        local function chosen() local v = s.value() return v and v ~= 0 and v ~= "" end
        return ui.Rect { anchors = { fill = true, margins = 3 }, radius = 8,
          color = function()
            local c = C()
            if s.disabled() then return c.onSurface:alpha(0.1) end
            if chosen() then return c.primary end
            return c.surface:alpha(0)
          end,
          border_width = function() return (s.disabled() or chosen()) and 0 or 1 end,
          border_color = function() return C().outlineVariant end,
          behavior = { color = quick() },
          M.icon("event_seat", math.floor(math.min(s.width, s.height) * 0.62), function()
            local c = C()
            if s.disabled() then return c.onSurface:alpha(0.38) end
            if chosen() then return c.onPrimary end
            return c.onSurfaceVariant
          end, { anchors = { center_in = true } }) }
      end
    end,
    header = function(t, spec)
      return function(h)
        if h.kind == "corner" then return nil end
        return M.text { anchors = { fill = true }, horizontal_alignment = "center", vertical_alignment = "center",
          text = function() return h.title() end, font_size = SZ.small, font_weight = 600,
          color = function() local c = C() return h.current() and c.primary or c.onSurfaceVariant end }
      end
    end,
    cursor = ring { width = 2, radius = 11, inset = 0 },
  }
end
