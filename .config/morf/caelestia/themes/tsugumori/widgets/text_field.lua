-- Tsugumori's look for each TextField widget: square fields in a hairline
-- of the primary that brightens with focus, L-brackets that close in on
-- the field as it takes focus, a rail along the foot that runs out from
-- the left, and labels in the mono face that lift and shrink to a caption.
-- The alert signal takes over while what is typed would not be accepted.
-- Each widget adds its instrument: a prompt block, ruled lines, a status
-- light, a tick ruler, square tags, digit cells, a gutter. The input is
-- the configuration's; what it accepts, the archetype's.
local morf = require("morf")
local ui = require("morf.ui")
local stripes = require("themes.tsugumori.stripes")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local function get(v) if type(v) == "function" then return v() end return v end
  local quick = { duration = 140, easing = "out_cubic" }
  local glide = { duration = 340, easing = "out_expo" }

  local function sides(v)
    if type(v) == "table" then return v[1] or 0, v[2] or 0, v[3] or 0, v[4] or 0 end
    v = v or 0
    return v, v, v, v
  end
  local FOOT = 22
  local function foot(spec) return spec.supporting and FOOT or 0 end
  local function bad(t) return not t.acceptable and not t.empty end
  local function box(t, spec) return math.max(0, (t.height or 0) - foot(spec)) end
  local function alert() return M.signal("alert")() end
  local function primary() return C.primary end
  --- What marks the field: the alert signal, the primary while focused,
  --- else the dim ink.
  local function mark(t)
    return function()
      if bad(t) then return alert() end
      return t.focused and C.primary or C.onSurfaceVariant
    end
  end

  -- --------------------------------------------------------- pieces --

  --- The field: a square ground (`color`, a role) in a hairline that goes
  --- from idle to focus, the alert while it would not be accepted.
  local function frame(t, spec, color)
    return ui.Rect { anchors = { left = true, right = true, top = true }, height = function() return box(t, spec) end,
      color = function()
        local c = C[color or "surfaceContainerHigh"]
        return (t.hovered and not t.focused) and c:mix(C.primary, 0.05) or c
      end,
      border_width = 1,
      border_color = function()
        if bad(t) then return alert() end
        return t.focused and stroke(C, "focus") or (t.hovered and stroke(C, "hover") or stroke(C, "idle"))
      end,
      behavior = { color = quick, border_color = quick } }
  end

  --- Focus: brackets that close in on the corners, and the rail along the
  --- foot running out from the left.
  local function focus(t, spec, no_rail)
    local brackets = hud().corners { length = 8, weight = 2, color = mark(t) }
    local holder = ui.Item { anchors = { left = true, right = true, top = true }, z = 6,
      height = function() return box(t, spec) end,
      ui.Item { anchors = { fill = true }, transform_origin_x = 0.5, transform_origin_y = 0.5,
        opacity = function() return (t.focused or bad(t)) and 1 or 0 end,
        scale = function() return (t.focused or bad(t)) and 1 or 1.12 end,
        behavior = { opacity = quick, scale = glide }, brackets } }
    if not no_rail then
      ui.reparent(ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 2, transform_origin_x = 0,
        scale_x = function() return (t.focused or bad(t)) and 1 or 0 end,
        color = function() return bad(t) and alert() or C.primary end,
        behavior = { scale_x = glide, color = quick } }, holder)
    end
    return holder
  end

  --- The label (`spec.label`), in caps: at the middle while empty and idle,
  --- lifted to a caption at the top once focused or holding text.
  local function label(t, spec, always)
    if not spec.label then return nil end
    local l = sides(spec.inset)
    local size = theme.typography.menu + 1
    local lh = math.ceil(size * 1.4)
    local function up() return always or t.focused or not t.empty or spec.tags ~= nil end
    local function rest() return math.floor((box(t, spec) - lh) / 2) end
    return M.text { text = tostring(spec.label):upper(), x = l, height = lh, font_size = size, font_weight = 500,
      letter_spacing = 0.8, vertical_alignment = "center", transform_origin_x = 0, transform_origin_y = 0, z = 8,
      y = rest,
      translate_y = function() return up() and (5 - rest()) or 0 end,
      scale = function() return up() and 0.86 or 1 end,
      color = mark(t),
      behavior = { translate_y = glide, scale = glide, color = quick } }
  end

  --- A glyph at the start in a prompt block: dim, the primary while focused.
  local function leading(t, spec, color)
    if not spec.icon then return nil end
    return M.icon(spec.icon, 18, color or mark(t),
      { x = 15, y = function() return math.floor((box(t, spec) - 18) / 2) end, behavior = { color = quick } })
  end

  --- The supporting line and a mono count.
  local function supporting(t, spec)
    if not spec.supporting and not spec.max_length then return nil end
    local l = sides(spec.inset)
    local function ink() return bad(t) and alert() or C.onSurfaceVariant end
    local node = ui.Item { anchors = { left = true, right = true, bottom = true }, height = FOOT }
    if spec.supporting then
      ui.reparent(M.text { text = spec.supporting, x = l, anchors = { bottom = true }, height = 18,
        font_size = theme.typography.menu, color = ink, behavior = { color = quick } }, node)
    end
    if spec.max_length then
      ui.reparent(M.text { anchors = { right = true, bottom = true, right_margin = 10,
          bottom_margin = spec.supporting and 0 or 4 }, height = 18,
        font_size = theme.typography.menu, color = ink,
        text = function() return ("%03d/%03d"):format(t.length or 0, spec.max_length) end }, node)
    end
    return node
  end

  local function blank() return ui.Item {} end
  local function add(node, ...) for _, child in ipairs { ... } do if child then ui.reparent(child, node) end end return node end

  -- -------------------------------------------------------------- looks --

  local LOOK = {}

  function LOOK.entry(t, spec)
    return { background = frame(t, spec), placeholder = label(t, spec), error = focus(t, spec),
      counter = supporting(t, spec) or blank() }
  end

  --- A password: a lock in its prompt.
  function LOOK.password(t, spec)
    local s = LOOK.entry(t, spec)
    s.leading = leading(t, spec)
    return s
  end

  --- Search: the prompt as a block of the primary, the magnifier on it.
  function LOOK.search(t, spec)
    return {
      background = add(frame(t, spec),
        ui.Rect { anchors = { left = true, top = true, bottom = true, margins = 1 }, width = 34,
          color = function() return C.primary:alpha(t.focused and 1 or 0.16) end, behavior = { color = quick } }),
      leading = M.icon(spec.icon or "search", 18, function() return t.focused and C.onPrimary or C.primary end,
        { x = 9, y = function() return math.floor((box(t, spec) - 18) / 2) end, behavior = { color = quick } }),
      error = focus(t, spec), placeholder = label(t, spec),
    }
  end

  --- Several lines: ruled like a log -- a faint rule under every line --
  --- the label held as a caption.
  function LOOK.text_area(t, spec)
    local _, top = sides(spec.inset)
    local lh = math.ceil((get(spec.font_size) or theme.size.normal) * 1.2)
    local h = get(spec.height) or 120
    local rules = {}
    local y = top + lh + 3
    while y < h - 8 do rules[#rules + 1] = ("M8 %d H%d"):format(y, 600) y = y + lh end
    return {
      background = add(frame(t, spec, "surfaceContainer"),
        ui.Item { anchors = { fill = true, margins = 1 }, clip = true,
          ui.Path { width = 600, height = h, view_box = { 0, 0, 600, h }, d = table.concat(rules, " "),
            fill_color = "transparent", stroke_width = 1, stroke_color = function() return stroke(C, "quiet") end } }),
      placeholder = label(t, spec, true), error = focus(t, spec), counter = supporting(t, spec) or blank(),
    }
  end

  --- An address: its glyph, and a status light at the end -- the primary
  --- once it would be accepted, the alert while not.
  local function judged(t, spec)
    local s = LOOK.entry(t, spec)
    s.leading = leading(t, spec)
    s.trailing = ui.Rect { anchors = { right = true, right_margin = 16 }, width = 8, height = 8,
      y = function() return math.floor((box(t, spec) - 8) / 2) end,
      color = function() return bad(t) and alert() or C.primary end,
      opacity = function() return t.empty and 0 or 1 end, behavior = { opacity = quick },
      ui.Rect { anchors = { fill = true, margins = -4 }, color = "transparent", border_width = 1,
        border_color = function() return (bad(t) and alert() or C.primary):alpha(0.5) end } }
    return s
  end
  LOOK.url = judged
  LOOK.email = judged

  --- A number: its unit after it, a tick ruler along the foot.
  function LOOK.numeric_entry(t, spec)
    local s = LOOK.entry(t, spec)
    local w = get(spec.width) or 160
    s.background = add(s.background, ui.Path { anchors = { left = true, bottom = true, left_margin = 6, bottom_margin = 3 },
      width = w - 12, height = 5, view_box = { 0, 0, w - 12, 5 },
      d = morf.geometry.ruler(w - 12, 5, { pitch = 8, major = 5, min_count = 4 }),
      fill_color = "transparent", stroke_width = 1, stroke_color = function() return stroke(C, "idle") end })
    if spec.unit then
      local _, top, _, bottom = sides(spec.inset)
      s.trailing = M.text { text = tostring(spec.unit):upper(), anchors = { right = true, right_margin = 14 }, height = 20,
        y = function() return top + math.floor((box(t, spec) - top - bottom - 20) / 2) end,
        font_size = theme.typography.menu, vertical_alignment = "center",
        color = function() return C.onSurfaceVariant end }
    end
    return s
  end

  --- A one-time code: a framed cell per digit, the one being typed into
  --- bracketed; the digits drawn in the cells.
  function LOOK.otp(t, spec)
    local n = tonumber(spec.max_length) or 6
    local gap = 8
    if spec.input then spec.input.color, spec.input.caret_color = "transparent", "transparent" end
    local function cell_w() return math.max(0, ((t.width or 0) - gap * (n - 1)) / n) end
    local cells = ui.Item { anchors = { fill = true } }
    for i = 1, n do
      local function x() return (i - 1) * (cell_w() + gap) end
      local function h() return t.height or 0 end
      local function current() return t.focused and ((t.length or 0) + 1 == i or ((t.length or 0) == n and i == n)) end
      local function done() return i <= (t.length or 0) end
      ui.reparent(ui.Rect { x = x, width = cell_w, height = h,
        color = function() return done() and C.primary:alpha(0.12) or C.surfaceContainerHigh end,
        border_width = 1, border_color = function() return done() and stroke(C, "focus") or stroke(C, "idle") end,
        behavior = { color = quick } }, cells)
      ui.reparent(ui.Item { x = x, width = cell_w, height = h, z = 2,
        opacity = function() return current() and 1 or 0 end, scale = function() return current() and 1 or 1.2 end,
        behavior = { opacity = quick, scale = glide },
        hud().corners { length = 7, weight = 2, color = primary } }, cells)
      ui.reparent(M.text { x = x, width = cell_w, height = h, z = 3, horizontal_alignment = "center",
        vertical_alignment = "center", font_size = theme.size.large + 2, font_weight = 600,
        text = function() return (t.text or ""):sub(i, i) end }, cells)
    end
    return { background = cells, placeholder = blank(), error = blank(), counter = blank() }
  end

  --- Tags: square tags along the top, a block of the primary at each head.
  function LOOK.tag_input(t, spec)
    local s = LOOK.entry(t, spec)
    local l = sides(spec.inset)
    local row = { x = l, y = 24, gap = 6 }
    for _, tag in ipairs(spec.tags or {}) do
      local text = M.text { text = tostring(tag):upper(), x = 11, height = 24, vertical_alignment = "center",
        font_size = theme.typography.menu, letter_spacing = 0.5, color = function() return C.onSurface end }
      row[#row + 1] = ui.Rect { height = 24, accessible_name = tostring(tag),
        width = function() return (text.layout_width or 0) + 34 end,
        color = function() return C.primary:alpha(0.1) end, border_width = 1,
        border_color = function() return stroke(C, "idle") end,
        ui.Rect { width = 3, height = 24, color = primary },
        text,
        M.icon("close", 14, function() return C.primary end,
          { y = 5, x = function() return (text.layout_width or 0) + 15 end }) }
    end
    s.leading = ui.Row(row)
    return s
  end

  --- Mentions: the @ in a block of the primary, a send key after it.
  function LOOK.mentions(t, spec)
    local function b() return box(t, spec) end
    return {
      background = add(frame(t, spec),
        ui.Rect { anchors = { left = true, top = true, bottom = true }, width = 36, color = primary }),
      leading = M.icon(spec.icon or "alternate_email", 18, function() return C.onPrimary end,
        { x = 9, y = function() return math.floor((b() - 18) / 2) end }),
      trailing = ui.Rect { anchors = { right = true, right_margin = 6 }, y = 6,
        width = function() return b() - 12 end, height = function() return b() - 12 end,
        color = function() return t.empty and C.surfaceContainerHighest or C.primary:alpha(0.16) end,
        border_width = 1, border_color = function() return t.empty and stroke(C, "idle") or stroke(C, "focus") end,
        behavior = { color = quick },
        M.icon("keyboard_return", 18, function() return t.empty and C.onSurfaceVariant or C.primary end,
          { anchors = { center_in = true } }) },
      error = focus(t, spec, true), placeholder = label(t, spec),
    }
  end

  --- A rename in place: the words over a dashed underline until focused,
  --- then the field and its brackets; a pencil after it while idle.
  function LOOK.inline_rename(t, spec)
    local w = get(spec.width) or 240
    local dashes = {}
    for x = 0, w - 6, 8 do dashes[#dashes + 1] = ("M%d 0.5 H%d"):format(x, x + 4) end
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerHigh end,
          border_width = 1, border_color = function() return stroke(C, "focus") end,
          opacity = function() return t.focused and 1 or 0 end, behavior = { opacity = quick } },
        ui.Path { anchors = { left = true, bottom = true }, width = w, height = 1, view_box = { 0, 0, w, 1 },
          d = table.concat(dashes, " "), fill_color = "transparent", stroke_width = 1,
          stroke_color = function() return t.hovered and stroke(C, "focus") or stroke(C, "idle") end,
          opacity = function() return t.focused and 0 or 1 end } },
      error = focus(t, spec, true),
      trailing = spec.icon and M.icon(spec.icon, 16, primary,
        { anchors = { right = true, right_margin = 10, vertical_center = true },
          opacity = function() return t.focused and 0 or 1 end, behavior = { opacity = quick } }) or nil,
      placeholder = blank(),
    }
  end

  --- An entry row: a row over a hairline rule, its label lifting, a square
  --- apply key after it.
  function LOOK.entry_row(t, spec)
    return {
      background = ui.Item { anchors = { left = true, right = true, top = true }, height = function() return box(t, spec) end,
        ui.Rect { anchors = { fill = true }, color = function()
          return t.hovered and not t.focused and C.primary:alpha(0.05) or C.primary:alpha(0) end },
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
          color = function() return stroke(C, "idle") end } },
      placeholder = label(t, spec), error = focus(t, spec),
      trailing = spec.icon and ui.Rect { anchors = { right = true, right_margin = 8, vertical_center = true },
        width = 32, height = 32,
        color = function() return t.focused and C.primary or C.primary:alpha(0.08) end,
        border_width = 1, border_color = function() return stroke(C, "focus") end, behavior = { color = quick },
        M.icon(spec.icon, 18, function() return t.focused and C.onPrimary or C.primary end,
          { anchors = { center_in = true } }) } or nil,
      counter = supporting(t, spec) or blank(),
    }
  end

  --- A filter: compact, hatched while it filters.
  function LOOK.filter_field(t, spec)
    return {
      background = add(frame(t, spec),
        ui.Item { anchors = { fill = true, margins = 1 }, clip = true,
          opacity = function() return t.empty and 0 or 1 end, behavior = { opacity = quick },
          stripes.box { width = 400, height = 40, gap = 7, weight = 2,
            color = function() return C.primary:alpha(0.16) end } }),
      leading = leading(t, spec, function() return t.empty and C.onSurfaceVariant or C.primary end),
      error = focus(t, spec, true), placeholder = blank(),
    }
  end

  --- Code: a dark page with a gutter of line numbers and a rail of the
  --- primary down its edge.
  function LOOK.code_input(t, spec)
    local l, top = sides(spec.inset)
    local size = get(spec.font_size) or 14
    return {
      background = add(frame(t, spec, "surfaceContainerLowest"),
        ui.Rect { anchors = { left = true, top = true, bottom = true, margins = 1 }, width = math.max(0, l - 8),
          color = function() return C.primary:alpha(0.06) end },
        ui.Rect { anchors = { left = true, top = true, bottom = true }, width = 2,
          color = function() return t.focused and C.primary or stroke(C, "focus") end }),
      leading = M.text { x = 4, y = top, width = math.max(0, l - 14), horizontal_alignment = "right",
        font_family = theme.mono, font_size = size, line_height = 1.2, z = 3,
        color = function() return stroke(C, "focus") end,
        text = function()
          local lines = select(2, (t.text or ""):gsub("\n", "\n")) + 1
          local out = {}
          for i = 1, lines do out[i] = ("%02d"):format(i) end
          return table.concat(out, "\n")
        end },
      error = focus(t, spec, true), placeholder = blank(),
    }
  end

  for widget, look in pairs(LOOK) do S[widget] = look end

  -- ------------------------------------------------------ shortcut recorder --

  local LEGEND = { ctrl = "Ctrl", shift = "Shift", alt = "Alt", super = "Super", Return = "Enter", space = "Space",
    Escape = "Esc", BackSpace = "Bksp", Delete = "Del", Page_Up = "PgUp", Page_Down = "PgDn",
    Left = "←", Right = "→", Up = "↑", Down = "↓" }
  local function legend(part)
    if LEGEND[part] then return LEGEND[part]:upper() end
    return (part:gsub("_", " ")):upper()
  end
  local function chord_parts(text)
    local out = {}
    text = tostring(text or "")
    local body, plus = text:match("^(.-)%+(%+)$")
    if plus then text = body end
    for part in text:gmatch("[^+]+") do out[#out + 1] = part end
    if plus then out[#out + 1] = "+" end
    return out
  end

  --- A shortcut recorder: a square field in a hairline that brightens with
  --- focus and brackets that close in on it, the chord as square keycaps
  --- -- plates on their own offset blocks, legends in caps -- rebuilt only
  --- when it changes; "PRESS KEYS…" while it listens and is empty; a chord
  --- another action has turns the frame to the alert and says so.
  function S.shortcut_recorder(t, spec)
    local function h() return box(t, spec) end
    local function warned() return (t.conflict or "") ~= "" end
    local caps = ui.Row { x = 12, gap = 8, align = "center", height = 30,
      y = function() return math.floor((h() - 30) / 2) end }
    local made, shown = {}, nil
    morf.effect("tsugumori.recorder." .. tostring(caps), function()
      local text = t.text or ""
      if text == shown then return end
      shown = text
      for _, node in ipairs(made) do ui.destroy(node, true) end
      made = {}
      for i, part in ipairs(chord_parts(text)) do
        local label = M.text { text = legend(part), anchors = { center_in = true }, font_size = theme.typography.menu,
          font_weight = 500, color = function() return C.onSurface end }
        local function w() return math.max(26, (label.layout_width or 0) + 16) end
        made[i] = ui.Item { width = function() return w() + 2 end, height = 28,
          ui.Rect { x = 2, y = 2, width = w, height = 26, color = function() return C.primary:alpha(.32) end },
          ui.Rect { width = w, height = 26, color = function() return C.surfaceContainerHigh end,
            border_width = 1, border_color = function() return stroke(C, "hover") end, label },
          enter = { opacity = 0, translate_y = -4 }, opacity = 1, translate_y = 0,
          behavior = { opacity = quick, translate_y = quick } }
        ui.reparent(made[i], caps)
      end
    end, { owner = caps })
    local function edge()
      if warned() then return alert() end
      return t.focused and C.primary or stroke(C, t.hovered and "hover" or "idle")
    end
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { left = true, right = true, top = true }, height = h,
          color = function() return C.surfaceContainer end,
          border_width = 1, border_color = edge, behavior = { border_color = quick } },
        caps },
      placeholder = M.text { x = 14, height = 20, y = function() return math.floor((h() - 20) / 2) end,
        text = function() return t.focused and "PRESS KEYS…" or tostring(spec.placeholder or "None"):upper() end,
        font_size = theme.typography.menu, font_weight = 500, color = function() return C.onSurfaceVariant end,
        opacity = function() return (t.text or "") == "" and 1 or 0 end, behavior = { opacity = quick } },
      trailing = ui.Row { anchors = { right = true, right_margin = 12 }, gap = 6, align = "center", height = 20,
        y = function() return math.floor((h() - 20) / 2) end,
        opacity = function() return warned() and 1 or 0 end, behavior = { opacity = quick },
        ui.Rect { width = 8, height = 8, color = alert },
        M.text { text = function() return tostring(t.conflict or ""):upper() end, font_size = theme.typography.menu,
          font_weight = 500, color = alert } },
      error = ui.Item { anchors = { left = true, right = true, top = true }, height = h,
        hud().corners { length = 7, weight = 2, color = function() return warned() and alert() or C.primary end,
          opacity = function() return (t.focused or warned()) and 1 or 0 end } },
      counter = ui.Item {},
    }
  end
end
