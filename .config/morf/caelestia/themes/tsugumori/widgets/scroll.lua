-- Tsugumori's looks for the Scroll widgets: a pager's square ticks on a
-- hairline with a block that slides to the page and brackets round it, a
-- shelf whose edges fade over a hatched band and whose square framed
-- arrows light under the pointer, a scroll area's sideways rail, and an
-- infinite list's bracketed run of pulsing blocks. The scrolling, snapping
-- and loading are lib.kit.scroll's and the Scroll archetype's.
local ui = require("morf.ui")
local control = require("lib.kit.control")
local stripes = require("themes.tsugumori.stripes")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local quick = { duration = 140, easing = "out_cubic" }
  local travel = { duration = 220, easing = "out_expo" }

  local TICK, BLOCK, PITCH, DOTS_H, DOTS_GAP = 7, 9, 18, 20, 6
  local MAX_DOTS = 12
  local ARROW, ARROW_GAP = 30, 8
  local FADE = 36
  local LOADING_H, RUN_W, RUN_H = 48, 64, 22

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

  -- ------------------------------------------------------------ pages --

  --- A page tick: a square outline, lit under the pointer.
  function S.page_dot(t)
    return {
      background = ui.Rect { x = (PITCH - TICK) / 2, y = (DOTS_H - TICK) / 2, width = TICK, height = TICK,
        color = "transparent", border_width = 1,
        border_color = function() return t.hovered and C.primary or C.primary:alpha(.45) end,
        behavior = { border_color = quick } },
      content = blank(),
      indicator = hud().corners { length = 4, weight = 2, color = function() return C.primary end,
        visible = function() return t.visual_focus end },
      icon = blank(), label = blank(), badge = blank(),
    }
  end

  local function dots(t, spec)
    local row = ui.Item { width = function() return pages(t) * PITCH end, height = DOTS_H,
      x = function() return math.floor(((t.width or 0) - pages(t) * PITCH) / 2) end,
      y = function() return (t.height or 0) - DOTS_H - DOTS_GAP end,
      visible = function() return pages(t) > 1 end }
    -- The rail the ticks sit on.
    ui.reparent(ui.Rect { x = 2, y = DOTS_H / 2, height = 1, width = function() return pages(t) * PITCH - 4 end,
      color = function() return stroke(C, "idle") end }, row)
    for i = 1, MAX_DOTS do
      ui.reparent(part("page_dot", { x = (i - 1) * PITCH, width = PITCH, height = DOTS_H, cursor = "pointer",
        accessible_name = "Page " .. i, visible = function() return i <= pages(t) end },
        function() if spec.glide then spec.glide((i - 1) * (t.viewport_width or 0), nil) end end), row)
    end
    -- The current page's block, bracketed, cutting across to the page.
    local function at() return math.max(0, math.min(pages(t) - 1, math.floor(page_at(t) + 0.5))) end
    ui.reparent(ui.Item { z = 5, y = 0, width = PITCH, height = DOTS_H,
      x = function() return at() * PITCH end, behavior = { x = travel },
      ui.Rect { x = (PITCH - BLOCK) / 2, y = (DOTS_H - BLOCK) / 2, width = BLOCK, height = BLOCK,
        color = function() return C.primary end },
      ui.Item { x = 1, y = 3, width = PITCH - 2, height = DOTS_H - 6,
        hud().corners { length = 3, weight = 1, color = function() return C.primary end } } }, row)
    return row
  end

  function S.pager(t, spec) return { scroll_bar_x = dots(t, spec) } end

  -- ------------------------------------------------------------ shelf --

  --- A shelf's arrow: a square frame on the container tone, its edge and
  --- chevron lit under the pointer, brackets while it is held.
  function S.shelf_arrow(t, spec)
    return {
      background = ui.Rect { anchors = { fill = true },
        color = function() return t.down and C.primary:mix(C.surfaceContainer, 0.82) or C.surfaceContainer end,
        border_width = 1,
        border_color = function() return (t.hovered or t.down) and C.primary or C.primary:alpha(.45) end,
        behavior = { color = quick, border_color = quick } },
      content = M.icon(spec.icon, 20, function() return t.hovered and C.primary or C.onSurface end,
        { anchors = { center_in = true } }),
      indicator = ui.Item { anchors = { fill = true, margins = -3 }, z = 50,
        hud().corners { length = 5, weight = 2, color = function() return C.primary end,
          visible = function() return t.visual_focus or t.down end } },
      icon = blank(), label = blank(), badge = blank(),
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
          opacity = function() return shown() and 0 or 1 end, behavior = { opacity = quick } } }
    end
    return ui.Item {
      ui.Rect { anchors = { fill = true, left_margin = FADE, right_margin = FADE }, color = "#000000" },
      edge("left", shown_before), edge("right", shown_after) }
  end

  -- Over each fading edge, a faint hatched band and a hairline: the
  -- instrument's mark that the strip runs on.
  local function band(side, shown)
    return ui.Item { anchors = { top = true, bottom = true, [side] = true }, width = 10, clip = true,
      opacity = function() return shown() and 1 or 0 end, behavior = { opacity = quick },
      stripes.box { y = 0, width = 10, height = 480, gap = 6, weight = 1.5,
        color = function() return C.primary:alpha(.32) end },
      ui.Rect { anchors = { top = true, bottom = true, [side == "left" and "right" or "left"] = true }, width = 1,
        color = function() return C.primary:alpha(.5) end } }
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
        anchors = { [side] = true, vertical_center = true, left_margin = ARROW_GAP + 4, right_margin = ARROW_GAP + 4 },
        opacity = function() return shown() and 1 or 0 end, visible = shown,
        translate_x = function() return shown() and 0 or (dir < 0 and -8 or 8) end,
        behavior = { opacity = quick, translate_x = travel } }, function() go(dir) end, { icon = icon })
    end
    if spec.flick then spec.flick.mask = edge_mask(more_before, more_after) end
    return {
      edge_fade = ui.Item { anchors = { fill = true }, band("left", more_before), band("right", more_after) },
      overscroll = ui.Item { anchors = { fill = true },
        arrow("left", "chevron_left", more_before, -1), arrow("right", "chevron_right", more_after, 1) },
    }
  end

  -- ----------------------------------------------------- scroll views --

  --- A scroll area's sideways bar: a hairline rail and a square block the
  --- length of the view's share, lit under the pointer.
  function S.scroll_bar_x(t, spec)
    local function length() return math.max(24, ((type(spec.size) == "function" and spec.size()) or 1) * (t.width or 0)) end
    return {
      track = ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
        color = function() return stroke(C, "quiet") end },
      handle = ui.Rect { anchors = { bottom = true }, height = function() return (t.hovered or t.down) and 6 or 3 end,
        width = length, x = function() return (t.visual_position or 0) * ((t.width or 0) - length()) end,
        color = function() return C.primary:alpha((t.hovered or t.down) and .9 or .5) end,
        behavior = { height = quick } },
      fill = blank(), second_handle = blank(), ticks = blank(), value_label = blank(), increase = blank(),
      decrease = blank(), background = blank(), content = blank(),
    }
  end

  function S.scroll_area(t, spec)
    local flick = spec.flick
    return { scroll_bar_x = control.make("Range", "scroll_bar_x", { widget = "scroll_bar_x", orientation = "horizontal",
      wheel = false, accessible_name = "Scroll position", height = 8,
      anchors = { left = true, right = true, bottom = true, left_margin = 2, right_margin = 12, bottom_margin = 1 },
      visible = function() return t.bar_x end, value = function() return t.position_x end,
      size = function() return t.size_x end,
      on_moved = function(v) if flick then flick.content_x = v * room_x(t) end end }) }
  end

  --- An infinite list: a bracketed run of blocks pulsing in turn cuts in
  --- at its foot while more is fetched.
  function S.infinite_scroll(t)
    return { overscroll = ui.Item { anchors = { left = true, right = true, bottom = true }, height = LOADING_H,
      visible = function() return t.loading end,
      ui.Rect { anchors = { horizontal_center = true }, y = (LOADING_H - RUN_H) / 2, width = RUN_W, height = RUN_H,
        color = function() return C.surfaceContainer end, border_width = 1,
        border_color = function() return C.primary:alpha(.45) end,
        opacity = function() return t.loading and 1 or 0 end,
        translate_y = function() return t.loading and 0 or 10 end,
        behavior = { opacity = quick, translate_y = travel },
        hud().corners { length = 5, weight = 2, inset = -3, color = function() return C.primary end },
        M.loading(40, function() return C.primary end,
          { x = (RUN_W - 40) / 2, y = (RUN_H - 40) / 2 - 1, active = function() return t.loading end }) } } }
  end
end
