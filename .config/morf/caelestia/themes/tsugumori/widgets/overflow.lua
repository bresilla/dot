-- Tsugumori's looks for each Overflow widget. The layout is the kit's (the
-- glue in lib.kit.overflow: items at running x that move into place as
-- the line overflows, "more" where the hidden ones went), drawn square: the
-- "more" button a framed key whose stroke brightens under the pointer and
-- that wears brackets while its menu is open, a tab strip's chosen tab
-- marked by a primary bar along its top that runs from tab to tab, a
-- breadcrumb trail's gap as "…", the rest of a chip row as a framed "+N".
local ui = require("morf.ui")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local quick = { duration = 140, easing = "out_cubic" }
  local slide = { duration = 220, easing = "out_expo" }
  local function ink(s) return function() return s.open() and C.primary or C.onSurfaceVariant end end

  --- A square key: a faint wash pressed, hovered or open, its frame
  --- brightening under the pointer, brackets while open.
  local function key(s, inset)
    inset = inset or 3
    return ui.Item { anchors = { fill = true, margins = inset },
      ui.Rect { anchors = { fill = true }, color = function()
          return C.primary:alpha(s.down() and .18 or (s.open() and .14 or (s.hovered() and .055 or 0))) end,
        behavior = { color = quick } },
      ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
        border_color = function() return (s.hovered() or s.open()) and stroke(C, "hover") or stroke(C, "quiet") end,
        behavior = { border_color = quick } },
      hud().corners { length = 5, weight = 2, color = function() return C.primary end,
        visible = function() return s.open() or s.focused() end } }
  end
  local function glyph_key(s, glyph)
    return ui.Item { anchors = { fill = true }, key(s), M.icon(glyph, 18, ink(s), { anchors = { center_in = true } }) }
  end
  local function menu() return { placement = "bottom-end", width = 220, item_height = 34 } end

  function S.Overflow(t, spec)
    return { background = ui.Item {}, more = function(s) return glyph_key(s, "more_horiz") end, menu = menu }
  end
  function S.overflow_toolbar(t, spec)
    return { background = ui.Item {}, more = function(s) return glyph_key(s, "more_horiz") end, menu = menu }
  end

  --- A tab strip: ruled underneath in the idle stroke; a primary bar
  --- along the top of the chosen tab that runs to the next; the menu's
  --- key a chevron that turns.
  function S.overflow_tabs(t, spec)
    local track = ui.Item { y = 0, height = 2, x = function() return t.cur_x or 0 end,
      width = function() return t.cur_w or 0 end, behavior = { x = slide, width = slide } }
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
          color = function() return stroke(C, "idle") end },
        track,
        ui.Sdf { anchors = { fill = true }, z = 1, visible = function() return (t.current or 0) > 0 end,
          ui.SdfShape { shape = "box", track = track, radius = 0, fill_color = function() return C.primary end } } },
      more = function(s)
        return ui.Item { anchors = { fill = true }, key(s),
          ui.Item { anchors = { center_in = true }, width = 18, height = 18,
            rotation = function() return s.open() and 180 or 0 end, behavior = { rotation = slide },
            M.icon("expand_more", 18, ink(s)) } }
      end,
      menu = menu,
    }
  end

  --- A breadcrumb trail: the chevron into the gap, "…" on a framed key.
  function S.overflow_breadcrumbs(t, spec)
    return {
      background = ui.Item {},
      more = function(s)
        return ui.Row { anchors = { fill = true }, align = "center", gap = 0,
          ui.Item { width = 18, height = 18,
            M.icon("chevron_right", 16, function() return C.onSurfaceVariant end, { anchors = { center_in = true } }) },
          ui.Item { width = s.width - 18, height = s.height, key(s, 5),
            M.text { anchors = { fill = true }, text = "…", font_size = theme.size.normal, color = ink(s),
              horizontal_alignment = "center", vertical_alignment = "center" } } }
      end,
      menu = function() return { placement = "bottom-start", width = 220, item_height = 34 } end,
    }
  end

  --- The rest of a chip row: a framed key saying "+N" in the label face.
  function S.chip_overflow(t, spec)
    return {
      background = ui.Item {},
      more = function(s)
        return ui.Item { anchors = { fill = true }, key(s, 1),
          M.menu_label { anchors = { fill = true }, text = function() return "+" .. tostring(s.count()) end,
            color = ink(s), horizontal_alignment = "center", vertical_alignment = "center" } }
      end,
      menu = function() return { placement = "bottom-start", width = 200, item_height = 34 } end,
    }
  end

  --- A site's navigation: the tab strip's bar, the rest behind the key.
  function S.priority_nav(t, spec)
    local slots = S.overflow_tabs(t, spec)
    slots.more = function(s) return glyph_key(s, "more_horiz") end
    return slots
  end
end
