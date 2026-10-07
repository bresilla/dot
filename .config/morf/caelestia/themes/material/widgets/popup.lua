-- Material 3's look for each Popup widget: tonal surfaces with no
-- outline -- menus on surfaceContainer with 12 px corners, dialogs on
-- surfaceContainerHigh with 28 px ones, sheets with a drag handle, plain
-- tooltips and snackbars on the inverse surface -- lifted by the shadow
-- role. A popover and a tour step wear a beak filleted into their body
-- (one distance field). Each comes in on a spring from where it hangs: a
-- menu unfolds from its anchor's edge, a dialog grows from the middle, a
-- sheet slides, a snackbar rises and a toast stretches. What a popup holds
-- and how it behaves are not the skin's.
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local function get(v) if type(v) == "function" then return v() end return v end

  -- ------------------------------------------------------------- inks --

  -- The inverse surface's ink for a tooltip, a toast of words and a
  -- snackbar; light ink on a picture's scrim (lib.kit.popup: `popup_ink`).
  local INVERSE = { tooltip = true, toast = true, snackbar = true }
  function M.popup_ink(widget, level)
    if INVERSE[widget] then
      return function()
        local c = C()
        if level == "accent" then return c.inversePrimary end
        if level == "lo" then return c.inverseOnSurface:alpha(0.78) end
        return c.inverseOnSurface
      end
    elseif widget == "lightbox" then
      return function()
        local ink = C().scrim:text_color()
        if level == "lo" then return ink:alpha(0.7) end
        if level == "accent" then return C().inversePrimary end
        return ink
      end
    end
  end

  -- ------------------------------------------------------------ motion --

  local HOW = {
    menu = "unfold", context_menu = "unfold", menu_bar_menu = "unfold", submenu = "unfold",
    dropdown_list = "unfold", autocomplete_list = "unfold", popover = "anchored", tooltip = "anchored",
    rich_tooltip = "anchored", hover_card = "anchored", tour_step = "anchored",
    command_palette = "drop", dialog = "center", message_dialog = "center", alert_dialog = "center",
    about_dialog = "center", preferences_dialog = "center", shortcuts_dialog = "center",
    bottom_sheet = "rise", side_sheet = "from_end", drawer = "from_start",
    toast = "stretch", snackbar = "lift", banner = "drop", notification_popup = "slide", lightbox = "zoom",
  }
  local ALONG = { start = 0, center = 0.5, ["end"] = 1 }

  --- The pose a popup comes in from: an origin on its anchor's side, a
  --- scale (and a vertical and horizontal one), offsets, an opacity.
  local function pose(widget, placement, w, h)
    local how = HOW[widget] or "center"
    local side, align = tostring(placement or "center"):match("^(%a+)%-?(%a*)$")
    side, align = side or "center", (align ~= nil and align ~= "") and align or "center"
    local p = { ox = 0.5, oy = 0.5, tx = 0, ty = 0, s = 1, sx = 1, sy = 1, op = 0 }
    local function from_side(shift)
      if side == "bottom" then p.oy, p.ty, p.ox = 0, -shift, ALONG[align]
      elseif side == "top" then p.oy, p.ty, p.ox = 1, shift, ALONG[align]
      elseif side == "right" then p.ox, p.tx, p.oy = 0, -shift, ALONG[align]
      elseif side == "left" then p.ox, p.tx, p.oy = 1, shift, ALONG[align] end
    end
    if how == "unfold" then
      -- Material's menu: unrolled from the edge at its anchor.
      from_side(0)
      if side == "left" or side == "right" then p.sx = 0.6 else p.sy = 0.55 end
    elseif how == "anchored" then p.s = 0.9 from_side(6)
    elseif how == "center" then p.s = 0.84
    elseif how == "rise" then p.ty, p.op = h + 56, 1
    elseif how == "from_end" then p.tx, p.op = w + 56, 1
    elseif how == "from_start" then p.tx, p.op = -(w + 56), 1
    elseif how == "drop" then p.oy, p.ty, p.sy = 0, -28, 0.9
    elseif how == "stretch" then p.sx, p.s, p.ty = 0.5, 0.92, 18
    elseif how == "lift" then p.ty, p.sx = 40, 0.9
    elseif how == "slide" then p.tx = 72
    elseif how == "zoom" then p.s = 0.7 end
    return p
  end

  local function known(v, fallback) v = get(v) return (type(v) == "number" and v > 0) and v or fallback end

  --- The motion the glue gives a popup's node (lib.kit.popup:
  --- `popup_motion`): its pose at rest while open, and the springs that
  --- carry it there -- Material's expressive ones, a touch past and back.
  function M.popup_motion(widget, spec, state)
    local how = HOW[widget] or "center"
    local spatial = M.spring(how == "unfold" and 560 or 520, how == "unfold" and 30 or 34)
    local bouncy = M.spring(360, 17)
    local grow = (how == "stretch" or how == "zoom") and bouncy or spatial
    local rest = pose(widget, spec.placement, known(spec.width, 280), known(spec.height, 280))
    local function shut(key, open) return function() if state.open() then return open end return rest[key] end end
    return {
      -- How long it stays in the layer once shut, while it goes.
      linger = (theme.duration.small or 0) <= 0 and 0 or 260,
      behavior = { scale = grow, scale_x = grow, scale_y = grow, translate_x = spatial, translate_y = spatial,
        opacity = { duration = theme.duration.small, easing = theme.ease.standard_decel } },
      transform_origin_x = rest.ox, transform_origin_y = rest.oy,
      scale = shut("s", 1), scale_x = shut("sx", 1), scale_y = shut("sy", 1),
      translate_x = shut("tx", 0), translate_y = shut("ty", 0),
      opacity = function() return (state.open() or rest.op == 1) and 1 or 0 end,
    }
  end

  -- ----------------------------------------------------------- grounds --

  --- The shadow role under a ground, by elevation level (1-3).
  local function lifted(props, level)
    props.shadow_color = function() return C().shadow:alpha(0.14 + level * 0.04) end
    props.shadow_blur = 4 + level * 4
    props.shadow_offset_y = level
    return props
  end
  local function role(name) return function() return C()[name] end end

  --- A tonal ground: `corners` (one radius or { tl, tr, br, bl }), `color`
  --- (a role's name or a binding), `level` (its elevation; 0 none),
  --- `outline` (a border binding).
  local function ground(o)
    local c = type(o.corners) == "table" and o.corners or { o.corners, o.corners, o.corners, o.corners }
    local color = type(o.color) == "string" and role(o.color) or o.color or role("surfaceContainer")
    local props = { anchors = { fill = true }, color = color,
      top_left_radius = c[1], top_right_radius = c[2], bottom_right_radius = c[3], bottom_left_radius = c[4],
      border_width = o.outline and 1 or 0, border_color = o.outline or "transparent",
      behavior = { color = { duration = theme.duration.small } } }
    if (o.level or 2) > 0 then lifted(props, o.level or 2) end
    return ui.Rect(props)
  end

  -- A beak: the field's triangle inscribed in an 18 px box, its base sunk
  -- 3 px into the body, its tip towards the anchor.
  local BEAK, ROOM = 18, 26
  local function beaked(t, o)
    local function at()
      local side, align = tostring(t.placement or "center"):match("^(%a+)%-?(%a*)$")
      local w, h = t.width or 0, t.height or 0
      local function along(len) return align == "start" and 26 or (align == "end" and len - 26 or len / 2) end
      if side == "bottom" then return along(w) - 9, -10.5, 0 end
      if side == "top" then return along(w) - 9, h - 7.5, 180 end
      if side == "right" then return -10.5, along(h) - 9, -90 end
      if side == "left" then return w - 7.5, along(h) - 9, 90 end
    end
    local color = type(o.color) == "string" and role(o.color) or o.color
    local field = ui.Sdf(lifted({ anchors = { fill = true, margins = -ROOM }, blend = 8, blend_profile = "circular",
      fill_color = color, stroke_color = o.outline or "transparent", stroke_width = o.outline and (o.width or 1) or 0,
      ui.SdfShape { shape = "box", anchors = { fill = true, margins = ROOM }, radius = o.radius or 16 },
      ui.SdfShape { shape = "triangle", operation = "smooth_union", width = BEAK, height = BEAK,
        visible = function() return at() ~= nil end,
        x = function() local x = at() return (x or 0) + ROOM end,
        y = function() local _, y = at() return (y or 0) + ROOM end,
        rotation = function() local _, _, r = at() return r or 0 end },
    }, o.level or 2))
    return ui.Item { anchors = { fill = true }, field }
  end

  --- A tonal wash across the top of a ground, fading out.
  local function glow(name, height, radius, strength)
    return ui.Rect { anchors = { left = true, right = true, top = true }, height = height,
      top_left_radius = radius, top_right_radius = radius,
      gradient = function()
        local c = C()[name]
        return { angle = 180, stops = { c:alpha(strength), c:alpha(0) } }
      end }
  end
  local function stack(...) return ui.Item { anchors = { fill = true }, ... } end
  local function none() return ui.Item {} end
  -- Material's drag handle: 32 x 4, onSurfaceVariant at 40 %.
  local function handle()
    return ui.Rect { anchors = { top = true, horizontal_center = true, top_margin = 10 }, width = 32, height = 4,
      radius = 2, z = 5, color = function() return C().onSurfaceVariant:alpha(0.4) end }
  end

  -- ------------------------------------------------------------- looks --

  local LOOK = {}

  -- Menus: surfaceContainer, 12 px corners, level 2; attached ones square
  -- where they meet what they hang from.
  function LOOK.menu() return { background = ground { corners = 12 } } end
  function LOOK.context_menu() return { background = ground { corners = 12 } } end
  function LOOK.menu_bar_menu() return { background = ground { corners = { 2, 2, 12, 12 } } } end
  function LOOK.submenu()
    -- One tone higher than the menu it came from.
    return { background = ground { corners = 12, color = "surfaceContainerHigh", level = 3 } }
  end
  function LOOK.dropdown_list() return { background = ground { corners = { 0, 0, 8, 8 } } } end
  function LOOK.autocomplete_list()
    -- Under the field being typed in: its active indicator runs on along
    -- the top.
    return { background = stack(ground { corners = { 0, 0, 8, 8 } },
      ui.Rect { anchors = { left = true, right = true, top = true }, height = 2, color = role("primary") }) }
  end

  -- Floating.
  function LOOK.popover(t) return { background = beaked(t, { color = "surfaceContainerHigh", radius = 16 }) } end
  function LOOK.tooltip()
    return { background = ui.Rect { anchors = { fill = true }, radius = 4, color = role("inverseSurface") } }
  end
  function LOOK.rich_tooltip() return { background = ground { corners = 12, color = "surfaceContainer" } } end
  function LOOK.hover_card()
    -- An elevated card with a cover of the primary container.
    return { background = stack(ground { corners = 16, color = "surfaceContainerLow", level = 1 },
      glow("primaryContainer", 64, 16, 0.9)) }
  end
  function LOOK.tour_step(t)
    return { background = beaked(t, { color = "surfaceContainerHigh", radius = 16, level = 3,
      outline = role("primary"), width = 2 }) }
  end

  -- Dialogs: surfaceContainerHigh, 28 px corners, level 3.
  function LOOK.command_palette() return { background = ground { corners = 28, color = "surfaceContainerHigh", level = 3 } } end
  function LOOK.dialog() return { background = ground { corners = 28, color = "surfaceContainerHigh", level = 3 } } end
  function LOOK.message_dialog()
    return { background = stack(ground { corners = 28, color = "surfaceContainerHigh", level = 3 },
      glow("secondaryContainer", 72, 28, 0.6)) }
  end
  function LOOK.alert_dialog()
    return { background = stack(ground { corners = 28, color = "surfaceContainerHigh", level = 3 },
      glow("errorContainer", 96, 28, 0.5)) }
  end
  function LOOK.about_dialog()
    return { background = stack(ground { corners = 28, color = "surfaceContainerHigh", level = 3 },
      glow("primaryContainer", 120, 28, 0.85)) }
  end
  -- Full-screen dialogs: the surface itself, an outline round it.
  local function full()
    return { background = ground { corners = 28, color = "surface", level = 3,
      outline = function() return C().outlineVariant end } }
  end
  function LOOK.preferences_dialog() return full() end
  function LOOK.shortcuts_dialog() return full() end

  -- Sheets: surfaceContainerLow, rounded on the side that faces in.
  function LOOK.bottom_sheet()
    return { background = ground { corners = { 28, 28, 0, 0 }, color = "surfaceContainerLow", level = 1 },
      content = handle() }
  end
  function LOOK.side_sheet() return { background = ground { corners = { 16, 0, 0, 16 }, color = "surfaceContainerLow", level = 1 } } end
  function LOOK.drawer() return { background = ground { corners = { 0, 16, 16, 0 }, color = "surfaceContainerLow", level = 1 } } end

  -- Transient.
  function LOOK.toast(t, spec)
    if spec.content then return { background = ground { corners = 16, color = "surfaceContainer", level = 3 } } end
    return { background = ui.Rect(lifted({ anchors = { fill = true }, radius = function() return (t.height or 0) / 2 end,
      color = role("inverseSurface") }, 3)) }
  end
  function LOOK.snackbar()
    return { background = ui.Rect(lifted({ anchors = { fill = true }, radius = 4, color = role("inverseSurface") }, 3)) }
  end
  function LOOK.banner()
    return { background = stack(ground { corners = 12, color = "secondaryContainer", level = 1 }) }
  end
  function LOOK.notification_popup() return { background = ground { corners = 16, color = "surfaceContainerHigh", level = 3 } } end
  function LOOK.lightbox()
    return { background = ui.Rect(lifted({ anchors = { fill = true }, radius = 28,
      color = function() return C().scrim:alpha(0.9) end }, 3)) }
  end

  for widget, look in pairs(LOOK) do
    S[widget] = function(t, spec)
      local slots = look(t, spec)
      slots.dim = none()
      return slots
    end
  end
end
