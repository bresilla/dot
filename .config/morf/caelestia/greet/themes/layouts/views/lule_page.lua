-- The Lule page, in the page template (themes/layouts/page.lua): a
-- Wallpaper, a Colors and an Appearance section, captions over cards, one
-- under the other (wallpaper and colours side by side on a page 1000 wide).
-- The settings frame draws the title; shell/lule_page.lua scrolls it.
local morf = require("morf")
local ui = require("morf.ui")
local kit = require("kit")
local theme = require("theme")
local C = theme.color
local P = require("themes.layouts.page")
local M = { WIDTH = 960, HEIGHT = 545 }
-- On a phone the wallpaper and colour cards stack, the page's width each,
-- over the control strip.
local responsive = require("responsive")
local COMPACT = responsive.compact()
if COMPACT then M.WIDTH = responsive.page_width() end
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
--- `width`: the page's own (a side panel's settings page is 400 or so);
--- without, the dashboard's. Under 1000 the cards stack; under 600 the
--- popups fit the page.
function M.build(state, width)
  local appearance = state.appearance
  local w = width or M.WIDTH
  local COMPACT = w < 1000
  local NARROW = w < 600
  local GAP, PAD, ROW, BH = P.GAP, P.PAD, P.ROW_GAP, P.BUTTON_H
  -- A section's height from its card's contents (a caption over it).
  local function section_h(items) return 16 + GAP / 2 + items + 2 * PAD end
  local function busy() return state.busy:get() or appearance.busy:get() end
  -- A button (P.button), dimmed and still while Lule works.
  local function button(spec)
    local action = spec.on_clicked
    spec.on_clicked = function() if not busy() then action() end end
    local node = P.button(spec)
    node.opacity = function() return busy() and 0.45 or 1 end
    return node
  end
  -- Buttons sharing `bw` evenly (P.buttons', each dimmed while busy).
  local function bar(bw, specs)
    local n, gap = #specs, 8
    local row = { gap = gap, align = "center" }
    for i, spec in ipairs(specs) do
      spec.width = spec.width or math.floor((bw - gap * (n - 1)) / n)
      row[i] = button(spec)
    end
    return ui.Row(row)
  end
  local function small(value, props)
    props = props or {}
    props.text, props.font_size, props.height = value, props.font_size or theme.size.small, props.height or 16
    props.color = props.color or kit.ink("lo")
    return kit.text(props)
  end

  -- ----------------------------------------------------------- widths --
  local left = COMPACT and w or math.floor((w - GAP) * 0.60)
  local right = COMPACT and w or w - left - GAP
  local li, ri, ci = P.inner(left), P.inner(right), P.inner(w)

  -- -------------------------------------------------------- wallpaper --
  local PV = math.max(160, math.min(260, math.floor(li * 0.45)))
  local PAGE_SIZE = 4
  local page_rows = morf.list_model({})
  morf.effect("caelestia.lule.page-rows", function()
    local files, page, out = state.files:get(), state.page:get(), {}
    for i = 1, PAGE_SIZE do
      local item = files[(page - 1) * PAGE_SIZE + i]
      if item then out[#out + 1] = { key = tostring(i), path = item.path, name = item.name, slot = i } end
    end
    page_rows:replace(out, "key")
  end)
  local list_w = li - 16
  local browser_node = kit.widgets.file_list { id = "lule-files", width = list_w, height = 116,
    rows = page_rows, row_height = 29, focus_policy = "tab",
    on_activated = function(i) local r = page_rows:get(i) if r then state.select(r.path) end end,
    delegate = function(row, s)
      local area
      local function now() return s.row() or row end
      area = kit.action { id = ("lule-file-%d"):format(row.slot), width = list_w, height = 26, cursor = "pointer",
        on_clicked = function() state.select(now().path) end,
        kit.icon("image", 16, kit.ink("accent"), { x = 8, y = 5 }),
        kit.menu_label { text = function() return now().name or "" end,
          x = 30, y = 5, width = list_w - 39, elide = "right", font_size = 12 },
      }
      kit.hover(area, function(hovered)
        return (hovered or s.current()) and C.primaryContainer or C.surfaceContainerHigh
      end, 8)
      return area, function(next_row) area.id = ("lule-file-%d"):format(next_row.slot) end
    end }
  -- The folder's images over the preview while browsing.
  local library = kit.card { id = "lule-browser", width = li, height = PV, radius = kit.round(P.RADIUS),
    color = function() return C.surfaceContainerHigh end, visible = function() return state.browsing:get() end,
    ui.Column { x = 8, y = 8, width = list_w, gap = 8,
      small(function() return #state.files:get() == 0 and "No images in this folder"
        or #state.files:get() .. " wallpapers · Choose a preview" end, { width = list_w, elide = "middle" }),
      ui.Item { width = list_w, height = 116, browser_node },
      ui.Row { gap = 8, align = "center",
        button { id = "lule-files-prev", label = "Back", icon = "chevron_left", height = 30,
          on_clicked = function() state.page_by(-1, PAGE_SIZE) end },
        button { id = "lule-files-next", label = "More", icon = "chevron_right", height = 30,
          on_clicked = function() state.page_by(1, PAGE_SIZE) end },
        small(function() return state.page:get() .. " / " .. math.max(1, math.ceil(#state.files:get() / PAGE_SIZE)) end),
      },
    },
  }
  local function step(id, icon, name, by, side)
    local b = kit.named(button { id = id, label = "", icon = icon, width = BH, on_clicked = function() state.step(by) end }, name)
    b.anchors = { [side] = true, [side .. "_margin"] = 10, vertical_center = true }
    return b
  end
  local preview = ui.Item { width = li, height = PV,
    kit.surface { anchors = { fill = true }, radius = kit.round(P.RADIUS), clip = true,
      color = function() return C.surfaceContainerLowest end,
      ui.Image { id = "lule-preview", anchors = { fill = true }, fill_mode = "preserve_aspect_crop",
        source = function() return state.preview:get() end },
      kit.decor("corners", { length = 10, color = kit.stroke("mark") }) or ui.Item {},
      ui.Column { anchors = { center_in = true }, align = "center", gap = 8,
        visible = function() return state.preview:get() == "" end,
        kit.icon("wallpaper", 32, kit.ink("accent")),
        small(function() return state.preview_error:get() ~= "" and "Preview unavailable"
          or state.selected:get() == "" and "Choose a wallpaper" or "Preparing preview…" end),
      },
    },
    step("lule-prev", "chevron_left", "Previous image", -1, "left"),
    step("lule-next", "chevron_right", "Next image", 1, "right"),
    library,
  }
  local name_row = ui.Item { width = li, height = 22,
    kit.menu_label { text = function() return basename(state.selected:get()) ~= "" and basename(state.selected:get()) or "Your wallpaper collection" end,
      anchors = { vertical_center = true }, width = li - 90, elide = "middle", font_size = 13, font_weight = 600 },
    kit.chip { anchors = { right = true, vertical_center = true }, width = 72,
      text = function()
        local scheme = state.scheme:get() or {}
        return state.selected:get() == scheme.wallpaper and "CURRENT" or "PREVIEW"
      end },
  }
  local field_node, field
  local use_folder = button { id = "lule-use-folder", label = "Use folder",
    on_clicked = function() state.set_folder(field.text) end }
  use_folder.anchors = { right = true, vertical_center = true }
  local function folder_w()
    local bw = use_folder.width
    if type(bw) == "function" then bw = bw() end
    return li - (bw or 110) - 8
  end
  field_node, field = kit.text_field("entry", { id = "lule-folder", width = function() return folder_w() - 20 end,
    height = 30, x = 10, y = 3,
    font_family = theme.font, font_size = 12, placeholder = "~/Pictures/Wallpapers",
    color = function() return C.onSurface end, placeholder_color = function() return C.onSurfaceVariant end,
    caret_color = function() return C.primary end, selection_color = function() return C.primary:alpha(0.25) end,
    on_text_changed = function(value) if state.folder_draft then state.folder_draft:set(value) end end,
    on_accepted = function(value) state.set_folder(value) end,
    on_escape = state.escape })
  morf.effect("caelestia.lule.folder-field", function() field.text = (state.folder_draft and state.folder_draft:get()) or state.folder:get() end)
  local folder_row = ui.Item { width = li, height = BH,
    kit.surface { width = folder_w, height = BH, radius = kit.round(10),
      color = function() return C.surfaceContainerHighest end, field_node,
      kit.decor("corners", { length = 5, color = kit.stroke("mark") }) },
    use_folder,
  }
  -- The three actions in a row; on a card too narrow for all three
  -- labels, the primary one takes a row of its own under the other two.
  local SPLIT = li < 460
  local actions = {
    { id = "lule-browse", label = "Images", icon = "folder_open", on_clicked = state.browse },
    { id = "lule-shuffle", label = "Shuffle", icon = "shuffle", on_clicked = state.shuffle },
  }
  local random = { id = "lule-random-apply", label = "Random & apply", icon = "auto_awesome", tone = "primary",
    on_clicked = state.random_apply }
  local wallpaper_items = PV + 22 + BH + BH + 3 * ROW
  local wall = { id = "lule-wallpaper", caption_id = "lule-wallpaper-heading", width = left, title = "Wallpaper",
    preview, name_row, folder_row }
  if SPLIT then
    wall[#wall + 1] = bar(li, actions)
    random.width = li
    wall[#wall + 1] = button(random)
    wallpaper_items = wallpaper_items + BH + ROW
  else
    actions[3] = random
    wall[#wall + 1] = bar(li, actions)
  end
  local wallpaper = P.section(wall)
  local WALL_H = section_h(wallpaper_items)

  -- ----------------------------------------------------------- colours --
  local color = state.color
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
  local picked = morf.signal("caelestia.lule.picked", "")
  local function grid(id, entries, columns, cell_w, cell_h, gap, name)
    return kit.widgets.swatch_grid { id = id, accessible_name = name, items = entries, columns = columns, gap = gap,
      item_width = cell_w, item_height = cell_h, press_activates = true, current = 0,
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
  -- Sixteen swatches four by four over the three named ones.
  local CELL, CG = 42, 6
  local SW_H = 5 * CELL + 3 * CG + 14
  local swatches = ui.Item { width = ri, height = SW_H,
    grid("lule-colors", numbered, 4, (ri - 3 * CG) / 4, CELL, CG, "Terminal colours"),
    ui.Item { y = 4 * CELL + 3 * CG + 14, grid("lule-named", named, 3, (ri - 2 * CG) / 3, CELL, CG, "Theme colours") },
  }
  local picking = morf.signal("caelestia.lule.picking", false)
  local terminal = {}
  for n = 0, 15 do terminal[#terminal + 1] = function() return color(n) end end
  local picker_node, picker_handle
  picker_node, picker_handle = require("lib.kit.composites").colour_picker { id = "lule", width = ri, height = SW_H,
    swatches = terminal, swatch_size = 18,
    value = function() return picked:get() end,
    trailing = button { id = "lule-picker-copy", label = "Copy", icon = "content_copy",
      on_clicked = function() state.copy(picker_handle.value()) end } }
  local picker = ui.Item { width = ri, height = SW_H, visible = function() return picking:get() end, picker_node }
  swatches.visible = function() return not picking:get() end
  local colors = P.section { id = "lule-colors", caption_id = "lule-colors-heading", width = right, title = "Colors",
    bar(ri, {
      { id = "lule-view-swatches", label = "Swatches", group = "lule-view",
        selected = function() return not picking:get() end, on_clicked = function() picking:set(false) end },
      { id = "lule-view-picker", label = "Picker", group = "lule-view",
        selected = function() return picking:get() end, on_clicked = function() picking:set(true) end },
    }),
    ui.Item { width = ri, height = SW_H, swatches, picker } }
  local COLORS_H = section_h(BH + ROW + SW_H)

  -- ---------------------------------------------------------- controls --
  -- A caption and its buttons: the card's groups, 62 high.
  local GROUP_H = 62
  local function group(id, title, node)
    return ui.Item { width = ci, height = GROUP_H,
      small(title, { id = id, width = ci }), ui.Item { y = 20, width = ci, height = BH, node } }
  end
  local modes, methods, styles = {}, {}, {}
  for _, mode in ipairs { "dark", "light" } do
    modes[#modes + 1] = { id = "lule-mode-" .. mode, label = mode == "dark" and "Dark" or "Light",
      icon = mode == "dark" and "dark_mode" or "light_mode", group = "lule-mode",
      on_clicked = function() state.set_mode(mode) end, selected = function() return state.mode:get() == mode end }
  end
  for _, method in ipairs { "pigment", "median", "histogram", "tonal" } do
    methods[#methods + 1] = { id = "lule-method-" .. method, label = (method:gsub("^%l", string.upper)),
      group = "lule-method", on_clicked = function() state.set_method(method) end,
      selected = function() return state.method:get() == method end }
  end
  for _, style in ipairs { { "material", "Material" }, { "tsugumori", "Tsugumori" } } do
    styles[#styles + 1] = { id = "lule-theme-" .. style[1], label = style[2], group = "lule-theme",
      on_clicked = function() appearance.request(style[1]) end,
      selected = function() return require("themes").current.id == style[1] end }
  end
  local font = button { id = "lule-font", icon = "expand_more", width = ci,
    label = function() local name = require("themes").font return name and name ~= "" and name or "Theme default" end,
    on_clicked = function() require("themes.fonts").open() end }
  local apply = button { id = "lule-apply", tone = "primary", width = ci,
    label = function() return busy() and state.busy:get() and "Applying…" or "Apply wallpaper & colors" end,
    on_clicked = state.apply }
  local status = kit.subtitle { id = "lule-status", width = ci, height = 32, wrap = true, font_size = 12,
    text = function() return appearance.message:get() ~= "" and appearance.message:get() or state.message:get() end,
    color = function() return state.failed:get() and C.error or C.onSurfaceVariant end }
  local controls = P.section { id = "lule-controls", width = w, title = "Appearance",
    group("lule-appearance-title", "Mode", bar(ci, modes)),
    group("lule-method-title", "Palette method", bar(ci, methods)),
    group("lule-theme-title", "Shell theme", bar(ci, styles)),
    group("lule-font-title", "Font", font),
    apply, status }
  local CONTROLS_H = section_h(4 * GROUP_H + BH + 32 + 5 * ROW)

  -- -------------------------------------------------------------- page --
  local top = COMPACT and ui.Column { width = w, gap = GAP, wallpaper, colors }
    or ui.Row { width = w, gap = GAP, wallpaper, colors }
  local TOP_H = COMPACT and WALL_H + GAP + COLORS_H or math.max(WALL_H, COLORS_H)
  local HEIGHT = TOP_H + GAP + CONTROLS_H + GAP
  -- The Font button's y on the page: the font picker opens over it.
  local font_y = TOP_H + GAP + 16 + GAP / 2 + PAD + 3 * (GROUP_H + ROW) + 20
  -- The picker sits over the page; on a page between 600 and 1000 wide it
  -- is laid out for a narrow one, centred.
  local picker_w = (NARROW or not COMPACT) and w or 599
  local fonts = require("themes.layouts.font_picker")(state, picker_w, COMPACT and font_y or nil)
  local overlay = ui.Item { x = math.floor((w - picker_w) / 2), width = picker_w, height = HEIGHT, z = 100, fonts }
  return { page = ui.Item { id = "lule-page", width = w, height = HEIGHT,
    ui.Column { width = w, gap = GAP, top, controls }, overlay }, width = w, height = HEIGHT }
end
return M
