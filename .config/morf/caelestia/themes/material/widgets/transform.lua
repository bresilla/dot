-- Material's looks for the Transform archetype and each of its widgets.
-- The layouts are the kit's (the default look's widgets/transform.lua),
-- drawn in Material's roles at its roundings: a floating panel as a
-- surfaceContainerHigh sheet whose 28 px corners spring square as it
-- maximizes, with standard icon buttons whose round state layer tightens
-- to a rounded square pressed; a resize box as one distance field in the
-- primary -- its outline, the dots on its corners and edges and the turn
-- knob on its stalk all filleted together, a dot swelling under the
-- pointer and morphing from a circle to a rounded square while held; an
-- image cropper with round-ended brackets; a picture-in-picture that
-- squashes and stretches on Material's springs as it flies to a corner;
-- an event block on its tone's container.
local morf = require("morf")
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local look, K = M.canvas_look, M.canvas_kit
  local function quick() return { duration = theme.duration.small, easing = theme.ease.standard } end

  --- A standard icon button: a round state layer that shows under the
  --- pointer and tightens to a rounded square pressed (Material 3's shape
  --- morph); the symbol in onSurfaceVariant.
  function K.transform_button(icon, name, action, size)
    size = size or 32
    local area
    area = ui.MouseArea { width = size, height = size, cursor = "pointer", accessible_role = "button",
      accessible_name = name, on_clicked = action,
      ui.Rect { anchors = { fill = true },
        radius = function() return (area and area.pressed) and size / 4 or size / 2 end,
        color = function()
          local c = C()
          if area and area.pressed then return c.onSurfaceVariant:alpha(0.12) end
          if area and area.hovered then return c.onSurfaceVariant:alpha(0.08) end
          return c.onSurfaceVariant:alpha(0)
        end,
        behavior = { radius = M.spring(520, 22), color = quick() } },
      M.icon(icon, 20, function() return C().onSurfaceVariant end, { anchors = { center_in = true } }) }
    return area
  end

  --- A grip as a layer of the resize box's field (below): a dot on a
  --- corner, a capsule on an edge, swelling under the pointer; held, a
  --- corner's dot morphs to a rounded square. The node returned is what
  --- the field's layer tracks.
  local function field_knob(field, s)
    if not field then return nil end
    local vertical = s.name == "e" or s.name == "w"
    local function big() return s.hovered() or s.held() end
    local w = function() if s.corner then return big() and 18 or 12 end return vertical and 6 or (big() and 28 or 20) end
    local h = function() if s.corner then return big() and 18 or 12 end return vertical and (big() and 28 or 20) or 6 end
    local node = ui.Item { anchors = { center_in = true }, width = w, height = h,
      behavior = { width = M.spring(420, 18), height = M.spring(420, 18) } }
    ui.reparent(ui.SdfShape { shape = "box", track = node, operation = "smooth_union", blend = 4,
      radius = function()
        if s.corner and s.held() then return 5 end
        return math.min(w(), h()) / 2
      end, behavior = { radius = M.spring(420, 22) } }, field)
    return node
  end

  -- The resize box's field: the outline a ring of the primary, the stalk
  -- a capsule up from it and the turn knob a circle on top, joined by
  -- round seams; the grips add their layers to it as they are made.
  local function selection_field(t, spec, rotatable)
    local PAD, STALK, KNOB = 24, spec.stalk or 28, 20
    local top = rotatable and (STALK + KNOB / 2 + 4) or PAD
    local field = ui.Sdf { anchors = { fill = true, margins = -PAD, top_margin = -top }, blend = 8,
      fill_color = function() return C().primary end }
    local outline = ui.Item { anchors = { fill = true, margins = PAD - 1, top_margin = top - 1 } }
    local inside = ui.Item { anchors = { fill = true, margins = PAD + 1, top_margin = top + 1 } }
    ui.reparent(outline, field)
    ui.reparent(inside, field)
    ui.reparent(ui.SdfShape { shape = "box", radius = 2, track = outline }, field)
    ui.reparent(ui.SdfShape { shape = "box", radius = 1, track = inside, operation = "subtract" }, field)
    if rotatable then
      local stalk = ui.Item { anchors = { horizontal_center = true, top = true, top_margin = top - STALK }, width = 2,
        height = STALK }
      local knob = ui.Item { anchors = { horizontal_center = true, top = true, top_margin = top - STALK - KNOB / 2 },
        width = KNOB, height = KNOB }
      ui.reparent(stalk, field)
      ui.reparent(knob, field)
      ui.reparent(ui.SdfShape { shape = "box", radius = 1, track = stalk, operation = "smooth_union", blend = 6 }, field)
      ui.reparent(ui.SdfShape { shape = "circle", track = knob, operation = "smooth_union", blend = 6 }, field)
      ui.reparent(M.icon("rotate_right", 14, function() return C().onPrimary end,
        { anchors = { horizontal_center = true, top = true, top_margin = top - STALK - 7 } }), field)
    end
    return field
  end

  -- A floating panel is one surfaceContainerHigh sheet, header and all,
  -- with no outline: the shadow lifts it.
  K.transform_tones = {
    ground = function() return C().surfaceContainerHigh end,
    header = function() return C().surfaceContainerHigh end,
    line = function() return C().outlineVariant end,
    edge = function() return C().outlineVariant:alpha(0) end,
  }

  require("lib.kit.skins.default.widgets.transform")(S, look, K)
  local function restyle(name, change) require("lib.kit.canvas").restyle(S, name, change) end
  local function get(v) if type(v) == "function" then return v() end return v end

  -- The outline, grips and turn knob as one field; the keyboard's ring.
  for _, name in ipairs { "Transform", "resize_box" } do
    restyle(name, function(slots, t, spec)
      local field = selection_field(t, spec, get(spec.rotatable) == true)
      slots.frame = ui.Item { anchors = { fill = true }, field,
        ui.Rect { anchors = { fill = true, margins = -5 }, color = "transparent", radius = 6, border_width = 2,
          border_color = function() return C().secondary end, visible = function() return t.visual_focus end } }
      slots.handle = function(s) return field_knob(field, s) end
      slots.rotate_handle = nil
    end)
  end

  -- The cropper's brackets and edge bars with round ends.
  restyle("image_cropper", function(slots, t)
    local paper = function() local p = look.P() return p.paper end
    local B, L = 4, 22
    local function bracket(anchors, horizontal)
      return ui.Rect { anchors = anchors, width = horizontal and L or B, height = horizontal and B or L, radius = B / 2,
        color = paper }
    end
    local frame = ui.Item { anchors = { fill = true },
      ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
        border_color = function() return paper():alpha(0.8) end },
      ui.Rect { anchors = { fill = true, margins = -5 }, color = "transparent", radius = 6, border_width = 2,
        border_color = function() return C().primary end, visible = function() return t.visual_focus end } }
    for _, corner in ipairs { { "left", "top" }, { "right", "top" }, { "left", "bottom" }, { "right", "bottom" } } do
      for _, horizontal in ipairs { true, false } do
        local a = { [corner[1]] = true, [corner[2]] = true }
        a[corner[1] .. "_margin"], a[corner[2] .. "_margin"] = -B, -B
        ui.reparent(bracket(a, horizontal), frame)
      end
    end
    slots.frame = frame
  end)

end
