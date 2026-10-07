-- Material's looks for each Roving widget. The layout is the kit's (the
-- glue in lib.kit.roving: members in a row, one Tab stop); Material draws
-- it in its roles: a toolbar as a floating toolbar on surfaceContainer, a
-- menu bar on surfaceContainer with the open menu's title on the
-- secondary container, a bar of icons on a pill. What moves is one field
-- shape -- a secondary-container pill under the current member, or a
-- primary ring over members with grounds of their own -- riding a track
-- whose leading edge leaves first, so it stretches towards the next
-- member, and springs in there.
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local function quick() return { duration = theme.duration.small, easing = theme.ease.standard } end
  local function get(v) if type(v) == "function" then return v() end return v end
  local function glide(t, inset)
    return require("lib.kit.roving").glide(t, { reduced = theme.reduced, stretch = M.STRETCH, duration = 260,
      fit = function(x, y, w, h) return x + inset, y + inset, math.max(0, w - 2 * inset), math.max(0, h - 2 * inset) end })
  end
  local function shown(t) return function() return (t.within or (t.open or 0) > 0) and 1 or 0 end end

  --- The pill under the current member: the secondary container (the
  --- primary's under a keyboard), fully round unless `radius` says.
  local function pill(t, radius)
    local track = glide(t, 2)
    return ui.Item { anchors = { fill = true }, z = -1, track,
      ui.Sdf { anchors = { fill = true },
        ui.SdfShape { shape = "box", track = track, opacity = shown(t), behavior = { opacity = quick() },
          radius = function() return radius and get(radius) or (track.height or 0) / 2 end,
          fill_color = function()
            local c = C()
            if (t.open or 0) > 0 then return c.secondaryContainer end
            return t.keyboard and c.primary:alpha(0.16) or c.onSurface:alpha(0.08)
          end } } }
  end

  --- A ring of the primary over the current member, 3 px out (Material's
  --- focus indicator), the box less the box inside it.
  local function ring(t, radius)
    local track = glide(t, -3)
    local inner = ui.Item { anchors = { fill = true, margins = 2 } }
    ui.reparent(inner, track)
    return ui.Item { anchors = { fill = true }, z = 2, track,
      ui.Sdf { anchors = { fill = true }, opacity = function() return t.keyboard and 1 or 0 end,
        behavior = { opacity = quick() }, fill_color = function() return C().secondary end,
        ui.SdfShape { shape = "box", track = track, radius = function() return get(radius) + 3 end },
        ui.SdfShape { shape = "box", track = inner, radius = function() return get(radius) + 1 end, operation = "subtract" } } }
  end

  local function divider(vertical)
    return ui.Item { width = vertical and 13 or 24, height = vertical and 24 or 13,
      ui.Rect { anchors = { center_in = true }, width = vertical and 1 or 16, height = vertical and 20 or 1,
        color = function() return C().outlineVariant end } }
  end
  local function ground(radius, role)
    return ui.Rect { anchors = { fill = true }, z = -2, radius = radius,
      color = function() return C()[role or "surfaceContainer"] end }
  end

  function S.Roving(t, spec)
    return { background = ground(function() return (t.height or 40) / 2 end), indicator = pill(t), separator = divider }
  end

  --- A floating toolbar: a pill of surfaceContainer, round members.
  function S.toolbar_group(t, spec)
    return { background = ground(function() return (t.height or 40) / 2 end), indicator = pill(t), separator = divider }
  end

  --- A menu bar: surfaceContainer at the small rounding, the open
  --- menu's title on the secondary container.
  function S.menubar(t, spec)
    return { background = ground(8), indicator = pill(t, 6), separator = divider }
  end

  --- A connected button group: the segments draw the row; the focus ring
  --- slides over it.
  function S.button_group(t, spec)
    return { background = ui.Item {}, indicator = ring(t, function() return (t.cur_h or 36) / 2 end),
      separator = function() return ui.Item { width = 2, height = 1 } end }
  end

  --- Filter chips (8 px corners): the ring slides from chip to chip.
  function S.chip_row(t, spec)
    return { background = ui.Item {}, indicator = ring(t, 8), separator = divider }
  end

  --- A bar of icons: a pill of surfaceContainerHigh, the current icon on
  --- a round plate.
  function S.icon_bar(t, spec)
    return { background = ground(function() return (t.height or 48) / 2 end, "surfaceContainerHigh"),
      indicator = pill(t), separator = divider }
  end
end
