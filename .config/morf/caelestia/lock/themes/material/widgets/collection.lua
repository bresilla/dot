-- Material's looks for each Collection widget: list items with an
-- onSurface state layer and the secondary container on the chosen one;
-- a boxed list as M3 Expressive's segmented list (tiles that round
-- outward at the ends and meet with tight corners); tables with a tonal
-- header, the chosen row in the secondary container and a sort arrow that
-- turns; trees with outline guides and a chevron that turns; tonal file
-- icons; a timeline whose current dot swells in its container; feed cards,
-- chat bubbles in primary and container, kanban cards that lift, and
-- transfer rows with M3 checks. The layouts are the default kit's and
-- tsugumori's; only the style differs.
local morf = require("morf")
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local SZ = theme.size
  local function get(v) if type(v) == "function" then return v() end return v end
  local function quick() return { duration = theme.duration.small } end
  local MOTION = {
    enter = { opacity = 0, translate_y = 12, duration = 300, easing = theme.ease.emphasized_decel },
    exit = { opacity = 0, translate_x = -40, duration = 200, easing = theme.ease.emphasized_accel },
  }

  local function label_of(r)
    if type(r) == "table" then return tostring(r.label or r.name or r.title or r.text or r.key or "") end
    return tostring(r or "")
  end
  local function field(s, row, key)
    local r = s.row() or row
    return type(r) == "table" and r[key] or nil
  end
  local function chosen(s) return s.selected() or s.current() end
  -- A row's tone: the chosen one in the secondary container, the state
  -- layer over the rest (as an opaque mix, so overlapping pieces agree).
  local function row_tone(s, base, stripe)
    local c = C()
    if chosen(s) then return c.secondaryContainer:mix(c.onSecondaryContainer, s.hovered() and 0.08 or 0) end
    -- (Over a ground of its own the layer is mixed in; over whatever is
    -- under the list it is the ink at an alpha.)
    local layer = s.down() and 0.12 or (s.hovered() and 0.08) or (stripe and s.index() % 2 == 0 and 0.035) or 0
    if base then return c[base]:mix(c.onSurface, layer) end
    return c.onSurface:alpha(layer)
  end
  local function row_ink(s) local c = C() return chosen(s) and c.onSecondaryContainer or c.onSurface end
  local function focus_edge(t, s) return function() return t.visual_focus and s.current() and 2 or 0 end end
  local function focus_color() return C().secondary end
  local TONES = { { "primaryContainer", "onPrimaryContainer" }, { "secondaryContainer", "onSecondaryContainer" },
    { "tertiaryContainer", "onTertiaryContainer" }, { "errorContainer", "onErrorContainer" } }
  local function tone_of(name)
    local h = 0
    for i = 1, #name do h = (h * 31 + name:byte(i)) % 997 end
    return TONES[h % #TONES + 1]
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
  local ICON_TONE = { folder = "primary", folder_open = "primary", image = "tertiary", movie = "error",
    music_note = "secondary", picture_as_pdf = "error", folder_zip = "secondary", code = "primary" }
  local function is_folder(r) return type(r) == "table" and (r.is_dir or r.kind == "folder" or r.type == "folder") end
  local function file_icon(r, open)
    if type(r) == "table" and r.icon then return r.icon end
    if is_folder(r) then return open and "folder_open" or "folder" end
    local ext = label_of(r):match("%.([%w]+)$")
    return ext and EXT[ext:lower()] or "draft"
  end
  local function icon_color(name) return function() local c = C() return c[ICON_TONE[name] or "onSurfaceVariant"] end end
  local function chevron(s, size, color, props)
    local holder = ui.Item { x = props.x, anchors = { vertical_center = true }, width = size, height = size,
      visible = props.visible, M.icon("chevron_right", size, color, { anchors = { center_in = true } }) }
    local key, open
    morf.effect("caelestia.collection.chevron." .. tostring(holder), function()
      local r = s.row()
      local k, e = r and r.key, r and r.expanded or false
      local turn = e and 90 or 0
      if k == key and e ~= open then
        morf.animation.play { { node = holder, property = "rotation", to = turn, duration = 320, easing = theme.ease.spatial } }
      else
        holder.rotation = turn
      end
      key, open = k, e
    end, { owner = holder })
    return holder
  end
  -- An indeterminate arc that turns (a loop on a static drawing).
  local function spinner(size, color, active)
    return ui.Item { width = size, height = size,
      loop = function() if not active() then return nil end return { rotation = { from = 0, to = 360, duration = 900, easing = "linear" } } end,
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, size, size }, d = M.arc_path(size / 2, size / 2, size / 2 - 2, 0, 270),
        fill_color = "transparent", stroke_color = color, stroke_width = 2.5, stroke_cap = "round" } }
  end
  local function empty(t, spec)
    if spec.delegate then return nil end
    return ui.Column { anchors = { center_in = true }, gap = 8, align = "center",
      visible = function() return (t.count or 0) == 0 end,
      ui.Rect { width = 56, height = 56, radius = 18, color = function() return C().surfaceContainerHigh end,
        M.icon(spec.empty_icon or "inbox", 28, function() return C().onSurfaceVariant end, { anchors = { center_in = true } }) },
      M.text { text = spec.empty_text or "Nothing here", font_size = SZ.normal, color = function() return C().onSurfaceVariant end } }
  end

  -- -------------------------------------------------------------- rows --

  local function item_row(t, spec, o)
    local H = spec.row_height or 36
    local two = H >= 46
    return function(row, s)
      local function r(key) return field(s, row, key) end
      local inset = o.inset or 3
      local lead = 14 + inset
      local has_icon = function() return r("icon") ~= nil end
      local tx = function() return lead + (o.number and 44 or 0) + (has_icon() and 34 or 0) end
      local right = function() return 14 + inset + (o.chevron and 22 or 0) + ((r("trailing") or r("value")) and 70 or 0) end
      local node = ui.Item { anchors = { fill = true },
        o.segmented or ui.Rect { anchors = { fill = true, margins = inset }, radius = o.radius or 14,
          color = function() return row_tone(s, nil, o.stripe) end, behavior = { color = quick() },
          border_width = focus_edge(t, s), border_color = focus_color },
        o.separator and ui.Rect { anchors = { left = true, right = true, bottom = true, left_margin = 16, right_margin = 16 },
          height = 1, color = function() return C().outlineVariant end,
          visible = function() return s.index() < s.count() end } or nil,
        o.number and M.text { x = lead, width = 36, anchors = { vertical_center = true }, horizontal_alignment = "right",
          text = function() return tostring(s.index()) end, font_family = theme.mono, font_size = SZ.small,
          color = function() return C().onSurfaceVariant end } or nil,
        ui.Rect { x = lead + (o.number and 44 or 0) - 4, anchors = { vertical_center = true }, width = 28, height = 28, radius = 14,
          visible = has_icon, color = function() local c = C() return chosen(s) and c.secondary:alpha(0.16) or c.primary:alpha(0.1) end,
          M.icon(function() return r("icon") or "" end, 18, function() return C().primary end, { anchors = { center_in = true } }) },
        M.text { x = tx, y = two and function() return r("subtitle") and (H / 2 - 20) or (H - SZ.normal * 1.3) / 2 end
            or (H - SZ.normal * 1.3) / 2,
          width = function() return math.max(0, s.width() - tx() - right()) end, elide = "right",
          text = function() return label_of(s.row() or row) end, font_size = SZ.normal,
          color = function() return row_ink(s) end },
        two and M.text { x = tx, y = H / 2 + 1, visible = function() return r("subtitle") ~= nil end,
          width = function() return math.max(0, s.width() - tx() - right()) end, elide = "right",
          text = function() return tostring(r("subtitle") or "") end, font_size = SZ.small,
          color = function() return C().onSurfaceVariant end } or nil,
        M.text { anchors = { right = true, vertical_center = true, right_margin = 14 + inset + (o.chevron and 22 or 0) },
          text = function() return tostring(r("trailing") or r("value") or "") end, font_size = SZ.small,
          color = function() return C().onSurfaceVariant end },
        o.chevron and M.icon("chevron_right", 20, function() return C().onSurfaceVariant end,
          { anchors = { right = true, vertical_center = true, right_margin = 10 + inset } }) or nil,
      }
      return node, function() end
    end
  end

  S.list = { row = function(t, spec) return item_row(t, spec, {}) end, empty = empty }
  S.virtual_list = { row = function(t, spec) return item_row(t, spec, { number = true, stripe = true, inset = 0, radius = 0 }) end,
    empty = empty }
  S.list_box = { row = function(t, spec) return item_row(t, spec, { separator = true, inset = 0, radius = 0 }) end,
    empty = empty }

  --- The segmented list: each row a tile, rounded wide at the list's ends
  --- and tight where tiles meet, two pixels apart.
  S.boxed_list = {
    row = function(t, spec)
      return function(row, s)
        local tone = function() return row_tone(s, "surfaceContainer") end
        local first = function() return s.index() == 1 end
        local last = function() return s.index() == s.count() end
        local tile = ui.Item { anchors = { fill = true, top_margin = 1, bottom_margin = 1 },
          ui.Rect { anchors = { fill = true }, radius = 6, color = tone, behavior = { color = quick() },
            border_width = focus_edge(t, s), border_color = focus_color },
          -- The outer corners: a wider round over the half toward the end.
          ui.Rect { anchors = { left = true, right = true, top = true }, height = function() return (s.area.height or 50) * 0.6 end,
            radius = 20, color = tone, visible = first, behavior = { color = quick() } },
          ui.Rect { anchors = { left = true, right = true, bottom = true }, height = function() return (s.area.height or 50) * 0.6 end,
            radius = 20, color = tone, visible = last, behavior = { color = quick() } } }
        -- (The square halves under the round ones keep the inner corners tight.)
        local node, update = item_row(t, spec, { chevron = true, inset = 0, segmented = tile })(row, s)
        return node, update
      end
    end,
    empty = empty,
  }

  S.grid_view = {
    row = function(t, spec)
      local CW, CH = spec.cell_width or 96, spec.cell_height or 96
      return function(row, s)
        local function r(key) return field(s, row, key) end
        local node = ui.Item { width = CW, height = CH,
          ui.Rect { anchors = { fill = true, margins = 4 },
            radius = function() return chosen(s) and 28 or 16 end,
            color = function()
              local c = C()
              if chosen(s) then return c.primaryContainer end
              return row_tone(s, "surfaceContainerLow")
            end,
            border_width = focus_edge(t, s), border_color = focus_color,
            behavior = { color = quick(), radius = M.spring(420, 22) } },
          ui.Item { anchors = { horizontal_center = true }, y = CH * 0.16, width = 40, height = 40,
            scale = function() return s.down() and 0.9 or (s.hovered() and 1.08 or 1) end,
            behavior = { scale = M.spring(520, 20) },
            M.icon(function() return r("icon") or "image" end, 34,
              function() local c = C() return chosen(s) and c.onPrimaryContainer or c.primary end,
              { anchors = { center_in = true } }) },
          M.text { x = 8, width = CW - 16, y = CH * 0.16 + 46, horizontal_alignment = "center", elide = "right",
            text = function() return label_of(s.row() or row) end, font_size = SZ.small,
            color = function() local c = C() return chosen(s) and c.onPrimaryContainer or c.onSurface end } }
        return node, function() end
      end
    end,
    empty = empty,
  }

  --- Filter chips: outlined, filled with the secondary container and a
  --- check once picked.
  S.flow_box = {
    row = function(t, spec)
      local CW, CH = spec.cell_width or 128, spec.cell_height or 44
      return function(row, s)
        local function on() return s.selected() or s.current() end
        local node = ui.Item { width = CW, height = CH,
          ui.Rect { anchors = { fill = true, left_margin = 4, right_margin = 4, top_margin = 6, bottom_margin = 6 },
            radius = function() return on() and (CH - 12) / 2 or 8 end,
            color = function()
              local c = C()
              if on() then return c.secondaryContainer:mix(c.onSecondaryContainer, s.hovered() and 0.08 or 0) end
              return c.onSurface:alpha(s.down() and 0.12 or (s.hovered() and 0.08 or 0))
            end,
            border_width = function() return (t.visual_focus and s.current() and 2) or (on() and 0 or 1) end,
            border_color = function() local c = C() return t.visual_focus and s.current() and c.secondary or c.outline end,
            behavior = { color = quick(), radius = M.spring(420, 22) } },
          M.icon("check", 18, function() return C().onSecondaryContainer end,
            { x = 14, anchors = { vertical_center = true }, opacity = function() return on() and 1 or 0 end,
              scale = function() return on() and 1 or 0.4 end, behavior = { opacity = quick(), scale = M.spring(520, 22) } }),
          M.text { anchors = { vertical_center = true }, x = function() return on() and 36 or 18 end, width = CW - 52,
            behavior = { x = M.spring(420, 26) }, elide = "right",
            text = function() return label_of(s.row() or row) end, font_size = SZ.small, font_weight = 500,
            color = function() local c = C() return on() and c.onSecondaryContainer or c.onSurfaceVariant end } }
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
        ui.Rect { anchors = { fill = true }, color = function() return C().surfaceContainer end },
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1, color = function() return C().outlineVariant end },
        M.text { anchors = { fill = true, left_margin = 14, right_margin = 32 }, vertical_alignment = "center",
          horizontal_alignment = numeric and "right" or "left",
          text = column.title or column.key, elide = "right", font_size = SZ.small, font_weight = 600,
          color = function() local c = C() return sorted() and c.primary or c.onSurfaceVariant end },
        ui.Rect { anchors = { right = true, right_margin = 6, vertical_center = true }, width = 22, height = 22, radius = 11,
          color = function() return C().primary:alpha(0.12) end, opacity = function() return sorted() and 1 or 0 end,
          behavior = { opacity = quick() },
          M.icon("arrow_upward", 16, function() return C().primary end,
            { anchors = { center_in = true }, rotation = function() return t.sort_ascending and 0 or 180 end,
              behavior = { rotation = M.spring(320, 22) } }) } }
    end
  end
  local function cell_text(column, s, row, x, format)
    local numeric = column.align == "end" or column.key == "size"
    return M.text { anchors = { fill = true, left_margin = x or 14, right_margin = numeric and 32 or 14 },
      vertical_alignment = "center", horizontal_alignment = numeric and "right" or "left", elide = "right",
      font_size = SZ.normal,
      text = function()
        local v = field(s, row, column.key)
        if format then return format(v) end
        return show(v)
      end,
      color = function() local c = C() return chosen(s) and c.onSecondaryContainer or (column.index == 1 and c.onSurface or c.onSurfaceVariant) end }
  end
  local function row_ground(t, s)
    return ui.Item { width = function() return s.width() end, anchors = { top = true, bottom = true },
      ui.Rect { anchors = { fill = true }, color = function() return row_tone(s, nil, true) end, behavior = { color = quick() },
        border_width = focus_edge(t, s), border_color = focus_color },
      ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1, color = function() return C().outlineVariant:alpha(0.5) end } }
  end
  local function table_cell(t, spec)
    return function(row, column, s)
      if column.index == 1 then
        return ui.Item { anchors = { fill = true }, row_ground(t, s), cell_text(column, s, row) }, function() end
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
          ui.Rect { x = 10, anchors = { vertical_center = true }, width = 26, height = 26, radius = 8,
            color = function() return icon_color(file_icon(s.row() or row))():alpha(0.14) end,
            M.icon(function() return file_icon(s.row() or row) end, 18,
              function() return icon_color(file_icon(s.row() or row))() end, { anchors = { center_in = true } }) },
          cell_text(column, s, row, 46) }, function() end
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
        ui.Rect { anchors = { fill = true, margins = 2 }, radius = 12, color = function() return row_tone(s) end,
          border_width = focus_edge(t, s), border_color = focus_color },
        M.icon(function() return file_icon(s.row() or row) end, 20,
          function() return icon_color(file_icon(s.row() or row))() end, { x = 14, anchors = { vertical_center = true } }),
        M.text { x = 44, y = (H - SZ.normal * 1.3) / 2, width = function() return s.width() - 56 end, elide = "right",
          text = function() return label_of(s.row() or row) end, font_size = SZ.normal,
          color = function() return row_ink(s) end } }, function() end
    end
  end, empty = empty }

  -- ------------------------------------------------------------- trees --

  local INDENT = 18
  local function tree_parts(t, s, row, x0, width_of)
    local parts = {}
    for level = 1, 8 do
      parts[#parts + 1] = ui.Rect { x = x0 + (level - 1) * INDENT + 8, width = 1,
        anchors = { top = true, bottom = true }, color = function() return C().outlineVariant end,
        visible = function() return s.depth() >= level end }
    end
    local function ix() return x0 + s.depth() * INDENT end
    parts[#parts + 1] = chevron(s, 18, function() return C().onSurfaceVariant end,
      { x = ix, visible = function() return s.expandable() end })
    parts[#parts + 1] = ui.Item { x = function() return ix() + 1 end, anchors = { vertical_center = true },
      width = 16, height = 16, visible = function() return s.loading() end,
      spinner(16, function() return C().primary end, function() return s.loading() end) }
    parts[#parts + 1] = M.icon(function()
        local r = s.row() or row
        if type(r) == "table" and r.icon then return r.icon end
        if s.expandable() then return s.expanded() and "folder_open" or "folder" end
        return file_icon(r)
      end, 18,
      function() local r = s.row() or row return icon_color(s.expandable() and "folder" or file_icon(r))() end,
      { x = function() return ix() + 20 end, anchors = { vertical_center = true },
        visible = function() return not s.loading() end })
    parts[#parts + 1] = M.text { anchors = { vertical_center = true },
      x = function() return ix() + (s.loading() and 24 or 44) end,
      width = function() return math.max(0, width_of() - ix() - 52) end, elide = "right",
      text = function() return s.loading() and "Loading…" or label_of(s.row() or row) end, font_size = SZ.normal,
      color = function() local c = C() return s.loading() and c.onSurfaceVariant or row_ink(s) end }
    return parts
  end
  S.tree_view = { row = function(t, spec)
    return function(row, s)
      local node = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true, margins = 2 }, radius = 12,
          color = function() return row_tone(s) end, behavior = { color = quick() },
          border_width = focus_edge(t, s), border_color = focus_color } }
      for _, part in ipairs(tree_parts(t, s, row, 6, function() return s.width() end)) do ui.reparent(part, node) end
      return node, function() end
    end
  end, empty = empty }

  S.tree_table = {
    header = header,
    cell = function(t, spec)
      return function(row, column, s)
        if column.index == 1 then
          local node = ui.Item { anchors = { fill = true }, row_ground(t, s) }
          for _, part in ipairs(tree_parts(t, s, row, 6, function() return column.width or 160 end)) do ui.reparent(part, node) end
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
      local DOT = 12
      local cy = 18
      return function(row, s)
        local function r(key) return field(s, row, key) end
        local function on() return chosen(s) end
        local node = ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true, margins = 2 }, radius = 12,
            color = function() return C().onSurface:alpha(s.hovered() and 0.06 or 0) end,
            border_width = focus_edge(t, s), border_color = focus_color },
          ui.Rect { x = RAIL - 1, y = 0, width = 2, height = cy, radius = 1,
            color = function() return r("done") and C().primary or C().outlineVariant end,
            visible = function() return s.index() > 1 end },
          ui.Rect { x = RAIL - 1, y = cy, width = 2, height = H - cy, radius = 1,
            color = function() return r("done") and C().primary or C().outlineVariant end,
            visible = function() return s.index() < s.count() end },
          ui.Rect { x = RAIL - 14, y = cy - 14, width = 28, height = 28, radius = 14,
            color = function() return C().primaryContainer end,
            scale = function() return on() and 1 or 0.3 end, opacity = function() return on() and 1 or 0 end,
            behavior = { scale = M.spring(420, 18), opacity = quick() } },
          ui.Rect { x = RAIL - DOT / 2, y = cy - DOT / 2, width = DOT, height = DOT, radius = DOT / 2,
            color = function()
              local c = C()
              if on() or r("done") then return c.primary end
              return c.surface
            end,
            border_width = 2, border_color = function() local c = C() return (on() or r("done")) and c.primary or c.outline end,
            behavior = { color = quick() } },
          M.text { x = RAIL + 22, y = cy - SZ.normal * 0.68, width = function() return s.width() - RAIL - 110 end,
            elide = "right", text = function() return label_of(s.row() or row) end, font_size = SZ.normal,
            font_weight = 500, color = function() local c = C() return on() and c.primary or c.onSurface end },
          M.text { anchors = { right = true, right_margin = 12 }, y = cy - SZ.small * 0.68,
            text = function() return tostring(r("time") or "") end, font_size = SZ.small,
            color = function() local c = C() return on() and c.primary or c.onSurfaceVariant end },
          M.text { x = RAIL + 22, y = cy + 10, width = function() return s.width() - RAIL - 34 end, elide = "right",
            text = function() return tostring(r("detail") or r("subtitle") or "") end, font_size = SZ.small,
            color = function() return C().onSurfaceVariant end } }
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
          ui.Rect { anchors = { fill = true, left_margin = 2, right_margin = 2, top_margin = 4, bottom_margin = 4 },
            radius = 18, color = function() return row_tone({ selected = function() return false end, current = function() return false end,
              hovered = s.hovered, down = s.down, index = s.index }, "surfaceContainerLow") end,
            border_width = focus_edge(t, s), border_color = focus_color, behavior = { color = quick() } },
          ui.Rect { x = 14, y = 16, width = 36, height = 36, radius = 18,
            color = function() return C()[tone_of(author())[1]] end,
            M.text { anchors = { fill = true }, horizontal_alignment = "center", vertical_alignment = "center",
              text = function() return initial(author()) end, font_size = SZ.normal, font_weight = 600,
              color = function() return C()[tone_of(author())[2]] end } },
          M.text { x = 60, y = 14, width = function() return s.width() - 140 end, elide = "right",
            text = author, font_size = SZ.normal, font_weight = 600, color = function() return C().onSurface end },
          M.text { anchors = { right = true, right_margin = 16 }, y = 16, text = function() return tostring(r("time") or "") end,
            font_size = SZ.small, color = function() return C().onSurfaceVariant end },
          M.text { x = 60, y = 36, width = function() return s.width() - 78 end, height = H - 46, wrap = true,
            max_lines = 2, text = function() return tostring(r("text") or r("body") or label_of(s.row() or row)) end,
            font_size = SZ.small, color = function() return C().onSurfaceVariant end } }
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
        local CHAR = 7.8
        local function per_line() return math.max(8, math.floor((s.width() * 0.72 - 28) / 7.4)) end
        local function bw()
          local longest = 0
          for part in (text() .. "\n"):gmatch("([^\n]*)\n") do longest = math.max(longest, #part) end
          local time = tostring(r("time") or "")
          return math.max(64, #time * 8 + 28, math.ceil(math.min(per_line(), longest) * CHAR) + 28 + 6)
        end
        local function bx() return mine() and (s.width() - bw() - 8) or 8 end
        local body
        local function bh()
          local lines = body and body.layout_height or 0
          return math.min((s.area.height or 48) - 8, math.max(lines, 18) + 9 + 24)
        end
        local function fill() local c = C() return mine() and c.primary or c.surfaceContainerHigh end
        local function ink() local c = C() return mine() and c.onPrimary or c.onSurface end
        body = M.text { x = 16, y = 9, width = function() return bw() - 28 end, wrap = true, text = text,
          font_size = SZ.small, color = ink }
        local node = ui.Item { anchors = { fill = true },
          ui.Item { x = bx, y = 4, width = bw, height = bh,
            scale = function() return s.down() and 0.97 or 1 end, behavior = { scale = M.spring(520, 22) },
            ui.Rect { anchors = { fill = true }, radius = 20, color = fill,
              border_width = function() return t.visual_focus and s.current() and 2 or 0 end, border_color = focus_color },
            ui.Rect { width = 18, height = 18, radius = 4, anchors = { bottom = true }, color = fill,
              x = function() return mine() and (bw() - 18) or 0 end },
            body,
            M.text { anchors = { right = true, bottom = true, right_margin = 14, bottom_margin = 6 },
              text = function() return tostring(r("time") or "") end, font_size = SZ.small,
              color = function() return get(ink()):alpha(0.72) end } } }
        return node, function() end
      end
    end,
    empty = empty,
  }

  -- ------------------------------------------------------------ kanban --

  S.kanban_column = {
    background = function(t, spec)
      if spec.delegate then return nil end
      return ui.Rect { anchors = { fill = true }, radius = 24, color = function() return C().surfaceContainerLow end }
    end,
    row = function(t, spec)
      local H = spec.row_height or 64
      return function(row, s)
        local function r(key) return field(s, row, key) end
        local function tag() return r("tag") and tostring(r("tag")) or nil end
        local node = ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true, margins = 6 }, radius = 16,
            color = function()
              local c = C()
              if chosen(s) then return c.secondaryContainer end
              return s.hovered() and c.surfaceContainerHighest or c.surfaceContainerHigh
            end,
            border_width = focus_edge(t, s), border_color = focus_color,
            shadow_color = function() return C().shadow and C().shadow:alpha(0.3) or "#00000040" end,
            shadow_blur = function() return s.hovered() and 10 or 0 end, shadow_offset_y = function() return s.hovered() and 3 or 0 end,
            translate_y = function() return s.hovered() and -2 or 0 end,
            behavior = { color = quick(), shadow_blur = quick(), translate_y = M.spring(420, 24) } },
          M.text { x = 18, y = 13, width = function() return s.width() - 50 end, elide = "right",
            text = function() return label_of(s.row() or row) end, font_size = SZ.normal,
            color = function() local c = C() return chosen(s) and c.onSecondaryContainer or c.onSurface end },
          ui.Rect { x = 18, y = H - 32, height = 22, radius = 8,
            width = function() return #(tag() or "") * 7 + 20 end, visible = function() return tag() ~= nil end,
            color = function() return C()[tone_of(tag() or "")[1]] end,
            M.text { anchors = { fill = true }, horizontal_alignment = "center", vertical_alignment = "center",
              text = function() return tag() or "" end, font_size = SZ.small, font_weight = 500,
              color = function() return C()[tone_of(tag() or "")[2]] end } },
          M.icon("drag_indicator", 20, function() return C().onSurfaceVariant end,
            { anchors = { right = true, right_margin = 14, vertical_center = true },
              opacity = function() return s.hovered() and 1 or 0 end, behavior = { opacity = quick() } }) }
        return node, function() end
      end
    end,
    empty = empty,
  }

  -- ------------------------------------------------------ transfer list --

  S.transfer_list = {
    background = function(t, spec)
      if spec.delegate then return nil end
      return ui.Rect { anchors = { fill = true }, radius = 20, color = function() return C().surfaceContainerLow end }
    end,
    row = function(t, spec)
      local H = spec.row_height or 36
      return function(row, s)
        local function on() return s.selected() end
        local node = ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true, margins = 3 }, radius = 12,
            color = function() return C().onSurface:alpha(s.down() and 0.12 or (s.hovered() and 0.08 or 0)) end,
            border_width = focus_edge(t, s), border_color = focus_color },
          ui.Rect { x = 14, y = (H - 18) / 2, width = 18, height = 18, radius = 3,
            color = function() local c = C() return on() and c.primary or c.primary:alpha(0) end,
            border_width = function() return on() and 0 or 2 end, border_color = function() return C().onSurfaceVariant end,
            behavior = { color = quick() },
            M.icon("check", 16, function() return C().onPrimary end,
              { anchors = { center_in = true }, scale = function() return on() and 1 or 0.3 end,
                opacity = function() return on() and 1 or 0 end, behavior = { scale = M.spring(520, 20), opacity = quick() } }) },
          M.text { x = 46, y = (H - SZ.normal * 1.3) / 2, width = function() return s.width() - 58 end, elide = "right",
            text = function() return label_of(s.row() or row) end, font_size = SZ.normal,
            color = function() return C().onSurface end } }
        return node, function() end
      end
    end,
    empty = empty,
  }

  local CHAT = { enter = { opacity = 0, translate_y = 16, scale = 0.94, duration = 360, easing = theme.ease.spatial },
    exit = MOTION.exit }
  for _, name in ipairs { "list", "virtual_list", "list_box", "boxed_list", "grid_view", "flow_box", "file_list",
    "tree_view", "timeline", "feed", "chat_log", "kanban_column", "transfer_list" } do
    local build = S[name].row
    S[name].row = function(t, spec)
      local fn = build(t, spec)
      return setmetatable({ motion = name == "chat_log" and CHAT or MOTION },
        { __call = function(_, row, s) return fn(row, s) end })
    end
  end
end
