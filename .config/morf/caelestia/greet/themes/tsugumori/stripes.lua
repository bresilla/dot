-- Tsugumori's hatched fills: diagonal stripes cut to their box, so a filled
-- run is a clipped box of these whose width moves while the stripes stay
-- put -- a changing level redraws nothing but its clip.
local morf = require("morf")
local ui = require("morf.ui")
local S = {}

local cache = {}
--- Path data for `/` stripes across `w` x `h`, one every `gap` pixels
--- along the bottom edge, each cut where it leaves the box
--- (`morf.geometry.hatch`, kept per size).
function S.hatch_d(w, h, gap)
  local key = ("d%g:%g:%g"):format(w, h, gap)
  if not cache[key] then cache[key] = morf.geometry.hatch(w, h, gap) end
  return cache[key]
end

--- A hatched box: `width`, `height` (numbers), `gap` (6), `weight`
--- (stroke, 2), `color`; any other node properties pass through.
function S.box(spec)
  local w, h = spec.width, spec.height
  local gap, weight = spec.gap or 6, spec.weight or 2
  return ui.Path { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h,
    opacity = spec.opacity, view_box = { 0, 0, w, h }, d = S.hatch_d(w, h, gap), fill_color = "transparent",
    stroke_color = spec.color, stroke_width = weight, stroke_cap = "butt" }
end

--- Path data for the `/` stripes inside the area under a stepped series:
--- step `i` spans [x0 + (i-1)*dx, x0 + i*dx] at screen height `ys[i]`, the
--- floor is `h`, the box `w` wide (`morf.geometry.hatch_under`; a chart
--- reading a channel draws the same with `plot = { kind = "hatch_steps" }`).
function S.under_steps_d(x0, dx, ys, w, h, gap)
  return morf.geometry.hatch_under(x0, dx, ys, w, h, gap)
end

return S
