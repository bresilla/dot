-- Material's looks for the Scroll widgets: a pager's dots with a primary
-- pill that springs (and stretches) from page to page, a shelf whose
-- edges fade and whose tonal round arrows squish as they are pressed, a
-- scroll area's sideways bar, and an infinite list's contained loading
-- indicator -- M3 Expressive's morphing shape. The scrolling, snapping and
-- loading are lib.kit.scroll's and the Scroll archetype's.
local ui = require("morf.ui")
local control = require("lib.kit.control")

return function(S, theme, M)
  local function C() return theme.color end
  local small = { duration = theme.duration.small }
  local function bouncy() return M.spring(520, 24) end

  local DOT, PILL, PITCH, DOTS_H, DOTS_GAP = 8, 24, 20, 20, 6
  local MAX_DOTS = 12
  local ARROW, ARROW_GAP = 36, 8
  local FADE = 36
  local LOADING_H, CHIP = 52, 40

  local function room_x(t) return math.max(0, (t.content_width or 0) - (t.viewport_width or 0)) end
  local function pages(t)
    local vw = t.viewport_width or 0
    if vw <= 0 then return 1 end
    return math.max(1, math.min(MAX_DOTS, math.floor((t.content_width or 0) / vw + 0.5)))
  end
  local function page_at(t)
    local vw = t.viewport_width or 0
    if vw <= 0 then return 0 end
    return (t.content_x or 0) / vw
  end
  local function part(widget, props, on_clicked, settings)
    local spec = { widget = widget, on_clicked = on_clicked }
    for k, v in pairs(settings or {}) do spec[k] = v end
    return (control.make("Press", widget, spec, { props = props }))
  end
  local function blank() return ui.Item {} end
  local function ring(t, radius, inset)
    return ui.Rect { anchors = { fill = true, margins = inset or 0 }, z = 50, color = "transparent", radius = radius,
      border_width = 2, border_color = function() return C().secondary end, visible = function() return t.visual_focus end }
  end

  -- ------------------------------------------------------------ pages --

  --- A page dot: the variant tone, a state layer under the pointer.
  function S.page_dot(t)
    return {
      background = ui.Rect { x = (PITCH - DOT) / 2, y = (DOTS_H - DOT) / 2, width = DOT, height = DOT, radius = DOT / 2,
        color = function() return C().onSurfaceVariant:alpha(t.hovered and 0.6 or 0.38) end,
        behavior = { color = small } },
      content = blank(), indicator = ring(t, 6, 0), icon = blank(), label = blank(), badge = blank(),
    }
  end

  local function dots(t, spec)
    local row = ui.Item { width = function() return pages(t) * PITCH end, height = DOTS_H,
      x = function() return math.floor(((t.width or 0) - pages(t) * PITCH) / 2) end,
      y = function() return (t.height or 0) - DOTS_H - DOTS_GAP end,
      visible = function() return pages(t) > 1 end }
    for i = 1, MAX_DOTS do
      ui.reparent(part("page_dot", { x = (i - 1) * PITCH, width = PITCH, height = DOTS_H, cursor = "pointer",
        accessible_name = "Page " .. i, visible = function() return i <= pages(t) end },
        function() if spec.glide then spec.glide((i - 1) * (t.viewport_width or 0), nil) end end), row)
    end
    -- The current page's pill: it springs to the page the view is going
    -- to, stretching along the way.
    ui.reparent(ui.Rect { z = 5, y = (DOTS_H - DOT) / 2, width = PILL, height = DOT, radius = DOT / 2,
      x = function()
        local at = math.max(0, math.min(pages(t) - 1, math.floor(page_at(t) + 0.5)))
        return at * PITCH + (PITCH - PILL) / 2
      end,
      color = function() return C().primary end,
      behavior = { x = bouncy() }, stretch = { stiffness = 300, damping = 14, scale = 0.18 } }, row)
    return row
  end

  function S.pager(t, spec) return { scroll_bar_x = dots(t, spec) } end

  -- ------------------------------------------------------------ shelf --

  --- A shelf's arrow: a tonal round icon button whose corners pull in as
  --- it is pressed.
  function S.shelf_arrow(t, spec)
    return {
      background = ui.Rect { anchors = { fill = true },
        radius = function() return t.down and ARROW * 0.3 or ARROW / 2 end,
        color = function()
          local c, ink = C().secondaryContainer, C().onSecondaryContainer
          if t.down then return c:mix(ink, 0.12) end
          return t.hovered and c:mix(ink, 0.08) or c
        end,
        shadow_color = "#00000040", shadow_blur = 6, shadow_offset_y = 1,
        behavior = { color = small, radius = bouncy() } },
      content = M.icon(spec.icon, 22, function() return C().onSecondaryContainer end, { anchors = { center_in = true } }),
      indicator = ring(t, ARROW / 2, -3), icon = blank(), label = blank(), badge = blank(),
    }
  end

  -- The fades: a mask on the view (only its alpha counts), solid at an
  -- end that is reached, a ramp to nothing where there is more.
  local function edge_mask(shown_before, shown_after)
    local function edge(side, shown)
      return ui.Item { anchors = { top = true, bottom = true, [side] = true }, width = FADE,
        rotation = side == "right" and 180 or 0,
        ui.Rect { anchors = { fill = true }, gradient = { angle = 90, stops = { "#00000000", "#000000" } } },
        ui.Rect { anchors = { fill = true }, color = "#000000",
          opacity = function() return shown() and 0 or 1 end, behavior = { opacity = small } } }
    end
    return ui.Item {
      ui.Rect { anchors = { fill = true, left_margin = FADE, right_margin = FADE }, color = "#000000" },
      edge("left", shown_before), edge("right", shown_after) }
  end

  function S.shelf(t, spec)
    local function more_before() return (t.content_x or 0) > 0.5 end
    local function more_after() return (t.content_x or 0) < room_x(t) - 0.5 end
    local function go(dir)
      local item = (type(spec.item_size) == "number" and spec.item_size > 0) and spec.item_size or 120
      local step = math.max(item, math.floor((t.viewport_width or 0) * 0.8 / item) * item)
      local to = math.floor(((t.content_x or 0) + dir * step) / item + 0.5) * item
      if spec.glide then spec.glide(math.max(0, math.min(room_x(t), to)), nil) end
    end
    local function arrow(side, icon, shown, dir)
      return part("shelf_arrow", { width = ARROW, height = ARROW, cursor = "pointer",
        accessible_name = dir < 0 and "Scroll back" or "Scroll on",
        anchors = { [side] = true, vertical_center = true, left_margin = ARROW_GAP, right_margin = ARROW_GAP },
        opacity = function() return shown() and 1 or 0 end, visible = shown,
        scale = function() return shown() and 1 or 0.4 end,
        behavior = { opacity = small, scale = bouncy() } }, function() go(dir) end, { icon = icon })
    end
    if spec.flick then spec.flick.mask = edge_mask(more_before, more_after) end
    return { overscroll = ui.Item { anchors = { fill = true },
      arrow("left", "chevron_left", more_before, -1), arrow("right", "chevron_right", more_after, 1) } }
  end

  -- ----------------------------------------------------- scroll views --

  --- A scroll area's sideways bar: the vertical one's pill, turned.
  function S.scroll_bar_x(t, spec)
    local function length() return math.max(24, ((type(spec.size) == "function" and spec.size()) or 1) * (t.width or 0)) end
    return {
      track = ui.Item { anchors = { fill = true } },
      handle = ui.Rect { anchors = { bottom = true }, radius = 4,
        height = function() return (t.hovered or t.down) and 8 or 4 end,
        width = length, x = function() return (t.visual_position or 0) * ((t.width or 0) - length()) end,
        color = function() return C().onSurfaceVariant:alpha((t.hovered or t.down) and .6 or .35) end,
        behavior = { height = small } },
      fill = blank(), second_handle = blank(), ticks = blank(), value_label = blank(), increase = blank(),
      decrease = blank(), background = blank(), content = blank(),
    }
  end

  function S.scroll_area(t, spec)
    local flick = spec.flick
    return { scroll_bar_x = control.make("Range", "scroll_bar_x", { widget = "scroll_bar_x", orientation = "horizontal",
      wheel = false, accessible_name = "Scroll position", height = 10,
      anchors = { left = true, right = true, bottom = true, left_margin = 4, right_margin = 14, bottom_margin = 2 },
      visible = function() return t.bar_x end, value = function() return t.position_x end,
      size = function() return t.size_x end,
      on_moved = function(v) if flick then flick.content_x = v * room_x(t) end end }) }
  end

  --- An infinite list: the contained loading indicator -- the morphing
  --- shape on a primary container -- springs up at its foot while more
  --- is fetched.
  function S.infinite_scroll(t)
    return { overscroll = ui.Item { anchors = { left = true, right = true, bottom = true }, height = LOADING_H,
      visible = function() return t.loading end,
      ui.Rect { anchors = { horizontal_center = true }, y = (LOADING_H - CHIP) / 2, width = CHIP, height = CHIP,
        radius = CHIP / 2, color = function() return C().primaryContainer end,
        shadow_color = "#00000040", shadow_blur = 6, shadow_offset_y = 1,
        opacity = function() return t.loading and 1 or 0 end,
        translate_y = function() return t.loading and 0 or LOADING_H / 2 end,
        scale = function() return t.loading and 1 or 0.4 end,
        behavior = { opacity = small, translate_y = bouncy(), scale = bouncy() },
        M.loading(26, function() return C().onPrimaryContainer end,
          { anchors = { center_in = true }, active = function() return t.loading end }) } } }
  end
end
