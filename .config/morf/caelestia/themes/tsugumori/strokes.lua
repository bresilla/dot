-- Decorative lines follow the wallpaper accent without competing with text.
-- Keep these separate from palette roles: muted text and status ink stay legible.
local opacity = { quiet = .10, idle = .18, corner = .42, hover = .45, focus = .65 }
return function(colors, role)
  return colors.primary:alpha(assert(opacity[role or "idle"], "unknown stroke role"))
end
