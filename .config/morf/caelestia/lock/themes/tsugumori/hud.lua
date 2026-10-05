-- Instrument pieces for lists and keys: L-bracket corners, the list
-- selection (a plate with an accent edge, brackets, a hatched strip at its
-- far end and one scanline pass when it lands) and bracketed key caps.
-- Brought over from the Futuristic theme.
local morf = require("morf")
local ui = require("morf.ui")

return function(theme, kit)
  local C = theme.color
  local stripes = require("themes.tsugumori.stripes")
  local common = require("themes.kit_common")
  local get = common.get
  local H = {}
  local STRENGTH = { faint = .13, quiet = .24, idle = .4, mark = .72, hot = 1 }
  local function line(strength) local a = STRENGTH[strength] return function() return C.primary:alpha(a) end end
  H.line = line

  --- Four L-brackets on the corners of whatever box they sit in: `length`
  --- (8), `weight` (1), `inset` (0), `color`.
  function H.corners(spec)
    spec = spec or {}
    local l, t, i = spec.length or 8, spec.weight or 1, spec.inset or 0
    local color = spec.color or line("mark")
    local h = t / 2
    local function mark(anchors, d)
      anchors.left_margin, anchors.right_margin, anchors.top_margin, anchors.bottom_margin = i, i, i, i
      return ui.Path { anchors = anchors, width = l, height = l, view_box = { 0, 0, l, l }, d = d,
        fill_color = "transparent", stroke_color = color, stroke_width = t, stroke_cap = "square" }
    end
    return ui.Item { id = spec.id, anchors = { fill = true }, opacity = spec.opacity, visible = spec.visible,
      mark({ left = true, top = true }, ("M%g %g V%g H%g"):format(h, l, h, l)),
      mark({ right = true, top = true }, ("M0 %g H%g V%g"):format(h, l - h, l)),
      mark({ left = true, bottom = true }, ("M%g 0 V%g H%g"):format(h, l - h, l)),
      mark({ right = true, bottom = true }, ("M0 %g H%g V0"):format(l - h, l - h)),
    }
  end

  --- The highlight under a list's chosen row: `track` (the item that moves
  --- from row to row), `color` (the plate), `id`.
  function H.selection(spec)
    local track = spec.track
    local color = spec.color or function() return C.primary:alpha(.1) end
    local scan = ui.Rect { anchors = { left = true, right = true }, height = 1, z = 2,
      color = function() return C.primary end, opacity = 0 }
    local strip = ui.Item { anchors = { right = true, top = true, bottom = true, right_margin = 10,
        top_margin = 8, bottom_margin = 8 }, width = 64, z = 1, clip = true,
      stripes.box { width = 64, height = 64, gap = 7, weight = 2.5, color = function() return C.primary:alpha(.5) end } }
    for _, child in ipairs {
      ui.Rect { anchors = { left = true, top = true, bottom = true }, width = 3, z = 2,
        color = function() return C.primary end },
      H.corners { length = 7, color = line("hot") },
      strip,
      scan,
    } do ui.reparent(child, track) end
    local settle_timer, running
    local plate = ui.Sdf { id = spec.id, anchors = { fill = true }, z = -1,
      ui.SdfShape { shape = "box", radius = 0, track = track, fill_color = color },
      -- A pass still waiting when the list goes would reach for nodes that
      -- are gone.
      on_destroyed = function() if settle_timer then settle_timer:cancel() settle_timer = nil end end,
    }
    -- Once the track stops moving, one pass of the scanline down the row.
    morf.effect("tsugumori.selection." .. tostring(spec.id or track.id or "list"), function()
      local _ = track.layout_y, track.layout_height
      if settle_timer then settle_timer:cancel() end
      settle_timer = morf.timer(70, function()
        settle_timer = nil
        if running then running:stop() end
        local h = track.layout_height or 0
        if h <= 0 then return end
        running = morf.animation.play { { parallel = {
          { node = scan, property = "translate_y", from = 0, to = h - 1, duration = 220, easing = "out_quart" },
          { node = scan, property = "opacity", duration = 260, keyframes = {
            { at = 0, value = .9 }, { at = .7, value = .6 }, { at = 1, value = 0 } } },
        } }, on_finished = function() running = nil end }
      end, false)
    end, { owner = plate })
    return plate
  end

  --- A key hint cap: a tinted plate with an accent bar, L-brackets and the
  --- key in caps. `text`, `height` (22), `width` (fits the key).
  function H.keycap(spec)
    local h = spec.height or 22
    local size = math.max(10, math.floor(h * .5))
    local key = kit.text { text = function() return tostring(get(spec.text) or ""):upper() end, font_size = size,
      font_weight = 600, letter_spacing = .5, color = kit.ink("hi"), anchors = { vertical_center = true },
      height = h, vertical_alignment = "center" }
    local function W() return get(spec.width) or math.max(h + 2, (key.layout_width or 0) + 15) end
    key.x = function() return math.floor((W() + 3 - (key.layout_width or 0)) / 2) end
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = W, height = h,
      ui.Rect { anchors = { fill = true }, color = function() return C.primary:alpha(.07) end,
        border_width = 1, border_color = line("idle") },
      ui.Rect { x = 2, y = 3, width = 2, height = h - 6, color = function() return C.primary:alpha(.8) end },
      H.corners { length = math.min(5, math.floor(h / 4)), color = line("hot") },
      key,
    }
  end

  return H
end
