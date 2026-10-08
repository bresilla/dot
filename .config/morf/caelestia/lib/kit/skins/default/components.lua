-- The default kit's components: the contract's functions (lib.kit.contract)
-- drawn in an Adwaita-like style -- neutral greys, one blue accent, flat
-- controls with a quiet wash under the pointer, 6 px corners on controls
-- and 12 px on cards, cards outlined in light and raised in dark, nothing
-- that overshoots and nothing that moves at rest.
--
-- `theme` (built by init.lua): `P()` the live palette (morf colours),
-- `size`, `font`, `mono`, `icon_font`, `radius`, `ease`, `duration`,
-- `reduced` (motion off).
local morf = require("morf")
local ui = require("morf.ui")
local channel = require("lib.util.channel")

return function(theme)
  local M = {}
  local P = theme.P
  local function get(v) if type(v) == "function" then return v() end return v end
  local function clamp01(x)
    x = tonumber(x) or 0
    if x ~= x then return 0 end
    return x < 0 and 0 or (x > 1 and 1 or x)
  end
  --- The ink at the alpha the palette gives a state layer.
  local function wash(kind) return function() local p = P() return p.ink:alpha(p.wash[kind]) end end
  local function quick() return { duration = theme.duration.small, easing = theme.ease.standard } end
  local function settle() return { duration = theme.duration.normal, easing = theme.ease.standard } end
  M.wash = wash

  -- ---------------------------------------------------------- helpers --

  local function summary(list)
    local n, sum, peak = 0, 0, 0
    for _, v in ipairs(list or {}) do
      v = tonumber(v) or 0
      n, sum = n + 1, sum + v
      if v > peak then peak = v end
    end
    return (list and tonumber(list[#list])) or 0, n > 0 and sum / n or 0, peak
  end

  --- Bytes in binary units, one decimal under ten: "1.1", "MiB". `unit`
  --- forces one.
  function M.bytes(n, unit)
    n = tonumber(n) or 0
    local units = { "B", "KiB", "MiB", "GiB", "TiB", "PiB" }
    local i = 1
    if unit then
      for k, u in ipairs(units) do if u == unit then i = k end end
      n = n / 1024 ^ (i - 1)
    else
      while n >= 1024 and i < #units do n = n / 1024 i = i + 1 end
    end
    local text = (n < 10 and i > 1) and ("%.1f"):format(n) or ("%d"):format(math.floor(n + 0.5))
    return text, units[i]
  end

  local function sentence(s)
    s = tostring(s or "")
    return s:sub(1, 1):upper() .. s:sub(2)
  end

  local function glyphs(s)
    local ok, n = pcall(utf8.len, s)
    return ok and n or #s
  end

  -- ----------------------------------------------------- colour and ink --

  local SIGNAL = { accent = "accent", ok = "success", warn = "warning", alert = "error", info = "info", extra = "extra" }
  --- A status tone as a fill: `accent`, `ok`, `warn`, `alert`, `info`, `extra`.
  function M.signal(kind)
    local role = SIGNAL[kind or "accent"] or "accent"
    return function() return P()[role] end
  end
  --- The same tone as text on the window's ground.
  function M.signal_ink(kind)
    local role = SIGNAL[kind or "accent"] or "accent"
    return function() return P()[role .. "_ink"] end
  end

  function M.ink(kind)
    if kind == "lo" then return function() return P().ink_dim end end
    if kind == "accent" then return function() return P().accent_ink end end
    return function() return P().ink end
  end

  -- Lines: hairlines in the ink at a strength; high contrast draws them solid.
  local STROKE = { faint = 0.08, quiet = 0.14, idle = 0.22, mark = 0.45, hot = 1 }
  function M.stroke(strength, color)
    local a = assert(STROKE[strength or "idle"], "unknown stroke strength")
    return function()
      local p = P()
      if color then return get(color):alpha(strength == "hot" and 1 or math.min(1, a * 2)) end
      if strength == "hot" then return p.accent end
      if p.strong then return p.ink:alpha(math.min(1, a * 3)) end
      return p.ink:alpha(a)
    end
  end

  function M.level(value, warn, alert)
    warn, alert = warn or 70, alert or 90
    return function()
      local v = tonumber(get(value)) or 0
      local p = P()
      if v >= alert then return p.error end
      if v >= warn then return p.warning end
      return p.accent
    end
  end

  --- The ink on a `state_surface`: white on the accent while on.
  function M.state_ink(spec)
    return function()
      if spec.on and spec.on() == true then return P().on_accent end
      return get(spec.idle) or P().ink
    end
  end

  -- --------------------------------------------------------------- text --

  --- Text in the kit's face; `props` as a `ui.Text`'s.
  function M.text(props)
    props.font_family = props.font_family or theme.font
    props.font_size = props.font_size or theme.size.normal
    if props.color == nil then props.color = function() return P().ink end end
    return ui.Text(props)
  end

  --- A page's title (`level = "section"`: a group's), bold.
  function M.heading(props)
    local level = props.level == "section" and 2 or 1
    props.font_size = props.font_size or (level == 2 and theme.size.larger or theme.size.large)
    props.font_weight = props.font_weight or (level == 2 and 700 or 800)
    if props.ink then props.color = props.color or props.ink end
    props.active, props.reveal_delay, props.scope, props.level, props.ink = nil, nil, nil, nil, nil
    props.decode_lead, props.decode_stagger, props.viewport = nil, nil, nil
    props.accessible_role, props.accessible = "heading", { level = level }
    return M.text(props)
  end

  --- Secondary text: the dim ink.
  function M.subtitle(props)
    props.color = props.color or M.ink("lo")
    return M.text(props)
  end

  --- A preferences group's title: bold, the body size less one.
  function M.section_label(props)
    props.font_size = props.font_size or theme.size.smaller
    props.font_weight = props.font_weight or 700
    return M.text(props)
  end

  function M.menu_label(props)
    props.font_size = props.font_size or theme.size.normal
    return M.text(props)
  end

  --- A caption (units, small notes): the small size in the dim ink.
  function M.label(props)
    props.font_size = props.font_size or props.size or (theme.size.small - 1)
    props.size = nil
    props.color = props.color or M.ink("lo")
    props.height = props.height or math.ceil(props.font_size * 1.4)
    return M.text(props)
  end

  --- A big reading: `value` (fn -> string), `size`, `unit`, `color`.
  function M.readout(spec)
    local size = spec.size or theme.size.extra
    local row = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, gap = 4, align = "end",
      M.text { text = spec.value, font_size = size, font_weight = 700, color = spec.color or M.ink("hi"),
        height = math.ceil(size * 1.15) },
    }
    if spec.unit then
      row[#row + 1] = M.label { text = spec.unit, size = math.max(10, math.floor(size * 0.42)),
        color = spec.unit_color or M.ink("lo") }
    end
    return ui.Row(row)
  end

  --- The default kit prints no decorative codes.
  function M.code() return "" end

  --- A state word: said plainly.
  function M.term(_, plain) return plain end

  --- A symbolic icon by name (`"wifi_off"`), in the icon face; `props.fill`
  --- (a boolean or a binding) fills it in.
  function M.icon(name, size, color, props)
    props = props or {}
    props.text = name
    if props.accessible_name == nil and props.accessible_hidden == nil then props.accessible_hidden = true end
    props.font_family = theme.icon_font
    props.font_size = size or 16
    props.color = color or function() return P().ink end
    local fill = props.fill
    props.fill = nil
    props.axes = function()
      local on = fill
      if type(fill) == "function" then on = fill() end
      return { FILL = on and 1 or 0, wght = 400, GRAD = 0 }
    end
    return ui.Text(props)
  end

  --- A caption row across `width`: the caption bold, a dim note at the right.
  function M.caption(spec)
    local w = spec.width
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, width = w, height = 14,
      M.text { x = 0, y = -3, height = 20, text = spec.text, font_size = theme.size.small, font_weight = 700,
        color = spec.color and M.ink("hi") or M.ink("hi"), width = w - 130, elide = "right" },
      spec.note and M.label { anchors = { right = true }, y = -2, height = 18, text = spec.note,
        width = 124, horizontal_alignment = "right" } or nil,
    }
  end

  --- Property lines, as a boxed list: the label dim at the left, the value
  --- at the right, hairlines between. `rows` ({ label, value }), `width`,
  --- `row_h` (17), `label_w` (half).
  function M.facts(rows, width, row_h, label_w)
    row_h = row_h or 17
    label_w = label_w or math.floor(width * 0.5)
    local fs = math.min(theme.size.small, math.floor(row_h * 0.72))
    local ty = math.floor((row_h - fs * 1.3) / 2)
    local node = { width = width, height = #rows * row_h }
    for k, r in ipairs(rows) do
      local y = (k - 1) * row_h
      if k > 1 then
        node[#node + 1] = ui.Rect { y = y, width = width, height = 1, color = M.stroke("quiet") }
      end
      node[#node + 1] = M.text { x = 2, y = y + ty, text = (tostring(get(r[1]) or ""):gsub(":$", "")),
        font_size = fs, color = M.ink("lo"), width = label_w - 4, elide = "right" }
      node[#node + 1] = M.text { x = label_w, y = y + ty, text = r[2], font_size = fs,
        color = M.ink("hi"), width = width - label_w - 2, elide = "left", horizontal_alignment = "right" }
    end
    return ui.Item(node)
  end

  -- --------------------------------------------------------- containers --

  --- Non-interactive surfaces.
  M.surface = ui.Rect

  -- While a collector is set, a card is an item whose ground is a layer of
  -- a distance field the caller builds (`{ node, radius, color, shape }`).
  local collector
  function M.collect(list) collector = list end

  --- A card: 12 px corners; light, a white card on a hairline; dark, a
  --- lighter raised tone; high contrast, a solid outline.
  function M.card(props)
    props.radius = props.radius or theme.radius.large
    if props.color == nil then props.color = function() return P().card end end
    if not collector then
      if props.border_width == nil then
        props.border_width = function() local p = P() return (p.strong and 2) or (p.dark and 0) or 1 end
        props.border_color = props.border_color or function() return P().border end
      end
      return ui.Rect(props)
    end
    local radius, color = props.radius, props.color
    props.radius, props.color, props.border_width, props.border_color = nil, nil, nil, nil
    local node = ui.Item(props)
    local entry = { node = node, radius = radius, color = color }
    entry.shape = ui.SdfShape {
      shape = "box", radius = radius, track = node,
      operation = #collector == 0 and "union" or "smooth_union",
      fill_color = color,
    }
    collector[#collector + 1] = entry
    return node
  end

  --- An item centred in a box of `w` x `h`.
  function M.centred(w, h, child, props)
    props = props or {}
    props.width, props.height = w, h
    child.anchors = { center_in = true }
    props[#props + 1] = child
    return ui.Item(props)
  end

  --- No scroll-tracked effects to scope.
  function M.with_viewport(_, build) return build() end

  --- The strip a panel wears: the title bold, and when a status is given a
  --- dot in its colour with the word dim at the right. `width`, `title`,
  --- `status`, `color`. 22 high.
  function M.header(spec)
    local w = spec.width
    local color = spec.color or M.signal("accent")
    local has_status = spec.status ~= nil and spec.status ~= false
    local node = { id = spec.id, x = spec.x, y = spec.y, width = w, height = 22,
      M.text { x = 0, y = 0, height = 22, vertical_alignment = "center", text = spec.title or "",
        font_size = theme.size.normal, font_weight = 700, color = M.ink("hi"),
        width = has_status and w - 92 or w, elide = "right" },
    }
    if has_status then
      node[#node + 1] = ui.Row { anchors = { right = true, vertical_center = true }, gap = 6, align = "center",
        ui.Rect { width = 8, height = 8, radius = 4, color = color, behavior = { color = quick() } },
        M.text { text = function() return sentence(get(spec.status)) end, font_size = theme.size.small,
          color = M.ink("lo") },
      }
    end
    return ui.Item(node)
  end

  --- A framed region: a card with the header strip or a title. `width`,
  --- `height`, `title`, `header`, `status`, `color`, `radius`, children.
  function M.panel(spec)
    local w, h = spec.width, spec.height
    local node = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
      clip = spec.clip, visible = spec.visible,
      M.card { anchors = { fill = true }, radius = spec.radius or theme.radius.large },
    }
    local wn = get(w)
    if spec.header and type(wn) == "number" then
      node[#node + 1] = M.header { x = 14, y = 10, width = wn - 28, title = spec.title, status = spec.status,
        color = spec.color }
    elseif spec.title then
      node[#node + 1] = M.text { x = 14, y = 10, text = spec.title, font_size = theme.size.normal,
        font_weight = 700, color = spec.color or M.ink("hi") }
    end
    for _, child in ipairs(spec) do node[#node + 1] = child end
    return ui.Item(node)
  end

  --- A small tag: a pill in a tint of its colour, or `filled`. `text`,
  --- `color`, `width` (fits the text). 13 high.
  function M.chip(spec)
    local color = spec.color or M.signal("accent")
    local function word() return sentence(get(spec.text)) end
    local w = spec.width
    if w == nil then
      if type(spec.text) == "function" then w = function() return 12 + math.ceil(glyphs(word()) * 5.4) end
      else w = 12 + math.ceil(glyphs(word()) * 5.4) end
    end
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = 13,
      ui.Rect { anchors = { fill = true }, radius = 6.5,
        color = function()
          if spec.filled then return get(color) end
          return get(color):alpha(P().strong and 0.0 or 0.2)
        end,
        border_width = function() return (P().strong and not spec.filled) and 1 or 0 end,
        border_color = color },
      M.text { anchors = { center_in = true }, text = word, font_size = 9, font_weight = 700,
        color = spec.filled and function() return P().on_accent end
          or function() local p = P() return p.dark and get(color):mix(p.ink, 0.45) or get(color):mix(p.ink, 0.25) end },
    }
  end

  --- Decorations are not part of this style: the call is accepted and the
  --- box it asked for kept, empty.
  function M.decor(_, spec)
    if type(spec) ~= "table" then return nil end
    local w = spec.width or spec.length
    local h = spec.height or (spec.vertical and spec.length) or spec.size
    if w == nil and h == nil and spec.anchors == nil then return nil end
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h }
  end

  -- ----------------------------------------------------------- controls --

  --- Lets Tab reach `area` and draws the keyboard's ring on it while a
  --- keyboard put focus there: 2 px of the accent at half strength, just
  --- inside the edge, rounded as the control. Returns `area`.
  function M.focusable(area, radius)
    area.focus_policy = "tab"
    local ring = ui.Rect {
      anchors = { fill = true }, z = 50, color = "transparent",
      radius = radius or function() return math.min(theme.radius.small, (tonumber(area.height) or 0) / 2) end,
      border_width = 2, border_color = function() local p = P() return p.strong and p.focus or p.focus:alpha(0.6) end,
      visible = function() return area.visual_focus end,
    }
    ui.reparent(ring, area)
    return area
  end

  --- A pointer area that Tab reaches too.
  function M.action(props) return M.focusable(ui.MouseArea(props)) end

  --- Gives a MouseArea a background whose colour follows its hover:
  --- `color(hovered)`; `radius`.
  function M.hover(area, color, radius)
    local bg = ui.Rect {
      anchors = { fill = true }, z = -1, radius = radius or 0,
      color = function() return color(area.hovered) end,
      behavior = { color = quick() },
    }
    ui.reparent(bg, area)
    return area
  end

  local widgets = require("lib.kit.widgets")
  local function copy(spec)
    local out = {}
    for k, v in pairs(spec or {}) do out[k] = v end
    return out
  end

  --- A filled pill button (the suggested action): `label`, `icon`,
  --- `on_clicked`, `width`, `height` (34), `color`/`ink`.
  function M.pill(spec)
    local s = copy(spec)
    s.height = s.height or theme.control_height
    return widgets.suggested(s)
  end

  --- A switch: `on` (fn), `on_toggled(on)`.
  function M.switch(spec)
    local s = copy(spec)
    s.checked, s.on = spec.on, nil
    return widgets.switch(s)
  end

  --- A small flat icon toggle: `icon_on`, `icon_off`, `on` (fn; the error
  --- tone while on), `on_clicked`, `width`, `height`, `size`.
  function M.icon_button(spec) return widgets.icon(copy(spec)) end

  --- A slider: `id`, `width`, `height` (the bar's, 44), `value` (fn, 0..1),
  --- `set(v)`, `icon`, `label` (false hides the reading).
  function M.slider(spec)
    local s = copy(spec)
    s.bar_height = spec.height or 44
    s.height = function() return get(s.bar_height) + 8 end
    s.value, s.set = spec.value, nil
    s.on_moved = spec.set
    return widgets.slider(s)
  end

  --- The media position, and seeking it: `width`, `value` (fn, 0..1),
  --- `seek(v)`, `active` and `playing` (fns).
  function M.media_progress(spec)
    local s = copy(spec)
    s.height = 34
    s.id = s.id or "media-seek"
    s.on_moved, s.seek = spec.seek, nil
    return widgets.seek_bar(s)
  end

  --- A text field (a kit TextField): `widget` and the props of a
  --- `ui.TextInput`. Returns the control and the input inside it.
  function M.text_field(widget, props) return require("lib.kit.text_field").make(widget, props) end

  --- A scrolled view (a kit Scroll). Returns the control and the flickable.
  function M.scroll(props) return require("lib.kit.scroll").make("scroll_view", props) end

  --- The tab row, as libadwaita's view switcher: `id`, `tabs` (`{ key,
  --- name, icon | icon_build }`), `tab` (a signal, from 1), `width`,
  --- `height`, `pad`, `ids` (`"name"` or `"key"`), `growing`.
  function M.tabs(spec)
    local s = copy(spec)
    local order = morf.signal("kit.default." .. spec.id .. ".tab-order", {})
    local function shown()
      local o = order:get()
      if #o ~= #spec.tabs then o = {} for i = 1, #spec.tabs do o[i] = i end end
      return o
    end
    local function position(index)
      for p, i in ipairs(shown()) do if i == index then return p end end
      return index
    end
    s.items = function()
      local out = {}
      for p, i in ipairs(shown()) do out[p] = spec.tabs[i] end
      return out
    end
    s.tabs, s.tab = nil, nil
    s.current = function() return position(spec.tab:get()) end
    s.on_current_changed = function(p) spec.tab:set(shown()[p] or p) end
    s.on_reorder = function(p, step)
      local o = shown()
      local q = p + step
      if not o[q] then return end
      o[p], o[q] = o[q], o[p]
      order:set(o)
    end
    local by_name = spec.ids == "name"
    s.item_id = function(_, entry)
      return spec.id .. "-tab-" .. (by_name and entry.name:lower() or (entry.key or entry.name:lower()))
    end
    s.ids = nil
    s.id, s.tab_id = spec.id .. "-tabs", spec.id
    if spec.growing then
      s.width = nil
      s.anchors = { left = true, right = true, left_margin = spec.pad or 11, right_margin = spec.pad or 11 }
    end
    s.height = spec.height or 64
    s.width_of = spec.width
    return widgets.tabs(s)
  end

  --- A panel with the tab row along its top and the pages under it.
  function M.tabbed(spec) return require("lib.kit.skins.default.tabbed")(theme, M, spec) end

  --- A radius in the kit's measure from a Material one: small corners as
  --- they are, larger ones tightened towards Adwaita's 12-15.
  function M.round(r)
    r = tonumber(r) or 0
    if r <= 14 then return r end
    return 14 + (r - 14) * 0.3
  end

  --- The highlight under a list's chosen row: the selected wash in a box
  --- of a distance field riding `track`. `track`, `color`, `radius` (6),
  --- `stretch`, `id`, `anchors`, `z`.
  function M.selection(spec)
    local track = spec.track
    if track and spec.stretch ~= false and M.STRETCH then
      local ok, current = pcall(function() return track.stretch end)
      if ok and not current then track.stretch = spec.stretch or M.STRETCH end
    end
    return ui.Sdf { id = spec.id, x = spec.x, y = spec.y, width = spec.width, height = spec.height,
      anchors = spec.anchors or (spec.width == nil and { fill = true } or nil), z = spec.z or -1,
      ui.SdfShape { shape = "box", radius = spec.radius or theme.radius.small, track = track,
        fill_color = spec.color or wash("selected") },
    }
  end

  --- The ground of a stateful control (a quick-settings tile): a grey
  --- button while off, the accent while on, 12 px corners that do not
  --- change, a wash under the pointer and a deeper one pressed. `area`,
  --- `on` (fn), `height`, `tone` ("primary" the accent, "error" the
  --- destructive), `pressed` (fn), `id`.
  function M.state_surface(spec)
    local on = spec.on or function() return false end
    local function area() return get(spec.area) end
    local is_node = spec.area ~= nil and type(spec.area) ~= "function"
    local h = spec.height or (is_node and tonumber(spec.area.height)) or 56
    local function pressed()
      local a = area()
      return (a and a.pressed) or (spec.pressed and spec.pressed()) or false
    end
    local node = ui.Rect {
      id = spec.id, z = -1, anchors = spec.anchors or { fill = true },
      radius = math.min(theme.radius.large, h / 2),
      color = function()
        local p = P()
        local a = area()
        if on() then
          local base = spec.tone == "error" and p.destructive or p.accent
          if pressed() then return base:mix(p.shade, 0.25) end
          if a and a.hovered then return base:mix(p.on_accent, 0.1) end
          return base
        end
        local k = pressed() and "checked" or ((a and a.hovered) and "raised_hover" or "button")
        return p.ink:alpha(p.wash[k])
      end,
      border_width = function() return P().strong and 1 or 0 end,
      border_color = function() return P().border end,
      behavior = { color = quick() },
    }
    if is_node then ui.reparent(node, spec.area) end
    return node
  end

  --- A key hint, as a shortcut label: a light key on a hairline with its
  --- legend. `text`, `height` (22), `width` (fits).
  function M.keycap(spec)
    local h = spec.height or 22
    local function legend() return tostring(get(spec.text) or "") end
    local function fit() return math.max(h + 2, glyphs(legend()) * 8 + 14) end
    local w = spec.width or (type(spec.text) == "function" and fit or fit())
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
      ui.Rect { anchors = { fill = true }, radius = theme.radius.small,
        color = wash("button"),
        border_width = 1, border_color = function() local p = P() return p.strong and p.border or p.ink:alpha(0.12) end },
      M.text { anchors = { center_in = true }, text = legend, font_size = theme.size.small - 1, font_weight = 700,
        color = M.ink("lo") },
    }
  end

  --- The well a text input sits in, as an Adwaita entry: a soft grey fill
  --- with 6 px corners, and on focus a 2 px accent ring (the error tone
  --- while `error()`). `width`, `height` (36), `focused`, `error`, children.
  function M.field(spec)
    local w, h = spec.width, spec.height or 36
    local focused = spec.focused or function() return false end
    local err = spec.error or function() return false end
    local node = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
      visible = spec.visible,
      ui.Rect { anchors = { fill = true }, radius = theme.radius.small,
        color = function()
          local p = P()
          if err() then return p.error:alpha(0.12) end
          return p.ink:alpha(p.dark and 0.08 or 0.07)
        end,
        border_width = function() return P().strong and 1 or 0 end,
        border_color = function() return P().border end,
        behavior = { color = quick() } },
    }
    for _, child in ipairs(spec) do node[#node + 1] = child end
    node[#node + 1] = ui.Rect { anchors = { fill = true }, radius = theme.radius.small, color = "transparent",
      border_width = 2,
      border_color = function()
        local p = P()
        if err() then return p.error end
        return p.strong and p.accent or p.focus:alpha(0.6)
      end,
      opacity = function() return (focused() or err()) and 1 or 0 end,
      behavior = { opacity = quick() } }
    return ui.Item(node)
  end

  --- The on-screen keyboard's keys: grey keys on the raised ground, the
  --- function keys a step darker, the accent key blue.
  function M.keyboard_look(look)
    look = look or {}
    look.panel = function() return P().window:alpha(0) end
    look.key = function() local p = P() return p.dark and p.card or p.view end
    look.key_dim = function() local p = P() return p.dark and p.sidebar or p.sidebar end
    look.accent = function() return P().accent end
    look.on_accent = function() return P().on_accent end
    look.text = function() return P().ink end
    look.dim = function() return P().ink_dim end
    look.press = function() local p = P() return (p.dark and p.card or p.view):mix(p.ink, 0.2) end
    look.radius = (look.radius and look.radius ~= 0) and math.min(look.radius, theme.radius.small) or theme.radius.small
    return look
  end

  -- ---------------------------------------------------------- motion --

  --- A spring for a `behavior`; with motion reduced, an instant step.
  function M.spring(stiffness, damping)
    if theme.reduced then return { duration = 0 } end
    -- Adwaita's springs are critically damped: no overshoot.
    local k = stiffness or 320
    return ui.spring { stiffness = k, damping = math.max(damping or 26, 2 * math.sqrt(k) * 0.95) }
  end

  --- A whisper of squash and stretch for something that travels; none with
  --- motion reduced.
  M.STRETCH = (not theme.reduced) and { stiffness = 320, damping = 30, scale = 0.05, max = 0.1 } or nil

  --- Makes `node` ride out with drawer `d` as it opens (see the drawer's
  --- `panel`): tied to the panel's own position every frame.
  function M.ride(name, node, d, distance)
    morf.effect("kit.default.ride." .. name, function()
      local dist = distance()
      local s = { node = d.panel, property = "translate_x", offset = dist }
      if dist >= 0 then s.min = 0 else s.max = 0 end
      ui.follow(node, "translate_x", s)
    end)
  end

  --- Moves a bar from `[l0, r0]` to `[l1, r1]` along `axis`: both edges
  --- together on ease-out, as a libadwaita indicator slides.
  local running = setmetatable({}, { __mode = "k" })
  function M.elastic(node, axis, l0, r0, l1, r1, opts)
    opts = opts or {}
    local size = axis == "x" and "width" or "height"
    if running[node] then running[node]:stop() end
    local duration = theme.reduced and 0 or (opts.duration and math.min(opts.duration, 320) or theme.duration.normal)
    if duration == 0 then
      node[axis], node[size] = l1, math.max(0, r1 - l1)
      return nil
    end
    running[node] = morf.animation.play {
      { parallel = {
        { node = node, property = axis, from = l0, to = l1, duration = duration, easing = theme.ease.standard },
        { node = node, property = size, from = math.max(0, r0 - l0), to = math.max(0, r1 - l1), duration = duration,
          easing = theme.ease.standard },
      } },
    }
    return running[node]
  end

  --- Contents coming in (`coming`) or going: each fades and settles from a
  --- touch smaller, one a little after the other. Returns the handles.
  function M.bud(nodes, coming, opts)
    opts = opts or {}
    local handles = {}
    for k, n in ipairs(nodes) do
      if theme.reduced then
        n.opacity, n.scale = coming and 1 or 0, 1
      else
        local fresh = not (n.opacity > 0 and n.opacity < 1)
        local delay = coming and ((opts.delay or 0) + (k - 1) * (opts.stagger or 20)) or 0
        handles[#handles + 1] = morf.animation.play { { parallel = {
          { node = n, property = "scale", from = coming and fresh and (opts.from or 0.97) or nil, to = coming and 1 or 0.98,
            duration = coming and 250 or 150, easing = theme.ease.standard, delay = delay },
          { node = n, property = "opacity", from = coming and fresh and 0 or nil, to = coming and 1 or 0,
            duration = coming and 200 or 120, delay = delay },
        } } }
      end
    end
    return handles
  end

  -- ------------------------------------------------------------ shapes --

  local shapes
  local function m3() shapes = shapes or require("lib.util.m3shapes") return shapes end

  function M.shape_path(...) return m3().path(...) end

  --- A shape by name that eases into the next whenever `shape()` changes.
  --- `props` as a `ui.Path`'s; `color`, `duration`, `easing`.
  function M.shape(props)
    props.easing = props.easing or theme.ease.standard
    props.duration = theme.reduced and 0 or (props.duration or theme.duration.normal)
    return m3().Shape(props)
  end

  local svgs = {}
  --- A shape as an inline SVG document, for an `SdfShape`'s `source`.
  function M.svg(name)
    if not svgs[name] then
      svgs[name] = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><path d="%s"/></svg>')
        :format(m3().path(name))
    end
    return svgs[name]
  end

  --- A field layer in a named shape that morphs outline to outline whenever
  --- `shape()` changes. `props` as an `SdfShape`'s, `duration`, `easing`.
  function M.sdf_shape(props)
    local source = props.shape
    local current = type(source) == "function" and source() or source
    local motion = { duration = theme.reduced and 0 or (props.duration or theme.duration.normal),
      easing = props.easing or theme.ease.standard }
    props.shape, props.duration, props.easing = nil, nil, nil
    props.source = M.svg(current)
    props.source_morph_to = M.svg(current)
    props.morph_progress = 0
    props.behavior = props.behavior or {}
    props.behavior.morph_progress = motion
    local node = ui.SdfShape(props)
    if type(source) == "function" then
      local at_end = false
      morf.effect("kit.default.sdf_shape", function()
        local name = source()
        if name == current then return end
        current = name
        if at_end then node.source, node.morph_progress = M.svg(name), 0
        else node.source_morph_to, node.morph_progress = M.svg(name), 1 end
        at_end = not at_end
      end, { owner = node })
    end
    return node
  end

  --- SVG path data for an arc of `sweep` degrees clockwise from `from`
  --- (0 at twelve o'clock), radius `r` about `(cx, cy)`.
  function M.arc_path(cx, cy, r, from, sweep)
    local function at(deg)
      local a = math.rad(deg)
      return cx + r * math.sin(a), cy - r * math.cos(a)
    end
    local x, y = at(from)
    local d = { ("M%.3f %.3f"):format(x, y) }
    local pieces = math.max(1, math.ceil(sweep / 90))
    for i = 1, pieces do
      local ex, ey = at(from + sweep * i / pieces)
      d[#d + 1] = ("A%.3f %.3f 0 0 1 %.3f %.3f"):format(r, r, ex, ey)
    end
    return table.concat(d, " ")
  end

  --- A number whose digits morph into the next ones (glyphs in a distance
  --- field): `id`, `value` (fn), `size`, `color`, `digits` (3), `duration`,
  --- `font`, `weight` (700).
  function M.morph_number(spec)
    local size = spec.size
    local n = spec.digits or 3
    local dw = math.floor(size * 0.62 + 0.5)
    local family = spec.font or (theme.font:match("^%s*([^,]+)") or "sans-serif")
    local motion = { duration = theme.reduced and 0 or (spec.duration or 220), easing = theme.ease.standard }
    local slots, state = {}, {}
    local field = { id = spec.id, width = n * dw, height = size, fill_color = spec.color or M.ink("hi") }
    for i = 1, n do
      slots[i] = ui.SdfShape {
        id = spec.id and (spec.id .. "-digit-" .. i) or nil,
        shape = "glyph", morph_to = "glyph", glyph = "", glyph_morph_to = "",
        font_family = family, font_family_morph_to = family, font_weight = spec.weight or 700,
        x = (i - 1) * dw, y = 0, width = dw, height = size, morph_progress = 0,
        behavior = { morph_progress = motion, x = motion },
      }
      state[i] = { shown = "", at_end = false }
      field[#field + 1] = slots[i]
    end
    local node = ui.Sdf(field)
    morf.effect("kit.default.morph_number" .. (spec.id and ("." .. spec.id) or ""), function()
      local text = tostring(spec.value() or "")
      if #text > n then text = text:sub(-n) end
      local lead = n - #text
      for i = 1, n do
        local c = i > lead and text:sub(i - lead, i - lead) or ""
        local slot, st = slots[i], state[i]
        slot.x = (i - 1) * dw - lead * dw / 2
        if c ~= st.shown then
          if st.shown == "" or c == "" then
            slot.glyph, slot.glyph_morph_to = c, c
            st.at_end = false
            slot.morph_progress = 0
          elseif st.at_end then
            slot.glyph, slot.morph_progress, st.at_end = c, 0, false
          else
            slot.glyph_morph_to, slot.morph_progress, st.at_end = c, 1, true
          end
          st.shown = c
        end
      end
    end, { owner = node })
    return node
  end

  --- libadwaita's spinner: an arc of the ring turning, `size` across, in
  --- `color` (the dim ink). `props.active()` runs it; stopped, it rests as
  --- a faint ring. Only the turn moves: a transform, no path changes.
  function M.loading(size, color, props)
    props = props or {}
    local active = props.active or function() return true end
    local stroke = math.max(2, size / 9)
    local r = size / 2 - stroke / 2
    local arc = M.arc_path(size / 2, size / 2, r, 0, 100)
    local ring = M.arc_path(size / 2, size / 2, r, 0, 360)
    color = color or M.ink("lo")
    return ui.Item { id = props.id, x = props.x, y = props.y, anchors = props.anchors, width = size, height = size,
      accessible_role = "progress", accessible_name = props.accessible_name or "Loading",
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, size, size }, d = ring, fill_color = "transparent",
        stroke_width = stroke, stroke_color = function() return get(color):alpha(0.2) end },
      ui.Item { anchors = { fill = true },
        visible = function() return active() end,
        loop = function()
          if not active() or theme.reduced then return nil end
          return { rotation = { from = 0, to = 360, duration = 1100, easing = "linear" } }
        end,
        ui.Path { anchors = { fill = true }, view_box = { 0, 0, size, size }, d = arc, fill_color = "transparent",
          stroke_width = stroke, stroke_cap = "round", stroke_color = color } },
    }
  end

  -- ---------------------------------------------------------- readings --

  --- A progress arc: the value in `color` over a faint round-capped
  --- trough. `value()` (0..1), `size`, `stroke`, `from`, `sweep`, `color`,
  --- `track`, `id`, and children over it.
  function M.gauge(spec)
    local size, stroke = spec.size, spec.stroke or 6
    local r = size / 2 - stroke / 2
    local sweep = spec.sweep or 360
    local d = M.arc_path(size / 2, size / 2, r, spec.from or 0, sweep)
    local function v() return clamp01(get(spec.value)) end
    local node = {
      id = spec.id, width = size, height = size, x = spec.x, y = spec.y, anchors = spec.anchors,
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, size, size }, d = d,
        fill_color = "transparent", stroke_width = stroke, stroke_cap = "round",
        stroke_color = spec.track or function() return P().track end },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, size, size }, d = d,
        fill_color = "transparent", stroke_width = stroke, stroke_cap = "round",
        stroke_color = spec.color or M.signal("accent"),
        opacity = function() return v() > 0.002 and 1 or 0 end,
        trim_end = function() return math.max(0.001, v()) end,
        behavior = { trim_end = settle() } },
    }
    for _, child in ipairs(spec) do node[#node + 1] = child end
    return ui.Item(node)
  end

  --- A large gauge with its reading in the middle: `size`, `value` (0..1),
  --- `color`, `text` (the percentage when nil), `label`, `sweep` (270),
  --- `thickness`, `track`, `text_size`.
  function M.ring(spec)
    local s = spec.size
    local sweep = spec.sweep or 270
    local from = sweep >= 360 and 0 or -sweep / 2
    local thick = spec.thickness or math.max(4, math.floor(s / 14))
    local r = s / 2 - thick / 2 - 1
    local color = spec.color or M.signal("accent")
    local function v() return clamp01(get(spec.value)) end
    local d = M.arc_path(s / 2, s / 2, r, from, sweep)
    local node = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s,
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = d, fill_color = "transparent",
        stroke_width = thick, stroke_cap = "round", stroke_color = spec.track or function() return P().track end },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = d, fill_color = "transparent",
        stroke_width = thick, stroke_cap = "round", stroke_color = color,
        opacity = function() return v() > 0.002 and 1 or 0 end,
        trim_end = function() return math.max(0.001, v()) end, behavior = { trim_end = settle() } },
    }
    local text = spec.text or function() return ("%d%%"):format(math.floor(v() * 100 + 0.5)) end
    node[#node + 1] = ui.Column { anchors = { center_in = true }, gap = 0, align = "center",
      M.text { text = text, font_size = spec.text_size or math.floor(s * 0.2), font_weight = 700,
        color = M.ink("hi"), horizontal_alignment = "center" },
      spec.label and M.label { text = spec.label, horizontal_alignment = "center" } or nil,
    }
    for _, child in ipairs(spec) do node[#node + 1] = child end
    return ui.Item(node)
  end

  --- A small circular gauge with its caption under it. `size`, `value`,
  --- `text`, `label`, `color`. `size` wide, `size` + 14 high.
  function M.mini_ring(spec)
    local s = spec.size
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s + 14,
      M.ring { size = s, value = spec.value, color = spec.color, text = spec.text, sweep = 360,
        thickness = math.max(3, math.floor(s / 13)), text_size = spec.text_size or math.floor(s * 0.22) },
      M.label { anchors = { horizontal_center = true }, y = s, height = 14, text = spec.label,
        horizontal_alignment = "center" },
    }
  end

  --- A progress bar: a pill trough and the value in `color`. `width`,
  --- `stroke` (6), `value()`, `color`, `track`, `id`.
  function M.bar(spec)
    local w, h = spec.width, spec.stroke or 6
    local function v() return clamp01(get(spec.value)) end
    return ui.Item {
      id = spec.id, width = w, height = h, x = spec.x, y = spec.y, anchors = spec.anchors,
      ui.Rect { anchors = { fill = true }, radius = h / 2, color = spec.track or function() return P().track end },
      ui.Rect { height = h, radius = h / 2, color = spec.color or M.signal("accent"),
        width = function() return v() <= 0 and 0 or math.max(h, v() * w) end,
        behavior = { width = settle() } },
    }
  end

  --- A level bar: continuous, or `count` blocks as GtkLevelBar's discrete
  --- mode. `width`, `height` (8), `count`, `value`, `color`, `track`.
  function M.meter(spec)
    local w, h = spec.width, spec.height or 8
    local color = spec.color or M.signal("accent")
    local count = spec.count
    if not count or count < 2 then
      return M.bar { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, stroke = h,
        value = spec.value, color = color, track = spec.track }
    end
    local gap = 2
    local bw = (w - gap * (count - 1)) / count
    local node = { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h }
    for i = 1, count do
      node[#node + 1] = ui.Rect { x = (i - 1) * (bw + gap), width = bw, height = h, radius = math.min(3, h / 2),
        color = function()
          if clamp01(get(spec.value)) * count >= i - 0.5 then return get(color) end
          return get(spec.track) or P().track
        end, behavior = { color = quick() } }
    end
    return ui.Item(node)
  end

  --- An emphasised fill: a pill trough as tall as the box, filled. `width`,
  --- `height` (14), `value`, `color`.
  function M.fill(spec)
    local w, h = spec.width, spec.height or 14
    return M.bar { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, stroke = h,
      value = spec.value, color = spec.color, track = spec.track }
  end

  --- A vertical level: a pill trough filled from the foot. `width` (10),
  --- `height`, `value`, `color`.
  function M.vmeter(spec)
    local w, h = spec.width or 10, spec.height
    local function lit()
      local v = clamp01(get(spec.value))
      return v <= 0 and 0 or math.max(w, v * h)
    end
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
      ui.Rect { anchors = { fill = true }, radius = w / 2, color = spec.track or function() return P().track end },
      ui.Rect { width = w, radius = w / 2, color = spec.color or M.signal("accent"),
        y = function() return h - lit() end, height = lit, behavior = { y = settle(), height = settle() } },
    }
  end

  --- A history chart on the view's ground: faint rules, the first series
  --- as a line over a soft fill, the second as a thinner line in the extra
  --- tone. `width`, `height`, `samples`, `first`, `second`, `top`,
  --- `bottom`, `floor`, `color`, `emphasis`/`hatch`, `caption`, `scale`,
  --- `id`. Returns the node and `top`.
  function M.chart(spec)
    local w, h = spec.width, spec.height
    local color = spec.color or M.signal("accent")
    local PAD = 4
    local first, feed_first = channel.from(spec.first)
    local second, feed_second
    if spec.second then second, feed_second = channel.from(spec.second) end
    local function bottom() return get(spec.bottom) or 0 end
    local function top()
      if type(spec.top) == "function" then return math.max(bottom() + 1e-9, spec.top()) end
      if spec.top then return spec.top end
      local peak = math.max(bottom(), first:peak() or 0, second and second:peak() or 0)
      return math.max(peak * 1.15, bottom() + (spec.floor or 1))
    end
    local function plot(kind)
      return function()
        return { kind = kind, smooth = false, width = w, height = h, samples = spec.samples, bottom = bottom(),
          top = top(), pad_top = PAD, pad_bottom = PAD }
      end
    end
    local strong = spec.emphasis or spec.hatch
    local grid = {}
    for k = 1, 3 do grid[#grid + 1] = ("M0 %g H%g "):format(math.floor(h * k / 4) + 0.5, w) end
    local box = { id = spec.id, width = w, height = h,
      M.card { anchors = { fill = true }, radius = theme.radius.large, color = function() return P().view end },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, w, h }, d = table.concat(grid),
        fill_color = "transparent", stroke_color = M.stroke("faint"), stroke_width = 1 },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, w, h }, series = first.id, plot = plot("area"),
        fill_color = function() return get(color):alpha(strong and 0.3 or 0.16) end },
    }
    if spec.second then
      box[#box + 1] = ui.Path { anchors = { fill = true }, view_box = { 0, 0, w, h },
        series = second.id, plot = plot("line"), fill_color = "transparent",
        stroke_color = M.signal("extra"), stroke_width = 1.5, stroke_join = "round" }
    end
    box[#box + 1] = ui.Path { anchors = { fill = true }, view_box = { 0, 0, w, h },
      series = first.id, plot = plot("line"), fill_color = "transparent",
      stroke_color = color, stroke_width = 2, stroke_cap = "round", stroke_join = "round" }
    if not spec.caption then box.x, box.y, box.anchors = spec.x, spec.y, spec.anchors end
    local node = ui.Item(box)
    feed_first(node)
    if feed_second then feed_second(node) end
    if not spec.caption then return node, top end
    return ui.Column { x = spec.x, y = spec.y, anchors = spec.anchors, gap = 8,
      M.caption { width = w, text = spec.caption, color = color,
        note = spec.scale and function() return spec.scale(top()) end or nil },
      node,
    }, top
  end

  --- Bars, one per value, with softly rounded tops, all in one path.
  --- `width`, `height`, `values` (or `channel`), `color`, `gap` (2), `mirror`.
  function M.spectrum(spec)
    local w, h = spec.width, spec.height
    local bars, feed = channel.from(spec.channel or spec.values, { size = 512 })
    local node = ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, w, h }, series = bars.id,
        plot = { kind = "bars", width = w, height = h, gap = spec.gap or 2, radius = 2, min_bar = 2,
          mirror = spec.mirror == true },
        fill_color = spec.color or M.signal("accent") },
    }
    feed(node)
    return node
  end

  --- A path whose outline eases to the next one whenever `build()` gives
  --- another with the same commands.
  local function morphing(props, build)
    local current = build()
    props.d, props.morph_to, props.morph_progress = current, current, 0
    props.behavior = props.behavior or {}
    props.behavior.morph_progress = settle()
    local node = ui.Path(props)
    local at_end = false
    morf.effect("kit.default.morph", function()
      local d = build()
      if d == current then return end
      current = d
      if at_end then node.d, node.morph_progress = d, 0
      else node.morph_to, node.morph_progress = d, 1 end
      at_end = not at_end
    end, { owner = node })
    return node
  end

  --- A polygon over a web of rings and spokes. `size`, `values` (fn -> list
  --- of 0..1), `axes` (6), `color`.
  function M.radar(spec)
    local s = spec.size
    local c = s / 2
    local axes = spec.axes or 6
    local color = spec.color or M.signal("accent")
    local R = c - 3
    local function point(k, r)
      local a = math.rad(360 * k / axes)
      return c + r * math.sin(a), c - r * math.cos(a)
    end
    local function polygon(f)
      local d = {}
      for k = 0, axes - 1 do
        local x, y = point(k, f(k))
        d[#d + 1] = ("%s%.2f %.2f"):format(k == 0 and "M" or "L", x, y)
      end
      return table.concat(d, " ") .. " Z"
    end
    local web = {}
    for i = 1, 3 do web[#web + 1] = polygon(function() return R * i / 3 end) end
    for k = 0, axes - 1 do
      local x, y = point(k, R)
      web[#web + 1] = ("M%.2f %.2f L%.2f %.2f"):format(c, c, x, y)
    end
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s,
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = table.concat(web, " "),
        fill_color = "transparent", stroke_color = M.stroke("quiet"), stroke_width = 1 },
      morphing({ anchors = { fill = true }, view_box = { 0, 0, s, s },
        fill_color = function() return get(color):alpha(0.25) end, stroke_color = color, stroke_width = 2,
        stroke_join = "round" }, function()
          local values = get(spec.values) or {}
          return polygon(function(k) return R * math.max(0.05, clamp01(values[k + 1] or 0)) end)
        end),
    }
  end

  --- A dial: a ring with twelve ticks, the value as an arc, and a needle
  --- that turns to it about a hub. `size`, `value` (0..1), `color`.
  function M.dial(spec)
    local s = spec.size
    local c = s / 2
    local color = spec.color or M.signal("accent")
    local thick = math.max(3, math.floor(s / 22))
    local r = c - thick / 2 - 2
    local function v() return clamp01(get(spec.value)) end
    local full = M.arc_path(c, c, r, 0, 360)
    local ticks = {}
    for k = 0, 11 do
      local a = math.rad(k * 30)
      local r1, r2 = r - thick - 3, r - thick - (k % 3 == 0 and 11 or 7)
      ticks[#ticks + 1] = ("M%.2f %.2f L%.2f %.2f"):format(c + r1 * math.sin(a), c - r1 * math.cos(a),
        c + r2 * math.sin(a), c - r2 * math.cos(a))
    end
    local hub = math.max(8, math.floor(s * 0.08))
    local needle = r - thick - 14
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s,
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = full, fill_color = "transparent",
        stroke_width = thick, stroke_color = function() return P().track end },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = full, fill_color = "transparent",
        stroke_width = thick, stroke_cap = "round", stroke_color = color,
        opacity = function() return v() > 0.002 and 1 or 0 end,
        trim_end = function() return math.max(0.001, v()) end, behavior = { trim_end = settle() } },
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, s, s }, d = table.concat(ticks, " "),
        fill_color = "transparent", stroke_color = M.stroke("mark"), stroke_width = 1.5, stroke_cap = "round" },
      ui.Item { anchors = { fill = true }, rotation = function() return 360 * v() end,
        behavior = { rotation = M.spring(220, 30) },
        ui.Rect { x = c - 1.5, y = c - needle, width = 3, height = needle, radius = 1.5, color = M.ink("hi") } },
      ui.Rect { x = c - hub / 2, y = c - hub / 2, width = hub, height = hub, radius = hub / 2, color = color },
    }
  end

  --- A small card with its number and a level bar along its foot, the
  --- bar's tone following the level. `width`, `height`, `value` (0..100),
  --- `text`, `label`.
  function M.cell(spec)
    local w, h = spec.width, spec.height
    local function v() return tonumber(get(spec.value)) or 0 end
    local color = M.level(v)
    local text = spec.text or function() return ("%d"):format(math.floor(v() + 0.5)) end
    local fs = math.floor(math.min(h * 0.38, w * 0.3))
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, width = w, height = h,
      M.card { anchors = { fill = true }, radius = math.min(theme.radius.large, h / 3) },
      spec.label and M.label { x = 7, y = 3, text = spec.label, size = 9 } or nil,
      M.text { anchors = { horizontal_center = true }, y = math.floor((h - 8) / 2 - fs * 0.62), text = text,
        font_size = fs, font_weight = 700, color = M.ink("hi") },
      M.meter { x = 7, y = h - 9, width = w - 14, height = 4, color = color,
        value = function() return v() / 100 end },
    }
  end

  --- A readout card: a label, the value large and a level bar at its foot.
  --- `width`, `height` (58), `label`, `value` (fn -> string), `level`,
  --- `color`, `mark` ("solid" | "dashed").
  function M.stat(spec)
    local w, h = spec.width, spec.height or 58
    local color = spec.color or M.signal("accent")
    local node = { id = spec.id, x = spec.x, y = spec.y, width = w, height = h,
      M.card { anchors = { fill = true } },
      M.label { x = 12, y = 7, text = spec.label, width = w - 40, elide = "right" },
      M.text { x = 12, y = 22, text = spec.value, font_size = theme.size.large - 2, font_weight = 700,
        color = M.ink("hi"), width = w - 24, elide = "right" },
    }
    if spec.mark then
      node[#node + 1] = ui.Rect { x = w - 20, y = 11, width = 8, height = 8, radius = 4,
        color = spec.mark == "dashed" and M.signal("extra") or color }
    end
    if spec.level then
      node[#node + 1] = M.meter { x = 12, y = h - 10, width = w - 24, height = 4, value = spec.level, color = color }
    end
    return ui.Item(node)
  end

  --- Now / Average / Peak of a series as three cards. `width`, `series`,
  --- `top`, `format`, `color`, `font_size`. 74 high.
  function M.triplet(spec)
    local w = spec.width
    local cw = math.floor((w - 16) / 3)
    local function pick(i) return function() return (select(i, summary(get(spec.series)))) end end
    local items = { { "Now", pick(1) }, { "Average", pick(2) }, { "Peak", pick(3) } }
    local node = { id = spec.id, x = spec.x, y = spec.y, width = w, height = 74 }
    for i, item in ipairs(items) do
      local value = item[2]
      local function frac() return clamp01(value() / math.max(1e-9, get(spec.top) or 1)) end
      node[#node + 1] = ui.Item { x = (i - 1) * (cw + 8), width = cw, height = 74,
        M.card { anchors = { fill = true } },
        M.label { x = 12, y = 8, text = item[1] },
        M.text { x = 12, y = 24, text = function() return spec.format(value()) end,
          font_size = spec.font_size or 19, font_weight = 700, color = M.ink("hi"), width = cw - 24, elide = "right" },
        M.meter { x = 12, y = 60, width = cw - 24, height = 4, value = frac,
          color = spec.color or M.level(function() return frac() * 100 end) },
      }
    end
    return ui.Item(node)
  end

  -- ------------------------------------------------------------ status --

  local EMBLEM = {
    ok = "check", warn = "priority_high", alert = "close", info = "info_i",
  }

  --- A status mark: a disc in the kind's tone with its symbolic glyph.
  --- `kind` (alert, warn, ok, info; may be a binding), `size` (48), `color`.
  function M.emblem(spec)
    local s = spec.size or 48
    local function kind() local k = get(spec.kind) return EMBLEM[k] and k or "info" end
    local color = spec.color or function() return M.signal(kind())() end
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = s, height = s,
      ui.Rect { anchors = { fill = true }, radius = s / 2, color = color, behavior = { color = quick() } },
      M.icon(function() return EMBLEM[kind()] end, math.floor(s * 0.56), function() return P().on_accent end,
        { anchors = { center_in = true }, fill = true }),
    }
  end

  -- The banner status_line and status draw: a card in a tint of the kind's
  -- tone (a solid outline in high contrast), the emblem, the title bold
  -- and the subtitle in the tone's ink.
  local function banner(spec, default)
    local w, s = spec.width, spec.size or default
    local function kind() return get(spec.kind) or "info" end
    local color = spec.color or function() return M.signal(kind())() end
    local tw = w - s - 16
    local fs = math.floor(s * 0.36)
    local block = fs * 1.3 + (spec.subtitle and 15 or 0)
    local ty = math.floor((s - block) / 2)
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, width = w, height = s,
      ui.Rect { anchors = { fill = true }, radius = theme.radius.large,
        color = function() local p = P() return p.strong and p.card or get(color):alpha(p.dark and 0.2 or 0.13) end,
        border_width = function() return P().strong and 2 or 0 end, border_color = color,
        behavior = { color = quick() } },
      M.emblem { x = 7, y = 7, size = s - 14, kind = kind, color = color },
      M.text { x = s + 2, y = ty, text = spec.title, font_size = fs, font_weight = 700, color = M.ink("hi"),
        width = tw, elide = "right" },
      spec.subtitle and M.text { x = s + 2, y = ty + fs * 1.3, height = 15, text = spec.subtitle,
        font_size = theme.size.small - 1,
        color = function() return M.signal_ink(kind())() end, width = tw, elide = "right" } or nil,
    }
  end

  --- Mark + word + subtitle: `kind`, `title`, `subtitle`, `width`, `size` (46).
  function M.status_line(spec) return banner(spec, 46) end

  --- The live status strip: `width`, `kind` (fn), `title` (fn), `subtitle`
  --- (fn), `size` (40).
  function M.status(spec) return banner(spec, 40) end

  return M
end
