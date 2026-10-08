-- Material's skins for the kit's archetypes (lib.kit.skin): the looks of
-- every press and range, drawn from a control's live state `t` -- the
-- behaviour (pressing, dragging, keys, focus) is the archetype's.
local morf = require("morf")
local ui = require("morf.ui")

return function(theme, M)
  local S = {}
  local function C() return theme.color end
  local function get(v) if type(v) == "function" then return v() end return v end
  local function clamp01(v) return math.max(0, math.min(1, v)) end
  -- The keyboard's ring: a 2 px secondary outline inside the edge, made the
  -- first time the control is reached (lib.kit.skin: a slot given as a
  -- function) -- most never are.
  local function ring(t, radius)
    return function()
      return ui.Rect { anchors = { fill = true, margins = 1 }, z = 50, color = "transparent", radius = radius,
        border_width = 2, border_color = function() return C().secondary end,
        visible = function() return t.visual_focus end }
    end
  end

  -- ----------------------------------------------------------- presses --

  --- A pill-shaped filled button: `icon`, `label`, `color`/`ink`
  --- (primaryContainer and its ink).
  local function pill(t, spec)
    local color = spec.color or function() return C().primaryContainer end
    local ink = spec.ink or function() return C().onPrimaryContainer end
    local h = function() return t.height > 0 and t.height or 32 end
    local measure=M.text {text=spec.label,font_size=theme.size.normal,opacity=0}
    local function width() return get(spec.width) or (measure.layout_width or 0)+24+(spec.icon and 26 or 0) end
    local function label_width()
      local available=math.max(0,width()-24-(spec.icon and 26 or 0))
      return math.min(measure.layout_width or 0,available)
    end
    return {
      background = ui.Rect { anchors = { fill = true },
        radius = function() return t.down and h() * 0.22 or h() / 2 end,
        color = function()
          local c = color()
          if t.down then return c:mix(ink(), 0.12) end
          return t.hovered and c:mix(ink(), 0.08) or c
        end,
        behavior = { color = { duration = theme.duration.small }, radius = ui.spring { stiffness = 520, damping = 22 } } },
      content = ui.Item { anchors = { center_in = true },width=width,height=h,clip = true,
        ui.Item {width=1,height=1,clip=true,measure},
        ui.Row { anchors = { center_in = true }, gap = 8, align = "center",
          spec.icon and M.icon(spec.icon, 18, ink) or nil,
          M.text { id=spec.id and spec.id.."-label",text = spec.label, width=label_width,elide="right",
            font_size = theme.size.normal, color = ink } } },
      indicator = ring(t, function() return h() / 2 end),
    }
  end

  --- The M3 switch: a track that fills when on, and a thumb that springs
  --- across, grows when on and more when pressed, and morphs from a circle
  --- to a scalloped cookie.
  local function switch(t)
    local motion = { duration = theme.duration.small, easing = theme.ease.standard }
    local function thumb() return t.down and 28 or (t.checked and 24 or 16) end
    local jump = M.spring(520, 22)
    return {
      background = ui.Rect { anchors = { fill = true }, radius = 16,
        color = function() return t.checked and C().primary or C().surfaceContainerHighest end,
        border_width = function() return t.checked and 0 or 2 end,
        border_color = function() return C().outline end,
        behavior = { color = motion } },
      indicator = ui.Item {
        x = function() return ((t.checked ~= (t.mirrored == true)) and 36 or 16) - thumb() / 2 end,
        y = function() return 16 - thumb() / 2 end,
        width = thumb, height = thumb,
        behavior = { x = jump, y = jump, width = jump, height = jump },
        stretch = M.STRETCH,
        M.shape { anchors = { fill = true },
          shape = function() return t.checked and "cookie12" or "circle" end,
          color = function() return t.checked and C().onPrimary or C().outline end },
        M.icon(function() return t.checked and "check" or "close" end, 14, function()
          return t.checked and C().primary or C().surfaceContainerHighest
        end, { anchors = { center_in = true }, visible = function() return thumb() >= 20 end }),
      },
      badge = ring(t, 16),
    }
  end

  --- A small icon toggle: `icon_on`, `icon_off`, `on` (fn; the error tone
  --- while on), `size` (20). Round off, a rounded square on, tighter while
  --- pressed, its icon filling in.
  local function icon(t, spec)
    local W, H = spec.width or 36, spec.height or 30
    local h = math.min(W, H)
    local function on() return spec.on and spec.on() == true end
    local function ink() return on() and C().onErrorContainer or C().onSurfaceVariant end
    return {
      background = ui.Rect { width = W, height = H,
        radius = function()
          if t.down then return h * 0.2 end
          return on() and h * 0.3 or h / 2
        end,
        color = function()
          local base = on() and C().errorContainer or C().surfaceContainerHighest
          if t.down then return base:mix(ink(), 0.12) end
          if t.hovered then return base:mix(ink(), 0.08) end
          return base
        end,
        behavior = { radius = ui.spring { stiffness = 480, damping = 18 }, color = { duration = theme.duration.small } } },
      icon = M.icon(function() return on() and spec.icon_on or spec.icon_off end, spec.size or 20, ink,
        { anchors = { center_in = true }, fill = on }),
      indicator = ring(t, h / 2 - 1),
    }
  end

  --- A checkbox: a rounded square, filled and ticked when checked, a dash
  --- when partial.
  local function checkbox(t)
    return {
      background = ui.Rect { anchors = { fill = true, margins = 3 }, radius = 3,
        color = function() return (t.checked or t.partial) and C().primary or "transparent" end,
        border_width = function() return (t.checked or t.partial) and 0 or 2 end,
        border_color = function() return C().onSurfaceVariant end,
        behavior = { color = { duration = theme.duration.small } } },
      indicator = M.icon(function() return t.partial and "remove" or "check" end, 16,
        function() return C().onPrimary end,
        { anchors = { center_in = true }, visible = function() return t.checked or t.partial end }),
      badge = ring(t, 6),
    }
  end

  --- A radio button: a ring with a dot that grows in when checked.
  local function radio(t)
    return {
      background = ui.Rect { anchors = { fill = true, margins = 2 }, radius = 10, color = "transparent",
        border_width = 2, border_color = function() return t.checked and C().primary or C().onSurfaceVariant end },
      indicator = ui.Rect { anchors = { center_in = true }, color = function() return C().primary end,
        width = function() return t.checked and 10 or 0 end, height = function() return t.checked and 10 or 0 end,
        radius = 5, behavior = { width = M.spring(520, 22), height = M.spring(520, 22) } },
      badge = ring(t, 12),
    }
  end

  --- A menu row: its icon and label on a hover wash, a check when checked.
  local function menu_item(t, spec)
    local function ink() return C().onSurface end
    local left=spec.icon and 40 or 14
    local right=spec.widget=="menu_item" and 14 or 38
    return {
      background = ui.Rect { anchors = { fill = true }, radius = 8,
        color = function()
          if t.down then return C().onSurface:alpha(0.12) end
          return (t.hovered or t.visual_focus) and C().onSurface:alpha(0.08) or C().onSurface:alpha(0)
        end, behavior = { color = { duration = theme.duration.small } } },
      icon = spec.icon and M.icon(spec.icon, 18, function() return C().onSurfaceVariant end,
        { x = 12, anchors = { vertical_center = true } }) or nil,
      label = M.text { x = left, anchors = { vertical_center = true }, text = spec.label,
        width=function() return math.max(1e-3,t.width-left-right) end,elide="right",
        font_size = theme.size.normal, color = ink },
      indicator = (spec.widget ~= "menu_item") and M.icon(function()
        if spec.widget == "radio_menu_item" then return t.checked and "radio_button_checked" or "radio_button_unchecked" end
        return "check"
      end, 18, function() return C().primary end, { anchors = { right = true, right_margin = 12, vertical_center = true },
        visible = function() return spec.widget == "radio_menu_item" or t.checked end }) or nil,
    }
  end

  function S.Press(t, spec)
    local widget = spec.widget
    if widget == "menu_item" or widget == "check_menu_item" or widget == "radio_menu_item" then
      return menu_item(t, spec)
    end
    -- A layout's own area draws itself: only the keyboard's ring here.
    if widget == "area" or widget == "segment" then
      return { indicator = ring(t, function() return math.min(16, t.height / 2) end) }
    end
    if widget == "switch" then return switch(t)
    elseif widget == "icon" then return icon(t, spec)
    elseif widget == "checkbox" or widget == "check_menu_item" then return checkbox(t)
    elseif widget == "radio" or widget == "radio_menu_item" then return radio(t)
    end
    return pill(t, spec)
  end

  --- Disclosures: a layout's own header (`area`) gets only the keyboard's
  --- ring; an expander draws its header -- the title, a hover tint and a
  --- chevron that turns over on a spring as it opens.
  function S.Disclosure(t, spec)
    if spec.widget == "area" then
      return { indicator = ring(t, function() return math.min(16, t.height / 2) end) }
    end
    local H = spec.header_height or 40
    return {
      background = ui.Rect { width = function() return t.width end, height = H, radius = 12,
        color = function()
          if t.down then return C().onSurface:alpha(0.1) end
          return t.hovered and C().onSurface:alpha(0.06) or C().onSurface:alpha(0)
        end,
        behavior = { color = { duration = theme.duration.small } } },
      header = M.text { x = 14, y = (H - theme.size.normal * 1.4) / 2, text = spec.title or "",
        font_size = theme.size.normal, color = function() return t.expanded and C().primary or C().onSurface end,
        behavior = { color = { duration = theme.duration.small } } },
      indicator = ui.Item { x = function() return t.width - 34 end, y = (H - 22) / 2, width = 22, height = 22,
        rotation = function() return t.expanded and 180 or 0 end,
        behavior = { rotation = M.spring(420, 24) },
        M.icon("expand_more", 22, function() return C().onSurfaceVariant end) },
    }
  end

  --- Drags: a divider's grip -- a slim pill that swells on a spring while
  --- hovered and fills with the primary while held -- and the keyboard's
  --- ring. A swipe is headless: the layout's own node moves.
  function S.Drag(t, spec)
    local across = (spec.axis or "x") == "x"
    local function long() return t.active and 56 or (t.hovered and 44 or 32) end
    local function thick() return (t.active or t.hovered) and 6 or 4 end
    return {
      background = ring(t, 3),
      handle = ui.Rect {
        x = function() return ((t.width or 0) - (across and thick() or long())) / 2 end,
        y = function() return ((t.height or 0) - (across and long() or thick())) / 2 end,
        width = function() return across and thick() or long() end,
        height = function() return across and long() or thick() end,
        radius = 3,
        color = function() return t.active and C().primary or C().outline end,
        behavior = { width = M.spring(520, 24), height = M.spring(520, 24), x = M.spring(520, 24),
          y = M.spring(520, 24), color = { duration = theme.duration.small } } },
    }
  end

  --- Navigations: M3's shared axis -- the new page drifts in from its side
  --- as it fades up, the old one drifts the other way as it fades out.
  function S.Navigation(t, spec)
    -- The page last brought in: a page left behind is hidden only if a
    -- newer change has not brought it back meanwhile.
    local latest
    return {
      transition = function(from, to, direction)
        latest = to
        local shift = 36 * (direction or 1)
        to.translate_x, to.opacity = shift, 0
        local steps = { { node = to, property = "translate_x", to = 0, duration = 300, easing = "out_cubic" },
          { node = to, property = "opacity", to = 1, duration = 210, easing = "linear" } }
        if from then
          steps[#steps + 1] = { node = from, property = "translate_x", to = -shift, duration = 300, easing = "out_cubic" }
          steps[#steps + 1] = { node = from, property = "opacity", to = 0, duration = 90, easing = "linear" }
        end
        morf.animation.play { { parallel = steps }, on_finished = function()
          if from and from ~= latest then from.visible, from.translate_x, from.opacity = false, 0, 1 end
        end }
      end,
    }
  end

  --- An application window's ground (the Shell archetype): the surface
  --- tone under its regions.
  function S.Shell(t)
    return { background = ui.Rect { anchors = { fill = true }, color = function() return C().surface end } }
  end

  -- ------------------------------------------------------------ ranges --

  --- The M3 expressive slider: the active part, a gap, a slim upright
  --- handle standing past the track, the rest of the track, an icon inside
  --- the active part once it fits and the reading at the end. `spec`:
  --- `width`, `height` (44, the track's), `icon`, `label` (false hides it).
  local function slider(t, spec)
    local H = spec.bar_height or 44
    local function W() return math.max(1,get(spec.width) or t.width) end
    local reading_width=spec.reading and 64 or 40
    local function label_width() return math.min(reading_width,math.max(1,W()-H-28)) end
    -- On a short rail the moving reading and icon would meet halfway.
    -- Reserve a separate readout there; wide sliders keep the embedded one.
    local function separate() return spec.label~=false and W()<2*reading_width+math.floor(H/2)+72 end
    local function rail_width() return separate() and W()-label_width()-12 or W() end
    local GAP = 6
    local function hx() return H / 2 + math.max(0,rail_width() - H) * clamp01(t.visual_position) end
    local function grip() return t.down and 2 or 4 end
    local function rest_x() return hx()+grip()/2+GAP end
    local function rest_width() return math.max(0,rail_width()-rest_x()) end
    local function filled_width() return math.max(0,hx()-grip()/2-GAP) end
    local function handle_x() return hx()-grip()/2 end
    local slots = {
      -- The travel the pointer maps onto: the handle's centre keeps the
      -- track's rounded ends clear.
      track = ui.Item { id=spec.id and spec.id.."-track",x = H / 2, y = 4,
        width = function() return math.max(1,rail_width() - H) end, height = H },
      background = ui.Rect { y = 4, height = H,
        x = rest_x(), width = rest_width(),
        top_left_radius = 6, bottom_left_radius = 6, top_right_radius = H / 2, bottom_right_radius = H / 2,
        color = function() return C().surfaceContainerHighest end },
      fill = ui.Rect { id = spec.id and spec.id .. "-level", x = 0, y = 4, height = H,
        width = filled_width(),
        top_left_radius = H / 2, bottom_left_radius = H / 2, top_right_radius = 6, bottom_right_radius = 6,
        color = function() return C().primary end },
      handle = ui.Rect { id = spec.id and spec.id .. "-handle", y = 0, height = H + 8, radius = 2,
        x = handle_x(), width = grip,
        color = function() return C().primary end,
        behavior = { width = { duration = 150 } } },
      second_handle = ring(t, H / 2),
    }
    local targets={
      {node=slots.background,values={x=rest_x,width=rest_width}},
      {node=slots.fill,values={width=filled_width}},
      {node=slots.handle,values={x=handle_x}},
    }
    local size = math.floor(H / 2)
    if spec.icon then
      local function inside() return filled_width()>=size+18 end
      local function icon_x()
        if inside() then return math.floor(H/2-size/2) end
        return math.floor(hx()+grip()/2+GAP+6)
      end
      slots.ticks = M.icon(spec.icon, size, function()
        return inside() and C().onPrimary or C().onSurfaceVariant
      end, { id=spec.id and spec.id.."-icon",y = 4 + (H - size) / 2,width=size,height=size,
        visible=function() return inside() or icon_x()+size<=rail_width()-8 end,
        x = icon_x() })
      targets[#targets+1]={node=slots.ticks,values={x=icon_x}}
    end
    if spec.label ~= false then
      local function in_fill() return not separate() and hx()>W()-label_width()-24 end
      local function label_x()
        if separate() then return W()-label_width() end
        if in_fill() then return hx()-GAP-10-label_width() end
        return W()-14-label_width()
      end
      slots.value_label = M.text { id = spec.id and spec.id .. "-value", width = label_width, horizontal_alignment = "right",
        y = 4 + (H - 20) / 2, height = 20,
        x = label_x(),
        -- `reading(position)`: what it says instead of its percent.
        text = function()
          if spec.reading then return spec.reading(clamp01(t.position)) end
          return ("%d"):format(math.floor(clamp01(t.position) * 100 + 0.5))
        end,
        font_size = H >= 40 and theme.size.normal or theme.size.small,
        color = function() return in_fill() and C().onPrimary or C().onSurfaceVariant end }
      targets[#targets+1]={node=slots.value_label,values={x=label_x}}
    end
    require("themes.kit_common").follow_range(t,slots.handle,targets,
      {duration=160,easing=theme.ease.standard_decel})
    return slots
  end

  --- The media rail: a wave that runs while playing, up to an upright
  --- thumb, then the rest of the track and a stop dot. `spec`: `width`,
  --- `active` and `playing` (fns).
  local function seek_bar(t, spec)
    local WAVE = 38
    local function W() return math.max(1,get(spec.width) or t.width) end
    local function wave_path(width)
      local d = { "M0 6" }
      for k = 1, math.ceil(width / 2) do
        local x = k * 2
        d[#d + 1] = ("L%d %.2f"):format(x, 6 - 4 * math.sin(x / WAVE * 2 * math.pi))
      end
      return table.concat(d, " ")
    end
    local function at() return clamp01(t.visual_position) end
    local function playing() return get(spec.active) ~= false and spec.playing and spec.playing() end
    local function fill_width() return math.max(1e-3,at()*W()-6) end
    local function rest_x() return math.min(W(),at()*W()+6) end
    local function rest_width() return math.max(0,W()-rest_x()) end
    local function handle_x()
      local width=t.down and 6 or 4
      return math.max(0,math.min(W()-width,at()*W()-width/2))
    end
    local fill=ui.Item { id = "media-progress-wave", x = 0, y = 0, height = 12, clip = true,
      width=fill_width(),visible=function() return at()*W()>6 end,
      ui.Path { width = function() return W()+WAVE end, height = 12,
        view_box = function() return {0,0,W()+WAVE,12} end,d=function() return wave_path(W()+WAVE) end,
        fill_color = "transparent", stroke_width = 5, stroke_cap = "round",
        stroke_color = function() return C().primary end,
        loop = function()
          if not playing() then return nil end
          return { translate_x = { from = 0, to = -WAVE, duration = 1300, easing = "linear" } }
        end } }
    local rest=M.surface {y=13,height=8,radius=4,x=rest_x(),width=rest_width(),
      color=function() return C().surfaceVariant end}
    local handle=M.surface { id = "media-progress-handle", y = 0, height = 34, radius = 2,
        width = function() return t.down and 6 or 4 end,
        x=handle_x(),color = function() return C().primary end }
    local previous=at()
    require("themes.kit_common").follow_range(t,handle,{
      {node=fill,values={width=fill_width}},
      {node=rest,values={x=rest_x,width=rest_width}},
      {node=handle,values={x=handle_x}},
    },function()
      local value=at()
      local flowing=playing() and not t.dragging and value>previous and value-previous<.03
      previous=value
      return {duration=flowing and 1000 or 180,easing=flowing and "linear" or "out_cubic"}
    end)
    return {
      track=ui.Item {width=W,height=34},
      fill=ui.Item {y=11,width=W,height=12,fill},
      background=ui.Item {width=W,height=34,rest,
        M.surface {x=function() return math.max(0,W()-6) end,y=15,width=4,height=4,radius=2,color=function() return C().primary end}},
      handle=handle,
    }
  end

  --- A scroll bar: a slim rounded handle the length of the view's share,
  --- wider under the pointer.
  local function scroll_bar(t, spec)
    local vertical=spec.orientation=="vertical"
    local function extent() return math.max(0,vertical and t.height or t.width) end
    local function length() return math.min(extent(),math.max(24,clamp01(get(spec.size) or 1)*extent())) end
    local function thickness() return math.min(vertical and t.width or t.height,(t.hovered or t.down) and 8 or 4) end
    local function offset() return t.visual_position*(extent()-length()) end
    return {
      track = ui.Item { anchors = { fill = true } },
      handle = ui.Rect { anchors = vertical and {right=true} or {bottom=true}, radius = 4,
        width = vertical and thickness or length,height = vertical and length or thickness,
        x = not vertical and offset or nil,y = vertical and offset or nil,
        color = function() return C().onSurfaceVariant:alpha((t.hovered or t.down) and .6 or .35) end,
        behavior = {[vertical and "width" or "height"]={duration=theme.duration.small}} },
    }
  end

  function S.Range(t, spec)
    -- A layout's own instrument (a fader, a knob, a spin drawn by its
    -- maker): only the keyboard's mark here.
    if spec.widget == "area" then return { indicator = ring(t, function() return math.min(12, t.height / 2) end) } end
    if spec.widget == "seek_bar" then return seek_bar(t, spec) end
    if spec.widget == "scroll_bar" then return scroll_bar(t, spec) end
    return slider(t, spec)
  end

  -- ------------------------------------------------------- text fields --

  --- A text field: Material's filled well when `well` is asked (an input
  --- set in a layout's own well needs none), an underline that grows from
  --- the middle with focus and turns to error while what is typed would
  --- not be accepted, a clear button when `clear`, a reveal for a password,
  --- and a counter against `max_length`.
  function S.TextField(t, spec, _, send)
    local grow = M.spring(460, 30)
    local function bad() return not t.acceptable and not t.empty end
    local slots = {
      error = ui.Rect { anchors = { bottom = true }, height = 2,
        x = function() return t.focused and 0 or t.width / 2 end,
        width = function() return t.focused and t.width or 0 end,
        color = function() return bad() and C().error or C().primary end,
        behavior = { x = grow, width = grow, color = { duration = theme.duration.small } } },
    }
    if spec.well then
      local r = math.min(12, math.floor((get(spec.height) or 48) / 4))
      slots.background = ui.Rect { anchors = { fill = true }, top_left_radius = r, top_right_radius = r,
        color = function()
          local c = C().surfaceContainerHighest
          return bad() and c:mix(C().error, 0.06) or c
        end }
    end
    if spec.clear or spec.reveal then
      local reveal = spec.reveal and spec.echo == "password"
      slots.trailing = require("lib.kit.widgets").icon { width = 28, height = 28, size = 18,
        anchors = { right = true, right_margin = 6, vertical_center = true },
        icon_off = reveal and "visibility" or "close", icon_on = "visibility_off",
        on = function() return reveal and t.revealed end,
        visible = function() return reveal or not t.empty end,
        on_clicked = function() send(reveal and "reveal" or "clear") end }
    end
    if spec.max_length then
      slots.counter = M.text { anchors = { right = true, bottom = true, right_margin = 6, bottom_margin = 4 },
        font_size = theme.size.smaller, color = function() return bad() and C().error or C().onSurfaceVariant end,
        text = function() return ("%d/%d"):format(t.length, spec.max_length) end }
    end
    return slots
  end

  -- ------------------------------------------------------------ scrolls --

  --- A scrolled view: a scroll bar (a kit Range) along its right edge
  --- while there is somewhere to scroll.
  function S.Scroll(t, spec)
    local flick = spec.flick
    local function room() return math.max(0, t.content_height - t.viewport_height) end
    return {
      scroll_bar_y = require("lib.kit.widgets").scroll_bar { width = 10, orientation = "vertical", inverted = true,
        accessible_name = "Scroll position",
        anchors = { right = true, top = true, bottom = true, right_margin = 2, top_margin = 4, bottom_margin = 4 },
        visible = function() return t.bar_y end,
        value = function() return t.position_y end,
        size = function() return t.size_y end,
        handle_size = function() return math.max(24, t.size_y * t.viewport_height) end,
        on_moved = function(v) if flick then flick.content_y = v * room() end end },
    }
  end

  -- -------------------------------------------------------- selections --

  --- Material tabs: icon over label in each slot, a hover wash, and the
  --- primary indicator riding an SDF hairline under the row, springing
  --- from tab to tab. `spec`: `items` (`{ name, icon | icon_build }`),
  --- `width`, `height` (64), `pad` (11), `growing` (the row follows an
  --- easing drawer and its tabs share it).
  local function tabs(t, spec)
    -- The row's own name and width: the caller's, not the control's.
    local id, row_width = spec.tab_id or spec.id, spec.width_of or spec.width
    local list = type(spec.items) == "function" and spec.items() or spec.items
    local PAD, H = spec.pad or 11, spec.height or 64
    local growing = spec.growing == true
    local function width() return get(row_width) or 0 end
    local function slot() return (width() - 2 * PAD) / math.max(1, #list) end
    local labels = {}
    local function span(i)
      local l = labels[i]
      local w = (l and l.layout_width or (growing and 80 or 60)) + 4
      local x = (i - 1) * slot() + (slot() - w) / 2
      if not growing then x = x + PAD end
      return x, x + w
    end
    local indicator = ui.Item { id = id and id .. "-tab-indicator", y = H - 4, height = 3, x = 0, width = 0 }
    local moving = morf.signal("caelestia." .. tostring(id) .. ".indicator.moving", false)
    -- Set going once every label is there to be measured.
    local function follow()
      local still
      local shown, moved = t.current, false
      morf.effect("caelestia." .. tostring(id) .. ".indicator", function()
        local now = t.current
        if now < 1 then return end
        local l1, r1 = span(now)
        if now == shown then
          if not moved then indicator.x, indicator.width = l1, r1 - l1 end
          return
        end
        local l0, r0 = span(shown)
        shown, moved = now, true
        M.elastic(indicator, "x", l0, r0, l1, r1, { duration = 520 })
        moving:set(true)
        if still then still:cancel() end
        still = morf.timer(560, function() still = nil moving:set(false) end, false)
      end, { owner = indicator })
    end
    local line = { shape = "box", operation = "union", y = 7, height = 1,
      fill_color = function() return C().outlineVariant end }
    local field = { id = id and id .. "-tab-field", y = H - 8, height = 8,
      blend = function() return theme.motion.liquid_cards ~= false and moving:get() and 4 or 0 end,
      behavior = { blend = { duration = 200 } } }
    if growing then
      field.anchors = { left = true, right = true }
      line.anchors = { left = true, right = true }
    else
      field.x, field.width = 0, width
      line.x, line.width = PAD, function() return width() - 2 * PAD end
    end
    field[1] = ui.SdfShape(line)
    field[2] = ui.SdfShape { id = id and id .. "-tab-indicator-shape", shape = "box",
      operation = "smooth_union", top_left_radius = 1.5, top_right_radius = 1.5, track = indicator,
      fill_color = function() return C().primary end }
    return {
      indicator = indicator,
      background = ui.Sdf(field),
      container = function()
        if growing then
          return ui.Flex { anchors = { fill = true, bottom_margin = 4 }, direction = "row", padding = 0 }
        end
        return ui.Item { anchors = { fill = true } }
      end,
      place = function(i)
        if growing then return { width = 10, height = H - 4, layout = { grow = 1 } } end
        return { y = 4, height = H - 8, width = slot, x = function() return PAD + (i - 1) * slot() end }
      end,
      item = function(i, entry, s)
        local name = spec.item_id and spec.item_id(i, entry) or ("tab-" .. i)
        -- `icons_only` (a phone's row): no label, the icon centred.
        labels[i] = M.text { text = spec.icons_only and "" or entry.name,
          font_size = growing and theme.size.normal + 1 or theme.size.small,
          color = function() return s.current() and C().primary or C().onSurface end,
          behavior = { color = { duration = theme.duration.small } } }
        if i == #list then follow() end
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true, top_margin = growing and 6 or 2, bottom_margin = growing and 1 or 2 },
            radius = 10,
            color = function() return s.hovered() and C().onSurface:alpha(0.06) or C().onSurface:alpha(0) end,
            border_width = function() return t.visual_focus and s.current() and 2 or 0 end,
            border_color = function() return C().secondary end,
            behavior = { color = { duration = theme.duration.small } } },
          ui.Column { anchors = { horizontal_center = true },
            y = spec.icons_only and math.floor((H - 8 - 28) / 2) or growing and 8 or 6, gap = growing and 4 or 3,
            align = "center",
            -- Every icon in the same box, so the labels share one baseline
            -- whatever an icon_build draws.
            M.centred(26, 28, entry.icon_build and entry.icon_build(s.current, name .. "-icon")
              or M.icon(entry.icon, 22, function() return s.current() and C().primary or C().onSurface end,
                { id = name .. "-icon", fill = s.current })),
            labels[i] },
        }
      end,
    }
  end

  --- Any other selection: a rounded secondary-container plate that
  --- springs to the current entry, each entry its label, and the ring on
  --- the current one for the keyboard.
  local function entries(t, spec)
    local spring = M.spring(380, 26)
    return {
      indicator = ui.Rect { radius = 12, color = function() return C().secondaryContainer end,
        x = function() return t.current_x end, y = function() return t.current_y end,
        width = function() return t.current_width end, height = function() return t.current_height end,
        visible = function() return t.current > 0 end,
        behavior = { x = spring, y = spring, width = spring, height = spring } },
      item = function(_, value, s)
        local label = type(value) == "table" and (value.label or value.name) or tostring(value)
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true }, radius = 12,
            color = function() return s.hovered() and C().onSurface:alpha(0.06) or C().onSurface:alpha(0) end,
            border_width = function() return t.visual_focus and s.current() and 2 or 0 end,
            border_color = function() return C().secondary end },
          M.text { anchors = { center_in = true }, text = label, font_size = theme.size.small,
            color = function() return s.current() and C().onSecondaryContainer or C().onSurface end } }
      end,
    }
  end

  function S.Selection(t, spec)
    if spec.widget == "tabs" then return tabs(t, spec) end
    return entries(t, spec)
  end

  -- -------------------------------------------------------- collections --

  --- A list, table or tree row: a hover wash, the secondary container on
  --- the current row, the label indented by depth with a chevron for a
  --- tree node; a table's cells in its type, its header in the label tone.
  S.Collection = {
    row = function(t)
      return function(row, s)
        local function now() return s.row() or row end
        local label = M.text { anchors = { vertical_center = true },
          x = function() return 14 + s.depth() * 18 + (s.expandable() and 20 or 0) end,
          text = function() local r = now() return tostring(r.label or r.name or r.title or r.key or "") end,
          font_size = theme.size.normal, color = function() return s.current() and C().onSecondaryContainer or C().onSurface end }
        local node = ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true, margins = 2 }, radius = 10,
            color = function()
              if s.current() then return C().secondaryContainer end
              return s.hovered() and C().onSurface:alpha(0.06) or C().onSurface:alpha(0)
            end,
            border_width = function() return t.visual_focus and s.current() and 2 or 0 end,
            border_color = function() return C().secondary end },
          M.icon(function() return s.expanded() and "expand_more" or "chevron_right" end, 18,
            function() return C().onSurfaceVariant end,
            { anchors = { vertical_center = true }, x = function() return 10 + s.depth() * 18 end,
              visible = function() return s.expandable() end }),
          label }
        return node, function() end
      end
    end,
    cell = function()
      return function(row, column, s)
        local text = M.text { x = 10, anchors = { vertical_center = true }, font_size = theme.size.small,
          text = function() local r = s.row() or row return tostring(r[column.key] or "") end,
          color = function() return s.current() and C().onSecondaryContainer or C().onSurface end }
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true }, color = function() return s.current() and C().secondaryContainer or "transparent" end },
          text }, function() end
      end
    end,
    header = function(t)
      return function(column)
        return ui.Item { anchors = { fill = true },
          M.text { x = 10, anchors = { vertical_center = true }, text = column.title or column.key,
            font_size = theme.size.small, font_weight = 600, color = function() return C().onSurfaceVariant end },
          M.icon(function() return t.sort_ascending and "arrow_upward" or "arrow_downward" end, 14,
            function() return C().primary end,
            { anchors = { right = true, right_margin = 8, vertical_center = true },
              visible = function() return t.sort_column == column.key end }) }
      end
    end,
  }

  -- ------------------------------------------------------------ popups --

  --- A popup's ground: the highest tonal surface, rounded, with a hairline.
  function S.Popup(t, spec)
    return {
      background = ui.Rect { anchors = { fill = true }, radius = spec.widget == "tooltip" and 8 or 16,
        color = function() return spec.widget == "tooltip" and C().inverseSurface or C().surfaceContainerHigh end,
        border_width = 1, border_color = function() return C().outlineVariant end },
    }
  end

  -- ------------------------------------------------------------ planes --

  --- A colour plane: saturation across, value down, of `spec.hue()`
  --- (degrees), rounded, with a white ring for the handle. Any other plane:
  --- a tonal field with the ring.
  function S.Plane(t, spec)
    if spec.widget == "area" then return { indicator = ring(t, function() return math.min(12, t.height / 2) end) } end
    local W, H = spec.width or 160, spec.height or 160
    local field
    if spec.widget == "colour_plane" then
      local function hue() return morf.color(("hsl(%d, 100%%, 50%%)"):format(math.floor(get(spec.hue) or 0))) end
      field = ui.Item { width = W, height = H, clip = true,
        ui.Rect { anchors = { fill = true }, radius = 12,
          gradient = function() return { angle = 90, stops = { "#ffffff", hue() } } end },
        ui.Rect { anchors = { fill = true }, radius = 12,
          gradient = { angle = 180, stops = { "#00000000", "#000000" } } } }
    else
      field = ui.Rect { width = W, height = H, radius = 12, color = function() return C().surfaceContainerHighest end }
    end
    return {
      track = ui.Item { width = W, height = H },
      field = field,
      handle = ui.Rect { width = 18, height = 18, radius = 9, color = "transparent", border_width = 3,
        border_color = "#ffffff",
        x = function() return t.visual_x * W - 9 end, y = function() return t.visual_y * H - 9 end },
      crosshair = ring(t, 12),
    }
  end

  -- Each archetype's widgets may have looks of their own, in
  -- widgets/<archetype>.lua: a function of (S, theme, M) that adds
  -- S.<widget>. The kit asks a widget's skin before its archetype's, slot
  -- by slot, so a widget's look fills what it draws and the archetype's
  -- skin the rest.
  for _, name in ipairs { "press", "range", "plane", "selection", "popup", "text_field", "scroll", "collection",
    "disclosure", "drag", "navigation", "shell", "canvas", "dock", "transform", "sheet", "roving", "form",
    "overflow" } do
    local ok, looks = pcall(require, "themes.material.widgets." .. name)
    if ok then
      if type(looks) == "function" then looks(S, theme, M) end
    -- (Only its own absence is quiet: an error inside it, or in what it
    -- requires, is raised.)
    elseif not tostring(looks):find("`themes.material.widgets." .. name .. "` is not available", 1, true) then
      error(looks, 0)
    end
  end

  return S
end
