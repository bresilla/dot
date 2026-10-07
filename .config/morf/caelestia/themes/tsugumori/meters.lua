-- Quiet instrument levels: square segments lit up to a value. (The slider
-- and the media rail are skins of the kit's Range: skins.lua.)
local morf = require("morf")
local ui = require("morf.ui")

return function(theme, kit)
  local C = theme.color
  local M = {}
  local motion = { duration = 160, easing = "out_cubic" }
  local function clamp(v) return math.max(0, math.min(1, v)) end

  --- A thin level: square segments, lit up to the value.
  function M.bar(spec)
    local W, H = spec.width, spec.stroke or 4
    local color = spec.color or function() return C.primary end
    local n = math.max(6, math.floor(W / 7))
    local gap = 2
    local seg = math.max(0.5, (W - gap * (n - 1)) / n)
    local d = ("M0 %g H%g"):format(H / 2, W)
    local function lit() return math.floor(clamp(spec.value()) * n + .5) / n end
    return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = W, height = H,
      ui.Path { width = W, height = H, view_box = { 0, 0, W, H }, d = d, fill_color = "transparent",
        stroke_width = H, dash = { seg, gap }, stroke_cap = "butt",
        stroke_color = spec.track or function() return C.primary:alpha(.16) end },
      ui.Path { id = spec.id and spec.id .. "-fill", width = W, height = H, view_box = { 0, 0, W, H }, d = d,
        fill_color = "transparent", stroke_width = H, dash = { seg, gap }, stroke_cap = "butt", stroke_color = color,
        opacity = function() return lit() > 0 and 1 or 0 end,
        trim_end = function() return math.max(.0001, lit()) end, behavior = { trim_end = motion } },
    }
  end

  return M
end
