-- Tsugumori's looks for each Roving widget. The layout is the kit's (the
-- glue in lib.kit.roving: members in a row, one Tab stop), drawn square in
-- the wallpaper's roles: a toolbar framed by the primary's quiet stroke on
-- the low container, a menu bar as a strip ruled underneath, separators as
-- notched hairlines. What moves is one square field block -- a faint
-- primary plate under the current member, or a frame over members with
-- grounds of their own -- riding a track whose leading edge snaps across
-- first and whose trailing edge follows, so it draws out to the next
-- member and in again; the keyboard's brackets ride on it.
local ui = require("morf.ui")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local quick = { duration = 140, easing = "out_cubic" }
  local function glide(t, inset)
    return require("lib.kit.roving").glide(t, { reduced = theme.reduced, duration = 200, lead = 0.4,
      fit = function(x, y, w, h) return x + inset, y + inset, math.max(0, w - 2 * inset), math.max(0, h - 2 * inset) end })
  end
  local function shown(t) return function() return (t.within or (t.open or 0) > 0) and 1 or 0 end end

  --- The plate: a square of the primary, stronger under an open menu's
  --- title; a primary bar along its foot and brackets on it under a
  --- keyboard.
  local function plate(t)
    local track = glide(t, 1)
    ui.reparent(ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 2,
      color = function() return C.primary end, opacity = function() return (t.open or 0) > 0 and 1 or 0 end,
      behavior = { opacity = quick } }, track)
    ui.reparent(hud().corners { length = 5, weight = 2, color = function() return C.primary end,
      visible = function() return t.keyboard end }, track)
    return ui.Item { anchors = { fill = true }, z = -1, track,
      ui.Sdf { anchors = { fill = true },
        ui.SdfShape { shape = "box", track = track, radius = 0, opacity = shown(t), behavior = { opacity = quick },
          fill_color = function()
            if (t.open or 0) > 0 then return C.primary:alpha(.18) end
            return C.primary:alpha(t.keyboard and .14 or .07)
          end } } }
  end

  --- A frame over the current member, 2 px out: the box less the box a
  --- pixel inside it, in the focus stroke, with brackets.
  local function frame(t)
    local track = glide(t, -2)
    local inner = ui.Item { anchors = { fill = true, margins = 1 } }
    ui.reparent(inner, track)
    ui.reparent(hud().corners { length = 6, weight = 2, color = function() return C.primary end,
      visible = function() return t.keyboard end }, track)
    return ui.Item { anchors = { fill = true }, z = 2, track,
      ui.Item { anchors = { fill = true }, opacity = function() return t.keyboard and 1 or 0 end,
        behavior = { opacity = quick },
        ui.Sdf { anchors = { fill = true }, fill_color = function() return stroke(C, "focus") end,
          ui.SdfShape { shape = "box", track = track, radius = 0 },
          ui.SdfShape { shape = "box", track = inner, radius = 0, operation = "subtract" } } } }
  end

  --- A hairline with a primary notch at its middle.
  local function notched(vertical)
    return ui.Item { width = vertical and 11 or 24, height = vertical and 24 or 11,
      ui.Rect { anchors = { center_in = true }, width = vertical and 1 or 18, height = vertical and 18 or 1,
        color = function() return stroke(C, "idle") end },
      ui.Rect { anchors = { center_in = true }, width = vertical and 3 or 1, height = vertical and 1 or 3,
        color = function() return C.primary end } }
  end
  local function framed()
    return ui.Item { anchors = { fill = true }, z = -2,
      ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerLow end },
      ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
        border_color = function() return stroke(C, "idle") end } }
  end

  function S.Roving(t, spec) return { background = framed(), indicator = plate(t), separator = notched } end

  --- A toolbar: framed on the low container.
  function S.toolbar_group(t, spec) return { background = framed(), indicator = plate(t), separator = notched } end

  --- A menu bar: the low container ruled underneath in the primary's
  --- quiet stroke; the open menu's title on a stronger plate with its bar.
  function S.menubar(t, spec)
    return {
      background = ui.Item { anchors = { fill = true }, z = -2,
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerLow end },
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
          color = function() return stroke(C, "hover") end } },
      indicator = plate(t), separator = notched,
    }
  end

  --- A linked group: the segments draw the row; the frame slides over it.
  function S.button_group(t, spec)
    return { background = ui.Item {}, indicator = frame(t), separator = function() return ui.Item { width = 1, height = 1 } end }
  end

  --- Chips: the frame slides from chip to chip.
  function S.chip_row(t, spec) return { background = ui.Item {}, indicator = frame(t), separator = notched } end

  --- A bar of icons: framed, with the plate.
  function S.icon_bar(t, spec) return { background = framed(), indicator = plate(t), separator = notched } end
end
