-- Tsugumori's looks for each Sheet widget: square and technical -- a
-- spreadsheet of quiet primary hairlines under caps header strips on a
-- primary rule, its range a primary plate with a square fill block at the
-- corner, the current cell held by L-brackets on a thin frame; a data grid
-- of faint primary stripes; a step sequencer of square pads lit in the
-- primary, the playing column a band of light with a scan line over it;
-- a seat map of seats framed (free), hatched (taken) and filled (chosen);
-- a plain cell grid. The brackets spring between cells and the plate
-- stretches. The layouts are the default kit's and material's; only the
-- style differs.
local ui = require("morf.ui")
local stripes = require("themes.tsugumori.stripes")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local SZ = theme.size
  local TY = theme.typography or {}
  local MENU = math.max(13, TY.menu or 13)
  local function get(v) if type(v) == "function" then return v() end return v end
  local quick = { duration = 140, easing = "out_cubic" }
  local glide = { duration = 220, easing = "out_expo" }

  local function caps(props)
    props.font_size = props.font_size or MENU
    props.font_weight = props.font_weight or 500
    props.letter_spacing = props.letter_spacing or 0.4
    local text = props.text
    props.text = function() return tostring(get(text) or ""):upper() end
    return M.text(props)
  end

  -- (Numbers sit to the right, as a spreadsheet's do.)
  local function numeric(v) return type(v) == "number" or (type(v) == "string" and v:match("^%-?[%d%.,]+$") ~= nil) end

  -- -------------------------------------------------------------- parts --

  local function text_cell(o)
    return function(t, spec)
      return function(s)
        return ui.Item { anchors = { fill = true },
          o.zebra and ui.Rect { anchors = { fill = true },
            color = function() return C.primary:alpha(s.row() % 2 == 0 and 0.035 or 0) end } or nil,
          o.right ~= false and ui.Rect { anchors = { right = true, top = true, bottom = true }, width = 1,
            color = function() return stroke(C, "quiet") end } or nil,
          ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
            color = function() return stroke(C, "quiet") end },
          M.text { anchors = { fill = true, left_margin = o.pad or 8, right_margin = o.pad or 8 },
            vertical_alignment = "center", elide = "right", font_size = SZ.small,
            font_family = theme.mono, horizontal_alignment = o.center and "center" or function() return numeric(s.value()) and "right" or "left" end,
            text = function() return s.text() end,
            color = function() return s.disabled() and C.onSurfaceVariant or C.onSurface end } }
      end
    end
  end

  local function header(o)
    o = o or {}
    return function(t, spec)
      return function(h)
        local row = h.kind == "row"
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainer end },
          ui.Rect { anchors = { fill = true }, color = function() return C.primary:alpha(h.selected() and 0.12 or 0) end,
            behavior = { color = quick } },
          ui.Rect { anchors = { right = true, top = true, bottom = true }, width = 1,
            color = function() return row and C.primary:alpha(0.5) or stroke(C, "quiet") end },
          ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
            color = function() return row and stroke(C, "quiet") or C.primary:alpha(0.5) end },
          -- The current column's or row's block on the rule.
          h.kind ~= "corner" and ui.Rect {
            anchors = row and { right = true, top = true, bottom = true } or { left = true, right = true, bottom = true },
            width = row and 3 or nil, height = row and nil or 3,
            color = function() return C.primary end, opacity = function() return h.current() and 1 or 0 end,
            behavior = { opacity = quick } } or nil,
          caps { anchors = { fill = true, left_margin = o.left and 12 or 4, right_margin = 4 },
            vertical_alignment = "center", horizontal_alignment = (o.left and not row) and "left" or "center",
            elide = "right", text = function() return h.title() end, font_weight = o.bold and 600 or 500,
            color = function() return (h.current() or h.selected()) and C.primary or C.onSurfaceVariant end } }
      end
    end
  end

  --- The current cell: a thin frame with L-brackets at its corners.
  local function ring(o)
    return function(t, spec)
      local function box(i) return function() return select(i, spec.cursor_box(t)) end end
      local inset = o.inset or 0
      return ui.Item { x = function() return box(1)() + inset end, y = function() return box(2)() + inset end,
        width = function() return box(3)() - 2 * inset end, height = function() return box(4)() - 2 * inset end,
        opacity = function() return (t.focused or t.visual_focus) and 1 or 0.55 end,
        visible = function() return not t.editing end,
        behavior = { x = glide, y = glide, width = glide, height = glide, opacity = quick },
        ui.Rect { anchors = { fill = true }, color = "transparent", border_width = o.width or 1,
          border_color = function() return C.primary:alpha(0.8) end },
        hud().corners { length = o.length or 6, weight = 2, inset = -2, color = function() return C.primary end } }
    end
  end

  local function plate(o)
    return function(t, spec)
      local function box(i) return function() return select(i, spec.range_box(t)) end end
      local function many() local r0, c0, r1, c1 = tostring(t.range or ""):match("(%d+),(%d+),(%d+),(%d+)")
        return r0 ~= nil and (r0 ~= r1 or c0 ~= c1) end
      return ui.Item { x = box(1), y = box(2), width = box(3), height = box(4),
        behavior = { x = glide, y = glide, width = glide, height = glide },
        ui.Rect { anchors = { fill = true }, color = function() return C.primary:alpha(0.1) end,
          border_width = o.border or 1, border_color = function() return C.primary:alpha(0.7) end,
          opacity = function() return many() and 1 or 0 end, behavior = { opacity = quick } },
        o.handle and ui.Rect { anchors = { right = true, bottom = true, right_margin = -3, bottom_margin = -3 },
          width = 7, height = 7, color = function() return C.primary end,
          visible = function() return not t.editing end } or nil }
    end
  end

  local function editor(o)
    return function(t, spec)
      return function(props)
        props.font_size = SZ.small
        props.font_family = theme.mono
        props.color = function() return C.onSurface end
        props.selection_color = function() return C.primary:alpha(0.3) end
        props.caret_color = function() return C.primary end
        props.vertical_alignment = "center"
        props.anchors = { fill = true, left_margin = 8, right_margin = 6 }
        local input = ui.TextInput(props)
        local node = ui.Rect { anchors = { fill = true, margins = -1 },
          color = function() return C.surfaceContainerHigh end, border_width = 1,
          border_color = function() return C.primary end,
          ui.Rect { anchors = { left = true, top = true, bottom = true }, width = 3, color = function() return C.primary end },
          input }
        return node, input
      end
    end
  end

  local function ground(role)
    return function(t, spec)
      return ui.Rect { anchors = { fill = true }, color = function() return C[role] end, border_width = 1,
        border_color = function() return stroke(C, "idle") end }
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
    range = plate { handle = true },
    cursor = ring { width = 2, length = 7, inset = 0 },
    editor = editor {},
  }

  S.data_grid = {
    background = ground("surfaceContainerLow"),
    cell = text_cell { zebra = true, right = false, pad = 12 },
    header = header { left = true, bold = true },
    range = plate { border = 0 },
    cursor = ring { width = 1, inset = 1 },
    editor = editor {},
  }

  S.cell_grid = {
    background = ground("surfaceContainerLow"),
    cell = text_cell { center = true },
    range = plate {},
    cursor = ring { width = 1, inset = 1 },
    editor = editor {},
  }

  S.step_sequencer = {
    background = function() return ui.Item { anchors = { fill = true },
      ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerLow end },
      hud().corners { length = 8, weight = 2, color = function() return C.primary:alpha(0.6) end } } end,
    cell = function(t, spec)
      return function(s)
        local down_beat = (s.column - 1) % 8 < 4
        local function on() return s.value() and s.value() ~= 0 and s.value() ~= "" end
        return ui.Rect { anchors = { fill = true, margins = 3 },
          color = function()
            if on() then return C.primary end
            return C.primary:alpha(down_beat and 0.1 or 0.05)
          end,
          border_width = function() return on() and 0 or 1 end,
          border_color = function() return stroke(C, "quiet") end,
          behavior = { color = quick },
          ui.Rect { anchors = { fill = true }, color = function() return C.onPrimary:alpha(0.35) end,
            opacity = function() return (on() and s.playing()) and 1 or 0 end, behavior = { opacity = { duration = 90 } } } }
      end
    end,
    header = function(t, spec)
      return function(h)
        if h.kind == "corner" then return nil end
        if h.kind == "row" then
          return caps { anchors = { fill = true, left_margin = 12, right_margin = 6 }, vertical_alignment = "center",
            elide = "right", text = function() return h.title() end,
            color = function() return h.current() and C.primary or C.onSurfaceVariant end }
        end
        local beat = (h.index() - 1) % 4 == 0
        return ui.Item { anchors = { fill = true },
          beat and M.text { anchors = { fill = true }, horizontal_alignment = "center", vertical_alignment = "center",
            text = function() return ("%02d"):format(h.index()) end, font_size = MENU, font_family = theme.mono,
            color = function() return (h.playing() or h.current()) and C.primary or C.onSurfaceVariant end } or nil,
          not beat and ui.Rect { anchors = { center_in = true }, width = 1, height = 8,
            color = function() return h.playing() and C.primary or stroke(C, "idle") end } or nil }
      end
    end,
    cursor = function(t, spec)
      local function box(i) return function() return select(i, spec.cursor_box(t)) end end
      local function col(i) return function() return select(i, spec.column_box(spec.playhead_column())) end end
      return ui.Item {
        -- The playhead: a band of light with a scan line at its top.
        ui.Item { x = col(1), y = 0, width = col(3), height = col(4), z = -1,
          visible = function() return spec.playhead_column() > 0 end,
          behavior = { x = { duration = 90, easing = "out_cubic" } },
          ui.Rect { anchors = { fill = true }, color = function() return C.primary:alpha(0.12) end },
          ui.Rect { anchors = { left = true, right = true, top = true }, height = 2, color = function() return C.primary end } },
        ui.Item { x = box(1), y = box(2), width = box(3), height = box(4),
          opacity = function() return t.focused and 1 or 0 end,
          behavior = { x = glide, y = glide, opacity = quick },
          hud().corners { length = 6, weight = 2, color = function() return C.primary end } } }
    end,
  }

  S.seat_map = {
    background = function() return ui.Item { anchors = { fill = true },
      ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerLow end },
      hud().corners { length = 8, weight = 2, color = function() return C.primary:alpha(0.6) end } } end,
    cell = function(t, spec)
      return function(s)
        local function chosen() local v = s.value() return v and v ~= 0 and v ~= "" end
        local side = math.floor(math.min(s.width, s.height)) - 6
        return ui.Rect { anchors = { fill = true, margins = 3 }, clip = true,
          color = function() return chosen() and C.primary or C.primary:alpha(0) end,
          border_width = function() return chosen() and 0 or 1 end,
          border_color = function() return s.disabled() and stroke(C, "quiet") or stroke(C, "hover") end,
          behavior = { color = quick },
          -- A taken seat is hatched over.
          stripes.box { width = side, height = side, gap = 5, weight = 1.5,
            color = function() return C.primary:alpha(0.28) end, opacity = function() return s.disabled() and 1 or 0 end },
          M.icon("event_seat", math.floor(math.min(s.width, s.height) * 0.62), function()
            if s.disabled() then return C.onSurfaceVariant:alpha(0.35) end
            if chosen() then return C.onPrimary end
            return C.onSurfaceVariant
          end, { anchors = { center_in = true } }) }
      end
    end,
    header = function(t, spec)
      return function(h)
        if h.kind == "corner" then return nil end
        return M.text { anchors = { fill = true }, horizontal_alignment = "center", vertical_alignment = "center",
          text = function() return h.title() end, font_size = MENU, font_family = theme.mono,
          color = function() return h.current() and C.primary or C.onSurfaceVariant end }
      end
    end,
    cursor = ring { width = 1, inset = 0, length = 5 },
  }
end
