-- Tsugumori's look for each Popup widget: square instrument panels in a
-- hairline of the wallpaper's primary, L-bracket corners, hatched runs
-- and tick rulers, a hard offset shadow -- each widget marked by what it
-- is: a rail down a menu, a tab on a bar's menu, a connector on a
-- submenu, hazard stripes over an alert, crop marks round a picture, a
-- sharp beak on a popover. They come in on the reference's out-expo
-- curves rather than springs (Tsugumori moves without squash and stretch):
-- a menu uncovers from its anchor, a panel opens across, a sheet slides.
-- What a popup holds and how it behaves are not the skin's.
local morf = require("morf")
local ui = require("morf.ui")
local stripes = require("themes.tsugumori.stripes")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local function get(v) if type(v) == "function" then return v() end return v end
  local function primary() return C.primary end
  local function alert() return M.signal("alert")() end

  -- ------------------------------------------------------------- inks --

  -- The primary plate's ink for a tooltip and a toast of words; light ink
  -- on a picture's scrim (lib.kit.popup: `popup_ink`).
  function M.popup_ink(widget, level)
    if widget == "tooltip" or widget == "toast" then
      return function()
        if level == "lo" then return C.onPrimary:alpha(0.78) end
        return C.onPrimary
      end
    elseif widget == "lightbox" then
      return function()
        local ink = C.scrim:text_color()
        if level == "lo" then return ink:alpha(0.7) end
        if level == "accent" then return C.primary end
        return ink
      end
    end
  end

  -- ------------------------------------------------------------ motion --

  local HOW = {
    menu = "uncover", context_menu = "uncover", menu_bar_menu = "uncover", submenu = "uncover",
    dropdown_list = "uncover", autocomplete_list = "uncover", popover = "anchored", tooltip = "anchored",
    rich_tooltip = "anchored", hover_card = "anchored", tour_step = "anchored",
    command_palette = "across", dialog = "across", message_dialog = "across", alert_dialog = "across",
    about_dialog = "across", preferences_dialog = "across", shortcuts_dialog = "across",
    bottom_sheet = "rise", side_sheet = "from_end", drawer = "from_start",
    toast = "wipe", snackbar = "wipe", banner = "uncover", notification_popup = "slide", lightbox = "across",
  }
  local ALONG = { start = 0, center = 0.5, ["end"] = 1 }

  local function pose(widget, placement, w, h)
    local how = HOW[widget] or "across"
    local side, align = tostring(placement or "center"):match("^(%a+)%-?(%a*)$")
    side, align = side or "center", (align ~= nil and align ~= "") and align or "center"
    local p = { ox = 0.5, oy = 0.5, tx = 0, ty = 0, sx = 1, sy = 1, op = 0 }
    local function at_side()
      if side == "bottom" then p.oy, p.ox = 0, ALONG[align]
      elseif side == "top" then p.oy, p.ox = 1, ALONG[align]
      elseif side == "right" then p.ox, p.oy = 0, ALONG[align]
      elseif side == "left" then p.ox, p.oy = 1, ALONG[align] end
    end
    if how == "uncover" then
      at_side()
      if side == "left" or side == "right" then p.sx = 0.08 else p.sy = 0.08 end
      if widget == "banner" then p.oy, p.sy = 0, 0.08 end
    elseif how == "anchored" then
      at_side()
      if side == "bottom" then p.ty = -10 elseif side == "top" then p.ty = 10
      elseif side == "right" then p.tx = -10 elseif side == "left" then p.tx = 10 end
    elseif how == "across" then p.sx, p.sy = 0.04, 0.9
    elseif how == "rise" then p.ty, p.op = h + 40, 1
    elseif how == "from_end" then p.tx, p.op = w + 40, 1
    elseif how == "from_start" then p.tx, p.op = -(w + 40), 1
    elseif how == "wipe" then p.sx = 0.02
    elseif how == "slide" then p.tx = 64 end
    return p
  end

  local function known(v, fallback) v = get(v) return (type(v) == "number" and v > 0) and v or fallback end

  --- The motion the glue gives a popup's node (lib.kit.popup:
  --- `popup_motion`): the reference's covered entrance -- 440 ms out-expo
  --- -- from a pose on its anchor's side.
  function M.popup_motion(widget, spec, state)
    local reduced = theme.duration.small <= 0
    local open = reduced and { duration = 0 } or { duration = 440, easing = "out_expo" }
    local rest = pose(widget, spec.placement, known(spec.width, 280), known(spec.height, 280))
    local function shut(key, at) return function() if state.open() then return at end return rest[key] end end
    return {
      -- How long it stays in the layer once shut, while it goes.
      linger = reduced and 0 or 280,
      behavior = { scale_x = open, scale_y = open, translate_x = open, translate_y = open,
        opacity = reduced and { duration = 0 } or { duration = 180, easing = "out_cubic" } },
      transform_origin_x = rest.ox, transform_origin_y = rest.oy,
      scale_x = shut("sx", 1), scale_y = shut("sy", 1), translate_x = shut("tx", 0), translate_y = shut("ty", 0),
      opacity = function() return (state.open() or rest.op == 1) and 1 or 0 end,
    }
  end

  -- ----------------------------------------------------------- grounds --

  --- A panel: `color` (a role's name), `edge` (its hairline's strength:
  --- quiet, idle, focus; or a binding), `width`, `corners` (the brackets'
  --- length; false for none), `drop` (the hard shadow, true by default).
  local function panel(o)
    o = o or {}
    local color = o.color or "surfaceContainerHigh"
    local edge = type(o.edge) == "function" and o.edge or function() return stroke(C, o.edge or "focus") end
    local ground = ui.Rect { anchors = { fill = true }, color = function() return C[color] end,
      border_width = o.width or 1, border_color = edge,
      shadow_color = o.drop ~= false and function() return C.shadow:alpha(0.4) end or nil,
      shadow_blur = 0, shadow_offset_x = o.drop ~= false and 4 or 0, shadow_offset_y = o.drop ~= false and 4 or 0 }
    local node = ui.Item { anchors = { fill = true }, ground }
    if o.corners ~= false then
      ui.reparent(hud().corners { length = o.corners or 8, weight = o.weight or 1, color = o.mark or primary }, node)
    end
    return node
  end
  local function add(node, ...) for _, child in ipairs { ... } do if child then ui.reparent(child, node) end end return node end

  --- A run of `/` hatching across `anchors` (cut to them), `thick` px deep.
  local function hatch(anchors, size, color, strength)
    anchors.left_margin = anchors.left_margin or 0
    local holder = ui.Item { anchors = anchors, width = size[1], height = size[2], clip = true }
    ui.reparent(stripes.box { width = 640, height = math.max(size[2] or 0, 24), gap = 7, weight = 2,
      color = color or function() return C.primary:alpha(strength or 0.4) end }, holder)
    return holder
  end
  --- Ticks along an edge: a ruler `len` long.
  local function ruler(anchors, len, color)
    local ticks = 6
    return ui.Path { anchors = anchors, width = len, height = ticks, view_box = { 0, 0, len, ticks },
      d = morf.geometry.ruler(len, ticks, { pitch = 8, major = 5, min_count = 4 }),
      fill_color = "transparent", stroke_color = color or function() return stroke(C, "focus") end, stroke_width = 1 }
  end
  local function rail(side, color, width)
    local anchors = { top = true, bottom = true }
    anchors[side] = true
    return ui.Rect { anchors = anchors, width = width or 2, color = color or primary }
  end
  local function band(edge, color, height)
    local anchors = { left = true, right = true }
    anchors[edge] = true
    return ui.Rect { anchors = anchors, height = height or 2, color = color or primary }
  end

  -- A beak's box: an equilateral triangle in it, base sunk 3 px into the
  -- panel, tip at the anchor. No fillet: Tsugumori's joins are sharp.
  local BEAK, ROOM = 18, 24
  local function beaked(t, o)
    local function at()
      local side, align = tostring(t.placement or "center"):match("^(%a+)%-?(%a*)$")
      local w, h = t.width or 0, t.height or 0
      local function along(len) return align == "start" and 22 or (align == "end" and len - 22 or len / 2) end
      if side == "bottom" then return along(w) - 9, -10.5, 0 end
      if side == "top" then return along(w) - 9, h - 7.5, 180 end
      if side == "right" then return -10.5, along(h) - 9, -90 end
      if side == "left" then return w - 7.5, along(h) - 9, 90 end
    end
    local field = ui.Sdf { anchors = { fill = true, margins = -ROOM },
      fill_color = function() return C[o.color or "surfaceContainerHigh"] end,
      stroke_color = o.edge or function() return stroke(C, "focus") end, stroke_width = o.width or 1,
      shadow_color = function() return C.shadow:alpha(0.4) end, shadow_offset_x = 4, shadow_offset_y = 4,
      ui.SdfShape { shape = "box", anchors = { fill = true, margins = ROOM }, radius = 0 },
      ui.SdfShape { shape = "triangle", width = BEAK, height = BEAK,
        visible = function() return at() ~= nil end,
        x = function() local x = at() return (x or 0) + ROOM end,
        y = function() local _, y = at() return (y or 0) + ROOM end,
        rotation = function() local _, _, r = at() return r or 0 end },
    }
    return add(ui.Item { anchors = { fill = true }, field },
      hud().corners { length = o.corners or 8, weight = o.weight or 1, color = primary })
  end

  local function none() return ui.Item {} end

  -- ------------------------------------------------------------- looks --

  local LOOK = {}

  -- Menus: a rail of the primary down the leading edge.
  function LOOK.menu() return { background = add(panel(), rail("left")) } end
  function LOOK.context_menu()
    -- From the pointer: a crosshair at the corner it opened from, no rail.
    return { background = add(panel { corners = 6 },
      ui.Rect { x = -6, y = -1, width = 13, height = 2, color = primary },
      ui.Rect { x = -1, y = -6, width = 2, height = 13, color = primary }) }
  end
  function LOOK.menu_bar_menu()
    -- Hung from the bar: a tab of the primary along its top.
    return { background = add(panel { corners = false }, band("top", primary, 3),
      hud().corners { length = 8, color = primary, visible = true }) }
  end
  function LOOK.submenu()
    -- A connector block on the edge it branched from.
    return { background = add(panel { color = "surfaceContainerHighest" },
      ui.Rect { x = -4, y = 12, width = 7, height = 7, color = primary }) }
  end
  function LOOK.dropdown_list()
    return { background = add(panel { corners = 6 },
      hatch({ right = true, top = true, bottom = true, right_margin = 1, top_margin = 1, bottom_margin = 1 }, { 8, 400 })) }
  end
  function LOOK.autocomplete_list()
    -- A ruler along the top, continuing the field typed in.
    return { background = add(panel { corners = false },
      band("top", primary, 1), ruler({ left = true, top = true, left_margin = 4, top_margin = 2 }, 160)) }
  end

  -- Floating.
  function LOOK.popover(t) return { background = beaked(t, {}) } end
  function LOOK.tooltip()
    -- The primary plate, a dark block at its head.
    return { background = ui.Item { anchors = { fill = true },
      ui.Rect { anchors = { fill = true }, color = primary },
      ui.Rect { anchors = { left = true, top = true, bottom = true }, width = 3,
        color = function() return C.onPrimary:alpha(0.5) end } } }
  end
  function LOOK.rich_tooltip()
    return { background = add(panel(), rail("left", primary, 3),
      hatch({ right = true, top = true, right_margin = 10, top_margin = 6 }, { 44, 8 })) }
  end
  function LOOK.hover_card()
    -- A hatched cover band behind its head.
    return { background = add(panel { corners = 10 },
      hatch({ left = true, right = true, top = true, margins = 1 }, { nil, 40 }, nil, 0.22),
      band("top", primary, 2)) }
  end
  function LOOK.tour_step(t)
    return { background = beaked(t, { edge = primary, width = 2, corners = 12, weight = 2 }) }
  end

  -- Dialogs.
  function LOOK.command_palette()
    return { background = add(panel { edge = "focus", corners = 12, weight = 2 }, band("top", primary, 2),
      ruler({ left = true, bottom = true, left_margin = 12, bottom_margin = 4 }, 200)) }
  end
  function LOOK.dialog()
    return { background = add(panel { corners = 12 },
      hatch({ right = true, top = true, right_margin = 14, top_margin = 8 }, { 72, 10 })) }
  end
  function LOOK.message_dialog()
    return { background = add(panel { corners = 12 }, rail("left", function() return M.signal("info")() end, 3)) }
  end
  function LOOK.alert_dialog()
    -- Hazard stripes over it, its edge in the alert tone.
    return { background = add(panel { corners = 12, edge = alert, mark = alert },
      hatch({ left = true, right = true, top = true, margins = 1 }, { nil, 10 }, alert),
      band("top", alert, 1)) }
  end
  function LOOK.about_dialog()
    return { background = add(panel { corners = 18, weight = 2 },
      hatch({ left = true, right = true, bottom = true, margins = 1 }, { nil, 6 }, nil, 0.3)) }
  end
  local function window()
    return { background = add(panel { color = "surfaceContainer", corners = 12 },
      hatch({ left = true, right = true, top = true, margins = 1 }, { nil, 5 }, nil, 0.45)) }
  end
  function LOOK.preferences_dialog() return window() end
  function LOOK.shortcuts_dialog() return window() end

  -- Sheets: the primary along the edge that faces in, no brackets on the
  -- one they are flush with.
  function LOOK.bottom_sheet()
    local ticks = ui.Row { anchors = { top = true, horizontal_center = true, top_margin = 10 }, gap = 4, z = 5 }
    for _ = 1, 3 do ui.reparent(ui.Rect { width = 10, height = 3, color = primary }, ticks) end
    return { background = add(panel { corners = false }, band("top", primary, 2)), content = ticks }
  end
  function LOOK.side_sheet()
    return { background = add(panel { corners = false }, rail("left", primary, 2),
      ruler({ left = true, top = true, left_margin = 4, top_margin = 6 }, 120)) }
  end
  function LOOK.drawer()
    return { background = add(panel { color = "surfaceContainer", corners = false }, rail("right", primary, 2),
      hatch({ right = true, top = true, bottom = true, right_margin = 4 }, { 6, 600 }, nil, 0.3)) }
  end

  -- Transient.
  function LOOK.toast(t, spec)
    if spec.content then return { background = panel { corners = 6 } } end
    return LOOK.tooltip()
  end
  function LOOK.snackbar(t, spec)
    -- A block at its head, and the time it has left running out along its
    -- foot (a scale of one drawing).
    local left = ui.Rect { anchors = { left = true, right = true, bottom = true, left_margin = 6 }, height = 2,
      transform_origin_x = 0, color = primary }
    local running
    morf.effect("tsugumori.snackbar." .. tostring(left), function()
      local open = t.open
      if running then running:stop() running = nil end
      if open and theme.duration.small > 0 and spec.behavior == nil then
        running = morf.animation.play { { node = left, property = "scale_x", from = 1, to = 0,
          duration = spec.timeout or 5000 } }
      else left.scale_x = 1 end
    end, { owner = left })
    return { background = add(panel { color = "surfaceContainerHighest", corners = false }, rail("left", primary, 6), left) }
  end
  function LOOK.banner()
    return { background = add(panel { corners = false },
      hatch({ left = true, right = true, top = true, bottom = true, margins = 1 }, { nil, 200 }, nil, 0.12),
      rail("left", primary, 4)) }
  end
  function LOOK.notification_popup()
    return { background = add(panel(), rail("left", primary, 3),
      hatch({ right = true, top = true, right_margin = 10, top_margin = 6 }, { 40, 8 })) }
  end
  function LOOK.lightbox()
    -- Crop marks just outside the picture's frame.
    return { background = add(ui.Item { anchors = { fill = true } },
      ui.Rect { anchors = { fill = true }, color = function() return C.scrim:alpha(0.92) end },
      hud().corners { length = 12, weight = 2, inset = -7, color = primary }) }
  end

  for widget, look in pairs(LOOK) do
    S[widget] = function(t, spec)
      local slots = look(t, spec)
      slots.dim = none()
      return slots
    end
  end
end
