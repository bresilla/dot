-- Tsugumori's looks for the Press widgets: square, framed, technical --
-- hairline frames, hatched runs, offset blocks, registration marks and
-- brackets, captions in caps that roll up through a strip of marks when the
-- pointer arrives -- each widget the instrument its name promises: a
-- suggested action is a lit block with a hatched go-end, a raised button a
-- plate on its own offset block that it sinks onto, an elevated one over a
-- hatched shadow, a circular one a diamond, a tile a register with its
-- state read out. Every press has the theme's feedback (wash, glint, marks,
-- the keyboard's brackets). Widgets not named here (pill, icon, switch,
-- checkbox, radio, menu items) keep the archetype's look (skins.lua). The
-- behaviour is the archetype's.
local morf = require("morf")
local ui = require("morf.ui")
local stripes = require("themes.tsugumori.stripes")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local function get(v) if type(v) == "function" then return v() end return v end
  local quick = { duration = 140, easing = "out_cubic" }
  local MARK = "M0 0 H7 V1.5 H1.5 V7 H0 Z"
  local FS = theme.size.small
  local function none() return nil end
  local SLOTS = { "background", "content", "indicator", "icon", "label", "badge" }
  local function full(slots)
    for _, name in ipairs(SLOTS) do if slots[name] == nil then slots[name] = none end end
    return slots
  end
  local function H(t) return (t.height and t.height > 0) and t.height or 32 end
  local function W(t) return (t.width and t.width > 0) and t.width or 32 end
  local function dim(t) return function() return t.enabled == false and 0.4 or 1 end end
  local function alert() return M.signal("alert")() end
  local function with(kind, props, ...)
    for i = 1, select("#", ...) do
      local child = select(i, ...)
      if child then props[#props + 1] = child end
    end
    return kind(props)
  end
  -- A drawing size for what is drawn once and cut to its box: the spec's
  -- own when it gives numbers.
  local function box_of(spec, w, h)
    return math.max(w or 0, tonumber(get(spec.width)) or 0, 16), math.max(h or 0, tonumber(get(spec.height)) or 0, 16)
  end

  --- A hatched run cut to `props` (anchors, width, height...): `/`
  --- stripes drawn once at `w` x `h` and clipped.
  local function hatch(props, w, h, color, gap, weight)
    props.clip = true
    props[#props + 1] = stripes.box { width = w, height = h, gap = gap or 6, weight = weight or 2, color = color }
    return ui.Item(props)
  end

  -- The press feedback (as skins.lua's): a faint wash, one glint across
  -- on entry or press, the registration marks parting while hovered and
  -- the keyboard's brackets -- built the first time the control is reached.
  local function feedback(t, id)
    return function()
      id = id or "tsugumori-control"
      local holder = ui.Item { anchors = { fill = true }, z = 40 }
      local wash = ui.Rect { id = id .. "-wash", anchors = { fill = true },
        color = function() return C.primary end, opacity = 0,
        behavior = { opacity = { duration = 140, easing = "out_cubic" } } }
      local glint = ui.Path { id = id .. "-glint", x = -36, width = 28,
        height = function() return math.max(1, t.height) end,
        view_box = { 0, 0, 28, 100 }, d = "M20 0 H28 L8 100 H0 Z",
        fill_color = function() return C.primary end, opacity = 0 }
      ui.reparent(wash, holder)
      ui.reparent(ui.Item { id = id .. "-glint-clip", anchors = { fill = true }, clip = true, glint }, holder)
      local marks = {}
      for i, corner in ipairs { { left = true, top = true }, { right = true, bottom = true } } do
        marks[i] = ui.Path { id = id .. "-mark-" .. i, anchors = corner, width = 7, height = 7,
          view_box = { 0, 0, 7, 7 }, d = MARK, rotation = i == 1 and 0 or 180,
          fill_color = function() return C.primary end, opacity = 0,
          behavior = { translate_x = { duration = 340, easing = "out_cubic" },
            translate_y = { duration = 340, easing = "out_cubic" }, opacity = { duration = 180 } } }
        ui.reparent(marks[i], holder)
      end
      ui.reparent(hud().corners { length = 6, weight = 2, color = function() return C.primary end,
        visible = function() return t.visual_focus end }, holder)
      local hovered, pressed, running = false, false, nil
      morf.effect(id .. ".feedback", function()
        local over, down = t.hovered, t.down
        local fire = (over and not hovered) or (down and not pressed)
        hovered, pressed = over, down
        wash.opacity = down and 0.18 or over and 0.055 or 0
        for i, mark in ipairs(marks) do
          local shift = (over and not down) and (i == 1 and -3 or 3) or 0
          mark.translate_x, mark.translate_y = shift, shift
          mark.opacity = over and 1 or 0
        end
        if not over and not down then
          if running then running:stop() running = nil end
          glint.opacity = 0
        elseif fire then
          if running then running:stop() end
          running = morf.animation.play { { parallel = {
            { node = glint, property = "x", from = -36, to = t.width + 36, duration = 330, easing = "out_cubic" },
            { node = glint, property = "opacity", duration = 330, keyframes = {
              { at = 0, value = 0 }, { at = .13, value = .33 }, { at = .65, value = .27 }, { at = 1, value = 0 },
            } },
          } }, on_finished = function() running = nil end }
        end
      end, { owner = holder })
      return holder
    end
  end

  -- Registration marks always shown on the top-left / bottom-right corners.
  local function marks(color, l)
    l = l or 7
    local d = ("M0 0 H%g V1.5 H1.5 V%g H0 Z"):format(l, l)
    return ui.Item { anchors = { fill = true },
      ui.Path { anchors = { left = true, top = true }, width = l, height = l, view_box = { 0, 0, l, l }, d = d,
        fill_color = color },
      ui.Path { anchors = { right = true, bottom = true }, width = l, height = l, view_box = { 0, 0, l, l }, d = d,
        rotation = 180, fill_color = color } }
  end

  --- A caption in caps that rolls up through a strip of marks when the
  --- pointer arrives (the theme's button label). `text` a string or fn.
  local function caption(t, text, ink, size)
    size = size or FS
    local function words() return tostring(get(text) or ""):upper() end
    local measure = M.menu_label { text = words, font_size = size, height = 18, opacity = 0 }
    local function width() return math.max(1, (measure.layout_width or 0) + 2) end
    local strip = ui.Column { y = -36, gap = 0,
      M.menu_label { text = "/ / / / / / / /", font_size = size, height = 18, color = ink },
      M.menu_label { text = "+ | + | + | + |", font_size = size, height = 18, color = ink },
      M.menu_label { text = words, font_size = size, height = 18, color = ink } }
    local node = ui.Item { width = width, height = 18, clip = true, measure, strip }
    local was, running = false, nil
    morf.effect("tsugumori.press.caption." .. tostring(strip), function()
      local now = t.hovered
      if was == now then return end
      was = now
      if running then running:stop() running = nil end
      if now then
        running = morf.animation.play { { node = strip, property = "y", from = 0, to = -36, duration = 340,
          easing = "out_cubic" } }
      else strip.y = -36 end
    end, { owner = strip })
    return node
  end

  --- An icon and a rolling caption in a row, centred (or from `start`).
  local function legend(t, spec, ink, o)
    o = o or {}
    local glyph = o.icon ~= nil and o.icon or spec.icon
    local text = o.label ~= nil and o.label or spec.label
    local props = { gap = o.gap or 8, align = "center" }
    if o.start then props.anchors = { left = true, left_margin = o.start, vertical_center = true }
    else props.anchors = { center_in = true } end
    return with(ui.Row, props,
      o.pre,
      glyph and M.icon(glyph, o.glyph or 17, o.icon_ink or ink) or nil,
      (text and text ~= "") and caption(t, text, ink, o.size) or nil,
      o.post)
  end

  --- A framed button: `fill`, `edge` (colour fns), `ink`, `under` (nodes
  --- under the plate), `over` (nodes over it), `sink` (px the plate moves
  --- while pressed), and what `legend` takes.
  local function framed(t, spec, o)
    local function ink() return get(o.ink) end
    local plate = ui.Rect { anchors = { fill = true }, color = o.fill or "transparent",
      border_width = o.edge and (o.edge_width or 1) or 0, border_color = o.edge,
      translate_x = o.sink and function() return t.down and o.sink or 0 end or nil,
      translate_y = o.sink and function() return t.down and o.sink or 0 end or nil,
      behavior = { color = quick, border_color = quick, translate_x = quick, translate_y = quick } }
    local ground = { anchors = { fill = true }, opacity = dim(t) }
    for _, node in ipairs(o.under or {}) do ground[#ground + 1] = node end
    ground[#ground + 1] = plate
    for _, node in ipairs(o.over or {}) do ground[#ground + 1] = node end
    local body = o.content
    if body == nil then body = legend(t, spec, ink, o) end
    if o.sink and body then
      body = ui.Item { anchors = { fill = true },
        translate_x = function() return t.down and o.sink or 0 end,
        translate_y = function() return t.down and o.sink or 0 end,
        behavior = { translate_x = quick, translate_y = quick }, body }
    end
    return full {
      background = ui.Item(ground),
      content = body or none,
      badge = feedback(t, spec.id),
    }
  end

  local function idle() return stroke(C, "idle") end
  local function hot(t) return function() return t.hovered and stroke(C, "focus") or stroke(C, "idle") end end

  -- ------------------------------------------------------------ actions --

  --- A push button: a neutral plate in a hairline frame, the frame lit
  --- under the pointer.
  function S.push(t, spec)
    return framed(t, spec, { fill = function() return C.surfaceContainerHigh end, edge = hot(t),
      ink = function() return C.onSurface end })
  end

  --- The suggested action: a lit primary block with a hatched go-end and
  --- an arrow that steps forward under the pointer.
  function S.suggested(t, spec)
    local w, h = box_of(spec, 0, 40)
    local function ink() return get(spec.ink) or C.onPrimary end
    return framed(t, spec, {
      fill = function() local c = get(spec.color) or C.primary return t.down and c:mix(ink(), .2) or c end,
      ink = ink,
      over = { hatch({ anchors = { right = true, top = true, bottom = true }, width = 18 }, 18, h,
        function() return ink():alpha(.35) end, 5, 1.5) },
      post = ui.Item { width = 16, height = 16,
        translate_x = function() return t.hovered and 3 or 0 end, behavior = { translate_x = quick },
        M.icon("arrow_forward", 16, ink, { anchors = { center_in = true } }) } })
  end

  --- The destructive action: the alert tone -- a tinted plate, an alert
  --- frame and a hatched band at its head.
  function S.destructive(t, spec)
    local w, h = box_of(spec, 0, 40)
    return framed(t, spec, {
      fill = function() return alert():alpha(t.down and .3 or (t.hovered and .2 or .12)) end,
      edge = function() return alert():alpha(t.hovered and .95 or .7) end,
      ink = alert,
      over = { hatch({ anchors = { left = true, top = true, bottom = true, margins = 1 }, width = 10 }, 10, h,
        function() return alert():alpha(.7) end, 4, 1.5) } })
  end

  --- A flat button: the caption alone, the feedback for a ground.
  function S.flat(t, spec)
    return framed(t, spec, { ink = function() return t.hovered and C.primary or C.onSurfaceVariant end })
  end

  --- A raised button: a plate standing on its own offset block, sinking
  --- onto it when pressed.
  function S.raised(t, spec)
    return framed(t, spec, {
      under = { ui.Rect { anchors = { fill = true }, translate_x = 4, translate_y = 4,
        color = function() return C.primary:alpha(t.hovered and .45 or .28) end, behavior = { color = quick } } },
      fill = function() return C.surfaceContainerHighest end, edge = hot(t), sink = 3,
      ink = function() return C.onSurface end, icon_ink = function() return C.primary end })
  end

  --- An outlined button: a lit hairline with registration marks at two
  --- corners, nothing inside.
  function S.outlined(t, spec)
    return framed(t, spec, { edge = function() return t.hovered and stroke(C, "focus") or stroke(C, "hover") end,
      ink = function() return C.primary end,
      over = { marks(function() return C.primary end) } })
  end

  --- A text button: the primary caption between square brackets that
  --- part under the pointer.
  function S.text(t, spec)
    local function bracket(left)
      return ui.Path { anchors = left and { left = true, vertical_center = true } or { right = true, vertical_center = true },
        width = 6, height = 18, view_box = { 0, 0, 6, 18 },
        d = left and "M6 0 H0 V18 H6 V16.5 H1.5 V1.5 H6 Z" or "M0 0 H6 V18 H0 V16.5 H4.5 V1.5 H0 Z",
        translate_x = function() return t.hovered and (left and -3 or 3) or 0 end,
        fill_color = function() return C.primary:alpha(t.hovered and 1 or .55) end,
        behavior = { translate_x = { duration = 240, easing = "out_cubic" }, fill_color = quick } }
    end
    return framed(t, spec, { ink = function() return C.primary end,
      over = { ui.Item { anchors = { fill = true, left_margin = 6, right_margin = 6 }, bracket(true), bracket(false) } } })
  end

  --- A link: the primary in plain case over a dashed rule that turns solid
  --- under the pointer, an arrow out after it.
  function S.link(t, spec)
    local w = box_of(spec, 160, 0)
    local function ink() return C.primary end
    local text = M.text { text = spec.label or "", font_size = FS, color = ink }
    return full {
      background = ui.Item { anchors = { fill = true }, opacity = dim(t) },
      content = ui.Row { anchors = { center_in = true }, gap = 4, align = "center",
        ui.Item { width = function() return text.layout_width or 0 end, height = 20, text,
          ui.Path { anchors = { left = true, right = true, bottom = true }, height = 2, view_box = { 0, 0, w, 2 },
            d = ("M0 1 H%g"):format(w), fill_color = "transparent", stroke_width = 1,
            stroke_color = function() return C.primary:alpha(.6) end, dash = { 3, 3 },
            opacity = function() return t.hovered and 0 or 1 end, behavior = { opacity = quick } },
          ui.Rect { anchors = { left = true, bottom = true }, height = 1,
            width = function() return t.hovered and (text.layout_width or 0) or 0 end,
            color = ink, behavior = { width = { duration = 240, easing = "out_cubic" } } } },
        M.icon("north_east", 14, ink) },
      badge = feedback(t, spec.id),
    }
  end

  --- A tonal button: a primary tint with a hatched strip at its head.
  function S.tonal(t, spec)
    local w, h = box_of(spec, 0, 40)
    return framed(t, spec, {
      fill = function() return C.primary:alpha(t.down and .26 or (t.hovered and .2 or .14)) end,
      ink = function() return C.primary end,
      over = { hatch({ anchors = { left = true, top = true, bottom = true }, width = 8 }, 8, h,
        function() return C.primary:alpha(.6) end, 4, 1.5) } })
  end

  --- An elevated button: a plate over a hatched shadow that drops further
  --- under the pointer.
  function S.elevated(t, spec)
    local w, h = box_of(spec, 120, 40)
    return framed(t, spec, {
      under = { hatch({ anchors = { fill = true },
        translate_x = function() return t.hovered and 6 or 4 end,
        translate_y = function() return t.hovered and 6 or 4 end,
        behavior = { translate_x = quick, translate_y = quick } }, w, h,
        function() return C.primary:alpha(.45) end, 5, 1.5) },
      fill = function() return C.surfaceContainerHighest end, edge = hot(t), sink = 2,
      ink = function() return C.onSurface end, icon_ink = function() return C.primary end })
  end

  -- ------------------------------------------------------- icon presses --

  -- A square icon cell: `glyph` (a name or fn), `fill`, `edge`, `ink`,
  -- `nudge` (fn: a lean under the pointer), `size`, `over`.
  local function cell(t, spec, glyph, o)
    local function ink() return get(o.ink) end
    return framed(t, spec, { fill = o.fill, edge = o.edge or hot(t), ink = o.ink, over = o.over, under = o.under,
      content = ui.Item { anchors = { center_in = true }, width = 24, height = 24,
        translate_x = o.nudge and function() return t.hovered and o.nudge() or 0 end or nil,
        behavior = { translate_x = quick },
        M.icon(glyph, o.size or 20, ink, { anchors = { center_in = true }, fill = o.fill_icon }) } })
  end

  --- The circular button, squared the theme's way: a diamond frame with
  --- its icon, lit under the pointer.
  function S.circular(t, spec)
    local diamond = "M50 1 L99 50 L50 99 L1 50 Z"
    return framed(t, spec, {
      under = { ui.Path { anchors = { fill = true }, view_box = { 0, 0, 100, 100 }, d = diamond,
        fill_color = function() return t.down and C.primary:alpha(.3) or C.surfaceContainerHigh end,
        stroke_color = function() return t.hovered and C.primary or stroke(C, "hover") end, stroke_width = 3,
        stroke_join = "miter", behavior = { fill_color = quick, stroke_color = quick } } },
      content = M.icon(spec.icon or "add", 20, function() return t.hovered and C.primary or C.onSurface end,
        { anchors = { center_in = true } }) })
  end

  --- A close key: a square cell with the cross, gone to the alert tone
  --- under the pointer.
  function S.close(t, spec)
    return cell(t, spec, spec.icon or "close", {
      edge = function() return t.hovered and alert():alpha(.8) or stroke(C, "idle") end,
      fill = function() return t.hovered and alert():alpha(.12) or C.surfaceContainerHigh end,
      ink = function() return t.hovered and alert() or C.onSurfaceVariant end })
  end

  --- Help: a square cell with the question mark and a hatched corner.
  function S.help(t, spec)
    return cell(t, spec, "question_mark", { fill = function() return C.surfaceContainerHigh end,
      ink = function() return t.hovered and C.primary or C.onSurfaceVariant end,
      over = { hatch({ anchors = { right = true, top = true, margins = 1 }, width = 10, height = 10 }, 10, 10,
        function() return C.primary:alpha(.6) end, 4, 1.5) } })
  end

  --- Back and forward: square cells whose arrow steps the way it goes
  --- under the pointer (mirrored right to left).
  local function arrow(way)
    return function(t, spec)
      local function sign() return ((way == "back") ~= (t.mirrored == true)) and -1 or 1 end
      return cell(t, spec, function() return sign() < 0 and "arrow_back" or "arrow_forward" end, {
        fill = function() return C.surfaceContainerHigh end,
        ink = function() return t.hovered and C.primary or C.onSurface end, nudge = function() return sign() * 3 end })
    end
  end
  S.back = arrow("back")
  S.forward = arrow("forward")

  --- A repeat key: a square cell that, held, fills with a hatched run and
  --- lights its frame for as long as it repeats.
  function S.repeat_button(t, spec)
    local w, h = box_of(spec, 40, 40)
    return cell(t, spec, spec.icon or "add", { fill = function() return C.surfaceContainerHigh end,
      edge = function() return t.down and C.primary or (t.hovered and stroke(C, "focus") or stroke(C, "idle")) end,
      ink = function() return t.down and C.primary or C.onSurface end,
      under = {},
      over = { hatch({ anchors = { fill = true, margins = 1 }, opacity = function() return t.down and 1 or 0 end,
        behavior = { opacity = quick } }, w, h, function() return C.primary:alpha(.35) end, 5, 1.5) } })
  end

  --- A disclosure button: its caption and a square plus whose upright
  --- folds flat into a minus while open.
  function S.disclosure_button(t, spec)
    local function ink() return t.checked and C.primary or C.onSurface end
    local sign = ui.Item { width = 12, height = 12,
      ui.Rect { x = 0, y = 5, width = 12, height = 2, color = function() return C.primary end },
      ui.Rect { x = 5, width = 2, color = function() return C.primary end,
        y = function() return t.checked and 5 or 0 end, height = function() return t.checked and 2 or 12 end,
        behavior = { y = quick, height = quick } } }
    return framed(t, spec, { fill = function() return C.surfaceContainerHigh end,
      edge = function() return t.checked and C.primary or (t.hovered and stroke(C, "focus") or stroke(C, "idle")) end,
      ink = ink, gap = 10, post = sign })
  end

  -- -------------------------------------------------- feedback presses --

  --- Copy: a framed key whose icon and caption turn to a tick and
  --- "copied" on a lit plate for a moment after the press.
  function S.copy(t, spec)
    local copied = morf.signal("tsugumori.copy." .. tostring({}), false)
    local function ink() return copied:get() and C.primary or C.onSurface end
    local glyph = M.icon(function() return copied:get() and "check" or (spec.icon or "content_copy") end, 17, ink)
    local row = with(ui.Row, { anchors = { center_in = true }, gap = 8, align = "center" }, glyph,
      spec.label and caption(t, function() return copied:get() and "Copied" or spec.label end, ink) or nil)
    local was, timer = false, nil
    morf.effect("tsugumori.copy.watch." .. tostring(row), function()
      local down = t.down
      if was and not down and t.hovered then
        copied:set(true)
        if timer then timer:cancel() end
        timer = morf.timer(1400, function() timer = nil copied:set(false) end, false)
      end
      was = down
    end, { owner = row })
    return framed(t, spec, {
      fill = function() return copied:get() and C.primary:alpha(.16) or C.surfaceContainerHigh end,
      edge = function() return copied:get() and C.primary or (t.hovered and stroke(C, "focus") or stroke(C, "idle")) end,
      content = row })
  end

  --- A busy key: the theme's running bars before its caption, a hatched
  --- run along its foot.
  function S.loading(t, spec)
    local w = box_of(spec, 140, 0)
    local function ink() return C.onSurfaceVariant end
    return framed(t, spec, { fill = function() return C.surfaceContainerHigh end, edge = idle,
      over = { hatch({ anchors = { left = true, right = true, bottom = true, margins = 1 }, height = 3 }, w, 3,
        function() return C.primary:alpha(.6) end, 4, 1.5) },
      content = with(ui.Row, { anchors = { center_in = true }, gap = 10, align = "center" },
        M.loading(20, function() return C.primary end),
        spec.label and caption(t, spec.label, ink) or nil) })
  end

  -- ------------------------------------------------------------ toggles --

  --- A toggle: a framed key with a status pip; on, a lit block.
  function S.toggle(t, spec)
    local function ink() return t.checked and C.onPrimary or C.onSurface end
    local pip = ui.Rect { width = 7, height = 7, border_width = 1,
      color = function() return t.checked and C.onPrimary or "transparent" end,
      border_color = function() return t.checked and C.onPrimary or C.outline end, behavior = { color = quick } }
    return framed(t, spec, {
      fill = function() return t.checked and C.primary or C.surfaceContainerHigh end,
      edge = function() return t.checked and C.primary or (t.hovered and stroke(C, "focus") or stroke(C, "idle")) end,
      ink = ink, pre = pip })
  end

  --- A toggle group's member (`position`): square cells sharing their
  --- frames; the chosen one a primary tint with a lit bar along its foot.
  function S.toggle_group_member(t, spec)
    local pos = spec.position
    local function ink() return t.checked and C.primary or C.onSurfaceVariant end
    local glyph = spec.icon
    local body = (glyph and not spec.label) and M.icon(glyph, 20, ink, { anchors = { center_in = true } })
      or legend(t, spec, ink)
    return full {
      background = ui.Item { anchors = { fill = true, left_margin = (pos == "middle" or pos == "last") and -1 or 0 },
        opacity = dim(t),
        ui.Rect { anchors = { fill = true },
          color = function() return t.checked and C.primary:alpha(.16) or C.surfaceContainerHigh end,
          border_width = 1, border_color = function() return t.checked and stroke(C, "focus") or stroke(C, "idle") end,
          behavior = { color = quick } },
        ui.Rect { anchors = { left = true, right = true, bottom = true, margins = 1 },
          height = function() return t.checked and 3 or 0 end, color = function() return C.primary end,
          behavior = { height = quick } } },
      content = body,
      badge = feedback(t, spec.id),
    }
  end

  --- A segment of a linked row (`position`): square cells sharing their
  --- frames; the chosen one a lit block. A layout's own segment (no
  --- label, no icon) gets only the feedback.
  function S.segment(t, spec)
    if not spec.label and not spec.icon then return { badge = feedback(t, spec.id) } end
    local pos = spec.position
    local function ink() return t.checked and C.onPrimary or C.onSurface end
    return full {
      background = ui.Item { anchors = { fill = true, left_margin = (pos == "middle" or pos == "last") and -1 or 0 },
        opacity = dim(t),
        ui.Rect { anchors = { fill = true }, color = function() return t.checked and C.primary or C.surfaceContainerHigh end,
          border_width = 1, border_color = function() return t.checked and C.primary or stroke(C, "idle") end,
          behavior = { color = quick } } },
      content = legend(t, spec, ink),
      badge = feedback(t, spec.id),
    }
  end

  --- A rating star: filled in the primary when chosen, an outline in the
  --- quiet ink otherwise, in a frame that shows under the pointer.
  function S.rating_star(t, spec)
    return full {
      background = ui.Rect { anchors = { fill = true, margins = 2 }, color = "transparent", border_width = 1,
        border_color = function() return t.hovered and stroke(C, "focus") or stroke(C, "quiet"):alpha(0) end,
        behavior = { border_color = quick } },
      icon = M.icon("star", 22, function() return t.checked and C.primary or C.onSurfaceVariant end,
        { anchors = { center_in = true }, fill = function() return t.checked end }),
      badge = feedback(t, spec.id),
    }
  end

  -- -------------------------------------------------------------- chips --

  --- An assist chip: a hairline frame, its icon in the primary.
  function S.chip_assist(t, spec)
    return framed(t, spec, { edge = hot(t), fill = function() return C.surfaceContainer end,
      ink = function() return C.onSurface end, icon_ink = function() return C.primary end, glyph = 16, gap = 6 })
  end

  --- A filter chip: a frame; chosen, a hatched fill, a lit frame and a
  --- block before its caption.
  function S.chip_filter(t, spec)
    local w, h = box_of(spec, 120, 32)
    local function ink() return t.checked and C.primary or C.onSurfaceVariant end
    local pip = ui.Rect { width = 8, height = 8, border_width = 1,
      color = function() return t.checked and C.primary or "transparent" end,
      border_color = function() return t.checked and C.primary or C.outline end, behavior = { color = quick } }
    return framed(t, spec, {
      fill = function() return t.checked and C.primary:alpha(.1) or C.surfaceContainer end,
      edge = function() return t.checked and stroke(C, "focus") or (t.hovered and stroke(C, "hover") or stroke(C, "idle")) end,
      under = {},
      over = { hatch({ anchors = { fill = true, margins = 1 }, opacity = function() return t.checked and 1 or 0 end,
        behavior = { opacity = quick } }, w, h, function() return C.primary:alpha(.22) end, 6, 1.5) },
      ink = ink, pre = pip, gap = 8 })
  end

  --- An input chip: its icon, its caption and a remove key in a cell of
  --- its own behind a hairline.
  function S.chip_input(t, spec)
    local function ink() return C.onSurface end
    return framed(t, spec, { edge = hot(t), fill = function() return C.surfaceContainer end, ink = ink,
      icon_ink = function() return C.primary end, glyph = 16, gap = 6,
      over = { ui.Item { anchors = { right = true, top = true, bottom = true }, width = 28,
        ui.Rect { anchors = { left = true, top = true, bottom = true }, width = 1, color = idle },
        M.icon("close", 16, function() return t.hovered and alert() or C.onSurfaceVariant end,
          { anchors = { center_in = true } }) } },
      content = with(ui.Row, { anchors = { left = true, left_margin = 10, vertical_center = true }, gap = 6, align = "center" },
        spec.icon and M.icon(spec.icon, 16, function() return C.primary end) or nil,
        caption(t, spec.label or "", ink)) })
  end

  --- A suggestion chip: no frame -- registration marks at two corners
  --- and its caption in the quiet ink.
  function S.chip_suggestion(t, spec)
    return framed(t, spec, { ink = function() return t.hovered and C.primary or C.onSurfaceVariant end,
      over = { marks(function() return t.hovered and C.primary or stroke(C, "corner") end) } })
  end

  --- A tag: a small lit block with its caption in caps and a notch.
  function S.tag(t, spec)
    return full {
      background = ui.Item { anchors = { fill = true }, opacity = dim(t),
        ui.Rect { anchors = { fill = true }, color = function() return C.primary end },
        ui.Rect { anchors = { left = true, vertical_center = true, left_margin = 4 }, width = 3, height = 8,
          color = function() return C.onPrimary end } },
      content = M.menu_label { anchors = { center_in = true, horizontal_center_offset = 3 },
        text = tostring(spec.label or ""):upper(), font_size = FS, color = function() return C.onPrimary end },
      badge = feedback(t, spec.id),
    }
  end

  -- -------------------------------------------------- tiles, cards, rows --

  --- A tile: a register -- a framed plate with its icon, caption and
  --- state line, and its state read out at the end; on, a lit frame and a
  --- hatched band down its far edge.
  function S.tile(t, spec)
    local w, h = box_of(spec, 200, 64)
    local function ink() return t.checked and C.primary or C.onSurface end
    local function words() return math.max(0, W(t) - 110) end
    return framed(t, spec, {
      fill = function() return t.checked and C.primary:alpha(.12) or C.surfaceContainerHigh end,
      edge = function() return t.checked and C.primary or (t.hovered and stroke(C, "focus") or stroke(C, "idle")) end,
      over = {
        hatch({ anchors = { right = true, top = true, bottom = true, margins = 1 }, width = 14,
          opacity = function() return t.checked and 1 or 0 end, behavior = { opacity = quick } }, 14, h,
          function() return C.primary:alpha(.6) end, 5, 1.5),
        M.menu_label { anchors = { right = true, right_margin = 22, vertical_center = true }, font_size = FS,
          text = function() return t.checked and "ON" or "OFF" end,
          color = function() return t.checked and C.primary or C.onSurfaceVariant end },
        marks(function() return t.checked and C.primary or stroke(C, "corner") end, 6) },
      content = ui.Row { anchors = { left = true, left_margin = 14, vertical_center = true }, gap = 12, align = "center",
        M.icon(spec.icon or "toggle_on", 22, ink, { fill = function() return t.checked end }),
        with(ui.Column, { gap = 2 },
          M.menu_label { text = tostring(spec.label or ""):upper(), font_size = theme.size.normal, color = ink,
            elide = "right", width = words },
          spec.subtitle and M.text { text = spec.subtitle, font_size = FS, color = function() return C.onSurfaceVariant end,
            elide = "right", width = words } or nil) } })
  end

  --- An action card: a framed plate, its icon in a tinted square cell, a
  --- caption and a line, and an arrow that steps in under the pointer.
  function S.card_action(t, spec)
    local function words() return math.max(0, W(t) - 112) end
    return framed(t, spec, { fill = function() return C.surfaceContainer end, edge = hot(t),
      over = {
        ui.Item { anchors = { right = true, right_margin = 14, vertical_center = true }, width = 22, height = 22,
          translate_x = function() return t.hovered and 4 or 0 end, behavior = { translate_x = quick },
          M.icon("arrow_forward", 20, function() return t.hovered and C.primary or C.onSurfaceVariant end,
            { anchors = { center_in = true } }) },
        marks(function() return stroke(C, "corner") end, 8) },
      content = with(ui.Row, { anchors = { left = true, left_margin = 14, vertical_center = true }, gap = 14,
          align = "center" },
        spec.icon and ui.Rect { width = 40, height = 40, color = function() return C.primary:alpha(.14) end,
          border_width = 1, border_color = function() return stroke(C, "hover") end,
          M.icon(spec.icon, 20, function() return C.primary end, { anchors = { center_in = true } }) } or nil,
        with(ui.Column, { gap = 3 },
          M.menu_label { text = tostring(spec.label or ""):upper(), font_size = theme.size.normal,
            color = function() return C.onSurface end, elide = "right", width = words },
          spec.subtitle and M.text { text = spec.subtitle, font_size = FS, color = function() return C.onSurfaceVariant end,
            elide = "right", width = words } or nil)) })
  end

  --- An activatable row: no plate -- an index bar at its head that grows
  --- and lights under the pointer, its icon, caption and line, a chevron
  --- and the list's quiet rule under it.
  function S.row_activation(t, spec)
    local left = spec.icon and 46 or 16
    local function words() return math.max(0, W(t) - left - 40) end
    return framed(t, spec, {
      under = {
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1, color = function() return stroke(C, "quiet") end },
        ui.Rect { anchors = { left = true, vertical_center = true }, width = 3,
          height = function() return t.hovered and H(t) - 8 or math.max(8, H(t) / 3) end,
          color = function() return t.hovered and C.primary or C.outline end,
          behavior = { height = { duration = 240, easing = "out_cubic" }, color = quick } },
        spec.icon and M.icon(spec.icon, 20, function() return t.hovered and C.primary or C.onSurfaceVariant end,
          { x = 16, anchors = { vertical_center = true } }) or nil,
        M.icon("chevron_right", 20, function() return C.onSurfaceVariant end,
          { anchors = { right = true, right_margin = 8, vertical_center = true } }) },
      content = with(ui.Column, { x = left, anchors = { vertical_center = true }, gap = 2 },
        M.text { text = spec.label or "", font_size = theme.size.normal, color = function() return C.onSurface end,
          elide = "right", width = words },
        spec.subtitle and M.text { text = spec.subtitle, font_size = FS, color = function() return C.onSurfaceVariant end,
          elide = "right", width = words } or nil) })
  end

  --- A key: a square cap in a hairline on a lip of the outline that it
  --- presses down onto.
  function S.keycap(t, spec)
    return full {
      background = ui.Item { anchors = { fill = true }, opacity = dim(t),
        ui.Rect { anchors = { fill = true }, color = function() return C.outline end },
        ui.Rect { anchors = { left = true, right = true, top = true },
          height = function() return math.max(0, H(t) - (t.down and 1 or 3)) end,
          translate_y = function() return t.down and 2 or 0 end,
          color = function() return C.surfaceContainerHighest end, border_width = 1,
          border_color = function() return t.hovered and stroke(C, "focus") or stroke(C, "idle") end,
          behavior = { height = quick, translate_y = quick } } },
      label = M.menu_label { anchors = { horizontal_center = true }, height = 18,
        y = function() return (H(t) - 3) / 2 - 9 + (t.down and 2 or 0) end, behavior = { y = quick },
        text = tostring(spec.label or spec.text or ""):upper(), font_size = FS,
        color = function() return C.onSurface end },
      badge = feedback(t, spec.id),
    }
  end

  -- -------------------------------------------------- floating actions --

  --- The FAB: a lit square block with its icon and a hatched corner,
  --- pressing in a little.
  function S.fab(t, spec)
    local function ink() return C.onPrimary end
    return full {
      background = ui.Item { anchors = { fill = true }, opacity = dim(t),
        scale = function() return t.down and .94 or 1 end, behavior = { scale = quick },
        ui.Rect { anchors = { fill = true }, translate_x = 3, translate_y = 3,
          color = function() return C.primary:alpha(.3) end },
        ui.Rect { anchors = { fill = true }, color = function() return C.primary end },
        hatch({ anchors = { right = true, top = true }, width = 16, height = 16 }, 16, 16,
          function() return C.onPrimary:alpha(.4) end, 4, 1.5) },
      icon = ui.Item { anchors = { center_in = true }, width = 24, height = 24,
        scale = function() return t.down and .9 or 1 end, behavior = { scale = quick },
        M.icon(spec.icon or "add", 24, ink, { anchors = { center_in = true } }) },
      badge = feedback(t, spec.id),
    }
  end

  --- The extended FAB: a lit block with its icon, caption and a hatched
  --- tail, on its offset block.
  function S.extended_fab(t, spec)
    local w, h = box_of(spec, 160, 56)
    local function ink() return C.onPrimary end
    return framed(t, spec, {
      under = { ui.Rect { anchors = { fill = true }, translate_x = 3, translate_y = 3,
        color = function() return C.primary:alpha(.3) end } },
      fill = function() return t.down and C.primary:mix(C.onPrimary, .15) or C.primary end, sink = 2, ink = ink,
      glyph = 22, gap = 10,
      over = { hatch({ anchors = { right = true, top = true, bottom = true }, width = 16 }, 16, h,
        function() return C.onPrimary:alpha(.35) end, 5, 1.5) } })
  end

  --- A speed dial's action: its caption in a framed tag at the start, a
  --- leader rule, and its icon in a lit square cell at the end.
  function S.speed_dial_item(t, spec)
    local function d() return math.min(H(t), 48) - 4 end
    return full {
      background = ui.Item { anchors = { fill = true }, opacity = dim(t),
        ui.Rect { anchors = { right = true, vertical_center = true }, width = d, height = d,
          color = function() return t.down and C.primary:mix(C.onPrimary, .15) or C.primaryContainer end,
          border_width = 1, border_color = function() return t.hovered and C.primary or stroke(C, "hover") end,
          behavior = { color = quick, border_color = quick } },
        ui.Rect { anchors = { vertical_center = true }, height = 1,
          x = function() return math.max(0, W(t) - d() - 18) end, width = 14,
          color = function() return t.hovered and C.primary or stroke(C, "hover") end } },
      icon = ui.Item { anchors = { right = true, vertical_center = true }, width = d, height = d,
        M.icon(spec.icon or "add", 20, function() return C.onPrimaryContainer end, { anchors = { center_in = true } }) },
      label = spec.label and ui.Rect { x = 0, anchors = { vertical_center = true }, height = 28,
        width = function() return math.max(0, W(t) - d() - 18) end,
        color = function() return C.surfaceContainerHigh end, border_width = 1, border_color = idle,
        ui.Row { anchors = { center_in = true }, caption(t, spec.label, function() return C.onSurface end) } } or none,
      badge = feedback(t, spec.id),
    }
  end

  -- ------------------------------------------------------------ holding --

  --- A hold button (a press that counts only once held for `t.hold` ms):
  --- a square plate in a hairline, its caption in caps, a square register
  --- round the icon that a clock wipe fills -- one distance-field frame cut
  --- by a wedge whose angle runs over the hold -- and a hatched run in the
  --- error tone (`tone = "accent"`: the primary) whose clip runs across
  --- behind a scan line while the stripes stay put. Let go early, both run
  --- back; held to the end, the register fills solid with a tick.
  function S.hold_button(t, spec)
    local bw, bh = box_of(spec, 160, 40)
    local function tone() return spec.tone == "accent" and C.primary or C.error end
    local function on_tone() return spec.tone == "accent" and C.onPrimary or C.onError end
    local done = morf.signal("tsugumori.hold." .. tostring({}), false)
    local stripes_node = stripes.box { width = bw, height = bh, gap = 7, weight = 2,
      color = function() return tone():alpha(.3) end }
    stripes_node.translate_x = bw
    local mover = ui.Item { anchors = { fill = true }, translate_x = -bw,
      ui.Item { anchors = { fill = true }, clip = true, stripes_node },
      ui.Rect { anchors = { right = true, top = true, bottom = true }, width = 2, color = tone } }
    local fill = ui.SdfShape { shape = "pie", anchors = { fill = true, margins = -6 }, operation = "intersect",
      angle = 0, rotation = 0 }
    local D = 24
    local function frame_shapes(extra)
      local list = { ui.SdfShape { shape = "box", anchors = { fill = true }, radius = 0 },
        ui.SdfShape { shape = "box", anchors = { fill = true, margins = 3 }, radius = 0, operation = "subtract" } }
      if extra then list[#list + 1] = extra end
      return list
    end
    local track_props = { anchors = { fill = true }, fill_color = function() return stroke(C, "hover") end }
    for i, shape in ipairs(frame_shapes()) do track_props[i] = shape end
    local fill_props = { anchors = { fill = true }, fill_color = tone }
    for i, shape in ipairs(frame_shapes(fill)) do fill_props[i] = shape end
    local dial = ui.Item { width = D, height = D,
      ui.Sdf(track_props), ui.Sdf(fill_props),
      ui.Rect { anchors = { fill = true }, color = tone, opacity = function() return done:get() and 1 or 0 end,
        behavior = { opacity = quick } },
      M.icon(function() return done:get() and "check" or (spec.icon or "delete") end, 16,
        function() return done:get() and on_tone() or C.onSurface end, { anchors = { center_in = true } }) }
    local running, was, counted, settle_timer = nil, false, false, nil
    local function play(to, duration, easing)
      if running then running:stop() end
      running = morf.animation.play { { parallel = {
        { node = fill, property = "angle", to = 360 * to, duration = duration, easing = easing },
        { node = fill, property = "rotation", to = 180 * to, duration = duration, easing = easing },
        { node = mover, property = "translate_x", to = (to - 1) * bw, duration = duration, easing = easing },
        { node = stripes_node, property = "translate_x", to = (1 - to) * bw, duration = duration, easing = easing } } },
        on_finished = function() running = nil end }
    end
    morf.effect("tsugumori.hold.watch." .. tostring(dial), function()
      local holding, down = t.holding, t.down
      if holding and not was then
        if settle_timer then settle_timer:cancel() settle_timer = nil end
        done:set(false)
        play(1, math.max(1, t.hold or 800), "linear")
      elseif was and not holding then
        if down then counted = true done:set(true) else play(0, 220, "out_expo") end
      elseif counted and not down then
        counted = false
        settle_timer = morf.timer(500, function()
          settle_timer = nil
          done:set(false)
          play(0, 260, "out_expo")
        end, false)
      end
      was = holding
    end, { owner = dial })
    return full {
      background = ui.Item { anchors = { fill = true }, opacity = dim(t),
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainer end },
        ui.Item { anchors = { fill = true }, clip = true, mover },
        ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
          border_color = function() return t.holding and tone() or stroke(C, t.hovered and "hover" or "idle") end,
          behavior = { border_color = quick } } },
      content = ui.Row { anchors = { center_in = true }, gap = 10, align = "center", dial,
        spec.label and M.text { text = tostring(spec.label):upper(), font_size = theme.typography.menu, font_weight = 500,
          color = function() return C.onSurface end } or nil },
      badge = feedback(t, spec.id),
    }
  end
end
