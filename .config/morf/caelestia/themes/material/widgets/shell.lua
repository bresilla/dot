-- Material's Shell looks: the surface as the window's ground, a flat top
-- app bar on it, the page and the inspector as rounded panes a tone up
-- (surfaceContainerLow, surfaceContainer) set in from the edges, the
-- sidebar flush on the surface -- and, folded into a drawer, a
-- surfaceContainerLow sheet with its far corners rounded -- and toolbars
-- and the navigation bar on surfaceContainer. Each ground is the skin's
-- slot of that region, laid under it by lib.kit.shell so it moves with
-- it. The behaviour is the archetype's.
local ui = require("morf.ui")

return function(S, theme, M)
  local function C() return theme.color end
  local PANE, GAP = 16, 6

  -- A rounded pane inside the box it fills: `margins(side)` gives each
  -- edge's inset ("left", "right", "top", "bottom").
  local function pane(role, margins)
    local box = ui.Item { anchors = { fill = true } }
    ui.reparent(ui.Rect { radius = PANE, color = function() return C()[role] end,
      x = function() return margins("left") end, y = function() return margins("top") end,
      width = function() return math.max(0, (box.layout_width or 0) - margins("left") - margins("right")) end,
      height = function() return math.max(0, (box.layout_height or 0) - margins("top") - margins("bottom")) end,
      behavior = { x = M.spring(420, 40), width = M.spring(420, 40) } }, box)
    return box
  end

  local function frame(o)
    o = o or {}
    return function(t, spec)
      local function bar(role) return ui.Rect { anchors = { fill = true }, color = function() return C()[role] end } end
      local capped = (spec.header_bar or spec.toolbar_top) and true or false
      local floored = (spec.toolbar_bottom or spec.bottom_bar) and true or false
      -- Which physical side is the start (the sidebar's), right to left too.
      local function start_side(physical) return (physical == "left") == (t.mirrored ~= true) end
      local function has_sidebar() return spec.sidebar ~= nil and spec.sidebar ~= false end
      -- The page: the edge beside the sidebar or the inspector takes none
      -- of the gap (the neighbour's own inset gives it), the rest all.
      local function page_margin(side)
        if side == "top" then return capped and 0 or GAP end
        if side == "bottom" then return (floored and not (spec.bottom_bar and not t.bottom_bar)) and 0 or GAP end
        if start_side(side) then return (has_sidebar() and t.sidebar_open and not t.collapsed) and 0 or GAP end
        return (spec.inspector ~= nil and t.inspector_shown) and 0 or GAP
      end
      local function inspector_margin(side)
        if side == "top" then return capped and 0 or GAP end
        if side == "bottom" then return GAP end
        return GAP
      end
      return {
        background = ui.Rect { anchors = { fill = true }, color = function() return C().surface end },
        header_bar = bar("surface"),
        toolbar_top = bar("surface"),
        toolbar_bottom = bar("surfaceContainer"),
        bottom_bar = bar("surfaceContainer"),
        -- (A flat page still fills the slot: left empty, the archetype's skin
        -- would fill it with its pane.)
        content = o.flat and ui.Item {} or pane(o.content or "surfaceContainerLow", page_margin),
        -- Beside the page, flush on the surface; as a drawer, a sheet with
        -- its far corners rounded.
        sidebar = ui.Rect { anchors = { fill = true },
          color = function() return t.collapsed and C().surfaceContainerLow or C().surface end,
          top_right_radius = function() return (t.collapsed and not t.mirrored) and PANE or 0 end,
          bottom_right_radius = function() return (t.collapsed and not t.mirrored) and PANE or 0 end,
          top_left_radius = function() return (t.collapsed and t.mirrored) and PANE or 0 end,
          bottom_left_radius = function() return (t.collapsed and t.mirrored) and PANE or 0 end },
        inspector = pane("surfaceContainer", inspector_margin),
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
  -- A bin and a clamp hold one page on the window's own surface.
  S.breakpoint_bin = frame { flat = true }
  S.clamp = frame { flat = true }
  S.bottom_bar = frame()
end
