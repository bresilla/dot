-- Tsugumori's skins for the kit's archetypes (lib.kit.skin): square,
-- framed, mechanical -- hatched runs, block handles, tick rulers, rolling
-- labels -- drawn from a control's live state `t`. The behaviour is the
-- archetype's.
local morf = require("morf")
local ui = require("morf.ui")
local stripes = require("themes.tsugumori.stripes")
local stroke = require("themes.tsugumori.strokes")

return function(theme, M, hud)
  local S = {}
  local C = theme.color
  local function get(v) if type(v) == "function" then return v() end return v end
  local function clamp01(v) return math.max(0, math.min(1, v)) end
  local quick = { duration = 140, easing = "out_cubic" }
  local MARK = "M0 0 H7 V1.5 H1.5 V7 H0 Z"

  -- Decoration made the first time the pointer, a press or the keyboard
  -- reaches the control (lib.kit.skin: a slot given as a function): a shell
  -- holds hundreds of controls, most never touched.
  local function lazy(_, build) return build end

  -- The feedback a press or the pointer gives a target: a faint wash, one
  -- glint that crosses it on entry or press, the two registration marks
  -- on its diagonal parting outward while hovered, and the keyboard's
  -- brackets. Built the first time the control is reached (a lazy slot);
  -- the target's input box never moves. `id` names the pieces
  -- (`<id>-wash`, `<id>-glint`, `<id>-mark-1`).
  local function feedback(t, id)
    return lazy(t, function()
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
    end)
  end

  -- A tick ruler along `len`: a short tick every 8 px, a long one every 5th.
  local function ruler(x, y, len, size, color)
    return ui.Path { x = x, y = y, width = len, height = size, view_box = function() return { 0, 0, get(len), size } end,
      d = function() return morf.geometry.ruler(get(len), size, { pitch = 8, major = 5, min_count = 4 }) end,
      fill_color = "transparent", stroke_color = color, stroke_width = 1 }
  end

  -- ----------------------------------------------------------- presses --

  --- A framed button whose caption rolls up through a strip of marks when
  --- the pointer arrives: `icon`, `label`, `color`/`ink`.
  local function pill(t, spec)
    local ink = spec.ink or function() return C.onPrimaryContainer end
    local fill = spec.color or function() return C.primaryContainer end
    local function caption() return tostring(get(spec.label) or ""):upper() end
    local measure = M.menu_label { text = caption, font_size = theme.typography.menu, height = 18, opacity = 0 }
    local function natural_width()
      return math.max(1, measure.layout_width or utf8.len(caption()) * theme.typography.menu * .62)
    end
    local function width() return get(spec.width) or natural_width()+(spec.icon and 36 or 16) end
    local function available() return math.max(0, width() - (spec.icon and 36 or 16)) end
    local function label_size()
      return math.max(9, math.min(theme.typography.menu, theme.typography.menu * available() / natural_width()))
    end
    local function text_width() return math.min(available(), natural_width() * label_size() / theme.typography.menu + 2) end
    local strip = ui.Column { y = -36, gap = 0,
      M.menu_label { text = "/ / / / / /", height = 18, color = ink },
      M.menu_label { text = "+ | + | + |", height = 18, color = ink },
      M.menu_label { text = caption, font_size = label_size, height = 18, width = text_width, elide = "right", color = ink },
    }
    local content = ui.Row { anchors = { center_in = true }, gap = 6, align = "center",
      spec.icon and M.icon(spec.icon, 17, ink) or nil,
      ui.Item { id = (spec.id or "pill") .. "-label", width = text_width, height = 18, clip = true,
        visible = function() return text_width() > 0 end, strip },
    }
    local was, running = false, nil
    morf.effect("tsugumori.label." .. (spec.id or tostring(strip)), function()
      local now = t.hovered
      if was == now then return end
      was = now
      if running then running:stop() end
      if now then running = morf.animation.play { { node = strip, property = "y", from = 0, to = -36, duration = 340, easing = "out_cubic" } }
      else strip.y = -36 end
    end, { owner = strip })
    return {
      background = ui.Rect { anchors = { fill = true }, radius = 0, border_width = 1,
        color = function() return t.hovered and fill():mix(ink(), 0.12) or fill() end,
        border_color = function() return t.hovered and stroke(C, "focus") or stroke(C, "idle") end,
        behavior = { color = quick, border_color = quick } },
      content = ui.Item { anchors = { center_in = true },width=width,height=spec.height or 32,
        ui.Item {width=1,height=1,clip=true,measure}, content },
      badge = feedback(t, spec.id),
    }
  end

  --- A square rail with a block that slides across and takes the accent.
  local function switch(t, spec)
    return {
      background = ui.Rect { anchors = { fill = true }, radius = 0, border_width = 1,
        color = function() return C.surfaceContainerHighest end,
        border_color = function() return t.checked and stroke(C, "focus") or stroke(C, "idle") end },
      indicator = ui.Rect { y = 5, x = function() return (t.checked ~= (t.mirrored == true)) and 28 or 5 end, width = 19, height = 22,
        color = function() return t.checked and C.primary or C.outline end,
        behavior = { x = { duration = 150, easing = "out_cubic" } } },
      badge = feedback(t, spec.id),
    }
  end

  --- A framed icon toggle in the alert tone while `on`, with a lit tab.
  local function icon(t, spec)
    local w, h = spec.width or 32, spec.height or 32
    local function on() return spec.on and spec.on() == true end
    local alert = M.signal("alert")
    local c = math.max(3, math.floor(math.min(w, h) * .22))
    return {
      background = ui.Path { width = w, height = h, view_box = { 0, 0, w, h }, d = M.frame_path(w, h, c, .5),
        fill_color = function() return on() and alert():alpha(.16) or C.surfaceContainerHigh end,
        stroke_color = function() return on() and alert():alpha(.75) or stroke(C, "idle") end,
        stroke_width = 1, stroke_join = "miter", behavior = { fill_color = quick, stroke_color = quick } },
      icon = M.icon(function() return on() and (spec.icon_on or spec.icon_off) or (spec.icon_off or spec.icon_on) end,
        math.floor(math.min(w, h) * .56), function() return on() and alert() or C.onSurfaceVariant end,
        { anchors = { center_in = true }, fill = on }),
      indicator = ui.Rect { x = w - c - 1, y = 2, width = c - 1, height = 2, color = alert,
        opacity = function() return on() and 1 or 0 end, behavior = { opacity = quick } },
      badge = feedback(t, spec.id),
    }
  end

  --- A square box, hatched when checked, a bar when partial.
  local function checkbox(t)
    return {
      background = ui.Rect { anchors = { fill = true, margins = 3 }, color = "transparent", border_width = 1,
        border_color = function() return (t.checked or t.partial) and C.primary or stroke(C, "idle") end },
      indicator = ui.Item { anchors = { fill = true, margins = 6 }, clip = true,
        visible = function() return t.checked or t.partial end,
        ui.Rect { anchors = { fill = true }, color = function() return C.primary:alpha(t.partial and .5 or 1) end } },
      badge = feedback(t),
    }
  end

  --- A square frame with a block in it when chosen.
  local function radio(t)
    return {
      background = ui.Rect { anchors = { fill = true, margins = 3 }, color = "transparent", border_width = 1,
        border_color = function() return t.checked and C.primary or stroke(C, "idle") end },
      indicator = ui.Rect { anchors = { center_in = true }, color = function() return C.primary end,
        width = function() return t.checked and 8 or 0 end, height = function() return t.checked and 8 or 0 end,
        behavior = { width = quick, height = quick } },
      badge = feedback(t),
    }
  end

  --- A menu row: a mono label, the accent plate under the pointer, a
  --- block when checked.
  local function menu_item(t, spec)
    local left=spec.icon and 34 or 12
    local right=spec.widget=="menu_item" and 12 or 28
    return {
      background = ui.Rect { anchors = { fill = true },
        color = function() return C.primary:alpha(t.down and .2 or (t.hovered or t.visual_focus) and .1 or 0) end,
        behavior = { color = quick } },
      icon = spec.icon and M.icon(spec.icon, 16, function() return C.onSurfaceVariant end,
        { x = 10, anchors = { vertical_center = true } }) or nil,
      label = M.menu_label { x = left, anchors = { vertical_center = true },
        width=function() return math.max(1e-3,t.width-left-right) end,elide="right",
        text = function() return tostring(get(spec.label) or ""):upper() end,color = function() return C.onSurface end },
      indicator = (spec.widget ~= "menu_item") and ui.Rect { anchors = { right = true, right_margin = 12,
        vertical_center = true }, width = 8, height = 8, color = function() return C.primary end,
        visible = function() return t.checked end } or nil,
      badge = feedback(t, spec.id),
    }
  end

  function S.Press(t, spec)
    local widget = spec.widget
    if widget == "menu_item" or widget == "check_menu_item" or widget == "radio_menu_item" then
      return menu_item(t, spec)
    end
    -- A layout's own area draws itself: the wash, the marks and the
    -- keyboard's brackets here.
    if widget == "area" or widget == "segment" then return { badge = feedback(t, spec.id) } end
    if widget == "switch" then return switch(t, spec)
    elseif widget == "icon" then return icon(t, spec)
    elseif widget == "checkbox" or widget == "check_menu_item" then return checkbox(t)
    elseif widget == "radio" or widget == "radio_menu_item" then return radio(t)
    end
    return pill(t, spec)
  end

  --- Disclosures: a layout's own header (`area`) gets the press feedback;
  --- an expander draws a framed header -- the title, a hatched wash while
  --- open, and a square plus whose upright folds flat into a minus.
  function S.Disclosure(t, spec)
    if spec.widget == "area" then return { indicator = feedback(t, spec.id) } end
    local H = spec.header_height or 40
    return {
      background = ui.Item { width = function() return t.width end, height = H,
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainer end,
          border_width = 1, border_color = function() return t.expanded and C.primary or C.outlineVariant end },
        ui.Rect { anchors = { fill = true, margins = 1 }, color = function() return C.primary end,
          opacity = function() return t.down and 0.18 or t.hovered and 0.06 or 0 end,
          behavior = { opacity = quick } } },
      header = M.text { x = 12, y = (H - theme.size.normal * 1.4) / 2, text = spec.title or "",
        font_size = theme.size.normal, color = function() return t.expanded and C.primary or C.onSurface end },
      indicator = ui.Item { x = function() return t.width - 28 end, y = (H - 14) / 2, width = 14, height = 14,
        ui.Rect { x = 0, y = 6, width = 14, height = 2, color = function() return C.primary end },
        ui.Rect { x = 6, width = 2, color = function() return C.primary end,
          y = function() return t.expanded and 6 or 0 end, height = function() return t.expanded and 2 or 14 end,
          behavior = { y = quick, height = quick } } },
    }
  end

  --- Drags: a divider's grip -- three square studs that part along the
  --- axis while hovered and turn primary while held -- with the press
  --- feedback. A swipe is headless: the layout's own node moves.
  function S.Drag(t, spec)
    local across = (spec.axis or "x") == "x"
    local studs = ui.Item { anchors = { fill = true } }
    for i = -1, 1 do
      local function at() return i * ((t.active or t.hovered) and 9 or 6) end
      ui.reparent(ui.Rect { width = 4, height = 4,
        x = function() return (t.width or 0) / 2 - 2 + (across and 0 or at()) end,
        y = function() return (t.height or 0) / 2 - 2 + (across and at() or 0) end,
        color = function() return t.active and C.primary or C.outline end,
        behavior = { x = quick, y = quick } }, studs)
    end
    return { background = feedback(t, spec.id), handle = studs }
  end

  --- Navigations: a hard wipe -- the new page cuts in from its side over a
  --- hatched band while the old one drops away at once.
  function S.Navigation(t, spec)
    -- The page last brought in: a page left behind is hidden only if a
    -- newer change has not brought it back meanwhile.
    local latest
    return {
      transition = function(from, to, direction)
        latest = to
        local width = math.max(1, to.layout_width or t.width or 400)
        to.translate_x = (direction or 1) * width * 0.6
        local steps = { { node = to, property = "translate_x", to = 0, duration = 220, easing = "out_expo" } }
        if from then
          steps[#steps + 1] = { node = from, property = "opacity", to = 0, duration = 80, easing = "linear" }
        end
        morf.animation.play { { parallel = steps }, on_finished = function()
          if from and from ~= latest then from.visible, from.opacity = false, 1 end
        end }
      end,
    }
  end

  --- An application window's ground (the Shell archetype): the surface,
  --- framed in a hairline with the registration marks.
  function S.Shell(t)
    return { background = ui.Item { anchors = { fill = true },
      ui.Rect { anchors = { fill = true }, color = function() return C.surface end, border_width = 1,
        border_color = function() return C.primary:alpha(0.24) end } } }
  end

  -- ------------------------------------------------------------ ranges --

  --- The slider: a faint band, the hatched run up to the value, a tick
  --- ruler under it, a square block handle and the reading at the end.
  local function slider(t, spec)
    local H = spec.bar_height or 44
    local function W() return math.max(1,get(spec.width) or t.width) end
    local compact = H < 36
    local isz = compact and 16 or 20
    local left = spec.icon and (isz + 12) or 3
    local function span() return math.max(1,W()-(spec.label~=false and 50 or 3)-left) end
    local band = compact and math.max(6, math.floor(H * .42)) or math.floor(H * .42)
    local by = compact and 4 + math.floor((H - band) / 2) or 4 + math.floor(H * .18)
    local function value() return clamp01(t.visual_position) end
    local function engaged() return t.hovered or t.down end
    local follow = { duration = 90, easing = "out_cubic" }
    local tick = compact and 4 or 6
    local ty = by + band + 3
    local id = spec.id or "slider"
    local slots={
      track = ui.Rect { id = id .. "-track", x = left, y = by, width = span, height = band,
        color = function() return C.primary:alpha(engaged() and .1 or .06) end,
        border_width = 1, border_color = function() return C.primary:alpha(.18) end, behavior = { color = quick } },
      fill = ui.Item { id = id .. "-level", x = left, y = by, height = band, clip = true,
        width = span()*value(),
        visible = function() return value() > .002 end,
        ui.Rect { width = span, height = band, color = function() return C.primary:alpha(.2) end },
        stripes.box { width = span, height = band, gap = 6, weight = 2, color = function() return C.primary end } },
      ticks = ty + tick <= H + 8 and ruler(left, ty, span, tick, function() return C.primary:alpha(.32) end) or nil,
      handle = ui.Rect { id = id .. "-handle", y = by - 4, width = 6, height = band + 8,
        x = left+span()*value()-3,
        color = function() return C.primary end },
      decrease = spec.icon and M.icon(spec.icon, isz, function() return engaged() and C.primary or C.onSurfaceVariant end,
        { x = 2, y = by + math.floor((band - isz) / 2) }) or nil,
      value_label = spec.label ~= false and M.text { id = id .. "-value", x = function() return W() - 46 end, y = by + math.floor((band - 18) / 2),
        width = 46, height = 18, horizontal_alignment = "right", font_size = 12,
        color = function() return engaged() and C.primary or C.onSurfaceVariant end,
        -- `spec.reading(position)`: what it says instead of its percent.
        text = function()
          if spec.reading then return spec.reading(clamp01(t.position)) end
          return ("%03d"):format(math.floor(clamp01(t.position) * 100 + .5))
        end } or nil,
      second_handle = feedback(t, spec.id),
    }
    require("themes.kit_common").follow_range(t,slots.handle,{
      {node=slots.fill,values={width=function() return span()*value() end}},
      {node=slots.handle,values={x=function() return left+span()*value()-3 end}},
    },follow)
    return slots
  end

  --- The media position: a hatched run with a block head over a faint band
  --- and a tick ruler; it flows between the player's one-second updates.
  local function seek_bar(t, spec)
    local function W() return math.max(1,get(spec.width) or t.width) end
    local previous = clamp01(t.visual_position)
    local function tip(v) return math.max(0, math.min(W() - 4, W() * v - 2)) end
    -- A width of 0 is no width at all -- the clip would take its child's --
    -- so an empty run keeps a sliver.
    local function run(v) return math.max(1e-3, W() * v) end
    local fill = ui.Item { id = "media-progress-fill", y = 11, height = 10, width = run(previous), clip = true,
      ui.Rect { width = W, height = 10, color = function() return C.primary:alpha(.2) end },
      stripes.box { width = W, height = 10, gap = 6, weight = 2, color = function() return C.primary end } }
    local grip = ui.Rect { id = "media-progress-handle", y = 7, width = 4, height = 18,
      x = tip(previous), color = function() return C.primary end }
    local running
    morf.effect("tsugumori.media.progress." .. tostring(fill), function()
      local v = clamp01(t.visual_position)
      local active = get(spec.active) ~= false
      local playing = spec.playing and spec.playing()
      -- Interpolate the player's one-second ticks; a drag and a seek settle
      -- at once.
      local flowing = playing and not t.dragging and v > previous and v - previous < .03
      previous = v
      if running then running:stop() running = nil end
      if not active or t.dragging then fill.width, grip.x = run(v), tip(v) return end
      local duration, easing = flowing and 1000 or 180, flowing and "linear" or "out_cubic"
      running = morf.animation.play { { parallel = {
        { node = fill, property = "width", to = run(v), duration = duration, easing = easing },
        { node = grip, property = "x", to = tip(v), duration = duration, easing = easing },
      } } }
    end, { owner = fill })
    return {
      track = ui.Item { width = W, height = 34 },
      background = ui.Item { width = W, height = 34,
        ui.Rect { y = 11, width = W, height = 10, color = function() return C.primary:alpha(.06) end,
          border_width = 1, border_color = function() return C.primary:alpha(.18) end },
        ruler(0, 24, W, 5, function() return C.primary:alpha(.3) end) },
      fill = fill,
      handle = grip,
    }
  end

  --- A scroll bar: a hairline rail and a square block the length of the
  --- view's share, lit under the pointer.
  local function scroll_bar(t, spec)
    local vertical=spec.orientation=="vertical"
    local function extent() return math.max(0,vertical and t.height or t.width) end
    local function length() return math.min(extent(),math.max(24,clamp01(get(spec.size) or 1)*extent())) end
    local function thickness() return math.min(vertical and t.width or t.height,(t.hovered or t.down) and 6 or 3) end
    local function offset() return t.visual_position*(extent()-length()) end
    return {
      track = ui.Rect { anchors = vertical and {right=true,top=true,bottom=true} or {left=true,right=true,bottom=true},
        width=vertical and 1 or nil,height=not vertical and 1 or nil,
        color = function() return stroke(C, "quiet") end },
      handle = ui.Rect { anchors = vertical and {right=true} or {bottom=true},
        width=vertical and thickness or length,height=vertical and length or thickness,
        x=not vertical and offset or nil,y=vertical and offset or nil,
        color = function() return C.primary:alpha((t.hovered or t.down) and .9 or .5) end,
        behavior = {[vertical and "width" or "height"]=quick} },
    }
  end

  function S.Range(t, spec)
    -- A layout's own instrument (a fader, a knob, a spin drawn by its
    -- maker): only the keyboard's mark here.
    if spec.widget == "area" then return { indicator = feedback(t, spec.id) } end
    if spec.widget == "seek_bar" then return seek_bar(t, spec) end
    if spec.widget == "scroll_bar" then return scroll_bar(t, spec) end
    return slider(t, spec)
  end

  -- ------------------------------------------------------- text fields --

  --- A text field: a hairline well when `well` is asked, a rail along the
  --- foot that lights with focus and turns to alert while what is typed
  --- would not be accepted, a framed clear (or reveal) key, a mono counter.
  function S.TextField(t, spec, _, send)
    local function bad() return not t.acceptable and not t.empty end
    local slots = {
      error = ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 2,
        color = function() return bad() and M.signal("alert")() or C.primary end,
        opacity = function() return (t.focused or bad()) and 1 or 0 end, behavior = { opacity = quick } },
    }
    if spec.well then
      slots.background = ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerHigh end,
        border_width = 1, border_color = function() return t.focused and stroke(C, "focus") or stroke(C, "idle") end }
    end
    if spec.clear or spec.reveal then
      local reveal = spec.reveal and spec.echo == "password"
      slots.trailing = require("lib.kit.widgets").icon { width = 26, height = 26,
        anchors = { right = true, right_margin = 5, vertical_center = true },
        icon_off = reveal and "visibility" or "close", icon_on = "visibility_off",
        on = function() return reveal and t.revealed end,
        visible = function() return reveal or not t.empty end,
        on_clicked = function() send(reveal and "reveal" or "clear") end }
    end
    if spec.max_length then
      slots.counter = M.menu_label { anchors = { right = true, bottom = true, right_margin = 6, bottom_margin = 4 },
        color = function() return bad() and M.signal("alert")() or C.onSurfaceVariant end,
        text = function() return ("%03d/%03d"):format(t.length, spec.max_length) end }
    end
    return slots
  end

  -- ------------------------------------------------------------ scrolls --

  --- A scrolled view: the hairline scroll bar (a kit Range) on its right.
  function S.Scroll(t, spec)
    local flick = spec.flick
    local function room() return math.max(0, t.content_height - t.viewport_height) end
    return {
      scroll_bar_y = require("lib.kit.widgets").scroll_bar { width = 8, orientation = "vertical", inverted = true,
        accessible_name = "Scroll position",
        anchors = { right = true, top = true, bottom = true, right_margin = 1, top_margin = 2, bottom_margin = 2 },
        visible = function() return t.bar_y end,
        value = function() return t.position_y end,
        size = function() return t.size_y end,
        handle_size = function() return math.max(24, t.size_y * t.viewport_height) end,
        on_moved = function(v) if flick then flick.content_y = v * room() end end },
    }
  end

  -- -------------------------------------------------------- selections --

  --- Numbered instrument tabs: each a framed slot whose chosen state fills
  --- with the accent from the left, a rolling caption, registration marks
  --- on the chosen one's diagonal, and a square rail under the row whose
  --- accent segment slides to it. `spec`: `items`, `width`, `height` (64),
  --- `pad` (11), `growing`.
  local function tabs(t, spec)
    -- The row's own name and width: the caller's, not the control's.
    local id, row_width = spec.tab_id or spec.id, spec.width_of or spec.width
    local list = type(spec.items) == "function" and spec.items() or spec.items
    local growing = spec.growing == true
    local pad, height, gap = spec.pad or 11, spec.height or 64, 8
    local MENU = theme.typography.menu
    local grown = growing and morf.signal("caelestia." .. tostring(id) .. ".tabs.span", 0) or nil
    local function span()
      if growing then return grown:get() end
      return math.max(0, (get(row_width) or 0) - 2 * pad)
    end
    local function slot() return math.max(1, (span() - gap * (#list - 1)) / #list) end
    local function left(i) return (i - 1) * (slot() + gap) end
    local rail = ui.Rect { id = id and id .. "-tab-rail", y = height - 7, height = 1,
      color = function() return stroke(C, "quiet") end }
    local indicator = ui.Rect { id = id and id .. "-tab-indicator", y = height - 8, height = 2,
      color = function() return C.primary end, width = slot,
      x = function() return (growing and 0 or pad) + left(math.max(1, t.current)) end,
      behavior = { x = { duration = 260, easing = "out_cubic" } } }
    if growing then rail.anchors = { left = true, right = true } else rail.x, rail.width = pad, span end
    return {
      background = rail,
      indicator = indicator,
      container = function()
        if not growing then return ui.Item { anchors = { fill = true } } end
        local row = ui.Flex { anchors = { left = true, right = true }, y = 8, height = 40, direction = "row",
          gap = gap, padding = 0 }
        -- A growing row reads its own laid-out width as the drawer eases it.
        morf.effect("caelestia." .. tostring(id) .. ".tabs.span", function()
          local w = row.layout_width or 0
          if math.abs(w - grown:get()) > .25 then grown:set(w) end
        end, { owner = row })
        return row
      end,
      place = function(i)
        if growing then return { width = 10, height = 40, layout = { grow = 1 } } end
        return { x = function() return pad + left(i) end, y = 8, width = slot, height = 40 }
      end,
      item = function(i, entry, s)
        local name = spec.item_id and spec.item_id(i, entry) or ("tab-" .. i)
        local selected = s.current
        local function ink() return selected() and C.onPrimary or C.onSurface end
        local caption = entry.name:upper()
        local has_icon = (entry.icon_build or entry.icon) and true or false
        local function width() return slot() end
        local measure = M.menu_label { text = caption, font_size = MENU, height = 18, opacity = 0 }
        local function natural() return math.max(1, measure.layout_width or utf8.len(caption) * MENU * .62) end
        local function room() return math.max(0, width() - (has_icon and 66 or 42)) end
        local function size() return math.max(9, math.min(MENU, math.floor(MENU * (room() - 4) / natural() * 2) / 2)) end
        local function text_w() return math.min(room(), natural() * size() / MENU + 2) end
        local strip = ui.Column { gap = 0, y = -36,
          M.menu_label { text = "/ / / / / /", height = 18, color = ink },
          M.menu_label { text = "+ | + | + |", height = 18, color = ink },
          M.menu_label { text = caption, font_size = size, height = 18, width = text_w, elide = "right",
            vertical_alignment = "center", color = ink },
        }
        local look = ui.Item { anchors = { fill = true },
          measure,
          ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainer end, border_width = 1,
            border_color = function()
              return selected() and stroke(C, "focus") or s.hovered() and stroke(C, "hover") or stroke(C, "quiet")
            end,
            behavior = { border_color = { duration = 180 } } },
          ui.Item { anchors = { fill = true, margins = 1 }, clip = true,
            ui.Rect { x = 0, y = 0, height = 38,
              width = function() return selected() and math.max(0, width() - 2) or 0 end,
              color = function() return C.primary end,
              behavior = { width = { duration = 220, easing = { x1 = 0.76, y1 = 0, x2 = 0.24, y2 = 1 } } } } },
          -- `icons_only` (a phone's row): the icon alone, centred.
          M.section_label { text = ("%02d"):format(i), x = 9, y = 14, color = ink, visible = not spec.icons_only },
          ui.Rect { x = 27, y = 10, width = 1, height = 20, color = function() return ink():alpha(0.35) end,
            visible = not spec.icons_only },
          ui.Item { id = name .. "-label", x = 34, y = 12, height = 18, clip = true,
            width = text_w, visible = function() return not spec.icons_only and text_w() > 0 end, strip },
          hud().corners { length = 6, weight = 2, color = function() return C.primary end,
            visible = function() return t.visual_focus and selected() end },
        }
        -- Registration marks on the chosen tab's diagonal.
        for k, corner in ipairs { { left = true, top = true }, { right = true, bottom = true } } do
          local d = k == 1 and -3 or 3
          ui.reparent(ui.Path { anchors = corner, width = 7, height = 7, z = 2,
            view_box = { 0, 0, 7, 7 }, d = MARK, rotation = k == 1 and 0 or 180,
            fill_color = function() return C.primary end,
            translate_x = function() return selected() and d or 0 end,
            translate_y = function() return selected() and d or 0 end,
            opacity = function() return selected() and 1 or 0 end,
            behavior = { translate_x = { duration = 340, easing = "out_cubic" },
              translate_y = { duration = 340, easing = "out_cubic" }, opacity = { duration = 220 } } }, look)
        end
        if has_icon then
          local icon_id = name .. "-icon"
          local icon = entry.icon_build and entry.icon_build(selected, icon_id, ink)
            or M.icon(entry.icon, 18, ink, { id = icon_id, fill = selected })
          icon.anchors = spec.icons_only and { center_in = true }
            or { right = true, right_margin = 9, vertical_center = true }
          ui.reparent(icon, look)
        end
        local was, running = false, nil
        morf.effect(tostring(id) .. ".tab-roll." .. i, function()
          local now = s.hovered()
          if now == was then return end
          was = now
          if running then running:stop() running = nil end
          if now then
            running = morf.animation.play { { node = strip, property = "y", from = 0, to = -36,
              duration = 300, easing = "out_cubic" } }
          else strip.y = -36 end
        end, { owner = look })
        return look
      end,
    }
  end

  --- Any other selection: a square accent plate that slides to the
  --- current entry, mono labels, brackets on it for the keyboard.
  local function entries(t, spec)
    local slide = { duration = 220, easing = "out_cubic" }
    return {
      indicator = ui.Rect { color = function() return C.primary:alpha(.16) end, border_width = 1,
        border_color = function() return C.primary end,
        x = function() return t.current_x end, y = function() return t.current_y end,
        width = function() return t.current_width end, height = function() return t.current_height end,
        visible = function() return t.current > 0 end,
        behavior = { x = slide, y = slide, width = slide, height = slide } },
      item = function(_, value, s)
        local label = type(value) == "table" and (value.label or value.name) or tostring(value)
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
            border_color = function() return s.hovered() and stroke(C, "hover") or stroke(C, "quiet") end },
          M.menu_label { anchors = { center_in = true }, text = tostring(label):upper(),
            color = function() return s.current() and C.primary or C.onSurface end },
          hud().corners { length = 5, weight = 2, color = function() return C.primary end,
            visible = function() return t.visual_focus and s.current() end } }
      end,
    }
  end

  function S.Selection(t, spec)
    if spec.widget == "tabs" then return tabs(t, spec) end
    return entries(t, spec)
  end

  -- -------------------------------------------------------- collections --

  --- A list, table or tree row: a hairline under it, the accent plate on
  --- the current row with a block at its edge, mono labels indented by
  --- depth, a square marker for a tree node; a table's header in caps.
  S.Collection = {
    row = function(t)
      return function(row, s)
        local function now() return s.row() or row end
        local node = ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true }, color = function()
            return C.primary:alpha(s.current() and .14 or s.hovered() and .06 or 0) end },
          ui.Rect { width = 3, anchors = { top = true, bottom = true }, color = function() return C.primary end,
            visible = function() return s.current() end },
          ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
            color = function() return stroke(C, "quiet") end },
          ui.Rect { width = 7, height = 7, anchors = { vertical_center = true },
            x = function() return 10 + s.depth() * 16 end,
            color = function() return s.expanded() and C.primary or "transparent" end, border_width = 1,
            border_color = function() return C.primary end, visible = function() return s.expandable() end },
          M.menu_label { anchors = { vertical_center = true },
            x = function() return 12 + s.depth() * 16 + (s.expandable() and 14 or 0) end,
            text = function() local r = now() return tostring(r.label or r.name or r.title or r.key or ""):upper() end,
            color = function() return s.current() and C.primary or C.onSurface end },
          hud().corners { length = 5, weight = 2, color = function() return C.primary end,
            visible = function() return t.visual_focus and s.current() end } }
        return node, function() end
      end
    end,
    cell = function()
      return function(row, column, s)
        return M.menu_label { x = 8, anchors = { vertical_center = true },
          text = function() local r = s.row() or row return tostring(r[column.key] or "") end,
          color = function() return s.current() and C.primary or C.onSurface end }, function() end
      end
    end,
    header = function(t)
      return function(column)
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
            color = function() return C.primary:alpha(.5) end },
          M.menu_label { x = 8, anchors = { vertical_center = true },
            text = tostring(column.title or column.key):upper(), color = function() return C.onSurfaceVariant end },
          M.menu_label { anchors = { right = true, right_margin = 6, vertical_center = true },
            text = function() return t.sort_ascending and "▲" or "▼" end, color = function() return C.primary end,
            visible = function() return t.sort_column == column.key end } }
      end
    end,
  }

  -- ------------------------------------------------------------ popups --

  --- A popup's ground: a square framed panel with corner brackets.
  function S.Popup(t, spec)
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerHigh end,
          border_width = 1, border_color = function() return stroke(C, "focus") end },
        hud().corners { length = 8, color = function() return C.primary end } },
    }
  end

  -- ------------------------------------------------------------ planes --

  --- A colour plane: saturation across, value down, of `spec.hue()`,
  --- square, with a crosshair through a square handle. Any other plane: a
  --- hairline grid with the same crosshair.
  function S.Plane(t, spec)
    if spec.widget == "area" then return { indicator = feedback(t, spec.id) } end
    local W, H = spec.width or 160, spec.height or 160
    local field
    if spec.widget == "colour_plane" then
      local function hue() return morf.color(("hsl(%d, 100%%, 50%%)"):format(math.floor(get(spec.hue) or 0))) end
      field = ui.Item { width = W, height = H,
        ui.Rect { anchors = { fill = true }, gradient = function() return { angle = 90, stops = { "#ffffff", hue() } } end },
        ui.Rect { anchors = { fill = true }, gradient = { angle = 180, stops = { "#00000000", "#000000" } } },
        ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
          border_color = function() return C.primary:alpha(.4) end } }
    else
      field = M.decor("grid", { width = W, height = H, columns = 8, rows = 8 })
    end
    local function hx() return t.visual_x * W end
    local function hy() return t.visual_y * H end
    return {
      track = ui.Item { width = W, height = H },
      field = field,
      crosshair = ui.Item { width = W, height = H,
        ui.Rect { width = W, height = 1, y = hy, color = function() return C.primary:alpha(.6) end },
        ui.Rect { width = 1, height = H, x = hx, color = function() return C.primary:alpha(.6) end } },
      handle = ui.Rect { width = 12, height = 12, color = "transparent", border_width = 2,
        border_color = function() return t.visual_focus and C.primary or C.onSurface end,
        x = function() return hx() - 6 end, y = function() return hy() - 6 end },
    }
  end

  -- Each archetype's widgets may have looks of their own, in
  -- widgets/<archetype>.lua: a function of (S, theme, M, hud) that adds
  -- S.<widget>. The kit asks a widget's skin before its archetype's, slot
  -- by slot, so a widget's look fills what it draws and the archetype's
  -- skin the rest.
  for _, name in ipairs { "press", "range", "plane", "selection", "popup", "text_field", "scroll", "collection",
    "disclosure", "drag", "navigation", "shell", "canvas", "dock", "transform", "sheet", "roving", "form",
    "overflow" } do
    local ok, looks = pcall(require, "themes.tsugumori.widgets." .. name)
    if ok then
      if type(looks) == "function" then looks(S, theme, M, hud) end
    -- (Only its own absence is quiet: an error inside it, or in what it
    -- requires, is raised.)
    elseif not tostring(looks):find("`themes.tsugumori.widgets." .. name .. "` is not available", 1, true) then
      error(looks, 0)
    end
  end

  return S
end
