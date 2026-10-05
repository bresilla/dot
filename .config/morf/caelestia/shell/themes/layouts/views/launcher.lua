-- The launcher's view: a panel floating in the middle of the screen.
--
-- A caption names what is being searched and counts what was found; the
-- search sits under it and stays there; the results stack below, and the
-- panel grows and shrinks with them. The mode shows as a badge at the
-- field's head, an M3 shape that morphs from mode to mode. What the
-- prefixes do is a legend outside the panel, beside it. An instrument
-- theme (Tsugumori) numbers the rows and brackets the
-- panel, the field and the legend. Searching, choosing and running belong
-- to the controller.
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local C = theme.color
local V = {}

-- Each mode's badge: the shape it morphs to, and the glyph on it.
local BADGES = {
  Search = { "circle", "search" }, Apps = { "cookie9", "apps" }, Web = { "soft_burst", "language" },
  Calculator = { "diamond", "calculate" }, Run = { "square", "terminal" }, Files = { "pill", "folder_open" },
  Windows = { "square", "desktop_windows" }, System = { "sunny", "settings_power" },
  Emoji = { "cookie9", "mood" }, Clipboard = { "pill", "content_paste" }, Colour = { "sunny", "palette" },
  Commands = { "soft_burst", "bolt" }, Actions = { "soft_burst", "bolt" },
}

-- The prefixes the legend lists, most useful first.
local CHIPS = {
  { "=", "Calc" }, { "/", "Files" }, { "?", "Web" }, { "@", "Win" }, { "!", "Sys" }, { ":", "Emoji" },
}

