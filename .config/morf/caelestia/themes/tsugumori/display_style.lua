-- Tsugumori's style for the shared display widgets (lib.kit.display):
-- square everything, hairline frames with registration marks on the
-- diagonal, hatched fills, mono type, quantised readings, the wallpaper
-- palette's signal tones for series.
return function(theme, M, marks)
  local C = theme.color
  local SERIES = { "accent", "info", "ok", "warn", "extra", "alert" }
  return {
    name = "tsugumori",
    accent = M.signal("accent"), ok = M.signal("ok"), warn = M.signal("warn"), alert = M.signal("alert"),
    info = M.signal("info"), extra = M.signal("extra"),
    series = function(i)
      local tone = M.signal(SERIES[(i - 1) % #SERIES + 1])
      if i <= #SERIES then return tone end
      return function() return tone():alpha(0.6) end
    end,
    surface = function() return C.surfaceContainer end,
    raised = function() return C.surfaceContainerHigh end,
    track = function() return C.primary:alpha(0.13) end,
    line = M.stroke("idle"),
    ink = function() return C.onSurface end,
    ink_lo = function() return C.onSurfaceVariant end,
    on_accent = function() return C.surface end,
    radius = function() return 0 end,
    pill = false,
    -- Fills carry `/` stripes (stripes.lua) over a faint wash.
    hatched = true,
    stroke = 1,
    size = theme.size,
    font = theme.font, mono_font = theme.mono,
    text = M.text, label = M.label, icon = M.icon,
    surface_node = M.surface,
    -- A container's decoration: the registration marks on its diagonal.
    marks = function(color) return marks(8, color or M.stroke("mark"), -3) end,
    stripes = require("themes.tsugumori.stripes"),
    stroke_of = M.stroke,
    motion = { duration = theme.duration.normal, easing = "out_cubic" },
    spring = M.spring,
  }
end
