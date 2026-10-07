-- Material's looks for the Drag archetype's widgets: M3's drag handles
-- (slim outline pills that swell on a spring as they are held), list items
-- and tiles that rise to a higher tone on an elevation shadow while their
-- corners round further, cards that tip as they are swiped, a row's
-- actions as rounded tertiary and error containers that grow in as they
-- are uncovered, the circular refresh indicator on its disc, the sheet's
-- handle, and a drop target whose icon disc swells and squares off while
-- it would take what is over it. Behaviour is lib.kit.drag's and the
-- archetype's.
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local function quick() return { duration = theme.duration.small } end
  local function bouncy() return M.spring(520, 24) end
  local function W(t) return (t.width and t.width > 0) and t.width or 0 end
  local function H(t) return (t.height and t.height > 0) and t.height or 0 end
  local function clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end
  local SHADOW = "#00000066"

  local function ring(t, radius)
    return function()
      return ui.Rect { anchors = { fill = true, margins = 1 }, z = 50, color = "transparent", radius = radius,
        border_width = 2, border_color = function() return C().secondary end,
        visible = function() return t.visual_focus end }
    end
  end

  -- A slot's node, lifted while the control is carried.
  local function lift(t, scale, props)
    props.scale = function() return t.active and (scale or 1.03) or 1 end
    props.behavior = { scale = bouncy() }
    if props.anchors == nil then props.anchors = { fill = true } end
    return ui.Item(props)
  end

  -- A container that rises while it is carried: to the highest tone, on an
  -- elevation shadow, its corners rounding from `r0` to `r1`.
  local function container(t, r0, r1, scale, rest)
    local function radius() return t.active and r1 or r0 end
    return lift(t, scale, {
      ui.Rect { anchors = { fill = true, margins = 3 }, radius = radius, color = function() return C().surfaceContainerHighest end,
        shadow_color = SHADOW, shadow_blur = 20, shadow_offset_y = 8,
        opacity = function() return t.active and 1 or 0 end,
        behavior = { opacity = quick(), radius = bouncy() } },
      ui.Rect { anchors = { fill = true }, radius = radius,
        color = function()
          local c = C()
          if t.active then return c.surfaceContainerHighest end
          local base = rest and rest() or c.surfaceContainer
          if t.down then return base:mix(c.onSurface, 0.1) end
          return t.hovered and base:mix(c.onSurface, 0.08) or base
        end,
        behavior = { color = quick(), radius = bouncy() } } })
  end

  -- The M3 pane drag handle: a 4 px outline pill, 12 px and longer in the
  -- surface's ink while it is held.
  local function divider(t, spec, extra)
    local across = (spec.axis or "x") == "x"
    local function long() return t.active and 52 or (t.hovered and 48 or 40) end
    local function thick() return t.active and 12 or (t.hovered and 6 or 4) end
    local slots = {
      background = ring(t, 6),
      handle = ui.Rect {
        x = function() return (W(t) - (across and thick() or long())) / 2 end,
        y = function() return (H(t) - (across and long() or thick())) / 2 end,
        width = function() return across and thick() or long() end,
        height = function() return across and long() or thick() end,
        radius = function() return thick() / 2 end,
        color = function() local c = C() return t.active and c.onSurface or c.outline end,
        behavior = { width = bouncy(), height = bouncy(), x = bouncy(), y = bouncy(), radius = bouncy(),
          color = quick() } },
    }
    for k, v in pairs(extra or {}) do slots[k] = v end
    return slots
  end

  S.split_pane = function(t, spec) return divider(t, spec) end

  --- A panel's edge: the handle, and while it is dragged the width in an
  --- inverse-surface tooltip beside it.
  S.resizable_panel = function(t, spec)
    return divider(t, spec, {
      ghost = ui.Rect { x = -72, y = function() return H(t) / 2 - 16 end, width = 64, height = 32, radius = 8,
        color = function() return C().inverseSurface end,
        opacity = function() return t.active and 1 or 0 end, scale = function() return t.active and 1 or 0.8 end,
        behavior = { opacity = quick(), scale = bouncy() },
        M.text { anchors = { fill = true }, horizontal_alignment = "center", vertical_alignment = "center",
          font_size = theme.size.small, color = function() return C().inverseOnSurface or C().surface end,
          text = function() return ("%d px"):format(math.floor((t.value or 0) + 0.5)) end } },
    })
  end

  --- A corner grip: a quarter-round of three arcs in the outline tone on a
  --- state layer.
  S.resize_grip = function(t)
    return {
      background = ui.Rect { anchors = { fill = true }, radius = 12,
        color = function() local c = C() return c.onSurface:alpha(t.active and 0.12 or (t.hovered and 0.08 or 0)) end,
        behavior = { color = quick() } },
      handle = ui.Path { anchors = { fill = true, margins = 4 }, view_box = { 0, 0, 16, 16 },
        d = "M15 4 A11 11 0 0 1 4 15 M15 9 A6 6 0 0 1 9 15 M15 13.5 A1.5 1.5 0 0 1 13.5 15",
        fill_color = "transparent", stroke_width = 2, stroke_cap = "round",
        stroke_color = function() local c = C() return t.active and c.primary or c.outline end },
      content = ring(t, 12),
    }
  end

  local function grip_icon(t, props)
    return M.icon("drag_indicator", 22, function()
      local c = C()
      return t.active and c.primary or c.onSurfaceVariant
    end, props)
  end

  --- A list item that is carried: a tonal container whose corners round
  --- from 12 to 20 as it rises.
  S.reorderable_rows = function(t, spec)
    return {
      background = container(t, 12, 20, 1.03),
      handle = lift(t, 1.03, { grip_icon(t, { x = 12, anchors = { vertical_center = true } }) }),
      content = lift(t, 1.03, {
        spec.icon and M.icon(spec.icon, 22, function() return C().onSurfaceVariant end,
          { x = 44, anchors = { vertical_center = true } }) or nil,
        M.text { x = spec.icon and 78 or 44, anchors = { vertical_center = true }, text = spec.label or "",
          color = function() return C().onSurface end } }),
      drop_indicator = ring(t, 12),
    }
  end

  --- A tab that is carried: the current one in the primary over its
  --- rounded indicator; carried, it rises as a container.
  S.reorderable_tabs = function(t, spec)
    return {
      handle = ui.Item {},
      background = lift(t, 1.05, {
        ui.Rect { anchors = { fill = true }, radius = 20, color = function() return C().surfaceContainerHighest end,
          shadow_color = SHADOW, shadow_blur = 16, shadow_offset_y = 6,
          opacity = function() return t.active and 1 or 0 end, behavior = { opacity = quick() } },
        ui.Rect { anchors = { fill = true }, radius = 20,
          color = function()
            local c = C()
            if t.down then return c.onSurface:alpha(0.1) end
            return c.onSurface:alpha(t.hovered and 0.08 or 0)
          end, behavior = { color = quick() } },
        ui.Rect { anchors = { bottom = true, horizontal_center = true }, height = 3, radius = 1.5,
          width = function() return t.highlighted and math.max(0, W(t) - 36) or 0 end,
          opacity = function() return (t.highlighted and not t.active) and 1 or 0 end,
          color = function() return C().primary end,
          behavior = { width = bouncy(), opacity = quick() } } }),
      content = lift(t, 1.05, { M.text { anchors = { fill = true }, horizontal_alignment = "center",
        vertical_alignment = "center", text = spec.label or "",
        color = function() local c = C() return t.highlighted and c.primary or c.onSurfaceVariant end,
        behavior = { color = quick() } } }),
      drop_indicator = ring(t, 20),
    }
  end

  --- A tile that is carried: a high-tone container that turns the primary
  --- container and rounds from 16 to 28 as it rises.
  S.sortable_grid = function(t, spec)
    return {
      handle = ui.Item {},
      background = container(t, 16, 28, 1.07, function() return C().surfaceContainerHigh end),
      content = lift(t, 1.07, {
        M.icon(spec.icon or "apps", 30, function() local c = C() return t.active and c.primary or c.onSurface end,
          { anchors = { horizontal_center = true }, y = function() return H(t) / 2 - 30 end }),
        M.text { anchors = { left = true, right = true }, y = function() return H(t) / 2 + 8 end,
          horizontal_alignment = "center", elide = "right", text = spec.label or "",
          font_size = theme.size.small, color = function() return C().onSurfaceVariant end } }),
      drop_indicator = ring(t, 16),
    }
  end

  --- A card that is swiped: it rises, tips with the drag and fades the
  --- further it goes.
  S.swipe_dismiss = function(t, spec)
    local function tip() return math.max(-6, math.min(6, (t.delta_x or 0) * 0.03)) end
    local function fade() return 1 - 0.5 * clamp01(math.abs(t.delta_x or 0) / math.max(1, W(t))) end
    return {
      handle = ui.Item {},
      background = ui.Item { anchors = { fill = true }, rotation = tip,
        container(t, 16, 24, 1.02, function() return C().surfaceContainerHigh end) },
      content = ui.Item { anchors = { fill = true }, rotation = tip, opacity = fade,
        ui.Rect { x = 12, width = 36, height = 36, radius = 18, anchors = { vertical_center = true },
          color = function() return C().secondaryContainer end,
          M.icon("notifications", 20, function() return C().onSecondaryContainer end, { anchors = { center_in = true } }) },
        M.text { x = 60, y = function() return H(t) / 2 - 20 end, text = spec.label or "",
          color = function() return C().onSurface end },
        M.text { x = 60, y = function() return H(t) / 2 + 2 end, text = spec.detail or "",
          font_size = theme.size.small, color = function() return C().onSurfaceVariant end } },
      drop_indicator = ring(t, 16),
    }
  end

  --- A row whose actions wait under its trailing edge: rounded tertiary
  --- and error containers that grow in as they are uncovered.
  S.swipe_actions = function(t, spec)
    local reveal = spec.reveal or 128
    local actions = spec.actions or {}
    local function uncovered()
      local base = t.open and reveal or 0
      if not t.active then return base / reveal end
      return clamp01((base - (t.delta_x or 0)) / reveal)
    end
    -- (Past the trailing edge: the left one right to left.)
    local plates = ui.Item { x = function() return t.mirrored and -reveal or W(t) end, width = reveal,
      height = function() return H(t) end }
    local each = reveal / math.max(1, #actions)
    for i, action in ipairs(actions) do
      local function tone()
        local c = C()
        if action.tone == "destructive" then return c.errorContainer, c.onErrorContainer end
        return c.tertiaryContainer, c.onTertiaryContainer
      end
      ui.reparent(ui.Rect { x = (i - 1) * each + 3, width = each - 6, y = 3,
        height = function() return H(t) - 6 end, radius = 16,
        scale = function() return 0.7 + 0.3 * uncovered() end,
        color = function() return (tone()) end,
        M.icon(action.icon or "check", 22, function() local _, ink = tone() return ink end,
          { anchors = { horizontal_center = true }, y = function() return (H(t) - 6) / 2 - 20 end,
            opacity = uncovered }),
        M.text { anchors = { left = true, right = true }, y = function() return (H(t) - 6) / 2 + 4 end,
          horizontal_alignment = "center", text = action.label or "", font_size = theme.size.small,
          color = function() local _, ink = tone() return ink end, opacity = uncovered } }, plates)
    end
    return {
      handle = ui.Item {},
      background = ui.Rect { anchors = { fill = true }, radius = 16,
        color = function()
          local c = C()
          local base = c.surfaceContainer
          if t.down then return base:mix(c.onSurface, 0.1) end
          return t.hovered and base:mix(c.onSurface, 0.08) or base
        end, behavior = { color = quick() } },
      content = ui.Item { anchors = { fill = true },
        M.text { x = 16, anchors = { vertical_center = true }, text = spec.label or "",
          color = function() return C().onSurface end },
        ui.Rect { anchors = { fill = true, margins = 1 }, radius = 16, color = "transparent", border_width = 2,
          border_color = function() return C().secondary end, visible = function() return t.visual_focus end } },
      drop_indicator = plates,
    }
  end

  local function arc(cx, cy, r, from, sweep)
    local function at(deg) local a = math.rad(deg) return cx + r * math.sin(a), cy - r * math.cos(a) end
    local x, y = at(from)
    local d = { ("M%.2f %.2f"):format(x, y) }
    local pieces = math.max(1, math.ceil(sweep / 90))
    for i = 1, pieces do
      local ex, ey = at(from + sweep * i / pieces)
      d[#d + 1] = ("A%.2f %.2f 0 0 1 %.2f %.2f"):format(r, r, ex, ey)
    end
    return table.concat(d, " ")
  end

  --- The M3 pull-to-refresh indicator: a disc on a shadow that comes down
  --- with the pull, its primary arc turning and the disc stretching as it
  --- travels; it spins while the list refreshes.
  S.pull_to_refresh = function(t, spec)
    local REST = spec.pull_distance or 64
    local spinner = ui.Item { width = 40, height = 40, rotation = function() return (t.pull or 0) * 320 end,
      loop = function() if t.refreshing then return { rotation = { to = 360, duration = 900 } } end return nil end,
      ui.Path { anchors = { fill = true }, view_box = { 0, 0, 40, 40 }, d = arc(20, 20, 11, 0, 280),
        fill_color = "transparent", stroke_width = 4, stroke_cap = "round", stroke_color = function() return C().primary end } }
    return {
      handle = ui.Item {},
      drop_indicator = ui.Rect { width = 44, height = 44, radius = 22, z = 5,
        x = function() return (W(t) - 44) / 2 end,
        y = function() return t.refreshing and (REST - 44) / 2 or math.min(1.4, t.pull or 0) * REST / 2 - 22 end,
        scale = function() return t.refreshing and 1 or 0.3 + 0.7 * clamp01(t.pull or 0) end,
        visible = function() return t.refreshing or (t.pull or 0) > 0.02 end,
        stretch = { stiffness = 260, damping = 14, scale = 0.14, max = 0.3 },
        color = function() return C().surfaceContainerHigh end,
        shadow_color = SHADOW, shadow_blur = 10, shadow_offset_y = 3,
        behavior = { y = bouncy() },
        ui.Item { anchors = { center_in = true }, width = 40, height = 40, spinner } },
    }
  end

  --- The M3 sheet drag handle: 32 x 4 in the variant ink, longer and full
  --- strength while it is held.
  S.sheet_handle = function(t)
    local function w() return t.active and 48 or (t.hovered and 40 or 32) end
    return {
      background = ring(t, 14),
      handle = ui.Rect { y = 12, height = function() return t.active and 6 or 4 end,
        width = w, x = function() return (W(t) - w()) / 2 end, radius = 3,
        color = function() local c = C() return t.active and c.onSurface or c.onSurfaceVariant:alpha(0.4) end,
        behavior = { width = bouncy(), height = bouncy(), x = bouncy(), color = quick() } },
    }
  end

  --- A window's title strip: the title on a state layer that deepens while
  --- the window moves.
  S.window_move = function(t, spec)
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true, margins = 3 }, radius = 14,
          color = function() local c = C() return c.onSurface:alpha(t.active and 0.12 or (t.hovered and 0.08 or 0)) end,
          behavior = { color = quick() } } },
      content = M.text { anchors = { fill = true }, horizontal_alignment = "center", vertical_alignment = "center",
        text = spec.label or "", color = function() local c = C() return t.active and c.primary or c.onSurface end },
      handle = M.icon("open_with", 18, function() return C().onSurfaceVariant end,
        { x = 12, anchors = { vertical_center = true },
          opacity = function() return (t.hovered or t.active) and 1 or 0 end, behavior = { opacity = quick() } }),
      drop_indicator = ring(t, 14),
    }
  end

  local function chip_face(spec, ink)
    return ui.Row { anchors = { center_in = true }, gap = 8, align = "center",
      spec.icon and M.icon(spec.icon, 18, ink) or nil,
      M.text { text = spec.label or "", font_size = theme.size.small, color = ink } }
  end

  --- Something to drag out: an outlined assist chip; carried, it stays
  --- behind faded and a copy rides the pointer as an elevated primary
  --- container whose corners round further.
  S.drag_source = function(t, spec)
    return {
      handle = ui.Item {},
      background = ui.Rect { anchors = { fill = true }, radius = 10,
        opacity = function() return t.active and 0.38 or 1 end,
        color = function() local c = C() return c.onSurface:alpha(t.down and 0.1 or (t.hovered and 0.08 or 0)) end,
        border_width = 1, border_color = function() return C().outlineVariant end,
        behavior = { color = quick(), opacity = quick() } },
      content = ui.Item { anchors = { fill = true }, opacity = function() return t.active and 0.38 or 1 end,
        chip_face(spec, function() return C().onSurfaceVariant end) },
      ghost = ui.Rect { width = function() return W(t) end, height = function() return H(t) end, z = 30,
        radius = function() return t.active and H(t) / 2 or 10 end,
        translate_x = function() return t.delta_x or 0 end, translate_y = function() return t.delta_y or 0 end,
        scale = function() return t.active and 1.08 or 0.9 end,
        visible = function() return t.active end,
        color = function() return C().primaryContainer end,
        shadow_color = SHADOW, shadow_blur = 18, shadow_offset_y = 8,
        behavior = { scale = bouncy(), radius = bouncy() },
        chip_face(spec, function() return C().onPrimaryContainer end) },
      drop_indicator = ring(t, 10),
    }
  end

  --- Where a drag lands: an outlined container round a tonal icon disc;
  --- while a drag it would take is over it the container fills with the
  --- primary container, its outline turns primary, and the disc swells
  --- and squares off from a circle.
  S.drop_zone = function(t, spec)
    return {
      handle = ui.Item {},
      background = ui.Rect { anchors = { fill = true }, radius = 16,
        color = function() local c = C() return t.accepting and c.primaryContainer or c.surfaceContainerLow or c.surfaceContainer end,
        border_width = function() return t.accepting and 3 or 2 end,
        border_color = function() local c = C() return t.accepting and c.primary or c.outlineVariant end,
        behavior = { color = quick(), border_color = quick() } },
      content = ui.Item { anchors = { fill = true },
        ui.Rect { width = 48, height = 48, anchors = { horizontal_center = true },
          y = function() return H(t) / 2 - 42 end,
          radius = function() return t.accepting and 14 or 24 end,
          scale = function() return t.accepting and 1.15 or 1 end,
          color = function() local c = C() return t.accepting and c.primary or c.secondaryContainer end,
          behavior = { radius = bouncy(), scale = bouncy(), color = quick() },
          M.icon(spec.icon or "upload", 24, function()
            local c = C() return t.accepting and c.onPrimary or c.onSecondaryContainer end,
            { anchors = { center_in = true } }) },
        M.text { anchors = { left = true, right = true }, y = function() return H(t) / 2 + 12 end,
          horizontal_alignment = "center", text = spec.label or "Drop here", font_size = theme.size.small,
          color = function() local c = C() return t.accepting and c.onPrimaryContainer or c.onSurfaceVariant end } },
    }
  end

  -- ------------------------------------------------------ slide to confirm --

  --- Slide to confirm: a surfaceContainerHighest pill with its prompt,
  --- which fades as the knob is slid; the knob is a primary disc that
  --- morphs (one distance-field outline) into a cookie while it is carried
  --- and squashes as it runs, the primary container following it in. Let
  --- go short, it springs home; all the way, it turns sunny with a tick.
  function S.slide_to_confirm(t, spec)
    local K = t.knob or 52
    local function along() return (t.value or 0) * (t.extent or 0) end
    local follow = M.spring(600, 40)
    local function radius() return H(t) / 2 end
    return {
      background = ui.Rect { anchors = { fill = true }, radius = radius,
        opacity = function() return t.enabled == false and 0.38 or 1 end,
        color = function()
          local c = C()
          return t.hovered and c.surfaceContainerHighest:mix(c.onSurface, 0.08) or c.surfaceContainerHighest
        end,
        behavior = { color = quick() },
        ui.ClipRect { anchors = { fill = true }, radius = radius, color = "transparent",
          ui.Rect { anchors = { fill = true }, radius = radius, color = function() return C().primaryContainer end,
            translate_x = function() return along() + K - W(t) end, behavior = { translate_x = follow } } } },
      content = M.text { anchors = { fill = true, left_margin = K, right_margin = 16 }, horizontal_alignment = "center",
        vertical_alignment = "center", elide = "right",
        text = function() return t.done and (spec.done_label or "Done") or (spec.label or "Slide to confirm") end,
        font_size = theme.size.normal, font_weight = 500, color = function() return C().onSurfaceVariant end,
        opacity = function() return t.done and 1 or math.max(0, 1 - (t.value or 0) * 1.8) end,
        behavior = { opacity = quick() } },
      handle = ui.Item { x = 0, y = 0, width = K, height = function() return H(t) end,
        translate_x = along, behavior = { translate_x = follow }, stretch = M.STRETCH,
        ui.Sdf { anchors = { fill = true, margins = 4 }, fill_color = function() return C().primary end,
          shadow_color = function() return C().shadow:alpha(t.active and 0.3 or 0.18) end,
          shadow_blur = function() return t.active and 8 or 3 end, shadow_offset_y = 1,
          behavior = { shadow_blur = quick() },
          M.sdf_shape { anchors = { fill = true },
            shape = function() return t.done and "sunny" or (t.active and "cookie9" or "circle") end, duration = 380 } },
        M.icon(function() return t.done and "check" or (spec.icon or "arrow_forward") end, 22,
          function() return C().onPrimary end, { anchors = { center_in = true } }) },
      drop_indicator = ring(t, radius),
    }
  end
end
