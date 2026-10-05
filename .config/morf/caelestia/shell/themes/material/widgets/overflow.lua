-- Material's looks for each Overflow widget. The layout is the kit's (the
-- glue in lib.kit.overflow: items at running x that spring into place as
-- the line overflows, "more" where the hidden ones went); Material draws
-- the "more" button as a standard icon button with its state layer, a
-- tab strip's chosen tab with the primary indicator (3 px, round on top)
-- that springs and stretches between tabs, a breadcrumb trail's gap as
-- "…", and the rest of a chip row as an outlined "+N" chip.
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local function quick() return { duration = theme.duration.small, easing = theme.ease.standard } end
  local function ink(s) return function() local c = C() return s.open() and c.primary or c.onSurfaceVariant end end

  --- Material's state layer: onSurface at 8 % hovered, 10 % pressed, the
  --- secondary container while its menu is open.
  local function layer(s, radius)
    return ui.Rect { anchors = { fill = true, margins = 2 }, radius = radius,
      color = function()
        local c = C()
        if s.open() then return c.secondaryContainer end
        if s.down() then return c.onSurface:alpha(0.1) end
        return s.hovered() and c.onSurface:alpha(0.08) or c.onSurface:alpha(0)
      end, behavior = { color = quick() } }
  end
  local function icon_button(s, glyph)
    return ui.Item { anchors = { fill = true }, layer(s, (s.height - 4) / 2),
      M.icon(glyph, 24, ink(s), { anchors = { center_in = true } }) }
  end
  local function menu() return { placement = "bottom-end", width = 224, item_height = 44 } end

  function S.Overflow(t, spec)
    return { background = ui.Item {}, more = function(s) return icon_button(s, "more_vert") end, menu = menu }
  end
  function S.overflow_toolbar(t, spec)
    return { background = ui.Item {}, more = function(s) return icon_button(s, "more_vert") end, menu = menu }
  end

  --- Primary tabs: a divider along the foot, the primary indicator under
  --- the chosen tab, a chevron that turns while the menu is open.
  function S.overflow_tabs(t, spec)
    local track = ui.Item { y = function() return (t.height or 40) - 3 end, height = 3,
      x = function() return (t.cur_x or 0) + 6 end, width = function() return math.max(0, (t.cur_w or 0) - 12) end,
      behavior = { x = M.spring(380, 26), width = M.spring(380, 26) }, stretch = M.STRETCH }
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
          color = function() return C().surfaceContainerHighest end },
        track,
        ui.Sdf { anchors = { fill = true }, z = 1, visible = function() return (t.current or 0) > 0 end,
          ui.SdfShape { shape = "box", track = track, radius = 1.5, fill_color = function() return C().primary end } } },
      more = function(s)
        return ui.Item { anchors = { fill = true }, layer(s, (s.height - 4) / 2),
          ui.Item { anchors = { center_in = true }, width = 24, height = 24,
            rotation = function() return s.open() and 180 or 0 end, behavior = { rotation = M.spring(380, 26) },
            M.icon("expand_more", 24, ink(s)) } }
      end,
      menu = menu,
    }
  end

  --- A breadcrumb trail: the chevron into the gap and "…" on a state layer.
  function S.overflow_breadcrumbs(t, spec)
    return {
      background = ui.Item {},
      more = function(s)
        return ui.Row { anchors = { fill = true }, align = "center", gap = 0,
          ui.Item { width = 18, height = 18,
            M.icon("chevron_right", 18, function() return C().onSurfaceVariant end, { anchors = { center_in = true } }) },
          ui.Item { width = s.width - 18, height = s.height, layer(s, 8),
            M.text { anchors = { fill = true }, text = "…", font_size = theme.size.normal, color = ink(s),
              horizontal_alignment = "center", vertical_alignment = "center" } } }
      end,
      menu = function() return { placement = "bottom-start", width = 224, item_height = 44 } end,
    }
  end

  --- The rest of a chip row: an outlined chip (8 px corners) saying "+N",
  --- on the secondary container while its menu is open.
  function S.chip_overflow(t, spec)
    return {
      background = ui.Item {},
      more = function(s)
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true, margins = 1 }, radius = 8,
            color = function()
              local c = C()
              if s.open() then return c.secondaryContainer end
              if s.down() then return c.onSurface:alpha(0.1) end
              return s.hovered() and c.onSurface:alpha(0.08) or c.onSurface:alpha(0)
            end, behavior = { color = quick() },
            border_width = function() return s.open() and 0 or 1 end, border_color = function() return C().outline end },
          M.text { anchors = { fill = true }, text = function() return "+" .. tostring(s.count()) end,
            font_size = theme.size.small, font_weight = 600,
            color = function() local c = C() return s.open() and c.onSecondaryContainer or c.onSurfaceVariant end,
            horizontal_alignment = "center", vertical_alignment = "center" } }
      end,
      menu = function() return { placement = "bottom-start", width = 200, item_height = 44 } end,
    }
  end

  --- A site's navigation: tabs' indicator, the rest behind the dots.
  function S.priority_nav(t, spec)
    local slots = S.overflow_tabs(t, spec)
    slots.more = function(s) return icon_button(s, "more_horiz") end
    return slots
  end
end
