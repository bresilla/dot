-- Tsugumori's looks for each Collection widget: square, technical rows --
-- a hairline under each, the chosen one on a primary plate with a block at
-- its edge and a hatched strip at its far end, brackets where the keyboard
-- is; a boxed list framed with L-brackets; tables with caps headers on a
-- primary rule and a triangle that turns; trees with hairline guides and a
-- turning triangle; a timeline of square stations (a diamond for the
-- current one); framed feed cards, square chat bubbles, bracketed kanban
-- tags and square checks. The layouts are the default kit's and
-- material's; only the style differs.
local morf = require("morf")
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
  local MOTION = {
    enter = { opacity = 0, translate_x = 14, duration = 220, easing = "out_expo" },
    exit = { opacity = 0, translate_x = -28, duration = 160, easing = "in_cubic" },
  }
  local TRIANGLE = "M0 0 L8 5 L0 10 Z"

  local function label_of(r)
    if type(r) == "table" then return tostring(r.label or r.name or r.title or r.text or r.key or "") end
    return tostring(r or "")
  end
  local function field(s, row, key)
    local r = s.row() or row
    return type(r) == "table" and r[key] or nil
  end
  local function chosen(s) return s.selected() or s.current() end
  local function row_tone(s, stripe)
    if chosen(s) then return C.primary:alpha(s.hovered() and 0.18 or 0.13) end
    if s.down() then return C.primary:alpha(0.16) end
    if s.hovered() then return C.primary:alpha(0.06) end
    if stripe and s.index() % 2 == 0 then return C.primary:alpha(0.03) end
    return C.primary:alpha(0)
  end
  local function row_ink(s) return chosen(s) and C.primary or C.onSurface end
  local function caps(props)
    props.font_size = props.font_size or MENU
    props.font_weight = props.font_weight or 500
    props.letter_spacing = props.letter_spacing or 0.4
    local text = props.text
    props.text = function() return tostring(get(text) or ""):upper() end
    return M.text(props)
  end
  -- The keyboard's brackets on the current row.
  local function brackets(t, s)
    return hud().corners { length = 5, weight = 2, color = function() return C.primary end,
      visible = function() return t.visual_focus and s.current() end }
  end
  -- The chosen row's marks: a block at its start, a hatched strip at its end.
  local function chosen_marks(s, strip)
    return ui.Item { anchors = { fill = true }, visible = function() return chosen(s) end,
      ui.Rect { anchors = { left = true, top = true, bottom = true }, width = 3, color = function() return C.primary end },
      strip ~= false and ui.Item { anchors = { right = true, top = true, bottom = true, right_margin = 6, top_margin = 6,
          bottom_margin = 6 }, width = 36, clip = true,
        stripes.box { width = 36, height = 64, gap = 6, weight = 2, color = function() return C.primary:alpha(0.35) end } } or nil }
  end
  local function initial(name) return (tostring(name or "?"):match("[%w]") or "?"):upper() end
  local function show(v)
    if type(v) ~= "number" then return tostring(v == nil and "" or v) end
    if v == math.floor(v) and math.abs(v) < 1e15 then
      local sign, digits = ("%d"):format(v):match("^(-?)(%d+)$")
      digits = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
      return sign .. digits
    end
    return ("%.1f"):format(v)
  end
  local function bytes(n)
    if type(n) ~= "number" then return n and tostring(n) or "" end
    local units, i = { "B", "kB", "MB", "GB", "TB" }, 1
    while n >= 1000 and i < #units do n, i = n / 1000, i + 1 end
    return i == 1 and ("%d %s"):format(n, units[i]) or ("%.1f %s"):format(n, units[i])
  end
  local function date(v)
    if type(v) == "number" then return os.date("%d %b %H:%M", v) end
    return v and tostring(v) or ""
  end
  local EXT = { png = "image", jpg = "image", jpeg = "image", svg = "image", gif = "image", webp = "image",
    mp4 = "movie", mkv = "movie", webm = "movie", mov = "movie", mp3 = "music_note", flac = "music_note",
    ogg = "music_note", wav = "music_note", pdf = "picture_as_pdf", zip = "folder_zip", gz = "folder_zip",
    tar = "folder_zip", xz = "folder_zip", lua = "code", rs = "code", py = "code", js = "code", c = "code",
    h = "code", toml = "code", json = "code", md = "article", txt = "article", odt = "article", doc = "article" }
  local function is_folder(r) return type(r) == "table" and (r.is_dir or r.kind == "folder" or r.type == "folder") end
  local function file_icon(r, open)
    if type(r) == "table" and r.icon then return r.icon end
    if is_folder(r) then return open and "folder_open" or "folder" end
    local ext = label_of(r):match("%.([%w]+)$")
    return ext and EXT[ext:lower()] or "draft"
  end
  local function icon_color(name)
    return function()
      if name == "folder" or name == "folder_open" then return C.primary end
      if name == "picture_as_pdf" or name == "movie" then return C.error end
      return C.onSurfaceVariant
    end
  end
  -- A solid triangle that turns a quarter as its row opens (only when the
  -- same row opens or closes, not when a recycled row is rebound).
  local function turner(s, props)
    local holder = ui.Item { x = props.x, anchors = { vertical_center = true }, width = 12, height = 12,
      visible = props.visible,
      ui.Path { x = 2, y = 1, width = 8, height = 10, view_box = { 0, 0, 8, 10 }, d = TRIANGLE,
        fill_color = function() return s.expanded() and C.primary or C.onSurfaceVariant end } }
    local key, open
    morf.effect("tsugumori.collection.turner." .. tostring(holder), function()
      local r = s.row()
      local k, e = r and r.key, r and r.expanded or false
      local turn = e and 90 or 0
      if k == key and e ~= open then
        morf.animation.play { { node = holder, property = "rotation", to = turn, duration = 220, easing = "out_expo" } }
      else
        holder.rotation = turn
      end
      key, open = k, e
    end, { owner = holder })
    return holder
  end
  local function empty(t, spec)
    if spec.delegate then return nil end
    return ui.Item { anchors = { center_in = true }, width = 160, height = 56,
      visible = function() return (t.count or 0) == 0 end,
      ui.Item { anchors = { fill = true }, clip = true,
        stripes.box { width = 160, height = 56, gap = 8, weight = 1.5, color = function() return C.primary:alpha(0.14) end } },
      hud().corners { length = 7, weight = 1, color = function() return C.primary:alpha(0.6) end },
      caps { anchors = { center_in = true }, text = spec.empty_text or "No entries", color = function() return C.onSurfaceVariant end } }
  end

  -- -------------------------------------------------------------- rows --

  local function item_row(t, spec, o)
    local H = spec.row_height or 36
    local two = H >= 46
    return function(row, s)
      local function r(key) return field(s, row, key) end
      local lead = 14
      local has_icon = function() return r("icon") ~= nil end
      local tx = function() return lead + (o.number and 48 or 0) + (has_icon() and 30 or 0) end
      local right = function() return 14 + (o.chevron and 22 or 0) + ((r("trailing") or r("value")) and 76 or 0) end
      local node = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, color = function() return row_tone(s, o.stripe) end, behavior = { color = quick } },
        chosen_marks(s, not o.number),
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
          color = function() return stroke(C, "quiet") end, visible = function() return s.index() < s.count() end },
        o.number and M.text { x = lead, width = 40, anchors = { vertical_center = true }, horizontal_alignment = "right",
          text = function() return ("%04d"):format(s.index() % 10000) end, font_family = theme.mono, font_size = SZ.small,
          color = function() return C.primary:alpha(0.7) end } or nil,
        M.icon(function() return r("icon") or "" end, 18, function() return chosen(s) and C.primary or C.onSurfaceVariant end,
          { x = lead + (o.number and 48 or 0), anchors = { vertical_center = true }, visible = has_icon }),
        caps { x = tx, y = two and function() return r("subtitle") and (H / 2 - 19) or (H - MENU * 1.3) / 2 end
            or (H - MENU * 1.3) / 2,
          width = function() return math.max(0, s.width() - tx() - right()) end, elide = "right",
          text = function() return label_of(s.row() or row) end, color = function() return row_ink(s) end },
        two and M.text { x = tx, y = H / 2 + 1, visible = function() return r("subtitle") ~= nil end,
          width = function() return math.max(0, s.width() - tx() - right()) end, elide = "right",
          text = function() return tostring(r("subtitle") or "") end, font_size = SZ.small,
          color = function() return C.onSurfaceVariant end } or nil,
        M.text { anchors = { right = true, vertical_center = true, right_margin = 14 + (o.chevron and 22 or 0) },
          text = function() return tostring(r("trailing") or r("value") or "") end, font_family = theme.mono,
          font_size = SZ.small, color = function() return C.onSurfaceVariant end },
        o.chevron and ui.Path { anchors = { right = true, vertical_center = true, right_margin = 14 }, width = 6, height = 10,
          view_box = { 0, 0, 6, 10 }, d = "M0 0 L6 5 L0 10", fill_color = "transparent", stroke_width = 1.5,
          stroke_color = function() return chosen(s) and C.primary or C.onSurfaceVariant end } or nil,
        brackets(t, s),
      }
      return node, function() end
    end
  end

  S.list = { row = function(t, spec) return item_row(t, spec, {}) end, empty = empty }
  S.virtual_list = { row = function(t, spec) return item_row(t, spec, { number = true, stripe = true }) end, empty = empty }
  S.list_box = { row = function(t, spec) return item_row(t, spec, {}) end, empty = empty }

  --- A boxed list: the rows in a hairline frame with L-brackets at its
  --- corners, as tall as its rows.
  S.boxed_list = {
    background = function(t, spec)
      if spec.delegate then return nil end
      local H = spec.row_height or 50
      return ui.Item { width = function() return t.width end,
        height = function() return math.min(t.height or 0, (t.count or 0) * H) end,
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainer end, border_width = 1,
          border_color = function() return stroke(C, "idle") end },
        hud().corners { length = 8, weight = 2, color = function() return C.primary end } }
    end,
    row = function(t, spec) return item_row(t, spec, { chevron = true }) end,
    empty = empty,
  }

  S.grid_view = {
    row = function(t, spec)
      local CW, CH = spec.cell_width or 96, spec.cell_height or 96
      return function(row, s)
        local function r(key) return field(s, row, key) end
        local node = ui.Item { width = CW, height = CH,
          ui.Item { anchors = { fill = true, margins = 4 },
            ui.Rect { anchors = { fill = true }, color = function() return chosen(s) and C.primary:alpha(0.12) or row_tone(s) end,
              border_width = 1, border_color = function() return chosen(s) and C.primary or stroke(C, "idle") end,
              behavior = { color = quick } },
            hud().corners { length = 7, weight = 2, color = function() return C.primary end,
              visible = function() return chosen(s) or s.hovered() end } },
          ui.Item { anchors = { horizontal_center = true }, y = CH * 0.16, width = 40, height = 40,
            scale = function() return s.down() and 0.9 or 1 end, behavior = { scale = quick },
            M.icon(function() return r("icon") or "image" end, 34,
              function() return chosen(s) and C.primary or C.onSurfaceVariant end, { anchors = { center_in = true } }) },
          caps { x = 6, width = CW - 12, y = CH * 0.16 + 46, horizontal_alignment = "center", elide = "right",
            text = function() return label_of(s.row() or row) end, color = function() return row_ink(s) end } }
        return node, function() end
      end
    end,
    empty = empty,
  }

  S.flow_box = {
    row = function(t, spec)
      local CW, CH = spec.cell_width or 128, spec.cell_height or 44
      return function(row, s)
        local function on() return s.selected() or s.current() end
        local node = ui.Item { width = CW, height = CH,
          ui.Rect { anchors = { fill = true, left_margin = 4, right_margin = 4, top_margin = 7, bottom_margin = 7 },
            color = function()
              if on() then return C.primary end
              return C.primary:alpha(s.down() and 0.16 or (s.hovered() and 0.07 or 0))
            end,
            border_width = 1, border_color = function() return on() and C.primary or stroke(C, "hover") end,
            behavior = { color = quick } },
          ui.Rect { x = 14, anchors = { vertical_center = true }, width = 6, height = 6,
            color = function() return on() and C.onPrimary or C.primary:alpha(0.5) end },
          caps { anchors = { vertical_center = true }, x = 28, width = CW - 40, elide = "right",
            text = function() return label_of(s.row() or row) end,
            color = function() return on() and C.onPrimary or C.onSurface end },
          hud().corners { length = 5, weight = 2, color = function() return C.primary end,
            visible = function() return t.visual_focus and s.current() end } }
        return node, function() end
      end
    end,
    empty = empty,
  }

  -- ------------------------------------------------------------ tables --

  local function header(t, spec)
    return function(column)
      local sorted = function() return t.sort_column == column.key end
      local numeric = column.align == "end" or column.key == "size"
      return ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
          color = function() return C.primary:alpha(0.5) end },
        ui.Rect { anchors = { left = true, bottom = true }, height = 3, width = function() return sorted() and 24 or 0 end,
          color = function() return C.primary end, behavior = { width = quick } },
        caps { anchors = { fill = true, left_margin = 12, right_margin = 30 }, vertical_alignment = "center",
          horizontal_alignment = numeric and "right" or "left", text = column.title or column.key, elide = "right",
          color = function() return sorted() and C.primary or C.onSurfaceVariant end },
        ui.Item { anchors = { right = true, right_margin = 10, vertical_center = true }, width = 10, height = 10,
          rotation = function() return t.sort_ascending and -90 or 90 end, opacity = function() return sorted() and 1 or 0 end,
          behavior = { rotation = { duration = 220, easing = "out_expo" }, opacity = quick },
          ui.Path { x = 1, anchors = { fill = true }, view_box = { 0, 0, 8, 10 }, d = TRIANGLE,
            fill_color = function() return C.primary end } } }
    end
  end
  local function cell_text(column, s, row, x, format)
    local numeric = column.align == "end" or column.key == "size"
    return M.text { anchors = { fill = true, left_margin = x or 12, right_margin = numeric and 30 or 12 },
      vertical_alignment = "center", horizontal_alignment = numeric and "right" or "left", elide = "right",
      font_size = SZ.small, font_family = numeric and theme.mono or nil,
      text = function()
        local v = field(s, row, column.key)
        if format then return format(v) end
        return show(v)
      end,
      color = function() return chosen(s) and C.primary or (column.index == 1 and C.onSurface or C.onSurfaceVariant) end }
  end
  local function row_ground(t, s)
    return ui.Item { width = function() return s.width() end, anchors = { top = true, bottom = true },
      ui.Rect { anchors = { fill = true }, color = function() return row_tone(s, true) end, behavior = { color = quick } },
      ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1, color = function() return stroke(C, "quiet") end },
      chosen_marks(s, false),
      brackets(t, s) }
  end
  local function table_cell(t, spec)
    return function(row, column, s)
      if column.index == 1 then
        return ui.Item { anchors = { fill = true }, row_ground(t, s), cell_text(column, s, row, 14) }, function() end
      end
      return cell_text(column, s, row), function() end
    end
  end
  S.data_table = { header = header, cell = table_cell, empty = empty }

  local function file_cell(t, spec)
    return function(row, column, s)
      if column.key == "name" or column.index == 1 then
        return ui.Item { anchors = { fill = true },
          column.index == 1 and row_ground(t, s) or nil,
          M.icon(function() return file_icon(s.row() or row) end, 18,
            function() return icon_color(file_icon(s.row() or row))() end, { x = 14, anchors = { vertical_center = true } }),
          cell_text(column, s, row, 42) }, function() end
      end
      local format = column.key == "size" and function(v)
        if is_folder(s.row() or row) then return field(s, row, "items") and (show(field(s, row, "items")) .. " items") or "" end
        return bytes(v)
      end or (column.key == "modified" and date) or nil
      return cell_text(column, s, row, nil, format), function() end
    end
  end
  S.file_list = { header = header, cell = file_cell, row = function(t, spec)
    return function(row, s)
      local H = spec.row_height or 36
      return ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, color = function() return row_tone(s) end },
        chosen_marks(s),
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1, color = function() return stroke(C, "quiet") end },
        M.icon(function() return file_icon(s.row() or row) end, 18,
          function() return icon_color(file_icon(s.row() or row))() end, { x = 14, anchors = { vertical_center = true } }),
        caps { x = 42, y = (H - MENU * 1.3) / 2, width = function() return s.width() - 54 end, elide = "right",
          text = function() return label_of(s.row() or row) end, color = function() return row_ink(s) end },
        brackets(t, s) }, function() end
    end
  end, empty = empty }

  -- ------------------------------------------------------------- trees --

  local INDENT = 18
  local function tree_parts(t, s, row, x0, width_of)
    local parts = {}
    for level = 1, 8 do
      parts[#parts + 1] = ui.Rect { x = x0 + (level - 1) * INDENT + 6, width = 1,
        anchors = { top = true, bottom = true }, color = function() return stroke(C, "idle") end,
        visible = function() return s.depth() >= level end }
    end
    local function ix() return x0 + s.depth() * INDENT end
    parts[#parts + 1] = turner(s, { x = ix, visible = function() return s.expandable() end })
    parts[#parts + 1] = ui.Item { x = function() return ix() end, anchors = { vertical_center = true },
      width = 16, height = 16, visible = function() return s.loading() end,
      M.loading(16, function() return C.primary end, { active = function() return s.loading() end }) }
    parts[#parts + 1] = M.icon(function()
        local r = s.row() or row
        if type(r) == "table" and r.icon then return r.icon end
        if s.expandable() then return s.expanded() and "folder_open" or "folder" end
        return file_icon(r)
      end, 16,
      function() local r = s.row() or row return icon_color(s.expandable() and "folder" or file_icon(r))() end,
      { x = function() return ix() + 16 end, anchors = { vertical_center = true },
        visible = function() return not s.loading() end })
    parts[#parts + 1] = caps { anchors = { vertical_center = true },
      x = function() return ix() + (s.loading() and 24 or 38) end,
      width = function() return math.max(0, width_of() - ix() - 46) end, elide = "right",
      text = function() return s.loading() and "Loading" or label_of(s.row() or row) end,
      color = function() return s.loading() and C.onSurfaceVariant or row_ink(s) end }
    return parts
  end
  S.tree_view = { row = function(t, spec)
    return function(row, s)
      local node = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, color = function() return row_tone(s) end, behavior = { color = quick } },
        chosen_marks(s) }
      for _, part in ipairs(tree_parts(t, s, row, 8, function() return s.width() end)) do ui.reparent(part, node) end
      ui.reparent(brackets(t, s), node)
      return node, function() end
    end
  end, empty = empty }

  S.tree_table = {
    header = header,
    cell = function(t, spec)
      return function(row, column, s)
        if column.index == 1 then
          local node = ui.Item { anchors = { fill = true }, row_ground(t, s) }
          for _, part in ipairs(tree_parts(t, s, row, 8, function() return column.width or 160 end)) do ui.reparent(part, node) end
          return node, function() end
        end
        return cell_text(column, s, row, nil, column.key == "size" and bytes or nil), function() end
      end
    end,
    empty = empty,
  }

  -- --------------------------------------------------------- timelines --

  local RAIL = 24
  S.timeline = {
    row = function(t, spec)
      local H = spec.row_height or 56
      local cy = 18
      return function(row, s)
        local function r(key) return field(s, row, key) end
        local function on() return chosen(s) end
        local node = ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true }, color = function() return C.primary:alpha(s.hovered() and 0.05 or 0) end },
          ui.Rect { x = RAIL, y = 0, width = 1, height = cy, color = function() return r("done") and C.primary or stroke(C, "hover") end,
            visible = function() return s.index() > 1 end },
          ui.Rect { x = RAIL, y = cy, width = 1, height = H - cy,
            color = function() return r("done") and C.primary or stroke(C, "hover") end,
            visible = function() return s.index() < s.count() end },
          -- The current station: a diamond in a turning frame.
          ui.Rect { x = RAIL - 10, y = cy - 10, width = 21, height = 21, color = "transparent", border_width = 1,
            border_color = function() return C.primary end,
            rotation = function() return on() and 45 or 0 end, scale = function() return on() and 1 or 0.3 end,
            opacity = function() return on() and 1 or 0 end,
            behavior = { rotation = { duration = 320, easing = "out_expo" }, scale = { duration = 260, easing = "out_expo" },
              opacity = quick } },
          ui.Rect { x = RAIL - 4, y = cy - 4, width = 9, height = 9,
            rotation = function() return on() and 45 or 0 end,
            color = function() return (on() or r("done")) and C.primary or C.surface end,
            border_width = 1, border_color = function() return C.primary end,
            behavior = { rotation = { duration = 320, easing = "out_expo" }, color = quick } },
          caps { x = RAIL + 22, y = cy - MENU * 0.7, width = function() return s.width() - RAIL - 110 end,
            elide = "right", text = function() return label_of(s.row() or row) end,
            color = function() return on() and C.primary or C.onSurface end },
          M.text { anchors = { right = true, right_margin = 12 }, y = cy - SZ.small * 0.7, font_family = theme.mono,
            text = function() return tostring(r("time") or "") end, font_size = SZ.small,
            color = function() return on() and C.primary or C.onSurfaceVariant end },
          M.text { x = RAIL + 22, y = cy + 10, width = function() return s.width() - RAIL - 34 end, elide = "right",
            text = function() return tostring(r("detail") or r("subtitle") or "") end, font_size = SZ.small,
            color = function() return C.onSurfaceVariant end },
          brackets(t, s) }
        return node, function() end
      end
    end,
    empty = empty,
  }

  -- -------------------------------------------------------------- feed --

  S.feed = {
    row = function(t, spec)
      local H = spec.row_height or 92
      return function(row, s)
        local function r(key) return field(s, row, key) end
        local function author() return tostring(r("author") or r("from") or "") end
        local node = ui.Item { anchors = { fill = true },
          ui.Item { anchors = { fill = true, left_margin = 2, right_margin = 2, top_margin = 4, bottom_margin = 4 },
            ui.Rect { anchors = { fill = true }, color = function()
                return s.hovered() and C.surfaceContainerHigh or C.surfaceContainer end,
              border_width = 1, border_color = function() return stroke(C, s.hovered() and "hover" or "idle") end,
              behavior = { color = quick } },
            hud().corners { length = 6, weight = 2, color = function() return C.primary end,
              visible = function() return s.hovered() or (t.visual_focus and s.current()) end } },
          ui.Rect { x = 14, y = 16, width = 34, height = 34, color = "transparent", border_width = 1,
            border_color = function() return C.primary end,
            M.text { anchors = { fill = true }, horizontal_alignment = "center", vertical_alignment = "center",
              text = function() return initial(author()) end, font_family = theme.mono, font_size = SZ.normal,
              color = function() return C.primary end } },
          caps { x = 60, y = 14, width = function() return s.width() - 140 end, elide = "right",
            text = author, color = function() return C.onSurface end },
          M.text { anchors = { right = true, right_margin = 14 }, y = 15, text = function() return tostring(r("time") or "") end,
            font_family = theme.mono, font_size = SZ.small, color = function() return C.primary:alpha(0.8) end },
          M.text { x = 60, y = 36, width = function() return s.width() - 76 end, height = H - 46, wrap = true,
            max_lines = 2, text = function() return tostring(r("text") or r("body") or label_of(s.row() or row)) end,
            font_size = SZ.small, color = function() return C.onSurfaceVariant end } }
        return node, function() end
      end
    end,
    empty = empty,
  }

  -- ---------------------------------------------------------- chat log --

  S.chat_log = {
    row = function(t, spec)
      return function(row, s)
        local function r(key) return field(s, row, key) end
        local function mine() local f = r("from") return f == "me" or f == true or r("mine") == true end
        local function text() return tostring(r("text") or label_of(s.row() or row)) end
        -- Wrapped at the characters a line the list's estimate of the
        -- message's height counts on (lib.kit.collection: 7.4 px each over
        -- 72 % of the width), in this face's own advance, so the lines it
        -- reserved are the lines drawn; the bubble is as tall as they are.
        local CHAR = 8.6
        local function per_line() return math.max(8, math.floor((s.width() * 0.72 - 28) / 7.4)) end
        local function bw()
          local longest = 0
          for part in (text() .. "\n"):gmatch("([^\n]*)\n") do longest = math.max(longest, #part) end
          local time = tostring(r("time") or "")
          return math.max(64, #time * 8 + 28, math.ceil(math.min(per_line(), longest) * CHAR) + 28 + 6)
        end
        local function bx() return mine() and (s.width() - bw() - 10) or 10 end
        local body
        local function bh()
          local lines = body and body.layout_height or 0
          return math.min((s.area.height or 48) - 8, math.max(lines, 18) + 9 + 24)
        end
        local function ink() return mine() and C.onPrimary or C.onSurface end
        body = M.text { x = 14, y = 9, width = function() return bw() - 28 end, wrap = true, text = text,
          font_size = SZ.small, color = ink }
        local node = ui.Item { anchors = { fill = true },
          ui.Item { x = bx, y = 4, width = bw, height = bh,
            ui.Rect { anchors = { fill = true }, color = function() return mine() and C.primary or C.surfaceContainer end,
              border_width = function() return mine() and 0 or 1 end, border_color = function() return stroke(C, "hover") end },
            -- The tick toward the sender.
            ui.Rect { width = 6, height = 6, anchors = { bottom = true }, color = function() return C.primary end,
              x = function() return mine() and bw() or -6 end },
            body,
            M.text { anchors = { right = true, bottom = true, right_margin = 12, bottom_margin = 6 },
              text = function() return tostring(r("time") or "") end, font_family = theme.mono, font_size = SZ.small,
              color = function() return get(ink()):alpha(0.7) end },
            hud().corners { length = 5, weight = 2, color = function() return C.primary end,
              visible = function() return t.visual_focus and s.current() end } } }
        return node, function() end
      end
    end,
    empty = empty,
  }

  -- ------------------------------------------------------------ kanban --

  S.kanban_column = {
    background = function(t, spec)
      if spec.delegate then return nil end
      return ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerLow end, border_width = 1,
          border_color = function() return stroke(C, "quiet") end },
        hud().corners { length = 8, weight = 1, color = function() return C.primary:alpha(0.6) end } }
    end,
    row = function(t, spec)
      local H = spec.row_height or 64
      return function(row, s)
        local function r(key) return field(s, row, key) end
        local function tag() return r("tag") and tostring(r("tag")) or nil end
        local studs = ui.Item { anchors = { right = true, right_margin = 16, vertical_center = true }, width = 4, height = 18,
          opacity = function() return s.hovered() and 1 or 0 end, behavior = { opacity = quick } }
        for i = 0, 2 do
          ui.reparent(ui.Rect { y = i * 7, width = 4, height = 4, color = function() return C.primary end }, studs)
        end
        local node = ui.Item { anchors = { fill = true },
          ui.Item { anchors = { fill = true, margins = 6 },
            translate_x = function() return s.hovered() and 3 or 0 end, behavior = { translate_x = quick },
            ui.Rect { anchors = { fill = true }, color = function() return chosen(s) and C.primary:alpha(0.12) or C.surfaceContainer end,
              border_width = 1, border_color = function() return chosen(s) and C.primary or stroke(C, "idle") end,
              behavior = { color = quick } },
            ui.Rect { anchors = { left = true, top = true, bottom = true }, width = 3, color = function() return C.primary end,
              visible = function() return chosen(s) end },
            hud().corners { length = 5, weight = 2, color = function() return C.primary end,
              visible = function() return t.visual_focus and s.current() end } },
          caps { x = 18, y = 13, width = function() return s.width() - 50 end, elide = "right",
            text = function() return label_of(s.row() or row) end, color = function() return row_ink(s) end },
          M.text { x = 18, y = H - 30, visible = function() return tag() ~= nil end, font_family = theme.mono,
            text = function() return "[ " .. (tag() or ""):upper() .. " ]" end, font_size = SZ.small,
            color = function() return C.primary end },
          studs }
        return node, function() end
      end
    end,
    empty = empty,
  }

  -- ------------------------------------------------------ transfer list --

  S.transfer_list = {
    background = function(t, spec)
      if spec.delegate then return nil end
      return ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainer end, border_width = 1,
          border_color = function() return stroke(C, "idle") end },
        hud().corners { length = 7, weight = 2, color = function() return C.primary end } }
    end,
    row = function(t, spec)
      local H = spec.row_height or 36
      return function(row, s)
        local function on() return s.selected() end
        local node = ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true, margins = 1 },
            color = function() return C.primary:alpha(s.down() and 0.16 or (s.hovered() and 0.06 or 0)) end },
          ui.Rect { x = 14, y = (H - 14) / 2, width = 14, height = 14, color = "transparent", border_width = 1,
            border_color = function() return on() and C.primary or C.onSurfaceVariant end,
            ui.Rect { anchors = { fill = true, margins = 3 }, color = function() return C.primary end,
              scale = function() return on() and 1 or 0 end, behavior = { scale = { duration = 180, easing = "out_expo" } } } },
          caps { x = 40, y = (H - MENU * 1.3) / 2, width = function() return s.width() - 52 end, elide = "right",
            text = function() return label_of(s.row() or row) end, color = function() return on() and C.primary or C.onSurface end },
          brackets(t, s) }
        return node, function() end
      end
    end,
    empty = empty,
  }

  for _, name in ipairs { "list", "virtual_list", "list_box", "boxed_list", "grid_view", "flow_box", "file_list",
    "tree_view", "timeline", "feed", "chat_log", "kanban_column", "transfer_list" } do
    local build = S[name].row
    S[name].row = function(t, spec)
      local fn = build(t, spec)
      return setmetatable({ motion = MOTION }, { __call = function(_, row, s) return fn(row, s) end })
    end
  end
end
