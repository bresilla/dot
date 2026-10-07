-- The volume / brightness OSD as a vertical level column beside the
-- right-edge markers: the channel's name and tag, the theme's vertical
-- meter (with the theme's scale down both sides and its marks riding the
-- level, where it draws them), and the reading large under it. It swells out of the frame (a layer of the
-- frame's field) beside its marker, its corners easing from round to the
-- theme's own as it lands and stretching along its run; the meter fills
-- from its floor as it arrives and eases to every new reading. Nothing
-- moves at rest.
--
-- Readings, hold and visibility are shell/levels.lua's; this is the face.
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local P = require("themes.layouts.parts")
local C = theme.color
local V = {}

function V.build(model)
  local W, H = 118, 322
  local COL_W = 26
  local COL_X = math.floor((W - COL_W) / 2)
  local CAP = P.role_size("caption")
  local LABEL_H = P.lh(P.role_size("label"))
  local TITLE_H = P.lh(CAP)
  local CHIP_Y = 6 + TITLE_H + 2
  local CODE_Y = CHIP_Y + 13 + 3
  local COL_Y = CODE_Y + LABEL_H + 4
  local VALUE = P.role_size("hero")
  local VALUE_H = P.lh(VALUE)
  local FOOT_Y = H - 20
  local VALUE_Y = FOOT_Y - 4 - VALUE_H
  local COL_H = VALUE_Y - 6 - COL_Y
  local REST = P.control_round(W) -- the theme's corners at rest
  local ROUND = W / 4      -- and while it swells

  local function geometry()
    local r = model.rail_geometry()
    local top = math.floor((r.h - 2 * r.item - r.gap) / 2)
    return { w = r.w, h = r.h, item = r.item, pill_h = r.item, gap = r.gap, pill_x = r.w - theme.BORDER / 2 - 3,
      clear = 8, tops = { volume = top, brightness = top + r.item + r.gap } }
  end
  local function kind() return model.shown:get() ~= "" and model.shown:get() or "volume" end
  local function value() return model.value[kind()]() end
  local function muted() return kind() == "volume" and model.muted() end
  local function ink()
    if muted() then return kit.signal("warn")() end
    return kind() == "brightness" and kit.signal("info")() or kit.signal("accent")()
  end
  local function tucked() return geometry().w + theme.BORDER + 2 end
  local function out() return geometry().w - W - theme.BORDER - 8 end
  local settle = { duration = theme.duration.large, easing = theme.ease.emphasized_decel }

  -- The meter, filling from its floor (its origin) when the column arrives.
  local meter = ui.Item { x = COL_X, y = COL_Y, width = COL_W, height = COL_H, transform_origin_y = 1,
    kit.vmeter { id = "levels-meter", width = COL_W, height = COL_H, value = value, color = ink,
      count = math.floor(COL_H / 7) },
  }
  -- The theme's marks either side of the column at the level (none where
  -- the theme draws no ticks).
  local marker = ui.Item { x = COL_X - 6, width = COL_W + 12, height = 14,
    y = function() return COL_Y + COL_H * (1 - value()) - 7 end, behavior = { y = settle },
    P.decor_box("ticks", { y = 3, length = COL_W + 12, count = 1, major = 1, size = 8, color = ink }),
  }

  local body = ui.Item { id = "levels-bud", width = W, height = H,
    P.decor_box("corners", { length = 8, color = ink }),
    kit.heading { id = "levels-title", x = 10, y = 6, width = W - 20, height = TITLE_H, level = "caption",
      reveal_delay = 0, active = function() return model.active:get() end, ink = ink,
      text = function() return kind() == "brightness" and "Brightness" or muted() and "Muted" or "Volume" end },
    kit.chip { x = 10, y = CHIP_Y, width = W - 20, filled = true, color = ink,
      text = function() return kind() == "brightness" and "Display" or "Output" end },
    kit.label { x = 10, y = CODE_Y, width = W - 20, elide = "right",
      text = function() return kit.code(kind(), "SD. ##.#") end },
    P.decor_box("scale", { x = COL_X - 32, y = COL_Y, height = COL_H, count = 20, major = 5,
      color = kit.stroke("idle") }),
    P.decor_box("scale", { x = COL_X + COL_W + 2, y = COL_Y, height = COL_H, count = 20, major = 5, flip = true,
      color = kit.stroke("idle") }),
    meter,
    marker,
    kit.text { id = "levels-value", x = 4, y = VALUE_Y, width = W - 8, height = VALUE_H,
      horizontal_alignment = "center", vertical_alignment = "center", font_size = VALUE, font_weight = 300,
      color = ink, text = function() return ("%d%%"):format(math.floor(value() * 100 + .5)) end },
    P.rule { x = 10, y = FOOT_Y, width = W - 20 },
    kit.label { x = 10, y = FOOT_Y + 2, width = W - 20, elide = "right",
      text = function() return kit.code(kind() .. ".foot", "CH. ##") end },
  }
  local panel = ui.Item { id = "levels-swell", x = tucked(), width = 0, height = 0, opacity = 0, visible = false,
    stretch = { stiffness = 360, damping = 30, scale = .1, max = .2 },
    y = function()
      local g = geometry()
      return math.max(12, math.min(g.h - H - 12, g.tops[kind()] + g.item / 2 - H / 2))
    end, behavior = { y = { duration = 200, easing = theme.ease.standard } }, body }
  local shape = ui.SdfShape { id = "levels-swell-background", shape = "box", operation = "smooth_union",
    blend_group = 1001, track = panel, radius = REST, opacity = 0 }
  local root = ui.Item { id = "levels", anchors = { fill = true }, panel }
  for _, name in ipairs { "volume", "brightness" } do
    ui.reparent(kit.surface { id = "levels-" .. name, x = function() return geometry().pill_x end,
      y = function() return geometry().tops[name] end, width = 6, height = function() return geometry().pill_h end,
      radius = P.control_round(6),
      color = function() return model.shown:get() == name and ink() or kit.stroke("idle")() end,
      opacity = function() return model.shown:get() == name and 1 or .6 end,
      behavior = { color = { duration = 180 }, opacity = { duration = 180 } },
    }, root)
  end
  kit.ride("levels", root, model.sidebar.drawer,
    function() return -(theme.SIDE_W + theme.STRIP / 2 + theme.BORDER / 2) end)

  local motion
  local function show()
    if motion then motion:stop() end
    local fresh = not panel.visible or panel.x > out() + W / 2
    panel.width, panel.height = W, H
    panel.visible = true
    local steps = {
      { node = panel, property = "x", to = out(), duration = 420, easing = theme.ease.spatial },
      { node = panel, property = "opacity", to = 1, duration = 180 },
      { node = shape, property = "opacity", to = 1, duration = 180 },
      { node = shape, property = "radius", to = REST, duration = 520, easing = theme.ease.spatial },
    }
    -- Coming out, the column fills from its floor and the marker drops in.
    if fresh then
      shape.radius = ROUND
      steps[#steps + 1] = { node = meter, property = "scale_y", from = 0, to = 1, duration = 520, delay = 80,
        easing = theme.ease.spatial }
      steps[#steps + 1] = { node = marker, property = "opacity", from = 0, to = 1, duration = 240, delay = 260 }
    end
    motion = morf.animation.play { { parallel = steps },
      on_finished = function() meter.scale_y, marker.opacity = 1, 1 end }
  end
  local function hide(done)
    if motion then motion:stop() end
    motion = morf.animation.play { { parallel = {
      { node = panel, property = "x", to = tucked(), duration = 260, easing = theme.ease.emphasized_accel },
      { node = panel, property = "opacity", to = 0, duration = 200 },
      { node = shape, property = "opacity", to = 0, duration = 200 },
      { node = shape, property = "radius", to = ROUND, duration = 240, easing = theme.ease.emphasized_accel },
    } }, on_finished = function(reason)
      if reason ~= "completed" then return end
      panel.width, panel.height = 0, 0
      panel.visible = false
      done()
    end }
  end
  return { node = root, shape = shape, show = show, hide = hide, hold = 2200, geometry = geometry }
end
return V
