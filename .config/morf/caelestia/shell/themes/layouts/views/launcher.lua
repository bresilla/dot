-- Material launcher view. Search, navigation and activation belong to its controller.
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local C = theme.color
local V = {}
function V.build(M)
  local row_of = M.row_of
  local mode_name = M.mode_name
  local WIDTH, WIDE = 720, 1270
  local PAD = 8
  local ROW, ROW_GAP = 50, 2
  local HEADER = 30
  local HERO = 116
  local SEARCH = 60
  local FOOTER = 38
  local EMPTY = 90
  local CAROUSEL = 203
  local SLOT, SLOT_ON = 248, 304

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

  local function wide() return M.mode:get() == "wallpapers" end

  -- Wide for the wallpapers, as far as the output allows.
  local function wide_width()
    local _, _, desk_w = require("bar").desk()
    return math.max(WIDTH, math.min(WIDE, (desk_w or WIDE) - 40))
  end
  local function width() return wide() and wide_width() or WIDTH end

  -- As much of the list as the output has room for; the rest scrolls.
  local function view_height()
    local _, _, _, desk_h = require("bar").desk()
    local room = math.floor((desk_h or 1080) * 0.84) - 40 - SEARCH - 2 * PAD - FOOTER
    return math.max(ROW, math.min(list_height(), room))
  end

  local function height()
    local body = wide() and CAROUSEL or view_height()
    return SEARCH + PAD + body + PAD + FOOTER
  end

  local function row_icon(row)
    if row.glyph then
      return kit.centred(32, 32, kit.text { text = row.glyph, font_size = 26 })
    end
    if row.swatch then
      local ok, color = pcall(morf.color, row.swatch)
      return kit.centred(32, 32, kit.surface {
        width = 28, height = 28, radius = 14, color = ok and color or row.swatch,
        border_width = 2, border_color = kit.stroke("idle"),
      })
    end
    if row.kind == "action" or row.kind == "variant" or row.material then
      return kit.centred(32, 32, kit.icon(row.material or row.icon, 34, function() return C.onSurfaceVariant end))
    end
    if row.kind == "calc" then
      return kit.centred(32, 32, kit.icon("function", 36, function() return C.onSurface end))
    end
    if row.kind == "scheme" then
      if not row.color then
        return kit.centred(32, 32, kit.icon("wallpaper", 30, function() return C.onSurfaceVariant end))
      end
      local ok, color = pcall(morf.color, row.color)
      return kit.centred(32, 32, kit.surface {
        width = 28, height = 28, radius = 14, color = ok and color or row.color,
        border_width = 2, border_color = kit.stroke("idle"),
      })
    end
    local hit = M.icon(row.icon)
    if hit and hit.name then
      return ui.Icon { width = 32, height = 32, name = hit.name, source_width = 64, source_height = 64 }
    elseif hit and hit.path then
      return ui.Image { width = 32, height = 32, source = hit.path, fill_mode = "preserve_aspect_fit" }
    end
    return kit.centred(32, 32, kit.icon("apps", 28, function() return C.onSurfaceVariant end))
  end

  local function is_selected(key)
    local sel = M.results:get(M.selected:get())
    return sel and sel.key == key
  end

  local results
  local function header(entry)
    return ui.Item {
      id = "launcher-header-" .. entry.key,
      width = WIDTH - 2 * PAD, height = HEADER,
      enter = { opacity = 0, duration = theme.duration.small },
      kit.heading {
        id = "launcher-section-" .. entry.key, scope = "launcher", level = "section",
        viewport = function() return results end,
        anchors = { left = true, left_margin = 14, bottom = true, bottom_margin = 6 }, width = WIDTH - 2 * PAD - 120,
        elide = "right",
        text = entry.name, font_size = theme.size.small, font_weight = 600,
        color = kit.ink("lo"), ink = kit.ink("accent"),
      },
      -- The theme's decorative code for the section ("" where it prints none).
      kit.label { anchors = { right = true, right_margin = 14, bottom = true, bottom_margin = 7 },
        text = kit.code(entry.name, "##.##"), font_size = theme.size.small - 4, color = kit.ink("lo") },
    }
  end

  --- An answer, as Raycast shows one: the question in a box, an arrow, the
  --- answer in large type in another.
  local function hero(entry)
    local row = row_of(entry) or entry
    local box_w = (WIDTH - 2 * PAD - 56) / 2
    local function box(x, big, label, id)
      return kit.card {
        x = x, y = 6, width = box_w, height = HERO - 12, radius = 16,
        color = function() return C.surfaceContainerHigh end,
        ui.Column {
          anchors = { center_in = true }, gap = 6, align = "center",
          kit.text {
            id = id, text = big, width = box_w - 24, horizontal_alignment = "center", elide = "middle",
            font_size = id and 30 or 19, font_weight = id and 700 or 500,
            color = function() return id and C.onSurface or C.onSurfaceVariant end,
          },
          kit.text {
            text = label, font_size = theme.size.small,
            color = function() return C.onSurfaceVariant end,
          },
        },
      }
    end
    local question = row.question or row.description or ""
    return kit.action {
      id = "launcher-row-" .. entry.key,
      width = WIDTH - 2 * PAD, height = HERO, cursor = "pointer",
      enter = { opacity = 0, scale = 0.97, duration = theme.duration.small, easing = theme.ease.standard_decel },
      on_clicked = function() M.activate(row) end,
      box(0, question, row.material == "currency_exchange" and "Amount" or "Question"),
      kit.icon("arrow_forward", 26, function() return C.onSurfaceVariant end, {
        x = box_w + 15, y = (HERO - 26) / 2,
      }),
      box(box_w + 56, row.name, "Return copies it", "launcher-answer"),
    }
  end

  -- An ordinary row, rebindable: scrolled out of sight, the list view
  -- hands it the row scrolling in rather than building another.
  local serial = 0
  local function plain_row(entry)
    serial = serial + 1
    local bound = { entry = entry, row = row_of(entry) or entry }
    local revision = morf.signal("caelestia.launcher.row." .. serial, 0)
    local function now() revision:get() return bound.row end
    local icon = row_icon(bound.row)
    local icon_box = ui.Item { width = 32, height = 32, icon }
    local area = kit.action {
      id = "launcher-row-" .. entry.key,
      enter = { opacity = 0, scale = 0.96, duration = theme.duration.small, easing = theme.ease.standard_decel },
      width = WIDTH - 2 * PAD, height = ROW, cursor = "pointer",
      on_entered = function()
        for i = 1, M.results:len() do
          if M.results:get(i).key == bound.entry.key then M.selected:set(i) end
        end
      end,
      on_clicked = function() M.activate(bound.row) end,
      ui.Row {
        anchors = { left = true, left_margin = 12 }, y = (ROW - 32) / 2, gap = 13, align = "center",
        icon_box,
        ui.Column {
          gap = 3,
          kit.text { id = "launcher-name", text = function() return tostring(now().name or "") end, font_size = theme.size.larger,
            color = function() return C.onSurface end },
          kit.text {
            text = function() return tostring(now().description or "") end, font_size = theme.size.smaller,
            color = function() return C.onSurfaceVariant end,
            width = function() return WIDTH - 2 * PAD - 80 - (now().current and 30 or 0) end, elide = "right",
          },
        },
      },
      kit.icon("check", 22, function() return C.primary end, {
        anchors = { right = true, right_margin = 16, vertical_center = true },
        visible = function() return now().current and true or false end,
      }),
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

  local function delegate(entry)
    if entry.kind == "header" then return header(entry) end
    if entry.kind == "hero" then return hero(entry) end
    local row = row_of(entry) or entry
    local body
    if row.kind == "calc" then
      -- One line: the expression and its answer, and a button that copies
      -- the answer.
      body = {
        ui.Row {
          anchors = { left = true, left_margin = 12 }, y = (ROW - 32) / 2, gap = 17, align = "center",
          row_icon(row),
          kit.text {
            id = "launcher-calc", text = row.name, font_size = theme.size.normal + 1,
            width = WIDTH - 2 * PAD - 150, elide = "right",
            color = function() return row.failed and C.onSurfaceVariant or C.onSurface end,
          },
        },
        kit.hover(kit.action {
          id = "launcher-calc-copy",
          anchors = { right = true, right_margin = 12, vertical_center = true },
          width = 54, height = 44, cursor = "pointer",
          visible = not row.failed,
          on_clicked = function() M.activate(row) end,
          kit.icon("open_in_new", 24, function() return C.onTertiaryContainer end, { anchors = { center_in = true } }),
        }, function(hovered)
          return hovered and C.tertiaryContainer:mix(C.onTertiaryContainer, 0.08) or C.tertiaryContainer
        end, 12),
      }
    else
      return plain_row(entry)
    end
    local area = kit.action {
      id = "launcher-row-" .. entry.key,
      enter = { opacity = 0, scale = 0.96, duration = theme.duration.small, easing = theme.ease.standard_decel },
      exit = { opacity = 0, scale = 0.96, duration = 150, easing = theme.ease.standard_accel },
      width = WIDTH - 2 * PAD, height = ROW, cursor = "pointer",
      on_entered = function()
        for i = 1, M.results:len() do
          if M.results:get(i).key == entry.key then M.selected:set(i) end
        end
      end,
      on_clicked = function() M.activate(row) end,
      kit.surface {
        anchors = { fill = true },
        radius = 14,
        -- The selection is drawn once, under the rows (the highlight below).
        color = function()
          if row.kind == "calc" then return C.surfaceContainer end
          return C.onSurface:alpha(0)
        end,
        behavior = { color = { duration = theme.duration.small } },
      },
      table.unpack(body),
    }
    return area
  end

  -- --------------------------------------------------------------- carousel --

  local MAX_SLOTS = 64

  -- The slots are a window on the wallpapers that follows the chosen one,
  -- so a folder of more than MAX_SLOTS still reaches its last picture.
  local function offset()
    local count = M.wall_count:get()
    return math.max(0, math.min(M.selected:get() - MAX_SLOTS // 2, count - MAX_SLOTS))
  end

  local function carousel()
    local slots = {}
    for i = 1, MAX_SLOTS do
      local function index() return offset() + i end
      local function wall() return index() <= M.wall_count:get() and M.walls[index()] or nil end
      local function on() return M.selected:get() == index() end
      -- Only pictures near the chosen one are loaded.
      local function near() return math.abs(M.selected:get() - index()) <= 4 end
      local motion = { duration = theme.duration.normal, easing = theme.ease.emphasized_decel }
      local slot
      slot = kit.action {
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
          anchors = { horizontal_center = true }, gap = 6, align = "center",
          y = function() return on() and 14 or 32 end,
          behavior = { y = motion },
          kit.surface {
            radius = 10, clip = true,
            width = function() return on() and 280 or 224 end,
            height = function() return on() and 158 or 126 end,
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
            font_size = function() return on() and theme.size.normal + 1 or theme.size.small end,
            font_weight = 500,
            width = function() return on() and 280 or 224 end,
            horizontal_alignment = "center", elide = "right",
          },
        },
      }
      kit.hover(slot, function(hovered)
        if on() then return C.onSurface:alpha(0.07) end
        return hovered and C.onSurface:alpha(0.04) or C.onSurface:alpha(0)
      end, 12)
      slots[i] = slot
    end
    local row = ui.Row {
      gap = 0,
      translate_x = function()
        local sel = math.max(1, M.selected:get() - offset())
        return (wide_width() - 2 * PAD) / 2 - ((sel - 1) * SLOT + SLOT_ON / 2)
      end,
      behavior = { translate_x = { duration = theme.duration.normal, easing = theme.ease.emphasized_decel } },
      table.unpack(slots),
    }
    return ui.Item {
      id = "launcher-wallpapers",
      x = PAD, y = SEARCH + PAD, width = function() return wide_width() - 2 * PAD end, height = CAROUSEL, clip = true,
      visible = wide,
      row,
      kit.text {
        anchors = { center_in = true }, text = "No wallpapers in ~/Pictures/Wallpapers",
        font_size = theme.size.larger, color = function() return C.onSurfaceVariant end,
        visible = function() return M.wall_count:get() == 0 end,
      },
    }
  end

  -- A kit TextField; the launcher draws its own clear button.
  local field_node, field = kit.text_field("search", {
    id = "launcher-search", clear = false,
    tab_navigation = false,
    height = SEARCH,
    anchors = { left = true, right = true, left_margin = 56, right_margin = 52 },
    vertical_alignment = "center",
    font_family = theme.font, font_size = 21,
    color = function() return C.onSurface end,
    placeholder = "Search apps, files, the web, windows…",
    placeholder_color = function() return C.onSurfaceVariant end,
    caret_color = function() return C.onSurface end,
    selection_color = function() return C.primary:alpha(0.4) end,
    on_text_changed = function(text) M.query:set(text) end,
    on_accepted = function() M.activate(M.chosen()) end,
    on_escape = M.escape,
    on_key_pressed = M.key,
    on_key_released = M.release,
  })
  local clear
  clear = kit.action {
    id = "launcher-clear",
    width = 36, height = 36, cursor = "pointer",
    anchors = { right = true, right_margin = 12, top = true, top_margin = (SEARCH - 36) / 2 },
    visible = function() return M.query:get() ~= "" end,
    on_clicked = function() field.text = "" M.query:set("") end,
    kit.icon("close", 20, function() return C.onSurfaceVariant end, { anchors = { center_in = true } }),
  }

  local empty = ui.Row {
    id = "launcher-empty",
    anchors = { center_in = true }, gap = 14, align = "center",
    visible = function() return M.count:get() == 0 end,
    kit.icon("manage_search", 40, function() return C.onSurfaceVariant end),
    ui.Column {
      gap = 0,
      kit.text { text = "No results", font_size = theme.size.large, color = function() return C.onSurface end },
      kit.text {
        text = "Try searching for something else", font_size = theme.size.larger,
        color = function() return C.onSurfaceVariant end,
      },
    },
  }

  -- The selection: the theme's highlight under the rows, riding an item
  -- that springs from row to row rather than a highlight that jumps.
  local scroll = morf.signal("caelestia.launcher.scroll", 0)
  morf.effect("caelestia.launcher.scroll", function()
    local count = M.results:len()
    if wide() or count == 0 then if scroll:get() ~= 0 then scroll:set(0) end return end
    local at = math.max(1, math.min(M.selected:get(), count))
    local top, h = entry_span(at)
    local before = at > 1 and M.results:get(at - 1) or nil
    if before and before.kind == "header" then top = entry_span(at - 1) end
    local view, now = view_height(), scroll:get()
    local next_scroll = now
    if top < now then next_scroll = top end
    if select(1, entry_span(at)) + h > now + view then next_scroll = select(1, entry_span(at)) + h - view end
    next_scroll = math.max(0, math.min(next_scroll, math.max(0, list_height() - view)))
    if next_scroll ~= now then scroll:set(next_scroll) end
  end)

  -- The rows: the engine's list view, virtualised by each row's height and
  -- recycling within a kind (the rows are the model's; the choosing is the
  -- launcher's kit Collection), scrolled by the effect above.
  M.row_heights = { header = HEADER + ROW_GAP, hero = HERO + ROW_GAP, row = ROW + ROW_GAP }
  local list = ui.ListView {
    id = "launcher-list", model = M.results, delegate = delegate, width = WIDTH - 2 * PAD, height = 1,
    item_extent = ROW + ROW_GAP, size_field = "height", kind_field = "kind", overscan = 3,
  }
  morf.effect("caelestia.launcher.list", function()
    local y = scroll:get()
    -- Its height first: the rows it builds are the ones that fit.
    list.height = view_height()
    morf.sync_view(list, y)
  end, { owner = list })

  local highlight = ui.Item {
    id = "launcher-highlight",
    x = 0, width = WIDTH - 2 * PAD,
    y = function() return (entry_span(math.max(1, M.selected:get()))) - scroll:get() end,
    height = function() local _, h = entry_span(math.max(1, M.selected:get())) return h end,
    behavior = { y = kit.spring(380, 26), height = kit.spring(380, 26) },
    visible = function() return M.count:get() > 0 end,
  }
  local selection = kit.selection {
    id = "launcher-selection", track = highlight, radius = kit.round(12),
    color = function() return C.onSurface:alpha(0.15) end,
  }

  results = ui.Item {
    id = "launcher-results",
    y = SEARCH + PAD, width = WIDTH - 2 * PAD,
    anchors = { horizontal_center = true },
    height = view_height,
    visible = function() return not wide() end,
    clip = true,
    selection,
    highlight,
    list,
    empty,
  }

  -- The bar at the foot: what is being searched, and what Return and Tab do.
  local function key_hint(key, label)
    return ui.Row {
      gap = 6, align = "center",
      kit.text { text = label, font_size = theme.size.small, color = kit.ink("lo") },
      kit.keycap { text = key, height = 22 },
    }
  end
  -- Tab's hint, there only while the chosen row has other actions.
  local tab_hint = key_hint("Tab", "Actions")
  tab_hint.visible = function()
    local sel = row_of(M.results:get(M.selected:get()))
    return sel ~= nil and sel.actions ~= nil and M.acting:get() == ""
  end
  -- The keys at the right; the prefixes at the left take what room they
  -- leave (every theme's face is a different width).
  local keys = ui.Row {
    anchors = { right = true, right_margin = 12, vertical_center = true }, gap = 14, align = "center",
    key_hint("↵", "Open"),
    tab_hint,
    key_hint("esc", function() return M.acting:get() ~= "" and "Back" or "Close" end),
  }
  local mode = kit.label { text = function() return (mode_name()) end, font_size = theme.size.small,
    font_weight = 600, color = kit.ink("hi") }
  -- The search prefixes, most useful first. Each run of them is measured
  -- in the theme's face once; the footer shows the longest run that fits
  -- and drops the later prefixes whole rather than cutting one short.
  local PREFIXES = { "= calc", "/ files", "? web", "@ windows", "! system", ": emoji" }
  local runs, measures = {}, {}
  for i = 1, #PREFIXES do
    runs[i] = table.concat(PREFIXES, "   ", 1, i)
    measures[i] = kit.text { text = runs[i], font_size = theme.size.small, opacity = 0 }
  end
  local function prefix_room()
    return math.max(0, width() - 16 - 26 - (mode.layout_width or 60) - 8 - (keys.layout_width or 220) - 12 - 12)
  end
  local function prefix_run()
    local room, best = prefix_room(), 1
    for i = 1, #runs do
      if (measures[i].layout_width or math.huge) <= room then best = i end
    end
    return best
  end
  local footer = ui.Item {
    id = "launcher-footer",
    anchors = { left = true, right = true, bottom = true }, height = FOOTER,
    kit.surface { anchors = { left = true, right = true, top = true }, height = 1, color = kit.stroke("quiet") },
    ui.Row {
      anchors = { left = true, left_margin = 16, vertical_center = true }, gap = 8, align = "center",
      kit.icon(function() return select(2, mode_name()) end, 18, kit.ink("accent")),
      mode,
      kit.text {
        id = "launcher-prefixes", elide = "right",
        width = function()
          return math.min(prefix_room(), (measures[prefix_run()].layout_width or 0) + 2)
        end,
        text = function()
          if M.query:get() ~= "" or M.acting:get() ~= "" then return "" end
          return runs[prefix_run()]
        end,
        font_size = theme.size.small, color = kit.ink("lo"),
      },
    },
    keys,
    ui.Item { width = 0, height = 0, clip = true, table.unpack(measures) },
  }

  local content = ui.Item {
    anchors = { fill = true },
    -- The search, on top, in large type.
    ui.Item {
      id = "launcher-field",
      anchors = { left = true, right = true, top = true }, height = SEARCH,
      kit.icon("search", 24, function() return C.onSurfaceVariant end,
        { anchors = { left = true, left_margin = 20 }, y = (SEARCH - 24) / 2 }),
      field_node,
      clear,
    },
    kit.surface { anchors = { left = true, right = true }, y = SEARCH, height = 1, color = kit.stroke("quiet") },
    -- The results, down from the search, scrolled to keep the chosen row
    -- -- and its section's heading -- in view.
    results,
    carousel(),
    footer,
    kit.decor("corners", { length = 12, color = kit.stroke("mark") }) or ui.Item {},
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
