-- Compact dashboard layout: wallpaper and palette above one control strip.
local morf = require("morf")
local ui = require("morf.ui")
local kit = require("kit")
local theme = require("theme")
local C = theme.color
local M = { WIDTH = 960, HEIGHT = 545 }
local function text(value, props)
  props = props or {} props.text = value
  return kit.text(props)
end
local function label(value, props)
  props = props or {} props.font_size = props.font_size or 12
  props.color = props.color or function() return C.onSurfaceVariant end
  props.text = value
  return kit.subtitle(props)
end
local function basename(path) return path:match("([^/]+)$") or path end
function M.build(state)
  local appearance=state.appearance
  local w,h=M.WIDTH,function() return M.HEIGHT end
  -- A button; with a `group`, one of a segmented choice (a kit Press in an
  -- exclusive group: one chosen, the arrows walk them).
  local function button(id, title, icon, width, action, selected, height, group)
    local node = kit.pill { id = id, label = title, icon = icon, width = width, height = height or 32,
      checkable = group ~= nil or nil, group = group, checked = group and selected or nil,
      on_clicked = function() if not state.busy:get() and not appearance.busy:get() then action() end end,
      color = function() return selected and selected() and C.primary or C.surfaceContainerHighest end,
      ink = function() return selected and selected() and C.onPrimary or C.onSurface end }
    node.opacity = function() return (state.busy:get() or appearance.busy:get()) and 0.45 or 1 end
    return node
  end
  local GAP, PAD, TOP = 12, 16, 354
  local left = math.floor((w - GAP) * 0.60)
  local right = w - left - GAP
  local inner = right - 2 * PAD
  local color = state.color
  -- A swatch's face, the entry of a swatch grid (a kit Selection: the
  -- arrows walk the colours, a press or Return copies one).
  local function face(caption, value, s)
    local function ink() return morf.color(value()):text_color() end
    return ui.Item { anchors = { fill = true },
      kit.surface { anchors = { fill = true }, radius = function() return s.hovered() and 9 or 14 end,
        color = function() return morf.color(value()) end,
        behavior = { radius = kit.spring(420, 24), color = { duration = 220 } },
        text(caption, { x = 8, y = 5, font_size = 10, font_weight = 600, color = ink }),
        text(value, { x = 8, y = 22, font_size = 11, color = ink }),
      },
      (function()
        local mark = kit.decor("corners", { length = 5, color = function() return ink():alpha(0.8) end })
        if mark then mark.visible = function() return s.hovered() or s.current() end return mark end
        return ui.Item {}
      end)(),
    }
  end
  -- The colour last chosen in either grid, for the picker to start from.
  local picked = morf.signal("caelestia.lule.picked", "")
  local function grid(id, entries, columns, width, height, gap, name)
    return kit.widgets.swatch_grid { id = id, accessible_name = name, items = entries, columns = columns, gap = gap,
      item_width = width, item_height = height, press_activates = true, current = 0,
      item_id = function(_, entry) return entry.id end,
      delegate = function(_, entry, s) return face(entry.caption, entry.value, s) end,
      on_current_changed = function(i) picked:set(entries[i].value()) end,
      on_activated = function(i) state.copy(entries[i].value()) end }
  end
  local numbered = {}
  for n = 0, 15 do
    numbered[#numbered + 1] = { id = "lule-color-" .. n, caption = string.format("%02d", n),
      value = function() return color(n) end }
  end
  local named = {}
  for _, entry in ipairs { { "background", "Background" }, { "foreground", "Text" }, { "cursor", "Cursor" } } do
    named[#named + 1] = { id = "lule-" .. entry[1], caption = entry[2], value = function() return color(entry[1]) end }
  end
  local swatches = ui.Item { x = PAD, y = 47, width = inner, height = 287,
    grid("lule-colors", numbered, 4, (inner - 18) / 4, 50, 6, "Terminal colours"),
    ui.Item { y = 238, grid("lule-named", named, 3, (inner - 12) / 3, 49, 6, "Theme colours") },
  }

  -- The picker: any colour (the kit's colour picker: a Plane of saturation
  -- and value under a hue slider, the hex, the terminal colours as
  -- swatches), starting from the swatch last chosen.
  local picking = morf.signal("caelestia.lule.picking", false)
  local terminal = {}
  for n = 0, 15 do terminal[#terminal + 1] = function() return color(n) end end
  local picker_handle
  local picker_node
  picker_node, picker_handle = require("lib.kit.composites").colour_picker { id = "lule", width = inner, height = 287,
    swatches = terminal, swatch_size = 18,
    value = function() return picked:get() end,
    trailing = button("lule-picker-copy", "Copy", "content_copy", 100,
      function() state.copy(picker_handle.value()) end) }
  local picker = ui.Item { x = PAD, y = 47, width = inner, height = 287,
    visible = function() return picking:get() end, picker_node }
  swatches.visible = function() return not picking:get() end
  local folder_w = left - 2 * PAD - 212
  local field_node, field = kit.text_field("entry", { id = "lule-folder", width = folder_w - 20, height = 30, x = 10,
    font_family = theme.font, font_size = 12, placeholder = "~/Pictures/Wallpapers",
    color = function() return C.onSurface end, placeholder_color = function() return C.onSurfaceVariant end,
    caret_color = function() return C.primary end, selection_color = function() return C.primary:alpha(0.25) end,
    on_text_changed = function(value) if state.folder_draft then state.folder_draft:set(value) end end,
    on_accepted = function(value) state.set_folder(value) end,
    on_escape = state.escape })
  morf.effect("caelestia.lule.folder-field", function() field.text = (state.folder_draft and state.folder_draft:get()) or state.folder:get() end)
  local use_folder = button("lule-use-folder", "Use folder", nil, 96,
    function() state.set_folder(field.text) end, nil, 30)
  use_folder.x, use_folder.y = left - PAD - 96, 275
  local PAGE_SIZE = 4
  -- The folder's images, a page at a time, as a kit Collection (a file
  -- list): its rows are rebound as the page turns, not built again.
  local page_rows = morf.list_model({})
  morf.effect("caelestia.lule.page-rows", function()
    local files, page, out = state.files:get(), state.page:get(), {}
    for i = 1, PAGE_SIZE do
      local item = files[(page - 1) * PAGE_SIZE + i]
      if item then out[#out + 1] = { key = tostring(i), path = item.path, name = item.name, slot = i } end
    end
    page_rows:replace(out, "key")
  end)
  local browser_node = kit.widgets.file_list { id = "lule-files", width = left - 2 * PAD - 16, height = 116,
    rows = page_rows, row_height = 29, focus_policy = "tab",
    on_activated = function(i) local r = page_rows:get(i) if r then state.select(r.path) end end,
    delegate = function(row, s)
      local area
      local function now() return s.row() or row end
      area = kit.action { id = ("lule-file-%d"):format(row.slot), width = left - 2 * PAD - 16, height = 26, cursor = "pointer",
        on_clicked = function() state.select(now().path) end,
        kit.icon("image", 16, kit.ink("accent"), { x = 8, y = 5 }),
        kit.menu_label { text = function() return now().name or "" end,
          x = 30, y = 5, width = left - 2 * PAD - 55, elide = "right", font_size = 12 },
      }
      kit.hover(area, function(hovered)
        return (hovered or s.current()) and C.primaryContainer or C.surfaceContainerHigh
      end, 8)
      return area, function(next_row) area.id = ("lule-file-%d"):format(next_row.slot) end
    end }
  local library = kit.card { id = "lule-browser", x = PAD, y = 44, width = left - 2 * PAD, height = 227,
    radius = 18, color = function() return C.surfaceContainer end, visible = function() return state.browsing:get() end,
    ui.Column { x = 8, y = 8, width = left - 2 * PAD - 16, gap = 5,
      label(function() return #state.files:get() == 0 and "No images in this folder"
        or #state.files:get() .. " wallpapers · Choose a preview" end,
        { width = left - 2 * PAD - 16, height = 15, elide = "middle", font_size = 11 }),
      ui.Item { width = left - 2 * PAD - 16, height = 116, browser_node },
      ui.Row { gap = 8,
        button("lule-files-prev", "Back", "chevron_left", 80,
          function() state.page_by(-1,PAGE_SIZE) end, nil, 26),
        button("lule-files-next", "More", "chevron_right", 80,
          function() state.page_by(1,PAGE_SIZE) end, nil, 26),
        label(function() return state.page:get() .. " / " .. math.max(1, math.ceil(#state.files:get() / PAGE_SIZE)) end, { y = 6 }),
      },
    },
  }
  local left_card = kit.card { id = "lule-wallpaper-card", width = left, height = TOP, radius = 24,
    kit.heading { id = "lule-wallpaper-heading", text = "Wallpaper", x = PAD, y = 11, width = 190,
      font_size = 18, font_weight = 600, active = function() return state.active:get() end },
    kit.chip { anchors = { right = true, right_margin = PAD }, y = 17, width = 64,
      text = function()
        local scheme = state.scheme:get() or {}
        return state.selected:get() == scheme.wallpaper and "CURRENT" or "PREVIEW"
      end },
    kit.surface { x = PAD, y = 44, width = left - 2 * PAD, height = 199, radius = 18, clip = true,
      color = function() return C.surfaceContainerLowest end,
      ui.Image { id = "lule-preview", anchors = { fill = true }, fill_mode = "preserve_aspect_crop",
        source = function() return state.preview:get() end },
      kit.decor("corners", { length = 10, color = kit.stroke("mark") }) or ui.Item {},
      ui.Column { anchors = { center_in = true }, align = "center", gap = 8,
        visible = function() return state.preview:get() == "" end,
        kit.icon("wallpaper", 32, kit.ink("accent")),
        label(function() return state.preview_error:get() ~= "" and "Preview unavailable"
          or state.selected:get() == "" and "Choose a wallpaper" or "Preparing preview…" end),
      },
    },
    kit.menu_label { text = function() return basename(state.selected:get()) ~= "" and basename(state.selected:get()) or "Your wallpaper collection" end,
      x = PAD, y = 252, width = left - 2 * PAD, elide = "middle", font_size = 13, font_weight = 600 },
    kit.label { text = "Folder", x = PAD, y = 281, width = 104, height = 18, elide = "right",
      font_size = 11, vertical_alignment = "center", color = kit.ink("lo") },
    kit.surface { x = PAD + 110, y = 275, width = folder_w, height = 30, radius = 10,
      color = function() return C.surfaceContainerHighest end, field_node,
      kit.decor("corners", { length = 5, color = kit.stroke("mark") }) },
    use_folder,
    ui.Row { x = PAD, y = 313, gap = 6,
      button("lule-browse", "Images", "folder_open", 100, state.browse),
      button("lule-shuffle", "Shuffle", "shuffle", 100, state.shuffle),
      button("lule-random-apply", "Random & apply", "auto_awesome", left - 2 * PAD - 288, state.random_apply, function() return true end),
      kit.named(button("lule-prev", "", "chevron_left", 32, function() state.step(-1) end), "Previous image"),
      kit.named(button("lule-next", "", "chevron_right", 32, function() state.step(1) end), "Next image"),
    },
    library,
  }
  local palette_card = kit.card { id = "lule-colors-card", x = left + GAP, width = right, height = TOP, radius = 24,
    kit.heading { id = "lule-colors-heading", text = "Colors", x = PAD, y = 11, width = 110,
      font_size = 18, font_weight = 600, active = function() return state.active:get() end },
    ui.Row { anchors = { right = true, right_margin = PAD }, y = 10, gap = 6,
      button("lule-view-swatches", "Swatches", nil, 84, function() picking:set(false) end,
        function() return not picking:get() end, 26, "lule-view"),
      button("lule-view-picker", "Picker", nil, 84, function() picking:set(true) end,
        function() return picking:get() end, 26, "lule-view") },
    swatches, picker,
  }
  local mode_w, apply_w = 160, 200
  local methods_w = w - 2 * PAD - mode_w - apply_w - 24
  local modes = { x = PAD, y = 35, gap = 6 }
  for _, mode in ipairs { "dark", "light" } do
    modes[#modes + 1] = button("lule-mode-" .. mode, mode == "dark" and "Dark" or "Light",
      mode == "dark" and "dark_mode" or "light_mode", (mode_w - 6) / 2,
      function() state.set_mode(mode) end, function() return state.mode:get() == mode end, nil, "lule-mode")
  end
  local methods = { x = PAD + mode_w + 12, y = 35, gap = 6 }
  for _, method in ipairs { "pigment", "median", "histogram", "tonal" } do
    methods[#methods + 1] = button("lule-method-" .. method, method:gsub("^%l", string.upper), nil,
      (methods_w - 18) / 4, function() state.set_method(method) end, function() return state.method:get() == method end,
      nil, "lule-method")
  end
  local apply = button("lule-apply", function() return state.busy:get() and "Applying…" or "Apply wallpaper & colors" end,
    nil, apply_w, state.apply, function() return true end)
  apply.x, apply.y = w - PAD - apply_w, 35
  -- Three themes between the row's title and the font picker at 510.
  local styles={x=PAD+160+12,y=118,gap=8}
  local style_w=math.floor((510-12-styles.x-2*styles.gap)/3)
  for _,style in ipairs {{"material","Material"},{"tsugumori","Tsugumori"}} do
    styles[#styles+1]=button("lule-theme-"..style[1],style[2],nil,style_w,
      function() appearance.request(style[1]) end,
      function() return require("themes").current.id==style[1] end,34,"lule-theme")
  end
  local controls = kit.card { id = "lule-controls", y = TOP + GAP, width = w, height = function() return h() - TOP - GAP end, radius = 24,
    kit.heading { id = "lule-appearance-title", text = "Appearance", level = "caption", active = function() return state.active:get() end, x = PAD, y = 12, font_size = 12, color = function() return C.onSurfaceVariant end },
    kit.heading { id = "lule-method-title", text = "Palette method", level = "caption", active = function() return state.active:get() end, x = PAD + mode_w + 12, y = 12, font_size = 12, color = function() return C.onSurfaceVariant end },
    kit.subtitle { text = "Preview first, then apply", x = w - PAD - apply_w, y = 12, font_size = 12, color = function() return C.onSurfaceVariant end },
    ui.Row(modes), ui.Row(methods), apply,
    kit.heading {id="lule-theme-title",text="Shell theme",level="caption",x=PAD,y=129,font_size=12,
      active=function() return state.active:get() end,color=function() return C.onSurfaceVariant end},
    ui.Row(styles),
    kit.heading {id="lule-font-title",text="Font",level="caption",x=510,y=129,font_size=12,
      active=function() return state.active:get() end,color=function() return C.onSurfaceVariant end},
    ui.Item {x=582,y=118,width=362,height=34,
      button("lule-font",function() local name=require("themes").font return name and name~="" and name or "Theme default" end,
        "expand_more",362,function() require("themes.fonts").open() end,nil,34)},
    kit.subtitle { text = function() return appearance.message:get() ~= "" and appearance.message:get() or state.message:get() end, id = "lule-status", x = PAD, y = 79, width = w - 2 * PAD, height = 32,
      wrap = true, font_size = 12, color = function() return state.failed:get() and C.error or C.onSurfaceVariant end },
  }
  return {page=ui.Item { id = "lule-page", width = w, height = h, left_card, palette_card, controls,
    require("themes.layouts.font_picker")(state) }}
end
return M
