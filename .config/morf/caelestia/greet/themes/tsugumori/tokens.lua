-- Tsugumori geometry, type and motion. No palette values belong here: every
-- colour comes from the wallpaper roles (`theme.color`) and `theme.lule`.
local M = {}

-- -------------------------------------------------------------------- type --

M.font = "IBM Plex Mono, JetBrains Mono, monospace"
M.auth_font = M.font
M.mono = M.font
-- The shared glyph set for icons; Tsugumori draws them at its own weights.
M.icon_font = "Material Symbols Rounded"
-- Pixel sizes shared with every theme's layouts (a layout reserves the box,
-- so the set of names and their sizes must match across themes).
M.size = {
  small = 14, smaller = 15, normal = 16, larger = 17.5, large = 20, extra = 30,
}
M.typography = { title = 16, section = 14, caption = 11, hero = 24, subtitle = 12, label = 11, menu = 13 }

-- ------------------------------------------------------------------ sizes --

-- The frame and side geometry are part of the layout contract (the kit contract):
-- only the corner treatment differs. Tsugumori's corners are square.
M.BORDER, M.LEFT = 10, 10
M.ROUNDING = 2
M.SIDE_W = 430
M.STRIP = 20
M.SEAM = 0
M.PAD = 16
M.GAP = 12
M.key_radius = 0
-- Square everywhere (the old chamfer is 0), and the registration mark
-- length.
M.CHAMFER = 0
M.MARK = 10

-- --------------------------------------------------------------- motion --

M.duration = { small = 140, normal = 240, large = 400, drawer_open = 280, drawer_close = 180 }
M.ease = {
  standard = "out_cubic", standard_decel = "out_cubic", standard_accel = "in_cubic",
  emphasized_decel = "out_cubic", emphasized_accel = "in_cubic",
  spatial = "out_cubic", emphasized = "in_out_cubic",
}
return M
