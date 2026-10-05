-- The Tsugumori desktop frame: a square opening with ruler ticks along
-- its inner lip. The workspace rail and level pills sit in the side bands.
-- Rulers are cached paths, static while the desktop geometry is unchanged.
local ui = require("morf.ui")
local theme = require("theme")
local C = theme.color
local V = {}

function V.insets(bar)
  bar = bar or { left = 0, top = 0, right = 0, bottom = 0 }
  return { left = theme.LEFT + bar.left, top = theme.BORDER + bar.top,
    right = theme.BORDER + bar.right, bottom = theme.BORDER + bar.bottom }
end

local PITCH, MAJOR = 8, 10        -- ruler: a tick every PITCH px, every MAJORth long
local EDGE_PAD = 4                -- keep ticks clear of the opening ends

-- A ruler along one edge of the opening: ticks rise out of the band from
-- the opening's lip, continuing evenly behind the pills.
-- `edge` is top/bottom/left/right.
local function ruler(model, edge)
  local B, L = theme.BORDER, theme.LEFT
  local function size() local _, _, w, h = model.desk() return w, h end
  local horizontal = edge == "top" or edge == "bottom"
  local function d(major)
    local w, h = size()
    local a0, a1 = horizontal and L + EDGE_PAD or B + EDGE_PAD,
      horizontal and w - B - EDGE_PAD or h - B - EDGE_PAD
    local origin, every = a0, MAJOR
    if not horizontal then
      local rail = require("rail").geometry()
      -- Three evenly spaced workspaces between consecutive major ticks.
      origin = rail.top - rail.gap / 2
      every = 3 * (rail.item + rail.gap) / PITCH
    end
    local out = {}
    for k = math.ceil((a0 - origin) / PITCH), math.floor((a1 - origin) / PITCH) do
      local at = origin + k * PITCH
      if (k % every == 0) == major then
        local s = major and 5 or 2
        local p = math.floor(at) + .5
        if edge == "top" then out[#out + 1] = ("M%g %g V%g "):format(p, B, B - s)
        elseif edge == "bottom" then out[#out + 1] = ("M%g %g V%g "):format(p, h - B, h - B + s)
        elseif edge == "left" then out[#out + 1] = ("M%g %g H%g "):format(L, p, L - s)
        else out[#out + 1] = ("M%g %g H%g "):format(w - B, p, w - B + s) end
      end
    end
    return #out > 0 and table.concat(out) or "M0 0"
  end
  return ui.Item { id = "tsugumori-frame-ruler-" .. edge, anchors = { fill = true },
    ui.Path { id = "tsugumori-frame-ruler-" .. edge .. "-minor", anchors = { fill = true }, d = function() return d(false) end,
      fill_color = "transparent", stroke_color = function() return C.primary:alpha(.4) end, stroke_width = 1 },
    ui.Path { id = "tsugumori-frame-ruler-" .. edge .. "-major", anchors = { fill = true }, d = function() return d(true) end,
      fill_color = "transparent", stroke_color = function() return C.primary:alpha(.72) end, stroke_width = 1 },
  }
end

local function decorations(model)
  return ui.Item { id = "tsugumori-frame-marks", anchors = { fill = true },
    ruler(model, "top"),
    ruler(model, "bottom"),
    ruler(model, "left"),
    ruler(model, "right"),
  }
end

function V.build(model)
  local opening = ui.SdfShape { id = "frame-opening", shape = "box", operation = "subtract", radius = 0,
    x = function() local x = model.desk() return x + theme.LEFT end,
    y = function() local _, y = model.desk() return y + theme.BORDER end,
    width = function() local _, _, w = model.desk() return w - theme.LEFT - theme.BORDER end,
    height = function() local _, _, _, h = model.desk() return h - 2 * theme.BORDER end }
  local transition = require("themes.session").transition
  require("themes.switcher").morph(opening, "radius", 0, transition and transition.frame_rounding)
  local field = { id = "frame", anchors = { fill = true }, fill_color = function() return C.surface end, blend = 0,
    ui.SdfShape { shape = "box", anchors = { fill = true } },
    opening,
  }
  for _, drawer in ipairs(model.drawers) do field[#field + 1] = drawer.shape end
  field[#field + 1] = model.rail.shape
  -- The rail's lip swells the frame at the workspace on show.
  local rail = require("themes.tsugumori.views.rail")
  for _, shape in ipairs(rail.extra_shapes or {}) do field[#field + 1] = shape end
  field[#field + 1] = model.levels.shape
  return require("themes.frame_host")(model, ui.Sdf(field), V.insets(), decorations(model))
end
return V
