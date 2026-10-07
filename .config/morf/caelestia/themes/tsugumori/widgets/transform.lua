-- Tsugumori's looks for the Transform archetype and each of its widgets.
-- The layouts are the kit's (the default look's widgets/transform.lua),
-- drawn square in the wallpaper's roles: a floating panel as a framed
-- window with its title in capitals, a hatched run in its title bar,
-- square framed buttons and brackets on its corners; an image cropper
-- whose dimmed outside is hatched, bracketed in the primary, its thirds
-- in a quiet stroke; a resize box as a hairline with square grips,
-- brackets standing off its corners and a square knob on a stalk, its
-- size read out in a square plate; a picture-in-picture as a framed tile
-- whose brackets close in under the pointer; an event block as a square
-- chip in its tone with a primary bar down its edge and a hatched grab
-- strip along its bottom.
local morf = require("morf")
local ui = require("morf.ui")
local stripes = require("themes.tsugumori.stripes")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local look, K = M.canvas_look, M.canvas_kit
  local quick = { duration = 140, easing = "out_cubic" }

  --- A grip: a square on a corner (the ground inside a primary hairline,
  --- the primary while held, a size up under the pointer), a short bar
  --- on an edge.
  function K.transform_knob(s)
    local vertical = s.name == "e" or s.name == "w"
    local function big() return s.hovered() or s.held() end
    return ui.Rect { anchors = { center_in = true },
      width = function() if s.corner then return big() and 11 or 8 end return vertical and 3 or (big() and 20 or 14) end,
      height = function() if s.corner then return big() and 11 or 8 end return vertical and (big() and 20 or 14) or 3 end,
      color = function()
        if not s.corner then return C.primary end
        return s.held() and C.primary or C.surface
      end,
      border_width = function() return s.corner and 1 or 0 end, border_color = function() return C.primary end,
      behavior = { width = quick, height = quick, color = quick } }
  end

  --- A window button: a square in a quiet frame that lights under the
  --- pointer, its symbol in the variant ink.
  function K.transform_button(icon, name, action, size)
    size = size or 24
    local area
    area = ui.MouseArea { width = size, height = size, cursor = "pointer", accessible_role = "button",
      accessible_name = name, on_clicked = action,
      ui.Rect { anchors = { fill = true },
        color = function() return (area and area.pressed) and C.primary:alpha(0.16) or C.primary:alpha(0) end,
        border_width = 1,
        border_color = function() return (area and area.hovered) and stroke(C, "focus") or stroke(C, "idle") end,
        behavior = { border_color = quick, color = quick } },
      M.icon(icon, 14, function() return (area and area.hovered) and C.primary or C.onSurfaceVariant end,
        { anchors = { center_in = true } }) }
    return area
  end

  --- The turn's handle: a hairline stalk to a square knob.
  function K.transform_rotate_handle(spec)
    local STALK, KNOB = spec.stalk or 28, 16
    return ui.Item { anchors = { horizontal_center = true, top = true, top_margin = -STALK - KNOB / 2 },
      width = KNOB, height = STALK + KNOB / 2,
      ui.Rect { x = math.floor(KNOB / 2), anchors = { bottom = true }, width = 1, height = STALK - KNOB / 2,
        color = function() return C.primary end },
      ui.Rect { width = KNOB, height = KNOB, color = function() return C.surface end, border_width = 1,
        border_color = function() return C.primary end,
        M.icon("rotate_right", 12, function() return C.primary end, { anchors = { center_in = true } }) } }
  end

  K.transform_title = function(s) return s:upper() end
  K.transform_tones = {
    ground = function() return C.surfaceContainerLow end,
    header = function() return C.surfaceContainer end,
    line = function() return stroke(C, "idle") end,
    edge = function() return stroke(C, "hover") end,
  }

  require("lib.kit.skins.default.widgets.transform")(S, look, K)
  local function restyle(name, change) require("lib.kit.canvas").restyle(S, name, change) end
  local function get(v) if type(v) == "function" then return v() end return v end

  -- A hatched strip `h` high, cut to its box however wide it grows.
  local function hatch_strip(props, h, color)
    props.clip = true
    local node = ui.Item(props)
    ui.reparent(stripes.box { width = 640, height = h, gap = 6, weight = 1.5, color = color }, node)
    return node
  end

  -- The window: brackets on its corners and a hatched run in its title
  -- bar, before the title.
  restyle("floating_panel", function(slots, t, spec)
    local TITLE = spec.title_height or 40
    local frame = slots.frame
    ui.reparent(hatch_strip({ x = 12, y = 12, width = 56, height = TITLE - 24,
      opacity = function() return t.focused and 1 or 0.45 end, behavior = { opacity = quick } }, TITLE - 24,
      function() return C.primary:alpha(0.45) end), frame)
    ui.reparent(hud().corners { length = 8, weight = 2, inset = -1, color = function() return C.primary end }, frame)
    return { frame }
  end)

  -- The cropper: its dimmed outside hatched, brackets in the primary.
  restyle("image_cropper", function(slots, t, spec)
    local background = slots.background
    if background then
      -- One hatch the size of the picture, seen through each dimmed part:
      -- the parts move, the stripes stay where they are on the picture.
      local function cw() return t.container_width end
      local function ch() return t.container_height end
      local function part(x, y, w, h)
        local box = ui.Item { x = x, y = y, width = w, height = h, clip = true }
        ui.reparent(ui.Path { x = function() return -get(x) - t.x end, y = function() return -get(y) - t.y end,
          width = cw, height = ch,
          view_box = function() return { 0, 0, math.max(1, cw()), math.max(1, ch()) } end,
          d = function() return stripes.hatch_d(math.max(1, cw()), math.max(1, ch()), 10) end,
          fill_color = "transparent", stroke_width = 1, stroke_cap = "butt",
          stroke_color = function() return C.primary:alpha(0.35) end }, box)
        ui.reparent(box, background)
      end
      local function neg_x() return -t.x end
      part(neg_x, function() return -t.y end, cw, function() return math.max(0, t.y) end)
      part(neg_x, function() return t.box_height end, cw, function() return math.max(0, ch() - t.y - t.box_height) end)
      part(neg_x, 0, function() return math.max(0, t.x) end, function() return t.box_height end)
      part(function() return t.box_width end, 0, function() return math.max(0, cw() - t.x - t.box_width) end,
        function() return t.box_height end)
    end
    slots.frame = ui.Item { anchors = { fill = true },
      ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
        border_color = function() return C.primary:alpha(0.8) end },
      hud().corners { length = 20, weight = 3, inset = -3, color = function() return C.primary end },
      ui.Rect { anchors = { fill = true, margins = -6 }, color = "transparent", border_width = 1,
        border_color = function() return stroke(C, "focus") end, visible = function() return t.visual_focus end } }
    slots.handle = function(s)
      if s.corner then return nil end
      local vertical = s.name == "e" or s.name == "w"
      return ui.Rect { anchors = { center_in = true }, color = function() return C.primary end,
        width = function() return vertical and 3 or ((s.hovered() or s.held()) and 28 or 18) end,
        height = function() return vertical and ((s.hovered() or s.held()) and 28 or 18) or 3 end,
        behavior = { width = quick, height = quick } }
    end
    return background and { background } or nil
  end)

  -- The resize box: a hairline, brackets standing off its corners, the
  -- size in a square plate.
  for _, name in ipairs { "Transform", "resize_box" } do
    restyle(name, function(slots, t)
      slots.frame = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
          border_color = function() return C.primary end },
        hud().corners { length = 10, weight = 1, inset = -8, color = function() return stroke(C, "focus") end },
        ui.Rect { anchors = { fill = true, margins = -12 }, color = "transparent", border_width = 1,
          border_color = function() return stroke(C, "focus") end, visible = function() return t.visual_focus end } }
      if slots.guide then
        slots.guide = ui.Rect { anchors = { horizontal_center = true }, y = function() return t.box_height + 14 end,
          width = 104, height = 24, color = function() return C.primary end,
          opacity = function() return t.active == "resize" and 1 or 0 end, behavior = { opacity = quick },
          M.text { anchors = { fill = true }, horizontal_alignment = "center", vertical_alignment = "center",
            font_size = theme.typography.label + 1, color = function() return C.onPrimary end,
            text = function()
              return ("%d × %d"):format(math.floor(t.box_width + 0.5), math.floor(t.box_height + 0.5))
            end } }
      end
    end)
  end

  -- The picture-in-picture: a hairline frame, brackets closing in under
  -- the pointer.
  restyle("pip_window", function(slots, t)
    local frame = slots.frame
    ui.reparent(ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
      border_color = function() return stroke(C, "hover") end }, frame)
    ui.reparent(hud().corners { length = 10, weight = 2, color = function() return C.primary end,
      inset = -6, opacity = function() return (t.hovered or t.down) and 1 or 0.5 end }, frame)
    return { frame }
  end)

  -- The event block: a hatched grab strip along its bottom, lit under
  -- the pointer.
  restyle("event_block", function(slots, t, spec)
    local function tone() return (M.canvas_tone and M.canvas_tone(get(spec.tone) or "accent")) or C.primary end
    slots.frame = ui.Item { anchors = { fill = true },
      hatch_strip({ anchors = { left = true, right = true, bottom = true, left_margin = 10, right_margin = 6,
        bottom_margin = 4 }, height = 6,
        opacity = function() return (t.hovered or t.active ~= "none") and 1 or 0.45 end,
        behavior = { opacity = quick } }, 6, tone),
      ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1, border_color = tone,
        opacity = function() return t.focused and 1 or 0 end, behavior = { opacity = quick } },
      hud().corners { length = 6, weight = 1, color = tone, visible = function() return t.active ~= "none" end } }
  end)
end
