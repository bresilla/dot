-- Material's style for the shared display widgets (lib.kit.display): tonal
-- surfaces, soft corners that follow a box's size, filled shapes over
-- strokes, the wallpaper palette for series, the theme's own type.
return function(theme, M)
  local function C() return theme.color end
  -- Series tones: the accent first, then the palette's other roles.
  local SERIES = { "primary", "tertiary", "secondary", "error", "primaryFixedDim", "tertiaryFixedDim" }
  return {
    name = "material",
    accent = M.signal("accent"), ok = M.signal("ok"), warn = M.signal("warn"), alert = M.signal("alert"),
    info = M.signal("info"), extra = M.signal("extra"),
    series = function(i)
      return function()
        local c = C()
        local tone = c[SERIES[(i - 1) % #SERIES + 1]] or c.primary
        -- Past the six roles, the same tones lighter.
        return i > #SERIES and tone:mix(c.surface, 0.35) or tone
      end
    end,
    surface = function() return C().surfaceContainer end,
    raised = function() return C().surfaceContainerHigh end,
    track = function() return C().surfaceContainerHighest end,
    line = function() return C().outlineVariant end,
    ink = function() return C().onSurface end,
    ink_lo = function() return C().onSurfaceVariant end,
    on_accent = function() return C().onPrimary end,
    -- Corners: half a small thing's height, 12 at most; full pills for bars.
    radius = function(h) return math.min((h or 0) / 2, 12) end,
    pill = true,
    hatched = false,
    stroke = 1,
    size = theme.size,
    font = theme.font, mono_font = theme.mono,
    text = M.text, label = M.label, icon = M.icon,
    surface_node = M.surface,
    -- A container's decoration: none (the tone and corners are the look).
    marks = function() return nil end,
    motion = { duration = theme.duration.normal, easing = theme.ease.emphasized_decel or "out_cubic" },
    spring = M.spring,
  }
end