function V.build(M)
  local row_of = M.row_of
  local WIDTH, WIDE = 620, 1180
  local PAD = 10
  local SEARCH = 50
  local HEAD = 30
  local INSTRUMENT = theme.appearance.id == "tsugumori"
  local NUMBER = INSTRUMENT and 26 or 0
  local ROW, ROW_GAP = 48, 2
  local HEADER = 28
  local HERO = 92
  local EMPTY = 96
  local CAROUSEL = 196
  local SLOT, SLOT_ON = 224, 280
  local INNER = WIDTH - 2 * PAD

  local function wide() return M.mode:get() == "wallpapers" end
  local function wide_width()
    local _, _, desk_w = require("bar").desk()
    return math.max(WIDTH, math.min(WIDE, (desk_w or WIDE) - 80))
  end
  local function width() return wide() and wide_width() or WIDTH end

  local function entry_height(entry)
    if not entry then return ROW end
    if entry.kind == "header" then return HEADER end
    if entry.kind == "hero" then return HERO end
    return ROW
  end
  --- Where entry `index` starts in the list, and how tall it is.
  local function entry_span(index)
    local y = 0
    for i = 1, index - 1 do y = y + entry_height(M.results:get(i)) + ROW_GAP end
    return y, entry_height(M.results:get(index))
  end
  local function list_height()
    local n = M.count:get()
    if n <= 0 then return EMPTY end
    local y, h = entry_span(n)
    return y + h
  end

  -- As much of the list as the output has room for; the rest scrolls.
  local function view_height()
    local _, _, _, desk_h = require("bar").desk()
    local room = math.floor((desk_h or 1080) * 0.66) - HEAD - SEARCH - 3 * PAD
    return math.max(ROW, math.min(list_height(), room))
  end
  local function body_height() return wide() and CAROUSEL or view_height() end
  local TOP = PAD + HEAD + SEARCH + PAD
  local function height() return TOP + body_height() + PAD end

  -- ------------------------------------------------------------------ rows --

  local function centred(node) return kit.centred(32, 32, node) end
  local function row_icon(row)
    if row.glyph then return centred(kit.text { text = row.glyph, font_size = 24 }) end
    local paint = row.swatch or (row.kind == "scheme" and row.color)
    if paint then
      local ok, color = pcall(morf.color, paint)
      return centred(kit.shape {
        width = 26, height = 26, shape = "cookie9", color = ok and color or paint,
      })
    end
    if row.kind == "scheme" then
      return centred(kit.icon("wallpaper", 26, function() return C.onSurfaceVariant end))
    end
    if row.kind == "calc" then
      return centred(kit.icon("function", 28, function() return C.onSurface end))
    end
    if row.kind == "action" or row.kind == "variant" or row.material then
      return centred(kit.icon(row.material or row.icon, 26, function() return C.onSurfaceVariant end))
    end
    local hit = M.icon(row.icon)
    if hit and hit.name then
      return ui.Icon { width = 32, height = 32, name = hit.name, source_width = 64, source_height = 64 }
    elseif hit and hit.path then
      return ui.Image { width = 32, height = 32, source = hit.path, fill_mode = "preserve_aspect_fit" }
    end
    return centred(kit.icon("apps", 26, function() return C.onSurfaceVariant end))
  end

  local function index_of(key)
    for i = 1, M.results:len() do
      if M.results:get(i).key == key then return i end
    end
  end
  local function is_selected(key)
    local sel = M.results:get(M.selected:get())
    return sel ~= nil and sel.key == key
  end

  -- The chosen row's own hint: Tab, while it has other actions to list.
  local function hints(selected, has_actions)
    return ui.Row {
      anchors = { right = true, right_margin = 12, vertical_center = true }, gap = 6, align = "center",
      opacity = function() return (selected() and has_actions()) and 1 or 0 end,
      behavior = { opacity = { duration = theme.duration.small } },
      kit.text { text = "Actions", font_size = theme.size.smaller, color = kit.ink("lo") },
      kit.keycap { text = "Tab", height = 20 },
    }
  end

  local results
  local function header(entry)
    return ui.Item {
      id = "launcher-header-" .. entry.key,
      width = INNER, height = HEADER,
      enter = { opacity = 0, duration = theme.duration.small },
      kit.heading {
        id = "launcher-section-" .. entry.key, scope = "launcher", level = "section",
        viewport = function() return results end,
        anchors = { left = true, left_margin = 12, bottom = true, bottom_margin = 5 }, width = INNER - 24,
        elide = "right", text = entry.name, font_size = theme.size.smaller, font_weight = 600,
        color = kit.ink("lo"), ink = kit.ink("accent"),
      },
    }
  end

  --- The question and its answer, the answer in large type: what an
  --- arithmetic, a conversion or `>calc` comes back with.
  local function hero(entry)
    local row = row_of(entry) or entry
    local answer, question
    if row.kind == "calc" and not row.failed and row.result then
      answer = tostring(row.result)
      question = tostring(row.name):gsub("%s*=%s*[^=]*$", "")
    else
      answer = tostring(row.name or "")
      question = tostring(row.question or (row.kind ~= "calc" and row.description) or "")
    end
    return kit.action {
      id = "launcher-row-" .. entry.key,
      width = INNER, height = HERO, cursor = "pointer",
      enter = { opacity = 0, scale = 0.97, duration = theme.duration.small, easing = theme.ease.standard_decel },
      on_clicked = function() M.activate(row) end,
      kit.card {
        anchors = { fill = true, top_margin = 4, bottom_margin = 4 }, radius = kit.round(16),
        color = function() return C.surfaceContainerHigh end,
        ui.Column {
          anchors = { left = true, left_margin = 18, vertical_center = true }, gap = 2,
          kit.text {
            text = question, font_size = theme.size.small, width = INNER - 160, elide = "middle",
            color = function() return C.onSurfaceVariant end, visible = question ~= "",
          },
          ui.Row {
            gap = 10, align = "center",
            kit.text {
              text = "=", font_size = 28, visible = question ~= "",
              color = function() return C.primary end,
            },
            kit.text {
              id = "launcher-answer", text = answer, width = INNER - 190, elide = "middle",
              font_size = row.failed and theme.size.larger or 30, font_weight = 700,
              color = function() return row.failed and C.onSurfaceVariant or C.onSurface end,
            },
          },
        },
      },
    }
  end

  -- An ordinary row, rebindable: scrolled out of sight, the list view hands
  -- it the row scrolling in rather than building another.
  local serial = 0
  local function plain_row(entry)
    serial = serial + 1
    local bound = { entry = entry, row = row_of(entry) or entry }
    local revision = morf.signal("caelestia.launcher.row." .. serial, 0)
    local function now() revision:get() return bound.row end
    local function selected() revision:get() return is_selected(bound.entry.key) end
    local function has_actions() local r = now() return r.actions ~= nil and #r.actions > 0 and M.acting:get() == "" end
    local icon = row_icon(bound.row)
    local icon_box = ui.Item { width = 32, height = 32, icon }
    local area = kit.action {
      id = "launcher-row-" .. entry.key,
      enter = { opacity = 0, scale = 0.97, duration = theme.duration.small, easing = theme.ease.standard_decel },
      width = INNER, height = ROW, cursor = "pointer",
      on_entered = function()
        local i = index_of(bound.entry.key)
        if i then M.selected:set(i) end
      end,
      on_clicked = function() M.activate(bound.row) end,
      ui.Row {
        anchors = { left = true, left_margin = 10, vertical_center = true }, gap = 12, align = "center",
        INSTRUMENT and kit.text {
          width = NUMBER - 12, horizontal_alignment = "right", font_size = theme.size.smaller, font_weight = 600,
          text = function()
            revision:get()
            local i, n = index_of(bound.entry.key), 0
            for j = 1, (i or 0) do if M.results:get(j).kind ~= "header" then n = n + 1 end end
            return ("%02d"):format(n)
          end,
          color = function() return selected() and C.primary or C.onSurfaceVariant end,
        } or nil,
        icon_box,
        ui.Column {
          gap = 1,
          kit.text {
            id = "launcher-name", text = function() return tostring(now().name or "") end,
            font_size = theme.size.normal, font_weight = 500, elide = "right",
            width = function() return INNER - 70 - NUMBER - ((selected() and has_actions()) and 120 or 0) end,
            color = function() return C.onSurface end,
          },
          kit.text {
            text = function() return tostring(now().description or "") end, font_size = theme.size.smaller,
            visible = function() return (now().description or "") ~= "" end, elide = "right",
            width = function() return INNER - 70 - NUMBER - ((selected() and has_actions()) and 120 or 0) end,
            color = function() return C.onSurfaceVariant end,
          },
        },
      },
      kit.icon("check", 20, function() return C.primary end, {
        anchors = { right = true, right_margin = 16, vertical_center = true },
        visible = function() return now().current and true or false end,
      }),
      hints(selected, has_actions),
    }
    return area, function(next_entry)
      bound.entry, bound.row = next_entry, row_of(next_entry) or next_entry
      area.id = "launcher-row-" .. next_entry.key
      ui.destroy(icon, true)
      icon = row_icon(bound.row)
      ui.reparent(icon, icon_box)
      revision:set(revision:get() + 1)
    end
  end

  -- The selection changes no row's binding by itself; the rows that show
  -- hints read it through their revision, so they follow it here.
  local function delegate(entry)
    if entry.kind == "header" then return header(entry) end
    if entry.kind == "hero" then return hero(entry) end
    return plain_row(entry)
  end

  -- -------------------------------------------------------------- carousel --

  local MAX_SLOTS = 64
  -- The slots are a window on the wallpapers that follows the chosen one,
  -- so a folder of more than MAX_SLOTS still reaches its last picture.
  local function offset()
    local count = M.wall_count:get()
    return math.max(0, math.min(M.selected:get() - MAX_SLOTS // 2, count - MAX_SLOTS))
  end
  local function carousel()
    local slots = {}
    local motion = { duration = theme.duration.normal, easing = theme.ease.emphasized_decel }
    for i = 1, MAX_SLOTS do
      local function index() return offset() + i end
      local function wall() return index() <= M.wall_count:get() and M.walls[index()] or nil end
      local function on() return M.selected:get() == index() end
      -- Only pictures near the chosen one are loaded.
      local function near() return math.abs(M.selected:get() - index()) <= 4 end
      slots[i] = kit.action {
        id = "launcher-wallpaper-" .. i,
        height = CAROUSEL, cursor = "pointer",
        width = function() return on() and SLOT_ON or SLOT end,
        visible = function() return wall() ~= nil end,
        behavior = { width = motion },
        on_clicked = function()
          if on() then
            local w = wall()
            if w then M.activate(w) end
          else
            M.selected:set(index())
          end
        end,
        ui.Column {
          anchors = { horizontal_center = true }, gap = 8, align = "center",
          y = function() return on() and 8 or 26 end,
          behavior = { y = motion },
          kit.surface {
            radius = kit.round(14), clip = true,
            width = function() return on() and SLOT_ON - 16 or SLOT - 24 end,
            height = function() return on() and 152 or 122 end,
            behavior = { width = motion, height = motion },
            color = function() return C.surfaceContainerHigh end,
            ui.Image {
              anchors = { fill = true }, fill_mode = "preserve_aspect_crop",
              source = function()
                local w = wall()
                return (w and near()) and w.path or ""
              end,
            },
          },
          kit.text {
            text = function() local w = wall() return w and w.name or "" end,
            font_size = function() return on() and theme.size.normal or theme.size.small end,
            font_weight = 500, width = function() return on() and SLOT_ON - 16 or SLOT - 24 end,
            horizontal_alignment = "center", elide = "right",
            color = function() return on() and C.onSurface or C.onSurfaceVariant end,
          },
        },
      }
    end
    local strip = ui.Row {
      gap = 0,
      translate_x = function()
        local sel = math.max(1, M.selected:get() - offset())
        return (wide_width() - 2 * PAD) / 2 - ((sel - 1) * SLOT + SLOT_ON / 2)
      end,
      behavior = { translate_x = motion },
      table.unpack(slots),
    }
    return ui.Item {
      id = "launcher-wallpapers",
      x = PAD, y = TOP, width = function() return wide_width() - 2 * PAD end, height = CAROUSEL, clip = true,
      visible = wide,
      strip,
      kit.text {
        anchors = { center_in = true }, text = "No wallpapers in ~/Pictures/Wallpapers",
        font_size = theme.size.larger, color = function() return C.onSurfaceVariant end,
        visible = function() return M.wall_count:get() == 0 end,
      },
    }
  end

  -- ---------------------------------------------------------------- results --

  local empty = ui.Column {
    id = "launcher-empty",
    anchors = { center_in = true }, gap = 4, align = "center",
    visible = function() return M.count:get() == 0 end,
    kit.icon("search_off", 30, function() return C.onSurfaceVariant end),
    kit.text { text = "Nothing matches", font_size = theme.size.normal, font_weight = 500,
      color = function() return C.onSurface end },
  }

  -- Keeps the chosen row, and its section's heading, in view.
  local scroll = morf.signal("caelestia.launcher.scroll", 0)
  morf.effect("caelestia.launcher.scroll", function()
    local count = M.results:len()
    if wide() or count == 0 then if scroll:get() ~= 0 then scroll:set(0) end return end
    local at = math.max(1, math.min(M.selected:get(), count))
    local start, h = entry_span(at)
    local top = start
    local before = at > 1 and M.results:get(at - 1) or nil
    if before and before.kind == "header" then top = entry_span(at - 1) end
    local view, now = view_height(), scroll:get()
    local next_scroll = now
    if top < now then next_scroll = top end
    if start + h > now + view then next_scroll = start + h - view end
    next_scroll = math.max(0, math.min(next_scroll, math.max(0, list_height() - view)))
    if next_scroll ~= now then scroll:set(next_scroll) end
  end)

  -- The rows: the engine's list view, virtualised by each row's height and
  -- recycling within a kind, scrolled by the effect above.
  M.row_heights = { header = HEADER + ROW_GAP, hero = HERO + ROW_GAP, row = ROW + ROW_GAP }
  local list = ui.ListView {
    id = "launcher-list", model = M.results, delegate = delegate, width = INNER, height = 1,
    item_extent = ROW + ROW_GAP, size_field = "height", kind_field = "kind", overscan = 3,
  }
  morf.effect("caelestia.launcher.list", function()
    local y = scroll:get()
    list.height = view_height()
    morf.sync_view(list, y)
  end, { owner = list })

  -- The selection: one box in a distance field riding an item that springs
  -- from row to row, so it stretches towards the next row and settles there.
  local highlight = ui.Item {
    id = "launcher-highlight",
    x = 0, width = INNER,
    y = function() return (entry_span(math.max(1, M.selected:get()))) - scroll:get() end,
    height = function() local _, h = entry_span(math.max(1, M.selected:get())) return h end,
    behavior = { y = kit.spring(420, 28), height = kit.spring(420, 28) },
    visible = function()
      local sel = M.results:get(M.selected:get())
      return M.count:get() > 0 and sel ~= nil and sel.kind ~= "hero"
    end,
  }
  local selection = kit.selection {
    id = "launcher-selection", track = highlight, radius = kit.round(14),
    color = function() return C.primary:alpha(0.14) end,
  }

  results = ui.Item {
    id = "launcher-results",
    x = PAD, y = TOP, width = INNER, height = view_height,
    visible = function() return not wide() end,
    clip = true,
    selection,
    highlight,
    list,
    empty,
  }


  -- ----------------------------------------------------------------- legend --

  -- What the prefixes do, beside the panel: a strip of its own, read, not
  -- pressed (a press out there shuts the panel), and only after a wait.
  local prefixes = {}
  for i, spec in ipairs(CHIPS) do
    prefixes[i] = ui.Row {
      gap = 8, align = "center", height = 22,
      kit.text { text = spec[1], font_size = theme.size.small, font_weight = 700, width = 10,
        horizontal_alignment = "center", color = function() return C.primary end },
      kit.text { text = INSTRUMENT and spec[2]:upper() or spec[2], font_size = theme.size.smaller,
        color = kit.ink("lo") },
    }
  end
  local LEGEND_W = 96
  -- Shown only to someone who opened the launcher and then waited: five
  -- seconds untouched brings it; a key typed first keeps it away until the
  -- next opening.
  local LEGEND_DELAY = 5000
  local legend_due = morf.signal("caelestia.launcher.legend", false)
  local legend_timer, typed = nil, false
  local function stop_legend_timer()
    if legend_timer then legend_timer:cancel() legend_timer = nil end
  end
  morf.effect("caelestia.launcher.legend.open", function()
    local open = M.opened:get()
    stop_legend_timer()
    typed = false
    legend_due:set(false)
    if open then
      legend_timer = morf.timer(LEGEND_DELAY, function()
        legend_timer = nil
        if not typed and M.query:get() == "" then legend_due:set(true) end
      end, false)
    end
  end)
  morf.effect("caelestia.launcher.legend.typed", function()
    if M.query:get() ~= "" and M.opened:get() then
      typed = true
      stop_legend_timer()
      legend_due:set(false)
    end
  end)
  local legend = ui.Item {
    id = "launcher-legend",
    x = function() return width() + 10 end, y = 0, width = LEGEND_W, height = #CHIPS * 22 + 20,
    opacity = function()
      return (legend_due:get() and M.opened:get() and not wide() and M.acting:get() == "") and 1 or 0
    end,
    behavior = { opacity = { duration = theme.duration.normal } },
    ui.Rect {
      anchors = { fill = true }, radius = INSTRUMENT and 0 or 14,
      color = function() return C.surface:alpha(0.92) end,
      border_width = 1, border_color = kit.stroke("quiet"),
    },
    kit.decor("corners", { length = 7 }) or ui.Item {},
    ui.Column {
      anchors = { left = true, left_margin = 14, top = true, top_margin = 10 }, gap = 0,
      table.unpack(prefixes),
    },
  }

  -- ----------------------------------------------------------------- header --

  local header_row = kit.caption {
    id = "launcher-caption",
    x = PAD + 4, y = PAD + 8, width = INNER - 8,
    text = function() return INSTRUMENT and ((M.mode_name()) .. " //"):upper() or (M.mode_name()) end,
    note = function()
      local n = 0
      for i = 1, M.results:len() do
        local kind = M.results:get(i).kind
        if kind ~= "header" then n = n + 1 end
      end
      if wide() then n = M.wall_count:get() end
      return INSTRUMENT and ("%02d MATCHES"):format(n) or (n == 1 and "1 result" or n .. " results")
    end,
  }

  local field
  -- ----------------------------------------------------------------- search --

  -- What the query is searching, as the badge at the field's head: an M3
  -- shape that morphs from one mode's to the next, the mode's glyph on it.
  local function badge_of() return BADGES[(M.mode_name())] or BADGES.Search end
  local badge = ui.Item {
    id = "launcher-badge",
    anchors = { left = true, left_margin = 7, vertical_center = true }, width = 36, height = 36,
    kit.shape {
      anchors = { fill = true }, shape = function() return badge_of()[1] end,
      color = function() return C.primaryContainer end,
    },
    kit.icon(function() return badge_of()[2] end, 20, function() return C.onPrimaryContainer end,
      { anchors = { center_in = true } }),
  }

  field = ui.TextInput {
    id = "launcher-search",
    anchors = { left = true, right = true, top = true, bottom = true, left_margin = 54, right_margin = 46 },
    vertical_alignment = "center", tab_navigation = false,
    font_family = theme.font, font_size = theme.size.larger,
    color = function() return C.onSurface end,
    placeholder = "Search apps, files, the web…",
    placeholder_color = function() return C.onSurfaceVariant end,
    caret_color = function() return C.primary end,
    selection_color = function() return C.primary:alpha(0.35) end,
    on_text_changed = function(text) M.query:set(text) end,
    on_accepted = function() M.activate(M.chosen()) end,
    on_escape = M.escape,
    on_key_pressed = M.key,
    on_key_released = M.release,
  }
  local clear = kit.action {
    id = "launcher-clear",
    width = 32, height = 32, cursor = "pointer",
    anchors = { right = true, right_margin = 9, vertical_center = true },
    visible = function() return M.query:get() ~= "" end,
    on_clicked = function() field.text = "" M.query:set("") field.focus = true end,
    kit.icon("close", 18, function() return C.onSurfaceVariant end, { anchors = { center_in = true } }),
  }
  local search = ui.Item {
    id = "launcher-field",
    anchors = { left = true, right = true, top = true, left_margin = PAD, right_margin = PAD, top_margin = PAD + HEAD },
    height = SEARCH,
    kit.surface {
      anchors = { fill = true }, radius = kit.round(SEARCH / 2),
      color = function() return C.surfaceContainerHigh end,
    },
    -- A rail along its foot that lights while something is typed.
    ui.Rect {
      anchors = { left = true, right = true, bottom = true, left_margin = INSTRUMENT and 0 or SEARCH / 2,
        right_margin = INSTRUMENT and 0 or SEARCH / 2 },
      height = 2, color = function() return C.primary end,
      opacity = function() return M.query:get() ~= "" and 1 or 0 end,
      behavior = { opacity = { duration = theme.duration.small } },
    },
    kit.decor("corners", { length = 8 }) or ui.Item {},
    badge,
    field,
    clear,
  }

  local content = ui.Item {
    anchors = { fill = true },
    -- An instrument's panel: a hairline frame, and L-brackets on its corners.
    INSTRUMENT and ui.Rect {
      anchors = { fill = true }, color = "transparent", border_width = 1, border_color = kit.stroke("quiet"),
    } or nil,
    kit.decor("corners", { length = 14, inset = 4 }) or ui.Item {},
    header_row,
    results,
    carousel(),
    search,
    legend,
  }

  local function top_margin()
    local _, _, _, h = require("bar").desk()
    return math.floor(h * 0.16)
  end
  return {
    content = content, width = width, height = height,
    set_query = function(text) field.text = text field.cursor_position = #text end,
    focus = function(on) field.focus = on end,
    props = {
      anchors = { top = true, horizontal_center = true, top_margin = top_margin() },
      behavior = {
        width = { duration = theme.duration.normal, easing = theme.ease.emphasized_decel },
        height = { duration = theme.duration.normal, easing = theme.ease.emphasized_decel },
      },
    },
  }
end
return V
