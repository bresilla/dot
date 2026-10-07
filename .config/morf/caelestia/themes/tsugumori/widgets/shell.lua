-- Tsugumori's Shell looks: square, framed, technical. The window is the
-- surface in a hairline frame; the header a surfaceContainer strip ruled
-- in the accent with a block at its start and a hatched run at its end;
-- the sidebar and the inspector panels on surfaceContainerLow with a
-- hairline toward the page and registration marks on their corners --
-- folded into a drawer, the sidebar's edge turns to a solid accent rule
-- -- and the toolbars and bottom bar strips ruled toward the page with
-- a tick ruler along them. Each ground is the skin's slot of that
-- region, laid under it by lib.kit.shell so it moves with it. The
-- behaviour is the archetype's.
local morf = require("morf")
local ui = require("morf.ui")
local stripes = require("themes.tsugumori.stripes")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local quick = { duration = 140, easing = "out_cubic" }
  local MARK = "M0 0 H7 V1.5 H1.5 V7 H0 Z"

  -- A hairline along an edge of the box it fills: "start"/"end"
  -- (mirrored right to left), "top" or "bottom".
  local function rule(t, side, color, weight)
    weight = weight or 1
    if side == "top" or side == "bottom" then
      return ui.Rect { anchors = { left = true, right = true, [side] = true }, height = weight, color = color }
    end
    local function at_right() return (side == "end") ~= (t.mirrored == true) end
    return ui.Item { anchors = { fill = true },
      ui.Rect { anchors = { right = true, top = true, bottom = true }, width = weight, color = color,
        visible = at_right, behavior = { color = quick } },
      ui.Rect { anchors = { left = true, top = true, bottom = true }, width = weight, color = color,
        visible = function() return not at_right() end, behavior = { color = quick } } }
  end
  -- Registration marks on two diagonal corners of the box.
  local function marks(color)
    return ui.Item { anchors = { fill = true },
      ui.Path { anchors = { left = true, top = true, left_margin = 4, top_margin = 4 }, width = 7, height = 7,
        view_box = { 0, 0, 7, 7 }, d = MARK, fill_color = color },
      ui.Path { anchors = { right = true, bottom = true, right_margin = 4, bottom_margin = 4 }, width = 7, height = 7,
        view_box = { 0, 0, 7, 7 }, d = MARK, rotation = 180, fill_color = color } }
  end
  -- A hatched band at the far end of a strip, standing on its rule.
  local function hatch(color)
    return ui.Item { anchors = { right = true, bottom = true, right_margin = 10, bottom_margin = 1 },
      width = 56, height = 5, clip = true,
      stripes.box { width = 56, height = 5, gap = 4, weight = 1.5, color = color } }
  end
  -- A tick ruler along a strip's edge (static: drawn once at its size).
  local function ruler(len, color, anchors)
    return ui.Path { anchors = anchors, width = len, height = 4, view_box = { 0, 0, len, 4 },
      d = morf.geometry.ruler(len, 4, { pitch = 8, major = 5, min_count = 4 }),
      fill_color = "transparent", stroke_color = color, stroke_width = 1 }
  end

  local function frame(o)
    o = o or {}
    return function(t, spec)
      local W = tonumber(type(spec.width) == "function" and spec.width() or spec.width) or 0
      local function header()
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainer end },
          rule(t, "bottom", function() return C.primary:alpha(.5) end),
          ui.Rect { anchors = { left = true, top = true, bottom = true, top_margin = 10, bottom_margin = 10 },
            width = 3, color = function() return C.primary end },
          hatch(function() return C.primary:alpha(.6) end) }
      end
      local function strip(edge)
        local bar = ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainer end },
          rule(t, edge, function() return C.primary:alpha(.5) end) }
        if W > 0 then
          ui.reparent(ruler(W, function() return stroke(C, "idle") end,
            edge == "top" and { top = true, top_margin = 1 } or { bottom = true, bottom_margin = 1 }), bar)
        end
        return bar
      end
      local function panel(side)
        return ui.Item { anchors = { fill = true },
          ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerLow end },
          marks(function() return stroke(C, "corner") end),
          side == "end" and rule(t, "end", function()
            return t.collapsed and C.primary or stroke(C, "idle")
          end, 1) or rule(t, side, function() return stroke(C, "idle") end) }
      end
      return {
        background = ui.Rect { anchors = { fill = true }, color = function() return C.surface end },
        -- The window's frame, over its regions (in the toasts' layer, the
        -- topmost): a hairline with brackets on its corners.
        toasts = ui.Item { anchors = { fill = true }, z = 60,
          ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
            border_color = function() return C.primary:alpha(.24) end },
          hud().corners { length = 8, weight = 2, color = function() return C.primary:alpha(.8) end } },
        content = o.content and ui.Rect { anchors = { fill = true }, color = function() return C[o.content] end } or nil,
        header_bar = header(),
        toolbar_top = strip("bottom"),
        toolbar_bottom = strip("top"),
        bottom_bar = strip("top"),
        sidebar = panel("end"),
        inspector = panel("start"),
      }
    end
  end

  S.Shell = frame()
  S.window_layout = frame()
  S.header_bar = frame()
  S.toolbar_view = frame()
  S.split_view = frame()
  S.overlay_split_view = frame()
  S.navigation_split_view = frame()
  S.multi_pane = frame()
  S.breakpoint_bin = frame()
  S.clamp = frame()
  S.bottom_bar = frame()
end
