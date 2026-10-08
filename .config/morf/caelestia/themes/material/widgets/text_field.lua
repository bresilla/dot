-- Material 3's look for each TextField widget: filled fields (a tonal
-- well with 4 px top corners and an active indicator that grows from the
-- middle on focus) and outlined ones (a 1 px outline that thickens to 2 px
-- of the primary, cut by a notch the floating label sits in -- one distance
-- field, the notch tracking a node that springs open). Labels float up and
-- shrink by a move and a scale; the error role takes over the indicator,
-- the label and the supporting line while what is typed would not be
-- accepted. The input is the configuration's; what it accepts, the
-- archetype's.
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local function get(v) if type(v) == "function" then return v() end return v end
  local function quick() return { duration = theme.duration.small, easing = theme.ease.standard } end
  local function grow() return M.spring(460, 30) end

  local function sides(v)
    if type(v) == "table" then return v[1] or 0, v[2] or 0, v[3] or 0, v[4] or 0 end
    v = v or 0
    return v, v, v, v
  end
  local FOOT = 22
  local function foot(spec) return spec.supporting and FOOT or 0 end
  local function bad(t) return not t.acceptable and not t.empty end
  local function box(t, spec) return math.max(0, (t.height or 0) - foot(spec)) end
  --- The tone of what marks the field: error, primary while focused, else `idle`.
  local function tone(t, idle)
    return function()
      local c = C()
      if bad(t) then return c.error end
      if t.focused then return c.primary end
      return idle and c[idle] or c.onSurfaceVariant
    end
  end

  -- --------------------------------------------------------- pieces --

  --- A filled field's well: surfaceContainerHighest, 4 px top corners
  --- (`radius` to round it otherwise), a state layer under the pointer.
  local function filled(t, spec, radius)
    local r = radius or 4
    return ui.Rect { anchors = { left = true, right = true, top = true },
      height = function() return box(t, spec) end,
      top_left_radius = r, top_right_radius = r, bottom_left_radius = radius or 0, bottom_right_radius = radius or 0,
      color = function()
        local c = C()
        local base = c.surfaceContainerHighest
        if bad(t) then return base:mix(c.error, 0.06) end
        return (t.hovered and not t.focused) and base:mix(c.onSurface, 0.08) or base
      end,
      behavior = { color = quick() } }
  end

  --- A filled field's active indicator: 1 px of onSurfaceVariant, and 2 px
  --- of the primary (or the error role) grown from the middle on focus.
  local function indicator(t, spec)
    return ui.Item { anchors = { left = true, right = true, top = true }, z = 6,
      height = function() return box(t, spec) end,
      ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
        color = function() local c = C() return bad(t) and c.error or c.onSurfaceVariant end },
      ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 2, transform_origin_x = 0.5,
        scale_x = function() return (t.focused or bad(t)) and 1 or 0 end,
        color = function() local c = C() return bad(t) and c.error or c.primary end,
        behavior = { scale_x = grow(), color = quick() } } }
  end

  local SIZE = function() return theme.size.normal end
  --- The label (`spec.label`): in the middle of the field while it is empty
  --- and idle, floated and shrunk to three quarters once focused or holding
  --- text -- onto the outline when `outlined`. Returns the label and a
  --- binding of whether it is up.
  local function label(t, spec, o)
    o = o or {}
    if not spec.label then return nil, function() return false end end
    local l,_,r = sides(spec.inset)
    local size = SIZE()
    local lh = math.ceil(size * 1.3)
    local function up() return o.always or t.focused or not t.empty or spec.tags ~= nil end
    local function rest() return math.floor((box(t, spec) - lh) / 2) end
    local floated = o.outlined and -math.floor(lh * 0.75 / 2) or 7
    -- The outline notch follows the actual label, including after a font
    -- change, rather than the entire available text box.
    local measure=o.outlined and M.text {text=spec.label,font_size=size,height=lh,opacity=0} or nil
    local node = M.text { text = spec.label, x = l, height = lh, font_size = size, vertical_alignment = "center",
      width=function() return math.max(1e-3,math.min(t.width-l-r,measure and (measure.layout_width or 0) or t.width)) end,
      elide="right",
      transform_origin_x = 0, transform_origin_y = 0, z = 8, y = rest,
      translate_y = function() return up() and (floated - rest()) or 0 end,
      scale = function() return up() and 0.75 or 1 end,
      color = tone(t),
      behavior = { translate_y = grow(), scale = grow(), color = quick() },
      measure and ui.Item {width=1,height=1,clip=true,measure} or nil }
    return node, up
  end

  --- An outlined field's edge: 1 px of the outline, 2 px of the primary on
  --- focus, cut by a notch where the floated label sits -- a field of a box
  --- minus its inside minus a box tracking a node that springs open.
  local function outline(t, spec, text, up, radius)
    local r = radius or 4
    local l = sides(spec.inset)
    local notch = ui.Item { x = l - 4, y = -4, height = 8, transform_origin_x = 0,
      width = function() return text and ((text.layout_width or 0) * 0.75 + 8) or 0 end,
      scale_x = function() return up() and 1 or 0.001 end,
      behavior = { scale_x = grow() } }
    local field = ui.Sdf { anchors = { left = true, right = true, top = true }, z = 6,
      height = function() return box(t, spec) end,
      fill_color = function()
        local c = C()
        if bad(t) then return c.error end
        if t.focused then return c.primary end
        return t.hovered and c.onSurface or c.outline
      end,
      behavior = { fill_color = quick() },
      ui.SdfShape { shape = "box", anchors = { fill = true }, radius = r },
      ui.SdfShape { shape = "box", operation = "subtract", radius = math.max(0, r - 1),
        anchors = function() return { fill = true, margins = (t.focused or bad(t)) and 2 or 1 } end },
      text and ui.SdfShape { shape = "box", operation = "subtract", track = notch } or nil,
    }
    return ui.Item { anchors = { fill = true }, notch, field }
  end

  --- A glyph at the start, centred on the field.
  local function leading(t, spec, color)
    if not spec.icon then return nil end
    return M.icon(spec.icon, 22, color or function() local c = C() return bad(t) and c.error or c.onSurfaceVariant end,
      { x = 13, y = function() return math.floor((box(t, spec) - 22) / 2) end })
  end

  --- The supporting line, and the count against `max_length` at its end.
  local function supporting(t, spec)
    if not spec.supporting and not spec.max_length then return nil end
    local l = sides(spec.inset)
    local function ink() local c = C() return bad(t) and c.error or c.onSurfaceVariant end
    local node = ui.Item { anchors = { left = true, right = true, bottom = true }, height = FOOT }
    local counter
    if spec.max_length then
      counter=M.text { anchors = { right = true, bottom = true, right_margin = 16,
          bottom_margin = spec.supporting and 0 or 4 }, height = 18,
        font_size = theme.size.small - 1, color = ink,
        text = function() return ("%d/%d"):format(t.length or 0, spec.max_length) end }
      ui.reparent(counter,node)
    end
    if spec.supporting then
      ui.reparent(M.text {text=spec.supporting,x=l,anchors={bottom=true},height=18,
        width=function() return math.max(1e-3,t.width-l-16-(counter and (counter.layout_width or 0)+8 or 0)) end,
        elide="right",font_size=theme.size.small-1,color=ink,behavior={color=quick()}},node)
    end
    return node
  end

  local function blank() return ui.Item {} end

  -- -------------------------------------------------------------- looks --

  local LOOK = {}

  --- A filled text field.
  function LOOK.entry(t, spec)
    local text = label(t, spec)
    return { background = filled(t, spec), placeholder = text, error = indicator(t, spec),
      counter = supporting(t, spec) or blank() }
  end

  --- A password: filled, a lock before it, the reveal after (the archetype
  --- skin's).
  function LOOK.password(t, spec)
    local s = LOOK.entry(t, spec)
    s.leading = leading(t, spec)
    return s
  end

  --- An outlined field: `o.radius`, `o.always` (the label stays up).
  local function outlined(t, spec, o)
    o = o or {}
    local text, up = label(t, spec, { outlined = true, always = o.always })
    return { background = ui.Item {}, placeholder = text, error = outline(t, spec, text, up, o.radius),
      counter = supporting(t, spec) or blank() }
  end

  --- Material's search bar: a full capsule on surfaceContainerHigh, the
  --- magnifier before it; focus lifts it a tone.
  function LOOK.search(t, spec)
    return {
      background = ui.Rect { anchors = { left = true, right = true, top = true },
        height = function() return box(t, spec) end, radius = function() return box(t, spec) / 2 end,
        color = function()
          local c = C()
          if t.focused then return c.surfaceContainerHighest end
          return t.hovered and c.surfaceContainerHigh:mix(c.onSurface, 0.08) or c.surfaceContainerHigh
        end,
        shadow_color = function() return C().shadow:alpha(t.focused and 0.3 or 0) end,
        shadow_blur = 8, shadow_offset_y = 2,
        behavior = { color = quick(), shadow_color = quick() } },
      leading = leading(t, spec, function() local c = C() return t.focused and c.primary or c.onSurface end),
      error = blank(), placeholder = label(t, spec),
    }
  end

  --- Several lines: outlined, the label held on the outline, the count in
  --- the corner.
  function LOOK.text_area(t, spec) return outlined(t, spec, { always = true }) end

  --- An address: outlined, its glyph before it, and after it a check once
  --- it would be accepted or the error mark while not.
  local function judged(t, spec)
    local s = outlined(t, spec)
    s.leading = leading(t, spec)
    s.trailing = M.icon(function() return bad(t) and "error" or "check_circle" end, 22,
      function() local c = C() return bad(t) and c.error or c.primary end,
      { anchors = { right = true, right_margin = 12 }, fill = true,
        y = function() return math.floor((box(t, spec) - 22) / 2) end,
        opacity = function() return t.empty and 0 or 1 end,
        scale = function() return t.empty and 0.5 or 1 end,
        behavior = { opacity = quick(), scale = M.spring(420, 18) } })
    return s
  end
  LOOK.url = judged
  LOOK.email = judged

  --- A number: filled, its unit after it as a suffix.
  function LOOK.numeric_entry(t, spec)
    local s = LOOK.entry(t, spec)
    if spec.unit then
      local _, top, _, bottom = sides(spec.inset)
      s.trailing = M.text { text = spec.unit, anchors = { right = true, right_margin = 16 }, height = 22,
        y = function() return top + math.floor((box(t, spec) - top - bottom - 22) / 2) end,
        vertical_alignment = "center", color = function() return C().onSurfaceVariant end }
    end
    return s
  end

  --- A one-time code: an outlined cell per digit, the one being typed into
  --- in 2 px of the primary; the digits drawn in the cells.
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
      ui.reparent(ui.Rect { x = x, width = cell_w, height = h, radius = 12,
        color = function() local c = C() return done() and c.secondaryContainer or c.surfaceContainerHighest end,
        border_width = function() return current() and 2 or 0 end,
        border_color = function() return C().primary end,
        behavior = { color = quick() } }, cells)
      ui.reparent(M.text { x = x, width = cell_w, height = h, z = 3, horizontal_alignment = "center",
        vertical_alignment = "center", font_size = theme.size.large + 2, font_weight = 600,
        color = function() return C().onSecondaryContainer end,
        text = function() return (t.text or ""):sub(i, i) end,
        scale = function() return done() and 1 or 0.3 end, behavior = { scale = M.spring(420, 18) } }, cells)
    end
    return { background = cells, placeholder = blank(), error = blank(), counter = blank() }
  end

  --- Tags: filled, the entered ones as input chips (outlined, 8 px
  --- corners, a close mark) along the top.
  function LOOK.tag_input(t, spec)
    local s = LOOK.entry(t, spec)
    local l = sides(spec.inset)
    local row = { x = l, y = 24, gap = 8 }
    for _, tag in ipairs(spec.tags or {}) do
      local text = M.text { text = tostring(tag), x = 10, height = 26, vertical_alignment = "center",
        font_size = theme.size.small, color = function() return C().onSurfaceVariant end }
      row[#row + 1] = ui.Rect { height = 26, radius = 8, accessible_name = tostring(tag),
        width = function() return (text.layout_width or 0) + 36 end,
        color = function() return C().surfaceContainerLow end,
        border_width = 1, border_color = function() return C().outlineVariant end,
        text,
        M.icon("close", 16, function() return C().onSurfaceVariant end,
          { y = 5, x = function() return (text.layout_width or 0) + 14 end }) }
    end
    s.leading = ui.Row(row)
    return s
  end

  --- Mentions: a composer -- a capsule on surfaceContainerHigh, the @ in
  --- the primary, a send button in the primary container after it.
  function LOOK.mentions(t, spec)
    local function b() return box(t, spec) end
    return {
      background = ui.Rect { anchors = { left = true, right = true, top = true }, height = b,
        radius = function() return b() / 2 end,
        color = function() local c = C() return t.focused and c.surfaceContainerHighest or c.surfaceContainerHigh end,
        behavior = { color = quick() } },
      leading = leading(t, spec, function() return C().primary end),
      trailing = ui.Rect { anchors = { right = true, right_margin = 5 }, y = 5,
        width = function() return b() - 10 end, height = function() return b() - 10 end,
        radius = function() return t.empty and (b() - 10) / 2 or 12 end,
        color = function() local c = C() return t.empty and c.surfaceContainerHighest or c.primaryContainer end,
        behavior = { color = quick(), radius = M.spring(480, 18) },
        M.icon("send", 18, function() local c = C() return t.empty and c.onSurfaceVariant or c.onPrimaryContainer end,
          { anchors = { center_in = true } }) },
      error = blank(), placeholder = label(t, spec),
    }
  end

  --- A rename in place: the words alone until focused, then a filled well
  --- whose indicator grows in; a pencil after it while idle.
  function LOOK.inline_rename(t, spec)
    return {
      background = ui.Rect { anchors = { fill = true }, top_left_radius = 4, top_right_radius = 4,
        color = function()
          local c = C()
          if t.focused then return c.surfaceContainerHighest end
          return c.onSurface:alpha(t.hovered and 0.08 or 0)
        end, behavior = { color = quick() } },
      error = ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 2, transform_origin_x = 0.5,
        scale_x = function() return t.focused and 1 or 0 end, color = function() return C().primary end,
        behavior = { scale_x = grow() } },
      trailing = spec.icon and M.icon(spec.icon, 18, function() return C().onSurfaceVariant end,
        { anchors = { right = true, right_margin = 10, vertical_center = true },
          opacity = function() return t.focused and 0 or 1 end, behavior = { opacity = quick() } }) or nil,
      placeholder = blank(),
    }
  end

  --- An entry row: a list item on surfaceContainer with 16 px corners, the
  --- label floating, a tonal apply button after it.
  function LOOK.entry_row(t, spec)
    local text = label(t, spec)
    return {
      background = ui.Rect { anchors = { left = true, right = true, top = true },
        height = function() return box(t, spec) end, radius = 16,
        color = function()
          local c = C()
          return (t.hovered and not t.focused) and c.surfaceContainer:mix(c.onSurface, 0.08) or c.surfaceContainer
        end, behavior = { color = quick() } },
      placeholder = text,
      error = ui.Rect { anchors = { left = true, right = true, top = true }, z = 6, color = "transparent",
        height = function() return box(t, spec) end, radius = 16, border_width = 2,
        border_color = tone(t), opacity = function() return (t.focused or bad(t)) and 1 or 0 end,
        behavior = { opacity = quick() } },
      trailing = spec.icon and ui.Rect { anchors = { right = true, right_margin = 10, vertical_center = true },
        width = 36, height = 36, radius = 18,
        color = function() local c = C() return t.focused and c.secondaryContainer or c.surfaceContainerHighest end,
        behavior = { color = quick() },
        M.icon(spec.icon, 20, function() return C().onSecondaryContainer end, { anchors = { center_in = true } }) } or nil,
      counter = supporting(t, spec) or blank(),
    }
  end

  --- A filter: a filter chip -- an outlined, 8 px rounded field that turns
  --- to the secondary container while it filters.
  function LOOK.filter_field(t, spec)
    local function on() return not t.empty end
    return {
      background = ui.Rect { anchors = { fill = true }, radius = 8,
        color = function()
          local c = C()
          if on() then return c.secondaryContainer end
          return c.onSurface:alpha(t.hovered and 0.08 or 0)
        end,
        border_width = function() return on() and 0 or 1 end,
        border_color = function() return t.focused and C().primary or C().outlineVariant end,
        behavior = { color = quick() } },
      leading = leading(t, spec, function() local c = C() return on() and c.onSecondaryContainer or c.onSurfaceVariant end),
      error = blank(), placeholder = blank(),
    }
  end

  --- Code: a page on surfaceContainerLowest with a tonal gutter of line
  --- numbers in the mono face, ringed in the primary while focused.
  function LOOK.code_input(t, spec)
    local l, top = sides(spec.inset)
    local size = get(spec.font_size) or 14
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, radius = 12, color = function() return C().surfaceContainerLowest end,
          border_width = 1, border_color = function() return C().outlineVariant end },
        ui.Rect { anchors = { left = true, top = true, bottom = true, margins = 1 }, width = math.max(0, l - 8),
          top_left_radius = 11, bottom_left_radius = 11, color = function() return C().surfaceContainer end } },
      leading = M.text { x = 4, y = top, width = math.max(0, l - 14), horizontal_alignment = "right",
        font_family = theme.mono, font_size = size, line_height = 1.2, z = 3,
        color = function() return C().onSurfaceVariant end,
        text = function()
          local lines = select(2, (t.text or ""):gsub("\n", "\n")) + 1
          local out = {}
          for i = 1, lines do out[i] = tostring(i) end
          return table.concat(out, "\n")
        end },
      error = ui.Rect { anchors = { fill = true }, z = 6, radius = 12, color = "transparent", border_width = 2,
        border_color = function() return C().primary end, opacity = function() return t.focused and 1 or 0 end,
        behavior = { opacity = quick() } },
      placeholder = blank(),
    }
  end

  for widget, look in pairs(LOOK) do S[widget] = look end

  -- ------------------------------------------------------ shortcut recorder --

  local LEGEND = { ctrl = "Ctrl", shift = "Shift", alt = "Alt", super = "Super", Return = "Enter", space = "Space",
    Escape = "Esc", BackSpace = "Backspace", Delete = "Del", Page_Up = "PgUp", Page_Down = "PgDn",
    Left = "←", Right = "→", Up = "↑", Down = "↓" }
  local function legend(part)
    if LEGEND[part] then return LEGEND[part] end
    if #part == 1 then return part:upper() end
    return (part:gsub("_", " "))
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

  --- A shortcut recorder: an outlined field (1 px of the outline, 2 px of
  --- the primary while focused, the error role when another action has
  --- the chord) with the chord as keycap chips -- 8 px tonal chips that
  --- pop in on a spring, rebuilt only when it changes; "Press keys…"
  --- while it listens and is empty.
  function S.shortcut_recorder(t, spec)
    local function h() return box(t, spec) end
    local function warned() return (t.conflict or "") ~= "" end
    local caps = ui.Row { x = 12, gap = 6, align = "center", height = 30,
      y = function() return math.floor((h() - 30) / 2) end }
    local made, shown = {}, nil
    morf.effect("caelestia.material.recorder." .. tostring(caps), function()
      local text = t.text or ""
      if text == shown then return end
      shown = text
      for _, node in ipairs(made) do ui.destroy(node, true) end
      made = {}
      for i, part in ipairs(chord_parts(text)) do
        local label = M.text { text = legend(part), anchors = { center_in = true }, font_size = theme.size.small,
          font_weight = 500, color = function() return C().onSurfaceVariant end }
        made[i] = ui.Rect { height = 28, radius = 8,
          width = function() return math.max(28, (label.layout_width or 0) + 18) end,
          color = function() return C().surfaceContainerHigh end,
          border_width = 1, border_color = function() return C().outlineVariant end,
          scale = 1, enter = { scale = 0.5, opacity = 0 },
          behavior = { scale = M.spring(520, 20), opacity = quick() },
          label }
        ui.reparent(made[i], caps)
      end
    end, { owner = caps })
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { left = true, right = true, top = true }, height = h, radius = 4,
          color = function() local c = C() return t.hovered and c.onSurface:alpha(0.04) or c.onSurface:alpha(0) end,
          border_width = function() return (t.focused or warned()) and 2 or 1 end,
          border_color = function()
            local c = C()
            if warned() then return c.error end
            if t.focused then return c.primary end
            return t.hovered and c.onSurface or c.outline
          end,
          behavior = { color = quick(), border_color = quick() } },
        caps },
      placeholder = M.text { x = 16, height = 20, y = function() return math.floor((h() - 20) / 2) end,
        text = function() return t.focused and "Press keys…" or (spec.placeholder or "None") end,
        color = function() return C().onSurfaceVariant end,
        opacity = function() return (t.text or "") == "" and 1 or 0 end, behavior = { opacity = quick() } },
      trailing = ui.Row { anchors = { right = true, right_margin = 12 }, gap = 4, align = "center", height = 20,
        y = function() return math.floor((h() - 20) / 2) end,
        opacity = function() return warned() and 1 or 0 end, behavior = { opacity = quick() },
        M.icon("error", 18, function() return C().error end),
        M.text { text = function() return t.conflict or "" end, font_size = theme.size.small, font_weight = 500,
          color = function() return C().error end } },
      error = ui.Item {},
      counter = ui.Item {},
    }
  end
end
